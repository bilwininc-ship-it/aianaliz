import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/user_service.dart';

class LanguageProvider extends ChangeNotifier {
  final UserService _userService = UserService();
  Locale _locale = const Locale('tr', 'TR');
  
  Locale get locale => _locale;
  
  Future<void> loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language_code') ?? 'tr';
    final countryCode = prefs.getString('country_code') ?? 'TR';
    _locale = Locale(languageCode, countryCode);
    notifyListeners();
  }
  
  Future<void> loadLanguageWithUser(String userId) async {
    try {
      await loadLanguage();
      
      final user = await _userService.getUser(userId);
      if (user != null && user.preferredLanguage.isNotEmpty) {
        final firebaseLang = user.preferredLanguage;
        final currentLang = _locale.languageCode;
        
        if (firebaseLang != currentLang) {
          await syncLanguageFromFirebase(firebaseLang);
        }
      }
    } catch (e) {
      // Silent fail
    }
  }
  
  Future<void> changeLanguage(String languageCode, String countryCode, {String? userId}) async {
    _locale = Locale(languageCode, countryCode);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', languageCode);
    await prefs.setString('country_code', countryCode);
    
    if (userId != null) {
      await _userService.updateUserLanguage(userId, languageCode);
    }
    
    notifyListeners();
  }
  
  Future<void> syncLanguageFromFirebase(String? languageCode) async {
    if (languageCode == null || languageCode.isEmpty) return;
    
    final countryCode = languageCode == 'tr' ? 'TR' : 'US';
    _locale = Locale(languageCode, countryCode);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', languageCode);
    await prefs.setString('country_code', countryCode);
    
    notifyListeners();
  }
  
  bool get isTurkish => _locale.languageCode == 'tr';
  bool get isEnglish => _locale.languageCode == 'en';
  String get languageCode => _locale.languageCode;
}
