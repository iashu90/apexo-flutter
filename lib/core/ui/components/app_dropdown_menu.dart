import 'package:fluent_ui/fluent_ui.dart';

class AppDropdownItem<T> {
  final T value;
  final String label;

  const AppDropdownItem({
    required this.value,
    required this.label,
  });
}

class AppDropdownMenu<T> extends StatelessWidget {
  final double width;
  final T value;
  final List<AppDropdownItem<T>> items;
  final ValueChanged<T> onChanged;

  const AppDropdownMenu({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.width = 180,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: ComboBox<T>(
        isExpanded: true,
        value: value,
        items: items
            .map(
              (item) => ComboBoxItem<T>(
                value: item.value,
                child: Text(item.label),
              ),
            )
            .toList(growable: false),
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
      ),
    );
  }
}
