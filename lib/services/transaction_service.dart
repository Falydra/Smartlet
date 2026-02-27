import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_constants.dart';









class TransactionService {














  Future<Map<String, dynamic>> createTransaction({
    required String token,
    required String rbwId,
    required String categoryId,
    required double amount,
    required String type, // "income" or "expense"
    String? description,
    required DateTime transactionDate,
  }) async {
    try {
      final body = {
        "rbw_id": rbwId,
        "category_id": categoryId,
        "amount": amount,
        "type": type,
        if (description != null) "description": description,
        "transaction_date": transactionDate.toUtc().toIso8601String(),
      };

      print('[TRANSACTION SERVICE] POST ${ApiConstants.transactions}');
      print('[TRANSACTION SERVICE] Request body: ${jsonEncode(body)}');

      final response = await http.post(
        Uri.parse(ApiConstants.transactions),
        headers: ApiConstants.authHeaders(token),
        body: jsonEncode(body),
      );

      print('[TRANSACTION SERVICE] Status: ${response.statusCode}');
      print('[TRANSACTION SERVICE] Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
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
    } catch (e, stackTrace) {
      print('[TRANSACTION SERVICE] Exception: $e');
      print('[TRANSACTION SERVICE] Stack trace: $stackTrace');
      return {
        'success': false,
        'message': 'Error creating transaction: $e',
      };
    }
  }


  Future<Map<String, dynamic>> createIncome({
    required String token,
    required String rbwId,
    required String categoryId,
    required double amount,
    String? description,
    required DateTime transactionDate,
  }) async {
    return createTransaction(
      token: token,
      rbwId: rbwId,
      categoryId: categoryId,
      amount: amount,
      type: ApiConstants.transactionTypeIncome,
      description: description,
      transactionDate: transactionDate,
    );
  }


  Future<Map<String, dynamic>> createExpense({
    required String token,
    required String rbwId,
    required String categoryId,
    required double amount,
    String? description,
    required DateTime transactionDate,
  }) async {
    return createTransaction(
      token: token,
      rbwId: rbwId,
      categoryId: categoryId,
      amount: amount,
      type: ApiConstants.transactionTypeExpense,
      description: description,
      transactionDate: transactionDate,
    );
  }








  Future<Map<String, dynamic>> getTransaction({
    required String token,
    required String transactionId,
  }) async {
    try {
      final url = ApiConstants.transactionDetail(transactionId);
      print('[TRANSACTION SERVICE] GET $url');

      final response = await http.get(
        Uri.parse(url),
        headers: ApiConstants.authHeaders(token),
      );

      print('[TRANSACTION SERVICE] Status: ${response.statusCode}');

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
      print('[TRANSACTION SERVICE] Exception: $e');
      return {
        'success': false,
        'message': 'Error getting transaction: $e',
      };
    }
  }












  Future<Map<String, dynamic>> updateTransaction({
    required String token,
    required String transactionId,
    String? categoryId,
    double? amount,
    String? description,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (categoryId != null) body['category_id'] = categoryId;
      if (amount != null) body['amount'] = amount;
      if (description != null) body['description'] = description;

      final url = ApiConstants.transactionDetail(transactionId);
      print('[TRANSACTION SERVICE] PATCH $url');
      print('[TRANSACTION SERVICE] Request body: ${jsonEncode(body)}');

      final response = await http.patch(
        Uri.parse(url),
        headers: ApiConstants.authHeaders(token),
        body: jsonEncode(body),
      );

      print('[TRANSACTION SERVICE] Status: ${response.statusCode}');
      print('[TRANSACTION SERVICE] Response: ${response.body}');

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
      print('[TRANSACTION SERVICE] Exception: $e');
      return {
        'success': false,
        'message': 'Error updating transaction: $e',
      };
    }
  }







  Future<Map<String, dynamic>> deleteTransaction({
    required String token,
    required String transactionId,
  }) async {
    try {
      final url = ApiConstants.transactionDetail(transactionId);
      print('[TRANSACTION SERVICE] DELETE $url');

      final response = await http.delete(
        Uri.parse(url),
        headers: ApiConstants.authHeaders(token),
      );

      print('[TRANSACTION SERVICE] Status: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        return {
          'success': true,
          'message': 'Transaction deleted successfully',
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
      print('[TRANSACTION SERVICE] Exception: $e');
      return {
        'success': false,
        'message': 'Error deleting transaction: $e',
      };
    }
  }














  Future<Map<String, dynamic>> listTransactionsByRbw({
    required String token,
    required String rbwId,
    int page = 1,
    int limit = 20,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        if (type != null) 'type': type,
        if (startDate != null) 'start_date': _formatDate(startDate),
        if (endDate != null) 'end_date': _formatDate(endDate),
      };

      final uri = Uri.parse(ApiConstants.rbwTransactions(rbwId))
          .replace(queryParameters: queryParams);
      print('[TRANSACTION SERVICE] GET $uri');
      print('[TRANSACTION SERVICE] Query params: $queryParams');

      final response = await http.get(
        uri,
        headers: ApiConstants.authHeaders(token),
      );

      print('[TRANSACTION SERVICE] Status: ${response.statusCode}');
      print('[TRANSACTION SERVICE] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final transactions = responseData['data'] ?? [];
        print('[TRANSACTION SERVICE] Received ${transactions.length} transactions');
        if (transactions.isNotEmpty) {
          print('[TRANSACTION SERVICE] First transaction: ${transactions.first}');
        }
        return {
          'success': true,
          'data': transactions,
          'meta': responseData['meta'],
        };
      } else {
        final errorData = _parseError(response);
        return {
          'success': false,
          'message': errorData['message'],
          'data': [],
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      print('[TRANSACTION SERVICE] Exception: $e');
      return {
        'success': false,
        'message': 'Error listing transactions: $e',
        'data': [],
      };
    }
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


  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }






  @Deprecated('Use listTransactionsByRbw instead')
  Future<List<dynamic>> getAll(
    String token, {
    int? month,
    int? year,
    String? houseId,
  }) async {
    if (houseId == null) {
      print('[TRANSACTION SERVICE] Warning: getAll requires houseId (rbwId)');
      return [];
    }


    DateTime? startDate;
    DateTime? endDate;
    if (year != null && month != null) {
      startDate = DateTime(year, month, 1);
      endDate = DateTime(year, month + 1, 0); // Last day of month
    }

    final result = await listTransactionsByRbw(
      token: token,
      rbwId: houseId,
      startDate: startDate,
      endDate: endDate,
      limit: 100,
    );

    return result['data'] ?? [];
  }


  @Deprecated('Use getTransaction instead')
  Future<Map<String, dynamic>?> getById(String token, String id) async {
    final result = await getTransaction(token: token, transactionId: id);
    return result['success'] == true ? result['data'] : null;
  }


  @Deprecated('Use deleteTransaction instead')
  Future<Map<String, dynamic>> delete(String token, String id) async {
    return deleteTransaction(token: token, transactionId: id);
  }


  @Deprecated('Use updateTransaction instead')
  Future<Map<String, dynamic>> update(
    String token,
    String id,
    Map<String, dynamic> data,
  ) async {
    return updateTransaction(
      token: token,
      transactionId: id,
      categoryId: data['category_id'],
      amount: data['amount']?.toDouble(),
      description: data['description'],
    );
  }
}
