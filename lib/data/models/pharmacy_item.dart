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
  final double totalPrice;
  final double distance;

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
    this.totalPrice = 0.0,
    this.distance = 0.0,
  });

  factory Pharmacy.fromJson(Map<String, dynamic> json) {
    return Pharmacy(
      id: json['pharmacy_id'] as int,
      name: json['name'] as String,
      address: json['address'] as String?,
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      contactNumber: json['contact_number'] as String?,
      email: json['email'] as String?,
      openingHours: json['opening_hours'] as String?,
      matchedItems: json['matched_items'] != null ? (json['matched_items'] as num).toInt() : 0,
      totalPrice: json['total_price'] != null ? (json['total_price'] as num).toDouble() : 0.0,
      distance: json['distance_m'] != null ? (json['distance_m'] as num).toDouble() : 0.0,
    );
  }
}
