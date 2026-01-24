import 'package:flutter/material.dart';
import 'tr.dart';
import 'en.dart';

class AppLocalizations {
  final Locale locale;
  
  AppLocalizations(this.locale);
  
  /// Context'ten AppLocalizations'a erişim
  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }
  
  /// Delegate tanımı
  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();
  
  /// Desteklenen diller
  static const List<Locale> supportedLocales = [
    Locale('tr', 'TR'),
    Locale('en', 'US'),
  ];
  
  late Map<String, String> _localizedStrings;
  
  /// Çeviri dosyasını yükle
  Future<bool> load() async {
    if (locale.languageCode == 'tr') {
      _localizedStrings = tr;
    } else {
      _localizedStrings = en;
    }
    return true;
  }
  
  /// Çeviri metni al
  String translate(String key) {
    return _localizedStrings[key] ?? key;
  }
  
  /// Kısa kullanım için helper method
  String t(String key) => translate(key);
}

/// Localizations Delegate
class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();
  
  @override
  bool isSupported(Locale locale) {
    return ['tr', 'en'].contains(locale.languageCode);
  }
  
  @override
  Future<AppLocalizations> load(Locale locale) async {
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }
  
  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
