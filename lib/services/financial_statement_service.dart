import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_constants.dart';





class FinancialStatementService {
















  Future<Map<String, dynamic>> generateStatement({
    required String token,
    required String rbwId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final body = {
        "rbw_id": rbwId,
        "start_date": _formatDate(startDate),
        "end_date": _formatDate(endDate),
      };

      print('[FINANCIAL STATEMENT SERVICE] POST ${ApiConstants.financialStatements}');
      print('[FINANCIAL STATEMENT SERVICE] Request body: ${jsonEncode(body)}');

      final response = await http.post(
        Uri.parse(ApiConstants.financialStatements),
        headers: ApiConstants.authHeaders(token),
        body: jsonEncode(body),
      );

      print('[FINANCIAL STATEMENT SERVICE] Status: ${response.statusCode}');
      print('[FINANCIAL STATEMENT SERVICE] Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'data': responseData['data'] ?? responseData,
        };
      } else {
        final errorData = _parseError(response);
        return {
          'success': false,
          'message': errorData['message'],
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      print('[FINANCIAL STATEMENT SERVICE] Exception: $e');
      return {
        'success': false,
        'message': 'Error generating financial statement: $e',
      };
    }
  }


  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }


  Map<String, dynamic> _parseError(http.Response response) {
    try {
      if (response.body.isNotEmpty) {
        final errorData = jsonDecode(response.body);
        return {
          'message': errorData['message'] ?? errorData['error'] ?? 'Unknown error',
          'error': errorData['error'],
        };
      }
    } catch (e) {

    }

    return {
      'message': 'Server error (${response.statusCode})',
      'error': null,
    };
  }
}
