import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_constants.dart';

class HealthCheckService {
  // Health check endpoints from ApiConstants
  Future<Map<String, dynamic>> healthCheck() async {
    final response = await http.get(Uri.parse(ApiConstants.health), headers: ApiConstants.jsonHeaders);
    return jsonDecode(response.body);
  }

  // Readiness check - indicates if the service is ready to handle requests
  Future<Map<String, dynamic>> readinessCheck() async {
    final response = await http.get(Uri.parse(ApiConstants.ready), headers: ApiConstants.jsonHeaders);
    return jsonDecode(response.body);
  }

  // Liveness check - indicates if the service is running
  Future<Map<String, dynamic>> livenessCheck() async {
    final response = await http.get(Uri.parse(ApiConstants.live), headers: ApiConstants.jsonHeaders);
    return jsonDecode(response.body);
  }

  // Comprehensive system status check
  Future<bool> isSystemHealthy() async {
    try {
      final health = await healthCheck();
      final ready = await readinessCheck();
      final live = await livenessCheck();
      
      return health['status'] == 'healthy' &&
             ready['status'] == 'ready' &&
             live['status'] == 'alive';
    } catch (e) {
      return false;
    }
  }
}