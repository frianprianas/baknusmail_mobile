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
}
