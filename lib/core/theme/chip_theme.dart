import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';

class AppChipTheme {
  static ChipThemeData theme = const ChipThemeData(
    backgroundColor: AppColors.primary50,
    labelStyle: TextStyle(fontWeight: FontWeight.w600),
    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    shape: RoundedRectangleBorder(borderRadius: AppRadius.pill),
  );
}
