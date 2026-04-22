import 'package:flutter/material.dart';

import '../../theme/app_text_theme.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;

  const SectionHeader({
    super.key,
    required this.title,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextTheme.textTheme.headlineMedium),
        if (action != null) action!,
      ],
    );
  }
}
