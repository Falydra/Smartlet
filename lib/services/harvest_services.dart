import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_constants.dart';

class HarvestService {
  final String baseUrl = ApiConstants.harvests;

  /// Get harvests with optional filters.
  /// Supports query params: limit, offset, rbw_id, floor_no
  Future<List<dynamic>> getAll(String token, {int limit = 50, int offset = 0, String? rbwId, int? floorNo}) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    if (rbwId != null) queryParams['rbw_id'] = rbwId;
    if (floorNo != null) queryParams['floor_no'] = floorNo.toString();

    final uri = Uri.parse(baseUrl).replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: ApiConstants.authHeadersOnly(token));
    return jsonDecode(response.body)['data'];
  }

  Future<Map<String, dynamic>> create(String token, Map<String, dynamic> payload) async {
    try {
      print('HarvestService.create - Sending payload: ${jsonEncode(payload)}');
      final response = await http.post(
        Uri.parse(baseUrl), 
        headers: ApiConstants.authHeaders(token), 
        body: jsonEncode(payload)
      );
      
      print('HarvestService.create - Response status: ${response.statusCode}');
      print('HarvestService.create - Response body: ${response.body}');
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        return {'success': true, ...data};
      } else {
        // Error response
        try {
          final errorData = jsonDecode(response.body);
          return {
            'success': false,
            'error': errorData['error'] ?? errorData['message'] ?? 'Unknown error',
            'statusCode': response.statusCode,
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'HTTP ${response.statusCode}: ${response.body}',
            'statusCode': response.statusCode,
          };
        }
      }
    } catch (e) {
      print('HarvestService.create - Exception: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> update(String token, String id, Map<String, dynamic> payload) async {
    try {
      print('HarvestService.update - Updating ID: $id with payload: ${jsonEncode(payload)}');
      final response = await http.patch(
        Uri.parse("$baseUrl/$id"), 
        headers: ApiConstants.authHeaders(token), 
        body: jsonEncode(payload)
      );
      
      print('HarvestService.update - Response status: ${response.statusCode}');
      print('HarvestService.update - Response body: ${response.body}');
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        return {'success': true, ...data};
      } else {
        try {
          final errorData = jsonDecode(response.body);
          return {
            'success': false,
            'error': errorData['error']?['message'] ?? errorData['message'] ?? errorData['error'] ?? 'Unknown error',
            'statusCode': response.statusCode,
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'HTTP ${response.statusCode}: ${response.body}',
            'statusCode': response.statusCode,
          };
        }
      }
    } catch (e) {
      print('HarvestService.update - Exception: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  Future<Map<String, dynamic>> delete(String token, String id) async {
    try {
      print('HarvestService.delete - Deleting ID: $id');
      final response = await http.delete(
        Uri.parse("$baseUrl/$id"), 
        headers: ApiConstants.authHeadersOnly(token)
      );
      
      print('HarvestService.delete - Response status: ${response.statusCode}');
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true};
      } else {
        try {
          final errorData = jsonDecode(response.body);
          return {
            'success': false,
            'error': errorData['error'] ?? errorData['message'] ?? 'Unknown error',
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'HTTP ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      print('HarvestService.delete - Exception: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }
}
