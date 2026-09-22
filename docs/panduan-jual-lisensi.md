# Panduan Jual Lepas TokoKu — 1 Lisensi = 1 HP

Sistem: **bayar sekali, pakai selamanya.** Setiap pembelian mendapat satu Kode
Aktivasi yang hanya bisa dipakai di **satu HP**. Aktivasi butuh internet sekali;
setelah itu aplikasi jalan penuh secara offline.

---

## Status saat ini (per 22 September 2026)

Kode sudah selesai dan build sudah **hijau** di GitHub Actions. Yang masih
kurang hanya dua hal di bawah ini — keduanya belum bisa dikerjakan tanpa data
dari Anda.

| Bagian | Status |
|---|---|
| Kode lisensi + aktivasi + cek pembaruan | Selesai, sudah di-commit & build sukses |
| Fitur hutang, catatan, laporan harian/mingguan/bulanan, scan barcode, profil toko | Selesai — versi **1.1.1** |
| APK bisa diunduh | Selesai — [tautan rilis terbaru](https://github.com/anton1990-90/kiosku/releases/latest/download/app-release.apk) |
| **Kunci tanda tangan (BAGIAN A)** | **Belum** — 4 GitHub Secrets masih kosong, jadi APK saat ini masih ditandatangani debug key |
| **Server aktivasi (BAGIAN B)** | **Belum** — `supabaseUrl` dan `supabaseAnonKey` masih berisi `ISI_...` |

> **Jangan jual APK yang sekarang.** APK itu ditandatangani debug key, sehingga
> tidak bisa di-update dan Android ID-nya akan berubah saat kuncinya diganti —
> artinya lisensi pelanggan akan mati. Kerjakan BAGIAN A dulu, jalankan build
> ulang, baru mulai jualan.

### Selama BAGIAN B belum dikerjakan, aplikasi terbuka tanpa aktivasi

Supaya Anda tetap bisa mencoba semua fitur sebelum server aktivasi siap,
gerbang lisensi sengaja dimatikan selama `supabaseUrl` / `supabaseAnonKey`
masih berisi `ISI_...`. Saat itu beranda menampilkan spanduk merah:

> Mode uji: lisensi belum aktif karena server aktivasi belum diisi di
> app_config.dart. Jangan jual APK ini.

Begitu kedua kunci Supabase diisi dan build dijalankan ulang, gerbang lisensi
**aktif kembali otomatis** dan setiap pelanggan wajib aktivasi. Jadi APK yang
benar-benar dijual selalu terkunci — tidak perlu mengubah kode lagi.

**Artinya:** selama spanduk merah itu masih muncul, APK tersebut adalah versi
uji, bukan versi jual.

---

## Ringkasan alur

```
Pelanggan instal APK
   → aplikasi tampilkan Kode Perangkat (mis. TK-7F3A-91C2-B8D4)
   → pelanggan kirim kode itu + bukti transfer ke WhatsApp Anda
   → Anda buat lisensi di dashboard Supabase (10 detik)
   → Anda kirim Kode Aktivasi (mis. TK-1234-5678-9012)
   → pelanggan masukkan kode → aplikasi aktif selamanya, offline
```

Kode Aktivasi tidak bisa dipakai di HP lain, karena server mengikatnya ke Kode
Perangkat yang pertama kali memakainya.

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

Kita pakai Supabase. Gratis, dan cukup untuk ratusan sampai ribuan lisensi.

1. Daftar di **https://supabase.com** (bisa pakai akun Google)
2. Klik **New project**. Nama bebas, mis. `tokoku-lisensi`.
   Simpan password database di tempat aman (tidak dipakai aplikasi).
3. Tunggu ± 2 menit sampai project selesai dibuat
4. Buka menu **SQL Editor** → **New query**
5. Buka file `supabase/schema.sql` dari repo ini, **salin seluruh isinya**,
   tempel di SQL Editor, lalu klik **Run**
6. Buka **Project Settings** (ikon gerigi) → **API**
7. Catat dua nilai ini:
   - **Project URL** — bentuknya `https://xxxxxxxx.supabase.co`
   - **anon public** (di bagian Project API keys) — kode panjang diawali `eyJ...`

8. Tempel dua nilai itu ke file `lib/core/config/app_config.dart`:

   ```dart
   static const String supabaseUrl = 'https://xxxxxxxx.supabase.co';
   static const String supabaseAnonKey = 'eyJhbGciOi...';
   ```

   Kalau mau, kirimkan dua nilai itu ke saya — saya isikan sekalian.

> **Catatan:** kunci `anon` memang dirancang untuk ditanam di aplikasi, jadi ini
> aman. Yang **tidak boleh** dibagikan adalah `service_role key` — jangan pernah
> taruh itu di aplikasi.

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

### 2. Pelanggan membuka aplikasi

Aplikasi menampilkan **Kode Perangkat**, contoh `TK-7F3A-91C2-B8D4`.
Minta pelanggan mengirim kode itu + bukti transfer.

### 3. Anda membuat lisensi

Buka Supabase → **Table Editor** → tabel `licenses` → **Insert row**:

| Kolom | Isi |
|---|---|
| `code` | kode aktivasi, mis. `TK-1234-5678-9012` |
| `customer_name` | nama pembeli, mis. `Bu Siti` |
| `store_name` | nama toko, mis. `Toko Siti Jaya` |
| `status` | `active` |
| `device_id` | **kosongkan** — nanti diisi otomatis saat aktivasi |
| `activated_at` | **kosongkan** |

Klik **Save**. Selesai — 10 detik.

**Tips membuat kode:** gunakan pola `TK-XXXX-XXXX-XXXX` dengan angka acak.
Jangan berurutan (`TK-0001`, `TK-0002`), supaya tidak bisa ditebak orang lain.
Ganti juga `TK` dengan kode singkatan Anda sendiri kalau mau.

### 4. Kirim Kode Aktivasi ke pelanggan

Pelanggan memasukkan kode itu di layar Aktivasi. Aplikasi akan menampilkan
pesan "aktif" dan langsung masuk ke halaman pendaftaran akun toko.

**Setelah aktif, aplikasi tidak butuh internet lagi** untuk operasi harian.

---

## BAGIAN D — Merilis update aplikasi

Setiap kali Anda (atau saya) mengubah kode:

1. Naikkan versi di `pubspec.yaml`, contoh `version: 1.0.0+1` → `version: 1.0.1+2`
2. Push ke branch `main`
3. GitHub Actions otomatis:
   - membangun APK dengan kunci rilis Anda
   - menerbitkan Release dengan tag `v1.0.1`
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
2. Pelanggan kirim **Kode Perangkat baru**
3. Anda buka Supabase → **SQL Editor**, jalankan:

   ```sql
   select public.reset_license_device('TK-1234-5678-9012');
   ```

4. Pelanggan memasukkan Kode Aktivasi yang **sama** di HP baru → aktif

HP lama otomatis tidak berlaku lagi.

**Saran kebijakan:** gratis 1× dalam 12 bulan, setelah itu Rp 25–50rb per
pindah perangkat. Tulis di nota supaya tidak ribut.

---

## BAGIAN F — Kalau pembeli minta refund

Buka Supabase → SQL Editor:

```sql
update public.licenses set status = 'revoked' where code = 'TK-1234-5678-9012';
```

Aplikasi yang sudah aktif **tetap jalan** (karena sudah offline), tapi kode itu
tidak bisa lagi dipakai untuk aktivasi baru di HP lain.

---

## Kebijakan yang sebaiknya Anda tentukan sekarang

| Hal | Saran |
|---|---|
| Harga | Rp 100rb–300rb sekali bayar untuk 1 HP |
| Pindah perangkat | Gratis 1× / 12 bulan, lalu Rp 25–50rb |
| Update versi | Gratis (bagus untuk reputasi) |
| Batas support | 6 bulan konsultasi WhatsApp, tulis di nota |
| Nota | Sertakan nama toko, email, kode lisensi, tanggal, ketentuan |

---

## Daftar periksa sebelum jualan pertama

- [ ] 4 GitHub Secrets sudah diisi (Bagian A)
- [ ] Folder `release-signing` sudah dicadangkan ke 2 tempat
- [ ] Supabase sudah dibuat dan `schema.sql` sudah dijalankan (Bagian B)
- [ ] `app_config.dart` sudah diisi URL + anon key
- [ ] Sudah push, dan build GitHub Actions **hijau**
- [ ] Sudah tes sendiri: instal APK, aktivasi dengan 1 kode percobaan
- [ ] Sudah tes: coba kode yang sama di HP kedua → harus **ditolak**
