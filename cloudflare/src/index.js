/**
 * TokoKu — server aktivasi lisensi di Cloudflare Workers + D1.
 *
 * Kenapa Cloudflare, bukan Supabase:
 *   Proyek gratis Supabase dibekukan kalau tidak ada aktivitas database
 *   sekitar 7 hari. Worker tidak pernah dibekukan, dan kuota gratisnya
 *   100.000 permintaan per hari — jauh lebih dari cukup.
 *
 * Model jual lepas yang dipertahankan: 1 voucher = 1 HP, sekali bayar,
 * tanpa langganan. Aktivasi hanya butuh internet SEKALI, setelah itu
 * aplikasi berjalan penuh secara offline.
 *
 * Dua jalan aktivasi, keduanya tanpa campur tangan penjual:
 *   1. Di dalam aplikasi  → pelanggan menempel Kode Voucher (VC-...)
 *   2. Di halaman portal  → pelanggan menempel Kode Voucher (VC-...)
 *                           lalu menerima Kode Aktivasi (AK-...) untuk
 *                           diketik ke aplikasi
 *
 * Keduanya memakai satu endpoint yang sama: POST /api/aktivasi
 *
 * Selain aktivasi, Worker ini juga melayani unduhan aplikasi (GET /unduh dan
 * GET /unduh/apk) serta pemeriksaan versi (GET /api/versi). Tujuannya satu:
 * pelanggan tidak pernah melihat akun GitHub penjual.
 */

import { halamanPortal } from './halaman-portal.js';
import { halamanAdmin } from './halaman-admin.js';
import { halamanUnduh, halamanUnduhGagal } from './halaman-unduh.js';
import { emailVoucher } from './email-voucher.js';

/**
 * Alfabet kode. Huruf I, O, 0, dan 1 dibuang karena sering tertukar saat
 * pelanggan mengetik ulang. Panjangnya tepat 32 karakter, jadi perhitungan
 * "byte % 32" di bawah tidak berat sebelah ke karakter mana pun.
 */
const ALFABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

const AWALAN_VOUCHER = 'VC';
const AWALAN_AKTIVASI = 'AK';
const AWALAN_PERANGKAT = 'TK';

const HEADER_CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, x-admin-key',
};

// ---------------------------------------------------------------------------
// Alat bantu
// ---------------------------------------------------------------------------

function balasJson(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
      ...HEADER_CORS,
    },
  });
}

function balasHtml(isi, status = 200) {
  return new Response(isi, {
    status,
    headers: {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'no-store',
      // Portal ini berdiri sendiri, tidak butuh skrip dari luar.
      'Content-Security-Policy':
        "default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; connect-src 'self'; img-src 'self' data:; base-uri 'none'; form-action 'none'",
      'X-Content-Type-Options': 'nosniff',
      'Referrer-Policy': 'no-referrer',
    },
  });
}

function normalisasi(nilai) {
  return String(nilai ?? '')
    .trim()
    .toUpperCase()
    .replace(/\s+/g, '');
}

async function bacaJson(request) {
  try {
    const data = await request.json();
    return data && typeof data === 'object' ? data : null;
  } catch (_) {
    return null;
  }
}

/** Hasilkan kode berformat <awalan>-XXXX-XXXX-XXXX. */
function kodeAcak(awalan) {
  const bytes = new Uint8Array(12);
  crypto.getRandomValues(bytes);
  let isi = '';
  for (let i = 0; i < 12; i += 1) {
    isi += ALFABET[bytes[i] % ALFABET.length];
  }
  return `${awalan}-${isi.slice(0, 4)}-${isi.slice(4, 8)}-${isi.slice(8, 12)}`;
}

/** Perbandingan kunci dengan waktu tetap, supaya tidak bisa ditebak pelan-pelan. */
function kunciSama(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string') return false;
  if (a.length !== b.length || a.length === 0) return false;
  let beda = 0;
  for (let i = 0; i < a.length; i += 1) {
    beda |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return beda === 0;
}

function adminSah(request, env) {
  const kunci = env.ADMIN_KEY;
  if (!kunci) return false; // belum diatur → semua operasi admin ditolak
  return kunciSama(request.headers.get('x-admin-key') ?? '', kunci);
}

function sekarangIso() {
  return new Date().toISOString();
}

// ---------------------------------------------------------------------------
// Inti: tukar voucher / aktifkan lisensi
// ---------------------------------------------------------------------------

/**
 * Tukarkan satu voucher menjadi satu lisensi yang terikat ke satu Kode
 * Perangkat. Aman dipanggil dua kali dari HP yang sama (idempotent).
 */
async function tukarVoucher(env, voucher, deviceId, storeName) {
  const v = await env.DB.prepare(
    'SELECT code, status, license_code, customer_name FROM vouchers WHERE code = ?'
  )
    .bind(voucher)
    .first();

  if (!v) return { ok: false, reason: 'not_found' };
  if (v.status === 'revoked') return { ok: false, reason: 'revoked' };

  // Voucher sudah pernah dipakai.
  if (v.status === 'used') {
    const lis = await env.DB.prepare(
      'SELECT code, device_id, customer_name, store_name, status FROM licenses WHERE code = ?'
    )
      .bind(v.license_code)
      .first();

    if (lis && lis.status === 'active' && lis.device_id === deviceId) {
      // HP yang sama membuka portal dua kali, atau instal ulang aplikasi.
      return {
        ok: true,
        already: true,
        activation_code: lis.code,
        customer_name: lis.customer_name,
        store_name: lis.store_name,
      };
    }
    return { ok: false, reason: 'used_on_other_device' };
  }

  const kodeLisensi = kodeAcak(AWALAN_AKTIVASI);
  const waktu = sekarangIso();

  // Klaim voucher secara atomik. Kalau ada dua permintaan berbarengan,
  // hanya satu yang berhasil mengubah baris (changes === 1).
  const klaim = await env.DB.prepare(
    "UPDATE vouchers SET status = 'used', license_code = ?, used_at = ? " +
      "WHERE code = ? AND status = 'unused'"
  )
    .bind(kodeLisensi, waktu, voucher)
    .run();

  if (klaim.meta.changes !== 1) {
    return { ok: false, reason: 'busy' };
  }

  try {
    await env.DB.prepare(
      'INSERT INTO licenses (code, voucher_code, device_id, customer_name, ' +
        "store_name, status, activated_at, created_at) VALUES (?, ?, ?, ?, ?, 'active', ?, ?)"
    )
      .bind(
        kodeLisensi,
        voucher,
        deviceId,
        v.customer_name ?? '',
        storeName,
        waktu,
        waktu
      )
      .run();
  } catch (_) {
    // Gagal menyimpan lisensi → kembalikan voucher supaya pelanggan bisa
    // mencoba lagi, bukan malah kehilangan vouchernya.
    await env.DB.prepare(
      'UPDATE vouchers SET status = ?, license_code = NULL, used_at = NULL ' +
        'WHERE code = ? AND license_code = ?'
    )
      .bind('unused', voucher, kodeLisensi)
      .run();
    return { ok: false, reason: 'server_error' };
  }

  return {
    ok: true,
    activation_code: kodeLisensi,
    customer_name: v.customer_name ?? '',
    store_name: storeName,
  };
}

/**
 * Cocokkan Kode Aktivasi dengan Kode Perangkat HP yang meminta.
 * Inilah satu-satunya panggilan internet yang dilakukan aplikasi.
 */
async function aktifkanLisensi(env, kode, deviceId) {
  const lis = await env.DB.prepare(
    'SELECT code, device_id, customer_name, store_name, status, activated_at ' +
      'FROM licenses WHERE code = ?'
  )
    .bind(kode)
    .first();

  if (!lis) return { ok: false, reason: 'not_found' };
  if (lis.status !== 'active') return { ok: false, reason: 'revoked' };

  const waktu = sekarangIso();

  // Lisensi lama yang belum sempat terikat (mis. dibuat manual lewat admin).
  if (!lis.device_id) {
    await env.DB.prepare(
      'UPDATE licenses SET device_id = ?, activated_at = coalesce(activated_at, ?) ' +
        'WHERE code = ? AND device_id IS NULL'
    )
      .bind(deviceId, waktu, kode)
      .run();

    return {
      ok: true,
      customer_name: lis.customer_name,
      store_name: lis.store_name,
      activated_at: lis.activated_at ?? waktu,
    };
  }

  if (lis.device_id === deviceId) {
    return {
      ok: true,
      already: true,
      customer_name: lis.customer_name,
      store_name: lis.store_name,
      activated_at: lis.activated_at ?? waktu,
    };
  }

  return { ok: false, reason: 'used_on_other_device' };
}

/** Satu pintu masuk untuk aplikasi maupun portal. */
async function tanganiAktivasi(request, env) {
  const body = await bacaJson(request);
  if (!body) return balasJson({ ok: false, reason: 'bad_request' }, 400);

  const kode = normalisasi(body.code);
  const deviceId = normalisasi(body.device_id);
  const storeName = String(body.store_name ?? '')
    .trim()
    .slice(0, 80);

  if (!kode || !deviceId) {
    return balasJson({ ok: false, reason: 'invalid_code' });
  }

  if (kode.startsWith(`${AWALAN_PERANGKAT}-`)) {
    // Pelanggan salah menempel Kode Perangkat ke kolom Kode Voucher.
    return balasJson({ ok: false, reason: 'device_code_entered' });
  }

  const hasil = kode.startsWith(`${AWALAN_VOUCHER}-`)
    ? await tukarVoucher(env, kode, deviceId, storeName)
    : await aktifkanLisensi(env, kode, deviceId);

  // Selalu 200 supaya aplikasi membaca kolom "reason" dan menampilkan pesan
  // yang ramah, bukan sekadar "server menolak (400)".
  return balasJson(hasil);
}

// ---------------------------------------------------------------------------
// Operasi admin (penjual) — semuanya wajib menyertakan header x-admin-key
// ---------------------------------------------------------------------------

async function tanganiBuatVoucher(request, env) {
  const body = (await bacaJson(request)) ?? {};
  const jumlah = Math.min(Math.max(parseInt(body.jumlah ?? 1, 10) || 1, 1), 200);
  const awalan = normalisasi(body.awalan) || AWALAN_VOUCHER;
  const batch = String(body.batch ?? '')
    .trim()
    .slice(0, 40);
  const nama = String(body.customer_name ?? '')
    .trim()
    .slice(0, 80);

  const waktu = sekarangIso();
  const dibuat = [];

  for (let i = 0; i < jumlah; i += 1) {
    // Peluang bentrok sangat kecil, tapi tetap dicoba beberapa kali.
    for (let coba = 0; coba < 5; coba += 1) {
      const kode = kodeAcak(awalan);
      try {
        await env.DB.prepare(
          'INSERT INTO vouchers (code, batch, customer_name, status, created_at) ' +
            "VALUES (?, ?, ?, 'unused', ?)"
        )
          .bind(kode, batch, nama, waktu)
          .run();
        dibuat.push(kode);
        break;
      } catch (_) {
        if (coba === 4) return balasJson({ ok: false, reason: 'server_error' }, 500);
      }
    }
  }

  return balasJson({ ok: true, vouchers: dibuat });
}

async function tanganiLepasPerangkat(request, env) {
  const body = (await bacaJson(request)) ?? {};
  const kode = normalisasi(body.code);
  if (!kode) return balasJson({ ok: false, reason: 'invalid_code' }, 400);

  const hasil = await env.DB.prepare(
    'UPDATE licenses SET device_id = NULL, activated_at = NULL WHERE code = ?'
  )
    .bind(kode)
    .run();

  if (hasil.meta.changes !== 1) {
    return balasJson({ ok: false, reason: 'not_found' });
  }
  return balasJson({ ok: true, code: kode });
}

async function tanganiNonaktifkan(request, env) {
  const body = (await bacaJson(request)) ?? {};
  const kode = normalisasi(body.code);
  const jenis = String(body.jenis ?? 'lisensi').toLowerCase();
  if (!kode) return balasJson({ ok: false, reason: 'invalid_code' }, 400);

  if (jenis === 'voucher') {
    const hasil = await env.DB.prepare(
      "UPDATE vouchers SET status = 'revoked' WHERE code = ?"
    )
      .bind(kode)
      .run();
    if (hasil.meta.changes !== 1) {
      return balasJson({ ok: false, reason: 'not_found' });
    }
    return balasJson({ ok: true, code: kode, jenis: 'voucher' });
  }

  const hasil = await env.DB.prepare(
    "UPDATE licenses SET status = 'revoked' WHERE code = ?"
  )
    .bind(kode)
    .run();
  if (hasil.meta.changes !== 1) {
    return balasJson({ ok: false, reason: 'not_found' });
  }
  return balasJson({ ok: true, code: kode, jenis: 'lisensi' });
}

async function tanganiDataAdmin(env) {
  const vouchers = await env.DB.prepare(
    'SELECT code, batch, customer_name, customer_email, order_ref, status, ' +
      'license_code, created_at, used_at ' +
      'FROM vouchers ORDER BY created_at DESC, code ASC LIMIT 500'
  ).all();

  const licenses = await env.DB.prepare(
    'SELECT code, voucher_code, device_id, customer_name, store_name, status, ' +
      'activated_at, created_at FROM licenses ' +
      'ORDER BY activated_at DESC, code ASC LIMIT 500'
  ).all();

  const ringkas = await env.DB.prepare(
    'SELECT ' +
      "(select count(*) from vouchers where status = 'unused')  as voucher_tersedia, " +
      "(select count(*) from vouchers where status = 'used')    as voucher_terpakai, " +
      "(select count(*) from vouchers where status = 'revoked') as voucher_mati, " +
      "(select count(*) from licenses where status = 'active')  as lisensi_aktif, " +
      "(select count(*) from licenses where status = 'revoked') as lisensi_mati"
  ).first();

  // Catatan pesanan dari platform jualan, supaya penjual bisa memeriksa
  // "pesanan ini sudah masuk atau belum" dan mengirim ulang emailnya.
  const pesanan = await env.DB.prepare(
    'SELECT delivery_id, event, status, voucher_code, email, email_status, ' +
      'alasan, received_at FROM webhook_events ' +
      'ORDER BY received_at DESC LIMIT 50'
  ).all();

  return balasJson({
    ok: true,
    ringkas: ringkas ?? {},
    vouchers: vouchers.results ?? [],
    licenses: licenses.results ?? [],
    pesanan: pesanan.results ?? [],
  });
}

// ---------------------------------------------------------------------------
// Pesanan otomatis dari platform jualan (OrderHero)
// ---------------------------------------------------------------------------
//
// Pelanggan membayar di OrderHero -> OrderHero mengirim webhook ke sini ->
// tanda tangan diverifikasi -> satu voucher dibuat -> email berisi kode dan
// tautan unduh dikirim ke pembeli. Penjual tidak menyentuh apa pun.
//
// Dua hal yang WAJIB benar:
//   1. Tanda tangan diverifikasi. Tanpa ini siapa pun bisa mengirim pesanan
//      palsu dan mendapat voucher gratis.
//   2. Penerimaan idempoten. OrderHero bisa mengirim satu event lebih dari
//      sekali; tanpa penjaga ini satu pembayaran menghasilkan dua voucher.

/** Verifikasi header X-Webhook-Signature ala OrderHero: "t=<detik>,v1=<hex>". */
async function tandaTanganSah(rawBody, header, secret) {
  const cocok = /^t=(\d+),v1=([a-f0-9]+)$/i.exec(String(header || '').trim());
  if (!cocok) return false;

  const cap = cocok[1];
  const diberi = cocok[2].toLowerCase();

  // Tolak yang kedaluwarsa, supaya rekaman permintaan lama tidak bisa
  // diputar ulang oleh orang lain.
  const sekarang = Math.floor(Date.now() / 1000);
  if (Math.abs(sekarang - Number(cap)) > 300) return false;

  const enc = new TextEncoder();
  const kunci = await crypto.subtle.importKey(
    'raw',
    enc.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );
  const tanda = await crypto.subtle.sign('HMAC', kunci, enc.encode(`${cap}.${rawBody}`));
  const hex = [...new Uint8Array(tanda)]
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');

  return kunciSama(hex, diberi);
}

/**
 * Kirim email berisi voucher lewat Resend.
 * Selalu mengembalikan keterangan status (untuk dicatat), tidak pernah melempar.
 */
async function kirimEmailVoucher(env, o) {
  const kunci = String((env && env.RESEND_API_KEY) || '').trim();
  const dari = String((env && env.EMAIL_DARI) || '').trim();
  if (!kunci || !dari) return 'dilewati:email_belum_diatur';
  if (!o.email) return 'dilewati:tanpa_email';

  const isi = emailVoucher({
    namaPembeli: o.nama,
    kodeVoucher: o.voucher,
    namaAplikasi: String((env && env.APP_NAME) || 'TokoKu'),
    halamanUnduh: o.halamanUnduh,
    portal: o.portal,
  });

  try {
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${kunci}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: dari,
        to: [o.email],
        subject: isi.subject,
        html: isi.html,
        text: isi.text,
      }),
      // OrderHero menuntut jawaban dalam 10 detik, jadi jangan menggantung.
      signal: AbortSignal.timeout(6000),
    });
    if (!res.ok) {
      const pesan = (await res.text().catch(() => '')).slice(0, 140);
      return `gagal:${res.status}${pesan ? ' ' + pesan : ''}`;
    }
    return 'terkirim';
  } catch (e) {
    return `gagal:${String((e && e.message) || e).slice(0, 100)}`;
  }
}

/** Buat satu voucher lengkap dengan email pembeli. Null kalau gagal. */
async function buatSatuVoucher(env, batch, nama, email, orderRef) {
  const waktu = sekarangIso();
  for (let coba = 0; coba < 5; coba += 1) {
    const kode = kodeAcak(AWALAN_VOUCHER);
    try {
      await env.DB.prepare(
        'INSERT INTO vouchers ' +
          '(code, batch, customer_name, customer_email, order_ref, status, created_at) ' +
          "VALUES (?, ?, ?, ?, ?, 'unused', ?)"
      )
        .bind(kode, batch, nama, email, orderRef, waktu)
        .run();
      return kode;
    } catch (_) {
      // Bentrok kode (sangat jarang sekali) — coba kode lain.
    }
  }
  return null;
}

async function tanganiWebhookOrderHero(request, env) {
  const secret = String((env && env.ORDERHERO_WEBHOOK_SECRET) || '').trim();
  if (!secret) return balasJson({ ok: false, reason: 'not_configured' }, 500);

  // Tanda tangan dihitung atas badan permintaan APA ADANYA, jadi baca sebagai
  // teks mentah DULU. Kalau JSON di-parse lalu diserialisasi ulang, teksnya
  // berubah dan tanda tangannya tidak akan pernah cocok.
  const raw = await request.text();

  const sah = await tandaTanganSah(
    raw,
    request.headers.get('X-Webhook-Signature'),
    secret
  );
  if (!sah) return balasJson({ ok: false, reason: 'bad_signature' }, 401);

  let data;
  try {
    data = JSON.parse(raw);
  } catch (_) {
    return balasJson({ ok: false, reason: 'bad_json' }, 400);
  }

  const event = String((data && data.event) || request.headers.get('X-Webhook-Event') || '');
  const delivery = String(
    request.headers.get('X-Webhook-Delivery') || (data && data.delivery_id) || ''
  ).trim();
  const isi = (data && data.data) || {};

  const catat = async (status, kode, email, emailStatus, alasan) => {
    if (!delivery) return;
    try {
      await env.DB.prepare(
        'INSERT OR REPLACE INTO webhook_events ' +
          '(delivery_id, sumber, event, status, voucher_code, email, email_status, ' +
          'alasan, received_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)'
      )
        .bind(
          delivery,
          'orderhero',
          event,
          status,
          kode,
          email,
          emailStatus,
          alasan,
          sekarangIso()
        )
        .run();
    } catch (_) {
      // Pencatatan gagal tidak boleh menggagalkan pembuatan voucher.
    }
  };

  // Idempotensi: pengiriman ulang tidak boleh menghasilkan voucher kedua.
  if (delivery) {
    const sudah = await env.DB.prepare(
      'SELECT voucher_code FROM webhook_events WHERE delivery_id = ?'
    )
      .bind(delivery)
      .first();
    if (sudah) {
      return balasJson({ ok: true, duplikat: true, voucher: sudah.voucher_code ?? null });
    }
  }

  // Baru bertindak setelah pembayaran benar-benar masuk.
  if (event !== 'order_paid') {
    await catat('ignored', null, '', '', 'event ' + (event || '(kosong)') + ' diabaikan');
    return balasJson({ ok: true, diabaikan: true, event: event });
  }

  const email = String(isi.customer_email || '').trim().slice(0, 160);
  const nama = String(isi.customer_name || '').trim().slice(0, 80);
  const orderRef = String(isi.order_number || isi.order_id || '').trim().slice(0, 60);

  const kode = await buatSatuVoucher(env, (orderRef || 'PESANAN').slice(0, 40), nama, email, orderRef);
  if (!kode) {
    await catat('error', null, email, '', 'gagal membuat voucher');
    return balasJson({ ok: false, reason: 'server_error' }, 500);
  }

  const asal = new URL(request.url).origin;
  const emailStatus = await kirimEmailVoucher(env, {
    email: email,
    nama: nama,
    voucher: kode,
    halamanUnduh: asal + '/unduh',
    portal: asal,
  });

  await catat('processed', kode, email, emailStatus, '');
  return balasJson({ ok: true, voucher: kode, email: emailStatus });
}

/** Kirim ulang email voucher dari halaman admin (kalau email pertama gagal). */
async function tanganiKirimUlangEmail(request, env) {
  const body = (await bacaJson(request)) ?? {};
  const kode = normalisasi(body.code);
  if (!kode) return balasJson({ ok: false, reason: 'invalid_code' }, 400);

  const v = await env.DB.prepare(
    'SELECT code, customer_name, customer_email FROM vouchers WHERE code = ?'
  )
    .bind(kode)
    .first();
  if (!v) return balasJson({ ok: false, reason: 'not_found' }, 404);
  if (!v.customer_email) return balasJson({ ok: false, reason: 'tanpa_email' }, 400);

  const asal = new URL(request.url).origin;
  const status = await kirimEmailVoucher(env, {
    email: v.customer_email,
    nama: v.customer_name,
    voucher: v.code,
    halamanUnduh: asal + '/unduh',
    portal: asal,
  });

  try {
    await env.DB.prepare('UPDATE webhook_events SET email_status = ? WHERE voucher_code = ?')
      .bind(status, v.code)
      .run();
  } catch (_) {
    // Bukan hal fatal — voucher tetap ada.
  }

  return balasJson({ ok: status === 'terkirim', status: status });
}

// ---------------------------------------------------------------------------
// Pembaruan aplikasi — pelanggan tidak pernah menyentuh GitHub
// ---------------------------------------------------------------------------
//
// Aplikasi memanggil dua alamat di bawah ini, BUKAN GitHub langsung:
//
//   GET /api/versi   → nomor versi terbaru + alamat unduhnya
//   GET /unduh/apk   → file APK-nya (dialirkan Worker dari rilis GitHub)
//   GET /unduh       → halaman unduh yang bisa dibagikan ke pelanggan
//
// Karena semuanya lewat sini, akun GitHub penjual tidak pernah muncul di HP
// pelanggan — yang mereka lihat hanya alamat Worker ini.

/** Repo GitHub tempat rilis APK disimpan. Hanya ada di sisi server. */
function repoGithub(env) {
  return String((env && env.GITHUB_REPO) || '').trim();
}

/**
 * Ambil info rilis terbaru dari GitHub.
 *
 * Di-cache di edge Cloudflare selama 10 menit: batas GitHub untuk permintaan
 * tanpa token hanya 60 per jam per alamat IP, dan IP Worker dipakai bersama.
 * Tanpa cache, cek pembaruan bisa gagal begitu banyak pelanggan membukanya.
 */
async function ambilRilisTerbaru(env) {
  const repo = repoGithub(env);
  if (!repo) return null;

  const res = await fetch(
    `https://api.github.com/repos/${repo}/releases/latest`,
    {
      headers: {
        Accept: 'application/vnd.github+json',
        'User-Agent': 'tokoku-lisensi-worker',
      },
      cf: { cacheTtl: 600, cacheEverything: true },
    }
  );
  if (!res.ok) return null;

  let data;
  try {
    data = await res.json();
  } catch (_) {
    return null;
  }
  if (!data || typeof data !== 'object') return null;

  const versi = String(data.tag_name ?? '')
    .replace(/^v/, '')
    .trim();
  if (!versi) return null;

  let ukuran = 0;
  const aset = Array.isArray(data.assets) ? data.assets : [];
  for (const a of aset) {
    if (a && typeof a.name === 'string' && a.name.toLowerCase().endsWith('.apk')) {
      ukuran = Number(a.size) || 0;
      break;
    }
  }

  return {
    versi,
    ukuran,
    catatan: String(data.body ?? '').slice(0, 2000),
    diterbitkan: String(data.published_at ?? ''),
  };
}

/** GET /api/versi — dipakai aplikasi untuk memeriksa pembaruan. */
async function tanganiVersi(env, url) {
  const rilis = await ambilRilisTerbaru(env);
  if (!rilis) return balasJson({ ok: false, reason: 'tidak_ada_rilis' });

  return balasJson({
    ok: true,
    versi: rilis.versi,
    ukuran: rilis.ukuran,
    catatan: rilis.catatan,
    diterbitkan: rilis.diterbitkan,
    unduh: new URL('/unduh/apk', url.origin).toString(),
    halaman: new URL('/unduh', url.origin).toString(),
  });
}

/**
 * GET /unduh/apk — alirkan file APK dari rilis GitHub.
 *
 * Badan respons dialirkan apa adanya (tidak ditahan di memori), jadi file
 * berukuran puluhan MB tidak membebani Worker.
 */
async function tanganiUnduhApk(env, request) {
  const repo = repoGithub(env);
  if (!repo) return balasJson({ ok: false, reason: 'server_error' }, 500);

  // Teruskan Range kalau ada. Tanpa ini, unduhan 34 MB yang terputus di
  // jaringan seluler akan mengulang dari nol, bukan melanjutkan.
  const mintaRange = request ? request.headers.get('range') : null;
  const headerPermintaan = { 'User-Agent': 'tokoku-lisensi-worker' };
  if (mintaRange) headerPermintaan['Range'] = mintaRange;

  const res = await fetch(
    `https://github.com/${repo}/releases/latest/download/app-release.apk`,
    { headers: headerPermintaan, redirect: 'follow' }
  );

  // 206 = potongan isi (unduhan dilanjutkan). Selain 200/206 berarti gagal.
  const potongan = res.status === 206;
  if (!res.ok || !res.body) {
    return balasHtml(halamanUnduhGagal(env), 502);
  }

  const rilis = await ambilRilisTerbaru(env);
  const namaBerkas = rilis && rilis.versi ? `TokoKu-${rilis.versi}.apk` : 'TokoKu.apk';

  const header = {
    'Content-Type': 'application/vnd.android.package-archive',
    'Content-Disposition': `attachment; filename="${namaBerkas}"`,
    'Cache-Control': 'public, max-age=3600',
    'X-Content-Type-Options': 'nosniff',
    'Accept-Ranges': 'bytes',
  };

  // Panjang isi diteruskan kalau memang ada, supaya Android bisa menampilkan
  // progres unduhan. Kalau kosong, biarkan runtime yang mengurus.
  const panjang = res.headers.get('content-length');
  if (panjang && /^\d+$/.test(panjang)) header['Content-Length'] = panjang;

  const rentang = res.headers.get('content-range');
  if (potongan && rentang) header['Content-Range'] = rentang;

  // HEAD: header saja, tanpa badan. Dipakai pemeriksa tautan dan pengelola
  // unduhan Android untuk tahu ukuran sebelum benar-benar mengunduh.
  const kepala = request && request.method.toUpperCase() === 'HEAD';
  const status = potongan ? 206 : 200;

  return new Response(kepala ? null : res.body, { status, headers: header });
}

// ---------------------------------------------------------------------------
// Perutean
// ---------------------------------------------------------------------------

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const jalur = url.pathname.replace(/\/+$/, '') || '/';
    const metode = request.method.toUpperCase();

    if (metode === 'OPTIONS') {
      return new Response(null, { status: 204, headers: HEADER_CORS });
    }

    try {
      // --- publik -------------------------------------------------------
      if (jalur === '/' && metode === 'GET') {
        return balasHtml(halamanPortal(env));
      }

      if (jalur === '/api/aktivasi' && metode === 'POST') {
        return await tanganiAktivasi(request, env);
      }

      // Pesanan dari platform jualan (OrderHero). Diverifikasi dengan
      // tanda tangan, jadi endpoint ini boleh publik.
      if (jalur === '/webhook/orderhero' && metode === 'POST') {
        return await tanganiWebhookOrderHero(request, env);
      }

      // Pembaruan aplikasi — pengganti tautan GitHub supaya akun GitHub
      // penjual tidak terlihat pelanggan.
      if (jalur === '/api/versi' && metode === 'GET') {
        return await tanganiVersi(env, url);
      }

      if (jalur === '/unduh/apk' && (metode === 'GET' || metode === 'HEAD')) {
        return await tanganiUnduhApk(env, request);
      }

      if (jalur === '/unduh' && metode === 'GET') {
        const rilis = await ambilRilisTerbaru(env);
        return balasHtml(halamanUnduh(env, rilis));
      }

      if (jalur === '/health' && metode === 'GET') {
        const cek = await env.DB.prepare(
          'SELECT count(*) as jumlah from licenses'
        ).first();
        return balasJson({ ok: true, lisensi: cek?.jumlah ?? 0 });
      }

      // --- admin --------------------------------------------------------
      if (jalur === '/admin' && metode === 'GET') {
        return balasHtml(halamanAdmin(env));
      }

      if (jalur.startsWith('/admin/')) {
        if (!adminSah(request, env)) {
          return balasJson({ ok: false, reason: 'unauthorized' }, 401);
        }
        if (jalur === '/admin/data' && metode === 'GET') {
          return await tanganiDataAdmin(env);
        }
        if (jalur === '/admin/vouchers' && metode === 'POST') {
          return await tanganiBuatVoucher(request, env);
        }

        if (jalur === '/admin/kirim-email' && metode === 'POST') {
          return await tanganiKirimUlangEmail(request, env);
        }
        if (jalur === '/admin/reset' && metode === 'POST') {
          return await tanganiLepasPerangkat(request, env);
        }
        if (jalur === '/admin/revoke' && metode === 'POST') {
          return await tanganiNonaktifkan(request, env);
        }
        return balasJson({ ok: false, reason: 'not_found' }, 404);
      }

      return balasJson({ ok: false, reason: 'not_found' }, 404);
    } catch (err) {
      // Jangan bocorkan detail internal ke pelanggan.
      console.error('galat server:', err && err.stack ? err.stack : err);
      return balasJson({ ok: false, reason: 'server_error' }, 500);
    }
  },
};
