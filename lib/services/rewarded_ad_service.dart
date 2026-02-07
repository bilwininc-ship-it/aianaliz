import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './remote_config_service.dart';
import './user_service.dart';
import './analytics_service.dart';
import '../models/credit_transaction_model.dart';
import 'dart:async';

/// Ödüllü Reklam Servisi (OPTIMIZE EDİLMİŞ)
/// 
/// ✅ Pre-loading mekanizması
/// ✅ Optimize edilmiş AdRequest
/// ✅ Exponential backoff retry
/// ✅ Ad revenue tracking
class RewardedAdService {
  static final RewardedAdService _instance = RewardedAdService._internal();
  factory RewardedAdService() => _instance;
  RewardedAdService._internal();

  final RemoteConfigService _remoteConfig = RemoteConfigService();
  final UserService _userService = UserService();
  final AnalyticsService _analytics = AnalyticsService();
  
  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;
  bool _isLoading = false;
  int _retryAttempt = 0;
  Timer? _retryTimer;

  // Callbacks
  Function()? onAdLoaded;
  Function()? onAdFailedToLoad;
  Function()? onAdShown;
  Function()? onRewardEarned;
  Function(String)? onError;

  /// ✅ PRE-LOADING: Reklamı önceden yükle (uygulama başlangıcında)
  /// 🚀 AGRESİF STRATEJI: Cooldown kontrolü YAPMA - Her zaman yükle
  /// Gösterim sırasında cooldown kontrol edilecek
  Future<void> preloadAd() async {
    if (_isLoading || _isAdLoaded) {
      debugPrint('⚠️ Reklam zaten yükleniyor veya yüklenmiş');
      return;
    }

    debugPrint('🚀 Pre-loading rewarded ad (AGRESİF MOD - cooldown yok)...');
    await loadAd();
  }

  /// Kullanıcı reklam izleyebilir mi? (Remote Config'den cooldown kontrolü)
  Future<bool> canWatchAd() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastWatchTime = prefs.getInt('last_rewarded_ad_watch') ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      
      final cooldownHours = _remoteConfig.giftCreditIntervalHours;
      final cooldownPeriod = cooldownHours * 3600000;
      
      return (currentTime - lastWatchTime) >= cooldownPeriod;
    } catch (e) {
      debugPrint('❌ Cooldown kontrolü hatası: $e');
      return false;
    }
  }

  /// Bir sonraki reklam için kalan süre
  Future<Duration> getRemainingCooldown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastWatchTime = prefs.getInt('last_rewarded_ad_watch') ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      
      final cooldownHours = _remoteConfig.giftCreditIntervalHours;
      final cooldownPeriod = cooldownHours * 3600000;
      
      final elapsed = currentTime - lastWatchTime;
      final remaining = cooldownPeriod - elapsed;
      
      if (remaining <= 0) {
        return Duration.zero;
      }
      
      return Duration(milliseconds: remaining);
    } catch (e) {
      debugPrint('❌ Kalan süre hesaplama hatası: $e');
      return Duration.zero;
    }
  }
  
  /// ✅ OPTİMİZE EDİLMİŞ AdRequest
  AdRequest _buildOptimizedAdRequest() {
    return const AdRequest(
      // ✅ Non-personalized ads için GDPR uyumlu
      nonPersonalizedAds: false,
      
      // ✅ Targeting keywords (spor uygulaması)
      keywords: ['sports', 'football', 'soccer', 'betting', 'analysis'],
      
      // ✅ Content URL (uygulama bağlamı)
      contentUrl: 'https://aispor.pro',
    );
  }
  
  /// ✅ Ödüllü reklamı yükle (EXPONENTIAL BACKOFF ile)
  Future<void> loadAd() async {
    if (_isLoading || _isAdLoaded) {
      debugPrint('⚠️ Reklam zaten yükleniyor veya yüklenmiş');
      return;
    }

    _isLoading = true;

    try {
      // ✅ CANLI REKLAM ID
      String adUnitId = 'ca-app-pub-6066935997419400/8249485401';
      
      // Remote Config'den gerçek ID al
      final remoteAdUnit = _remoteConfig.admobRewardedAdUnit;
      if (remoteAdUnit.isNotEmpty && remoteAdUnit != 'ca-app-pub-3940256099942544~3347511713') {
        adUnitId = remoteAdUnit;
        debugPrint('✅ Remote Config Ad Unit kullanılıyor: $adUnitId');
      } else {
        debugPrint('✅ Canlı Rewarded Ad Unit kullanılıyor: $adUnitId');
      }

      await RewardedAd.load(
        adUnitId: adUnitId,
        request: _buildOptimizedAdRequest(), // ✅ Optimize edilmiş request
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;
            _isAdLoaded = true;
            _isLoading = false;
            _retryAttempt = 0; // ✅ Retry counter reset
            debugPrint('✅ Ödüllü reklam yüklendi');
            onAdLoaded?.call();
            _setupAdCallbacks();
          },
          onAdFailedToLoad: (error) {
            _isLoading = false;
            _isAdLoaded = false;
            debugPrint('❌ Ödüllü reklam yükleme hatası: ${error.code} - ${error.message}');
            
            // ✅ Analytics'e hata rapor et
            _analytics.trackAdLoadFailed(
              adFormat: 'rewarded',
              errorCode: error.code.toString(),
              errorMessage: error.message,
            );
            
            onAdFailedToLoad?.call();
            
            // ✅ EXPONENTIAL BACKOFF RETRY
            _scheduleRetry();
          },
        ),
      );
    } catch (e) {
      _isLoading = false;
      _isAdLoaded = false;
      debugPrint('❌ Reklam yükleme exception: $e');
      onError?.call('Reklam yükleme hatası: $e');
      
      // ✅ Retry mekanizması
      _scheduleRetry();
    }
  }

  /// ✅ EXPONENTIAL BACKOFF: Yeniden deneme mekanizması
  void _scheduleRetry() {
    if (_retryAttempt >= 5) {
      debugPrint('❌ Maksimum retry sayısına ulaşıldı (5)');
      onError?.call('Reklam yüklenemedi. Lütfen daha sonra tekrar deneyin.');
      return;
    }

    _retryAttempt++;
    
    // Exponential backoff: 1s, 2s, 4s, 8s, 16s
    final delaySeconds = (1 << (_retryAttempt - 1));
    
    debugPrint('🔄 Retry #$_retryAttempt - $delaySeconds saniye sonra...');
    
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: delaySeconds), () {
      debugPrint('🔄 Retry #$_retryAttempt başlatılıyor...');
      loadAd();
    });
  }

  /// Reklam callback'lerini ayarla
  void _setupAdCallbacks() {
    if (_rewardedAd == null) return;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('📺 Ödüllü reklam gösterildi');
        onAdShown?.call();
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('❌ Ödüllü reklam kapatıldı');
        _isAdLoaded = false;
        ad.dispose();
        _rewardedAd = null;
        
        // 🚀 AGGRESSIVE AUTO-RELOAD: ANINDA yeni reklam yükle (0 saniye delay)
        debugPrint('🚀 AGGRESSIVE AUTO-RELOAD: Yeni Rewarded reklamı yükleniyor...');
        preloadAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('❌ Ödüllü reklam gösterim hatası: $error');
        _isAdLoaded = false;
        ad.dispose();
        _rewardedAd = null;
        onError?.call('Reklam gösterilemedi');
        
        // 🚀 AGGRESSIVE AUTO-RELOAD: Hata sonrası da anında retry
        debugPrint('🚀 AGGRESSIVE AUTO-RELOAD: Hata sonrası yeni reklam yükleniyor...');
        _scheduleRetry();
      },
    );
  }

  /// Ödüllü reklamı göster
  Future<bool> showAd(String userId) async {
    if (!_isAdLoaded || _rewardedAd == null) {
      onError?.call('Reklam henüz yüklenmedi');
      
      // ✅ Eğer yüklenmemişse hemen yüklemeyi dene
      await loadAd();
      return false;
    }

    // Cooldown kontrolü
    final canWatch = await canWatchAd();
    if (!canWatch) {
      final remaining = await getRemainingCooldown();
      final hours = remaining.inHours;
      final minutes = remaining.inMinutes.remainder(60);
      onError?.call('$hours saat $minutes dakika sonra tekrar izleyebilirsiniz');
      return false;
    }

    try {
      await _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) async {
          debugPrint('✅ Kullanıcı ödül kazandı: ${reward.amount} ${reward.type}');
          
          // Kullanıcıya kredi ekle
          await _addCreditToUser(userId);
          
          // Son izleme zamanını kaydet
          await _saveLastWatchTime();
          
          // ✅ Analytics: Rewarded ad complete
          await _analytics.trackRewardedAdComplete(
            adUnitId: 'ca-app-pub-6066935997419400/8249485401',
            rewardAmount: _remoteConfig.giftCreditAmount,
          );
          
          // ✅ Ad Revenue Tracking (AdMob'dan gelen para)
          // NOT: Gerçek revenue bilgisi AdMob'dan paid_event ile gelir
          // Şimdilik tahmini değer kullanıyoruz
          await _analytics.trackAdRevenue(
            adUnitId: 'ca-app-pub-6066935997419400/8249485401',
            adFormat: 'rewarded',
            value: 0.05, // Tahmini eCPM (gerçek değer AdMob'dan gelecek)
            currency: 'USD',
          );
          
          onRewardEarned?.call();
        },
      );

      return true;
    } catch (e) {
      debugPrint('❌ Reklam gösterme hatası: $e');
      onError?.call('Reklam gösterme hatası');
      return false;
    }
  }

  /// Kullanıcıya kredi ekle
  Future<void> _addCreditToUser(String userId) async {
    try {
      final creditAmount = _remoteConfig.giftCreditAmount;
      
      final success = await _userService.addCredits(
        userId: userId,
        amount: creditAmount,
        type: TransactionType.rewardedAd,
        description: 'Ödüllü reklam izlendi - $creditAmount kredi kazanıldı',
      );

      if (success) {
        debugPrint('✅ Kullanıcıya +$creditAmount kredi eklendi (Rewarded Ad)');
      } else {
        debugPrint('❌ Kredi eklenemedi');
      }
    } catch (e) {
      debugPrint('❌ Kredi ekleme hatası: $e');
    }
  }

  /// Son izleme zamanını kaydet
  Future<void> _saveLastWatchTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'last_rewarded_ad_watch',
        DateTime.now().millisecondsSinceEpoch,
      );
      debugPrint('✅ Son izleme zamanı kaydedildi');
    } catch (e) {
      debugPrint('❌ İzleme zamanı kaydetme hatası: $e');
    }
  }

  /// Servisi temizle
  void dispose() {
    _retryTimer?.cancel();
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isAdLoaded = false;
    _isLoading = false;
    _retryAttempt = 0;
  }

  /// Getters
  bool get isAdLoaded => _isAdLoaded;
  bool get isLoading => _isLoading;
  int get retryAttempt => _retryAttempt;
}
