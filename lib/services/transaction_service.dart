import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_constants.dart';

class TransactionService {
  // Create income transaction
  Future<Map<String, dynamic>> createIncome(String token, Map<String, dynamic> data) async {
    try {
      print('[TRANSACTION SERVICE] Creating income...');
      print('[TRANSACTION SERVICE] Original data: ${jsonEncode(data)}');
      
      // Validate items array
      if (data['items'] == null || (data['items'] as List).isEmpty) {
        return {
          'success': false,
          'message': 'No items provided',
        };
      }
      
      final items = data['items'] as List;
      final firstItem = items[0] as Map<String, dynamic>;
      
      // Extract and validate date
      final transactionDate = data['transaction_date']?.toString().split('T')[0] ?? '';
      print('[TRANSACTION SERVICE] Transaction date extracted: $transactionDate');
      
      // Transform data to match backend API
      final transformedData = {
        'rbw_id': data['house_id']?.toString(), // Convert house_id to rbw_id
        'date': transactionDate, // YYYY-MM-DD format
        'category_id': data['category_id']?.toString(),
        'qty': (firstItem['quantity'] as num), // Keep as num (int or double)
        'unit_price': (firstItem['price'] as num), // Keep as num (int or double)
        'note': data['description']?.toString() ?? '',
      };
      
      print('[TRANSACTION SERVICE] URL: ${ApiConstants.apiBaseUrl}/transactions');
      print('[TRANSACTION SERVICE] Transformed data: ${jsonEncode(transformedData)}');
      print('[TRANSACTION SERVICE] Data types: rbw_id=${transformedData['rbw_id'].runtimeType}, date=${transformedData['date'].runtimeType}, category_id=${transformedData['category_id'].runtimeType}, qty=${transformedData['qty'].runtimeType}, unit_price=${transformedData['unit_price'].runtimeType}');
      
      final response = await http.post(
        Uri.parse('${ApiConstants.apiBaseUrl}/transactions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(transformedData),
      );

      print('[TRANSACTION SERVICE] Response status: ${response.statusCode}');
      print('[TRANSACTION SERVICE] Response body: ${response.body}');
      print('[TRANSACTION SERVICE] Response headers: ${response.headers}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'data': responseData['data'] ?? responseData, // Handle both wrapped and unwrapped responses
        };
      } else {
        // Try to parse error message from response
        String errorMessage = 'Failed to create income';
        try {
          if (response.body.isNotEmpty) {
            final errorData = jsonDecode(response.body);
            errorMessage = errorData['error']?['message'] ?? errorData['message'] ?? response.body;
          } else {
            errorMessage = 'Server error (${response.statusCode}): ${response.reasonPhrase ?? "No response body"}';
          }
        } catch (e) {
          errorMessage = 'Server error (${response.statusCode}): ${response.body.isEmpty ? "Empty response" : response.body}';
        }
        
        return {
          'success': false,
          'message': errorMessage,
          'statusCode': response.statusCode,
        };
      }
    } catch (e, stackTrace) {
      print('[TRANSACTION SERVICE] Exception: $e');
      print('[TRANSACTION SERVICE] Stack trace: $stackTrace');
      return {
        'success': false,
        'message': 'Error creating income: $e',
      };
    }
  }

  // Create expense transaction
  Future<Map<String, dynamic>> createExpense(String token, Map<String, dynamic> data) async {
    try {
      print('[TRANSACTION SERVICE] Creating expense...');
      print('[TRANSACTION SERVICE] Original data: ${jsonEncode(data)}');
      
      // Validate items array
      if (data['items'] == null || (data['items'] as List).isEmpty) {
        return {
          'success': false,
          'message': 'No items provided',
        };
      }
      
      final items = data['items'] as List;
      final firstItem = items[0] as Map<String, dynamic>;
      
      // Extract and validate date
      final transactionDate = data['transaction_date']?.toString().split('T')[0] ?? '';
      print('[TRANSACTION SERVICE] Transaction date extracted: $transactionDate');
      
      // Transform data to match backend API
      final transformedData = {
        'rbw_id': data['house_id']?.toString(), // Convert house_id to rbw_id
        'date': transactionDate, // YYYY-MM-DD format
        'category_id': data['category_id']?.toString(),
        'qty': (firstItem['quantity'] as num), // Keep as num (int or double)
        'unit_price': (firstItem['price'] as num), // Keep as num (int or double)
        'note': data['description']?.toString() ?? '',
      };
      
      print('[TRANSACTION SERVICE] URL: ${ApiConstants.apiBaseUrl}/transactions');
      print('[TRANSACTION SERVICE] Transformed data: ${jsonEncode(transformedData)}');
      print('[TRANSACTION SERVICE] Data types: rbw_id=${transformedData['rbw_id'].runtimeType}, date=${transformedData['date'].runtimeType}, category_id=${transformedData['category_id'].runtimeType}, qty=${transformedData['qty'].runtimeType}, unit_price=${transformedData['unit_price'].runtimeType}');
      
      final response = await http.post(
        Uri.parse('${ApiConstants.apiBaseUrl}/transactions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(transformedData),
      );

      print('[TRANSACTION SERVICE] Response status: ${response.statusCode}');
      print('[TRANSACTION SERVICE] Response body: ${response.body}');
      print('[TRANSACTION SERVICE] Response headers: ${response.headers}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'data': responseData['data'] ?? responseData, // Handle both wrapped and unwrapped responses
        };
      } else {
        // Try to parse error message from response
        String errorMessage = 'Failed to create expense';
        try {
          if (response.body.isNotEmpty) {
            final errorData = jsonDecode(response.body);
            errorMessage = errorData['error']?['message'] ?? errorData['message'] ?? response.body;
          } else {
            errorMessage = 'Server error (${response.statusCode}): ${response.reasonPhrase ?? "No response body"}';
          }
        } catch (e) {
          errorMessage = 'Server error (${response.statusCode}): ${response.body.isEmpty ? "Empty response" : response.body}';
        }
        
        return {
          'success': false,
          'message': errorMessage,
          'statusCode': response.statusCode,
        };
      }
    } catch (e, stackTrace) {
      print('[TRANSACTION SERVICE] Exception: $e');
      print('[TRANSACTION SERVICE] Stack trace: $stackTrace');
      return {
        'success': false,
        'message': 'Error creating expense: $e',
      };
    }
  }

  // Get all transactions (income and expenses)
  Future<List<dynamic>> getAll(String token, {int? month, int? year, String? houseId}) async {
    try {
      // According to API docs, use /rbw/{rbw_id}/transactions when houseId is provided
      String url;
      List<String> params = [];
      
      if (houseId != null && houseId.isNotEmpty) {
        // Use RBW-specific endpoint
        url = '${ApiConstants.apiBaseUrl}/rbw/$houseId/transactions';
        
        // Build date range filter from month/year
        if (year != null && month != null) {
          // Calculate from and to dates
          final from = DateTime(year, month, 1);
          final to = DateTime(year, month + 1, 0); // Last day of month
          params.add('from=${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}');
          params.add('to=${to.year}-${to.month.toString().padLeft(2, '0')}-${to.day.toString().padLeft(2, '0')}');
        }
      } else {
        // Fallback to general endpoint (may not work for farmers)
        url = '${ApiConstants.apiBaseUrl}/transactions';
        if (month != null) params.add('month=$month');
        if (year != null) params.add('year=$year');
      }
      
      if (params.isNotEmpty) {
        url += '?${params.join('&')}';
      }

      print('[TRANSACTION SERVICE] Fetching from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('Transaction API timeout - endpoint may not exist yet');
          throw Exception('Request timeout');
        },
      );

      print('[TRANSACTION SERVICE] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Handle different response formats
        List<dynamic> transactions = [];
        if (data is List) {
          transactions = data;
        } else if (data is Map) {
          if (data['data'] != null) {
            if (data['data'] is List) {
              transactions = data['data'] as List;
            } else if (data['data'] is Map && data['data']['data'] != null) {
              // Nested data structure: {data: {data: [...], total: x}}
              transactions = data['data']['data'] as List;
            }
          }
        }
        
        print('[TRANSACTION SERVICE] Loaded ${transactions.length} transactions');
        return transactions;
      } else if (response.statusCode == 404) {
        print('[TRANSACTION SERVICE] Transaction endpoint not found (404)');
        return [];
      } else if (response.statusCode == 405) {
        print('[TRANSACTION SERVICE] Method not allowed (405) - wrong endpoint');
        return [];
      } else {
        print('[TRANSACTION SERVICE] Failed to load transactions: ${response.statusCode}');
        print('[TRANSACTION SERVICE] Response: ${response.body}');
        return [];
      }
    } catch (e) {
      print('[TRANSACTION SERVICE] Error loading transactions: $e');
      return [];
    }
  }

  // Get transaction by ID
  Future<Map<String, dynamic>?> getById(String token, String id) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.apiBaseUrl}/transactions/$id'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Error loading transaction: $e');
      return null;
    }
  }

  // Delete transaction
  Future<Map<String, dynamic>> delete(String token, String id) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConstants.apiBaseUrl}/transactions/$id'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return {
          'success': true,
          'message': 'Transaction deleted successfully',
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to delete transaction: ${response.body}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error deleting transaction: $e',
      };
    }
  }

  // Update transaction
  Future<Map<String, dynamic>> update(String token, String id, Map<String, dynamic> data) async {
    try {
      print('[TRANSACTION SERVICE] Updating transaction $id...');
      print('[TRANSACTION SERVICE] Update data: ${jsonEncode(data)}');
      
      // Validate items array
      if (data['items'] == null || (data['items'] as List).isEmpty) {
        return {
          'success': false,
          'message': 'No items provided',
        };
      }
      
      final items = data['items'] as List;
      final firstItem = items[0] as Map<String, dynamic>;
      
      // Extract and validate date
      final transactionDate = data['transaction_date']?.toString().split('T')[0] ?? '';
      print('[TRANSACTION SERVICE] Transaction date extracted: $transactionDate');
      
      // Transform data to match backend API
      final transformedData = {
        'rbw_id': data['house_id']?.toString(),
        'date': transactionDate,
        'category_id': data['category_id']?.toString(),
        'qty': (firstItem['quantity'] as num),
        'unit_price': (firstItem['price'] as num),
        'note': data['description']?.toString() ?? '',
      };
      
      print('[TRANSACTION SERVICE] Transformed update data: ${jsonEncode(transformedData)}');
      
      final response = await http.put(
        Uri.parse('${ApiConstants.apiBaseUrl}/transactions/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(transformedData),
      );

      print('[TRANSACTION SERVICE] Update response status: ${response.statusCode}');
      print('[TRANSACTION SERVICE] Update response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'data': responseData['data'] ?? responseData,
        };
      } else {
        String errorMessage = 'Failed to update transaction';
        try {
          if (response.body.isNotEmpty) {
            final errorData = jsonDecode(response.body);
            errorMessage = errorData['error']?['message'] ?? errorData['message'] ?? response.body;
          } else {
            errorMessage = 'Server error (${response.statusCode}): ${response.reasonPhrase ?? "No response body"}';
          }
        } catch (e) {
          errorMessage = 'Server error (${response.statusCode}): ${response.body.isEmpty ? "Empty response" : response.body}';
        }
        
        return {
          'success': false,
          'message': errorMessage,
          'statusCode': response.statusCode,
        };
      }
    } catch (e, stackTrace) {
      print('[TRANSACTION SERVICE] Exception in update: $e');
      print('[TRANSACTION SERVICE] Stack trace: $stackTrace');
      return {
        'success': false,
        'message': 'Error updating transaction: $e',
      };
    }
  }

  // Get summary (total income, expense, profit)
  Future<Map<String, dynamic>> getSummary(String token, {int? month, int? year, String? houseId}) async {
    try {
      String url = '${ApiConstants.apiBaseUrl}/transactions/summary';
      List<String> params = [];
      
      if (month != null) params.add('month=$month');
      if (year != null) params.add('year=$year');
      if (houseId != null) params.add('house_id=$houseId');
      
      if (params.isNotEmpty) {
        url += '?${params.join('&')}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'total_income': 0.0,
          'total_expense': 0.0,
          'net_profit': 0.0,
        };
      }
    } catch (e) {
      print('Error loading transaction summary: $e');
      return {
        'total_income': 0.0,
        'total_expense': 0.0,
        'net_profit': 0.0,
      };
    }
  }
}
