/**
 * Halaman admin untuk PENJUAL.
 *
 * Terbuka di /admin, tapi semua datanya baru muncul setelah kunci admin
 * (ADMIN_KEY) dimasukkan. Kunci dikirim lewat header x-admin-key, bukan
 * lewat alamat halaman, supaya tidak tertinggal di riwayat browser.
 *
 * Isinya: ringkasan stok voucher, pembuat voucher baru, daftar voucher,
 * dan daftar lisensi (termasuk tombol pindah HP & nonaktifkan).
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

export function halamanAdmin(env) {
  const namaAplikasi = aman(env && env.APP_NAME, 'TokoKu');

  return `<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>Admin Lisensi ${namaAplikasi}</title>
<style>
  *, *::before, *::after { box-sizing: border-box; }
  body {
    margin: 0;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
      "Helvetica Neue", Arial, sans-serif;
    background: #F4F5F7; color: #1A1A2E; font-size: 14px; line-height: 1.5;
  }
  header {
    background: linear-gradient(135deg, #0F6E56 0%, #085041 100%);
    color: #fff; padding: 22px 20px;
  }
  header h1 { margin: 0; font-size: 19px; font-weight: 800; }
  header p { margin: 4px 0 0; font-size: 12.5px; color: rgba(255,255,255,.85); }
  .bungkus { max-width: 1000px; margin: 0 auto; padding: 18px 16px 60px; }

  .kartu {
    background: #fff; border: 1px solid #E8E9EB; border-radius: 13px;
    padding: 16px; margin-bottom: 14px;
  }
  h2 { margin: 0 0 12px; font-size: 15px; font-weight: 700; }

  label { display: block; font-size: 11.5px; font-weight: 600; color: #6B7280; margin-bottom: 5px; }
  input, select {
    width: 100%; padding: 10px 12px; font-size: 14px; font-family: inherit;
    color: #1A1A2E; background: #F8F9FA; border: 1.5px solid #E8E9EB;
    border-radius: 10px; outline: none;
  }
  input:focus, select:focus { border-color: #0F6E56; background: #fff; }
  .baris { display: flex; flex-wrap: wrap; gap: 12px; }
  .baris > div { flex: 1 1 150px; }

  button { font-family: inherit; cursor: pointer; border: none; }
  .utama {
    padding: 11px 18px; font-size: 14px; font-weight: 700; color: #fff;
    background: #0F6E56; border-radius: 10px; margin-top: 12px;
  }
  .utama:hover:not(:disabled) { background: #0B5B47; }
  .utama:disabled { background: #A9BDB7; cursor: default; }
  .kecil {
    padding: 5px 10px; font-size: 11.5px; font-weight: 600; border-radius: 8px;
    background: #F8F9FA; color: #6B7280; border: 1px solid #E8E9EB;
  }
  .kecil:hover { background: #E8E9EB; }
  .kecil.bahaya { color: #A32D2D; border-color: #F3D3D3; background: #FCEBEB; }
  .kecil.bahaya:hover { background: #F7DADA; }

  .ringkas { display: flex; flex-wrap: wrap; gap: 10px; }
  .angka {
    flex: 1 1 120px; background: #F8F9FA; border: 1px solid #E8E9EB;
    border-radius: 11px; padding: 12px 14px;
  }
  .angka .nilai { font-size: 24px; font-weight: 800; color: #085041; line-height: 1.2; }
  .angka .label { font-size: 11.5px; color: #6B7280; }

  .tabelBungkus { overflow-x: auto; margin-top: 4px; }
  table { width: 100%; border-collapse: collapse; font-size: 12.5px; }
  th, td { text-align: left; padding: 9px 10px; border-bottom: 1px solid #F0F1F2; white-space: nowrap; }
  th { font-size: 11px; text-transform: uppercase; letter-spacing: .4px; color: #9CA3AF; font-weight: 700; }
  td.mono { font-family: ui-monospace, Menlo, Consolas, monospace; font-weight: 700; }
  tr:last-child td { border-bottom: none; }

  .tag {
    display: inline-block; padding: 2px 8px; border-radius: 20px;
    font-size: 11px; font-weight: 700;
  }
  .tag.unused  { background: #E1F5EE; color: #085041; }
  .tag.used    { background: #E6F1FB; color: #185FA5; }
  .tag.active  { background: #E1F5EE; color: #085041; }
  .tag.revoked { background: #FCEBEB; color: #A32D2D; }

  .pesan { display: none; padding: 11px 13px; border-radius: 10px; font-size: 12.5px; margin-top: 12px; }
  .pesan.tampil { display: block; }
  .pesan.galat { background: #FCEBEB; color: #A32D2D; }
  .pesan.baik { background: #E1F5EE; color: #085041; }

  .kosong { color: #9CA3AF; font-size: 12.5px; padding: 10px 0; }
  .kaki { font-size: 11.5px; color: #9CA3AF; text-align: center; margin-top: 24px; }
  .daftarKode {
    margin-top: 12px; padding: 12px; background: #E1F5EE; border-radius: 10px;
    font-family: ui-monospace, Menlo, Consolas, monospace; font-size: 13px;
    font-weight: 700; color: #085041; white-space: pre-wrap; word-break: break-all;
  }
</style>
</head>
<body>
<header>
  <h1>Admin Lisensi ${namaAplikasi}</h1>
  <p>Buat voucher, pantau lisensi, dan pindahkan lisensi ke HP baru.</p>
</header>

<div class="bungkus">
  <div class="kartu">
    <h2>Kunci Admin</h2>
    <div class="baris">
      <div style="flex:2 1 260px">
        <label for="kunci">ADMIN_KEY (rahasia, jangan dibagikan)</label>
        <input id="kunci" type="password" autocomplete="off" placeholder="tempel kunci admin Anda">
      </div>
      <div style="flex:0 1 auto;display:flex;align-items:flex-end">
        <button id="simpanKunci" class="utama" style="margin-top:0">Masuk</button>
      </div>
    </div>
    <div id="pesanKunci" class="pesan"></div>
    <p style="font-size:11.5px;color:#9CA3AF;margin:10px 0 0">
      Kunci hanya disimpan di tab ini dan hilang saat tab ditutup.
    </p>
  </div>

  <div id="isi" style="display:none">
    <div class="kartu">
      <h2>Ringkasan</h2>
      <div class="ringkas">
        <div class="angka"><div id="rVoucherTersedia" class="nilai">0</div><div class="label">Voucher belum terjual</div></div>
        <div class="angka"><div id="rVoucherTerpakai" class="nilai">0</div><div class="label">Voucher sudah dipakai</div></div>
        <div class="angka"><div id="rVoucherMati" class="nilai">0</div><div class="label">Voucher dinonaktifkan</div></div>
        <div class="angka"><div id="rLisensiAktif" class="nilai">0</div><div class="label">Lisensi aktif</div></div>
      </div>
    </div>

    <div class="kartu">
      <h2>Buat Voucher Baru</h2>
      <div class="baris">
        <div>
          <label for="jumlah">Jumlah</label>
          <input id="jumlah" type="number" min="1" max="200" value="5">
        </div>
        <div>
          <label for="batch">Kelompok (opsional)</label>
          <input id="batch" type="text" placeholder="Grosir-2026-09">
        </div>
        <div>
          <label for="namaPembeli">Nama pembeli (opsional)</label>
          <input id="namaPembeli" type="text" placeholder="Bu Siti">
        </div>
      </div>
      <button id="buat" class="utama">Buat Voucher</button>
      <div id="pesanBuat" class="pesan"></div>
      <div id="kodeBaru"></div>
    </div>

    <div class="kartu">
      <h2>Daftar Voucher</h2>
      <div class="tabelBungkus"><table>
        <thead><tr>
          <th>Kode Voucher</th><th>Kelompok</th><th>Pembeli</th>
          <th>Status</th><th>Kode Aktivasi</th><th>Dipakai</th><th></th>
        </tr></thead>
        <tbody id="tabelVoucher"></tbody>
      </table></div>
    </div>

    <div class="kartu">
      <h2>Daftar Lisensi</h2>
      <div class="tabelBungkus"><table>
        <thead><tr>
          <th>Kode Aktivasi</th><th>Voucher</th><th>Kode Perangkat</th>
          <th>Nama Toko</th><th>Status</th><th>Aktif Pada</th><th></th>
        </tr></thead>
        <tbody id="tabelLisensi"></tbody>
      </table></div>
    </div>
  </div>

  <p class="kaki">Halaman ini hanya untuk penjual. Jangan bagikan alamatnya.</p>
</div>

<script>
(function () {
  var elKunci = document.getElementById('kunci');
  var elSimpanKunci = document.getElementById('simpanKunci');
  var elPesanKunci = document.getElementById('pesanKunci');
  var elIsi = document.getElementById('isi');

  var KUNCI_SIMPAN = 'tokoku_admin_key';

  function kunci() { return sessionStorage.getItem(KUNCI_SIMPAN) || ''; }

  function pesan(el, teks, jenis) {
    el.textContent = teks;
    el.className = 'pesan ' + (jenis || 'galat') + ' tampil';
  }

  function sembunyikan(el) { el.className = 'pesan'; el.textContent = ''; }

  function panggil(jalur, opsi) {
    opsi = opsi || {};
    opsi.headers = Object.assign(
      { 'Content-Type': 'application/json', 'x-admin-key': kunci() },
      opsi.headers || {}
    );
    return fetch(jalur, opsi).then(function (r) {
      return r.json().then(function (data) { return { status: r.status, data: data }; });
    });
  }

  function teksTanggal(nilai) {
    if (!nilai) return '-';
    var d = new Date(nilai);
    if (isNaN(d.getTime())) return nilai;
    return d.toLocaleString('id-ID', {
      day: '2-digit', month: 'short', year: 'numeric',
      hour: '2-digit', minute: '2-digit'
    });
  }

  function sel(teks, kelas) {
    var td = document.createElement('td');
    td.textContent = teks;
    if (kelas) td.className = kelas;
    return td;
  }

  function selTag(status) {
    var td = document.createElement('td');
    var span = document.createElement('span');
    span.className = 'tag ' + status;
    span.textContent = status;
    td.appendChild(span);
    return td;
  }

  function tombol(teks, kelas, aksi) {
    var td = document.createElement('td');
    var b = document.createElement('button');
    b.className = 'kecil' + (kelas ? ' ' + kelas : '');
    b.textContent = teks;
    b.addEventListener('click', aksi);
    td.appendChild(b);
    return td;
  }

  function isiTabel(tbody, baris, buatBaris, kosong) {
    tbody.textContent = '';
    if (!baris.length) {
      var tr = document.createElement('tr');
      var td = document.createElement('td');
      td.colSpan = 7;
      td.className = 'kosong';
      td.textContent = kosong;
      tr.appendChild(td);
      tbody.appendChild(tr);
      return;
    }
    baris.forEach(function (item) { tbody.appendChild(buatBaris(item)); });
  }

  var dataTerakhir = { vouchers: [], licenses: [] };

  function muatData() {
    return panggil('/admin/data', { method: 'GET' }).then(function (hasil) {
      if (hasil.status === 401) {
        pesan(elPesanKunci, 'Kunci admin salah. Periksa kembali.', 'galat');
        elIsi.style.display = 'none';
        return;
      }
      if (!hasil.data || !hasil.data.ok) {
        pesan(elPesanKunci, 'Gagal memuat data dari server.', 'galat');
        return;
      }

      sembunyikan(elPesanKunci);
      elIsi.style.display = 'block';

      var r = hasil.data.ringkas || {};
      document.getElementById('rVoucherTersedia').textContent = r.voucher_tersedia || 0;
      document.getElementById('rVoucherTerpakai').textContent = r.voucher_terpakai || 0;
      document.getElementById('rVoucherMati').textContent = r.voucher_mati || 0;
      document.getElementById('rLisensiAktif').textContent = r.lisensi_aktif || 0;

      dataTerakhir.vouchers = hasil.data.vouchers || [];
      dataTerakhir.licenses = hasil.data.licenses || [];

      isiTabel(
        document.getElementById('tabelVoucher'),
        dataTerakhir.vouchers,
        function (v) {
          var tr = document.createElement('tr');
          tr.appendChild(sel(v.code, 'mono'));
          tr.appendChild(sel(v.batch || '-'));
          tr.appendChild(sel(v.customer_name || '-'));
          tr.appendChild(selTag(v.status));
          tr.appendChild(sel(v.license_code || '-', 'mono'));
          tr.appendChild(sel(teksTanggal(v.used_at)));
          tr.appendChild(tombol('Nonaktifkan', 'bahaya', function () {
            if (!confirm('Nonaktifkan voucher ' + v.code + '?')) return;
            panggil('/admin/revoke', {
              method: 'POST',
              body: JSON.stringify({ code: v.code, jenis: 'voucher' })
            }).then(muatData);
          }));
          return tr;
        },
        'Belum ada voucher. Buat yang pertama di atas.'
      );

      isiTabel(
        document.getElementById('tabelLisensi'),
        dataTerakhir.licenses,
        function (l) {
          var tr = document.createElement('tr');
          tr.appendChild(sel(l.code, 'mono'));
          tr.appendChild(sel(l.voucher_code || '-', 'mono'));
          tr.appendChild(sel(l.device_id || '(belum terikat)', 'mono'));
          tr.appendChild(sel(l.store_name || '-'));
          tr.appendChild(selTag(l.status));
          tr.appendChild(sel(teksTanggal(l.activated_at)));
          var td = document.createElement('td');
          var b1 = document.createElement('button');
          b1.className = 'kecil';
          b1.textContent = 'Pindah HP';
          b1.addEventListener('click', function () {
            if (!confirm('Lepaskan lisensi ' + l.code + ' dari HP lama?\\n\\nPelanggan lalu bisa mengaktifkan ulang di HP barunya.')) return;
            panggil('/admin/reset', {
              method: 'POST',
              body: JSON.stringify({ code: l.code })
            }).then(muatData);
          });
          td.appendChild(b1);
          var b2 = document.createElement('button');
          b2.className = 'kecil bahaya';
          b2.style.marginLeft = '6px';
          b2.textContent = 'Nonaktifkan';
          b2.addEventListener('click', function () {
            if (!confirm('Nonaktifkan lisensi ' + l.code + '?')) return;
            panggil('/admin/revoke', {
              method: 'POST',
              body: JSON.stringify({ code: l.code, jenis: 'lisensi' })
            }).then(muatData);
          });
          td.appendChild(b2);
          tr.appendChild(td);
          return tr;
        },
        'Belum ada lisensi yang aktif.'
      );
    });
  }

  elSimpanKunci.addEventListener('click', function () {
    var nilai = elKunci.value.trim();
    if (!nilai) {
      pesan(elPesanKunci, 'Masukkan kunci admin dulu.', 'galat');
      return;
    }
    sessionStorage.setItem(KUNCI_SIMPAN, nilai);
    muatData();
  });

  elKunci.addEventListener('keydown', function (e) {
    if (e.key === 'Enter') elSimpanKunci.click();
  });

  document.getElementById('buat').addEventListener('click', function () {
    var elTombol = document.getElementById('buat');
    var elPesanBuat = document.getElementById('pesanBuat');
    sembunyikan(elPesanBuat);
    document.getElementById('kodeBaru').textContent = '';

    var jumlah = parseInt(document.getElementById('jumlah').value, 10) || 1;
    elTombol.disabled = true;
    elTombol.textContent = 'Membuat...';

    panggil('/admin/vouchers', {
      method: 'POST',
      body: JSON.stringify({
        jumlah: jumlah,
        batch: document.getElementById('batch').value,
        customer_name: document.getElementById('namaPembeli').value
      })
    })
      .then(function (hasil) {
        if (hasil.data && hasil.data.ok) {
          pesan(elPesanBuat, 'Berhasil membuat ' + hasil.data.vouchers.length + ' voucher.', 'baik');
          var kotak = document.createElement('div');
          kotak.className = 'daftarKode';
          kotak.textContent = hasil.data.vouchers.join('\\n');
          document.getElementById('kodeBaru').appendChild(kotak);
          return muatData();
        }
        pesan(elPesanBuat, 'Gagal membuat voucher. Coba lagi.', 'galat');
      })
      .catch(function () {
        pesan(elPesanBuat, 'Tidak bisa menghubungi server.', 'galat');
      })
      .then(function () {
        elTombol.disabled = false;
        elTombol.textContent = 'Buat Voucher';
      });
  });

  if (kunci()) {
    elKunci.value = kunci();
    muatData();
  }
})();
</script>
</body>
</html>`;
}
