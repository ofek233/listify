import 'package:flutter/material.dart';
import 'app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  int _selectedColorIndex = 0;
  ThemeData _currentTheme = AppTheme.lightTheme(AppTheme.availableColors[0]);

  bool get isDarkMode => _isDarkMode;
  int get selectedColorIndex => _selectedColorIndex;
  ThemeData get currentTheme => _currentTheme;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    _isDarkMode = await AppTheme.getThemeMode();
    _selectedColorIndex = await AppTheme.getSecondaryColorIndex();
    _updateTheme();
  }

  void _updateTheme() {
    final secondaryColor = AppTheme.availableColors[_selectedColorIndex];
    if (_isDarkMode) {
      _currentTheme = AppTheme.darkTheme(secondaryColor);
    } else {
      _currentTheme = AppTheme.lightTheme(secondaryColor);
    }
    notifyListeners();
  }

  Future<void> setDarkMode(bool isDarkMode) async {
    _isDarkMode = isDarkMode;
    await AppTheme.saveThemeMode(isDarkMode);
    _updateTheme();
  }

  Future<void> setSecondaryColor(int colorIndex) async {
    _selectedColorIndex = colorIndex;
    await AppTheme.saveSecondaryColor(colorIndex);
    _updateTheme();
  }
}
