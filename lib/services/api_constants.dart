class ApiConstants {
  // Base URLs
  static const String baseUrl = "https://api.fuadfakhruz.id";
  static const String apiVersion = "v1";
  static const String apiBaseUrl = "$baseUrl/api/$apiVersion";
  
  // Authentication Endpoints
  static const String authLogin = "$apiBaseUrl/auth/login";
  static const String authRegister = "$apiBaseUrl/auth/register";
  static const String authProfile = "$apiBaseUrl/auth/profile";
  static const String authChangePassword = "$apiBaseUrl/auth/change-password";
  static const String authRefresh = "$apiBaseUrl/auth/refresh";
  static const String authValidate = "$apiBaseUrl/auth/validate";
  static const String authLogout = "$apiBaseUrl/auth/logout";
  
  // Health Check Endpoints
  static const String health = "$baseUrl/health";
  static const String ready = "$baseUrl/ready";
  static const String live = "$baseUrl/live";
  
  // Swiftlet Houses Endpoints
  static const String swiftletHouses = "$apiBaseUrl/swiftlet-houses";
  
  // IoT Devices Endpoints
  static const String iotDevices = "$apiBaseUrl/iot-devices";
  
  // Sensor Data Endpoints
  static const String sensorData = "$apiBaseUrl/sensors/data";
  static const String sensorLatest = "$apiBaseUrl/sensors/latest";
  static const String sensorStatistics = "$apiBaseUrl/sensors/statistics";
  
  // Harvests Endpoints
  static const String harvests = "$apiBaseUrl/harvests";
  static const String harvestsRecent = "$apiBaseUrl/harvests/recent";
  static const String harvestsSummary = "$apiBaseUrl/harvests/summary";
  
  // Market Data Endpoints
  static const String weeklyPrices = "$apiBaseUrl/weekly-prices";
  static const String harvestSales = "$apiBaseUrl/harvest-sales";
  
  // Service Requests Endpoints
  static const String installationRequests = "$apiBaseUrl/installation-requests";
  static const String maintenanceRequests = "$apiBaseUrl/maintenance-requests";
  static const String uninstallationRequests = "$apiBaseUrl/uninstallation-requests";
  static const String requestAnalytics = "$apiBaseUrl/requests/analytics";
  
  // File Management Endpoints
  static const String fileUpload = "$apiBaseUrl/files/upload";
  static const String fileProfileImage = "$apiBaseUrl/files/profile-image";
  static const String fileHarvestImage = "$apiBaseUrl/files/harvest-image";
  static const String fileDelete = "$apiBaseUrl/files/delete";
  static const String filePresignedUrl = "$apiBaseUrl/files/presigned-url";
  
  // Request Headers
  static const Map<String, String> jsonHeaders = {
    "Content-Type": "application/json",
  };
  
  static Map<String, String> authHeaders(String token) => {
    "Authorization": "Bearer $token",
    "Content-Type": "application/json",
  };
  
  static Map<String, String> authHeadersOnly(String token) => {
    "Authorization": "Bearer $token",
  };
  
  // HTTP Status Codes
  static const int statusOk = 200;
  static const int statusCreated = 201;
  static const int statusNoContent = 204;
  static const int statusBadRequest = 400;
  static const int statusUnauthorized = 401;
  static const int statusForbidden = 403;
  static const int statusNotFound = 404;
  static const int statusInternalServerError = 500;
  
  // Default Pagination
  static const int defaultLimit = 50;
  static const int defaultOffset = 0;
  
  // File Upload Limits
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB
  static const List<String> allowedImageTypes = [
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp'
  ];
  
  // Request Timeouts (in seconds)
  static const int defaultTimeout = 30;
  static const int uploadTimeout = 120;
  
  // Error Messages
  static const String networkError = "Network error occurred";
  static const String timeoutError = "Request timeout";
  static const String unauthorizedError = "Unauthorized access";
  static const String serverError = "Server error occurred";
}