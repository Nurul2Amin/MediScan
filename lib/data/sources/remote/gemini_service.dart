import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:prescription_scanner/config/env.dart';

class GeminiService {
  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent';

  Future<Map<String, dynamic>> extractMedicines(String imagePath) async {
    final apiKey = Env.geminiApiKey;
    final url = Uri.parse('$_baseUrl?key=$apiKey');

    final bytes = await File(imagePath).readAsBytes();
    final base64Image = base64Encode(bytes);

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {
            "text": "You are an expert pharmacist and OCR system. Extract medicines from the prescription image to match a database schema. Return ONLY this JSON: { 'medicines': [ { 'name': '', 'generic_name': '', 'strength': '', 'form': '' } ] } Rules: 1. 'name': Extract the exact Brand Name written. 2. 'generic_name': Infer the scientific/generic name (e.g., 'Napa' -> 'Paracetamol'). CRITICAL for matching. 3. 'strength': Combine text (e.g., '500 mg', '10 mg/5 ml'). 4. 'form': Standardize to: Tablet, Capsule, Syrup, Suspension, Gel, Cream, Injection, Drop, Suppository, Inhaler. 5. Normalize spelling (e.g. 'Azothro' -> 'Azithromycin'). 6. Ignore dosage instructions/frequency. Return JSON only."
              },
              {
                "inline_data": {
                  "mime_type": "image/jpeg",
                  "data": base64Image
                }
              }
            ]
          }
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Simplify parsing logic for the complex Gemini response structure
      // Typically: candidates[0].content.parts[0].text
      try {
        final text = data['candidates'][0]['content']['parts'][0]['text'];
        // Clean markdown code blocks if present
        final cleanText = text.replaceAll('```json', '').replaceAll('```', '').trim();
        return jsonDecode(cleanText);
      } catch (e) {
        throw Exception('Failed to parse Gemini response: $e');
      }
    } else {
      throw Exception('Failed to extract medicines: ${response.body}');
    }
  }
}
