import 'package:flutter/foundation.dart';
import '../data/models/baknus_service_models.dart';
import '../data/services/baknus_api_service.dart';

class BaknusProvider extends ChangeNotifier {
  final BaknusApiService _apiService;

  BaknusAttendData? _attendData;
  BaknusTalimData? _talimData;
  BaknusDriveData? _driveData;

  bool _isLoading = false;
  String? _currentUserEmail;

  BaknusProvider(this._apiService);

  BaknusAttendData? get attendData => _attendData;
  BaknusTalimData? get talimData => _talimData;
  BaknusDriveData? get driveData => _driveData;
  bool get isLoading => _isLoading;

  String get userRole {
    if (_attendData != null && _attendData!.role.isNotEmpty) {
      return _attendData!.role;
    }
    if (_driveData != null && _driveData!.role.isNotEmpty) {
      return _driveData!.role;
    }
    if (_talimData != null && _talimData!.role.isNotEmpty) {
      return _talimData!.role;
    }
    return 'Siswa / Civitas';
  }

  Future<void> loadAllStats(String email) async {
    if (email.isEmpty) return;
    _currentUserEmail = email;
    _isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiService.fetchAttendStats(email),
        _apiService.fetchTalimStats(email),
        _apiService.fetchDriveStats(email),
      ]);

      _attendData = results[0] as BaknusAttendData?;
      _talimData = results[1] as BaknusTalimData?;
      _driveData = results[2] as BaknusDriveData?;
    } catch (e) {
      debugPrint('Error loading Baknus stats: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (_currentUserEmail != null) {
      await loadAllStats(_currentUserEmail!);
    }
  }
}
