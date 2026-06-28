import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const String baseUrl = 'https://revenue.nexarcit.com';
  static const String _tokenKey = 'session_token';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _getToken();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      // Backend uses cookie named 'session_token'
      headers['Cookie'] = 'session_token=$token';
    }
    return headers;
  }

  /// Login. The server sets an httpOnly cookie — we extract it from Set-Cookie header.
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      // Extract session_token from Set-Cookie header
      final setCookie = response.headers['set-cookie'] ?? '';
      String? token;
      for (final part in setCookie.split(';')) {
        final trimmed = part.trim();
        if (trimmed.startsWith('session_token=')) {
          token = trimmed.substring('session_token='.length);
          break;
        }
      }
      // Also check for comma-separated cookies
      if (token == null) {
        for (final cookie in setCookie.split(',')) {
          for (final part in cookie.split(';')) {
            final trimmed = part.trim();
            if (trimmed.startsWith('session_token=')) {
              token = trimmed.substring('session_token='.length);
              break;
            }
          }
          if (token != null) break;
        }
      }

      if (token != null && token.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, token);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['user'] as Map<String, dynamic>? ?? data;
    } else {
      final body = _tryDecode(response.body);
      throw Exception(body['error'] ?? body['message'] ?? 'Login failed');
    }
  }

  Future<void> logout() async {
    try {
      final headers = await _authHeaders();
      await http.post(Uri.parse('$baseUrl/api/auth/logout'), headers: headers);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<Map<String, dynamic>?> getMe() async {
    try {
      final headers = await _authHeaders();
      final response =
          await http.get(Uri.parse('$baseUrl/api/auth/me'), headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['user'] as Map<String, dynamic>? ?? data;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> sendChat(
    String message,
    String mode,
    String? sessionId,
  ) async {
    final headers = await _authHeaders();
    final body = <String, dynamic>{'message': message, 'mode': mode};
    if (sessionId != null) body['sessionId'] = sessionId;

    final response = await http.post(
      Uri.parse('$baseUrl/api/chat'),
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final data = _tryDecode(response.body);
      throw Exception(data['error'] ?? data['message'] ?? 'Chat request failed (${response.statusCode})');
    }
  }

  Future<List<dynamic>> getSessions() async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
          Uri.parse('$baseUrl/api/chat/sessions'),
          headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) return data;
        if (data is Map && data['sessions'] is List) return data['sessions'];
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Map<String, dynamic> _tryDecode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}
