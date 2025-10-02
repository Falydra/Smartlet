import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  final String baseUrl = "https://api.fuadfakhruz.id/api/v1/auth";

  // User login
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse("$baseUrl/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );
    return jsonDecode(response.body);
  }

  // User registration
  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    final response = await http.post(
      Uri.parse("$baseUrl/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"name": name, "email": email, "password": password}),
    );
    return jsonDecode(response.body);
  }

  // Get user profile
  Future<Map<String, dynamic>> profile(String token) async {
    final response = await http.get(
      Uri.parse("$baseUrl/profile"),
      headers: {"Authorization": "Bearer $token"},
    );
    return jsonDecode(response.body);
  }

  // Update user profile
  Future<Map<String, dynamic>> updateProfile(String token, Map<String, dynamic> payload) async {
    final response = await http.put(
      Uri.parse("$baseUrl/profile"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json"
      },
      body: jsonEncode(payload),
    );
    return jsonDecode(response.body);
  }

  // Change password
  Future<Map<String, dynamic>> changePassword(String token, String currentPassword, String newPassword) async {
    final response = await http.post(
      Uri.parse("$baseUrl/change-password"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json"
      },
      body: jsonEncode({
        "current_password": currentPassword,
        "new_password": newPassword
      }),
    );
    return jsonDecode(response.body);
  }

  // Refresh authentication token
  Future<Map<String, dynamic>> refreshToken(String token) async {
    final response = await http.post(
      Uri.parse("$baseUrl/refresh"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"token": token}),
    );
    return jsonDecode(response.body);
  }

  // Validate authentication token
  Future<Map<String, dynamic>> validateToken(String token) async {
    final response = await http.post(
      Uri.parse("$baseUrl/validate"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"token": token}),
    );
    return jsonDecode(response.body);
  }

  // User logout
  Future<Map<String, dynamic>> logout(String token) async {
    final response = await http.post(
      Uri.parse("$baseUrl/logout"),
      headers: {"Authorization": "Bearer $token"},
    );
    return jsonDecode(response.body);
  }
}
