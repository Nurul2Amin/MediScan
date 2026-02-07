class InventoryBatch {
  final int batchId;
  final int pharmacyMedicineId;
  final String? batchNo;
  final DateTime expiryDate;
  final double? buyPrice;
  final int qtyRemaining;
  final DateTime createdAt;

  InventoryBatch({
    required this.batchId,
    required this.pharmacyMedicineId,
    this.batchNo,
    required this.expiryDate,
    this.buyPrice,
    required this.qtyRemaining,
    required this.createdAt,
  });

  factory InventoryBatch.fromJson(Map<String, dynamic> json) {
    return InventoryBatch(
      batchId: json['batch_id'] as int,
      pharmacyMedicineId: json['pharmacy_medicine_id'] as int,
      batchNo: json['batch_no'] as String?,
      expiryDate: DateTime.parse(json['expiry_date'] as String),
      buyPrice: json['buy_price'] != null ? (json['buy_price'] as num).toDouble() : null,
      qtyRemaining: json['qty_remaining'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'batch_id': batchId,
      'pharmacy_medicine_id': pharmacyMedicineId,
      'batch_no': batchNo,
      'expiry_date': expiryDate.toIso8601String().split('T')[0],
      'buy_price': buyPrice,
      'qty_remaining': qtyRemaining,
      'created_at': createdAt.toIso8601String(),
    };
  }

  int get daysUntilExpiry => expiryDate.difference(DateTime.now()).inDays;
  bool get isExpired => daysUntilExpiry < 0;
  bool get isExpiringSoon => daysUntilExpiry >= 0 && daysUntilExpiry <= 30;
}
