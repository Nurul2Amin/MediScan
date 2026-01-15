class OsmPharmacy {
  final int id;
  final double latitude;
  final double longitude;
  final String? name;
  final String? address;

  OsmPharmacy({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.name,
    this.address,
  });

  factory OsmPharmacy.fromJson(Map<String, dynamic> json) {
    return OsmPharmacy(
      id: json['id'] as int,
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lon'] as num).toDouble(),
      name: json['tags']?['name'],
      address: json['tags']?['addr:full'] ?? json['tags']?['addr:street'],
    );
  }
}
