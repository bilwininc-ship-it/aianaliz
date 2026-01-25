import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/user_service.dart';

class LanguageProvider extends ChangeNotifier {
  final UserService _userService = UserService();
  Locale _locale = const Locale('tr', 'TR'); // Varsayılan Türkçe
  
  Locale get locale => _locale;
  
  /// Uygulama başlarken dil yükle (SharedPreferences'dan)
  /// Firebase senkronizasyonu için loadLanguageWithUser() kullanın
  Future<void> loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language_code') ?? 'tr';
    final countryCode = prefs.getString('country_code') ?? 'TR';
    _locale = Locale(languageCode, countryCode);
    notifyListeners();
    debugPrint('✅ Dil yüklendi (SharedPreferences): $languageCode');
  }
  
  /// Kullanıcı giriş yaptıktan sonra Firebase'den dil yükle
  Future<void> loadLanguageWithUser(String userId) async {
    try {
      // Önce SharedPreferences'dan yükle (hızlı)
      await loadLanguage();
      
      // Sonra Firebase'den kontrol et ve senkronize et
      final user = await _userService.getUser(userId);
      if (user != null && user.preferredLanguage.isNotEmpty) {
        final firebaseLang = user.preferredLanguage;
        final currentLang = _locale.languageCode;
        
        // Firebase'deki dil ile local dil farklıysa Firebase'i önceliklendir
        if (firebaseLang != currentLang) {
          debugPrint('🔄 Firebase\'den farklı dil tespit edildi: $firebaseLang');
          await syncLanguageFromFirebase(firebaseLang);
        } else {
          debugPrint('✅ Dil senkron: $currentLang');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Firebase dil yükleme hatası: $e');
    }
  }
  
  /// Dil değiştir ve kaydet (SharedPreferences + Firebase)
  Future<void> changeLanguage(String languageCode, String countryCode, {String? userId}) async {
    _locale = Locale(languageCode, countryCode);
    
    // SharedPreferences'a kaydet
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', languageCode);
    await prefs.setString('country_code', countryCode);
    
    // Firebase'e kaydet (eğer userId varsa)
    if (userId != null) {
      await _userService.updateUserLanguage(userId, languageCode);
    }
    
    notifyListeners();
    debugPrint('✅ Dil değiştirildi ve senkronize edildi: $languageCode');
  }
  
  /// Firebase'den dil yükle ve uygula
  Future<void> syncLanguageFromFirebase(String? languageCode) async {
    if (languageCode == null || languageCode.isEmpty) return;
    
    final countryCode = languageCode == 'tr' ? 'TR' : 'US';
    _locale = Locale(languageCode, countryCode);
    
    // SharedPreferences'a da kaydet
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', languageCode);
    await prefs.setString('country_code', countryCode);
    
    notifyListeners();
    debugPrint('✅ Firebase\'den dil senkronize edildi: $languageCode');
  }
  
  /// Türkçe mi?
  bool get isTurkish => _locale.languageCode == 'tr';
  
  /// İngilizce mi?
  bool get isEnglish => _locale.languageCode == 'en';
  
  /// Dil kodu (API istekleri için)
  String get languageCode => _locale.languageCode;
}