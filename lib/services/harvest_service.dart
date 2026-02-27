import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_constants.dart';











class HarvestService {



  Future<Map<String, dynamic>> create({
    required String token,
    required String rbwId,
    required int floorNo,
    required DateTime harvestedAt,
    String? nodeId,
    int? nestsCount,
    double? weightKg,
    String? grade,
    String? notes,
  }) async {
    try {
      final body = {
        'rbw_id': rbwId,
        'floor_no': floorNo,
        'harvested_at': harvestedAt.toUtc().toIso8601String(),
        if (nodeId != null) 'node_id': nodeId,
        if (nestsCount != null) 'nests_count': nestsCount,
        if (weightKg != null) 'weight_kg': weightKg,
        if (grade != null) 'grade': grade,
        if (notes != null) 'notes': notes,
      };

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/harvests'),
        headers: ApiConstants.authHeaders(token),
        body: jsonEncode(body),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'data': responseData['data'] ?? responseData,
        };
      } else {
        final errorData = _parseError(response);
        return {
          'success': false,
          'message': errorData['message'],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error creating harvest: $e',
      };
    }
  }




  Future<Map<String, dynamic>> list({
    required String token,
    Map<String, String>? queryParams,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/harvests')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: ApiConstants.authHeaders(token),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'data': responseData['data'] ?? [],
          'meta': responseData['meta'],
        };
      } else {
        final errorData = _parseError(response);
        return {
          'success': false,
          'message': errorData['message'],
          'data': [],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error listing harvests: $e',
        'data': [],
      };
    }
  }




  Future<Map<String, dynamic>> get({
    required String token,
    required String harvestId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/harvests/$harvestId'),
        headers: ApiConstants.authHeaders(token),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'data': responseData['data'] ?? responseData,
        };
      } else {
        final errorData = _parseError(response);
        return {
          'success': false,
          'message': errorData['message'],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error getting harvest: $e',
      };
    }
  }




  Future<Map<String, dynamic>> update({
    required String token,
    required String harvestId,
    int? floorNo,
    int? nestsCount,
    double? weightKg,
    String? grade,
    String? notes,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (floorNo != null) body['floor_no'] = floorNo;
      if (nestsCount != null) body['nests_count'] = nestsCount;
      if (weightKg != null) body['weight_kg'] = weightKg;
      if (grade != null) body['grade'] = grade;
      if (notes != null) body['notes'] = notes;

      final response = await http.patch(
        Uri.parse('${ApiConstants.baseUrl}/harvests/$harvestId'),
        headers: ApiConstants.authHeaders(token),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'data': responseData['data'] ?? responseData,
        };
      } else {
        final errorData = _parseError(response);
        return {
          'success': false,
          'message': errorData['message'],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error updating harvest: $e',
      };
    }
  }




  Future<Map<String, dynamic>> delete({
    required String token,
    required String harvestId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConstants.baseUrl}/harvests/$harvestId'),
        headers: ApiConstants.authHeaders(token),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return {
          'success': true,
          'message': 'Harvest deleted successfully',
        };
      } else {
        final errorData = _parseError(response);
        return {
          'success': false,
          'message': errorData['message'],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error deleting harvest: $e',
      };
    }
  }




  Future<Map<String, dynamic>> getStats({
    required String token,
    String? rbwId,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (rbwId != null) queryParams['rbw_id'] = rbwId;

      final uri = Uri.parse('${ApiConstants.baseUrl}/harvests/stats')
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(
        uri,
        headers: ApiConstants.authHeaders(token),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'data': responseData['data'] ?? responseData,
        };
      } else {
        final errorData = _parseError(response);
        return {
          'success': false,
          'message': errorData['message'],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error getting harvest stats: $e',
      };
    }
  }




  Future<Map<String, dynamic>> listByRbw({
    required String token,
    required String rbwId,
    Map<String, String>? queryParams,
  }) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/rbw/$rbwId/harvests')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: ApiConstants.authHeaders(token),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'data': responseData['data'] ?? [],
          'meta': responseData['meta'],
        };
      } else {
        final errorData = _parseError(response);
        return {
          'success': false,
          'message': errorData['message'],
          'data': [],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error listing harvests by RBW: $e',
        'data': [],
      };
    }
  }




  

  Map<String, dynamic> _parseError(http.Response response) {
    try {
      if (response.body.isNotEmpty) {
        final errorData = jsonDecode(response.body);
        return {
          'message': errorData['message'] ?? errorData['error'] ?? 'Unknown error',
          'error': errorData['error'],
        };
      }
    } catch (e) {

    }

    return {
      'message': 'Server error (${response.statusCode})',
      'error': null,
    };
  }
}
