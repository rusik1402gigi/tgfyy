import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/track.dart';

class ApiService {
  static const String _defaultUrl = "http://127.0.0.1:8000";
  static const String _prefKeyBaseUrl = "spotigram_backend_url";

  String _baseUrl = _defaultUrl;
  String get baseUrl => _baseUrl;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_prefKeyBaseUrl) ?? _defaultUrl;
  }

  Future<void> setBaseUrl(String url) async {
    String cleanUrl = url.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    _baseUrl = cleanUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyBaseUrl, _baseUrl);
  }

  Future<List<Track>> getTracks({int offset = 0, int limit = 50, String? tag}) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/tracks').replace(queryParameters: {
        'offset': offset.toString(),
        'limit': limit.toString(),
        if (tag != null) 'tag': tag,
      });

      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final List data = jsonDecode(utf8.decode(res.bodyBytes));
        return data.map((item) => Track.fromJson(item)).toList();
      }
    } catch (e) {
      print("[ApiService] getTracks error: $e");
    }
    return [];
  }

  Future<List<Track>> searchTracks(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final uri = Uri.parse('$_baseUrl/api/search').replace(queryParameters: {
        'q': query.trim(),
        'limit': '50',
      });

      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final List data = jsonDecode(utf8.decode(res.bodyBytes));
        return data.map((item) => Track.fromJson(item)).toList();
      }
    } catch (e) {
      print("[ApiService] searchTracks error: $e");
    }
    return [];
  }

  Future<List<Track>> getFavorites() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/api/favorites')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final List data = jsonDecode(utf8.decode(res.bodyBytes));
        return data.map((item) => Track.fromJson(item)).toList();
      }
    } catch (e) {
      print("[ApiService] getFavorites error: $e");
    }
    return [];
  }

  Future<List<PlaylistInfo>> getPlaylists() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/api/playlists')).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final List data = jsonDecode(utf8.decode(res.bodyBytes));
        return data.map((item) => PlaylistInfo.fromJson(item)).toList();
      }
    } catch (e) {
      print("[ApiService] getPlaylists error: $e");
    }
    return [];
  }

  Future<bool> toggleFavorite(String trackId) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/api/tracks/$trackId/favorite'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['is_favorite'] ?? false;
      }
    } catch (e) {
      print("[ApiService] toggleFavorite error: $e");
    }
    return false;
  }

  Future<Map<String, dynamic>> triggerSync() async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/api/sync')).timeout(const Duration(seconds: 30));
      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes));
      }
    } catch (e) {
      print("[ApiService] triggerSync error: $e");
    }
    return {"status": "error", "message": "Не удалось подключиться к серверу"};
  }

  Future<Map<String, dynamic>?> getStatus() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/api/status')).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes));
      }
    } catch (e) {
      print("[ApiService] getStatus error: $e");
    }
    return null;
  }
}

final apiService = ApiService();
