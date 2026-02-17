import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppTheme {
  static const String _themeModeKey = 'themeMode';
  static const String _secondaryColorKey = 'secondaryColor';

  static final List<Color> availableColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.purple,
    Colors.orange,
    Colors.pink,
    Colors.teal,
    Colors.amber,
  ];

  static Future<void> saveThemeMode(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeModeKey, isDarkMode);
  }

  static Future<bool> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_themeModeKey) ?? false;
  }

  static Future<void> saveSecondaryColor(int colorIndex) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_secondaryColorKey, colorIndex);
  }

  static Future<int> getSecondaryColorIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_secondaryColorKey) ?? 0; // Default to blue
  }

  static ThemeData lightTheme(Color secondaryColor) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primarySwatch: Colors.blue,
      primaryColor: Colors.blue,
      secondaryHeaderColor: secondaryColor,
      colorScheme: ColorScheme.light(
        primary: Colors.blue,
        secondary: secondaryColor,
        surface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 2,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
    );
  }

  static ThemeData darkTheme(Color secondaryColor) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primarySwatch: Colors.blue,
      primaryColor: Colors.blue,
      secondaryHeaderColor: secondaryColor,
      colorScheme: ColorScheme.dark(
        primary: Colors.blue,
        secondary: secondaryColor,
        surface: Colors.grey[900]!,
      ),
      appBarTheme: AppBarTheme(
        elevation: 2,
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      scaffoldBackgroundColor: Colors.grey[900],
    );
  }
}
