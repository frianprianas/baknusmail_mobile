import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/weather_model.dart';

class WeatherService {
  // Koordinat Cileunyi, Kabupaten Bandung (SMK Bakti Nusantara 666)
  static const double cileunyiLat = -6.9456;
  static const double cileunyiLon = 107.7554;

  static const String openMeteoUrl =
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$cileunyiLat&longitude=$cileunyiLon'
      '&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m'
      '&timezone=Asia%2FJakarta';

  /// Fetch real-time weather data for Cileunyi, Kab. Bandung
  Future<WeatherData> fetchCileunyiWeather() async {
    try {
      final uri = Uri.parse(openMeteoUrl);
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        return WeatherData.fromJson(json);
      } else {
        throw Exception('Gagal mengambil data cuaca (HTTP ${response.statusCode})');
      }
    } catch (e) {
      debugPrint('Error fetching Cileunyi weather: $e');
      rethrow;
    }
  }
}
