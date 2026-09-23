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

/**
 * Susun email untuk satu pembeli.
 *
 * @param {object} o
 * @param {string} o.namaPembeli  nama pembeli (boleh kosong)
 * @param {string} o.kodeVoucher  kode yang baru dibuat, mis. VC-XXXX-XXXX-XXXX
 * @param {string} o.namaAplikasi nama aplikasi, mis. "TokoKu"
 * @param {string} o.halamanUnduh alamat halaman unduh
 * @param {string} o.portal       alamat portal aktivasi
 * @returns {{subject: string, html: string, text: string}}
 */
export function emailVoucher(o) {
  const namaAplikasi = aman(o && o.namaAplikasi, 'TokoKu');
  const kode = aman(o && o.kodeVoucher, '');
  const halamanUnduh = String((o && o.halamanUnduh) || '').trim();
  const portal = String((o && o.portal) || '').trim();

  const nama = String((o && o.namaPembeli) || '').trim();
  const sapaan = nama === '' ? 'Halo' : `Halo ${nama}`;

  const subject = `Kode Aktivasi ${namaAplikasi} Anda — ${kode}`;

  const teks = [
    `${sapaan},`,
    '',
    `Terima kasih sudah membeli ${namaAplikasi}.`,
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
    `Simpan email ini. Kode voucher hanya berlaku untuk satu HP.`,
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

    '<tr><td style="padding:18px 24px 24px 24px;font-family:Arial,Helvetica,sans-serif">' +
    '<p style="margin:0;font-size:12px;line-height:19px;color:#9CA3AF">Email ini dikirim otomatis setelah pembayaran Anda terkonfirmasi. Kalau ada pertanyaan, balas email ini.</p>' +
    '</td></tr>' +

    '</table></td></tr></table></body></html>';

  return { subject, html, text: teks };
}
