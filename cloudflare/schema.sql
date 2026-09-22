-- ============================================================================
-- TokoKu — Skema database lisensi (Cloudflare D1 / SQLite)
--
-- Cara pakai:
--   npx wrangler d1 execute tokoku-lisensi --remote --file=cloudflare/schema.sql
--
-- Aman dijalankan berulang kali (semua pakai "if not exists").
-- ============================================================================


-- ---------------------------------------------------------------------------
-- Tabel voucher — kode yang Anda JUAL ke pelanggan.
--
-- Satu baris = satu lembar voucher yang belum/tidak dipakai. Voucher bersifat
-- sekali pakai: begitu ditukar, statusnya jadi 'used' dan terkunci ke satu HP.
-- ---------------------------------------------------------------------------
create table if not exists vouchers (
  code          text primary key,               -- VC-XXXX-XXXX-XXXX
  batch         text not null default '',       -- penanda kelompok, mis. "Grosir-2026-09"
  customer_name text not null default '',       -- nama pembeli (opsional, diisi saat buat)
  status        text not null default 'unused', -- unused | used | revoked
  license_code  text,                           -- Kode Aktivasi hasil penukaran (AK-...)
  created_at    text not null,
  used_at       text
);

create index if not exists vouchers_status_idx on vouchers (status);
create index if not exists vouchers_batch_idx  on vouchers (batch);


-- ---------------------------------------------------------------------------
-- Tabel lisensi — hasil penukaran voucher. Satu baris = satu HP yang aktif.
--
-- device_id adalah Kode Perangkat HP pelanggan. Karena voucher hanya bisa
-- ditukar sekali, satu voucher otomatis hanya hidup di satu HP.
-- ---------------------------------------------------------------------------
create table if not exists licenses (
  code          text primary key,               -- AK-XXXX-XXXX-XXXX
  voucher_code  text not null,                  -- voucher asal
  device_id     text,                           -- Kode Perangkat yang mengikat
  customer_name text not null default '',
  store_name    text not null default '',
  status        text not null default 'active', -- active | revoked
  activated_at  text,
  created_at    text not null
);

create index if not exists licenses_device_idx  on licenses (device_id);
create index if not exists licenses_voucher_idx on licenses (voucher_code);
create index if not exists licenses_status_idx  on licenses (status);


-- ---------------------------------------------------------------------------
-- Contoh pemeriksaan manual (pakai wrangler):
--
--   -- lihat semua lisensi yang sudah aktif
--   npx wrangler d1 execute tokoku-lisensi --remote --command \
--     "select code, device_id, store_name, activated_at from licenses order by activated_at desc"
--
--   -- pindahkan satu lisensi ke HP baru (pelanggan ganti HP)
--   npx wrangler d1 execute tokoku-lisensi --remote --command \
--     "update licenses set device_id = null, activated_at = null where code = 'AK-XXXX-XXXX-XXXX'"
--
--   -- nonaktifkan lisensi (mis. pelanggan minta refund)
--   npx wrangler d1 execute tokoku-lisensi --remote --command \
--     "update licenses set status = 'revoked' where code = 'AK-XXXX-XXXX-XXXX'"
-- ---------------------------------------------------------------------------
