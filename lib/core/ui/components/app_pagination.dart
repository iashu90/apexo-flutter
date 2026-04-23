import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

class AppPagination extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  const AppPagination({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) {
      return const SizedBox.shrink();
    }

    final canGoPrev = currentPage > 1;
    final canGoNext = currentPage < totalPages;

    final tokens = _pageTokens();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _NavButton(
            icon: Icons.chevron_left,
            enabled: canGoPrev,
            onTap: canGoPrev ? () => onPageChanged(currentPage - 1) : null,
          ),
          const SizedBox(width: AppSpacing.sm),
          ...tokens.map((page) {
            if (page == null) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                child: const Text(
                  '...',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            }

            final isActive = page == currentPage;
            return GestureDetector(
              onTap: () => onPageChanged(page),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary500 : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderSoft),
                ),
                child: Text(
                  '$page',
                  style: TextStyle(
                    color: isActive ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }),
          const SizedBox(width: AppSpacing.sm),
          _NavButton(
            icon: Icons.chevron_right,
            enabled: canGoNext,
            onTap: canGoNext ? () => onPageChanged(currentPage + 1) : null,
          ),
        ],
      ),
    );
  }

  List<int?> _pageTokens() {
    if (totalPages <= 7) {
      return List<int?>.generate(totalPages, (index) => index + 1);
    }

    final tokens = <int?>[1, 2];
    final start = (currentPage - 1).clamp(3, totalPages - 2);
    final end = (currentPage + 1).clamp(3, totalPages - 2);

    if (start > 3) tokens.add(null);
    for (int page = start; page <= end; page++) {
      if (!tokens.contains(page)) tokens.add(page);
    }
    if (end < totalPages - 2) tokens.add(null);

    if (!tokens.contains(totalPages - 1)) tokens.add(totalPages - 1);
    tokens.add(totalPages);
    return tokens;
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _NavButton({
    required this.icon,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? AppColors.textPrimary : AppColors.textMuted,
        ),
      ),
    );
  }
}
