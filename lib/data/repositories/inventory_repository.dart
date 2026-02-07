import 'package:prescription_scanner/data/models/inventory_batch.dart';
import 'package:prescription_scanner/data/models/inventory_summary.dart';
import 'package:prescription_scanner/data/models/unit_conversion.dart';
import 'package:prescription_scanner/data/sources/supabase/supabase_client.dart';

class InventoryRepository {
  final AppSupabaseClient _supabaseClient;

  InventoryRepository({required AppSupabaseClient supabaseClient})
      : _supabaseClient = supabaseClient;

  /// Get inventory summary for a pharmacy
  Future<List<InventorySummary>> getInventorySummary(int pharmacyId) async {
    try {
      final response = await _supabaseClient.supabase
          .from('v_pharmacy_inventory_summary')
          .select()
          .eq('pharmacy_id', pharmacyId)
          .order('medicine_name');

      return (response as List)
          .map((e) => InventorySummary.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get batches for a pharmacy medicine
  Future<List<InventoryBatch>> getBatches(int pharmacyMedicineId) async {
    try {
      final response = await _supabaseClient.supabase
          .from('pharmacy_medicine_batches')
          .select()
          .eq('pharmacy_medicine_id', pharmacyMedicineId)
          .order('expiry_date', ascending: true);

      return (response as List)
          .map((e) => InventoryBatch.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // Re-throw to surface the actual error instead of hiding it
      rethrow;
    }
  }

  /// Stock in: Add inventory
  Future<int> stockIn({
    required int pharmacyMedicineId,
    required int qtyBaseUnits,
    required DateTime expiryDate,
    String? batchNo,
    double? buyPrice,
    String? notes,
  }) async {
    try {
      final response = await _supabaseClient.supabase.rpc(
        'inventory_stock_in',
        params: {
          'p_pharmacy_medicine_id': pharmacyMedicineId,
          'p_qty_base_units': qtyBaseUnits,
          'p_expiry_date': expiryDate.toIso8601String().split('T')[0],
          'p_batch_no': batchNo,
          'p_buy_price': buyPrice,
          'p_note': notes,
        },
      );

      return response as int;
    } catch (e) {
      rethrow;
    }
  }

  /// Stock out: Remove inventory (FEFO)
  Future<List<dynamic>> stockOut({
    required int pharmacyMedicineId,
    required int qtyBaseUnits,
    int? preferredBatchId,
    bool useActiveBatch = true,
    String? notes,
  }) async {
    try {
      final response = await _supabaseClient.supabase.rpc(
        'inventory_stock_out',
        params: {
          'p_pharmacy_medicine_id': pharmacyMedicineId,
          'p_qty_base_units': qtyBaseUnits,
          'p_preferred_batch_id': preferredBatchId,
          'p_use_active_batch': useActiveBatch,
          'p_note': notes,
        },
      );

      return response as List<dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  /// Move inventory between batches
  Future<void> moveBetweenBatches({
    required int fromBatchId,
    required int toBatchId,
    required int qty,
  }) async {
    try {
      await _supabaseClient.supabase.rpc(
        'inventory_move_between_batches',
        params: {
          'from_batch_id': fromBatchId,
          'to_batch_id': toBatchId,
          'qty': qty,
        },
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Set active batch for a pharmacy medicine
  Future<void> setActiveBatch(int pharmacyMedicineId, int? batchId) async {
    try {
      await _supabaseClient.supabase
          .from('pharmacy_medicines')
          .update({'active_batch_id': batchId})
          .eq('id', pharmacyMedicineId);
    } catch (e) {
      rethrow;
    }
  }

  /// Update reorder level
  Future<void> updateReorderLevel(int pharmacyMedicineId, int reorderLevel) async {
    try {
      await _supabaseClient.supabase
          .from('pharmacy_medicines')
          .update({'reorder_level': reorderLevel})
          .eq('id', pharmacyMedicineId);
    } catch (e) {
      rethrow;
    }
  }

  /// Get unit conversions for a pharmacy medicine
  Future<List<UnitConversion>> getUnitConversions(int pharmacyMedicineId) async {
    try {
      final response = await _supabaseClient.supabase
          .from('pharmacy_unit_conversions')
          .select()
          .eq('pharmacy_medicine_id', pharmacyMedicineId)
          .order('multiplier_to_base');

      return (response as List)
          .map((e) => UnitConversion.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Create or update unit conversion
  Future<void> upsertUnitConversion({
    required int pharmacyMedicineId,
    required String unitLabel,
    required double multiplierToBase,
    bool isDefault = false,
  }) async {
    try {
      await _supabaseClient.supabase
          .from('pharmacy_unit_conversions')
          .upsert({
            'pharmacy_medicine_id': pharmacyMedicineId,
            'unit_label': unitLabel,
            'multiplier_to_base': multiplierToBase,
            'is_default': isDefault,
          });
    } catch (e) {
      rethrow;
    }
  }

  /// Get expiring batches for a pharmacy
  Future<List<Map<String, dynamic>>> getExpiringBatches(
    int pharmacyId, {
    int daysUntilExpiry = 30,
  }) async {
    try {
      final response = await _supabaseClient.supabase
          .from('v_pharmacy_expiring_batches')
          .select()
          .eq('pharmacy_id', pharmacyId)
          .lte('days_until_expiry', daysUntilExpiry)
          .gte('days_until_expiry', 0)
          .order('days_until_expiry');

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      rethrow;
    }
  }

  /// Get expired batches for a pharmacy
  Future<List<Map<String, dynamic>>> getExpiredBatches(int pharmacyId) async {
    try {
      final response = await _supabaseClient.supabase
          .from('v_pharmacy_expiring_batches')
          .select()
          .eq('pharmacy_id', pharmacyId)
          .lt('days_until_expiry', 0)
          .order('days_until_expiry');

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      rethrow;
    }
  }
}
