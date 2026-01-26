import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:go_router/go_router.dart';
import '../../services/gemini_service.dart';
import '../../services/football_api_service.dart';
import '../../services/match_pool_service.dart';
import '../../l10n/app_localizations.dart';

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
  String _statusMessage = '';
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
    final loc = AppLocalizations.of(context)!;
    try {
      setState(() {
        _statusMessage = loc.t('loading_analysis');
      });

      final database = FirebaseDatabase.instance;
      final snapshot = await database.ref('bulletins/${widget.bulletinId}').get();
      
      if (!snapshot.exists) {
        throw Exception(loc.t('analysis_not_found'));
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final matchesRaw = data['matches'];
      
      if (matchesRaw == null) {
        throw Exception(loc.t('no_match_info'));
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
        throw Exception(loc.t('match_info_read_error'));
      }

      print('✅ ${parsedMatches.length} ${loc.t('matches_found')}');

      setState(() {
        _isAnalyzing = false;
        _analysisResults = parsedMatches;
        _statusMessage = loc.t('analysis_loaded');
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
    final loc = AppLocalizations.of(context)!;
    try {
      await _updateStatus('analyzing', loc.t('analyzing_image'));
      final geminiResponse = await _geminiService.analyzeImage(widget.base64Image!);
      
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(geminiResponse);
      if (jsonMatch == null) {
        throw Exception(loc.t('no_matches_in_image'));
      }

      final jsonData = jsonDecode(jsonMatch.group(0)!);
      final matches = (jsonData['matches'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      if (matches.isEmpty) {
        throw Exception(loc.t('no_matches_in_image'));
      }

      print('📋 Gemini\'den gelen maçlar:');
      for (var match in matches) {
        print('  - ${match['homeTeam']} vs ${match['awayTeam']}');
      }

      setState(() {
        _matches = matches;
        _statusMessage = '${matches.length} ${loc.t('matches_found')}';
      });

      await _analyzeAllMatchesInBatch(matches);
      await _updateStatus('completed', loc.t('analysis_completed'));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.t('bulletin_uploaded_successfully')),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );

        await Future.delayed(const Duration(seconds: 1));
        
        if (mounted) {
          context.go('/history');
        }
      }

    } catch (e) {
      print('❌ Analiz hatası: $e');
      await _updateStatus('failed', loc.t('analysis_failed'));
      
      setState(() {
        _isAnalyzing = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _analyzeAllMatchesInBatch(List<Map<String, dynamic>> matches) async {
    final loc = AppLocalizations.of(context)!;
    try {
      setState(() {
        _statusMessage = loc.t('fetching_from_firebase');
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
          _statusMessage = '${loc.t('match_analysis_detail')} ${i + 1}/${matches.length}: $homeTeam vs $awayTeam';
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
              _statusMessage = '${loc.t('fetching_stats')}: $homeTeam vs $awayTeam';
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
          print('⚠ Maç ${i + 1}: ${loc.t('fetching_from_pool')}, ${loc.t('football_api_source')}...');
          
          setState(() {
            _statusMessage = '${loc.t('football_api_source')}: $homeTeam vs $awayTeam';
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
        'reasoning': 'reasoning_insufficient_stats',
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
      reasoning = 'reasoning_home_domination';
    } else if (awayWinRate > 60 && goalDiff < -0.8) {
      prediction = '2';
      confidence = (70 + (awayWinRate - homeWinRate) * 0.3).toInt().clamp(65, 90);
      reasoning = 'reasoning_away_strong';
    } else if (homeWinRate > awayWinRate + 15 && goalDiff > 0.3) {
      prediction = '1';
      confidence = (60 + (homeWinRate - awayWinRate) * 0.4).toInt().clamp(55, 75);
      reasoning = 'reasoning_home_stable';
    } else if (awayWinRate > homeWinRate + 15 && goalDiff < -0.3) {
      prediction = '2';
      confidence = (60 + (awayWinRate - homeWinRate) * 0.4).toInt().clamp(55, 75);
      reasoning = 'reasoning_away_stable';
    } else if ((homeDrawRate + awayDrawRate) / 2 > 35) {
      prediction = 'X';
      confidence = (55 + ((homeDrawRate + awayDrawRate) / 2 - 35)).toInt().clamp(50, 70);
      reasoning = 'reasoning_both_draw_often';
    } else if ((homeWinRate - awayWinRate).abs() < 10) {
      prediction = '1';
      confidence = 52;
      reasoning = 'reasoning_balanced';
    } else {
      prediction = '1';
      confidence = (55 + goalDiff * 5).toInt().clamp(50, 65);
      reasoning = 'reasoning_home_advantage';
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
      prediction = 'pred_over_25';
      confidence = (65 + ((avgGoals - 3.0) * 10).clamp(0, 25)).toInt();
      reasoning = 'reasoning_high_goals';
    } else if (avgGoals < 2.0) {
      prediction = 'pred_under_25';
      confidence = (65 + ((2.0 - avgGoals) * 10).clamp(0, 25)).toInt();
      reasoning = 'reasoning_low_goals';
    } else {
      prediction = 'pred_over_25';
      confidence = 50;
      reasoning = 'reasoning_medium_goals';
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
      prediction = 'pred_btts_yes';
      confidence = (70 + h2hBothScoredRate * 0.2).toInt().clamp(55, 90);
      reasoning = 'reasoning_both_teams_score';
    } else if (!bothTeamsScore || homeAvgGoalsFor < 0.8 || awayAvgGoalsFor < 0.8) {
      prediction = 'pred_btts_no';
      confidence = 65;
      reasoning = 'reasoning_team_struggles';
    } else {
      prediction = 'pred_btts_yes';
      confidence = 55;
      reasoning = 'reasoning_medium_btts';
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
      prediction = 'pred_home_handicap_15';
      confidence = (65 + (goalDiff * 10).clamp(0, 25)).toInt();
      reasoning = 'reasoning_home_clear_advantage';
    } else if (goalDiff < -1.2 && winRateDiff < -0.25) {
      prediction = 'pred_away_handicap_15';
      confidence = (65 + (goalDiff.abs() * 10).clamp(0, 25)).toInt();
      reasoning = 'reasoning_away_clear_advantage';
    } else if (goalDiff > 0.5) {
      prediction = 'pred_home_handicap_05';
      confidence = 60;
      reasoning = 'reasoning_home_slight_advantage';
    } else if (goalDiff < -0.5) {
      prediction = 'pred_away_handicap_05';
      confidence = 60;
      reasoning = 'reasoning_away_slight_advantage';
    } else {
      prediction = 'pred_handicap_0';
      confidence = 50;
      reasoning = 'reasoning_balanced_forces';
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
      prediction = 'pred_first_half_home';
      confidence = 60;
      reasoning = 'reasoning_home_first_half_dominant';
    } else if (firstHalfAwayGoals > firstHalfHomeGoals + 0.3 && awayWinRate > 0.5) {
      prediction = 'pred_first_half_away';
      confidence = 60;
      reasoning = 'reasoning_away_first_half_dominant';
    } else {
      prediction = 'pred_first_half_draw';
      confidence = 55;
      reasoning = 'reasoning_first_half_balanced';
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
      prediction = 'pred_goals_0_1';
      confidence = 65;
      reasoning = 'reasoning_very_low_goals';
    } else if (totalGoalsExpected < 2.5) {
      prediction = 'pred_goals_2_3';
      confidence = 70;
      reasoning = 'reasoning_normal_goals';
    } else if (totalGoalsExpected < 3.5) {
      prediction = 'pred_goals_3_4';
      confidence = 65;
      reasoning = 'reasoning_high_goals_expected';
    } else {
      prediction = 'pred_goals_4_plus';
      confidence = 60;
      reasoning = 'reasoning_very_high_goals';
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
        'prediction': 'pred_double_1x',
        'confidence': 55,
        'reasoning': 'reasoning_home_advantage_insufficient',
      };
    }

    final homeNotLoseRate = ((homeWins + homeDraws) / homeGamesPlayed) * 100;
    final awayNotLoseRate = ((awayWins + awayDraws) / awayGamesPlayed) * 100;

    String prediction;
    int confidence;
    String reasoning;

    if (homeNotLoseRate > 75) {
      prediction = 'pred_double_1x';
      confidence = 75;
      reasoning = 'reasoning_home_low_loss_rate';
    } else if (awayNotLoseRate > 75) {
      prediction = 'pred_double_x2';
      confidence = 75;
      reasoning = 'reasoning_away_low_loss_rate';
    } else if (homeNotLoseRate > awayNotLoseRate + 10) {
      prediction = 'pred_double_1x';
      confidence = 70;
      reasoning = 'reasoning_home_safer';
    } else if (awayNotLoseRate > homeNotLoseRate + 10) {
      prediction = 'pred_double_x2';
      confidence = 70;
      reasoning = 'reasoning_away_safer';
    } else {
      prediction = 'pred_double_12';
      confidence = 65;
      reasoning = 'reasoning_clear_winner';
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
    final loc = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
          tooltip: loc.t('back'),
        ),
        title: Text(loc.t('analysis_results')),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isAnalyzing ? _buildLoadingView() : _buildResultsView(),
    );
  }

  Widget _buildLoadingView() {
    final loc = AppLocalizations.of(context)!;
    
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
                '${_matches.length} ${loc.t('matches_found')}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultsView() {
    final loc = AppLocalizations.of(context)!;
    
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
                loc.t('analysis_failed'),
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
                child: Text(loc.t('go_back')),
              ),
            ],
          ),
        ),
      );
    }

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
                loc.t('no_analysis_results'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                loc.t('no_matches_analyzed'),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    // ⭐ GOLDEN CARD: Tüm tahminler arasından en yüksek confidence'ı bul
    Map<String, dynamic>? goldenPick;
    String? goldenMatchId;
    String? goldenPredictionType;
    int maxConfidence = 0;

    for (int i = 0; i < _analysisResults.length; i++) {
      final match = _analysisResults[i];
      final predictions = match['predictions'] as Map<String, dynamic>?;
      
      if (predictions != null) {
        predictions.forEach((key, value) {
          final confidence = value['confidence'] as int? ?? 0;
          if (confidence > maxConfidence) {
            maxConfidence = confidence;
            goldenPick = value;
            goldenMatchId = '${match['homeTeam']} vs ${match['awayTeam']}';
            goldenPredictionType = key;
          }
        });
      }
    }

    // ⭐ Maçları maxConfidence'a göre sırala
    final sortedMatches = List<Map<String, dynamic>>.from(_analysisResults);
    sortedMatches.sort((a, b) {
      final aMax = _getMaxConfidenceForMatch(a);
      final bMax = _getMaxConfidenceForMatch(b);
      return bMax.compareTo(aMax);
    });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ⭐ GOLDEN CARD
        if (goldenPick != null && goldenMatchId != null)
          _buildGoldenCard(loc, goldenPick!, goldenMatchId!, goldenPredictionType!),
        
        const SizedBox(height: 24),
        
        // Header
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
                  '${sortedMatches.length} ${loc.t('matches_analyzed')}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.blue[900],
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  loc.t('professional_analysis_done'),
                  style: TextStyle(color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Maç kartları
        ...sortedMatches.map((result) => _buildMatchCard(loc, result)),
      ],
    );
  }

  int _getMaxConfidenceForMatch(Map<String, dynamic> match) {
    final predictions = match['predictions'] as Map<String, dynamic>?;
    if (predictions == null) return 0;
    
    int max = 0;
    predictions.forEach((key, value) {
      final confidence = value['confidence'] as int? ?? 0;
      if (confidence > max) max = confidence;
    });
    return max;
  }

  // ⭐ GOLDEN CARD Widget
  Widget _buildGoldenCard(AppLocalizations loc, Map<String, dynamic> pick, String matchId, String predictionType) {
    final confidence = pick['confidence'] as int? ?? 0;
    final prediction = pick['prediction'] as String? ?? '?';
    final reasoning = pick['reasoning'] as String? ?? '';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1976D2), // Mavi
            const Color(0xFF2E7D32), // Yeşil
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rozet
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.emoji_events, color: Colors.white, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        loc.t('todays_pick'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Maç bilgisi
            Text(
              matchId,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              _getPredictionTypeLabel(loc, predictionType),
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Tahmin
            Text(
              _getTranslatedPrediction(loc, prediction),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Yıldızlar + Confidence
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      ..._buildStars(confidence),
                      const SizedBox(width: 12),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '%$confidence',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: confidence / 100,
                minHeight: 8,
                backgroundColor: Colors.white.withOpacity(0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // İnsansı Yorum
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getFriendlyReasoning(loc, reasoning),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getPredictionTypeLabel(AppLocalizations loc, String type) {
    switch (type) {
      case 'matchResult':
        return loc.t('match_result');
      case 'over25':
        return loc.t('over_under_25');
      case 'btts':
        return loc.t('btts');
      case 'handicap':
        return loc.t('handicap');
      case 'firstHalf':
        return loc.t('first_half_result');
      case 'totalGoalsRange':
        return loc.t('total_goals_range');
      case 'doubleChance':
        return loc.t('double_chance');
      default:
        return type;
    }
  }

  List<Widget> _buildStars(int confidence) {
    int starCount = 1;
    if (confidence >= 81) {
      starCount = 5;
    } else if (confidence >= 71) {
      starCount = 4;
    } else if (confidence >= 61) {
      starCount = 3;
    } else if (confidence >= 51) {
      starCount = 2;
    }
    
    return List.generate(5, (index) {
      return Icon(
        index < starCount ? Icons.star : Icons.star_border,
        color: Colors.amber,
        size: 24,
      );
    });
  }

  String _getFriendlyReasoning(AppLocalizations loc, String reasoningKey) {
    // Eğer reasoning key ise, friendly versiyonunu kullan
    if (reasoningKey.startsWith('reasoning_')) {
      final friendlyKey = reasoningKey.replaceFirst('reasoning_', 'friendly_reasoning_');
      final friendly = loc.t(friendlyKey);
      // Eğer çeviri bulunamazsa (key döndüyse), normal reasoning'i kullan
      if (friendly == friendlyKey) {
        return loc.t(reasoningKey);
      }
      return friendly;
    }
    return reasoningKey;
  }

  /// Prediction key'lerini çeviriye dönüştür
  /// Hem yeni format (pred_over_25) hem eski format (Üst 2.5) desteklenir
  String _getTranslatedPrediction(AppLocalizations loc, String predictionKey) {
    // Eğer prediction key formatındaysa, çevir
    if (predictionKey.startsWith('pred_')) {
      return loc.t(predictionKey);
    }
    
    // Eski format için backward compatibility
    // Firebase'de hala eski Türkçe kayıtlar varsa onları da çevir
    final oldToNewKeyMap = {
      'Üst 2.5': 'pred_over_25',
      'Alt 2.5': 'pred_under_25',
      'Evet (KG Var)': 'pred_btts_yes',
      'Hayır (KG Yok)': 'pred_btts_no',
      'Ev Sahibi -1.5': 'pred_home_handicap_15',
      'Deplasman -1.5': 'pred_away_handicap_15',
      'Ev Sahibi -0.5': 'pred_home_handicap_05',
      'Deplasman -0.5': 'pred_away_handicap_05',
      'Handikap 0': 'pred_handicap_0',
      '1 (Ev Sahibi)': 'pred_first_half_home',
      '2 (Deplasman)': 'pred_first_half_away',
      'X (Beraberlik)': 'pred_first_half_draw',
      '0-1 Gol': 'pred_goals_0_1',
      '2-3 Gol': 'pred_goals_2_3',
      '3-4 Gol': 'pred_goals_3_4',
      '4+ Gol': 'pred_goals_4_plus',
      '1X': 'pred_double_1x',
      'X2': 'pred_double_x2',
      '12': 'pred_double_12',
    };
    
    // Eski format varsa key'e çevir ve sonra translate et
    if (oldToNewKeyMap.containsKey(predictionKey)) {
      return loc.t(oldToNewKeyMap[predictionKey]!);
    }
    
    // Hiçbiri değilse olduğu gibi döndür
    return predictionKey;
  }

  Widget _buildMatchCard(AppLocalizations loc, Map<String, dynamic> result) {
    final predictions = result['predictions'] as Map<String, dynamic>?;
    
    // Tahminleri confidence'a göre sırala
    List<MapEntry<String, dynamic>> sortedPredictions = [];
    if (predictions != null) {
      sortedPredictions = predictions.entries.toList();
      sortedPredictions.sort((a, b) {
        final aConf = a.value['confidence'] as int? ?? 0;
        final bConf = b.value['confidence'] as int? ?? 0;
        return bConf.compareTo(aConf);
      });
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Maç başlığı
            Row(
              children: [
                Icon(Icons.sports_soccer, color: Colors.blue[700], size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${result['homeTeam']} vs ${result['awayTeam']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      if (result['league'] != null && result['league'] != 'Bilinmiyor')
                        Text(
                          result['league'],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            
            const Divider(height: 28),

            // Tahminler (sıralı)
            if (sortedPredictions.isNotEmpty) ...[
              ...sortedPredictions.map((entry) {
                final type = entry.key;
                final pred = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _buildPredictionRow(
                    loc: loc,
                    type: type,
                    prediction: pred['prediction'] ?? '?',
                    confidence: pred['confidence'] ?? 0,
                    reasoning: pred['reasoning'] ?? '',
                    extra: pred['expectedGoals'],
                  ),
                );
              }),
            ],

            const SizedBox(height: 12),
            
            // İstatistikler
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn(
                    loc,
                    loc.t('home_team'),
                    '${loc.t('goals')}: ${result['homeStats']?['avgGoalsFor'] ?? '0'}',
                    '${loc.t('win_rate')}: %${result['homeStats']?['winRate'] ?? 0}',
                  ),
                  Container(width: 1, height: 40, color: Colors.grey[400]),
                  _buildStatColumn(
                    loc,
                    loc.t('away_team'),
                    '${loc.t('goals')}: ${result['awayStats']?['avgGoalsFor'] ?? '0'}',
                    '${loc.t('win_rate')}: %${result['awayStats']?['winRate'] ?? 0}',
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
    required AppLocalizations loc,
    required String type,
    required String prediction,
    required int confidence,
    required String reasoning,
    String? extra,
  }) {
    final color = _getPredictionColor(type);
    final icon = _getPredictionIcon(type);
    final label = _getPredictionTypeLabel(loc, type);
    
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.grey[800],
                ),
              ),
              const Spacer(),
              // Yıldızlar (küçük)
              ..._buildSmallStars(confidence),
              const SizedBox(width: 8),
              // Confidence badge with Flexible to prevent overflow
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _getConfidenceColor(confidence).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getConfidenceColor(confidence),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      '%$confidence',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _getConfidenceColor(confidence),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 10),
          
          // Tahmin
          Text(
            _getTranslatedPrediction(loc, prediction),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
          
          if (extra != null) ...[
            const SizedBox(height: 5),
            Text(
              '${loc.t('expected')}: $extra ${loc.t('goal')}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          
          const SizedBox(height: 10),
          
          // Progress Bar (Pastel)
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: confidence / 100,
              minHeight: 6,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                color.withOpacity(0.7),
              ),
            ),
          ),
          
          const SizedBox(height: 10),
          
          // İnsansı Yorum
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.psychology, size: 16, color: Colors.deepPurple[300]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getFriendlyReasoning(loc, reasoning),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSmallStars(int confidence) {
    int starCount = 1;
    if (confidence >= 81) {
      starCount = 5;
    } else if (confidence >= 71) {
      starCount = 4;
    } else if (confidence >= 61) {
      starCount = 3;
    } else if (confidence >= 51) {
      starCount = 2;
    }
    
    return List.generate(5, (index) {
      return Icon(
        index < starCount ? Icons.star : Icons.star_border,
        color: Colors.amber[700],
        size: 16,
      );
    });
  }

  Color _getPredictionColor(String type) {
    switch (type) {
      case 'matchResult':
        return Colors.orange;
      case 'over25':
        return Colors.green;
      case 'btts':
        return Colors.purple;
      case 'handicap':
        return Colors.blue;
      case 'firstHalf':
        return Colors.teal;
      case 'totalGoalsRange':
        return Colors.amber;
      case 'doubleChance':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  IconData _getPredictionIcon(String type) {
    switch (type) {
      case 'matchResult':
        return Icons.emoji_events;
      case 'over25':
        return Icons.sports_score;
      case 'btts':
        return Icons.compare_arrows;
      case 'handicap':
        return Icons.balance;
      case 'firstHalf':
        return Icons.timer_outlined;
      case 'totalGoalsRange':
        return Icons.show_chart;
      case 'doubleChance':
        return Icons.casino;
      default:
        return Icons.help_outline;
    }
  }

  Widget _buildStatColumn(AppLocalizations loc, String title, String stat1, String stat2) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          stat1,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        Text(
          stat2,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
