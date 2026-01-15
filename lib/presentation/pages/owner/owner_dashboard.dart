import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prescription_scanner/presentation/providers/owner_provider.dart';
import 'package:prescription_scanner/presentation/pages/owner/pharmacy_setup_page.dart';
import 'package:prescription_scanner/presentation/pages/owner/inventory_page.dart';
import 'package:prescription_scanner/data/providers.dart';

class OwnerDashboardPage extends ConsumerWidget {
  const OwnerDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pharmacyAsync = ref.watch(myPharmacyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(supabaseProvider).auth.signOut(),
          ),
        ],
      ),
      body: pharmacyAsync.when(
        data: (pharmacy) {
          if (pharmacy == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No Pharmacy Found'),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const PharmacySetupPage()),
                      );
                    },
                    child: const Text('Create My Pharmacy'),
                  ),
                ],
              ),
            );
          }
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Managing: ${pharmacy.name}', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => InventoryPage(pharmacyId: pharmacy.id),
                      ),
                    );
                  }, 
                  icon: const Icon(Icons.inventory), 
                  label: const Text('Manage Inventory')
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
