import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/match_pool_model.dart';
import './football_api_service.dart';
import './remote_config_service.dart';

class MatchPoolService {
  static final MatchPoolService _instance = MatchPoolService._internal();
  factory MatchPoolService() => _instance;
  MatchPoolService._internal();

  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final FootballApiService _footballApi = FootballApiService();
  final RemoteConfigService _remoteConfig = RemoteConfigService();

  String get _apiKey => _remoteConfig.footballApiKey;
  final String _baseUrl = 'https://v3.football.api-sports.io';

  /// 🔥 FIREBASE HAVUZUNU GÜNCELLE (Bugün + Yarın TÜM MAÇLAR)
  Future<void> updateMatchPool() async {
    try {
      print('🔄 Maç havuzu güncelleniyor (TÜM MAÇLAR)...');
      
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));
      
      int totalMatches = 0;
      Set<int> uniqueLeagues = {};
      
      // BUGÜN'ÜN MAÇLARINI ÇEK
      print('📥 Bugün oynanan maçlar çekiliyor...');
      final todayMatches = await _fetchAllFixturesForDate(now);
      if (todayMatches.isNotEmpty) {
        await _saveMatchesToFirebase(todayMatches);
        totalMatches += todayMatches.length;
        for (var match in todayMatches) {
          uniqueLeagues.add(match.leagueId);
        }
        print('✅ Bugün: ${todayMatches.length} maç eklendi');
      }
      
      // Rate limit koruması
      await Future.delayed(const Duration(milliseconds: 500));
      
      // YARIN'IN MAÇLARINI ÇEK
      print('📥 Yarın oynanan maçlar çekiliyor...');
      final tomorrowMatches = await _fetchAllFixturesForDate(tomorrow);
      if (tomorrowMatches.isNotEmpty) {
        await _saveMatchesToFirebase(tomorrowMatches);
        totalMatches += tomorrowMatches.length;
        for (var match in tomorrowMatches) {
          uniqueLeagues.add(match.leagueId);
        }
        print('✅ Yarın: ${tomorrowMatches.length} maç eklendi');
      }

      // Metadata güncelle
      await _updatePoolMetadata(totalMatches, uniqueLeagues.toList());
      
      print('🎉 Havuz güncellendi: $totalMatches maç (${uniqueLeagues.length} farklı lig)');
    } catch (e) {
      print('❌ Havuz güncelleme hatası: $e');
      rethrow;
    }
  }

  /// Belirli bir tarihte oynanan TÜM maçları çek (tüm ligler)
  Future<List<MatchPoolModel>> _fetchAllFixturesForDate(DateTime date) async {
    final dateStr = _formatDate(date); // ✅ Scope dışına taşındı
    
    try {
      
      final url = Uri.parse(
        '$_baseUrl/fixtures?date=$dateStr',
      );

      print('📡 API Request: /fixtures?date=$dateStr');

      final response = await http.get(url, headers: {
        'x-rapidapi-host': 'v3.football.api-sports.io',
        'x-rapidapi-key': _apiKey,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final fixtures = data['response'] as List? ?? [];
        
        print('📊 API Response: ${fixtures.length} maç bulundu');
        
        List<MatchPoolModel> matches = [];
        
        // Her maç için stats ve h2h çekme (opsiyonel - çok request olabilir)
        // İlk versiyonda sadece temel bilgileri kaydedelim
        for (var fixture in fixtures) {
          final homeTeamId = fixture['teams']['home']['id'];
          final awayTeamId = fixture['teams']['away']['id'];
          final leagueId = fixture['league']['id'];
          
          // Rate limit koruması
          await Future.delayed(const Duration(milliseconds: 200));
          
          // Stats çek (opsiyonel)
          final homeStats = await _footballApi.getTeamStats(homeTeamId, leagueId).catchError((_) => null);
          await Future.delayed(const Duration(milliseconds: 200));
          
          final awayStats = await _footballApi.getTeamStats(awayTeamId, leagueId).catchError((_) => null);
          await Future.delayed(const Duration(milliseconds: 200));
          
          // H2H çek (opsiyonel)
          final h2h = await _footballApi.getH2H(homeTeamId, awayTeamId).catchError((_) => []);
          
          final match = MatchPoolModel(
            fixtureId: fixture['fixture']['id'],
            homeTeam: _cleanTeamName(fixture['teams']['home']['name']),
            awayTeam: _cleanTeamName(fixture['teams']['away']['name']),
            homeTeamId: homeTeamId,
            awayTeamId: awayTeamId,
            league: fixture['league']['name'],
            leagueId: leagueId,
            date: fixture['fixture']['date'].split('T')[0],
            time: fixture['fixture']['date'].split('T')[1].substring(0, 5),
            timestamp: DateTime.parse(fixture['fixture']['date']).millisecondsSinceEpoch,
            status: fixture['fixture']['status']['short'],
            homeStats: homeStats,
            awayStats: awayStats,
            h2h: h2h,
            lastUpdated: DateTime.now().millisecondsSinceEpoch,
          );
          
          matches.add(match);
        }
        
        return matches;
      } else {
        print('❌ API Error: Status ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Fixtures fetch error ($dateStr): $e');
      return [];
    }
  }

  /// Firebase'e maçları kaydet
  Future<void> _saveMatchesToFirebase(List<MatchPoolModel> matches) async {
    try {
      for (var match in matches) {
        final date = match.date;
        final fixtureId = match.fixtureId.toString();
        
        await _database
            .child('matchPool')
            .child(date)
            .child(fixtureId)
            .set(match.toJson());
      }
    } catch (e) {
      print('❌ Firebase kayıt hatası: $e');
    }
  }

  /// Pool metadata güncelle
  Future<void> _updatePoolMetadata(int totalMatches, List<int> leagues) async {
    try {
      final now = DateTime.now();
      final nextUpdate = now.add(const Duration(hours: 6)); // 6 saatte bir güncelle
      
      await _database.child('poolMetadata').update({
        'lastUpdate': now.millisecondsSinceEpoch,
        'totalMatches': totalMatches,
        'leagues': leagues,
        'nextUpdate': nextUpdate.millisecondsSinceEpoch,
        'lastUpdateFormatted': '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
        'nextUpdateFormatted': '${nextUpdate.day}/${nextUpdate.month}/${nextUpdate.year} ${nextUpdate.hour}:${nextUpdate.minute.toString().padLeft(2, '0')}',
      });
      
      print('📊 Metadata güncellendi:');
      print('  - Toplam maç: $totalMatches');
      print('  - Ligler: ${leagues.length}');
      print('  - Sonraki güncelleme: ${nextUpdate.hour}:${nextUpdate.minute.toString().padLeft(2, '0')}');
    } catch (e) {
      print('❌ Metadata güncelleme hatası: $e');
    }
  }

  /// 🔍 HAVUZDA MAÇ ARA (Fuzzy Matching)
  Future<MatchPoolModel?> findMatchInPool(String homeTeam, String awayTeam) async {
    try {
      print('🔍 Havuzda aranıyor: $homeTeam vs $awayTeam');
      
      // Son 2 günlük maçlara bak
      final dates = _getLast2Days();
      
      for (var date in dates) {
        final snapshot = await _database
            .child('matchPool')
            .child(date)
            .get();
        
        if (snapshot.exists) {
          final matchesMap = snapshot.value as Map<dynamic, dynamic>;
          
          for (var entry in matchesMap.entries) {
            final matchData = entry.value as Map<dynamic, dynamic>;
            final match = MatchPoolModel.fromJson(
              Map<String, dynamic>.from(matchData),
            );
            
            // Fuzzy matching (%85 benzerlik)
            if (_isMatchingSimilar(homeTeam, match.homeTeam, 0.85) &&
                _isMatchingSimilar(awayTeam, match.awayTeam, 0.85)) {
              print('✅ Eşleşme bulundu: ${match.getMatchSummary()}');
              return match;
            }
          }
        }
      }
      
      print('⚠️ Havuzda bulunamadı: $homeTeam vs $awayTeam');
      return null;
    } catch (e) {
      print('❌ Havuz arama hatası: $e');
      return null;
    }
  }

  /// 🗑️ BİTEN MAÇLARI TEMİZLE
  Future<void> cleanOldMatches() async {
    try {
      print('🗑️ Eski maçlar temizleniyor...');
      
      final now = DateTime.now();
      final cutoffDate = now.subtract(const Duration(hours: 3)); // 3 saat önceki maçları sil
      
      final snapshot = await _database.child('matchPool').get();
      
      if (snapshot.exists) {
        final datesMap = snapshot.value as Map<dynamic, dynamic>;
        int deletedCount = 0;
        
        for (var dateEntry in datesMap.entries) {
          final date = dateEntry.key as String;
          final matchesMap = dateEntry.value as Map<dynamic, dynamic>;
          
          for (var matchEntry in matchesMap.entries) {
            final matchData = matchEntry.value as Map<dynamic, dynamic>;
            final timestamp = matchData['timestamp'] as int;
            
            // Maç 3 saat önceyse sil
            if (timestamp < cutoffDate.millisecondsSinceEpoch) {
              await _database
                  .child('matchPool')
                  .child(date)
                  .child(matchEntry.key)
                  .remove();
              deletedCount++;
            }
          }
          
          // Eğer o günün tüm maçları silindiyse tarihi de sil
          final remainingMatches = await _database
              .child('matchPool')
              .child(date)
              .get();
          
          if (!remainingMatches.exists || 
              (remainingMatches.value as Map).isEmpty) {
            await _database.child('matchPool').child(date).remove();
          }
        }
        
        print('✅ $deletedCount eski maç temizlendi');
      }
    } catch (e) {
      print('❌ Temizlik hatası: $e');
    }
  }

  /// 📊 HAVUZ İSTATİSTİKLERİ
  Future<Map<String, dynamic>> getPoolStats() async {
    try {
      final metadataSnapshot = await _database.child('poolMetadata').get();
      
      if (metadataSnapshot.exists) {
        return Map<String, dynamic>.from(metadataSnapshot.value as Map);
      }
      
      return {};
    } catch (e) {
      print('❌ Stats alma hatası: $e');
      return {};
    }
  }

  // ============= HELPER METHODS =============

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  List<String> _getLast2Days() {
    final now = DateTime.now();
    return [
      _formatDate(now),
      _formatDate(now.add(const Duration(days: 1))),
    ];
  }

  String _cleanTeamName(String name) {
    // Türkçe karakterleri temizle ve normalize et
    final map = {
      'ç': 'c', 'Ç': 'C', 'ğ': 'g', 'Ğ': 'G',
      'ı': 'i', 'İ': 'I', 'ö': 'o', 'Ö': 'O',
      'ş': 's', 'Ş': 'S', 'ü': 'u', 'Ü': 'U',
    };
    
    var clean = name;
    map.forEach((turkish, english) {
      clean = clean.replaceAll(turkish, english);
    });
    
    return clean.trim();
  }

  /// Fuzzy string matching (Levenshtein distance)
  bool _isMatchingSimilar(String str1, String str2, double threshold) {
    str1 = _cleanTeamName(str1.toLowerCase());
    str2 = _cleanTeamName(str2.toLowerCase());
    
    final distance = _levenshteinDistance(str1, str2);
    final maxLength = str1.length > str2.length ? str1.length : str2.length;
    
    if (maxLength == 0) return true;
    
    final similarity = 1.0 - (distance / maxLength);
    return similarity >= threshold;
  }

  int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> v0 = List<int>.generate(s2.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;

      for (int j = 0; j < s2.length; j++) {
        int cost = (s1[i] == s2[j]) ? 0 : 1;
        v1[j + 1] = [
          v1[j] + 1,
          v0[j + 1] + 1,
          v0[j] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }

      List<int> temp = v0;
      v0 = v1;
      v1 = temp;
    }

    return v0[s2.length];
  }

  /// 🧪 TEST METODU: Pool operasyonlarını test et
  Future<void> testPoolOperations() async {
    try {
      print('🧪 Pool test başlıyor...');
      
      // 1. Pool güncelle (1 lig test için)
      print('📥 Pool güncelleniyor (Sadece Süper Lig)...');
      final testLeagues = [203]; // Sadece Süper Lig
      
      // Not: updateMatchPool manuel çağrılmalı - test için geçici
      
      // 2. Bir maç ara
      print('🔍 Test maçı aranıyor...');
      final testMatch = await findMatchInPool('Galatasaray', 'Fenerbahce');
      
      if (testMatch != null) {
        print('✅ Test başarılı: ${testMatch.getMatchSummary()}');
      } else {
        print('⚠️ Test maçı bulunamadı (Normal - maç bugün olmayabilir)');
      }
      
      // 3. Stats göster
      print('📊 Pool istatistikleri alınıyor...');
      final stats = await getPoolStats();
      
      if (stats.isNotEmpty) {
        print('✅ Pool Stats:');
        print('  - Son Güncelleme: ${stats['lastUpdate']}');
        print('  - Toplam Maç: ${stats['totalMatches']}');
        print('  - Ligler: ${stats['leagues']}');
      } else {
        print('⚠️ Pool metadata bulunamadı');
      }
      
      print('🎉 Test tamamlandı!');
    } catch (e) {
      print('❌ Test hatası: $e');
    }
  }
}
