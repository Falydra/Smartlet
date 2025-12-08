class ApiConstants {
  // Base
  static const String baseUrl = "https://api.zacht.space";
  static const String apiVersion = "v1";
  static const String apiBaseUrl = "$baseUrl/api/$apiVersion";

  // Core Auth & Users
  static const String authLogin = "$apiBaseUrl/auth/login"; // POST
  static const String authRegister = "$apiBaseUrl/auth/register"; // POST
  static const String authProfile = "$apiBaseUrl/auth/profile"; // GET/PATCH (alias: /users/me)
  static const String usersMe = "$apiBaseUrl/users/me"; // GET/PATCH
  static const String authChangePassword = "$apiBaseUrl/auth/change-password"; // POST
  // Missing definitions used across app
  static const String users = "$apiBaseUrl/users"; // GET list, POST create (admin) – used for technician listing
  static const String authRefresh = "$apiBaseUrl/auth/refresh"; // POST
  static const String authValidate = "$apiBaseUrl/auth/validate"; // POST
  static const String authLogout = "$apiBaseUrl/auth/logout"; // POST

  // Health readiness / liveness (backward compatibility)
  static const String ready = "$baseUrl/health/ready"; // GET
  static const String live = "$baseUrl/health/live"; // GET

  // Legacy service request category endpoints (mapped to new service-requests for backward compatibility)
  static const String installationRequests = "$apiBaseUrl/service-requests/installation"; // CRUD (alias)
  static const String maintenanceRequests = "$apiBaseUrl/service-requests/maintenance"; // CRUD (alias)
  static const String uninstallationRequests = "$apiBaseUrl/service-requests/uninstallation"; // CRUD (alias)
  static const String requestAnalytics = "$apiBaseUrl/service-requests/analytics"; // GET analytics

  // Timeouts & file size limits (legacy compatibility)
  static const int defaultTimeout = 30; // seconds
  static const int uploadTimeout = 120; // seconds
  static const int maxFileSize = 50 * 1024 * 1024; // 50 MB generic max

  // File upload endpoints (aliases to new upload structure)
  static const String fileProfileImage = userAvatar; // backward compatibility
  static const String fileHarvestImage = "$apiBaseUrl/uploads/harvests/photos"; // POST multipart
  static const String fileUpload = "$apiBaseUrl/uploads/files"; // generic file upload
  static const String filePresignedUrl = fileUrl; // alias for presigned retrieval

  // Health
  static const String health = "$baseUrl/health";

  // RBW (Swiftlet Houses)
  static const String rbw = "$apiBaseUrl/rbw"; // CRUD + nested resources

  // Nodes & Sensors
  static const String nodes = "$apiBaseUrl/nodes"; // standalone node operations
  static const String sensors = "$apiBaseUrl/sensors"; // standalone sensor operations

  // Sensor Readings (Telemetry)
  static String sensorReadings(String sensorId) => "$apiBaseUrl/sensors/$sensorId/readings"; // POST/GET
  static String sensorLatest(String sensorId) => "$apiBaseUrl/sensors/$sensorId/readings/latest"; // GET
  static String sensorAnomalies(String sensorId) => "$apiBaseUrl/sensors/$sensorId/readings/anomalies"; // GET

  // Alerts
  static const String alerts = "$apiBaseUrl/alerts"; // CRUD

  // Service Requests
  static const String serviceRequests = "$apiBaseUrl/service-requests"; // CRUD + /my-tasks + /{id}/assign + /{id}/status

  // Harvests
  static const String harvests = "$apiBaseUrl/harvests"; // CRUD + stats via /rbw/{id}/harvests/stats

  // Uploads (File Management)
  static const String uploads = "$apiBaseUrl/uploads"; // base prefix
  static String rbwPhoto(String rbwId) => "$apiBaseUrl/uploads/rbw/$rbwId/photos"; // POST multipart
  static const String userAvatar = "$apiBaseUrl/uploads/users/me/avatar"; // POST multipart
  static String serviceRequestAttachment(String id) => "$apiBaseUrl/uploads/service-requests/$id/attachments"; // POST multipart
  static const String fileUrl = "$apiBaseUrl/uploads/files/url"; // GET presigned
  static const String fileDelete = "$apiBaseUrl/uploads/files"; // DELETE ?path=...

  // Standard headers
  static const Map<String, String> jsonHeaders = {"Content-Type": "application/json"};
  static Map<String, String> authHeaders(String token) => {"Authorization": "Bearer $token", "Content-Type": "application/json"};
  static Map<String, String> authHeadersOnly(String token) => {"Authorization": "Bearer $token"};

  // HTTP Status Codes
  static const int statusOk = 200;
  static const int statusCreated = 201;
  static const int statusNoContent = 204;
  static const int statusBadRequest = 400;
  static const int statusUnauthorized = 401;
  static const int statusForbidden = 403;
  static const int statusNotFound = 404;
  static const int statusConflict = 409;
  static const int statusInternalServerError = 500;

  // Pagination defaults (API docs use page/per_page; keep generic defaults)
  static const int defaultPerPage = 20;
  static const int maxPerPage = 100;

  // File limits (from docs)
  static const int maxRbwPhotoSize = 10 * 1024 * 1024; // 10MB
  static const int maxAvatarSize = 2 * 1024 * 1024; // 2MB
  static const int maxServiceAttachmentSize = 20 * 1024 * 1024; // 20MB

  static const List<String> allowedImageTypes = [
    'image/jpeg',
    'image/png',
    'image/webp'
  ];
  static const List<String> allowedAttachmentTypes = [
    'image/jpeg',
    'image/png',
    'image/webp',
    'application/pdf'
  ];

  // Common error messages
  static const String networkError = "Network error occurred";
  static const String timeoutError = "Request timeout";
  static const String unauthorizedError = "Unauthorized access";
  static const String forbiddenError = "Forbidden";
  static const String notFoundError = "Resource not found";
  static const String conflictError = "Conflict";
  static const String serverError = "Server error occurred";
}