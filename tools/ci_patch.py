#!/usr/bin/env python3
"""Perbaiki folder `android/` hasil `flutter create` saat build di CI.

Repo ini tidak menyimpan folder `android/`, jadi GitHub Actions menjalankan
`flutter create . --platforms android` lebih dulu. Template yang dihasilkan
masih generik, jadi skrip ini merapikannya untuk TokoKu:

  * menyuntikkan izin kamera + bluetooth dan blok <queries> untuk url_launcher
  * memaksa compileSdk 35 / minSdk 21 (dibutuhkan mobile_scanner & flutter_blue_plus)
  * mengganti applicationId dari com.example.tokoku menjadi applicationId asli
  * memindahkan MainActivity ke package yang sesuai
  * memasang release signing dari variabel lingkungan KEYSTORE_*
  * menyalin ikon kustom dari tools/icon/ ke folder android/app/src/main/res/mipmap-*

Jalankan tanpa argumen dari akar repo. Kalau variabel KEYSTORE_PASSWORD tidak
ada, langkah signing dilewati dan APK ditandatangani debug key (hanya untuk uji).
"""

import os
import re
import shutil
import sys
from pathlib import Path

APP_ID = "com.tokoku.sembako"
COMPILE_SDK = "35"
MIN_SDK = "21"
KEYSTORE_FILENAME = "tokoku-release.jks"

PERMISSIONS = [
    "android.permission.INTERNET",
    "android.permission.CAMERA",
    "android.permission.BLUETOOTH",
    "android.permission.BLUETOOTH_ADMIN",
    "android.permission.BLUETOOTH_SCAN",
    "android.permission.BLUETOOTH_CONNECT",
    "android.permission.ACCESS_FINE_LOCATION",
]

QUERIES_INTENT = """        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="https" />
        </intent>
"""

QUERIES_BLOCK = "    <queries>\n" + QUERIES_INTENT + "    </queries>\n"


def baris_izin(nama):
    """Satu baris <uses-permission> untuk AndroidManifest.

    BLUETOOTH_SCAN wajib diberi penanda `neverForLocation`. Tanpa penanda itu,
    Android 12+ menuntut izin lokasi untuk memindai perangkat Bluetooth. Aplikasi
    ini tidak pernah meminta lokasi, jadi pemindaian akan berhasil tanpa pesan
    galat tetapi selalu mengembalikan nol perangkat — persis keluhan "printer
    tidak ditemukan".
    """
    if nama == "android.permission.BLUETOOTH_SCAN":
        return (
            '    <uses-permission android:name="%s"\n'
            '        android:usesPermissionFlags="neverForLocation" />\n' % nama
        )
    return '    <uses-permission android:name="%s" />\n' % nama


fatal = []
notes = []


def read(path):
    return Path(path).read_text(encoding="utf-8")


def write(path, text):
    Path(path).write_text(text, encoding="utf-8")


def detect_store_type(path):
    """Tebak jenis keystore dari magic bytes-nya: 'JKS' atau 'PKCS12'.

    Gradle/AGP memakai JKS sebagai default kalau `storeType` tidak ditulis.
    File yang isinya PKCS12 — hasil `keytool` JDK 9+ meski namanya berakhiran
    `.jks` — hanya terbaca sebagai JKS karena JDK punya fallback
    `keystore.type.compat`. Itu perilaku bawaan JDK yang bisa berubah, jadi
    `storeType` ditulis eksplisit supaya build tidak bergantung padanya.

    Mengembalikan None kalau formatnya tidak dikenali.
    """
    try:
        with open(path, "rb") as f:
            head = f.read(4)
    except OSError:
        return None
    # JKS diawali FE ED FE ED.
    if head == b"\xfe\xed\xfe\xed":
        return "JKS"
    # PKCS12 = ASN.1 SEQUENCE: 0x30 lalu panjang 2 byte (0x82) atau 4 byte (0x84).
    if head[:1] == b"\x30" and len(head) >= 2 and head[1] in (0x82, 0x84):
        return "PKCS12"
    return None


def patch_manifest():
    path = "android/app/src/main/AndroidManifest.xml"
    if not Path(path).exists():
        fatal.append("AndroidManifest.xml tidak ditemukan: " + path)
        return
    content = read(path)

    if "<uses-permission" in content:
        notes.append("manifest: izin sudah ada, dilewati")
    else:
        # Blok izin disisipkan tepat sebelum <application>, di dalam <manifest>.
        # Indentasi baris pertama dibuang karena template sudah menyisakan 4
        # spasi di depan "<application" — tanpa itu barisnya menjorok 8 spasi.
        perms = "".join(baris_izin(p) for p in PERMISSIONS).lstrip()
        content = content.replace("<application", perms + "    <application", 1)
        notes.append("manifest: %d izin disuntikkan" % len(PERMISSIONS))

    if "android.intent.action.VIEW" in content:
        notes.append("manifest: queries VIEW sudah ada, dilewati")
    elif "<queries>" in content:
        content = content.replace("<queries>", "<queries>\n" + QUERIES_INTENT, 1)
        notes.append("manifest: queries VIEW ditambahkan ke blok queries yang ada")
    else:
        match = re.search(r"<manifest[^>]*>", content)
        if not match:
            fatal.append("Tag <manifest> tidak ditemukan")
            return
        content = content[: match.end()] + "\n" + QUERIES_BLOCK + content[match.end() :]
        notes.append("manifest: blok queries baru ditambahkan")

    write(path, content)


def patch_gradle():
    path = "android/app/build.gradle"
    if not Path(path).exists():
        fatal.append("build.gradle tidak ditemukan: " + path)
        return
    src = read(path)

    # Setiap langkah dibuat idempoten: kalau nilainya sudah benar, lewati saja.
    # Aman kalau skrip ini dijalankan dua kali (mis. diuji manual di laptop).
    if re.search(r"compileSdk\s*=\s*" + COMPILE_SDK + r"\b", src):
        notes.append("gradle: compileSdk sudah " + COMPILE_SDK + ", dilewati")
    else:
        src, n = re.subn(
            r"compileSdk(?:Version)?\s*=?\s*flutter\.compileSdkVersion",
            "compileSdk = " + COMPILE_SDK,
            src,
        )
        if n == 0:
            fatal.append("compileSdk tidak berhasil dipatch")
        else:
            notes.append("gradle: compileSdk = " + COMPILE_SDK)

    if re.search(r"minSdk\s*=\s*" + MIN_SDK + r"\b", src):
        notes.append("gradle: minSdk sudah " + MIN_SDK + ", dilewati")
    else:
        src, n = re.subn(
            r"minSdk(?:Version)?\s*=?\s*flutter\.minSdkVersion",
            "minSdk = " + MIN_SDK,
            src,
        )
        if n == 0:
            fatal.append("minSdk tidak berhasil dipatch")
        else:
            notes.append("gradle: minSdk = " + MIN_SDK)

    if 'namespace = "%s"' % APP_ID in src:
        notes.append("gradle: namespace sudah benar, dilewati")
    else:
        src, n = re.subn(r'namespace\s*=\s*"[^"]*"', 'namespace = "%s"' % APP_ID, src)
        if n == 0:
            fatal.append("namespace tidak berhasil dipatch")
        else:
            notes.append("gradle: namespace = " + APP_ID)

    if 'applicationId = "%s"' % APP_ID in src:
        notes.append("gradle: applicationId sudah benar, dilewati")
    else:
        src, n = re.subn(
            r'applicationId\s*=\s*"[^"]*"', 'applicationId = "%s"' % APP_ID, src
        )
        if n == 0:
            fatal.append("applicationId tidak berhasil dipatch")
        else:
            notes.append("gradle: applicationId = " + APP_ID)

    store_password = os.environ.get("KEYSTORE_PASSWORD", "").strip()
    keystore_path = Path("android/app") / KEYSTORE_FILENAME
    keystore_ok = keystore_path.exists()

    # Signing rilis hanya dipasang kalau DUA-DUANYA ada: file keystore dan
    # passwordnya. Kalau salah satu hilang, lebih baik APK ditandatangani debug
    # key daripada build gagal total (storeFile yang tidak ada = error Gradle).
    if store_password and keystore_ok:
        # Jenis keystore ditulis eksplisit supaya Gradle tidak menebak. File
        # berakhiran .jks bisa saja isinya PKCS12 (hasil keytool JDK baru).
        store_type = detect_store_type(keystore_path)
        if store_type is None:
            # Jangan menulis blok signing yang sudah pasti salah — biarkan
            # `fatal` yang menghentikan build dengan pesan yang jelas.
            with open(keystore_path, "rb") as f:
                head = f.read(4)
            fatal.append(
                "jenis keystore tidak dikenali (magic bytes %s). Harus JKS "
                "atau PKCS12." % " ".join("%02X" % b for b in head)
            )
        else:
            # Catatan: cek harus pakai "signingConfigs {" (dengan kurung
            # kurawal), karena teks asli sudah memuat "signingConfigs.debug".
            if "signingConfigs {" not in src:
                block = (
                    "\n    signingConfigs {\n"
                    "        release {\n"
                    '            storeFile file("%s")\n' % KEYSTORE_FILENAME
                    + '            storePassword System.getenv("KEYSTORE_PASSWORD")\n'
                    + '            keyAlias System.getenv("KEY_ALIAS")\n'
                    + '            keyPassword System.getenv("KEY_PASSWORD")\n'
                    + '            storeType "%s"\n' % store_type
                    + "        }\n"
                    "    }\n\n"
                )
                if "buildTypes" in src:
                    src = src.replace("buildTypes", block + "    buildTypes", 1)
                    notes.append(
                        "gradle: blok signingConfigs release ditambahkan "
                        "(storeType=%s)" % store_type
                    )
                else:
                    fatal.append(
                        "blok buildTypes tidak ditemukan, signing gagal dipasang"
                    )

            if "signingConfig = signingConfigs.release" in src:
                notes.append("gradle: release signing sudah aktif, dilewati")
            else:
                src, n = re.subn(
                    r"signingConfig\s*=\s*signingConfigs\.debug",
                    "signingConfig = signingConfigs.release",
                    src,
                )
                if n == 0:
                    fatal.append("signingConfigs.debug tidak berhasil diganti")
                else:
                    notes.append(
                        "gradle: release signing AKTIF (%s) — password dibaca "
                        "SAAT BUILD, jadi langkah 'Build APK release' wajib "
                        "menerima env KEYSTORE_PASSWORD/KEY_ALIAS/KEY_PASSWORD"
                        % KEYSTORE_FILENAME
                    )
    elif store_password and not keystore_ok:
        notes.append(
            "gradle: KEYSTORE_PASSWORD ada tapi %s TIDAK ADA -> DEBUG KEY "
            "(cek secret KEYSTORE_BASE64)" % KEYSTORE_FILENAME
        )
    else:
        notes.append("gradle: signing dilewati (KEYSTORE_PASSWORD kosong) -> DEBUG KEY")

    write(path, src)


def move_main_activity():
    roots = [
        Path("android/app/src/main/kotlin"),
        Path("android/app/src/main/java"),
    ]
    found = []
    for root in roots:
        if root.exists():
            found.extend(root.rglob("MainActivity.kt"))
            found.extend(root.rglob("MainActivity.java"))
    if not found:
        notes.append("MainActivity: tidak ditemukan (lewati, mungkin tak diperlukan)")
        return

    for old in found:
        suffix = old.suffix
        new = Path("android/app/src/main/kotlin") / Path(*APP_ID.split(".")) / (
            "MainActivity" + suffix
        )
        if old.resolve() == new.resolve():
            notes.append("MainActivity: sudah di lokasi benar, dilewati")
            continue
        text = read(old)
        text = re.sub(
            r"^package\s+[\w.]+", "package " + APP_ID, text, count=1, flags=re.M
        )
        new.parent.mkdir(parents=True, exist_ok=True)
        write(new, text)
        notes.append("MainActivity: %s -> %s" % (old.as_posix(), new.as_posix()))

    old_dir = Path("android/app/src/main/kotlin/com/example")
    if old_dir.exists():
        shutil.rmtree(old_dir)
        notes.append("MainActivity: folder com/example dihapus")
    old_java = Path("android/app/src/main/java/com/example")
    if old_java.exists():
        shutil.rmtree(old_java)
        notes.append("MainActivity: folder java/com/example dihapus")


# Pemetaan nama file ikon (tanpa .png) ke subfolder mipmap Android.
# Ikon disimpan di tools/icon/ dan disalin saat CI ke res/mipmap-*/ic_launcher.png.
ICON_SIZES = [
    ("mipmap-mdpi",     "mipmap-mdpi"),
    ("mipmap-hdpi",     "mipmap-hdpi"),
    ("mipmap-xhdpi",    "mipmap-xhdpi"),
    ("mipmap-xxhdpi",   "mipmap-xxhdpi"),
    ("mipmap-xxxhdpi",  "mipmap-xxxhdpi"),
]


def install_icon():
    """Salin ikon kustom TokoKu ke folder android/app/src/main/res/mipmap-*.

    flutter create menghasilkan ikon Flutter bawaan (kupu-kupu biru). Fungsi
    ini menggantinya dengan logo TokoKu dari tools/icon/ supaya APK yang
    dihasilkan CI sudah memakai ikon yang benar tanpa langkah manual.

    Kalau folder tools/icon/ tidak ada (mis. repo di-clone baru dan belum ada
    gambar), langkah ini dilewati dan bukan dianggap fatal — ikon bawaan Flutter
    tidak rusak, hanya kurang pas tampilannya.
    """
    icon_src_dir = Path("tools") / "icon"
    if not icon_src_dir.exists():
        notes.append("icon: folder tools/icon/ tidak ditemukan, dilewati")
        return

    res_dir = Path("android/app/src/main/res")
    dipasang = 0
    for size_name, mipmap_folder in ICON_SIZES:
        # Cari file sumber: lebih dulu _launcher variant, lalu generic.
        src_launcher = icon_src_dir / (size_name + "_launcher.png")
        src_generic  = icon_src_dir / (size_name + ".png")
        src = src_launcher if src_launcher.exists() else (src_generic if src_generic.exists() else None)
        if src is None:
            notes.append(f"icon: {size_name}.png tidak ditemukan, dilewati")
            continue

        dest_dir = res_dir / mipmap_folder
        dest_dir.mkdir(parents=True, exist_ok=True)

        # ic_launcher.png
        shutil.copy2(src, dest_dir / "ic_launcher.png")

        # ic_launcher_round.png — cari versi round khusus, fallback ke yang sama
        src_round = icon_src_dir / (size_name + "_launcher_round.png")
        shutil.copy2(src_round if src_round.exists() else src, dest_dir / "ic_launcher_round.png")

        dipasang += 1

    notes.append(f"icon: {dipasang} ukuran ic_launcher dipasang dari tools/icon/")

    # Pastikan android:roundIcon terdaftar di AndroidManifest — template lama
    # terkadang melewatinya dan launcher Android menampilkan ikon persegi.
    manifest_path = "android/app/src/main/AndroidManifest.xml"
    if Path(manifest_path).exists():
        content = read(manifest_path)
        if 'android:roundIcon' not in content:
            content = content.replace(
                'android:icon="@mipmap/ic_launcher"',
                'android:icon="@mipmap/ic_launcher" android:roundIcon="@mipmap/ic_launcher_round"',
                1,
            )
            write(manifest_path, content)
            notes.append("icon: android:roundIcon ditambahkan ke AndroidManifest")
        else:
            notes.append("icon: android:roundIcon sudah ada, dilewati")


# Berkas Kotlin yang disalin ke folder android/ setiap build, beserta objek
# yang kanalnya harus didaftarkan di MainActivity.
NATIVE_FILES = [
    ("PrinterSpp.kt", "PrinterSpp"),
    ("ScannerUsb.kt", "ScannerUsb"),
]

IZIN_BLOK = """
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        PrinterSpp.terimaIzin(requestCode, grantResults)
    }
"""


def install_native_channels():
    """Pasang jembatan native: printer Classic SPP + daftar alat USB.

    Keduanya tidak bisa dibuat di Dart:

      * PrinterSpp -- printer thermal 58 mm seperti RPP02N memakai Bluetooth
        Classic SPP, sedangkan flutter_blue_plus hanya BLE. Perangkat Classic
        TIDAK PERNAH muncul di pemindaian BLE.
      * ScannerUsb -- daftar alat USB hanya terbaca lewat UsbManager. Scanner
        USB sendiri tetap bekerja tanpa ini (Android meneruskan ketikannya
        sebagai keyboard), tetapi tanpa daftar alat tidak ada cara membedakan
        "belum dicolok" dari "tercolok dalam mode COM".

    Kalau salah satu berkas sumbernya hilang, ini FATAL: APK tanpa PrinterSpp
    kembali ke bug lama (printer tidak pernah ditemukan), dan APK tanpa
    ScannerUsb selalu berkata "tidak ada alat" -- dua-duanya tanpa gejala yang
    bisa dilihat dari luar.
    """
    tujuan_dir = Path("android/app/src/main/kotlin") / Path(*APP_ID.split("."))
    tujuan_dir.mkdir(parents=True, exist_ok=True)

    terpasang = []
    for nama, objek in NATIVE_FILES:
        sumber = Path("tools") / "android" / nama
        if not sumber.exists():
            fatal.append(
                "tools/android/%s tidak ada - dukungan %s tidak akan ikut ke APK"
                % (nama, objek)
            )
            continue
        tujuan = tujuan_dir / nama
        shutil.copy2(sumber, tujuan)
        terpasang.append(objek)
        notes.append("native: %s disalin ke %s" % (nama, tujuan.as_posix()))

    if not terpasang:
        return

    patch_main_activity(terpasang)


def patch_main_activity(kelas):
    """Daftarkan kanal native di MainActivity hasil `flutter create`."""
    path = (
        Path("android/app/src/main/kotlin")
        / Path(*APP_ID.split("."))
        / "MainActivity.kt"
    )
    if not path.exists():
        fatal.append(
            "MainActivity.kt tidak ditemukan di %s - kanal native tidak "
            "terdaftar dan printer Classic maupun daftar alat USB tidak bisa "
            "dipakai" % path.as_posix()
        )
        return

    teks = read(path)

    kurang = [k for k in kelas if ("%s.daftarkan" % k) not in teks]
    butuh_izin = "PrinterSpp" in kelas and "PrinterSpp.terimaIzin" not in teks

    if not kurang and not butuh_izin:
        notes.append("native: MainActivity sudah mendaftarkan semua kanal, dilewati")
        return

    if "import io.flutter.embedding.engine.FlutterEngine" not in teks:
        teks, n = re.subn(
            r"^package\s+[\w.]+[ \t]*$",
            "\\g<0>\n\nimport io.flutter.embedding.engine.FlutterEngine",
            teks,
            count=1,
            flags=re.M,
        )
        if n == 0:
            fatal.append("baris package MainActivity tidak ditemukan, impor gagal")
            return

    daftar_baris = "".join(
        "        %s.daftarkan(this, flutterEngine.dartExecutor.binaryMessenger)\n" % k
        for k in kurang
    )

    if "override fun configureFlutterEngine" in teks:
        # MainActivity yang sudah pernah dipatch: menambah override kedua dengan
        # nama yang sama tidak bisa dikompilasi, jadi barisnya disisipkan ke
        # override yang sudah ada.
        pola = re.compile(r"super\.configureFlutterEngine\s*\([^)]*\)[ \t]*\r?\n")
        cocok = pola.search(teks)
        if not cocok:
            fatal.append(
                "configureFlutterEngine sudah ada tetapi baris super-nya tidak "
                "ditemukan - kanal native gagal didaftarkan"
            )
            return
        teks = teks[: cocok.end()] + daftar_baris + teks[cocok.end() :]
        notes.append(
            "native: %d kanal disisipkan ke configureFlutterEngine yang ada"
            % len(kurang)
        )
    else:
        kelas_re = re.search(
            r"class\s+MainActivity\s*:\s*FlutterActivity\s*\(\s*\)", teks
        )
        if not kelas_re:
            fatal.append(
                "bentuk kelas MainActivity tidak dikenali (bukan "
                "'class MainActivity: FlutterActivity()') - kanal native gagal "
                "didaftarkan"
            )
            return

        sisip = (
            "\n    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {\n"
            "        super.configureFlutterEngine(flutterEngine)\n"
            + daftar_baris
            + "    }\n"
        )
        if butuh_izin:
            sisip += IZIN_BLOK

        # DUA bentuk kelas harus ditangani:
        #
        #   Flutter 3.27 (template sekarang):  class MainActivity: FlutterActivity()
        #   Flutter lama:                      class MainActivity: FlutterActivity() { }
        #
        # Template 3.27 TIDAK menulis kurung kurawal sama sekali. Percobaan
        # pertama hanya menangani bentuk ber-kurung, sehingga build v1.28.2
        # berhenti di sini dengan "bentuk kelas MainActivity tidak dikenali".
        sisa = teks[kelas_re.end() :]
        spasi = re.match(r"[ \t\r\n]*", sisa)
        awal = kelas_re.end() + (spasi.end() if spasi else 0)

        if teks[awal : awal + 1] == "{":
            teks = teks[: awal + 1] + sisip + teks[awal + 1 :]
            notes.append(
                "native: badan kelas sudah ada, overrides disisipkan di dalamnya"
            )
        else:
            teks = teks[: kelas_re.end()] + " {" + sisip + "}" + teks[kelas_re.end() :]
            notes.append("native: kelas tanpa badan ditambahi badan + overrides")

        # Blok izin sudah ikut di dalam `sisip`.
        butuh_izin = False

    if butuh_izin:
        if "override fun onRequestPermissionsResult" in teks:
            notes.append("native: onRequestPermissionsResult sudah ada, dilewati")
        else:
            pos = teks.rfind("}")
            if pos == -1:
                fatal.append("penutup kelas MainActivity tidak ditemukan")
                return
            teks = teks[:pos] + IZIN_BLOK + teks[pos:]
            notes.append(
                "native: onRequestPermissionsResult disisipkan sebelum penutup kelas"
            )

    write(path, teks)
    notes.append("native: kanal terdaftar (%s)" % ", ".join(kelas))


def main():
    if not Path("android").exists():
        print("ERROR: folder android/ belum ada. Jalankan `flutter create . --platforms android` dulu.")
        return 1

    patch_manifest()
    patch_gradle()
    move_main_activity()
    install_native_channels()
    install_icon()

    print("=" * 60)
    for n in notes:
        print("  ok   " + n)
    for f in fatal:
        print("  FAIL " + f)
    print("=" * 60)

    print("\n--- AndroidManifest.xml ---")
    print(read("android/app/src/main/AndroidManifest.xml"))
    print("\n--- baris penting build.gradle ---")
    for line in read("android/app/build.gradle").splitlines():
        if re.search(
            r"namespace|applicationId|Sdk|signingConfig|storeFile|storeType|keyAlias",
            line,
        ):
            print(line)
    print()

    if fatal:
        print("PATCH GAGAL - build dihentikan supaya APK tidak salah konfigurasi.")
        return 1
    print("Semua patch berhasil.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
