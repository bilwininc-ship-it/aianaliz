class MatchPoolModel {
  final int fixtureId;
  final String homeTeam;
  final String awayTeam;
  final int homeTeamId;
  final int awayTeamId;
  final String league;
  final int leagueId;
  final String date;
  final String time;
  final int timestamp;
  final String status;
  final Map<String, dynamic>? homeStats;
  final Map<String, dynamic>? awayStats;
  final List<dynamic>? h2h;
  final int lastUpdated;

  MatchPoolModel({
    required this.fixtureId,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.league,
    required this.leagueId,
    required this.date,
    required this.time,
    required this.timestamp,
    required this.status,
    this.homeStats,
    this.awayStats,
    this.h2h,
    required this.lastUpdated,
  });

  /// Firebase'den gelen data'yı model'e çevir
  factory MatchPoolModel.fromJson(Map<String, dynamic> json) {
    return MatchPoolModel(
      fixtureId: json['fixtureId'] ?? 0,
      homeTeam: json['homeTeam'] ?? '',
      awayTeam: json['awayTeam'] ?? '',
      homeTeamId: json['homeTeamId'] ?? 0,
      awayTeamId: json['awayTeamId'] ?? 0,
      league: json['league'] ?? '',
      leagueId: json['leagueId'] ?? 0,
      date: json['date'] ?? '',
      time: json['time'] ?? '',
      timestamp: json['timestamp'] ?? 0,
      status: json['status'] ?? 'NS',
      homeStats: json['homeStats'] as Map<String, dynamic>?,
      awayStats: json['awayStats'] as Map<String, dynamic>?,
      h2h: json['h2h'] as List<dynamic>?,
      lastUpdated: json['lastUpdated'] ?? 0,
    );
  }

  /// Model'i Firebase'e kaydetmek için JSON'a çevir
  Map<String, dynamic> toJson() {
    return {
      'fixtureId': fixtureId,
      'homeTeam': homeTeam,
      'awayTeam': awayTeam,
      'homeTeamId': homeTeamId,
      'awayTeamId': awayTeamId,
      'league': league,
      'leagueId': leagueId,
      'date': date,
      'time': time,
      'timestamp': timestamp,
      'status': status,
      'homeStats': homeStats,
      'awayStats': awayStats,
      'h2h': h2h,
      'lastUpdated': lastUpdated,
    };
  }

  /// Maç bilgisini özet string olarak döndür
  String getMatchSummary() {
    return '$homeTeam vs $awayTeam - $date $time ($league)';
  }
}
