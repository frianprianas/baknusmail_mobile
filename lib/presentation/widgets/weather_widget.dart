import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/weather_provider.dart';
import '../../data/models/weather_model.dart';
import '../../data/models/traffic_model.dart';

class WeatherWidget extends StatelessWidget {
  const WeatherWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final weatherProvider = context.watch<WeatherProvider>();
    final weather = weatherProvider.weather;
    final traffic = weatherProvider.trafficOverview;
    final isLoading = weatherProvider.isLoading;
    final errorMessage = weatherProvider.errorMessage;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        // Gambar background gedung sekolah SMK Bakti Nusantara 666
        image: const DecorationImage(
          image: AssetImage('assets/images/school_building.jpg'),
          fit: BoxFit.cover,
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.18)
              : const Color(0xFF0284C7).withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: (weather?.accentColor ?? const Color(0xFF0284C7))
                .withValues(alpha: isDark ? 0.15 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.pushNamed(context, '/weather_traffic_detail');
            },
            child: Container(
              // Overlay transparan agar foto gedung sekolah terlihat jelas namun ringkas & kontras
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          const Color(0xFF0F172A).withValues(alpha: 0.80),
                          const Color(0xFF1E293B).withValues(alpha: 0.72),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.82),
                          const Color(0xFFF0F9FF).withValues(alpha: 0.75),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ==================== HEADER RINGKAS (Lokasi & Refresh) ====================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                size: 14,
                                color: weather?.accentColor ?? const Color(0xFF0284C7),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Cuaca & Lalu Lintas',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.lightTextPrimary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Live dot badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981)
                                      .withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFF10B981)
                                        .withValues(alpha: 0.4),
                                    width: 0.6,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 4,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    const Text(
                                      'REAL-TIME',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF059669),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            if (weatherProvider.lastFetchTime != null)
                              Text(
                                DateFormat('HH:mm').format(weatherProvider.lastFetchTime!),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.lightTextMuted,
                                ),
                              ),
                            const SizedBox(width: 4),
                            InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: isLoading
                                  ? null
                                  : () => weatherProvider.fetchWeather(forceRefresh: true),
                              child: Padding(
                                padding: const EdgeInsets.all(3.0),
                                child: isLoading
                                    ? SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.8,
                                          color: weather?.accentColor ?? const Color(0xFF0284C7),
                                        ),
                                      )
                                    : Icon(
                                        Icons.refresh_rounded,
                                        size: 15,
                                        color: isDark ? Colors.white70 : Colors.black54,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // ==================== CONTENT RINGKAS ====================
                    if (isLoading && weather == null)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 6.0),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    else if (errorMessage != null && weather == null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cloud_off_rounded,
                              size: 16, color: Colors.orange),
                          const SizedBox(width: 6),
                          Text(
                            errorMessage,
                            style: const TextStyle(fontSize: 11, color: Colors.orange),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () =>
                                weatherProvider.fetchWeather(forceRefresh: true),
                            child: const Text('Coba lagi',
                                style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      )
                    else if (weather != null)
                      _buildCompactWeatherBody(context, weather, traffic, isDark),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactWeatherBody(
      BuildContext context, WeatherData weather, TrafficOverview? traffic, bool isDark) {
    final trafficLevel = traffic?.overallStatus ?? TrafficLevel.lancar;

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon & Suhu Utama
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: weather.accentColor.withValues(alpha: isDark ? 0.25 : 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(
                weather.conditionIcon,
                size: 24,
                color: weather.accentColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${weather.temperature.round()}°C',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: weather.accentColor.withValues(alpha: isDark ? 0.25 : 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: weather.accentColor.withValues(alpha: 0.3),
                            width: 0.6,
                          ),
                        ),
                        child: Text(
                          weather.conditionText,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: weather.accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Indicator Traffic Badge pada Ringkasan Widget
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: trafficLevel.color.withValues(alpha: isDark ? 0.2 : 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: trafficLevel.color.withValues(alpha: 0.35),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    trafficLevel.icon,
                    size: 13,
                    color: trafficLevel.color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    trafficLevel.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: trafficLevel.color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Micro Stats Bar (Terasa, Kelembapan, Angin)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMicroStat(
                icon: Icons.thermostat_rounded,
                label: 'Terasa',
                value: '${weather.apparentTemperature.round()}°C',
                color: const Color(0xFFEF4444),
                isDark: isDark,
              ),
              _buildMicroDivider(isDark),
              _buildMicroStat(
                icon: Icons.water_drop_rounded,
                label: 'Lembap',
                value: '${weather.humidity}%',
                color: const Color(0xFF0284C7),
                isDark: isDark,
              ),
              _buildMicroDivider(isDark),
              _buildMicroStat(
                icon: Icons.air_rounded,
                label: 'Angin',
                value: '${weather.windSpeed.toStringAsFixed(1)} km/h',
                color: const Color(0xFF10B981),
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Clickable Detail Hint Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Klik untuk detail cuaca & lalu lintas sekitar sekolah ',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
            Icon(
              Icons.arrow_forward_rounded,
              size: 11,
              color: weather.accentColor,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMicroStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          '$label ',
          style: TextStyle(
            fontSize: 10,
            color: isDark
                ? AppColors.darkTextMuted
                : AppColors.lightTextMuted,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildMicroDivider(bool isDark) {
    return Container(
      height: 12,
      width: 1,
      color: isDark
          ? Colors.white.withValues(alpha: 0.15)
          : Colors.black.withValues(alpha: 0.1),
    );
  }
}

