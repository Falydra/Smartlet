import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_constants.dart';

class ServiceRequestService {
  final String baseUrl = ApiConstants.apiBaseUrl;

  /// Create a new service request (POST /service-requests)
  Future<Map<String, dynamic>> create(String token, Map<String, dynamic> payload) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/service-requests'),
        headers: {"Authorization": "Bearer $token", "Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      try {
        final body = jsonDecode(response.body);
        return {'success': response.statusCode == 201 || response.statusCode == 200, 'data': body['data'], 'statusCode': response.statusCode};
      } catch (e) {
        return {'success': response.statusCode == 201 || response.statusCode == 200, 'statusCode': response.statusCode, 'message': response.body.isNotEmpty ? response.body : 'Non-JSON response from create service request'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// List service requests (GET /service-requests) with optional query params
  Future<Map<String, dynamic>> list(String token, {Map<String, String>? queryParams}) async {
    try {
      final uri = Uri.parse('$baseUrl/service-requests').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: {"Authorization": "Bearer $token"});

      if (response.statusCode == 200) {
        try {
          final body = jsonDecode(response.body);
          return {'success': true, 'data': body['data'], 'meta': body['meta']};
        } catch (e) {
          return {'success': false, 'message': 'Invalid JSON response: ${response.body}', 'statusCode': response.statusCode};
        }
      }

      return {'success': false, 'message': response.body.isNotEmpty ? response.body : 'Failed to list service requests', 'statusCode': response.statusCode};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// List service requests assigned to logged-in technician (GET /service-requests/my-tasks)
  Future<Map<String, dynamic>> myTasks(String token) async {
    try {
      final uri = Uri.parse('$baseUrl/service-requests/my-tasks');
      final response = await http.get(uri, headers: {"Authorization": "Bearer $token"});

      if (response.statusCode == 200) {
        try {
          final body = jsonDecode(response.body);
          return {'success': true, 'data': body['data']};
        } catch (e) {
          return {'success': false, 'message': 'Invalid JSON response: ${response.body}', 'statusCode': response.statusCode};
        }
      }

      return {'success': false, 'message': response.body.isNotEmpty ? response.body : 'Failed to get my tasks', 'statusCode': response.statusCode};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Get details of a service request (GET /service-requests/{id})
  Future<Map<String, dynamic>> getById(String token, String id) async {
    try {
      final uri = Uri.parse('$baseUrl/service-requests/$id');
      final response = await http.get(uri, headers: {"Authorization": "Bearer $token"});

      if (response.statusCode == 200) {
        try {
          final body = jsonDecode(response.body);
          return {'success': true, 'data': body['data']};
        } catch (e) {
          return {'success': false, 'message': 'Invalid JSON response: ${response.body}', 'statusCode': response.statusCode};
        }
      }

      return {'success': false, 'message': response.body.isNotEmpty ? response.body : 'Failed to get service request', 'statusCode': response.statusCode};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Update service request (PATCH /service-requests/{id})
  Future<Map<String, dynamic>> update(String token, String id, Map<String, dynamic> payload) async {
    try {
      final uri = Uri.parse('$baseUrl/service-requests/$id');
      final response = await http.patch(uri, headers: {"Authorization": "Bearer $token", "Content-Type": "application/json"}, body: jsonEncode(payload));

      try {
        final body = jsonDecode(response.body);
        return {'success': response.statusCode == 200, 'data': body['data'], 'statusCode': response.statusCode};
      } catch (e) {
        return {'success': response.statusCode == 200, 'statusCode': response.statusCode, 'message': response.body.isNotEmpty ? response.body : 'Non-JSON response from update service request'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Patch status (PATCH /service-requests/{id}/status)
  Future<Map<String, dynamic>> patchStatus(String token, String id, Map<String, dynamic> payload) async {
    try {
      final uri = Uri.parse('$baseUrl/service-requests/$id/status');
      final response = await http.patch(uri, headers: {"Authorization": "Bearer $token", "Content-Type": "application/json"}, body: jsonEncode(payload));

      try {
        final body = jsonDecode(response.body);
        return {'success': response.statusCode == 200, 'data': body['data'], 'statusCode': response.statusCode};
      } catch (e) {
        return {'success': response.statusCode == 200, 'statusCode': response.statusCode, 'message': response.body.isNotEmpty ? response.body : 'Non-JSON response from patch status'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Assign technician to ticket (PATCH /service-requests/{id}/assign) - Admin only
  Future<Map<String, dynamic>> assign(String token, String id, Map<String, dynamic> payload) async {
    try {
      final uri = Uri.parse('$baseUrl/service-requests/$id/assign');
      final response = await http.patch(uri, headers: {"Authorization": "Bearer $token", "Content-Type": "application/json"}, body: jsonEncode(payload));

      try {
        final body = jsonDecode(response.body);
        return {'success': response.statusCode == 200, 'data': body['data'], 'statusCode': response.statusCode};
      } catch (e) {
        return {'success': response.statusCode == 200, 'statusCode': response.statusCode, 'message': response.body.isNotEmpty ? response.body : 'Non-JSON response from assign'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Composite assignment as per updated spec: status + assigned_to + schedule_date
  /// Sends PATCH /service-requests/{id} with body {status, assigned_to, schedule_date}
  /// Falls back to current UTC time if scheduleDate not provided.
  Future<Map<String, dynamic>> assignComposite(String token, String id, String technicianId, {DateTime? scheduleDate}) async {
    final payload = {
      'status': 'assigned',
      'assigned_to': technicianId,
      'schedule_date': (scheduleDate ?? DateTime.now().toUtc()).toIso8601String(),
    };
    try {
      final uri = Uri.parse('$baseUrl/service-requests/$id');
      final response = await http.patch(
        uri,
        headers: {"Authorization": "Bearer $token", "Content-Type": "application/json"},
        body: jsonEncode(payload),
      );
      try {
        final body = jsonDecode(response.body);
        return {
          'success': response.statusCode == 200,
          'data': body['data'],
          'statusCode': response.statusCode,
        };
      } catch (e) {
        return {
          'success': response.statusCode == 200,
          'statusCode': response.statusCode,
          'message': response.body.isNotEmpty ? response.body : 'Non-JSON response from composite assign',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Delete ticket (DELETE /service-requests/{id}) - Admin only
  Future<Map<String, dynamic>> delete(String token, String id) async {
    try {
      final uri = Uri.parse('$baseUrl/service-requests/$id');
      final response = await http.delete(uri, headers: {"Authorization": "Bearer $token"});

      try {
        final body = jsonDecode(response.body);
        return {'success': response.statusCode == 200 || response.statusCode == 204, 'data': body['data'], 'statusCode': response.statusCode};
      } catch (e) {
        return {'success': response.statusCode == 200 || response.statusCode == 204, 'statusCode': response.statusCode, 'message': response.body.isNotEmpty ? response.body : 'Non-JSON response from delete'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// List service requests under a specific RBW (GET /rbw/{rbw_id}/service-requests)
  Future<Map<String, dynamic>> listByRbw(String token, String rbwId, {Map<String, String>? queryParams}) async {
    try {
      final uri = Uri.parse('$baseUrl/rbw/$rbwId/service-requests').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: {"Authorization": "Bearer $token"});

      if (response.statusCode == 200) {
        try {
          final body = jsonDecode(response.body);
          return {'success': true, 'data': body['data'], 'meta': body['meta']};
        } catch (e) {
          return {'success': false, 'message': 'Invalid JSON response: ${response.body}', 'statusCode': response.statusCode};
        }
      }

      return {'success': false, 'message': response.body.isNotEmpty ? response.body : 'Failed to list service requests for RBW', 'statusCode': response.statusCode};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}
