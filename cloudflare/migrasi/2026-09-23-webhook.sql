-- ============================================================================
-- Migrasi 2026-09-23 — pesanan otomatis dari platform jualan (OrderHero)
--
-- Untuk database yang SUDAH ADA. Database baru cukup pakai `schema.sql`.
--
-- Jalankan SEKALI SAJA:
--   npx wrangler d1 execute tokoku-lisensi --remote --file=cloudflare/migrasi/2026-09-23-webhook.sql
--
-- Kenapa berkas terpisah: SQLite TIDAK mendukung "alter table ... add column
-- if not exists". Kalau berkas ini dijalankan dua kali, dua baris pertama akan
-- gagal dengan "duplicate column name" — itu wajar, bukan kerusakan. Baris
-- "create table if not exists" di bawahnya tetap aman diulang.
-- ============================================================================

-- 1. Voucher kini menyimpan email pembeli dan nomor pesanan platform, supaya
--    Anda bisa melacak satu voucher berasal dari pembelian yang mana.
alter table vouchers add column customer_email text not null default '';
alter table vouchers add column order_ref text not null default '';

-- 2. Catatan setiap webhook yang masuk. delivery_id sebagai kunci utama —
--    inilah yang membuat penerimaan pesanan idempoten.
create table if not exists webhook_events (
  delivery_id  text primary key,
  sumber       text not null default '',
  event        text not null default '',
  status       text not null default '',
  voucher_code text,
  email        text not null default '',
  email_status text not null default '',
  alasan       text not null default '',
  received_at  text not null
);

create index if not exists webhook_events_waktu_idx on webhook_events (received_at);
create index if not exists webhook_events_voucher_idx on webhook_events (voucher_code);
