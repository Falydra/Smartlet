import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_constants.dart';

class RequestService {
  final String baseUrl = ApiConstants.apiBaseUrl;






  Future<List<dynamic>> getInstallationRequests(String token, {int limit = 50, int offset = 0}) async {
    final queryParams = {
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    final uri = Uri.parse(ApiConstants.installationRequests).replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: ApiConstants.authHeadersOnly(token));
    return jsonDecode(response.body)['data'];
  }


  Future<Map<String, dynamic>> getInstallationRequestById(String token, int id) async {
    final response = await http.get(Uri.parse("${ApiConstants.installationRequests}/$id"), headers: ApiConstants.authHeadersOnly(token));
    return jsonDecode(response.body);
  }


  Future<Map<String, dynamic>> createInstallationRequest(String token, Map<String, dynamic> payload) async {
    final response = await http.post(Uri.parse(ApiConstants.installationRequests), headers: ApiConstants.authHeaders(token), body: jsonEncode(payload));
    return jsonDecode(response.body);
  }


  Future<Map<String, dynamic>> updateInstallationRequest(String token, int id, Map<String, dynamic> payload) async {
    final response = await http.put(Uri.parse("${ApiConstants.installationRequests}/$id"), headers: ApiConstants.authHeaders(token), body: jsonEncode(payload));
    return jsonDecode(response.body);
  }


  Future<Map<String, dynamic>> updateInstallationRequestStatus(String token, int id, Map<String, dynamic> payload) async {
    final response = await http.patch(Uri.parse("${ApiConstants.installationRequests}/$id/status"), headers: ApiConstants.authHeaders(token), body: jsonEncode(payload));
    return jsonDecode(response.body);
  }


  Future<Map<String, dynamic>> deleteInstallationRequest(String token, int id) async {
    final response = await http.delete(Uri.parse("${ApiConstants.installationRequests}/$id"), headers: ApiConstants.authHeadersOnly(token));
    return jsonDecode(response.body);
  }






  Future<List<dynamic>> getMaintenanceRequests(String token, {int limit = 50, int offset = 0}) async {
    final queryParams = {
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    final uri = Uri.parse(ApiConstants.maintenanceRequests).replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: ApiConstants.authHeadersOnly(token));
    return jsonDecode(response.body)['data'];
  }


  Future<Map<String, dynamic>> getMaintenanceRequestById(String token, int id) async {
    final response = await http.get(Uri.parse("${ApiConstants.maintenanceRequests}/$id"), headers: ApiConstants.authHeadersOnly(token));
    return jsonDecode(response.body);
  }


  Future<Map<String, dynamic>> createMaintenanceRequest(String token, Map<String, dynamic> payload) async {
    final response = await http.post(Uri.parse(ApiConstants.maintenanceRequests), headers: ApiConstants.authHeaders(token), body: jsonEncode(payload));
    return jsonDecode(response.body);
  }


  Future<Map<String, dynamic>> updateMaintenanceRequest(String token, int id, Map<String, dynamic> payload) async {
    final response = await http.put(Uri.parse("${ApiConstants.maintenanceRequests}/$id"), headers: ApiConstants.authHeaders(token), body: jsonEncode(payload));
    return jsonDecode(response.body);
  }


  Future<Map<String, dynamic>> updateMaintenanceRequestStatus(String token, int id, Map<String, dynamic> payload) async {
    final response = await http.patch(Uri.parse("${ApiConstants.maintenanceRequests}/$id/status"), headers: ApiConstants.authHeaders(token), body: jsonEncode(payload));
    return jsonDecode(response.body);
  }


  Future<Map<String, dynamic>> deleteMaintenanceRequest(String token, int id) async {
    final response = await http.delete(Uri.parse("${ApiConstants.maintenanceRequests}/$id"), headers: ApiConstants.authHeadersOnly(token));
    return jsonDecode(response.body);
  }






  Future<List<dynamic>> getUninstallationRequests(String token, {int limit = 50, int offset = 0}) async {
    final queryParams = {
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    final uri = Uri.parse(ApiConstants.uninstallationRequests).replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: ApiConstants.authHeadersOnly(token));
    return jsonDecode(response.body)['data'];
  }


  Future<Map<String, dynamic>> getUninstallationRequestById(String token, int id) async {
    final response = await http.get(Uri.parse("${ApiConstants.uninstallationRequests}/$id"), headers: ApiConstants.authHeadersOnly(token));
    return jsonDecode(response.body);
  }


  Future<Map<String, dynamic>> createUninstallationRequest(String token, Map<String, dynamic> payload) async {
    final response = await http.post(Uri.parse(ApiConstants.uninstallationRequests), headers: ApiConstants.authHeaders(token), body: jsonEncode(payload));
    return jsonDecode(response.body);
  }


  Future<Map<String, dynamic>> updateUninstallationRequest(String token, int id, Map<String, dynamic> payload) async {
    final response = await http.put(Uri.parse("${ApiConstants.uninstallationRequests}/$id"), headers: ApiConstants.authHeaders(token), body: jsonEncode(payload));
    return jsonDecode(response.body);
  }


  Future<Map<String, dynamic>> updateUninstallationRequestStatus(String token, int id, Map<String, dynamic> payload) async {
    final response = await http.patch(Uri.parse("${ApiConstants.uninstallationRequests}/$id/status"), headers: ApiConstants.authHeaders(token), body: jsonEncode(payload));
    return jsonDecode(response.body);
  }


  Future<Map<String, dynamic>> deleteUninstallationRequest(String token, int id) async {
    final response = await http.delete(Uri.parse("${ApiConstants.uninstallationRequests}/$id"), headers: ApiConstants.authHeadersOnly(token));
    return jsonDecode(response.body);
  }






  Future<Map<String, dynamic>> getRequestAnalytics(String token) async {
    final response = await http.get(Uri.parse(ApiConstants.requestAnalytics), headers: ApiConstants.authHeadersOnly(token));
    return jsonDecode(response.body);
  }


  Future<Map<String, dynamic>> getTechnicianWorkload(String token, int technicianId) async {
    final response = await http.get(Uri.parse("${ApiConstants.requestAnalytics}/technician-workload/$technicianId"), headers: ApiConstants.authHeadersOnly(token));
    return jsonDecode(response.body);
  }
}
