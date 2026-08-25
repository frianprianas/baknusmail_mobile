import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/jamendo_music.dart';

class JamendoService {
  static const String _clientId = '56b41cb8'; // Jamendo Public API Client ID
  static const String _baseUrl = 'https://api.jamendo.com/v3.0/tracks';
  static const String _itunesSearchUrl = 'https://itunes.apple.com/search';

  /// Mengambil daftar trek lagu populer (Trending/Popular)
  Future<List<JamendoMusic>> fetchTrendingTracks({int limit = 25}) async {
    // 1. Coba panggil Jamendo API
    try {
      final url = Uri.parse('$_baseUrl/?client_id=$_clientId&format=json&limit=$limit&order=popularity_week&audioformat=mp32');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List<dynamic>? ?? [];
        if (results.isNotEmpty) {
          return results.map((item) => JamendoMusic.fromJson(Map<String, dynamic>.from(item))).toList();
        }
      }
    } catch (e) {
      debugPrint('Jamendo API fetch failed, falling back to iTunes API: $e');
    }

    // 2. Fallback otomatis ke iTunes Search API (100% Reliabel, Bebas API Key & Memiliki MP3 Preview)
    return _fetchFromITunes('indonesia pop', limit: limit);
  }

  /// Mencari lagu berdasarkan nama trek atau artis
  Future<List<JamendoMusic>> searchTracks(String query, {int limit = 25}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      return fetchTrendingTracks(limit: limit);
    }

    // 1. Coba panggil Jamendo API
    try {
      final url = Uri.parse(
        '$_baseUrl/?client_id=$_clientId&format=json&limit=$limit&namesearch=${Uri.encodeComponent(cleanQuery)}&audioformat=mp32',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List<dynamic>? ?? [];
        if (results.isNotEmpty) {
          return results.map((item) => JamendoMusic.fromJson(Map<String, dynamic>.from(item))).toList();
        }
      }
    } catch (e) {
      debugPrint('Jamendo API search failed, falling back to iTunes API: $e');
    }

    // 2. Fallback otomatis ke iTunes Search API
    return _fetchFromITunes(cleanQuery, limit: limit);
  }

  /// Helper untuk mengambil data dari iTunes Search API jika Jamendo API error/unauthorized
  Future<List<JamendoMusic>> _fetchFromITunes(String query, {int limit = 25}) async {
    try {
      final url = Uri.parse(
        '$_itunesSearchUrl?term=${Uri.encodeComponent(query)}&entity=song&limit=$limit',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List<dynamic>? ?? [];
        return results
            .map((item) {
              final map = Map<String, dynamic>.from(item);
              final preview = map['previewUrl']?.toString() ?? '';
              if (preview.isEmpty) return null;

              final durationMs = map['trackTimeMillis'] is num ? (map['trackTimeMillis'] as num).toInt() : 30000;

              return JamendoMusic(
                id: map['trackId']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
                name: map['trackName']?.toString() ?? 'Tanpa Judul',
                artistName: map['artistName']?.toString() ?? 'Unknown Artist',
                audioUrl: preview,
                coverUrl: map['artworkUrl100']?.toString() ?? map['artworkUrl60']?.toString() ?? '',
                duration: (durationMs / 1000).round(),
              );
            })
            .whereType<JamendoMusic>()
            .toList();
      }
    } catch (e) {
      debugPrint('iTunes API fetch error: $e');
    }
    return [];
  }
}
