import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:prescription_scanner/data/models/pharmacy_item.dart';
import 'package:prescription_scanner/data/providers.dart';
import 'package:prescription_scanner/presentation/providers/auth_provider.dart';
import 'package:prescription_scanner/presentation/providers/cart_provider.dart';

class PharmacyFinderPage extends ConsumerStatefulWidget {
  const PharmacyFinderPage({super.key});

  @override
  ConsumerState<PharmacyFinderPage> createState() => _PharmacyFinderPageState();
}

class _PharmacyFinderPageState extends ConsumerState<PharmacyFinderPage> {
  final MapController _mapController = MapController();
  List<Pharmacy> _pharmacies = [];
  bool _isLoading = true;
  Position? _currentPosition;
  
  // Custom marker data
  final List<Marker> _markers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // 1. Get Location
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are disabled.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw Exception('Location permissions are denied');
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }

      _currentPosition = await Geolocator.getCurrentPosition();

      // 2. Get Cart Items
      final cartItems = ref.read(cartProvider);
      final medicineIds = cartItems.map((e) => e.id).toList();

      if (medicineIds.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      // 3. Get user preferences
      final profile = ref.read(userProfileProvider).value;
      final defaultRadiusM = profile?.defaultRadiusM ?? 5000;
      final sortMode = profile?.sortMode ?? 'balanced';
      final requireFullMatch = profile?.requireFullMatch ?? false;
      final maxResults = profile?.maxResults ?? 20;

      // 4. Find Pharmacies (RPC) using user's default radius
      final repo = ref.read(pharmacyRepositoryProvider);
      final results = await repo.findPharmacies(
        lat: _currentPosition!.latitude,
        long: _currentPosition!.longitude,
        medicineIds: medicineIds,
        radius: defaultRadiusM, 
      );

      // 5. Apply client-side filtering and sorting
      var filteredResults = results;
      
      // Filter: require_full_match (only pharmacies with all cart items)
      if (requireFullMatch && medicineIds.isNotEmpty) {
        final requiredCount = medicineIds.length;
        filteredResults = results.where((p) => p.matchedItems >= requiredCount).toList();
      }

      // Sort based on user preference
      switch (sortMode) {
        case 'nearest':
          filteredResults.sort((a, b) => a.distance.compareTo(b.distance));
          break;
        case 'cheapest':
          filteredResults.sort((a, b) => a.totalPrice.compareTo(b.totalPrice));
          break;
        case 'most_matched':
          filteredResults.sort((a, b) => b.matchedItems.compareTo(a.matchedItems));
          break;
        case 'balanced':
        default:
          // Balanced: prioritize matched_items desc, then distance asc, then price asc
          filteredResults.sort((a, b) {
            final matchDiff = b.matchedItems.compareTo(a.matchedItems);
            if (matchDiff != 0) return matchDiff;
            final distDiff = a.distance.compareTo(b.distance);
            if (distDiff != 0) return distDiff;
            return a.totalPrice.compareTo(b.totalPrice);
          });
          break;
      }

      // Limit results
      filteredResults = filteredResults.take(maxResults).toList();

      _pharmacies = filteredResults;
      _buildMarkers();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _buildMarkers() {
    _markers.clear();
    
    // User Location Marker
    if (_currentPosition != null) {
      _markers.add(
        Marker(
          point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          width: 60,
          height: 60,
          child: const Column(
            children: [
               Icon(Icons.my_location, color: Colors.blue, size: 30),
               Text("You", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    // Pharmacy Markers
    for (var p in _pharmacies) {
      if (p.latitude != null && p.longitude != null) {
        _markers.add(
          Marker(
            point: LatLng(p.latitude!, p.longitude!),
            width: 80,
            height: 80,
            child: GestureDetector(
              onTap: () {
                _showPharmacyDetails(p);
              },
              child: const Icon(Icons.location_on, color: Colors.red, size: 40),
            ),
          ),
        );
      }
    }
  }

  void _showPharmacyDetails(Pharmacy p) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        height: 200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(p.address ?? "No address"),
            const SizedBox(height: 8),
            Text("${p.matchedItems} items matched • \$${p.totalPrice.toStringAsFixed(2)}"),
            const Spacer(),
            ElevatedButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text("Close")
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Pharmacies (OSM)'),
        actions: [
            IconButton(
                icon: const Icon(Icons.my_location),
                onPressed: () {
                    if (_currentPosition != null) {
                        _mapController.move(
                            LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 
                            13.0
                        );
                    }
                },
            )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentPosition != null
                        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                        : const LatLng(23.8103, 90.4125),
                    initialZoom: 13.0,
                    interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.prescription_scanner',
                    ),
                    MarkerLayer(markers: _markers),
                    if (_currentPosition != null)
                        Consumer(
                          builder: (context, ref, _) {
                            final defaultRadiusM = ref.read(userProfileProvider).value?.defaultRadiusM.toDouble() ?? 5000;
                            return CircleLayer(
                              circles: [
                                CircleMarker(
                                  point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                                  color: Colors.blue.withOpacity(0.1),
                                  borderStrokeWidth: 2,
                                  borderColor: Colors.blue,
                                  useRadiusInMeter: true,
                                  radius: defaultRadiusM,
                                )
                              ],
                            );
                          },
                        ),
                  ],
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _pharmacies.length,
                      itemBuilder: (context, index) {
                        final p = _pharmacies[index];
                        return Container(
                          width: 300,
                          margin: const EdgeInsets.only(right: 10),
                          child: Card(
                            child: InkWell(
                              onTap: () {
                                  if (p.latitude != null && p.longitude != null) {
                                      _mapController.move(LatLng(p.latitude!, p.longitude!), 15);
                                  }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      p.address ?? 'No Address',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                    const Divider(),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('${p.matchedItems} matches', style: const TextStyle(color: Colors.green)),
                                        Text('\$${p.totalPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${(p.distance / 1000).toStringAsFixed(1)} km away',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
