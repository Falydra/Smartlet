import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_constants.dart';

class HouseService {

  final String baseUrl = ApiConstants.rbw;

  Future<List<dynamic>> getAll(String token) async {
    try {
      print('HouseService: Calling GET $baseUrl');
      final response = await http.get(
        Uri.parse(baseUrl), 
        headers: ApiConstants.authHeadersOnly(token)
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('HouseService: Request timeout after 15 seconds');
          throw Exception('Request timeout');
        },
      );
      
      print('HouseService: Response status ${response.statusCode}');
      print('HouseService: Response body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['data'] != null) {
          print('HouseService: Found ${(data['data'] as List).length} houses');
          return data['data'];
        }
      }
      
      print('HouseService: No data found, returning empty list');
      return [];
    } catch (e) {
      print('HouseService: Error loading houses: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> create(String token, Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: ApiConstants.authHeaders(token),
      body: jsonEncode(payload),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> update(String token, String id, Map<String, dynamic> payload) async {
    final response = await http.put(
      Uri.parse("$baseUrl/$id"),
      headers: ApiConstants.authHeaders(token),
      body: jsonEncode(payload),
    );
    final status = response.statusCode;
    if (response.body.trim().isEmpty) {
      return {
        'success': (status == 200 || status == 201 || status == 204),
        'statusCode': status,
        'message': status == 204 ? 'No content' : null,
      };
    }

    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        body['statusCode'] = status;
        if (!body.containsKey('success')) {
          body['success'] = (status == 200 || status == 201 || status == 204);
        }
        return body;
      }
      return {
        'success': (status == 200 || status == 201),
        'statusCode': status,
        'data': body,
      };
    } catch (e) {
      return {
        'success': (status == 200 || status == 201),
        'statusCode': status,
        'message': response.body,
      };
    }
  }

  Future<Map<String, dynamic>> delete(String token, String id) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/$id"),
      headers: ApiConstants.authHeadersOnly(token),
    );


    final status = response.statusCode;
    if (response.body.trim().isEmpty) {
      return {
        'success': (status == 200 || status == 204),
        'statusCode': status,
        'message': status == 204 ? 'Deleted (no content)' : null,
      };
    }

    try {
      final body = jsonDecode(response.body);

      if (body is Map<String, dynamic>) {
        body['statusCode'] = status;
        if (!body.containsKey('success')) {
          body['success'] = (status == 200 || status == 201 || status == 204);
        }
        return body;
      }
      return {
        'success': (status == 200 || status == 201),
        'statusCode': status,
        'data': body,
      };
    } catch (e) {

      return {
        'success': (status == 200 || status == 201 || status == 204),
        'statusCode': status,
        'message': response.body,
      };
    }
  }
}
