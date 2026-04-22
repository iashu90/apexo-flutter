import 'package:flutter/material.dart';

class AppGradients {
  static const primary = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const secondary = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
  );

  static const success = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF34D399)],
  );
}
