package com.tokoku.sembako

import android.content.Context
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Pembaca daftar alat USB yang sedang tercolok.
 *
 * Kanal ini **tidak** dipakai untuk menerima hasil scan. Scanner kabel USB dan
 * dongle nirkabel 2,4 GHz mengirim sebagai keyboard (HID), jadi Android sendiri
 * yang meneruskan ketikannya ke aplikasi — tanpa izin, tanpa driver, tanpa
 * langkah pemasangan. Kalau kanal ini dihapus, scanner tetap berfungsi.
 *
 * Yang dibaca di sini hanya daftar alatnya, untuk membedakan tiga keadaan yang
 * gejalanya sama-sama "tidak bisa scan":
 *
 *   1. tidak ada alat tercolok sama sekali;
 *   2. alat tercolok dalam mode COM/serial (USB virtual COM port) — lampunya
 *      menyala, Android menyebutnya terpasang, tetapi tidak ada satu karakter
 *      pun yang sampai ke aplikasi;
 *   3. alat tercolok dalam mode HID — inilah yang benar.
 *
 * Keadaan kedua adalah sumber kebingungan paling sering, dan tidak bisa
 * dibedakan dari sisi Dart: bagi Flutter, keduanya sama-sama "tidak ada
 * ketikan". Karena itu daftar alatnya perlu dibaca native.
 *
 * Cara memperbaikinya juga tidak ada di aplikasi: pengguna harus memindai
 * barcode "USB HID Keyboard" di buku manual alatnya. Itulah sebabnya keadaan
 * ini dilaporkan sebagai peringatan, bukan sebagai galat.
 */
object ScannerUsb {

    const val KANAL = "tokoku/pemindai_usb"

    fun daftarkan(context: Context, messenger: BinaryMessenger) {
        MethodChannel(messenger, KANAL).setMethodCallHandler { panggilan, hasil ->
            if (panggilan.method == "daftar") {
                // Aplikasi konteks, bukan activity: daftar alat tidak berubah
                // saat layar diputar ulang, dan memegang activity di sini akan
                // menahan layar tetap hidup di memori.
                hasil.success(daftar(context.applicationContext))
            } else {
                hasil.notImplemented()
            }
        }
    }

    private fun daftar(context: Context): List<Map<String, Any?>> {
        val manajer = context.getSystemService(Context.USB_SERVICE) as? UsbManager
            ?: return emptyList()

        val keluaran = ArrayList<Map<String, Any?>>()
        for ((nama, alat) in manajer.deviceList) {
            val kelas = kelas(alat)
            keluaran.add(
                mapOf(
                    "nama" to nama,
                    "judul" to judul(alat),
                    "vendor" to alat.vendorId,
                    "produk" to alat.productId,
                    "kelas" to kelas,
                    "hid" to (kelas == "HID"),
                    "izin" to manajer.hasPermission(alat)
                )
            )
        }
        return keluaran
    }

    /**
     * Tebak peran alat dari kelas antarmukanya.
     *
     * Kelas perangkat saja tidak cukup: banyak scanner mendaftarkan diri
     * sebagai vendor-specific (0xFF) di tingkat perangkat, lalu menaruh
     * antarmuka HID di dalamnya. Karena itu antarmuka ikut diperiksa.
     */
    private fun kelas(alat: UsbDevice): String {
        var hid = alat.deviceClass == UsbConstants.USB_CLASS_HID
        var com = alat.deviceClass == UsbConstants.USB_CLASS_COMM ||
            alat.deviceClass == UsbConstants.USB_CLASS_CDC_DATA

        val jumlah = alat.interfaceCount
        for (i in 0 until jumlah) {
            // getInterface bisa melempar pada alat yang sedang dilepas.
            val antarmuka = try {
                alat.getInterface(i)
            } catch (e: Exception) {
                null
            }
            if (antarmuka == null) continue

            val kelasAntarmuka = antarmuka.interfaceClass
            if (kelasAntarmuka == UsbConstants.USB_CLASS_HID) hid = true
            if (kelasAntarmuka == UsbConstants.USB_CLASS_COMM ||
                kelasAntarmuka == UsbConstants.USB_CLASS_CDC_DATA
            ) {
                com = true
            }
        }

        return when {
            hid -> "HID"
            com -> "COM"
            alat.deviceClass == UsbConstants.USB_CLASS_MASS_STORAGE -> "PENYIMPANAN"
            else -> "LAIN"
        }
    }

    /**
     * Nama alat yang bisa dibaca manusia.
     *
     * productName melempar SecurityException kalau izin USB belum diberikan
     * untuk alat itu — dan izin baru diminta setelah aplikasi membuka alatnya,
     * yang tidak pernah dilakukan di sini. Jadi jalur cadangan ini yang
     * sebenarnya sering dipakai, bukan pengecualian yang jarang.
     */
    private fun judul(alat: UsbDevice): String {
        val cadangan = "USB " + Integer.toHexString(alat.vendorId) + ":" +
            Integer.toHexString(alat.productId)
        return try {
            val nama = alat.productName
            if (nama.isNullOrBlank()) cadangan else nama
        } catch (e: Exception) {
            cadangan
        }
    }
}
