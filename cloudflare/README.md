# Server Aktivasi TokoKu — Cloudflare Worker + D1

Folder ini berisi seluruh server aktivasi lisensi TokoKu: satu Worker yang
sekaligus menjadi **API aktivasi**, **portal pelanggan**, dan **halaman admin
penjual**.

## Kenapa Cloudflare, bukan Supabase

Proyek gratis Supabase **dibekukan** kalau tidak ada aktivitas database sekitar
7 hari. Untuk aplikasi jual lepas yang penjualannya tidak setiap hari, ini
sangat merepotkan — lisensi pelanggan bisa gagal diaktifkan hanya karena
servernya tidur.

Cloudflare Worker **tidak pernah dibekukan**. Kuota gratisnya juga lebih besar:

| | Cloudflare Workers (gratis) | Supabase (gratis) |
|---|---|---|
| Dibekukan kalau nganggur | **Tidak pernah** | Ya, setelah ± 7 hari |
| Kuota | 100.000 permintaan/hari | — |
| Database | D1 (SQLite), 5 GB | Postgres, 500 MB |
| Cocok untuk | Jual lepas, penjualan tidak rutin | Aplikasi yang dipakai harian |

---

## Yang perlu disiapkan

- Akun **Cloudflare** gratis — https://dash.cloudflare.com/sign-up
- **Node.js** 18 atau lebih baru (untuk menjalankan `wrangler`)

Tidak perlu kartu kredit. Tidak perlu beli domain.

---

## Pemasangan (sekali saja, ± 10 menit)

Semua perintah di bawah dijalankan dari dalam folder `cloudflare/`.

### 1. Pasang wrangler

```bash
cd cloudflare
npm install
```

### 2. Masuk ke akun Cloudflare

```bash
npx wrangler login
```

Browser akan terbuka dan meminta izin. Klik **Allow**.

### 3. Buat database

```bash
npx wrangler d1 create tokoku-lisensi
```

Perintah ini mencetak potongan konfigurasi berisi `database_id`. **Salin nilai
itu** ke `wrangler.toml`, ganti `GANTI_DENGAN_ID_DATABASE`.

### 4. Buat tabelnya

```bash
npx wrangler d1 execute tokoku-lisensi --remote --file=schema.sql
```

Aman dijalankan berulang kali.

### 5. Buat kunci admin

Kunci ini yang melindungi pembuatan voucher. Buat kunci acak yang panjang:

```bash
python -c "import secrets; print(secrets.token_urlsafe(32))"
```

Lalu simpan ke Cloudflare sebagai rahasia (tidak ikut tersimpan di repo):

```bash
npx wrangler secret put ADMIN_KEY
```

Tempel kunci tadi saat diminta. **Simpan kunci itu** di pengelola kata sandi —
Anda akan memakainya terus untuk membuat voucher.

### 6. Terbitkan

```bash
npx wrangler deploy
```

Wrangler akan mencetak alamat server Anda, bentuknya:

```
https://tokoku-lisensi.nama-anda.workers.dev
```

### 7. Sambungkan ke aplikasi

Buka `lib/core/config/app_config.dart` dan isi alamat tadi:

```dart
static const String activationServerUrl = 'https://tokoku-lisensi.nama-anda.workers.dev';
```

Simpan, commit, push. Build di GitHub Actions akan menerbitkan APK baru dengan
gerbang lisensi **aktif**.

> Kalau alamat ini masih berisi `ISI_...`, aplikasi sengaja dibiarkan terbuka
> tanpa aktivasi supaya bisa dicoba dulu. Beranda akan menampilkan spanduk
> merah "Mode uji" — selama spanduk itu ada, **jangan jual APK-nya**.

---

## Setelah terpasang

### Portal pelanggan

Buka alamat Worker di browser — itulah portalnya. Pelanggan memasukkan:

1. **Kode Perangkat** (dari aplikasi, berawalan `TK-`)
2. **Kode Voucher** (yang Anda jual, berawalan `VC-`)
3. Nama toko (boleh dikosongkan)

lalu menerima **Kode Aktivasi** (berawalan `AK-`) untuk diketik ke aplikasi.
Tidak ada langkah yang perlu Anda kerjakan.

### Halaman admin penjual

Buka `<alamat-worker>/admin`, masukkan `ADMIN_KEY`. Dari situ Anda bisa:

- melihat ringkasan stok voucher dan lisensi aktif
- membuat voucher baru sekaligus banyak
- memindahkan lisensi ke HP baru (tombol **Pindah HP**)
- menonaktifkan voucher atau lisensi

Kunci hanya disimpan di tab browser dan hilang saat tab ditutup.

### Membuat voucher dari terminal

Lebih cepat daripada membuka browser:

```bash
export TOKOKU_URL="https://tokoku-lisensi.nama-anda.workers.dev"
export TOKOKU_ADMIN_KEY="kunci-admin-Anda"

python tools/buat-voucher.py --jumlah 10 --kelompok "Grosir-2026-09"
python tools/buat-voucher.py --ringkasan          # lihat lisensi aktif
```

---

## Daftar endpoint

| Metode | Jalur | Untuk | Butuh kunci |
|---|---|---|---|
| `GET` | `/` | Portal pelanggan | — |
| `GET` | `/admin` | Halaman admin penjual | — |
| `GET` | `/health` | Cek server hidup | — |
| `POST` | `/api/aktivasi` | Tukar voucher / aktifkan lisensi | — |
| `GET` | `/admin/data` | Ringkasan + daftar voucher & lisensi | ✔ |
| `POST` | `/admin/vouchers` | Buat voucher baru | ✔ |
| `POST` | `/admin/reset` | Lepaskan lisensi dari HP lama | ✔ |
| `POST` | `/admin/revoke` | Nonaktifkan voucher / lisensi | ✔ |

`POST /api/aktivasi` menerima satu bentuk permintaan untuk dua keperluan:

```jsonc
// Isi "code" dengan Kode Voucher (VC-...) ATAU Kode Aktivasi (AK-...)
POST /api/aktivasi
{ "code": "VC-1A2B-3C4D-5E6F", "device_id": "TK-9Z8Y-7X6W-5V4U", "store_name": "Toko Siti Jaya" }
```

Jawaban berhasil:

```json
{ "ok": true, "activation_code": "AK-4M2P-8QRT-1WZX", "customer_name": "", "store_name": "Toko Siti Jaya" }
```

Jawaban gagal (selalu berstatus HTTP 200 supaya pesannya terbaca aplikasi):

```json
{ "ok": false, "reason": "used_on_other_device" }
```

Kemungkinan `reason`: `invalid_code`, `not_found`, `used_on_other_device`,
`revoked`, `device_code_entered`, `busy`, `server_error`, `bad_request`.

---

## Mencoba di komputer sendiri

Tidak perlu menyentuh server sungguhan:

```bash
cd cloudflare
npm install
npx wrangler d1 execute tokoku-lisensi --local --file=schema.sql
npx wrangler dev
```

Lalu buka `http://localhost:8787`. Untuk membuat kunci admin lokal, buat file
`.dev.vars` berisi:

```
ADMIN_KEY="kunci-uji-lokal"
```

`.dev.vars` sudah masuk `.gitignore` — jangan di-commit.

---

## Biaya

Semuanya masuk paket gratis:

- 100.000 permintaan per hari (aktivasi memakai 1 permintaan per pelanggan)
- D1: 5 GB penyimpanan, 5 juta baris dibaca per hari
- Tidak ada pembekuan, tidak ada masa kedaluwarsa

Untuk 10.000 pelanggan pun masih jauh di bawah batas gratis.

---

## Catatan keamanan

- `ADMIN_KEY` hanya ada di Cloudflare (lewat `wrangler secret put`) dan di
  komputer Anda. Jangan pernah ditulis di repo ini.
- Tabel voucher dan lisensi **tidak bisa dibaca publik**. Satu-satunya pintu
  masuk untuk pelanggan adalah `POST /api/aktivasi`, dan pintu itu hanya bisa
  menukar satu voucher menjadi satu lisensi.
- `GET /admin/data` mengirim daftar pembeli Anda, jadi jangan bagikan alamat
  `/admin` beserta kuncinya.
- Satu voucher hanya bisa ditukar sekali. Klaimnya dilakukan dengan satu
  perintah `UPDATE ... WHERE status = 'unused'`, jadi dua HP yang menekan tombol
  bersamaan tidak bisa dua-duanya berhasil.
