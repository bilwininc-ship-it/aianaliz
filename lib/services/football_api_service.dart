import 'package:http/http.dart' as http;
import 'dart:convert';
import './remote_config_service.dart';

class FootballApiService {
  static final FootballApiService _instance = FootballApiService._internal();
  factory FootballApiService() => _instance;
  FootballApiService._internal();

  final String _baseUrl = 'https://v3.football.api-sports.io';
  final RemoteConfigService _remoteConfig = RemoteConfigService();
  
  String get _apiKey => _remoteConfig.footballApiKey;

  /// 🆕 YENİ METOD: Takım ara ve tüm verileri getir (analysis_screen için)
  Future<Map<String, dynamic>?> searchAndGetTeamData(String teamName) async {
    try {
      print('🔍 Aranıyor: $teamName → ${_cleanTurkishChars(teamName)}');
      
      // 1. Takımı ara
      final team = await searchTeam(teamName);
      
      if (team == null) {
        print('❌ Bulunamadı: $teamName');
        return null;
      }
      
      final teamId = team['team']['id'] as int;
      final teamOfficialName = team['team']['name'] as String;
      final leagues = team['leagues'] as List<int>? ?? [];
      
      // 2. İlk ligden istatistik çek
      Map<String, dynamic>? stats;
      if (leagues.isNotEmpty) {
        final leagueId = leagues.first;
        print('📊 İstatistik alınıyor: Team=$teamId, League=$leagueId');
        
        await Future.delayed(const Duration(milliseconds: 800));
        stats = await getTeamStats(teamId, leagueId);
      } else {
        print('⚠️ $teamOfficialName için lig bilgisi yok');
      }
      
      return {
        'name': teamOfficialName,
        'id': teamId,
        'league': leagues.isNotEmpty ? 'Lig Bilgisi Mevcut' : 'Bilinmiyor',
        'leagueId': leagues.isNotEmpty ? leagues.first : 0,
        'stats': stats,
      };
      
    } catch (e) {
      print('❌ searchAndGetTeamData hatası: $e');
      return null;
    }
  }

  /// Takım bilgisi getir (isim ile arama - akıllı arama)
  Future<Map<String, dynamic>?> searchTeam(String teamName) async {
    try {
      final cleanName = _cleanTurkishChars(teamName);
      print('🔍 Aranıyor: $teamName → $cleanName');
      
      // ✅ URL encoding ekle
      final encodedName = Uri.encodeComponent(cleanName);
      final url = Uri.parse('$_baseUrl/teams?search=$encodedName');
      final response = await http.get(url, headers: {
        'x-rapidapi-host': 'v3.football.api-sports.io',
        'x-rapidapi-key': _apiKey,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final teams = data['response'] as List?;
        
        if (teams != null && teams.isNotEmpty) {
          final team = teams.first;
          print('✅ Bulundu: ${team['team']['name']} (ID: ${team['team']['id']})');
          
          // ⭐ YENİ: Takımın oynadığı ligleri de getir
          final teamId = team['team']['id'];
          final leagues = await _getTeamLeagues(teamId);
          
          return {
            ...team,
            'leagues': leagues, // ⭐ Ligleri ekle
          };
        }
        
        print('❌ Bulunamadı: $teamName');
        return null;
      } else if (response.statusCode == 429) {
        print('⚠️ Rate limit! 5 saniye bekleniyor...');
        await Future.delayed(const Duration(seconds: 5));
        return null;
      } else {
        throw Exception('Football API error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Football API Search Error: $e');
      return null;
    }
  }

  /// ⭐ YENİ: Takımın oynadığı ligleri getir
  Future<List<int>> _getTeamLeagues(int teamId) async {
    try {
      final season = DateTime.now().year;
      final url = Uri.parse('$_baseUrl/leagues?team=$teamId&season=$season');
      
      final response = await http.get(url, headers: {
        'x-rapidapi-host': 'v3.football.api-sports.io',
        'x-rapidapi-key': _apiKey,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final leagues = data['response'] as List?;
        
        if (leagues != null && leagues.isNotEmpty) {
          // Lig ID'lerini çıkar
          return leagues.map<int>((l) => l['league']['id'] as int).toList();
        }
      } else {
        print('! Ligler alınamadı: ${response.statusCode}');
      }
      
      return [];
    } catch (e) {
      print('! Ligler alınamadı: $e');
      return [];
    }
  }

  /// Türkçe karakterleri temizle
  String _cleanTurkishChars(String text) {
    final map = {
      'ç': 'c', 'Ç': 'C', 'ğ': 'g', 'Ğ': 'G',
      'ı': 'i', 'İ': 'I', 'ö': 'o', 'Ö': 'O',
      'ş': 's', 'Ş': 'S', 'ü': 'u', 'Ü': 'U',
    };
    
    var clean = text;
    map.forEach((turkish, english) {
      clean = clean.replaceAll(turkish, english);
    });
    
    return clean.trim().toLowerCase();
  }

  /// Takım istatistikleri (league ZORUNLU!)
  Future<Map<String, dynamic>?> getTeamStats(int teamId, int leagueId) async {
    try {
      // ✅ Lig ID kontrolü ekle
      if (leagueId == 0) {
        print('⚠️ Lig ID yok, stats alınamıyor');
        return null;
      }
      
      final season = DateTime.now().year;
      
      print('📊 İstatistik alınıyor: Team=$teamId, League=$leagueId, Season=$season');
      
      final url = Uri.parse('$_baseUrl/teams/statistics?team=$teamId&season=$season&league=$leagueId');

      final response = await http.get(url, headers: {
        'x-rapidapi-host': 'v3.football.api-sports.io',
        'x-rapidapi-key': _apiKey,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Boş response kontrolü
        if (data['response'] == null || 
            (data['response'] is Map && (data['response'] as Map).isEmpty)) {
          print('⚠️ İstatistik verisi yok');
          return null;
        }
        
        print('✅ İstatistik alındı');
        return data['response'];
      } else if (response.statusCode == 429) {
        print('⚠️ Rate limit! 5 saniye bekleniyor...');
        await Future.delayed(const Duration(seconds: 5));
        return null;
      } else {
        print('❌ API Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Stats Error: $e');
      return null;
    }
  }

  /// Son 5 maç sonucu
  Future<List<Map<String, dynamic>>> getLastMatches(int teamId, {int limit = 5}) async {
    try {
      print('🔄 Son $limit maç alınıyor: Team=$teamId');
      
      final url = Uri.parse('$_baseUrl/fixtures?team=$teamId&last=$limit');

      final response = await http.get(url, headers: {
        'x-rapidapi-host': 'v3.football.api-sports.io',
        'x-rapidapi-key': _apiKey,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final fixtures = data['response'] as List?;
        
        if (fixtures != null && fixtures.isNotEmpty) {
          print('✅ ${fixtures.length} maç alındı');
          return fixtures.cast<Map<String, dynamic>>();
        }
        
        print('⚠️ Maç verisi yok');
        return [];
      } else if (response.statusCode == 429) {
        print('⚠️ Rate limit! 5 saniye bekleniyor...');
        await Future.delayed(const Duration(seconds: 5));
        return [];
      } else {
        print('❌ API Error: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Last Matches Error: $e');
      return [];
    }
  }

  /// İki takım arasındaki H2H (head to head)
  Future<List<Map<String, dynamic>>> getH2H(int team1Id, int team2Id) async {
    try {
      final url = Uri.parse('$_baseUrl/fixtures/headtohead?h2h=$team1Id-$team2Id');

      final response = await http.get(
        url,
        headers: {
          'x-rapidapi-host': 'v3.football.api-sports.io',
          'x-rapidapi-key': _apiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final fixtures = data['response'] as List?;
        return fixtures?.cast<Map<String, dynamic>>() ?? [];
      } else if (response.statusCode == 429) {
        print('⚠️ Rate limit! 5 saniye bekleniyor...');
        await Future.delayed(const Duration(seconds: 5));
        return [];
      } else {
        throw Exception('Football API error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Football API H2H Error: $e');
      return [];
    }
  }

  /// API quota kontrolü
  Future<Map<String, dynamic>?> getApiStatus() async {
    try {
      final url = Uri.parse('$_baseUrl/status');

      final response = await http.get(
        url,
        headers: {
          'x-rapidapi-host': 'v3.football.api-sports.io',
          'x-rapidapi-key': _apiKey,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'];
      }
      return null;
    } catch (e) {
      print('❌ Football API Status Error: $e');
      return null;
    }
  }
}