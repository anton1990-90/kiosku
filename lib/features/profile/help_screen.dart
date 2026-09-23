import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';

/// Pusat bantuan — panduan pemakaian dan pertanyaan yang sering ditanya.
///
/// Seluruh isinya ditulis di dalam aplikasi, jadi tetap terbaca tanpa
/// internet. Yang butuh koneksi hanya "Chat penjual" dan "Bagikan aplikasi".
///
/// Halaman ini sengaja tidak mengambil data dari database: kalau pemilik toko
/// membukanya justru karena ada yang bermasalah, halaman bantuan harus tetap
/// tampil utuh walau data usaha sedang bermasalah.
class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key});

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

/// Satu langkah panduan: judul, ikon, warna, dan daftar langkahnya.
typedef _Panduan = ({
  String judul,
  String ringkas,
  IconData ikon,
  Color warna,
  List<String> langkah,
});

/// Satu tanya-jawab.
typedef _TanyaJawab = ({String tanya, String jawab});

class _HelpScreenState extends ConsumerState<HelpScreen> {
  static const List<_Panduan> _panduan = [
    (
      judul: 'Mencatat penjualan',
      ringkas: 'Layar Kasir',
      ikon: Icons.point_of_sale_outlined,
      warna: AppColors.primary,
      langkah: [
        'Buka tab Kasir di bagian bawah layar.',
        'Ketuk produk yang dibeli. Bisa juga memindai barcode lewat ikon kamera.',
        'Ubah jumlahnya kalau pembeli mengambil lebih dari satu.',
        'Pilih metode pembayaran, lalu tekan tombol Bayar.',
        'Kalau pembeli belum membayar, nyalakan dulu tombol Hutang sebelum '
            'menekan Bayar supaya tercatat sebagai piutang.',
      ],
    ),
    (
      judul: 'Menambah dan mengubah produk',
      ringkas: 'Layar Produk',
      ikon: Icons.inventory_2_outlined,
      warna: AppColors.info,
      langkah: [
        'Buka tab Produk, lalu tekan tombol Tambah.',
        'Isi nama barang, harga beli, harga jual, dan stok awal.',
        'Isi juga stok minimum. Kalau stok turun sampai angka itu, aplikasi '
            'memberi peringatan supaya barang tidak kehabisan.',
        'Untuk mengubah barang yang sudah ada, ketuk produknya lalu pilih Ubah.',
        'Harga beli dipakai untuk menghitung laba di laporan, jadi isi dengan '
            'benar.',
      ],
    ),
    (
      judul: 'Mencatat hutang dan piutang',
      ringkas: 'Layar Hutang',
      ikon: Icons.receipt_long_outlined,
      warna: AppColors.warningMid,
      langkah: [
        'Hutang pelanggan otomatis tercatat saat Anda menekan Bayar dengan '
            'tombol Hutang menyala di layar Kasir.',
        'Untuk mencatat dari awal, buka tab Hutang lalu tekan Tambah.',
        'Pilih jenisnya: Piutang kalau pelanggan berhutang kepada Anda, '
            'Hutang kalau Anda yang berhutang ke supplier.',
        'Saat pelanggan membayar sebagian, buka catatannya lalu tekan Bayar '
            'sebagian. Sisanya tetap tercatat.',
      ],
    ),
    (
      judul: 'Mencetak struk',
      ringkas: 'Printer Bluetooth',
      ikon: Icons.print_outlined,
      warna: AppColors.successMid,
      langkah: [
        'Nyalakan printer struk, lalu sambungkan lewat pengaturan Bluetooth HP.',
        'Setelah pembayaran selesai, akan muncul tombol Cetak struk.',
        'Kalau struk tidak keluar, pastikan printer masih tersambung dan '
            'kertasnya masih ada.',
        'Logo toko dan gambar QRIS ikut tercetak kalau sudah diisi di Info toko.',
      ],
    ),
    (
      judul: 'Mencadangkan data',
      ringkas: 'Simpan ke luar HP',
      ikon: Icons.save_alt,
      warna: AppColors.primary,
      langkah: [
        'Buka Profil, lalu pilih Cadangkan data.',
        'Simpan berkasnya ke email, WhatsApp, atau Google Drive.',
        'Aplikasi juga membuat cadangan otomatis setiap kali dibuka, paling '
            'banyak sekali dalam 24 jam.',
        'Cadangan yang hanya tersimpan di dalam HP tidak menolong kalau HP-nya '
            'hilang, jadi kirim juga ke luar.',
      ],
    ),
    (
      judul: 'Pindah ke HP baru',
      ringkas: 'Pulihkan data',
      ikon: Icons.phone_iphone,
      warna: AppColors.infoMid,
      langkah: [
        'Pastikan Anda sudah punya berkas cadangan dari HP lama.',
        'Di HP baru, pasang aplikasi lalu masukkan kode aktivasi Anda.',
        'Buka Profil, pilih Pulihkan data, lalu pilih berkas cadangannya.',
        'Data di HP baru akan diganti isi cadangan. Akun (email dan password) '
            'tidak ikut berubah.',
        'Hubungi penjual untuk memindahkan lisensi ke HP baru.',
      ],
    ),
    (
      judul: 'Mengunci aplikasi dengan PIN',
      ringkas: 'Kunci layar',
      ikon: Icons.lock_outline,
      warna: AppColors.dangerMid,
      langkah: [
        'Buka Profil, pilih Kunci PIN, lalu tentukan 4 sampai 6 angka.',
        'Setiap aplikasi dibuka, PIN akan diminta lebih dulu.',
        'Kalau lupa PIN, tekan Lupa PIN? di layar kunci lalu masuk memakai '
            'email dan password akun Anda.',
        'PIN bisa dimatikan lagi kapan saja dari menu yang sama.',
      ],
    ),
    (
      judul: 'Mengubah nama toko, logo, dan QRIS',
      ringkas: 'Info toko',
      ikon: Icons.storefront_outlined,
      warna: AppColors.info,
      langkah: [
        'Buka Profil, lalu pilih Info toko.',
        'Nama toko dan alamatnya ikut tercetak di struk.',
        'Unggah logo dan gambar QRIS supaya pelanggan bisa langsung memindai '
            'dari struk.',
        'Isi juga data rekening kalau Anda menerima transfer bank.',
      ],
    ),
  ];

  static const List<_TanyaJawab> _faq = [
    (
      tanya: 'Aplikasi meminta kode aktivasi. Apa itu?',
      jawab: 'Aplikasi ini berlisensi untuk satu HP. Kode aktivasi diberikan '
          'penjual setelah pembelian. Masukkan kodenya di layar aktivasi. '
          'Kalau Anda ganti HP, hubungi penjual untuk memindahkan lisensinya.',
    ),
    (
      tanya: 'Apakah aplikasi bisa dipakai tanpa internet?',
      jawab: 'Bisa. Semua data penjualan, produk, hutang, dan laporan '
          'tersimpan di dalam HP dan tetap berjalan tanpa koneksi. Internet '
          'hanya dipakai untuk aktivasi dan memeriksa versi terbaru.',
    ),
    (
      tanya: 'Lupa password akun, bagaimana?',
      jawab: 'Hubungi penjual. Password disimpan dalam bentuk acak (hash), '
          'jadi tidak ada yang bisa membacanya kembali, termasuk aplikasi ini.',
    ),
    (
      tanya: 'Lupa PIN, bagaimana?',
      jawab: 'Di layar PIN, tekan Lupa PIN?. Anda akan diminta email dan '
          'password. Setelah berhasil masuk, atur ulang PIN lewat Profil.',
    ),
    (
      tanya: 'Apakah data hilang kalau aplikasi dihapus?',
      jawab: 'Ya. Data tersimpan di dalam aplikasi. Sebelum menghapus '
          'aplikasi atau berganti HP, cadangkan dulu lewat Profil lalu simpan '
          'berkasnya ke luar HP.',
    ),
    (
      tanya: 'Kenapa stok barang berkurang sendiri?',
      jawab: 'Setiap penjualan mengurangi stok secara otomatis, termasuk '
          'penjualan yang dibayar dengan hutang. Untuk menambah stok saat '
          'barang datang, pakai menu Stok.',
    ),
    (
      tanya: 'Salah memasukkan transaksi, bisa dihapus?',
      jawab: 'Bisa. Buka tab Transaksi, pilih transaksi yang salah, lalu hapus. '
          'Stok, kas, dan laporannya akan menyesuaikan sendiri.',
    ),
    (
      tanya: 'Kenapa laporan tidak sama dengan uang di laci?',
      jawab: 'Pastikan semua uang masuk dan keluar dicatat di tab Kas, '
          'termasuk uang yang Anda ambil untuk keperluan pribadi (prive). '
          'Laporan keuangan dihitung dari catatan itu.',
    ),
  ];

  Future<void> _bukaLink(String alamat) async {
    final uri = Uri.tryParse(alamat);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak bisa membuka tautan. Periksa koneksi Anda.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _chatPenjual() async {
    if (AppConfig.sellerWhatsApp.isEmpty) return;
    final text = Uri.encodeComponent(
      'Halo, saya butuh bantuan memakai aplikasi TokoKu.',
    );
    await _bukaLink('https://wa.me/${AppConfig.sellerWhatsApp}?text=$text');
  }

  Future<void> _bagikanAplikasi() async {
    if (!AppConfig.isActivationConfigured) return;
    final teks = 'Aplikasi kasir TokoKu untuk warung dan toko sembako.\n'
        'Unduh di sini: ${AppConfig.downloadPageUrl}';
    try {
      await Share.share(teks, subject: 'Aplikasi TokoKu');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak bisa membuka menu bagikan.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(title: const Text('Pusat Bantuan')),
      body: Responsive.centered(
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _sapaan(),
            const SizedBox(height: 20),
            _judulBagian('Panduan cepat'),
            ..._panduan.map(_kartuPanduan),
            const SizedBox(height: 24),
            _judulBagian('Pertanyaan yang sering ditanya'),
            ..._faq.map(_kartuTanyaJawab),
            const SizedBox(height: 24),
            _judulBagian('Masih butuh bantuan?'),
            _kartuKontak(),
            if (AppConfig.isActivationConfigured) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _bagikanAplikasi,
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Bagikan aplikasi ini'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sapaan() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.help_outline, size: 20, color: AppColors.infoMid),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Semua panduan di halaman ini bisa dibaca tanpa internet. '
              'Ketuk judulnya untuk membuka langkah-langkahnya.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: AppColors.infoMid,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _judulBagian(String teks) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 10),
      child: Text(
        teks,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _kartuPanduan(_Panduan item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Theme(
        // Garis pemisah bawaan ExpansionTile terlihat berantakan di dalam
        // kartu bersudut bulat, jadi dimatikan.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: item.warna.withOpacity(0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(item.ikon, size: 18, color: item.warna),
          ),
          title: Text(
            item.judul,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textMain,
            ),
          ),
          subtitle: Text(
            item.ringkas,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          children: [
            for (var i = 0; i < item.langkah.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(top: 1, right: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.bgSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.langkah[i],
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.5,
                          color: AppColors.textMain,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _kartuTanyaJawab(_TanyaJawab item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: Text(
            item.tanya,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textMain,
            ),
          ),
          children: [
            Text(
              item.jawab,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kartuKontak() {
    final adaWhatsApp = AppConfig.sellerWhatsApp.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kalau panduan di atas belum menjawab, hubungi penjual tempat '
            'Anda membeli aplikasi ini. Sebutkan Kode Perangkat Anda supaya '
            'penjual bisa memeriksa lebih cepat — kodenya ada di '
            'Profil → Info Lisensi.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          if (adaWhatsApp) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _chatPenjual,
                icon: const Icon(Icons.chat_outlined, size: 18),
                label: const Text('Chat penjual'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
