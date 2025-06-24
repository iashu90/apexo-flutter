import 'package:flutter/material.dart';
// If using Fluent UI ToggleSwitch, import it as well
import 'package:fluent_ui/fluent_ui.dart' as fluent;

class TeethPicker extends StatefulWidget {
  final Set<String> selectedTeeth;
  final ValueChanged<Set<String>> onChanged;
  final bool isAdult;

  const TeethPicker({
    Key? key,
    required this.selectedTeeth,
    required this.onChanged,
    this.isAdult = true,
  }) : super(key: key);

  @override
  _TeethPickerState createState() => _TeethPickerState();
}

class _TeethPickerState extends State<TeethPicker> {
  late Set<String> _selected;
  bool isAdult = true;
  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.selectedTeeth);
    isAdult = widget.isAdult;
  }

  @override
  void didUpdateWidget(covariant TeethPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAdult != oldWidget.isAdult) {
      setState(() {
        isAdult = widget.isAdult;
      });
    }
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
    // Use different quadrants for adult and kid
    final quadrants = isAdult
        ? [
            {'label': 'UR', 'teeth': List.generate(8, (i) => '1${8 - i}')},
            {'label': 'UL', 'teeth': List.generate(8, (i) => '2${i + 1}')},
            {'label': 'LL', 'teeth': List.generate(8, (i) => '3${i + 1}')},
            {'label': 'LR', 'teeth': List.generate(8, (i) => '4${8 - i}')},
          ]
        : [
            {'label': 'UR', 'teeth': List.generate(5, (i) => '5${5 - i}')},
            {'label': 'UL', 'teeth': List.generate(5, (i) => '6${i + 1}')},
            {'label': 'LL', 'teeth': List.generate(5, (i) => '7${i + 1}')},
            {'label': 'LR', 'teeth': List.generate(5, (i) => '8${5 - i}')},
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isAdult ? "Select Adult Teeth" : "Select Kid Teeth",
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(width: 12),
            fluent.ToggleSwitch(
              checked: isAdult,
              onChanged: (value) {
                setState(() {
                  isAdult = value;
                  _selected.clear();
                  widget.onChanged(_selected);
                });
              },
              content: Text(isAdult ? "Adult" : "Kid"),
              style: fluent.ToggleSwitchThemeData(
                checkedDecoration: fluent.WidgetStateProperty.all(
                  BoxDecoration(
                    color: Colors.blue.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                checkedKnobDecoration: fluent.WidgetStateProperty.all(
                  BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                uncheckedKnobDecoration: fluent.WidgetStateProperty.all(
                  BoxDecoration(
                    color: Colors.grey.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              ),
            ),
          ],
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
                      child: buildQuadrant(quadrants[0]['label'] as String,
                          quadrants[0]['teeth'] as List<String>),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: quadrantWidth,
                      child: buildQuadrant(quadrants[1]['label'] as String,
                          quadrants[1]['teeth'] as List<String>),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: quadrantWidth,
                      child: buildQuadrant(quadrants[3]['label'] as String,
                          quadrants[3]['teeth'] as List<String>),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: quadrantWidth,
                      child: buildQuadrant(quadrants[2]['label'] as String,
                          quadrants[2]['teeth'] as List<String>),
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
