import 'dart:convert';
import 'package:http/http.dart' as http;

class MarketService {
  final String baseUrl = "https://api.fuadfakhruz.id/api/v1";

  // ===================
  // WEEKLY PRICES
  // ===================

  // Get all weekly prices
  Future<List<dynamic>> getWeeklyPrices(String token, {int limit = 50, int offset = 0}) async {
    final queryParams = {
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    final uri = Uri.parse("$baseUrl/weekly-prices").replace(queryParameters: queryParams);
    
    final response = await http.get(
      uri,
      headers: {"Authorization": "Bearer $token"},
    );
    return jsonDecode(response.body)['data'];
  }

  // Get latest weekly prices
  Future<Map<String, dynamic>> getLatestWeeklyPrices(String token) async {
    final response = await http.get(
      Uri.parse("$baseUrl/weekly-prices/latest"),
      headers: {"Authorization": "Bearer $token"},
    );
    return jsonDecode(response.body);
  }

  // Get weekly price by ID
  Future<Map<String, dynamic>> getWeeklyPriceById(String token, int id) async {
    final response = await http.get(
      Uri.parse("$baseUrl/weekly-prices/$id"),
      headers: {"Authorization": "Bearer $token"},
    );
    return jsonDecode(response.body);
  }

  // Create weekly price
  Future<Map<String, dynamic>> createWeeklyPrice(String token, Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse("$baseUrl/weekly-prices"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json"
      },
      body: jsonEncode(payload),
    );
    return jsonDecode(response.body);
  }

  // Update weekly price
  Future<Map<String, dynamic>> updateWeeklyPrice(String token, int id, Map<String, dynamic> payload) async {
    final response = await http.put(
      Uri.parse("$baseUrl/weekly-prices/$id"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json"
      },
      body: jsonEncode(payload),
    );
    return jsonDecode(response.body);
  }

  // Delete weekly price
  Future<Map<String, dynamic>> deleteWeeklyPrice(String token, int id) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/weekly-prices/$id"),
      headers: {"Authorization": "Bearer $token"},
    );
    return jsonDecode(response.body);
  }

  // ===================
  // HARVEST SALES
  // ===================

  // Get all harvest sales
  Future<List<dynamic>> getHarvestSales(String token, {int limit = 50, int offset = 0}) async {
    final queryParams = {
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    final uri = Uri.parse("$baseUrl/harvest-sales").replace(queryParameters: queryParams);
    
    final response = await http.get(
      uri,
      headers: {"Authorization": "Bearer $token"},
    );
    return jsonDecode(response.body)['data'];
  }

  // Get harvest sales by ID
  Future<Map<String, dynamic>> getHarvestSaleById(String token, int id) async {
    final response = await http.get(
      Uri.parse("$baseUrl/harvest-sales/$id"),
      headers: {"Authorization": "Bearer $token"},
    );
    return jsonDecode(response.body);
  }

  // Create harvest sale
  Future<Map<String, dynamic>> createHarvestSale(String token, Map<String, dynamic> payload) async {
    final response = await http.post(
      Uri.parse("$baseUrl/harvest-sales"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json"
      },
      body: jsonEncode(payload),
    );
    return jsonDecode(response.body);
  }

  // Update harvest sale
  Future<Map<String, dynamic>> updateHarvestSale(String token, int id, Map<String, dynamic> payload) async {
    final response = await http.put(
      Uri.parse("$baseUrl/harvest-sales/$id"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json"
      },
      body: jsonEncode(payload),
    );
    return jsonDecode(response.body);
  }

  // Update harvest sale status
  Future<Map<String, dynamic>> updateHarvestSaleStatus(String token, int id, Map<String, dynamic> payload) async {
    final response = await http.patch(
      Uri.parse("$baseUrl/harvest-sales/$id/status"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json"
      },
      body: jsonEncode(payload),
    );
    return jsonDecode(response.body);
  }

  // Delete harvest sale
  Future<Map<String, dynamic>> deleteHarvestSale(String token, int id) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/harvest-sales/$id"),
      headers: {"Authorization": "Bearer $token"},
    );
    return jsonDecode(response.body);
  }

  // Get sales by province
  Future<Map<String, dynamic>> getSalesByProvince(String token, String province) async {
    final response = await http.get(
      Uri.parse("$baseUrl/harvest-sales/province/$province"),
      headers: {"Authorization": "Bearer $token"},
    );
    return jsonDecode(response.body);
  }

  // Get user sales total
  Future<Map<String, dynamic>> getUserSalesTotal(String token) async {
    final response = await http.get(
      Uri.parse("$baseUrl/harvest-sales/user/total"),
      headers: {"Authorization": "Bearer $token"},
    );
    return jsonDecode(response.body);
  }
}
