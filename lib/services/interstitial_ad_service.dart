import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './remote_config_service.dart';

/// Interstitial Ad Service
/// 
/// Geçmiş (History) ekranı ve Analiz başlangıcı için reklam servisi.
/// - History: Kullanıcı ücretsiz üyeyse ve son X saat içinde reklam izlemediyse gösterilir.
/// - Analysis: Her analiz başlangıcında gösterilir (threshold kontrolü yok).
/// ⚡ KULLANICI DOSTU: Ekran açılışında değil, detay tıklamasında gösterilir.
class InterstitialAdService {
  static final InterstitialAdService _instance = InterstitialAdService._internal();
  factory InterstitialAdService() => _instance;
  InterstitialAdService._internal();

  final RemoteConfigService _remoteConfig = RemoteConfigService();
  
  // History reklamı için
  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;
  bool _isLoading = false;

  // Analiz reklamı için (ayrı instance)
  InterstitialAd? _analysisAd;
  bool _isAnalysisAdLoaded = false;
  bool _isAnalysisAdLoading = false;

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
      String adUnitId = 'ca-app-pub-6066935997419400/9631151157'; // gercek Interstitial ID
      
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
  /// ========== ANALİZ REKLAMI METODLARİ ==========
  
  /// Analiz reklamını yükle (threshold kontrolü YOK)
  Future<void> loadAnalysisAd() async {
    if (_isAnalysisAdLoading || _isAnalysisAdLoaded) {
      debugPrint('⚠️ Analiz reklamı zaten yükleniyor veya yüklenmiş');
      return;
    }

    _isAnalysisAdLoading = true;

    try {
      // Test Ad Unit ID (geliştirme için)
      String adUnitId = 'ca-app-pub-6066935997419400/9631151157'; // gercek Interstitial ID
      
      // Remote Config'den gerçek ID al (production'da)
      final remoteAdUnit = _remoteConfig.admobInterstitialAdUnit;
      if (remoteAdUnit.isNotEmpty && !remoteAdUnit.contains('~')) {
        adUnitId = remoteAdUnit;
        debugPrint('✅ Remote Config Analysis Ad Unit kullanılıyor');
      } else {
        debugPrint('🔧 Test Analysis Ad Unit kullanılıyor');
      }

      await InterstitialAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _analysisAd = ad;
            _isAnalysisAdLoaded = true;
            _isAnalysisAdLoading = false;
            debugPrint('✅ Analiz reklamı yüklendi');
            _setupAnalysisAdCallbacks();
          },
          onAdFailedToLoad: (error) {
            _isAnalysisAdLoading = false;
            _isAnalysisAdLoaded = false;
            debugPrint('❌ Analiz reklamı yükleme hatası: $error');
            // ⚡ HATA YÖNETİMİ: Kullanıcıyı bekletme, analiz devam etsin
          },
        ),
      );
    } catch (e) {
      _isAnalysisAdLoading = false;
      _isAnalysisAdLoaded = false;
      debugPrint('❌ Analiz reklamı yükleme hatası: $e');
    }
  }

  /// Analiz reklamı callback'lerini ayarla
  void _setupAnalysisAdCallbacks() {
    if (_analysisAd == null) return;

    _analysisAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('📺 Analiz reklamı gösterildi');
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('✅ Analiz reklamı kapatıldı');
        _isAnalysisAdLoaded = false;
        ad.dispose();
        _analysisAd = null;
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('❌ Analiz reklamı gösterim hatası: $error');
        _isAnalysisAdLoaded = false;
        ad.dispose();
        _analysisAd = null;
      },
    );
  }

  /// Analiz reklamını göster (threshold kontrolü YOK)
  /// ⚡ FAIL-SAFE: Reklam yüklenemezse analiz devam eder
  Future<bool> showAnalysisAd() async {
    if (!_isAnalysisAdLoaded || _analysisAd == null) {
      debugPrint('⚠️ Analiz reklamı henüz yüklenmedi - analiz devam edecek');
      return false;
    }

    try {
      await _analysisAd!.show();
      debugPrint('✅ Analiz reklamı gösterildi');
      return true;
    } catch (e) {
      debugPrint('❌ Analiz reklamı gösterme hatası: $e');
      return false;
    }
  }

  /// Servisi temizle
  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isAdLoaded = false;
    _isLoading = false;
    
    // Analiz reklamını da temizle
    _analysisAd?.dispose();
    _analysisAd = null;
    _isAnalysisAdLoaded = false;
    _isAnalysisAdLoading = false;
  }

  /// Getters
  bool get isAdLoaded => _isAdLoaded;
  bool get isLoading => _isLoading;
  bool get isAnalysisAdLoaded => _isAnalysisAdLoaded;
  bool get isAnalysisAdLoading => _isAnalysisAdLoading;
}
