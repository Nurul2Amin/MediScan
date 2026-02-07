import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prescription_scanner/data/providers.dart';
import 'package:prescription_scanner/data/models/inventory_summary.dart';
import 'package:prescription_scanner/data/models/unit_conversion.dart';
import 'package:prescription_scanner/presentation/delegates/inventory_search_delegate.dart';
import 'package:prescription_scanner/core/helpers/error_handler.dart';

class StockInPage extends ConsumerStatefulWidget {
  const StockInPage({super.key});

  @override
  ConsumerState<StockInPage> createState() => _StockInPageState();
}

class _StockInPageState extends ConsumerState<StockInPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Selection
  InventorySummary? _selectedItem;
  // unused: Medicine? _selectedMedicine;
  List<UnitConversion> _conversions = [];
  
  // Inputs
  final _qtyController = TextEditingController();
  final _batchController = TextEditingController();
  final _priceController = TextEditingController();
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 365));

  bool _isLoading = false;

  // AI Paste
  final _pasteController = TextEditingController();

  @override
  void dispose() {
    _qtyController.dispose();
    _batchController.dispose();
    _priceController.dispose();
    _pasteController.dispose();
    super.dispose();
  }

  Future<void> _loadConversions() async {
    if (_selectedItem == null) return;
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final list = await repo.getUnitConversions(_selectedItem!.pharmacyMedicineId);
      if (mounted) setState(() => _conversions = list);
    } catch (e) {
      // ignore
    }
  }

  Future<void> _submit() async {
    if (_selectedItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a medicine')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(inventoryRepositoryProvider);
      await repo.stockIn(
        pharmacyMedicineId: _selectedItem!.pharmacyMedicineId,
        qtyBaseUnits: int.parse(_qtyController.text),
        expiryDate: _expiryDate,
        batchNo: _batchController.text.isEmpty ? null : _batchController.text,
        buyPrice: _priceController.text.isEmpty ? null : double.parse(_priceController.text),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock In Successful')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppErrorHandler.getUserFriendlyMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPasteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Paste Purchase List"),
        content: TextField(
          controller: _pasteController,
          maxLines: 10,
          decoration: const InputDecoration(hintText: "Paste text from invoice/SMS..."),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await _processPaste(_pasteController.text);
            },
            child: const Text("Analyze"),
          ),
        ],
      ),
    );
  }

  Future<void> _processPaste(String text) async {
    if (text.isEmpty) return;
    
    setState(() => _isLoading = true);
    try {
      final service = ref.read(edgeFunctionGeminiServiceProvider);
      final result = await service.parseStockText(text);
      
      // For now, just showing the parsed result. In a real app, we'd loop through items.
      // Simplification: Just pre-fill the form with the first detected item if possible
      // or show a list of detected items to import.
      
      if (mounted) {
         showDialog(
            context: context,
            builder: (context) => AlertDialog(
               title: const Text("AI Analysis Result"),
               content: SingleChildScrollView(child: Text(result.toString())),
               actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
            ),
         );
      }
      
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppErrorHandler.getUserFriendlyMessage(e))));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  void _addQty(double multiplier) {
    int current = int.tryParse(_qtyController.text) ?? 0;
    int add = multiplier.round();
    setState(() {
      _qtyController.text = (current + add).toString();
    });
  }

  List<({double multiplier, String label})> _getSmartButtons() {
    if (_selectedItem == null) return [];
    
    final type = _selectedItem!.unitType.toLowerCase();
    final pillsPerLeaflet = _selectedItem!.pillsPerLeaflet;
    final leafletsPerBox = _selectedItem!.leafletsPerBox;
    final List<({double multiplier, String label})> buttons = [];

    // 1. Always add Base Unit (1)
    final capType = type.isNotEmpty ? '${type[0].toUpperCase()}${type.substring(1)}' : 'Unit';
    buttons.add((multiplier: 1.0, label: '1 $capType'));

    // 2. For pill/piece types, add Strip and Box buttons based on config
    if (['pill', 'piece', 'tablet', 'capsule'].contains(type)) {
      // Add Strip/Leaflet button
      if (pillsPerLeaflet > 1) {
        buttons.add((multiplier: pillsPerLeaflet.toDouble(), label: '1 Strip ($pillsPerLeaflet $capType)'));
      }
      // Add Box button
      final unitsPerBox = pillsPerLeaflet * leafletsPerBox;
      if (unitsPerBox > 1) {
        buttons.add((multiplier: unitsPerBox.toDouble(), label: '1 Box ($unitsPerBox $capType)'));
      }
      // Add 5 Boxes and 10 Boxes for bulk
      if (unitsPerBox > 1) {
        buttons.add((multiplier: (unitsPerBox * 5).toDouble(), label: '5 Boxes'));
        buttons.add((multiplier: (unitsPerBox * 10).toDouble(), label: '10 Boxes'));
      }
    } else {
      // 3. Add Type-Specific Presets for non-pill types
      switch (type) {
        case 'bottle':
          buttons.add((multiplier: 6.0, label: '6 Pack'));
          buttons.add((multiplier: 12.0, label: '12 Pack'));
          break;
        case 'vial':
          buttons.add((multiplier: 5.0, label: '5 Vials'));
          buttons.add((multiplier: 10.0, label: '10 Vials'));
          break;
        case 'sachet':
          buttons.add((multiplier: 10.0, label: '10 Pack'));
          buttons.add((multiplier: 50.0, label: '50 Box'));
          break;
        case 'strip':
          buttons.add((multiplier: 3.0, label: '1 Box (3 strips)'));
          buttons.add((multiplier: 10.0, label: '10 Strips'));
          break;
        case 'tube':
          buttons.add((multiplier: 6.0, label: '6 Pack'));
          buttons.add((multiplier: 12.0, label: '12 Pack'));
          break;
      }
    }

    // 4. Add DB Conversions (custom unit conversions)
    for (final c in _conversions) {
      if ((c.multiplierToBase - 1.0).abs() > 0.001) { 
        buttons.add((multiplier: c.multiplierToBase, label: c.unitLabel));
      }
    }
    
    // Remove duplicates and sort
    final seen = <double>{};
    final unique = buttons.where((b) => seen.add(b.multiplier)).toList();
    unique.sort((a, b) => a.multiplier.compareTo(b.multiplier));
    return unique;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Stock In"),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: _showPasteDialog,
            tooltip: "AI Paste",
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView( // Add scroll for smaller screens
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                 // Medicine Search Placeholder
                  ElevatedButton.icon(
                    onPressed: () async {
                      setState(() => _isLoading = true);
                      try {
                        final pharmacy = await ref.read(myPharmacyProvider.future);
                        if (pharmacy == null) {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No pharmacy found')));
                          return;
                        }
  
                        final repo = ref.read(inventoryRepositoryProvider);
                        final inventory = await repo.getInventorySummary(pharmacy.id);
  
                        if (context.mounted) {
                          final selected = await showSearch(
                            context: context,
                            delegate: InventorySearchDelegate(inventory),
                          );
  
                          if (selected != null) {
                            setState(() {
                              _selectedItem = selected;
                              _conversions = []; // clear old
                            });
                            _loadConversions();
                          }
                        }
                      } catch (e) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppErrorHandler.getUserFriendlyMessage(e))));
                      } finally {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    }, 
                    icon: const Icon(Icons.search),
                    label: Text(_selectedItem == null ? "Select Medicine to Restock" : "Change Medicine"),
                  ),
                  if (_selectedItem != null) 
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.medication, color: Colors.blue),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Restocking: ${_selectedItem!.medicineName}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text("Base Unit: ${_selectedItem!.unitType} | Current Stock: ${_selectedItem!.totalBaseUnits}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                 const SizedBox(height: 16),
                 TextFormField(
                   controller: _qtyController,
                   decoration: const InputDecoration(
                     labelText: "Quantity (Base Units)",
                     border: OutlineInputBorder(),
                     helperText: "Total number of single units",
                   ),
                   keyboardType: TextInputType.number,
                   validator: (v) => v == null || v.isEmpty ? "Required" : null,
                 ),
                 
                 // Smart Buttons for adding quantity
                 if (_selectedItem != null) ...[
                   const SizedBox(height: 8),
                   const Text("Quick Add:", style: TextStyle(fontWeight: FontWeight.bold)),
                   const SizedBox(height: 8),
                   Wrap(
                     spacing: 8,
                     runSpacing: 8,
                     children: _getSmartButtons().map((btn) {
                       return ActionChip(
                         avatar: const Icon(Icons.add_circle, size: 16, color: Colors.green),
                         label: Text(btn.label),
                         onPressed: () => _addQty(btn.multiplier),
                         tooltip: "Add ${btn.multiplier.round()} units",
                       );
                     }).toList(),
                   ),
                 ],
  
                 const SizedBox(height: 16),
                 TextFormField(
                   controller: _batchController,
                   decoration: const InputDecoration(labelText: "Batch No (Optional)"),
                 ),
                 TextFormField(
                   controller: _priceController,
                   decoration: const InputDecoration(labelText: "Buy Price (Optional)"),
                   keyboardType: TextInputType.number,
                   validator: (v) => null, // Optional
                 ),
                 const SizedBox(height: 16),
                 Row(
                   children: [
                     const Text("Expiry: "),
                     TextButton(
                       onPressed: () async {
                         final d = await showDatePicker(
                           context: context,
                           firstDate: DateTime.now().subtract(const Duration(days: 365)),
                           lastDate: DateTime.now().add(const Duration(days: 365*5)),
                           initialDate: _expiryDate,
                         );
                         if (d != null) setState(() => _expiryDate = d);
                       },
                       child: Text("${_expiryDate.year}-${_expiryDate.month}-${_expiryDate.day}"),
                     ),
                   ],
                 ),
                 const SizedBox(height: 32),
                 SizedBox(
                   width: double.infinity,
                   child: ElevatedButton(
                     style: ElevatedButton.styleFrom(
                       padding: const EdgeInsets.symmetric(vertical: 16),
                       backgroundColor: Theme.of(context).primaryColor,
                       foregroundColor: Colors.white,
                     ),
                     onPressed: _isLoading ? null : _submit,
                     child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("CONFIRM STOCK IN", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                   ),
                 ),
                 const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
