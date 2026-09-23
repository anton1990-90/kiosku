/**
 * Halaman unduh APK untuk PELANGGAN.
 *
 * Alamat ini bisa dibagikan langsung ke pelanggan (atau dipasang sebagai
 * tautan di toko online). Isinya cuma satu tombol unduh — dan yang penting,
 * tombol itu menunjuk ke /unduh/apk milik Worker ini sendiri, bukan ke GitHub.
 * Jadi pelanggan tidak pernah tahu di mana file APK-nya disimpan.
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

/** Ubah jumlah byte jadi teks yang enak dibaca, mis. "31,6 MB". */
function ukuranTeks(bytes) {
  const nilai = Number(bytes) || 0;
  if (nilai <= 0) return '';
  const mb = nilai / (1024 * 1024);
  if (mb >= 1) return `${mb.toFixed(1).replace('.', ',')} MB`;
  const kb = nilai / 1024;
  return `${kb.toFixed(0)} KB`;
}

/**
 * @param {object} env   Variabel Worker (APP_NAME, SUPPORT_WHATSAPP).
 * @param {object|null} rilis  Hasil ambilRilisTerbaru(), boleh null.
 */
export function halamanUnduh(env, rilis) {
  const namaAplikasi = aman(env && env.APP_NAME, 'TokoKu');
  const whatsapp = String((env && env.SUPPORT_WHATSAPP) || '').replace(
    /[^0-9]/g,
    ''
  );

  const versi = rilis && rilis.versi ? aman(rilis.versi, '') : '';
  const ukuran = rilis ? ukuranTeks(rilis.ukuran) : '';

  const bagianVersi = versi
    ? '<p class="versi">Versi terbaru <b>' +
      versi +
      '</b>' +
      (ukuran ? ' &middot; ' + ukuran : '') +
      '</p>'
    : '';

  const blokBantuan = whatsapp
    ? '<p class="bantuan">Butuh bantuan? ' +
      '<a href="https://wa.me/' +
      whatsapp +
      '" target="_blank" rel="noopener">Hubungi penjual via WhatsApp</a></p>'
    : '';

  return `<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>Unduh ${namaAplikasi}</title>
<style>
  *, *::before, *::after { box-sizing: border-box; }
  html { -webkit-text-size-adjust: 100%; }
  body {
    margin: 0;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
      "Helvetica Neue", Arial, sans-serif;
    background: #F4F5F7;
    color: #1A1A2E;
    line-height: 1.55;
  }
  .bungkus { max-width: 520px; margin: 0 auto; padding: 0 0 48px; }

  header {
    background: linear-gradient(135deg, #0F6E56 0%, #085041 100%);
    color: #fff;
    padding: 32px 24px 28px;
    border-radius: 0 0 22px 22px;
  }
  .logo {
    width: 52px; height: 52px; border-radius: 15px;
    background: rgba(255, 255, 255, 0.16);
    display: flex; align-items: center; justify-content: center;
    margin-bottom: 16px;
  }
  .logo svg { width: 28px; height: 28px; }
  header h1 { margin: 0 0 6px; font-size: 23px; font-weight: 800; letter-spacing: -0.4px; }
  header p { margin: 0; font-size: 14px; color: rgba(255, 255, 255, 0.85); }

  main { padding: 20px 16px 0; }

  .kartu {
    background: #fff;
    border-radius: 14px;
    padding: 18px 16px;
    margin-bottom: 14px;
    border: 1px solid #E8E9EB;
  }
  .kartu h2 { margin: 0 0 6px; font-size: 16px; font-weight: 700; }
  .versi { margin: 0 0 14px; font-size: 13px; color: #6B7280; }
  .versi b { color: #085041; }

  .unduh {
    display: block;
    width: 100%;
    padding: 16px;
    font-size: 16px;
    font-weight: 700;
    text-align: center;
    text-decoration: none;
    color: #fff;
    background: #0F6E56;
    border-radius: 12px;
    transition: background .15s;
  }
  .unduh:hover { background: #0B5B47; }

  ol { margin: 12px 0 0; padding-left: 20px; font-size: 13px; color: #6B7280; }
  ol li { margin-bottom: 6px; }
  ol b { color: #1A1A2E; }

  .peringatan {
    background: #FAEEDA;
    border-radius: 11px;
    padding: 13px 14px;
    font-size: 12.5px;
    color: #854F0B;
    margin-top: 14px;
  }

  .bantuan { text-align: center; font-size: 12.5px; color: #6B7280; margin: 22px 0 0; }
  .bantuan a { color: #0F6E56; font-weight: 600; }
  footer { text-align: center; font-size: 11px; color: #9CA3AF; margin-top: 20px; }
</style>
</head>
<body>
<div class="bungkus">
  <header>
    <div class="logo">
      <svg viewBox="0 0 24 24" fill="none" stroke="#ffffff" stroke-width="2"
           stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
        <path d="M12 3v12"></path>
        <path d="M7 10l5 5 5-5"></path>
        <path d="M4 20h16"></path>
      </svg>
    </div>
    <h1>Unduh ${namaAplikasi}</h1>
    <p>Aplikasi kasir &amp; pembukuan untuk toko sembako.</p>
  </header>

  <main>
    <section class="kartu">
      <h2>Unduh aplikasinya</h2>
      ${bagianVersi}
      <a class="unduh" href="/unduh/apk" rel="noopener">Unduh APK</a>
      <ol>
        <li>Tekan tombol <b>Unduh APK</b> di atas.</li>
        <li>Kalau Android bertanya, pilih <b>Izinkan</b> memasang aplikasi
            dari sumber ini.</li>
        <li>Buka file yang sudah terunduh, lalu tekan <b>Instal</b>.</li>
        <li>Buka aplikasi, lalu aktifkan dengan Kode Voucher Anda.</li>
      </ol>
      <div class="peringatan">
        Sudah punya aplikasinya? Jangan diinstal ulang. Cukup buka
        <b>Profil &rarr; Cek Pembaruan</b> di dalam aplikasi &mdash; data toko
        Anda akan tetap utuh.
      </div>
    </section>

    <section class="kartu">
      <h2>Belum punya Kode Voucher?</h2>
      <p style="margin:0;font-size:13px;color:#6B7280">
        Kode Voucher dibeli dari penjual. Satu kode berlaku untuk satu HP.
        Setelah punya kodenya, aktivasi bisa dilakukan sendiri lewat
        <a href="/" style="color:#0F6E56;font-weight:600">halaman aktivasi</a>.
      </p>
    </section>

    ${blokBantuan}
    <footer>${namaAplikasi}</footer>
  </main>
</div>
</body>
</html>`;
}

/** Halaman yang muncul kalau file APK-nya gagal diambil dari server asal. */
export function halamanUnduhGagal(env) {
  const namaAplikasi = aman(env && env.APP_NAME, 'TokoKu');
  return `<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>Gagal mengunduh — ${namaAplikasi}</title>
<style>
  body {
    margin: 0; min-height: 100vh;
    display: flex; align-items: center; justify-content: center;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Arial, sans-serif;
    background: #F4F5F7; color: #1A1A2E; padding: 24px;
  }
  .kotak {
    background: #fff; border-radius: 14px; border: 1px solid #E8E9EB;
    padding: 24px; max-width: 420px; text-align: center;
  }
  h1 { margin: 0 0 8px; font-size: 18px; }
  p { margin: 0 0 18px; font-size: 13px; color: #6B7280; line-height: 1.6; }
  a {
    display: inline-block; padding: 12px 20px; font-size: 14px; font-weight: 700;
    text-decoration: none; color: #fff; background: #0F6E56; border-radius: 11px;
  }
</style>
</head>
<body>
  <div class="kotak">
    <h1>File unduhan sedang tidak bisa diambil</h1>
    <p>
      Coba lagi sebentar lagi. Kalau tetap gagal, hubungi penjual untuk
      mendapatkan file ${namaAplikasi} secara langsung.
    </p>
    <a href="/unduh">Coba lagi</a>
  </div>
</body>
</html>`;
}
