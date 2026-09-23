import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';

/// Jarak aman dari tepi atas layar, termasuk tinggi status bar HP.
///
/// Dipakai oleh layar yang memakai header sendiri (bukan `AppBar`). Tanpa ini
/// header akan tertutup jam/baterai/notch HP. Header tetap boleh mewarnai
/// area di belakang status bar — yang digeser hanya isinya.
double topSafePadding(BuildContext context, {double extra = 0}) {
  return MediaQuery.of(context).padding.top + extra;
}

/// Avatar toko: menampilkan logo usaha kalau sudah dipasang, kalau belum
/// memakai inisial nama toko. Dipakai di header beranda dan profil.
class StoreAvatar extends StatelessWidget {
  final String? logoPath;
  final String initials;
  final double radius;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;

  const StoreAvatar({
    super.key,
    required this.logoPath,
    required this.initials,
    this.radius = 22,
    this.backgroundColor = AppColors.primary,
    this.foregroundColor = Colors.white,
    this.borderColor,
  });

  bool get _hasLogo => logoPath != null && logoPath!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: _hasLogo ? Colors.white : backgroundColor,
        shape: BoxShape.circle,
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: 3),
      ),
      clipBehavior: Clip.antiAlias,
      child: _hasLogo
          // File gambar lokal bisa hilang (aplikasi dibersihkan). Kalau gagal
          // dibaca, tampilkan inisial supaya header tidak kosong.
          ? Image.file(
              File(logoPath!),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initials(),
            )
          : _initials(),
    );
  }

  Widget _initials() {
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }
}

/// Dekorasi kartu di beranda — latar putih, sudut membulat, bayangan tipis.
///
/// Dipakai bersama oleh [StatCard] dan [QuickAction]. Sengaja tinggal di satu
/// tempat: kalau radius atau bayangannya diubah di salah satu saja, kedua kartu
/// itu berhenti terlihat sekeluarga dan tidak ada yang menyadarinya.
BoxDecoration dekorasiKartuBeranda() {
  return BoxDecoration(
    color: AppColors.bgCard,
    borderRadius: BorderRadius.circular(16),
    boxShadow: const [
      BoxShadow(
        color: AppColors.shadow,
        blurRadius: 10,
        offset: Offset(0, 2),
      ),
    ],
  );
}

/// Stat card for dashboard — shows a metric with icon and trend.
/// Kalau [onTap] diisi, kartu bisa diketuk dan muncul tanda panah kecil.
class StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String value;
  final String label;
  final String? trend;
  final bool? isUp;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.value,
    required this.label,
    this.trend,
    this.isUp,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // `Spacer` di bawah menuntut tinggi yang terbatas, jadi kartu ini hanya
    // boleh dipakai di dalam grid yang tingginya ditetapkan (`mainAxisExtent`),
    // bukan di dalam kolom yang tingginya mengikuti isi.
    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: dekorasiKartuBeranda(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 17, color: iconColor),
              ),
              const Spacer(),
              if (trend != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isUp == true
                        ? AppColors.successLight
                        : AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    trend!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isUp == true
                          ? AppColors.successMid
                          : AppColors.dangerMid,
                    ),
                  ),
                )
              else if (onTap != null)
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
            ],
          ),
          // Angka dan label selalu menempel ke dasar kartu, jadi kartu berlabel
          // satu baris dan dua baris tetap punya garis dasar yang sama.
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 21,
              height: 1.15,
              fontWeight: FontWeight.w800,
              color: AppColors.textMain,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.25,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: card,
      ),
    );
  }
}

/// Quick action button for dashboard.
class QuickAction extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String label;
  final VoidCallback onTap;

  const QuickAction({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: dekorasiKartuBeranda(),
      // Warnanya ada di Container, jadi riaknya perlu lapisan Material
      // transparan sendiri. Kalau tidak, riak tergambar DI BAWAH latar putih
      // dan tombolnya terlihat mati walau tetap bisa diketuk.
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            child: Column(
              // Isi selalu di tengah, jadi label satu baris ("Hutang") dan dua
              // baris ("Tambah Stok") tetap sejajar satu sama lain.
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 22, color: iconColor),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMain,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Stock status badge.
class StockBadge extends StatelessWidget {
  final int stock;
  final int minStock;

  const StockBadge({super.key, required this.stock, this.minStock = 5});

  @override
  Widget build(BuildContext context) {
    String label;
    Color bg;
    Color fg;

    if (stock == 0) {
      label = 'Habis';
      bg = AppColors.dangerLight;
      fg = AppColors.dangerMid;
    } else if (stock <= minStock) {
      label = 'Stok $stock';
      bg = AppColors.warningLight;
      fg = AppColors.warningMid;
    } else {
      label = 'Stok $stock';
      bg = AppColors.successLight;
      fg = AppColors.successMid;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

/// Section title with optional "see more" link.
class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          // Batang aksen di kiri judul — penanda bagian yang jauh lebih ringan
          // daripada garis pemisah selebar halaman.
          Container(
            width: 3.5,
            height: subtitle == null ? 18 : 32,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMain,
                    letterSpacing: -0.2,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.3,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Empty state widget.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppColors.textTertiary),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Satu baris "label — nilai" untuk dialog rincian.
///
/// Sengaja dipakai bersama oleh dialog rincian hutang/piutang di dua layar —
/// riwayat Kas dan halaman Hutang & Piutang. Kalau tiap layar punya salinannya
/// sendiri, lebar labelnya bisa menyimpang tanpa ada yang sadar.
Widget barisRincian(String label, String value, {bool tebal = false}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 126,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: tebal ? FontWeight.w700 : FontWeight.w500,
              color: AppColors.textMain,
            ),
          ),
        ),
      ],
    ),
  );
}
