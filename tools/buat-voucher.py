#!/usr/bin/env python3
"""Buat voucher TokoKu langsung di server Cloudflare, lalu catat di arsip lokal.

Alat bantu untuk PENJUAL. Skrip ini hanya butuh Python standar — tidak ada
paket yang perlu dipasang.

Kenapa kode dibuat oleh SERVER, bukan oleh skrip ini:
  supaya dijamin tidak ada kode kembar. Server yang menyimpan daftarnya, jadi
  server pula yang paling tahu kode mana yang masih kosong. Skrip ini lalu
  menyalin hasilnya ke arsip lokal supaya Anda punya catatan sendiri.

Singkatan biar tidak perlu mengetik panjang:

    export TOKOKU_URL="https://tokoku-lisensi.NAMA-ANDA.workers.dev"
    export TOKOKU_ADMIN_KEY="kunci-admin-yang-Anda-pasang"

Contoh pakai:

    # buat 5 voucher untuk stok jualan
    python tools/buat-voucher.py --jumlah 5

    # 1 voucher untuk pembeli tertentu, sekalian catat namanya
    python tools/buat-voucher.py --nama "Bu Siti" --kelompok "Grosir-09"

    # tampilkan kode saja (untuk disalin ke chat / dicetak)
    python tools/buat-voucher.py --jumlah 3 --ringkas

    # lihat ringkasan + daftar lisensi aktif
    python tools/buat-voucher.py --ringkasan

    # kalau belum mau langsung kirim, cetak perintah curl-nya saja
    python tools/buat-voucher.py --jumlah 10 --curl
"""

import argparse
import csv
import json
import os
import sys
import urllib.error
import urllib.request
from datetime import datetime

LEDGER_NAME = "ledger-voucher.csv"
LEDGER_HEADER = ["kode", "kelompok", "nama", "dibuat_pada"]

URL_BAWAAN = os.environ.get("TOKOKU_URL", "").strip()
KUNCI_BAWAAN = os.environ.get("TOKOKU_ADMIN_KEY", "").strip()


# ---------------------------------------------------------------------------
# Arsip lokal
# ---------------------------------------------------------------------------
def baca_ledger(path):
    """Kode yang sudah pernah dicatat, supaya arsipnya bisa diperiksa."""
    if not os.path.exists(path):
        return set()
    with open(path, newline="", encoding="utf-8") as f:
        return {row["kode"] for row in csv.DictReader(f) if row.get("kode")}


def tulis_ledger(path, baris):
    baru = not os.path.exists(path)
    with open(path, "a", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=LEDGER_HEADER)
        if baru:
            writer.writeheader()
        writer.writerows(baris)


# ---------------------------------------------------------------------------
# Bicara dengan server
# ---------------------------------------------------------------------------
def panggil(url, kunci, jalur, muatan=None, metode=None):
    """Panggil server. Mengembalikan (status, data)."""
    alamat = url.rstrip("/") + jalur
    badan = None if muatan is None else json.dumps(muatan).encode("utf-8")
    if metode is None:
        metode = "POST" if badan is not None else "GET"

    permintaan = urllib.request.Request(alamat, data=badan, method=metode)
    permintaan.add_header("Accept", "application/json")
    if kunci:
        permintaan.add_header("x-admin-key", kunci)
    if badan is not None:
        permintaan.add_header("Content-Type", "application/json")

    try:
        with urllib.request.urlopen(permintaan, timeout=30) as jawaban:
            return jawaban.status, json.loads(jawaban.read().decode("utf-8"))
    except urllib.error.HTTPError as galat:
        try:
            return galat.code, json.loads(galat.read().decode("utf-8"))
        except Exception:
            return galat.code, {}
    except urllib.error.URLError as galat:
        print("Tidak bisa menghubungi server: %s" % galat.reason)
        print("Periksa TOKOKU_URL dan koneksi internet Anda.")
        return None, {}
    except json.JSONDecodeError:
        print("Jawaban server tidak bisa dibaca (bukan JSON).")
        return None, {}


def perintah_curl(url, kunci, muatan):
    return (
        "curl -X POST '%s/admin/vouchers' \\\n"
        "  -H 'Content-Type: application/json' \\\n"
        "  -H 'x-admin-key: %s' \\\n"
        "  -d '%s'"
        % (url.rstrip("/"), kunci or "KUNCI_ADMIN_ANDA", json.dumps(muatan))
    )


# ---------------------------------------------------------------------------
# Perintah
# ---------------------------------------------------------------------------
def periksa_pengaturan(args):
    """Pastikan URL dan kunci siap. Mengembalikan pesan galat atau None."""
    if not args.url:
        print("Alamat server belum diisi.")
        print("Pakai --url, atau set TOKOKU_URL, misalnya:")
        print('  export TOKOKU_URL="https://tokoku-lisensi.NAMA.workers.dev"')
        return "url kosong"
    if not args.url.startswith("http"):
        print("Alamat server harus dimulai dengan http:// atau https://")
        return "url salah"
    if not args.kunci and not args.curl:
        print("Kunci admin belum diisi.")
        print("Pakai --kunci, atau set TOKOKU_ADMIN_KEY, misalnya:")
        print('  export TOKOKU_ADMIN_KEY="kunci-rahasia-Anda"')
        return "kunci kosong"
    return None


def jalankan_ringkasan(args):
    status, data = panggil(args.url, args.kunci, "/admin/data", metode="GET")
    if status == 401:
        print("Kunci admin ditolak (401). Periksa TOKOKU_ADMIN_KEY.")
        return 1
    if not data.get("ok"):
        print("Gagal mengambil data (status %s)." % status)
        return 1

    r = data.get("ringkas", {})
    print("=" * 68)
    print("RINGKASAN LISENSI TOKOKU")
    print("=" * 68)
    print("  Voucher belum terjual : %s" % r.get("voucher_tersedia", 0))
    print("  Voucher sudah dipakai : %s" % r.get("voucher_terpakai", 0))
    print("  Voucher dinonaktifkan : %s" % r.get("voucher_mati", 0))
    print("  Lisensi aktif         : %s" % r.get("lisensi_aktif", 0))
    print("  Lisensi dinonaktifkan : %s" % r.get("lisensi_mati", 0))
    print()

    lisensi = data.get("licenses", [])
    aktif = [x for x in lisensi if x.get("status") == "active"]
    if not aktif:
        print("Belum ada lisensi yang aktif.")
        return 0

    print("LISENSI AKTIF (%d)" % len(aktif))
    print("-" * 68)
    print(
        "%-21s %-20s %-20s %s"
        % ("Kode Aktivasi", "Kode Perangkat", "Toko", "Aktif pada")
    )
    print("-" * 68)
    for x in aktif:
        print(
            "%-21s %-20s %-20s %s"
            % (
                x.get("code", ""),
                x.get("device_id") or "(belum terikat)",
                (x.get("store_name") or "-")[:20],
                (x.get("activated_at") or "-")[:16].replace("T", " "),
            )
        )
    print()
    print("Pindahkan lisensi ke HP baru:")
    print("  curl -X POST '%s/admin/reset' \\" % args.url.rstrip("/"))
    print("    -H 'x-admin-key: KUNCI_ANDA' \\")
    print('    -d \'{"code":"KODE-AKTIVASI"}\'')
    return 0


def jalankan_buat(args):
    muatan = {
        "jumlah": args.jumlah,
        "batch": args.kelompok,
        "customer_name": args.nama,
    }

    if args.curl:
        print("Perintah curl untuk membuat %d voucher:" % args.jumlah)
        print()
        print(perintah_curl(args.url, args.kunci, muatan))
        return 0

    status, data = panggil(args.url, args.kunci, "/admin/vouchers", muatan)
    if status == 401:
        print("Kunci admin ditolak (401). Periksa TOKOKU_ADMIN_KEY.")
        return 1
    if not data.get("ok"):
        print("Server gagal membuat voucher (status %s)." % status)
        return 1

    kode = data.get("vouchers", [])
    if not kode:
        print("Server tidak mengembalikan kode apa pun.")
        return 1

    # Cek silang dengan arsip lokal — kalau ada yang bentrok, itu tanda
    # serius, jadi jangan dicatat diam-diam.
    sudah_ada = baca_ledger(args.ledger)
    bentrok = [k for k in kode if k in sudah_ada]
    if bentrok:
        print("PERINGATAN: kode berikut sudah ada di arsip lokal:")
        for k in bentrok:
            print("  " + k)
        print("Periksa arsip Anda sebelum menjualnya.")
        print()

    sekarang = datetime.now().strftime("%Y-%m-%d %H:%M")
    tulis_ledger(
        args.ledger,
        [
            {
                "kode": k,
                "kelompok": args.kelompok,
                "nama": args.nama,
                "dibuat_pada": sekarang,
            }
            for k in kode
        ],
    )

    if args.ringkas:
        for k in kode:
            print(k)
        return 0

    print("=" * 68)
    print("VOUCHER BARU (%d) — siap dijual" % len(kode))
    print("=" * 68)
    for k in kode:
        print("  " + k)
    print()

    print("=" * 68)
    print("CARA PAKAI")
    print("=" * 68)
    print("Berikan SATU kode di atas ke pelanggan (mis. lewat chat, atau cetak")
    print("di kartu). Pelanggan lalu membuka halaman portal berikut:")
    print()
    print("  %s" % args.url.rstrip("/"))
    print()
    print("Di halaman itu pelanggan memasukkan Kode Perangkat dari aplikasi dan")
    print("Kode Voucher di atas, lalu menerima Kode Aktivasi. Tidak ada yang")
    print("perlu Anda kerjakan lagi.")
    print()
    print("Pelanggan juga bisa menempel langsung Kode Voucher ke kolom Kode")
    print("Aktivasi di aplikasi — hasilnya sama, tanpa membuka portal.")
    print()
    print("Arsip kode tersimpan di: %s" % os.path.abspath(args.ledger))
    print("Simpan berkas itu — jangan di-commit ke repo publik.")
    return 0


def main():
    p = argparse.ArgumentParser(
        description="Buat voucher TokoKu di server Cloudflare.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p.add_argument(
        "--jumlah", type=int, default=1, help="berapa voucher (default 1, maks 200)"
    )
    p.add_argument("--kelompok", default="", help="penanda kelompok, mis. Grosir-2026-09")
    p.add_argument("--nama", default="", help="nama pembeli (opsional)")
    p.add_argument(
        "--url",
        default=URL_BAWAAN,
        help="alamat server, mis. https://xxx.workers.dev",
    )
    p.add_argument("--kunci", default=KUNCI_BAWAAN, help="kunci admin (ADMIN_KEY)")
    p.add_argument("--ringkas", action="store_true", help="tampilkan kode saja")
    p.add_argument(
        "--ringkasan",
        action="store_true",
        help="lihat ringkasan lisensi, tidak membuat voucher",
    )
    p.add_argument("--curl", action="store_true", help="cetak perintah curl, jangan kirim")
    p.add_argument(
        "--ledger", default=LEDGER_NAME, help="berkas arsip (default %s)" % LEDGER_NAME
    )
    args = p.parse_args()

    if args.ringkasan:
        if not args.url:
            print("Alamat server belum diisi. Pakai --url atau set TOKOKU_URL.")
            return 1
        return jalankan_ringkasan(args)

    if args.jumlah < 1 or args.jumlah > 200:
        print("Jumlah voucher harus antara 1 dan 200.")
        return 1

    galat = periksa_pengaturan(args)
    if galat:
        return 1

    return jalankan_buat(args)


if __name__ == "__main__":
    sys.exit(main())
