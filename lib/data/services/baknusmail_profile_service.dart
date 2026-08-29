import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service integrasi foto profil dan nama pengguna BaknusMail.
///
/// Endpoint: `POST https://baknusmail.smkbn666.sch.id/api/integration/user-profile`
/// Header: `X-API-Key: BAKNUS_SECRET_INTERNAL_KEY_999`
class BaknusMailProfileService {
  static const String baseUrl =
      'https://baknusmail.smkbn666.sch.id/api/integration/user-profile';
  static const String apiKey = 'BAKNUS_SECRET_INTERNAL_KEY_999';

  /// Memperbarui profil dan foto profil pengguna BaknusMail.
  ///
  /// [email] - Email pengguna Baknus (Wajib).
  /// [displayName] - Nama baru pengguna (Opsional).
  /// [imageFile] - File foto dari ImagePicker (Opsional).
  /// [imageBytes] - Byte foto jika dari memory/FilePicker (Opsional).
  /// [avatarBase64] - String Base64 Data URI siap pakai (Opsional).
  /// [validateWithAI] - Set `true` jika ingin verifikasi via BaknusAI (Default: `false`).
  static Future<Map<String, dynamic>> updateProfile({
    required String email,
    String? displayName,
    File? imageFile,
    Uint8List? imageBytes,
    String? avatarBase64,
    bool validateWithAI = false,
  }) async {
    try {
      String? finalAvatarBase64 = avatarBase64;

      if (finalAvatarBase64 == null && imageFile != null) {
        final List<int> bytes = await imageFile.readAsBytes();
        final String base64String = base64Encode(bytes);
        finalAvatarBase64 = 'data:image/jpeg;base64,$base64String';
      } else if (finalAvatarBase64 == null && imageBytes != null) {
        final String base64String = base64Encode(imageBytes);
        finalAvatarBase64 = 'data:image/jpeg;base64,$base64String';
      }

      final Map<String, dynamic> body = {
        'email': email,
        if (displayName != null) 'displayName': displayName,
        if (finalAvatarBase64 != null) 'avatar': finalAvatarBase64,
        'validateAvatarWithAI': validateWithAI,
      };

      final response = await http
          .post(
            Uri.parse(baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'X-API-Key': apiKey,
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && responseData['success'] == true) {
        return {
          'success': true,
          'message': responseData['message'] ?? 'Profil berhasil diperbarui!',
          'user': responseData['user'],
          'avatar': finalAvatarBase64,
        };
      } else {
        return {
          'success': false,
          'error': responseData['error'] ??
              responseData['message'] ??
              'Gagal memperbarui profil (${response.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('BaknusMailProfileService error: $e');
      return {
        'success': false,
        'error': 'Terjadi kesalahan koneksi: $e',
      };
    }
  }
}
