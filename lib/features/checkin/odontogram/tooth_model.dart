enum ToothSurface { mesial, distal, occlusal, buccal, lingual }

enum TreatmentType {
  filling,
  rootCanal,
  crown,
  extraction,
  implant,
}

class ToothState {
  final String toothId;
  final Map<ToothSurface, TreatmentType?> surfaces;

  ToothState({
    required this.toothId,
    Map<ToothSurface, TreatmentType?>? surfaces,
  }) : surfaces =
            surfaces ??
            {
              ToothSurface.mesial: null,
              ToothSurface.distal: null,
              ToothSurface.occlusal: null,
              ToothSurface.buccal: null,
              ToothSurface.lingual: null,
            };
}
