import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prescription_scanner/data/models/pharmacy_item.dart';
import 'package:prescription_scanner/presentation/providers/auth_provider.dart';
import 'package:prescription_scanner/data/providers.dart';

// Fetches the pharmacy owned by the logged-in user
final myPharmacyProvider = FutureProvider<Pharmacy?>((ref) async {
  final user = ref.watch(userProvider);
  final supabase = ref.watch(supabaseProvider);

  if (user == null) return null;

  try {
    final response = await supabase
        .from('pharmacies')
        .select()
        .eq('owner_id', user.id)
        .maybeSingle(); // Returns null if no pharmacy found

    if (response == null) return null;
    return Pharmacy.fromJson(response);
  } catch (e) {
    // Handle error or return null
    return null;
  }
});
