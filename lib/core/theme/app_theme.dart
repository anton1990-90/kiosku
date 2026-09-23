import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppTheme {
  AppTheme._();
  static ThemeData get light {
    // `ColorScheme.fromSeed` menurunkan teal-nya sendiri dari warna benih, dan
    // hasilnya BUKAN [AppColors.primary]. Tanpa timpaan di bawah, riak, cincin
    // fokus, dan sakelar bawaan Material memakai teal yang berbeda dari sisa
    // aplikasi — bedanya tipis, tapi terlihat begitu bersebelahan.
    final skema = ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.bgCard,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bgPage,
      colorScheme: skema,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textMain),
        bodyLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMain),
      ),
      // Tanpa `scrolledUnderElevation: 0`, AppBar Material 3 menumpuk lapisan
      // warna begitu isi halaman tergeser ke bawahnya. Di halaman yang latarnya
      // putih rata, lapisan itu terbaca sebagai kotor.
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgCard,
        foregroundColor: AppColors.textMain,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.textMain,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardTheme(
        color: AppColors.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
