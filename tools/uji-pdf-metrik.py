#!/usr/bin/env python3
"""Uji tabel metrik font dan tata letak penulis PDF TokoKu.

Jalankan:  python tools/uji-pdf-metrik.py

Kenapa ada berkas Python di repo Flutter ini?
Ekspor PDF ditulis tangan (lib/shared/services/pdf_builder.dart) tanpa pustaka
pihak ketiga, jadi tidak ada yang memeriksa hasilnya. Kesalahan metrik font
tidak membuat build gagal — yang terjadi cuma tulisan melewati tepi kanan
halaman dan terpotong saat dicetak. Skrip ini menjaga bagian itu.

Yang diperiksa:
  1. Tabel lebar Helvetica (95 entri, ASCII 32..126) cocok dengan berkas AFM
     resmi Adobe — satu per satu.
  2. Tabel lebar Helvetica-Bold juga cocok, dan TIDAK sama dengan tabel biasa.
     Kalau kedua tabel identik, teks tebal diukur dengan metrik reguler dan
     nilai rata kanan akan melewati margin kanan.
  3. Setiap pemanggilan textWidth() meneruskan penanda `bold`, dan penanda itu
     mengalir sampai ke pengukuran di _textRight/_fit/_wrap/text/keyValue/row.
  4. Teks panjang dilipat (_wrap) di text() dan note(), bukan digambar
     sebagai satu baris panjang.
  5. row() tidak membagi dengan total bobot nol (yang menghasilkan Infinity
     dan PDF rusak tanpa pesan yang jelas).

PENTING — risiko drift: skrip ini MEMBACA sumber Dart, bukan menjalankannya.
Pemeriksaannya berbasis pola, jadi kalau kamu menulis ulang tata letak dengan
cara yang sangat berbeda, pemeriksaan di bagian 3-5 bisa perlu disesuaikan.
Bagian 1-2 (tabel metrik) tetap berlaku apa pun bentuk kodenya.

Pembuktian byte-nyata (bukan sekadar pola) dilakukan sekali secara manual:
PDF hasil ditulis ulang dengan Python, lalu dibuka dengan pypdf dan dirender
dengan PDFium (mesin cetak Chrome) untuk mengukur tinta paling kanan.
"""

import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BERKAS_PDF = os.path.join(REPO, "lib/shared/services/pdf_builder.dart")

lulus = 0
gagal = 0


def cek(nama, kondisi, detail=""):
    global lulus, gagal
    if kondisi:
        lulus += 1
        print("  OK    %s" % nama)
    else:
        gagal += 1
        print("  GAGAL %s  %s" % (nama, detail))


# ---------------------------------------------------------------------------
# Nilai resmi dari berkas AFM Adobe (Core 14) untuk ASCII 32..126, satuan
# 1/1000 em. Sudah dicocokkan dengan data metrik di pdfminer.six.
# ---------------------------------------------------------------------------
AFM_HELVETICA = [
    278, 278, 355, 556, 556, 889, 667, 191, 333, 333,   # 32..41
    389, 584, 278, 333, 278, 278,                       # 42..47
    556, 556, 556, 556, 556, 556, 556, 556, 556, 556,   # 48..57
    278, 278, 584, 584, 584, 556, 1015,                 # 58..64
    667, 667, 722, 722, 667, 611, 778, 722, 278, 500,   # 65..74
    667, 556, 833, 722, 778, 667, 778, 722, 667, 611,   # 75..84
    722, 667, 944, 667, 667, 611,                       # 85..90
    278, 278, 278, 469, 556, 333,                       # 91..96
    556, 556, 500, 556, 556, 278, 556, 556, 222, 222,   # 97..106
    500, 222, 833, 556, 556, 556, 556, 333, 500, 278,   # 107..116
    556, 500, 722, 500, 500, 500,                       # 117..122
    334, 260, 334, 584,                                 # 123..126
]

AFM_HELVETICA_BOLD = [
    278, 333, 474, 556, 556, 889, 722, 238, 333, 333,   # 32..41
    389, 584, 278, 333, 278, 278,                       # 42..47
    556, 556, 556, 556, 556, 556, 556, 556, 556, 556,   # 48..57
    333, 333, 584, 584, 584, 611, 975,                  # 58..64
    722, 722, 722, 722, 667, 611, 778, 722, 278, 556,   # 65..74
    722, 611, 833, 722, 778, 667, 778, 722, 667, 611,   # 75..84
    722, 667, 944, 667, 667, 611,                       # 85..90
    333, 278, 333, 584, 556, 333,                       # 91..96
    556, 611, 556, 611, 556, 333, 611, 611, 278, 278,   # 97..106
    556, 278, 889, 611, 611, 611, 611, 389, 556, 333,   # 107..116
    611, 556, 778, 556, 556, 500,                       # 117..122
    389, 280, 389, 584,                                 # 123..126
]


def tabel_dari_dart(isi, nama):
    """Ambil isi `nama = [ ... ];` dari sumber Dart sebagai list int."""
    m = re.search(r"%s\s*=\s*\[(.*?)\];" % re.escape(nama), isi, re.S)
    if not m:
        return None
    tanpa_komentar = re.sub(r"//.*", "", m.group(1))
    return [int(x) for x in re.findall(r"\d+", tanpa_komentar)]


def badan_method(isi, nama):
    """Isi badan method `nama(...) { ... }`, daftar parameter dilewati.

    Blok parameter bernama `{bool bold = false}` harus dilewati dulu, kalau
    tidak ia akan disangka badan method.
    """
    m = re.search(r"\b%s\s*\(" % re.escape(nama), isi)
    if not m:
        return None
    i = m.end() - 1
    dalam = 0
    while i < len(isi):
        if isi[i] == "(":
            dalam += 1
        elif isi[i] == ")":
            dalam -= 1
            if dalam == 0:
                break
        i += 1
    j = isi.find("{", i)
    if j < 0:
        return None
    dalam = 0
    k = j
    while k < len(isi):
        if isi[k] == "{":
            dalam += 1
        elif isi[k] == "}":
            dalam -= 1
            if dalam == 0:
                return isi[j:k]
        k += 1
    return None


def main():
    if not os.path.exists(BERKAS_PDF):
        print("Berkas tidak ditemukan: %s" % BERKAS_PDF)
        return 2
    with open(BERKAS_PDF, encoding="utf-8") as f:
        isi = f.read()

    print("== 1. Tabel metrik Helvetica ==")
    tabel = tabel_dari_dart(isi, "_helveticaWidths")
    cek("tabel reguler ada", tabel is not None)
    if tabel is not None:
        cek("tabel reguler punya 95 entri (ASCII 32..126)", len(tabel) == 95,
            len(tabel))
        beda = ["ASCII %d: %d != %d" % (i + 32, a, b)
                for i, (a, b) in enumerate(zip(tabel, AFM_HELVETICA)) if a != b]
        cek("semua 95 lebar cocok dengan Adobe Helvetica.afm", not beda,
            " | ".join(beda[:5]))
    cek("akses tabel dijaga rentang 32..126",
        re.search(r"if\s*\(c\s*>=\s*32\s*&&\s*c\s*<=\s*126\)[\s\S]{0,80}?"
                  r"tabel\[c\s*-\s*32\]", isi) is not None)
    cek("rune > 0xFF dipetakan ke '?'",
        re.search(r"rune\s*>\s*0xFF\s*\?\s*0x3F", isi) is not None)

    print("\n== 2. Tabel metrik Helvetica-Bold ==")
    tabel_bold = tabel_dari_dart(isi, "_helveticaBoldWidths")
    cek("tabel bold ada", tabel_bold is not None)
    if tabel_bold is not None:
        cek("tabel bold punya 95 entri", len(tabel_bold) == 95, len(tabel_bold))
        beda = ["ASCII %d: %d != %d" % (i + 32, a, b)
                for i, (a, b) in enumerate(zip(tabel_bold, AFM_HELVETICA_BOLD))
                if a != b]
        cek("semua 95 lebar bold cocok dengan Adobe Helvetica-Bold.afm",
            not beda, " | ".join(beda[:5]))
        cek("tabel bold TIDAK sama dengan tabel reguler",
            tabel_bold != tabel,
            "identik - teks tebal akan diukur dengan metrik reguler")

    print("\n== 3. textWidth() sadar-bold ==")
    cek("textWidth menerima parameter bold",
        re.search(r"textWidth\s*\(\s*String\s+text\s*,\s*double\s+size\s*,"
                  r"\s*\{\s*bool\s+bold\s*=\s*false\s*\}", isi) is not None)
    cek("textWidth memilih tabel sesuai bold",
        re.search(r"bold\s*\?\s*_helveticaBoldWidths\s*:\s*_helveticaWidths",
                  isi) is not None)

    panggilan = [p for p in
                 re.findall(r"textWidth\((?:[^()]|\([^()]*\))*\)", isi)
                 if "String text" not in p]
    tanpa_bold = [p for p in panggilan if "bold:" not in p]
    cek("semua %d pemanggilan textWidth() meneruskan bold" % len(panggilan),
        not tanpa_bold, " | ".join(tanpa_bold[:3]))

    ALIRAN = [
        ("_textRight", r"textWidth\(text,\s*size,\s*bold:\s*bold\)"),
        ("_fit", r"textWidth\(value,\s*size,\s*bold:\s*bold\)"),
        ("_fit", r"textWidth\('\$out\.\.\.',\s*size,\s*bold:\s*bold\)"),
        ("_wrap", r"textWidth\(calon,\s*size,\s*bold:\s*bold\)"),
        ("text", r"_wrap\(value,\s*size,\s*contentWidth,\s*bold:\s*bold\)"),
        ("keyValue", r"textWidth\(value,\s*size,\s*bold:\s*bold\)"),
        ("keyValue",
         r"_fit\(label,\s*size,\s*maxLabel,\s*minKeep:\s*2,\s*bold:\s*bold\)"),
        ("row", r"_fit\(cells\[i\],\s*size,\s*colWidth\s*-\s*4,\s*bold:\s*bold\)"),
        ("heading", r"_fit\(text,\s*15,\s*contentWidth,\s*bold:\s*true\)"),
    ]
    for nama, pola in ALIRAN:
        isi_m = badan_method(isi, nama)
        cek("%s() meneruskan bold ke pengukuran" % nama,
            isi_m is not None and re.search(pola, isi_m) is not None,
            "pola %s tidak ditemukan" % pola)

    print("\n== 4. Teks panjang dilipat ==")
    cek("text() melipat lewat _wrap",
        re.search(r"for\s*\(final\s+baris\s+in\s+_wrap\(", isi) is not None)
    for nama in ("text", "note"):
        isi_m = badan_method(isi, nama)
        cek("%s() memakai _wrap" % nama,
            isi_m is not None and "_wrap(" in isi_m)

    print("\n== 5. Pembagian aman di row() ==")
    isi_row = badan_method(isi, "row")
    cek("row() menjatuhkan total bobot nol ke bobot rata",
        isi_row is not None
        and re.search(r"jumlahBobot\s*>\s*0\s*\?\s*jumlahBobot", isi_row)
        is not None
        and re.search(r"jumlahBobot\s*>\s*0\s*\?\s*w\[i\]\s*:\s*1\.0", isi_row)
        is not None,
        "pembagian dengan total bobot nol menghasilkan Infinity")

    print()
    print("=" * 46)
    print("LULUS: %d   GAGAL: %d" % (lulus, gagal))
    print("=" * 46)
    return 1 if gagal else 0


if __name__ == "__main__":
    sys.exit(main())
