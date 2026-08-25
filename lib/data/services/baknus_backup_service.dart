import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/backup_item.dart';

class BaknusBackupService {
  static const String baseUrl = 'https://baknusdrive.smkbn666.sch.id/api/backup';
  static const String apiKey = 'baknus_secret_dashboard_key_2026';

  Map<String, String> get _defaultHeaders => {
        'X-API-KEY': apiKey,
      };

  /// A. Upload File Backup Chat (POST /api/backup/upload)
  Future<Map<String, dynamic>> uploadBackup({
    required String email,
    required File file,
    String type = 'auto',
    int messageCount = 0,
  }) async {
    final cleanEmail = email.toLowerCase().trim();
    if (cleanEmail.isEmpty) {
      return {'success': false, 'message': 'Email pengguna tidak boleh kosong'};
    }

    try {
      final uri = Uri.parse('$baseUrl/upload?api_key=$apiKey');
      final request = http.MultipartRequest('POST', uri);

      request.headers.addAll(_defaultHeaders);
      request.fields['email'] = cleanEmail;
      request.fields['backup_type'] = type;
      request.fields['message_count'] = messageCount.toString();

      final bytes = await file.readAsBytes();
      final filename = file.path.split(Platform.pathSeparator).last;

      request.files.add(
        http.MultipartFile.fromBytes(
          'backup_file',
          bytes,
          filename: filename,
        ),
      );

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return json;
      } else if (response.statusCode == 400) {
        return {
          'success': false,
          'message': json['message'] ?? 'Storage quota exceeded (Kapasitas BaknusDrive Penuh)',
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Autentikasi API Key gagal (401 Unauthorized)',
        };
      } else {
        return {
          'success': false,
          'message': json['message'] ?? 'Gagal mengunggah backup (HTTP ${response.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('Exception in uploadBackup: $e');
      return {
        'success': false,
        'message': 'Terjadi kesalahan koneksi server BaknusDrive: $e',
      };
    }
  }

  /// Upload dari byte array (Versi pendukung tanpa melempar error I/O)
  Future<Map<String, dynamic>> uploadBackupBytes({
    required String email,
    required List<int> fileBytes,
    required String filename,
    String type = 'auto',
    int messageCount = 0,
  }) async {
    final cleanEmail = email.toLowerCase().trim();
    if (cleanEmail.isEmpty) {
      return {'success': false, 'message': 'Email pengguna tidak boleh kosong'};
    }

    try {
      final uri = Uri.parse('$baseUrl/upload?api_key=$apiKey');
      final request = http.MultipartRequest('POST', uri);

      request.headers.addAll(_defaultHeaders);
      request.fields['email'] = cleanEmail;
      request.fields['backup_type'] = type;
      request.fields['message_count'] = messageCount.toString();

      request.files.add(
        http.MultipartFile.fromBytes(
          'backup_file',
          fileBytes,
          filename: filename,
        ),
      );

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return json;
      } else if (response.statusCode == 400) {
        return {
          'success': false,
          'message': json['message'] ?? 'Storage quota exceeded (Kapasitas BaknusDrive Penuh)',
        };
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Autentikasi API Key gagal (401 Unauthorized)',
        };
      } else {
        return {
          'success': false,
          'message': json['message'] ?? 'Gagal mengunggah backup (HTTP ${response.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('Exception in uploadBackupBytes: $e');
      return {
        'success': false,
        'message': 'Terjadi kesalahan koneksi server BaknusDrive: $e',
      };
    }
  }

  /// B. Ambil Riwayat Backup (GET /api/backup/list?email={user_email})
  Future<List<BackupItem>> listBackups({required String email}) async {
    final cleanEmail = email.toLowerCase().trim();
    if (cleanEmail.isEmpty) return [];

    try {
      final uri = Uri.parse('$baseUrl/list?email=${Uri.encodeComponent(cleanEmail)}&api_key=$apiKey');
      final response = await http.get(
        uri,
        headers: _defaultHeaders,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final list = json['data'] as List? ?? [];
        return list.map((item) => BackupItem.fromJson(item as Map<String, dynamic>)).toList();
      } else {
        debugPrint('listBackups status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('Exception in listBackups: $e');
    }
    return [];
  }

  /// C. Download File Backup (GET /api/backup/download/{backup_id})
  Future<File> downloadBackup({
    required String downloadUrl,
    required String savePath,
  }) async {
    try {
      Uri uri = Uri.parse(downloadUrl);
      if (!uri.queryParameters.containsKey('api_key')) {
        uri = uri.replace(queryParameters: {
          ...uri.queryParameters,
          'api_key': apiKey,
        });
      }

      final response = await http.get(
        uri,
        headers: _defaultHeaders,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final file = File(savePath);
        await file.writeAsBytes(response.bodyBytes);
        return file;
      } else {
        throw Exception('Download failed with HTTP status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Exception in downloadBackup: $e');
      rethrow;
    }
  }

  /// D. Hapus Backup (DELETE /api/backup/{backup_id}?email={user_email})
  Future<bool> deleteBackup({
    required String backupId,
    required String email,
  }) async {
    final cleanEmail = email.toLowerCase().trim();
    if (cleanEmail.isEmpty) return false;

    try {
      final uri = Uri.parse('$baseUrl/$backupId?email=${Uri.encodeComponent(cleanEmail)}&api_key=$apiKey');
      final response = await http.delete(
        uri,
        headers: _defaultHeaders,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['success'] == true;
      }
    } catch (e) {
      debugPrint('Exception in deleteBackup: $e');
    }
    return false;
  }
}
