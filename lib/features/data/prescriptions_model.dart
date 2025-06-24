import '../../core/model.dart';

class Prescriptions extends Model {
  String prescription = '';

  Prescriptions() : super.fromJson({});

  Prescriptions.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    prescription = json['prescription'] ?? '';
  }

  @override
  Map<String, dynamic> toJson() {
    final json = super.toJson();
    if (prescription.isNotEmpty) json['prescription'] = prescription;
    return json;
  }
}
