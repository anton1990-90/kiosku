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
 */

import { halamanPortal } from './halaman-portal.js';
import { halamanAdmin } from './halaman-admin.js';

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
    'SELECT code, batch, customer_name, status, license_code, created_at, used_at ' +
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

  return balasJson({
    ok: true,
    ringkas: ringkas ?? {},
    vouchers: vouchers.results ?? [],
    licenses: licenses.results ?? [],
  });
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
