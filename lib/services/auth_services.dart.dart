import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_constants.dart';

class AuthService {













  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    try {
      final body = {
        "name": name,
        "email": email,
        "password": password,
        if (phone != null) "phone": phone,
      };

      print('[AUTH SERVICE] POST ${ApiConstants.authRegister}');
      print('[AUTH SERVICE] Request body: ${jsonEncode(body)}');

      final response = await http.post(
        Uri.parse(ApiConstants.authRegister),
        headers: ApiConstants.jsonHeaders,
        body: jsonEncode(body),
      );

      print('[AUTH SERVICE] Status: ${response.statusCode}');
      print('[AUTH SERVICE] Response: ${response.body}');

      return jsonDecode(response.body);
    } catch (e) {
      print('[AUTH SERVICE] Error in register: $e');
      return {
        'success': false,
        'message': 'Error during registration: $e',
      };
    }
  }












  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final body = {
        "email": email,
        "password": password,
      };

      print('[AUTH SERVICE] POST ${ApiConstants.authLogin}');
      print('[AUTH SERVICE] Email: $email');

      final response = await http.post(
        Uri.parse(ApiConstants.authLogin),
        headers: ApiConstants.jsonHeaders,
        body: jsonEncode(body),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Connection timeout - Please check your internet connection');
        },
      );

      print('[AUTH SERVICE] Status: ${response.statusCode}');
      print('[AUTH SERVICE] Response: ${response.body}');

      return jsonDecode(response.body);
    } on http.ClientException catch (e) {
      print('[AUTH SERVICE] ClientException in login: $e');
      return {
        'success': false,
        'message': 'Network error: Unable to connect to server. Please check:\n1. Your internet connection\n2. The API server is running',
      };
    } catch (e) {
      print('[AUTH SERVICE] Error in login: $e');
      String errorMessage = e.toString();
      

      if (errorMessage.contains('XMLHttpRequest')) {
        errorMessage = 'CORS error: The API server needs to allow requests from this web app. This typically works on mobile apps.';
      } else if (errorMessage.contains('Failed host lookup')) {
        errorMessage = 'Cannot reach server: Please check your internet connection';
      }
      
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }












  Future<Map<String, dynamic>> changePassword({
    required String token,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final body = {
        "old_password": oldPassword,
        "new_password": newPassword,
      };

      print('[AUTH SERVICE] POST ${ApiConstants.authChangePassword}');

      final response = await http.post(
        Uri.parse(ApiConstants.authChangePassword),
        headers: ApiConstants.authHeaders(token),
        body: jsonEncode(body),
      );

      print('[AUTH SERVICE] Status: ${response.statusCode}');
      print('[AUTH SERVICE] Response: ${response.body}');

      return jsonDecode(response.body);
    } catch (e) {
      print('[AUTH SERVICE] Error in changePassword: $e');
      return {
        'success': false,
        'message': 'Error changing password: $e',
      };
    }
  }











  Future<Map<String, dynamic>> forgotPassword({
    required String token,
    required String email,
  }) async {
    try {
      final body = {
        "email": email,
      };

      print('[AUTH SERVICE] POST ${ApiConstants.authForgotPassword}');

      final response = await http.post(
        Uri.parse(ApiConstants.authForgotPassword),
        headers: ApiConstants.authHeaders(token),
        body: jsonEncode(body),
      );

      print('[AUTH SERVICE] Status: ${response.statusCode}');
      print('[AUTH SERVICE] Response: ${response.body}');

      return jsonDecode(response.body);
    } catch (e) {
      print('[AUTH SERVICE] Error in forgotPassword: $e');
      return {
        'success': false,
        'message': 'Error resetting password: $e',
      };
    }
  }







  Future<Map<String, dynamic>> getProfile(String token) async {
    try {
      print('[AUTH SERVICE] GET ${ApiConstants.usersMe}');

      final response = await http.get(
        Uri.parse(ApiConstants.usersMe),
        headers: ApiConstants.authHeaders(token),
      );

      print('[AUTH SERVICE] Status: ${response.statusCode}');
      print('[AUTH SERVICE] Response: ${response.body}');

      return jsonDecode(response.body);
    } catch (e) {
      print('[AUTH SERVICE] Error in getProfile: $e');
      return {
        'success': false,
        'message': 'Error getting profile: $e',
      };
    }
  }


  Future<Map<String, dynamic>> profile(String token) => getProfile(token);












  Future<Map<String, dynamic>> updateProfile({
    required String token,
    String? name,
    String? phone,
    String? avatarUrl,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (phone != null) body['phone'] = phone;
      if (avatarUrl != null) body['avatar_url'] = avatarUrl;

      print('[AUTH SERVICE] PATCH ${ApiConstants.usersMe}');
      print('[AUTH SERVICE] Request body: ${jsonEncode(body)}');

      final response = await http.patch(
        Uri.parse(ApiConstants.usersMe),
        headers: ApiConstants.authHeaders(token),
        body: jsonEncode(body),
      );

      print('[AUTH SERVICE] Status: ${response.statusCode}');
      print('[AUTH SERVICE] Response: ${response.body}');

      return jsonDecode(response.body);
    } catch (e) {
      print('[AUTH SERVICE] Error in updateProfile: $e');
      return {
        'success': false,
        'message': 'Error updating profile: $e',
      };
    }
  }












  Future<Map<String, dynamic>> listUsers({
    required String token,
    int page = 1,
    int limit = 20,
    String? role,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (role != null) 'role': role,
      };

      final uri = Uri.parse(ApiConstants.users).replace(queryParameters: queryParams);
      print('[AUTH SERVICE] GET $uri');

      final response = await http.get(
        uri,
        headers: ApiConstants.authHeaders(token),
      );

      print('[AUTH SERVICE] Status: ${response.statusCode}');

      return jsonDecode(response.body);
    } catch (e) {
      print('[AUTH SERVICE] Error in listUsers: $e');
      return {
        'success': false,
        'message': 'Error listing users: $e',
      };
    }
  }














  Future<Map<String, dynamic>> createUser({
    required String token,
    required String name,
    required String email,
    required String password,
    required String role,
    String? phone,
  }) async {
    try {
      final body = {
        "name": name,
        "email": email,
        "password": password,
        "role": role,
        if (phone != null) "phone": phone,
      };

      print('[AUTH SERVICE] POST ${ApiConstants.users}');
      print('[AUTH SERVICE] Request body: ${jsonEncode(body)}');

      final response = await http.post(
        Uri.parse(ApiConstants.users),
        headers: ApiConstants.authHeaders(token),
        body: jsonEncode(body),
      );

      print('[AUTH SERVICE] Status: ${response.statusCode}');
      print('[AUTH SERVICE] Response: ${response.body}');

      return jsonDecode(response.body);
    } catch (e) {
      print('[AUTH SERVICE] Error in createUser: $e');
      return {
        'success': false,
        'message': 'Error creating user: $e',
      };
    }
  }
}
