import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/baknus_service_models.dart';

class AttendanceService {
  static const String _baseUrl = 'https://baknusattend.smkbn666.sch.id/api/user-stats';
  static const String _apiKey = 'baknus_secret_dashboard_key_2026';

  /// Mengambil data statistik & rincian absensi bulanan pengguna
  static Future<Map<String, dynamic>?> getUserAttendance({
    required String email,
    int? month,
    int? year,
  }) async {
    try {
      final queryParams = {
        'email': email.trim().toLowerCase(),
        if (month != null) 'month': month.toString(),
        if (year != null) 'year': year.toString(),
      };
      final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {
          'X-API-Key': _apiKey,
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (body['status'] == 'success' && body['data'] != null) {
          return body['data'] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getUserAttendance: $e');
      return null;
    }
  }

  /// Helper untuk mengambil data langsung sebagai model BaknusAttendData
  static Future<BaknusAttendData?> getUserAttendanceModel({
    required String email,
    int? month,
    int? year,
  }) async {
    final data = await getUserAttendance(email: email, month: month, year: year);
    if (data != null) {
      return BaknusAttendData.fromJson(data);
    }
    return null;
  }
}
