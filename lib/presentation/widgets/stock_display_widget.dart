import 'package:flutter/material.dart';
import 'package:prescription_scanner/core/helpers/stock_formatter.dart';

/// A reusable widget to display stock in pharmacy-friendly format.
/// Shows breakdown like "2 boxes + 3 leaflets + 7 pills" with visual indicators.
class StockDisplayWidget extends StatelessWidget {
  final int totalBaseUnits;
  final String unitType;
  final int pillsPerLeaflet;
  final int leafletsPerBox;
  final bool showPackConfig;
  final bool compact;
  final TextStyle? textStyle;

  const StockDisplayWidget({
    super.key,
    required this.totalBaseUnits,
    required this.unitType,
    this.pillsPerLeaflet = 10,
    this.leafletsPerBox = 3,
    this.showPackConfig = true,
    this.compact = false,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final breakdown = StockFormatter.getBreakdown(
      totalBaseUnits: totalBaseUnits,
      unitType: unitType,
      pillsPerLeaflet: pillsPerLeaflet,
      leafletsPerBox: leafletsPerBox,
    );

    if (compact) {
      return _buildCompact(context, breakdown);
    }
    return _buildFull(context, breakdown);
  }

  Widget _buildCompact(BuildContext context, StockBreakdown breakdown) {
    return Text(
      breakdown.formatted,
      style: textStyle ?? Theme.of(context).textTheme.bodyMedium,
    );
  }

  Widget _buildFull(BuildContext context, StockBreakdown breakdown) {
    // For non-pill items, show simple format
    if (unitType != 'pill') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Text(
            breakdown.formatted,
            style: textStyle ?? TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    // For pills, show visual breakdown with icons
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Visual breakdown with icons
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (breakdown.boxes > 0)
              _StockChip(
                count: breakdown.boxes,
                label: 'box',
                icon: Icons.inventory_2,
                color: Colors.blue,
              ),
            if (breakdown.leaflets > 0)
              _StockChip(
                count: breakdown.leaflets,
                label: 'leaflet',
                icon: Icons.layers,
                color: Colors.green,
              ),
            if (breakdown.pills > 0 || (breakdown.boxes == 0 && breakdown.leaflets == 0))
              _StockChip(
                count: breakdown.pills,
                label: 'pill',
                icon: Icons.medication,
                color: Colors.orange,
              ),
          ],
        ),
        if (showPackConfig) ...[
          const SizedBox(height: 6),
          Text(
            'Pack: $pillsPerLeaflet pills/leaflet × $leafletsPerBox leaflets/box',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}

class _StockChip extends StatelessWidget {
  final int count;
  final String label;
  final IconData icon;
  final Color color;

  const _StockChip({
    required this.count,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            '$count ${count == 1 ? label : _pluralize(label)}',
            style: TextStyle(
              color: color.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  String _pluralize(String word) {
    switch (word) {
      case 'box':
        return 'boxes';
      case 'leaflet':
        return 'leaflets';
      case 'pill':
        return 'pills';
      default:
        return '${word}s';
    }
  }
}

/// Extension to get shade from Color
extension ColorShade on Color {
  Color get shade700 {
    final hsl = HSLColor.fromColor(this);
    return hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
  }
}

/// Card widget showing stock summary with formatted display
class StockSummaryCard extends StatelessWidget {
  final int totalBaseUnits;
  final String unitType;
  final int pillsPerLeaflet;
  final int leafletsPerBox;
  final String? title;
  final bool isLowStock;

  const StockSummaryCard({
    super.key,
    required this.totalBaseUnits,
    required this.unitType,
    this.pillsPerLeaflet = 10,
    this.leafletsPerBox = 3,
    this.title,
    this.isLowStock = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: isLowStock ? Colors.orange.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title ?? 'Current Stock',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                if (isLowStock)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'LOW STOCK',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            StockDisplayWidget(
              totalBaseUnits: totalBaseUnits,
              unitType: unitType,
              pillsPerLeaflet: pillsPerLeaflet,
              leafletsPerBox: leafletsPerBox,
            ),
            const Divider(height: 24),
            Row(
              children: [
                Icon(Icons.summarize, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  'Total: $totalBaseUnits $unitType${totalBaseUnits == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
