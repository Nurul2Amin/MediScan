import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prescription_scanner/data/sources/supabase/supabase_client.dart';
import 'package:prescription_scanner/data/sources/remote/gemini_service.dart';
import 'package:prescription_scanner/data/sources/remote/edge_function_gemini_service.dart';
import 'package:prescription_scanner/data/repositories/medicine_repository.dart';
import 'package:prescription_scanner/data/repositories/pharmacy_repository.dart';
import 'package:prescription_scanner/data/models/pharmacy_item.dart';
import 'package:prescription_scanner/data/repositories/inventory_repository.dart';
import 'package:prescription_scanner/data/repositories/order_repository.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) {
  throw UnimplementedError('SupabaseClient must be initialized in main');
});

final appSupabaseClientProvider = Provider<AppSupabaseClient>((ref) {
  return AppSupabaseClient(ref.watch(supabaseProvider));
});

final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});

final edgeFunctionGeminiServiceProvider = Provider<EdgeFunctionGeminiService>((ref) {
  return EdgeFunctionGeminiService(ref.watch(supabaseProvider));
});

final medicineRepositoryProvider = Provider<MedicineRepository>((ref) {
  return MedicineRepository(
    geminiService: ref.watch(edgeFunctionGeminiServiceProvider),
    supabaseClient: ref.watch(appSupabaseClientProvider),
  );
});

final pharmacyRepositoryProvider = Provider<PharmacyRepository>((ref) {
  return PharmacyRepository(
    supabaseClient: ref.watch(appSupabaseClientProvider),
  );
});

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(
    supabaseClient: ref.watch(appSupabaseClientProvider),
  );
});

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(ref.watch(supabaseProvider));
});

final myPharmacyProvider = FutureProvider<Pharmacy?>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final user = supabase.auth.currentUser;
  if (user == null) return null;
  
  final repo = ref.watch(pharmacyRepositoryProvider);
  return repo.getMyPharmacy(user.id);
});
