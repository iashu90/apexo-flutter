import 'package:apexo/features/appointments/appointments_store.dart';

class Treatment {
  final String name;
  final double price;
  final bool multiplier; // Changed to boolean

  Treatment({
    required this.name,
    required this.price,
    this.multiplier = false, // Default value
  });

  factory Treatment.fromJson(Map<String, dynamic> json) {
    bool multiplier;
    if (json['multiplier'] != null) {
      final val = json['multiplier'];
      if (val is bool) {
        multiplier = val;
      } else if (val is num) {
        multiplier = val != 0; // Any non-zero is true, zero is false
      } else {
        multiplier = val.toString() == 'true';
      }
    } else {
      // fallback to allTreatments or default
      final match = allTreatments.firstWhere(
        (t) => t.name == json['name'],
        orElse: () =>
            Treatment(name: json['name'], price: 0, multiplier: false),
      );
      multiplier = match.multiplier;
    }
    return Treatment(
      name: json['name'],
      price: (json['price'] ?? 0).toDouble(),
      multiplier: multiplier,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'price': price,
        'multiplier': multiplier,
      };
}
