# Panduan Jual Lepas TokoKu — 1 Lisensi = 1 HP

Sistem: **bayar sekali, pakai selamanya.** Setiap pembelian mendapat satu
**Kode Voucher** yang hanya bisa dipakai di **satu HP**. Aktivasi butuh internet
sekali; setelah itu aplikasi jalan penuh secara offline.

**Pelanggan mengaktifkan sendiri.** Anda tidak perlu membuat atau mengirim kode
aktivasi satu per satu — cukup jual kodenya, sisanya dikerjakan server.

---

## Status saat ini (per 23 September 2026)

Kode sudah selesai, kunci tanda tangan sudah terpasang, dan server aktivasi
sudah **berjalan**. Tidak ada lagi langkah persiapan yang tertinggal.

| Bagian | Status |
|---|---|
| Kode lisensi + aktivasi + cek pembaruan | Selesai |
| Fitur hutang, catatan, laporan, scan barcode, profil toko | Selesai — versi **1.5.0** |
| Portal aktivasi pelanggan + halaman admin penjual | Selesai — [buka portal](https://tokoku-lisensi.dompetkuai.workers.dev) |
| Halaman unduh APK untuk pelanggan | Selesai — [buka halaman unduh](https://tokoku-lisensi.dompetkuai.workers.dev/unduh) |
| **Kunci tanda tangan (BAGIAN A)** | **Selesai** — 4 GitHub Secrets sudah terisi, APK ditandatangani kunci rilis |
| **Server aktivasi (BAGIAN B)** | **Selesai** — berjalan di `https://tokoku-lisensi.dompetkuai.workers.dev` |

### Akun GitHub Anda tidak lagi terlihat pelanggan

Dulu tautan unduhan menunjuk langsung ke halaman rilis GitHub, sehingga
pelanggan bisa menemukan akun GitHub Anda. Sekarang tidak lagi — semua lewat
server aktivasi:

| Keperluan | Alamat yang dipakai aplikasi |
|---|---|
| Unduh APK | `https://tokoku-lisensi.dompetkuai.workers.dev/unduh` |
| Berkas APK-nya | `https://tokoku-lisensi.dompetkuai.workers.dev/unduh/apk` |
| Cek versi terbaru | `https://tokoku-lisensi.dompetkuai.workers.dev/api/versi` |

Server yang mengambilkan berkasnya dari rilis GitHub, jadi yang terlihat
pelanggan hanya alamat server aktivasi. Nama akun GitHub Anda hanya tersimpan di
sisi server, di `GITHUB_REPO` pada `cloudflare/wrangler.toml`.

### Gerbang lisensi sudah aktif

Karena `activationServerUrl` sudah diisi, setiap pelanggan **wajib aktivasi**.
Spanduk merah "Mode uji" tidak akan muncul lagi. Kalau suatu saat spanduk itu
muncul, berarti APK yang terpasang adalah build lama atau build uji — jangan
dijual.


---

## Ringkasan alur

```
Pelanggan instal APK
   → aplikasi menampilkan Kode Perangkat (mis. TK-7F3A-91C2-B8D4)
   → pelanggan membeli Kode Voucher dari Anda (mis. VC-4M2P-8QRT-1WZX)
   → pelanggan membuka portal aktivasi, memasukkan kedua kode itu
   → portal menampilkan Kode Aktivasi (mis. AK-9K3D-6VBH-2NQE)
   → pelanggan menempelkannya di aplikasi → aktif selamanya, offline
```

Yang perlu Anda kerjakan hanya **menyerahkan Kode Voucher**. Tidak ada langkah
manual lagi — pelanggan menyelesaikan sendiri dalam satu menit.

Pelanggan yang tidak mau membuka portal juga bisa menempel langsung Kode Voucher
ke kolom Kode Aktivasi di aplikasi. Hasilnya sama.

---

## Tiga jenis kode — jangan tertukar

| Kode | Awalan | Siapa yang membuat | Gunanya |
|---|---|---|---|
| **Kode Perangkat** | `TK-` | Aplikasi, otomatis | Menandai HP pelanggan. Tetap sama selama tidak diinstal ulang |
| **Kode Voucher** | `VC-` | Anda, lewat alat pembuat voucher | Yang Anda **jual**. Sekali pakai |
| **Kode Aktivasi** | `AK-` | Server, otomatis saat penukaran | Yang diketik pelanggan untuk mengaktifkan aplikasi |

Ketiganya memakai huruf `I`, `O` dan angka `0`, `1` yang dibuang, supaya
pelanggan tidak salah ketik.

---

## BAGIAN A — Pasang kunci tanda tangan (sekali saja) — SUDAH DIKERJAKAN

> **Status: selesai.** Keempat GitHub Secrets sudah terisi dan APK sudah
> ditandatangani kunci rilis. Langkah di bawah disimpan untuk keadaan darurat —
> misalnya kalau Anda mengganti kunci, memindahkan repo, atau menyiapkan mesin
> baru.

Ini **wajib dikerjakan sebelum menjual satu lisensi pun.** Kalau dilewati,
aplikasi pembeli tidak akan pernah bisa di-update, dan semua lisensi akan mati
kalau kuncinya berubah nanti.

1. Buka folder `C:\Users\Hariyanto\Documents\tokoku_app_source\release-signing\`
2. **Klik dua kali `SALIN-SECRET-GITHUB.bat`** — file itu menyalin keempat nilai
   ke clipboard satu per satu, jadi Anda tinggal Ctrl+V di GitHub. Tidak perlu
   menyalin 3.640 karakter base64 dengan tangan.
3. Kalau ingin tahu detailnya, baca `PENTING-BACA-INI.md` di folder yang sama.
4. Halaman GitHub-nya:
   `https://github.com/anton1990-90/kiosku/settings/secrets/actions`
   lalu tambahkan 4 secrets:

   | Name | Isi |
   |---|---|
   | `KEYSTORE_BASE64` | seluruh isi file `keystore-base64.txt` |
   | `KEYSTORE_PASSWORD` | seluruh isi file `storepass.txt` |
   | `KEY_ALIAS` | `tokoku` |
   | `KEY_PASSWORD` | seluruh isi file `storepass.txt` |

5. Jalankan build ulang: tab **Actions** → **Build APK** → **Run workflow**
   (branch `main`). Setelah selesai, APK di halaman Release sudah
   ditandatangani kunci rilis dan siap dijual.
6. **Cadangkan folder `release-signing`** ke Google Drive atau flashdisk.
   Kalau folder ini hilang, Anda tidak akan pernah bisa merilis update lagi.

---

## BAGIAN B — Pasang server aktivasi (sekali saja) — SUDAH DIKERJAKAN

> **Status: selesai.** Server sudah berjalan di
> **`https://tokoku-lisensi.dompetkuai.workers.dev`** dan `activationServerUrl`
> di `lib/core/config/app_config.dart` sudah menunjuk ke sana. Langkah di bawah
> disimpan kalau suatu saat server perlu dibuat ulang.

Server aktivasi sekarang berjalan di **Cloudflare Workers**. Gratis, dan yang
paling penting: **tidak pernah dibekukan** walaupun berhari-hari tidak dipakai.
(Dulu rencananya pakai Supabase, tapi proyek gratisnya dibekukan setelah ± 7
hari nganggur — sangat merepotkan untuk penjualan yang tidak setiap hari.)

Panduan teknis lengkapnya ada di **[`cloudflare/README.md`](../cloudflare/README.md)**.
Ringkasnya:

1. Daftar akun Cloudflare gratis di https://dash.cloudflare.com/sign-up
2. Pasang Node.js kalau belum ada
3. Jalankan, dari dalam folder `cloudflare/`:

   ```bash
   npm install
   npx wrangler login
   npx wrangler d1 create tokoku-lisensi
   ```

   Perintah terakhir mencetak `database_id`. Salin ke `cloudflare/wrangler.toml`.

4. Buat tabelnya:

   ```bash
   npx wrangler d1 execute tokoku-lisensi --remote --file=schema.sql
   ```

5. Buat kunci admin, lalu simpan di Cloudflare:

   ```bash
   python -c "import secrets; print(secrets.token_urlsafe(32))"
   npx wrangler secret put ADMIN_KEY
   ```

6. Terbitkan, lalu catat alamat yang dicetak:

   ```bash
   npx wrangler deploy
   ```

7. Isi alamat itu ke `lib/core/config/app_config.dart`:

   ```dart
   static const String activationServerUrl = 'https://tokoku-lisensi.nama-anda.workers.dev';
   ```

   Kalau mau, kirimkan alamat itu ke saya — saya isikan sekalian.

Setelah ini, `<alamat-worker>` adalah portal pelanggan, dan
`<alamat-worker>/admin` adalah halaman admin Anda.

---

## BAGIAN C — Cara menjual ke pelanggan (per transaksi)

### 1. Kirim APK ke pelanggan

Cukup kirim **satu tautan** ini — pelanggan akan melihat halaman unduh yang
ramah, lengkap dengan nomor versi terbaru:

```
https://tokoku-lisensi.dompetkuai.workers.dev/unduh
```

Halaman itu punya tombol **Unduh APK** yang otomatis mengambil versi terbaru.
Tautan ini **tidak menampilkan akun GitHub Anda** — berkasnya dialirkan lewat
server aktivasi.

Minta pelanggan:
- Buka tautannya lewat browser HP
- Tekan **Unduh APK**
- Aktifkan **"Instal dari sumber tidak dikenal"** kalau diminta
- Buka file APK untuk memasang

Halaman yang sama juga menautkan ke portal aktivasi, jadi pelanggan baru bisa
mengunduh **dan** mengaktifkan dari satu tempat.

### 2. Siapkan stok voucher

Buat sekaligus banyak, supaya tidak perlu repot setiap ada pembeli:

```bash
export TOKOKU_URL="https://tokoku-lisensi.dompetkuai.workers.dev"
export TOKOKU_ADMIN_KEY="kunci-admin-Anda"
```

`TOKOKU_ADMIN_KEY` tersimpan di
`C:\Users\Hariyanto\Documents\tokoku_app_source\release-signing\admin-key-tokoku.txt`
(di luar repo, jadi tidak ikut ter-commit). Isinya juga tersimpan di Cloudflare
sebagai secret `ADMIN_KEY`.

```bash
python tools/buat-voucher.py --jumlah 10 --kelompok "Grosir-2026-09"
```

Hasilnya daftar kode siap jual, dan tercatat di `ledger-voucher.csv`.

Kalau hanya butuh daftar kodenya (untuk disalin ke chat atau dicetak di kartu):

```bash
python tools/buat-voucher.py --jumlah 5 --ringkas
```

Bisa juga lewat browser: buka `<alamat-worker>/admin`, masukkan `ADMIN_KEY`,
lalu isi kolom **Buat Voucher Baru**.

### 3. Serahkan SATU kode ke pelanggan

Satu pembelian = satu Kode Voucher. Kirim lewat WhatsApp, atau cetak di kartu.
Sertakan juga alamat portal:

> Buka `https://tokoku-lisensi.dompetkuai.workers.dev`, masukkan Kode Perangkat
> dari aplikasi dan Kode Voucher di bawah ini.

### 4. Pelanggan menyelesaikan sendiri

Di portal, pelanggan memasukkan **Kode Perangkat** + **Kode Voucher**, lalu
mendapat **Kode Aktivasi**. Kode itu diketik di aplikasi → selesai.

**Setelah aktif, aplikasi tidak butuh internet lagi** untuk operasi harian.

### 5. Melihat siapa yang sudah aktif

```bash
python tools/buat-voucher.py --ringkasan
```

Atau buka `<alamat-worker>/admin`.

> **Jangan pernah meng-commit `ledger-voucher.csv`.** Berkas itu berisi daftar
> pembeli **dan kode voucher yang masih berlaku** — kalau bocor, orang lain bisa
> memakainya untuk mengaktifkan aplikasi. Berkas ini sudah masuk `.gitignore`,
> jadi jangan dihapus dari sana.

---

## BAGIAN D — Merilis update aplikasi

Setiap kali kode diubah:

1. Naikkan versi di `pubspec.yaml`, contoh `version: 1.5.0+10` → `version: 1.5.1+11`
   Angka setelah `+` **wajib naik** — itulah `versionCode` Android. Kalau tidak
   naik, Android menolak memasang APK di atas aplikasi yang sudah terpasang.
2. Push ke branch `main`
3. GitHub Actions otomatis:
   - membangun APK dengan kunci rilis Anda
   - menerbitkan Release dengan tag `v1.5.1`
4. Pelanggan diberi tahu lewat **dua cara**:
   - **Titik merah di lonceng pojok kanan atas** beranda — muncul begitu ada
     versi baru. Ketuk untuk membuka rinciannya.
   - **Dialog "Pembaruan tersedia"** yang tampil sekali saat aplikasi dibuka.

   Keduanya menampilkan nomor versi, ukuran berkas, dan catatan rilis. Menekan
   **Unduh** membuka halaman unduh di server aktivasi Anda — bukan GitHub.

**Penting:** karena APK ditandatangani dengan kunci yang sama, memasang versi
baru **tidak menghapus data toko** pelanggan.

Pelanggan juga bisa cek manual: **Profil → Cek pembaruan**. Tombol itu memakai
sumber data yang sama dengan lencana di beranda, jadi hasilnya selalu konsisten.

---

## BAGIAN E — Kalau pelanggan ganti HP

Karena lisensi terikat pada 1 HP, HP baru akan meminta aktivasi lagi.

1. Pelanggan instal aplikasi di HP baru
2. Anda buka `<alamat-worker>/admin`
3. Cari lisensi pelanggan itu di tabel **Daftar Lisensi**, tekan **Pindah HP**
4. Pelanggan memasukkan **Kode Voucher yang sama** (atau Kode Aktivasi yang
   dulu) di HP baru → aktif

HP lama otomatis tidak berlaku lagi.

Lewat terminal, caranya:

```bash
curl -X POST "$TOKOKU_URL/admin/reset" \
  -H "x-admin-key: $TOKOKU_ADMIN_KEY" \
  -d '{"code":"AK-9K3D-6VBH-2NQE"}'
```

**Saran kebijakan:** gratis 1× dalam 12 bulan, setelah itu Rp 25–50rb per
pindah perangkat. Tulis di nota supaya tidak ribut.

---

## BAGIAN F — Kalau pembeli minta refund

Buka `<alamat-worker>/admin` → tabel **Daftar Lisensi** → tekan
**Nonaktifkan**. Lewat terminal:

```bash
curl -X POST "$TOKOKU_URL/admin/revoke" \
  -H "x-admin-key: $TOKOKU_ADMIN_KEY" \
  -d '{"code":"AK-9K3D-6VBH-2NQE","jenis":"lisensi"}'
```

Aplikasi yang sudah aktif **tetap jalan** (karena sudah offline), tapi kode itu
tidak bisa lagi dipakai untuk aktivasi baru di HP lain.

Kalau pelanggan membatalkan pembelian **sebelum** menukar vouchernya, cukup
nonaktifkan vouchernya (`"jenis":"voucher"`) — kodenya jadi tidak berguna.

---

## Kebijakan yang sebaiknya Anda tentukan sekarang

| Hal | Saran |
|---|---|
| Harga | Rp 100rb–300rb sekali bayar untuk 1 HP |
| Pindah perangkat | Gratis 1× / 12 bulan, lalu Rp 25–50rb |
| Update versi | Gratis (bagus untuk reputasi) |
| Batas support | 6 bulan konsultasi WhatsApp, tulis di nota |
| Nota | Sertakan nama toko, email, kode voucher, tanggal, ketentuan |

---

## Daftar periksa sebelum jualan pertama

- [x] 4 GitHub Secrets sudah diisi (Bagian A) — **selesai**
- [ ] Folder `release-signing` sudah dicadangkan ke 2 tempat ← **BELUM, kerjakan ini**
- [x] Server Cloudflare sudah diterbitkan dan `schema.sql` sudah dijalankan (Bagian B) — **selesai**
- [x] `ADMIN_KEY` sudah disimpan (ada di `release-signing/admin-key-tokoku.txt`)
- [x] `app_config.dart` sudah diisi `activationServerUrl` — **selesai**
- [ ] Sudah push, dan build GitHub Actions **hijau**
- [ ] Halaman unduh `https://tokoku-lisensi.dompetkuai.workers.dev/unduh` bisa
      dibuka dan tombol **Unduh APK** benar-benar mengunduh berkasnya
- [ ] Di halaman unduh dan portal, **tidak ada** kata "github" yang terlihat

**Dua pemeriksaan di bawah ini yang paling sering terlewat.** Kalau salah satu
gagal, APK-nya tetap "hijau" di GitHub tapi tidak layak dijual:

- [ ] **APK benar-benar bertanda tangan kunci rilis, bukan debug key.**
  Cara paling cepat: buka halaman build di GitHub → kalau masih muncul peringatan
  `KEYSTORE_BASE64 belum diisi`, berarti masih debug key. Setelah terpasang,
  pastikan sidik jari sertifikatnya sama dengan yang tercatat di
  `release-signing/PENTING-BACA-INI.md`:
  ```bash
  keytool -printcert -jarfile app-release.apk
  ```
- [ ] **Spanduk merah "Mode uji" sudah tidak muncul lagi di beranda.**
  Spanduk itu hanya tampil selama `app_config.dart` masih berisi `ISI_...`.
  Kalau masih muncul, gerbang lisensi belum aktif — artinya pembeli bisa memakai
  aplikasi tanpa aktivasi. **Jangan dijual selama spanduk itu masih ada.**

- [ ] Sudah tes sendiri: instal APK, aktivasi dengan 1 voucher percobaan
- [ ] Sudah tes: coba voucher yang sama di HP kedua → harus **ditolak**
- [ ] Sudah tes: buka portal di HP kedua dengan voucher yang sama → harus muncul
      pesan "sudah dipakai di HP lain"
- [ ] Voucher percobaan sudah dinonaktifkan dari halaman admin

---

## Kalau nanti mau menambah fitur

Beberapa hal yang mudah ditambahkan tanpa mengubah arsitektur:

- **Kode voucher berisi harga.** Tambahkan kolom di tabel `vouchers`, lalu
  tampilkan di portal supaya pelanggan tahu paket yang dibeli.
- **Pembelian otomatis.** Kalau nanti jualan lewat marketplace atau toko online,
  server marketplace bisa memanggil `POST /admin/vouchers` untuk membuat kode
  otomatis saat ada yang membayar.
- **Masa berlaku voucher.** Tambahkan kolom tanggal kedaluwarsa dan periksa di
  `/api/aktivasi`.
