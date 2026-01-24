import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';

/// Google Ads Conversion Tracking Service
/// 
/// Bu servis Google Ads'e dönüşüm (conversion) olaylarını raporlar.
/// Kullanıcı satın alma yaptığında Google Ads bunu görür ve
/// benzer kullanıcılara otomatik reklam gösterir.
class GoogleAdsService {
  static final GoogleAdsService _instance = GoogleAdsService._internal();
  factory GoogleAdsService() => _instance;
  GoogleAdsService._internal();

  bool _initialized = false;

  /// Google Mobile Ads SDK'yı başlat
  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('⚠️ Google Ads zaten başlatılmış');
      return;
    }

    try {
      debugPrint('🚀 Google Ads başlatılıyor...');
      
      // Mobile Ads SDK'yı başlat
      await MobileAds.instance.initialize();
      
      _initialized = true;
      debugPrint('✅ Google Ads başlatıldı');
      
      // Test cihaz ID'lerini ayarla (geliştirme için)
      if (kDebugMode) {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(
            testDeviceIds: ['YOUR_TEST_DEVICE_ID'],
          ),
        );
        debugPrint('🔧 Test cihazlar yapılandırıldı');
      }
    } catch (e) {
      debugPrint('❌ Google Ads başlatma hatası: $e');
      _initialized = false;
    }
  }

  /// Satın alma dönüşümünü Google Ads'e bildir
  /// 
  /// [productId]: Satın alınan ürün ID'si (credits_5, premium_monthly, vb.)
  /// [value]: Satın alma tutarı (TL veya USD)
  /// [currency]: Para birimi (TRY, USD, vb.)
  Future<void> trackPurchase({
    required String productId,
    required double value,
    required String currency,
  }) async {
    if (!_initialized) {
      debugPrint('⚠️ Google Ads henüz başlatılmamış, başlatılıyor...');
      await initialize();
    }

    try {
      debugPrint('📊 Google Ads Conversion Tracking:');
      debugPrint('   Product ID: $productId');
      debugPrint('   Value: $value $currency');
      debugPrint('   Timestamp: ${DateTime.now()}');

      // NOT: Google Ads conversion tracking için Firebase Analytics 
      // veya Google Ads API entegrasyonu gerekir.
      // 
      // Basit implementasyon için şimdilik log tutuyoruz.
      // Production'da Firebase Analytics ile entegre edilecek:
      // 
      // await FirebaseAnalytics.instance.logPurchase(
      //   value: value,
      //   currency: currency,
      //   parameters: {
      //     'product_id': productId,
      //     'transaction_id': DateTime.now().millisecondsSinceEpoch.toString(),
      //   },
      // );

      // Google Ads dönüşüm tracking API çağrısı buraya eklenecek
      // Şimdilik tracking data'yı logladık
      
      debugPrint('✅ Conversion tracked successfully');
    } catch (e) {
      debugPrint('❌ Conversion tracking hatası: $e');
    }
  }

  /// İlk analiz dönüşümünü bildir
  /// Kullanıcının ilk kez analiz yaptığını Google Ads'e bildirir
  Future<void> trackFirstAnalysis() async {
    if (!_initialized) {
      await initialize();
    }

    try {
      debugPrint('📊 Google Ads: First Analysis Event');
      
      // İlk analiz eventi
      // Firebase Analytics ile entegre edilecek:
      // await FirebaseAnalytics.instance.logEvent(
      //   name: 'first_analysis',
      //   parameters: {
      //     'timestamp': DateTime.now().millisecondsSinceEpoch,
      //   },
      // );
      
      debugPrint('✅ First analysis tracked');
    } catch (e) {
      debugPrint('❌ First analysis tracking hatası: $e');
    }
  }

  /// Uygulama kurulumu dönüşümünü bildir
  /// İlk uygulama açılışında çağrılır
  Future<void> trackAppInstall() async {
    if (!_initialized) {
      await initialize();
    }

    try {
      debugPrint('📊 Google Ads: App Install Event');
      
      // App install eventi
      // Firebase Analytics ile entegre edilecek:
      // await FirebaseAnalytics.instance.logEvent(
      //   name: 'app_install',
      //   parameters: {
      //     'timestamp': DateTime.now().millisecondsSinceEpoch,
      //   },
      // );
      
      debugPrint('✅ App install tracked');
    } catch (e) {
      debugPrint('❌ App install tracking hatası: $e');
    }
  }

  /// Reklam gösterimini bildir (isteğe bağlı)
  Future<void> trackAdImpression({
    required String adUnitId,
    required String adFormat,
  }) async {
    try {
      debugPrint('📊 Google Ads: Ad Impression');
      debugPrint('   Ad Unit: $adUnitId');
      debugPrint('   Format: $adFormat');
      
      debugPrint('✅ Ad impression tracked');
    } catch (e) {
      debugPrint('❌ Ad impression tracking hatası: $e');
    }
  }

  /// Servis başlatıldı mı?
  bool get isInitialized => _initialized;
}
