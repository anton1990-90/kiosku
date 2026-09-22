# Panduan Jual Lepas TokoKu — 1 Lisensi = 1 HP

Sistem: **bayar sekali, pakai selamanya.** Setiap pembelian mendapat satu
**Kode Voucher** yang hanya bisa dipakai di **satu HP**. Aktivasi butuh internet
sekali; setelah itu aplikasi jalan penuh secara offline.

**Pelanggan mengaktifkan sendiri.** Anda tidak perlu membuat atau mengirim kode
aktivasi satu per satu — cukup jual kodenya, sisanya dikerjakan server.

---

## Status saat ini (per 22 September 2026)

Kode sudah selesai dan build sudah **hijau** di GitHub Actions. Yang masih
kurang hanya dua hal di bawah ini — keduanya belum bisa dikerjakan tanpa data
dari Anda.

| Bagian | Status |
|---|---|
| Kode lisensi + aktivasi + cek pembaruan | Selesai, sudah di-commit & build sukses |
| Fitur hutang, catatan, laporan harian/mingguan/bulanan, scan barcode, profil toko | Selesai — versi **1.2.0** |
| Portal aktivasi pelanggan + halaman admin penjual | Selesai — ada di folder `cloudflare/` |
| APK bisa diunduh | Selesai — [tautan rilis terbaru](https://github.com/anton1990-90/kiosku/releases/latest/download/app-release.apk) |
| **Kunci tanda tangan (BAGIAN A)** | **Belum** — 4 GitHub Secrets masih kosong, jadi APK saat ini masih ditandatangani debug key |
| **Server aktivasi (BAGIAN B)** | **Belum** — `activationServerUrl` masih berisi `ISI_...`, dan servernya belum diterbitkan ke Cloudflare |

> **Jangan jual APK yang sekarang.** APK itu ditandatangani debug key, sehingga
> tidak bisa di-update dan Android ID-nya akan berubah saat kuncinya diganti —
> artinya lisensi pelanggan akan mati. Kerjakan BAGIAN A dulu, jalankan build
> ulang, baru mulai jualan.

### Selama BAGIAN B belum dikerjakan, aplikasi terbuka tanpa aktivasi

Supaya Anda tetap bisa mencoba semua fitur sebelum server aktivasi siap,
gerbang lisensi sengaja dimatikan selama `activationServerUrl` masih berisi
`ISI_...`. Saat itu beranda menampilkan spanduk merah:

> Mode uji: lisensi belum aktif karena server aktivasi belum diisi di
> app_config.dart. Jangan jual APK ini.

Begitu alamat server diisi dan build dijalankan ulang, gerbang lisensi
**aktif kembali otomatis** dan setiap pelanggan wajib aktivasi. Jadi APK yang
benar-benar dijual selalu terkunci — tidak perlu mengubah kode lagi.

**Artinya:** selama spanduk merah itu masih muncul, APK tersebut adalah versi
uji, bukan versi jual.

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

## BAGIAN A — Pasang kunci tanda tangan (sekali saja)

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

## BAGIAN B — Pasang server aktivasi (sekali saja)

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

Link unduhan yang selalu menunjuk versi terbaru:

```
https://github.com/anton1990-90/kiosku/releases/latest/download/app-release.apk
```

Minta pelanggan:
- Unduh lewat browser HP
- Aktifkan **"Instal dari sumber tidak dikenal"** kalau diminta
- Buka file APK untuk memasang

### 2. Siapkan stok voucher

Buat sekaligus banyak, supaya tidak perlu repot setiap ada pembeli:

```bash
export TOKOKU_URL="https://tokoku-lisensi.nama-anda.workers.dev"
export TOKOKU_ADMIN_KEY="kunci-admin-Anda"

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

> Buka `https://tokoku-lisensi.nama-anda.workers.dev`, masukkan Kode Perangkat
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

1. Naikkan versi di `pubspec.yaml`, contoh `version: 1.2.0+4` → `version: 1.2.1+5`
2. Push ke branch `main`
3. GitHub Actions otomatis:
   - membangun APK dengan kunci rilis Anda
   - menerbitkan Release dengan tag `v1.2.1`
4. Pelanggan yang membuka aplikasi akan melihat dialog **"Pembaruan tersedia"**
   → tekan **Unduh** → browser terbuka → pasang APK baru

**Penting:** karena APK ditandatangani dengan kunci yang sama, memasang versi
baru **tidak menghapus data toko** pelanggan. Ini hanya berlaku kalau Bagian A
sudah dikerjakan.

Pelanggan juga bisa cek manual: **Profil → Cek pembaruan**.

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

- [ ] 4 GitHub Secrets sudah diisi (Bagian A)
- [ ] Folder `release-signing` sudah dicadangkan ke 2 tempat
- [ ] Server Cloudflare sudah diterbitkan dan `schema.sql` sudah dijalankan (Bagian B)
- [ ] `ADMIN_KEY` sudah disimpan di pengelola kata sandi
- [ ] `app_config.dart` sudah diisi `activationServerUrl`
- [ ] Sudah push, dan build GitHub Actions **hijau**

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
