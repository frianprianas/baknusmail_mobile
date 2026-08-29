import 'package:flutter/material.dart';

enum TrafficLevel {
  lancar,
  padatMerayap,
  macetTotal,
}

extension TrafficLevelX on TrafficLevel {
  String get label {
    switch (this) {
      case TrafficLevel.lancar:
        return 'Lancar';
      case TrafficLevel.padatMerayap:
        return 'Padat Merayap';
      case TrafficLevel.macetTotal:
        return 'Macet Total';
    }
  }

  Color get color {
    switch (this) {
      case TrafficLevel.lancar:
        return const Color(0xFF10B981); // Green
      case TrafficLevel.padatMerayap:
        return const Color(0xFFF59E0B); // Amber
      case TrafficLevel.macetTotal:
        return const Color(0xFFEF4444); // Red
    }
  }

  IconData get icon {
    switch (this) {
      case TrafficLevel.lancar:
        return Icons.directions_car_rounded;
      case TrafficLevel.padatMerayap:
        return Icons.traffic_rounded;
      case TrafficLevel.macetTotal:
        return Icons.warning_amber_rounded;
    }
  }
}

class RoadSegment {
  final String name;
  final TrafficLevel status;
  final int speedKmh;
  final int delayMinutes;
  final String description;

  RoadSegment({
    required this.name,
    required this.status,
    required this.speedKmh,
    required this.delayMinutes,
    required this.description,
  });
}

class TrafficOverview {
  final TrafficLevel overallStatus;
  final int congestionPercentage;
  final int averageSpeedKmh;
  final DateTime lastUpdated;
  final double schoolLat;
  final double schoolLon;
  final List<RoadSegment> roadSegments;
  final String trafficSummary;

  TrafficOverview({
    required this.overallStatus,
    required this.congestionPercentage,
    required this.averageSpeedKmh,
    required this.lastUpdated,
    required this.schoolLat,
    required this.schoolLon,
    required this.roadSegments,
    required this.trafficSummary,
  });
}
