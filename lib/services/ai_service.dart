import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_constants.dart';



class AIService {

  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();










  Future<Map<String, dynamic>> detectAnomaly(
    String token,
    String nodeId,
    Map<String, dynamic> sensorData,
  ) async {
    try {
      print('[AI SERVICE] Detecting anomalies for node: $nodeId');
      print('[AI SERVICE] Sensor data: $sensorData');

      final response = await http
          .post(
        Uri.parse('${ApiConstants.apiBaseUrl}/nodes/$nodeId/ai/anomaly'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'temperature': sensorData['temperature'],
          'humidity': sensorData['humidity'],
          'ammonia': sensorData['ammonia'],
          'co2': sensorData['co2'],
          'lux': sensorData['lux'],
        }),
      )
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('AI anomaly detection timeout');
        },
      );

      print('[AI SERVICE] Anomaly detection response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);


        final result = data['data'] ?? data;

        print('[AI SERVICE] Anomaly result: $result');
        return result;
      } else if (response.statusCode == 404) {
        print('[AI SERVICE] AI endpoint not available (404)');
        return {
          'anomaly_detected': false,
          'anomalies': [],
          'error': 'AI service not available',
        };
      } else {
        print('[AI SERVICE] Error: ${response.statusCode} - ${response.body}');
        return {
          'anomaly_detected': false,
          'anomalies': [],
          'error': 'Failed to detect anomalies',
        };
      }
    } catch (e) {
      print('[AI SERVICE] Exception in detectAnomaly: $e');
      return {
        'anomaly_detected': false,
        'anomalies': [],
        'error': e.toString(),
      };
    }
  }













  Future<Map<String, dynamic>> predictGrade(
    String token, {
    required double temperature,
    required double humidity,
    required double ammonia,
    String? rbwId,
    String? nodeId,
  }) async {
    try {
      print(
          '[AI SERVICE] Predicting grade with T=$temperature H=$humidity A=$ammonia');

      final body = <String, dynamic>{
        'temperature': temperature,
        'humidity': humidity,
        'ammonia': ammonia,
      };
      if (rbwId != null) body['rbw_id'] = rbwId;
      if (nodeId != null) body['node_id'] = nodeId;

      final response = await http
          .post(
        Uri.parse('${ApiConstants.apiBaseUrl}/ai/predict-grade'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('AI grade prediction timeout');
        },
      );

      print('[AI SERVICE] Grade prediction response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['data'] ?? data;

        print(
            '[AI SERVICE] Grade prediction: ${result['grade']} (${result['confidence']}');
        return result;
      } else if (response.statusCode == 404 || response.statusCode == 503) {
        print(
            '[AI SERVICE] AI endpoint not available (${response.statusCode})');
        return {
          'grade': 'Unknown',
          'confidence': 0.0,
          'error': 'AI service not available',
        };
      } else {
        print('[AI SERVICE] Error: ${response.statusCode} - ${response.body}');
        return {
          'grade': 'Unknown',
          'confidence': 0.0,
          'error': 'Failed to predict grade',
        };
      }
    } catch (e) {
      print('[AI SERVICE] Exception in predictGrade: $e');
      return {
        'grade': 'Unknown',
        'confidence': 0.0,
        'error': e.toString(),
      };
    }
  }













  Future<Map<String, dynamic>> getPumpRecommendation(
    String token, {
    required double temperature,
    required double humidity,
    required double ammonia,
    String? rbwId,
    String? nodeId,
  }) async {
    try {
      print(
          '[AI SERVICE] Getting pump recommendation T=$temperature H=$humidity A=$ammonia');

      final body = <String, dynamic>{
        'temperature': temperature,
        'humidity': humidity,
        'ammonia': ammonia,
      };
      if (rbwId != null) body['rbw_id'] = rbwId;
      if (nodeId != null) body['node_id'] = nodeId;

      final response = await http
          .post(
        Uri.parse('${ApiConstants.apiBaseUrl}/ai/predict-pump'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
          .timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('AI pump recommendation timeout');
        },
      );

      print(
          '[AI SERVICE] Pump recommendation response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['data'] ?? data;

        print(
            '[AI SERVICE] Pump recommendation: ${result['pump_state']} for ${result['duration_minutes']} mins');
        return result;
      } else if (response.statusCode == 404 || response.statusCode == 503) {
        print(
            '[AI SERVICE] AI endpoint not available (${response.statusCode})');
        return {
          'pump_state': 'maintain',
          'reason': 'AI service not available',
          'confidence': 0.0,
          'duration_minutes': 0,
        };
      } else {
        print('[AI SERVICE] Error: ${response.statusCode} - ${response.body}');
        return {
          'pump_state': 'maintain',
          'reason': 'Failed to get recommendation',
          'confidence': 0.0,
          'duration_minutes': 0,
        };
      }
    } catch (e) {
      print('[AI SERVICE] Exception in getPumpRecommendation: $e');
      return {
        'pump_state': 'maintain',
        'reason': e.toString(),
        'confidence': 0.0,
        'duration_minutes': 0,
      };
    }
  }













  Future<Map<String, dynamic>> getComprehensiveAnalysis(
    String token, {
    required double temperature,
    required double humidity,
    required double ammonia,
    String? rbwId,
    String? nodeId,
  }) async {
    try {
      print(
          '[AI SERVICE] Getting comprehensive analysis T=$temperature H=$humidity A=$ammonia');

      final body = <String, dynamic>{
        'temperature': temperature,
        'humidity': humidity,
        'ammonia': ammonia,
      };
      if (rbwId != null) body['rbw_id'] = rbwId;
      if (nodeId != null) body['node_id'] = nodeId;

      final response = await http
          .post(
        Uri.parse('${ApiConstants.apiBaseUrl}/ai/analyze'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('AI analysis timeout');
        },
      );

      print(
          '[AI SERVICE] Comprehensive analysis response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['data'] ?? data;

        print(
            '[AI SERVICE] Health score: ${result['overall_health_score']}/100');
        print('[AI SERVICE] Grade: ${result['grade_prediction']?['grade']}');
        return result;
      } else if (response.statusCode == 404 || response.statusCode == 503) {
        print(
            '[AI SERVICE] AI endpoint not available (${response.statusCode})');
        return {
          'overall_health_score': 0.0,
          'status': 'unknown',
          'sensors': {},
          'grade_prediction': {'grade': 'Unknown', 'confidence': 0.0},
          'pump_recommendation': {'pump_state': 'OFF', 'duration_minutes': 0},
          'recommendations': [],
          'error': 'AI service not available',
        };
      } else {
        print('[AI SERVICE] Error: ${response.statusCode} - ${response.body}');
        return {
          'overall_health_score': 0.0,
          'status': 'unknown',
          'sensors': {},
          'grade_prediction': {'grade': 'Unknown', 'confidence': 0.0},
          'pump_recommendation': {'pump_state': 'OFF', 'duration_minutes': 0},
          'recommendations': [],
          'error': 'Failed to get analysis',
        };
      }
    } catch (e) {
      print('[AI SERVICE] Exception in getComprehensiveAnalysis: $e');
      return {
        'overall_health_score': 0.0,
        'status': 'unknown',
        'sensors': {},
        'grade_prediction': {'grade': 'Unknown', 'confidence': 0.0},
        'pump_recommendation': {'pump_state': 'OFF', 'duration_minutes': 0},
        'recommendations': [],
        'error': e.toString(),
      };
    }
  }


  bool hasCriticalAnomalies(Map<String, dynamic> anomalyResult) {
    if (anomalyResult['anomaly_detected'] != true) return false;

    final anomalies = anomalyResult['anomalies'] as List?;
    if (anomalies == null || anomalies.isEmpty) return false;


    return anomalies.any((a) =>
        (a['severity'] ?? '').toString().toLowerCase() == 'critical' ||
        (a['severity'] ?? '').toString().toLowerCase() == 'high');
  }


  String getAnomalySummary(Map<String, dynamic> anomalyResult) {
    if (anomalyResult['anomaly_detected'] != true) {
      return 'Semua sensor normal';
    }

    final anomalies = anomalyResult['anomalies'] as List?;
    if (anomalies == null || anomalies.isEmpty) {
      return 'Tidak ada anomali terdeteksi';
    }

    final messages = anomalies.map((a) {
      final sensor = a['sensor'] ?? 'Unknown';
      final value = a['value'] ?? '-';
      final message = a['message'] ?? 'Abnormal';
      return '$sensor: $value - $message';
    }).join('\n');

    return messages;
  }


  String getGradeColor(String grade) {
    switch (grade.toUpperCase()) {
      case 'A':
        return '#4CAF50'; // Green
      case 'B':
        return '#8BC34A'; // Light Green
      case 'C':
        return '#FFC107'; // Amber
      case 'D':
        return '#F44336'; // Red
      default:
        return '#9E9E9E'; // Grey
    }
  }
}
