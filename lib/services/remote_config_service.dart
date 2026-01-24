import 'package:firebase_remote_config/firebase_remote_config.dart';

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  late FirebaseRemoteConfig _remoteConfig;
  bool _initialized = false;

  final Map<String, dynamic> _defaults = {
    'GEMINI_API_KEY': '',
    'API_FOOTBALL_KEY': '',
    'min_app_version': '1.0.0',
    'force_update': false,
    'maintenance_mode': false,
  };

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _remoteConfig = FirebaseRemoteConfig.instance;

      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(minutes: 1),
        ),
      );

      await _remoteConfig.setDefaults(_defaults);
      await _remoteConfig.fetchAndActivate();

      _initialized = true;
      print('✅ Remote Config initialized');
    } catch (e) {
      print('❌ Remote Config initialization error: $e');
      _initialized = true;
    }
  }

  String get geminiApiKey {
    try {
      final key = _remoteConfig.getString('GEMINI_API_KEY');
      if (key.isEmpty) throw Exception('GEMINI_API_KEY is empty');
      return key;
    } catch (e) {
      print('❌ Error getting Gemini API key: $e');
      throw Exception('Gemini API key not configured');
    }
  }

  String get footballApiKey {
    try {
      final key = _remoteConfig.getString('API_FOOTBALL_KEY');
      if (key.isEmpty) throw Exception('API_FOOTBALL_KEY is empty');
      return key;
    } catch (e) {
      print('❌ Error getting Football API key: $e');
      throw Exception('Football API key not configured');
    }
  }

  String get minAppVersion => _remoteConfig.getString('min_app_version');
  bool get forceUpdate => _remoteConfig.getBool('force_update');
  bool get maintenanceMode => _remoteConfig.getBool('maintenance_mode');

  Future<void> refresh() async {
    try {
      await _remoteConfig.fetchAndActivate();
      print('✅ Remote Config refreshed');
    } catch (e) {
      print('❌ Remote Config refresh error: $e');
    }
  }

  void printAllConfigs() {
    print('=== Remote Config Values ===');
    try {
      print('GEMINI_API_KEY: ${geminiApiKey.substring(0, 10)}...');
      print('API_FOOTBALL_KEY: ${footballApiKey.substring(0, 10)}...');
    } catch (e) {
      print('API keys not configured yet');
    }
    print('min_app_version: $minAppVersion');
    print('force_update: $forceUpdate');
    print('maintenance_mode: $maintenanceMode');
    print('============================');
  }
}