
import 'dart:convert';
import 'package:http/http.dart' as http;

class SensorService {
  final String baseUrl = "https://api.fuadfakhruz.id/api/v1/sensors";
  
  // Get sensor data with optional filters
  Future<Map<String, dynamic>> getData(String token, {
    String? installCode,
    int limit = 50,
    int offset = 0,
    String? startDate,
    String? endDate,
  }) async {
    Map<String, String> queryParams = {
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    
    if (installCode != null) queryParams['install_code'] = installCode;
    if (startDate != null) queryParams['start_date'] = startDate;
    if (endDate != null) queryParams['end_date'] = endDate;
    
    final uri = Uri.parse("$baseUrl/data").replace(queryParameters: queryParams);
    final response = await http.get(
      uri,
      headers: {"Authorization": "Bearer $token"},
    );
    return jsonDecode(response.body);
  }

  // Get sensor data by install code
  Future<Map<String, dynamic>> getDataByInstallCode(String token, String installCode, {int limit = 50}) async {
    // Auto-correct ESP31 to ESP32 if needed
    String correctedInstallCode = installCode;
    if (installCode.startsWith('ESP31')) {
      correctedInstallCode = installCode.replaceFirst('ESP31', 'ESP32');
      print('Auto-correcting install code: $installCode -> $correctedInstallCode');
    }
    
    final queryParams = {
      'install_code': correctedInstallCode,
      'limit': limit.toString(),
    };
    
    print('Fetching sensor data with install code: $correctedInstallCode');
    
    final uri = Uri.parse("$baseUrl/data").replace(queryParameters: queryParams);
    final response = await http.get(
      uri,
      headers: {"Authorization": "Bearer $token"},
    );

    print('Sensor API response for $correctedInstallCode: ${response.body}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch sensor data: ${response.statusCode}');
    }
  }

  // Get sensor data by date range
  Future<Map<String, dynamic>> getDataByDateRange(String token, {
    required String installCode,
    required String startDate,
    required String endDate,
  }) async {
    final queryParams = {
      'install_code': installCode,
      'start_date': startDate,
      'end_date': endDate,
    };
    
    final uri = Uri.parse("$baseUrl/data").replace(queryParameters: queryParams);
    final response = await http.get(
      uri,
      headers: {"Authorization": "Bearer $token"},
    );
    return jsonDecode(response.body);
  }

  // Get latest sensor data
  Future<Map<String, dynamic>> getLatest(String token) async {
    final response = await http.get(
      Uri.parse("$baseUrl/latest"),
      headers: {"Authorization": "Bearer $token"},
    );
    return jsonDecode(response.body);
  }

  // Get sensor statistics
  Future<Map<String, dynamic>> getStatistics(String token) async {
    final response = await http.get(
      Uri.parse("$baseUrl/statistics"),
      headers: {"Authorization": "Bearer $token"},
    );
    return jsonDecode(response.body);
  }

  // Create sensor data
  Future<Map<String, dynamic>> createData(String token, Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse("$baseUrl/data"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json"
      },
      body: jsonEncode(payload),
    );
    return jsonDecode(response.body);
  }

  // Delete sensor data
  Future<Map<String, dynamic>> deleteData(String token, int id) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/data/$id"),
      headers: {"Authorization": "Bearer $token"},
    );
    return jsonDecode(response.body);
  }
}
