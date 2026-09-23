# TokoKu — Aplikasi UMKM Toko Sembako & Penjualan (v1.14.0)

Aplikasi mobile cross-platform (Android & iOS) untuk toko sembako UMKM. Dibuat dengan Flutter, bekerja **offline-first** dengan autentikasi email.

## Fitur Utama

- **Offline-first**: Semua data tersimpan di perangkat (SQLite). Tidak butuh internet untuk jualan.
- **Autentikasi email**: Login dengan email & password. Akses penjualan dikendalikan sesuai email terdaftar.
- **Kasir (POS)**: Transaksi cepat dengan keranjang otomatis, pilihan metode pembayaran (tunai, QRIS, e-wallet), dan kalkulasi kembalian.
- **Potongan harga**: Potongan bisa diberikan **per barang** ("beli 2 kurang 500") maupun **untuk seluruh nota** ("borongan kurang 2.000"). Nilainya rupiah, bukan persen, dan selalu dibatasi harga barangnya supaya total tidak pernah negatif. Potongan ikut tercetak di struk, terlihat di riwayat transaksi, dan **mengurangi laba** yang dilaporkan — bukan hanya mengurangi total bayar.
- **Batal / retur transaksi**: Transaksi yang salah input bisa dibatalkan dari riwayat transaksi. Stok setiap barang dikembalikan, uang yang pernah masuk dikeluarkan lagi dari kas, dan piutang yang lahir dari transaksi itu dihapus — semuanya dalam **satu transaksi database**, jadi tidak ada pembatalan yang setengah jalan. Transaksinya **tidak dihapus**: statusnya berubah jadi "batal" dan jejaknya tetap bisa dilihat di Buku Kas dan Riwayat Stok, supaya pertanyaan "kenapa stok saya beda?" selalu bisa dijawab. Pembatalan ditolak kalau piutangnya sudah ada pembayarannya (uang itu benar-benar diterima, dan menghapusnya akan membuang riwayat bayar).
- **Scan barcode**: Scan barcode produk (EAN-13/UPC) langsung dari kamera — untuk menambah barang ke keranjang maupun mengisi barcode saat menambah produk baru.
- **Cetak struk thermal**: Cetak struk ke printer thermal Bluetooth 58mm/80mm setelah transaksi.
- **Cetak ulang struk**: Struk transaksi lama bisa dicetak lagi kapan saja dari riwayat transaksi — berguna kalau kertas habis, printer mati, atau pelanggan minta salinan.
- **Beranda**: Tombol aksi cepat berikon untuk hal yang paling sering dipakai — Transaksi, Tambah Stok, Laporan, Laporan Keuangan, Hutang & Piutang, Cetak Ulang Struk, Buku Kas, dan Catatan.
- **Manajemen produk**: Tambah, edit, hapus produk dengan kategori, harga modal & jual, barcode, dan stok. Supplier dipilih dari daftar yang bisa diedit. **Ikon produk bisa memakai foto dari galeri HP**, dan setiap produk punya **satuan** (pcs, kg, liter, ikat) supaya struk menulis "2 kg" dan bukan sekadar "2".
- **Manajemen stok**: Visual progress bar, peringatan stok menipis & habis, restok mudah. Daftar produk bisa langsung diklik untuk restok, dan kartu "stok menipis" di beranda membuka rincian produk yang perlu ditambah.
- **Laporan berkala**: Laporan **harian, mingguan, dan bulanan** dengan grafik, ringkasan laba, produk terlaris, dan **detail produk per item** lengkap dengan tanggal, waktu, harga, dan laba per transaksi.
- **Rincian produk terjual**: Maksimal 5 baris di layar Laporan, lalu "Lihat semua" membuka rincian lengkap yang bisa difilter harian/mingguan/bulanan, menampilkan total pendapatan beserta labanya, dan bisa **diekspor ke PDF & CSV**.
- **Kas**: Satu buku kas untuk semua uang masuk & keluar. Beranda menampilkan saldo kas di tengah, uang keluar di kiri bawah, uang masuk di kanan bawah. Setiap penjualan, pembayaran hutang/piutang, restok, beban, dan prive tercatat otomatis — plus riwayat lengkap dan pencatatan manual.
- **Laporan keuangan standar akuntansi**: **Laba rugi**, **perubahan ekuitas**, **neraca**, dan **arus kas**, semuanya bisa diekspor ke PDF & CSV. Ada juga pencatatan **beban usaha** dan **prive** (pengambilan pemilik).
- **Hutang & piutang**: Catat piutang pelanggan dan hutang ke supplier, cicilan pembayaran, riwayat bayar, serta peringatan jatuh tempo. Terhubung ke stok produk: restok yang belum dibayar penuh otomatis jadi hutang supplier, dan transaksi yang belum dibayar penuh jadi piutang pelanggan (dengan ceklist "Transaksi ini hutang?" di layar kasir).
- **Catatan**: Catatan bebas berwarna untuk pemilik toko, bisa disematkan (pin).
- **Profile**: Logo usaha bisa diganti dari galeri, info toko, metode pembayaran yang bisa diaktifkan/dinonaktifkan, daftar supplier yang bisa diedit, serta pintasan ke **Kas** dan **Laporan Keuangan**.
- **Lisensi & pembaruan**: Aktivasi satu perangkat, plus notifikasi otomatis saat ada versi baru.

## Prasyarat

1. **Flutter SDK** >= 3.19.0 — [Install Flutter](https://docs.flutter.dev/get-started/install)
2. **Android Studio** atau **VS Code** dengan Flutter extension
3. **Android SDK** (untuk build Android)
4. Untuk iOS build: macOS dengan Xcode

## Cara Menjalankan (lokal)

```bash
# 1. Masuk ke folder project
cd tokoku_app

# 2. Generate folder platform (android/, ios/) — hanya perlu sekali
flutter create . --project-name tokoku

# 3. Tambahkan izin Android (kamera + bluetooth) — lihat docs/android-permissions.md

# 4. Install dependencies
flutter pub get

# 5. Jalankan di emulator atau device
flutter run

# 6. Build APK (release)
flutter build apk --release
```

> **Catatan**: Folder `android/` dan `ios/` belum dibuat secara manual. Jalankan `flutter create .` untuk meng-generate folder platform secara otomatis sebelum `flutter run`.

## Build Online (tanpa install Flutter di komputer)

Jika Anda tidak mau install Flutter, gunakan build online — APK dihasilkan di cloud dan bisa diunduh langsung.

### Opsi A: GitHub Actions (gratis, disarankan)

1. Buat repository baru di [GitHub](https://github.com/new)
2. Upload seluruh isi folder `tokoku_app` ke repository (termasuk folder `.github/`)
3. Buka tab **Actions** → workflow **Build APK** akan otomatis jalan
4. Atau trigger manual: Actions → Build APK → **Run workflow**
5. Setelah selesai, unduh APK dari **Artifacts** → `tokoku-apk`

```bash
# Cara upload via git (di komputer Anda)
git init
git add .
git commit -m "TokoKu app"
git branch -M main
git remote add origin https://github.com/USERNAME/tokoku.git
git push -u origin main
```

### Opsi B: Codemagic (jalur alternatif)

Codemagic membaca `codemagic.yaml` dan menjalankan langkah yang **sama persis** dengan
GitHub Actions — termasuk `tools/ci_patch.py`, yang mengurus izin Android, `namespace`,
`compileSdk`, dan tanda tangan rilis. Jangan menambal Android secara manual di
`codemagic.yaml`; versi lama melakukannya sendiri dan lupa izin `INTERNET`, sehingga APK
hasilnya tidak akan pernah bisa aktivasi lisensi.

Sebelum build pertama, buat **Environment Group** bernama `tokoku` di
Codemagic → Environment variables, isi 4 variabel (semuanya ditandai *Secure*):

| Variabel | Isi |
|---|---|
| `KEYSTORE_BASE64` | seluruh isi `release-signing/keystore-base64.txt` |
| `KEYSTORE_PASSWORD` | seluruh isi `release-signing/storepass.txt` |
| `KEY_ALIAS` | `tokoku` |
| `KEY_PASSWORD` | seluruh isi `release-signing/storepass.txt` |

Kalau grup itu belum ada, build **gagal sejak awal** — disengaja, supaya tidak ada APK
debug key yang lolos tanpa disadari.

> **Catatan**: Untuk build lokal di komputer sendiri, izin Android perlu ditambahkan manual
> (lihat `docs/android-permissions.md`). Kedua jalur online di atas sudah otomatis.

## Arsitektur

```
lib/
├── main.dart                        # Entry point
├── app.dart                         # Root widget (MaterialApp.router)
├── core/
│   ├── constants/app_colors.dart    # Color palette (Teal primary, Amber accent)
│   ├── theme/app_theme.dart         # Material 3 theme
│   └── utils/formatters.dart         # Rupiah & date formatting
├── data/
│   ├── database/database_helper.dart # SQLite setup + seed data
│   ├── models/                      # User, Product, Sale, SaleItem
│   └── repositories/                # Auth, Product, Sale repositories
├── providers/                       # Riverpod state management
│   ├── auth_provider.dart           # Auth state (login/register/session)
│   ├── product_provider.dart        # Product list & filtering
│   ├── cart_provider.dart           # POS cart state
│   └── sale_provider.dart          # Sales + dashboard stats
├── routes/app_router.dart           # GoRouter with auth guards
├── shared/
│   ├── widgets/                     # Reusable widgets (bottom nav, cards)
│   └── services/                    # Receipt & Bluetooth printer services
└── features/                        # Screens
    ├── auth/                        # Login & Register
    ├── dashboard/                   # Beranda (Dashboard)
    ├── kasir/                       # Kasir (POS) + scan barcode + pilih printer
    ├── produk/                      # Produk management + form
    ├── stok/                        # Stok (Inventory)
    ├── laporan/                     # Laporan harian/mingguan/bulanan
    ├── hutang/                      # Piutang & hutang
    ├── catatan/                     # Catatan bebas
    ├── license/                     # Layar aktivasi lisensi
    └── profile/                     # Profile & settings

cloudflare/                          # Server aktivasi lisensi (Worker + D1)
├── src/index.js                     # API aktivasi + perutean
├── src/halaman-portal.js            # Portal aktivasi untuk pelanggan
├── src/halaman-admin.js             # Halaman admin untuk penjual
├── schema.sql                       # Tabel vouchers & licenses
└── README.md                        # Panduan pemasangan
```

## Alur Autentikasi Offline

1. **Registrasi pertama**: User daftar dengan email, password, dan nama toko. Data disimpan di SQLite lokal.
2. **Login**: Email & password divalidasi terhadap database lokal. Session disimpan di SharedPreferences.
3. **Offline**: Setelah login, semua operasi (penjualan, stok, laporan) bekerja tanpa internet.
4. **Kontrol akses**: Hanya email yang terdaftar yang bisa login. Password di-hash dengan SHA-256.

## Skema Database (SQLite)

Versi skema: **7**. Migrasi berjalan otomatis dan tidak menghapus data yang sudah ada — kolom baru selalu ditambahkan lewat `ALTER TABLE`, sedangkan tabel lama tidak pernah ditulis ulang.

| Table | Purpose |
|-------|---------|
| `users` | Akun dengan email, password hash, nama toko, telepon toko, path logo |
| `products` | Produk dengan nama, kategori, harga modal/jual, stok, satuan, dan path foto |
| `sales` | Transaksi dengan invoice number, total, laba, metode bayar, penanda hutang, potongan nota, **status** (`selesai`/`batal`), dan **alasan pembatalan** |
| `sale_items` | Line items per transaksi (product, qty, satuan saat terjual, subtotal setelah potongan, potongan baris) |
| `suppliers` | Data pemasok yang bisa diedit |
| `payment_methods` | Metode pembayaran yang bisa diaktifkan/dinonaktifkan |
| `debts` | Piutang pelanggan & hutang ke supplier (terhubung ke `sale_id` / `product_id`) |
| `debt_payments` | Riwayat pembayaran cicilan hutang |
| `notes` | Catatan bebas pemilik toko |
| `cash_transactions` | **Buku kas** — satu-satunya sumber saldo, uang masuk/keluar, dan arus kas |
| `expenses` | Beban usaha (listrik, sewa, gaji, dll.) |
| `prive` | Pengambilan uang toko oleh pemilik (bukan beban) |
| `stock_movements` | Riwayat pergerakan stok (masuk/keluar) beserta nilai belanjanya |

### Catatan laporan keuangan

Laporan keuangan dihitung dari data transaksi (**derived**), bukan jurnal
berpasangan. Untuk UMKM ini pilihan tersebut lebih jujur dan lebih mudah
dirawat: setiap laporan bisa ditelusuri balik ke transaksi aslinya.

Neraca selalu seimbang. Karena stok awal contoh tidak punya jurnal pembuka,
muncul satu baris penyeimbang bernama **"Modal awal & penyesuaian"** dengan
penjelasan di layar maupun di PDF — bukan ketidakseimbangan yang disembunyikan.

### Catatan potongan harga

Potongan **per barang** disimpan sudah terpotong di dalam
`sale_items.subtotal`, sedangkan potongan **seluruh nota** disimpan di
`sales.discount` dan mengurangi `sales.total_amount`. Dengan begitu berlaku
satu aturan yang dipegang seluruh laporan:

```
SUM(sale_items.subtotal) = sales.total_amount + sales.discount
```

Artinya semua laporan yang membaca `sales.total_amount` (pendapatan harian,
bulanan, buku kas) dan semua yang membaca `SUM(sale_items.subtotal)`
(produk terlaris, rincian produk terjual) **otomatis ikut benar** tanpa perlu
diubah. Yang harus ikut diubah hanyalah perhitungan **laba**, karena laba tidak
boleh dihitung dari harga label — potongan yang diberikan kasir adalah uang yang
tidak jadi masuk. Karena itu `sale_items.profit` dan seluruh query laba
memakai `subtotal - cost_price * quantity`, bukan `sell_price - cost_price`.

### Catatan pembatalan transaksi

Transaksi yang dibatalkan **tidak dihapus**. `sales.status` berubah jadi
`batal` dan akibatnya dibalik dengan catatan baru: stok masuk kembali lewat
`stock_movements`, uang yang pernah diterima keluar lagi lewat
`cash_transactions`, dan piutangnya dihapus. Semuanya dalam **satu transaksi
database** — kalau ada satu langkah yang gagal, tidak ada yang setengah jalan.

Supaya transaksi batal tidak ikut terhitung di laporan mana pun, ada dua view
di atas tabel `sales`:

| View | Isi | Dipakai oleh |
|------|-----|--------------|
| `sales_aktif` | Hanya transaksi berstatus `selesai` | **Seluruh laporan**, buku kas, dan daftar transaksi |
| `sales_semua` | Semua transaksi, termasuk yang dibatalkan | Cetak ulang struk, proses pembatalan itu sendiri, dan pencadangan data |

Aturannya sederhana: **tidak ada berkas di luar `database_helper.dart` yang
boleh membaca tabel `sales` langsung.** Dengan begitu transaksi batal hilang
dari semua laporan tanpa satu pun query laporan perlu ditulis ulang, dan query
laporan baru otomatis ikut benar.

Kolom `status` punya nilai awal `'selesai'` karena nota lama belum punya kolom
itu. Nilai awal itulah yang menentukan nasib seluruh riwayat penjualan yang
sudah ada — kalau salah, semua transaksi lama langsung hilang dari setiap
laporan tanpa galat apa pun. Karena itu nilainya dikunci oleh pemeriksa statis
dan diuji-negatif.

## Palet Warna

| Color | Hex | Usage |
|-------|-----|-------|
| Primary (Teal) | #0F6E56 | Primary actions, nav active |
| Accent (Amber) | #EF9F27 | Highlights, warnings |
| Success (Green) | #1D9E75 | Stock OK, positive trends |
| Warning (Amber) | #EF9F27 | Low stock |
| Danger (Red) | #E24B4A | Out of stock, errors |
| Info (Blue) | #378ADD | Info messages |

## Teknologi

- **Flutter** 3.x (cross-platform: Android & iOS)
- **Riverpod** — state management
- **GoRouter** — navigation with auth guards
- **sqflite** — local SQLite database (offline-first)
- **crypto** — SHA-256 password hashing
- **shared_preferences** — session persistence
- **esc_pos_utils** — ESC/POS thermal receipt generation
- **flutter_blue_plus** — Bluetooth connection to thermal printer
- **mobile_scanner** — barcode scanning (camera + ML Kit)
- **share_plus** — membuka menu "bagikan" Android untuk hasil ekspor
- **PDF buatan sendiri** — `lib/shared/services/pdf_builder.dart` menulis PDF
  langsung (PDF 1.4, font Helvetica base-14, tabel xref manual) tanpa pustaka
  tambahan. Ini disengaja: paket `pdf` versi apa pun butuh `image ^4.x`,
  sedangkan `esc_pos_utils` (printer termal) mengunci `image ^3.x` — keduanya
  tidak bisa dipasang bersamaan.
- **CSV** — UTF-8 dengan BOM dan pemisah `;` supaya langsung rapi di Excel
  berbahasa Indonesia.

## Pengujian tanpa Flutter

Beberapa bagian paling mudah salah tidak bisa diuji dengan menjalankan
aplikasinya (mis. saat mesin pengembangan tidak punya Flutter/Dart SDK).
Untuk itu ada skrip Python di `tools/` yang membaca sumber Dart apa adanya
dan menguji perilakunya dengan alat sungguhan:

```bash
python tools/uji-akuntansi.py    # 57 pemeriksaan - laporan keuangan vs SQLite
python tools/uji-pdf-metrik.py   # 25 pemeriksaan - metrik font & tata letak PDF
```

- **`uji-akuntansi.py`** — membuat skema v3 di SQLite sungguhan, menjalankan
  alur uang, lalu menguji identitas akuntansi (laba kotor, laba bersih, neraca
  seimbang, arus kas, HPP saat terjual, prive bukan beban).
- **`uji-pdf-metrik.py`** — mencocokkan tabel lebar Helvetica dan
  Helvetica-Bold dengan berkas AFM resmi Adobe, lalu memastikan teks tebal
  diukur dengan metrik yang benar dan teks panjang dilipat. Kesalahan di sini
  tidak menggagalkan build — akibatnya hanya tulisan terpotong saat dicetak.

## Lisensi & Aktivasi

Sistem jual lepas: **bayar sekali, 1 voucher = 1 HP**. Aktivasi butuh internet
sekali saja; setelah itu aplikasi berjalan penuh secara offline.

```
Pelanggan instal APK
  → aplikasi menampilkan Kode Perangkat (TK-XXXX-XXXX-XXXX)
  → pelanggan membeli Kode Voucher (VC-XXXX-XXXX-XXXX) dari penjual
  → pelanggan menukarnya di portal aktivasi (atau langsung di aplikasi)
  → menerima Kode Aktivasi (AK-XXXX-XXXX-XXXX) → aplikasi aktif
```

Server aktivasi berjalan di **Cloudflare Workers + D1** — paket gratisnya
100.000 permintaan/hari dan **tidak pernah dibekukan** karena lama tidak dipakai.

| Alamat | Untuk |
|---|---|
| `<alamat-worker>/` | Portal aktivasi pelanggan |
| `<alamat-worker>/admin` | Halaman admin penjual (butuh `ADMIN_KEY`) |

Alat bantu penjual:

```bash
python tools/buat-voucher.py --jumlah 10 --kelompok "Grosir-2026-09"
python tools/buat-voucher.py --ringkasan
```

Panduan lengkap: **[`cloudflare/README.md`](cloudflare/README.md)** (pemasangan)
dan **[`docs/panduan-jual-lisensi.md`](docs/panduan-jual-lisensi.md)** (cara jualan).

> Selama `activationServerUrl` di `lib/core/config/app_config.dart` masih berisi
> `ISI_...`, gerbang lisensi sengaja dimatikan supaya aplikasi bisa dicoba dan
> beranda menampilkan spanduk merah "Mode uji". **APK seperti itu belum layak dijual.**

## License

This is a private project for UMKM use.
