import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:prescription_scanner/data/models/pharmacy_item.dart';
import 'package:prescription_scanner/data/models/cart_item.dart';
import 'package:prescription_scanner/data/providers.dart';
import 'package:prescription_scanner/presentation/providers/auth_provider.dart';
import 'package:prescription_scanner/presentation/providers/cart_provider.dart';
import 'package:prescription_scanner/presentation/pages/orders/place_order_page.dart';
import 'package:prescription_scanner/core/helpers/error_handler.dart';

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

      if (cartItems.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      // 3. Get user preferences
      final profile = ref.read(userProfileProvider).value;
      final defaultRadiusM = profile?.defaultRadiusM ?? 5000;
      final sortMode = profile?.sortMode ?? 'balanced';
      final requireFullMatch = profile?.requireFullMatch ?? false;
      final maxResults = profile?.maxResults ?? 20;

      // 4. Find Pharmacies WITH STOCK CHECK (converts cart units to base units)
      final repo = ref.read(pharmacyRepositoryProvider);
      final results = await repo.findPharmaciesWithStock(
        lat: _currentPosition!.latitude,
        long: _currentPosition!.longitude,
        cartItems: cartItems,
        radius: defaultRadiusM, 
      );

      // 5. Apply client-side filtering and sorting
      var filteredResults = results;
      
      // Filter: require_full_match (only pharmacies with sufficient stock for ALL items)
      if (requireFullMatch && cartItems.isNotEmpty) {
        filteredResults = results.where((p) => p.hasFullStock).toList();
      }

      // Sort based on user preference (but always prioritize pharmacies with full stock)
      switch (sortMode) {
        case 'nearest':
          filteredResults.sort((a, b) {
            // First by full stock, then by distance
            if (a.hasFullStock != b.hasFullStock) return a.hasFullStock ? -1 : 1;
            return a.distance.compareTo(b.distance);
          });
          break;
        case 'cheapest':
          filteredResults.sort((a, b) {
            if (a.hasFullStock != b.hasFullStock) return a.hasFullStock ? -1 : 1;
            return a.totalPrice.compareTo(b.totalPrice);
          });
          break;
        case 'most_matched':
          filteredResults.sort((a, b) {
            if (a.hasFullStock != b.hasFullStock) return a.hasFullStock ? -1 : 1;
            return b.matchedItems.compareTo(a.matchedItems);
          });
          break;
        case 'balanced':
        default:
          // Balanced: full stock first, then matched_items desc, then distance, then price
          filteredResults.sort((a, b) {
            if (a.hasFullStock != b.hasFullStock) return a.hasFullStock ? -1 : 1;
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppErrorHandler.getUserFriendlyMessage(e))));
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
    final cartItems = ref.read(cartProvider);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                
                // Pharmacy Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.local_pharmacy, color: Colors.green.shade700, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  p.address ?? "No address",
                                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Stats Row
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        icon: Icons.check_circle,
                        value: '${p.matchedItems}/${cartItems.length}',
                        label: 'Items',
                        color: p.matchedItems == cartItems.length ? Colors.green : Colors.orange,
                      ),
                      Container(width: 1, height: 40, color: Colors.grey[300]),
                      _buildStatItem(
                        icon: Icons.currency_exchange,
                        value: '৳${p.totalPrice.toStringAsFixed(2)}',
                        label: 'Total',
                        color: Colors.blue,
                      ),
                      Container(width: 1, height: 40, color: Colors.grey[300]),
                      _buildStatItem(
                        icon: Icons.directions_walk,
                        value: _formatDistance(p.distance),
                        label: 'Away',
                        color: Colors.purple,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openMapsDirections(p),
                        icon: const Icon(Icons.directions),
                        label: const Text('Directions'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (p.contactNumber != null && p.contactNumber!.isNotEmpty)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _callPharmacy(p.contactNumber!),
                          icon: const Icon(Icons.phone),
                          label: const Text('Call'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Place Order Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // Close bottom sheet
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlaceOrderPage(
                            pharmacy: p,
                            cartItems: cartItems,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.shopping_cart_checkout),
                    label: const Text('Place Order'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Matched Medicines Section
                const Text(
                  'Available Medicines',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                
                // Medicine List
                ...cartItems.map((cartItem) {
                  final medicine = cartItem.medicine;
                  // Get pharmacy-specific item details (price, stock, config)
                  final itemDetail = p.getItemDetail(medicine.id);
                  final isMatched = itemDetail != null;
                  final hasStock = itemDetail?.hasStock ?? false;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: hasStock ? Colors.green.shade50 : (isMatched ? Colors.orange.shade50 : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: hasStock ? Colors.green.shade200 : (isMatched ? Colors.orange.shade200 : Colors.grey.shade300),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          hasStock ? Icons.check_circle : (isMatched ? Icons.warning_amber : Icons.help_outline),
                          color: hasStock ? Colors.green : (isMatched ? Colors.orange : Colors.grey),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                medicine.name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              if (medicine.form != null || medicine.strength != null)
                                Text(
                                  '${medicine.form ?? ''} ${medicine.strength ?? ''}'.trim(),
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              // Show quantity with pharmacy's actual config
                              if (itemDetail != null)
                                Text(
                                  '${cartItem.quantity} ${cartItem.unit.displayName}${cartItem.quantity > 1 ? 's' : ''} (${itemDetail.requiredBaseUnits} pcs)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                )
                              else
                                Text(
                                  cartItem.quantityDisplay,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Show pharmacy-specific price
                        if (itemDetail != null)
                          Text(
                            '৳${itemDetail.itemTotalPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          )
                        else if (cartItem.totalPrice != null)
                          Text(
                            '৳${cartItem.totalPrice!.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[400],
                            ),
                          ),
                      ],
                    ),
                  );
                }),
                
                const SizedBox(height: 20),
                
                // Contact Info (if available)
                if (p.contactNumber != null && p.contactNumber!.isNotEmpty) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.phone_outlined, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(p.contactNumber!, style: TextStyle(color: Colors.grey[700])),
                    ],
                  ),
                ],
                
                if (p.openingHours != null && p.openingHours!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(p.openingHours!, style: TextStyle(color: Colors.grey[700])),
                    ],
                  ),
                ],
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  String _formatDistance(double meters) {
    if (meters < 100) {
      return '< 100m';
    } else if (meters < 1000) {
      return '${meters.round()}m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
  }

  Future<void> _openMapsDirections(Pharmacy pharmacy) async {
    if (pharmacy.latitude == null || pharmacy.longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pharmacy location not available')),
      );
      return;
    }

    final lat = pharmacy.latitude!;
    final lng = pharmacy.longitude!;
    final label = Uri.encodeComponent(pharmacy.name);

    Uri uri;
    if (Platform.isIOS) {
      // Apple Maps
      uri = Uri.parse('https://maps.apple.com/?daddr=$lat,$lng&dirflg=d');
    } else {
      // Google Maps (works on Android and fallback)
      uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=$label');
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback to web Google Maps
      final webUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callPharmacy(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch phone dialer')),
        );
      }
    }
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
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _showPharmacyDetails(p),
                              onLongPress: () {
                                  if (p.latitude != null && p.longitude != null) {
                                      _mapController.move(LatLng(p.latitude!, p.longitude!), 15);
                                  }
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(Icons.local_pharmacy, color: Colors.green.shade700, size: 20),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            p.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        // Stock availability indicator
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: p.hasFullStock 
                                              ? Colors.green.shade100 
                                              : Colors.orange.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                p.hasFullStock 
                                                  ? Icons.check_circle 
                                                  : Icons.warning_amber_rounded,
                                                size: 12,
                                                color: p.hasFullStock 
                                                  ? Colors.green.shade700 
                                                  : Colors.orange.shade700,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                p.hasFullStock ? 'In Stock' : 'Partial',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: p.hasFullStock 
                                                    ? Colors.green.shade700 
                                                    : Colors.orange.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            p.address ?? 'No Address',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    const Divider(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade100,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '${p.matchedItems} matches',
                                            style: TextStyle(color: Colors.green.shade800, fontSize: 12, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        Text(
                                          '৳${p.totalPrice.toStringAsFixed(2)}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(Icons.directions_walk, size: 14, color: Colors.grey[500]),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatDistance(p.distance),
                                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                        ),
                                        const Spacer(),
                                        Text(
                                          'Tap for details',
                                          style: TextStyle(fontSize: 11, color: Colors.blue.shade400),
                                        ),
                                      ],
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
