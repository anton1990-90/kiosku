/**
 * Halaman portal aktivasi untuk PELANGGAN.
 *
 * Pelanggan membuka halaman ini, menempel Kode Perangkat dari aplikasi dan
 * Kode Voucher yang dibeli, lalu menerima Kode Aktivasi untuk diketik ke
 * aplikasi. Tidak ada langkah yang perlu dilakukan penjual.
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

export function halamanPortal(env) {
  const namaAplikasi = aman(env && env.APP_NAME, 'TokoKu');
  const whatsapp = String((env && env.SUPPORT_WHATSAPP) || '').replace(
    /[^0-9]/g,
    ''
  );

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
<title>Aktivasi ${namaAplikasi}</title>
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

  .langkah {
    background: #fff;
    border-radius: 14px;
    padding: 16px;
    margin-bottom: 14px;
    border: 1px solid #E8E9EB;
  }
  .kepala { display: flex; align-items: center; gap: 10px; margin-bottom: 4px; }
  .nomor {
    flex: none;
    width: 24px; height: 24px; border-radius: 50%;
    background: #E1F5EE; color: #085041;
    font-size: 13px; font-weight: 800;
    display: flex; align-items: center; justify-content: center;
  }
  .kepala h2 { margin: 0; font-size: 15px; font-weight: 700; }
  .petunjuk { margin: 0 0 12px 34px; font-size: 13px; color: #6B7280; }

  label { display: block; font-size: 12px; font-weight: 600; color: #6B7280; margin-bottom: 6px; }
  input[type="text"] {
    width: 100%;
    padding: 13px 14px;
    font-size: 17px;
    font-weight: 700;
    letter-spacing: 1px;
    font-family: ui-monospace, "SF Mono", Menlo, Consolas, monospace;
    color: #1A1A2E;
    background: #F8F9FA;
    border: 1.5px solid #E8E9EB;
    border-radius: 11px;
    outline: none;
    transition: border-color .15s, background .15s;
  }
  input[type="text"]:focus { border-color: #0F6E56; background: #fff; }
  input[type="text"]::placeholder { color: #9CA3AF; font-weight: 600; letter-spacing: 1px; }

  .catatan { margin: 8px 0 0; font-size: 11.5px; color: #9CA3AF; }
  .opsional { font-weight: 500; color: #9CA3AF; text-transform: none; }

  button {
    font-family: inherit;
    cursor: pointer;
    border: none;
  }
  .utama {
    width: 100%;
    padding: 16px;
    font-size: 16px;
    font-weight: 700;
    color: #fff;
    background: #0F6E56;
    border-radius: 12px;
    margin-top: 4px;
    transition: background .15s;
  }
  .utama:hover:not(:disabled) { background: #0B5B47; }
  .utama:disabled { background: #A9BDB7; cursor: default; }

  .pesan {
    display: none;
    margin-top: 14px;
    padding: 13px 14px;
    border-radius: 11px;
    font-size: 13px;
    line-height: 1.5;
  }
  .pesan.tampil { display: block; }
  .pesan.galat { background: #FCEBEB; color: #A32D2D; }

  .hasil { display: none; }
  .hasil.tampil { display: block; }
  .hasil .kotak {
    background: #fff;
    border: 1.5px solid #1D9E75;
    border-radius: 14px;
    padding: 18px 16px;
    text-align: center;
  }
  .centang {
    width: 44px; height: 44px; margin: 0 auto 10px;
    border-radius: 50%; background: #E1F5EE;
    display: flex; align-items: center; justify-content: center;
  }
  .centang svg { width: 24px; height: 24px; }
  .hasil h3 { margin: 0 0 4px; font-size: 16px; font-weight: 800; color: #085041; }
  .hasil .sub { margin: 0 0 14px; font-size: 12.5px; color: #6B7280; }
  .kodeAktivasi {
    font-family: ui-monospace, "SF Mono", Menlo, Consolas, monospace;
    font-size: 20px; font-weight: 800; letter-spacing: 1.5px;
    color: #085041;
    background: #E1F5EE;
    border-radius: 10px;
    padding: 14px 10px;
    word-break: break-all;
    user-select: all;
  }
  .salin {
    margin-top: 10px;
    width: 100%;
    padding: 12px;
    font-size: 14px; font-weight: 700;
    color: #0F6E56;
    background: #fff;
    border: 1.5px solid #0F6E56;
    border-radius: 11px;
  }
  .salin:hover { background: #E1F5EE; }
  .langkahLanjut {
    margin: 14px 0 0;
    font-size: 13px; color: #6B7280; text-align: left;
    background: #FAEEDA;
    border-radius: 11px;
    padding: 13px 14px;
  }
  .langkahLanjut b { color: #854F0B; }

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
        <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"></path>
        <path d="M9 12l2 2 4-4"></path>
      </svg>
    </div>
    <h1>Aktivasi ${namaAplikasi}</h1>
    <p>Aktifkan sendiri dalam 1 menit. Tanpa perlu menghubungi penjual.</p>
  </header>

  <main>
    <div id="formulir">
      <section class="langkah">
        <div class="kepala">
          <div class="nomor">1</div>
          <h2>Salin Kode Perangkat</h2>
        </div>
        <p class="petunjuk">
          Buka aplikasi ${namaAplikasi}, di layar Aktivasi salin kode yang
          tertulis pada kotak hijau &ldquo;Kode Perangkat HP ini&rdquo;.
        </p>
        <label for="perangkat">Kode Perangkat</label>
        <input id="perangkat" type="text" inputmode="text" autocomplete="off"
               spellcheck="false" placeholder="TK-XXXX-XXXX-XXXX" maxlength="17">
        <p class="catatan">Selalu diawali <b>TK-</b>. Kodenya tetap sama
          selama aplikasi tidak diinstal ulang.</p>
      </section>

      <section class="langkah">
        <div class="kepala">
          <div class="nomor">2</div>
          <h2>Masukkan Kode Voucher</h2>
        </div>
        <p class="petunjuk">
          Kode yang Anda terima saat membeli aplikasi. Contohnya tertulis di
          kartu atau dikirim penjual lewat chat.
        </p>
        <label for="voucher">Kode Voucher</label>
        <input id="voucher" type="text" inputmode="text" autocomplete="off"
               spellcheck="false" placeholder="VC-XXXX-XXXX-XXXX" maxlength="17">
        <p class="catatan">Selalu diawali <b>VC-</b>. Satu voucher berlaku untuk
          satu HP saja.</p>
      </section>

      <section class="langkah">
        <div class="kepala">
          <div class="nomor">3</div>
          <h2>Nama Toko <span class="opsional">(boleh dikosongkan)</span></h2>
        </div>
        <p class="petunjuk">
          Nama usaha Anda. Boleh dikosongkan dan diisi nanti dari dalam aplikasi.
        </p>
        <label for="toko">Nama Toko</label>
        <input id="toko" type="text" autocomplete="organization"
               placeholder="Contoh: Toko Siti Jaya" maxlength="80"
               style="font-family:inherit;font-size:15px;font-weight:500;letter-spacing:0">
      </section>

      <button id="tombol" class="utama" type="button">Aktivasi Sekarang</button>
      <div id="pesan" class="pesan"></div>
    </div>

    <div id="hasil" class="hasil">
      <div class="kotak">
        <div class="centang">
          <svg viewBox="0 0 24 24" fill="none" stroke="#0F6E56" stroke-width="3"
               stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
            <path d="M20 6L9 17l-5-5"></path>
          </svg>
        </div>
        <h3>Aktivasi berhasil</h3>
        <p class="sub">Kode Aktivasi untuk HP Anda:</p>
        <div id="kodeAktivasi" class="kodeAktivasi"></div>
        <button id="salin" class="salin" type="button">Salin Kode Aktivasi</button>
        <p class="langkahLanjut">
          <b>Langkah terakhir:</b> buka aplikasi ${namaAplikasi}, tempel kode
          berawalan <b>AK-</b> di atas pada kolom <b>Kode Aktivasi</b>, lalu
          tekan tombol <b>Aktivasi</b>. Setelah itu aplikasi bisa dipakai
          tanpa internet.
        </p>
      </div>
      <p class="catatan" style="text-align:center;margin-top:12px">
        Simpan kode ini. Kode hanya berlaku untuk HP dengan Kode Perangkat
        <span id="perangkatTampil" style="font-weight:700"></span>.
      </p>
    </div>

    ${blokBantuan}
    <footer>Halaman ini hanya untuk aktivasi lisensi.</footer>
  </main>
</div>

<script>
(function () {
  var AWALAN_PERANGKAT = 'TK';
  var AWALAN_VOUCHER = 'VC';

  var elPerangkat = document.getElementById('perangkat');
  var elVoucher = document.getElementById('voucher');
  var elToko = document.getElementById('toko');
  var elTombol = document.getElementById('tombol');
  var elPesan = document.getElementById('pesan');
  var elFormulir = document.getElementById('formulir');
  var elHasil = document.getElementById('hasil');
  var elKode = document.getElementById('kodeAktivasi');
  var elSalin = document.getElementById('salin');
  var elPerangkatTampil = document.getElementById('perangkatTampil');

  /* Rapikan jadi XXXXX-XXXX-XXXX-XXXX sambil diketik. */
  function rapikan(nilai) {
    var s = (nilai || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
    if (s.length <= 2) return s;
    var awalan = s.slice(0, 2);
    var sisa = s.slice(2, 14);
    var potong = [];
    for (var i = 0; i < sisa.length; i += 4) potong.push(sisa.slice(i, i + 4));
    return awalan + (potong.length ? '-' + potong.join('-') : '');
  }

  function pasang(el) {
    el.addEventListener('input', function () {
      var posisi = el.selectionStart;
      var sebelum = el.value.length;
      el.value = rapikan(el.value);
      var beda = el.value.length - sebelum;
      var baru = Math.max(0, Math.min(el.value.length, posisi + beda));
      try { el.setSelectionRange(baru, baru); } catch (e) { /* diabaikan */ }
    });
  }

  pasang(elPerangkat);
  pasang(elVoucher);

  function tampilkanPesan(teks) {
    elPesan.textContent = teks;
    elPesan.className = 'pesan galat tampil';
  }

  function sembunyikanPesan() {
    elPesan.className = 'pesan';
    elPesan.textContent = '';
  }

  var PESAN = {
    invalid_code: 'Kode belum lengkap. Periksa kembali Kode Perangkat dan Kode Voucher Anda.',
    not_found: 'Kode voucher tidak ditemukan. Periksa kembali penulisannya, atau hubungi penjual tempat Anda membeli.',
    used_on_other_device: 'Voucher ini sudah dipakai di HP lain. Satu voucher hanya berlaku untuk satu HP. Hubungi penjual kalau Anda baru mengganti HP.',
    revoked: 'Kode ini sudah dinonaktifkan oleh penjual.',
    device_code_entered: 'Sepertinya Anda menempel Kode Perangkat ke kolom Kode Voucher. Kolom Kode Voucher harus diisi kode berawalan VC-.',
    busy: 'Sedang ada permintaan lain untuk voucher ini. Tunggu sebentar lalu coba lagi.',
    server_error: 'Server sedang bermasalah. Coba lagi beberapa saat lagi.',
    bad_request: 'Permintaan tidak dikenali. Muat ulang halaman ini lalu coba lagi.'
  };

  function kodeSiap(nilai, awalan) {
    var s = (nilai || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
    if (s.slice(0, 2) !== awalan) return null;
    if (s.length !== 14) return null;
    return s;
  }

  elTombol.addEventListener('click', function () {
    sembunyikanPesan();

    var perangkat = kodeSiap(elPerangkat.value, AWALAN_PERANGKAT);
    var voucher = kodeSiap(elVoucher.value, AWALAN_VOUCHER);

    if (!perangkat) {
      tampilkanPesan('Kode Perangkat belum lengkap. Salin ulang dari aplikasi, contoh: TK-1A2B-3C4D-5E6F.');
      elPerangkat.focus();
      return;
    }
    if (!voucher) {
      tampilkanPesan('Kode Voucher belum lengkap. Contoh: VC-1A2B-3C4D-5E6F.');
      elVoucher.focus();
      return;
    }

    elTombol.disabled = true;
    elTombol.textContent = 'Memproses...';

    fetch('/api/aktivasi', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        code: voucher,
        device_id: perangkat,
        store_name: elToko.value || ''
      })
    })
      .then(function (r) { return r.json(); })
      .then(function (data) {
        if (data && data.ok && data.activation_code) {
          elKode.textContent = data.activation_code;
          elPerangkatTampil.textContent = perangkat;
          elFormulir.style.display = 'none';
          elHasil.className = 'hasil tampil';
          window.scrollTo({ top: 0, behavior: 'smooth' });
          return;
        }
        var alasan = (data && data.reason) || 'server_error';
        tampilkanPesan(PESAN[alasan] || PESAN.server_error);
      })
      .catch(function () {
        tampilkanPesan('Tidak bisa menghubungi server. Periksa koneksi internet Anda lalu coba lagi.');
      })
      .then(function () {
        elTombol.disabled = false;
        elTombol.textContent = 'Aktivasi Sekarang';
      });
  });

  elSalin.addEventListener('click', function () {
    var teks = elKode.textContent;
    function berhasil() {
      elSalin.textContent = 'Tersalin!';
      setTimeout(function () { elSalin.textContent = 'Salin Kode Aktivasi'; }, 1800);
    }
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(teks).then(berhasil, pilihManual);
    } else {
      pilihManual();
    }
    function pilihManual() {
      var area = document.createElement('textarea');
      area.value = teks;
      area.setAttribute('readonly', '');
      area.style.position = 'absolute';
      area.style.left = '-9999px';
      document.body.appendChild(area);
      area.select();
      try { document.execCommand('copy'); berhasil(); } catch (e) { /* diabaikan */ }
      document.body.removeChild(area);
    }
  });

  [elPerangkat, elVoucher, elToko].forEach(function (el) {
    el.addEventListener('keydown', function (e) {
      if (e.key === 'Enter') elTombol.click();
    });
  });
})();
</script>
</body>
</html>`;
}
