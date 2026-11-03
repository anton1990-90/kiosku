/**
 * Worker halaman penjualan TokoKu (tokoku.kibo.ai.id).
 *
 * Alur pembelian:
 *   halaman -> POST /api/checkout -> Pakasir (QRIS / VA)
 *           -> pembeli bayar -> Pakasir kirim webhook -> voucher dibuat
 *           -> email berisi kode dikirim lewat Resend
 *
 * Dua jalur di bawah ini menuju fungsi yang SAMA (lunasiPesanan), supaya
 * tidak mungkin ada versi kode yang berbeda antara "lewat webhook" dan
 * "lewat pengecekan status":
 *   1. Webhook Pakasir (jalur utama, seketika).
 *   2. /api/check-payment yang dipanggil halaman tiap 5 detik. Kalau webhook
 *      hilang (URL salah, gangguan jaringan, atau Cloudflare menolak), halaman
 *      yang sedang terbuka tetap menyelamatkan pesanan: worker menanyakan
 *      status langsung ke Pakasir lalu menerbitkan voucher.
 */

/** Harga lisensi. Dikunci di server, tidak pernah diambil dari peramban. */
const HARGA = 99000;

/** Alamat halaman unduh yang dipakai di dalam email. */
const HALAMAN_UNDUH = "https://tokoku.kibo.ai.id/unduh";

/** Alamat portal aktivasi yang dipakai di dalam email. */
const PORTAL_AKTIVASI = "https://lisensi.kibo.ai.id";

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
  const metode = String((o && o.metode) || 'QRIS').trim().toUpperCase();

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
        rincianBaris('Metode', aman(metode, 'QRIS')) +
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
// Pembantu
// ---------------------------------------------------------------------------

/** Perbandingan yang tidak membocorkan panjang/isi lewat waktu balasan. */
function rahasiaSama(a, b) {
  const kiri = String(a || '');
  const kanan = String(b || '');
  if (kanan === '') return false;
  let beda = kiri.length ^ kanan.length;
  const panjang = Math.max(kiri.length, kanan.length);
  for (let i = 0; i < panjang; i += 1) {
    beda |= (kiri.charCodeAt(i) || 0) ^ (kanan.charCodeAt(i) || 0);
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
 * delivery_id adalah kunci utama, dan Pakasir bisa mengirim webhook yang sama
 * lebih dari sekali. Dulu baris kedua ditolak UNIQUE sehingga yang tercatat
 * justru galatnya. Sesudah diperbaiki dengan INSERT OR REPLACE, muncul masalah
 * baru yang lebih halus: pencatatan "webhook masuk" MENIMPA kolom email_status
 * pada baris yang sama, sehingga pemeriksaan "sudah pernah dikirim?" membaca
 * string kosong dan pelanggan menerima email kedua.
 *
 * Karena itu kejadian biasa hanya memperbarui status/alasan, sedangkan kolom
 * email dan voucher hanya ditulis oleh catatHasilEmail.
 */
async function catatKejadian(env, o) {
  try {
    await env.DB.prepare(
      "INSERT INTO webhook_events " +
        "(delivery_id, sumber, event, status, voucher_code, email, email_status, alasan, received_at) " +
        "VALUES (?, 'pakasir', ?, ?, NULL, '', '', ?, ?) " +
        "ON CONFLICT(delivery_id) DO UPDATE SET " +
        "event = excluded.event, " +
        // Jangan turunkan status akhir ("processed"/"error" dari pengiriman
        // email) menjadi status webhook mentah saat Pakasir mengirim ulang.
        "status = CASE WHEN webhook_events.status IN ('processed', 'error') " +
        "THEN webhook_events.status ELSE excluded.status END, " +
        "alasan = excluded.alasan, received_at = excluded.received_at"
    )
      .bind(
        String(o.delivery || "tanpa-id").slice(0, 120),
        String(o.event || "webhook").slice(0, 40),
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
        "VALUES (?, 'pakasir', ?, ?, ?, ?, ?, ?, ?) " +
        "ON CONFLICT(delivery_id) DO UPDATE SET " +
        "event = excluded.event, status = excluded.status, " +
        "voucher_code = excluded.voucher_code, email = excluded.email, " +
        "email_status = excluded.email_status, alasan = excluded.alasan, " +
        "received_at = excluded.received_at"
    )
      .bind(
        String(o.delivery || "tanpa-id").slice(0, 120),
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
 * Aman dipanggil berkali-kali (webhook, pengecekan status, atau keduanya
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
    metode: (info && info.metode) || "QRIS",
  });

  await catatHasilEmail(env, {
    delivery: txnId || orderRef,
    event: "pembayaran",
    status: hasil.startsWith("terkirim") ? "processed" : "error",
    voucher: kode,
    email,
    emailStatus: hasil,
    alasan: hasil.startsWith("terkirim") ? "" : "email tidak terkirim",
  });

  return { ok: hasil.startsWith("terkirim"), kode, email: hasil };
}

/** POST /api/v2/create-transaction — "find or create", jadi aman diulang. */
async function buatTransaksiPakasir(env, orderId, metode) {
  const apiKey = String((env.PAKASIR_API_KEY || "")).trim();
  const slug = String((env.PAKASIR_SLUG || "")).trim();
  if (!apiKey || !slug) return { error: "gateway_belum_diatur" };

  try {
    const res = await fetch(
      `https://app.pakasir.com/api/v2/create-transaction/${slug}/${encodeURIComponent(orderId)}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-Api-Key": apiKey },
        body: JSON.stringify({ method: metode, amount: HARGA }),
        signal: AbortSignal.timeout(12000),
      }
    );
    const data = await res.json().catch(() => ({}));
    if (!res.ok) return { error: data.error || `http_${res.status}` };
    return data;
  } catch (e) {
    return { error: String((e && e.message) || e).slice(0, 120) };
  }
}

/** GET /api/v2/transaction-status — sumber kebenaran status pembayaran. */
async function statusPakasir(env, txnId) {
  const apiKey = String((env.PAKASIR_API_KEY || "")).trim();
  const slug = String((env.PAKASIR_SLUG || "")).trim();
  if (!apiKey || !slug || !txnId) return "";

  try {
    const res = await fetch(
      `https://app.pakasir.com/api/v2/transaction-status/${slug}/${encodeURIComponent(txnId)}`,
      {
        headers: { "X-Api-Key": apiKey },
        signal: AbortSignal.timeout(8000),
      }
    );
    if (!res.ok) return "";
    const data = await res.json().catch(() => ({}));
    return String(data.status || "");
  } catch (_) {
    return "";
  }
}

/** Simpan txn_id supaya pesanan bisa diperiksa ulang walau webhook hilang. */
async function simpanTxnId(env, orderRef, txnId) {
  if (!txnId) return;
  try {
    await env.DB.prepare(
      "UPDATE vouchers SET txn_id = ? WHERE order_ref = ? AND (txn_id IS NULL OR txn_id = '')"
    )
      .bind(String(txnId).slice(0, 60), orderRef)
      .run();
  } catch (_) {
    // Kolom txn_id mungkin belum ada di database lama — jangan gagal total.
  }
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // 1. BUAT TRANSAKSI DARI HALAMAN SALES
    if (request.method === "POST" && url.pathname === "/api/checkout") {
      try {
        const body = await request.json();
        const customerName = String(body.name || "").trim();
        const customerEmail = String(body.email || "").trim();
        const metode = String(body.method || "qris").trim();

        if (!customerName || !customerEmail) {
          return balasJson({ error: "Nama dan Email wajib diisi" }, 400);
        }

        const orderId = "INV-" + Date.now();
        const data = await buatTransaksiPakasir(env, orderId, metode);

        if (data.error) {
          return balasJson({ error: "Gagal memproses pembayaran: " + data.error }, 502);
        }
        if (!data.payment_link && !data.qr_string && !data.va_number) {
          return balasJson({ error: "Gagal memproses pembayaran" }, 502);
        }

        // Pesanan disimpan sebagai "pending" sampai pembayaran terbukti masuk.
        // Kolom code sementara diisi nomor pesanan; setelah lunas diganti kode
        // voucher sungguhan.
        try {
          await env.DB.prepare(
            "INSERT OR IGNORE INTO vouchers " +
              "(code, batch, customer_name, customer_email, order_ref, status, created_at) " +
              "VALUES (?, ?, ?, ?, ?, 'pending', ?)"
          )
            .bind(
              orderId,
              "pakasir-web",
              customerName,
              customerEmail,
              orderId,
              new Date().toISOString()
            )
            .run();
        } catch (e) {
          return balasJson({ error: "Gagal menyimpan pesanan: " + e.message }, 500);
        }

        await simpanTxnId(env, orderId, data.txn_id);

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
          ...data,
          order_id: orderId,
          total_payment: data.total_payment ?? HARGA,
          metode,
        });
      } catch (err) {
        return balasJson({ error: err.message }, 500);
      }
    }

    // 2. PENGECEKAN STATUS PEMBAYARAN (dipanggil halaman tiap 5 detik)
    //
    // Ini bukan sekadar membaca database. Kalau pesanan masih "pending",
    // worker menanyakan status langsung ke Pakasir — jadi pembeli yang sudah
    // membayar tetap mendapat kode walau webhook tidak pernah sampai.
    if (request.method === "GET" && url.pathname === "/api/check-payment") {
      try {
        const orderId = String(url.searchParams.get("order_id") || "").trim();
        if (!orderId) return balasJson({ error: "order_id wajib diisi" }, 400);

        const pesanan = await env.DB.prepare(
          "SELECT code, status, txn_id, customer_email FROM vouchers WHERE order_ref = ?"
        )
          .bind(orderId)
          .first();

        if (!pesanan) return balasJson({ error: "Pesanan tidak ditemukan" }, 404);

        const statusDb = String(pesanan.status || "");

        // Sudah lunas sebelumnya — cukup laporkan.
        if (statusDb !== "pending") {
          const kode = String(pesanan.code || "");
          return balasJson({
            status: statusDb === "batal" ? "canceled" : "completed",
            kode_terkirim: kode.startsWith("VC-"),
            email: kode.startsWith("VC-") ? await statusEmailVoucher(env, kode) : "",
          });
        }

        // Masih pending: pastikan dulu ke Pakasir.
        let txnId = String(pesanan.txn_id || "").trim();
        if (!txnId) {
          // Pesanan lama (sebelum txn_id disimpan). create-transaction
          // bersifat "find or create", jadi memanggilnya lagi mengembalikan
          // transaksi yang sama beserta txn_id-nya.
          const ulang = await buatTransaksiPakasir(env, orderId, "qris");
          if (ulang && ulang.txn_id) {
            txnId = String(ulang.txn_id);
            await simpanTxnId(env, orderId, txnId);
          }
        }

        if (!txnId) return balasJson({ status: "pending" });

        const status = await statusPakasir(env, txnId);

        if (status === "completed") {
          const hasil = await lunasiPesanan(env, orderId, txnId, { metode: "QRIS" });
          return balasJson({
            status: hasil.ok ? "completed" : "paid_email_gagal",
            kode_terkirim: hasil.ok,
            email: hasil.email || "",
          });
        }

        if (status === "canceled") {
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

    // 3. TERIMA WEBHOOK DARI PAKASIR
    //
    // Pengecualian /api/ dan /internal/ perlu disebut supaya permintaan ke
    // halaman internal tidak tercatat sebagai acara webhook palsu.
    if (
      request.method === "POST" &&
      !url.pathname.startsWith("/api/") &&
      !url.pathname.startsWith("/internal/")
    ) {
      const rawPayload = await request.text();
      let payload = {};
      try {
        payload = JSON.parse(rawPayload);
      } catch (_) {}

      const txnId = String(payload.txn_id || "").trim();
      const orderId = String(payload.order_id || "").trim();
      const statusMasuk = String(payload.status || "").trim().toLowerCase();

      const secretHeader = request.headers.get("X-Secret");
      const webhookSecret = String(env.PAKASIR_WEBHOOK_SECRET || "").trim();

      // JANGAN pernah mengembalikan nilai secret di dalam balasan galat.
      // Versi lama mencantumkannya, sehingga siapa pun yang mengirim POST
      // sekali bisa membaca secret itu dan memalsukan pembayaran.
      //
      // Pemeriksaan ini juga dilakukan SEBELUM mencatat apa pun: kalau tidak,
      // siapa pun bisa membanjiri tabel webhook_events dengan POST sampah.
      if (!rahasiaSama(secretHeader, webhookSecret)) {
        return balasJson({ error: "unauthorized" }, 401);
      }

      // Catat lebih dulu, apa pun hasilnya — supaya penjual bisa melihat
      // "webhook masuk tapi email gagal" di dasbor admin.
      await catatKejadian(env, {
        delivery: txnId || "tanpa-txn-" + Date.now(),
        event: "webhook",
        status: statusMasuk || "tanpa_status",
        alasan: rawPayload.slice(0, 300),
      });

      if (statusMasuk !== "completed") {
        await catatKejadian(env, {
          delivery: txnId || "tanpa-txn",
          event: "webhook",
          status: "diabaikan",
          alasan: "status " + (statusMasuk || "(kosong)"),
        });
        return new Response("OK", { status: 200 });
      }

      // Nominal harus cocok. Tanpa pemeriksaan ini, transaksi Rp 1.000 bisa
      // dipakai untuk mengklaim lisensi Rp 99.000.
      if (payload.amount != null && Number(payload.amount) !== HARGA) {
        await catatKejadian(env, {
          delivery: txnId || "tanpa-txn",
          event: "webhook",
          status: "nominal_tidak_cocok",
          alasan: "amount=" + String(payload.amount),
        });
        return new Response("OK", { status: 200 });
      }

      if (!orderId) {
        await catatKejadian(env, {
          delivery: txnId || "tanpa-txn",
          event: "webhook",
          status: "tanpa_order",
          alasan: rawPayload.slice(0, 300),
        });
        return new Response("OK", { status: 200 });
      }

      const hasil = await lunasiPesanan(env, orderId, txnId, {
        jumlah: payload.amount,
        waktu: payload.completed_at,
        metode: payload.payment_method,
      });

      // 500 hanya kalau voucher belum jadi — Pakasir akan mencoba lagi.
      // Email yang gagal TIDAK diulang lewat webhook (voucher sudah ada);
      // jalur /api/check-payment dan dasbor admin yang menanganinya.
      if (!hasil.kode) {
        return new Response("Gagal menerbitkan voucher", { status: 500 });
      }
      return new Response("OK", { status: 200 });
    }

    // 4. UNDUHAN — dilayani dari domain ini, bukan dari server lisensi
    //
    // Berkas APK tetap diambil dari server lisensi karena hanya di sana
    // kredensial GitHub disimpan — Worker ini sengaja tidak tahu-menahu soal
    // repo rilis. Yang berubah hanya alamat yang dilihat pelanggan.
    if (request.method === "GET" && url.pathname === "/api/versi") {
      try {
        return await fetch("https://lisensi.kibo.ai.id/api/versi", {
          headers: { "Accept": "application/json" },
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
    //
    // Halaman ini tidak ditautkan dari mana pun. Isinya baru terbuka setelah
    // kunci admin dimasukkan, dan kunci itu tidak pernah dikirim ke Worker
    // ini: halaman memanggil API admin di server lisensi langsung dari
    // peramban. Jadi yang perlu dijaga di sini hanya dua hal — alamatnya
    // tidak diindeks mesin pencari, dan isinya tidak ikut tersimpan di cache.
    if (url.pathname === "/internal" || url.pathname === "/internal/") {
      return Response.redirect(url.origin + "/internal/voucher", 301);
    }

    if (url.pathname.startsWith("/internal/")) {
      if (request.method !== "GET" && request.method !== "HEAD") {
        return new Response("Metode tidak diizinkan", { status: 405 });
      }
      // Binding ASSETS bisa tidak ada kalau konfigurasi deploy berubah.
      // Tanpa pemeriksaan ini, permintaan melempar galat dan Cloudflare
      // menjawab 500.
      if (!env.ASSETS) {
        return new Response("Halaman internal belum tersedia", {
          status: 404,
          headers: { "Content-Type": "text/plain; charset=utf-8" },
        });
      }
      const aset = await env.ASSETS.fetch(request);
      // Hanya balasan yang benar-benar berisi yang perlu ditambahi header;
      // balasan pengalihan dibiarkan apa adanya supaya tidak berputar.
      if (aset.status !== 200) return aset;
      const kepalaAset = new Headers(aset.headers);
      kepalaAset.set("X-Robots-Tag", "noindex, nofollow, noarchive");
      kepalaAset.set("Cache-Control", "no-store");
      kepalaAset.set("Referrer-Policy", "no-referrer");
      return new Response(aset.body, { status: 200, headers: kepalaAset });
    }

    // Jika bukan rute di atas, serahkan ke aset statis (HTML/CSS/gambar).
    //
    // Binding `ASSETS` hanya ada kalau didaftarkan di konfigurasi deploy.
    // Tanpa pemeriksaan ini, permintaan ke berkas yang sudah dihapus atau URL
    // yang salah ketik melempar galat dan Cloudflare menjawab 500 ("Worker
    // threw an exception") — terlihat seperti server rusak, padahal yang
    // benar cukup 404.
    if (env.ASSETS) {
      return env.ASSETS.fetch(request);
    }
    return new Response("Halaman tidak ditemukan", {
      status: 404,
      headers: { "Content-Type": "text/plain; charset=utf-8" },
    });
  },
};
