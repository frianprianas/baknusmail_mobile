import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service Validasi Foto Profil BaknusAI di sisi Client (Flutter)
/// Memanfaat Google Gemini 1.5 Flash Vision API.
class BaknusAIClientService {
  /// Membaca API Key dari environment variables (--dart-define / env.json)
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  static const String _geminiEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  /// Validasi foto profil menggunakan Gemini Vision API di sisi Client
  static Future<Map<String, dynamic>> validateProfilePhoto({
    required String base64Image,
    String? customApiKey,
  }) async {
    final activeKey = (customApiKey != null && customApiKey.isNotEmpty)
        ? customApiKey
        : geminiApiKey;

    if (activeKey.isEmpty || activeKey.contains('MASUKKAN_')) {
      return {
        'isApproved': false,
        'reason':
            'API Key Gemini belum diatur di file env.json / .env. Silakan isi GEMINI_API_KEY terlebih dahulu.',
      };
    }

    try {
      String cleanBase64 = base64Image;
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',').last;
      }

      final url = Uri.parse('$_geminiEndpoint?key=$activeKey');

      final payload = {
        "contents": [
          {
            "parts": [
              {
                "text":
                    "Apakah gambar ini mengandung foto wajah/pasfoto manusia yang jelas dan pantas dijadikan foto profil sekolah/instansi? "
                    "Jawab HANYA dengan format JSON persis seperti ini: "
                    "{\"isApproved\": true/false, \"reason\": \"Alasan singkat dalam bahasa Indonesia\"}"
              },
              {
                "inline_data": {
                  "mime_type": "image/jpeg",
                  "data": cleanBase64,
                }
              }
            ]
          }
        ],
        "generationConfig": {
          "response_mime_type": "application/json",
        }
      };

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        final String textResponse =
            data?['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '{}';

        final Map<String, dynamic> resultJson = jsonDecode(textResponse);

        return {
          'isApproved': resultJson['isApproved'] ?? false,
          'reason': resultJson['reason'] ?? 'Foto tidak memenuhi syarat.',
        };
      } else {
        return {
          'isApproved': false,
          'reason': 'Gagal verifikasi AI di client (${response.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('BaknusAI Client Validation Error: $e');
      return {
        'isApproved': false,
        'reason': 'Terjadi kesalahan koneksi AI: $e',
      };
    }
  }
}
