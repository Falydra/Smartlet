# Home Page and Analysis Page API Integration Enhancement

## Overview
Enhanced the home page and analysis page to fully integrate with API services for house management, device monitoring, and harvest data analysis based on user input.

## Key Improvements

### 1. Home Page Enhancements (`lib/pages/home_page.dart`)

**API Integration for House Data:**
- Enhanced `_loadKandangFromAPI()` to properly load house data from HouseService
- Added device data integration using DeviceService for each house
- Implemented fallback mechanism: API → Local Storage → Default values

**Device Data Integration:**
- Each house now displays real-time device data (temperature, humidity, ammonia, twitter status)
- Device data is loaded from API and linked to specific houses
- Fallback to default device data if API call fails

**Enhanced Data Structure:**
```dart
kandangList.add({
  'id': 'house_${house['id']}',
  'apiId': house['id'],                    // API house ID
  'name': house['name'],                   // House name from API
  'address': house['address'],             // House address from API
  'floors': house['floors'],               // Number of floors from API
  'image': house['image_url'],             // House image from API
  'deviceData': deviceData,                // Real-time device data
  'harvestCycle': harvestCycle,           // Harvest cycle data
  'isFromAPI': true,                      // Flag to indicate API source
});
```

**Real-time Device Display:**
- Temperature, humidity, ammonia levels from actual IoT devices
- Twitter (sound detection) status from device sensors
- Color-coded status indicators (green for active, red for inactive)

### 2. Analysis Page Enhancements (`lib/pages/analysis_alternate_page.dart`)

**House-Specific Analysis:**
- Added `_selectedHouseId` to track which house is being analyzed
- Enhanced `_loadCageData()` to load house data from API
- Analysis now shows data specific to the selected house

**API-Driven Harvest Data:**
- Enhanced `_loadHarvestData()` to filter harvest data by house ID
- Harvest data loaded from HarvestService API
- Date-based filtering (month/year) combined with house filtering

**Improved Data Loading:**
```dart
// Filter harvests for selected month/year and house
for (var harvest in harvests) {
  final harvestDate = DateTime.tryParse(harvest['harvest_date'] ?? '');
  bool isCorrectHouse = _selectedHouseId == null || harvest['house_id'] == _selectedHouseId;
  
  if (harvestDate != null && 
      harvestDate.month == _selectedMonth && 
      harvestDate.year == _selectedYear &&
      isCorrectHouse) {
    // Aggregate harvest data by type
    mangkok += (harvest['mangkok'] as num?)?.toDouble() ?? 0.0;
    sudut += (harvest['sudut'] as num?)?.toDouble() ?? 0.0;
    oval += (harvest['oval'] as num?)?.toDouble() ?? 0.0;
    patahan += (harvest['patahan'] as num?)?.toDouble() ?? 0.0;
  }
}
```

**Enhanced Date Selection:**
- Date picker properly reloads harvest data when date changes
- Shows loading indicator during data refresh
- Maintains user selection state

### 3. Data Flow Integration

**Home to Analysis Navigation:**
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => AnalysisPageAlternate(
      selectedCageId: kandang['id']?.toString() ?? 'kandang_default',
    ),
  ),
);
```

**Analysis Page House Detection:**
```dart
if (widget.selectedCageId != null) {
  final houseId = widget.selectedCageId!.replaceFirst('house_', '');
  selectedHouse = houses.firstWhere(
    (house) => house['id'].toString() == houseId,
    orElse: () => houses.first,
  );
}
```

### 4. API Service Usage

**House Service Integration:**
- `HouseService.getAll()` - Load all user houses
- Real-time house data display with proper fallback

**Device Service Integration:**
- `DeviceService.getAll()` - Load IoT device data
- Device data linked to specific houses
- Real-time monitoring display

**Harvest Service Integration:**
- `HarvestService.getAll()` - Load harvest records
- Filtered by house ID and date range
- Aggregated data for analysis charts

### 5. User Experience Improvements

**Smart Data Loading:**
1. **API First**: Try to load from API services
2. **Local Cache**: Fallback to SharedPreferences
3. **Default Values**: Use static defaults if all else fails

**Real-time Updates:**
- Device data reflects actual IoT sensor readings
- Harvest analysis shows data specific to selected house
- Date selection immediately updates analysis charts

**Seamless Navigation:**
- Home page passes house context to analysis page
- Analysis page loads specific house data automatically
- Maintains user selections across navigation

### 6. Error Handling and Reliability

**Graceful Degradation:**
```dart
try {
  // Try API first
  final houses = await _houseService.getAll(_authToken!);
  // Process API data
} catch (e) {
  print('API failed, falling back to local storage: $e');
  // Fallback to local storage
}
```

**Multi-level Fallback:**
1. API services (real-time data)
2. SharedPreferences (cached data)  
3. Static defaults (always available)

**User Feedback:**
- Loading indicators during API calls
- Error messages for failed operations
- Empty state handling for no data scenarios

## Benefits Achieved

1. **Real-time Monitoring**: Live device data from IoT sensors
2. **House-Specific Analysis**: Harvest data filtered by selected house
3. **Seamless Integration**: API-first approach with reliable fallbacks
4. **Enhanced User Experience**: Smart navigation and data loading
5. **Data Consistency**: Unified data flow from API to UI
6. **Scalability**: Support for multiple houses and devices

## Data Integration Summary

**Home Page Data Flow:**
```
API Services → House Data + Device Data → UI Display → Navigation Context
```

**Analysis Page Data Flow:**
```
House Context → API Harvest Data → Date Filtering → Chart Visualization
```

**Overall Architecture:**
```
User Input → API Services → Data Processing → UI Updates → Navigation
```

This implementation provides a comprehensive, API-driven experience where users can:
- View real-time data from their IoT-enabled swiftlet houses
- Analyze harvest performance specific to each house
- Navigate seamlessly between home monitoring and detailed analysis
- Enjoy reliable functionality even when API services are unavailable

The system now fully integrates house management, device monitoring, and harvest analysis through the API services while maintaining excellent user experience and data reliability.