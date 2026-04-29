import 'package:apexo/core/theme/app_colors.dart';
import 'package:apexo/core/theme/app_text_theme.dart';
import 'package:flutter/widgets.dart';

class AppScreenTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const AppScreenTitle({
    super.key,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextTheme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.blue750,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: AppTextTheme.textTheme.bodySmall?.copyWith(
              color: AppColors.textBlueMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}
