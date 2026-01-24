import 'package:http/http.dart' as http;
import 'dart:convert';
import './remote_config_service.dart';
import 'package:flutter/material.dart';

class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  final String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';
  final RemoteConfigService _remoteConfig = RemoteConfigService();
  
  String get _apiKey => _remoteConfig.geminiApiKey;

  /// Analyze image with language support
  Future<String> analyzeImage(String base64Image, {String languageCode = 'tr'}) async {
    try {
      // ⭐ Dynamic prompt based on language
      final String prompt = languageCode == 'en' 
          ? '''Analyze the football matches in this image and extract team names for each match.

IMPORTANT: Convert team names to their official English names. Must be compatible with Football-API.com.

Examples:
- "Espanyol II" → "Espanyol B"
- "Valencia M." → "Valencia Mestalla"  
- "Almería B" → "Almeria B"
- "Girona B" → "Girona B"
- Convert Turkish characters (ı,ğ,ü,ş,ö,ç) to English (i,g,u,s,o,c)

JSON format:
{
  "matches": [
    {
      "homeTeam": "Official English Team Name",
      "awayTeam": "Official English Team Name"
    }
  ]
}

Return only JSON, no additional explanation.'''
          : '''Bu görseldeki futbol maçlarını analiz et ve her maç için takım isimlerini çıkar.

ÖNEMLİ: Takım isimlerini resmi İngilizce isimlerine çevir. Football-API.com ile uyumlu olmalı.

Örnekler:
- "Espanyol II" → "Espanyol B"
- "Valencia M." → "Valencia Mestalla"  
- "Almería B" → "Almeria B"
- "Girona B" → "Girona B"
- Türkçe karakterleri (ı,ğ,ü,ş,ö,ç) İngilizce'ye çevir (i,g,u,s,o,c)

JSON formatı:
{
  "matches": [
    {
      "homeTeam": "Resmi İngilizce Takım Adı",
      "awayTeam": "Resmi İngilizce Takım Adı"
    }
  ]
}

Sadece JSON döndür, başka açıklama yazma.''';

      final url = Uri.parse('$_baseUrl/gemini-2.5-flash:generateContent?key=$_apiKey');

      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'text': prompt
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
      final url = Uri.parse('$_baseUrl/gemini-2.5-flash:generateContent?key=$_apiKey');

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

  /// ⭐ YENİ METOD: Google Search ile analiz (OPSIYONEL)
  Future<String> analyzeWithGoogleSearch(String prompt) async {
    try {
      print('🔍 Google Search ile analiz başlatılıyor...');
      
      final url = Uri.parse('$_baseUrl/gemini-2.0-flash-thinking-exp:generateContent?key=$_apiKey');

      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.1,
          'topK': 20,
          'topP': 0.9,
          'maxOutputTokens': 2048,
        },
        // ⭐ GOOGLE SEARCH AKTİF
        'tools': [
          {
            'googleSearch': {}
          }
        ]
      });

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
        
        print('✅ Google Search analizi tamamlandı');
        return text;
      } else {
        throw Exception('Gemini API error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Gemini Google Search Error: $e');
      rethrow;
    }
  }

  /// ⭐ YENİ: Opsiyonel Google Search ile analiz
  Future<String> analyzeWithOptionalSearch(String prompt, {bool useSearch = false}) async {
    try {
      final url = Uri.parse('$_baseUrl/gemini-2.5-flash:generateContent?key=$_apiKey');

      final body = jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.4,
          'maxOutputTokens': 2048,
        },
        if (useSearch) // ✅ Sadece gerekirse ekle
          'tools': [
            {'googleSearch': {}}
          ],
      });

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
      }

      throw Exception('Gemini error: ${response.statusCode}');
    } catch (e) {
      print('❌ Gemini Error: $e');
      rethrow;
    }
  }
}