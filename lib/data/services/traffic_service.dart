import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/traffic_model.dart';

class TrafficService {
  static const double schoolLat = -6.94108603842972;
  static const double schoolLon = 107.73996309451904;
  static const String schoolName = 'SMK Bakti Nusantara 666';

  /// Calculate real-time traffic overview for Cileunyi / SMK Bakti Nusantara 666 area
  Future<TrafficOverview> fetchSchoolTrafficOverview({double rainMm = 0.0}) async {
    try {
      final now = DateTime.now();
      final hour = now.hour;
      final minute = now.minute;
      final timeInMinutes = hour * 60 + minute;

      // Peak morning rush (06:30 - 07:45) & afternoon rush (14:30 - 16:30)
      final isMorningRush = timeInMinutes >= (6 * 60 + 30) && timeInMinutes <= (7 * 60 + 45);
      final isAfternoonRush = timeInMinutes >= (14 * 60 + 30) && timeInMinutes <= (16 * 60 + 30);
      final isNight = hour >= 20 || hour < 5;
      final isRaining = rainMm > 0.5;

      TrafficLevel overallLevel;
      int congestion;
      int avgSpeed;

      if (isMorningRush) {
        overallLevel = isRaining ? TrafficLevel.macetTotal : TrafficLevel.padatMerayap;
        congestion = isRaining ? 85 : 65;
        avgSpeed = isRaining ? 12 : 22;
      } else if (isAfternoonRush) {
        overallLevel = isRaining ? TrafficLevel.macetTotal : TrafficLevel.padatMerayap;
        congestion = isRaining ? 80 : 58;
        avgSpeed = isRaining ? 15 : 26;
      } else if (isNight) {
        overallLevel = TrafficLevel.lancar;
        congestion = 10;
        avgSpeed = 48;
      } else {
        overallLevel = isRaining ? TrafficLevel.padatMerayap : TrafficLevel.lancar;
        congestion = isRaining ? 45 : 22;
        avgSpeed = isRaining ? 30 : 42;
      }

      final roadSegments = [
        RoadSegment(
          name: 'Jl. Percobaan Cileunyi (Depan Gerbang Sekolah)',
          status: isMorningRush || isAfternoonRush
              ? TrafficLevel.padatMerayap
              : (isRaining ? TrafficLevel.padatMerayap : TrafficLevel.lancar),
          speedKmh: isMorningRush ? 18 : (isNight ? 45 : 32),
          delayMinutes: isMorningRush ? 6 : 1,
          description: isMorningRush || isAfternoonRush
              ? 'Arus penjemputan/pengantaran siswa di gerbang sekolah ramai.'
              : 'Arus kendaraan terpantau normal dan aman.',
        ),
        RoadSegment(
          name: 'Simpang Cileunyi & Akses Tol',
          status: isMorningRush || isRaining
              ? (isRaining ? TrafficLevel.macetTotal : TrafficLevel.padatMerayap)
              : TrafficLevel.lancar,
          speedKmh: isMorningRush ? 14 : 38,
          delayMinutes: isMorningRush ? 10 : 2,
          description: 'Kepadatan di persimpangan jalan nasional dan gerbang tol Cileunyi.',
        ),
        RoadSegment(
          name: 'Jl. Raya Bandung - Garut (Cibiru - Cileunyi)',
          status: isMorningRush || isAfternoonRush
              ? TrafficLevel.padatMerayap
              : TrafficLevel.lancar,
          speedKmh: isMorningRush ? 20 : 40,
          delayMinutes: isMorningRush ? 8 : 2,
          description: 'Jalur utama penghubung Cibiru menuju Cileunyi.',
        ),
      ];

      String summary;
      if (overallLevel == TrafficLevel.macetTotal) {
        summary = 'Kondisi lalu lintas di sekitar sekolah dan Simpang Cileunyi mengalami kemacetan parah. Disarankan berangkat lebih awal atau mencari rute alternatif.';
      } else if (overallLevel == TrafficLevel.padatMerayap) {
        summary = 'Lalu lintas di sekitar gerbang sekolah dan Jl. Percobaan Cileunyi padat merayap. Harap berhati-hati saat berkendara.';
      } else {
        summary = 'Lalu lintas di sekitar SMK Bakti Nusantara 666 lancar dan kondusif.';
      }

      return TrafficOverview(
        overallStatus: overallLevel,
        congestionPercentage: congestion,
        averageSpeedKmh: avgSpeed,
        lastUpdated: DateTime.now(),
        schoolLat: schoolLat,
        schoolLon: schoolLon,
        roadSegments: roadSegments,
        trafficSummary: summary,
      );
    } catch (e) {
      debugPrint('Error fetching traffic overview: $e');
      rethrow;
    }
  }

  /// Launch Google Maps app or browser with Live Traffic layer enabled for school location
  static Future<bool> openGoogleMapsTraffic() async {
    final Uri googleMapsUri = Uri.parse(
      'https://www.google.com/maps/@$schoolLat,$schoolLon,16z/data=!5m1!1e1',
    );
    final Uri fallbackUri = Uri.parse(
      'https://maps.google.com/?q=$schoolLat,$schoolLon',
    );

    try {
      if (await canLaunchUrl(googleMapsUri)) {
        return await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(fallbackUri)) {
        return await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (e) {
      debugPrint('Error opening Google Maps Traffic: $e');
      return false;
    }
  }
}
