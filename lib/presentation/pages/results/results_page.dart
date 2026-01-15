import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prescription_scanner/presentation/pages/pharmacy/pharmacy_finder_page.dart';
import 'package:prescription_scanner/presentation/pages/pharmacy/pharmacy_page.dart';
import 'package:prescription_scanner/presentation/providers/medicine_provider.dart';
import 'package:prescription_scanner/presentation/providers/cart_provider.dart';
import 'package:prescription_scanner/data/models/medicine.dart';

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
    final inCart = cart.any((element) => element.id == match.id);

    return CheckboxListTile(
      value: inCart,
      onChanged: (val) {
        if (val == true) {
          ref.read(cartProvider.notifier).addItem(match);
        } else {
          ref.read(cartProvider.notifier).removeItem(match.id);
        }
      },
      title: Text(match.name),
      subtitle: Text('${match.strength ?? ""} ${match.form ?? ""} (Generic: ${match.genericName})'),
      secondary: const Icon(Icons.check_circle_outline),
    );
  }
}
