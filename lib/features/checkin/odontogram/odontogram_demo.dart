import 'package:fluent_ui/fluent_ui.dart';

import 'tooth_model.dart';
import 'tooth_widget.dart';

class OdontogramDemo extends StatefulWidget {
  const OdontogramDemo({super.key});

  @override
  State<OdontogramDemo> createState() => _OdontogramDemoState();
}

class _OdontogramDemoState extends State<OdontogramDemo> {
  final ToothState tooth = ToothState(toothId: '16');

  void onSurfaceClicked(ToothSurface surface) {
    setState(() {
      tooth.surfaces[surface] = TreatmentType.filling;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      content: Container(
        color: const Color(0xFFEFF3F8),
        child: Center(
          child: ToothWidget(
            tooth: tooth,
            onSurfaceTap: onSurfaceClicked,
            size: 90,
          ),
        ),
      ),
    );
  }
}
