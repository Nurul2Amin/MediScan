import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prescription_scanner/data/models/medicine.dart';

// Notifier to manage the list of medicines to search for
class CartNotifier extends Notifier<List<Medicine>> {
  @override
  List<Medicine> build() {
    return [];
  }

  // Set items from OCR result (after validation/matching)
  void setItems(List<Medicine> items) {
    state = items;
  }

  void addItem(Medicine item) {
    if (!state.any((element) => element.id == item.id)) {
      state = [...state, item];
    }
  }

  void removeItem(int id) {
    state = state.where((element) => element.id != id).toList();
  }

  void clear() {
    state = [];
  }
}

final cartProvider = NotifierProvider<CartNotifier, List<Medicine>>(() {
  return CartNotifier();
});
