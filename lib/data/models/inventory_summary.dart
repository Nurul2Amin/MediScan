import 'package:prescription_scanner/core/helpers/stock_formatter.dart';

class InventorySummary {
  final int pharmacyId;
  final int pharmacyMedicineId;
  final int medicineId;
  final String medicineName;
  final String? form;
  final String? strength;
  final String unitType;
  final int totalBaseUnits;
  final int reorderLevel;
  final bool isAvailable;
  final DateTime? nextExpiryDate;
  final int activeBatchCount;
  final int expiredQty;
  
  // Pack configuration for display formatting
  final int pillsPerLeaflet;
  final int leafletsPerBox;

  InventorySummary({
    required this.pharmacyId,
    required this.pharmacyMedicineId,
    required this.medicineId,
    required this.medicineName,
    this.form,
    this.strength,
    required this.unitType,
    required this.totalBaseUnits,
    required this.reorderLevel,
    required this.isAvailable,
    this.nextExpiryDate,
    required this.activeBatchCount,
    required this.expiredQty,
    this.pillsPerLeaflet = 10,
    this.leafletsPerBox = 3,
  });

  factory InventorySummary.fromJson(Map<String, dynamic> json) {
    return InventorySummary(
      pharmacyId: json['pharmacy_id'] as int,
      pharmacyMedicineId: json['pharmacy_medicine_id'] as int,
      medicineId: json['medicine_id'] as int,
      medicineName: json['medicine_name'] as String,
      form: json['form'] as String?,
      strength: json['strength'] as String?,
      unitType: json['unit_type'] as String? ?? 'pill',
      totalBaseUnits: json['total_base_units'] as int,
      reorderLevel: json['reorder_level'] as int? ?? 10,
      isAvailable: json['is_available'] as bool? ?? true,
      nextExpiryDate: json['next_expiry_date'] != null
          ? DateTime.parse(json['next_expiry_date'] as String)
          : null,
      activeBatchCount: json['active_batch_count'] as int? ?? 0,
      expiredQty: json['expired_qty'] as int? ?? 0,
      pillsPerLeaflet: json['pills_per_leaflet'] as int? ?? 10,
      leafletsPerBox: json['leaflets_per_box'] as int? ?? 3,
    );
  }

  bool get isLowStock => totalBaseUnits <= reorderLevel;
  bool get hasExpiringSoon => nextExpiryDate != null && 
      nextExpiryDate!.difference(DateTime.now()).inDays <= 30;
  bool get hasExpired => expiredQty > 0;

  /// Get formatted stock display (e.g., "2 boxes + 3 leaflets + 7 pills")
  String get formattedStock => StockFormatter.format(
    totalBaseUnits: totalBaseUnits,
    unitType: unitType,
    pillsPerLeaflet: pillsPerLeaflet,
    leafletsPerBox: leafletsPerBox,
  );

  /// Get stock breakdown for UI components
  StockBreakdown get stockBreakdown => StockFormatter.getBreakdown(
    totalBaseUnits: totalBaseUnits,
    unitType: unitType,
    pillsPerLeaflet: pillsPerLeaflet,
    leafletsPerBox: leafletsPerBox,
  );
}
