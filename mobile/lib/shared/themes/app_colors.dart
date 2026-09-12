import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF0A0A0F);
  static const surface = Color(0xFF12121A);
  static const surfaceHover = Color(0xFF1A1A2E);
  static const border = Color(0xFF2A2A3A);
  static const primary = Color(0xFF00FF88);
  static const primaryDim = Color(0xFF00CC6A);
  static const secondary = Color(0xFF00CCFF);
  static const accent = Color(0xFF7C3AED);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFB0B0C0);
  static const textMuted = Color(0xFF606070);
  static const error = Color(0xFFFF4444);
  static const warning = Color(0xFFFFBB33);
  static const success = Color(0xFF00FF88);
  static const info = Color(0xFF00CCFF);
}

class AppTextStyles {
  static const h1 = TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontFamily: 'Inter');
  static const h2 = TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontFamily: 'Inter');
  static const h3 = TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.textPrimary, fontFamily: 'Inter');
  static const body = TextStyle(fontSize: 14, color: AppColors.textSecondary, fontFamily: 'Inter', height: 1.5);
  static const bodySmall = TextStyle(fontSize: 12, color: AppColors.textSecondary, fontFamily: 'Inter');
  static const caption = TextStyle(fontSize: 11, color: AppColors.textMuted, fontFamily: 'Inter');
  static const mono = TextStyle(fontSize: 12, color: AppColors.textPrimary, fontFamily: 'JetBrainsMono');
  static const button = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.background, fontFamily: 'Inter');
}
