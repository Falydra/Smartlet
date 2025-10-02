# Flutter API Services Documentation

## Overview
Comprehensive Flutter API services based on the Swiftlet Management System API. All services are built with proper error handling, type safety, and consistent patterns.

## Architecture

```
lib/services/
├── api_client.dart              # Base HTTP client with error handling
├── api_constants.dart           # API endpoints and configuration
├── api_service_manager.dart     # Centralized service manager
├── auth_services.dart.dart      # Authentication service
├── house_services.dart          # Swiftlet house management
├── devices.services.dart        # IoT device management
├── sensor_services.dart         # Sensor data service
├── harvest_services.dart        # Harvest management
├── market_services.dart         # Market data and sales
├── request_services.dart        # Service requests
├── file_services.dart           # File upload/management
└── health_check_service.dart    # System health monitoring
```

## Usage Examples

### 1. Service Manager (Recommended)
```dart
import 'package:swiftlead/services/api_service_manager.dart';
import 'package:swiftlead/utils/token_manager.dart';

// Check system health before using services
final isHealthy = await ApiServiceManager.isSystemReady();
if (!isHealthy) {
  // Handle system unavailability
  return;
}

// Get authentication token
final token = await TokenManager.getToken();
if (token == null) {
  // Handle unauthenticated state
  return;
}

// Use services through the manager
final houses = await ApiServiceManager.house.getAll(token);
final devices = await ApiServiceManager.device.getAll(token);
final harvests = await ApiServiceManager.harvest.getAll(token);
```

### 2. Direct Service Usage
```dart
import 'package:swiftlead/services/auth_services.dart.dart';

final authService = AuthService();

// Login
final loginResponse = await authService.login(email, password);
if (loginResponse['success'] == true) {
  final token = loginResponse['data']['token'];
  final user = loginResponse['data']['user'];
  // Store token and user data
}
```

## Service Details

### 1. Authentication Service (`auth_services.dart.dart`)

**Methods:**
- `login(email, password)` - User authentication
- `register(name, email, password)` - User registration
- `profile(token)` - Get user profile
- `updateProfile(token, data)` - Update profile
- `changePassword(token, current, new)` - Change password
- `refreshToken(token)` - Refresh auth token
- `validateToken(token)` - Validate token
- `logout(token)` - User logout

**Example:**
```dart
final authService = AuthService();
final response = await authService.login('user@example.com', 'password');
```

### 2. House Service (`house_services.dart`)

**Methods:**
- `getAll(token)` - Get all user houses
- `getById(token, id)` - Get house by ID
- `create(token, data)` - Create new house
- `update(token, id, data)` - Update house
- `delete(token, id)` - Delete house

**Example:**
```dart
final houseService = HouseService();
final houses = await houseService.getAll(token);
```

### 3. Device Service (`devices.services.dart`)

**Methods:**
- `getAll(token)` - Get all user devices
- `getById(token, id)` - Get device by ID
- `create(token, data)` - Register new device
- `update(token, id, data)` - Update device
- `updateStatus(token, id, status)` - Update device status
- `delete(token, id)` - Delete device

### 4. Sensor Service (`sensor_services.dart`)

**Methods:**
- `getData(token, options)` - Get sensor data with filters
- `getDataByDateRange(token, installCode, startDate, endDate)` - Get data by date range
- `getLatest(token)` - Get latest sensor readings
- `getStatistics(token)` - Get sensor statistics
- `createData(token, data)` - Create sensor data
- `deleteData(token, id)` - Delete sensor data

### 5. Harvest Service (`harvest_services.dart`)

**Methods:**
- `getAll(token, options)` - Get all harvests
- `getById(token, id)` - Get harvest by ID
- `create(token, data)` - Create harvest record
- `update(token, id, data)` - Update harvest
- `delete(token, id)` - Delete harvest

### 6. Market Service (`market_services.dart`)

**Weekly Prices:**
- `getWeeklyPrices(token, options)` - Get price data
- `getLatestWeeklyPrices(token)` - Get latest prices
- `createWeeklyPrice(token, data)` - Create price entry
- `updateWeeklyPrice(token, id, data)` - Update price
- `deleteWeeklyPrice(token, id)` - Delete price

**Harvest Sales:**
- `getHarvestSales(token, options)` - Get sales data
- `createHarvestSale(token, data)` - Create sale
- `updateHarvestSaleStatus(token, id, status)` - Update sale status
- `getSalesByProvince(token, province)` - Get regional sales
- `getUserSalesTotal(token)` - Get user total sales

### 7. Request Service (`request_services.dart`)

**Installation Requests:**
- `getInstallationRequests(token, options)`
- `createInstallationRequest(token, data)`
- `updateInstallationRequestStatus(token, id, status)`

**Maintenance Requests:**
- `getMaintenanceRequests(token, options)`
- `createMaintenanceRequest(token, data)`
- `updateMaintenanceRequestStatus(token, id, status)`

**Uninstallation Requests:**
- `getUninstallationRequests(token, options)`
- `createUninstallationRequest(token, data)`
- `updateUninstallationRequestStatus(token, id, status)`

**Analytics:**
- `getRequestAnalytics(token)` - Get request analytics
- `getTechnicianWorkload(token, technicianId)` - Get workload data

### 8. File Service (`file_services.dart`)

**Methods:**
- `uploadProfileImage(token, file)` - Upload profile image
- `uploadHarvestImage(token, file, harvestId)` - Upload harvest image
- `uploadFile(token, file, options)` - Upload generic file
- `deleteFile(token, fileUrl)` - Delete file
- `getPresignedUrl(token, objectName, expires)` - Get upload URL

### 9. Health Check Service (`health_check_service.dart`)

**Methods:**
- `healthCheck()` - General health status
- `readinessCheck()` - Service readiness
- `livenessCheck()` - Service liveness
- `isSystemHealthy()` - Comprehensive health check

## Error Handling

All services use consistent error handling through custom exceptions:

```dart
try {
  final data = await ApiServiceManager.house.getAll(token);
  // Handle success
} on ApiException catch (e) {
  // Handle API errors (400, 401, 500, etc.)
  print('API Error: ${e.message} (${e.statusCode})');
} on NetworkException catch (e) {
  // Handle network errors
  print('Network Error: ${e.message}');
} on TimeoutException catch (e) {
  // Handle timeout errors
  print('Timeout Error: ${e.message}');
} catch (e) {
  // Handle unexpected errors
  print('Unexpected Error: $e');
}
```

## Data Models

Data models are available in `lib/models/api_models.dart`:

- `User` - User profile data
- `SwiftletHouse` - House/kandang data
- `IoTDevice` - Device information
- `SensorData` - Sensor readings
- `Harvest` - Harvest records

## Configuration

API configuration is centralized in `api_constants.dart`:

```dart
// Base URLs
static const String baseUrl = "https://api.fuadfakhruz.id";
static const String apiBaseUrl = "$baseUrl/api/v1";

// Default settings
static const int defaultLimit = 50;
static const int defaultTimeout = 30;
static const int maxFileSize = 10 * 1024 * 1024; // 10MB
```

## Best Practices

1. **Always check system health** before making API calls
2. **Handle authentication** properly with token management
3. **Use the service manager** for centralized access
4. **Implement proper error handling** for all API calls
5. **Cache data locally** for offline functionality
6. **Validate file uploads** before sending to server
7. **Use pagination** for large data sets
8. **Implement retry logic** for network failures

## Integration with Existing Code

The services are designed to work seamlessly with existing Flutter code:

```dart
// In your existing pages/widgets
class HomePage extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _loadData(),
      builder: (context, snapshot) {
        // Handle loading, error, and success states
      },
    );
  }

  Future<void> _loadData() async {
    try {
      final token = await TokenManager.getToken();
      if (token != null) {
        final houses = await ApiServiceManager.house.getAll(token);
        final devices = await ApiServiceManager.device.getAll(token);
        // Update UI state
      }
    } catch (e) {
      // Handle errors
    }
  }
}
```

This comprehensive API service implementation provides a robust, scalable foundation for the Flutter app's backend integration.