import 'package:apexo/core/ui/components/app_button.dart';
import 'package:flutter/material.dart';

class SelectableChipGroup extends StatelessWidget {
  final List<String> options;
  final Set<String> selected;
  final void Function(String value) onToggle;

  const SelectableChipGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map(
            (item) => AppButton(
              label: item,
              compact: false,
              variant: selected.contains(item)
                  ? AppButtonVariant.primary
                  : AppButtonVariant.secondary,
              onPressed: () => onToggle(item),
            ),
          )
          .toList(growable: false),
    );
  }
}
