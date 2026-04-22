import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'app_badge.dart';

class AppAlert extends StatelessWidget {
  final String message;
  final BadgeType type;
  final IconData? icon;

  const AppAlert({
    super.key,
    required this.message,
    required this.type,
    this.icon,
  });

  Color _color() {
    return switch (type) {
      BadgeType.success => AppColors.success,
      BadgeType.warning => AppColors.warning,
      BadgeType.error => AppColors.error,
      BadgeType.info => AppColors.info,
      BadgeType.primary => AppColors.primary500,
      BadgeType.secondary => AppColors.secondary500,
    };
  }

  IconData _icon() {
    if (icon != null) return icon!;

    return switch (type) {
      BadgeType.success => Icons.check_circle_outline,
      BadgeType.warning => Icons.warning_amber_rounded,
      BadgeType.error => Icons.error_outline,
      BadgeType.info => Icons.info_outline,
      BadgeType.primary => Icons.info_outline,
      BadgeType.secondary => Icons.info_outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(_icon(), color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
