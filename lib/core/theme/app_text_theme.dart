import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTextTheme {
  static const plusJakartaSans = 'Segoe UI';

  // Flip this to true to use the platform system font everywhere.
  static const useSystemFont = false;

  static const sansFallback = <String>[
    'Segoe UI',
    'Roboto',
    'Helvetica Neue',
    'Arial',
    'sans-serif',
  ];

  static String? get fontFamily => useSystemFont ? null : plusJakartaSans;
  static List<String>? get fontFamilyFallback =>
      useSystemFont ? null : sansFallback;
  static TextStyle get baseTextStyle => TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
  );

  static TextTheme textTheme = const TextTheme(
    displayLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.w700),
    headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
    headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
    titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
    titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
    bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
  ).apply(
    bodyColor: AppColors.textPrimary,
    displayColor: AppColors.textPrimary,
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
  );
}
