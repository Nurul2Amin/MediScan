import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prescription_scanner/data/sources/supabase/supabase_client.dart';
import 'package:prescription_scanner/data/sources/remote/gemini_service.dart';
import 'package:prescription_scanner/data/repositories/medicine_repository.dart';
import 'package:prescription_scanner/data/repositories/pharmacy_repository.dart';

// Supabase Instance Provider (To be overridden in main)
final supabaseProvider = Provider<SupabaseClient>((ref) {
  throw UnimplementedError('SupabaseClient must be initialized in main');
});

// Service Providers
final appSupabaseClientProvider = Provider<AppSupabaseClient>((ref) {
  return AppSupabaseClient(ref.watch(supabaseProvider));
});

final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});

// Repository Providers
final medicineRepositoryProvider = Provider<MedicineRepository>((ref) {
  return MedicineRepository(
    geminiService: ref.watch(geminiServiceProvider),
    supabaseClient: ref.watch(appSupabaseClientProvider),
  );
});

final pharmacyRepositoryProvider = Provider<PharmacyRepository>((ref) {
  return PharmacyRepository(
    supabaseClient: ref.watch(appSupabaseClientProvider),
  );
});
