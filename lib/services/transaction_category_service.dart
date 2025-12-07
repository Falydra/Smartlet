import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_constants.dart';

class TransactionCategoryService {
  // Get all transaction categories
  Future<List<dynamic>> getAll(String token) async {
    try {
      print('[CATEGORY SERVICE] Fetching from: ${ApiConstants.apiBaseUrl}/transaction-categories');
      final response = await http.get(
        Uri.parse('${ApiConstants.apiBaseUrl}/transaction-categories'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('[CATEGORY SERVICE] Transaction categories API timeout');
          throw Exception('Request timeout');
        },
      );

      print('[CATEGORY SERVICE] Response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[CATEGORY SERVICE] Response body type: ${data.runtimeType}');
        if (data is List) {
          print('[CATEGORY SERVICE] Direct list, count: ${data.length}');
          return data;
        } else if (data is Map && data['data'] != null) {
          final categories = data['data'] as List;
          print('[CATEGORY SERVICE] Wrapped in data, count: ${categories.length}');
          return categories;
        }
        print('[CATEGORY SERVICE] No data found in response');
        return [];
      } else if (response.statusCode == 404) {
        print('[CATEGORY SERVICE] Transaction categories endpoint not found (404)');
        return [];
      } else {
        print('[CATEGORY SERVICE] Failed to load transaction categories: ${response.statusCode}');
        print('[CATEGORY SERVICE] Response body: ${response.body}');
        return [];
      }
    } catch (e) {
      print('[CATEGORY SERVICE] Error loading transaction categories: $e');
      return [];
    }
  }

  // Get category by ID
  Future<Map<String, dynamic>?> getById(String token, String id) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.apiBaseUrl}/transaction-categories/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map) {
          return data as Map<String, dynamic>;
        } else if (data is Map && data['data'] != null) {
          return data['data'] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      print('Error loading category: $e');
      return null;
    }
  }

  // Create new category
  Future<Map<String, dynamic>> create(String token, Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.apiBaseUrl}/transaction-categories'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to create category: ${response.body}',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error creating category: $e',
      };
    }
  }

  // Update category
  Future<Map<String, dynamic>> update(String token, String id, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConstants.apiBaseUrl}/transaction-categories/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to update category: ${response.body}',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error updating category: $e',
      };
    }
  }

  // Delete category
  Future<Map<String, dynamic>> delete(String token, String id) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConstants.apiBaseUrl}/transaction-categories/$id'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return {
          'success': true,
          'message': 'Category deleted successfully',
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to delete category: ${response.body}',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error deleting category: $e',
      };
    }
  }
}
