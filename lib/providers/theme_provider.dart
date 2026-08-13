import 'package:flutter/material.dart';
import '../data/services/storage_service.dart';

class ThemeProvider extends ChangeNotifier {
  final StorageService _storageService;
  ThemeMode _themeMode = ThemeMode.system;

  ThemeProvider(this._storageService) {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    if (_themeMode == ThemeMode.dark) return true;
    if (_themeMode == ThemeMode.light) return false;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  }

  void _loadTheme() {
    final modeStr = _storageService.getThemeMode();
    if (modeStr == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (modeStr == 'light') {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    String modeStr = 'system';
    if (mode == ThemeMode.dark) modeStr = 'dark';
    if (mode == ThemeMode.light) modeStr = 'light';
    await _storageService.setThemeMode(modeStr);
    notifyListeners();
  }
}
