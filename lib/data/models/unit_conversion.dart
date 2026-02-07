class UnitConversion {
  final int conversionId;
  final int pharmacyMedicineId;
  final String unitLabel;
  final double multiplierToBase;
  final bool isDefault;
  final DateTime createdAt;

  UnitConversion({
    required this.conversionId,
    required this.pharmacyMedicineId,
    required this.unitLabel,
    required this.multiplierToBase,
    required this.isDefault,
    required this.createdAt,
  });

  factory UnitConversion.fromJson(Map<String, dynamic> json) {
    return UnitConversion(
      conversionId: json['conversion_id'] as int,
      pharmacyMedicineId: json['pharmacy_medicine_id'] as int,
      unitLabel: json['unit_label'] as String,
      multiplierToBase: (json['multiplier_to_base'] as num).toDouble(),
      isDefault: json['is_default'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conversion_id': conversionId,
      'pharmacy_medicine_id': pharmacyMedicineId,
      'unit_label': unitLabel,
      'multiplier_to_base': multiplierToBase,
      'is_default': isDefault,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Convert qty in this unit to base units
  int toBaseUnits(int qty) => (qty * multiplierToBase).round();

  /// Convert qty from base units to this unit
  double fromBaseUnits(int baseQty) => baseQty / multiplierToBase;
}
