/// Uygulama genelinde kullanılan sabit değerler
class AppConstants {
  // ❌ Constructor'ı private yap - instance oluşturulmasın
  AppConstants._();

  /// Google Play Store URL
  static const String PLAY_STORE_URL = 'https://play.google.com/store/apps/details?id=com.aisporanaliz.app';

  /// App Version
  static const String APP_VERSION = '1.0.0';

  /// Support Email
  static const String SUPPORT_EMAIL = 'bilwininc@gmail.com';

  /// Company Name
  static const String COMPANY_NAME = 'Bilwin.inc';

  /// App Name
  static const String APP_NAME = 'AI Spor Pro';

  /// Default Credits for new users
  static const int DEFAULT_CREDITS = 3;

  /// Maximum free analysis count
  static const int MAX_FREE_ANALYSIS = 3;
}
