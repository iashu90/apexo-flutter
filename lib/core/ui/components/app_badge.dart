import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

enum BadgeType { primary, secondary, success, warning, error, info }

class AppBadge extends StatelessWidget {
  final String text;
  final BadgeType type;
  final Color? color;

  const AppBadge({
    super.key,
    required this.text,
    this.type = BadgeType.primary,
    this.color,
  });

  Color _resolvedColor() {
    if (color != null) return color!;

    return switch (type) {
      BadgeType.primary => AppColors.primary500,
      BadgeType.secondary => AppColors.secondary500,
      BadgeType.success => AppColors.success,
      BadgeType.warning => AppColors.warning,
      BadgeType.error => AppColors.error,
      BadgeType.info => AppColors.info,
    };
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = _resolvedColor();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.12),
        borderRadius: const BorderRadius.all(AppRadius.xs),
      ),
      child: Text(
        text,
        style: TextStyle(color: baseColor, fontWeight: FontWeight.w500),
      ),
    );
  }
}
