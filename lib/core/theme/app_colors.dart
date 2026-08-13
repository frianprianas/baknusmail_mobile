import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors - SMK Bakti Nusantara 666
  static const Color primary = Color(0xFF1E40AF); // Deep Royal Blue
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF1E3A8A);
  
  static const Color secondary = Color(0xFF0D9488); // Deep Teal
  static const Color secondaryLight = Color(0xFF14B8A6);
  
  static const Color accent = Color(0xFF06B6D4); // Cyan
  static const Color gold = Color(0xFFF59E0B); // Amber / Star
  
  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Dark Theme Surfaces
  static const Color darkBackground = Color(0xFF090D16);
  static const Color darkSurface = Color(0xFF111827);
  static const Color darkSurfaceElevated = Color(0xFF1F2937);
  static const Color darkBorder = Color(0xFF374151);
  static const Color darkTextPrimary = Color(0xFFF9FAFB);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);
  static const Color darkTextMuted = Color(0xFF6B7280);

  // Light Theme Surfaces
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // Avatar Gradient Colors
  static const List<Color> avatarColors = [
    Color(0xFF3B82F6), // Blue
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEC4899), // Pink
    Color(0xFFF59E0B), // Amber
    Color(0xFF10B981), // Emerald
    Color(0xFF06B6D4), // Cyan
    Color(0xFFF97316), // Orange
    Color(0xFF6366F1), // Indigo
  ];

  static Color getAvatarColor(String seed) {
    if (seed.isEmpty) return avatarColors[0];
    int hash = 0;
    for (int i = 0; i < seed.length; i++) {
      hash = seed.codeUnitAt(i) + ((hash << 5) - hash);
    }
    final index = hash.abs() % avatarColors.length;
    return avatarColors[index];
  }
}
