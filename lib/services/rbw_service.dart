import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_constants.dart';














class RbwService {










  Future<Map<String, dynamic>> listRbw({
    required String token,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        'include': 'owner',
      };

      final uri = Uri.parse(ApiConstants.rbw).replace(queryParameters: queryParams);
      print('[RBW SERVICE] GET $uri');

      final response = await http.get(
        uri,
        headers: ApiConstants.authHeadersOnly(token),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('[RBW SERVICE] Request timeout after 15 seconds');
          throw Exception('Request timeout');
        },
      );

      print('[RBW SERVICE] Status: ${response.statusCode}');

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
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      print('[RBW SERVICE] Exception: $e');
      return {
        'success': false,
        'message': 'Error listing RBW: $e',
        'data': [],
      };
    }
  }
















  Future<Map<String, dynamic>> createRbw({
    required String token,
    required String code,
    required String name,
    String? address,
    double? latitude,
    double? longitude,
    required int totalFloors,
    String? description,
  }) async {
    try {
      final body = {
        "code": code,
        "name": name,
        if (address != null) "address": address,
        if (latitude != null) "latitude": latitude,
        if (longitude != null) "longitude": longitude,
        "total_floors": totalFloors,
        if (description != null) "description": description,
      };

      print('[RBW SERVICE] POST ${ApiConstants.rbw}');
      print('[RBW SERVICE] Request body: ${jsonEncode(body)}');

      final response = await http.post(
        Uri.parse(ApiConstants.rbw),
        headers: ApiConstants.authHeaders(token),
        body: jsonEncode(body),
      );

      print('[RBW SERVICE] Status: ${response.statusCode}');
      print('[RBW SERVICE] Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
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
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      print('[RBW SERVICE] Exception: $e');
      return {
        'success': false,
        'message': 'Error creating RBW: $e',
      };
    }
  }








  Future<Map<String, dynamic>> getRbw({
    required String token,
    required String rbwId,
  }) async {
    try {
      final uri = Uri.parse(ApiConstants.rbwDetail(rbwId)).replace(
        queryParameters: {'include': 'owner'},
      );
      print('[RBW SERVICE] GET $uri');

      final response = await http.get(
        uri,
        headers: ApiConstants.authHeadersOnly(token),
      );

      print('[RBW SERVICE] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('[RBW SERVICE] Response data: ${responseData['data']}');
        return {
          'success': true,
          'data': responseData['data'] ?? responseData,
        };
      } else {
        final errorData = _parseError(response);
        return {
          'success': false,
          'message': errorData['message'],
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      print('[RBW SERVICE] Exception: $e');
      return {
        'success': false,
        'message': 'Error getting RBW: $e',
      };
    }
  }
















  Future<Map<String, dynamic>> updateRbw({
    required String token,
    required String rbwId,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    int? totalFloors,
    String? description,
    String? photoUrl,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (address != null) body['address'] = address;
      if (latitude != null) body['latitude'] = latitude;
      if (longitude != null) body['longitude'] = longitude;
      if (totalFloors != null) body['total_floors'] = totalFloors;
      if (description != null) body['description'] = description;
      if (photoUrl != null) body['photo_url'] = photoUrl;

      final url = ApiConstants.rbwDetail(rbwId);
      print('[RBW SERVICE] PATCH $url');
      print('[RBW SERVICE] Request body: ${jsonEncode(body)}');

      final response = await http.patch(
        Uri.parse(url),
        headers: ApiConstants.authHeaders(token),
        body: jsonEncode(body),
      );

      print('[RBW SERVICE] Status: ${response.statusCode}');
      print('[RBW SERVICE] Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (response.body.trim().isEmpty) {
          return {
            'success': true,
            'message': 'RBW updated successfully',
          };
        }
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
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      print('[RBW SERVICE] Exception: $e');
      return {
        'success': false,
        'message': 'Error updating RBW: $e',
      };
    }
  }







  Future<Map<String, dynamic>> deleteRbw({
    required String token,
    required String rbwId,
  }) async {
    try {
      final url = ApiConstants.rbwDetail(rbwId);
      print('[RBW SERVICE] DELETE $url');

      final response = await http.delete(
        Uri.parse(url),
        headers: ApiConstants.authHeadersOnly(token),
      );

      print('[RBW SERVICE] Status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        return {
          'success': true,
          'message': 'RBW deleted successfully',
        };
      } else {
        final errorData = _parseError(response);
        return {
          'success': false,
          'message': errorData['message'],
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      print('[RBW SERVICE] Exception: $e');
      return {
        'success': false,
        'message': 'Error deleting RBW: $e',
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






  @Deprecated('Use listRbw instead')
  Future<List<dynamic>> getAll(String token) async {
    final result = await listRbw(token: token, limit: 100);
    return result['data'] ?? [];
  }


  @Deprecated('Use createRbw instead')
  Future<Map<String, dynamic>> create(String token, Map<String, dynamic> payload) async {
    return createRbw(
      token: token,
      code: payload['code'] ?? '',
      name: payload['name'] ?? '',
      address: payload['address'],
      latitude: payload['latitude']?.toDouble(),
      longitude: payload['longitude']?.toDouble(),
      totalFloors: payload['total_floors'] ?? payload['floor_count'] ?? 1,
      description: payload['description'],
    );
  }


  @Deprecated('Use updateRbw instead')
  Future<Map<String, dynamic>> update(
    String token,
    String id,
    Map<String, dynamic> payload,
  ) async {
    return updateRbw(
      token: token,
      rbwId: id,
      name: payload['name'],
      address: payload['address'],
      latitude: payload['latitude']?.toDouble(),
      longitude: payload['longitude']?.toDouble(),
      totalFloors: payload['total_floors'] ?? payload['floor_count'],
      description: payload['description'],
      photoUrl: payload['photo_url'] ?? payload['image_url'],
    );
  }


  @Deprecated('Use deleteRbw instead')
  Future<Map<String, dynamic>> delete(String token, String id) async {
    return deleteRbw(token: token, rbwId: id);
  }
}
