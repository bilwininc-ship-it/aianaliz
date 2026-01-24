import 'package:firebase_database/firebase_database.dart';
import './match_pool_service.dart';

/// Uygulama başlangıç servisi - SADECE OKUMA MODU
/// - Match Pool durumunu kontrol eder
/// - KULLANICILAR GÜNCELLEME YAPMAZ
/// - Güncelleme: External Cron + Cloud Function tarafından yapılır
/// - Firebase FREE plan ile çalışır
class AppStartupService {
  static final AppStartupService _instance = AppStartupService._internal();
  factory AppStartupService() => _instance;
  AppStartupService._internal();

  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final MatchPoolService _matchPool = MatchPoolService();

  bool _isInitialized = false;

  /// Uygulama başlangıcında çağrılacak
  Future<void> initialize() async {
    if (_isInitialized) {
      print('⚠️ App Startup zaten çalıştırıldı');
      return;
    }

    try {
      print('🚀 App Startup başlatılıyor...');

      // 1. Pool durumunu kontrol et (SADECE OKUMA)
      final poolStatus = await _checkPoolStatus();
      
      if (poolStatus['exists']) {
        final hoursSinceUpdate = poolStatus['hoursSinceUpdate'] ?? 0;
        final totalMatches = poolStatus['totalMatches'] ?? 0;
        
        print('✅ Match Pool mevcut:');
        print('   - Toplam maç: $totalMatches');
        print('   - Son güncelleme: $hoursSinceUpdate saat önce');
        
        if (hoursSinceUpdate > 6) {
          print('⚠️ Pool eskimiş (6+ saat) - Cron job güncelleme yapacak');
        } else {
          print('✅ Pool güncel ve kullanıma hazır');
        }
      } else {
        print('⚠️ Match Pool henüz oluşturulmamış');
        print('💡 Cron job ilk güncellemeyi yapacak');
      }

      _isInitialized = true;
      print('✅ App Startup tamamlandı (Read-only mode)');
    } catch (e) {
      print('❌ App Startup hatası: $e');
      // Hata olsa bile uygulama açılmalı
      _isInitialized = true;
    }
  }

  /// Pool durumunu kontrol et (SADECE OKUMA)
  Future<Map<String, dynamic>> _checkPoolStatus() async {
    try {
      final metadataSnapshot = await _database.child('poolMetadata').get();

      if (!metadataSnapshot.exists) {
        return {
          'exists': false,
          'message': 'Pool henüz oluşturulmamış',
        };
      }

      final metadata = metadataSnapshot.value as Map<dynamic, dynamic>;
      final lastUpdate = metadata['lastUpdate'] as int?;
      final totalMatches = metadata['totalMatches'] as int? ?? 0;
      final nextUpdate = metadata['nextUpdate'] as int?;

      final now = DateTime.now().millisecondsSinceEpoch;
      final hoursSinceUpdate = lastUpdate != null 
          ? ((now - lastUpdate) / (1000 * 60 * 60)).floor() 
          : 0;

      return {
        'exists': true,
        'totalMatches': totalMatches,
        'lastUpdate': lastUpdate,
        'nextUpdate': nextUpdate,
        'hoursSinceUpdate': hoursSinceUpdate,
        'isStale': hoursSinceUpdate > 6,
      };
    } catch (e) {
      print('❌ Pool status kontrol hatası: $e');
      return {
        'exists': false,
        'error': e.toString(),
      };
    }
  }

  /// Timestamp'i okunabilir formata çevir
  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  /// Pool durumunu kontrol et
  Future<Map<String, dynamic>> getPoolStatus() async {
    try {
      final metadataSnapshot = await _database.child('poolMetadata').get();
      
      if (!metadataSnapshot.exists) {
        return {
          'exists': false,
          'message': 'Pool henüz oluşturulmamış',
        };
      }

      final metadata = metadataSnapshot.value as Map<dynamic, dynamic>;
      final lastUpdate = metadata['lastUpdate'] as int?;
      final totalMatches = metadata['totalMatches'] as int? ?? 0;
      final leagues = metadata['leagues'] as List<dynamic>? ?? [];
      final nextUpdate = metadata['nextUpdate'] as int?;

      final now = DateTime.now().millisecondsSinceEpoch;
      final hoursSinceUpdate = lastUpdate != null 
          ? ((now - lastUpdate) / (1000 * 60 * 60)).floor() 
          : 0;

      return {
        'exists': true,
        'totalMatches': totalMatches,
        'leagues': leagues.length,
        'lastUpdate': lastUpdate,
        'nextUpdate': nextUpdate,
        'hoursSinceUpdate': hoursSinceUpdate,
        'isStale': hoursSinceUpdate > 6, // 6 saatten eski ise stale
        'lastUpdateFormatted': lastUpdate != null ? _formatTimestamp(lastUpdate) : 'Bilinmiyor',
        'nextUpdateFormatted': nextUpdate != null ? _formatTimestamp(nextUpdate) : 'Bilinmiyor',
      };
    } catch (e) {
      print('❌ Pool status hatası: $e');
      return {
        'exists': false,
        'error': e.toString(),
      };
    }
  }
}
