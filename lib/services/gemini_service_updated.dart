import 'package:http/http.dart' as http;
import 'dart:convert';
import './remote_config_service.dart';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  final String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';
  final RemoteConfigService _remoteConfig = RemoteConfigService();
  
  String get _apiKey => _remoteConfig.geminiApiKey;

  /// Gemini 2.5 Pro ile görsel analizi
  Future<String> analyzeImage(String base64Image) async {
    try {
      final url = Uri.parse('$_baseUrl/gemini-2.0-flash-exp:generateContent?key=$_apiKey');

      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'text': 'Bu spor bülteni görselini analiz et ve JSON formatında yanıt ver.'
              },
              {
                'inline_data': {
                  'mime_type': 'image/jpeg',
                  'data': base64Image,
                }
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.4,
          'topK': 32,
          'topP': 1,
          'maxOutputTokens': 8192,
        }
      });

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
        
        if (text.isEmpty) {
          throw Exception('Gemini boş yanıt döndü');
        }
        
        return text;
      } else {
        throw Exception('Gemini API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Gemini Service Error: $e');
      rethrow;
    }
  }

  /// Metin analizi (opsiyonel)
  Future<String> analyzeText(String prompt) async {
    try {
      final url = Uri.parse('$_baseUrl/gemini-2.0-flash-exp:generateContent?key=$_apiKey');

      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 2048,
        }
      });

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
      } else {
        throw Exception('Gemini API error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Gemini Text Analysis Error: $e');
      rethrow;
    }
  }
}