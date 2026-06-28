import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const String _baseUrl = 'https://revenue.nexarcit.com';
  static const String _tokenKey = 'session_token';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _getToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Cookie'] = 'session=$token';
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Login with email and password. Returns user map on success, throws on failure.
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['token'] as String?;
      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, token);
      }
      return data['user'] as Map<String, dynamic>? ?? data;
    } else {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? body['error'] ?? 'Login failed');
    }
  }

  /// Logout. Clears local token.
  Future<void> logout() async {
    try {
      final headers = await _authHeaders();
      await http.post(
        Uri.parse('$_baseUrl/api/auth/logout'),
        headers: headers,
      );
    } catch (_) {
      // Ignore errors during logout
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    }
  }

  /// Get current user info. Returns null if not authenticated.
  Future<Map<String, dynamic>?> getMe() async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/api/auth/me'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Send a chat message. Returns {answer, sessionId, sources}.
  Future<Map<String, dynamic>> sendChat(
    String message,
    String mode,
    String? sessionId,
  ) async {
    final headers = await _authHeaders();
    final body = <String, dynamic>{
      'message': message,
      'mode': mode,
    };
    if (sessionId != null) {
      body['sessionId'] = sessionId;
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/api/chat'),
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final bodyData = jsonDecode(response.body);
      throw Exception(
          bodyData['message'] ?? bodyData['error'] ?? 'Chat request failed');
    }
  }

  /// Get chat sessions.
  Future<List<dynamic>> getSessions() async {
    try {
      final headers = await _authHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/api/chat/sessions'),
        headers: headers,
      );
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
}
