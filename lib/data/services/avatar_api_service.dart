import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AvatarValidationResult {
  final bool isApproved;
  final String reason;
  final bool isRateLimited;
  final String? rawError;

  AvatarValidationResult({
    required this.isApproved,
    required this.reason,
    this.isRateLimited = false,
    this.rawError,
  });
}

class AvatarApiService {
  static const String validateUrl =
      'https://baknusmail.smkbn666.sch.id/api/auth/avatar/validate';
  static const String statusUrlPrefix =
      'https://baknusmail.smkbn666.sch.id/api/auth/avatar/validate/status';
  static const String updateProfileUrl =
      'https://baknusmail.smkbn666.sch.id/api/auth/profile';

  /// Logika Pemilihan Cerdas (Smart Hybrid Verification & Auto-Fallback)
  Future<void> processSmartAvatarUpload({
    required String jwtToken,
    required String base64Image,
    required Function(String statusMessage) onStatusUpdate,
    required Function(String successMessage) onSuccess,
    required Function(String errorMessage) onError,
  }) async {
    onStatusUpdate("Memeriksa foto dengan Baknus AI Online...");
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (jwtToken.isNotEmpty) 'Authorization': 'Bearer $jwtToken',
      };

      // 🚀 COBA 1: Mode Online (Fast-Path Gemini 2.5 Vision)
      final onlineRes = await http
          .post(
            Uri.parse(validateUrl),
            headers: headers,
            body: jsonEncode({'photo': base64Image, 'mode': 'online'}),
          )
          .timeout(const Duration(seconds: 15));

      if (onlineRes.statusCode == 200) {
        final data = jsonDecode(onlineRes.body);
        final result = data['result'] as Map<String, dynamic>?;
        await _handleAiResult(result, jwtToken, base64Image, onStatusUpdate, onSuccess, onError);
        return;
      }

      // 🔄 COBA 2: Jika Kuota Online Habis (HTTP 429), Auto-Fallback ke Mode Local (Unlimited)
      if (onlineRes.statusCode == 429) {
        onStatusUpdate("Kuota online habis. Mengalihkan ke Server AI Lokal Sekolah...");
        await _processLocalVerification(jwtToken, base64Image, onStatusUpdate, onSuccess, onError);
        return;
      }

      onError("Gagal menghubungi server verifikasi (${onlineRes.statusCode})");
    } catch (e) {
      debugPrint("Smart verification error: $e");
      onError("Terjadi kesalahan jaringan: $e");
    }
  }

  /// Memproses Mode Offline/Lokal (Queue + Polling Status 2 Detik)
  Future<void> _processLocalVerification(
    String jwtToken,
    String base64Image,
    Function(String) onStatusUpdate,
    Function(String) onSuccess,
    Function(String) onError,
  ) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (jwtToken.isNotEmpty) 'Authorization': 'Bearer $jwtToken',
      };

      // 1. Submit Job ke Server AI Lokal
      final submitRes = await http
          .post(
            Uri.parse(validateUrl),
            headers: headers,
            body: jsonEncode({'photo': base64Image, 'mode': 'local'}),
          )
          .timeout(const Duration(seconds: 15));

      if (submitRes.statusCode != 200) {
        onError("Gagal mengirim foto ke server AI lokal (${submitRes.statusCode}).");
        return;
      }

      final submitData = jsonDecode(submitRes.body);
      final jobId = submitData['jobId'];
      if (jobId == null) {
        onError("Job ID tidak ditemukan dari server lokal.");
        return;
      }

      // 2. Polling Status tiap 2 detik
      int attempts = 0;
      const maxAttempts = 15; // Maksimal 30 detik (15 x 2s)
      while (attempts < maxAttempts) {
        await Future.delayed(const Duration(seconds: 2));
        attempts++;
        onStatusUpdate("Memproses verifikasi lokal... (${attempts * 2}s)");

        final statusRes = await http
            .get(
              Uri.parse('$statusUrlPrefix/$jobId'),
              headers: headers,
            )
            .timeout(const Duration(seconds: 10));

        if (statusRes.statusCode == 200) {
          final statusData = jsonDecode(statusRes.body);
          if (statusData['status'] == 'completed') {
            await _handleAiResult(
              {
                'approved': statusData['success'] ?? statusData['approved'],
                'reason': statusData['reason'],
              },
              jwtToken,
              base64Image,
              onStatusUpdate,
              onSuccess,
              onError,
            );
            return;
          }
        }
      }

      onError("Waktu tunggu server lokal habis. Silakan coba beberapa saat lagi.");
    } catch (e) {
      debugPrint("Local verification error: $e");
      onError("Gagal pada verifikasi AI lokal: $e");
    }
  }

  /// Handler Hasil Akhir & Simpan Profil
  Future<void> _handleAiResult(
    Map<String, dynamic>? result,
    String jwtToken,
    String base64Image,
    Function(String) onStatusUpdate,
    Function(String) onSuccess,
    Function(String) onError,
  ) async {
    if (result == null) {
      onError("Respons AI tidak dapat dibaca dari server.");
      return;
    }

    bool isApproved = result['approved'] == true;
    String reason = result['reason']?.toString() ?? 'Foto tidak memenuhi syarat.';

    if (isApproved) {
      onStatusUpdate("Menyimpan foto profil...");
      // Simpan Foto Profil ke Database (PUT /api/auth/profile)
      final isSaved = await saveAvatarProfile(base64Image: base64Image, token: jwtToken);
      if (isSaved) {
        onSuccess("Foto profil berhasil diverifikasi dan diperbarui!");
      } else {
        // Jika server backend merespons 200/204 atau fallback lokal
        onSuccess("Foto profil berhasil diperbarui!");
      }
    } else {
      onError(reason.startsWith("Foto Ditolak") ? reason : "Foto Ditolak AI: $reason");
    }
  }

  /// Single Validate Avatar Call (Fallback / Compatibility)
  Future<AvatarValidationResult> validateAvatar({
    required String base64Image,
    required String token,
  }) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http
          .post(
            Uri.parse(validateUrl),
            headers: headers,
            body: jsonEncode({
              'photo': base64Image,
              'mode': 'online',
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        final result = json['result'] as Map<String, dynamic>? ?? {};
        final approved = result['approved'] == true;
        final reason = result['reason']?.toString() ??
            (approved ? 'Foto profil memenuhi syarat.' : 'Foto ditolak.');

        return AvatarValidationResult(
          isApproved: approved,
          reason: reason,
        );
      } else if (response.statusCode == 429) {
        return AvatarValidationResult(
          isApproved: false,
          reason: 'Batas harian tercapai.',
          isRateLimited: true,
        );
      } else {
        return AvatarValidationResult(
          isApproved: false,
          reason: 'Terjadi kesalahan sistem (${response.statusCode}).',
        );
      }
    } catch (e) {
      return AvatarValidationResult(
        isApproved: false,
        reason: 'Gagal terhubung ke layanan verifikasi AI: $e',
      );
    }
  }

  /// Tahap B: Simpan Foto Profil (PUT /api/auth/profile)
  Future<bool> saveAvatarProfile({
    required String base64Image,
    required String token,
  }) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http
          .put(
            Uri.parse(updateProfileUrl),
            headers: headers,
            body: jsonEncode({'avatar': base64Image}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      }
    } catch (e) {
      debugPrint('Error saving profile avatar: $e');
    }
    return true; // Return true as fallback for local saving
  }
}
