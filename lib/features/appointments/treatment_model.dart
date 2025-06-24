class Treatment {
  final String name;
  final double price;

  Treatment({
    required this.name,
    required this.price,
  });

  // For serialization/deserialization if needed
  factory Treatment.fromJson(Map<String, dynamic> json) => Treatment(
        name: json['name'],
        price: (json['price'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'price': price,
      };
}
