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
      headers['Cookie'] = 'session_token=$token';
    }
    return headers;
  }

  /// Login — extracts session_token from Set-Cookie header.
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final setCookie = response.headers['set-cookie'] ?? '';
      String? token;
      for (final segment in setCookie.split(RegExp(r',(?=[^;])'))) {
        for (final part in segment.split(';')) {
          final trimmed = part.trim();
          if (trimmed.startsWith('session_token=')) {
            token = trimmed.substring('session_token='.length);
            break;
          }
        }
        if (token != null) break;
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
      await http.post(Uri.parse('$baseUrl/api/auth/logout'), headers: await _authHeaders());
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<Map<String, dynamic>?> getMe() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/auth/me'), headers: await _authHeaders());
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['user'] as Map<String, dynamic>?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Send chat. The server expects the full messages history array.
  Future<Map<String, dynamic>> sendChat({
    required List<Map<String, String>> messages,
    required String mode,
    String? sessionId,
  }) async {
    final body = <String, dynamic>{
      'messages': messages,
      'mode': mode,
    };
    if (sessionId != null) body['sessionId'] = sessionId;

    final response = await http.post(
      Uri.parse('$baseUrl/api/chat'),
      headers: await _authHeaders(),
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) return jsonDecode(response.body) as Map<String, dynamic>;
    final data = _tryDecode(response.body);
    throw Exception(data['error'] ?? data['message'] ?? 'Chat failed (${response.statusCode})');
  }

  /// List all sessions for current user, newest first.
  Future<List<Map<String, dynamic>>> getSessions() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/chat/sessions'), headers: await _authHeaders());
      if (response.statusCode == 200) {
        final data = _tryDecode(response.body);
        final list = data['sessions'] as List<dynamic>? ?? [];
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Load a specific session's full messages.
  Future<Map<String, dynamic>?> getSession(String sessionId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/chat/sessions/$sessionId'),
        headers: await _authHeaders(),
      );
      if (response.statusCode == 200) {
        final data = _tryDecode(response.body);
        return data['session'] as Map<String, dynamic>?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Delete a session.
  Future<bool> deleteSession(String sessionId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/chat/sessions/$sessionId'),
        headers: await _authHeaders(),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> _tryDecode(String body) {
    try { return jsonDecode(body) as Map<String, dynamic>; } catch (_) { return {}; }
  }
}
