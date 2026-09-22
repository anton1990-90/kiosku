-- ============================================================================
-- TokoKu — Skema lisensi (1 kode = 1 HP)
--
-- Cara pakai:
--   1. Buat project gratis di https://supabase.com
--   2. Buka SQL Editor > New query
--   3. Tempel SELURUH isi file ini, lalu klik Run
--
-- Setelah itu salin Project URL dan anon public key ke
-- lib/core/config/app_config.dart
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Tabel lisensi. Satu baris = satu lisensi yang Anda jual.
-- ---------------------------------------------------------------------------
create table if not exists public.licenses (
  code          text primary key,              -- kode aktivasi, mis. TK-1234-5678-9012
  customer_name text        not null default '',  -- nama pembeli
  store_name    text        not null default '',  -- nama toko pembeli
  status        text        not null default 'active',  -- active | revoked
  device_id     text,                          -- Kode Perangkat yang mengikat lisensi
  activated_at  timestamptz,                   -- kapan diaktifkan
  created_at    timestamptz not null default now()
);

create index if not exists licenses_device_id_idx on public.licenses (device_id);

-- ---------------------------------------------------------------------------
-- Keamanan: aktifkan Row Level Security TANPA membuat policy apa pun.
-- Artinya aplikasi (anon) TIDAK BISA membaca atau menulis tabel ini langsung —
-- jadi daftar pembeli Anda tidak bisa diunduh orang lain. Satu-satunya pintu
-- masuk adalah fungsi activate_license() di bawah.
-- ---------------------------------------------------------------------------
alter table public.licenses enable row level security;

-- ---------------------------------------------------------------------------
-- Fungsi aktivasi. Dijalankan dengan hak akses pemilik tabel (security definer)
-- sehingga bisa menembus RLS, tapi hanya melakukan satu hal: mengikat satu
-- lisensi ke satu perangkat.
-- ---------------------------------------------------------------------------
create or replace function public.activate_license(p_code text, p_device_id text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v public.licenses;
begin
  if p_code is null or length(trim(p_code)) = 0 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_code');
  end if;

  if p_device_id is null or length(trim(p_device_id)) = 0 then
    return jsonb_build_object('ok', false, 'reason', 'invalid_code');
  end if;

  -- for update mengunci baris supaya dua HP yang menekan Aktivasi
  -- pada saat yang sama tidak bisa dua-duanya berhasil.
  select * into v
    from public.licenses
   where upper(trim(code)) = upper(trim(p_code))
   for update;

  if v.code is null then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  if v.status <> 'active' then
    return jsonb_build_object('ok', false, 'reason', 'revoked');
  end if;

  -- Lisensi belum pernah dipakai: ikat ke perangkat ini.
  if v.device_id is null then
    update public.licenses
       set device_id    = p_device_id,
           activated_at = coalesce(v.activated_at, now())
     where code = v.code;

    return jsonb_build_object(
      'ok',            true,
      'customer_name', v.customer_name,
      'store_name',    v.store_name,
      'activated_at',  coalesce(v.activated_at, now())
    );
  end if;

  -- Sudah terikat ke perangkat ini: izinkan (mis. setelah instal ulang).
  if v.device_id = p_device_id then
    return jsonb_build_object(
      'ok',            true,
      'already',       true,
      'customer_name', v.customer_name,
      'store_name',    v.store_name,
      'activated_at',  v.activated_at
    );
  end if;

  -- Terikat ke perangkat lain: tolak.
  return jsonb_build_object('ok', false, 'reason', 'used_on_other_device');
end;
$$;

-- Aplikasi hanya boleh memanggil fungsi ini, tidak boleh menyentuh tabel.
revoke all on function public.activate_license(text, text) from public;
grant execute on function public.activate_license(text, text) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Alat bantu untuk ANDA (penjual): lepaskan lisensi dari HP lama supaya bisa
-- dipasang di HP baru pelanggan. Sengaja TIDAK diberikan ke anon, jadi hanya
-- bisa dijalankan dari SQL Editor Supabase.
--
-- Pakai:  select public.reset_license_device('TK-1234-5678-9012');
-- ---------------------------------------------------------------------------
create or replace function public.reset_license_device(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
begin
  update public.licenses
     set device_id    = null,
         activated_at = null
   where upper(trim(code)) = upper(trim(p_code))
  returning code into v_code;

  if v_code is null then
    return jsonb_build_object('ok', false, 'reason', 'not_found');
  end if;

  return jsonb_build_object('ok', true, 'code', v_code);
end;
$$;

revoke all on function public.reset_license_device(text) from public;

-- ---------------------------------------------------------------------------
-- Contoh membuat lisensi baru untuk pelanggan.
-- Ganti kodenya, dan pastikan belum pernah dipakai.
-- ---------------------------------------------------------------------------
-- insert into public.licenses (code, customer_name, store_name)
-- values ('TK-1234-5678-9012', 'Bu Siti', 'Toko Siti Jaya');

-- ---------------------------------------------------------------------------
-- Contoh menonaktifkan lisensi (mis. pembeli minta refund).
-- ---------------------------------------------------------------------------
-- update public.licenses set status = 'revoked' where code = 'TK-1234-5678-9012';

-- ---------------------------------------------------------------------------
-- Contoh melihat semua lisensi yang sudah aktif.
-- ---------------------------------------------------------------------------
-- select code, customer_name, store_name, device_id, activated_at
--   from public.licenses
--  order by activated_at desc nulls last;
