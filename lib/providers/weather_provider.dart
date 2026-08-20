import 'package:flutter/foundation.dart';
import '../data/models/weather_model.dart';
import '../data/services/weather_service.dart';

class WeatherProvider extends ChangeNotifier {
  final WeatherService _service;

  WeatherProvider(this._service);

  WeatherData? _weather;
  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastFetchTime;

  WeatherData? get weather => _weather;
  bool get isLoading => _isLoading;
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
    } catch (e) {
      _errorMessage = 'Gagal memuat data cuaca Cileunyi';
      debugPrint('WeatherProvider error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
