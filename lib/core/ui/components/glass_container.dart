import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.card,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: AppRadius.card,
            border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
            boxShadow: AppShadows.md,
          ),
          child: child,
        ),
      ),
    );
  }
}
