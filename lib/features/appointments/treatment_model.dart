
class Treatment {
  final String name;
  final double price;
  final List<Treatment> subTreatments;

  Treatment({
    required this.name,
    required this.price,
    this.subTreatments = const [],
  });

  // For serialization/deserialization if needed
  factory Treatment.fromJson(Map<String, dynamic> json) => Treatment(
        name: json['name'],
        price: (json['price'] ?? 0).toDouble(),
        subTreatments: (json['subTreatments'] as List<dynamic>? ?? [])
            .map((e) => Treatment.fromJson(e))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'price': price,
        'subTreatments': subTreatments.map((e) => e.toJson()).toList(),
      };
}