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

fatal = []
notes = []


def read(path):
    return Path(path).read_text(encoding="utf-8")


def write(path, text):
    Path(path).write_text(text, encoding="utf-8")


def patch_manifest():
    path = "android/app/src/main/AndroidManifest.xml"
    if not Path(path).exists():
        fatal.append("AndroidManifest.xml tidak ditemukan: " + path)
        return
    content = read(path)

    if "<uses-permission" in content:
        notes.append("manifest: izin sudah ada, dilewati")
    else:
        # Baris pertama tanpa indentasi: teks asli sudah punya 4 spasi sebelum
        # "<application", jadi indentasi baris pertama datang dari situ.
        perms = "<uses-permission android:name=\"%s\" />\n" % PERMISSIONS[0]
        perms += "".join(
            '    <uses-permission android:name="%s" />\n' % p
            for p in PERMISSIONS[1:]
        )
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
        # Catatan: cek harus pakai "signingConfigs {" (dengan kurung kurawal),
        # karena teks asli sudah memuat "signingConfigs.debug".
        if "signingConfigs {" not in src:
            block = (
                "\n    signingConfigs {\n"
                "        release {\n"
                '            storeFile file("%s")\n' % KEYSTORE_FILENAME
                + '            storePassword System.getenv("KEYSTORE_PASSWORD")\n'
                + '            keyAlias System.getenv("KEY_ALIAS")\n'
                + '            keyPassword System.getenv("KEY_PASSWORD")\n'
                "        }\n"
                "    }\n\n"
            )
            if "buildTypes" in src:
                src = src.replace("buildTypes", block + "    buildTypes", 1)
                notes.append("gradle: blok signingConfigs release ditambahkan")
            else:
                fatal.append("blok buildTypes tidak ditemukan, signing gagal dipasang")

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
                notes.append("gradle: release signing AKTIF (%s)" % KEYSTORE_FILENAME)
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


def main():
    if not Path("android").exists():
        print("ERROR: folder android/ belum ada. Jalankan `flutter create . --platforms android` dulu.")
        return 1

    patch_manifest()
    patch_gradle()
    move_main_activity()

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
        if re.search(r"namespace|applicationId|Sdk|signingConfig|storeFile|keyAlias", line):
            print(line)
    print()

    if fatal:
        print("PATCH GAGAL - build dihentikan supaya APK tidak salah konfigurasi.")
        return 1
    print("Semua patch berhasil.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
