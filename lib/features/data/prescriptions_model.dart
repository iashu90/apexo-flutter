import '../../core/model.dart';

class Prescriptions extends Model {
  String prescription = '';

  Prescriptions() : super.fromJson({});

  Prescriptions.fromJson(Map<String, dynamic> json) : super.fromJson(json) {
    prescription = json['prescription'] ?? '';
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'prescription': prescription,
      };
}
