import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  String _currentLanguage = 'English'; // Default language

  bool get isDarkMode => _isDarkMode;
  String get currentLanguage => _currentLanguage;

  Future<void> toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    await _saveThemePreference();
    notifyListeners();
  }

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    notifyListeners();
  }

  Future<void> _saveThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDarkMode', _isDarkMode);
  }

  // New method to toggle between English and Malayalam
  void toggleLanguage() {
    _currentLanguage = _currentLanguage == 'English' ? 'മലയാളം' : 'English';
    _saveLanguagePreference(); // Save language preference
    notifyListeners();
  }

  // New method to get the system theme
  ThemeMode getSystemThemeMode() {
    final brightness = WidgetsBinding.instance.window.platformBrightness;
    return brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light;
  }

  // New method to load language preference
  Future<void> loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString('currentLanguage') ?? 'English';
    notifyListeners();
  }

  // New method to save language preference
  Future<void> _saveLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('currentLanguage', _currentLanguage);
  }
}
