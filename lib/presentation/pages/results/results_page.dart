import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prescription_scanner/presentation/pages/pharmacy/pharmacy_finder_page.dart';
import 'package:prescription_scanner/presentation/pages/pharmacy/pharmacy_page.dart';
import 'package:prescription_scanner/presentation/providers/medicine_provider.dart';
import 'package:prescription_scanner/presentation/providers/cart_provider.dart';
import 'package:prescription_scanner/data/models/medicine.dart';
import 'package:prescription_scanner/data/models/cart_item.dart';

class ResultsPage extends ConsumerWidget {
  const ResultsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(medicineStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Results')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(child: Text('Error: ${state.error}'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       const Text(
                        'Confirm Medicines:',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),

                      if (state.extractedMedicines.isEmpty)
                         const Text('No medicines extracted.'),

                      ...state.extractedMedicines.map((extracted) {
                        final matches = state.foundMedicines[extracted] ?? [];
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: _ExpandableMedicineSection(
                            extractedName: extracted.name,
                            extractedSubtitle: 'Scanned: ${extracted.strength ?? "N/A"} ${extracted.form ?? ""}',
                            matches: matches,
                          ),
                        );
                      }),
                      
                      const SizedBox(height: 24),
                      Center(
                        child: Consumer(
                          builder: (context, ref, child) {
                            final cart = ref.watch(cartProvider);
                            return ElevatedButton.icon(
                              onPressed: cart.isEmpty ? null : () {
                                 Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => const PharmacyFinderPage(),
                                      ),
                                    );
                              }, 
                              icon: const Icon(Icons.map), 
                              label: const Text('Find Nearby Pharmacies')
                            );
                          }
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _ExpandableMedicineSection extends StatefulWidget {
  final String extractedName;
  final String extractedSubtitle;
  final List<Medicine> matches;

  const _ExpandableMedicineSection({
    required this.extractedName,
    required this.extractedSubtitle,
    required this.matches,
  });

  @override
  State<_ExpandableMedicineSection> createState() => _ExpandableMedicineSectionState();
}

class _ExpandableMedicineSectionState extends State<_ExpandableMedicineSection> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    // Relevance sort is already done in Repository.
    // Determine cutoff
    final limit = 5;
    final hasMore = widget.matches.length > limit;
    
    final displayList = _showAll ? widget.matches : widget.matches.take(limit).toList();

    return ExpansionTile(
      initiallyExpanded: true,
      leading: const Icon(Icons.assignment),
      title: Text(widget.extractedName, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(widget.extractedSubtitle),
      children: [
        if (widget.matches.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No matches found in database.', style: TextStyle(color: Colors.red)),
          )
        else ...[
          ...displayList.map((match) => _MedicineMatchTile(match: match)),
          
          if (hasMore)
            TextButton(
              onPressed: () {
                setState(() {
                  _showAll = !_showAll;
                });
              },
              child: Text(_showAll ? 'Show Less' : 'See More (${widget.matches.length - limit} more)'),
            )
        ]
      ],
    );
  }
}

class _MedicineMatchTile extends ConsumerWidget {
  final Medicine match;

  const _MedicineMatchTile({required this.match});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final inCart = cart.any((element) => element.medicine.id == match.id);

    return ListTile(
      leading: Checkbox(
        value: inCart,
        onChanged: (val) {
          if (val == true) {
            // Show quantity dialog when adding
            _showQuantityDialog(context, ref, match);
          } else {
            ref.read(cartProvider.notifier).removeItem(match.id);
          }
        },
      ),
      title: Text(match.name),
      subtitle: Text('${match.strength ?? ""} ${match.form ?? ""} (Generic: ${match.genericName})'),
      trailing: inCart
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, size: 16, color: Colors.green.shade700),
                  const SizedBox(width: 4),
                  Text(
                    cart.firstWhere((e) => e.medicine.id == match.id).quantityDisplay,
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          : TextButton(
              onPressed: () => _showQuantityDialog(context, ref, match),
              child: const Text('Add'),
            ),
      onTap: () {
        if (!inCart) {
          _showQuantityDialog(context, ref, match);
        }
      },
    );
  }

  void _showQuantityDialog(BuildContext context, WidgetRef ref, Medicine medicine) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AddToCartSheet(medicine: medicine),
    );
  }
}

class _AddToCartSheet extends ConsumerStatefulWidget {
  final Medicine medicine;

  const _AddToCartSheet({required this.medicine});

  @override
  ConsumerState<_AddToCartSheet> createState() => _AddToCartSheetState();
}

class _AddToCartSheetState extends ConsumerState<_AddToCartSheet> {
  late int _quantity;
  late MedicineUnit _selectedUnit;
  late List<MedicineUnit> _availableUnits;

  @override
  void initState() {
    super.initState();
    _quantity = 1;
    _availableUnits = MedicineUnit.getUnitsForForm(widget.medicine.form);
    _selectedUnit = _availableUnits.isNotEmpty ? _availableUnits.first : MedicineUnit.strip;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
          
          // Medicine info
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.medication, color: Colors.blue.shade700, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.medicine.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${widget.medicine.form ?? ""} ${widget.medicine.strength ?? ""}'.trim(),
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          const Text(
            'Select Unit Type',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 12),
          
          // Unit type chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableUnits.map((unit) {
              final isSelected = unit == _selectedUnit;
              return ChoiceChip(
                label: Text(unit.fullName),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedUnit = unit);
                  }
                },
                selectedColor: Colors.blue.shade100,
              );
            }).toList(),
          ),
          
          const SizedBox(height: 24),
          const Text(
            'Quantity',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 12),
          
          // Quantity selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filled(
                onPressed: _quantity > 1
                    ? () => setState(() => _quantity--)
                    : null,
                icon: const Icon(Icons.remove),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.black87,
                ),
              ),
              const SizedBox(width: 24),
              Text(
                '$_quantity',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 24),
              IconButton.filled(
                onPressed: () => setState(() => _quantity++),
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          
          // Quick quantity buttons
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [1, 2, 3, 5, 10].map((qty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ActionChip(
                  label: Text('$qty'),
                  onPressed: () => setState(() => _quantity = qty),
                  backgroundColor: _quantity == qty ? Colors.blue.shade100 : null,
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 24),
          
          // Add to cart button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ref.read(cartProvider.notifier).addItem(
                  widget.medicine,
                  quantity: _quantity,
                  unit: _selectedUnit,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Added $_quantity ${_selectedUnit.displayName}(s) of ${widget.medicine.name}'),
                    duration: const Duration(seconds: 2),
                    action: SnackBarAction(
                      label: 'View Cart',
                      onPressed: () {
                        // Navigate to cart if needed
                      },
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Add to Cart: $_quantity ${_selectedUnit.displayName}${_quantity > 1 ? "s" : ""}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
