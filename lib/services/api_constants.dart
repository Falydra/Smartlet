class ApiConstants {

  static const String baseUrl = "https://api.swiftlead.fuadfakhruz.com";
  static const String apiVersion = "v1";
  static const String apiBaseUrl = "$baseUrl/api/$apiVersion";




  static const String authLogin = "$apiBaseUrl/auth/login"; // POST
  static const String authRegister = "$apiBaseUrl/auth/register"; // POST (public)
  static const String authChangePassword = "$apiBaseUrl/auth/change-password"; // POST
  static const String authForgotPassword = "$apiBaseUrl/auth/forgot-password"; // POST (admin)




  static const String usersMe = "$apiBaseUrl/users/me"; // GET/PATCH
  static const String users = "$apiBaseUrl/users"; // GET list (admin), POST create (admin)
  

  static const String authProfile = usersMe; // GET/PATCH (alias: /users/me)




  static const String rbw = "$apiBaseUrl/rbw"; // GET list, POST create
  static String rbwDetail(String rbwId) => "$apiBaseUrl/rbw/$rbwId"; // GET/PATCH/DELETE
  static String rbwNodes(String rbwId) => "$apiBaseUrl/rbw/$rbwId/nodes"; // GET list, POST create
  static String rbwAlerts(String rbwId) => "$apiBaseUrl/rbw/$rbwId/alerts"; // GET list
  static String rbwHarvests(String rbwId) => "$apiBaseUrl/rbw/$rbwId/harvests"; // GET list
  static String rbwTransactions(String rbwId) => "$apiBaseUrl/rbw/$rbwId/transactions"; // GET list




  static const String nodes = "$apiBaseUrl/nodes"; // Base for standalone operations
  static String nodeDetail(String nodeId) => "$apiBaseUrl/nodes/$nodeId"; // GET/PATCH/DELETE
  static String nodeSensors(String nodeId) => "$apiBaseUrl/nodes/$nodeId/sensors"; // GET list, POST create
  static String nodeAudio(String nodeId) => "$apiBaseUrl/nodes/$nodeId/audio"; // GET state, PATCH control
  static String nodePump(String nodeId) => "$apiBaseUrl/nodes/$nodeId/pump"; // PATCH control




  static const String sensors = "$apiBaseUrl/sensors"; // Base
  static String sensorDetail(String sensorId) => "$apiBaseUrl/sensors/$sensorId"; // GET/PATCH
  static String sensorReadings(String sensorId) => "$apiBaseUrl/sensors/$sensorId/readings"; // POST create, GET list
  static String sensorTrend(String sensorId) => "$apiBaseUrl/sensors/$sensorId/trend"; // GET
  static String sensorLatest(String sensorId) => "$apiBaseUrl/sensors/$sensorId/readings?limit=1"; // GET latest reading




  static const String alerts = "$apiBaseUrl/alerts"; // GET list
  static String alertRead(String alertId) => "$apiBaseUrl/alerts/$alertId/read"; // PATCH
  static String alertResolve(String alertId) => "$apiBaseUrl/alerts/$alertId/resolve"; // PATCH




  static const String harvests = "$apiBaseUrl/harvests"; // GET list, POST create
  static const String harvestStats = "$apiBaseUrl/harvests/stats"; // GET
  static String harvestDetail(String harvestId) => "$apiBaseUrl/harvests/$harvestId"; // GET/PATCH/DELETE




  static const String serviceRequests = "$apiBaseUrl/service-requests"; // GET list, POST create
  static String serviceRequestDetail(String id) => "$apiBaseUrl/service-requests/$id"; // GET/PATCH




  static const String transactions = "$apiBaseUrl/transactions"; // POST create
  static String transactionDetail(String id) => "$apiBaseUrl/transactions/$id"; // GET/PATCH/DELETE




  static const String transactionCategories = "$apiBaseUrl/transaction-categories"; // GET list, POST create (admin)
  static String transactionCategoryDetail(String id) => "$apiBaseUrl/transaction-categories/$id"; // PATCH/DELETE (admin)




  static const String financialStatements = "$apiBaseUrl/financial-statements"; // POST generate




  static const String aiHealth = "$apiBaseUrl/ai/health"; // GET
  static const String aiPredictGrade = "$apiBaseUrl/ai/predict-grade"; // POST
  static const String aiPredictPump = "$apiBaseUrl/ai/predict-pump"; // POST
  static const String aiAnalyze = "$apiBaseUrl/ai/analyze"; // POST
  static const String aiAnomalyDetect = "$apiBaseUrl/ai/anomaly-detect"; // POST




  static const String uploadAvatar = "$apiBaseUrl/uploads/avatar"; // POST multipart
  static String uploadRbwPhoto(String rbwId) => "$apiBaseUrl/uploads/rbw/$rbwId/photo"; // POST multipart
  

  static const String uploads = "$apiBaseUrl/uploads";
  static String rbwPhoto(String rbwId) => uploadRbwPhoto(rbwId);
  static const String userAvatar = uploadAvatar;
  static const String fileProfileImage = uploadAvatar;
  static const String fileHarvestImage = "$apiBaseUrl/uploads/harvests/photos"; // Legacy
  static const String fileUpload = "$apiBaseUrl/uploads/files"; // Legacy
  static const String fileDelete = "$apiBaseUrl/uploads/files"; // Legacy
  static const String filePresignedUrl = "$apiBaseUrl/uploads/files/url"; // Legacy
  

  static const String ready = "$baseUrl/health";
  static const String live = "$baseUrl/health";
  

  static const String installationRequests = "$apiBaseUrl/service-requests"; // Legacy
  static const String maintenanceRequests = "$apiBaseUrl/service-requests"; // Legacy
  static const String uninstallationRequests = "$apiBaseUrl/service-requests"; // Legacy
  static const String requestAnalytics = "$apiBaseUrl/service-requests/analytics"; // Legacy




  static const String ws = "$apiBaseUrl/ws"; // WebSocket connection (with ?token=xxx)
  static const String wsStats = "$apiBaseUrl/ws/stats"; // GET




  static const String health = "$baseUrl/health"; // GET
  static const String metrics = "$baseUrl/metrics"; // GET (Prometheus)




  static const Map<String, String> jsonHeaders = {"Content-Type": "application/json"};
  static Map<String, String> authHeaders(String token) => {
    "Authorization": "Bearer $token", 
    "Content-Type": "application/json"
  };
  static Map<String, String> authHeadersOnly(String token) => {
    "Authorization": "Bearer $token"
  };




  static const int statusOk = 200;
  static const int statusCreated = 201;
  static const int statusNoContent = 204;
  static const int statusBadRequest = 400;
  static const int statusUnauthorized = 401;
  static const int statusForbidden = 403;
  static const int statusNotFound = 404;
  static const int statusMethodNotAllowed = 405;
  static const int statusConflict = 409;
  static const int statusValidationError = 422;
  static const int statusInternalServerError = 500;
  static const int statusServiceUnavailable = 503;




  static const int defaultPage = 1;
  static const int defaultLimit = 20;
  static const int maxLimit = 100;




  static const int defaultTimeout = 30; // seconds
  static const int uploadTimeout = 120; // seconds




  static const int maxFileSize = 50 * 1024 * 1024; // 50 MB
  static const int maxAvatarSize = 5 * 1024 * 1024; // 5 MB
  static const int maxRbwPhotoSize = 10 * 1024 * 1024; // 10 MB




  static const String roleAdmin = "admin";
  static const String roleTechnician = "technician";
  static const String roleFarmer = "farmer";




  static const String nodeTypeGateway = "gateway";
  static const String nodeTypeNest = "nest";
  static const String nodeTypeLmb = "lmb";
  static const String nodeTypePump = "pump";




  static const String sensorTypeTemp = "temp";
  static const String sensorTypeHumid = "humid";
  static const String sensorTypeAmmonia = "ammonia";




  static const String transactionTypeIncome = "income";
  static const String transactionTypeExpense = "expense";




  static const String harvestGradeGood = "good";
  static const String harvestGradeMedium = "medium";
  static const String harvestGradePoor = "poor";




  static const String serviceTypeInstallation = "installation";
  static const String serviceTypeMaintenance = "maintenance";
  static const String serviceTypeUninstall = "uninstall";




  static const String serviceStatusDraft = "draft";
  static const String serviceStatusPending = "pending";
  static const String serviceStatusApproved = "approved";
  static const String serviceStatusRejected = "rejected";
  static const String serviceStatusAssigned = "assigned";
  static const String serviceStatusInProgress = "in_progress";
  static const String serviceStatusResolved = "resolved";
  static const String serviceStatusCancelled = "cancelled";




  static const String alertTypeTempHigh = "temp_high";
  static const String alertTypeTempLow = "temp_low";
  static const String alertTypeHumidHigh = "humid_high";
  static const String alertTypeHumidLow = "humid_low";
  static const String alertTypeAmmoniaHigh = "ammonia_high";
  static const String alertTypeNodeOffline = "node_offline";
  static const String alertTypeAiAnomaly = "ai_anomaly";




  static const String audioActionSetLmb = "audio_set_lmb";
  static const String audioActionSetNest = "audio_set_nest";
  static const String audioActionCallBird = "call_bird";




  static const String pumpActionSet = "sprayer_set";




  static const String errorBadRequest = "bad_request";
  static const String errorUnauthorized = "unauthorized";
  static const String errorForbidden = "forbidden";
  static const String errorNotFound = "not_found";
  static const String errorMethodNotAllowed = "method_not_allowed";
  static const String errorConflict = "conflict";
  static const String errorValidation = "validation_error";
  static const String errorInternal = "internal_error";
  static const String errorAiDisabled = "ai_disabled";




  static const String networkError = "Network error occurred";
  static const String timeoutError = "Request timeout";
  static const String unauthorizedError = "Unauthorized access";
  static const String forbiddenError = "Forbidden";
  static const String notFoundError = "Resource not found";
  static const String conflictError = "Resource already exists";
  static const String validationError = "Validation failed";
  static const String serverError = "Internal server error";
  static const String aiDisabledError = "AI Engine is disabled";
}