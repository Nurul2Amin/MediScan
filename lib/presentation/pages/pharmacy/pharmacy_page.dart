import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:prescription_scanner/data/models/medicine.dart';
import 'package:prescription_scanner/data/models/pharmacy_item.dart';
import 'package:prescription_scanner/data/models/osm_pharmacy.dart';
import 'package:prescription_scanner/data/services/osm_service.dart';

class PharmacyMapPage extends StatefulWidget {
  final List<Pharmacy> pharmacies;
  final LatLng? userLocation;

  const PharmacyMapPage({
    super.key,
    required this.pharmacies,
    this.userLocation, // Pass user location if available, else default
  });

  @override
  State<PharmacyMapPage> createState() => _PharmacyMapPageState();
}

class _PharmacyMapPageState extends State<PharmacyMapPage> {
  // Default to a known location (e.g. city center) if no user location
  static const LatLng _defaultLocation = LatLng(23.8103, 90.4125); // Dhaka, as generic example
  
  final _osmService = OsmPharmacyService();
  List<OsmPharmacy> _osmPharmacies = [];
  bool _isLoadingOsm = false;

  @override
  void initState() {
    super.initState();
    _loadOsmPharmacies();
  }

  Future<void> _loadOsmPharmacies() async {
    final center = widget.userLocation ?? _defaultLocation;
    setState(() => _isLoadingOsm = true);
    
    try {
      final results = await _osmService.fetchNearbyPharmacies(
        center.latitude, 
        center.longitude,
        radiusMeters: 5000, 
      );
      if (mounted) {
        setState(() {
          _osmPharmacies = results;
        });
      }
    } catch (e) {
      debugPrint('Error loading OSM pharmacies: $e');
    } finally {
      if (mounted) setState(() => _isLoadingOsm = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.userLocation ?? _defaultLocation;

    return Scaffold(
      appBar: AppBar(title: const Text('Nearby Pharmacies')),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: 13.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.prescription_scanner',
          ),
          
          // Layer 1: OSM Pharmacies (Baseline - Grey)
          MarkerLayer(
            markers: _osmPharmacies.map((osm) {
              return Marker(
                point: LatLng(osm.latitude, osm.longitude),
                width: 30,
                height: 30,
                child: GestureDetector(
                  onTap: () {
                    // Show basic info for OSM pharmacy
                    showModalBottomSheet(context: context, builder: (_) => Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(osm.name ?? 'Pharmacy (Public)', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(osm.address ?? 'Address not available', style: const TextStyle(color: Colors.grey)),
                          const SizedBox(height: 8),
                          const Chip(label: Text('Availability: Unknown'), backgroundColor: Colors.grey),
                        ],
                      ),
                    ));
                  },
                  child: const Icon(Icons.local_pharmacy, color: Colors.grey, size: 30),
                ),
              );
            }).toList(),
          ),

          // Layer 2: Verified App Pharmacies (Overlay - Green)
          // These are overlayed ON TOP of OSM markers
          MarkerLayer(
            markers: [
              // Pharmacy Markers
              ...widget.pharmacies.map((pharmacy) {
                 // Parse location from Pharmacy model
                 double lat = center.latitude + 0.005; 
                 double lng = center.longitude + 0.005;
                 
                 if (pharmacy.latitude != null && pharmacy.longitude != null) {
                    lat = pharmacy.latitude!;
                    lng = pharmacy.longitude!;
                 }
                 
                 return Marker(
                  point: LatLng(lat, lng),
                  width: 50, // Slightly larger to stand out
                  height: 50,
                  child: GestureDetector(
                    onTap: () {
                      showModalBottomSheet(context: context, builder: (_) => Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Text(pharmacy.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                             const SizedBox(height: 4),
                             Text(pharmacy.address ?? 'No address', style: const TextStyle(color: Colors.black87)),
                             const SizedBox(height: 12),
                             Row(
                               children: [
                                 const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                 const SizedBox(width: 8),
                                 Text('${pharmacy.matchedItems} Items Available', style: const TextStyle(fontWeight: FontWeight.bold)),
                               ],
                             ),
                             if (pharmacy.totalPrice != null)
                               Text('Total Price: \$${pharmacy.totalPrice}'),
                          ],
                        ),
                      ));
                    },
                    child: const Icon(Icons.location_on, color: Colors.green, size: 50),
                  ),
                );
              }),
              
              // User Location Marker (Blue - Keeping standard UX)
              Marker(
                point: center,
                width: 40,
                height: 40,
                child: const Icon(Icons.my_location, color: Colors.blue, size: 40),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
