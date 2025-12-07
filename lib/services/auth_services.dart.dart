import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_constants.dart';

class AuthService {
  // Use ApiConstants to build endpoints
  final String baseUrl = ApiConstants.apiBaseUrl;

  // User login
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse(ApiConstants.authLogin),
      headers: ApiConstants.jsonHeaders,
      body: jsonEncode({"email": email, "password": password}),
    );
    // Debug: log HTTP status and raw response body to help diagnose failures
    try {
      print('AuthService.login -> POST ${ApiConstants.authLogin}');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
    } catch (e) {
      print('AuthService.login -> failed to print response: $e');
    }
    return jsonDecode(response.body);
  }

  // User registration
  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    final response = await http.post(
      Uri.parse(ApiConstants.users),
      headers: ApiConstants.jsonHeaders,
      body: jsonEncode({"name": name, "email": email, "password": password}),
    );
    return jsonDecode(response.body);
  }

  // Get user profile
  Future<Map<String, dynamic>> profile(String token) async {
    final response = await http.get(
      Uri.parse(ApiConstants.usersMe),
      headers: ApiConstants.authHeaders(token),
    );
    return jsonDecode(response.body);
  }

  // Update user profile
  Future<Map<String, dynamic>> updateProfile(String token, Map<String, dynamic> payload) async {
    final response = await http.put(
      Uri.parse(ApiConstants.usersMe),
      headers: ApiConstants.authHeaders(token),
      body: jsonEncode(payload),
    );
    return jsonDecode(response.body);
  }

  // Change password
  Future<Map<String, dynamic>> changePassword(String token, String currentPassword, String newPassword) async {
    final response = await http.post(
      Uri.parse(ApiConstants.authChangePassword),
      headers: ApiConstants.authHeaders(token),
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
      Uri.parse(ApiConstants.authRefresh),
      headers: ApiConstants.jsonHeaders,
      body: jsonEncode({"token": token}),
    );
    return jsonDecode(response.body);
  }

  // Validate authentication token
  Future<Map<String, dynamic>> validateToken(String token) async {
    final response = await http.post(
      Uri.parse(ApiConstants.authValidate),
      headers: ApiConstants.jsonHeaders,
      body: jsonEncode({"token": token}),
    );
    return jsonDecode(response.body);
  }

  // User logout
  Future<Map<String, dynamic>> logout(String token) async {
    final response = await http.post(
      Uri.parse(ApiConstants.authLogout),
      headers: ApiConstants.authHeaders(token),
    );
    return jsonDecode(response.body);
  }
}
