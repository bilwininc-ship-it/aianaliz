import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Firebase Analytics Service
/// 
/// Trafik, davranış, para ve reklam geliri analitiği için
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  late FirebaseAnalytics _analytics;
  bool _initialized = false;

  /// Analytics servisi başlat
  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('⚠️ Analytics zaten başlatılmış');
      return;
    }

    try {
      _analytics = FirebaseAnalytics.instance;
      _initialized = true;
      debugPrint('✅ Firebase Analytics başlatıldı');
      
      // İlk session_start eventi
      await trackSessionStart();
    } catch (e) {
      debugPrint('❌ Analytics başlatma hatası: $e');
      _initialized = false;
    }
  }

  /// 📊 TRAFIK: Session Start (Uygulama açılışı)
  Future<void> trackSessionStart() async {
    if (!_initialized) return;
    
    try {
      await _analytics.logEvent(
        name: 'session_start',
        parameters: {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      debugPrint('📊 Session start tracked');
    } catch (e) {
      debugPrint('❌ Session start tracking hatası: $e');
    }
  }

  /// 💰 PARA: Purchase Success (Satın alma başarılı)
  Future<void> trackPurchaseSuccess({
    required String productId,
    required double value,
    required String currency,
    required String transactionId,
  }) async {
    if (!_initialized) return;
    
    try {
      await _analytics.logPurchase(
        value: value,
        currency: currency,
        parameters: {
          'product_id': productId,
          'transaction_id': transactionId,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      debugPrint('💰 Purchase tracked: $productId - $value $currency');
    } catch (e) {
      debugPrint('❌ Purchase tracking hatası: $e');
    }
  }

  /// 💵 REKLAM GELİRİ: Ad Revenue SDK Track
  /// AdMob reklamlarından gelen geliri Firebase'e aktarır
  Future<void> trackAdRevenue({
    required String adUnitId,
    required String adFormat, // 'rewarded', 'interstitial', 'banner'
    required double value,
    required String currency,
    String? adSourceName,
  }) async {
    if (!_initialized) return;
    
    try {
      await _analytics.logEvent(
        name: 'ad_impression',
        parameters: {
          'ad_platform': 'AdMob',
          'ad_source': adSourceName ?? 'AdMob',
          'ad_format': adFormat,
          'ad_unit_name': adUnitId,
          'currency': currency,
          'value': value,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      debugPrint('💵 Ad Revenue tracked: $adFormat - $value $currency');
    } catch (e) {
      debugPrint('❌ Ad revenue tracking hatası: $e');
    }
  }

  /// 📱 DAVRANIŞ: User Engagement (Ekran görüntüleme)
  Future<void> trackScreenView(String screenName) async {
    if (!_initialized) return;
    
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenName,
      );
      debugPrint('📱 Screen view tracked: $screenName');
    } catch (e) {
      debugPrint('❌ Screen view tracking hatası: $e');
    }
  }

  /// 🎬 Ödüllü reklam başarılı izleme
  Future<void> trackRewardedAdComplete({
    required String adUnitId,
    required int rewardAmount,
  }) async {
    if (!_initialized) return;
    
    try {
      await _analytics.logEvent(
        name: 'rewarded_ad_complete',
        parameters: {
          'ad_unit_id': adUnitId,
          'reward_amount': rewardAmount,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      debugPrint('🎬 Rewarded ad complete tracked');
    } catch (e) {
      debugPrint('❌ Rewarded ad tracking hatası: $e');
    }
  }

  /// 📉 Reklam yüklenme başarısızlığı
  Future<void> trackAdLoadFailed({
    required String adFormat,
    required String errorCode,
    required String errorMessage,
  }) async {
    if (!_initialized) return;
    
    try {
      await _analytics.logEvent(
        name: 'ad_load_failed',
        parameters: {
          'ad_format': adFormat,
          'error_code': errorCode,
          'error_message': errorMessage,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
      debugPrint('📉 Ad load failed tracked: $adFormat - $errorCode');
    } catch (e) {
      debugPrint('❌ Ad load failed tracking hatası: $e');
    }
  }

  /// Custom event tracking
  Future<void> trackCustomEvent({
    required String eventName,
    Map<String, dynamic>? parameters,
  }) async {
    if (!_initialized) return;
    
    try {
      await _analytics.logEvent(
        name: eventName,
        parameters: parameters,
      );
      debugPrint('📊 Custom event tracked: $eventName');
    } catch (e) {
      debugPrint('❌ Custom event tracking hatası: $e');
    }
  }

  /// User ID ayarla (login sonrası)
  Future<void> setUserId(String userId) async {
    if (!_initialized) return;
    
    try {
      await _analytics.setUserId(id: userId);
      debugPrint('👤 User ID set: $userId');
    } catch (e) {
      debugPrint('❌ User ID set hatası: $e');
    }
  }

  /// User property ayarla
  Future<void> setUserProperty({
    required String name,
    required String value,
  }) async {
    if (!_initialized) return;
    
    try {
      await _analytics.setUserProperty(name: name, value: value);
      debugPrint('🏷️ User property set: $name = $value');
    } catch (e) {
      debugPrint('❌ User property set hatası: $e');
    }
  }

  /// Analytics instance'ı dışarı aç (gerekirse)
  FirebaseAnalytics get analytics => _analytics;
  
  /// Servsi başlatıldı mı?
  bool get isInitialized => _initialized;
}
