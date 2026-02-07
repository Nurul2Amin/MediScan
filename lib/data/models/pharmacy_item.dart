/// Per-item pricing details from pharmacy
class PharmacyItemDetail {
  final int medicineId;
  final double pricePerUnit;
  final int pillsPerStrip;
  final int stripsPerBox;
  final int requestedQty;
  final String requestedUnit;
  final int requiredBaseUnits;
  final double itemTotalPrice;
  final bool hasStock;
  final int availableStock;

  PharmacyItemDetail({
    required this.medicineId,
    required this.pricePerUnit,
    required this.pillsPerStrip,
    required this.stripsPerBox,
    required this.requestedQty,
    required this.requestedUnit,
    required this.requiredBaseUnits,
    required this.itemTotalPrice,
    required this.hasStock,
    required this.availableStock,
  });

  factory PharmacyItemDetail.fromJson(Map<String, dynamic> json) {
    return PharmacyItemDetail(
      medicineId: (json['medicine_id'] as num).toInt(),
      pricePerUnit: (json['price_per_unit'] as num?)?.toDouble() ?? 0.0,
      pillsPerStrip: (json['pills_per_strip'] as num?)?.toInt() ?? 10,
      stripsPerBox: (json['strips_per_box'] as num?)?.toInt() ?? 3,
      requestedQty: (json['requested_qty'] as num?)?.toInt() ?? 1,
      requestedUnit: json['requested_unit'] as String? ?? 'piece',
      requiredBaseUnits: (json['required_base_units'] as num?)?.toInt() ?? 1,
      itemTotalPrice: (json['item_total_price'] as num?)?.toDouble() ?? 0.0,
      hasStock: json['has_stock'] as bool? ?? false,
      availableStock: (json['available_stock'] as num?)?.toInt() ?? 0,
    );
  }
}

class Pharmacy {
  final int id;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? contactNumber;
  final String? email;
  final String? openingHours;
  
  // Extra fields for Search Results
  final int matchedItems;
  final int totalItems;  // Total items in cart
  final double totalPrice;
  final double distance;
  final bool hasFullStock;  // True if pharmacy has stock for ALL items
  
  // Per-item pricing details from pharmacy
  final List<PharmacyItemDetail> itemDetails;

  Pharmacy({
    required this.id,
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
    this.contactNumber,
    this.email,
    this.openingHours,
    this.matchedItems = 0,
    this.totalItems = 0,
    this.totalPrice = 0.0,
    this.distance = 0.0,
    this.hasFullStock = false,
    this.itemDetails = const [],
  });

  /// Check if pharmacy has all items in stock
  bool get hasAllItems => matchedItems >= totalItems && totalItems > 0;
  
  /// Get item detail for a specific medicine
  PharmacyItemDetail? getItemDetail(int medicineId) {
    try {
      return itemDetails.firstWhere((d) => d.medicineId == medicineId);
    } catch (_) {
      return null;
    }
  }

  factory Pharmacy.fromJson(Map<String, dynamic> json) {
    // Parse item_details if present
    List<PharmacyItemDetail> details = [];
    if (json['item_details'] != null) {
      final itemList = json['item_details'] as List;
      details = itemList.map((e) => PharmacyItemDetail.fromJson(e as Map<String, dynamic>)).toList();
    }
    
    return Pharmacy(
      // Handle both 'pharmacy_id' (from table) and 'id' as fallback
      id: (json['pharmacy_id'] ?? json['id']) as int,
      name: json['name'] as String,
      address: json['address'] as String?,
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      contactNumber: json['contact_number'] as String?,
      email: json['email'] as String?,
      openingHours: json['opening_hours'] as String?,
      matchedItems: json['matched_items'] != null ? (json['matched_items'] as num).toInt() : 0,
      totalItems: json['total_items'] != null ? (json['total_items'] as num).toInt() : 0,
      totalPrice: json['total_price'] != null ? (json['total_price'] as num).toDouble() : 0.0,
      distance: json['distance_m'] != null ? (json['distance_m'] as num).toDouble() : 0.0,
      hasFullStock: json['has_full_stock'] as bool? ?? false,
      itemDetails: details,
    );
  }
}
