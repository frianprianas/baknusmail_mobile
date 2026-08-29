import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service Validasi Foto Profil BaknusAI di sisi Client (Flutter)
/// Menggunakan Endpoint Aivene AI (Gemini 2.5 Flash Vision Model).
class BaknusAIClientService {
  /// Membaca API Key dari environment variables (--dart-define / env.json)
  static const String aiveneApiKey = String.fromEnvironment(
    'AIVENE_API_KEY',
    defaultValue: String.fromEnvironment('GEMINI_API_KEY', defaultValue: ''),
  );

  static const String _aiveneEndpoint =
      'https://api.aivene.com/v1/chat/completions';

  /// Validasi foto profil menggunakan Aivene Gemini 2.5 Flash di sisi Client
  /// Kriteria:
  /// - Tidak NUDE / ketelanjangan / pakaian tidak sopan
  /// - Tidak MEROKOK / VAPE
  /// - Tidak MENGACUNGKAN JARI TENGAH / gestur kasar
  /// - Harus berupa foto seorang manusia (wajah/pasfoto yang jelas)
  static Future<Map<String, dynamic>> validateProfilePhoto({
    required String base64Image,
    String? customApiKey,
  }) async {
    final activeKey = (customApiKey != null && customApiKey.isNotEmpty)
        ? customApiKey
        : aiveneApiKey;

    if (activeKey.isEmpty || activeKey.contains('MASUKKAN_')) {
      return {
        'isApproved': false,
        'reason':
            'AIVENE_API_KEY belum diatur di file env.json / .env. Silakan isi AIVENE_API_KEY terlebih dahulu.',
      };
    }

    try {
      String cleanBase64 = base64Image;
      if (!cleanBase64.startsWith('data:image')) {
        cleanBase64 = 'data:image/jpeg;base64,$cleanBase64';
      }

      final url = Uri.parse(_aiveneEndpoint);

      final payload = {
        "model": "gemini-2.5-flash",
        "messages": [
          {
            "role": "user",
            "content": [
              {
                "type": "text",
                "text": "Anda adalah validator AI untuk foto profil instansi/sekolah BaknusMail.\n"
                    "Analisis foto ini dan pastikan memenuhi kriteria berikut:\n"
                    "1. Foto HARUS memperlihatkan seorang manusia (wajah/pasfoto diri yang jelas).\n"
                    "2. DILARANG NUDE / ketelanjangan / pakaian berlebihan terbuka.\n"
                    "3. DILARANG MEROKOK atau menggunakan VAPE / rokok elektrik.\n"
                    "4. DILARANG MENGACUNGKAN JARI TENGAH atau gestur tangan kasar/tidak sopan.\n\n"
                    "Jawab HANYA dengan format JSON valid persis seperti ini (tanpa format markdown tambahan):\n"
                    "{\"isApproved\": true, \"reason\": \"Foto memenuhi syarat\"} atau "
                    "{\"isApproved\": false, \"reason\": \"Foto ditolak karena (alasan)\"}"
              },
              {
                "type": "image_url",
                "image_url": {
                  "url": cleanBase64,
                }
              }
            ]
          }
        ],
        "temperature": 0.1,
      };

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $activeKey',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>?;
        String rawContent =
            data?['choices']?[0]?['message']?['content']?.toString() ?? '{}';

        // Bersihkan formatting ```json ... ``` jika dikembalikan oleh LLM
        rawContent = rawContent.replaceAll(RegExp(r'```json\s*'), '');
        rawContent = rawContent.replaceAll(RegExp(r'```\s*'), '');
        rawContent = rawContent.trim();

        final Map<String, dynamic> resultJson = jsonDecode(rawContent);

        return {
          'isApproved': resultJson['isApproved'] ?? false,
          'reason': resultJson['reason'] ?? 'Foto tidak memenuhi kriteria profil.',
        };
      } else {
        return {
          'isApproved': false,
          'reason': 'Gagal verifikasi AI Aivene (${response.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('BaknusAI Aivene Client Validation Error: $e');
      return {
        'isApproved': false,
        'reason': 'Terjadi kesalahan koneksi AI: $e',
      };
    }
  }
}
