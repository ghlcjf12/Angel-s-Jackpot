import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationService extends ChangeNotifier {
  String _currentLanguage = 'en'; // 'en' or 'ko'

  String get currentLanguage => _currentLanguage;
  bool get isKorean => _currentLanguage == 'ko';

  LocalizationService() {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString('language') ?? 'en';
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    _currentLanguage = languageCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', languageCode);
    notifyListeners();
  }

  void toggleLanguage() {
    setLanguage(_currentLanguage == 'en' ? 'ko' : 'en');
  }

  String translate(Map<String, String> translations) {
    return translations[_currentLanguage] ?? translations['en']!;
  }
}
