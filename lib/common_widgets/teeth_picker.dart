import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

class TeethPicker extends StatefulWidget {
  final Set<String> selectedTeeth;
  final ValueChanged<Set<String>> onChanged;

  const TeethPicker({
    Key? key,
    required this.selectedTeeth,
    required this.onChanged,
  }) : super(key: key);

  @override
  _TeethPickerState createState() => _TeethPickerState();
}

class _TeethPickerState extends State<TeethPicker> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.selectedTeeth);
  }

  void _toggleTooth(String tooth) {
    setState(() {
      if (_selected.contains(tooth)) {
        _selected.remove(tooth);
      } else {
        _selected.add(tooth);
      }
      widget.onChanged(_selected);
    });
  }

  @override
  Widget build(BuildContext context) {
    final quadrants = [
      {'label': 'UR', 'teeth': List.generate(8, (i) => '1${8 - i}')},
      {'label': 'UL', 'teeth': List.generate(8, (i) => '2${i + 1}')},
      {'label': 'LL', 'teeth': List.generate(8, (i) => '3${i + 1}')},
      {'label': 'LR', 'teeth': List.generate(8, (i) => '4${8 - i}')},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          "Select Teeth",
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final quadrantWidth = (maxWidth - 16) / 2; // 16 is total spacing
            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: quadrantWidth,
                      child: buildQuadrant(
                          'UR', quadrants[0]['teeth'] as List<String>),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: quadrantWidth,
                      child: buildQuadrant(
                          'UL', quadrants[1]['teeth'] as List<String>),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: quadrantWidth,
                      child: buildQuadrant(
                          'LR', quadrants[3]['teeth'] as List<String>),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: quadrantWidth,
                      child: buildQuadrant(
                          'LL', quadrants[2]['teeth'] as List<String>),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget buildQuadrant(String label, List<String> teeth) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 2),
        Wrap(
          spacing: 2,
          runSpacing: 2,
          children: teeth.map((tooth) {
            final selected = _selected.contains(tooth);
            return GestureDetector(
              onTap: () => _toggleTooth(tooth),
              child: Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? Colors.blue : Colors.grey[200],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: selected ? Colors.blue : Colors.grey[400]!,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Text(
                  tooth,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
