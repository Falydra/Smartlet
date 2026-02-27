import 'auth_services.dart.dart';
import 'house_services.dart';
import 'sensor_services.dart';
import 'harvest_services.dart';
import 'request_services.dart';
import 'file_services.dart';
import 'health_check_service.dart';


class ApiServiceManager {

  static final AuthService _authService = AuthService();
  static final HouseService _houseService = HouseService();
  static final SensorService _sensorService = SensorService();
  static final HarvestService _harvestService = HarvestService();
  static final RequestService _requestService = RequestService();
  static final FileService _fileService = FileService();
  static final HealthCheckService _healthCheckService = HealthCheckService();


  static AuthService get auth => _authService;
  static HouseService get house => _houseService;
  static SensorService get sensor => _sensorService;
  static HarvestService get harvest => _harvestService;
  static RequestService get request => _requestService;
  static FileService get file => _fileService;
  static HealthCheckService get health => _healthCheckService;


  static Future<bool> isSystemReady() async {
    try {
      return await _healthCheckService.isSystemHealthy();
    } catch (e) {
      return false;
    }
  }


  static Future<Map<String, dynamic>> getSystemStatus() async {
    try {
      final health = await _healthCheckService.healthCheck();
      final ready = await _healthCheckService.readinessCheck();
      final live = await _healthCheckService.livenessCheck();
      
      return {
        'overall': 'healthy',
        'health': health,
        'ready': ready,
        'live': live,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'overall': 'unhealthy',
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }
}


class ApiResponse<T> {
  final bool success;
  final String? message;
  final T? data;
  final Map<String, dynamic>? meta;
  final List<String>? errors;

  ApiResponse({
    required this.success,
    this.message,
    this.data,
    this.meta,
    this.errors,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json, T Function(dynamic)? fromJsonT) {
    return ApiResponse<T>(
      success: json['success'] ?? false,
      message: json['message'],
      data: json['data'] != null && fromJsonT != null ? fromJsonT(json['data']) : json['data'],
      meta: json['meta'],
      errors: json['errors'] != null ? List<String>.from(json['errors']) : null,
    );
  }
}


class PaginationInfo {
  final int limit;
  final int offset;
  final int total;
  final int currentPage;
  final int totalPages;
  final bool hasNext;
  final bool hasPrevious;

  PaginationInfo({
    required this.limit,
    required this.offset,
    required this.total,
    required this.currentPage,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrevious,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      limit: json['limit'] ?? 50,
      offset: json['offset'] ?? 0,
      total: json['total'] ?? 0,
      currentPage: json['current_page'] ?? 1,
      totalPages: json['total_pages'] ?? 1,
      hasNext: json['has_next'] ?? false,
      hasPrevious: json['has_previous'] ?? false,
    );
  }
}


class PaginatedResponse<T> {
  final List<T> data;
  final PaginationInfo pagination;

  PaginatedResponse({
    required this.data,
    required this.pagination,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    final dataList = json['data'] as List? ?? [];
    return PaginatedResponse<T>(
      data: dataList.map((item) => fromJsonT(item)).toList(),
      pagination: PaginationInfo.fromJson(json['meta'] ?? {}),
    );
  }
}