import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/bulletin_model.dart';
import './gemini_service.dart';
import './football_api_service.dart';
import './match_pool_service.dart';
import './user_service.dart';
import 'dart:convert';

/// 🎯 ANALİZ SERVİSİ - Bülten Oluşturma ve Analiz
class AnalysisService {
  static final AnalysisService _instance = AnalysisService._internal();
  factory AnalysisService() => _instance;
  AnalysisService._internal();

  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final GeminiService _gemini = GeminiService();
  final FootballApiService _footballApi = FootballApiService();
  final MatchPoolService _matchPool = MatchPoolService();
  final UserService _userService = UserService();

  /// 🚀 ANALİZ BAŞLAT (Image -> Gemini -> Pool/API -> AI Analysis -> Firebase)
  Future<String> analyzeBulletin(String base64Image) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) throw Exception('Kullanıcı giriş yapmamış');

    try {
      // 1️⃣ YENİ BÜLTEN OLUŞTUR
      final bulletinRef = _database.child('bulletins').child(userId).push();
      final bulletinId = bulletinRef.key!;
      
      final bulletin = BulletinModel(
        id: bulletinId,
        userId: userId,
        status: 'analyzing', // BulletinStatus.analyzing.toString() yerine direkt string
        createdAt: DateTime.now(),
      );
      
      await bulletinRef.set(bulletin.toMap());
      debugPrint('✅ Yeni bülten oluşturuldu: $bulletinId');

      // 2️⃣ KREDİ KULLAN
      final creditUsed = await _userService.useCredit(userId, analysisId: bulletinId);
      if (!creditUsed) {
        await bulletinRef.update({'status': 'failed', 'error': 'Yetersiz kredi'});
        throw Exception('Yetersiz kredi');
      }

      // 3️⃣ BÜLTEN DURUMUNU GÜNCELLE
      await bulletinRef.update({'status': 'analyzing'});
      debugPrint('✅ Bülten durumu güncellendi: analyzing');

      // 4️⃣ GEMİNİ İLE MAÇLARI ÇIKART
      final geminiResponse = await _gemini.analyzeImage(base64Image);
      final matchesData = _parseGeminiResponse(geminiResponse);
      
      debugPrint('📋 Gemini\'den gelen maçlar:');
      for (var match in matchesData) {
        debugPrint('  - ${match['homeTeam']} vs ${match['awayTeam']}');
      }

      // 5️⃣ HER MAÇ İÇİN VERİ TOPLA VE ANALİZ YAP
      final analyzedMatches = <Map<String, dynamic>>[];
      int matchIndex = 1;

      for (var matchData in matchesData) {
        debugPrint('\n🔍 Maç $matchIndex/${matchesData.length}: ${matchData['homeTeam']} vs ${matchData['awayTeam']}');
        
        try {
          // POOL'DA ARA
          final poolMatch = await _matchPool.findMatchInPool(
            matchData['homeTeam'],
            matchData['awayTeam'],
          );

          Map<String, dynamic>? homeStats;
          Map<String, dynamic>? awayStats;
          List<Map<String, dynamic>> h2h = [];
          String source;
          String league = 'Bilinmiyor';

          if (poolMatch != null) {
            // POOL'DAN AL
            debugPrint('✅ Pool\'da bulundu: ${poolMatch.getMatchSummary()}');
            homeStats = poolMatch.homeStats;
            awayStats = poolMatch.awayStats;
            h2h = (poolMatch.h2h ?? []).cast<Map<String, dynamic>>(); // Cast ekle
            source = 'firebase_pool';
            league = poolMatch.league;
          } else {
            // FOOTBALL API'DEN AL
            debugPrint('! Maç $matchIndex: Havuzda yok, Football API kullanılıyor...');
            
            final homeTeamData = await _footballApi.searchAndGetTeamData(matchData['homeTeam']);
            await Future.delayed(const Duration(milliseconds: 800));
            
            final awayTeamData = await _footballApi.searchAndGetTeamData(matchData['awayTeam']);
            await Future.delayed(const Duration(milliseconds: 800));

            homeStats = homeTeamData?['stats'];
            awayStats = awayTeamData?['stats'];
            source = 'football_api';
            league = homeTeamData?['league'] ?? 'Bilinmiyor';

            // H2H çek (opsiyonel)
            if (homeTeamData != null && awayTeamData != null) {
              try {
                final h2hResult = await _footballApi.getH2H(
                  homeTeamData['id'],
                  awayTeamData['id'],
                );
                h2h = h2hResult.cast<Map<String, dynamic>>(); // Cast ekle
              } catch (e) {
                debugPrint('! H2H alınamadı: $e');
              }
            }
          }

          // ANALİZ YAP
          final analysis = _performAiAnalysis({
            'homeTeam': matchData['homeTeam'],
            'awayTeam': matchData['awayTeam'],
            'homeStats': homeStats,
            'awayStats': awayStats,
            'h2h': h2h,
            'source': source,
            'league': league,
            'matchDate': poolMatch?.date ?? DateTime.now().toString().split(' ')[0],
          });

          analyzedMatches.add(analysis);
          debugPrint('✅ Maç $matchIndex: $source - ${matchData['homeTeam']} vs ${matchData['awayTeam']}');
          
        } catch (e) {
          debugPrint('❌ Maç $matchIndex analiz hatası: $e');
          // Hata olsa bile devam et
        }

        matchIndex++;
      }

      // 6️⃣ SONUÇLARI KAYDET
      await bulletinRef.update({
        'status': 'completed',
        'matches': analyzedMatches,
        'analyzedAt': DateTime.now().millisecondsSinceEpoch,
      });

      debugPrint('✅ ${analyzedMatches.length} maç analizi Realtime Database\'e kaydedildi');
      debugPrint('✅ Bülten durumu güncellendi: completed');

      return bulletinId;
    } catch (e) {
      debugPrint('❌ Analiz hatası: $e');
      rethrow;
    }
  }

  /// Gemini response'unu parse et
  List<Map<String, dynamic>> _parseGeminiResponse(String response) {
    try {
      // JSON parse
      final cleanResponse = response
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      
      final Map<String, dynamic> data = jsonDecode(cleanResponse);
      final matches = data['matches'] as List;
      
      return matches.map((m) => Map<String, dynamic>.from(m as Map)).toList();
    } catch (e) {
      debugPrint('❌ Gemini response parse hatası: $e');
      throw Exception('Gemini yanıtı işlenemedi');
    }
  }

  /// 🧠 AI ANALİZ MOTORU - 7 Bahis Türü
  Map<String, dynamic> _performAiAnalysis(Map<String, dynamic> matchData) {
    final homeStats = matchData['homeStats'] as Map<String, dynamic>?;
    final awayStats = matchData['awayStats'] as Map<String, dynamic>?;
    final h2h = matchData['h2h'] as List? ?? [];

    debugPrint('📊 Analiz: ${matchData['homeTeam']} vs ${matchData['awayTeam']}');
    debugPrint('  Home Stats: ${homeStats != null ? "✓" : "✗"}');
    debugPrint('  Away Stats: ${awayStats != null ? "✓" : "✗"}');
    debugPrint('  H2H: ${h2h.length} maç');

    // İstatistikleri parse et
    final stats = _parseStats(homeStats, awayStats);

    // 7 farklı bahis türü analizi
    final predictions = {
      'matchResult': _analyze1X2(stats),
      'over25': _analyzeOver25(stats),
      'btts': _analyzeBTTS(stats),
      'handicap': _analyzeHandicap(stats),
      'firstHalf': _analyzeFirstHalf(stats),
      'totalGoalsRange': _analyzeTotalGoalsRange(stats),
      'doubleChance': _analyzeDoubleChance(stats),
    };

    debugPrint('✅ Analiz tamam: ${predictions['matchResult']!['prediction']} (%${predictions['matchResult']!['confidence']})');

    return {
      'homeTeam': matchData['homeTeam'],
      'awayTeam': matchData['awayTeam'],
      'league': matchData['league'],
      'matchDate': matchData['matchDate'],
      'source': matchData['source'],
      'predictions': predictions,
      
      // Geriye dönük uyumluluk
      'aiPrediction': predictions['matchResult']!['prediction'],
      'confidence': predictions['matchResult']!['confidence'],
      'reasoning': predictions['matchResult']!['reasoning'],
      
      'homeStats': {
        'avgGoalsFor': stats['homeAvgFor']!.toStringAsFixed(2),
        'avgGoalsAgainst': stats['homeAvgAgainst']!.toStringAsFixed(2),
        'winRate': stats['homeWinRate']!.toInt(),
      },
      'awayStats': {
        'avgGoalsFor': stats['awayAvgFor']!.toStringAsFixed(2),
        'avgGoalsAgainst': stats['awayAvgAgainst']!.toStringAsFixed(2),
        'winRate': stats['awayWinRate']!.toInt(),
      },
    };
  }

  /// İstatistikleri parse et ve hesapla
  Map<String, double> _parseStats(Map<String, dynamic>? homeStats, Map<String, dynamic>? awayStats) {
    // Varsayılan değerler
    if (homeStats == null || awayStats == null) {
      debugPrint('  Varsayılan değerler kullanılıyor (stats yok)');
      return {
        'homeGamesPlayed': 10.0,
        'awayGamesPlayed': 10.0,
        'homeWins': 4.0,
        'homeDraws': 3.0,
        'homeLosses': 3.0,
        'awayWins': 3.0,
        'awayDraws': 3.0,
        'awayLosses': 4.0,
        'homeAvgFor': 1.3,
        'homeAvgAgainst': 1.2,
        'awayAvgFor': 1.1,
        'awayAvgAgainst': 1.3,
        'homeWinRate': 40.0,
        'awayWinRate': 30.0,
      };
    }

    // Football API formatı: goals.for.total.total
    final homeGoalsFor = _getDouble(homeStats, ['goals', 'for', 'total', 'total'], 13.0);
    final homeGoalsAgainst = _getDouble(homeStats, ['goals', 'against', 'total', 'total'], 12.0);
    final awayGoalsFor = _getDouble(awayStats, ['goals', 'for', 'total', 'total'], 11.0);
    final awayGoalsAgainst = _getDouble(awayStats, ['goals', 'against', 'total', 'total'], 13.0);

    final homeWins = _getDouble(homeStats, ['fixtures', 'wins', 'total'], 4.0);
    final homeDraws = _getDouble(homeStats, ['fixtures', 'draws', 'total'], 3.0);
    final homeLosses = _getDouble(homeStats, ['fixtures', 'loses', 'total'], 3.0);
    
    final awayWins = _getDouble(awayStats, ['fixtures', 'wins', 'total'], 3.0);
    final awayDraws = _getDouble(awayStats, ['fixtures', 'draws', 'total'], 3.0);
    final awayLosses = _getDouble(awayStats, ['fixtures', 'loses', 'total'], 4.0);

    final homeGamesPlayed = homeWins + homeDraws + homeLosses;
    final awayGamesPlayed = awayWins + awayDraws + awayLosses;

    debugPrint('  Ev: $homeGamesPlayed maç (${homeWins.toInt()}-${homeDraws.toInt()}-${homeLosses.toInt()}), Gol: ${homeGoalsFor.toInt()}/${homeGoalsAgainst.toInt()}');
    debugPrint('  Dep: $awayGamesPlayed maç (${awayWins.toInt()}-${awayDraws.toInt()}-${awayLosses.toInt()}), Gol: ${awayGoalsFor.toInt()}/${awayGoalsAgainst.toInt()}');

    return {
      'homeGamesPlayed': homeGamesPlayed > 0 ? homeGamesPlayed : 10.0,
      'awayGamesPlayed': awayGamesPlayed > 0 ? awayGamesPlayed : 10.0,
      'homeWins': homeWins,
      'homeDraws': homeDraws,
      'homeLosses': homeLosses,
      'awayWins': awayWins,
      'awayDraws': awayDraws,
      'awayLosses': awayLosses,
      'homeAvgFor': homeGamesPlayed > 0 ? homeGoalsFor / homeGamesPlayed : 1.3,
      'homeAvgAgainst': homeGamesPlayed > 0 ? homeGoalsAgainst / homeGamesPlayed : 1.2,
      'awayAvgFor': awayGamesPlayed > 0 ? awayGoalsFor / awayGamesPlayed : 1.1,
      'awayAvgAgainst': awayGamesPlayed > 0 ? awayGoalsAgainst / awayGamesPlayed : 1.3,
      'homeWinRate': homeGamesPlayed > 0 ? (homeWins / homeGamesPlayed) * 100 : 40.0,
      'awayWinRate': awayGamesPlayed > 0 ? (awayWins / awayGamesPlayed) * 100 : 30.0,
    };
  }

  /// Nested path'den double değer al
  double _getDouble(Map<String, dynamic> data, List<String> path, double defaultValue) {
    dynamic current = data;
    for (var key in path) {
      if (current is Map && current.containsKey(key)) {
        current = current[key];
      } else {
        return defaultValue;
      }
    }
    
    if (current is num) return current.toDouble();
    if (current is String) return double.tryParse(current) ?? defaultValue;
    return defaultValue;
  }

  /// 1X2 Analizi
  Map<String, dynamic> _analyze1X2(Map<String, double> stats) {
    final homeWinRate = stats['homeWinRate']!;
    final awayWinRate = stats['awayWinRate']!;
    final goalDiff = stats['homeAvgFor']! - stats['awayAvgFor']!;

    String prediction;
    int confidence;
    String reasoning;

    if (homeWinRate > 60 && goalDiff > 0.8) {
      prediction = '1';
      confidence = (70 + (homeWinRate - awayWinRate) * 0.3).toInt().clamp(65, 90);
      reasoning = 'Ev sahibi dominant: %${homeWinRate.toInt()} kazanma, ${stats['homeAvgFor']!.toStringAsFixed(1)} gol ort.';
    } else if (awayWinRate > 60 && goalDiff < -0.8) {
      prediction = '2';
      confidence = (70 + (awayWinRate - homeWinRate) * 0.3).toInt().clamp(65, 90);
      reasoning = 'Deplasman güçlü: %${awayWinRate.toInt()} kazanma, ${stats['awayAvgFor']!.toStringAsFixed(1)} gol ort.';
    } else if (homeWinRate > awayWinRate + 15) {
      prediction = '1';
      confidence = (60 + (homeWinRate - awayWinRate) * 0.4).toInt().clamp(55, 75);
      reasoning = 'Ev sahibi avantajlı: %${homeWinRate.toInt()} vs %${awayWinRate.toInt()}';
    } else if (awayWinRate > homeWinRate + 15) {
      prediction = '2';
      confidence = (60 + (awayWinRate - homeWinRate) * 0.4).toInt().clamp(55, 75);
      reasoning = 'Deplasman avantajlı: %${awayWinRate.toInt()} vs %${homeWinRate.toInt()}';
    } else {
      prediction = '1';
      confidence = 52;
      reasoning = 'Dengeli güçler, ev sahibi avantajı minimal';
    }

    return {'prediction': prediction, 'confidence': confidence, 'reasoning': reasoning};
  }

  /// Alt/Üst 2.5 Gol
  Map<String, dynamic> _analyzeOver25(Map<String, double> stats) {
    final totalExpected = (stats['homeAvgFor']! + stats['awayAvgAgainst']! + 
                           stats['awayAvgFor']! + stats['homeAvgAgainst']!) / 2;

    String prediction;
    int confidence;
    String reasoning;

    if (totalExpected > 3.0) {
      prediction = 'Üst 2.5';
      confidence = (65 + (totalExpected - 3.0) * 10).toInt().clamp(65, 85);
      reasoning = 'Yüksek gol beklentisi: ${totalExpected.toStringAsFixed(1)} gol tahmini';
    } else if (totalExpected < 2.0) {
      prediction = 'Alt 2.5';
      confidence = (65 + (2.0 - totalExpected) * 10).toInt().clamp(65, 85);
      reasoning = 'Düşük gol beklentisi: ${totalExpected.toStringAsFixed(1)} gol tahmini';
    } else {
      prediction = totalExpected > 2.5 ? 'Üst 2.5' : 'Alt 2.5';
      confidence = 58;
      reasoning = 'Orta seviye gol beklentisi: ${totalExpected.toStringAsFixed(1)} gol';
    }

    return {'prediction': prediction, 'confidence': confidence, 'reasoning': reasoning};
  }

  /// Karşılıklı Gol (BTTS)
  Map<String, dynamic> _analyzeBTTS(Map<String, double> stats) {
    final homeScoreProb = stats['homeAvgFor']! > 0.8;
    final awayScoreProb = stats['awayAvgFor']! > 0.8;

    String prediction;
    int confidence;
    String reasoning;

    if (homeScoreProb && awayScoreProb) {
      final avgScoring = (stats['homeAvgFor']! + stats['awayAvgFor']!) / 2;
      prediction = 'Var';
      confidence = (60 + avgScoring * 10).toInt().clamp(60, 80);
      reasoning = 'Her iki takım da gol buluyor (Ort: ${avgScoring.toStringAsFixed(1)} gol)';
    } else {
      prediction = 'Yok';
      confidence = 60;
      reasoning = 'En az bir takım gol bulma zorluğu yaşıyor';
    }

    return {'prediction': prediction, 'confidence': confidence, 'reasoning': reasoning};
  }

  /// Handikap
  Map<String, dynamic> _analyzeHandicap(Map<String, double> stats) {
    final goalDiff = stats['homeAvgFor']! - stats['awayAvgFor']!;

    String prediction;
    int confidence;

    if (goalDiff > 1.5) {
      prediction = 'Ev -1.5';
      confidence = 70;
    } else if (goalDiff > 0.8) {
      prediction = 'Ev -0.5';
      confidence = 65;
    } else if (goalDiff < -1.5) {
      prediction = 'Dep -1.5';
      confidence = 70;
    } else if (goalDiff < -0.8) {
      prediction = 'Dep -0.5';
      confidence = 65;
    } else {
      prediction = '0 (Dengeli)';
      confidence = 55;
    }

    return {
      'prediction': prediction,
      'confidence': confidence,
      'reasoning': 'Gol farkı: ${goalDiff.toStringAsFixed(2)}'
    };
  }

  /// İlk Yarı
  Map<String, dynamic> _analyzeFirstHalf(Map<String, double> stats) {
    final homeHalfGoals = stats['homeAvgFor']! * 0.42;
    final awayHalfGoals = stats['awayAvgFor']! * 0.42;

    String prediction;
    int confidence;

    if (homeHalfGoals > awayHalfGoals + 0.3) {
      prediction = '1';
      confidence = 60;
    } else if (awayHalfGoals > homeHalfGoals + 0.3) {
      prediction = '2';
      confidence = 60;
    } else {
      prediction = 'X';
      confidence = 55;
    }

    return {
      'prediction': prediction,
      'confidence': confidence,
      'reasoning': 'İlk yarı gol tahmini: Ev ${homeHalfGoals.toStringAsFixed(1)}, Dep ${awayHalfGoals.toStringAsFixed(1)}'
    };
  }

  /// Toplam Gol Aralığı
  Map<String, dynamic> _analyzeTotalGoalsRange(Map<String, double> stats) {
    final total = (stats['homeAvgFor']! + stats['awayAvgAgainst']! + 
                   stats['awayAvgFor']! + stats['homeAvgAgainst']!) / 2;

    String prediction;
    int confidence;

    if (total < 1.5) {
      prediction = '0-1 Gol';
      confidence = 65;
    } else if (total < 2.5) {
      prediction = '2-3 Gol';
      confidence = 70;
    } else if (total < 3.5) {
      prediction = '3-4 Gol';
      confidence = 65;
    } else {
      prediction = '4+ Gol';
      confidence = 60;
    }

    return {
      'prediction': prediction,
      'confidence': confidence,
      'reasoning': 'Toplam gol tahmini: ${total.toStringAsFixed(1)}'
    };
  }

  /// Çifte Şans
  Map<String, dynamic> _analyzeDoubleChance(Map<String, double> stats) {
    final homeNotLose = ((stats['homeWins']! + stats['homeDraws']!) / stats['homeGamesPlayed']!) * 100;
    final awayNotLose = ((stats['awayWins']! + stats['awayDraws']!) / stats['awayGamesPlayed']!) * 100;

    String prediction;
    int confidence;

    if (homeNotLose > 75) {
      prediction = '1X';
      confidence = 75;
    } else if (awayNotLose > 75) {
      prediction = 'X2';
      confidence = 75;
    } else if (homeNotLose > awayNotLose + 10) {
      prediction = '1X';
      confidence = 70;
    } else if (awayNotLose > homeNotLose + 10) {
      prediction = 'X2';
      confidence = 70;
    } else {
      prediction = '12';
      confidence = 65;
    }

    return {
      'prediction': prediction,
      'confidence': confidence,
      'reasoning': 'Kaybetmeme oranı: Ev %${homeNotLose.toInt()}, Dep %${awayNotLose.toInt()}'
    };
  }
}