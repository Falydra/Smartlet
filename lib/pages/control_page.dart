import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swiftlead/components/custom_bottom_navigation.dart';
import 'package:swiftlead/pages/cage_selection_page.dart';

import 'package:swiftlead/services/house_services.dart';
import 'package:swiftlead/services/devices.services.dart';
import 'package:swiftlead/services/device_installation_service.dart';
import 'package:swiftlead/services/sensor_services.dart';
import 'package:swiftlead/utils/token_manager.dart';
import 'package:swiftlead/pages/device_installation_page.dart';

class ControlPage extends StatefulWidget {
  const ControlPage({Key? key}) : super(key: key);

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  int _currentIndex = 1;

  // API Services
  final HouseService _houseService = HouseService();
  final DeviceService _deviceService = DeviceService();
  final DeviceInstallationService _installationService = DeviceInstallationService();
  final SensorService _sensorService = SensorService();

  // State management
  bool _isLoading = true;
  String? _authToken;
  List<dynamic> _houses = [];
  List<dynamic> _devices = [];
  
  // Selected cage info
  Map<String, dynamic>? _selectedHouse;
  String _cageName = 'Kandang 1';
  String _cageAddress = 'Alamat kandang belum diisi';
  int _cageFloors = 3;
  bool _hasValidKandang = false;
  bool _hasDeviceInstalled = false;
  List<String> _installationCodes = [];

  // Environment metrics state
  _MetricState? tempState;
  _MetricState? humidityState;
  _MetricState? ammoniaState;

  // Real sensor data
  List<Map<String, dynamic>> _sensorData = [];
  Map<String, dynamic>? _latestSensorData;

  // Sistem Suara and Water Level per floor
  List<_FloorStatus> soundSystem = [];
  List<_MetricState> waterLevelPerFloor = [];

  // Timer for periodic data refresh
  Timer? _refreshTimer;

  

  @override
  void initState() {
    super.initState();
    // Initialize with demo data immediately to prevent null errors
    _initDemoData();
    // Then try to load real data
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get authentication token
      _authToken = await TokenManager.getToken();
      
      if (_authToken == null) {
        // User not logged in, redirect to login
        _showLoginRequired();
        return;
      }

      // Load houses and devices from API
      await _loadHousesFromAPI();
      await _loadDevicesFromAPI();
      
      // Check if user has any kandang data
      _checkKandangData();
      
      if (_hasValidKandang && _selectedHouse != null) {
        // Always try to load sensor data first
        await _loadSensorData();
        if (_sensorData.isNotEmpty) {
          // Use real sensor data if available
          _initMetricsWithRealData();
          setState(() {
            _hasDeviceInstalled = true;
          });
        } else {
          // Fall back to demo data only if no sensor data available
          _initDemoData();
        }
      }
    } catch (e) {
      print('Error initializing data: $e');
      // Fallback to local storage check
      await _loadCageData();
      if (_hasValidKandang) {
        _initDemoData();
      }
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadHousesFromAPI() async {
    try {
      _houses = await _houseService.getAll(_authToken!);
      print('Loaded ${_houses.length} houses from API');
    } catch (e) {
      print('Error loading houses: $e');
      _houses = [];
    }
  }

  Future<void> _loadDevicesFromAPI() async {
    try {
      _devices = await _deviceService.getAll(_authToken!);
      print('Loaded ${_devices.length} devices from API');
    } catch (e) {
      print('Error loading devices: $e');
      _devices = [];
    }
  }

  void _checkKandangData() {
    if (_houses.isNotEmpty) {
      // Use first house as selected
      _selectedHouse = _houses.first;
      _cageName = _selectedHouse!['name'] ?? 'Kandang 1';
      _cageAddress = _selectedHouse!['location'] ?? 'Alamat tidak tersedia';
      _cageFloors = _selectedHouse!['floor_count'] ?? 3;
      _hasValidKandang = true;
      _checkDeviceInstallation();
    } else {
      _hasValidKandang = false;
    }
  }

  Future<void> _checkDeviceInstallation() async {
    if (_authToken == null || _selectedHouse == null) return;

    print('=== CHECKING DEVICE INSTALLATION ===');
    
    try {
      final result = await _installationService.checkDeviceInstallation(_authToken!, _selectedHouse!['id']);
      print('Device installation result: $result');
      
      if (result['success'] == true) {
        setState(() {
          _hasDeviceInstalled = result['hasDevices'] ?? false;
          _installationCodes = List<String>.from(result['installationCodes'] ?? []);
        });
        
        print('Has devices installed: $_hasDeviceInstalled');
        print('Installation codes: $_installationCodes');
        
        // Always try to load sensor data using latest endpoint
        await _loadSensorData();
        if (_sensorData.isNotEmpty) {
          print('Sensor data loaded successfully, using real data');
          _initMetricsWithRealData();
          setState(() {
            _hasDeviceInstalled = true;
          });
          _startPeriodicRefresh();
        } else {
          print('No sensor data found');
        }
      }
    } catch (e) {
      print('Error checking device installation: $e');
      // Always try loading sensor data anyway in case the latest endpoint works
      print('Trying to load sensor data as fallback...');
      try {
        await _loadSensorData();
        if (_sensorData.isNotEmpty) {
          print('Fallback sensor data load successful!');
          setState(() {
            _hasDeviceInstalled = true;
          });
          _initMetricsWithRealData();
          _startPeriodicRefresh();
        } else {
          print('Fallback sensor data load failed - no data available');
        }
      } catch (sensorError) {
        print('Error loading sensor data as fallback: $sensorError');
      }
    }
  }

  Future<void> _loadSensorData() async {
    if (_authToken == null) return;

    try {
      // First try to get latest sensor data
      final latestResult = await _sensorService.getLatest(_authToken!);
      print('Latest API Response: $latestResult');
      
      List<Map<String, dynamic>> allSensorData = [];
      
      if (latestResult['success'] == true && latestResult['data'] != null) {
        // Handle latest endpoint response
        if (latestResult['data'] is List) {
          List<dynamic> latestDataList = latestResult['data'];
          allSensorData.addAll(latestDataList.cast<Map<String, dynamic>>());
        } else {
          // Single object response
          allSensorData.add(latestResult['data']);
        }
      }
      
      // Also load historical data for each installation code if available
      if (_installationCodes.isNotEmpty) {
        for (String installCode in _installationCodes) {
          try {
            final result = await _sensorService.getDataByInstallCode(_authToken!, installCode, limit: 50);
            print('Install Code $installCode API Response: $result');
            
            if (result['success'] == true && result['data'] != null) {
              List<dynamic> sensorDataList = result['data'];
              allSensorData.addAll(sensorDataList.cast<Map<String, dynamic>>());
            }
          } catch (e) {
            print('Error loading data for install code $installCode: $e');
          }
        }
      }

      // Remove duplicates based on timestamp and install_code
      final uniqueData = <String, Map<String, dynamic>>{};
      for (final data in allSensorData) {
        final key = '${data['timestamp']}_${data['install_code']}';
        uniqueData[key] = data;
      }
      allSensorData = uniqueData.values.toList();

      // Sort by timestamp (newest first)
      allSensorData.sort((a, b) {
        String timestampA = a['timestamp'] ?? '';
        String timestampB = b['timestamp'] ?? '';
        return timestampB.compareTo(timestampA);
      });

      setState(() {
        _sensorData = allSensorData;
        _latestSensorData = allSensorData.isNotEmpty ? allSensorData.first : null;
      });

      print('Loaded ${allSensorData.length} sensor data points');
      if (_latestSensorData != null) {
        print('Latest sensor data: $_latestSensorData');
      }
      
      // Print the three latest sensor data for debugging
      await _printLatestThreeSensorData();
    } catch (e) {
      print('Error loading sensor data: $e');
      setState(() {
        _sensorData = [];
        _latestSensorData = null;
      });
    }
  }

  Future<void> _printLatestThreeSensorData() async {
    if (_sensorData.isEmpty) {
      print('No sensor data available');
      return;
    }
    
    print('\n=== THREE LATEST SENSOR DATA ===');
    for (int i = 0; i < _sensorData.length && i < 3; i++) {
      final data = _sensorData[i];
      print('Data ${i + 1}:');
      print('  Timestamp: ${data['timestamp'] ?? 'N/A'}');
      print('  Install Code: ${data['install_code'] ?? 'N/A'}');
      print('  Suhu: ${data['suhu'] ?? 'N/A'}°C');
      print('  Kelembaban: ${data['kelembaban'] ?? 'N/A'}%');
      print('  Amonia: ${data['amonia'] ?? 'N/A'} ppm');
      print('  ---');
    }
    print('================================\n');
  }

  Future<List<Map<String, dynamic>>> getLatestThreeSensorData() async {
    if (_authToken == null) {
      print('No auth token available');
      return [];
    }

    try {
      // First get latest data from /latest endpoint
      final latestResult = await _sensorService.getLatest(_authToken!);
      List<Map<String, dynamic>> latestData = [];
      
      if (latestResult['success'] == true && latestResult['data'] != null) {
        if (latestResult['data'] is List) {
          List<dynamic> dataList = latestResult['data'];
          latestData.addAll(dataList.cast<Map<String, dynamic>>());
        } else {
          latestData.add(latestResult['data']);
        }
      }
      
      // If we have installation codes, also get recent data from install codes
      if (_installationCodes.isNotEmpty && latestData.length < 3) {
        for (String installCode in _installationCodes) {
          try {
            final result = await _sensorService.getDataByInstallCode(_authToken!, installCode, limit: 3);
            
            if (result['success'] == true && result['data'] != null) {
              List<dynamic> sensorDataList = result['data'];
              latestData.addAll(sensorDataList.cast<Map<String, dynamic>>());
            }
          } catch (e) {
            print('Error fetching data for install code $installCode: $e');
          }
        }
      }

      // Remove duplicates and sort by timestamp (newest first)
      final uniqueData = <String, Map<String, dynamic>>{};
      for (final data in latestData) {
        final key = '${data['timestamp']}_${data['install_code']}';
        uniqueData[key] = data;
      }
      latestData = uniqueData.values.toList();
      
      latestData.sort((a, b) {
        String timestampA = a['timestamp'] ?? '';
        String timestampB = b['timestamp'] ?? '';
        return timestampB.compareTo(timestampA);
      });

      return latestData.take(3).toList();
    } catch (e) {
      print('Error fetching latest three sensor data: $e');
      return [];
    }
  }

  void _initMetricsWithRealData() {
    if (_sensorData.isEmpty || _latestSensorData == null) {
      print('No real sensor data available, falling back to demo data');
      // Fallback to demo data if no real data available
      _initDemoData();
      return;
    }
    
    print('Initializing metrics with real sensor data');
    print('Latest sensor data: $_latestSensorData');

    // Create metric states from real sensor data
    tempState = _createMetricFromSensorData(
      name: 'Suhu',
      dataKey: 'suhu',
      unit: '°C',
      icon: Icons.thermostat,
      minY: 20,
      maxY: 40,
      goodBad: (v) => _conditionForTemp(v),
    );

    humidityState = _createMetricFromSensorData(
      name: 'Kelembapan',
      dataKey: 'kelembaban',
      unit: '%',
      icon: Icons.water_drop_outlined,
      minY: 30,
      maxY: 100,
      goodBad: (v) => _conditionForHumidity(v),
    );

    ammoniaState = _createMetricFromSensorData(
      name: 'Amonia',
      dataKey: 'amonia',
      unit: 'ppm',
      icon: Icons.science_outlined,
      minY: 0,
      maxY: 100,
      goodBad: (v) => _conditionForAmmonia(v),
    );

    _initPerFloorLists();
  }

  _MetricState _createMetricFromSensorData({
    required String name,
    required String dataKey,
    required String unit,
    required IconData icon,
    required double minY,
    required double maxY,
    required String Function(double) goodBad,
  }) {
    // Convert sensor data to chart points
    List<FlSpot> points = [];
    
    for (int i = 0; i < _sensorData.length && i < 288; i++) {
      final data = _sensorData[_sensorData.length - 1 - i]; // Reverse order for chronological
      try {
        final timestamp = DateTime.parse(data['timestamp']);
        final value = (data[dataKey] as num?)?.toDouble() ?? 0.0;
        points.add(FlSpot(timestamp.millisecondsSinceEpoch.toDouble(), value));
      } catch (e) {
        print('Error parsing sensor data point: $e');
      }
    }

    // Get current values from latest data
    final currentValue = (_latestSensorData![dataKey] as num?)?.toDouble() ?? 0.0;
    final timestamp = DateTime.parse(_latestSensorData!['timestamp'] ?? DateTime.now().toIso8601String());
    final timeStr = _formatTime(timestamp);

    return _MetricState(
      name: name,
      icon: icon,
      unit: unit,
      minY: minY,
      maxY: maxY,
      points: points,
      currentValue: currentValue,
      lastTime: timeStr,
      condition: goodBad(currentValue),
    );
  }

  void _startPeriodicRefresh() {
    // Cancel existing timer if any
    _refreshTimer?.cancel();

    // Refresh sensor data every 5 minutes
    _refreshTimer = Timer.periodic(Duration(minutes: 5), (timer) async {
      if (_hasDeviceInstalled && _authToken != null) {
        print('Refreshing sensor data at ${DateTime.now()}');
        await _loadSensorData();
        _initMetricsWithRealData();
        
        // Fetch and display the latest three sensor data
        final latestThree = await getLatestThreeSensorData();
        if (latestThree.isNotEmpty) {
          print('Successfully fetched ${latestThree.length} latest sensor data points');
        }
      }
    });
  }

  void _stopPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  void _showLoginRequired() {
    // Show login required dialog or redirect to login
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('Login Diperlukan'),
          content: Text('Silakan login terlebih dahulu untuk mengakses fitur kontrol.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacementNamed(context, '/login-page');
              },
              child: Text('Login'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _loadCageData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check for valid kandang data
      bool hasValidData = false;
      String cageName = 'Kandang 1';
      String cageAddress = 'Alamat kandang belum diisi';
      int cageFloors = 3;
      
      // Get kandang count
      int kandangCount = prefs.getInt('kandang_count') ?? 0;
      
      if (kandangCount > 0) {
        // Check all kandang for at least one complete entry
        for (int i = 1; i <= kandangCount; i++) {
          final address = prefs.getString('kandang_${i}_address');
          final floors = prefs.getInt('kandang_${i}_floors');
          
          if (address != null && address.isNotEmpty && floors != null) {
            // Found at least one complete kandang
            hasValidData = true;
            cageName = 'Kandang $floors Lantai';
            cageAddress = address;
            cageFloors = floors;
            break; // Use the first valid kandang found
          }
        }
      } else {
        // Check legacy data
        final legacyAddress = prefs.getString('cage_address');
        final legacyFloors = prefs.getInt('cage_floors');
        
        if (legacyAddress != null && legacyAddress.isNotEmpty && legacyFloors != null) {
          hasValidData = true;
          cageName = 'Kandang $legacyFloors Lantai';
          cageAddress = legacyAddress;
          cageFloors = legacyFloors;
        }
      }
      
      setState(() {
        _cageName = cageName;
        _cageAddress = cageAddress;
        _cageFloors = cageFloors;
        _hasValidKandang = hasValidData;
      });
      
      // Only initialize control data if we have valid kandang
      if (hasValidData) {
        // Check if we have any devices installed for this kandang
        if (_hasDeviceInstalled && _installationCodes.isNotEmpty) {
          await _loadSensorData();
          _initMetricsWithRealData();
          _startPeriodicRefresh();
        } else {
          _initDemoData();
        }
      }
    } catch (_) {
      // Use defaults on failure
      setState(() {
        _hasValidKandang = false;
      });
    }
  }

  void _initPerFloorLists() {
    soundSystem = List.generate(
      _cageFloors,
      (i) => _FloorStatus(
        floor: i + 1,
        active: i % 2 == 0,
        lastTime: _formatTime(DateTime.now()),
        condition: i % 3 == 0 ? 'Baik' : (i % 3 == 1 ? 'Normal' : 'Buruk'),
      ),
    );

    waterLevelPerFloor = List.generate(
      _cageFloors,
      (i) => _generateMetricState(
        name: 'Water Lvl Lantai ${i + 1}',
        minY: 0,
        maxY: 100,
        base: 60 + (i * 5),
        variance: 15,
        unit: '%',
        icon: Icons.water_drop,
        goodBad: (v) => _conditionForWater(v),
      ),
    );
  }

  void _initDemoData() {
    // Initialize metrics even without valid kandang for UI stability
    print('Initializing demo data for UI stability');
    
    tempState = _generateMetricState(
      name: 'Suhu',
      minY: 20,
      maxY: 40,
      base: 28,
      variance: 4,
      unit: '°C',
      icon: Icons.thermostat,
      goodBad: (v) => _conditionForTemp(v),
    );

    humidityState = _generateMetricState(
      name: 'Kelembapan',
      minY: 30,
      maxY: 100,
      base: 75,
      variance: 10,
      unit: '%',
      icon: Icons.water_drop_outlined,
      goodBad: (v) => _conditionForHumidity(v),
    );

    ammoniaState = _generateMetricState(
      name: 'Amonia',
      minY: 0,
      maxY: 50,
      base: 8,
      variance: 6,
      unit: 'ppm',
      icon: Icons.science_outlined,
      goodBad: (v) => _conditionForAmmonia(v),
    );

    _initPerFloorLists();
  }

  // Template generator for 1-day data with 5-minute intervals
  _MetricState _generateMetricState({
    required String name,
    required double minY,
    required double maxY,
    required double base,
    required double variance,
    required String unit,
    required IconData icon,
    required String Function(double) goodBad,
  }) {
    final now = DateTime.now();
    // 24h * 12 points per hour = 288 points
    final points = <FlSpot>[];
    final rand = Random(name.hashCode ^ now.day ^ now.hour);
    final start = now.subtract(const Duration(hours: 24));
    for (int i = 0; i <= 288; i++) {
      final t = start.add(Duration(minutes: 5 * i));
      final x = t.millisecondsSinceEpoch.toDouble();
      final noise = (rand.nextDouble() * 2 - 1) * variance;
      double y = base + noise + sin(i / 14.0) * (variance / 2);
      y = y.clamp(minY, maxY);
      points.add(FlSpot(x, y));
    }
    final last = points.last.y;
    final timeStr = _formatTime(now);
    return _MetricState(
      name: name,
      icon: icon,
      unit: unit,
      minY: minY,
      maxY: maxY,
      points: points,
      currentValue: last,
      lastTime: timeStr,
      condition: goodBad(last),
    );
  }

  // Condition helpers
  String _conditionForTemp(double v) {
    if (v >= 26 && v <= 30) return 'Baik';
    if (v >= 24 && v <= 32) return 'Normal';
    return 'Buruk';
    // TODO: adjust thresholds per your domain
  }

  String _conditionForHumidity(double v) {
    if (v >= 70 && v <= 85) return 'Baik';
    if (v >= 60 && v <= 90) return 'Normal';
    return 'Buruk';
  }

  String _conditionForAmmonia(double v) {
    if (v < 10) return 'Baik';
    if (v < 20) return 'Normal';
    return 'Buruk';
  }

  String _conditionForWater(double v) {
    if (v >= 60) return 'Baik';
    if (v >= 40) return 'Normal';
    return 'Buruk';
  }

  String _formatTime(DateTime t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  // Method to manually fetch and display latest three sensor data
  Future<void> fetchAndDisplayLatestThree() async {
    print('\n=== FETCHING LATEST THREE SENSOR DATA ===');
    final latestThree = await getLatestThreeSensorData();
    
    if (latestThree.isEmpty) {
      print('No sensor data available');
      return;
    }
    
    print('Found ${latestThree.length} latest sensor data points:');
    for (int i = 0; i < latestThree.length; i++) {
      final data = latestThree[i];
      print('${i + 1}. Timestamp: ${data['timestamp']}');
      print('   Install Code: ${data['install_code'] ?? 'N/A'}');
      print('   Suhu: ${data['suhu']}°C, Kelembaban: ${data['kelembaban']}%, Amonia: ${data['amonia']} ppm');
    }
    print('========================================\n');
  }

  // Method to test API connection and display raw response
  Future<void> testAPIConnection() async {
    if (_authToken == null) {
      print('No authentication token available');
      return;
    }

    print('\n=== TESTING API CONNECTION ===');
    
    try {
      // Test latest endpoint
      print('Testing /latest endpoint...');
      final latestResult = await _sensorService.getLatest(_authToken!);
      print('Latest endpoint response: $latestResult');
      
      // Test install code endpoint if available
      if (_installationCodes.isNotEmpty) {
        for (String code in _installationCodes) {
          print('\nTesting install code: $code');
          final codeResult = await _sensorService.getDataByInstallCode(_authToken!, code, limit: 1);
          print('Install code $code response: $codeResult');
        }
      }
      
    } catch (e) {
      print('API Test Error: $e');
    }
    
    print('===============================\n');
  }

  // Navigate to cage selector, then reload cage data
  Future<void> _chooseCage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CageSelectionPage()),
    );
    await _loadCageData();
    _initDemoData(); // Reinitialize demo data after cage selection
  }

  void _navigateToDeviceInstallation() {
    if (_selectedHouse != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DeviceInstallationPage(
            houseId: _selectedHouse!['id'],
            houseName: _selectedHouse!['name'] ?? 'Kandang',
          ),
        ),
      ).then((_) {
        // Reload device data when returning
        _checkDeviceInstallation();
      });
    }
  }

  @override
  void dispose() {
    _stopPeriodicRefresh();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Kontrol'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF245C4C),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.95),
                Colors.white.withOpacity(0.8)
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      body: _hasValidKandang ? (_hasDeviceInstalled ? SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _chooseCage,
                        icon: const Icon(Icons.business, size: 18),
                        label: Text(_cageName),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF245C4C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      Container(
                        width: min(1, (width / 6))
                            .toDouble(), // visual separator dot if very small screen
                        height: 0,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    height: 1,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on,
                          color: Color(0xFF245C4C), size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _cageAddress,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Last Update: ${_latestSensorData != null ? _formatTime(DateTime.parse(_latestSensorData!['timestamp'] ?? DateTime.now().toIso8601String())) : 'No data'}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : () async {
                          setState(() {
                            _isLoading = true;
                          });
                          
                          try {
                            print('=== MANUAL REFRESH TRIGGERED ===');
                            await _loadSensorData();
                            
                            if (_sensorData.isNotEmpty) {
                              print('Found sensor data, using real data');
                              _initMetricsWithRealData();
                              setState(() {
                                _hasDeviceInstalled = true;
                              });
                            } else {
                              print('No sensor data found, using demo data');
                              _initDemoData();
                            }
                            
                            // Test API connection
                            await testAPIConnection();
                            
                            // Auto-correct install codes if needed
                            if (_selectedHouse != null && _installationCodes.any((code) => code.startsWith('ESP31'))) {
                              print('Found ESP31 codes, attempting auto-correction...');
                              try {
                                final correctionResult = await _installationService.autoCorrectInstallCodes(_authToken!, _selectedHouse!['id']);
                                print('Install code correction result: $correctionResult');
                                if (correctionResult['success'] == true) {
                                  // Reload device installation after correction
                                  await _checkDeviceInstallation();
                                }
                              } catch (e) {
                                print('Error correcting install codes: $e');
                              }
                            }
                            
                            // Fetch and display the latest three sensor data
                            final latestThree = await getLatestThreeSensorData();
                            if (latestThree.isNotEmpty) {
                              print('Manually fetched ${latestThree.length} latest sensor data points');
                            }
                            
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Sensor data updated! Found ${_sensorData.length} data points. Real data: ${_sensorData.isNotEmpty}'),
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                          } catch (e) {
                            print('Error refreshing sensor data: $e');
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error updating sensor data: $e'),
                                  duration: Duration(seconds: 3),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                          
                          setState(() {
                            _isLoading = false;
                          });
                        },
                        icon: _isLoading 
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.refresh, size: 14),
                        label: Text(_isLoading ? 'Loading...' : 'Refresh', style: const TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF245C4C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 1: Environment Controls
            _sectionCard(
              title: 'Kontrol Lingkungan',
              child: Column(
                children: [
                  if (tempState != null) _metricRow(tempState!) else _buildLoadingMetric('Suhu', Icons.thermostat),
                  const SizedBox(height: 12),
                  if (humidityState != null) _metricRow(humidityState!) else _buildLoadingMetric('Kelembapan', Icons.water_drop_outlined),
                  const SizedBox(height: 12),
                  if (ammoniaState != null) _metricRow(ammoniaState!) else _buildLoadingMetric('Amonia', Icons.science_outlined),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 2: Sistem Suara per-floor
            _sectionCard(
              title: 'Sistem Suara',
              child: Column(
                children: [
                  for (final f in soundSystem) _soundRow(f),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 3: Water Level per-floor
            _sectionCard(
              title: 'Water Level',
              child: Column(
                children: [
                  if (waterLevelPerFloor.isNotEmpty)
                    for (final w in waterLevelPerFloor) ...[
                      _metricRow(w),
                      const SizedBox(height: 12),
                    ]
                  else
                    _buildLoadingMetric('Water Level', Icons.water_drop),
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ) : _buildNoDeviceState()) : _buildEmptyState(),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
              icon: CustomBottomNavigationItem(
                icon: Icons.home,
                label: 'Beranda',
                currentIndex: _currentIndex,
                itemIndex: 0,
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/home-page');
                  setState(() {
                    _currentIndex = 0;
                  });
                },
              ),
              label: ''),
          BottomNavigationBarItem(
              icon: CustomBottomNavigationItem(
                icon: Icons.pest_control,
                label: 'Kontrol',
                currentIndex: _currentIndex,
                itemIndex: 1,
                onTap: () {
                  // Stay on control page
                  setState(() {
                    _currentIndex = 1;
                  });
                },
              ),
              label: ''),
          BottomNavigationBarItem(
              icon: CustomBottomNavigationItem(
                icon: Icons.agriculture,
                label: 'Panen',
                currentIndex: _currentIndex,
                itemIndex: 2,
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/harvest/analysis');
                  setState(() {
                    _currentIndex = 2;
                  });
                },
              ),
              label: ''),
          BottomNavigationBarItem(
              icon: CustomBottomNavigationItem(
                icon: Icons.sell,
                label: 'Jual',
                currentIndex: _currentIndex,
                itemIndex: 3,
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/store-page');
                  setState(() {
                    _currentIndex = 3;
                  });
                },
              ),
              label: ''),
          BottomNavigationBarItem(
              icon: CustomBottomNavigationItem(
                icon: Icons.person,
                label: 'Profil',
                currentIndex: _currentIndex,
                itemIndex: 4,
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/profile-page');
                  setState(() {
                    _currentIndex = 4;
                  });
                },
              ),
              label: ''),
        ],
      ),
    );
  }

  // UI helpers

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.dashboard_customize_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Belum Ada Kandang Terdaftar',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Anda perlu menambahkan dan melengkapi data kandang terlebih dahulu untuk menggunakan fitur kontrol',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _chooseCage,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Tambah Kandang',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF245C4C),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/home-page');
              },
              child: Text(
                'Kembali ke Beranda',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDeviceState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sensors_off,
              size: 80,
              color: Colors.red[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Control Device / Sensor Not Installed',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Anda perlu menginstall device/sensor terlebih dahulu di kandang "${_cageName}" untuk menggunakan fitur kontrol',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _navigateToDeviceInstallation,
              icon: const Icon(Icons.add_circle, color: Colors.white),
              label: const Text(
                'Request Installation',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/home-page');
              },
              child: Text(
                'Kembali ke Beranda',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF245C4C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _metricRow(_MetricState m) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          // Left: icon + label + time
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFF245C4C).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(m.icon, color: const Color(0xFF245C4C), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF245C4C),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.access_time,
                              size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            m.lastTime,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Middle: 1-day line chart (5-min intervals)
          // Expanded(
          //   flex: 4,
          //   child: SizedBox(
          //     height: 70,
          //     child: LineChart(
          //       LineChartData(
          //         minY: m.minY,
          //         maxY: m.maxY,
          //         gridData: FlGridData(
          //           show: true,
          //           drawVerticalLine: false,
          //         ),
          //         titlesData: FlTitlesData(
          //           topTitles: const AxisTitles(
          //               sideTitles: SideTitles(showTitles: false)),
          //           rightTitles: const AxisTitles(
          //               sideTitles: SideTitles(showTitles: false)),
          //           leftTitles: AxisTitles(
          //             sideTitles: SideTitles(
          //               showTitles: true,
          //               reservedSize: 28,
          //               getTitlesWidget: (v, mctx) => Text(
          //                 v.toStringAsFixed(0),
          //                 style:
          //                     const TextStyle(fontSize: 8, color: Colors.grey),
          //               ),
          //               interval: (m.maxY - m.minY) / 2,
          //             ),
          //           ),
          //           bottomTitles: AxisTitles(
          //             sideTitles: SideTitles(
          //               showTitles: true,
          //               interval:
          //                   (24 * 60 * 60 * 1000) / 4, // roughly 6h spacing
          //               getTitlesWidget: (x, mctx) {
          //                 final d =
          //                     DateTime.fromMillisecondsSinceEpoch(x.toInt());
          //                 return Text('${d.hour}:00',
          //                     style: const TextStyle(
          //                         fontSize: 8, color: Colors.grey));
          //               },
          //             ),
          //           ),
          //         ),
          //         borderData: FlBorderData(
          //           show: true,
          //           border: Border.all(color: Colors.grey[300]!),
          //         ),
          //         lineBarsData: [
          //           LineChartBarData(
          //             spots: m.points,
          //             isCurved: true,
          //             color: const Color(0xFF245C4C),
          //             barWidth: 2,
          //             dotData: const FlDotData(show: false),
          //             belowBarData: BarAreaData(
          //               show: true,
          //               color: const Color(0xFF245C4C).withOpacity(0.12),
          //             ),
          //           ),
          //         ],
          //       ),
          //     ),
          //   ),
          // ),
          const SizedBox(width: 10),

          // Right: current value + time, and condition chip
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${m.currentValue.toStringAsFixed(1)} ${m.unit}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF245C4C),
                  ),
                ),
                Text(
                  'Realtime ${m.lastTime}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                _conditionChip(m.condition),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _soundRow(_FloorStatus f) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          // Left: floor + status
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF245C4C).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.surround_sound,
                      color: Color(0xFF245C4C), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lantai ${f.floor}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF245C4C),
                        ),
                      ),
                      Text(
                        'Status: ${f.active ? 'active' : 'not'}',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Right: time + condition
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Icon(Icons.access_time, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(f.lastTime,
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 6),
                _conditionChip(f.condition),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingMetric(String name, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          // Left: icon + label
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: Colors.grey, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                      const Row(
                        children: [
                          Icon(Icons.access_time, size: 12, color: Colors.grey),
                          SizedBox(width: 4),
                          Text(
                            'Loading...',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Right: loading indicator
          const Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(height: 4),
                Text(
                  'Loading data...',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _conditionChip(String condition) {
    Color bg;
    Color fg;
    switch (condition.toLowerCase()) {
      case 'baik':
      case 'good':
        bg = const Color(0xFF4CAF50).withOpacity(0.12);
        fg = const Color(0xFF2E7D32);
        break;
      case 'normal':
        bg = const Color(0xFFFFC107).withOpacity(0.12);
        fg = const Color(0xFF996C00);
        break;
      default: // 'buruk' or 'bad'
        bg = const Color(0xFFF44336).withOpacity(0.12);
        fg = const Color(0xFFB71C1C);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        condition[0].toUpperCase() + condition.substring(1).toLowerCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

// Data holders

class _MetricState {
  final String name;
  final IconData icon;
  final String unit;
  final double minY;
  final double maxY;
  final List<FlSpot> points;
  final double currentValue;
  final String lastTime;
  final String condition;

  _MetricState({
    required this.name,
    required this.icon,
    required this.unit,
    required this.minY,
    required this.maxY,
    required this.points,
    required this.currentValue,
    required this.lastTime,
    required this.condition,
  });
}

class _FloorStatus {
  final int floor;
  final bool active;
  final String lastTime;
  final String condition;

  _FloorStatus({
    required this.floor,
    required this.active,
    required this.lastTime,
    required this.condition,
  });
}

/*
TODO: Integrate backend data
- Replace _initDemoData and _generateMetricState with API or device reads.
- Update _loadCageData to use your cage data source (or keep SharedPreferences).
- Push/refresh per 5 minutes via timer or stream.
- For Sistem Suara and Water Level, fetch per-floor runtime state.
*/