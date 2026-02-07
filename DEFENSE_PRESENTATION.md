# MediScan - Defense Presentation Guide

## 🎯 Project Overview

**MediScan** is a Flutter-based mobile application that bridges the gap between patients with prescriptions and pharmacies with available medicines using AI-powered prescription scanning and geolocation services.

### Tech Stack
| Component | Technology |
|-----------|------------|
| Frontend | Flutter (Dart) |
| State Management | Riverpod |
| Backend | Supabase (PostgreSQL + PostGIS) |
| AI Processing | Google Gemini via Edge Functions |
| Maps | flutter_map + OpenStreetMap |
| Authentication | Supabase Auth |

---

## 🔄 DEMO WORKFLOW

### **PART 1: Customer Journey**

---

### 1️⃣ App Initialization & Authentication

**Demo:** Launch app → Show login/signup screen

```dart
// main.dart - App Entry Point
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase backend
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  runApp(
    ProviderScope(
      overrides: [
        supabaseProvider.overrideWithValue(Supabase.instance.client),
      ],
      child: const PrescriptionScannerApp(),
    ),
  );
}
```

**Key Points:**
- Supabase handles authentication (email/password)
- ProviderScope enables Riverpod state management throughout app
- User roles: `customer` or `pharmacy_owner`

---

### 2️⃣ Home Page - Dashboard

**Demo:** Show home page with greeting, scan button, recent orders

```dart
// home_page.dart - Customer Dashboard
class HomePage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider).value;
    final cartItemCount = ref.watch(cartProvider).length;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            // Personalized greeting
            child: Text('Hello, ${user?.fullName ?? "User"}'),
          ),
          // Quick action cards
          // Recent orders widget
          // Scan prescription FAB
        ],
      ),
    );
  }
}
```

---

### 3️⃣ Prescription Scanning (Core Feature)

**Demo:** Take photo of prescription → Show loading → See extracted medicines

```dart
// scan_page.dart - Image Capture
class _ScanPageState extends ConsumerState<ScanPage> {
  String? _imagePath;

  Future<void> _pickImage(bool fromCamera) async {
    if (fromCamera) {
      final hasPermission = await PermissionHelper.requestCameraPermission();
      if (!hasPermission) return;
    }

    final path = fromCamera
        ? await ImagePickerHelper.pickImageFromCamera()
        : await ImagePickerHelper.pickImageFromGallery();

    if (path != null) {
      setState(() => _imagePath = path);
    }
  }

  Future<void> _processImage() async {
    // Trigger AI extraction via Riverpod
    await ref.read(medicineStateProvider.notifier)
        .scanAndProcessPrescription(_imagePath!);
    
    // Navigate to results
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => const ResultsPage()
    ));
  }
}
```

---

### 4️⃣ AI Medicine Extraction (Gemini Integration)

**Demo:** Explain how AI processes the prescription image

```dart
// edge_function_gemini_service.dart - AI Service
class EdgeFunctionGeminiService {
  final SupabaseClient _supabase;

  Future<Map<String, dynamic>> extractMedicines(String imagePath) async {
    // 1. Read image and convert to base64
    final file = File(imagePath);
    final bytes = await file.readAsBytes();
    final base64Image = base64Encode(bytes);
    
    // 2. Determine MIME type
    final mimeType = imagePath.endsWith('.png') 
        ? 'image/png' : 'image/jpeg';

    // 3. Call Supabase Edge Function (server-side Gemini)
    final response = await _supabase.functions.invoke(
      'ai_extract_medicines',
      body: {
        'image_base64': base64Image,
        'mime_type': mimeType,
      },
    );

    return response.data; // {medicines: [...]}
  }
}
```

**Why Edge Functions?**
- API key stays secure on server
- Lower latency (Deno runtime)
- Scales automatically

---

### 5️⃣ Medicine Matching Algorithm

**Demo:** Show how extracted text matches database entries

```dart
// medicine_repository.dart - Smart Matching
Future<Map<ParsedMedicine, List<Medicine>>> findMatches(
  List<ParsedMedicine> extracted
) async {
  final Map<ParsedMedicine, List<Medicine>> results = {};

  for (var item in extracted) {
    // Step 1: Try BRAND NAME match first
    var brandMatches = candidates.where((c) {
      return c.name.toLowerCase().contains(item.name.toLowerCase());
    }).toList();

    List<Medicine> finalMatches;

    if (brandMatches.isNotEmpty) {
      // Brand found (e.g., "Napa" → finds "Napa", "Napa Extra")
      finalMatches = brandMatches;
    } else {
      // Step 2: Fallback to GENERIC NAME
      finalMatches = candidates.where((c) {
        return item.genericName != null && 
               c.genericName?.toLowerCase() == item.genericName!.toLowerCase();
      }).toList();
    }

    // Step 3: Filter by FORM (tablet, syrup, etc.)
    if (item.form != null) {
      final formMatches = finalMatches.where((c) => 
          _isFormMatch(c.form, item.form!)).toList();
      if (formMatches.isNotEmpty) finalMatches = formMatches;
    }

    // Step 4: Filter by STRENGTH (500mg, 10ml, etc.)
    if (item.strength != null) {
      final strengthMatches = finalMatches.where((c) => 
          _isStrengthMatch(c.strength, item.strength!)).toList();
      if (strengthMatches.isNotEmpty) finalMatches = strengthMatches;
    }

    results[item] = finalMatches;
  }
  return results;
}
```

---

### 6️⃣ Cart Management

**Demo:** Add medicines to cart, show badge count

```dart
// cart_provider.dart - State Management
class CartNotifier extends StateNotifier<List<Medicine>> {
  CartNotifier() : super([]);

  void addToCart(Medicine medicine) {
    if (!state.any((m) => m.id == medicine.id)) {
      state = [...state, medicine];
    }
  }

  void removeFromCart(int medicineId) {
    state = state.where((m) => m.id != medicineId).toList();
  }

  void clear() {
    state = [];
  }
}

// Usage in UI
final cartItemCount = ref.watch(cartProvider).length;

Badge(
  label: Text('$cartItemCount'),
  isLabelVisible: cartItemCount > 0,
  child: const Icon(Icons.shopping_cart),
)
```

---

### 7️⃣ Pharmacy Finder (Geolocation + PostGIS)

**Demo:** Show map with nearby pharmacies, filter by distance/price

```dart
// pharmacy_finder_page.dart - Location-Based Search
Future<void> _loadData() async {
  // 1. Get user's current location
  _currentPosition = await Geolocator.getCurrentPosition();

  // 2. Get medicines from cart
  final cartItems = ref.read(cartProvider);
  final medicineIds = cartItems.map((e) => e.id).toList();

  // 3. Get user preferences
  final profile = ref.read(userProfileProvider).value;
  final defaultRadiusM = profile?.defaultRadiusM ?? 5000;
  final sortMode = profile?.sortMode ?? 'balanced';

  // 4. Call PostGIS RPC function
  final results = await repo.findPharmacies(
    lat: _currentPosition!.latitude,
    long: _currentPosition!.longitude,
    medicineIds: medicineIds,
    radius: defaultRadiusM,
  );

  // 5. Sort results (nearest/cheapest/most_matched/balanced)
  switch (sortMode) {
    case 'nearest':
      results.sort((a, b) => a.distance.compareTo(b.distance));
    case 'cheapest':
      results.sort((a, b) => a.totalPrice.compareTo(b.totalPrice));
    case 'balanced':
      // Prioritize: match count > distance > price
      results.sort((a, b) {
        final matchDiff = b.matchedItems.compareTo(a.matchedItems);
        if (matchDiff != 0) return matchDiff;
        return a.distance.compareTo(b.distance);
      });
  }
}
```

**PostGIS Query (Backend):**
```sql
-- Find pharmacies within radius with matching medicines
SELECT 
  p.pharmacy_id,
  p.name,
  ST_Distance(p.location, ST_Point($lng, $lat)::geography) AS distance_m,
  COUNT(DISTINCT pi.medicine_id) AS matched_items,
  SUM(pi.price) AS total_price
FROM pharmacies p
JOIN pharmacy_inventory pi ON pi.pharmacy_id = p.pharmacy_id
WHERE 
  pi.medicine_id = ANY($medicine_ids)
  AND ST_DWithin(p.location, ST_Point($lng, $lat)::geography, $radius)
GROUP BY p.pharmacy_id
ORDER BY matched_items DESC, distance_m ASC;
```

---

### 8️⃣ Order Placement

**Demo:** Select pharmacy → Confirm order → Show success

```dart
// place_order_page.dart - Order Flow
Future<void> _placeOrder() async {
  setState(() => _isLoading = true);

  try {
    final profile = ref.read(userProfileProvider).value;
    final orderRepo = ref.read(orderRepositoryProvider);

    // Create order via RPC
    final order = await orderRepo.placeOrder(
      pharmacyId: widget.pharmacy.id,
      items: widget.cartItems,
      customerName: profile?.fullName,
      customerPhone: profile?.phone,
      customerNotes: _notesController.text.trim(),
    );

    // Clear cart after success
    ref.read(cartProvider.notifier).clear();

    setState(() {
      _placedOrder = order;
      _isLoading = false;
    });
  } catch (e) {
    // Handle error
  }
}
```

**Order Database Schema:**
```sql
CREATE TABLE orders (
  order_id BIGINT PRIMARY KEY,
  customer_id UUID REFERENCES auth.users(id),
  pharmacy_id BIGINT REFERENCES pharmacies(pharmacy_id),
  status TEXT CHECK (status IN (
    'pending', 'confirmed', 'ready', 'completed', 'cancelled'
  )),
  total_amount NUMERIC,
  customer_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE order_items (
  item_id BIGINT PRIMARY KEY,
  order_id BIGINT REFERENCES orders(order_id),
  medicine_id BIGINT REFERENCES medicines(medicine_id),
  medicine_name TEXT,
  quantity INTEGER,
  unit_price NUMERIC
);
```

---

### **PART 2: Pharmacy Owner Journey**

---

### 9️⃣ Owner Dashboard

**Demo:** Login as owner → Show dashboard with action cards

```dart
// owner_dashboard.dart - Pharmacy Management
class OwnerDashboardPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pharmacyAsync = ref.watch(myPharmacyProvider);

    return Scaffold(
      body: pharmacyAsync.when(
        data: (pharmacy) {
          return Column(
            children: [
              // Pharmacy Info Card
              Card(child: Text(pharmacy.name)),
              
              // Quick Actions Grid
              Row(children: [
                _DashboardCard(
                  icon: Icons.receipt_long,
                  label: 'Orders',
                  onTap: () => Navigator.push(/*...*/),
                ),
                _DashboardCard(
                  icon: Icons.add_box,
                  label: 'Stock In',
                  onTap: () => Navigator.push(/*...*/),
                ),
              ]),
              Row(children: [
                _DashboardCard(
                  icon: Icons.point_of_sale,
                  label: 'Quick Sale',
                ),
                _DashboardCard(
                  icon: Icons.warning_amber,
                  label: 'Expiring Soon',
                ),
              ]),
            ],
          );
        },
      ),
    );
  }
}
```

---

### 🔟 Order Management (Owner View)

**Demo:** Show incoming orders → Accept → Mark Ready → Complete

```dart
// pharmacy_orders_page.dart - Order Workflow
class _PharmacyOrdersPageState extends ConsumerState<PharmacyOrdersPage> {
  late TabController _tabController; // 3 tabs: New | In Progress | Completed

  Future<void> _loadOrders() async {
    final orders = await orderRepo.getPharmacyOrders(
      pharmacyId: widget.pharmacyId,
    );

    setState(() {
      _pendingOrders = orders.where((o) => 
          o.status == OrderStatus.pending).toList();
      _activeOrders = orders.where((o) => 
          o.status == OrderStatus.confirmed || 
          o.status == OrderStatus.ready).toList();
      _completedOrders = orders.where((o) => 
          o.status == OrderStatus.completed).toList();
    });
  }

  Future<void> _updateOrderStatus(Order order, OrderStatus newStatus) async {
    await orderRepo.updateOrderStatus(
      orderId: order.id,
      status: newStatus,
    );
    await _loadOrders(); // Refresh
  }
}
```

**Order Status Flow:**
```
pending → confirmed → ready → completed
    ↓         ↓        ↓
    └─────────┴────────┴──→ cancelled
```

---

### 1️⃣1️⃣ Inventory Management

**Demo:** Show inventory list → Add stock → Unit conversion

```dart
// Key Features:
// - Batch tracking with expiry dates
// - Unit conversion (strip → tablet, bottle → ml)
// - Low stock alerts
// - Expiry warnings (30/60/90 days)

// Example: Adding stock
await supabase.from('pharmacy_inventory_batches').insert({
  'pharmacy_id': pharmacyId,
  'medicine_id': medicineId,
  'batch_no': 'BATCH-001',
  'expiry_date': '2027-06-15',
  'quantity': 100,
  'cost_price': 5.00,
  'selling_price': 8.00,
});
```

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      PRESENTATION LAYER                      │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────────────┐ │
│  │ HomePage │  │ScanPage │  │CartPage │  │PharmacyFinder   │ │
│  └────┬────┘  └────┬────┘  └────┬────┘  └────────┬────────┘ │
│       │            │            │                 │          │
│       └────────────┴────────────┴─────────────────┘          │
│                            │                                  │
│                    ┌───────▼───────┐                         │
│                    │   PROVIDERS   │  (Riverpod)             │
│                    │ medicineState │                         │
│                    │ cartProvider  │                         │
│                    │ userProfile   │                         │
│                    └───────┬───────┘                         │
└────────────────────────────┼─────────────────────────────────┘
                             │
┌────────────────────────────┼─────────────────────────────────┐
│                      DATA LAYER                               │
│                    ┌───────▼───────┐                         │
│                    │ REPOSITORIES  │                         │
│                    │ medicine_repo │                         │
│                    │ pharmacy_repo │                         │
│                    │ order_repo    │                         │
│                    └───────┬───────┘                         │
│                            │                                  │
│       ┌────────────────────┼────────────────────┐            │
│       │                    │                    │            │
│  ┌────▼────┐         ┌─────▼─────┐        ┌────▼────┐       │
│  │ Supabase │         │Edge Func  │        │Geolocator│       │
│  │ Client   │         │(Gemini AI)│        │         │       │
│  └────┬────┘         └─────┬─────┘        └─────────┘       │
└───────┼────────────────────┼────────────────────────────────┘
        │                    │
┌───────▼────────────────────▼────────────────────────────────┐
│                    SUPABASE BACKEND                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────┐ │
│  │PostgreSQL│  │ PostGIS  │  │   Auth   │  │Edge Functions│ │
│  │ Tables   │  │ Spatial  │  │  (JWT)   │  │ (Deno/AI)    │ │
│  └──────────┘  └──────────┘  └──────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔐 Security Features

### Row Level Security (RLS)
```sql
-- Customers can only see their own orders
CREATE POLICY "Customers view own orders" ON orders
  FOR SELECT USING (auth.uid() = customer_id);

-- Pharmacy owners can only see their pharmacy's orders
CREATE POLICY "Owners view pharmacy orders" ON orders
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM pharmacies 
      WHERE pharmacies.pharmacy_id = orders.pharmacy_id 
      AND pharmacies.owner_id = auth.uid()
    )
  );
```

---

## 📊 Demo Checklist

### Customer Demo Flow:
- [ ] 1. Login as customer
- [ ] 2. Show home page with greeting
- [ ] 3. Scan a prescription (camera/gallery)
- [ ] 4. Show AI extraction results
- [ ] 5. Add medicines to cart
- [ ] 6. Open pharmacy finder map
- [ ] 7. Select a pharmacy
- [ ] 8. Place order
- [ ] 9. Show order confirmation
- [ ] 10. Check order history

### Owner Demo Flow:
- [ ] 1. Login as pharmacy owner
- [ ] 2. Show owner dashboard
- [ ] 3. Check incoming orders
- [ ] 4. Accept an order → Mark ready → Complete
- [ ] 5. Show inventory management
- [ ] 6. Add stock with expiry tracking
- [ ] 7. Show expiry dashboard

---

## ❓ Potential Panel Questions

### Q1: How does the AI extraction work?
**A:** The prescription image is sent to a Supabase Edge Function which calls Google Gemini API. Gemini analyzes the image and returns structured JSON with medicine names, dosages, and forms. This is then matched against our database.

### Q2: How do you handle offline scenarios?
**A:** Currently the app requires internet connectivity. For future versions, we plan to cache recent prescription data locally using Hive/SQLite.

### Q3: Why Supabase instead of Firebase?
**A:** 
- PostgreSQL with PostGIS for geospatial queries (finding nearby pharmacies)
- Row Level Security for fine-grained access control
- Edge Functions with Deno runtime
- Open source and self-hostable

### Q4: How do you ensure medicine matching accuracy?
**A:** Multi-layered matching:
1. Brand name match (exact/contains)
2. Generic name fallback
3. Form filter (tablet/syrup/injection)
4. Strength filter (500mg/10ml)

### Q5: What's the order workflow?
**A:** 
```
Customer places order → Status: PENDING
Owner accepts → Status: CONFIRMED  
Order prepared → Status: READY
Customer picks up & pays → Status: COMPLETED
```

---

## 🚀 Future Enhancements

1. **Payment Integration** - Online payment via bKash/Nagad
2. **Delivery System** - Partner with delivery services
3. **Medicine Reminders** - Push notifications for dosage times
4. **Doctor Consultation** - Telemedicine integration
5. **Medicine Alternatives** - Suggest cheaper generic alternatives
6. **Offline Mode** - Local caching for areas with poor connectivity

---

## 📱 Running the Demo

```bash
# Terminal 1: Run Flutter app
cd /Users/nurul/first_ver_gemini
flutter run

# Test accounts (if seeded):
# Customer: customer@test.com / password123
# Owner: owner@test.com / password123
```

**Important:** Make sure to run `supabase/orders_schema.sql` in Supabase SQL Editor before demoing orders!

---

Good luck with your defense! 🎓
