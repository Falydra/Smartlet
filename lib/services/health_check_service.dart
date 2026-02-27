import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_constants.dart';

class HealthCheckService {

  Future<Map<String, dynamic>> healthCheck() async {
    final response = await http.get(Uri.parse(ApiConstants.health), headers: ApiConstants.jsonHeaders);
    return jsonDecode(response.body);
  }


  Future<Map<String, dynamic>> readinessCheck() async {
    final response = await http.get(Uri.parse(ApiConstants.ready), headers: ApiConstants.jsonHeaders);
    return jsonDecode(response.body);
  }


  Future<Map<String, dynamic>> livenessCheck() async {
    final response = await http.get(Uri.parse(ApiConstants.live), headers: ApiConstants.jsonHeaders);
    return jsonDecode(response.body);
  }


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