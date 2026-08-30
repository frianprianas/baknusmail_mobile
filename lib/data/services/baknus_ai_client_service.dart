import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Service Validasi Foto Profil BaknusAI di sisi Client (Flutter)
/// Menggunakan Endpoint Aivene AI (Gemini 2.5 Flash Vision Model).
class BaknusAIClientService {
  static const int maxDailyUploads = 2;
  static const String fallbackApiKey = 'isk-bhnSFoDz8ca3eEkjIqr4QIm5kRB40c7CEeFSVyKb';

  /// Membaca API Key dari environment variables (--dart-define / env.json) dengan fallback
  static String get aiveneApiKey {
    const envKey = String.fromEnvironment('AIVENE_API_KEY', defaultValue: '');
    if (envKey.isNotEmpty && !envKey.contains('MASUKKAN_')) {
      return envKey;
    }
    const geminiEnvKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
    if (geminiEnvKey.isNotEmpty && !geminiEnvKey.contains('MASUKKAN_')) {
      return geminiEnvKey;
    }
    return fallbackApiKey;
  }

  static const String _aiveneEndpoint =
      'https://api.aivene.com/v1/chat/completions';

  /// Memeriksa apakah kuota harian perubahan foto (maks 2x per hari) masih tersedia.
  static Future<bool> canChangeAvatarToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = DateTime.now().toIso8601String().split('T').first;
      final count = prefs.getInt('baknus_avatar_change_count_$todayStr') ?? 0;
      return count < maxDailyUploads;
    } catch (_) {
      return true;
    }
  }

  /// Menambah jumlah penggunaan kuota harian setelah berhasil mengubah foto.
  static Future<void> incrementDailyAvatarCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayStr = DateTime.now().toIso8601String().split('T').first;
      final count = prefs.getInt('baknus_avatar_change_count_$todayStr') ?? 0;
      await prefs.setInt('baknus_avatar_change_count_$todayStr', count + 1);
    } catch (_) {}
  }

  /// Validasi foto profil menggunakan Aivene Gemini 2.5 Flash di sisi Client
  /// Kriteria:
  /// 1. HARUS memperlihatkan TEPAT 1 ORANG saja (dilarang foto bersama / grup).
  /// 2. DILARANG NUDE / ketelanjangan / pakaian tidak sopan.
  /// 3. DILARANG MEROKOK / VAPE.
  /// 4. DILARANG MENGACUNGKAN JARI TENGAH / gestur kasar.
  /// 5. Harus berupa foto seorang manusia (wajah/pasfoto yang jelas).
  static Future<Map<String, dynamic>> validateProfilePhoto({
    required String base64Image,
    String? customApiKey,
  }) async {
    // 1. Cek Kuota Harian (Maksimal 2x Per Hari)
    final canChange = await canChangeAvatarToday();
    if (!canChange) {
      return {
        'isApproved': false,
        'reason': 'Fasilitas perubahan foto profil belum tersedia, coba lagi nanti.',
        'isQuotaExceeded': true,
      };
    }

    final activeKey = (customApiKey != null && customApiKey.isNotEmpty)
        ? customApiKey
        : aiveneApiKey;

    if (activeKey.isEmpty) {
      return {
        'isApproved': false,
        'reason': 'Fasilitas perubahan foto profil belum tersedia, coba lagi nanti.',
      };
    }

    try {
      String imageUrl = base64Image;
      if (!imageUrl.startsWith('data:image')) {
        imageUrl = 'data:image/jpeg;base64,$imageUrl';
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
                    "Analisis foto ini dan pastikan memenuhi SEMUA kriteria berikut:\n"
                    "1. Foto HARUS memperlihatkan TEPAT 1 ORANG saja (DILARANG foto bersama / lebih dari 1 orang dalam gambar).\n"
                    "2. Foto HARUS berupa pasfoto / foto diri wajah manusia yang jelas.\n"
                    "3. DILARANG NUDE / ketelanjangan / pakaian berlebihan terbuka.\n"
                    "4. DILARANG MEROKOK atau menggunakan VAPE / rokok elektrik.\n"
                    "5. DILARANG MENGACUNGKAN JARI TENGAH atau gestur tangan kasar/tidak sopan.\n\n"
                    "Jawab HANYA dengan format JSON valid persis seperti ini (tanpa format markdown tambahan):\n"
                    "{\"isApproved\": true, \"reason\": \"Foto memenuhi syarat\"} atau "
                    "{\"isApproved\": false, \"reason\": \"Foto ditolak karena (alasan)\"}"
              },
              {
                "type": "image_url",
                "image_url": {
                  "url": imageUrl,
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

        // Bersihkan formatting markdown jika ada (misal ```json ... ```)
        if (rawContent.contains('{') && rawContent.contains('}')) {
          final firstBrace = rawContent.indexOf('{');
          final lastBrace = rawContent.lastIndexOf('}');
          rawContent = rawContent.substring(firstBrace, lastBrace + 1);
        }

        final Map<String, dynamic> resultJson = jsonDecode(rawContent);
        final bool isApproved = resultJson['isApproved'] == true;

        return {
          'isApproved': isApproved,
          'reason': resultJson['reason']?.toString() ??
              (isApproved
                  ? 'Foto memenuhi syarat'
                  : 'Fasilitas perubahan foto profil belum tersedia, coba lagi nanti.'),
        };
      } else {
        debugPrint('Aivene API Status Error: ${response.statusCode} - ${response.body}');
        return {
          'isApproved': false,
          'reason': 'Fasilitas perubahan foto profil belum tersedia, coba lagi nanti.',
        };
      }
    } catch (e) {
      debugPrint('BaknusAI Client Validation Exception: $e');
      return {
        'isApproved': false,
        'reason': 'Fasilitas perubahan foto profil belum tersedia, coba lagi nanti.',
      };
    }
  }
}
