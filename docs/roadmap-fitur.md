# Roadmap Fitur TokoKu

Disusun 23 September 2026, berdasarkan pembacaan langsung kode di `lib/`
(pubspec saat itu: `1.11.0+17`, skema database versi 4, 14 tabel).

> **Catatan pemutakhiran.** Nomor skema di tiap usulan di bawah ditulis saat
> dokumen ini disusun, ketika versi skema masih 4 — jadi semuanya berbunyi
> "versi 5". Versi skema sekarang **10** (v1.17.0), dan usulan yang belum
> dikerjakan akan memakai versi berikutnya, bukan 5. Bagian yang sudah
> dikerjakan ditandai di judulnya.

Dokumen ini **hanya memuat yang belum ada**. Semua fitur di bagian
"Sudah ada — jangan diusulkan lagi" sudah terverifikasi ada di kode.

---

## Ringkasan prioritas

| Prioritas | Fitur | Usaha | Alasan singkat |
|---|---|---|---|
| 1 | Cetak ulang struk — **selesai v1.12.0** | Kecil | Datanya sudah ada, tinggal tombolnya |
| 2 | Batal / retur transaksi — **selesai v1.14.0** | Sedang | Sekarang salah input = permanen |
| 3 | Diskon per item / per nota — **selesai v1.13.0** | Sedang | Kebiasaan jualan sembako, belum bisa dicatat |
| 4 | Satuan produk (kg, liter, ikat) — **tahap A selesai v1.12.0** | Kecil | Struk "2" tidak jelas; salah tafsir |
| 5 | Data pelanggan tetap — **selesai v1.15.0** | Sedang | Piutang sekarang pakai teks bebas |
| 6 | Tutup kasir / hitung uang — **selesai v1.17.0** | Sedang | Kontrol harian kalau ada karyawan |
| 7 | Pembelian ke supplier | Besar | Menyambung stok masuk ↔ hutang |
| 8 | Akun kasir + hak akses — **selesai v1.16.0** | Besar | Dua peran: pemilik & kasir |
| — | Cetak label barcode | Besar | Hanya perlu kalau repack barang |
| — | Poin loyalitas | Sedang | Nilai kecil untuk toko sembako |
| — | Sinkronisasi multi-HP | Besar | **Bertentangan** dengan model 1 lisensi = 1 HP |

> Tabel di atas dan penanda **SELESAI** di judul tiap bagian sudah
> disamakan. Yang masih terbuka: bagian 4 tahap B dan bagian 7, sedangkan
> bagian 8 sengaja disisakan untuk izin per pengguna yang lebih rinci.

---

## 1. Cetak ulang struk — **SELESAI di v1.12.0**

**Kondisi sekarang.** `ReceiptService` hanya dipanggil di satu tempat:
`lib/features/kasir/kasir_screen.dart:135`. Begitu layar kasir ditutup,
struk hilang selamanya.

**Masalah nyata.** Printer kehabisan kertas, pelanggan minta salinan, atau
pelanggan komplain dua hari kemudian. Sekarang tidak ada cara mencetak ulang.

**Rancangan.** Semua data yang dibutuhkan sudah tersimpan di `sales` dan
`sale_items` — tidak perlu tabel baru. Tambahkan aksi "Cetak struk" pada
rincian transaksi di `transaksi_screen.dart`, lalu panggil
`ReceiptService.instance.generateReceipt(...)` dengan data transaksi lama.

**Usaha:** kecil. **Risiko:** rendah. **Skema:** tidak berubah.

---

## 2. Batal / retur transaksi — **SELESAI di v1.14.0**

**Kondisi sekarang.** `transaksi_screen.dart` bersifat baca saja — tidak ada
`onTap` pada baris, dan tidak ada `deleteSale` di seluruh `lib/`.
Satu salah tekan pada kasir merusak stok, kas, dan laporan **secara permanen**.

**Rancangan — jangan hapus baris.** Tambahkan kolom `status` pada `sales`
(`'selesai'` / `'dibatalkan'`) dan lakukan pembalikan, bukan penghapusan:

1. Stok dikembalikan lewat `stock_movements` bertipe masuk dengan
   `ref_type = 'batal_jual'`, `ref_id` = id penjualan.
2. Kas dibalik lewat `cash_transactions` dengan `ref_type`/`ref_id` yang sama.
3. Kalau `is_debt = 1`, hutang terkait ikut dibatalkan.
4. Laporan menyaring `status = 'selesai'`.

Tabel `stock_movements` dan `cash_transactions` sudah punya `ref_type` dan
`ref_id`, jadi pembalikan ini menyatu dengan desain yang ada.

**Penting:** pembatalan harus tercatat, bukan senyap. Kalau baris penjualan
bisa dihapus tanpa jejak, kasir bisa memakai itu untuk menyembunyikan
pengambilan uang.

**Usaha:** sedang. **Risiko:** sedang-tinggi — menyentuh laporan keuangan.
**Skema:** versi 7 (selesai).

---

## 3. Diskon per item / per nota — **SELESAI di v1.13.0**

**Kondisi sekarang.** Tidak ada satu pun kemunculan kata "diskon" atau
"discount" di `lib/`. `sales` tidak punya kolom potongan.

**Masalah nyata.** "Beli 2 kurang 500", "borongan diskon 5%", "harga teman" —
semuanya tidak bisa dicatat. Pemilik akhirnya mencatat harga palsu supaya
total cocok, dan laporan laba jadi salah.

**Rancangan.** Tambahkan `discount` pada `sales` (potongan nota) dan pada
`sale_items` (potongan baris). `total_amount` dan `total_profit` dihitung
setelah potongan. Tampilkan potongan di struk dan di laporan.

**Usaha:** sedang. **Risiko:** sedang — mengubah arti `total_profit`.
**Skema:** versi 6 (selesai).

---

## 4. Satuan produk (kg, liter, ikat, pcs) — **Tahap A SELESAI di v1.12.0; Tahap B belum**

**Kondisi sekarang.** Tabel `products` tidak punya kolom satuan, dan
`produk_form_screen.dart` tidak punya isian satuan. Jumlah hanya angka.

**Masalah nyata.** Toko sembako menjual gula per kg, minyak per liter, sayur
per ikat. Struk bertuliskan "2" tidak memberi tahu apa-apa.

**Rancangan dua tahap — jangan digabung.**

*Tahap A (kecil, aman).* Tambahkan kolom `unit TEXT DEFAULT 'pcs'`, isian di
form produk, dan tampilkan di struk/laporan sebagai "2 kg" bukan "2".
Hanya label; perhitungan tidak berubah.

*Tahap B (besar, pisah rilis).* Izinkan jumlah pecahan (0,5 kg). Ini
mengubah `quantity INTEGER` menjadi `REAL` di `sales`, `sale_items`, dan
`stock_movements`, plus seluruh aritmetika stok dan laporan. **Kerjakan
sebagai rilis tersendiri**, jangan digabung dengan fitur lain, karena
kesalahan pembulatan di sini langsung merusak laporan.

**Usaha:** A kecil, B besar. **Skema:** Tahap A versi 5 (selesai).
Tahap B menunggu versi 10 dan mengubah `quantity INTEGER` menjadi `REAL`
di `sales`, `sale_items`, dan `stock_movements` — kerjakan sebagai rilis
tersendiri, seperti catatan di atas.

---

## 5. Data pelanggan tetap — **SELESAI di v1.15.0**

**Kondisi sekarang.** Sudah ada tabel `customers` (nama, telepon, alamat,
catatan) beserta layar "Pelanggan" di menu Profil. `debts.customer_id` dan
`sales.customer_id` mengaitkan catatan dan nota ke buku pelanggan, sementara
`sales.customer_name` dan `debts.party_name` tetap menyimpan nama apa adanya
sebagai rekaman saat transaksi terjadi.

**Masalah yang dulu ada.** "Bu Ani", "bu ani", dan "Ani" tercatat sebagai tiga
orang berbeda. Pertanyaan "berapa total hutang Bu Ani?" tidak bisa dijawab
dengan yakin — padahal piutang adalah fitur yang sudah ada dan dipakai.

**Yang dikerjakan.** Nama pelanggan dari catatan piutang lama dipindahkan
sekali saat migrasi (nama cadangan `'Pelanggan'` sengaja dilewati), pengaitannya
dilakukan berdasarkan nama di dalam transaksi penyimpanan, dan daftar
pelanggannya menampilkan sisa piutang serta total belanja per orang.

Nilai tambah setelah ini tinggal: harga khusus pelanggan tetap.

**Usaha:** sedang. **Skema:** versi 8 (selesai).

---

## 6. Tutup kasir / hitung uang — **SELESAI di v1.17.0**

**Kondisi sekarang.** Tabel `cash_sessions` menyimpan setiap sesi kasir:
saldo awal, siapa yang membuka, saldo akhir menurut sistem, uang fisik yang
dihitung, selisihnya, siapa yang menutup, dan catatan. Layar `/kas/tutup`
menjalankan ritualnya dua langkah, dan setiap penjualan menyimpan
`sales.session_id` sesi yang sedang terbuka.

**Masalah yang dulu ada.** Begitu toko punya karyawan, ini kontrol harian yang
paling penting. Tanpa ini, selisih kas baru ketahuan berbulan-bulan
kemudian dan tidak bisa ditelusuri ke siapa.

**Yang dikerjakan.** Skema v10: tabel `cash_sessions` + kolom
`sales.session_id`. Dua angka yang dibandingkan (`opening_balance` dan
`expected_closing`) sama-sama dibaca dari `CashRepository.getSaldo()` supaya
"seharusnya di laci" tidak pernah berbeda dari saldo yang dilihat kasir di
Buku Kas. Selisih bukan nol **wajib** bercatatan, dan hanya satu sesi boleh
terbuka dalam satu waktu. Rutenya (`/kas` dan `/kas/tutup`) sengaja terbuka
untuk kasir maupun pemilik — yang menghitung uang adalah orang yang memegang
lacinya — sementara Laporan dan Laporan Keuangan tetap tertutup untuk kasir.

**Usaha:** sedang. **Skema:** versi 10 (versi 9 dipakai akun kasir).

---

## 7. Pembelian ke supplier (PO → terima barang → hutang)

**Kondisi sekarang.** Sebagian sudah ada: stok masuk beserta harga pokok
tercatat di `stock_movements`, dan `debts` sudah punya `supplier_id`.

**Yang belum.** Alur resmi: buat pesanan → terima barang (boleh sebagian) →
stok dan hutang otomatis menyesuaikan. Sekarang stok masuk dan hutang
dicatat terpisah, jadi rawan tidak sinkron.

**Usaha:** besar. **Skema:** versi 5 (tabel pesanan + baris pesanan).

---

## 8. Akun kasir + hak akses — **SELESAI di v1.16.0**

**Kondisi sekarang.** Tabel `users` menyimpan banyak akun, masing-masing
dengan peran **Pemilik** atau **Kasir** dan penanda aktif. Pemilik mengelola
akun karyawannya dari **Profil → Pengguna**.

**Masalah yang dulu ada.** Pemilik mungkin ingin karyawan bisa menjual tetapi
**tidak** bisa melihat laba, neraca, atau prive. Dulu tidak ada pilihan
selain memberikan akses penuh.

**Yang dikerjakan.** Kolom `role` dan `is_active` pada `users` (skema v9),
layar Pengguna, dan pembatas rute di `app_router.dart` — kasir yang membuka
rute laporan atau pengaturan dikembalikan ke Beranda. Akun **tidak pernah
dihapus** (nota lama harus tetap punya pemiliknya), hanya dinonaktifkan, dan
toko selalu dipaksa menyisakan satu pemilik aktif.

**Yang sengaja belum.** Izin per pengguna yang lebih rinci daripada
pemilik/kasir, dan PIN per akun — PIN masih milik perangkat, jadi PIN yang
sama membuka aplikasi untuk siapa pun yang memegang HP itu. Selama itu
belum berubah, pemisahan kasir berguna untuk mencegah **salah lihat dan
salah ubah** oleh orang yang memegang HP, bukan untuk menahan orang yang
sengaja ingin membuka.

**Usaha:** besar. **Risiko:** tinggi — menyentuh autentikasi. **Skema:**
versi 9 (selesai).

---

## Nilai kecil, kerjakan kalau ada waktu

- **Kategori jadi data tetap.** `products.category` masih teks bebas, jadi
  "Minuman" dan "minuman" bisa terpisah di laporan. Jadikan tabel tersendiri
  seperti `suppliers`.
- **Footer struk bisa diubah.** Teks "Terima kasih atas kunjungan Anda!"
  masih tertulis tetap di `receipt_service.dart` (baris 171 dan 359).
- **Mode gelap.** Belum ada `darkTheme`/`ThemeMode` sama sekali.

---

## Jangan dikerjakan (atau tunggu)

- **Sinkronisasi multi-HP / cloud.** Model bisnisnya 1 lisensi = 1 HP.
  Sinkronisasi akan membatalkan alasan pelanggan membeli lisensi kedua.
  Kalau kebutuhannya "pemilik ingin memantau dari rumah", jawaban yang benar
  bukan sinkronisasi, melainkan **ringkasan harian yang dikirim otomatis**
  (WhatsApp/email saat tutup kasir). Itu perlu domain + Resend — lihat
  bagian bawah.
- **Poin loyalitas.** Nilai kecil untuk toko sembako; pelanggan kembali
  karena harga dan kedekatan, bukan karena poin.
- **Cetak label barcode sendiri.** Hanya berguna kalau pemilik melakukan
  repack (gula 1 kg, tepung). Belum tentu dibutuhkan semua pembeli.

---

## Sudah ada — jangan diusulkan lagi

Terverifikasi ada di kode, supaya tidak diusulkan ulang:

- Kasir: keranjang, multi metode bayar, hitung kembalian, scan barcode
- Struk: printer termal Bluetooth, pilihan printer
- Produk: CRUD, barcode, emoji, stok minimum, supplier
- Stok: penambahan/pengurangan, riwayat pergerakan, peringatan stok menipis
- Laporan: harian/mingguan/bulanan, grafik, rincian per barang
- Laporan keuangan: laba rugi, perubahan ekuitas, neraca, arus kas
- Ekspor: PDF (pembuat sendiri, tanpa paket `pdf`) dan CSV
- Kas, beban operasional, prive
- Piutang & hutang dengan cicilan, **termasuk penanda jatuh tempo**
  (`DebtModel.isJatuhTempo`)
- Data supplier yang bisa diedit
- Metode pembayaran yang bisa diaktifkan/dinonaktifkan, info QRIS & rekening
- Catatan berwarna dengan pin
- Profil toko: nama, alamat, telepon, logo
- Cadangan & pemulihan JSON, termasuk cadangan otomatis
- Kunci PIN, lupa password lewat kode aktivasi (offline)
- Gerbang lisensi, aktivasi, pemberitahuan pembaruan
- Pusat bantuan

---

## Tiga hal non-fitur yang lebih mendesak daripada fitur apa pun

1. **Cadangkan folder `release-signing` ke dua tempat.** Masih belum
   tercentang di `docs/panduan-jual-lisensi.md`. Kalau kunci tanda tangan
   hilang, **tidak akan pernah bisa merilis pembaruan** untuk pelanggan yang
   sudah membeli — mereka harus memasang ulang dan kehilangan seluruh data.
   Ini risiko terbesar di seluruh proyek, lebih besar dari fitur apa pun.
2. **Cabut lisensi percobaan setelah masa uji selesai.** Lisensi uji
   bersifat permanen dan tidak akan kedaluwarsa sendiri.
3. **`README.md` sudah usang** — judulnya masih menyebut v1.3.0, padahal
   pubspec sekarang `1.11.0+17`.

**Terhambat pada Anda:** beli domain lalu pasang SPF/DKIM, supaya email
voucher otomatis dan ringkasan harian bisa jalan. Belum ada yang bisa
dikerjakan di sisi kode sebelum domain siap.

---

## Catatan teknis untuk pengerjaan nanti

Semua usulan di atas menambah tabel/kolom, jadi **satu migrasi skema versi 5**
dapat menampung prioritas 2–6 sekaligus. Namun sebaiknya **jangan digabung
dalam satu rilis** — masing-masing menyentuh perhitungan uang. Urutan yang
disarankan: 1 → 4A → 3 → 2 → 5 → 6.

Ingat jebakan yang sudah pernah menggigit proyek ini:

- Tinggi kartu grid memakai `mainAxisExtent`, bukan `childAspectRatio`
  (terpotong diam-diam di HP sempit).
- `ColorScheme.fromSeed` tidak mengembalikan warna benih — harus `copyWith`.
- `scrolledUnderElevation: 0`, bukan `elevation: 0`, untuk mematikan warna
  AppBar saat digulir.
- Berkas di repo ini campur akhiran baris (LF dan CRLF) — sunting lewat
  skrip, jangan tulis ulang seluruh berkas.
- Setiap asersi pemeriksa baru **wajib diuji-negatif**, dan jalankan
  `checkers/gate-rilis.py` sebelum commit.
