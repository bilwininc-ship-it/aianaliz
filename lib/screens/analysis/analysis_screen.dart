import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';
import '../../services/gemini_service.dart';
import '../../services/football_api_service.dart';
import '../../services/match_pool_service.dart';

class AnalysisScreen extends StatefulWidget {
  final String bulletinId;
  final String? base64Image;

  const AnalysisScreen({
    super.key,
    required this.bulletinId,
    this.base64Image,
  });

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final GeminiService _geminiService = GeminiService();
  final FootballApiService _footballApi = FootballApiService();
  final MatchPoolService _matchPool = MatchPoolService();

  bool _isAnalyzing = true;
  String _statusMessage = 'Görsel analiz ediliyor...';
  List<Map<String, dynamic>> _matches = [];
  List<Map<String, dynamic>> _analysisResults = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    
    if (widget.base64Image != null) {
      _startAnalysis();
    } else {
      _loadExistingAnalysis();
    }
  }

  Future<void> _loadExistingAnalysis() async {
    try {
      setState(() {
        _statusMessage = 'Analiz yükleniyor...';
      });

      final database = FirebaseDatabase.instance;
      final snapshot = await database.ref('bulletins/${widget.bulletinId}').get();
      
      if (!snapshot.exists) {
        throw Exception('Analiz bulunamadı');
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final matchesRaw = data['matches'];
      
      if (matchesRaw == null) {
        throw Exception('Bu analizde maç bilgisi bulunamadı');
      }

      final List<Map<String, dynamic>> parsedMatches = [];
      
      if (matchesRaw is List) {
        for (var match in matchesRaw) {
          if (match != null) {
            final matchMap = _deepConvertToMap(match);
            parsedMatches.add(matchMap);
          }
        }
      }
      
      if (parsedMatches.isEmpty) {
        throw Exception('Maç bilgisi okunamadı');
      }

      print('✅ ${parsedMatches.length} maç yüklendi');

      setState(() {
        _isAnalyzing = false;
        _analysisResults = parsedMatches;
        _statusMessage = 'Analiz yüklendi';
      });

    } catch (e) {
      print('❌ Analiz yükleme hatası: $e');
      setState(() {
        _isAnalyzing = false;
        _errorMessage = e.toString();
      });
    }
  }

  Map<String, dynamic> _deepConvertToMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(
        value.map((key, val) => MapEntry(key.toString(), _deepConvertValue(val)))
      );
    }
    return {};
  }

  dynamic _deepConvertValue(dynamic value) {
    if (value is Map) {
      return _deepConvertToMap(value);
    } else if (value is List) {
      return value.map((item) => _deepConvertValue(item)).toList();
    }
    return value;
  }

  Future<void> _startAnalysis() async {
    try {
      // 1. Görseli Gemini ile analiz et
      await _updateStatus('analyzing', 'Görsel analiz ediliyor...');
      final geminiResponse = await _geminiService.analyzeImage(widget.base64Image!);
      
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(geminiResponse);
      if (jsonMatch == null) {
        throw Exception('Gemini\'den geçersiz JSON yanıtı');
      }

      final jsonData = jsonDecode(jsonMatch.group(0)!);
      final matches = (jsonData['matches'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      if (matches.isEmpty) {
        throw Exception('Görselde maç bulunamadı');
      }

      print('📋 Gemini\'den gelen maçlar:');
      for (var match in matches) {
        print('  - ${match['homeTeam']} vs ${match['awayTeam']}');
      }

      setState(() {
        _matches = matches;
        _statusMessage = '${matches.length} maç bulundu. Analiz ediliyor...';
      });

      // 2. Tüm maçları analiz et
      await _analyzeAllMatchesInBatch(matches);

      // 3. Başarılı - Firebase'e kaydet
      await _updateStatus('completed', 'Analiz tamamlandı!');
      
      // ✅ YENİ: Analiz tamamlandı, geçmiş kuponlara yönlendir
      if (mounted) {
        // Kısa bir başarı mesajı göster
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Analiz başarıyla tamamlandı! Geçmiş kuponlara yönlendiriliyorsunuz...'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );

        // 1 saniye bekle, sonra geçmiş kuponlara git
        await Future.delayed(const Duration(seconds: 1));
        
        if (mounted) {
          // ✅ GoRouter ile /history sayfasına yönlendir
          context.go('/history');
        }
      }

    } catch (e) {
      print('❌ Analiz hatası: $e');
      await _updateStatus('failed', 'Analiz başarısız');
      
      setState(() {
        _isAnalyzing = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _analyzeAllMatchesInBatch(List<Map<String, dynamic>> matches) async {
    try {
      setState(() {
        _statusMessage = '🔥 Firebase havuzundan veriler alınıyor...';
      });

      List<Map<String, dynamic>> matchesWithData = [];
      int poolFoundCount = 0;
      int apiFoundCount = 0;
      
      for (int i = 0; i < matches.length; i++) {
        final match = matches[i];
        final homeTeam = match['homeTeam'] ?? '';
        final awayTeam = match['awayTeam'] ?? '';
        final userPrediction = match['userPrediction'] ?? '?';

        setState(() {
          _statusMessage = 'Maç ${i + 1}/${matches.length}: $homeTeam vs $awayTeam';
        });

        final poolMatch = await _matchPool.findMatchInPool(homeTeam, awayTeam);
        
        if (poolMatch != null) {
          poolFoundCount++;
          
          var homeStats = poolMatch.homeStats;
          var awayStats = poolMatch.awayStats;
          var h2h = poolMatch.h2h ?? [];
          
          if (homeStats == null || awayStats == null) {
            print('📊 Stats yoksa API\'den çekiliyor: ${poolMatch.fixtureId}');
            
            setState(() {
              _statusMessage = 'İstatistikler alınıyor: $homeTeam vs $awayTeam';
            });
            
            await Future.delayed(const Duration(milliseconds: 800));
            homeStats = await _footballApi.getTeamStats(
              poolMatch.homeTeamId, 
              poolMatch.leagueId,
            );
            
            await Future.delayed(const Duration(milliseconds: 800));
            awayStats = await _footballApi.getTeamStats(
              poolMatch.awayTeamId, 
              poolMatch.leagueId,
            );
            
            await Future.delayed(const Duration(milliseconds: 800));
            h2h = await _footballApi.getH2H(
              poolMatch.homeTeamId, 
              poolMatch.awayTeamId,
            );
            
            print('✅ Stats çekildi: $homeTeam vs $awayTeam');
          } else {
            print('✅ Stats zaten mevcut (Firebase Pool): $homeTeam vs $awayTeam');
          }
          
          matchesWithData.add({
            'homeTeam': poolMatch.homeTeam,
            'awayTeam': poolMatch.awayTeam,
            'league': poolMatch.league,
            'matchDate': poolMatch.date,
            'homeStats': homeStats,
            'awayStats': awayStats,
            'h2h': h2h,
            'userPrediction': userPrediction,
            'source': 'firebase_pool',
          });
          
          print('✅ Maç ${i + 1}: Firebase Pool - ${poolMatch.homeTeam} vs ${poolMatch.awayTeam}');
          
        } else {
          print('⚠ Maç ${i + 1}: Havuzda yok, Football API kullanılıyor...');
          
          setState(() {
            _statusMessage = 'Football API: $homeTeam vs $awayTeam';
          });
          
          final homeData = await _footballApi.searchAndGetTeamData(homeTeam);
          await Future.delayed(const Duration(milliseconds: 800));
          final awayData = await _footballApi.searchAndGetTeamData(awayTeam);
          
          apiFoundCount++;
          
          matchesWithData.add({
            'homeTeam': homeData?['name'] ?? homeTeam,
            'awayTeam': awayData?['name'] ?? awayTeam,
            'league': homeData?['league'] ?? 'Bilinmiyor',
            'matchDate': 'Bilinmiyor',
            'homeStats': homeData?['stats'],
            'awayStats': awayData?['stats'],
            'h2h': [],
            'userPrediction': userPrediction,
            'source': 'football_api',
          });
          
          print('✅ Maç ${i + 1}: Football API - ${homeData?['name'] ?? homeTeam} vs ${awayData?['name'] ?? awayTeam}');
        }
        
        await Future.delayed(const Duration(milliseconds: 800));
      }

      print('📊 Firebase Pool: $poolFoundCount/${matches.length} maç bulundu');
      print('📊 Football API: $apiFoundCount takım verisi çekildi');

      // Firebase'e kaydet
      await _saveAnalysisResults(matchesWithData);

    } catch (e, stackTrace) {
      print('❌ Batch analiz hatası: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> _saveAnalysisResults(List<Map<String, dynamic>> matchesWithData) async {
    try {
      final database = FirebaseDatabase.instance;
      
      final List<Map<String, dynamic>> analysisResults = [];
      
      for (var matchData in matchesWithData) {
        final analysis = _performAiAnalysis(matchData);
        analysisResults.add(analysis);
      }

      await database.ref('bulletins/${widget.bulletinId}/matches').set(analysisResults);
      
      print('✅ ${analysisResults.length} maç analizi Realtime Database\'e kaydedildi');

    } catch (e) {
      print('❌ Firebase kayıt hatası: $e');
      throw Exception('Analiz sonuçları kaydedilemedi: $e');
    }
  }

  Map<String, dynamic> _performAiAnalysis(Map<String, dynamic> matchData) {
    final homeStats = matchData['homeStats'];
    final awayStats = matchData['awayStats'];
    final h2h = matchData['h2h'] as List? ?? [];

    print('🔍 Analiz başlıyor: ${matchData['homeTeam']} vs ${matchData['awayTeam']}');
    
    final homeGoalsFor = _parseDouble(homeStats?['goals']?['for']?['total']?['total']);
    final homeGoalsAgainst = _parseDouble(homeStats?['goals']?['against']?['total']?['total']);
    final awayGoalsFor = _parseDouble(awayStats?['goals']?['for']?['total']?['total']);
    final awayGoalsAgainst = _parseDouble(awayStats?['goals']?['against']?['total']?['total']);

    final homeWins = _parseInt(homeStats?['fixtures']?['wins']?['total']);
    final homeDraws = _parseInt(homeStats?['fixtures']?['draws']?['total']);
    final homeLosses = _parseInt(homeStats?['fixtures']?['loses']?['total']);
    
    final awayWins = _parseInt(awayStats?['fixtures']?['wins']?['total']);
    final awayDraws = _parseInt(awayStats?['fixtures']?['draws']?['total']);
    final awayLosses = _parseInt(awayStats?['fixtures']?['loses']?['total']);

    final homeGamesPlayed = homeWins + homeDraws + homeLosses;
    final awayGamesPlayed = awayWins + awayDraws + awayLosses;

    final homeAvgGoalsFor = homeGamesPlayed > 0 ? homeGoalsFor / homeGamesPlayed : 1.3;
    final homeAvgGoalsAgainst = homeGamesPlayed > 0 ? homeGoalsAgainst / homeGamesPlayed : 1.3;
    final awayAvgGoalsFor = awayGamesPlayed > 0 ? awayGoalsFor / awayGamesPlayed : 1.1;
    final awayAvgGoalsAgainst = awayGamesPlayed > 0 ? awayGoalsAgainst / awayGamesPlayed : 1.3;

    // H2H analizi
    int homeH2HWins = 0;
    int awayH2HWins = 0;
    int h2hDraws = 0;
    double h2hTotalGoals = 0.0;
    int h2hBothScored = 0;

    if (h2h.isNotEmpty) {
      for (var game in h2h) {
        final homeTeamH2H = game['teams']?['home']?['name'] ?? '';
        final homeGoals = _parseDouble(game['goals']?['home']);
        final awayGoals = _parseDouble(game['goals']?['away']);

        h2hTotalGoals += homeGoals + awayGoals;
        if (homeGoals > 0 && awayGoals > 0) {
          h2hBothScored++;
        }

        if (homeTeamH2H.toLowerCase().contains(matchData['homeTeam'].toLowerCase())) {
          if (homeGoals > awayGoals) {
            homeH2HWins++;
          } else if (homeGoals < awayGoals) {
            awayH2HWins++;
          } else {
            h2hDraws++;
          }
        }
      }
    }

    final matchResultAnalysis = _analyze1X2(
      homeWins: homeWins,
      homeDraws: homeDraws,
      homeLosses: homeLosses,
      awayWins: awayWins,
      awayDraws: awayDraws,
      awayLosses: awayLosses,
      homeH2HWins: homeH2HWins,
      awayH2HWins: awayH2HWins,
      h2hDraws: h2hDraws,
      homeAvgGoalsFor: homeAvgGoalsFor,
      awayAvgGoalsFor: awayAvgGoalsFor,
      homeGamesPlayed: homeGamesPlayed,
      awayGamesPlayed: awayGamesPlayed,
    );

    final totalGoalsExpected = (homeAvgGoalsFor + awayAvgGoalsAgainst + awayAvgGoalsFor + homeAvgGoalsAgainst) / 2;
    final over25Analysis = _analyzeOver25Goals(
      totalGoalsExpected: totalGoalsExpected,
      homeAvgGoalsFor: homeAvgGoalsFor,
      awayAvgGoalsFor: awayAvgGoalsFor,
      h2hAvgGoals: h2h.isNotEmpty ? h2hTotalGoals / h2h.length : totalGoalsExpected,
    );

    final bttsAnalysis = _analyzeBTTS(
      homeAvgGoalsFor: homeAvgGoalsFor,
      awayAvgGoalsFor: awayAvgGoalsFor,
      homeAvgGoalsAgainst: homeAvgGoalsAgainst,
      awayAvgGoalsAgainst: awayAvgGoalsAgainst,
      h2hBothScored: h2hBothScored,
      h2hTotal: h2h.length,
    );

    final handicapAnalysis = _analyzeHandicap(
      homeAvgGoalsFor: homeAvgGoalsFor,
      awayAvgGoalsFor: awayAvgGoalsFor,
      homeWinRate: homeGamesPlayed > 0 ? homeWins / homeGamesPlayed : 0.4,
      awayWinRate: awayGamesPlayed > 0 ? awayWins / awayGamesPlayed : 0.3,
    );

    final firstHalfAnalysis = _analyzeFirstHalf(
      homeAvgGoalsFor: homeAvgGoalsFor,
      awayAvgGoalsFor: awayAvgGoalsFor,
      homeWinRate: homeGamesPlayed > 0 ? homeWins / homeGamesPlayed : 0.4,
      awayWinRate: awayGamesPlayed > 0 ? awayWins / awayGamesPlayed : 0.3,
    );

    final totalGoalsRangeAnalysis = _analyzeTotalGoalsRange(
      totalGoalsExpected: totalGoalsExpected,
    );

    final doubleChanceAnalysis = _analyzeDoubleChance(
      homeWins: homeWins,
      homeDraws: homeDraws,
      homeLosses: homeLosses,
      awayWins: awayWins,
      awayDraws: awayDraws,
      awayLosses: awayLosses,
      homeGamesPlayed: homeGamesPlayed,
      awayGamesPlayed: awayGamesPlayed,
    );

    return {
      'homeTeam': matchData['homeTeam'],
      'awayTeam': matchData['awayTeam'],
      'league': matchData['league'],
      'matchDate': matchData['matchDate'],
      'userPrediction': matchData['userPrediction'],
      'source': matchData['source'],
      
      'predictions': {
        'matchResult': matchResultAnalysis,
        'over25': over25Analysis,
        'btts': bttsAnalysis,
        'handicap': handicapAnalysis,
        'firstHalf': firstHalfAnalysis,
        'totalGoalsRange': totalGoalsRangeAnalysis,
        'doubleChance': doubleChanceAnalysis,
      },
      
      'aiPrediction': matchResultAnalysis['prediction'],
      'confidence': matchResultAnalysis['confidence'],
      'reasoning': matchResultAnalysis['reasoning'],
      
      'homeStats': {
        'avgGoalsFor': homeAvgGoalsFor.toStringAsFixed(2),
        'avgGoalsAgainst': homeAvgGoalsAgainst.toStringAsFixed(2),
        'winRate': homeGamesPlayed > 0 ? ((homeWins / homeGamesPlayed) * 100).toInt() : 0,
      },
      'awayStats': {
        'avgGoalsFor': awayAvgGoalsFor.toStringAsFixed(2),
        'avgGoalsAgainst': awayAvgGoalsAgainst.toStringAsFixed(2),
        'winRate': awayGamesPlayed > 0 ? ((awayWins / awayGamesPlayed) * 100).toInt() : 0,
      },
    };
  }

  Map<String, dynamic> _analyze1X2({
    required int homeWins,
    required int homeDraws,
    required int homeLosses,
    required int awayWins,
    required int awayDraws,
    required int awayLosses,
    required int homeH2HWins,
    required int awayH2HWins,
    required int h2hDraws,
    required double homeAvgGoalsFor,
    required double awayAvgGoalsFor,
    required int homeGamesPlayed,
    required int awayGamesPlayed,
  }) {
    if (homeGamesPlayed == 0 || awayGamesPlayed == 0) {
      return {
        'prediction': '1',
        'confidence': 55,
        'reasoning': 'Yetersiz istatistik - Ev sahibi avantajı uygulandı',
      };
    }

    final homeWinRate = (homeWins / homeGamesPlayed) * 100;
    final awayWinRate = (awayWins / awayGamesPlayed) * 100;
    final homeDrawRate = (homeDraws / homeGamesPlayed) * 100;
    final awayDrawRate = (awayDraws / awayGamesPlayed) * 100;
    final goalDiff = homeAvgGoalsFor - awayAvgGoalsFor;

    String prediction;
    int confidence;
    String reasoning;

    if (homeWinRate > 60 && goalDiff > 0.8) {
      prediction = '1';
      confidence = (70 + (homeWinRate - awayWinRate) * 0.3).toInt().clamp(65, 90);
      reasoning = 'Ev sahibi dominasyon gösteriyor: %${homeWinRate.toInt()} kazanma oranı';
    } else if (awayWinRate > 60 && goalDiff < -0.8) {
      prediction = '2';
      confidence = (70 + (awayWinRate - homeWinRate) * 0.3).toInt().clamp(65, 90);
      reasoning = 'Deplasman takımı çok güçlü: %${awayWinRate.toInt()} kazanma oranı';
    } else if (homeWinRate > awayWinRate + 15 && goalDiff > 0.3) {
      prediction = '1';
      confidence = (60 + (homeWinRate - awayWinRate) * 0.4).toInt().clamp(55, 75);
      reasoning = 'Ev sahibi daha istikrarlı: %${homeWinRate.toInt()} vs %${awayWinRate.toInt()}';
    } else if (awayWinRate > homeWinRate + 15 && goalDiff < -0.3) {
      prediction = '2';
      confidence = (60 + (awayWinRate - homeWinRate) * 0.4).toInt().clamp(55, 75);
      reasoning = 'Deplasman daha istikrarlı: %${awayWinRate.toInt()} vs %${homeWinRate.toInt()}';
    } else if ((homeDrawRate + awayDrawRate) / 2 > 35) {
      prediction = 'X';
      confidence = (55 + ((homeDrawRate + awayDrawRate) / 2 - 35)).toInt().clamp(50, 70);
      reasoning = 'Her iki takım da sık berabere kalıyor';
    } else if ((homeWinRate - awayWinRate).abs() < 10) {
      prediction = '1';
      confidence = 52;
      reasoning = 'Dengeli güçler, ev sahibi avantajı minimal';
    } else {
      prediction = '1';
      confidence = (55 + goalDiff * 5).toInt().clamp(50, 65);
      reasoning = 'Ev sahibi avantajı göz önünde bulunduruldu';
    }

    return {
      'prediction': prediction,
      'confidence': confidence,
      'reasoning': reasoning,
    };
  }

  Map<String, dynamic> _analyzeOver25Goals({
    required double totalGoalsExpected,
    required double homeAvgGoalsFor,
    required double awayAvgGoalsFor,
    required double h2hAvgGoals,
  }) {
    final avgGoals = (totalGoalsExpected + h2hAvgGoals) / 2;
    
    String prediction;
    int confidence;
    String reasoning;

    if (avgGoals > 3.0) {
      prediction = 'Üst 2.5';
      confidence = (65 + ((avgGoals - 3.0) * 10).clamp(0, 25)).toInt();
      reasoning = 'Yüksek gol ortalaması (Beklenen: ${avgGoals.toStringAsFixed(1)} gol)';
    } else if (avgGoals < 2.0) {
      prediction = 'Alt 2.5';
      confidence = (65 + ((2.0 - avgGoals) * 10).clamp(0, 25)).toInt();
      reasoning = 'Düşük gol ortalaması (Beklenen: ${avgGoals.toStringAsFixed(1)} gol)';
    } else {
      prediction = 'Üst 2.5';
      confidence = 50;
      reasoning = 'Orta seviye gol beklentisi (${avgGoals.toStringAsFixed(1)} gol)';
    }

    return {
      'prediction': prediction,
      'confidence': confidence,
      'reasoning': reasoning,
      'expectedGoals': avgGoals.toStringAsFixed(1),
    };
  }

  Map<String, dynamic> _analyzeBTTS({
    required double homeAvgGoalsFor,
    required double awayAvgGoalsFor,
    required double homeAvgGoalsAgainst,
    required double awayAvgGoalsAgainst,
    required int h2hBothScored,
    required int h2hTotal,
  }) {
    final bothTeamsScore = homeAvgGoalsFor >= 1.0 && awayAvgGoalsFor >= 1.0;
    final bothTeamsConcede = homeAvgGoalsAgainst >= 1.0 && awayAvgGoalsAgainst >= 1.0;
    final h2hBothScoredRate = h2hTotal > 0 ? (h2hBothScored / h2hTotal) * 100 : 0;

    String prediction;
    int confidence;
    String reasoning;

    if (bothTeamsScore && bothTeamsConcede) {
      prediction = 'Evet (KG Var)';
      confidence = (70 + h2hBothScoredRate * 0.2).toInt().clamp(55, 90);
      reasoning = 'Her iki takım da gol atıyor ve yiyor';
    } else if (!bothTeamsScore || homeAvgGoalsFor < 0.8 || awayAvgGoalsFor < 0.8) {
      prediction = 'Hayır (KG Yok)';
      confidence = 65;
      reasoning = 'En az bir takım gol üretmekte zorlanıyor';
    } else {
      prediction = 'Evet (KG Var)';
      confidence = 55;
      reasoning = 'Orta seviye karşılıklı gol olasılığı';
    }

    return {
      'prediction': prediction,
      'confidence': confidence,
      'reasoning': reasoning,
    };
  }

  Map<String, dynamic> _analyzeHandicap({
    required double homeAvgGoalsFor,
    required double awayAvgGoalsFor,
    required double homeWinRate,
    required double awayWinRate,
  }) {
    final goalDiff = homeAvgGoalsFor - awayAvgGoalsFor;
    final winRateDiff = homeWinRate - awayWinRate;

    String prediction;
    int confidence;
    String reasoning;

    if (goalDiff > 1.2 && winRateDiff > 0.25) {
      prediction = 'Ev Sahibi -1.5';
      confidence = (65 + (goalDiff * 10).clamp(0, 25)).toInt();
      reasoning = 'Ev sahibi net üstünlük';
    } else if (goalDiff < -1.2 && winRateDiff < -0.25) {
      prediction = 'Deplasman -1.5';
      confidence = (65 + (goalDiff.abs() * 10).clamp(0, 25)).toInt();
      reasoning = 'Deplasman net üstünlük';
    } else if (goalDiff > 0.5) {
      prediction = 'Ev Sahibi -0.5';
      confidence = 60;
      reasoning = 'Ev sahibi hafif üstün';
    } else if (goalDiff < -0.5) {
      prediction = 'Deplasman -0.5';
      confidence = 60;
      reasoning = 'Deplasman hafif üstün';
    } else {
      prediction = 'Handikap 0';
      confidence = 50;
      reasoning = 'Dengeli güçler';
    }

    return {
      'prediction': prediction,
      'confidence': confidence,
      'reasoning': reasoning,
    };
  }

  Map<String, dynamic> _analyzeFirstHalf({
    required double homeAvgGoalsFor,
    required double awayAvgGoalsFor,
    required double homeWinRate,
    required double awayWinRate,
  }) {
    final firstHalfHomeGoals = homeAvgGoalsFor * 0.42;
    final firstHalfAwayGoals = awayAvgGoalsFor * 0.42;

    String prediction;
    int confidence;
    String reasoning;

    if (firstHalfHomeGoals > firstHalfAwayGoals + 0.3 && homeWinRate > 0.5) {
      prediction = '1 (Ev Sahibi)';
      confidence = 60;
      reasoning = 'Ev sahibi ilk yarıda baskın';
    } else if (firstHalfAwayGoals > firstHalfHomeGoals + 0.3 && awayWinRate > 0.5) {
      prediction = '2 (Deplasman)';
      confidence = 60;
      reasoning = 'Deplasman ilk yarıda baskın';
    } else {
      prediction = 'X (Beraberlik)';
      confidence = 55;
      reasoning = 'İlk yarı genelde dengeli başlar';
    }

    return {
      'prediction': prediction,
      'confidence': confidence,
      'reasoning': reasoning,
    };
  }

  Map<String, dynamic> _analyzeTotalGoalsRange({
    required double totalGoalsExpected,
  }) {
    String prediction;
    int confidence;
    String reasoning;

    if (totalGoalsExpected < 1.5) {
      prediction = '0-1 Gol';
      confidence = 65;
      reasoning = 'Çok düşük gol beklentisi';
    } else if (totalGoalsExpected < 2.5) {
      prediction = '2-3 Gol';
      confidence = 70;
      reasoning = 'Normal gol beklentisi';
    } else if (totalGoalsExpected < 3.5) {
      prediction = '3-4 Gol';
      confidence = 65;
      reasoning = 'Yüksek gol beklentisi';
    } else {
      prediction = '4+ Gol';
      confidence = 60;
      reasoning = 'Çok yüksek gol beklentisi';
    }

    return {
      'prediction': prediction,
      'confidence': confidence,
      'reasoning': reasoning,
    };
  }

  Map<String, dynamic> _analyzeDoubleChance({
    required int homeWins,
    required int homeDraws,
    required int homeLosses,
    required int awayWins,
    required int awayDraws,
    required int awayLosses,
    required int homeGamesPlayed,
    required int awayGamesPlayed,
  }) {
    if (homeGamesPlayed == 0 || awayGamesPlayed == 0) {
      return {
        'prediction': '1X',
        'confidence': 55,
        'reasoning': 'Ev sahibi avantajı (yetersiz veri)',
      };
    }

    final homeNotLoseRate = ((homeWins + homeDraws) / homeGamesPlayed) * 100;
    final awayNotLoseRate = ((awayWins + awayDraws) / awayGamesPlayed) * 100;

    String prediction;
    int confidence;
    String reasoning;

    if (homeNotLoseRate > 75) {
      prediction = '1X';
      confidence = 75;
      reasoning = 'Ev sahibi kaybetme oranı çok düşük';
    } else if (awayNotLoseRate > 75) {
      prediction = 'X2';
      confidence = 75;
      reasoning = 'Deplasman kaybetme oranı çok düşük';
    } else if (homeNotLoseRate > awayNotLoseRate + 10) {
      prediction = '1X';
      confidence = 70;
      reasoning = 'Ev sahibi daha güvenli seçim';
    } else if (awayNotLoseRate > homeNotLoseRate + 10) {
      prediction = 'X2';
      confidence = 70;
      reasoning = 'Deplasman daha güvenli seçim';
    } else {
      prediction = '12';
      confidence = 65;
      reasoning = 'Net kazanan bekleniyor';
    }

    return {
      'prediction': prediction,
      'confidence': confidence,
      'reasoning': reasoning,
    };
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<void> _updateStatus(String status, String message) async {
    try {
      final database = FirebaseDatabase.instance;
      await database.ref('bulletins/${widget.bulletinId}').update({
        'status': status,
        'updatedAt': ServerValue.timestamp,
      });
    } catch (e) {
      print('⚠️ Durum güncellenemedi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // ✅ GoRouter ile geri git
            if (context.canPop()) {
              context.pop();
            } else {
              // Eğer pop edilemiyorsa home'a git
              context.go('/home');
            }
          },
          tooltip: 'Geri',
        ),
        title: const Text('Analiz Sonuçları'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isAnalyzing ? _buildLoadingView() : _buildResultsView(),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              _statusMessage,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (_matches.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '${_matches.length} maç tespit edildi',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultsView() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 80, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                'Analiz Başarısız',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
                child: const Text('Geri Dön'),
              ),
            ],
          ),
        ),
      );
    }

    // ✅ FIX: Sonuçlar yoksa bile mesaj göster
    if (_analysisResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 80, color: Colors.blue[300]),
              const SizedBox(height: 16),
              Text(
                'Analiz Sonucu Bulunamadı',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Henüz hiç maç analiz edilmedi',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    final totalCount = _analysisResults.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Colors.blue[50],
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  Icons.sports_soccer,
                  size: 48,
                  color: Colors.blue[700],
                ),
                const SizedBox(height: 12),
                Text(
                  '$totalCount Maç Analiz Edildi',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.blue[900],
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'AI tarafından 7 farklı bahis türü için profesyonel analiz yapıldı',
                  style: TextStyle(color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ..._analysisResults.map((result) => _buildMatchCard(result)),
      ],
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> result) {
    final predictions = result['predictions'] as Map<String, dynamic>?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sports_soccer, color: Colors.blue[700], size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${result['homeTeam']} vs ${result['awayTeam']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (result['league'] != null && result['league'] != 'Bilinmiyor')
                        Text(
                          result['league'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            if (predictions != null) ...[
              _buildPredictionRow(
                icon: Icons.emoji_events,
                title: 'Maç Sonucu',
                color: Colors.orange,
                prediction: predictions['matchResult']?['prediction'] ?? '?',
                confidence: predictions['matchResult']?['confidence'] ?? 0,
                reasoning: predictions['matchResult']?['reasoning'] ?? '',
              ),
              const SizedBox(height: 12),
              _buildPredictionRow(
                icon: Icons.sports_score,
                title: 'Alt/Üst 2.5 Gol',
                color: Colors.green,
                prediction: predictions['over25']?['prediction'] ?? '?',
                confidence: predictions['over25']?['confidence'] ?? 0,
                reasoning: predictions['over25']?['reasoning'] ?? '',
                extra: predictions['over25']?['expectedGoals'] != null
                    ? 'Beklenen: ${predictions['over25']['expectedGoals']} gol'
                    : null,
              ),
              const SizedBox(height: 12),
              _buildPredictionRow(
                icon: Icons.compare_arrows,
                title: 'Karşılıklı Gol',
                color: Colors.purple,
                prediction: predictions['btts']?['prediction'] ?? '?',
                confidence: predictions['btts']?['confidence'] ?? 0,
                reasoning: predictions['btts']?['reasoning'] ?? '',
              ),
              const SizedBox(height: 12),
              _buildPredictionRow(
                icon: Icons.balance,
                title: 'Handikap',
                color: Colors.blue,
                prediction: predictions['handicap']?['prediction'] ?? '?',
                confidence: predictions['handicap']?['confidence'] ?? 0,
                reasoning: predictions['handicap']?['reasoning'] ?? '',
              ),
              const SizedBox(height: 12),
              _buildPredictionRow(
                icon: Icons.timer_outlined,
                title: 'İlk Yarı',
                color: Colors.teal,
                prediction: predictions['firstHalf']?['prediction'] ?? '?',
                confidence: predictions['firstHalf']?['confidence'] ?? 0,
                reasoning: predictions['firstHalf']?['reasoning'] ?? '',
              ),
              const SizedBox(height: 12),
              _buildPredictionRow(
                icon: Icons.show_chart,
                title: 'Toplam Gol Aralığı',
                color: Colors.amber,
                prediction: predictions['totalGoalsRange']?['prediction'] ?? '?',
                confidence: predictions['totalGoalsRange']?['confidence'] ?? 0,
                reasoning: predictions['totalGoalsRange']?['reasoning'] ?? '',
              ),
              const SizedBox(height: 12),
              _buildPredictionRow(
                icon: Icons.casino,
                title: 'Çifte Şans',
                color: Colors.indigo,
                prediction: predictions['doubleChance']?['prediction'] ?? '?',
                confidence: predictions['doubleChance']?['confidence'] ?? 0,
                reasoning: predictions['doubleChance']?['reasoning'] ?? '',
              ),
            ],

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn(
                    'Ev Sahibi',
                    'Gol: ${result['homeStats']?['avgGoalsFor'] ?? '0'}',
                    'Kazanma: %${result['homeStats']?['winRate'] ?? 0}',
                  ),
                  Container(width: 1, height: 40, color: Colors.grey[400]),
                  _buildStatColumn(
                    'Deplasman',
                    'Gol: ${result['awayStats']?['avgGoalsFor'] ?? '0'}',
                    'Kazanma: %${result['awayStats']?['winRate'] ?? 0}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPredictionRow({
    required IconData icon,
    required String title,
    required Color color,
    required String prediction,
    required int confidence,
    required String reasoning,
    String? extra,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getConfidenceColor(confidence).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _getConfidenceColor(confidence),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bar_chart,
                      size: 12,
                      color: _getConfidenceColor(confidence),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '%$confidence',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: _getConfidenceColor(confidence),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            prediction,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: color,
            ),
          ),
          if (extra != null) ...[
            const SizedBox(height: 4),
            Text(
              extra,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline, size: 14, color: Colors.orange[700]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  reasoning,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String title, String stat1, String stat2) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          stat1,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
        Text(
          stat2,
          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Color _getConfidenceColor(int confidence) {
    if (confidence >= 75) return Colors.green;
    if (confidence >= 60) return Colors.orange;
    return Colors.red;
  }
}