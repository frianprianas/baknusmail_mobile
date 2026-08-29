import 'package:flutter/material.dart';

class HourlyForecast {
  final DateTime time;
  final double temperature;
  final int weatherCode;
  final int rainProbability;
  final double uvIndex;

  HourlyForecast({
    required this.time,
    required this.temperature,
    required this.weatherCode,
    required this.rainProbability,
    required this.uvIndex,
  });

  factory HourlyForecast.fromJson(
      DateTime time, double temp, int code, int rainProb, double uv) {
    return HourlyForecast(
      time: time,
      temperature: temp,
      weatherCode: code,
      rainProbability: rainProb,
      uvIndex: uv,
    );
  }
}

class WeatherData {
  final double temperature;
  final double apparentTemperature;
  final int humidity;
  final double windSpeed;
  final int weatherCode;
  final bool isDay;
  final double uvIndex;
  final double precipitation;
  final DateTime updatedAt;
  final String locationName;
  final double latitude;
  final double longitude;
  final List<HourlyForecast> hourlyForecast;

  WeatherData({
    required this.temperature,
    required this.apparentTemperature,
    required this.humidity,
    required this.windSpeed,
    required this.weatherCode,
    required this.isDay,
    required this.updatedAt,
    this.uvIndex = 0.0,
    this.precipitation = 0.0,
    this.locationName = 'SMK Bakti Nusantara 666 (Cileunyi)',
    this.latitude = -6.94108603842972,
    this.longitude = 107.73996309451904,
    this.hourlyForecast = const [],
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>? ?? {};
    
    // Parse hourly forecast if available
    final List<HourlyForecast> hourlyList = [];
    final hourly = json['hourly'] as Map<String, dynamic>?;
    if (hourly != null) {
      final times = (hourly['time'] as List?)?.cast<String>() ?? [];
      final temps = (hourly['temperature_2m'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [];
      final codes = (hourly['weather_code'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [];
      final rainProbs = (hourly['precipitation_probability'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [];
      final uvs = (hourly['uv_index'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [];

      final now = DateTime.now();
      for (int i = 0; i < times.length && hourlyList.length < 12; i++) {
        final itemTime = DateTime.tryParse(times[i]);
        if (itemTime != null && itemTime.isAfter(now.subtract(const Duration(hours: 1)))) {
          hourlyList.add(HourlyForecast(
            time: itemTime,
            temperature: i < temps.length ? temps[i] : 0.0,
            weatherCode: i < codes.length ? codes[i] : 0,
            rainProbability: i < rainProbs.length ? rainProbs[i] : 0,
            uvIndex: i < uvs.length ? uvs[i] : 0.0,
          ));
        }
      }
    }

    return WeatherData(
      temperature: (current['temperature_2m'] as num?)?.toDouble() ?? 0.0,
      apparentTemperature: (current['apparent_temperature'] as num?)?.toDouble() ?? 0.0,
      humidity: (current['relative_humidity_2m'] as num?)?.toInt() ?? 0,
      windSpeed: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0.0,
      weatherCode: (current['weather_code'] as num?)?.toInt() ?? 0,
      isDay: (current['is_day'] as num?)?.toInt() == 1,
      uvIndex: (current['uv_index'] as num?)?.toDouble() ?? 0.0,
      precipitation: (current['precipitation'] as num?)?.toDouble() ?? 0.0,
      updatedAt: current['time'] != null
          ? DateTime.tryParse(current['time'].toString()) ?? DateTime.now()
          : DateTime.now(),
      locationName: 'SMK Bakti Nusantara 666 (Cileunyi)',
      latitude: -6.94108603842972,
      longitude: 107.73996309451904,
      hourlyForecast: hourlyList,
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
        return isDay ? const Color(0xFFF59E0B) : const Color(0xFF818CF8);
      case 2:
      case 3:
        return const Color(0xFF0284C7);
      case 51:
      case 53:
      case 55:
      case 61:
      case 63:
      case 65:
      case 80:
      case 81:
      case 82:
        return const Color(0xFF2563EB);
      case 95:
      case 96:
      case 99:
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF0284C7);
    }
  }
}

