import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';

enum AppButtonVariant { primary, secondary, ghost, danger }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final Widget? leading;
  final bool expanded;
  final bool compact;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.leading,
    this.expanded = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = compact ? 10.0 : 16.0;
    final verticalPadding = compact ? 6.0 : 10.0;
    final minHeight = compact ? 30.0 : 40.0;

    final child = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: 8),
        ],
        Text(label),
      ],
    );

    switch (variant) {
      case AppButtonVariant.secondary:
        return OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary600,
            minimumSize: Size(0, minHeight),
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            side: const BorderSide(color: AppColors.borderSoft),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          ),
          child: child,
        );
      case AppButtonVariant.ghost:
        return TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary600,
            minimumSize: Size(0, minHeight),
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          ),
          child: child,
        );
      case AppButtonVariant.primary:
        return ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: AppColors.primary500,
            foregroundColor: Colors.white,
            minimumSize: Size(0, minHeight),
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          ),
          child: child,
        );
      case AppButtonVariant.danger:
        return ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            minimumSize: Size(0, minHeight),
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
          ),
          child: child,
        );
    }
  }
}
