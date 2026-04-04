import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'tooth_model.dart';
import 'treatment_colors.dart';

class ToothWidget extends StatelessWidget {
  final ToothState tooth;
  final Function(ToothSurface surface) onSurfaceTap;
  final VoidCallback? onToothTap;
  final double size;

  const ToothWidget({
    super.key,
    required this.tooth,
    required this.onSurfaceTap,
    this.onToothTap,
    this.size = 70,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 1.4,
      child: Stack(
        children: [
          _buildBaseTooth(),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: onToothTap,
            ),
          ),
          _buildSurface(ToothSurface.mesial, 'assets/svg/surface_M.svg'),
          _buildSurface(ToothSurface.distal, 'assets/svg/surface_D.svg'),
          _buildSurface(ToothSurface.occlusal, 'assets/svg/surface_O.svg'),
          _buildSurface(ToothSurface.buccal, 'assets/svg/surface_B.svg'),
          _buildSurface(ToothSurface.lingual, 'assets/svg/surface_L.svg'),
          _buildToothNumber(),
        ],
      ),
    );
  }

  Widget _buildBaseTooth() {
    return SvgPicture.asset(
      'assets/svg/tooth_base.svg',
      width: size,
      height: size * 1.4,
    );
  }

  Widget _buildSurface(ToothSurface surface, String asset) {
    final treatment = tooth.surfaces[surface];
    final color = getTreatmentColor(treatment);

    return Positioned.fill(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => onSurfaceTap(surface),
          child: SvgPicture.asset(
            asset,
            width: size,
            height: size * 1.4,
            colorFilter: ColorFilter.mode(
              color,
              BlendMode.srcATop,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToothNumber() {
    return Positioned(
      bottom: -2,
      left: 0,
      right: 0,
      child: Center(
        child: Text(
          tooth.toothId,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
