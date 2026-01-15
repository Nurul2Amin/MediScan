class Medicine {
  final int id;
  final String name;
  final String? genericName;
  final String? form;
  final String? strength;
  final String? manufacturer;
  final double? price;

  Medicine({
    required this.id,
    required this.name,
    this.genericName,
    this.form,
    this.strength,
    this.manufacturer,
    this.price,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) {
    return Medicine(
      id: json['medicine_id'] as int,
      name: json['name'] as String,
      genericName: json['generic_name'] as String?,
      form: json['form'] as String?,
      strength: json['strength'] as String?,
      manufacturer: json['manufacturer'] as String?,
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'medicine_id': id,
      'name': name,
      'generic_name': genericName,
      'form': form,
      'strength': strength,
      'manufacturer': manufacturer,
      'price': price,
    };
  }
}
