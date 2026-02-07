import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prescription_scanner/data/models/unit_conversion.dart';
import 'package:prescription_scanner/data/providers.dart';
import 'package:prescription_scanner/core/helpers/error_handler.dart';

import 'package:prescription_scanner/data/models/inventory_summary.dart';
import 'package:prescription_scanner/presentation/delegates/inventory_search_delegate.dart';

class QuickStockOutPage extends ConsumerStatefulWidget {
  const QuickStockOutPage({super.key});

  @override
  ConsumerState<QuickStockOutPage> createState() => _QuickStockOutPageState();
}

class _QuickStockOutPageState extends ConsumerState<QuickStockOutPage> {
  InventorySummary? _selectedItem; 
  List<UnitConversion> _conversions = [];
  bool _isLoading = false;

  Future<void> _selectMedicine() async {
    setState(() => _isLoading = true);
    try {
      final pharmacy = await ref.read(myPharmacyProvider.future);
      if (pharmacy == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No pharmacy found')));
        return;
      }

      final repo = ref.read(inventoryRepositoryProvider);
      final inventory = await repo.getInventorySummary(pharmacy.id);

      if (mounted) {
        final selected = await showSearch(
          context: context,
          delegate: InventorySearchDelegate(inventory),
        );

        if (selected != null) {
          setState(() {
            _selectedItem = selected;
            _conversions = [];
          });
          _loadConversions();
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading inventory: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadConversions() async {
    if (_selectedItem == null) return;
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final list = await repo.getUnitConversions(_selectedItem!.pharmacyMedicineId);
      
      // Ensure 'base' exists if not returned (it should be handled by trigger, but just in case)
      if (!list.any((c) => c.multiplierToBase == 1.0)) {
         // We can rely on the trigger, or add a visual fallback if needed.
         // For now, we trust the DB trigger sync_default_pill_conversions.
      }
      setState(() => _conversions = list);
    } catch(e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading units: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _stockOut(double multiplier, String label) async {
    if (_selectedItem == null) return;
    
    // Optimistic check
    final qtyToRemove = multiplier.round();
    if (_selectedItem!.totalBaseUnits < qtyToRemove) {
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
         content: Text('Insufficient stock! Have: ${_selectedItem!.totalBaseUnits}, Need: $qtyToRemove'),
         backgroundColor: Colors.red,
       ));
       return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      
      await repo.stockOut(
        pharmacyMedicineId: _selectedItem!.pharmacyMedicineId,
        qtyBaseUnits: qtyToRemove,
        useActiveBatch: true, 
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sold 1 $label')));
        // Refresh the selected item to update stock count
        _refreshSelectedItem();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppErrorHandler.getUserFriendlyMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshSelectedItem() async {
     // Re-fetch only the updated item would be ideal, but for now re-fetch inventory or just update local state
     // A simple way is to re-run the inventory fetch filter. But that's heavy.
     // Let's just decrease the count locally for UI responsiveness? 
     // For accuracy, let's fetch inventory again briefly or trust the user will see it next time.
     // Better: Update _selectedItem with new stock.
     
     // NOTE: We don't have a single-item fetch RPC yet efficiently exposed, 
     // so we might just decrement locally to show immediate feedback.
     setState(() {
       // We can't easily update valid const/final fields of InventorySummary without a copyWith or new fetch.
       // Let's just re-fetch the inventory list quickly to find this item.
     });
     
     final pharmacy = await ref.read(myPharmacyProvider.future);
     if (pharmacy != null) {
       final repo = ref.read(inventoryRepositoryProvider);
       final inventory = await repo.getInventorySummary(pharmacy.id);
       final updated = inventory.firstWhere((i) => i.pharmacyMedicineId == _selectedItem!.pharmacyMedicineId, orElse: () => _selectedItem!);
       if (mounted) setState(() => _selectedItem = updated);
     }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Quick Stock Out")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
             ElevatedButton.icon(
                 onPressed: _selectMedicine, 
                 icon: const Icon(Icons.search),
                 label: Text(_selectedItem == null ? "Select Medicine" : "Change Medicine"),
                 style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
               ),
             const SizedBox(height: 20),
             
             if (_selectedItem != null) ...[
               Card(
                 elevation: 2,
                 child: Padding(
                   padding: const EdgeInsets.all(16.0),
                   child: Column(
                     children: [
                       Text(
                         _selectedItem!.medicineName, 
                         style: Theme.of(context).textTheme.headlineSmall,
                         textAlign: TextAlign.center,
                       ),
                       const SizedBox(height: 12),
                       // Show formatted stock display
                       Container(
                         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                         decoration: BoxDecoration(
                           color: Colors.blue.shade50,
                           borderRadius: BorderRadius.circular(12),
                           border: Border.all(color: Colors.blue.shade200),
                         ),
                         child: Column(
                           children: [
                             const Text(
                               'Current Stock',
                               style: TextStyle(
                                 fontSize: 12,
                                 fontWeight: FontWeight.w500,
                                 color: Colors.blue,
                               ),
                             ),
                             const SizedBox(height: 4),
                             Text(
                               _selectedItem!.formattedStock,
                               style: const TextStyle(
                                 fontSize: 18,
                                 fontWeight: FontWeight.bold,
                               ),
                               textAlign: TextAlign.center,
                             ),
                             const SizedBox(height: 4),
                             Text(
                               '(${_selectedItem!.totalBaseUnits} total ${_selectedItem!.unitType}s)',
                               style: TextStyle(
                                 fontSize: 12,
                                 color: Colors.grey[600],
                               ),
                             ),
                           ],
                         ),
                       ),
                       const SizedBox(height: 8),
                       Text("Expiring Soon: ${_selectedItem!.hasExpiringSoon ? 'YES' : 'No'}", 
                            style: TextStyle(color: _selectedItem!.hasExpiringSoon ? Colors.orange : Colors.grey)),
                     ],
                   ),
                 ),
               ),
               const SizedBox(height: 20),
               const Text("Select Unit to Sell:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
               const SizedBox(height: 10),
             ],

             if (_isLoading) 
               const Center(child: CircularProgressIndicator())
             else if (_selectedItem != null) 
               Expanded(
                 child: GridView.count(
                   crossAxisCount: 2,
                   crossAxisSpacing: 10,
                   mainAxisSpacing: 10,
                   children: [
                     ..._getSmartButtons().map((btn) => _buildStockOutButton(btn.multiplier, btn.label)),
                     _buildCustomStockOutButton(),
                   ],
                 ),
               ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCustomStockOutDialog() async {
    final qtyCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Custom Quantity"),
        content: TextField(
          controller: qtyCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: "Enter quantity to sell (${_selectedItem!.unitType}s)",
            hintText: "e.g., 5",
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(qtyCtrl.text);
              if (val != null && val > 0) {
                Navigator.pop(context);
                _stockOut(val, "Custom ($val units)");
              }
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  List<({double multiplier, String label})> _getSmartButtons() {
    final type = _selectedItem!.unitType.toLowerCase();
    final List<({double multiplier, String label})> buttons = [];

    // 1. Always add Base Unit (1)
    // Capitalize type for label
    final capType = type.isNotEmpty ? '${type[0].toUpperCase()}${type.substring(1)}' : 'Unit';
    buttons.add((multiplier: 1.0, label: capType));

    // 2. Add Type-Specific Presets (as requested/intended UX)
    switch (type) {
      case 'bottle':
        // -2 Bottles
        buttons.add((multiplier: 2.0, label: '2 Bottles'));
        break;
      case 'vial':
        // -5 Vials
        buttons.add((multiplier: 5.0, label: '5 Vials'));
        break;
      case 'sachet':
        // -10 Sachets
        buttons.add((multiplier: 10.0, label: '10 Sachets'));
        break;
      // 'cream'/'tube' typically just 1, which is base.
      // 'pill' doesn't usually have arbitrary "5 pills" buttons, usually goes by strip/box.
    }

    // 3. Add DB Conversions (e.g., Strip, Box)
    // Filter out 1.0 if we already added it as base (to avoid duplicates like "1 Pill" and "1 Base Unit")
    for (final c in _conversions) {
      if ((c.multiplierToBase - 1.0).abs() > 0.001) { 
        buttons.add((multiplier: c.multiplierToBase, label: c.unitLabel));
      }
    }
    
    // Sort by multiplier so they appear in logical order (Small -> Large)
    buttons.sort((a, b) => a.multiplier.compareTo(b.multiplier));

    return buttons;
  }

  Widget _buildStockOutButton(double multiplier, String label) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(10),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () => _stockOut(multiplier, label),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.remove_circle_outline, size: 32),
          const SizedBox(height: 8),
          Text("Sell $label", textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text("(-${multiplier.round()} units)", style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildCustomStockOutButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(10),
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: _showCustomStockOutDialog,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.edit, size: 32),
          SizedBox(height: 8),
          Text("Manual", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text("(Enter Qty)", style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}


