import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class AuthService {
  final String baseUrl;
  static const String _tokenKey = 'dinieco_jwt_token';
  static const String _userKey = 'dinieco_user_data';

  AuthService({this.baseUrl = 'http://127.0.0.1:8000/api/v1'});

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<UserModel?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw != null) {
      try {
        return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    return null;
  }

  Future<UserModel> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
        'full_name': fullName.trim(),
      }),
    ).timeout(const Duration(seconds: 8));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final token = data['access_token'] as String;
      final user = UserModel(
        id: data['user_id'] as String,
        email: email.trim(),
        fullName: data['full_name'] as String,
      );
      await _saveSession(token, user);
      return user;
    } else {
      final err = _extractError(res.body, 'Registration failed');
      throw Exception(err);
    }
  }

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
      }),
    ).timeout(const Duration(seconds: 8));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final token = data['access_token'] as String;
      final user = UserModel(
        id: data['user_id'] as String,
        email: email.trim(),
        fullName: data['full_name'] as String,
      );
      await _saveSession(token, user);
      return user;
    } else {
      final err = _extractError(res.body, 'Invalid email or password');
      throw Exception(err);
    }
  }

  Future<UserModel?> validateSession() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return null;

    try {
      final res = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final user = UserModel.fromJson(data);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userKey, jsonEncode(user.toJson()));
        return user;
      } else {
        // Token expired or invalid
        await logout();
        return null;
      }
    } catch (_) {
      // Offline / network failure: check if locally saved user exists
      return await getSavedUser();
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  Future<void> _saveSession(String token, UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  String _extractError(String body, String defaultMsg) {
    try {
      final map = jsonDecode(body);
      if (map is Map && map['detail'] != null) {
        return map['detail'].toString();
      }
    } catch (_) {}
    return defaultMsg;
  }
}
