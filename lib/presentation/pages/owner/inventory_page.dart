import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prescription_scanner/data/models/medicine.dart';
import 'package:prescription_scanner/data/providers.dart';
import 'package:prescription_scanner/presentation/providers/auth_provider.dart';

class InventoryPage extends ConsumerStatefulWidget {
  final int pharmacyId;
  const InventoryPage({super.key, required this.pharmacyId});

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  // Inventory list state
  List<Map<String, dynamic>> _inventory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    setState(() => _isLoading = true);
    try {
      final supabase = ref.read(supabaseProvider);
      final response = await supabase
          .from('pharmacy_medicines')
          .select('*, medicine:medicines!inner(*)') // Join with medicines table
          .eq('pharmacy_id', widget.pharmacyId);
      
      var inventory = List<Map<String, dynamic>>.from(response);
      
      // Apply owner preferences filtering
      final profile = ref.read(userProfileProvider).value;
      final showLowStockOnly = profile?.showLowStockOnly ?? false;
      final lowStockThreshold = profile?.lowStockThreshold ?? 10;
      
      if (showLowStockOnly) {
        inventory = inventory.where((item) {
          final stockQty = item['stock_qty'] as int? ?? 0;
          return stockQty <= lowStockThreshold;
        }).toList();
      }
      
      setState(() => _inventory = inventory);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addItem() async {
    final selectedMedicine = await showSearch(
      context: context,
      delegate: MedicineSearchDelegate(ref),
    );

    if (selectedMedicine != null) {
      if (mounted) _showAddEditDialog(medicine: selectedMedicine);
    }
  }

  Future<void> _showAddEditDialog({Medicine? medicine, Map<String, dynamic>? existingItem}) async {
    final isEdit = existingItem != null;
    final medicineName = isEdit ? existingItem['medicine']['name'] : medicine!.name;
    final medicineId = isEdit ? existingItem['medicine_id'] : medicine!.id;

    final priceCtrl = TextEditingController(text: isEdit ? existingItem['price'].toString() : (medicine?.price?.toString() ?? ''));
    final stockCtrl = TextEditingController(text: isEdit ? existingItem['stock_qty'].toString() : '1');
    final leafletsCtrl = TextEditingController(text: isEdit ? (existingItem['leaflets_per_box']?.toString() ?? '1') : '1');
    final pillsCtrl = TextEditingController(text: isEdit ? (existingItem['pills_per_leaflet']?.toString() ?? '1') : '1');

    // State for total pills calculation
    int totalPills = 0;
    
    void calculateTotal() {
      final boxes = int.tryParse(stockCtrl.text) ?? 0;
      final leaflets = int.tryParse(leafletsCtrl.text) ?? 1;
      final pills = int.tryParse(pillsCtrl.text) ?? 1;
      totalPills = boxes * leaflets * pills;
    }
    
    calculateTotal();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(isEdit ? 'Edit $medicineName' : 'Add $medicineName'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: priceCtrl,
                    decoration: const InputDecoration(labelText: 'Price per Unit'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: stockCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Box Size (Number of Boxes)',
                      hintText: 'e.g., 10',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) {
                      setState(() => calculateTotal());
                    },
                  ),
                  TextField(
                    controller: leafletsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Leaflets per Box',
                      hintText: 'e.g., 3',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) {
                      setState(() => calculateTotal());
                    },
                  ),
                  TextField(
                    controller: pillsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Pills per Leaflet',
                      hintText: 'e.g., 10',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) {
                      setState(() => calculateTotal());
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Pills:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          '$totalPills',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final supabase = ref.read(supabaseProvider);
                    final price = double.tryParse(priceCtrl.text) ?? 0.0;
                    final stock = int.tryParse(stockCtrl.text) ?? 0;
                    final leaflets = int.tryParse(leafletsCtrl.text) ?? 1;
                    final pills = int.tryParse(pillsCtrl.text) ?? 1;

                    if (isEdit) {
                      await supabase
                          .from('pharmacy_medicines')
                          .update({
                            'price': price,
                            'stock_qty': stock,
                            'leaflets_per_box': leaflets,
                            'pills_per_leaflet': pills,
                          })
                          .eq('id', existingItem['id']);
                    } else {
                      await supabase.from('pharmacy_medicines').insert({
                        'pharmacy_id': widget.pharmacyId,
                        'medicine_id': medicineId,
                        'price': price,
                        'stock_qty': stock,
                        'leaflets_per_box': leaflets,
                        'pills_per_leaflet': pills,
                        'is_available': true,
                      });
                    }
                    
                    if (context.mounted) Navigator.pop(context);
                    _loadInventory();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteItem(int id) async {
    setState(() => _isLoading = true);
    try {
      final supabase = ref.read(supabaseProvider);
      await supabase.from('pharmacy_medicines').delete().eq('id', id);
      _loadInventory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item deleted successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDelete(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete $name from your inventory?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _deleteItem(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem,
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _inventory.length,
              itemBuilder: (context, index) {
                final item = _inventory[index];
                final med = item['medicine'];
                final stockQty = item['stock_qty'] as int? ?? 0;
                final profile = ref.read(userProfileProvider).value;
                final lowStockThreshold = profile?.lowStockThreshold ?? 10;
                final isLowStock = stockQty <= lowStockThreshold;
                
                return ListTile(
                  title: Text(med['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${med['form'] ?? 'Tablet'} • Stock: ${item['stock_qty']} • Price: \$${item['price']}'),
                  leading: isLowStock
                      ? const Icon(Icons.warning, color: Colors.orange)
                      : const Icon(Icons.check_circle, color: Colors.green),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showAddEditDialog(existingItem: item),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDelete(item['id'], med['name']),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class MedicineSearchDelegate extends SearchDelegate<Medicine?> {
  final WidgetRef ref;
  MedicineSearchDelegate(this.ref);

  @override
  List<Widget>? buildActions(BuildContext context) => [IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear))];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(onPressed: () => close(context, null), icon: const Icon(Icons.arrow_back));

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    if (query.isEmpty) return const SizedBox.shrink();

    final repo = ref.read(medicineRepositoryProvider);
    
    return FutureBuilder<List<Medicine>>(
      future: repo.searchMedicines(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final results = snapshot.data ?? [];
        if (results.isEmpty) return const Center(child: Text('No medicines found'));
        
        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final med = results[index];
            return ListTile(
              title: Text(med.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${med.form ?? "N/A"} • ${med.strength ?? "N/A"}'),
              trailing: Text(med.manufacturer ?? ''),
              onTap: () => close(context, med),
            );
          },
        );
      },
    );
  }
}
