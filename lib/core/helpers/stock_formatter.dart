/// Utility class for formatting stock quantities in pharmacy-friendly format.
/// Converts base units (pills) to readable format like "2 boxes + 3 leaflets + 7 pills"
class StockFormatter {
  /// Formats stock quantity into human-readable pharmacy format.
  /// 
  /// Example: 67 pills with 10 pills/leaflet and 3 leaflets/box = "2 boxes + 0 leaflets + 7 pills"
  /// 
  /// Parameters:
  /// - [totalBaseUnits]: Total quantity in base units (e.g., pills)
  /// - [unitType]: The base unit type (e.g., 'pill', 'ml', 'piece')
  /// - [pillsPerLeaflet]: Number of pills per leaflet (default: 10)
  /// - [leafletsPerBox]: Number of leaflets per box (default: 3)
  /// 
  /// Returns a formatted string like "2 boxes + 3 leaflets + 7 pills"
  static String format({
    required int totalBaseUnits,
    required String unitType,
    int pillsPerLeaflet = 10,
    int leafletsPerBox = 3,
  }) {
    // Only apply box/leaflet breakdown for pill-based medicines
    if (unitType != 'pill' || totalBaseUnits == 0) {
      return '$totalBaseUnits ${_pluralize(totalBaseUnits, unitType)}';
    }

    final pillsPerBox = pillsPerLeaflet * leafletsPerBox;
    
    int remaining = totalBaseUnits;
    
    // Calculate boxes
    final boxes = remaining ~/ pillsPerBox;
    remaining = remaining % pillsPerBox;
    
    // Calculate leaflets
    final leaflets = remaining ~/ pillsPerLeaflet;
    remaining = remaining % pillsPerLeaflet;
    
    // Remaining pills
    final pills = remaining;

    // Build formatted string
    final parts = <String>[];
    
    if (boxes > 0) {
      parts.add('$boxes ${_pluralize(boxes, 'box')}');
    }
    if (leaflets > 0) {
      parts.add('$leaflets ${_pluralize(leaflets, 'leaflet')}');
    }
    if (pills > 0 || parts.isEmpty) {
      parts.add('$pills ${_pluralize(pills, 'pill')}');
    }

    return parts.join(' + ');
  }

  /// Formats stock with a compact display (primary + details).
  /// Returns a record with primary display and breakdown.
  static ({String primary, String breakdown}) formatDetailed({
    required int totalBaseUnits,
    required String unitType,
    int pillsPerLeaflet = 10,
    int leafletsPerBox = 3,
  }) {
    if (unitType != 'pill' || totalBaseUnits == 0) {
      return (
        primary: '$totalBaseUnits ${_pluralize(totalBaseUnits, unitType)}',
        breakdown: '',
      );
    }

    final pillsPerBox = pillsPerLeaflet * leafletsPerBox;
    
    int remaining = totalBaseUnits;
    final boxes = remaining ~/ pillsPerBox;
    remaining = remaining % pillsPerBox;
    final leaflets = remaining ~/ pillsPerLeaflet;
    remaining = remaining % pillsPerLeaflet;
    final pills = remaining;

    // Primary: Show largest unit first
    String primary;
    if (boxes > 0) {
      primary = '$boxes ${_pluralize(boxes, 'box')}';
      if (leaflets > 0 || pills > 0) {
        primary += '+';
      }
    } else if (leaflets > 0) {
      primary = '$leaflets ${_pluralize(leaflets, 'leaflet')}';
      if (pills > 0) {
        primary += '+';
      }
    } else {
      primary = '$pills ${_pluralize(pills, 'pill')}';
    }

    // Breakdown: Full detail
    final parts = <String>[];
    if (boxes > 0) parts.add('$boxes ${_pluralize(boxes, 'box')}');
    if (leaflets > 0) parts.add('$leaflets ${_pluralize(leaflets, 'leaflet')}');
    if (pills > 0) parts.add('$pills ${_pluralize(pills, 'pill')}');
    
    final breakdown = parts.join(' + ');

    return (primary: primary, breakdown: breakdown);
  }

  /// Creates a compact widget-friendly format.
  /// Returns structured data for building UI components.
  static StockBreakdown getBreakdown({
    required int totalBaseUnits,
    required String unitType,
    int pillsPerLeaflet = 10,
    int leafletsPerBox = 3,
  }) {
    if (unitType != 'pill') {
      return StockBreakdown(
        boxes: 0,
        leaflets: 0,
        pills: totalBaseUnits,
        unitType: unitType,
        pillsPerLeaflet: 1,
        leafletsPerBox: 1,
      );
    }

    final pillsPerBox = pillsPerLeaflet * leafletsPerBox;
    
    int remaining = totalBaseUnits;
    final boxes = remaining ~/ pillsPerBox;
    remaining = remaining % pillsPerBox;
    final leaflets = remaining ~/ pillsPerLeaflet;
    remaining = remaining % pillsPerLeaflet;
    final pills = remaining;

    return StockBreakdown(
      boxes: boxes,
      leaflets: leaflets,
      pills: pills,
      unitType: unitType,
      pillsPerLeaflet: pillsPerLeaflet,
      leafletsPerBox: leafletsPerBox,
    );
  }

  static String _pluralize(int count, String word) {
    if (count == 1) return word;
    
    // Handle special plurals
    switch (word) {
      case 'box':
        return 'boxes';
      case 'leaflet':
        return 'leaflets';
      case 'pill':
        return 'pills';
      case 'bottle':
        return 'bottles';
      case 'vial':
        return 'vials';
      case 'tube':
        return 'tubes';
      case 'sachet':
        return 'sachets';
      case 'piece':
        return 'pieces';
      case 'ml':
        return 'ml';
      default:
        return '${word}s';
    }
  }
}

/// Structured breakdown of stock quantities
class StockBreakdown {
  final int boxes;
  final int leaflets;
  final int pills;
  final String unitType;
  final int pillsPerLeaflet;
  final int leafletsPerBox;

  const StockBreakdown({
    required this.boxes,
    required this.leaflets,
    required this.pills,
    required this.unitType,
    required this.pillsPerLeaflet,
    required this.leafletsPerBox,
  });

  /// Total in base units
  int get totalBaseUnits {
    if (unitType != 'pill') return pills;
    return (boxes * leafletsPerBox * pillsPerLeaflet) + 
           (leaflets * pillsPerLeaflet) + 
           pills;
  }

  /// Formatted display string
  String get formatted {
    if (unitType != 'pill') {
      return '$pills ${_pluralize(pills, unitType)}';
    }

    final parts = <String>[];
    if (boxes > 0) parts.add('$boxes ${_pluralize(boxes, 'box')}');
    if (leaflets > 0) parts.add('$leaflets ${_pluralize(leaflets, 'leaflet')}');
    if (pills > 0 || parts.isEmpty) parts.add('$pills ${_pluralize(pills, 'pill')}');
    
    return parts.join(' + ');
  }

  /// Short format: "2B + 3L + 7P"
  String get shortFormat {
    if (unitType != 'pill') {
      return '$pills ${unitType.substring(0, 1).toUpperCase()}';
    }

    final parts = <String>[];
    if (boxes > 0) parts.add('${boxes}B');
    if (leaflets > 0) parts.add('${leaflets}L');
    if (pills > 0 || parts.isEmpty) parts.add('${pills}P');
    
    return parts.join('+');
  }

  static String _pluralize(int count, String word) {
    if (count == 1) return word;
    switch (word) {
      case 'box': return 'boxes';
      case 'leaflet': return 'leaflets';
      case 'pill': return 'pills';
      case 'ml': return 'ml';
      default: return '${word}s';
    }
  }
}
