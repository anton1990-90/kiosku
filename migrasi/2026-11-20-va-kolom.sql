-- ============================================================================
-- Migrasi 2026-11-20 — kolom untuk pembayaran Virtual Account in-app.
--
-- Sebelumnya nomor VA hanya hidup di halaman DOKU, jadi tidak perlu disimpan.
-- Sekarang nomornya kita terbitkan sendiri (Direct API) dan tampilkan di
-- halaman penjualan, jadi perlu disimpan supaya admin/support bisa melihat
-- nomor mana yang diberikan ke pembeli.
--
-- Jalankan SEKALI pada database yang sudah ada:
--   npx wrangler d1 execute tokoku-lisensi --remote --file=migrasi/2026-11-20-va-kolom.sql
-- ============================================================================

alter table vouchers add column va_number text not null default '';
alter table vouchers add column va_bank   text not null default '';
