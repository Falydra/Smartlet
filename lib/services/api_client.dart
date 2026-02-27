import 'dart:convert';
import 'dart:io';
import 'dart:async' as async;
import 'package:http/http.dart' as http;
import 'api_constants.dart';


class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic response;

  ApiException(this.message, {this.statusCode, this.response});

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}

class RequestTimeoutException implements Exception {
  final String message;
  RequestTimeoutException(this.message);

  @override
  String toString() => 'RequestTimeoutException: $message';
}


class ApiClient {
  static const Duration _timeout = Duration(seconds: ApiConstants.defaultTimeout);
  static const Duration _uploadTimeout = Duration(seconds: ApiConstants.uploadTimeout);


  static Future<dynamic> get(
    String url, {
    Map<String, String>? headers,
    Map<String, String>? queryParams,
  }) async {
    try {
      Uri uri = Uri.parse(url);
      if (queryParams != null) {
        uri = uri.replace(queryParameters: queryParams);
      }

      final response = await http
          .get(uri, headers: headers)
          .timeout(_timeout);

      return _handleResponse(response);
    } on SocketException {
      throw NetworkException(ApiConstants.networkError);
    } on http.ClientException {
      throw NetworkException(ApiConstants.networkError);
    } on async.TimeoutException {
      throw RequestTimeoutException(ApiConstants.timeoutError);
    }
  }


  static Future<dynamic> post(
    String url, {
    Map<String, String>? headers,
    dynamic body,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: headers ?? ApiConstants.jsonHeaders,
            body: body is String ? body : jsonEncode(body),
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } on SocketException {
      throw NetworkException(ApiConstants.networkError);
    } on http.ClientException {
      throw NetworkException(ApiConstants.networkError);
    } on async.TimeoutException {
      throw RequestTimeoutException(ApiConstants.timeoutError);
    }
  }


  static Future<dynamic> put(
    String url, {
    Map<String, String>? headers,
    dynamic body,
  }) async {
    try {
      final response = await http
          .put(
            Uri.parse(url),
            headers: headers ?? ApiConstants.jsonHeaders,
            body: body is String ? body : jsonEncode(body),
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } on SocketException {
      throw NetworkException(ApiConstants.networkError);
    } on http.ClientException {
      throw NetworkException(ApiConstants.networkError);
    } on async.TimeoutException {
      throw RequestTimeoutException(ApiConstants.timeoutError);
    }
  }


  static Future<dynamic> patch(
    String url, {
    Map<String, String>? headers,
    dynamic body,
  }) async {
    try {
      final response = await http
          .patch(
            Uri.parse(url),
            headers: headers ?? ApiConstants.jsonHeaders,
            body: body is String ? body : jsonEncode(body),
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } on SocketException {
      throw NetworkException(ApiConstants.networkError);
    } on http.ClientException {
      throw NetworkException(ApiConstants.networkError);
    } on async.TimeoutException {
      throw RequestTimeoutException(ApiConstants.timeoutError);
    }
  }


  static Future<dynamic> delete(
    String url, {
    Map<String, String>? headers,
    dynamic body,
  }) async {
    try {
      final response = await http
          .delete(
            Uri.parse(url),
            headers: headers,
            body: body is String ? body : (body != null ? jsonEncode(body) : null),
          )
          .timeout(_timeout);

      return _handleResponse(response);
    } on SocketException {
      throw NetworkException(ApiConstants.networkError);
    } on http.ClientException {
      throw NetworkException(ApiConstants.networkError);
    } on async.TimeoutException {
      throw RequestTimeoutException(ApiConstants.timeoutError);
    }
  }


  static Future<dynamic> multipartRequest(
    String url,
    String method, {
    Map<String, String>? headers,
    Map<String, String>? fields,
    List<http.MultipartFile>? files,
  }) async {
    try {
      final request = http.MultipartRequest(method, Uri.parse(url));
      
      if (headers != null) {
        request.headers.addAll(headers);
      }
      
      if (fields != null) {
        request.fields.addAll(fields);
      }
      
      if (files != null) {
        request.files.addAll(files);
      }

      final streamedResponse = await request.send().timeout(_uploadTimeout);
      final response = await http.Response.fromStream(streamedResponse);
      
      return _handleResponse(response);
    } on SocketException {
      throw NetworkException(ApiConstants.networkError);
    } on http.ClientException {
      throw NetworkException(ApiConstants.networkError);
    } on async.TimeoutException {
      throw RequestTimeoutException(ApiConstants.timeoutError);
    }
  }


  static dynamic _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    
    try {
      final decodedBody = jsonDecode(response.body);
      
      if (statusCode >= 200 && statusCode < 300) {
        return decodedBody;
      } else {
        throw ApiException(
          decodedBody['message'] ?? 'API Error',
          statusCode: statusCode,
          response: decodedBody,
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      

      if (statusCode >= 200 && statusCode < 300) {
        return {'success': true, 'data': response.body};
      } else {
        throw ApiException(
          'HTTP $statusCode: ${response.reasonPhrase ?? 'Unknown error'}',
          statusCode: statusCode,
          response: response.body,
        );
      }
    }
  }


  static Map<String, String> buildQueryParams(Map<String, dynamic> params) {
    final queryParams = <String, String>{};
    params.forEach((key, value) {
      if (value != null) {
        queryParams[key] = value.toString();
      }
    });
    return queryParams;
  }


  static bool isValidImageFile(File file, {int? maxSizeBytes}) {

    final fileSize = file.lengthSync();
    final maxSize = maxSizeBytes ?? ApiConstants.maxFileSize;
    
    if (fileSize > maxSize) {
      return false;
    }


    final fileName = file.path.toLowerCase();
    return fileName.endsWith('.jpg') ||
           fileName.endsWith('.jpeg') ||
           fileName.endsWith('.png') ||
           fileName.endsWith('.gif') ||
           fileName.endsWith('.webp');
  }
}