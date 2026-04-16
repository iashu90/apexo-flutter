import 'package:flutter/material.dart';
// If using Fluent UI ToggleSwitch, import it as well
import 'package:fluent_ui/fluent_ui.dart' as fluent;

class TeethPicker extends StatefulWidget {
  final Set<String> selectedTeeth;
  final ValueChanged<Set<String>> onChanged;
  final bool isAdult;

  const TeethPicker({
    super.key,
    required this.selectedTeeth,
    required this.onChanged,
    this.isAdult = true,
  });

  @override
  _TeethPickerState createState() => _TeethPickerState();
}

class _TeethPickerState extends State<TeethPicker> {
  late Set<String> _adultSelected;
  late Set<String> _kidSelected;
  late Set<String> _selected;
  bool isAdult = true;

  @override
  void initState() {
    super.initState();
    isAdult = widget.isAdult;
    _adultSelected = isAdult ? Set<String>.from(widget.selectedTeeth) : {};
    _kidSelected = !isAdult ? Set<String>.from(widget.selectedTeeth) : {};
    _selected = isAdult ? _adultSelected : _kidSelected;
  }

  @override
  void didUpdateWidget(covariant TeethPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAdult != oldWidget.isAdult) {
      setState(() {
        isAdult = widget.isAdult;
        _selected = isAdult ? _adultSelected : _kidSelected;
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
      if (isAdult) {
        _adultSelected = _selected;
      } else {
        _kidSelected = _selected;
      }
      widget.onChanged(_selected);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use different quadrants for adult and kid
    final quadrants = isAdult
        ? [
            // UR: 18 17 16 15 14 13 12 11
            {'label': 'UR', 'teeth': List.generate(8, (i) => '1${8 - i}')},
            // UL: 26 27 28 21 22 23 24 25
            {
              'label': 'UL',
              'teeth': ['26', '27', '28', '21', '22', '23', '24', '25']
            },
            // LL: 35 34 33 32 31 38 37 36
            {
              'label': 'LL',
              'teeth': ['31', '32', '33', '34', '35', '36', '37', '38']
            },
            // LR: 45 44 43 42 41 48 47 46
            {
              'label': 'LR',
              'teeth': ['45', '44', '43', '42', '41', '48', '47', '46']
            },
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
                  _selected = isAdult ? _adultSelected : _kidSelected;
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
                      child: buildQuadrantCustom(
                          quadrants[0]['label'] as String,
                          quadrants[0]['teeth'] as List<String>,
                          rightAligned: true,
                          rowBreak: 3),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: quadrantWidth,
                      child: buildQuadrantCustom(
                        quadrants[1]['label'] as String,
                        quadrants[1]['teeth'] as List<String>,
                        rowBreak:
                            3, // First row: 26 27 28, Second row: 21 22 23 24 25
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: quadrantWidth,
                      child: buildQuadrantCustom(
                        quadrants[3]['label'] as String,
                        quadrants[3]['teeth'] as List<String>,
                        rightAligned: true,
                        rowBreak:
                            5, // First row: 45 44 43 42 41, Second row: 48 47 46
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: quadrantWidth,
                      child: buildQuadrantCustom(
                        quadrants[2]['label'] as String,
                        quadrants[2]['teeth'] as List<String>,
                        rowBreak:
                            5, // First row: 35 34 33 32 31, Second row: 38 37 36
                      ),
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

  Widget buildQuadrantCustom(
    String label,
    List<String> teeth, {
    bool rightAligned = false,
    int? rowBreak,
  }) {
    // If rowBreak is provided, split into two rows
    List<List<String>> rows = [];
    if (rowBreak != null && teeth.length > rowBreak) {
      rows.add(teeth.sublist(0, rowBreak));
      rows.add(teeth.sublist(rowBreak));
    } else {
      rows.add(teeth);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          rightAligned ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 2),
        ...rows.map((row) => Row(
              mainAxisAlignment: rightAligned
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              children: row.map((tooth) {
                final selected = _selected.contains(tooth);
                return GestureDetector(
                  onTap: () => _toggleTooth(tooth),
                  child: Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
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
            )),
      ],
    );
  }
}
