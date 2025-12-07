import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_constants.dart';

/// SensorService aligned with current API constants
class SensorService {
  final String baseUrl = ApiConstants.apiBaseUrl;

  /// Get readings for a sensor (GET /sensors/{sensorId}/readings)
  Future<Map<String, dynamic>> getReadings(
    String token,
    String sensorId, {
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse(ApiConstants.sensorReadings(sensorId)).replace(
      queryParameters: queryParams,
    );
    final response = await http.get(uri, headers: ApiConstants.authHeadersOnly(token));
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'success': response.statusCode == 200, 'data': decoded};
    } catch (_) {
      return {
        'success': response.statusCode == 200,
        'statusCode': response.statusCode,
        'message': response.body,
      };
    }
  }

  /// Get latest reading for a sensor (GET /sensors/{sensorId}/readings/latest)
  Future<Map<String, dynamic>> getLatestReading(String token, String sensorId) async {
    final uri = Uri.parse(ApiConstants.sensorLatest(sensorId));
    final response = await http.get(uri, headers: ApiConstants.authHeadersOnly(token));
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'success': response.statusCode == 200, 'data': decoded};
    } catch (_) {
      return {
        'success': response.statusCode == 200,
        'statusCode': response.statusCode,
        'message': response.body,
      };
    }
  }

  /// Create a sensor reading (POST /sensors/{sensorId}/readings)
  Future<Map<String, dynamic>> createReading(String token, String sensorId, Map<String, dynamic> payload) async {
    final uri = Uri.parse(ApiConstants.sensorReadings(sensorId));
    final response = await http.post(uri, headers: ApiConstants.authHeaders(token), body: jsonEncode(payload));
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'success': response.statusCode == 200 || response.statusCode == 201, 'data': decoded};
    } catch (_) {
      return {
        'success': response.statusCode == 200 || response.statusCode == 201,
        'statusCode': response.statusCode,
        'message': response.body,
      };
    }
  }
}
