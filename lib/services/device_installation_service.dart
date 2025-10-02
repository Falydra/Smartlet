import 'dart:convert';
import 'package:http/http.dart' as http;

class DeviceInstallationService {
  final String baseUrl = "https://api.fuadfakhruz.id/api/v1";

  // Get device installation code for a user
  Future<Map<String, dynamic>> getInstallationCode(String token, int houseId) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/iot-devices?swiftlet_house_id=$houseId"),
        headers: {"Authorization": "Bearer $token"},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to get installation code',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Install device with installation code
  Future<Map<String, dynamic>> installDevice(String token, String installCode, int houseId, int floor) async {
    try {
      final payload = {
        'install_code': installCode,
        'swiftlet_house_id': houseId,
        'floor': floor,
        'device_name': 'ESP32_YGY_001_L$floor',
        'device_type': 'ESP32_Sensor',
        'status': 1, // Active
      };

      final response = await http.post(
        Uri.parse("$baseUrl/iot-devices"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json"
        },
        body: jsonEncode(payload),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data['data'],
          'message': 'Device installed successfully',
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to install device',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Check if device is installed in a house
  Future<Map<String, dynamic>> checkDeviceInstallation(String token, int houseId) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/iot-devices?swiftlet_house_id=$houseId"),
        headers: {"Authorization": "Bearer $token"},
      );
      
      print('Device installation API response: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final devices = data['data'] as List;
        
        // Fix ESP31 to ESP32 in install codes
        final correctedInstallCodes = devices.map((device) {
          String installCode = device['install_code'] ?? '';
          // Fix ESP31 to ESP32 typo
          if (installCode.startsWith('ESP31')) {
            installCode = installCode.replaceFirst('ESP31', 'ESP32');
            print('Corrected install code from ${device['install_code']} to $installCode');
          }
          return installCode;
        }).toList();
        
        print('Raw install codes: ${devices.map((d) => d['install_code']).toList()}');
        print('Corrected install codes: $correctedInstallCodes');
        
        return {
          'success': true,
          'hasDevices': devices.isNotEmpty,
          'devices': devices,
          'installationCodes': correctedInstallCodes,
        };
      } else {
        return {
          'success': false,
          'hasDevices': false,
          'message': 'Failed to check device installation',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'hasDevices': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Get sensor data by installation code
  Future<Map<String, dynamic>> getSensorData(String token, String installCode) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/sensor-data?install_code=$installCode&limit=1"),
        headers: {"Authorization": "Bearer $token"},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final sensorData = data['data'] as List;
        
        if (sensorData.isNotEmpty) {
          return {
            'success': true,
            'hasData': true,
            'data': sensorData.first,
          };
        } else {
          return {
            'success': true,
            'hasData': false,
            'message': 'No sensor data available',
          };
        }
      } else {
        return {
          'success': false,
          'hasData': false,
          'message': 'Failed to get sensor data',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'hasData': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Correct ESP31 to ESP32 in install codes for a specific device
  Future<Map<String, dynamic>> correctInstallCode(String token, int deviceId, String newInstallCode) async {
    try {
      final payload = {
        'install_code': newInstallCode,
      };

      final response = await http.put(
        Uri.parse("$baseUrl/iot-devices/$deviceId"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json"
        },
        body: jsonEncode(payload),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data['data'],
          'message': 'Install code corrected successfully',
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to correct install code',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }

  // Auto-correct all ESP31 to ESP32 install codes for a house
  Future<Map<String, dynamic>> autoCorrectInstallCodes(String token, int houseId) async {
    try {
      final deviceCheck = await checkDeviceInstallation(token, houseId);
      
      if (deviceCheck['success'] == true) {
        final devices = deviceCheck['devices'] as List;
        int correctedCount = 0;
        
        for (final device in devices) {
          String installCode = device['install_code'] ?? '';
          if (installCode.startsWith('ESP31')) {
            String correctedCode = installCode.replaceFirst('ESP31', 'ESP32');
            final result = await correctInstallCode(token, device['id'], correctedCode);
            if (result['success'] == true) {
              correctedCount++;
              print('Auto-corrected: ${device['install_code']} -> $correctedCode');
            }
          }
        }
        
        return {
          'success': true,
          'correctedCount': correctedCount,
          'message': 'Auto-corrected $correctedCount install codes',
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to get devices for correction',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error auto-correcting install codes: $e',
      };
    }
  }

  // Request installation for a house
  Future<Map<String, dynamic>> requestInstallation(String token, int houseId, String reason) async {
    try {
      final payload = {
        'swiftlet_house_id': houseId,
        'request_reason': reason,
        'priority_level': 'normal',
        'status': 'pending',
      };

      final response = await http.post(
        Uri.parse("$baseUrl/installation-requests"),
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json"
        },
        body: jsonEncode(payload),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data['data'],
          'message': 'Installation request submitted successfully',
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to submit installation request',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: $e',
      };
    }
  }
}