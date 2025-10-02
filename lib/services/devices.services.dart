import 'dart:convert';
import 'package:http/http.dart' as http;

class DeviceService {
  final String baseUrl = "https://api.fuadfakhruz.id/api/v1/iot-devices";

  Future<List<dynamic>> getAll(String token) async {
    final response = await http.get(Uri.parse(baseUrl), headers: {"Authorization": "Bearer $token"});
    return jsonDecode(response.body)['data'];
  }

  Future<Map<String, dynamic>> create(String token, Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {"Authorization": "Bearer $token", "Content-Type": "application/json"},
      body: jsonEncode(payload),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> update(String token, int id, Map<String, dynamic> payload) async {
    final response = await http.put(
      Uri.parse("$baseUrl/$id"),
      headers: {"Authorization": "Bearer $token", "Content-Type": "application/json"},
      body: jsonEncode(payload),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> delete(String token, int id) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/$id"),
      headers: {"Authorization": "Bearer $token"},
    );
    return jsonDecode(response.body);
  }
}
