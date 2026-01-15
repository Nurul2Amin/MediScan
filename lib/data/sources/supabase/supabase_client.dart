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
      return [];
    }
  }

  // Find best pharmacies using PostGIS RPC
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
      // Return empty list on error
      return [];
    }
  }
}
