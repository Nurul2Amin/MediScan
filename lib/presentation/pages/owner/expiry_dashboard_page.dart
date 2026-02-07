import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prescription_scanner/data/providers.dart';

class ExpiryDashboardPage extends ConsumerStatefulWidget {
  const ExpiryDashboardPage({super.key});

  @override
  ConsumerState<ExpiryDashboardPage> createState() => _ExpiryDashboardPageState();
}

class _ExpiryDashboardPageState extends ConsumerState<ExpiryDashboardPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // State
  List<Map<String, dynamic>> _expiring30 = [];
  List<Map<String, dynamic>> _expired = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final pharmacy = await ref.read(myPharmacyProvider.future);
      if (pharmacy != null) {
        final repo = ref.read(inventoryRepositoryProvider);
        final e30 = await repo.getExpiringBatches(pharmacy.id, daysUntilExpiry: 30);
        final exp = await repo.getExpiredBatches(pharmacy.id);
        
        if (mounted) {
          setState(() {
            _expiring30 = e30;
            _expired = exp;
          });
        }
      }
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Expiry Dashboard"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Expiring (30 Days)"),
            Tab(text: "Expired"),
          ],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : TabBarView(
          controller: _tabController,
          children: [
            _buildList(_expiring30, isExpired: false),
            _buildList(_expired, isExpired: true),
          ],
        ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items, {required bool isExpired}) {
    if (items.isEmpty) return const Center(child: Text("No items found"));
    
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final days = item['days_until_expiry'];
        return Card(
          color: isExpired ? Colors.red[50] : Colors.amber[50],
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text(item['medicine_name'] ?? 'Unknown'),
            subtitle: Text("Batch: ${item['batch_no'] ?? 'N/A'}\nQty: ${item['qty_remaining']}"),
            trailing: Text(
              isExpired ? "Expired ${days.abs()} days ago" : "Expires in $days days",
              style: TextStyle(
                color: isExpired ? Colors.red : Colors.deepOrange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}
