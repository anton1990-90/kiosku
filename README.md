# TokoKu — Aplikasi UMKM Toko Sembako & Penjualan (v1.2.0)

Aplikasi mobile cross-platform (Android & iOS) untuk toko sembako UMKM. Dibuat dengan Flutter, bekerja **offline-first** dengan autentikasi email.

## Fitur Utama

- **Offline-first**: Semua data tersimpan di perangkat (SQLite). Tidak butuh internet untuk jualan.
- **Autentikasi email**: Login dengan email & password. Akses penjualan dikendalikan sesuai email terdaftar.
- **Kasir (POS)**: Transaksi cepat dengan keranjang otomatis, pilihan metode pembayaran (tunai, QRIS, e-wallet), dan kalkulasi kembalian.
- **Scan barcode**: Scan barcode produk (EAN-13/UPC) langsung dari kamera — untuk menambah barang ke keranjang maupun mengisi barcode saat menambah produk baru.
- **Cetak struk thermal**: Cetak struk ke printer thermal Bluetooth 58mm/80mm setelah transaksi.
- **Manajemen produk**: Tambah, edit, hapus produk dengan kategori, harga modal & jual, barcode, dan stok. Supplier dipilih dari daftar yang bisa diedit.
- **Manajemen stok**: Visual progress bar, peringatan stok menipis & habis, restok mudah.
- **Laporan berkala**: Laporan **harian, mingguan, dan bulanan** dengan grafik, ringkasan laba, produk terlaris, dan **detail produk per item** lengkap dengan tanggal, waktu, harga, dan laba per transaksi.
- **Hutang & piutang**: Catat piutang pelanggan dan hutang ke supplier, cicilan pembayaran, riwayat bayar, serta peringatan jatuh tempo.
- **Catatan**: Catatan bebas berwarna untuk pemilik toko, bisa disematkan (pin).
- **Profile**: Logo usaha bisa diganti dari galeri, info toko, metode pembayaran yang bisa diaktifkan/dinonaktifkan, dan daftar supplier yang bisa diedit.
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

### Opsi B: Codemagic (gratis untuk project open-source)

1. Daftar di [Codemagic](https://codemagic.io) dengan akun GitHub
2. Tambahkan repository → pilih project
3. Codemagic otomatis membaca `codemagic.yaml`
4. Klik **Start build** → APK bisa diunduh setelah selesai

> **Catatan**: Kedua opsi di atas sudah otomatis menambahkan izin kamera & bluetooth ke AndroidManifest. Untuk build lokal, tambahkan izin manual (lihat `docs/android-permissions.md`).

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

Versi skema: **2**. Migrasi dari versi 1 berjalan otomatis dan tidak menghapus data yang sudah ada.

| Table | Purpose |
|-------|---------|
| `users` | Akun dengan email, password hash, nama toko, telepon toko, path logo |
| `products` | Produk dengan nama, kategori, harga modal/jual, stok |
| `sales` | Transaksi dengan invoice number, total, laba, metode bayar |
| `sale_items` | Line items per transaksi (product, qty, subtotal) |
| `suppliers` | Data pemasok yang bisa diedit |
| `payment_methods` | Metode pembayaran yang bisa diaktifkan/dinonaktifkan |
| `debts` | Piutang pelanggan & hutang ke supplier |
| `debt_payments` | Riwayat pembayaran cicilan hutang |
| `notes` | Catatan bebas pemilik toko |

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
