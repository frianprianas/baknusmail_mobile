import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/weather_model.dart';

class WeatherService {
  // Koordinat SMK Bakti Nusantara 666 (Cileunyi, Kab. Bandung)
  static const double schoolLat = -6.94108603842972;
  static const double schoolLon = 107.73996309451904;

  static const String openMeteoUrl =
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$schoolLat&longitude=$schoolLon'
      '&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m,uv_index,precipitation'
      '&hourly=temperature_2m,weather_code,precipitation_probability,uv_index'
      '&timezone=Asia%2FJakarta';

  /// Fetch real-time weather & forecast data for SMK Bakti Nusantara 666
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
      debugPrint('Error fetching Baknus weather: $e');
      rethrow;
    }
  }
}

