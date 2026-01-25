import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './remote_config_service.dart';

/// Interstitial Ad Service
/// 
/// Geçmiş (History) ekranı için reklam servisi.
/// Kullanıcı ücretsiz üyeyse ve son X saat içinde reklam izlemediyse gösterilir.
/// ⚡ KULLANICI DOSTU: Ekran açılışında değil, detay tıklamasında gösterilir.
class InterstitialAdService {
  static final InterstitialAdService _instance = InterstitialAdService._internal();
  factory InterstitialAdService() => _instance;
  InterstitialAdService._internal();

  final RemoteConfigService _remoteConfig = RemoteConfigService();
  
  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;
  bool _isLoading = false;

  // Callbacks
  Function()? onAdLoaded;
  Function()? onAdFailedToLoad;
  Function()? onAdShown;
  Function()? onAdClosed;
  Function(String)? onError;

  /// Kullanıcı reklam görebilir mi? (Remote Config'den threshold kontrolü)
  Future<bool> canShowHistoryAd() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastShowTime = prefs.getInt('last_history_ad_time') ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      
      // ✅ Remote Config'den threshold süresini al (saat cinsinden)
      final thresholdHours = _remoteConfig.historyAdThresholdHours;
      final thresholdPeriod = thresholdHours * 3600000; // Saat -> milisaniye
      
      debugPrint('⏰ History Ad Threshold: $thresholdHours saat');
      
      return (currentTime - lastShowTime) >= thresholdPeriod;
    } catch (e) {
      debugPrint('❌ History ad threshold kontrolü hatası: $e');
      return false;
    }
  }

  /// Kalan süre
  Future<Duration> getRemainingTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastShowTime = prefs.getInt('last_history_ad_time') ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      
      final thresholdHours = _remoteConfig.historyAdThresholdHours;
      final thresholdPeriod = thresholdHours * 3600000;
      
      final elapsed = currentTime - lastShowTime;
      final remaining = thresholdPeriod - elapsed;
      
      if (remaining <= 0) {
        return Duration.zero;
      }
      
      return Duration(milliseconds: remaining);
    } catch (e) {
      debugPrint('❌ Kalan süre hesaplama hatası: $e');
      return Duration.zero;
    }
  }

  /// Interstitial reklamı yükle
  Future<void> loadAd() async {
    if (_isLoading || _isAdLoaded) {
      debugPrint('⚠️ Reklam zaten yükleniyor veya yüklenmiş');
      return;
    }

    _isLoading = true;

    try {
      // Test Ad Unit ID (geliştirme için)
      String adUnitId = 'ca-app-pub-3940256099942544/1033173712'; // Test Interstitial ID
      
      // Remote Config'den gerçek ID al (production'da)
      final remoteAdUnit = _remoteConfig.admobInterstitialAdUnit;
      if (remoteAdUnit.isNotEmpty && !remoteAdUnit.contains('~')) {
        adUnitId = remoteAdUnit;
        debugPrint('✅ Remote Config Interstitial Ad Unit kullanılıyor');
      } else {
        debugPrint('🔧 Test Interstitial Ad Unit kullanılıyor');
      }

      await InterstitialAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            _isAdLoaded = true;
            _isLoading = false;
            debugPrint('✅ Interstitial reklam yüklendi');
            onAdLoaded?.call();
            _setupAdCallbacks();
          },
          onAdFailedToLoad: (error) {
            _isLoading = false;
            _isAdLoaded = false;
            debugPrint('❌ Interstitial reklam yükleme hatası: $error');
            onAdFailedToLoad?.call();
            // ⚡ HATA YÖNETİMİ: Kullanıcıyı bekletme, devam et
            onError?.call('Reklam yüklenemedi (kullanıcı etkilenmez)');
          },
        ),
      );
    } catch (e) {
      _isLoading = false;
      _isAdLoaded = false;
      debugPrint('❌ Reklam yükleme hatası: $e');
      onError?.call('Reklam yükleme hatası: $e');
    }
  }

  /// Reklam callback'lerini ayarla
  void _setupAdCallbacks() {
    if (_interstitialAd == null) return;

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('📺 Interstitial reklam gösterildi');
        onAdShown?.call();
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('✅ Interstitial reklam kapatıldı');
        _isAdLoaded = false;
        ad.dispose();
        _interstitialAd = null;
        onAdClosed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('❌ Interstitial reklam gösterim hatası: $error');
        _isAdLoaded = false;
        ad.dispose();
        _interstitialAd = null;
        onError?.call('Reklam gösterilemedi');
      },
    );
  }

  /// Interstitial reklamı göster
  /// ⚡ FAIL-SAFE: Reklam yüklenemezse kullanıcıyı bekletmez
  Future<bool> showAd() async {
    if (!_isAdLoaded || _interstitialAd == null) {
      debugPrint('⚠️ Interstitial reklam henüz yüklenmedi - kullanıcı devam edebilir');
      onError?.call('Reklam hazır değil (kullanıcı geçebilir)');
      return false;
    }

    // Threshold kontrolü
    final canShow = await canShowHistoryAd();
    if (!canShow) {
      debugPrint('⏰ History ad threshold dolmadı, reklam gösterilmeyecek');
      return false;
    }

    try {
      await _interstitialAd!.show();
      
      // Son gösterim zamanını kaydet
      await _saveLastShowTime();
      
      return true;
    } catch (e) {
      debugPrint('❌ Reklam gösterme hatası: $e');
      onError?.call('Reklam gösterme hatası');
      return false;
    }
  }

  /// Son gösterim zamanını kaydet
  Future<void> _saveLastShowTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'last_history_ad_time',
        DateTime.now().millisecondsSinceEpoch,
      );
      debugPrint('✅ Son history ad gösterim zamanı kaydedildi');
    } catch (e) {
      debugPrint('❌ Gösterim zamanı kaydetme hatası: $e');
    }
  }

  /// Servisi temizle
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isAdLoaded = false;
    _isLoading = false;
  }

  /// Getters
  bool get isAdLoaded => _isAdLoaded;
  bool get isLoading => _isLoading;
}
