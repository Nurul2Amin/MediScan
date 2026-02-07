import 'package:prescription_scanner/data/models/pharmacy_item.dart';
import 'package:prescription_scanner/data/models/cart_item.dart';
import 'package:prescription_scanner/data/sources/supabase/supabase_client.dart';

class PharmacyRepository {
  final AppSupabaseClient _supabaseClient;

  PharmacyRepository({required AppSupabaseClient supabaseClient})
      : _supabaseClient = supabaseClient;

  /// Find pharmacies (basic - just checks if they have the medicines)
  Future<List<Pharmacy>> findPharmacies({
    required double lat,
    required double long,
    required List<int> medicineIds,
    int radius = 5000,
  }) async {
    final data = await _supabaseClient.findBestPharmacies(
      userLat: lat,
      userLng: long,
      medicineIds: medicineIds,
      radius: radius,
    );
    
    return data.map((e) => Pharmacy.fromJson(e)).toList();
  }

  /// Find pharmacies WITH STOCK CHECK
  /// Converts customer's cart items to base units and checks stock availability
  /// Returns pharmacies sorted by: full stock first, then matched items, then price
  Future<List<Pharmacy>> findPharmaciesWithStock({
    required double lat,
    required double long,
    required List<CartItem> cartItems,
    int radius = 5000,
  }) async {
    // Convert cart items to format expected by RPC
    final cartItemsJson = cartItems.map((item) => {
      'medicine_id': item.medicine.id,
      'quantity': item.quantity,
      'unit_type': item.unit.name,
    }).toList();

    final data = await _supabaseClient.findPharmaciesWithStock(
      userLat: lat,
      userLng: long,
      cartItems: cartItemsJson,
      radius: radius,
    );
    
    return data.map((e) => Pharmacy.fromJson(e)).toList();
  }

  Future<Pharmacy?> getMyPharmacy(String userId) async {
    final data = await _supabaseClient.getPharmacyByOwnerId(userId);
    if (data == null) return null;
    return Pharmacy.fromJson(data);
  }
}
