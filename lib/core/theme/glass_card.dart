import 'package:flutter/material.dart';

import 'app_radius.dart';
import 'app_shadows.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: AppRadius.card,
        color: Colors.white.withValues(alpha: 0.6),
        boxShadow: AppShadows.md,
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
      ),
      child: child,
    );
  }
}
