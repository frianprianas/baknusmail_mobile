import 'package:flutter/material.dart';

class WeatherData {
  final double temperature;
  final double apparentTemperature;
  final int humidity;
  final double windSpeed;
  final int weatherCode;
  final bool isDay;
  final DateTime updatedAt;
  final String locationName;

  WeatherData({
    required this.temperature,
    required this.apparentTemperature,
    required this.humidity,
    required this.windSpeed,
    required this.weatherCode,
    required this.isDay,
    required this.updatedAt,
    this.locationName = 'Cileunyi, Kab. Bandung',
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>? ?? {};
    
    return WeatherData(
      temperature: (current['temperature_2m'] as num?)?.toDouble() ?? 0.0,
      apparentTemperature: (current['apparent_temperature'] as num?)?.toDouble() ?? 0.0,
      humidity: (current['relative_humidity_2m'] as num?)?.toInt() ?? 0,
      windSpeed: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0.0,
      weatherCode: (current['weather_code'] as num?)?.toInt() ?? 0,
      isDay: (current['is_day'] as num?)?.toInt() == 1,
      updatedAt: current['time'] != null
          ? DateTime.tryParse(current['time'].toString()) ?? DateTime.now()
          : DateTime.now(),
      locationName: 'Cileunyi, Kab. Bandung',
    );
  }

  /// Deskripsi cuaca dalam Bahasa Indonesia berdasarkan kode WMO
  String get conditionText {
    switch (weatherCode) {
      case 0:
        return isDay ? 'Cerah' : 'Cerah Berawan (Malam)';
      case 1:
        return 'Sebagian Cerah';
      case 2:
        return 'Berawan';
      case 3:
        return 'Mendung';
      case 45:
      case 48:
        return 'Berkabut';
      case 51:
      case 53:
      case 55:
        return 'Gerimis';
      case 61:
        return 'Hujan Ringan';
      case 63:
        return 'Hujan Sedang';
      case 65:
        return 'Hujan Lebat';
      case 80:
      case 81:
      case 82:
        return 'Hujan Lokal';
      case 95:
      case 96:
      case 99:
        return 'Hujan Petir';
      default:
        return 'Berawan';
    }
  }

  /// Icon cuaca Flutter Material
  IconData get conditionIcon {
    switch (weatherCode) {
      case 0:
        return isDay ? Icons.wb_sunny_rounded : Icons.nightlight_round;
      case 1:
        return isDay ? Icons.wb_cloudy_rounded : Icons.nights_stay_rounded;
      case 2:
      case 3:
        return Icons.cloud_rounded;
      case 45:
      case 48:
        return Icons.cloud_queue_rounded;
      case 51:
      case 53:
      case 55:
        return Icons.grain_rounded;
      case 61:
      case 63:
      case 65:
      case 80:
      case 81:
      case 82:
        return Icons.umbrella_rounded;
      case 95:
      case 96:
      case 99:
        return Icons.thunderstorm_rounded;
      default:
        return Icons.wb_cloudy_rounded;
    }
  }

  /// Warna aksen untuk cuaca
  Color get accentColor {
    switch (weatherCode) {
      case 0:
      case 1:
        return isDay ? const Color(0xFFF59E0B) : const Color(0xFF818CF8); // Amber or Indigo
      case 2:
      case 3:
        return const Color(0xFF0284C7); // Sky Blue
      case 51:
      case 53:
      case 55:
      case 61:
      case 63:
      case 65:
      case 80:
      case 81:
      case 82:
        return const Color(0xFF2563EB); // Blue
      case 95:
      case 96:
      case 99:
        return const Color(0xFF7C3AED); // Purple
      default:
        return const Color(0xFF0284C7);
    }
  }
}
