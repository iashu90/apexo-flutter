import 'package:fluent_ui/fluent_ui.dart';

import 'tooth_model.dart';
import 'tooth_widget.dart';

class OdontogramPicker extends StatelessWidget {
  final Map<String, ToothState> teeth;
  final void Function(String toothId, ToothSurface surface) onSurfaceTap;
  final ValueChanged<String>? onToothTap;
  final double toothSize;

  const OdontogramPicker({
    super.key,
    required this.teeth,
    required this.onSurfaceTap,
    this.onToothTap,
    this.toothSize = 58,
  });

  static const List<String> _upperTeeth = [
    '18',
    '17',
    '16',
    '15',
    '14',
    '13',
    '12',
    '11',
    '21',
    '22',
    '23',
    '24',
    '25',
    '26',
    '27',
    '28',
  ];

  static const List<String> _lowerTeeth = [
    '48',
    '47',
    '46',
    '45',
    '44',
    '43',
    '42',
    '41',
    '31',
    '32',
    '33',
    '34',
    '35',
    '36',
    '37',
    '38',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _row(_upperTeeth),
        const SizedBox(height: 10),
        _row(_lowerTeeth),
      ],
    );
  }

  Widget _row(List<String> ids) {
    return Wrap(
      spacing: 2,
      runSpacing: 6,
      children: ids
          .map(
            (id) => ToothWidget(
              tooth: teeth[id] ?? ToothState(toothId: id),
              size: toothSize,
              onToothTap: onToothTap == null ? null : () => onToothTap!(id),
              onSurfaceTap: (surface) => onSurfaceTap(id, surface),
            ),
          )
          .toList(growable: false),
    );
  }
}
