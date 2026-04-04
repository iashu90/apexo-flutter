import 'package:fluent_ui/fluent_ui.dart';

import 'tooth_model.dart';

Color getTreatmentColor(TreatmentType? type) {
  switch (type) {
    case TreatmentType.filling:
      return const Color(0xFF4CAF50);
    case TreatmentType.rootCanal:
      return const Color(0xFFE53935);
    case TreatmentType.crown:
      return const Color(0xFFFFB300);
    case TreatmentType.extraction:
      return const Color(0xFF757575);
    case TreatmentType.implant:
      return const Color(0xFF1E88E5);
    default:
      return Colors.transparent;
  }
}
