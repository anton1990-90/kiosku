#!/usr/bin/env python3
"""Buat kode lisensi TokoKu + perintah SQL untuk ditempel ke Supabase.

Alat bantu untuk PENJUAL. Skrip ini tidak menyimpan rahasia apa pun dan tidak
bisa mengaktifkan lisensi sendiri — kode baru berguna setelah Anda masukkan
barisannya ke tabel `licenses` di Supabase.

Kenapa pakai skrip ini daripada mengetik kode manual:
  * kode acak, tidak berurutan, jadi tidak bisa ditebak orang lain
  * formatnya selalu benar (TK-XXXX-XXXX-XXXX)
  * tidak ada kode kembar, karena setiap kode diperiksa ke daftar lokal
  * tercatat di ledger.csv supaya Anda punya arsip siapa memakai kode apa

Contoh pakai:

    # 1 kode untuk satu pembeli
    python tools/buat-kode-lisensi.py --nama "Bu Siti" --toko "Toko Siti Jaya"

    # 5 kode sekaligus, tanpa nama (untuk stok jualan)
    python tools/buat-kode-lisensi.py --jumlah 5

    # pakai awalan sendiri, dan tampilkan kode saja (untuk dikirim via WA)
    python tools/buat-kode-lisensi.py --awalan TK --jumlah 3 --ringkas
"""

import argparse
import csv
import os
import secrets
import sys
from datetime import datetime

# Tanpa huruf I, O, 0, dan 1 — sering tertukar saat pelanggan mengetik ulang.
ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

LEDGER_NAME = "ledger-lisensi.csv"
LEDGER_HEADER = ["kode", "nama", "toko", "dibuat_pada", "catatan"]


def buat_kode(awalan: str) -> str:
    """Hasilkan kode berformat <awalan>-XXXX-XXXX-XXXX."""
    grup = ["".join(secrets.choice(ALPHABET) for _ in range(4)) for _ in range(3)]
    return "%s-%s" % (awalan, "-".join(grup))


def baca_ledger(path: str) -> set:
    """Kode yang sudah pernah dibuat, supaya tidak ada yang kembar."""
    if not os.path.exists(path):
        return set()
    with open(path, newline="", encoding="utf-8") as f:
        return {row["kode"] for row in csv.DictReader(f) if row.get("kode")}


def tulis_ledger(path: str, baris: list) -> None:
    baru = not os.path.exists(path)
    with open(path, "a", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=LEDGER_HEADER)
        if baru:
            writer.writeheader()
        writer.writerows(baris)


def escape_sql(teks: str) -> str:
    """Kutip satu untuk nilai SQL."""
    return teks.replace("'", "''")


def main() -> int:
    p = argparse.ArgumentParser(
        description="Buat kode lisensi TokoKu dan perintah SQL untuk Supabase.",
    )
    p.add_argument("--jumlah", type=int, default=1, help="berapa kode (default 1)")
    p.add_argument("--awalan", default="TK", help="awalan kode (default TK)")
    p.add_argument("--nama", default="", help="nama pembeli (opsional)")
    p.add_argument("--toko", default="", help="nama toko pembeli (opsional)")
    p.add_argument(
        "--ringkas",
        action="store_true",
        help="tampilkan kode saja, tanpa SQL dan tabel",
    )
    p.add_argument(
        "--ledger",
        default=LEDGER_NAME,
        help="berkas arsip kode (default %s)" % LEDGER_NAME,
    )
    args = p.parse_args()

    if args.jumlah < 1:
        print("Jumlah kode minimal 1.")
        return 1

    awalan = args.awalan.strip().upper() or "TK"
    if not awalan.replace("-", "").isalnum():
        print("Awalan hanya boleh huruf/angka.")
        return 1

    sudah_ada = baca_ledger(args.ledger)

    kode_baru = []
    for _ in range(args.jumlah):
        # Batas percobaan supaya tidak menggantung kalau ledger sudah penuh.
        for _ in range(100):
            kandidat = buat_kode(awalan)
            if kandidat not in sudah_ada and kandidat not in kode_baru:
                kode_baru.append(kandidat)
                break
        else:
            print("Gagal membuat kode unik. Coba lagi.")
            return 1

    sekarang = datetime.now().strftime("%Y-%m-%d %H:%M")
    tulis_ledger(
        args.ledger,
        [
            {
                "kode": k,
                "nama": args.nama,
                "toko": args.toko,
                "dibuat_pada": sekarang,
                "catatan": "",
            }
            for k in kode_baru
        ],
    )

    if args.ringkas:
        for k in kode_baru:
            print(k)
        return 0

    print("=" * 64)
    print("KODE LISENSI BARU (%d)" % len(kode_baru))
    print("=" * 64)
    for k in kode_baru:
        print("  " + k)
    print()

    print("=" * 64)
    print("LANGKAH BERIKUTNYA")
    print("=" * 64)
    print("Buka Supabase > SQL Editor > New query, tempel perintah di bawah,")
    print("lalu klik Run. Kolom device_id dan activated_at sengaja dikosongkan")
    print("supaya terisi otomatis saat pelanggan melakukan aktivasi.")
    print()
    print("-" * 64)
    for k in kode_baru:
        print(
            "insert into public.licenses (code, customer_name, store_name) "
            "values ('%s', '%s', '%s');"
            % (escape_sql(k), escape_sql(args.nama), escape_sql(args.toko))
        )
    print("-" * 64)
    print()

    print("Cek berhasil terpasang:")
    nilai = ", ".join("'%s'" % escape_sql(k) for k in kode_baru)
    print("  select code, customer_name, store_name, device_id")
    print("    from public.licenses")
    print("   where code in (%s);" % nilai)
    print()

    print("Arsip kode tersimpan di: %s" % os.path.abspath(args.ledger))
    print("Simpan berkas itu — jangan di-commit ke repo publik.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
