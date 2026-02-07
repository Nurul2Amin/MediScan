import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppSupabaseClient {
  final SupabaseClient supabase;

  AppSupabaseClient(this.supabase);

  // Fetch medicines from the database based on extracted names (fuzzy match)
  Future<List<Map<String, dynamic>>> getMedicines(List<String> medicineNames) async {
    // Note: This needs improvement for real fuzzy match (pg_trgm) via RPC ideally.
    // For now, simple exact match 'in'.
    try {
      // Build filter string for OR query: check both 'name' and 'generic_name'
      final namesList = medicineNames.map((e) => '"$e"').join(',');
      final response = await supabase
          .from('medicines')
          .select()
          .or('name.in.($namesList),generic_name.in.($namesList)');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  }

  // Find best pharmacies using PostGIS RPC (basic - just medicine IDs)
  Future<List<Map<String, dynamic>>> findBestPharmacies({
    required double userLat,
    required double userLng,
    required List<int> medicineIds,
    int radius = 5000,
  }) async {
    try {
      final response = await supabase.rpc(
        'find_best_pharmacies',
        params: {
          'user_lat': userLat,
          'user_lng': userLng,
          'medicine_ids': medicineIds,
          'radius_m': radius,
        },
      );
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Find pharmacies with STOCK AVAILABILITY check
  /// This converts customer's cart items (with quantity/unit) to base units
  /// and only returns pharmacies that have sufficient stock
  /// Now includes per-item pricing details from each pharmacy
  Future<List<Map<String, dynamic>>> findPharmaciesWithStock({
    required double userLat,
    required double userLng,
    required List<Map<String, dynamic>> cartItems, // [{medicine_id, quantity, unit_type}]
    int radius = 5000,
  }) async {
    try {
      final response = await supabase.rpc(
        'find_pharmacies_with_stock_details',
        params: {
          'user_lat': userLat,
          'user_lng': userLng,
          'cart_items': cartItems,
          'radius_m': radius,
        },
      );
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      // Fallback to old function if new one doesn't exist yet
      try {
        final response = await supabase.rpc(
          'find_pharmacies_with_stock',
          params: {
            'user_lat': userLat,
            'user_lng': userLng,
            'cart_items': cartItems,
            'radius_m': radius,
          },
        );
        return List<Map<String, dynamic>>.from(response);
      } catch (_) {
        rethrow;
      }
    }
  }

  // Get pharmacy by owner_id (returns most recent if multiple exist)
  Future<Map<String, dynamic>?> getPharmacyByOwnerId(String ownerId) async {
    try {
      final response = await supabase
          .from('pharmacies')
          .select()
          .eq('owner_id', ownerId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle(); // Get most recent pharmacy
      return response;
    } catch (e) {
      debugPrint('Error fetching pharmacy: $e');
      return null;
    }
  }
}
