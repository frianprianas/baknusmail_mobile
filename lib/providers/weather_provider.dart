import 'package:flutter/foundation.dart';
import '../data/models/weather_model.dart';
import '../data/models/traffic_model.dart';
import '../data/services/weather_service.dart';
import '../data/services/traffic_service.dart';

class WeatherProvider extends ChangeNotifier {
  final WeatherService _service;
  final TrafficService _trafficService = TrafficService();

  WeatherProvider(this._service);

  WeatherData? _weather;
  TrafficOverview? _trafficOverview;
  bool _isLoading = false;
  bool _isTrafficLoading = false;
  String? _errorMessage;
  DateTime? _lastFetchTime;

  WeatherData? get weather => _weather;
  TrafficOverview? get trafficOverview => _trafficOverview;
  bool get isLoading => _isLoading;
  bool get isTrafficLoading => _isTrafficLoading;
  String? get errorMessage => _errorMessage;
  DateTime? get lastFetchTime => _lastFetchTime;

  Future<void> fetchWeather({bool forceRefresh = false}) async {
    // Hindari refetch terlalu sering jika kurang dari 5 menit, kecuali forceRefresh
    if (!forceRefresh && _weather != null && _lastFetchTime != null) {
      final difference = DateTime.now().difference(_lastFetchTime!);
      if (difference.inMinutes < 5) {
        return;
      }
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _weather = await _service.fetchCileunyiWeather();
      _lastFetchTime = DateTime.now();
      _errorMessage = null;

      // Parallel/subsequent fetch traffic overview
      await fetchTraffic(rainMm: _weather?.precipitation ?? 0.0);
    } catch (e) {
      _errorMessage = 'Gagal memuat data cuaca & lalu lintas';
      debugPrint('WeatherProvider error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchTraffic({double rainMm = 0.0}) async {
    _isTrafficLoading = true;
    notifyListeners();

    try {
      _trafficOverview = await _trafficService.fetchSchoolTrafficOverview(rainMm: rainMm);
    } catch (e) {
      debugPrint('Error fetching traffic in provider: $e');
    } finally {
      _isTrafficLoading = false;
      notifyListeners();
    }
  }
}

