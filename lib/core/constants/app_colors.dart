import 'package:flutter/material.dart';

/// App color palette matching the TokoKu UI design.
/// Teal primary, amber accent, semantic colors for stock status.
class AppColors {
  AppColors._();

  // Primary - Teal
  static const Color primary = Color(0xFF0F6E56);
  static const Color primaryLight = Color(0xFFE1F5EE);
  static const Color primaryMid = Color(0xFF1D9E75);
  static const Color primaryDark = Color(0xFF085041);

  // Accent - Amber
  static const Color accent = Color(0xFFEF9F27);
  static const Color accentLight = Color(0xFFFAEEDA);
  static const Color accentMid = Color(0xFFBA7517);

  // Backgrounds
  static const Color bgPage = Color(0xFFF4F5F7);
  static const Color bgCard = Color(0xFFFFFFFF);
  static const Color bgSoft = Color(0xFFF8F9FA);

  // Text
  static const Color textMain = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);

  // Borders
  static const Color border = Color(0xFFE8E9EB);

  // Semantic - Success (Green)
  static const Color success = Color(0xFF1D9E75);
  static const Color successLight = Color(0xFFE1F5EE);
  static const Color successMid = Color(0xFF0F6E56);

  // Semantic - Warning (Amber)
  static const Color warning = Color(0xFFEF9F27);
  static const Color warningLight = Color(0xFFFAEEDA);
  static const Color warningMid = Color(0xFF854F0B);

  // Semantic - Danger (Red)
  static const Color danger = Color(0xFFE24B4A);
  static const Color dangerLight = Color(0xFFFCEBEB);
  static const Color dangerMid = Color(0xFFA32D2D);

  // Semantic - Info (Blue)
  static const Color info = Color(0xFF378ADD);
  static const Color infoLight = Color(0xFFE6F1FB);
  static const Color infoMid = Color(0xFF185FA5);
}
