import 'dart:convert';
import 'package:http/http.dart' as http;

class RequestService {
  final String baseUrl = "https://api.fuadfakhruz.id/api/v1";

  // ===================
  // INSTALLATION REQUESTS
  // ===================

  // Get all installation requests
  Future<List<dynamic>> getInstallationRequests(String token, {int limit = 50, int offset = 0}) async {
    final queryParams = {
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    final uri = Uri.parse("$baseUrl/installation-requests").replace(queryParameters: queryParams);
    
    final response = await http.get(
      uri,
      headers: {"Authorization": "Bearer $token"},
    );
    return jsonDecode(response.body)['data'];
  }

  // Get installation request by ID
  Future<Map<String, dynamic>> getInstallationRequestById(String token, int id) async {
    final response = await http.get(
      Uri.parse("$baseUrl/installation-requests/$id"),
      headers: {"Authorization": "Bearer $token"},
    );
    return jsonDecode(response.body);
  }

  // Create installation request
  Future<Map<String, dynamic>> createInstallationRequest(String token, Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse("$baseUrl/installation-requests"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json"
      },
      body: jsonEncode(payload),
    );
    return jsonDecode(response.body);
  }

  // Update installation request
  Future<Map<String, dynamic>> updateInstallationRequest(String token, int id, Map<String, dynamic> payload) async {
    final response = await http.put(
      Uri.parse("$baseUrl/installation-requests/$id"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json"
      },
      body: jsonEncode(payload),
    );
    return jsonDecode(response.body);
  }

  // Update installation request status
  Future<Map<String, dynamic>> updateInstallationRequestStatus(String token, int id, Map<String, dynamic> payload) async {
    final response = await http.patch(
      Uri.parse("$baseUrl/installation-requests/$id/status"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json"
      },
      body: jsonEncode(payload),
    );
    return jsonDecode(response.body);
  }

  // Delete installation request
  Future<Map<String, dynamic>> deleteInstallationRequest(String token, int id) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/installation-requests/$id"),
      headers: {"Authorization": "Bearer $token"},
    );
    return jsonDecode(response.body);
  }

  // ===================
  // MAINTENANCE REQUESTS
  // ===================

  // Get all maintenance requests
  Future<List<dynamic>> getMaintenanceRequests(String token, {int limit = 50, int offset = 0}) async {
    final queryParams = {
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    final uri = Uri.parse("$baseUrl/maintenance-requests").replace(queryParameters: queryParams);
    
    final response = await http.get(
      uri,
      headers: {"Authorization": "Bearer $token"},
    );
    return jsonDecode(response.body)['data'];
  }

  // Get maintenance request by ID
  Future<Map<String, dynamic>> getMaintenanceRequestById(String token, int id) async {
    final response = await http.get(
      Uri.parse("$baseUrl/maintenance-requests/$id"),
      headers: {"Authorization": "Bearer $token"},
    );
    return jsonDecode(response.body);
  }

  // Create maintenance request
  Future<Map<String, dynamic>> createMaintenanceRequest(String token, Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse("$baseUrl/maintenance-requests"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json"
      },
      body: jsonEncode(payload),
    );
    return jsonDecode(response.body);
  }

  // Update maintenance request
  Future<Map<String, dynamic>> updateMaintenanceRequest(String token, int id, Map<String, dynamic> payload) async {
    final response = await http.put(
      Uri.parse("$baseUrl/maintenance-requests/$id"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json"
      },
      body: jsonEncode(payload),
    );
    return jsonDecode(response.body);
  }

  // Update maintenance request status
  Future<Map<String, dynamic>> updateMaintenanceRequestStatus(String token, int id, Map<String, dynamic> payload) async {
    final response = await http.patch(
      Uri.parse("$baseUrl/maintenance-requests/$id/status"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json"
      },
      body: jsonEncode(payload),
    );
    return jsonDecode(response.body);
  }

  // Delete maintenance request
  Future<Map<String, dynamic>> deleteMaintenanceRequest(String token, int id) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/maintenance-requests/$id"),
      headers: {"Authorization": "Bearer $token"},
    );
    return jsonDecode(response.body);
  }

  // ===================
  // UNINSTALLATION REQUESTS
  // ===================

  // Get all uninstallation requests
  Future<List<dynamic>> getUninstallationRequests(String token, {int limit = 50, int offset = 0}) async {
    final queryParams = {
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    final uri = Uri.parse("$baseUrl/uninstallation-requests").replace(queryParameters: queryParams);
    
    final response = await http.get(
      uri,
      headers: {"Authorization": "Bearer $token"},
    );
    return jsonDecode(response.body)['data'];
  }

  // Get uninstallation request by ID
  Future<Map<String, dynamic>> getUninstallationRequestById(String token, int id) async {
    final response = await http.get(
      Uri.parse("$baseUrl/uninstallation-requests/$id"),
      headers: {"Authorization": "Bearer $token"},
    );
    return jsonDecode(response.body);
  }

  // Create uninstallation request
  Future<Map<String, dynamic>> createUninstallationRequest(String token, Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse("$baseUrl/uninstallation-requests"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json"
      },
      body: jsonEncode(payload),
    );
    return jsonDecode(response.body);
  }

  // Update uninstallation request
  Future<Map<String, dynamic>> updateUninstallationRequest(String token, int id, Map<String, dynamic> payload) async {
    final response = await http.put(
      Uri.parse("$baseUrl/uninstallation-requests/$id"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json"
      },
      body: jsonEncode(payload),
    );
    return jsonDecode(response.body);
  }

  // Update uninstallation request status
  Future<Map<String, dynamic>> updateUninstallationRequestStatus(String token, int id, Map<String, dynamic> payload) async {
    final response = await http.patch(
      Uri.parse("$baseUrl/uninstallation-requests/$id/status"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json"
      },
      body: jsonEncode(payload),
    );
    return jsonDecode(response.body);
  }

  // Delete uninstallation request
  Future<Map<String, dynamic>> deleteUninstallationRequest(String token, int id) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/uninstallation-requests/$id"),
      headers: {"Authorization": "Bearer $token"},
    );
    return jsonDecode(response.body);
  }

  // ===================
  // ANALYTICS & REPORTS
  // ===================

  // Get request analytics
  Future<Map<String, dynamic>> getRequestAnalytics(String token) async {
    final response = await http.get(
      Uri.parse("$baseUrl/requests/analytics"),
      headers: {"Authorization": "Bearer $token"},
    );
    return jsonDecode(response.body);
  }

  // Get technician workload
  Future<Map<String, dynamic>> getTechnicianWorkload(String token, int technicianId) async {
    final response = await http.get(
      Uri.parse("$baseUrl/requests/technician-workload/$technicianId"),
      headers: {"Authorization": "Bearer $token"},
    );
    return jsonDecode(response.body);
  }
}
