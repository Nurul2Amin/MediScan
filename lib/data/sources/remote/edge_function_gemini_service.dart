import 'dart:convert';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class EdgeFunctionGeminiService {
  final SupabaseClient _supabase;

  EdgeFunctionGeminiService(this._supabase);

  /// Extract medicines from prescription image using Edge Function
  /// Compatible with existing GeminiService interface
  Future<Map<String, dynamic>> extractMedicines(String imagePath) async {
    try {
      // Read image file from local filesystem
      final file = File(imagePath);
      if (!await file.exists()) {
        throw Exception('Image file not found: $imagePath');
      }

      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Determine mime type from file extension
      final mimeType = imagePath.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';

      // Call Edge Function
      final response = await _supabase.functions.invoke(
        'ai_extract_medicines',
        body: {
          'image_base64': base64Image,
          'mime_type': mimeType,
        },
      );

      if (response.status == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        final errorData = response.data ?? 'Unknown error';
        throw Exception('Edge function error: $errorData');
      }
    } catch (e) {
      throw Exception('Failed to extract medicines: $e');
    }
  }

  /// Parse stock text using Edge Function
  Future<Map<String, dynamic>> parseStockText(String rawText) async {
    try {
      final response = await _supabase.functions.invoke(
        'ai_parse_stock_text',
        body: {
          'raw_text': rawText,
        },
      );

      if (response.status == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        final errorData = response.data ?? 'Unknown error';
        throw Exception('Edge function error: $errorData');
      }
    } catch (e) {
      throw Exception('Failed to parse stock text: $e');
    }
  }

  /// Extract pack hints from package image
  Future<Map<String, dynamic>> extractPackHint(
    String base64Image,
    String mimeType,
  ) async {
    try {
      final response = await _supabase.functions.invoke(
        'ai_extract_pack_hint',
        body: {
          'image_base64': base64Image,
          'mime_type': mimeType,
        },
      );

      if (response.status == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        final errorData = response.data ?? 'Unknown error';
        throw Exception('Edge function error: $errorData');
      }
    } catch (e) {
      throw Exception('Failed to extract pack hint: $e');
    }
  }
}
