import 'package:prescription_scanner/data/models/medicine.dart';

/// Unit types for medicines
enum MedicineUnit {
  piece,   // Individual tablets/pills/capsules
  strip,   // Strip/leaflet (usually 10 tablets)
  box,     // Full box (multiple strips)
  bottle,  // For syrups/liquids
  tube,    // For creams/ointments
  vial,    // For injections
  sachet,  // For powders/granules
  pack;    // Generic pack

  String get displayName {
    switch (this) {
      case MedicineUnit.piece:
        return 'Pcs';
      case MedicineUnit.strip:
        return 'Strip';
      case MedicineUnit.box:
        return 'Box';
      case MedicineUnit.bottle:
        return 'Bottle';
      case MedicineUnit.tube:
        return 'Tube';
      case MedicineUnit.vial:
        return 'Vial';
      case MedicineUnit.sachet:
        return 'Sachet';
      case MedicineUnit.pack:
        return 'Pack';
    }
  }

  String get fullName {
    switch (this) {
      case MedicineUnit.piece:
        return 'Pieces (Tablets/Pills)';
      case MedicineUnit.strip:
        return 'Strip/Leaflet';
      case MedicineUnit.box:
        return 'Box';
      case MedicineUnit.bottle:
        return 'Bottle';
      case MedicineUnit.tube:
        return 'Tube';
      case MedicineUnit.vial:
        return 'Vial';
      case MedicineUnit.sachet:
        return 'Sachet';
      case MedicineUnit.pack:
        return 'Pack';
    }
  }

  /// Get appropriate units based on medicine form
  static List<MedicineUnit> getUnitsForForm(String? form) {
    if (form == null) return [MedicineUnit.piece, MedicineUnit.strip, MedicineUnit.box];
    
    final lowerForm = form.toLowerCase();
    
    if (lowerForm.contains('tablet') || lowerForm.contains('cap') || 
        lowerForm.contains('pill') || lowerForm.contains('tab')) {
      return [MedicineUnit.piece, MedicineUnit.strip, MedicineUnit.box];
    }
    
    if (lowerForm.contains('syrup') || lowerForm.contains('suspension') || 
        lowerForm.contains('liquid') || lowerForm.contains('solution') ||
        lowerForm.contains('drop')) {
      return [MedicineUnit.bottle];
    }
    
    if (lowerForm.contains('cream') || lowerForm.contains('ointment') || 
        lowerForm.contains('gel')) {
      return [MedicineUnit.tube];
    }
    
    if (lowerForm.contains('injection') || lowerForm.contains('inj') ||
        lowerForm.contains('iv') || lowerForm.contains('im')) {
      return [MedicineUnit.vial, MedicineUnit.box];
    }
    
    if (lowerForm.contains('powder') || lowerForm.contains('granule') ||
        lowerForm.contains('sachet')) {
      return [MedicineUnit.sachet, MedicineUnit.box];
    }
    
    // Default
    return [MedicineUnit.piece, MedicineUnit.strip, MedicineUnit.box, MedicineUnit.pack];
  }
}

/// Cart item with quantity and unit
class CartItem {
  final Medicine medicine;
  final int quantity;
  final MedicineUnit unit;
  
  // Packaging configuration (defaults, can be overridden by pharmacy)
  final int pillsPerStrip;
  final int stripsPerBox;

  CartItem({
    required this.medicine,
    this.quantity = 1,
    this.unit = MedicineUnit.strip,
    this.pillsPerStrip = 10,  // Default: 10 pills per strip
    this.stripsPerBox = 3,    // Default: 3 strips per box
  });

  /// Create a copy with updated values
  CartItem copyWith({
    Medicine? medicine,
    int? quantity,
    MedicineUnit? unit,
    int? pillsPerStrip,
    int? stripsPerBox,
  }) {
    return CartItem(
      medicine: medicine ?? this.medicine,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      pillsPerStrip: pillsPerStrip ?? this.pillsPerStrip,
      stripsPerBox: stripsPerBox ?? this.stripsPerBox,
    );
  }

  /// Get base units (pills/pieces) count
  int get baseUnitsCount {
    switch (unit) {
      case MedicineUnit.piece:
        return quantity;
      case MedicineUnit.strip:
        return quantity * pillsPerStrip;
      case MedicineUnit.box:
        return quantity * pillsPerStrip * stripsPerBox;
      default:
        return quantity; // For bottles, tubes, vials - 1:1
    }
  }

  /// Get display string for quantity with base units
  String get quantityDisplay {
    final unitLabel = '$quantity ${unit.displayName}${quantity > 1 ? 's' : ''}';
    
    // Add base unit breakdown for strips and boxes
    if (unit == MedicineUnit.strip && pillsPerStrip > 1) {
      return '$unitLabel ($baseUnitsCount pcs)';
    } else if (unit == MedicineUnit.box && pillsPerStrip > 1) {
      final totalStrips = quantity * stripsPerBox;
      return '$unitLabel ($totalStrips strips / $baseUnitsCount pcs)';
    }
    
    return unitLabel;
  }

  /// Get unit multiplier for price calculation
  int get unitMultiplier {
    switch (unit) {
      case MedicineUnit.piece:
        return 1;
      case MedicineUnit.strip:
        return pillsPerStrip;
      case MedicineUnit.box:
        return pillsPerStrip * stripsPerBox;
      default:
        return 1;
    }
  }

  /// Get total price based on unit type (price is per base unit/pill)
  double? get totalPrice {
    if (medicine.price == null) return null;
    return medicine.price! * quantity * unitMultiplier;
  }
  
  /// Get price per selected unit
  double? get pricePerUnit {
    if (medicine.price == null) return null;
    return medicine.price! * unitMultiplier;
  }

  /// Get default unit based on medicine form
  static MedicineUnit getDefaultUnit(String? form) {
    final units = MedicineUnit.getUnitsForForm(form);
    return units.isNotEmpty ? units.first : MedicineUnit.strip;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CartItem && other.medicine.id == medicine.id;
  }

  @override
  int get hashCode => medicine.id.hashCode;
}
