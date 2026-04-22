import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';

class AppCardTheme {
  static CardThemeData theme = const CardThemeData(
    elevation: 0,
    color: AppColors.bgCard,
    shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
    shadowColor: Colors.black12,
    margin: EdgeInsets.zero,
  );
}
