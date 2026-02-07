import 'package:prescription_scanner/data/models/medicine.dart';

/// Order status enum
enum OrderStatus {
  pending,
  confirmed,
  ready,
  completed,
  cancelled;

  static OrderStatus fromString(String status) {
    return OrderStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => OrderStatus.pending,
    );
  }

  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.ready:
        return 'Ready for Pickup';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get description {
    switch (this) {
      case OrderStatus.pending:
        return 'Waiting for pharmacy confirmation';
      case OrderStatus.confirmed:
        return 'Pharmacy is preparing your order';
      case OrderStatus.ready:
        return 'Your order is ready for pickup';
      case OrderStatus.completed:
        return 'Order completed';
      case OrderStatus.cancelled:
        return 'Order was cancelled';
    }
  }
}

/// Order item model
class OrderItem {
  final int id;
  final int orderId;
  final int medicineId;
  final String medicineName;
  final String? medicineForm;
  final String? medicineStrength;
  final int quantity;
  final String unitType; // piece, strip, box, bottle, tube, etc.
  final double unitPrice;
  final double subtotal;
  final DateTime createdAt;

  OrderItem({
    required this.id,
    required this.orderId,
    required this.medicineId,
    required this.medicineName,
    this.medicineForm,
    this.medicineStrength,
    required this.quantity,
    this.unitType = 'strip',
    required this.unitPrice,
    required this.subtotal,
    required this.createdAt,
  });

  /// Get display string for unit type
  String get unitDisplayName {
    switch (unitType) {
      case 'piece': return 'Pc';
      case 'strip': return 'Strip';
      case 'box': return 'Box';
      case 'bottle': return 'Bottle';
      case 'tube': return 'Tube';
      case 'vial': return 'Vial';
      case 'sachet': return 'Sachet';
      case 'pack': return 'Pack';
      default: return unitType;
    }
  }

  /// Get quantity with unit display
  String get quantityDisplay => '$quantity ${unitDisplayName}${quantity > 1 ? "s" : ""}';

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['item_id'] as int,
      orderId: json['order_id'] as int,
      medicineId: json['medicine_id'] as int,
      medicineName: json['medicine_name'] as String,
      medicineForm: json['medicine_form'] as String?,
      medicineStrength: json['medicine_strength'] as String?,
      quantity: json['quantity'] as int,
      unitType: json['unit_type'] as String? ?? 'strip',
      unitPrice: (json['unit_price'] as num).toDouble(),
      subtotal: (json['subtotal'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'medicine_id': medicineId,
      'medicine_name': medicineName,
      'medicine_form': medicineForm,
      'medicine_strength': medicineStrength,
      'quantity': quantity,
      'unit_price': unitPrice,
    };
  }

  /// Create OrderItem from a Medicine (for placing new orders)
  factory OrderItem.fromMedicine(Medicine medicine, {int quantity = 1}) {
    return OrderItem(
      id: 0, // Will be set by database
      orderId: 0, // Will be set when order is created
      medicineId: medicine.id,
      medicineName: medicine.name,
      medicineForm: medicine.form,
      medicineStrength: medicine.strength,
      quantity: quantity,
      unitPrice: medicine.price ?? 0,
      subtotal: (medicine.price ?? 0) * quantity,
      createdAt: DateTime.now(),
    );
  }
}

/// Main Order model
class Order {
  final int id;
  final String customerId;
  final int pharmacyId;
  final OrderStatus status;
  final double totalAmount;
  final int itemCount;
  final String? customerName;
  final String? customerPhone;
  final String? customerNotes;
  final String? pharmacyNotes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? confirmedAt;
  final DateTime? readyAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  
  // Joined data (optional)
  final String? pharmacyName;
  final String? pharmacyAddress;
  final String? pharmacyPhone;
  final List<OrderItem>? items;

  Order({
    required this.id,
    required this.customerId,
    required this.pharmacyId,
    required this.status,
    required this.totalAmount,
    required this.itemCount,
    this.customerName,
    this.customerPhone,
    this.customerNotes,
    this.pharmacyNotes,
    required this.createdAt,
    required this.updatedAt,
    this.confirmedAt,
    this.readyAt,
    this.completedAt,
    this.cancelledAt,
    this.pharmacyName,
    this.pharmacyAddress,
    this.pharmacyPhone,
    this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    // Handle joined pharmacy data
    final pharmacy = json['pharmacies'] as Map<String, dynamic>?;
    
    // Handle order items
    List<OrderItem>? items;
    if (json['order_items'] != null) {
      items = (json['order_items'] as List)
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return Order(
      id: json['order_id'] as int,
      customerId: json['customer_id'] as String,
      pharmacyId: json['pharmacy_id'] as int,
      status: OrderStatus.fromString(json['status'] as String),
      totalAmount: (json['total_amount'] as num).toDouble(),
      itemCount: json['item_count'] as int,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      customerNotes: json['customer_notes'] as String?,
      pharmacyNotes: json['pharmacy_notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      confirmedAt: json['confirmed_at'] != null 
          ? DateTime.parse(json['confirmed_at'] as String) : null,
      readyAt: json['ready_at'] != null 
          ? DateTime.parse(json['ready_at'] as String) : null,
      completedAt: json['completed_at'] != null 
          ? DateTime.parse(json['completed_at'] as String) : null,
      cancelledAt: json['cancelled_at'] != null 
          ? DateTime.parse(json['cancelled_at'] as String) : null,
      pharmacyName: pharmacy?['name'] as String?,
      pharmacyAddress: pharmacy?['address'] as String?,
      pharmacyPhone: pharmacy?['contact_number'] as String?,
      items: items,
    );
  }

  /// Check if order can be cancelled (only pending orders)
  bool get canCancel => status == OrderStatus.pending;

  /// Check if order is active (not completed or cancelled)
  bool get isActive => 
      status != OrderStatus.completed && status != OrderStatus.cancelled;

  /// Get formatted order number
  String get orderNumber => '#${id.toString().padLeft(4, '0')}';

  /// Get time since order was created
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }
}
