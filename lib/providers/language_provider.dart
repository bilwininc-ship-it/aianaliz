import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _locale = const Locale('tr', 'TR'); // Varsayılan Türkçe
  
  Locale get locale => _locale;
  
  /// Uygulama başlarken dil yükle
  Future<void> loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language_code') ?? 'tr';
    final countryCode = prefs.getString('country_code') ?? 'TR';
    _locale = Locale(languageCode, countryCode);
    notifyListeners();
    debugPrint('✅ Dil yüklendi: $languageCode');
  }
  
  /// Dil değiştir ve kaydet
  Future<void> changeLanguage(String languageCode, String countryCode) async {
    _locale = Locale(languageCode, countryCode);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', languageCode);
    await prefs.setString('country_code', countryCode);
    
    notifyListeners();
    debugPrint('✅ Dil değiştirildi: $languageCode');
  }
  
  /// Türkçe mi?
  bool get isTurkish => _locale.languageCode == 'tr';
  
  /// İngilizce mi?
  bool get isEnglish => _locale.languageCode == 'en';
  
  /// Dil kodu (API istekleri için)
  String get languageCode => _locale.languageCode;
}
