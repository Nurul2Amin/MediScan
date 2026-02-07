import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prescription_scanner/data/models/inventory_summary.dart';
import 'package:prescription_scanner/data/models/medicine.dart';
import 'package:prescription_scanner/data/providers.dart';
import 'package:prescription_scanner/presentation/pages/owner/inventory_v2_detail_page.dart';
import 'package:prescription_scanner/presentation/pages/owner/stock_in_page.dart';
import 'package:prescription_scanner/core/helpers/error_handler.dart';

class InventoryV2ListPage extends ConsumerStatefulWidget {
  const InventoryV2ListPage({super.key});

  @override
  ConsumerState<InventoryV2ListPage> createState() => _InventoryV2ListPageState();
}

class _InventoryV2ListPageState extends ConsumerState<InventoryV2ListPage> {
  List<InventorySummary> _inventory = [];
  bool _isLoading = true;
  String? _error;
  int? _pharmacyId;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final pharmacy = await ref.read(myPharmacyProvider.future);
      if (pharmacy == null) {
        throw Exception('No pharmacy found');
      }
      
      _pharmacyId = pharmacy.id;

      final repo = ref.read(inventoryRepositoryProvider);
      final inventory = await repo.getInventorySummary(pharmacy.id);

      setState(() {
        _inventory = inventory;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = AppErrorHandler.getUserFriendlyMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _addNewMedicine() async {
    // Search from master medicines database
    final selectedMedicine = await showSearch<Medicine?>(
      context: context,
      delegate: _MasterMedicineSearchDelegate(ref),
    );

    if (selectedMedicine == null || _pharmacyId == null) return;

    // Show dialog to set initial price and unit type
    await _showAddMedicineDialog(selectedMedicine);
  }

  /// Returns packaging config based on unit type
  /// Returns (label1, label2, default1, default2, hasTwoLevels, summaryFormat)
  _PackagingConfig _getPackagingConfig(String unitType) {
    switch (unitType.toLowerCase()) {
      case 'pill':
      case 'piece':
      case 'tablet':
      case 'capsule':
        return _PackagingConfig(
          level1Label: 'Per Strip',
          level2Label: 'Strips Per Box',
          default1: 10,
          default2: 3,
          hasTwoLevels: true,
          summaryFormat: (l1, l2, unit) => '1 Box = $l2 strips × $l1 $unit = ${l1 * l2} $unit',
        );
      case 'bottle':
      case 'syrup':
        return _PackagingConfig(
          level1Label: 'Bottles Per Carton',
          level2Label: '',
          default1: 1, // Usually sold individually
          default2: 1,
          hasTwoLevels: false,
          summaryFormat: (l1, l2, unit) => l1 > 1 ? '1 Carton = $l1 bottles' : 'Sold individually',
        );
      case 'vial':
      case 'ampoule':
      case 'injection':
        return _PackagingConfig(
          level1Label: 'Vials Per Box',
          level2Label: '',
          default1: 5,
          default2: 1,
          hasTwoLevels: false,
          summaryFormat: (l1, l2, unit) => '1 Box = $l1 vials',
        );
      case 'tube':
      case 'cream':
      case 'ointment':
        return _PackagingConfig(
          level1Label: 'Tubes Per Box',
          level2Label: '',
          default1: 1, // Usually sold individually
          default2: 1,
          hasTwoLevels: false,
          summaryFormat: (l1, l2, unit) => l1 > 1 ? '1 Box = $l1 tubes' : 'Sold individually',
        );
      case 'sachet':
        return _PackagingConfig(
          level1Label: 'Sachets Per Box',
          level2Label: '',
          default1: 10,
          default2: 1,
          hasTwoLevels: false,
          summaryFormat: (l1, l2, unit) => '1 Box = $l1 sachets',
        );
      case 'drop':
      case 'dropper':
        return _PackagingConfig(
          level1Label: 'Bottles Per Pack',
          level2Label: '',
          default1: 1,
          default2: 1,
          hasTwoLevels: false,
          summaryFormat: (l1, l2, unit) => l1 > 1 ? '1 Pack = $l1 bottles' : 'Sold individually',
        );
      default:
        return _PackagingConfig(
          level1Label: 'Units Per Pack',
          level2Label: 'Packs Per Box',
          default1: 1,
          default2: 1,
          hasTwoLevels: true,
          summaryFormat: (l1, l2, unit) => '1 Box = $l2 packs × $l1 $unit = ${l1 * l2} $unit',
        );
    }
  }

  Future<void> _showAddMedicineDialog(Medicine medicine) async {
    final priceCtrl = TextEditingController(text: medicine.price?.toString() ?? '0');
    final level1Ctrl = TextEditingController(text: '10');
    final level2Ctrl = TextEditingController(text: '3');
    
    String selectedUnitType = 'pill'; // Default to smallest unit
    _PackagingConfig packagingConfig = _getPackagingConfig('pill');

    final unitTypes = ['pill', 'tablet', 'capsule', 'bottle', 'syrup', 'vial', 'tube', 'sachet', 'drop', 'piece', 'pack'];

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          packagingConfig = _getPackagingConfig(selectedUnitType);
          
          return AlertDialog(
            title: Text('Add ${medicine.name}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${medicine.form ?? ''} • ${medicine.strength ?? ''}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  
                  // Price
                  TextFormField(
                    controller: priceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Selling Price (per base unit)',
                      prefixText: '৳ ',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  
                  // Base Unit Type
                  const Text('Base Unit Type:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(
                    'The smallest sellable unit',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: unitTypes.map((type) {
                      final isSelected = type == selectedUnitType;
                      return ChoiceChip(
                        label: Text(type.substring(0, 1).toUpperCase() + type.substring(1)),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              selectedUnitType = type;
                              final config = _getPackagingConfig(type);
                              level1Ctrl.text = config.default1.toString();
                              level2Ctrl.text = config.default2.toString();
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  
                  // Dynamic Packaging Configuration
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.inventory_2, size: 18, color: Colors.blue.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'Packaging Configuration',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        if (packagingConfig.hasTwoLevels)
                          // Two-level packaging (pills, tablets, capsules)
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: level1Ctrl,
                                  decoration: InputDecoration(
                                    labelText: packagingConfig.level1Label,
                                    hintText: packagingConfig.default1.toString(),
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: level2Ctrl,
                                  decoration: InputDecoration(
                                    labelText: packagingConfig.level2Label,
                                    hintText: packagingConfig.default2.toString(),
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                            ],
                          )
                        else
                          // Single-level packaging (bottles, vials, tubes, etc.)
                          TextFormField(
                            controller: level1Ctrl,
                            decoration: InputDecoration(
                              labelText: packagingConfig.level1Label,
                              hintText: packagingConfig.default1.toString(),
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            final l1 = int.tryParse(level1Ctrl.text) ?? packagingConfig.default1;
                            final l2 = int.tryParse(level2Ctrl.text) ?? packagingConfig.default2;
                            return Text(
                              packagingConfig.summaryFormat(l1, l2, selectedUnitType),
                              style: TextStyle(
                                color: Colors.blue.shade600,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Add to Inventory'),
              ),
            ],
          );
        },
      ),
    );

    if (result == true && mounted) {
      setState(() => _isLoading = true);
      try {
        final supabase = ref.read(supabaseProvider);
        
        final level1Value = int.tryParse(level1Ctrl.text) ?? packagingConfig.default1;
        final level2Value = int.tryParse(level2Ctrl.text) ?? packagingConfig.default2;
        
        // For two-level packaging: level1 = pills per leaflet, level2 = leaflets per box
        // For single-level packaging: level1 = units per box, level2 = 1
        final pillsPerLeaflet = packagingConfig.hasTwoLevels ? level1Value : level1Value;
        final leafletsPerBox = packagingConfig.hasTwoLevels ? level2Value : 1;
        
        // Insert into pharmacy_medicines with packaging config
        await supabase.from('pharmacy_medicines').insert({
          'pharmacy_id': _pharmacyId,
          'medicine_id': medicine.id,
          'price': double.tryParse(priceCtrl.text) ?? 0,
          'unit_type': selectedUnitType,
          'pills_per_leaflet': pillsPerLeaflet,
          'leaflets_per_box': leafletsPerBox,
          'is_available': true,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${medicine.name} added to inventory!')),
          );
          _loadInventory(); // Refresh list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppErrorHandler.getUserFriendlyMessage(e))),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory V2'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInventory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadInventory,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _inventory.isEmpty
                  ? const Center(child: Text('No inventory items'))
                  : RefreshIndicator(
                      onRefresh: _loadInventory,
                      child: ListView.builder(
                        itemCount: _inventory.length,
                        itemBuilder: (context, index) {
                          final item = _inventory[index];
                          return _InventoryItemCard(
                            item: item,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => InventoryV2DetailPage(
                                    pharmacyMedicineId: item.pharmacyMedicineId,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOptions(context),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Add to Inventory',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              // Option 1: Add New Medicine
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade50,
                  child: Icon(Icons.add_circle_outline, color: Colors.green.shade700),
                ),
                title: const Text('Add New Medicine'),
                subtitle: const Text('Search from database & add to your pharmacy'),
                onTap: () {
                  Navigator.pop(context);
                  _addNewMedicine();
                },
              ),
              const Divider(),
              
              // Option 2: Stock In
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  child: Icon(Icons.inventory_2, color: Colors.blue.shade700),
                ),
                title: const Text('Stock In'),
                subtitle: const Text('Restock existing inventory items'),
                onTap: () async {
                  Navigator.pop(context);
                  await Navigator.of(this.context).push(
                    MaterialPageRoute(builder: (_) => const StockInPage()),
                  );
                  _loadInventory();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _InventoryItemCard extends StatelessWidget {
  final InventorySummary item;
  final VoidCallback onTap;

  const _InventoryItemCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.medicineName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (item.isLowStock)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'LOW',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  if (item.hasExpired)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'EXPIRED',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  if (item.hasExpiringSoon && !item.hasExpired)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'EXPIRING',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${item.form ?? "N/A"} • ${item.strength ?? "N/A"}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _StockDisplay(item: item),
                  ),
                  const SizedBox(width: 8),
                  if (item.nextExpiryDate != null)
                    _InfoChip(
                      icon: Icons.calendar_today,
                      label: 'Expires: ${_formatDate(item.nextExpiryDate!)}',
                    ),
                ],
              ),
              if (item.activeBatchCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${item.activeBatchCount} active batch${item.activeBatchCount > 1 ? "es" : ""}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = date.difference(now).inDays;
    if (diff < 0) {
      return '${-diff} days ago';
    } else if (diff == 0) {
      return 'Today';
    } else if (diff <= 30) {
      return 'In $diff days';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey[700], fontSize: 14),
        ),
      ],
    );
  }
}

/// Widget to display stock in pharmacy-friendly format
/// Shows breakdown like "2 boxes + 3 leaflets + 7 pills"
class _StockDisplay extends StatelessWidget {
  final InventorySummary item;

  const _StockDisplay({required this.item});

  @override
  Widget build(BuildContext context) {
    // For non-pill items, show simple format
    if (item.unitType != 'pill') {
      return Row(
        children: [
          Icon(Icons.inventory_2, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            '${item.totalBaseUnits} ${item.unitType}',
            style: TextStyle(color: Colors.grey[700], fontSize: 14),
          ),
        ],
      );
    }

    // For pills, show breakdown with icons
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.inventory_2, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                item.formattedStock,
                style: TextStyle(
                  color: Colors.grey[700], 
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Show pack configuration hint
        Text(
          '(${item.pillsPerLeaflet}P/leaflet, ${item.leafletsPerBox}L/box)',
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 11,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

/// Search delegate for finding medicines from the master database
class _MasterMedicineSearchDelegate extends SearchDelegate<Medicine?> {
  final WidgetRef ref;
  _MasterMedicineSearchDelegate(this.ref);

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
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
    if (query.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Search for medicines to add to your inventory'),
          ],
        ),
      );
    }

    final repo = ref.read(medicineRepositoryProvider);

    return FutureBuilder<List<Medicine>>(
      future: repo.searchMedicines(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final results = snapshot.data ?? [];
        if (results.isEmpty) {
          return const Center(child: Text('No medicines found'));
        }

        return ListView.builder(
          itemCount: results.length,
          itemBuilder: (context, index) {
            final med = results[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade50,
                child: Icon(Icons.medication, color: Colors.blue.shade700),
              ),
              title: Text(
                med.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${med.form ?? "N/A"} • ${med.strength ?? "N/A"}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              trailing: med.manufacturer != null && med.manufacturer!.isNotEmpty
                  ? SizedBox(
                      width: 80,
                      child: Text(
                        med.manufacturer!,
                        style: TextStyle(color: Colors.blue[700], fontSize: 11),
                        textAlign: TextAlign.right,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  : null,
              onTap: () => close(context, med),
            );
          },
        );
      },
    );
  }
}

/// Helper class for dynamic packaging configuration
class _PackagingConfig {
  final String level1Label;
  final String level2Label;
  final int default1;
  final int default2;
  final bool hasTwoLevels;
  final String Function(int l1, int l2, String unit) summaryFormat;

  _PackagingConfig({
    required this.level1Label,
    required this.level2Label,
    required this.default1,
    required this.default2,
    required this.hasTwoLevels,
    required this.summaryFormat,
  });
}
