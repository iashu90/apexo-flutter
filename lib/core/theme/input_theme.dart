import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';

class AppInputTheme {
  static InputDecorationTheme theme = const InputDecorationTheme(
    filled: true,
    fillColor: AppColors.bgCard,
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: AppRadius.input,
      borderSide: BorderSide(color: AppColors.borderSoft),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: AppRadius.input,
      borderSide: BorderSide(color: AppColors.borderSoft),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: AppRadius.input,
      borderSide: BorderSide(color: AppColors.primary500, width: 1.5),
    ),
  );
}
