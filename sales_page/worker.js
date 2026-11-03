/**
 * Worker halaman penjualan TokoKu (tokoku.kibo.ai.id).
 *
 * Alur pembelian:
 *   halaman -> POST /api/checkout -> DOKU Checkout (/checkout/v1/payment)
 *           -> pembeli memilih metode & bayar di halaman DOKU
 *           -> DOKU kirim notifikasi -> voucher dibuat -> email dikirim (Resend)
 *
 * Gateway: **DOKU** (Jokul Checkout). Pakasir sudah tidak dipakai.
 *
 * Dua jalur menuju fungsi yang SAMA (lunasiPesanan), supaya tidak mungkin ada
 * versi kode berbeda antara "lewat notifikasi" dan "lewat pengecekan status":
 *   1. POST /api/doku-notification  (jalur utama, seketika)
 *   2. GET  /api/check-payment     (jaring pengaman kalau notifikasi hilang)
 */

/** Harga lisensi. Dikunci di server, tidak pernah diambil dari peramban. */
const HARGA = 99000;

/** Alamat halaman unduh yang dipakai di dalam email. */
const HALAMAN_UNDUH = "https://tokoku.kibo.ai.id/unduh";

/** Halaman yang dibuka lagi setelah pembeli selesai di DOKU. */
const HALAMAN_KEMBALI = "https://tokoku.kibo.ai.id/download";

/** Portal aktivasi yang dipakai di dalam email. */
const PORTAL_AKTIVASI = "https://lisensi.kibo.ai.id";

/** Path endpoint notifikasi — dipakai juga sebagai Request-Target tanda tangan. */
const PATH_NOTIFIKASI = "/api/doku-notification";

function aman(teks, cadangan) {
  const nilai = String(teks ?? '').trim();
  const dipakai = nilai === '' ? cadangan : nilai;
  return dipakai
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/** "3 November 2026, 09.54 WIB" — waktu Jakarta, bukan waktu server. */
function waktuIndonesia(iso) {
  const waktu = iso ? new Date(iso) : new Date();
  if (Number.isNaN(waktu.getTime())) return '';
  try {
    return new Intl.DateTimeFormat('id-ID', {
      timeZone: 'Asia/Jakarta',
      day: 'numeric',
      month: 'long',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      hour12: false,
    }).format(waktu) + ' WIB';
  } catch (_) {
    return waktu.toISOString().slice(0, 16).replace('T', ' ') + ' UTC';
  }
}

function rupiah(nilai) {
  const angka = Number(nilai);
  if (!Number.isFinite(angka)) return '';
  return 'Rp ' + angka.toLocaleString('id-ID');
}

/**
 * Nama metode yang enak dibaca dari id channel DOKU.
 * Contoh: "VIRTUAL_ACCOUNT_BRI" -> "Virtual Account BRI", "QRIS" -> "QRIS".
 */
function namaMetode(metode) {
  const teks = String(metode || '').trim();
  if (!teks) return 'DOKU';
  if (/^qris$/i.test(teks)) return 'QRIS';
  if (/^virtual_account_/i.test(teks)) {
    return 'Virtual Account ' + teks.replace(/^virtual_account_/i, '').replace(/_/g, ' ');
  }
  if (/^emoney_/i.test(teks)) return teks.replace(/^emoney_/i, '').toUpperCase();
  return teks.replace(/_/g, ' ');
}

/**
 * Isi email yang dikirim ke pelanggan setelah pembayaran terkonfirmasi.
 *
 * Ditulis dengan gaya surat biasa (bukan halaman web): memakai tabel dan
 * gaya sebaris, karena banyak aplikasi email membuang <style> di <head>.
 *
 * PENTING: jangan pernah mencantumkan tautan GitHub di sini. Semua tautan
 * harus menunjuk ke server aktivasi sendiri, supaya akun GitHub penjual
 * tidak terlihat pelanggan.
 */
function emailVoucher(o) {
  const namaAplikasi = aman(o && o.namaAplikasi, 'TokoKu');
  const kode = aman(o && o.kodeVoucher, '');
  const halamanUnduh = String((o && o.halamanUnduh) || '').trim();
  const portal = String((o && o.portal) || '').trim();

  const nama = String((o && o.namaPembeli) || '').trim();
  const sapaan = nama === '' ? 'Halo' : `Halo ${nama}`;

  // Rincian pembayaran: pembeli sering membuka email ini untuk memastikan
  // nominal dan nomor pesanannya, bukan hanya untuk mengambil kode.
  const nomorPesanan = String((o && o.nomorPesanan) || '').trim();
  const jumlah = rupiah(o && o.jumlah);
  const waktu = String((o && o.waktu) || '').trim();
  const metode = String((o && o.metode) || 'DOKU').trim();

  const subject = `Kode Aktivasi ${namaAplikasi} Anda — ${kode}`;

  const teks = [
    `${sapaan},`,
    '',
    `Terima kasih sudah membeli ${namaAplikasi}.`,
    'Pembayaran Anda sudah kami terima.',
    '',
    ...(nomorPesanan ? [`Nomor pesanan : ${nomorPesanan}`] : []),
    ...(waktu ? [`Waktu bayar   : ${waktu}`] : []),
    ...(jumlah ? [`Jumlah        : ${jumlah}`] : []),
    `Metode        : ${metode}`,
    '',
    `KODE VOUCHER ANDA: ${kode}`,
    '',
    'Cara pakai:',
    `1. Unduh aplikasinya di ${halamanUnduh}`,
    '2. Pasang di HP Android Anda',
    `3. Buka aplikasi, lalu buka ${portal}`,
    '4. Masukkan Kode Perangkat dari aplikasi dan Kode Voucher di atas',
    '5. Kode Aktivasi yang muncul, tempel di aplikasi lalu tekan Aktivasi',
    '',
    'Setelah aktif, aplikasi bisa dipakai tanpa internet.',
    '',
    'Simpan email ini. Kode voucher hanya berlaku untuk satu HP.',
  ].join('\n');

  const baris = (nomor, isi) =>
    '<tr>' +
    '<td style="padding:0 10px 8px 0;vertical-align:top;font-size:14px;line-height:22px;color:#0F6E56;font-weight:bold;width:16px">' +
    nomor +
    '</td>' +
    '<td style="padding:0 0 8px 0;font-size:14px;line-height:22px;color:#3F3F46">' +
    isi +
    '</td>' +
    '</tr>';

  const rincianBaris = (label, isi) =>
    '<tr>' +
    '<td style="padding:3px 0;font-size:12px;line-height:19px;color:#71717A;white-space:nowrap">' +
    label +
    '</td>' +
    '<td style="padding:3px 0 3px 12px;font-size:12px;line-height:19px;color:#1A1A2E;font-weight:bold;text-align:right">' +
    isi +
    '</td>' +
    '</tr>';

  const rincian =
    nomorPesanan || jumlah || waktu
      ? '<div style="background:#F6F7F9;border-radius:10px;padding:12px 14px;margin:0 0 18px 0">' +
        '<p style="margin:0 0 6px 0;font-size:12px;font-weight:bold;color:#1A1A2E">Rincian pembayaran</p>' +
        '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">' +
        (nomorPesanan ? rincianBaris('Nomor pesanan', aman(nomorPesanan, '')) : '') +
        (waktu ? rincianBaris('Waktu bayar', aman(waktu, '')) : '') +
        rincianBaris('Metode', aman(metode, 'DOKU')) +
        (jumlah ? rincianBaris('Jumlah', aman(jumlah, '')) : '') +
        '</table>' +
        '</div>'
      : '';

  const html =
    '<!DOCTYPE html><html lang="id"><head><meta charset="utf-8">' +
    '<meta name="viewport" content="width=device-width, initial-scale=1">' +
    `<title>${subject}</title></head>` +
    '<body style="margin:0;padding:0;background:#F4F5F7">' +
    '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#F4F5F7">' +
    '<tr><td align="center" style="padding:24px 12px">' +
    '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" ' +
    'style="max-width:520px;background:#ffffff;border-radius:14px;overflow:hidden">' +

    '<tr><td style="background:#0F6E56;padding:26px 24px">' +
    `<div style="font-family:Arial,Helvetica,sans-serif;font-size:19px;font-weight:bold;color:#ffffff;letter-spacing:-0.3px">${namaAplikasi}</div>` +
    '<div style="font-family:Arial,Helvetica,sans-serif;font-size:13px;color:#CFEAE0;padding-top:4px">Aplikasi kasir untuk toko Anda</div>' +
    '</td></tr>' +

    '<tr><td style="padding:24px 24px 8px 24px;font-family:Arial,Helvetica,sans-serif">' +
    `<p style="margin:0 0 14px 0;font-size:15px;line-height:24px;color:#1A1A2E">${sapaan}, terima kasih sudah membeli <b>${namaAplikasi}</b>. Pembayaran Anda sudah kami terima.</p>` +
    '<p style="margin:0 0 8px 0;font-size:13px;line-height:20px;color:#71717A">Kode Voucher Anda:</p>' +
    '<div style="background:#E1F5EE;border:1.5px solid #1D9E75;border-radius:12px;padding:16px 12px;text-align:center">' +
    `<div style="font-family:'Courier New',Courier,monospace;font-size:22px;font-weight:bold;color:#085041;letter-spacing:2px;word-break:break-all">${kode}</div>` +
    '</div>' +
    '<p style="margin:12px 0 20px 0;font-size:12px;line-height:19px;color:#71717A">Satu kode berlaku untuk satu HP. Simpan email ini.</p>' +

    rincian +

    '<div style="border-top:1px solid #E8E9EB;padding-top:18px">' +
    '<p style="margin:0 0 10px 0;font-size:14px;font-weight:bold;color:#1A1A2E">Cara pakai</p>' +
    '<table role="presentation" cellpadding="0" cellspacing="0" border="0">' +
    baris('1', `Unduh aplikasinya di <a href="${aman(halamanUnduh, '#')}" style="color:#0F6E56;font-weight:bold">halaman unduh</a>` +
      (halamanUnduh === '' ? ' (hubungi penjual)' : '')) +
    baris('2', 'Pasang di HP Android Anda') +
    baris('3', `Buka <a href="${aman(portal, '#')}" style="color:#0F6E56;font-weight:bold">portal aktivasi</a>, lalu masukkan <b>Kode Perangkat</b> dari aplikasi dan <b>Kode Voucher</b> di atas`) +
    baris('4', 'Kode Aktivasi yang muncul, tempel di aplikasi lalu tekan tombol <b>Aktivasi</b>') +
    '</table>' +
    '</div>' +

    '<div style="background:#FAEEDA;border-radius:10px;padding:12px 14px;margin-top:14px">' +
    '<p style="margin:0;font-size:12px;line-height:19px;color:#854F0B"><b>Perlu internet sekali saja.</b> Setelah aktif, aplikasi bisa dipakai tanpa internet untuk kegiatan sehari-hari.</p>' +
    '</div>' +
    '</td></tr>' +

    '<tr><td style="padding:18px 24px 24px 24px;font-family:Helvetica,Arial,sans-serif">' +
    '<p style="margin:0;font-size:12px;line-height:19px;color:#9CA3AF">Email ini dikirim otomatis setelah pembayaran Anda terkonfirmasi. Kalau kode di atas tidak bisa dipakai, balas email ini.</p>' +
    '</td></tr>' +
    '</table></td></tr></table></body></html>';

  return { subject, html, text: teks };
}

// ---------------------------------------------------------------------------
// Tanda tangan DOKU (Non-SNAP)
// ---------------------------------------------------------------------------
//
// stringToSign = baris berikut digabung "\n" TANPA newline di akhir:
//   Client-Id:{clientId}
//   Request-Id:{requestId}
//   Request-Timestamp:{timestamp}   ISO8601 UTC, TANPA milidetik
//   Request-Target:{path}
//   Digest:{base64(sha256(body))}   HANYA untuk request ber-body
// Signature = "HMACSHA256=" + base64(HMAC-SHA256(stringToSign, secretKey))
//
// Tiga jebakan: Digest base64 POLOS (tanpa prefiks "SHA-256="), GET tidak
// memuat baris Digest, dan timestamp bermilidetik ditolak DOKU.

const B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

function keBase64(bytes) {
  let keluaran = "";
  for (let i = 0; i < bytes.length; i += 3) {
    const b0 = bytes[i];
    const b1 = i + 1 < bytes.length ? bytes[i + 1] : 0;
    const b2 = i + 2 < bytes.length ? bytes[i + 2] : 0;
    keluaran += B64[b0 >> 2];
    keluaran += B64[((b0 & 0x03) << 4) | (b1 >> 4)];
    keluaran += i + 1 < bytes.length ? B64[((b1 & 0x0f) << 2) | (b2 >> 6)] : "=";
    keluaran += i + 2 < bytes.length ? B64[b2 & 0x3f] : "=";
  }
  return keluaran;
}

async function sha256Base64(teks) {
  const hash = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(teks));
  return keBase64(new Uint8Array(hash));
}

async function hmacSha256Base64(pesan, kunci) {
  const enc = new TextEncoder();
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    enc.encode(kunci),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const tanda = await crypto.subtle.sign("HMAC", cryptoKey, enc.encode(pesan));
  return keBase64(new Uint8Array(tanda));
}

/** ISO8601 UTC tanpa milidetik — DOKU menolak yang bermilidetik. */
function capWaktuDoku() {
  return new Date().toISOString().replace(/\.\d+Z$/, "Z");
}

async function tandaTanganDoku(env, o) {
  const baris = [
    `Client-Id:${String(env.DOKU_CLIENT_ID || "").trim()}`,
    `Request-Id:${o.requestId}`,
    `Request-Timestamp:${o.timestamp}`,
    `Request-Target:${o.target}`,
  ];
  if (o.rawBody !== undefined) {
    baris.push(`Digest:${await sha256Base64(o.rawBody)}`);
  }
  const hmac = await hmacSha256Base64(baris.join("\n"), String(env.DOKU_SECRET_KEY || "").trim());
  return `HMACSHA256=${hmac}`;
}

/** Header bertanda tangan untuk request keluar ke DOKU. */
async function headerDoku(env, o) {
  const requestId = crypto.randomUUID();
  const timestamp = capWaktuDoku();
  const signature = await tandaTanganDoku(env, {
    requestId,
    timestamp,
    target: o.target,
    rawBody: o.rawBody,
  });
  return {
    "Content-Type": "application/json",
    "Client-Id": String(env.DOKU_CLIENT_ID || "").trim(),
    "Request-Id": requestId,
    "Request-Timestamp": timestamp,
    Signature: signature,
  };
}

function dasarDoku(env) {
  return String(env.DOKU_API_BASE_URL || "https://api.doku.com").replace(/\/$/, "");
}

// ---------------------------------------------------------------------------
// Pembantu umum
// ---------------------------------------------------------------------------

/** Perbandingan yang tidak membocorkan panjang/isi lewat waktu balasan. */
function rahasiaSama(a, b) {
  const kiri = String(a || "");
  const kanan = String(b || "");
  if (kanan === "" || kiri.length !== kanan.length) return false;
  let beda = 0;
  for (let i = 0; i < kanan.length; i += 1) {
    beda |= kiri.charCodeAt(i) ^ kanan.charCodeAt(i);
  }
  return beda === 0;
}

function kodeVoucherBaru() {
  const charset = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const bytes = new Uint8Array(12);
  crypto.getRandomValues(bytes);
  let mentah = "";
  for (let i = 0; i < 12; i += 1) {
    mentah += charset[bytes[i] % charset.length];
  }
  return `VC-${mentah.slice(0, 4)}-${mentah.slice(4, 8)}-${mentah.slice(8, 12)}`;
}

function tidur(ms) {
  return new Promise((selesai) => setTimeout(selesai, ms));
}

function balasJson(isi, status = 200) {
  return new Response(JSON.stringify(isi), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

/**
 * Catat kejadian webhook TANPA merusak catatan email yang sudah ada.
 *
 * delivery_id adalah kunci utama, dan DOKU bisa mengirim notifikasi yang sama
 * lebih dari sekali. INSERT OR REPLACE polos MENIMPA kolom email_status pada
 * baris yang sama, sehingga pemeriksaan "sudah pernah dikirim?" membaca string
 * kosong dan pelanggan menerima email kedua. Karena itu kejadian biasa hanya
 * memperbarui status/alasan; kolom email hanya ditulis catatHasilEmail.
 */
async function catatKejadian(env, o) {
  try {
    await env.DB.prepare(
      "INSERT INTO webhook_events " +
        "(delivery_id, sumber, event, status, voucher_code, email, email_status, alasan, received_at) " +
        "VALUES (?, ?, ?, ?, NULL, '', '', ?, ?) " +
        "ON CONFLICT(delivery_id) DO UPDATE SET " +
        "sumber = excluded.sumber, event = excluded.event, " +
        // Jangan turunkan status akhir ("processed"/"error") menjadi status
        // notifikasi mentah saat DOKU mengirim ulang.
        "status = CASE WHEN webhook_events.status IN ('processed', 'error') " +
        "THEN webhook_events.status ELSE excluded.status END, " +
        "alasan = excluded.alasan, received_at = excluded.received_at"
    )
      .bind(
        String(o.delivery || "tanpa-id").slice(0, 120),
        String(o.sumber || "doku").slice(0, 20),
        String(o.event || "notifikasi").slice(0, 40),
        String(o.status || "").slice(0, 40),
        String(o.alasan || "").slice(0, 300),
        new Date().toISOString()
      )
      .run();
  } catch (_) {
    // Pencatatan tidak boleh menggagalkan penerbitan lisensi.
  }
}

/** Catat hasil pengiriman email (satu-satunya penulis kolom email/voucher). */
async function catatHasilEmail(env, o) {
  try {
    await env.DB.prepare(
      "INSERT INTO webhook_events " +
        "(delivery_id, sumber, event, status, voucher_code, email, email_status, alasan, received_at) " +
        "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) " +
        "ON CONFLICT(delivery_id) DO UPDATE SET " +
        "sumber = excluded.sumber, event = excluded.event, status = excluded.status, " +
        "voucher_code = excluded.voucher_code, email = excluded.email, " +
        "email_status = excluded.email_status, alasan = excluded.alasan, " +
        "received_at = excluded.received_at"
    )
      .bind(
        String(o.delivery || "tanpa-id").slice(0, 120),
        String(o.sumber || "doku").slice(0, 20),
        String(o.event || "pembayaran").slice(0, 40),
        String(o.status || "").slice(0, 40),
        o.voucher ? String(o.voucher).slice(0, 40) : null,
        String(o.email || "").slice(0, 160),
        String(o.emailStatus || "").slice(0, 200),
        String(o.alasan || "").slice(0, 300),
        new Date().toISOString()
      )
      .run();
  } catch (_) {
    // Pencatatan tidak boleh menggagalkan penerbitan lisensi.
  }
}

/**
 * Kirim email voucher lewat Resend.
 *
 * Mengembalikan keterangan status yang bisa dibaca manusia, mis.
 * "terkirim:01a1..." atau "gagal:422 domain belum terverifikasi".
 * Tidak pernah melempar, supaya voucher yang sudah dibuat tidak hilang
 * gara-gara email gagal.
 */
async function kirimEmail(env, o) {
  const kunci = String((env && env.RESEND_API_KEY) || "").trim();
  if (!kunci) return "dilewati:kunci_resend_belum_diatur";
  if (!o.email) return "dilewati:tanpa_email";

  const isi = emailVoucher({
    namaPembeli: o.nama,
    kodeVoucher: o.voucher,
    namaAplikasi: "TokoKu",
    halamanUnduh: HALAMAN_UNDUH,
    portal: PORTAL_AKTIVASI,
    nomorPesanan: o.nomorPesanan,
    jumlah: o.jumlah,
    waktu: o.waktu,
    metode: o.metode,
  });

  let terakhir = "";
  for (let coba = 1; coba <= 3; coba += 1) {
    try {
      const res = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${kunci}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: "TokoKu Support <support@kibo.ai.id>",
          to: [o.email],
          subject: isi.subject,
          html: isi.html,
          text: isi.text,
        }),
        signal: AbortSignal.timeout(10000),
      });

      if (res.ok) {
        const data = await res.json().catch(() => ({}));
        return `terkirim:${String(data.id || "").slice(0, 40)}`;
      }

      const pesan = (await res.text().catch(() => "")).slice(0, 140);
      terakhir = `${res.status} ${pesan}`.trim();

      // 429 / 5xx pantas dicoba lagi; 4xx lain (mis. email tidak valid)
      // tidak akan berubah hasilnya walau diulang.
      if (res.status === 429 || res.status >= 500) {
        await tidur(700 * coba);
        continue;
      }
      return `gagal:${terakhir}`;
    } catch (e) {
      terakhir = String((e && e.message) || e).slice(0, 120);
      await tidur(700 * coba);
    }
  }
  return `gagal:${terakhir || "tidak diketahui"}`;
}

/** Status email terakhir untuk satu kode voucher. */
async function statusEmailVoucher(env, kode) {
  try {
    const r = await env.DB.prepare(
      "SELECT email_status FROM webhook_events WHERE voucher_code = ? ORDER BY received_at DESC LIMIT 1"
    )
      .bind(kode)
      .first();
    return r ? String(r.email_status || "") : "";
  } catch (_) {
    return "";
  }
}

/**
 * Terbitkan voucher untuk pesanan yang sudah dibayar, lalu kirim emailnya.
 *
 * Aman dipanggil berkali-kali (notifikasi, pengecekan status, atau keduanya
 * bersamaan): peralihan status dikunci oleh
 * "UPDATE ... WHERE status = 'pending'", jadi hanya satu pemanggil yang
 * benar-benar membuat kode baru. Pemanggil berikutnya hanya mengirim ulang
 * email kalau email sebelumnya gagal.
 */
async function lunasiPesanan(env, orderRef, txnId, info) {
  const pesanan = await env.DB.prepare(
    "SELECT code, customer_name, customer_email, status, created_at FROM vouchers WHERE order_ref = ?"
  )
    .bind(orderRef)
    .first();

  if (!pesanan) return { ok: false, alasan: "pesanan_tidak_ditemukan" };

  let kode = String(pesanan.code || "");

  if (pesanan.status === "pending") {
    const kodeBaru = kodeVoucherBaru();
    const ubah = await env.DB.prepare(
      "UPDATE vouchers SET code = ?, status = 'unused', txn_id = ? " +
        "WHERE order_ref = ? AND status = 'pending'"
    )
      .bind(kodeBaru, String(txnId || "").slice(0, 60), orderRef)
      .run();

    const terpakai = ubah && ubah.meta ? Number(ubah.meta.changes || 0) : 0;
    if (terpakai > 0) {
      kode = kodeBaru;
    } else {
      // Balapan: permintaan lain sudah melunasi pesanan ini lebih dulu.
      const lagi = await env.DB.prepare(
        "SELECT code FROM vouchers WHERE order_ref = ?"
      )
        .bind(orderRef)
        .first();
      kode = lagi ? String(lagi.code || "") : "";
    }
  }

  if (!kode || kode.startsWith("INV-")) {
    return { ok: false, alasan: "voucher_gagal_dibuat" };
  }

  // Sudah pernah terkirim? Jangan kirim dua kali ke pelanggan yang sama.
  const sebelumnya = await statusEmailVoucher(env, kode);
  if (sebelumnya.startsWith("terkirim")) {
    return { ok: true, kode, email: sebelumnya, sudah: true };
  }

  const email = String(pesanan.customer_email || "").trim();
  const hasil = await kirimEmail(env, {
    email,
    nama: pesanan.customer_name,
    voucher: kode,
    nomorPesanan: orderRef,
    jumlah: (info && info.jumlah) || HARGA,
    waktu: waktuIndonesia((info && info.waktu) || pesanan.created_at),
    metode: (info && info.metode) || "DOKU",
  });

  await catatHasilEmail(env, {
    delivery: txnId || orderRef,
    sumber: "doku",
    event: "pembayaran",
    status: hasil.startsWith("terkirim") ? "processed" : "error",
    voucher: kode,
    email,
    emailStatus: hasil,
    alasan: hasil.startsWith("terkirim") ? "" : "email tidak terkirim",
  });

  return { ok: hasil.startsWith("terkirim"), kode, email: hasil };
}

// ---------------------------------------------------------------------------
// DOKU — buat pembayaran & cek status
// ---------------------------------------------------------------------------

/** true kalau kredensial DOKU tersedia di worker. */
function dokuSiap(env) {
  return Boolean(String(env.DOKU_CLIENT_ID || "").trim() && String(env.DOKU_SECRET_KEY || "").trim());
}

/**
 * Buat pembayaran lewat DOKU Checkout.
 *
 * Channel sengaja TIDAK dibatasi (`payment_method_types` tidak dikirim):
 * daftar channel aktif berbeda tiap akun dan bisa berubah dari Back Office,
 * sedangkan channel yang tidak aktif ditolak DOKU dengan
 * "PAYMENT CHANNEL IS INACTIVE". Dengan cara ini DOKU menampilkan semua
 * metode yang benar-benar aktif (QRIS, VA, e-wallet) dan pembeli memilih.
 */
async function buatPembayaranDoku(env, o) {
  if (!dokuSiap(env)) return { error: "doku_belum_diatur" };

  const body = {
    order: {
      amount: HARGA,
      invoice_number: o.invoice,
      currency: "IDR",
      callback_url: HALAMAN_KEMBALI,
      callback_url_result: HALAMAN_KEMBALI,
      auto_redirect: true,
      language: "ID",
    },
    payment: { payment_due_date: 1440, type: "SALE" },
    customer: { name: o.nama, email: o.email },
    additional_info: { override_notification_url: o.notifikasiUrl },
  };

  const rawBody = JSON.stringify(body);
  try {
    const res = await fetch(`${dasarDoku(env)}/checkout/v1/payment`, {
      method: "POST",
      headers: await headerDoku(env, { target: "/checkout/v1/payment", rawBody }),
      body: rawBody,
      signal: AbortSignal.timeout(25000),
    });

    const data = await res.json().catch(() => null);
    const pesan = Array.isArray(data && data.message)
      ? data.message.join(", ")
      : (data && data.message) || "";

    if (!res.ok || !data) {
      return { error: pesan || `doku_http_${res.status}` };
    }

    const pembayaran = (data.response && data.response.payment) || {};
    const url = String(pembayaran.url || "");
    if (!url) return { error: pesan || "doku_tanpa_url" };

    return {
      url,
      tokenId: String(pembayaran.token_id || ""),
      invoice: String((data.response && data.response.order && data.response.order.invoice_number) || o.invoice),
    };
  } catch (e) {
    return { error: String((e && e.message) || e).slice(0, 140) };
  }
}

/**
 * Status transaksi menurut DOKU: "SUCCESS" | "PENDING" | "FAILED".
 * Kosong kalau tidak bisa dibaca (jangan dianggap lunas).
 */
async function statusDoku(env, invoice) {
  if (!dokuSiap(env) || !invoice) return "";
  const target = `/orders/v1/status/${encodeURIComponent(invoice)}`;
  try {
    const res = await fetch(`${dasarDoku(env)}${target}`, {
      method: "GET",
      headers: await headerDoku(env, { target }),
      signal: AbortSignal.timeout(10000),
    });
    if (!res.ok) return "";
    const data = await res.json().catch(() => null);
    const isi = (data && data.response) || data || {};
    return String((isi.transaction && isi.transaction.status) || "").toUpperCase();
  } catch (_) {
    return "";
  }
}

/**
 * Verifikasi tanda tangan notifikasi DOKU.
 *
 * `Request-Target` yang ditandatangani DOKU adalah PATH dari URL notifikasi
 * yang terdaftar. Kalau header itu tidak ada (atau isinya berbeda karena URL
 * didaftarkan dengan cara lain), path tetap dicoba — tanpa mengorbankan
 * keamanan, karena tanda tangan tetap harus cocok untuk salah satu path itu.
 */
async function notifikasiDokuSah(env, request, rawBody) {
  if (!dokuSiap(env)) return false;

  const clientId = request.headers.get("Client-Id") || "";
  const requestId = request.headers.get("Request-Id") || "";
  const timestamp = request.headers.get("Request-Timestamp") || "";
  const signature = request.headers.get("Signature") || "";

  if (!requestId || !timestamp || !signature) return false;
  // Client-Id bukan rahasia, tapi kalau tidak cocok pesannya bukan untuk kita.
  if (clientId && !rahasiaSama(clientId, String(env.DOKU_CLIENT_ID || "").trim())) return false;

  const kandidat = [];
  const dariHeader = request.headers.get("Request-Target") || "";
  if (dariHeader) kandidat.push(dariHeader);
  kandidat.push(PATH_NOTIFIKASI);
  try {
    const jalur = new URL(request.url).pathname;
    if (jalur) kandidat.push(jalur);
  } catch (_) {}

  for (const target of [...new Set(kandidat)]) {
    const diharapkan = await tandaTanganDoku(env, {
      requestId,
      timestamp,
      target,
      rawBody,
    });
    if (rahasiaSama(diharapkan, signature)) return true;
  }
  return false;
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // 1. BUAT PEMBAYARAN DARI HALAMAN SALES
    if (request.method === "POST" && url.pathname === "/api/checkout") {
      try {
        const body = await request.json().catch(() => ({}));
        const customerName = String(body.name || "").trim();
        const customerEmail = String(body.email || "").trim();

        if (!customerName || !customerEmail) {
          return balasJson({ error: "Nama dan Email wajib diisi" }, 400);
        }
        if (!dokuSiap(env)) {
          return balasJson({ error: "Pembayaran belum siap: kredensial DOKU belum diatur." }, 503);
        }

        const orderId = "INV-" + Date.now();
        const hasil = await buatPembayaranDoku(env, {
          invoice: orderId,
          nama: customerName,
          email: customerEmail,
          notifikasiUrl: url.origin + PATH_NOTIFIKASI,
        });

        if (hasil.error) {
          return balasJson({ error: "Gagal memproses pembayaran: " + hasil.error }, 502);
        }

        // Pesanan disimpan sebagai "pending" sampai pembayaran terbukti masuk.
        // Kolom code sementara diisi nomor pesanan; setelah lunas diganti kode
        // voucher sungguhan.
        try {
          await env.DB.prepare(
            "INSERT OR IGNORE INTO vouchers " +
              "(code, batch, customer_name, customer_email, order_ref, txn_id, status, created_at) " +
              "VALUES (?, ?, ?, ?, ?, ?, 'pending', ?)"
          )
            .bind(
              orderId,
              "doku-web",
              customerName,
              customerEmail,
              orderId,
              hasil.tokenId || "",
              new Date().toISOString()
            )
            .run();
        } catch (e) {
          return balasJson({ error: "Gagal menyimpan pesanan: " + e.message }, 500);
        }

        // KABARI CRM (tidak boleh menggagalkan checkout).
        try {
          await fetch("https://lisensi.kibo.ai.id/webhook/internal-crm", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              event: "checkout",
              email: customerEmail,
              name: customerName,
              amount: HARGA,
              order_id: orderId,
              source: "tokoku.kibo.ai.id",
            }),
            signal: AbortSignal.timeout(6000),
          });
        } catch (_) {}

        return balasJson({
          payment_link: hasil.url,
          order_id: orderId,
          payment_method: "doku",
          total_payment: HARGA,
        });
      } catch (err) {
        return balasJson({ error: err.message }, 500);
      }
    }

    // 2. PENGECEKAN STATUS PEMBAYARAN
    //
    // Bukan sekadar membaca database: kalau pesanan masih "pending", worker
    // menanyakan status langsung ke DOKU — jadi pembeli yang sudah membayar
    // tetap mendapat kode walau notifikasi tidak pernah sampai.
    if (request.method === "GET" && url.pathname === "/api/check-payment") {
      try {
        const orderId = String(url.searchParams.get("order_id") || "").trim();
        if (!orderId) return balasJson({ error: "order_id wajib diisi" }, 400);

        const pesanan = await env.DB.prepare(
          "SELECT code, status FROM vouchers WHERE order_ref = ?"
        )
          .bind(orderId)
          .first();

        if (!pesanan) return balasJson({ error: "Pesanan tidak ditemukan" }, 404);

        const statusDb = String(pesanan.status || "");

        if (statusDb !== "pending") {
          const kode = String(pesanan.code || "");
          return balasJson({
            status: statusDb === "batal" ? "canceled" : "completed",
            kode_terkirim: kode.startsWith("VC-"),
            email: kode.startsWith("VC-") ? await statusEmailVoucher(env, kode) : "",
          });
        }

        const status = await statusDoku(env, orderId);

        if (status === "SUCCESS") {
          const hasil = await lunasiPesanan(env, orderId, "", { metode: "DOKU" });
          return balasJson({
            status: hasil.ok ? "completed" : "paid_email_gagal",
            kode_terkirim: hasil.ok,
            email: hasil.email || "",
          });
        }

        if (status === "FAILED" || status === "EXPIRED" || status === "CANCELLED") {
          try {
            await env.DB.prepare(
              "UPDATE vouchers SET status = 'batal' WHERE order_ref = ? AND status = 'pending'"
            )
              .bind(orderId)
              .run();
          } catch (_) {}
          return balasJson({ status: "canceled" });
        }

        return balasJson({ status: "pending" });
      } catch (err) {
        return balasJson({ error: err.message }, 500);
      }
    }

    // 3. NOTIFIKASI DARI DOKU
    //
    // Alamat ini yang didaftarkan di DOKU (dan dikirim ulang lewat
    // additional_info.override_notification_url saat membuat pembayaran).
    // Wajib menjawab 200; kalau 4xx/5xx DOKU akan mengirim ulang terus.
    if (request.method === "POST" && url.pathname === PATH_NOTIFIKASI) {
      const rawPayload = await request.text();

      const sah = await notifikasiDokuSah(env, request, rawPayload);
      if (!sah) {
        // Jangan catat apa pun untuk permintaan tak sah: kalau dicatat,
        // siapa pun bisa membanjiri tabel dengan POST sampah.
        return balasJson({ error: "unauthorized" }, 401);
      }

      let payload = {};
      try {
        payload = JSON.parse(rawPayload);
      } catch (_) {
        await catatKejadian(env, {
          delivery: "rusak-" + Date.now(),
          event: "notifikasi",
          status: "json_rusak",
          alasan: rawPayload.slice(0, 300),
        });
        return balasJson({ error: "bad_json" }, 400);
      }

      const invoice = String((payload.order && payload.order.invoice_number) || "").trim();
      const jumlah = Number((payload.order && payload.order.amount) ?? 0);
      const statusMasuk = String((payload.transaction && payload.transaction.status) || "").toUpperCase();
      const waktuBayar = (payload.transaction && payload.transaction.date) || "";
      const kanal = (payload.channel && payload.channel.id) || (payload.service && payload.service.id) || "";

      await catatKejadian(env, {
        delivery: invoice || "tanpa-invoice-" + Date.now(),
        event: "notifikasi",
        status: statusMasuk || "tanpa_status",
        alasan: rawPayload.slice(0, 300),
      });

      if (statusMasuk !== "SUCCESS") {
        await catatKejadian(env, {
          delivery: invoice || "tanpa-invoice",
          event: "notifikasi",
          status: "diabaikan",
          alasan: "status " + (statusMasuk || "(kosong)"),
        });
        return balasJson({ ok: true, diabaikan: true });
      }

      // Nominal harus cocok. Tanpa pemeriksaan ini, transaksi Rp 1.000 bisa
      // dipakai untuk mengklaim lisensi Rp 99.000.
      if (jumlah !== HARGA) {
        await catatKejadian(env, {
          delivery: invoice || "tanpa-invoice",
          event: "notifikasi",
          status: "nominal_tidak_cocok",
          alasan: "amount=" + String(jumlah),
        });
        return balasJson({ ok: true, nominal: false });
      }

      if (!invoice) {
        await catatKejadian(env, {
          delivery: "tanpa-invoice",
          event: "notifikasi",
          status: "tanpa_invoice",
          alasan: rawPayload.slice(0, 300),
        });
        return balasJson({ ok: true });
      }

      const hasil = await lunasiPesanan(env, invoice, "", {
        jumlah,
        waktu: waktuBayar,
        metode: namaMetode(kanal),
      });

      // 500 hanya kalau voucher belum jadi — DOKU akan mencoba lagi.
      // Email yang gagal TIDAK diulang lewat notifikasi (voucher sudah ada);
      // jalur /api/check-payment dan dasbor admin yang menanganinya.
      if (!hasil.kode) {
        return balasJson({ ok: false, reason: hasil.alasan || "gagal" }, 500);
      }
      return balasJson({ ok: true });
    }

    // 4. UNDUHAN — dilayani dari domain ini, bukan dari server lisensi
    if (request.method === "GET" && url.pathname === "/api/versi") {
      try {
        return await fetch("https://lisensi.kibo.ai.id/api/versi", {
          headers: { Accept: "application/json" },
        });
      } catch (err) {
        return balasJson({ ok: false, error: err.message }, 502);
      }
    }

    if (request.method === "GET" && url.pathname === "/unduh/apk") {
      try {
        // Dialirkan apa adanya: header Content-Type dan Content-Disposition
        // dari server lisensi ikut terbawa, jadi peramban tetap menyimpannya
        // sebagai app-release.apk.
        return await fetch("https://lisensi.kibo.ai.id/unduh/apk");
      } catch (err) {
        return new Response("Gagal mengambil berkas APK: " + err.message, {
          status: 502,
          headers: { "Content-Type": "text/plain; charset=utf-8" },
        });
      }
    }

    // Alamat lama (dipakai di email dan tautan yang sudah beredar) tetap
    // hidup: /unduh dilayani otomatis dari berkas unduh.html.
    if (request.method === "GET" && url.pathname === "/unduh/") {
      return Response.redirect(url.origin + "/unduh", 301);
    }

    // 5. HALAMAN INTERNAL — alat penjual, bukan untuk pelanggan
    if (url.pathname === "/internal" || url.pathname === "/internal/") {
      return Response.redirect(url.origin + "/internal/voucher", 301);
    }

    if (url.pathname.startsWith("/internal/")) {
      if (request.method !== "GET" && request.method !== "HEAD") {
        return new Response("Metode tidak diizinkan", { status: 405 });
      }
      if (!env.ASSETS) {
        return new Response("Halaman internal belum tersedia", {
          status: 404,
          headers: { "Content-Type": "text/plain; charset=utf-8" },
        });
      }
      const aset = await env.ASSETS.fetch(request);
      if (aset.status !== 200) return aset;
      const kepalaAset = new Headers(aset.headers);
      kepalaAset.set("X-Robots-Tag", "noindex, nofollow, noarchive");
      kepalaAset.set("Cache-Control", "no-store");
      kepalaAset.set("Referrer-Policy", "no-referrer");
      return new Response(aset.body, { status: 200, headers: kepalaAset });
    }

    // Selain rute di atas, serahkan ke aset statis (HTML/CSS/gambar).
    //
    // Binding `ASSETS` hanya ada kalau didaftarkan di konfigurasi deploy.
    // Tanpa pemeriksaan ini, permintaan ke berkas yang sudah dihapus melempar
    // galat dan Cloudflare menjawab 500 — terlihat seperti server rusak.
    if (env.ASSETS) {
      return env.ASSETS.fetch(request);
    }
    return new Response("Halaman tidak ditemukan", {
      status: 404,
      headers: { "Content-Type": "text/plain; charset=utf-8" },
    });
  },
};
