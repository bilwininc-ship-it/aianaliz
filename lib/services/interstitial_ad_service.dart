import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import './remote_config_service.dart';

/// 🚀 Interstitial Ad Service (OPTIMIZE EDİLMİŞ - SHOW RATE ARTIŞI)
/// 
/// ✅ Exponential backoff retry (5 deneme, max 30s delay)
/// ✅ Aggressive auto-reload (0 saniye delay - anında yükleme)
/// ✅ Pre-loading + Auto-reload stratejisi
/// ✅ Parallel loading için ayrı instance'lar
/// 🎯 HEDEF: %100 Show Rate
class InterstitialAdService {
  static final InterstitialAdService _instance = InterstitialAdService._internal();
  factory InterstitialAdService() => _instance;
  InterstitialAdService._internal();

  final RemoteConfigService _remoteConfig = RemoteConfigService();
  
  // History reklamı için
  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;
  bool _isLoading = false;
  int _retryAttempt = 0;
  Timer? _retryTimer;

  // Analiz reklamı için (ayrı instance)
  InterstitialAd? _analysisAd;
  bool _isAnalysisAdLoaded = false;
  bool _isAnalysisAdLoading = false;
  int _analysisRetryAttempt = 0;
  Timer? _analysisRetryTimer;

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

  /// 🚀 Interstitial reklamı yükle (EXPONENTIAL BACKOFF ile)
  Future<void> loadAd() async {
    if (_isLoading || _isAdLoaded) {
      debugPrint('⚠️ Reklam zaten yükleniyor veya yüklenmiş');
      return;
    }

    _isLoading = true;

    try {
      // CANLI Ad Unit ID
      String adUnitId = 'ca-app-pub-6066935997419400/9631151157';
      
      // Remote Config'den gerçek ID al (production'da)
      final remoteAdUnit = _remoteConfig.admobInterstitialAdUnit;
      if (remoteAdUnit.isNotEmpty && !remoteAdUnit.contains('~')) {
        adUnitId = remoteAdUnit;
        debugPrint('✅ Remote Config Interstitial Ad Unit kullanılıyor');
      } else {
        debugPrint('✅ Canlı Interstitial Ad Unit kullanılıyor: $adUnitId');
      }

      await InterstitialAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(
          keywords: ['sports', 'football', 'soccer', 'betting', 'analysis'],
        ),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            _isAdLoaded = true;
            _isLoading = false;
            _retryAttempt = 0; // ✅ Retry counter reset
            debugPrint('✅ Interstitial reklam yüklendi (History)');
            onAdLoaded?.call();
            _setupAdCallbacks();
          },
          onAdFailedToLoad: (error) {
            _isLoading = false;
            _isAdLoaded = false;
            debugPrint('❌ Interstitial reklam yükleme hatası (History): ${error.code} - ${error.message}');
            onAdFailedToLoad?.call();
            
            // ✅ EXPONENTIAL BACKOFF RETRY
            _scheduleRetry();
          },
        ),
      );
    } catch (e) {
      _isLoading = false;
      _isAdLoaded = false;
      debugPrint('❌ Reklam yükleme exception (History): $e');
      onError?.call('Reklam yükleme hatası: $e');
      
      // ✅ Retry mekanizması
      _scheduleRetry();
    }
  }

  /// ✅ EXPONENTIAL BACKOFF: Yeniden deneme mekanizması (History)
  void _scheduleRetry() {
    if (_retryAttempt >= 5) {
      debugPrint('❌ Maksimum retry sayısına ulaşıldı (5) - History Ad');
      return;
    }

    _retryAttempt++;
    
    // Exponential backoff: 2s, 4s, 8s, 16s, 30s (max)
    final delaySeconds = (1 << _retryAttempt).clamp(2, 30);
    
    debugPrint('🔄 History Ad Retry #$_retryAttempt - $delaySeconds saniye sonra...');
    
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: delaySeconds), () {
      debugPrint('🔄 History Ad Retry #$_retryAttempt başlatılıyor...');
      loadAd();
    });
  }

  /// Reklam callback'lerini ayarla (History)
  void _setupAdCallbacks() {
    if (_interstitialAd == null) return;

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('📺 Interstitial reklam gösterildi (History)');
        onAdShown?.call();
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('✅ Interstitial reklam kapatıldı (History)');
        _isAdLoaded = false;
        ad.dispose();
        _interstitialAd = null;
        onAdClosed?.call();
        
        // 🚀 AGGRESSIVE AUTO-RELOAD: ANINDA yeni reklam yükle
        debugPrint('🚀 AGGRESSIVE AUTO-RELOAD: Yeni History reklamı yükleniyor...');
        loadAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('❌ Interstitial reklam gösterim hatası (History): $error');
        _isAdLoaded = false;
        ad.dispose();
        _interstitialAd = null;
        onError?.call('Reklam gösterilemedi');
        
        // 🚀 AGGRESSIVE AUTO-RELOAD: Hata sonrası da yükle
        debugPrint('🚀 AGGRESSIVE AUTO-RELOAD: Hata sonrası yeni reklam yükleniyor...');
        _scheduleRetry();
      },
    );
  }

  /// Interstitial reklamı göster (History)
  /// ⚡ FAIL-SAFE: Reklam yüklenemezse kullanıcıyı bekletmez
  Future<bool> showAd() async {
    if (!_isAdLoaded || _interstitialAd == null) {
      debugPrint('⚠️ Interstitial reklam henüz yüklenmedi (History) - kullanıcı devam edebilir');
      onError?.call('Reklam hazır değil (kullanıcı geçebilir)');
      
      // 🚀 Eğer yüklenmemişse hemen yüklemeyi dene
      if (!_isLoading) {
        loadAd();
      }
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
      debugPrint('❌ Reklam gösterme hatası (History): $e');
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

  // ========== ANALİZ REKLAMI METODLARİ (OPTİMİZE EDİLMİŞ) ==========
  
  /// 🚀 Analiz reklamını yükle (EXPONENTIAL BACKOFF ile)
  Future<void> loadAnalysisAd() async {
    if (_isAnalysisAdLoading || _isAnalysisAdLoaded) {
      debugPrint('⚠️ Analiz reklamı zaten yükleniyor veya yüklenmiş');
      return;
    }

    _isAnalysisAdLoading = true;

    try {
      // CANLI Ad Unit ID
      String adUnitId = 'ca-app-pub-6066935997419400/9631151157';
      
      // Remote Config'den gerçek ID al (production'da)
      final remoteAdUnit = _remoteConfig.admobInterstitialAdUnit;
      if (remoteAdUnit.isNotEmpty && !remoteAdUnit.contains('~')) {
        adUnitId = remoteAdUnit;
        debugPrint('✅ Remote Config Analysis Ad Unit kullanılıyor');
      } else {
        debugPrint('✅ Canlı Analysis Ad Unit kullanılıyor: $adUnitId');
      }

      await InterstitialAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(
          keywords: ['sports', 'football', 'soccer', 'betting', 'analysis'],
        ),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _analysisAd = ad;
            _isAnalysisAdLoaded = true;
            _isAnalysisAdLoading = false;
            _analysisRetryAttempt = 0; // ✅ Retry counter reset
            debugPrint('✅ Analiz reklamı yüklendi');
            _setupAnalysisAdCallbacks();
          },
          onAdFailedToLoad: (error) {
            _isAnalysisAdLoading = false;
            _isAnalysisAdLoaded = false;
            debugPrint('❌ Analiz reklamı yükleme hatası: ${error.code} - ${error.message}');
            
            // ✅ EXPONENTIAL BACKOFF RETRY
            _scheduleAnalysisRetry();
          },
        ),
      );
    } catch (e) {
      _isAnalysisAdLoading = false;
      _isAnalysisAdLoaded = false;
      debugPrint('❌ Analiz reklamı yükleme exception: $e');
      
      // ✅ Retry mekanizması
      _scheduleAnalysisRetry();
    }
  }

  /// ✅ EXPONENTIAL BACKOFF: Yeniden deneme mekanizması (Analysis)
  void _scheduleAnalysisRetry() {
    if (_analysisRetryAttempt >= 5) {
      debugPrint('❌ Maksimum retry sayısına ulaşıldı (5) - Analysis Ad');
      return;
    }

    _analysisRetryAttempt++;
    
    // Exponential backoff: 2s, 4s, 8s, 16s, 30s (max)
    final delaySeconds = (1 << _analysisRetryAttempt).clamp(2, 30);
    
    debugPrint('🔄 Analysis Ad Retry #$_analysisRetryAttempt - $delaySeconds saniye sonra...');
    
    _analysisRetryTimer?.cancel();
    _analysisRetryTimer = Timer(Duration(seconds: delaySeconds), () {
      debugPrint('🔄 Analysis Ad Retry #$_analysisRetryAttempt başlatılıyor...');
      loadAnalysisAd();
    });
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
        
        // 🚀 AGGRESSIVE AUTO-RELOAD: ANINDA yeni reklam yükle
        debugPrint('🚀 AGGRESSIVE AUTO-RELOAD: Yeni Analysis reklamı yükleniyor...');
        loadAnalysisAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('❌ Analiz reklamı gösterim hatası: $error');
        _isAnalysisAdLoaded = false;
        ad.dispose();
        _analysisAd = null;
        
        // 🚀 AGGRESSIVE AUTO-RELOAD: Hata sonrası da yükle
        debugPrint('🚀 AGGRESSIVE AUTO-RELOAD: Hata sonrası yeni Analysis reklamı yükleniyor...');
        _scheduleAnalysisRetry();
      },
    );
  }

  /// Analiz reklamını göster (threshold kontrolü YOK)
  /// ⚡ FAIL-SAFE: Reklam yüklenemezse analiz devam eder
  Future<bool> showAnalysisAd() async {
    if (!_isAnalysisAdLoaded || _analysisAd == null) {
      debugPrint('⚠️ Analiz reklamı henüz yüklenmedi - analiz devam edecek');
      
      // 🚀 Eğer yüklenmemişse hemen yüklemeyi dene
      if (!_isAnalysisAdLoading) {
        loadAnalysisAd();
      }
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
    // History reklamı temizleme
    _retryTimer?.cancel();
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isAdLoaded = false;
    _isLoading = false;
    _retryAttempt = 0;
    
    // Analiz reklamı temizleme
    _analysisRetryTimer?.cancel();
    _analysisAd?.dispose();
    _analysisAd = null;
    _isAnalysisAdLoaded = false;
    _isAnalysisAdLoading = false;
    _analysisRetryAttempt = 0;
  }

  /// Getters
  bool get isAdLoaded => _isAdLoaded;
  bool get isLoading => _isLoading;
  bool get isAnalysisAdLoaded => _isAnalysisAdLoaded;
  bool get isAnalysisAdLoading => _isAnalysisAdLoading;
  int get retryAttempt => _retryAttempt;
  int get analysisRetryAttempt => _analysisRetryAttempt;
}
