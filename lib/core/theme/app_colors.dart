import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary brand palette (Slate / Navy)
  static const Color primary = Color(0xFF0F172A);
  static const Color primaryLight = Color(0xFF1E293B);
  static const Color primaryDark = Color(0xFF020617);

  // Accent & Action (Emerald / Mint for POS operations)
  static const Color accent = Color(0xFF059669);
  static const Color accentLight = Color(0xFF10B981);
  static const Color accentContainer = Color(0xFFD1FAE5);

  // Secondary Accents (Indigo, Purple, Amber, Cyan)
  static const Color indigo = Color(0xFF4F46E5);
  static const Color indigoLight = Color(0xFF6366F1);
  static const Color indigoContainer = Color(0xFFEEF2FF);

  static const Color purple = Color(0xFF7C3AED);
  static const Color purpleLight = Color(0xFF8B5CF6);
  static const Color purpleContainer = Color(0xFFF5F3FF);

  static const Color amber = Color(0xFFD97706);
  static const Color amberLight = Color(0xFFF59E0B);
  static const Color amberContainer = Color(0xFFFFFBEB);

  static const Color cyan = Color(0xFF0891B2);
  static const Color cyanLight = Color(0xFF06B6D4);
  static const Color cyanContainer = Color(0xFFECFEFF);

  // Background & Surfaces
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);

  // Semantic Status
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color danger = Color(0xFFDC2626);
  static const Color info = Color(0xFF2563EB);

  // Text & Borders
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color dividerLight = Color(0xFFF1F5F9);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient indigoGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
