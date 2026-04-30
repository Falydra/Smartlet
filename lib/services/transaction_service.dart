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
    required String transactionDate,
    int? quantity,
    double? unitPrice,
  }) async {
    try {
      final normalizedDate = _normalizeDateString(transactionDate);
      final resolvedQuantity = quantity ?? 1;
      final resolvedUnitPrice = unitPrice ?? amount;
      final body = {
        "rbw_id": rbwId,
        "date": normalizedDate,
        "category_id": categoryId,
        "qty": resolvedQuantity,
        "unit_price": resolvedUnitPrice,
        if (description != null) "note": description,
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
    required String transactionDate,
    int? quantity,
    double? unitPrice,
  }) async {
    return createTransaction(
      token: token,
      rbwId: rbwId,
      categoryId: categoryId,
      amount: amount,
      type: ApiConstants.transactionTypeIncome,
      description: description,
      transactionDate: transactionDate,
      quantity: quantity,
      unitPrice: unitPrice,
    );
  }


  Future<Map<String, dynamic>> createExpense({
    required String token,
    required String rbwId,
    required String categoryId,
    required double amount,
    String? description,
    required String transactionDate,
    int? quantity,
    double? unitPrice,
  }) async {
    return createTransaction(
      token: token,
      rbwId: rbwId,
      categoryId: categoryId,
      amount: amount,
      type: ApiConstants.transactionTypeExpense,
      description: description,
      transactionDate: transactionDate,
      quantity: quantity,
      unitPrice: unitPrice,
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
        final normalized = _normalizeTransaction(_extractTransactionMap(responseData));
        return {
          'success': true,
          'data': normalized,
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
        if (startDate != null) 'from': _formatDate(startDate),
        if (endDate != null) 'to': _formatDate(endDate),
      };

      final uri = Uri.parse(ApiConstants.rbwTransactions(rbwId))
          .replace(queryParameters: queryParams);
      print('[TRANSACTION SERVICE] GET $uri');
      print('[TRANSACTION SERVICE] Query params: $queryParams');

      final response = await http.get(
        uri,
        headers: ApiConstants.authHeaders(token),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => http.Response('{"data":[]}', 408),
      );

      print('[TRANSACTION SERVICE] Status: ${response.statusCode}');
      print('[TRANSACTION SERVICE] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final rawData = responseData['data'];
        final transactions = _normalizeTransactions(_extractTransactionList(rawData));
        print('[TRANSACTION SERVICE] Received ${transactions.length} transactions');
        if (transactions.isNotEmpty) {
          print('[TRANSACTION SERVICE] First transaction: ${transactions.first}');
        }
        return {
          'success': true,
          'data': transactions,
          'meta': _extractTransactionMeta(rawData),
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
        if (errorData is Map && errorData['error'] is Map) {
          final nestedError = errorData['error'] as Map;
          return {
            'message': nestedError['message'] ?? nestedError['error'] ?? 'Unknown error',
            'error': nestedError,
          };
        }
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

  String _normalizeDateString(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    if (trimmed.contains('T')) {
      return trimmed.split('T').first;
    }
    if (trimmed.length >= 10) {
      return trimmed.substring(0, 10);
    }
    return trimmed;
  }

  Map<String, dynamic> _extractTransactionMap(dynamic rawData) {
    if (rawData is Map && rawData['data'] is Map) {
      return Map<String, dynamic>.from(rawData['data'] as Map);
    }
    if (rawData is Map) {
      return Map<String, dynamic>.from(rawData);
    }
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _normalizeTransactions(List<dynamic> rawList) {
    return rawList
        .whereType<Map>()
        .map((item) => _normalizeTransaction(Map<String, dynamic>.from(item)))
        .toList();
  }

  Map<String, dynamic> _normalizeTransaction(Map<String, dynamic> raw) {
    final categoryName = _extractCategoryName(raw);
    final type = _inferTransactionType(raw, categoryName);
    final amount = _extractAmount(raw);
    final description = raw['description'] ?? raw['note'] ?? raw['notes'];
    final dateValue = raw['transaction_date'] ?? raw['date'] ?? raw['created_at'] ?? raw['createdAt'];
    final transactionDate = dateValue?.toString();

    return {
      ...raw,
      'category_name': categoryName,
      'type': type,
      'amount': amount,
      'description': description,
      'transaction_date': transactionDate,
    };
  }

  String? _extractCategoryName(Map<String, dynamic> raw) {
    final direct = raw['category_name']?.toString();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }
    final category = raw['category'];
    if (category is Map) {
      final name = category['name']?.toString();
      if (name != null && name.isNotEmpty) {
        return name;
      }
    }
    return null;
  }

  String _inferTransactionType(Map<String, dynamic> raw, String? categoryName) {
    final type = raw['type']?.toString().toLowerCase() ?? '';
    if (type == 'income' || type == 'expense') {
      return type;
    }
    final name = (categoryName ?? '').toLowerCase();
    if (name.contains('penjualan') ||
        name.contains('pendapatan') ||
        name.contains('pemasukan') ||
        name.contains('income')) {
      return 'income';
    }
    if (name.contains('biaya') ||
        name.contains('pengeluaran') ||
        name.contains('expense')) {
      return 'expense';
    }
    return 'expense';
  }

  double _extractAmount(Map<String, dynamic> raw) {
    final amount = raw['amount'];
    if (amount is num) {
      return amount.toDouble();
    }
    final total = raw['total'] ?? raw['total_amount'];
    if (total is num) {
      return total.toDouble();
    }
    final qty = raw['qty'];
    final unitPrice = raw['unit_price'];
    if (qty is num && unitPrice is num) {
      return qty.toDouble() * unitPrice.toDouble();
    }
    return 0.0;
  }

  List<dynamic> _extractTransactionList(dynamic rawData) {
    if (rawData == null) {
      return [];
    }
    if (rawData is List) {
      return rawData;
    }
    if (rawData is Map) {
      final nested = rawData['data'];
      if (nested is List) {
        return nested;
      }
    }
    return [];
  }

  Map<String, dynamic>? _extractTransactionMeta(dynamic rawData) {
    if (rawData is Map) {
      final total = rawData['total'];
      final limit = rawData['limit'];
      final offset = rawData['offset'];
      if (total != null || limit != null || offset != null) {
        return {
          'total': total ?? 0,
          'limit': limit ?? 0,
          'offset': offset ?? 0,
        };
      }
    }
    return null;
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

    final raw = result['data'] ?? [];
    if (raw is List) {
      return _normalizeTransactions(raw);
    }
    return [];
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
