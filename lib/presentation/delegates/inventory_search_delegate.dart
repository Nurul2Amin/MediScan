import 'package:flutter/material.dart';
import 'package:prescription_scanner/data/models/inventory_summary.dart';

class InventorySearchDelegate extends SearchDelegate<InventorySummary?> {
  final List<InventorySummary> inventory;
  InventorySearchDelegate(this.inventory);

  @override
  List<Widget>? buildActions(BuildContext context) => [
    if (query.isNotEmpty) IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear)),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(onPressed: () => close(context, null), icon: const Icon(Icons.arrow_back));

  @override
  Widget buildResults(BuildContext context) => _buildList();

  @override
  Widget buildSuggestions(BuildContext context) => _buildList();

  Widget _buildList() {
    final results = query.isEmpty 
        ? inventory 
        : inventory.where((item) => item.medicineName.toLowerCase().contains(query.toLowerCase())).toList();

    if (results.isEmpty) return const Center(child: Text("No items found"));

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final item = results[index];
        // Build form/strength info
        final details = [
          if (item.form != null && item.form!.isNotEmpty) item.form,
          if (item.strength != null && item.strength!.isNotEmpty) item.strength,
        ].join(' ');
        
        return ListTile(
          title: Text(
            item.medicineName,
            style: const TextStyle(fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            'Stock: ${item.totalBaseUnits} ${item.unitType}s',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (details.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxWidth: 90),
                  child: Text(
                    details,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (item.isLowStock) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('LOW', style: TextStyle(color: Colors.white, fontSize: 10)),
                ),
              ],
            ],
          ),
          onTap: () => close(context, item),
        );
      },
    );
  }
}
