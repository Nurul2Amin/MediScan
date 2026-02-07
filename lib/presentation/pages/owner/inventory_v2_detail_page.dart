import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prescription_scanner/data/models/inventory_batch.dart';
import 'package:prescription_scanner/data/models/unit_conversion.dart';
import 'package:prescription_scanner/data/providers.dart';
import 'package:prescription_scanner/core/helpers/error_handler.dart';

class InventoryV2DetailPage extends ConsumerStatefulWidget {
  final int pharmacyMedicineId;

  const InventoryV2DetailPage({super.key, required this.pharmacyMedicineId});

  @override
  ConsumerState<InventoryV2DetailPage> createState() =>
      _InventoryV2DetailPageState();
}

class _InventoryV2DetailPageState extends ConsumerState<InventoryV2DetailPage> {
  List<InventoryBatch> _batches = [];
  List<UnitConversion> _conversions = [];
  Map<String, dynamic>? _medicineInfo;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final supabase = ref.read(supabaseProvider);

      // Fetch batches and conversions
      final batchesFuture = repo.getBatches(widget.pharmacyMedicineId);
      final conversionsFuture = repo.getUnitConversions(
        widget.pharmacyMedicineId,
      );
      final medicineInfoFuture = supabase
          .from('pharmacy_medicines')
          .select('pills_per_leaflet, leaflets_per_box, unit_type')
          .eq('id', widget.pharmacyMedicineId)
          .single();

      final batches = await batchesFuture;
      final conversions = await conversionsFuture;
      final medicineInfo = await medicineInfoFuture;
      
      debugPrint('Loaded medicineInfo: $medicineInfo');

      if (mounted) {
        setState(() {
          _batches = batches;
          _conversions = conversions;
          _medicineInfo = medicineInfo;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppErrorHandler.getUserFriendlyMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _setActiveBatch(int? batchId) async {
    try {
      await ref
          .read(inventoryRepositoryProvider)
          .setActiveBatch(widget.pharmacyMedicineId, batchId);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Active batch updated')));
      _loadData(); // Reload to refresh UI if needed (though local state might need update)
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppErrorHandler.getUserFriendlyMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Medicine Details")),
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
                    onPressed: _loadData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Packaging Configuration Section
                  _buildSectionHeader(
                    "Packaging Configuration",
                    onAdd: _showEditPackagingDialog,
                  ),
                  _buildPackagingInfo(),
                  const SizedBox(height: 24),
                  _buildSectionHeader("Batches"),
                  if (_batches.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        "No batches found. Add stock to see details.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _batches.length,
                      itemBuilder: (context, index) {
                        final batch = _batches[index];
                        // Simplified display
                        return Card(
                          child: ListTile(
                            title: Text("Batch: ${batch.batchNo ?? 'N/A'}"),
                            subtitle: Text(
                              "Expires: ${batch.expiryDate.toIso8601String().split('T')[0]}\nQty: ${batch.qtyRemaining}",
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.check_circle_outline),
                              onPressed: () => _setActiveBatch(batch.batchId),
                              tooltip: "Set as Active",
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 24),
                  _buildSectionHeader(
                    "Unit Conversions",
                    onAdd: _showAddConversionDialog,
                  ),
                  ..._conversions.map(
                    (c) => ListTile(
                      title: Text(c.unitLabel),
                      subtitle: Text("Multiplier: ${c.multiplierToBase}"),
                      leading: c.isDefault
                          ? const Icon(Icons.star, color: Colors.amber)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onAdd}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (onAdd != null)
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.blue),
              onPressed: onAdd,
              tooltip: "Add New Unit",
            ),
        ],
      ),
    );
  }

  Future<void> _showAddConversionDialog() async {
    final unitController = TextEditingController();
    final multiplierController = TextEditingController();
    bool isDefault = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Add Unit Conversion"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: unitController,
                decoration: const InputDecoration(
                  labelText: "Unit Name (e.g. Box)",
                  hintText: "Enter unit name",
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: multiplierController,
                decoration: const InputDecoration(
                  labelText: "How many base units?",
                  hintText: "e.g. 10 (1 Box = 10 items)",
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text("Set as Default?"),
                value: isDefault,
                onChanged: (v) => setDialogState(() => isDefault = v ?? false),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final label = unitController.text.trim();
                final mult = double.tryParse(multiplierController.text);

                if (label.isEmpty || mult == null || mult <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please enter valid details")),
                  );
                  return;
                }

                Navigator.pop(context); // Close dialog

                try {
                  await ref
                      .read(inventoryRepositoryProvider)
                      .upsertUnitConversion(
                        pharmacyMedicineId: widget.pharmacyMedicineId,
                        unitLabel: label,
                        multiplierToBase: mult,
                        isDefault: isDefault,
                      );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Unit added successfully")),
                    );
                    _loadData();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text("Error: $e")));
                  }
                }
              },
              child: const Text("Add"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackagingInfo() {
    if (_medicineInfo == null) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          "Loading packaging info...",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final pillsPerLeaflet = _medicineInfo!['pills_per_leaflet'] ?? 1;
    final leafletsPerBox = _medicineInfo!['leaflets_per_box'] ?? 1;
    final baseUnit = _medicineInfo!['unit_type'] ?? 'pill';
    final totalPerBox = pillsPerLeaflet * leafletsPerBox;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  "Base Unit: $baseUnit",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildPackagingTile(
                    icon: Icons.filter_1,
                    label: "Per Leaflet",
                    value: "$pillsPerLeaflet ${baseUnit}s",
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildPackagingTile(
                    icon: Icons.filter_2,
                    label: "Per Box",
                    value: "$leafletsPerBox leaflets",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calculate, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    "1 Box = $totalPerBox ${baseUnit}s",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            if (pillsPerLeaflet == 1 && leafletsPerBox == 1)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "⚠️ Default values detected! Tap the + button to set correct packaging.",
                        style: TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackagingTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.blue),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _showEditPackagingDialog() async {
    final pillsController = TextEditingController(
      text: (_medicineInfo?['pills_per_leaflet'] ?? 1).toString(),
    );
    final leafletsController = TextEditingController(
      text: (_medicineInfo?['leaflets_per_box'] ?? 1).toString(),
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Packaging Configuration"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Configure how your medicine is packaged:",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pillsController,
                decoration: const InputDecoration(
                  labelText: "Pills/Items per Leaflet",
                  hintText: "e.g. 10",
                  prefixIcon: Icon(Icons.filter_1),
                  border: OutlineInputBorder(),
                ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: leafletsController,
              decoration: const InputDecoration(
                labelText: "Leaflets per Box",
                hintText: "e.g. 3",
                prefixIcon: Icon(Icons.filter_2),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: pillsController,
              builder: (context, pillsValue, _) {
                return ValueListenableBuilder<TextEditingValue>(
                  valueListenable: leafletsController,
                  builder: (context, leafletsValue, _) {
                    final pills = int.tryParse(pillsValue.text) ?? 0;
                    final leaflets = int.tryParse(leafletsValue.text) ?? 0;
                    final total = pills * leaflets;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.calculate, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(
                            "1 Box = $total items",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final pills = int.tryParse(pillsController.text);
              final leaflets = int.tryParse(leafletsController.text);

              if (pills == null ||
                  pills <= 0 ||
                  leaflets == null ||
                  leaflets <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Please enter valid positive numbers"),
                  ),
                );
                return;
              }

              Navigator.pop(context); // Close dialog

              try {
                final supabase = ref.read(supabaseProvider);
                
                // Debug: Print what we're trying to save
                debugPrint('Saving packaging config: pills=$pills, leaflets=$leaflets, id=${widget.pharmacyMedicineId}');
                
                final response = await supabase
                    .from('pharmacy_medicines')
                    .update({
                      'pills_per_leaflet': pills,
                      'leaflets_per_box': leaflets,
                    })
                    .eq('id', widget.pharmacyMedicineId)
                    .select();
                
                debugPrint('Update response: $response');

                if (mounted) {
                  // Update local state immediately for instant UI feedback
                  setState(() {
                    _medicineInfo = {
                      ..._medicineInfo ?? {},
                      'pills_per_leaflet': pills,
                      'leaflets_per_box': leaflets,
                    };
                  });
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("✅ Packaging configuration updated!"),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                debugPrint('Error saving packaging: $e');
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}
