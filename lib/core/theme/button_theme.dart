import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';

class AppButtonTheme {
  static ElevatedButtonThemeData elevated = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 0,
      backgroundColor: AppColors.primary500,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    ),
  );

  static OutlinedButtonThemeData outlined = OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.primary600,
      side: const BorderSide(color: AppColors.borderSoft),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
    ),
  );

  static TextButtonThemeData ghost = TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.primary600,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
    ),
  );
}
