#!/usr/bin/env python3
"""Periksa APK rilis sebelum diumumkan ke pelanggan.

Dua hal yang diam-diam merusak pembaruan pelanggan, dan keduanya diperiksa
di sini:

1. **versionCode tidak naik.** Android menolak memasang APK di atas aplikasi
   yang sudah terpasang kalau versionCode-nya sama atau lebih kecil. Build
   tetap hijau, rilis tetap terbit, pelanggan tidak pernah menerima apa pun.
2. **APK ditandatangani debug key.** Aplikasi yang sudah terpasang dengan
   kunci rilis tidak bisa ditimpa oleh APK berkunci debug.

`aapt`/`apkanalyzer` tidak ada di mesin ini, jadi AndroidManifest.xml biner
diurai langsung — tanpa perlu Java. Pemeriksaan sertifikat memakai `keytool`
kalau tersedia.

Pakai:
    python tools/cek-apk-rilis.py app-release.apk
    python tools/cek-apk-rilis.py app-release.apk --harap-versi 1.7.0 --harap-kode 12
    python tools/cek-apk-rilis.py app-release.apk \
        --keystore D:/BACKUP-tokoku-signing/tokoku-release.jks \
        --storepass-file D:/BACKUP-tokoku-signing/storepass.txt

Keluar dengan kode 1 kalau ada pemeriksaan yang gagal, supaya bisa dipakai
di skrip.
"""

import argparse
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import zipfile

RES_XML_TYPE = 0x0003
RES_STRING_POOL = 0x0001
RES_XML_START_ELEMENT = 0x0102

# Nilai tipe atribut di AXML.
TIPE_STRING = 0x03
TIPE_INT_DEC = 0x10

gagal = []


def cek(nama, kondisi, detail=""):
    print(("  OK    " if kondisi else "  GAGAL ") + nama +
          ("  -> " + str(detail) if (detail and not kondisi) else ""))
    if not kondisi:
        gagal.append(nama)
    return kondisi


def baca_string_pool(data, off):
    """Ambil daftar string dari chunk RES_STRING_POOL."""
    header_size = struct.unpack_from('<H', data, off + 2)[0]
    string_count, _style_count, flags, strings_start, _styles_start = \
        struct.unpack_from('<IIIII', data, off + 8)

    utf8 = bool(flags & 0x100)
    offsets = struct.unpack_from('<%dI' % string_count, data, off + header_size)
    base = off + strings_start

    hasil = []
    for o in offsets:
        p = base + o
        if utf8:
            # Panjang UTF-8 ditulis dalam 1 atau 2 byte, lalu jumlah byte.
            n = data[p]
            p += 1
            if n & 0x80:
                n = ((n & 0x7F) << 8) | data[p]
                p += 1
            n2 = data[p]
            p += 1
            if n2 & 0x80:
                n2 = ((n2 & 0x7F) << 8) | data[p]
                p += 1
            hasil.append(data[p:p + n].decode('utf-8', 'replace'))
        else:
            n = struct.unpack_from('<H', data, p)[0]
            p += 2
            if n & 0x8000:
                n = ((n & 0x7FFF) << 16) | struct.unpack_from('<H', data, p)[0]
                p += 2
            hasil.append(data[p:p + n * 2].decode('utf-16-le', 'replace'))
    return hasil


def baca_manifest(data):
    """Kembalikan atribut elemen <manifest> sebagai dict."""
    if struct.unpack_from('<H', data, 0)[0] != RES_XML_TYPE:
        raise ValueError('AndroidManifest.xml bukan AXML yang dikenali')

    off = struct.unpack_from('<H', data, 2)[0]
    total = struct.unpack_from('<I', data, 4)[0]

    strings = None
    hasil = {}
    while off < total:
        ctype, _chdr, csize = struct.unpack_from('<HHI', data, off)
        if csize == 0:
            break

        if ctype == RES_STRING_POOL and strings is None:
            strings = baca_string_pool(data, off)

        elif ctype == RES_XML_START_ELEMENT and strings is not None:
            name_i = struct.unpack_from('<I', data, off + 20)[0]
            attr_start, attr_size, attr_count = \
                struct.unpack_from('<HHH', data, off + 24)
            nama_tag = strings[name_i] if name_i < len(strings) else '?'

            if nama_tag == 'manifest':
                for k in range(attr_count):
                    a = off + 16 + attr_start + k * attr_size
                    a_name, _a_raw = struct.unpack_from('<II', data, a + 4)
                    a_type = data[a + 15]
                    a_data = struct.unpack_from('<I', data, a + 16)[0]
                    kunci = strings[a_name] if a_name < len(strings) else '?'
                    if kunci in ('package', 'versionCode', 'versionName'):
                        if a_type == TIPE_INT_DEC:
                            hasil[kunci] = a_data
                        elif a_type == TIPE_STRING:
                            hasil[kunci] = strings[a_data]
                        else:
                            hasil[kunci] = '(tipe 0x%02x)' % a_type
        off += csize

    return hasil, (strings or [])


def sertifikat_apk(apk):
    """(sidik jari SHA-256, pemilik, galat) sertifikat penanda tangan APK."""
    keytool = shutil.which('keytool')
    if not keytool:
        return None, None, 'keytool tidak ada di PATH'
    try:
        out = subprocess.run([keytool, '-printcert', '-jarfile', apk],
                             capture_output=True, text=True, timeout=120)
    except Exception as e:            # noqa: BLE001
        return None, None, 'keytool gagal: %s' % e
    teks = (out.stdout or '') + (out.stderr or '')

    sha = re.search(r'SHA256:\s*([0-9A-F:]{40,})', teks, re.I)
    owner = re.search(r'Owner:\s*(.+)', teks)
    if not sha:
        return None, None, teks.strip()[:300] or 'tidak ada sertifikat'
    return (sha.group(1).strip().upper(),
            owner.group(1).strip() if owner else '?', None)


def sertifikat_keystore(path, storepass):
    """Sidik jari SHA-256 sertifikat di dalam keystore, lewat keytool."""
    keytool = shutil.which('keytool')
    if not keytool:
        return None, 'keytool tidak ada di PATH'
    out = subprocess.run([keytool, '-list', '-keystore', path,
                          '-storepass', storepass],
                         capture_output=True, text=True, timeout=120)
    teks = (out.stdout or '') + (out.stderr or '')
    m = re.search(r'Certificate fingerprint \(SHA-256\):\s*([0-9A-F:]{40,})',
                  teks, re.I)
    if not m:
        return None, teks.strip()[:300]
    return m.group(1).strip().upper(), None


def main():
    p = argparse.ArgumentParser(description='Periksa APK rilis TokoKu.')
    p.add_argument('apk', help='berkas APK yang diperiksa')
    p.add_argument('--harap-versi', help='versionName yang diharapkan, mis. 1.7.0')
    p.add_argument('--harap-kode', type=int, help='versionCode yang diharapkan')
    p.add_argument('--keystore', help='keystore rilis untuk dibandingkan')
    p.add_argument('--storepass-file', help='berkas berisi storepass keystore')
    p.add_argument('--paket', default='com.tokoku.sembako',
                   help='package name yang diharapkan')
    a = p.parse_args()

    if not os.path.isfile(a.apk):
        print('Berkas tidak ada: ' + a.apk)
        return 1

    print('== Isi APK ==')
    try:
        with zipfile.ZipFile(a.apk) as z:
            nama = z.namelist()
            cek('berisi AndroidManifest.xml', 'AndroidManifest.xml' in nama)
            cek('berisi classes.dex',
                any(n.startswith('classes') and n.endswith('.dex') for n in nama))
            if 'AndroidManifest.xml' not in nama:
                print('\nBukan APK yang bisa diperiksa: AndroidManifest.xml tidak ada.')
                return 1
            mentah = z.read('AndroidManifest.xml')
    except zipfile.BadZipFile:
        print('Berkas ini bukan APK (bukan arsip ZIP): ' + a.apk)
        return 1

    ukuran = os.path.getsize(a.apk)
    print('  ukuran: %d byte (%.1f MiB)' % (ukuran, ukuran / 1048576))

    print('\n== Manifest ==')
    try:
        man, strings = baca_manifest(mentah)
    except ValueError as e:
        print('  GAGAL  manifest tidak terbaca -> %s' % e)
        return 1

    for kunci in ('package', 'versionCode', 'versionName'):
        print('  %-12s: %s' % (kunci, man.get(kunci, 'TIDAK ADA')))

    cek('versionCode ada', 'versionCode' in man)
    cek('versionName ada', 'versionName' in man)
    if 'package' in man:
        cek('package = %s' % a.paket, man['package'] == a.paket, man['package'])
    if a.harap_versi:
        cek('versionName = %s' % a.harap_versi,
            str(man.get('versionName')) == a.harap_versi, man.get('versionName'))
    if a.harap_kode:
        cek('versionCode = %d' % a.harap_kode,
            man.get('versionCode') == a.harap_kode, man.get('versionCode'))

    # Versi sebelumnya tidak boleh tertinggal di manifest. Diturunkan dari
    # --harap-versi (1.7.0 -> 1.6.0) supaya tidak perlu diperbarui tiap rilis.
    if a.harap_versi and strings:
        bagian = a.harap_versi.split('.')
        if len(bagian) == 3 and bagian[1].isdigit() and int(bagian[1]) > 0:
            lama = '%s.%d.%s' % (bagian[0], int(bagian[1]) - 1, bagian[2])
            cek('versi lama (%s) tidak ikut tertulis di manifest' % lama,
                lama not in strings)

    print('\n== Tanda tangan ==')
    sidik_apk, pemilik, galat = sertifikat_apk(a.apk)
    if sidik_apk:
        print('  sertifikat APK : ' + sidik_apk)
        print('  pemilik        : ' + (pemilik or '?'))
        cek('ditandatangani kunci RILIS, bukan debug key',
            'ANDROID DEBUG' not in (pemilik or '').upper())
    else:
        print('  (sertifikat tidak terbaca: %s)' % galat)

    if a.keystore and a.storepass_file:
        with open(a.storepass_file, encoding='utf-8') as f:
            storepass = f.read().strip()
        sidik_ks, galat = sertifikat_keystore(a.keystore, storepass)
        if sidik_ks:
            print('  sertifikat kunci: ' + sidik_ks)
            cek('sertifikat APK = sertifikat keystore rilis',
                sidik_apk is not None and sidik_apk == sidik_ks,
                '%s vs %s' % (sidik_apk, sidik_ks))
        else:
            # Keystore yang diminta tapi tidak terbaca HARUS menggagalkan
            # pemeriksaan. Kalau tidak, skrip ini akan bilang "LULUS" justru
            # saat pembandingnya tidak ada — kebalikan dari gunanya.
            print('  keystore tidak terbaca: %s' % galat)
            cek('keystore rilis bisa dibaca', False, galat)
    elif a.keystore or a.storepass_file:
        cek('--keystore dan --storepass-file dipakai bersama', False,
            'isi keduanya atau tidak sama sekali')

    print('\n' + '=' * 46)
    if gagal:
        print('GAGAL: %d pemeriksaan' % len(gagal))
        for n in gagal:
            print('  - ' + n)
        return 1
    print('SEMUA PEMERIKSAAN APK LULUS')
    return 0


if __name__ == '__main__':
    sys.exit(main())
