package com.tokoku.sembako

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.OutputStream
import java.util.UUID
import java.util.concurrent.Executors

/**
 * Jembatan Bluetooth Classic (SPP / RFCOMM) untuk printer termal.
 *
 * KENAPA BERKAS INI ADA
 * ---------------------
 * `flutter_blue_plus` yang dipakai aplikasi ini hanya bisa BLE (Bluetooth Low
 * Energy / GATT). Printer thermal murah — RPP02N, Xprinter, Goojprt, MPT-II,
 * dan hampir semua printer 58 mm lain — memakai **Bluetooth Classic SPP**.
 * Perangkat Classic TIDAK PERNAH muncul di pemindaian BLE, jadi printer yang
 * menyala dan sudah dipasangkan pun tidak akan kelihatan. Itulah sebabnya
 * layar "Pilih Printer" lama selalu kosong tanpa pesan galat.
 *
 * Android tidak menyediakan API Classic lewat Dart, jadi jalurnya dibuat di
 * sini: satu MethodChannel untuk perintah dan satu EventChannel untuk hasil
 * pemindaian.
 *
 * KENAPA TIDAK MEMAKAI PAKET PUB
 * ------------------------------
 * Paket Classic yang ada (`flutter_bluetooth_serial`, `blue_thermal_printer`,
 * `esc_pos_bluetooth`) sudah bertahun-tahun tidak dirawat dan tidak punya
 * `namespace` Gradle, sehingga gagal dikompilasi dengan AGP 8. Berkas ini
 * hanya memakai API Android bawaan, jadi tidak menambah satu pun dependensi.
 *
 * CATATAN PENTING
 * ---------------
 * Repo ini TIDAK menyimpan folder `android/`. `tools/ci_patch.py` menyalin
 * berkas ini ke `android/app/src/main/kotlin/com/tokoku/sembako/` dan
 * mendaftarkannya di `MainActivity.kt` pada setiap build. Kalau berkas ini
 * diubah, tidak ada yang perlu di-deploy — cukup build ulang APK.
 */
object PrinterSpp {

    private const val KANAL = "tokoku/printer_spp"
    private const val KANAL_ALIRAN = "tokoku/printer_spp/perangkat"
    private const val KODE_IZIN = 4711

    /** UUID resmi Serial Port Profile — dipakai hampir semua printer thermal. */
    private val UUID_SPP: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

    /**
     * UUID cadangan untuk printer yang tidak mengumumkan SPP dengan benar.
     * Beberapa model murah hanya menerima kanal buatan pabriknya sendiri.
     */
    private val UUID_CADANGAN: List<UUID> = listOf(
        UUID.fromString("0000FF00-0000-1000-8000-00805F9B34FB"),
        UUID.fromString("0000FFE0-0000-1000-8000-00805F9B34FB"),
        UUID.fromString("0000FF80-0000-1000-8000-00805F9B34FB"),
        UUID.fromString("49535343-FE7D-4AE5-8FA9-9FAFD205E455")
    )

    private val utama = Handler(Looper.getMainLooper())

    /**
     * Semua pekerjaan yang memblokir (connect, write) dijalankan berurutan di
     * satu thread. Kalau dijalankan di thread utama, `socket.connect()` yang
     * menunggu 5-10 detik akan membekukan layar dan Android menampilkan
     * "aplikasi tidak merespons".
     */
    private val kerja = Executors.newSingleThreadExecutor()

    private var aktivitas: Activity? = null
    private var aliran: EventChannel.EventSink? = null
    private var soket: BluetoothSocket? = null
    private var keluaran: OutputStream? = null
    private var izinTertunda: MethodChannel.Result? = null
    private var penerima: BroadcastReceiver? = null

    /** Dipanggil dari `MainActivity.configureFlutterEngine`. */
    fun daftarkan(aktivitasBaru: Activity, messenger: BinaryMessenger) {
        aktivitas = aktivitasBaru

        MethodChannel(messenger, KANAL).setMethodCallHandler { panggilan, hasil ->
            try {
                tangani(panggilan.method, panggilan.arguments, hasil)
            } catch (e: Exception) {
                hasil.error("GAGAL", e.message ?: "Kesalahan tidak dikenal", null)
            }
        }

        EventChannel(messenger, KANAL_ALIRAN).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(argumen: Any?, events: EventChannel.EventSink?) {
                    aliran = events
                }

                override fun onCancel(argumen: Any?) {
                    aliran = null
                }
            }
        )
    }

    private fun tangani(method: String, argumen: Any?, hasil: MethodChannel.Result) {
        when (method) {
            "status" -> hasil.success(status())
            "mintaIzin" -> mintaIzin(hasil)
            "terpasang" -> hasil.success(daftarTerpasang())
            "mulaiPindai" -> hasil.success(mulaiPindai())
            "hentikanPindai" -> {
                hentikanPindai()
                hasil.success(true)
            }
            "pasangkan" -> pasangkan(argumen as? String, hasil)
            "sambung" -> sambung(argumen as? String, hasil)
            "tulis" -> tulis(argumen as? ByteArray, hasil)
            "putus" -> kerja.execute {
                putus()
                diUtama { hasil.success(true) }
            }
            else -> hasil.notImplemented()
        }
    }

    // ---------------------------------------------------------------------
    // Status & izin
    // ---------------------------------------------------------------------

    private fun status(): Map<String, Any?> {
        val konteks = aktivitas
        val ad = adaptor()
        val hidup = try {
            ad != null && ad.isEnabled
        } catch (e: SecurityException) {
            // Izin CONNECT belum diberikan: kita tidak boleh tahu statusnya.
            false
        }
        return mapOf(
            "didukung" to (ad != null),
            "aktif" to hidup,
            "izin" to (konteks != null && punyaIzin(konteks))
        )
    }

    private fun adaptor(): BluetoothAdapter? {
        val konteks = aktivitas ?: return null
        return try {
            (konteks.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Android 12 (S) memecah izin Bluetooth menjadi izin runtime SCAN dan
     * CONNECT. Sebelum itu, izinnya diberikan saat pemasangan dan pemindaian
     * menuntut izin lokasi.
     */
    private fun punyaIzin(konteks: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            konteks.checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN) ==
                PackageManager.PERMISSION_GRANTED &&
                konteks.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) ==
                PackageManager.PERMISSION_GRANTED
        } else {
            konteks.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
                PackageManager.PERMISSION_GRANTED
        }
    }

    private fun mintaIzin(hasil: MethodChannel.Result) {
        val konteks = aktivitas
        if (konteks == null) {
            hasil.success(false)
            return
        }
        if (punyaIzin(konteks)) {
            hasil.success(true)
            return
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            // Sebelum Android 6 semua izin diberikan saat pemasangan.
            hasil.success(true)
            return
        }
        if (izinTertunda != null) {
            // Sudah ada dialog yang terbuka; jangan menumpuk permintaan.
            hasil.success(false)
            return
        }
        izinTertunda = hasil
        val daftar = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT
            )
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        konteks.requestPermissions(daftar, KODE_IZIN)
    }

    /** Dipanggil dari `MainActivity.onRequestPermissionsResult`. */
    fun terimaIzin(kode: Int, hasilIzin: IntArray) {
        if (kode != KODE_IZIN) return
        val menunggu = izinTertunda ?: return
        izinTertunda = null
        val diberi = hasilIzin.isNotEmpty() &&
            hasilIzin.all { it == PackageManager.PERMISSION_GRANTED }
        menunggu.success(diberi)
    }

    // ---------------------------------------------------------------------
    // Daftar perangkat
    // ---------------------------------------------------------------------

    @SuppressLint("MissingPermission")
    private fun daftarTerpasang(): List<Map<String, Any?>> {
        val ad = adaptor() ?: return emptyList()
        return try {
            ad.bondedDevices.map { alat ->
                mapOf(
                    "id" to alat.address,
                    "nama" to (alat.name ?: ""),
                    "terpasang" to true
                )
            }
        } catch (e: SecurityException) {
            // Izin CONNECT belum diberikan.
            emptyList()
        }
    }

    @SuppressLint("MissingPermission")
    private fun mulaiPindai(): Boolean {
        val konteks = aktivitas?.applicationContext ?: return false
        val ad = adaptor() ?: return false
        if (!punyaIzin(konteks)) return false

        val hidup = try {
            ad.isEnabled
        } catch (e: SecurityException) {
            false
        }
        if (!hidup) return false

        hentikanPindai()

        val saring = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_FOUND)
            addAction(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
            addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
        }

        val penerimaBaru = object : BroadcastReceiver() {
            override fun onReceive(konteksSiaran: Context?, niat: Intent?) {
                val isi = niat ?: return
                when (isi.action) {
                    BluetoothDevice.ACTION_FOUND,
                    BluetoothDevice.ACTION_BOND_STATE_CHANGED -> {
                        @Suppress("DEPRECATION")
                        val alat = isi.getParcelableExtra<BluetoothDevice>(
                            BluetoothDevice.EXTRA_DEVICE
                        )
                        if (alat != null) laporkan(alat)
                    }
                    BluetoothAdapter.ACTION_DISCOVERY_FINISHED ->
                        kirimKeDart(mapOf("selesai" to true))
                }
            }
        }

        penerima = penerimaBaru
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                // Android 13 mewajibkan penanda ekspor untuk penerima siaran.
                konteks.registerReceiver(penerimaBaru, saring, Context.RECEIVER_NOT_EXPORTED)
            } else {
                konteks.registerReceiver(penerimaBaru, saring)
            }
        } catch (e: Exception) {
            penerima = null
            return false
        }

        return try {
            ad.startDiscovery()
        } catch (e: SecurityException) {
            false
        }
    }

    @SuppressLint("MissingPermission")
    private fun hentikanPindai() {
        val penerimaLama = penerima
        penerima = null
        if (penerimaLama != null) {
            val konteks = aktivitas?.applicationContext
            if (konteks != null) {
                try {
                    konteks.unregisterReceiver(penerimaLama)
                } catch (e: IllegalArgumentException) {
                    // Memang belum terdaftar.
                }
            }
        }
        try {
            adaptor()?.cancelDiscovery()
        } catch (e: SecurityException) {
            // Izin belum ada; tidak ada pemindaian yang perlu dihentikan.
        }
    }

    @SuppressLint("MissingPermission")
    private fun laporkan(alat: BluetoothDevice) {
        val nama = try {
            alat.name ?: ""
        } catch (e: SecurityException) {
            ""
        }
        val terpasang = try {
            alat.bondState == BluetoothDevice.BOND_BONDED
        } catch (e: SecurityException) {
            false
        }
        kirimKeDart(
            mapOf(
                "id" to alat.address,
                "nama" to nama,
                "terpasang" to terpasang
            )
        )
    }

    private fun kirimKeDart(data: Map<String, Any?>) {
        diUtama { aliran?.success(data) }
    }

    // ---------------------------------------------------------------------
    // Pemasangan pasangan (pairing)
    // ---------------------------------------------------------------------

    @SuppressLint("MissingPermission")
    private fun pasangkan(mac: String?, hasil: MethodChannel.Result) {
        val konteks = aktivitas
        val ad = adaptor()
        if (mac == null || konteks == null || ad == null) {
            hasil.success(false)
            return
        }
        if (!punyaIzin(konteks)) {
            hasil.error("IZIN", "Izin Bluetooth belum diberikan", null)
            return
        }
        val alat = try {
            ad.getRemoteDevice(mac)
        } catch (e: IllegalArgumentException) {
            null
        }
        if (alat == null) {
            hasil.error("ALAT", "Alamat printer tidak sah", null)
            return
        }
        val dimulai = try {
            alat.createBond()
        } catch (e: SecurityException) {
            false
        }
        hasil.success(dimulai)
    }

    // ---------------------------------------------------------------------
    // Sambungan & penulisan
    // ---------------------------------------------------------------------

    @SuppressLint("MissingPermission")
    private fun sambung(mac: String?, hasil: MethodChannel.Result) {
        val konteks = aktivitas
        val ad = adaptor()
        if (mac == null || konteks == null || ad == null) {
            hasil.error("ARG", "Alamat printer tidak sah", null)
            return
        }
        if (!punyaIzin(konteks)) {
            hasil.error("IZIN", "Izin Bluetooth belum diberikan", null)
            return
        }
        val alat = try {
            ad.getRemoteDevice(mac)
        } catch (e: IllegalArgumentException) {
            null
        }
        if (alat == null) {
            hasil.error("ALAT", "Alamat printer tidak sah", null)
            return
        }

        kerja.execute {
            putus()
            try {
                // Pemindaian yang masih berjalan membuat sambungan gagal.
                ad.cancelDiscovery()
            } catch (e: SecurityException) {
                // Abaikan: bukan alasan untuk membatalkan sambungan.
            }
            val galat = cobaSambung(alat)
            diUtama {
                if (galat == null) {
                    hasil.success(true)
                } else {
                    hasil.error(
                        "SAMBUNG",
                        "Gagal tersambung ke printer: " +
                            (galat.message ?: "tidak diketahui"),
                        null
                    )
                }
            }
        }
    }

    /**
     * Mencoba beberapa cara menyambung, dari yang paling standar.
     *
     * Banyak printer murah tidak mengumumkan SPP dengan benar, jadi urutannya:
     *   1. SPP resmi + UUID cadangan pabrikan (kanal aman),
     *   2. SPP tidak aman — dipakai printer yang menolak kanal butuh link key,
     *   3. RFCOMM kanal 1 tanpa SDP — jalur terakhir untuk printer yang tidak
     *      mengumumkan layanannya sama sekali.
     *
     * Mengembalikan null kalau salah satu berhasil.
     */
    @SuppressLint("MissingPermission")
    private fun cobaSambung(alat: BluetoothDevice): Exception? {
        var galat: Exception? = null

        val daftarUuid = ArrayList<UUID>(UUID_CADANGAN.size + 1)
        daftarUuid.add(UUID_SPP)
        daftarUuid.addAll(UUID_CADANGAN)
        for (uuid in daftarUuid) {
            val hasil = cobaKanal { alat.createRfcommSocketToServiceRecord(uuid) }
            if (hasil == null) return null
            galat = hasil
        }

        val tidakAman = cobaKanal {
            alat.createInsecureRfcommSocketToServiceRecord(UUID_SPP)
        }
        if (tidakAman == null) return null
        galat = tidakAman

        val kanalSatu = cobaKanal {
            val metode = alat.javaClass.getMethod(
                "createRfcommSocket",
                Int::class.javaPrimitiveType!!
            )
            metode.invoke(alat, 1) as BluetoothSocket
        }
        if (kanalSatu == null) return null

        return galat ?: kanalSatu
    }

    /** Buat satu soket lewat [buat], sambungkan, dan simpan kalau berhasil. */
    @SuppressLint("MissingPermission")
    private fun cobaKanal(buat: () -> BluetoothSocket): Exception? {
        var calon: BluetoothSocket? = null
        return try {
            val baru = buat()
            calon = baru
            baru.connect()
            soket = baru
            keluaran = baru.outputStream
            null
        } catch (e: Exception) {
            try {
                calon?.close()
            } catch (e2: Exception) {
                // Soket sudah tidak terpakai.
            }
            e
        }
    }

    private fun tulis(data: ByteArray?, hasil: MethodChannel.Result) {
        val aliranKeluar = keluaran
        if (data == null || data.isEmpty()) {
            hasil.error("ARG", "Data struk kosong", null)
            return
        }
        if (aliranKeluar == null) {
            hasil.error("SOKET", "Printer belum tersambung", null)
            return
        }

        kerja.execute {
            try {
                var posisi = 0
                // 512 byte per potongan: cukup besar supaya cepat, cukup kecil
                // supaya buffer printer murah tidak meluap dan terpotong.
                while (posisi < data.size) {
                    val jumlah = minOf(512, data.size - posisi)
                    aliranKeluar.write(data, posisi, jumlah)
                    aliranKeluar.flush()
                    posisi += jumlah
                    try {
                        Thread.sleep(15)
                    } catch (e: InterruptedException) {
                        Thread.currentThread().interrupt()
                    }
                }
                diUtama { hasil.success(true) }
            } catch (e: Exception) {
                diUtama {
                    hasil.error("TULIS", e.message ?: "Gagal mengirim data ke printer", null)
                }
            }
        }
    }

    private fun putus() {
        try {
            keluaran?.flush()
        } catch (e: Exception) {
            // Tidak apa-apa: soket mungkin sudah ditutup printer.
        }
        try {
            keluaran?.close()
        } catch (e: Exception) {
            // Idem.
        }
        try {
            soket?.close()
        } catch (e: Exception) {
            // Idem.
        }
        keluaran = null
        soket = null
    }

    private fun diUtama(blok: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            blok()
        } else {
            utama.post(blok)
        }
    }
}
