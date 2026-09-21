# Izin Android (Permissions)

Aplikasi TokoKu membutuhkan izin berikut di `android/app/src/main/AndroidManifest.xml`.

## Jika build lokal (flutter create . di komputer Anda)

Setelah menjalankan `flutter create .`, buka file:
`android/app/src/main/AndroidManifest.xml`

Lalu tambahkan baris-baris ini **sebelum** tag `<application>`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

## Fungsi tiap izin

| Izin | Fungsi |
|------|--------|
| `CAMERA` | Scan barcode (mobile_scanner) |
| `BLUETOOTH` + `BLUETOOTH_ADMIN` | Koneksi printer thermal (Android < 12) |
| `BLUETOOTH_SCAN` + `BLUETOOTH_CONNECT` | Koneksi printer thermal (Android 12+) |
| `ACCESS_FINE_LOCATION` | Menemukan perangkat Bluetooth (scan) |

## Jika build online (GitHub Actions / Codemagic)

Izin otomatis ditambahkan oleh workflow — tidak perlu edit manual.
