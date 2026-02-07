import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prescription_scanner/data/models/medicine.dart';
import 'package:prescription_scanner/data/models/cart_item.dart';

// Notifier to manage the cart with quantity and unit support
class CartNotifier extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() {
    return [];
  }

  // Set items from OCR result (after validation/matching)
  void setItems(List<CartItem> items) {
    state = items;
  }

  // Add item with default quantity and unit
  void addItem(Medicine medicine, {int quantity = 1, MedicineUnit? unit}) {
    if (!state.any((element) => element.medicine.id == medicine.id)) {
      final defaultUnit = unit ?? CartItem.getDefaultUnit(medicine.form);
      state = [...state, CartItem(
        medicine: medicine,
        quantity: quantity,
        unit: defaultUnit,
      )];
    }
  }

  // Update quantity for an existing item
  void updateQuantity(int medicineId, int quantity) {
    if (quantity <= 0) {
      removeItem(medicineId);
      return;
    }
    
    state = state.map((item) {
      if (item.medicine.id == medicineId) {
        return item.copyWith(quantity: quantity);
      }
      return item;
    }).toList();
  }

  // Update unit type for an existing item
  void updateUnit(int medicineId, MedicineUnit unit) {
    state = state.map((item) {
      if (item.medicine.id == medicineId) {
        return item.copyWith(unit: unit);
      }
      return item;
    }).toList();
  }

  // Increment quantity
  void incrementQuantity(int medicineId) {
    final item = state.firstWhere(
      (i) => i.medicine.id == medicineId,
      orElse: () => throw Exception('Item not found'),
    );
    updateQuantity(medicineId, item.quantity + 1);
  }

  // Decrement quantity
  void decrementQuantity(int medicineId) {
    final item = state.firstWhere(
      (i) => i.medicine.id == medicineId,
      orElse: () => throw Exception('Item not found'),
    );
    if (item.quantity > 1) {
      updateQuantity(medicineId, item.quantity - 1);
    }
  }

  void removeItem(int id) {
    state = state.where((element) => element.medicine.id != id).toList();
  }

  void clear() {
    state = [];
  }

  // Get total item count
  int get totalItems => state.fold(0, (sum, item) => sum + item.quantity);
}

final cartProvider = NotifierProvider<CartNotifier, List<CartItem>>(() {
  return CartNotifier();
});
