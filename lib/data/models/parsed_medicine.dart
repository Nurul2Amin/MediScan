class ParsedMedicine {
  final String name;
  final String? genericName;
  final String? strength;
  final String? form;

  ParsedMedicine({
    required this.name,
    this.genericName,
    this.strength,
    this.form,
  });

  factory ParsedMedicine.fromJson(Map<String, dynamic> json) {
    return ParsedMedicine(
      name: json['name'] as String,
      genericName: json['generic_name'] as String?,
      strength: json['strength'] as String?,
      form: json['form'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'generic_name': genericName,
      'strength': strength,
      'form': form,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParsedMedicine &&
        other.name == name &&
        other.genericName == genericName &&
        other.strength == strength &&
        other.form == form;
  }

  @override
  int get hashCode => Object.hash(name, genericName, strength, form);
}
