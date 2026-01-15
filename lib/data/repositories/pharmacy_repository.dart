import 'package:prescription_scanner/data/models/pharmacy_item.dart';
import 'package:prescription_scanner/data/sources/supabase/supabase_client.dart';

class PharmacyRepository {
  final AppSupabaseClient _supabaseClient;

  PharmacyRepository({required AppSupabaseClient supabaseClient})
      : _supabaseClient = supabaseClient;

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
    
    return data.map((e) {
      // Data from RPC is flat, but Pharmacy.fromJson handles the fields.
      // e['distance_m'] -> Pharmacy.distance
      return Pharmacy.fromJson(e);
    }).toList();
  }
}
