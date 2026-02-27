import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_constants.dart';

class NodeService {
  final String baseUrl = ApiConstants.apiBaseUrl;


  Future<Map<String, dynamic>> createUnderRbw(String token, String rbwId, Map<String, dynamic> payload) async {
    try {
      final uri = Uri.parse('$baseUrl/rbw/$rbwId/nodes');
      final response = await http.post(uri, headers: {"Authorization": "Bearer $token", "Content-Type": "application/json"}, body: jsonEncode(payload));

      try {
        final body = jsonDecode(response.body);
        return {'success': response.statusCode == 201 || response.statusCode == 200, 'data': body['data'], 'statusCode': response.statusCode};
      } catch (e) {
        return {'success': response.statusCode == 201 || response.statusCode == 200, 'statusCode': response.statusCode, 'message': response.body.isNotEmpty ? response.body : 'Non-JSON response from create node'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }


  Future<Map<String, dynamic>> listByRbw(String token, String rbwId, {Map<String, String>? queryParams}) async {
    try {
      final uri = Uri.parse('$baseUrl/rbw/$rbwId/nodes').replace(queryParameters: queryParams);
      print('NodeService: Calling GET $uri');
      
      final response = await http.get(
        uri, 
        headers: {"Authorization": "Bearer $token"}
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('NodeService: Request timeout after 10 seconds');
          throw Exception('Request timeout');
        },
      );

      print('NodeService: Response status ${response.statusCode}');
      print('NodeService: Response body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');

      if (response.statusCode == 200) {
        try {
          final body = jsonDecode(response.body);
          print('NodeService: Found ${(body['data'] as List?)?.length ?? 0} nodes');
          return {'success': true, 'data': body['data'], 'meta': body['meta']};
        } catch (e) {
          print('NodeService: JSON decode error: $e');
          return {'success': false, 'message': 'Invalid JSON response: ${response.body}', 'statusCode': response.statusCode};
        }
      }

      print('NodeService: Error response: ${response.statusCode}');
      return {'success': false, 'message': response.body.isNotEmpty ? response.body : 'Failed to list nodes for RBW', 'statusCode': response.statusCode};
    } catch (e) {
      print('NodeService: Exception: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }


  Future<Map<String, dynamic>> getAllNodes(String token, {Map<String, String>? queryParams}) async {
    try {
      final uri = Uri.parse('$baseUrl/nodes').replace(queryParameters: queryParams);
      print('NodeService: Calling GET $uri');
      
      final response = await http.get(
        uri, 
        headers: {"Authorization": "Bearer $token"}
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('NodeService: Request timeout after 10 seconds');
          throw Exception('Request timeout');
        },
      );

      print('NodeService: Response status ${response.statusCode}');
      print('NodeService: Response body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');

      if (response.statusCode == 200) {
        try {
          final body = jsonDecode(response.body);
          print('NodeService: Found ${(body['data'] as List?)?.length ?? 0} nodes');
          return {'success': true, 'data': body['data'], 'meta': body['meta']};
        } catch (e) {
          print('NodeService: JSON decode error: $e');
          return {'success': false, 'message': 'Invalid JSON response: ${response.body}', 'statusCode': response.statusCode};
        }
      }

      print('NodeService: Error response: ${response.statusCode}');
      return {'success': false, 'message': response.body.isNotEmpty ? response.body : 'Failed to list nodes', 'statusCode': response.statusCode};
    } catch (e) {
      print('NodeService: Exception: $e');
      return {'success': false, 'message': 'Network error: $e'};
    }
  }


  Future<Map<String, dynamic>> getById(String token, String id) async {
    try {
      final uri = Uri.parse('$baseUrl/nodes/$id');
      final response = await http.get(uri, headers: {"Authorization": "Bearer $token"});

      if (response.statusCode == 200) {
        try {
          final body = jsonDecode(response.body);
          return {'success': true, 'data': body['data']};
        } catch (e) {
          return {'success': false, 'message': 'Invalid JSON response: ${response.body}', 'statusCode': response.statusCode};
        }
      }

      return {'success': false, 'message': response.body.isNotEmpty ? response.body : 'Failed to get node', 'statusCode': response.statusCode};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }


  Future<Map<String, dynamic>> listSensorsByNode(String token, String nodeId) async {
    final res = await getById(token, nodeId);
    if (res['success'] == true) {
      final data = res['data'] ?? {};
      final sensors = (data is Map && data.containsKey('sensors')) ? (data['sensors'] as List<dynamic>? ?? []) : [];
      return {'success': true, 'data': sensors};
    }
    return res;
  }


  Future<Map<String, dynamic>> getSensorsByNode(String token, String nodeId) async {
    try {
      final uri = Uri.parse('$baseUrl/nodes/$nodeId/sensors');
      final response = await http.get(uri, headers: {"Authorization": "Bearer $token"});

      if (response.statusCode == 200) {
        try {
          final body = jsonDecode(response.body);
          return {'success': true, 'data': body['data']};
        } catch (e) {
          return {'success': false, 'message': 'Invalid JSON response: ${response.body}', 'statusCode': response.statusCode};
        }
      }

      return {'success': false, 'message': response.body.isNotEmpty ? response.body : 'Failed to get sensors for node', 'statusCode': response.statusCode};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }


  Future<Map<String, dynamic>> update(String token, String id, Map<String, dynamic> payload) async {
    try {
      final uri = Uri.parse('$baseUrl/nodes/$id');
      final response = await http.patch(uri, headers: {"Authorization": "Bearer $token", "Content-Type": "application/json"}, body: jsonEncode(payload));

      try {
        final body = jsonDecode(response.body);
        return {'success': response.statusCode == 200, 'data': body['data'], 'statusCode': response.statusCode};
      } catch (e) {
        return {'success': response.statusCode == 200, 'statusCode': response.statusCode, 'message': response.body.isNotEmpty ? response.body : 'Non-JSON response from update node'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }


  Future<Map<String, dynamic>> delete(String token, String id) async {
    try {
      final uri = Uri.parse('$baseUrl/nodes/$id');
      final response = await http.delete(uri, headers: {"Authorization": "Bearer $token"});

      try {
        final body = jsonDecode(response.body);
        return {'success': response.statusCode == 200 || response.statusCode == 204, 'data': body['data'], 'statusCode': response.statusCode};
      } catch (e) {
        return {'success': response.statusCode == 200 || response.statusCode == 204, 'statusCode': response.statusCode, 'message': response.body.isNotEmpty ? response.body : 'Non-JSON response from delete node'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }


  Future<Map<String, dynamic>> patchAudio(String token, String id, bool state) async {
    try {
      final uri = Uri.parse('$baseUrl/nodes/$id/audio');
      final response = await http.patch(uri, headers: {"Authorization": "Bearer $token", "Content-Type": "application/json"}, body: jsonEncode({'state': state}));

      if (response.statusCode == 200) {
        try {
          final body = jsonDecode(response.body);
          return {'success': true, 'data': body['data']};
        } catch (e) {
          return {'success': false, 'message': 'Invalid JSON response: ${response.body}', 'statusCode': response.statusCode};
        }
      }

      return {'success': false, 'message': response.body.isNotEmpty ? response.body : 'Failed to patch audio state', 'statusCode': response.statusCode};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }


  Future<Map<String, dynamic>> getAudioState(String token, String id) async {
    try {
      final uri = Uri.parse('$baseUrl/nodes/$id/audio');
      final response = await http.get(uri, headers: {"Authorization": "Bearer $token"});

      if (response.statusCode == 200) {
        try {
          final body = jsonDecode(response.body);
          return {'success': true, 'data': body['data']};
        } catch (e) {
          return {'success': false, 'message': 'Invalid JSON response: ${response.body}', 'statusCode': response.statusCode};
        }
      }

      return {'success': false, 'message': response.body.isNotEmpty ? response.body : 'Failed to get audio state', 'statusCode': response.statusCode};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }




  Future<Map<String, dynamic>> controlAudio(String token, String id, String action, int value) async {
    try {
      final uri = Uri.parse('$baseUrl/nodes/$id/audio');
      final response = await http.patch(
        uri, 
        headers: {
          "Authorization": "Bearer $token", 
          "Content-Type": "application/json"
        }, 
        body: jsonEncode({
          'action': action,
          'value': value
        })
      );

      if (response.statusCode == 200) {
        try {
          final body = jsonDecode(response.body);
          return {'success': true, 'data': body['data']};
        } catch (e) {
          return {'success': false, 'message': 'Invalid JSON response: ${response.body}', 'statusCode': response.statusCode};
        }
      }

      return {'success': false, 'message': response.body.isNotEmpty ? response.body : 'Failed to control audio', 'statusCode': response.statusCode};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }


  Future<Map<String, dynamic>> patchPump(String token, String id, bool state) async {
    try {
      final uri = Uri.parse('$baseUrl/nodes/$id/pump');
      final response = await http.patch(uri, headers: {"Authorization": "Bearer $token", "Content-Type": "application/json"}, body: jsonEncode({'action': 'sprayer_set', 'value': state ? 1 : 0}));

      if (response.statusCode == 200) {
        try {
          final body = jsonDecode(response.body);
          return {'success': true, 'data': body['data']};
        } catch (e) {
          return {'success': false, 'message': 'Invalid JSON response: ${response.body}', 'statusCode': response.statusCode};
        }
      }

      return {'success': false, 'message': response.body.isNotEmpty ? response.body : 'Failed to patch pump state', 'statusCode': response.statusCode};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }


  Future<Map<String, dynamic>> patchStatus(String token, String id, String status) async {
    try {
      final uri = Uri.parse('$baseUrl/nodes/$id/status');
      final response = await http.patch(uri, headers: {"Authorization": "Bearer $token", "Content-Type": "application/json"}, body: jsonEncode({'status': status}));

      if (response.statusCode == 200) {
        try {
          final body = jsonDecode(response.body);
          return {'success': true, 'data': body['data']};
        } catch (e) {
          return {'success': false, 'message': 'Invalid JSON response: ${response.body}', 'statusCode': response.statusCode};
        }
      }

      return {'success': false, 'message': response.body.isNotEmpty ? response.body : 'Failed to patch status', 'statusCode': response.statusCode};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }


  Future<Map<String, dynamic>> heartbeat(String token, String id, Map<String, dynamic> payload) async {
    try {
      final uri = Uri.parse('$baseUrl/nodes/$id/heartbeat');
      final response = await http.post(uri, headers: {"Authorization": "Bearer $token", "Content-Type": "application/json"}, body: jsonEncode(payload));

      if (response.statusCode == 200) {
        try {
          final body = jsonDecode(response.body);
          return {'success': true, 'data': body['data']};
        } catch (e) {
          return {'success': false, 'message': 'Invalid JSON response: ${response.body}', 'statusCode': response.statusCode};
        }
      }

      return {'success': false, 'message': response.body.isNotEmpty ? response.body : 'Failed to send heartbeat', 'statusCode': response.statusCode};
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}
