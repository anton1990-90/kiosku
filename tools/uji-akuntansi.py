#!/usr/bin/env python3
"""Uji logika laporan keuangan TokoKu terhadap SQLite sungguhan.

Jalankan:  python tools/uji-akuntansi.py

Kenapa ada berkas Python di repo Flutter ini?
Mesin pengembangan tidak punya Flutter/Dart SDK, jadi laporan keuangan —
bagian paling mudah salah dan paling mahal kalau salah — tidak bisa diuji
dengan menjalankan aplikasinya. Skrip ini menutup celah itu: skema diambil
apa adanya dari lib/data/database/database_helper.dart, lalu alur uang
dijalankan dengan SQL yang disalin persis dari repository Dart, dan
identitas akuntansi diuji dengan angka nyata.

PENTING — risiko drift: skrip ini MENCERMINKAN logika Dart, bukan memanggilnya.
Kalau kamu mengubah kueri di lib/data/repositories/accounting_repository.dart
atau cash_repository.dart, ubah juga salinannya di sini, kalau tidak uji ini
akan memberi rasa aman yang palsu. Setiap kueri di bawah diberi komentar
asalnya.

Yang diuji:
  1. Skema v3 bisa dibuat di SQLite asli (13 tabel + kolom ALTER)
  2. Laba kotor = pendapatan - HPP; laba bersih = laba kotor - beban
  3. Neraca seimbang (aset = liabilitas + ekuitas) di setiap skenario
  4. Kalau SEMUA aset berasal dari transaksi tercatat, baris penyeimbang
     "Modal awal & penyesuaian" harus NOL — ini uji sesungguhnya
  5. Stok yang muncul tanpa transaksi mengisi baris penyeimbang TEPAT
     sebesar nilainya (kasus nyata: stok lama sebelum pakai aplikasi)
  6. Arus kas: saldo awal + mutasi = saldo akhir, cocok dengan saldo kas
  7. HPP memakai harga modal SAAT TERJUAL, bukan harga produk sekarang
  8. Prive mengurangi ekuitas tapi TIDAK mengurangi laba (bukan beban)
  9. Hutang supplier menambah persediaan sekaligus liabilitas
 10. Piutang menambah aset tanpa menambah kas
 11. Rentang setengah terbuka [start, end) tidak menghitung ganda di batas
"""

import os
import re
import sqlite3
import sys

# Akar repo = folder induk dari tools/ — supaya skrip bisa dijalankan
# dari mana saja tanpa mengubah path.
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

lulus = 0
gagal = 0


def cek(nama, kondisi, detail=""):
    global lulus, gagal
    if kondisi:
        lulus += 1
        print("  OK    " + nama)
    else:
        gagal += 1
        print("  GAGAL " + nama + ("  -> " + str(detail) if detail else ""))


def baca(p):
    with open(os.path.join(REPO, p), encoding="utf-8") as f:
        return f.read()


# ---------------------------------------------------------------------------
# 1. Skema asli dari database_helper.dart
# ---------------------------------------------------------------------------
print("== 1. Bangun skema v3 dari database_helper.dart ==")
isi_db = baca("lib/data/database/database_helper.dart")

# Ambil pernyataan CREATE TABLE dari blok triple-quote Dart.
# Catatan: CREATE INDEX sengaja dilewati — beberapa ditulis sebagai string
# Dart yang disambung antar-baris (`'CREATE INDEX ... '` + `'ON ...'`),
# sehingga pemotongan naif menghasilkan SQL tidak lengkap. Indeks hanya
# berpengaruh pada kecepatan, bukan pada kebenaran hasil kueri.
ddl = []
for m in re.finditer(r"'''(.*?)'''", isi_db, re.S):
    stmt = m.group(1).strip()
    if stmt.upper().startswith("CREATE TABLE"):
        ddl.append(stmt)

# _addColumnIfMissing: kolom yang ditambahkan setelah tabel dibuat
alter = {}
for m in re.finditer(
        r"_addColumnIfMissing\(\s*\w+\s*,\s*'(\w+)'\s*,\s*'(\w+)'\s*,\s*'([^']*)'",
        isi_db):
    alter.setdefault(m.group(1), []).append((m.group(2), m.group(3)))

print("     pernyataan CREATE TABLE: %d, tabel dapat kolom tambahan: %d"
      % (len(ddl), len(alter)))
cek("13 tabel terbaca dari database_helper.dart", len(ddl) == 13, len(ddl))

con = sqlite3.connect(":memory:")
con.execute("PRAGMA foreign_keys = ON")
for stmt in ddl:
    con.execute(stmt)

# Terapkan kolom tambahan (mensimulasikan _onUpgrade / _createV3Tables)
for tabel, kolom_list in alter.items():
    ada = {r[1] for r in con.execute("PRAGMA table_info(%s)" % tabel)}
    for nama, tipe in kolom_list:
        if nama not in ada:
            con.execute("ALTER TABLE %s ADD COLUMN %s %s" % (tabel, nama, tipe))
con.commit()

tabel_ada = {r[0] for r in con.execute(
    "SELECT name FROM sqlite_master WHERE type='table'")}
for t in ["sales", "sale_items", "products", "cash_transactions", "expenses",
          "prive", "stock_movements", "debts", "debt_payments"]:
    cek("tabel %s dibuat" % t, t in tabel_ada, sorted(tabel_ada))

# Kolom v3 hasil ALTER benar-benar ada
for tabel, kolom in [("sales", "is_debt"), ("sales", "debt_id"),
                     ("debts", "sale_id"), ("debts", "product_id")]:
    ada = {r[1] for r in con.execute("PRAGMA table_info(%s)" % tabel)}
    cek("%s.%s ada" % (tabel, kolom), kolom in ada, sorted(ada))


# ---------------------------------------------------------------------------
# SQL disalin persis dari repository Dart
# ---------------------------------------------------------------------------
def q1(sql, args=()):
    return con.execute(sql, args).fetchone()[0] or 0


def get_saldo():
    return q1("""SELECT COALESCE(SUM(
        CASE WHEN type = ? THEN amount ELSE -amount END), 0) AS saldo
        FROM cash_transactions""", ("in",))


def get_saldo_sebelum(start):
    return q1("""SELECT COALESCE(SUM(
        CASE WHEN type = ? THEN amount ELSE -amount END), 0) AS saldo
        FROM cash_transactions WHERE date < ?""", ("in", start))


def get_pendapatan(a, b):
    return q1("SELECT COALESCE(SUM(total_amount),0) AS total FROM sales "
              "WHERE created_at >= ? AND created_at < ?", (a, b))


def get_hpp(a, b):
    return q1("""SELECT COALESCE(SUM(si.cost_price * si.quantity),0) AS total
        FROM sale_items si INNER JOIN sales s ON s.id = si.sale_id
        WHERE s.created_at >= ? AND s.created_at < ?""", (a, b))


def get_beban(a, b):
    rows = con.execute("""SELECT category, COALESCE(SUM(amount),0) AS total
        FROM expenses WHERE date >= ? AND date < ?
        GROUP BY category ORDER BY total DESC""", (a, b)).fetchall()
    return rows


def total_prive(a, b):
    return q1("SELECT COALESCE(SUM(amount),0) AS total FROM prive "
              "WHERE date >= ? AND date < ?", (a, b))


def get_arus_kas(a, b):
    return con.execute("""SELECT category,
        COALESCE(SUM(CASE WHEN type = ? THEN amount ELSE 0 END),0) AS masuk,
        COALESCE(SUM(CASE WHEN type = ? THEN amount ELSE 0 END),0) AS keluar
        FROM cash_transactions WHERE date >= ? AND date < ?
        GROUP BY category ORDER BY category ASC""", ("in", "out", a, b)).fetchall()


def get_laba_rugi(a, b):
    pendapatan = get_pendapatan(a, b)
    hpp = get_hpp(a, b)
    beban = get_beban(a, b)
    total_beban = sum(x[1] for x in beban)
    return {
        "pendapatan": pendapatan,
        "hpp": hpp,
        "totalBeban": total_beban,
        "labaKotor": pendapatan - hpp,
        "labaBersih": pendapatan - hpp - total_beban,
    }


def get_neraca():
    kas = get_saldo()
    persediaan = q1("SELECT COALESCE(SUM(stock * cost_price),0) AS total "
                    "FROM products")
    piutang = q1("SELECT COALESCE(SUM(amount - paid_amount),0) AS sisa "
                 "FROM debts WHERE type='piutang' AND status != 'paid'")
    hutang = q1("SELECT COALESCE(SUM(amount - paid_amount),0) AS sisa "
                "FROM debts WHERE type='hutang' AND status != 'paid'")
    modal = q1("""SELECT COALESCE(SUM(amount),0) AS total FROM cash_transactions
        WHERE type = ? AND category = ?""", ("in", "modal"))
    penjualan = q1("SELECT COALESCE(SUM(total_amount),0) AS total FROM sales")
    hpp = q1("SELECT COALESCE(SUM(si.cost_price * si.quantity),0) AS total "
             "FROM sale_items si")
    beban = q1("SELECT COALESCE(SUM(amount),0) AS total FROM expenses")
    prive = q1("SELECT COALESCE(SUM(amount),0) AS total FROM prive")
    laba_ditahan = penjualan - hpp - beban - prive

    total_aset = kas + persediaan + piutang
    ekuitas_tercatat = modal + laba_ditahan          # labaBersihPeriode=0, privePeriode=0
    penyesuaian = total_aset - hutang - ekuitas_tercatat
    return {
        "kas": kas, "persediaan": persediaan, "piutang": piutang,
        "hutang": hutang, "modalDisetor": modal, "labaDitahan": laba_ditahan,
        "totalAset": total_aset, "ekuitasTercatat": ekuitas_tercatat,
        "penyesuaian": penyesuaian,
        "totalEkuitas": ekuitas_tercatat + penyesuaian,
    }


# ---------------------------------------------------------------------------
# Alur uang — SQL disalin dari sale_repository / product_repository
# ---------------------------------------------------------------------------
print("\n== 2. Jalankan alur uang ==")

T1 = "2026-09-01T08:00:00.000"
T2 = "2026-09-10T09:00:00.000"
T3 = "2026-09-15T10:00:00.000"
T4 = "2026-09-20T11:00:00.000"


def tambah_produk(nama, stok, modal, jual):
    cur = con.execute(
        "INSERT INTO products (name, category, cost_price, sell_price, stock, "
        "min_stock, created_at, updated_at) VALUES (?,?,?,?,?,?,?,?)",
        (nama, "Sembako", modal, jual, stok, 5, T1, T1))
    return cur.lastrowid


def catat_kas(tipe, jumlah, kategori, tanggal, ref_tipe=None, ref_id=None):
    if jumlah <= 0:
        return
    con.execute(
        "INSERT INTO cash_transactions (type, amount, category, note, ref_type, "
        "ref_id, date, created_at) VALUES (?,?,?,?,?,?,?,?)",
        (tipe, jumlah, kategori, None, ref_tipe, ref_id, tanggal, tanggal))


def jual(invoice, items, tanggal, dibayar=None, is_debt=False, due=None):
    """items: list of (product_id, nama, qty, sell_price, cost_price)"""
    total = sum(qty * jual_h for _, _, qty, jual_h, _ in items)
    profit = sum(qty * (jual_h - modal_h) for _, _, qty, jual_h, modal_h in items)
    total_items = sum(qty for _, _, qty, _, _ in items)
    if dibayar is None:
        dibayar = total
    dibayar = max(0, min(dibayar, total))
    sisa = total - dibayar
    catat_piutang = is_debt and sisa > 0

    cur = con.execute(
        "INSERT INTO sales (invoice_number, user_id, customer_name, total_amount, "
        "total_profit, total_items, payment_method, paid_amount, change_amount, "
        "is_debt, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?)",
        (invoice, USER_ID, "Pelanggan" if is_debt else None, total, profit,
         total_items, "tunai", dibayar, 0, 1 if is_debt else 0, tanggal))
    sale_id = cur.lastrowid

    for pid, nama, qty, jual_h, modal_h in items:
        con.execute(
            "INSERT INTO sale_items (sale_id, product_id, product_name, "
            "quantity, sell_price, cost_price, subtotal) VALUES (?,?,?,?,?,?,?)",
            (sale_id, pid, nama, qty, jual_h, modal_h, qty * jual_h))
        con.execute("UPDATE products SET stock = stock - ? WHERE id = ?",
                    (qty, pid))
        con.execute(
            "INSERT INTO stock_movements (product_id, product_name, type, "
            "quantity, total_cost, note, ref_type, ref_id, date, created_at) "
            "VALUES (?,?,?,?,?,?,?,?,?,?)",
            (pid, nama, "out", qty, modal_h * qty, None, "sale", sale_id,
             tanggal, tanggal))

    if catat_piutang:
        dcur = con.execute(
            "INSERT INTO debts (type, party_name, amount, paid_amount, status, "
            "sale_id, product_id, due_date, created_at, updated_at) "
            "VALUES (?,?,?,?,?,?,?,?,?,?)",
            ("piutang", "Pelanggan", total, dibayar, "unpaid", sale_id,
             items[0][0] if len(items) == 1 else None, due, tanggal, tanggal))
        con.execute("UPDATE sales SET debt_id = ? WHERE id = ?",
                    (dcur.lastrowid, sale_id))

    catat_kas("in", dibayar, "penjualan", tanggal, "sale", sale_id)
    return sale_id


def restok(pid, nama, qty, harga, tanggal, dibayar=None, supplier=None, due=None):
    """Salin dari product_repository.restockProduct."""
    total = qty * harga
    if dibayar is None:
        dibayar = total
    dibayar = max(0, min(dibayar, total))
    sisa = total - dibayar

    con.execute("UPDATE products SET stock = stock + ?, cost_price = ?, "
                "updated_at = ? WHERE id = ?", (qty, harga, tanggal, pid))
    con.execute(
        "INSERT INTO stock_movements (product_id, product_name, type, quantity, "
        "total_cost, note, ref_type, ref_id, date, created_at) "
        "VALUES (?,?,?,?,?,?,?,?,?,?)",
        (pid, nama, "in", qty, total, None, "restock", None, tanggal, tanggal))
    catat_kas("out", dibayar, "restok", tanggal, "restock", None)
    if sisa > 0:
        con.execute(
            "INSERT INTO debts (type, party_name, amount, paid_amount, status, "
            "product_id, due_date, created_at, updated_at) VALUES (?,?,?,?,?,?,?,?,?)",
            ("hutang", supplier or "Supplier", total, dibayar, "unpaid", pid,
             due, tanggal, tanggal))
    return total


# Skenario: SEMUA aset berasal dari transaksi tercatat -> penyesuaian harus 0
USER_ID = con.execute(
    "INSERT INTO users (email, password_hash, store_name, created_at) "
    "VALUES (?,?,?,?)",
    ("pemilik@toko.id", "x", "Toko Uji", T1)).lastrowid

catat_kas("in", 1_000_000, "modal", T1)                    # setoran pemilik
p1 = tambah_produk("Beras 5kg", 0, 0, 12_000)
restok(p1, "Beras 5kg", 100, 6_000, T1)                    # 600.000 lunas
jual("INV-1", [(p1, "Beras 5kg", 40, 10_000, 6_000)], T2)  # 400.000 lunas

con.commit()
print("     kas=%d persediaan=%d" % (get_saldo(), get_neraca()["persediaan"]))

# --- 2. Laba rugi
lr = get_laba_rugi(T1, T4)
print("     laba rugi: pendapatan=%d hpp=%d beban=%d labaKotor=%d labaBersih=%d"
      % (lr["pendapatan"], lr["hpp"], lr["totalBeban"], lr["labaKotor"],
         lr["labaBersih"]))
cek("pendapatan = 400.000", lr["pendapatan"] == 400_000, lr["pendapatan"])
cek("HPP = 40 x 6.000 = 240.000", lr["hpp"] == 240_000, lr["hpp"])
cek("laba kotor = pendapatan - HPP", lr["labaKotor"] == 160_000, lr["labaKotor"])
cek("laba bersih = laba kotor - beban",
    lr["labaBersih"] == lr["labaKotor"] - lr["totalBeban"], lr["labaBersih"])

# --- 3. Neraca
n = get_neraca()
print("     neraca: aset=%d (kas %d + persediaan %d + piutang %d), "
      "hutang=%d, ekuitas=%d, penyesuaian=%d"
      % (n["totalAset"], n["kas"], n["persediaan"], n["piutang"], n["hutang"],
         n["totalEkuitas"], n["penyesuaian"]))
cek("kas = 1.000.000 - 600.000 + 400.000 = 800.000", n["kas"] == 800_000, n["kas"])
cek("persediaan = 60 x 6.000 = 360.000", n["persediaan"] == 360_000,
    n["persediaan"])
cek("aset = liabilitas + ekuitas",
    n["totalAset"] == n["hutang"] + n["totalEkuitas"],
    "%d vs %d" % (n["totalAset"], n["hutang"] + n["totalEkuitas"]))
cek("PENYESUAIAN NOL kalau semua aset dari transaksi tercatat",
    n["penyesuaian"] == 0, n["penyesuaian"])
cek("ekuitas = modal 1.000.000 + laba 160.000", n["totalEkuitas"] == 1_160_000,
    n["totalEkuitas"])

# --- 4. Arus kas
ak = get_arus_kas(T1, T4)
saldo_awal = get_saldo_sebelum(T1)
masuk = sum(r[1] for r in ak)
keluar = sum(r[2] for r in ak)
print("     arus kas: awal=%d masuk=%d keluar=%d akhir=%d"
      % (saldo_awal, masuk, keluar, saldo_awal + masuk - keluar))
cek("saldo awal 0", saldo_awal == 0, saldo_awal)
cek("masuk = 1.400.000 (modal + penjualan)", masuk == 1_400_000, masuk)
cek("keluar = 600.000 (restok)", keluar == 600_000, keluar)
cek("saldo akhir arus kas == saldo kas",
    saldo_awal + masuk - keluar == get_saldo(), get_saldo())
cek("saldo sebelum T1 + mutasi [T1,T4) == saldo sebelum T4",
    get_saldo_sebelum(T1) + masuk - keluar == get_saldo_sebelum(T4),
    "%d + %d - %d != %d" % (get_saldo_sebelum(T1), masuk, keluar,
                            get_saldo_sebelum(T4)))
cek("saldo sebelum T1 = 0", get_saldo_sebelum(T1) == 0, get_saldo_sebelum(T1))
cek("saldo sebelum T2 = 1.000.000 - 600.000 (modal - restok, keduanya di T1)",
    get_saldo_sebelum(T2) == 400_000, get_saldo_sebelum(T2))

# --- 5. Beban & prive
con.execute("INSERT INTO expenses (category, amount, note, date, created_at) "
            "VALUES (?,?,?,?,?)", ("Listrik", 50_000, None, T3, T3))
catat_kas("out", 50_000, "beban", T3, "expense", None)
con.execute("INSERT INTO prive (amount, note, date, created_at) VALUES (?,?,?,?)",
            (30_000, None, T3, T3))
catat_kas("out", 30_000, "prive", T3, "prive", None)
con.commit()

lr2 = get_laba_rugi(T1, T4)
n2 = get_neraca()
print("     setelah beban 50.000 & prive 30.000: labaBersih=%d kas=%d "
      "penyesuaian=%d" % (lr2["labaBersih"], n2["kas"], n2["penyesuaian"]))
cek("beban mengurangi laba bersih",
    lr2["labaBersih"] == 160_000 - 50_000, lr2["labaBersih"])
cek("prive TIDAK mengurangi laba (bukan beban)",
    lr2["labaBersih"] == 110_000, lr2["labaBersih"])
cek("prive mengurangi ekuitas",
    n2["totalEkuitas"] == 1_000_000 + 110_000 - 30_000, n2["totalEkuitas"])
cek("penyesuaian tetap NOL", n2["penyesuaian"] == 0, n2["penyesuaian"])
cek("neraca tetap seimbang",
    n2["totalAset"] == n2["hutang"] + n2["totalEkuitas"],
    "%d vs %d" % (n2["totalAset"], n2["hutang"] + n2["totalEkuitas"]))

# --- 6. Restok belum lunas -> hutang supplier
restok(p1, "Beras 5kg", 50, 6_000, T4, dibayar=100_000, supplier="CV Sumber")
con.commit()
n3 = get_neraca()
print("     restok 300.000 bayar 100.000: kas=%d persediaan=%d hutang=%d "
      "penyesuaian=%d" % (n3["kas"], n3["persediaan"], n3["hutang"],
                          n3["penyesuaian"]))
cek("hutang supplier = 200.000", n3["hutang"] == 200_000, n3["hutang"])
cek("kas berkurang hanya sebesar yang dibayar",
    n3["kas"] == n2["kas"] - 100_000, n3["kas"])
cek("persediaan bertambah penuh 300.000",
    n3["persediaan"] == n2["persediaan"] + 300_000, n3["persediaan"])
cek("neraca masih seimbang dengan hutang",
    n3["totalAset"] == n3["hutang"] + n3["totalEkuitas"],
    "%d vs %d" % (n3["totalAset"], n3["hutang"] + n3["totalEkuitas"]))
cek("penyesuaian masih NOL", n3["penyesuaian"] == 0, n3["penyesuaian"])

# --- 7. Jual belum lunas -> piutang
# Produk dibuat dengan stok 0 lalu di-restok, supaya seluruh asetnya punya
# transaksi tercatat (kalau tidak, baris penyeimbang akan terisi — lihat §12).
p2 = tambah_produk("Gula 1kg", 0, 0, 13_000)
restok(p2, "Gula 1kg", 20, 8_000, T4, supplier="CV Manis")
con.commit()
n_sebelum_jual = get_neraca()

jual("INV-2", [(p2, "Gula 1kg", 5, 13_000, 8_000)], T4, dibayar=25_000,
     is_debt=True, due="2026-10-04")
con.commit()
n4 = get_neraca()
print("     jual 65.000 bayar 25.000: kas=%d piutang=%d penyesuaian=%d"
      % (n4["kas"], n4["piutang"], n4["penyesuaian"]))
cek("piutang = 40.000", n4["piutang"] == 40_000, n4["piutang"])
cek("kas bertambah hanya yang dibayar",
    n4["kas"] == n_sebelum_jual["kas"] + 25_000, n4["kas"])
cek("neraca seimbang dengan piutang",
    n4["totalAset"] == n4["hutang"] + n4["totalEkuitas"],
    "%d vs %d" % (n4["totalAset"], n4["hutang"] + n4["totalEkuitas"]))
cek("penyesuaian masih NOL", n4["penyesuaian"] == 0, n4["penyesuaian"])
# Rentang HARUS memakai batas atas yang melewati T4: rentang bersifat
# setengah terbuka, jadi penjualan tepat di T4 tidak masuk [T1, T4).
T_AKHIR = "2026-10-01T00:00:00.000"
lr3 = get_laba_rugi(T1, T_AKHIR)
print("     laba bersih [T1, 1 Okt) = %d" % lr3["labaBersih"])
cek("penjualan hutang tetap menambah laba (65.000 - HPP 40.000)",
    lr3["labaBersih"] == 110_000 + 25_000, lr3["labaBersih"])
cek("penjualan tepat di batas T4 TIDAK masuk rentang [T1,T4)",
    get_laba_rugi(T1, T4)["labaBersih"] == 110_000,
    get_laba_rugi(T1, T4)["labaBersih"])

# --- 8. Bayar hutang supplier -> kas keluar, hutang turun
con.execute("UPDATE debts SET paid_amount = paid_amount + 200000, status='paid' "
            "WHERE type='hutang'")
catat_kas("out", 200_000, "bayar_hutang", T4, "debt_payment", None)
con.commit()
n5 = get_neraca()
cek("hutang lunas -> 0", n5["hutang"] == 0, n5["hutang"])
cek("kas turun 200.000", n5["kas"] == n4["kas"] - 200_000, n5["kas"])
cek("neraca tetap seimbang", n5["totalAset"] == n5["hutang"] + n5["totalEkuitas"],
    "%d vs %d" % (n5["totalAset"], n5["hutang"] + n5["totalEkuitas"]))
cek("penyesuaian tetap NOL", n5["penyesuaian"] == 0, n5["penyesuaian"])

# --- 9. Rentang setengah terbuka: penjualan di batas tidak dihitung dua kali
awal_bulan = get_laba_rugi("2026-09-01T00:00:00.000", "2026-09-15T00:00:00.000")
sisa_bulan = get_laba_rugi("2026-09-15T00:00:00.000", "2026-10-01T00:00:00.000")
penuh = get_laba_rugi("2026-09-01T00:00:00.000", "2026-10-01T00:00:00.000")
cek("potongan periode tidak tumpang tindih di batas",
    awal_bulan["pendapatan"] + sisa_bulan["pendapatan"] == penuh["pendapatan"],
    "%d + %d != %d" % (awal_bulan["pendapatan"], sisa_bulan["pendapatan"],
                       penuh["pendapatan"]))
cek("laba bersih juga tidak dobel",
    awal_bulan["labaBersih"] + sisa_bulan["labaBersih"] == penuh["labaBersih"],
    "%d + %d != %d" % (awal_bulan["labaBersih"], sisa_bulan["labaBersih"],
                       penuh["labaBersih"]))

# --- 10. HPP memakai harga modal SAAT TERJUAL, bukan harga sekarang
sebelum_ubah = get_hpp(T1, T4)
con.execute("UPDATE products SET cost_price = 99_999 WHERE id = ?", (p1,))
con.commit()
sesudah_ubah = get_hpp(T1, T4)
cek("HPP tidak berubah walau harga modal produk diubah",
    sebelum_ubah == sesudah_ubah, "%d -> %d" % (sebelum_ubah, sesudah_ubah))

# --- 11. Pembagian nol aman
lr_kosong = get_laba_rugi("2020-01-01T00:00:00.000", "2020-01-02T00:00:00.000")
margin = 0 if lr_kosong["pendapatan"] == 0 else lr_kosong["labaKotor"] / lr_kosong["pendapatan"]
cek("margin kotor aman saat pendapatan 0",
    lr_kosong["pendapatan"] == 0 and margin == 0, margin)


# --- 12. Stok lama tanpa transaksi -> baris penyeimbang terisi tepat nilainya
# Inilah kasus nyata pemilik toko: sudah punya stok sebelum pakai aplikasi.
# Baris "Modal awal & penyesuaian" HARUS muncul sebesar nilai stok itu —
# dan neraca tetap seimbang.
sebelum = get_neraca()
p3 = tambah_produk("Kopi sachet", 10, 5_000, 7_000)   # stok datang entah dari mana
con.commit()
sesudah = get_neraca()
print("     stok tanpa transaksi 10 x 5.000: penyesuaian %d -> %d"
      % (sebelum["penyesuaian"], sesudah["penyesuaian"]))
cek("persediaan naik 50.000", sesudah["persediaan"] == sebelum["persediaan"] + 50_000,
    sesudah["persediaan"])
cek("penyesuaian naik TEPAT 50.000",
    sesudah["penyesuaian"] == sebelum["penyesuaian"] + 50_000,
    sesudah["penyesuaian"])
cek("neraca tetap seimbang dengan stok tanpa transaksi",
    sesudah["totalAset"] == sesudah["hutang"] + sesudah["totalEkuitas"],
    "%d vs %d" % (sesudah["totalAset"],
                  sesudah["hutang"] + sesudah["totalEkuitas"]))


print("\n" + "=" * 46)
print("LULUS: %d   GAGAL: %d" % (lulus, gagal))
print("=" * 46)
sys.exit(0 if gagal == 0 else 1)
