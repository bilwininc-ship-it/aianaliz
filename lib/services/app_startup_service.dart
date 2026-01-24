import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

/// Uygulama başlangıcında gerekli servisleri başlatır
/// Match pool kontrolü ve güncelleme işlemlerini yönetir
class AppStartupService {
  static final AppStartupService _instance = AppStartupService._internal();
  factory AppStartupService() => _instance;
  AppStartupService._internal();

  bool _initialized = false;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  /// Servisi başlat
  Future<void> initialize() async {
    if (_initialized) {
      debugPrint('⚠️ AppStartupService zaten başlatılmış');
      return;
    }

    try {
      debugPrint('🚀 AppStartupService başlatılıyor...');
      
      // Match pool kontrolü yap
      await _checkMatchPool();
      
      _initialized = true;
      debugPrint('✅ AppStartupService başarıyla başlatıldı');
    } catch (e) {
      debugPrint('❌ AppStartupService başlatma hatası: $e');
      _initialized = true; // Hata olsa bile işaretliyoruz ki tekrar deneme yapılmasın
    }
  }

  /// Match pool'un durumunu kontrol et
  Future<void> _checkMatchPool() async {
    try {
      final snapshot = await _dbRef.child('match_pool').get();
      
      if (!snapshot.exists) {
        debugPrint('⚠️ Match pool bulunamadı, ilk kez oluşturulacak');
        return;
      }

      final data = snapshot.value as Map?;
      if (data == null || data['last_updated'] == null) {
        debugPrint('⚠️ Match pool verisi eksik');
        return;
      }

      final lastUpdated = DateTime.fromMillisecondsSinceEpoch(
        data['last_updated'] as int,
      );
      final hoursSinceUpdate = DateTime.now().difference(lastUpdated).inHours;

      if (hoursSinceUpdate >= 12) {
        debugPrint('⚠️ Match pool eski ($hoursSinceUpdate saat), güncelleme gerekli');
      } else {
        debugPrint('✅ Match pool güncel (${hoursSinceUpdate} saat önce güncellendi)');
      }
    } catch (e) {
      debugPrint('❌ Match pool kontrolü hatası: $e');
    }
  }

  /// Pool durumunu al
  Future<Map<String, dynamic>> getPoolStatus() async {
    try {
      final snapshot = await _dbRef.child('match_pool').get();
      
      if (!snapshot.exists) {
        return {
          'exists': false,
          'message': 'Match pool henüz oluşturulmamış',
        };
      }

      final data = snapshot.value as Map;
      final lastUpdated = DateTime.fromMillisecondsSinceEpoch(
        data['last_updated'] as int,
      );
      final hoursSinceUpdate = DateTime.now().difference(lastUpdated).inHours;
      final isStale = hoursSinceUpdate >= 12;

      return {
        'exists': true,
        'totalMatches': data['total_matches'] ?? 0,
        'leagues': data['leagues']?.length ?? 0,
        'lastUpdated': lastUpdated.toIso8601String(),
        'hoursSinceUpdate': hoursSinceUpdate,
        'isStale': isStale,
      };
    } catch (e) {
      debugPrint('❌ Pool status alma hatası: $e');
      return {
        'exists': false,
        'message': 'Hata: $e',
      };
    }
  }

  /// Pool'u zorla güncelle
  Future<bool> forceUpdatePool() async {
    try {
      debugPrint('🔄 Match pool manuel güncelleme başlatıldı...');
      
      // Firebase Cloud Function'ı tetikle
      await _dbRef.child('triggers/update_pool').set({
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'manual': true,
      });
      
      debugPrint('✅ Güncelleme talebi gönderildi');
      return true;
    } catch (e) {
      debugPrint('❌ Pool güncelleme hatası: $e');
      return false;
    }
  }
}
