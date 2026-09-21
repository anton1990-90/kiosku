import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppTheme {
  AppTheme._();
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bgPage,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textMain),
        bodyLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMain),
      ),
      cardTheme: CardTheme(
        color: AppColors.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
