import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prescription_scanner/data/models/medicine.dart';
import 'package:prescription_scanner/data/models/parsed_medicine.dart';
import 'package:prescription_scanner/data/models/pharmacy_item.dart';
import 'package:prescription_scanner/data/providers.dart';

class MedicineState {
  final bool isLoading;
  final String? error;
  final List<ParsedMedicine> extractedMedicines;
  final Map<ParsedMedicine, List<Medicine>> foundMedicines;
  final List<Pharmacy> availablePharmacies;

  MedicineState({
    this.isLoading = false,
    this.error,
    this.extractedMedicines = const [],
    this.foundMedicines = const {},
    this.availablePharmacies = const [],
  });

  MedicineState copyWith({
    bool? isLoading,
    String? error,
    List<ParsedMedicine>? extractedMedicines,
    Map<ParsedMedicine, List<Medicine>>? foundMedicines,
    List<Pharmacy>? availablePharmacies,
  }) {
    return MedicineState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      extractedMedicines: extractedMedicines ?? this.extractedMedicines,
      foundMedicines: foundMedicines ?? this.foundMedicines,
      availablePharmacies: availablePharmacies ?? this.availablePharmacies,
    );
  }
}

class MedicineStateNotifier extends Notifier<MedicineState> {
  @override
  MedicineState build() {
    return MedicineState();
  }

  Future<void> scanAndProcessPrescription(String imagePath) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final medicineRepo = ref.read(medicineRepositoryProvider);
      
      // 1. Extract
      final extracted = await medicineRepo.extractMedicines(imagePath);
      
      // 2. Find matches
      final found = await medicineRepo.findMatches(extracted);

      // 3. Find pharmacies
      // Logic moved to PharmacyFinderPage to use Location + RPC directly.
      // We no longer eager-fetch here without user location.
      final pharmacyList = <Pharmacy>[]; 

      state = state.copyWith(
        isLoading: false,
        extractedMedicines: extracted,
        foundMedicines: found,
        availablePharmacies: pharmacyList,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final medicineStateProvider = NotifierProvider<MedicineStateNotifier, MedicineState>(() {
  return MedicineStateNotifier();
});
