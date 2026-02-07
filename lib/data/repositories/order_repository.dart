import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prescription_scanner/data/models/order.dart';
import 'package:prescription_scanner/data/models/cart_item.dart';

class OrderRepository {
  final SupabaseClient _client;

  OrderRepository(this._client);

  /// Place a new order
  Future<Order> placeOrder({
    required int pharmacyId,
    required List<CartItem> cartItems,
    String? customerName,
    String? customerPhone,
    String? customerNotes,
  }) async {
    // Convert cart items to order items JSON with quantity and unit
    final itemsJson = cartItems.map((cartItem) => {
      'medicine_id': cartItem.medicine.id,
      'medicine_name': cartItem.medicine.name,
      'medicine_form': cartItem.medicine.form,
      'medicine_strength': cartItem.medicine.strength,
      'unit_price': cartItem.medicine.price ?? 0,
      'quantity': cartItem.quantity,
      'unit_type': cartItem.unit.name, // Store unit type
    }).toList();

    final response = await _client.rpc('place_order', params: {
      'p_pharmacy_id': pharmacyId,
      'p_items': itemsJson,
      'p_customer_name': customerName,
      'p_customer_phone': customerPhone,
      'p_customer_notes': customerNotes,
    });

    if (response['success'] != true) {
      throw Exception(response['error'] ?? 'Failed to place order');
    }

    // Fetch the created order with full details
    final orderId = response['order_id'] as int;
    return await getOrderById(orderId);
  }

  /// Get order by ID with pharmacy info and items
  Future<Order> getOrderById(int orderId) async {
    final response = await _client
        .from('orders')
        .select('''
          *,
          pharmacies (name, address, contact_number),
          order_items (*)
        ''')
        .eq('order_id', orderId)
        .single();

    return Order.fromJson(response);
  }

  /// Get customer's orders (for customer view)
  Future<List<Order>> getCustomerOrders({
    OrderStatus? status,
    int limit = 20,
    int offset = 0,
  }) async {
    var query = _client
        .from('orders')
        .select('''
          *,
          pharmacies (name, address, contact_number)
        ''')
        .eq('customer_id', _client.auth.currentUser!.id);

    if (status != null) {
      query = query.eq('status', status.name);
    }

    final response = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    
    return (response as List).map((e) => Order.fromJson(e)).toList();
  }

  /// Get pharmacy's orders (for owner view)
  Future<List<Order>> getPharmacyOrders({
    required int pharmacyId,
    OrderStatus? status,
    bool activeOnly = false,
    int limit = 50,
    int offset = 0,
  }) async {
    var query = _client
        .from('orders')
        .select('''
          *,
          order_items (*)
        ''')
        .eq('pharmacy_id', pharmacyId);

    if (status != null) {
      query = query.eq('status', status.name);
    }

    if (activeOnly) {
      // Filter out completed and cancelled orders
      query = query.inFilter('status', ['pending', 'confirmed', 'ready']);
    }

    final response = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    
    return (response as List).map((e) => Order.fromJson(e)).toList();
  }

  /// Update order status (for pharmacy owner)
  Future<void> updateOrderStatus({
    required int orderId,
    required OrderStatus status,
    String? pharmacyNotes,
  }) async {
    final response = await _client.rpc('update_order_status', params: {
      'p_order_id': orderId,
      'p_status': status.name,
      'p_pharmacy_notes': pharmacyNotes,
    });

    if (response['success'] != true) {
      throw Exception(response['error'] ?? 'Failed to update order status');
    }
  }

  /// Get count of pending orders for pharmacy (for badge/notification)
  Future<int> getPendingOrderCount(int pharmacyId) async {
    final response = await _client
        .from('orders')
        .select('order_id')
        .eq('pharmacy_id', pharmacyId)
        .eq('status', 'pending');

    return (response as List).length;
  }

  /// Get count of active orders for customer
  Future<int> getActiveOrderCount() async {
    final response = await _client
        .from('orders')
        .select('order_id')
        .eq('customer_id', _client.auth.currentUser!.id)
        .not('status', 'in', '(completed,cancelled)');

    return (response as List).length;
  }
}
