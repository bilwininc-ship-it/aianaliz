import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './remote_config_service.dart';
import './user_service.dart';
import '../models/credit_transaction_model.dart';

/// Ödüllü Reklam Servisi
/// 
/// Kullanıcılar 24 saatte bir ödüllü reklam izleyerek +1 kredi kazanabilir.
/// Cooldown mekanizması ile spam önlenir.
class RewardedAdService {
  static final RewardedAdService _instance = RewardedAdService._internal();
  factory RewardedAdService() => _instance;
  RewardedAdService._internal();

  final RemoteConfigService _remoteConfig = RemoteConfigService();
  final UserService _userService = UserService();
  
  RewardedAd? _rewardedAd;
  bool _isAdLoaded = false;
  bool _isLoading = false;

  // Callbacks
  Function()? onAdLoaded;
  Function()? onAdFailedToLoad;
  Function()? onAdShown;
  Function()? onRewardEarned;
  Function(String)? onError;

  /// Kullanıcı reklam izleyebilir mi? (24 saat cooldown kontrolü)
  Future<bool> canWatchAd() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastWatchTime = prefs.getInt('last_rewarded_ad_watch') ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      
      // 24 saat = 86400000 milisaniye
      const cooldownPeriod = 86400000;
      
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
      
      const cooldownPeriod = 86400000; // 24 saat
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

  /// Ödüllü reklamı yükle
  Future<void> loadAd() async {
    if (_isLoading || _isAdLoaded) {
      debugPrint('⚠️ Reklam zaten yükleniyor veya yüklenmiş');
      return;
    }

    _isLoading = true;

    try {
      // Test Ad Unit ID (geliştirme için)
      String adUnitId = 'ca-app-pub-3940256099942544/5224354917';
      
      // Remote Config'den gerçek ID al (production'da)
      final remoteAdUnit = _remoteConfig.admobRewardedAdUnit;
      if (remoteAdUnit.isNotEmpty && remoteAdUnit != 'ca-app-pub-3940256099942544~3347511713') {
        adUnitId = remoteAdUnit;
        debugPrint('✅ Remote Config Ad Unit kullanılıyor');
      } else {
        debugPrint('🔧 Test Ad Unit kullanılıyor');
      }

      await RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewardedAd = ad;
            _isAdLoaded = true;
            _isLoading = false;
            debugPrint('✅ Ödüllü reklam yüklendi');
            onAdLoaded?.call();
            _setupAdCallbacks();
          },
          onAdFailedToLoad: (error) {
            _isLoading = false;
            _isAdLoaded = false;
            debugPrint('❌ Ödüllü reklam yükleme hatası: $error');
            onAdFailedToLoad?.call();
            onError?.call('Reklam yüklenemedi. Lütfen tekrar deneyin.');
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
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('❌ Ödüllü reklam gösterim hatası: $error');
        _isAdLoaded = false;
        ad.dispose();
        _rewardedAd = null;
        onError?.call('Reklam gösterilemedi');
      },
    );
  }

  /// Ödüllü reklamı göster
  Future<bool> showAd(String userId) async {
    if (!_isAdLoaded || _rewardedAd == null) {
      onError?.call('Reklam henüz yüklenmedi');
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
          
          // Kullanıcıya +1 kredi ekle
          await _addCreditToUser(userId);
          
          // Son izleme zamanını kaydet
          await _saveLastWatchTime();
          
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

  /// Kullanıcıya +1 kredi ekle (UserService üzerinden)
  Future<void> _addCreditToUser(String userId) async {
    try {
      final success = await _userService.addCredits(
        userId: userId,
        amount: 1,
        type: TransactionType.rewardedAd,
        description: 'Ödüllü reklam izlendi - 1 kredi kazanıldı',
      );

      if (success) {
        debugPrint('✅ Kullanıcıya +1 kredi eklendi (Rewarded Ad)');
      } else {
        debugPrint('❌ Kredi eklenemedi');
      }
    } catch (e) {
      debugPrint('❌ Kredi ekleme hatası: $e');
    }
  }

  /// Son izleme zamanını kaydet (SharedPreferences)
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
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isAdLoaded = false;
    _isLoading = false;
  }

  /// Getters
  bool get isAdLoaded => _isAdLoaded;
  bool get isLoading => _isLoading;
}