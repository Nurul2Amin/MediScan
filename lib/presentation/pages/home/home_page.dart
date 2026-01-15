import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:prescription_scanner/data/models/medicine.dart';
import 'package:prescription_scanner/data/providers.dart';
import 'package:prescription_scanner/presentation/pages/cart/cart_page.dart';
import 'package:prescription_scanner/presentation/pages/scan/scan_page.dart';
import 'package:prescription_scanner/presentation/providers/auth_provider.dart';
import 'package:prescription_scanner/presentation/providers/cart_provider.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider).value;
    final repo = ref.watch(medicineRepositoryProvider);
    final cartItemCount = ref.watch(cartProvider).length;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 1. Header & Search
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue, Colors.blueAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),
                      Text(
                        'Hello, ${user?.fullName ?? "User"}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Find your medicines',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
               IconButton(
                icon: Badge(
                  label: Text('$cartItemCount'),
                  isLabelVisible: cartItemCount > 0,
                  child: const Icon(Icons.shopping_cart),
                ),
                onPressed: () {
                   Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const CartPage()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  await ref.read(supabaseProvider).auth.signOut();
                  if (context.mounted) context.go('/login');
                },
              ),
              const Padding(
                padding: EdgeInsets.only(right: 16.0),
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, color: Colors.blue),
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: GestureDetector(
                  onTap: () {
                    showSearch(
                      context: context,
                      delegate: _MedicineSearchDelegate(repo, ref),
                    );
                  },
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Icon(Icons.search, color: Colors.grey),
                        ),
                        Text(
                          'Search to add to cart...',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. Popular Medicines (Horizontal)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Most Popular Medicines',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 140, // Height for cards
                    child: FutureBuilder<List<Medicine>>(
                      future: repo.getPopularMedicines(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final meds = snapshot.data ?? [];
                        if (meds.isEmpty) return const Text("No popular items.");

                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: meds.length,
                          itemBuilder: (context, index) {
                            final med = meds[index];
                            return GestureDetector(
                              onTap: () {
                                ref.read(cartProvider.notifier).addItem(med);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${med.name} added to cart'),
                                    action: SnackBarAction(
                                      label: 'View Cart',
                                      onPressed: () {
                                         Navigator.of(context).push(
                                          MaterialPageRoute(builder: (context) => const CartPage()),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                width: 120,
                                margin: const EdgeInsets.only(right: 12),
                                child: Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.medication, size: 40, color: Colors.blueAccent),
                                        const SizedBox(height: 8),
                                        Text(
                                          med.name,
                                          maxLines: 2,
                                          textAlign: TextAlign.center,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Recent Orders (Vertical Mock)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Recent Orders',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildRecentOrderTile("Order #1023", "2 Items • Delivered", "Yesterday"),
                  _buildRecentOrderTile("Order #1021", "5 Items • Delivered", "Last Week"),
                  _buildRecentOrderTile("Order #1018", "1 Item • Cancelled", "2 Weeks ago"),
                  const SizedBox(height: 80), // Space for FAB
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const ScanPage()),
          );
        },
        label: const Text('Scan Prescription'),
        icon: const Icon(Icons.camera_alt),
        backgroundColor: Colors.blueAccent,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildRecentOrderTile(String title, String subtitle, String date) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.green,
          child: Icon(Icons.check, color: Colors.white, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: Text(date, style: const TextStyle(color: Colors.grey)),
      ),
    );
  }
}

// Search Delegate
class _MedicineSearchDelegate extends SearchDelegate<Medicine?> {
  final dynamic repo; // Type: MedicineRepository
  final WidgetRef ref;
  _MedicineSearchDelegate(this.repo, this.ref);

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    if (query.isEmpty) return const Center(child: Text("Type to search medicines..."));

    return FutureBuilder<List<Medicine>>(
      future: repo.searchMedicines(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final results = snapshot.data ?? [];
        if (results.isEmpty) return const Center(child: Text("No medicines found"));

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final med = results[index];
            return ListTile(
              leading: const Icon(Icons.medication_liquid),
              title: Text(med.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(med.genericName ?? ''),
              trailing: Text('${med.form ?? ""} ${med.strength ?? ""}'),
              onTap: () {
                // Add to cart
                ref.read(cartProvider.notifier).addItem(med);
                
                // Show feedback
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${med.name} added to cart'),
                    duration: const Duration(seconds: 2),
                  ),
                );
                
                // We keep the search open so they can add more, or they can close it.
                // Alternatively, reset query or close:
                // close(context, med);
              },
            );
          },
        );
      },
    );
  }
}
