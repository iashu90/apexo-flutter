import 'package:fluent_ui/fluent_ui.dart';

class SittingsCheckboxGroup extends StatelessWidget {
  final String label;
  final List<String> sittings;
  final List<bool> checked;
  final ValueChanged<int>? onChanged; // index of sitting toggled

  const SittingsCheckboxGroup({
    super.key,
    required this.label,
    required this.sittings,
    required this.checked,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Split into rows of 2
    List<Widget> rows = [];
    for (int i = 0; i < sittings.length; i += 2) {
      rows.add(Row(
        children: [
          Checkbox(
            checked: checked[i],
            onChanged: (val) => onChanged?.call(i),
            content: Text(sittings[i]),
          ),
          if (i + 1 < sittings.length) ...[
            const SizedBox(width: 12),
            Checkbox(
              checked: checked[i + 1],
              onChanged: (val) => onChanged?.call(i + 1),
              content: Text(sittings[i + 1]),
            ),
          ],
        ],
      ));
      rows.add(const SizedBox(height: 6));
    }
    return  Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      );

  }
}