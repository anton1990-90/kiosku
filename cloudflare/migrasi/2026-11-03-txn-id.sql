-- ============================================================================
-- Menyimpan txn_id Pakasir pada baris pesanan.
--
-- Kenapa perlu:
--   Webhook bisa hilang (URL salah, gangguan jaringan, Cloudflare menolak).
--   Untuk menanyakan status pembayaran ke Pakasir kita butuh txn_id, bukan
--   order_id. Tanpa kolom ini, satu-satunya cara memulihkan pesanan adalah
--   memanggil ulang create-transaction (yang bersifat "find or create").
--   Kolom ini membuat pemulihan itu cukup satu panggilan status.
--
-- Aman dijalankan sekali. SQLite tidak punya "add column if not exists",
-- jadi jangan jalankan berkas ini dua kali (akan gagal "duplicate column").
--
--   cd cloudflare
--   ./node_modules/.bin/wrangler d1 execute tokoku-lisensi --remote \
--     -c wrangler.toml --file=migrasi/2026-11-03-txn-id.sql
-- ============================================================================

alter table vouchers add column txn_id text not null default '';
