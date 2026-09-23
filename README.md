# TokoKu — Aplikasi UMKM Toko Sembako & Penjualan (v1.17.0)

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
- **Beranda**: Tombol aksi cepat berikon untuk hal yang paling sering dipakai — Transaksi, Tambah Stok, Laporan, Laporan Keuangan, Hutang & Piutang, Cetak Ulang Struk, Buku Kas, **Buka/Tutup Kasir**, dan Catatan. Tombol kasir itu berubah sendiri mengikuti keadaan: menulis "Buka Kasir" kalau belum ada sesi, dan "Tutup Kasir" kalau sesi sedang berjalan.
- **Manajemen produk**: Tambah, edit, hapus produk dengan kategori, harga modal & jual, barcode, dan stok. Supplier dipilih dari daftar yang bisa diedit. **Ikon produk bisa memakai foto dari galeri HP**, dan setiap produk punya **satuan** (pcs, kg, liter, ikat) supaya struk menulis "2 kg" dan bukan sekadar "2".
- **Manajemen stok**: Visual progress bar, peringatan stok menipis & habis, restok mudah. Daftar produk bisa langsung diklik untuk restok, dan kartu "stok menipis" di beranda membuka rincian produk yang perlu ditambah.
- **Laporan berkala**: Laporan **harian, mingguan, dan bulanan** dengan grafik, ringkasan laba, produk terlaris, dan **detail produk per item** lengkap dengan tanggal, waktu, harga, dan laba per transaksi.
- **Rincian produk terjual**: Maksimal 5 baris di layar Laporan, lalu "Lihat semua" membuka rincian lengkap yang bisa difilter harian/mingguan/bulanan, menampilkan total pendapatan beserta labanya, dan bisa **diekspor ke PDF & CSV**.
- **Kas**: Satu buku kas untuk semua uang masuk & keluar. Beranda menampilkan saldo kas di tengah, uang keluar di kiri bawah, uang masuk di kanan bawah. Setiap penjualan, pembayaran hutang/piutang, restok, beban, dan prive tercatat otomatis — plus riwayat lengkap dan pencatatan manual.
- **Tutup kasir (hitung uang)**: Sebelum tutup toko, kasir menghitung uang fisik di laci dan aplikasi membandingkannya dengan catatan sistem. Selisihnya ditampilkan lebih/kurang **sebelum** disimpan, dan kalau tidak cocok **wajib** diisi penjelasannya. Setiap sesi mencatat siapa yang membuka, siapa yang menutup, saldo awal, jumlah seharusnya, uang fisik, dan selisihnya — jadi uang yang tidak cocok tidak pernah hilang diam-diam. Transaksi yang terjadi selama sesi ikut terhitung ke sesi itu.
- **Laporan keuangan standar akuntansi**: **Laba rugi**, **perubahan ekuitas**, **neraca**, dan **arus kas**, semuanya bisa diekspor ke PDF & CSV. Ada juga pencatatan **beban usaha** dan **prive** (pengambilan pemilik).
- **Hutang & piutang**: Catat piutang pelanggan dan hutang ke supplier, cicilan pembayaran, riwayat bayar, serta peringatan jatuh tempo. Terhubung ke stok produk: restok yang belum dibayar penuh otomatis jadi hutang supplier, dan transaksi yang belum dibayar penuh jadi piutang pelanggan (dengan ceklist "Transaksi ini hutang?" di layar kasir).
- **Data pelanggan**: Buku pelanggan yang bisa ditambah, diedit, dan dihapus — nama, nomor HP, alamat, dan catatan. Tiap pelanggan menampilkan **sisa piutang** dan **total belanjanya**, dan nomor HP-nya bisa langsung dibuka di WhatsApp. Piutang dari nota kasir maupun yang dicatat manual otomatis terhubung ke pelanggannya, dan nama yang belum ada di buku akan ditambahkan sendiri. Nama pelanggan tetap terekam apa adanya di setiap nota, jadi mengganti namanya **tidak mengubah struk dan laporan yang sudah terbit** — dan menghapus pelanggan **tidak menghapus riwayat transaksinya**.
- **Catatan**: Catatan bebas berwarna untuk pemilik toko, bisa disematkan (pin).
- **Profile**: Logo usaha bisa diganti dari galeri, info toko, metode pembayaran yang bisa diaktifkan/dinonaktifkan, daftar supplier dan **daftar pelanggan** yang bisa diedit, serta pintasan ke **Kas** dan **Laporan Keuangan**.
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

Versi skema: **10**. Migrasi berjalan otomatis dan tidak menghapus data yang sudah ada — kolom baru selalu ditambahkan lewat `ALTER TABLE`, sedangkan tabel lama tidak pernah ditulis ulang.

| Table | Purpose |
|-------|---------|
| `users` | Akun dengan email, password hash, nama toko, telepon toko, path logo |
| `products` | Produk dengan nama, kategori, harga modal/jual, stok, satuan, dan path foto |
| `sales` | Transaksi dengan invoice number, total, laba, metode bayar, penanda hutang, potongan nota, **status** (`selesai`/`batal`), **alasan pembatalan**, penghubung `customer_id`, dan penghubung `session_id` ke sesi kasir |
| `sale_items` | Line items per transaksi (product, qty, satuan saat terjual, subtotal setelah potongan, potongan baris) |
| `suppliers` | Data pemasok yang bisa diedit |
| `customers` | **Buku pelanggan** — nama, nomor HP, alamat, catatan yang bisa diedit |
| `payment_methods` | Metode pembayaran yang bisa diaktifkan/dinonaktifkan |
| `debts` | Piutang pelanggan & hutang ke supplier (terhubung ke `sale_id` / `product_id` / `customer_id`) |
| `debt_payments` | Riwayat pembayaran cicilan hutang |
| `notes` | Catatan bebas pemilik toko |
| `cash_transactions` | **Buku kas** — satu-satunya sumber saldo, uang masuk/keluar, dan arus kas |
| `cash_sessions` | **Sesi kasir** — saldo awal, siapa membuka/menutup, uang seharusnya, uang fisik, selisih, catatan, status |
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

### Catatan buku pelanggan

`customers` menyimpan identitas pelanggan: nama, nomor HP, alamat, dan catatan.
Ia menjawab dua pertanyaan yang sebelumnya tidak bisa dijawab aplikasi ini:
**siapa saja yang masih berhutang**, dan **bagaimana cara menghubunginya**.
Sebelum v1.15.0 nama pelanggan hanya tersimpan sebagai teks bebas di tiap
catatan piutang, sehingga "Bu Siti" dan "bu siti" tampak seperti dua orang yang
berbeda dan nomor HP-nya tidak tersimpan di mana pun.

`debts.customer_id` dan `sales.customer_id` hanyalah **penghubung**. Nama
pelanggan tetap disimpan apa adanya di `debts.party_name` dan
`sales.customer_name` — perlakuan yang sama dengan `sale_items.unit` yang
menyimpan satuan saat barang terjual. Jadi **mengganti nama pelanggan tidak
mengubah struk, riwayat, dan laporan yang sudah terbit**, dan tidak ada berkas
di luar `customer_repository.dart` yang boleh membaca nama pelanggan lewat
`FROM customers`. Aturan itu dikunci oleh pemeriksa statis dan diuji-negatif.

Nama cadangan `'Pelanggan'` untuk pembeli tanpa nama **tidak** ikut dipindahkan
ke buku pelanggan: kalau ikut, semua pembeli tanpa nama akan menumpuk jadi satu
pelanggan palsu. Nilainya ditulis di satu tempat saja
(`DatabaseHelper.namaPelangganUmum`).

Pengaitannya dilakukan berdasarkan **nama yang diketik**, di dalam transaksi
penyimpanan yang sama dengan nota atau catatan piutangnya — bukan dari pilihan
dropdown, yang bisa tertinggal kalau namanya diubah setelah memilih. Nama yang
belum ada di buku pelanggan akan ditambahkan otomatis, sehingga bukunya terisi
dari pemakaian sehari-hari.

**Menghapus pelanggan tidak menghapus riwayatnya.** Penghubungnya dikosongkan
di `debts` dan `sales`, lalu barisnya dihapus — riwayat penjualan dan piutang
adalah catatan uang, bukan data pelanggan. Buku pelanggan juga ikut
dicadangkan (`BackupService.tabelCadangan`) dan ikut dikosongkan saat
memulihkan, dengan urutan yang sama persis dengan "Reset semua data".

### Catatan tutup kasir

Sesi kasir menjawab satu pertanyaan yang paling sering ditanyakan pemilik toko
di penghujung hari: **"uang di laci kok tidak sama dengan catatan?"** Sebelum
v1.17.0 aplikasi ini tahu berapa saldo menurut sistem, tetapi tidak pernah
menyimpan berapa uang yang benar-benar dihitung orang.

Alurnya dua langkah. Kasir membuka sesi — saldo awal dicatat otomatis dari
saldo sistem, bukan diketik — lalu di akhir hari menutupnya dengan mengetik
jumlah uang fisik yang ia hitung. Aplikasi menampilkan selisihnya **lebih
dulu** — lebih atau kurang sekian — baru menyimpannya.

Dua angka yang dibandingkan sengaja diambil dari **sumber yang sama**, yaitu
`CashRepository.getSaldo()`:

| Kolom | Isi | Sumber |
|-------|-----|--------|
| `opening_balance` | Saldo kas saat sesi dibuka | `CashRepository.getSaldo()` |
| `expected_closing` | Saldo kas saat sesi ditutup | `CashRepository.getSaldo()` |

Itu disengaja: angka "seharusnya ada di laci" tidak boleh pernah berbeda dari
saldo yang dibaca kasir di layar Buku Kas. Kalau keduanya dihitung dengan cara
berbeda, satu-satunya hasilnya adalah kasir yang berdebat dengan aplikasinya
sendiri. Karena itu `opening_balance` **tidak** bisa diberi nilai awal di
skema: nilai awal SQLite tidak boleh mengacu ke kolom atau tabel lain, jadi
`bukaSesi()` yang membacanya. Kolom `expected_closing` dan `opening_balance`
juga berarti saldo itu **sudah termasuk** uang awal — ia tidak boleh
ditambahkan lagi saat membandingkan.

`difference = counted_cash - expected_closing`. Nilai **negatif berarti uang
kurang**, positif berarti lebih. Kalau selisihnya bukan nol, catatan
**wajib** diisi sebelum tombol simpan bekerja — tanpa itu, uang yang tidak
cocok bisa hilang tanpa satu pun penjelasan tertulis. Untuk alasan yang sama,
sesi yang masih terbuka tidak boleh ada dua: `bukaSesi()` menolak membuka sesi
baru selama sesi sebelumnya belum ditutup, dan penolakan itu terjadi **di dalam
transaksi database** supaya dua orang yang menekan tombol hampir bersamaan
tidak bisa menciptakan dua sesi terbuka.

Setiap penjualan menyimpan `sales.session_id` sesi yang sedang terbuka, dibaca
`SaleRepository.createSale` sendiri lewat `CashSessionRepository.idSesiAktif()`
— **bukan** diserahkan ke pemanggil. Kalau pemanggil yang harus mengirimnya,
satu tempat yang lupa akan membuat nota itu hilang dari rekap sesi tanpa satu
pun galat muncul. Nota yang dibuat saat tidak ada sesi terbuka tetap sah;
`session_id`-nya kosong.

Sesi kasir ikut dicadangkan (`BackupService.tabelCadangan`) dan ikut
dikosongkan saat memulihkan, dengan urutan yang sama persis dengan "Reset semua
data". Kolom `status` punya nilai awal `'open'`, dan seperti `sales.status`,
nilai awal itu adalah baris paling berbahaya di rilis ini: salah nilai berarti
seluruh riwayat sesi lenyap dari daftar tanpa galat apa pun — karena itu ia
dikunci oleh pemeriksa statis dan diuji-negatif.

### Akun kasir dan hak akses

Sampai v1.15.0 aplikasi ini hanya mengenal satu akun, dan akun itu adalah
pemilik toko. Begitu toko punya karyawan, pilihan yang ada cuma satu:
memberikan akses penuh. Sejak v1.16.0 ada dua peran — **Pemilik** dan
**Kasir** — dan pemilik bisa menambah, menonaktifkan, dan mengganti password
akun karyawannya dari **Profil → Pengguna**.

**Kolomnya, dan kenapa nilainya penting.** Skema v9 menambahkan
`users.role` (`'owner'` / `'kasir'`) dan `users.is_active`. Nilai awalnya
`'owner'` dan `1`, dan itu **load-bearing**: setiap pemasangan yang sudah ada
memperbarui aplikasi lewat `ALTER TABLE`, sehingga seluruh baris lama
mendapat nilai awal itu. Kalau nilai awalnya `'kasir'`, seluruh toko yang
memperbarui aplikasi kehilangan akses ke pengaturan, laporan, dan layar
Pengguna sekaligus — tanpa galat, tanpa peringatan, dan **tanpa cara
memperbaikinya dari dalam aplikasi**, karena yang boleh mengangkat pemilik
adalah pemilik. Pemeriksa statis mengunci arah nilai awalnya.

**Akun tidak pernah dihapus.** `sales.user_id` punya kunci asing ke
`users.id`, jadi menghapus akun akan membuang pemilik nota-nota lama — nota
yang justru bukti uang masuk. Yang tersedia adalah **menonaktifkan**: akun
nonaktif tidak bisa masuk (pesannya jelas, bukan "password salah"), namanya
tetap menempel di riwayat, dan bisa diaktifkan lagi kapan saja. Karena itu
tidak ada satu pun `DELETE FROM users` di seluruh `lib/`.

**Toko tidak boleh kehilangan pemilik aktif terakhir.** Menurunkan peran
pemilik terakhir menjadi kasir, atau menonaktifkannya, akan mengunci
pengelolaan akun selamanya — aplikasinya tetap berjalan normal, yang hilang
adalah kemampuan mengelolanya. Kedua tindakan itu ditolak di lapisan data
(`AuthRepository`), bukan hanya disembunyikan di layar, karena aturannya
menyangkut keadaan data.

**Router adalah penjaganya, bukan tampilan.** Kasir yang mengetik alamat
`/laporan` atau `/profile/toko` dikembalikan ke Beranda. Daftar rute pemilik
ada di `app_router.dart` dan **menutup** rute yang disebut di dalamnya;
`/stok/menipis` sengaja dikecualikan karena kasir memang perlu tahu barang
apa yang habis. Menyembunyikan tombol di dasbor dan menu Profil hanya
polesan — yang menentukan adalah pengalihan rutenya.

**Kasir boleh membuka Buku Kas dan menutup kasir.** Dua rute itu — `/kas` dan
`/kas/tutup` — sengaja **tidak** ada di daftar rute pemilik. Yang menghitung
uang di laci adalah orang yang memegang lacinya, jadi menutupnya dari layar
pemilik justru memindahkan pekerjaan orang yang tidak memegang uangnya. Yang
tetap tertutup untuk kasir adalah **Laporan** dan **Laporan Keuangan**: kasir
cukup tahu saldo kas dan selisih laci sesinya sendiri, bukan laba dan neraca
toko. Karena itu `/kas/tutup` juga hanya bisa dibuka kasir dan pemilik —
aturannya ditegakkan di router, bukan dengan menyembunyikan tombol.

**Akun pertama adalah pemilik.** Pendaftaran mandiri hanya terbuka pada
pemasangan baru; begitu ada akun, rute `/auth/register` ditutup dan akun
berikutnya hanya bisa dibuat pemilik dari layar Pengguna, bawaannya **kasir**.
Arah itu dipilih dengan sengaja: salah menebak ke arah kasir hanya membuat
satu akun kurang berkuasa dan pemilik bisa memperbaikinya, sedangkan salah
menebak ke arah pemilik memberi akses penuh kepada orang yang tidak berhak.

**Profil toko milik toko, bukan milik akun.** Menyimpan nama toko, logo,
QRIS, atau rekening bank menulis ke **seluruh** baris `users` — kalau tidak,
kasir akan mencetak struk dengan nama dan logo toko yang basi. Penyimpanan
itu sekaligus mempertahankan `role` dan `is_active` akun yang sedang dipakai,
sehingga menyimpan profil toko tidak pernah bisa diam-diam mengangkat kasir
menjadi pemilik atau mengaktifkan kembali akun yang dinonaktifkan.

**Hash password tidak ikut dicadangkan.** Tabel `users` sengaja **tidak**
masuk `BackupService.tabelCadangan`: berkas cadangan dibuka dan dibagikan
pengguna sebagai Excel/JSON, dan hash password tidak ada urusannya di sana.

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
