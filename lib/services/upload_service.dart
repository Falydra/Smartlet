import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_constants.dart';


class UploadService {
 
  Future<Map<String, dynamic>> uploadAvatar({
    required String token,
    required File file,
  }) async {
    try {
      print('[UPLOAD SERVICE] POST ${ApiConstants.uploadAvatar}');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConstants.uploadAvatar),
      );

      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('[UPLOAD SERVICE] Status: ${response.statusCode}');
      print('[UPLOAD SERVICE] Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'data': responseData['data'] ?? responseData,
          'url': responseData['data']?['url'] ?? responseData['url'],
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
      print('[UPLOAD SERVICE] Exception: $e');
      return {
        'success': false,
        'message': 'Error uploading avatar: $e',
      };
    }
  }











  Future<Map<String, dynamic>> uploadRbwPhoto({
    required String token,
    required String rbwId,
    required File file,
  }) async {
    try {
      final url = ApiConstants.uploadRbwPhoto(rbwId);
      print('[UPLOAD SERVICE] POST $url');

      var request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('[UPLOAD SERVICE] Status: ${response.statusCode}');
      print('[UPLOAD SERVICE] Response: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'data': responseData['data'] ?? responseData,
          'url': responseData['data']?['url'] ?? responseData['url'],
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
      print('[UPLOAD SERVICE] Exception: $e');
      return {
        'success': false,
        'message': 'Error uploading RBW photo: $e',
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
}
