import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_constants.dart';

class ServiceRequestService {
  final String baseUrl = ApiConstants.apiBaseUrl;


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
