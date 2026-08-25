import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/baknus_service_models.dart';

class BaknusApiService {
  static const String apiKey = 'baknus_secret_dashboard_key_2026';

  static const String attendBaseUrl =
      'https://baknusattend.smkbn666.sch.id/api/user-stats';
  static const String talimBaseUrl =
      'https://baknustalim.smkbn666.sch.id/api/user-stats';
  static const String driveBaseUrl =
      'https://baknusdrive.smkbn666.sch.id/api/user-stats';

  // 1. Fetch BaknusAttend Stats
  Future<BaknusAttendData?> fetchAttendStats(String email) async {
    try {
      final uri = Uri.parse('$attendBaseUrl?api_key=$apiKey&email=${Uri.encodeComponent(email)}');
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['data'] != null) {
          return BaknusAttendData.fromJson(json['data'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('Error fetching Attend stats: $e');
    }
    return null;
  }

  // 2. Fetch BaknusTalim Stats
  Future<BaknusTalimData?> fetchTalimStats(String email) async {
    try {
      final uri = Uri.parse('$talimBaseUrl?api_key=$apiKey&email=${Uri.encodeComponent(email)}');
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['data'] != null) {
          return BaknusTalimData.fromJson(json['data'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('Error fetching Talim stats: $e');
    }
    return null;
  }

  // 3. Fetch BaknusDrive Stats
  Future<BaknusDriveData?> fetchDriveStats(String email) async {
    try {
      final uri = Uri.parse('$driveBaseUrl?api_key=$apiKey&email=${Uri.encodeComponent(email)}');
      final response = await http.get(uri).timeout(const Duration(seconds: 6));
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['data'] != null) {
          return BaknusDriveData.fromJson(json['data'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('Error fetching Drive stats: $e');
    }
    return null;
  }

  static const String driveBackupBaseUrl = 'https://baknusdrive.smkbn666.sch.id/api/backup';

  // 4. Upload Chat Backup File
  Future<BaknusDriveBackup?> uploadBackup({
    required String email,
    required List<int> fileBytes,
    required String filename,
    String backupType = 'auto',
    int messageCount = 0,
  }) async {
    try {
      final uri = Uri.parse('$driveBackupBaseUrl/upload?api_key=$apiKey');
      final request = http.MultipartRequest('POST', uri);
      
      request.headers['X-API-KEY'] = apiKey;
      request.fields['email'] = email;
      request.fields['backup_type'] = backupType;
      request.fields['file_size'] = fileBytes.length.toString();
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

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return BaknusDriveBackup.fromJson(json['data'] as Map<String, dynamic>);
        }
      } else {
        debugPrint('Upload backup failed status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error uploading backup to BaknusDrive: $e');
    }
    return null;
  }

  // 5. List Chat Backups
  Future<List<BaknusDriveBackup>> listBackups(String email) async {
    try {
      final uri = Uri.parse('$driveBackupBaseUrl/list?api_key=$apiKey&email=${Uri.encodeComponent(email)}');
      final response = await http.get(
        uri,
        headers: {'X-API-KEY': apiKey},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final list = json['data'] as List? ?? [];
        return list
            .map((item) => BaknusDriveBackup.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      debugPrint('Error listing backups from BaknusDrive: $e');
    }
    return [];
  }

  // 6. Download Chat Backup Bytes
  Future<List<int>?> downloadBackup({
    required String email,
    required String backupId,
    String? downloadUrl,
  }) async {
    try {
      Uri uri;
      if (downloadUrl != null && downloadUrl.isNotEmpty) {
        uri = Uri.parse(downloadUrl);
        if (!uri.queryParameters.containsKey('api_key')) {
          uri = uri.replace(queryParameters: {
            ...uri.queryParameters,
            'api_key': apiKey,
            'email': email,
          });
        }
      } else {
        uri = Uri.parse('$driveBackupBaseUrl/download/$backupId?api_key=$apiKey&email=${Uri.encodeComponent(email)}');
      }

      final response = await http.get(
        uri,
        headers: {'X-API-KEY': apiKey},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      debugPrint('Error downloading backup $backupId: $e');
    }
    return null;
  }

  // 7. Delete Chat Backup
  Future<bool> deleteBackup({required String email, required String backupId}) async {
    try {
      final uri = Uri.parse('$driveBackupBaseUrl/$backupId?api_key=$apiKey&email=${Uri.encodeComponent(email)}');
      final response = await http.delete(
        uri,
        headers: {'X-API-KEY': apiKey},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['success'] == true;
      }
    } catch (e) {
      debugPrint('Error deleting backup $backupId: $e');
    }
    return false;
  }
}

