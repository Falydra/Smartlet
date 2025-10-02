import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class FileService {
  final String baseUrl = "https://api.fuadfakhruz.id/api/v1/files";

  // Upload profile image
  Future<Map<String, dynamic>> uploadProfileImage(String token, File file) async {
    final request = http.MultipartRequest("POST", Uri.parse("$baseUrl/profile-image"));
    request.headers["Authorization"] = "Bearer $token";
    request.files.add(await http.MultipartFile.fromPath("file", file.path));
    final response = await request.send();
    final body = await response.stream.bytesToString();
    return jsonDecode(body);
  }

  // Upload harvest image
  Future<Map<String, dynamic>> uploadHarvestImage(String token, File file, {int? harvestId}) async {
    final request = http.MultipartRequest("POST", Uri.parse("$baseUrl/harvest-image"));
    request.headers["Authorization"] = "Bearer $token";
    request.files.add(await http.MultipartFile.fromPath("file", file.path));
    
    if (harvestId != null) {
      request.fields["harvest_id"] = harvestId.toString();
    }
    
    final response = await request.send();
    final body = await response.stream.bytesToString();
    return jsonDecode(body);
  }

  // Upload generic file
  Future<Map<String, dynamic>> uploadFile(String token, File file, {
    String? category,
    String? description,
  }) async {
    final request = http.MultipartRequest("POST", Uri.parse("$baseUrl/upload"));
    request.headers["Authorization"] = "Bearer $token";
    request.files.add(await http.MultipartFile.fromPath("file", file.path));
    
    if (category != null) {
      request.fields["category"] = category;
    }
    
    if (description != null) {
      request.fields["description"] = description;
    }
    
    final response = await request.send();
    final body = await response.stream.bytesToString();
    return jsonDecode(body);
  }

  // Delete file
  Future<Map<String, dynamic>> deleteFile(String token, String fileUrl) async {
    final response = await http.delete(
      Uri.parse("$baseUrl/delete"),
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json"
      },
      body: jsonEncode({"file_url": fileUrl}),
    );
    return jsonDecode(response.body);
  }

  // Get presigned URL for direct upload
  Future<Map<String, dynamic>> getPresignedUrl(String token, {
    required String objectName,
    int expires = 3600,
  }) async {
    final queryParams = {
      'object_name': objectName,
      'expires': expires.toString(),
    };
    final uri = Uri.parse("$baseUrl/presigned-url").replace(queryParameters: queryParams);
    
    final response = await http.get(
      uri,
      headers: {"Authorization": "Bearer $token"},
    );
    return jsonDecode(response.body);
  }
}
