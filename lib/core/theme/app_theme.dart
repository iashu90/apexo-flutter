import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_theme.dart';
import 'button_theme.dart';
import 'input_theme.dart';
import 'card_theme.dart';
import 'chip_theme.dart';

class AppTheme {
  static ThemeData light = ThemeData(
    useMaterial3: true,
    fontFamily: AppTextTheme.fontFamily,
    scaffoldBackgroundColor: AppColors.bgMain,
    primaryColor: AppColors.primary500,
    textTheme: AppTextTheme.textTheme,
    elevatedButtonTheme: AppButtonTheme.elevated,
    outlinedButtonTheme: AppButtonTheme.outlined,
    textButtonTheme: AppButtonTheme.ghost,
    inputDecorationTheme: AppInputTheme.theme,
    cardTheme: AppCardTheme.theme,
    chipTheme: AppChipTheme.theme,
  );
}
