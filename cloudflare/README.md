# Server Aktivasi TokoKu — Cloudflare Worker + D1

> **Status: sudah diterbitkan.**
> Alamat: `https://tokoku-lisensi.dompetkuai.workers.dev`
> Database D1 `tokoku-lisensi` sudah dibuat dan `schema.sql` sudah dijalankan.
> Secret `ADMIN_KEY` sudah terpasang. Langkah di bawah disimpan untuk keadaan
> darurat — misalnya kalau server perlu dibuat ulang dari nol.
>
> **Belum terpasang:** tiga rahasia untuk pesanan otomatis —
> `ORDERHERO_WEBHOOK_SECRET`, `RESEND_API_KEY`, `EMAIL_DARI`. Selama ketiganya
> kosong, penjualan lewat OrderHero belum mengirim email; lihat bagian
> [Pesanan otomatis dari OrderHero](#pesanan-otomatis-dari-orderhero).

Folder ini berisi seluruh server aktivasi lisensi TokoKu: satu Worker yang
sekaligus menjadi **API aktivasi**, **portal pelanggan**, **halaman unduh APK**,
dan **halaman admin penjual**.

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

> **Kecuali** Anda ingin email voucher terkirim otomatis ke pembeli. Mengirim
> email butuh domain sendiri (alamat `*.workers.dev` tidak bisa jadi pengirim).
> Kalau belum punya domain, lewati saja dulu — pembuatan voucher otomatis tetap
> jalan, hanya emailnya yang dilewati.

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

> **Sudah punya database dari versi lama?** Jangan pakai `schema.sql` saja — kolom
> dan tabel baru tidak akan ikut masuk ke tabel yang sudah ada. Jalankan berkas
> migrasi di folder `migrasi/` secara berurutan, sekali masing-masing. Lihat
> bagian [Pesanan otomatis dari OrderHero](#pesanan-otomatis-dari-orderhero).

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
| `GET` | `/unduh` | Halaman unduh APK untuk pelanggan | — |
| `GET` | `/unduh/apk` | Berkas APK terbaru, dialirkan dari rilis GitHub | — |
| `GET` | `/api/versi` | Versi terbaru + alamat unduhnya | — |
| `GET` | `/admin` | Halaman admin penjual | — |
| `GET` | `/health` | Cek server hidup | — |
| `POST` | `/api/aktivasi` | Tukar voucher / aktifkan lisensi | — |
| `GET` | `/admin/data` | Ringkasan + daftar voucher, lisensi & pesanan | ✔ |
| `POST` | `/admin/vouchers` | Buat voucher baru | ✔ |
| `POST` | `/admin/kirim-email` | Kirim ulang email voucher ke pembeli | ✔ |
| `POST` | `/admin/reset` | Lepaskan lisensi dari HP lama | ✔ |
| `POST` | `/admin/revoke` | Nonaktifkan voucher / lisensi | ✔ |
| `POST` | `/webhook/orderhero` | Kabar pesanan lunas dari OrderHero | tanda tangan |

`GET /unduh/apk` juga menerima `HEAD` (dipakai aplikasi untuk membaca ukuran
berkas sebelum mengunduh) dan meneruskan header `Range`, sehingga unduhan 34 MB
yang terputus bisa dilanjutkan, bukan mengulang dari nol.

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

## Pesanan otomatis dari OrderHero

Kalau Anda berjualan di **OrderHero**, pelanggan tidak perlu menunggu Anda
mengirim kode secara manual. Begitu pembayaran dikonfirmasi, OrderHero memanggil
`POST /webhook/orderhero`; server membuat satu voucher baru dan **mengirimnya ke
email pembeli**. Anda tidak melakukan apa pun.

Alurnya:

```
Pelanggan bayar di OrderHero
   → OrderHero memanggil POST /webhook/orderhero
   → Worker memeriksa tanda tangan (HMAC-SHA256)
   → Worker membuat 1 voucher baru  → tercatat di tabel vouchers
   → Worker mengirim email berisi kode voucher + tautan unduh & portal
   → Anda bisa melihatnya di /admin (kolom "Pesanan")
```

### Yang membuat ini aman

- **Tanda tangan wajib.** Setiap panggilan membawa header
  `X-Webhook-Signature: t=<detik>,v1=<hex>`. Worker menghitung ulang
  HMAC-SHA256 atas `"<detik>.<badan permintaan mentah>"` memakai
  `ORDERHERO_WEBHOOK_SECRET`, lalu membandingkannya dengan waktu tetap
  (*constant time*). Tanda tangan salah → `401`.
- **Tolak yang kedaluwarsa.** Permintaan yang stempel waktunya lebih tua dari
  **300 detik** ditolak, supaya panggilan lama tidak bisa diputar ulang.
- **Idempoten.** OrderHero bisa mengirim ulang kabar yang sama. Setiap panggilan
  punya `X-Webhook-Delivery` yang unik; Worker mencatatnya di tabel
  `webhook_events` (kunci utama). Pengiriman ulang yang sama **tidak** membuat
  voucher kedua — jadi satu pembelian tetap satu voucher, tidak pernah dobel.
- **Tanpa rahasia, mati.** Kalau `ORDERHERO_WEBHOOK_SECRET` belum diisi, endpoint
  menjawab `500 not_configured` dan tidak membuat voucher apa pun.

### Langkah memasang (sekali saja)

**1. Punya domain sendiri untuk email.** Pengirim email tidak boleh memakai
alamat `*.workers.dev`. Beli satu domain (Rp 150–250rb/tahun), lalu daftarkan di
[Resend](https://resend.com) → **Domains → Add Domain** → salin record SPF dan
DKIM yang diberikan ke pengaturan DNS domain Anda. Tunggu sampai Resend
menandainya **Verified** (biasanya beberapa menit).

> Resend punya paket gratis **3.000 email/bulan, gratis selamanya**, tanpa perlu
> kartu kredit. Untuk penjualan ratusan lisensi per bulan itu lebih dari cukup.
> Kalau Anda tidak mau mengurus domain, lewati saja bagian email — vouchernya
> tetap dibuat otomatis, Anda tinggal mengirim kodenya manual.

**2. Isi tiga rahasia baru** (dari dalam folder `cloudflare/`):

```bash
npx wrangler secret put ORDERHERO_WEBHOOK_SECRET   # dari dashboard OrderHero
npx wrangler secret put RESEND_API_KEY             # dari Resend → API Keys
npx wrangler secret put EMAIL_DARI                 # mis. TokoKu <kode@domainanda.com>
```

`EMAIL_DARI` harus memakai domain yang sudah diverifikasi di langkah 1, dan
formatnya `Nama <alamat@domain>`. Kalau `RESEND_API_KEY` atau `EMAIL_DARI`
kosong, server tetap membuat voucher tapi emailnya dilewati — tercatat sebagai
`dilewati:email_belum_diatur` di `/admin`.

**3. Daftarkan alamat webhook di OrderHero.** Buka dashboard OrderHero →
**Plugin → Webhook**, lalu isi:

| Kolom | Isi |
|---|---|
| URL | `https://tokoku-lisensi.dompetkuai.workers.dev/webhook/orderhero` |
| Event | `order_paid` (wajib), `order_new` boleh ikut |
| Secret | salin nilai `whsec_...` yang ditampilkan, lalu pakai sebagai `ORDERHERO_WEBHOOK_SECRET` |

OrderHero akan mengirim percobaan (*test delivery*). Balasan `200` berarti
berhasil tersambung.

**4. Perbarui database kalau sudah pernah dipakai.** Database yang dibuat sebelum
23 September 2026 belum punya kolom email dan tabel `webhook_events`. Jalankan
sekali:

```bash
npx wrangler d1 execute tokoku-lisensi --remote --file=migrasi/2026-09-23-webhook.sql
```

> Kalau berkas ini dijalankan dua kali, muncul `duplicate column name` — **itu
> wajar**, bukan kerusakan. SQLite tidak punya `add column if not exists`, jadi
> barisnya memang akan menolak diulang. Tabel dan indeksnya tetap aman.

### Kalau email gagal terkirim

Voucher tetap dibuat — email yang gagal tidak boleh membuat pelanggan kehilangan
kode yang sudah dibayar. Kegagalannya tercatat di `/admin` pada kolom status
email (`gagal:<alasan>`), dan Anda bisa mengirim ulang:

```bash
curl -X POST "$TOKOKU_URL/admin/kirim-email" \
  -H "x-admin-key: $TOKOKU_ADMIN_KEY" \
  -d '{"delivery_id":"<id dari /admin>"}'
```

### Mencoba webhook tanpa menunggu pesanan sungguhan

```bash
BODY='{"event":"order_paid","data":{"customer":{"email":"uji@example.com","name":"Budi"},"id":"INV-1"}}'
TS=$(date +%s)
SIG=$(printf '%s' "$TS.$BODY" | openssl dgst -sha256 -hmac "$ORDERHERO_WEBHOOK_SECRET" -hex | awk '{print $2}')

curl -X POST "$TOKOKU_URL/webhook/orderhero" \
  -H "Content-Type: application/json" \
  -H "X-Webhook-Event: order_paid" \
  -H "X-Webhook-Delivery: uji-$TS" \
  -H "X-Webhook-Signature: t=$TS,v1=$SIG" \
  --data-raw "$BODY"
```

Kirim ulang perintah yang sama (dengan `X-Webhook-Delivery` yang sama) untuk
membuktikan idempotensi: panggilan kedua harus menjawab `duplicate` dan **tidak**
menambah voucher.

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
- `POST /webhook/orderhero` adalah satu-satunya endpoint publik yang **membuat**
  voucher. Pintu itu dijaga tanda tangan HMAC-SHA256 dengan batas waktu 300 detik
  dan pencatatan idempoten, jadi orang yang tahu alamatnya tetap tidak bisa
  membuat voucher tanpa `ORDERHERO_WEBHOOK_SECRET`.
- `ORDERHERO_WEBHOOK_SECRET`, `RESEND_API_KEY`, dan `EMAIL_DARI` hanya ada di
  Cloudflare (lewat `wrangler secret put`). Jangan pernah ditulis di repo ini.
- Email voucher **tidak pernah** memuat tautan GitHub — semua tautannya menunjuk
  ke server aktivasi Anda sendiri.
