import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF1E1E1E);
  static const surface = Color(0xFF252526);
  static const surfaceHover = Color(0xFF2D2D30);
  static const border = Color(0xFF3E3E42);
  static const primary = Color(0xFF007ACC);
  static const primaryDim = Color(0xFF005F9E);
  static const secondary = Color(0xFF4FC1FF);
  static const accent = Color(0xFFC586C0);
  static const textPrimary = Color(0xFFCCCCCC);
  static const textSecondary = Color(0xFF969696);
  static const textMuted = Color(0xFF606060);
  static const error = Color(0xFFF48771);
  static const warning = Color(0xFFCCA700);
  static const success = Color(0xFF89D185);
  static const info = Color(0xFF4FC1FF);
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
