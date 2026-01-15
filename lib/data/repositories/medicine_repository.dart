import 'package:prescription_scanner/data/models/parsed_medicine.dart';
import 'package:prescription_scanner/data/models/medicine.dart';
import 'package:prescription_scanner/data/sources/remote/gemini_service.dart';
import 'package:prescription_scanner/data/sources/supabase/supabase_client.dart';

class MedicineRepository {
  final GeminiService _geminiService;
  final AppSupabaseClient _supabaseClient;

  MedicineRepository({
    required GeminiService geminiService,
    required AppSupabaseClient supabaseClient,
  })  : _geminiService = geminiService,
        _supabaseClient = supabaseClient;

  // Extract medicines from image
  Future<List<ParsedMedicine>> extractMedicines(String imagePath) async {
    final result = await _geminiService.extractMedicines(imagePath);
    final List<dynamic> list = result['medicines'] ?? [];
    return list.map((e) => ParsedMedicine.fromJson(e)).toList();
  }

  // Find exact matches in database with advanced filtering (Client-side)
  Future<Map<ParsedMedicine, List<Medicine>>> findMatches(List<ParsedMedicine> extracted) async {
    if (extracted.isEmpty) return {};

    // 1. Build broad search list (Names + Generic Names)
    final Set<String> searchTerms = {};
    for (var e in extracted) {
      searchTerms.add(e.name);
      if (e.genericName != null) searchTerms.add(e.genericName!);
    }

    // 2. Fetch ALL candidates from DB
    final rawData = await _supabaseClient.getMedicines(searchTerms.toList());
    final List<Medicine> candidates = rawData.map((e) => Medicine.fromJson(e)).toList();

    // 3. Match Logic
    final Map<ParsedMedicine, List<Medicine>> results = {};

    for (var item in extracted) {
      // 3a. strict Brand Name Check First
      // We look for medicines where the Name contains the scanned name (e.g. "Napa" -> "Napa", "Napa Extra")
      var brandMatches = candidates.where((c) {
        return c.name.toLowerCase().contains(item.name.toLowerCase());
      }).toList();

      List<Medicine> finalMatches;

      if (brandMatches.isNotEmpty) {
        // CASE 1: Brand Found (e.g. User scanned "Napa")
        // Return ONLY the brand matches. Ignore "Ace" even if generic matches.
        finalMatches = brandMatches;
      } else {
        // CASE 2: No Brand Found (e.g. User scanned "Paracetamol")
        // Fallback to Generic Search.
        finalMatches = candidates.where((c) {
           return item.genericName != null && 
                  c.genericName?.toLowerCase() == item.genericName!.toLowerCase();
        }).toList();
      }

      // Filter by Form (Secondary Filter)
      if (item.form != null) {
        final formMatches = finalMatches.where((c) => _isFormMatch(c.form, item.form!)).toList();
        if (formMatches.isNotEmpty) {
          finalMatches = formMatches;
        }
      }

      // Filter by Strength (Tertiary Filter)
      if (item.strength != null) {
         final strengthMatches = finalMatches.where((c) => _isStrengthMatch(c.strength, item.strength!)).toList();
          if (strengthMatches.isNotEmpty) {
            finalMatches = strengthMatches;
          }
      }

      results[item] = finalMatches;

      // 3d. Sorting (Relevance Sort)
      // 1. Exact Match on Name
      // 2. Shortest Name (Proxy for "Main Brand")
      // 3. Alphabetical
      finalMatches.sort((a, b) {
        final nameA = a.name.toLowerCase();
        final nameB = b.name.toLowerCase();
        final query = item.name.toLowerCase();

        // 1. Exact Match Priority
        final exactA = nameA == query;
        final exactB = nameB == query;
        if (exactA && !exactB) return -1;
        if (!exactA && exactB) return 1;

        // 2. Length Priority (Shorter is usually the main brand)
        if (nameA.length != nameB.length) {
          return nameA.length.compareTo(nameB.length);
        }

        // 3. Alphabetical
        return nameA.compareTo(nameB);
      });
    }

    return results;
  }

  // Search Global Medicines (for Homepage & Inventory)
  Future<List<Medicine>> searchMedicines(String query) async {
    if (query.isEmpty) return [];
    try {
      final response = await _supabaseClient.supabase
          .from('medicines')
          .select()
          .ilike('name', '%$query%')
          .limit(50); // Increased limit to allow good sorting
      
      final List<Medicine> candidates = (response as List).map((e) => Medicine.fromJson(e)).toList();

      // Client-side Sort: Exact Match > Starts With > Shorter Name > Alphabetical
      candidates.sort((a, b) {
        final nameA = a.name.toLowerCase();
        final nameB = b.name.toLowerCase();
        final q = query.toLowerCase();

        // 1. Exact Match
        final exactA = nameA == q;
        final exactB = nameB == q;
        if (exactA && !exactB) return -1;
        if (!exactA && exactB) return 1;

        // 2. Starts With
        final startA = nameA.startsWith(q);
        final startB = nameB.startsWith(q);
        if (startA && !startB) return -1;
        if (!startA && startB) return 1;

        // 3. Length (Shorter is likely the main brand)
        if (nameA.length != nameB.length) {
          return nameA.length.compareTo(nameB.length);
        }

        // 4. Alphabetical
        return nameA.compareTo(nameB);
      });

      return candidates;
    } catch (e) {
      return [];
    }
  }

  // Get Popular Medicines (Mocked by fetching first 10 for now)
  Future<List<Medicine>> getPopularMedicines() async {
    try {
      final response = await _supabaseClient.supabase
          .from('medicines')
          .select()
          .limit(10);
      return (response as List).map((e) => Medicine.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  bool _isFormMatch(String? dbForm, String parsedForm) {
    if (dbForm == null) return false;
    final d = dbForm.toLowerCase();
    final p = parsedForm.toLowerCase();
    // Simple normalization check
    return d.contains(p) || p.contains(d); 
  }

  bool _isStrengthMatch(String? dbStrength, String parsedStrength) {
      if (dbStrength == null) return false;
      // Remove spaces for comparison: "500 mg" == "500mg"
      final d = dbStrength.replaceAll(' ', '').toLowerCase();
      final p = parsedStrength.replaceAll(' ', '').toLowerCase();
      return d.contains(p) || p.contains(d);
  }
}
