import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // GitHub Primer Brand Colors
  static const Color primary = Color(0xFF58A6FF); // GitHub electric blue
  static const Color primaryDark = Color(0xFF1F6FEB);
  static const Color primaryLight = Color(0xFF79C0FF);
  static const Color secondary = Color(0xFFA371F7); // GitHub purple
  static const Color secondaryGlow = Color(0xFFBC8CFF);
  static const Color accent = Color(0xFF2EA043); // GitHub green

  // Dark Theme (Authentic GitHub Primer Dark)
  static const Color darkBg = Color(0xFF0D1117); // Canvas default
  static const Color darkCard = Color(0xFF161B22); // Canvas sub
  static const Color darkElevated = Color(0xFF21262D); // Canvas overlay
  static const Color darkBorder = Color(0xFF30363D); // Border default
  static const Color darkBorderSubtle = Color(0xFF21262D);
  static const Color darkTextPrimary = Color(0xFFF0F6FC); // Foreground default
  static const Color darkTextSecondary = Color(0xFFC9D1D9); // Foreground muted
  static const Color darkTextMuted = Color(0xFF8B949E); // Foreground subtle

  // Light Theme (GitHub Primer Light)
  static const Color lightBg = Color(0xFFF6F8FA);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightElevated = Color(0xFFEAEEF2);
  static const Color lightBorder = Color(0xFFD0D7DE);
  static const Color lightBorderSubtle = Color(0xFFAF8F1F);
  static const Color lightTextPrimary = Color(0xFF1F2328);
  static const Color lightTextSecondary = Color(0xFF424A53);
  static const Color lightTextMuted = Color(0xFF656D76);

  // Status colors
  static const Color success = Color(0xFF238636); // GitHub commit green
  static const Color warning = Color(0xFFE3B341); // GitHub star gold
  static const Color error = Color(0xFFF85149); // GitHub issue closed red
  static const Color info = Color(0xFF58A6FF);

  // Language tags
  static const Color langDart = Color(0xFF00B4AB);
  static const Color langPython = Color(0xFF3572A5);
  static const Color langTypeScript = Color(0xFF3178C6);
  static const Color langJavaScript = Color(0xFFF1E05A);
  static const Color langRust = Color(0xFFDEA584);
  static const Color langGo = Color(0xFF00ADD8);
  static const Color langKotlin = Color(0xFFA97BFF);
  static const Color langSwift = Color(0xFFF05138);

  // Frosted Glass Tints (Deep Apple/GitHub Frosted)
  static const Color glassHighlightDark = Color(0x2EFFFFFF);
  static const Color glassHighlightLight = Color(0x80FFFFFF);
}
