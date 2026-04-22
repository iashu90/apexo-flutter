import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_theme.dart';
import 'app_card.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextTheme.textTheme.bodyMedium!
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                Text(value, style: AppTextTheme.textTheme.titleLarge),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: AppTextTheme.textTheme.bodySmall!
                        .copyWith(color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
