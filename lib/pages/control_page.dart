import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swiftlead/components/custom_bottom_navigation.dart';
import 'package:swiftlead/pages/cage_selection_page.dart';

import 'package:swiftlead/services/house_services.dart';
// Removed deprecated services: DeviceService (iot-devices) & DeviceInstallationService
// import 'package:swiftlead/services/devices.services.dart';
// import 'package:swiftlead/services/device_installation_service.dart';
import 'package:swiftlead/services/sensor_services.dart';
import 'package:swiftlead/services/node_service.dart';
import 'package:swiftlead/services/ai_service.dart';
import 'package:swiftlead/utils/token_manager.dart';
import 'package:swiftlead/utils/time_utils.dart';
import 'package:swiftlead/pages/device_installation_page.dart';
import 'package:swiftlead/services/alert_service.dart';
import 'package:swiftlead/utils/notification_manager.dart';
import 'package:swiftlead/utils/local_notification_helper.dart';
import 'package:swiftlead/services/timer_background_service.dart';

class ControlPage extends StatefulWidget {
  const ControlPage({super.key});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  int _currentIndex = 1;

  // API Services
  final HouseService _houseService = HouseService();
  // Removed deprecated services; device management now through nodes API
  // final DeviceService _deviceService = DeviceService();
  // final DeviceInstallationService _installationService = DeviceInstallationService();
  final SensorService _sensorService = SensorService();
  final NodeService _nodeService = NodeService();
  final AIService _aiService = AIService();

  // State management
  bool _isLoading = true;
  String? _authToken;

  // AI Anomaly Detection State
  Map<String, dynamic>? _anomalyData;
  bool _hasAnomalies = false;

  // AI Comprehensive Analysis State
  Map<String, dynamic>? _aiAnalysis;
  bool _isLoadingAI = false;

  // Health scores for sensors (0-100)
  double? _tempHealthScore;
  double? _humidityHealthScore;
  double? _ammoniaHealthScore;
  double? _overallHealthScore;

  List<dynamic> _houses = [];
  // TODO: Replace with nodes data when available
  // List<dynamic> _devices = [];

  // Selected cage info
  Map<String, dynamic>? _selectedHouse;
  String _cageName = 'Kandang 1';
  String _cageAddress = 'Alamat kandang belum diisi';
  int _cageFloors = 3;
  bool _hasValidKandang = false;
  bool _hasDeviceInstalled = false;
  List<String> _nodeIds = [];
  List<Map<String, dynamic>> _nodes =
      []; // store node objects for actuator + floor mapping
  List<Map<String, dynamic>> _sensors = [];

  // Environment metrics state
  _MetricState? tempState;
  _MetricState? humidityState;
  _MetricState? ammoniaState;

  // Real sensor data
  List<Map<String, dynamic>> _sensorData = [];
  Map<String, dynamic>?
      _latestSensorData; // newest individual reading among all
  Map<String, dynamic>?
      _latestByMetric; // {temperature, humidity, ammonia, timestamp, sensorIds}
  Map<int, Map<String, dynamic>> _latestByMetricPerFloor =
      {}; // floor -> metric map

  // Floor 2 metric states (explicit request)
  // Floor 1 & 2 metric states
  _MetricState? tempFloor1State;
  _MetricState? humidityFloor1State;
  _MetricState? ammoniaFloor1State;
  _MetricState? tempFloor2State;
  _MetricState? humidityFloor2State;
  _MetricState? ammoniaFloor2State;

  // Actuator states (Mist Spray pump & Tweeter audio)
  String? _pumpNodeId;
  bool? _pumpState;
  bool _pumpLoading = false;
  String? _audioNodeId;
  bool? _audioBothState;
  bool _audioBothLoading = false;
  bool? _audioLmbState;
  bool _audioLmbLoading = false;
  bool? _audioNestState;
  bool _audioNestLoading = false;

  // Timer states for each actuator
  DateTime? _pumpTimerEnd;
  DateTime? _audioBothTimerEnd;
  DateTime? _audioLmbTimerEnd;
  DateTime? _audioNestTimerEnd;
  Timer? _actuatorTimer;

  // Notification IDs for updating progress
  int? _pumpNotificationId;
  int? _audioBothNotificationId;
  int? _audioLmbNotificationId;
  int? _audioNestNotificationId;

  // Sistem Suara and Water Level per floor
  List<_FloorStatus> soundSystem = [];
  List<_MetricState> waterLevelPerFloor = [];

  // Timer for periodic data refresh
  Timer? _refreshTimer;
  final AlertService _alertService = AlertService();
  final NotificationManager _notif = NotificationManager();

  @override
  void initState() {
    super.initState();
    // Initialize with demo data immediately to prevent null errors
    _initDemoData();
    // Initialize background service
    _initBackgroundService();
    // Then try to load real data
    _initializeData();
  }

  Future<void> _initBackgroundService() async {
    await TimerBackgroundService.initialize();
    // Load saved timers from background service
    await _loadSavedTimers();
  }

  Future<void> _loadSavedTimers() async {
    final pumpDuration = await TimerBackgroundService.getRemainingTime('pump');
    if (pumpDuration != null) {
      setState(() {
        _pumpTimerEnd = DateTime.now().add(pumpDuration);
      });
    }

    final audioBothDuration =
        await TimerBackgroundService.getRemainingTime('audio_both');
    if (audioBothDuration != null) {
      setState(() {
        _audioBothTimerEnd = DateTime.now().add(audioBothDuration);
      });
    }

    final audioLmbDuration =
        await TimerBackgroundService.getRemainingTime('audio_lmb');
    if (audioLmbDuration != null) {
      setState(() {
        _audioLmbTimerEnd = DateTime.now().add(audioLmbDuration);
      });
    }

    final audioNestDuration =
        await TimerBackgroundService.getRemainingTime('audio_nest');
    if (audioNestDuration != null) {
      setState(() {
        _audioNestTimerEnd = DateTime.now().add(audioNestDuration);
      });
    }

    // Start UI timer if any timers are active
    if (_pumpTimerEnd != null ||
        _audioBothTimerEnd != null ||
        _audioLmbTimerEnd != null ||
        _audioNestTimerEnd != null) {
      _startActuatorTimer();
    }
  }

  Future<void> _initializeData() async {
    if (!mounted) return;

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
      if (!mounted) return;

      await _loadNodesAndSensors();
      if (!mounted) return;

      // Check if user has any kandang data
      _checkKandangData();

      if (_hasValidKandang && _selectedHouse != null) {
        // Always try to load sensor data first via readings endpoint
        await _loadSensorReadingsFromQuery();
        if (!mounted) return;

        if (_sensorData.isNotEmpty) {
          _initMetricsWithRealData();
          if (!mounted) return;

          setState(() {
            _hasDeviceInstalled = true;
          });
          _startPeriodicRefresh();
        } else {
          _initDemoData();
        }
      }
    } catch (e) {
      print('Error initializing data: $e');
      // Fallback to local storage check
      await _loadCageData();
      if (!mounted) return;

      if (mounted) {
        if (_hasValidKandang) {
          _initDemoData();
        }
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
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

  Future<void> _loadNodesAndSensors() async {
    _nodeIds.clear();
    _sensors.clear();
    _nodes.clear();
    print('[LOAD NODES] Starting to load nodes and sensors...');
    try {
      if (_authToken == null) return;
      for (final house in _houses) {
        if (!mounted) return;

        final rbwId = house['id']?.toString();
        if (rbwId == null || rbwId.isEmpty) continue;
        print('[LOAD NODES] Loading nodes for house: $rbwId');
        final nodesRes = await _nodeService
            .listByRbw(_authToken!, rbwId, queryParams: {'per_page': '50'});

        if (!mounted) return;

        print(
            '[LOAD NODES] Nodes response: success=${nodesRes['success']}, data count=${(nodesRes['data'] as List?)?.length ?? 0}');
        if (nodesRes['success'] == true) {
          final nodes = (nodesRes['data'] as List<dynamic>?) ?? [];
          print('[LOAD NODES] Processing ${nodes.length} nodes...');
          for (final n in nodes) {
            if (!mounted) return;

            final nid =
                (n is Map && n['id'] != null) ? n['id'].toString() : null;
            if (nid != null) {
              _nodeIds.add(nid);
              if (n is Map<String, dynamic>) {
                _nodes.add(Map<String, dynamic>.from(n));
                print('[LOAD NODES] About to register actuator for node: $nid');
                _maybeRegisterActuatorNode(n); // identify pump/audio nodes
              }
              // fetch sensors via dedicated endpoint
              final sensorsRes =
                  await _nodeService.getSensorsByNode(_authToken!, nid);

              if (!mounted) return;

              if (sensorsRes['success'] == true) {
                final sList = (sensorsRes['data'] as List<dynamic>?) ?? [];
                for (final s in sList) {
                  if (s is Map<String, dynamic>) {
                    // ensure node_id present
                    s['node_id'] ??= nid;
                    _sensors.add(Map<String, dynamic>.from(s));
                  }
                }
              }
            }
          }
        }
      }
      _hasDeviceInstalled = _sensors.isNotEmpty;
      if (_hasDeviceInstalled) {
        await _loadSensorReadingsFromQuery();
      }
    } catch (e) {
      print('Error loading nodes/sensors: $e');
    }
  }

  void _checkKandangData() {
    if (_houses.isNotEmpty) {
      // Use first house as selected
      _selectedHouse = _houses.first;
      _cageName = _selectedHouse!['name'] ?? 'Kandang 1';
      _cageAddress = _selectedHouse!['address'] ?? 'Alamat tidak tersedia';
      _cageFloors = _selectedHouse!['total_floors'] ?? 3;
      _hasValidKandang = true;
      _checkDeviceInstallation();
    } else {
      _hasValidKandang = false;
    }
  }

  Future<void> _checkDeviceInstallation() async {
    if (_authToken == null || _selectedHouse == null) return;

    print('=== CHECKING DEVICE INSTALLATION ===');

    // NOTE: Previously used deprecated DeviceInstallationService.checkDeviceInstallation()
    // TODO: Replace with nodes API: GET /rbw/{house_id}/nodes
    // Node-based installation already processed in _loadNodesAndSensors
  }

  Future<void> _loadSensorReadingsFromQuery() async {
    if (_authToken == null) return;
    List<Map<String, dynamic>> collected = [];
    DateTime? newestTs;
    Map<String, dynamic>? newestRecord;
    // Track latest per metric
    double? temperature;
    double? humidity;
    double? ammonia;
    String? temperatureSensorId;
    String? humiditySensorId;
    String? ammoniaSensorId;
    DateTime? latestMetricTs;
    // Per-floor trackers
    final Map<int, double?> tempPerFloor = {};
    final Map<int, double?> humidityPerFloor = {};
    final Map<int, double?> ammoniaPerFloor = {};
    final Map<int, DateTime?> tsPerFloor = {};
    final Map<int, String?> tempSensorPerFloor = {};
    final Map<int, String?> humiditySensorPerFloor = {};
    final Map<int, String?> ammoniaSensorPerFloor = {};

    for (final sensor in _sensors) {
      final sid = sensor['id']?.toString();
      if (sid == null || sid.isEmpty) continue;
      final nodeId = sensor['node_id']?.toString();
      final floor = _floorForNode(nodeId);

      try {
        final res = await _sensorService
            .getReadings(_authToken!, sid, queryParams: {'limit': '10'});
        if (res['data'] is List) {
          final List<dynamic> readings = res['data'];

          // Sort readings by recorded_at desc (newest first) and collect all
          readings.sort((a, b) {
            final aTime =
                DateTime.tryParse(a['recorded_at']?.toString() ?? '') ??
                    DateTime.fromMillisecondsSinceEpoch(0);
            final bTime =
                DateTime.tryParse(b['recorded_at']?.toString() ?? '') ??
                    DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime); // Descending order
          });

          for (final r in readings) {
            if (r is Map<String, dynamic>) {
              collected.add(r);
              final ts = DateTime.tryParse(r['recorded_at']?.toString() ?? '');
              if (ts != null && (newestTs == null || ts.isAfter(newestTs))) {
                newestTs = ts;
                newestRecord = r;
              }
            }
          }

          // Take newest for this sensor and classify into metric buckets
          if (readings.isNotEmpty) {
            final newest = readings.first;
            if (newest is Map<String, dynamic>) {
              final metric = _classifySensorMetric(sensor);
              final val = (newest['value'] as num?)?.toDouble();
              final ts =
                  DateTime.tryParse(newest['recorded_at']?.toString() ?? '');
              if (val != null) {
                if (metric == 'temperature') {
                  temperature = val;
                  temperatureSensorId = sid;
                  latestMetricTs = _pickLatest(latestMetricTs, ts);
                } else if (metric == 'humidity') {
                  humidity = val;
                  humiditySensorId = sid;
                  latestMetricTs = _pickLatest(latestMetricTs, ts);
                } else if (metric == 'ammonia') {
                  ammonia = val;
                  ammoniaSensorId = sid;
                  latestMetricTs = _pickLatest(latestMetricTs, ts);
                }
                // per-floor capture
                if (floor != null) {
                  if (metric == 'temperature') {
                    tempPerFloor[floor] = val;
                    tempSensorPerFloor[floor] = sid;
                    tsPerFloor[floor] = _pickLatest(tsPerFloor[floor], ts);
                  } else if (metric == 'humidity') {
                    humidityPerFloor[floor] = val;
                    humiditySensorPerFloor[floor] = sid;
                    tsPerFloor[floor] = _pickLatest(tsPerFloor[floor], ts);
                  } else if (metric == 'ammonia') {
                    ammoniaPerFloor[floor] = val;
                    ammoniaSensorPerFloor[floor] = sid;
                    tsPerFloor[floor] = _pickLatest(tsPerFloor[floor], ts);
                  }
                }
              }
              // Debug
              // ignore: avoid_print
              print(
                  '[CONTROL] Sensor $sid type=${sensor['type'] ?? sensor['name'] ?? sensor['label']} classified=$metric value=$val at ${newest['recorded_at']}');
            }
          }
        }
      } catch (e) {
        print('Sensor $sid error: $e');
      }
    }

    setState(() {
      _sensorData = collected;
      _latestSensorData = newestRecord;
      _latestByMetric = {
        'temperature': temperature,
        'humidity': humidity,
        'ammonia': ammonia,
        'timestamp': (latestMetricTs ?? newestTs)?.toIso8601String(),
        'temperatureSensorId': temperatureSensorId,
        'humiditySensorId': humiditySensorId,
        'ammoniaSensorId': ammoniaSensorId,
      };
      // Build per-floor metric map
      _latestByMetricPerFloor.clear();
      final floors = {
        ...tempPerFloor.keys,
        ...humidityPerFloor.keys,
        ...ammoniaPerFloor.keys
      };
      for (final f in floors) {
        _latestByMetricPerFloor[f] = {
          'temperature': tempPerFloor[f],
          'humidity': humidityPerFloor[f],
          'ammonia': ammoniaPerFloor[f],
          'timestamp': tsPerFloor[f]?.toIso8601String(),
          'temperatureSensorId': tempSensorPerFloor[f],
          'humiditySensorId': humiditySensorPerFloor[f],
          'ammoniaSensorId': ammoniaSensorPerFloor[f],
        };
      }
    });
  }

  // Removed legacy _printLatestThreeSensorData helper

  // Removed legacy getLatestThreeSensorData() helper

  void _initMetricsWithRealData() {
    if (_sensorData.isEmpty || _latestByMetric == null) {
      print('No real sensor data available, falling back to demo data');
      // Fallback to demo data if no real data available
      _initDemoData();
      return;
    }

    print('Initializing metrics with real sensor data');
    print('Latest by metric: $_latestByMetric');

    // Create metric states from real sensor data
    tempState = _createMetricFromSensorData(
      name: 'Suhu',
      unit: '°C',
      icon: Icons.thermostat,
      minY: 20,
      maxY: 40,
      goodBad: (v) => _conditionForTemp(v),
      currentValue:
          (_latestByMetric!['temperature'] as num?)?.toDouble() ?? 0.0,
      currentTimestamp:
          DateTime.tryParse((_latestByMetric!['timestamp'] ?? '').toString()) ??
              DateTime.now(),
    );

    humidityState = _createMetricFromSensorData(
      name: 'Kelembapan',
      unit: '%',
      icon: Icons.water_drop_outlined,
      minY: 30,
      maxY: 100,
      goodBad: (v) => _conditionForHumidity(v),
      currentValue: (_latestByMetric!['humidity'] as num?)?.toDouble() ?? 0.0,
      currentTimestamp:
          DateTime.tryParse((_latestByMetric!['timestamp'] ?? '').toString()) ??
              DateTime.now(),
    );

    ammoniaState = _createMetricFromSensorData(
      name: 'Amonia',
      unit: 'ppm',
      icon: Icons.science_outlined,
      minY: 0,
      maxY: 100,
      goodBad: (v) => _conditionForAmmonia(v),
      currentValue: (_latestByMetric!['ammonia'] as num?)?.toDouble() ?? 0.0,
      currentTimestamp:
          DateTime.tryParse((_latestByMetric!['timestamp'] ?? '').toString()) ??
              DateTime.now(),
    );

    _initPerFloorLists();
    _initFloorMetricsFromRealData(1);
    _initFloorMetricsFromRealData(
        2); // build metrics for floor 1 & 2 if present
    // Evaluate immediately as well
    _evaluateAndNotifyConditions();
  }

  _MetricState _createMetricFromSensorData({
    required String name,
    required String unit,
    required IconData icon,
    required double minY,
    required double maxY,
    required String Function(double) goodBad,
    required double currentValue,
    required DateTime currentTimestamp,
  }) {
    // Convert sensor data to chart points
    List<FlSpot> points = [];

    // Convert generic reading objects to points using recorded_at & value
    for (int i = 0; i < _sensorData.length && i < 288; i++) {
      final data = _sensorData[_sensorData.length - 1 - i];
      try {
        final ts = DateTime.tryParse(data['recorded_at']?.toString() ?? '') ??
            DateTime.now();
        final value = (data['value'] as num?)?.toDouble() ?? 0.0;
        points.add(FlSpot(ts.millisecondsSinceEpoch.toDouble(), value));
      } catch (e) {
        print('Error parsing reading point: $e');
      }
    }

    final timeStr = _formatTime(currentTimestamp);

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
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_hasDeviceInstalled && _authToken != null) {
        await _loadSensorReadingsFromQuery();
        if (!mounted) return;
        _initMetricsWithRealData();
        _initFloorMetricsFromRealData(1);
        _initFloorMetricsFromRealData(2);
        _evaluateAndNotifyConditions();
      }
    });
  }

  // Check AI anomaly detection for sudden spikes/drops
  Future<void> _evaluateAndNotifyConditions() async {
    if (_authToken == null) return;

    // Only check AI anomaly detection - no notifications for normal condition changes
    await _checkAnomalies();
  }

  /// Check for sensor anomalies using AI
  /// Detects sudden spikes/drops and abnormal readings
  Future<void> _checkAnomalies() async {
    if (!mounted) return;
    if (_authToken == null || _latestByMetric == null) return;

    // Only check if we have valid node IDs
    if (_nodeIds.isEmpty) return;

    try {
      // Prepare sensor data for AI analysis
      final sensorData = {
        'temperature': _latestByMetric?['temperature'],
        'humidity': _latestByMetric?['humidity'],
        'ammonia': _latestByMetric?['ammonia'],
        'co2': _latestByMetric?['co2'] ?? 400, // Default CO2 if not available
        'lux': _latestByMetric?['lux'] ?? 500, // Default lux if not available
      };

      // Use the first node ID for anomaly detection
      final nodeId = _nodeIds.first;

      final anomalyResult = await _aiService.detectAnomaly(
        _authToken!,
        nodeId,
        sensorData,
      );

      if (!mounted) return;

      setState(() {
        _anomalyData = anomalyResult;
        _hasAnomalies = _aiService.hasCriticalAnomalies(anomalyResult);
      });

      // Show notification for ANY anomaly detected (including sudden spikes/drops)
      if (anomalyResult['anomaly_detected'] == true) {
        final anomalies = anomalyResult['anomalies'] as List?;

        if (anomalies != null && anomalies.isNotEmpty) {
          // Get severity level for notification priority
          final hasCritical = anomalies.any((a) =>
              (a['severity'] ?? '').toString().toLowerCase() == 'critical');
          final hasHigh = anomalies.any(
              (a) => (a['severity'] ?? '').toString().toLowerCase() == 'high');

          final severity =
              hasCritical ? 'critical' : (hasHigh ? 'high' : 'medium');

          // Build detailed message from anomalies
          final messages = anomalies.map((a) {
            final sensor = a['sensor'] ?? 'Sensor';
            final value = a['value'] ?? '-';
            final message = a['message'] ?? a['reason'] ?? 'Abnormal reading';
            return '$sensor: $value - $message';
          }).join('\n');

          final title = hasCritical
              ? '🚨 Anomali Kritis Terdeteksi'
              : (hasHigh ? '⚠️ Anomali Terdeteksi' : '⚠️ Perhatian');

          // Show notification with sound for anomalies
          await LocalNotificationHelper().showWithSound(
            title: title,
            body: messages,
            payload: 'ai_anomaly_${DateTime.now().millisecondsSinceEpoch}',
          );

          if (!mounted) return;

          // Add to alerts system
          final synthetic = await _alertService.createLocalSynthetic(
            _authToken!,
            title: 'AI Anomaly Detection',
            message: messages,
            severity: severity,
          );
          _notif.addAlert(synthetic);

          print('[AI ANOMALY] $severity anomaly detected: $messages');
        }
      }
    } catch (e) {
      print('[CONTROL PAGE] Error checking anomalies: $e');
    }
  }

  /// Show detailed anomaly information dialog
  void _showAnomalyDetails() {
    if (_anomalyData == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.psychology, color: Color(0xFF6A1B9A), size: 24),
            SizedBox(width: 8),
            Text(
              'Detail Anomali AI',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_anomalyData!['anomalies'] != null &&
                    (_anomalyData!['anomalies'] as List).isNotEmpty) ...[
                  Text(
                    'Sensor Abnormal:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  ...(_anomalyData!['anomalies'] as List).map((anomaly) {
                    final severity =
                        anomaly['severity']?.toString() ?? 'medium';
                    final color = severity == 'critical' || severity == 'high'
                        ? Colors.red
                        : Colors.orange;

                    return Container(
                      margin: EdgeInsets.only(bottom: 8),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.sensors, color: color, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${anomaly['sensor']}'.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Nilai: ${anomaly['value']}',
                            style: TextStyle(fontSize: 12),
                          ),
                          Text(
                            'Pesan: ${anomaly['message']}',
                            style: TextStyle(fontSize: 12),
                          ),
                          if (anomaly['expected_range'] != null)
                            Text(
                              'Rentang Normal: ${anomaly['expected_range']}',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[600]),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ] else
                  Text(
                    'Tidak ada anomali terdeteksi',
                    style: TextStyle(color: Colors.green),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tutup'),
          ),
        ],
      ),
    );
  }

  // Shared helpers with Home
  String? _classifySensorMetric(Map<String, dynamic> s) {
    final raw = (s['sensor_type'] ?? s['type'] ?? s['name'] ?? s['label'] ?? '')
        .toString()
        .toLowerCase();
    final unit = (s['unit']?.toString() ?? '').toLowerCase();
    const tempKeys = ['temp', 'temperature', 'suhu', 'heat', 'panas'];
    const humidityKeys = ['humid', 'humidity', 'kelembaban', 'lembab'];
    const ammoniaKeys = ['ammon', 'ammonia', 'amonia', 'nh3'];
    bool match(List<String> keys) => keys.any((k) => raw.contains(k));
    if (match(tempKeys) || unit.contains('c')) return 'temperature';
    if (match(humidityKeys) || unit.contains('%')) return 'humidity';
    if (match(ammoniaKeys) || unit.contains('ppm')) return 'ammonia';
    return null;
  }

  DateTime? _pickLatest(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return b.isAfter(a) ? b : a;
  }

  void _stopPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  void _startActuatorTimer() {
    _actuatorTimer?.cancel();
    _actuatorTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      bool needsUpdate = false;

      // Check pump timer
      if (_pumpTimerEnd != null && now.isAfter(_pumpTimerEnd!)) {
        _togglePump(false);
        await TimerBackgroundService.clearTimer('pump');

        // Show notification
        await LocalNotificationHelper().showWithSound(
          title: '⏰ Timer Selesai',
          body:
              'Mist Spray telah dimatikan secara otomatis pada ${_formatTime(now)}',
          payload: 'timer_pump_expired',
        );

        setState(() {
          _pumpTimerEnd = null;
          _pumpNotificationId = null;
        });
        needsUpdate = true;
      }

      // Check audio both timer
      if (_audioBothTimerEnd != null && now.isAfter(_audioBothTimerEnd!)) {
        _toggleAudioBoth(false);
        await TimerBackgroundService.clearTimer('audio_both');

        // Show notification
        await LocalNotificationHelper().showWithSound(
          title: '⏰ Timer Selesai',
          body:
              'Semua Speaker telah dimatikan secara otomatis pada ${_formatTime(now)}',
          payload: 'timer_audio_both_expired',
        );

        setState(() {
          _audioBothTimerEnd = null;
          _audioBothNotificationId = null;
        });
        needsUpdate = true;
      }

      // Check audio LMB timer
      if (_audioLmbTimerEnd != null && now.isAfter(_audioLmbTimerEnd!)) {
        _toggleAudioLmb(false);
        await TimerBackgroundService.clearTimer('audio_lmb');

        // Show notification
        await LocalNotificationHelper().showWithSound(
          title: '⏰ Timer Selesai',
          body:
              'Speaker LMB telah dimatikan secara otomatis pada ${_formatTime(now)}',
          payload: 'timer_audio_lmb_expired',
        );

        setState(() {
          _audioLmbTimerEnd = null;
          _audioLmbNotificationId = null;
        });
        needsUpdate = true;
      }

      // Check audio Nest timer
      if (_audioNestTimerEnd != null && now.isAfter(_audioNestTimerEnd!)) {
        _toggleAudioNest(false);
        await TimerBackgroundService.clearTimer('audio_nest');

        // Show notification
        await LocalNotificationHelper().showWithSound(
          title: '⏰ Timer Selesai',
          body:
              'Speaker Nest telah dimatikan secara otomatis pada ${_formatTime(now)}',
          payload: 'timer_audio_nest_expired',
        );

        setState(() {
          _audioNestTimerEnd = null;
          _audioNestNotificationId = null;
        });
        needsUpdate = true;
      }

      // Update UI to show countdown and update notifications
      if (_pumpTimerEnd != null ||
          _audioBothTimerEnd != null ||
          _audioLmbTimerEnd != null ||
          _audioNestTimerEnd != null) {
        // Update notifications with current countdown every second
        _updateTimerNotifications(now);

        if (mounted) setState(() {});
      } else {
        // No more active timers, stop the UI timer
        timer.cancel();
        _actuatorTimer = null;
      }
    });
  }

  void _stopActuatorTimer() {
    _actuatorTimer?.cancel();
    _actuatorTimer = null;
  }

  /// Update timer notifications with current countdown
  Future<void> _updateTimerNotifications(DateTime now) async {
    // Update pump notification
    if (_pumpTimerEnd != null && _pumpNotificationId != null) {
      final remaining = _pumpTimerEnd!.difference(now);
      if (remaining.inSeconds > 0) {
        await LocalNotificationHelper().show(
          title: '💧 Mist Spray Berjalan',
          body: 'Sisa waktu: ${_formatDuration(remaining)}',
          payload: 'pump_running',
          id: _pumpNotificationId,
        );
      }
    }

    // Update audio both notification
    if (_audioBothTimerEnd != null && _audioBothNotificationId != null) {
      final remaining = _audioBothTimerEnd!.difference(now);
      if (remaining.inSeconds > 0) {
        await LocalNotificationHelper().show(
          title: '🔊 Semua Speaker Berjalan',
          body: 'Sisa waktu: ${_formatDuration(remaining)}',
          payload: 'audio_both_running',
          id: _audioBothNotificationId,
        );
      }
    }

    // Update audio LMB notification
    if (_audioLmbTimerEnd != null && _audioLmbNotificationId != null) {
      final remaining = _audioLmbTimerEnd!.difference(now);
      if (remaining.inSeconds > 0) {
        await LocalNotificationHelper().show(
          title: '🔊 Speaker LMB Berjalan',
          body: 'Sisa waktu: ${_formatDuration(remaining)}',
          payload: 'audio_lmb_running',
          id: _audioLmbNotificationId,
        );
      }
    }

    // Update audio Nest notification
    if (_audioNestTimerEnd != null && _audioNestNotificationId != null) {
      final remaining = _audioNestTimerEnd!.difference(now);
      if (remaining.inSeconds > 0) {
        await LocalNotificationHelper().show(
          title: '🔊 Speaker Nest Berjalan',
          body: 'Sisa waktu: ${_formatDuration(remaining)}',
          payload: 'audio_nest_running',
          id: _audioNestNotificationId,
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}j ${minutes}m ${seconds}d';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}d';
    } else {
      return '${seconds}d';
    }
  }

  Future<void> _showMultiSelectTimerDialog(
      String groupName, List<Map<String, dynamic>> devices) async {
    Set<String> selectedDevices = {};
    int selectedMinutes = 5;
    int selectedSeconds = 0;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Set Timer - $groupName'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pilih perangkat yang akan diatur timer:',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700]),
                ),
                const SizedBox(height: 12),
                ...devices
                    .map((device) => CheckboxListTile(
                          title: Text(device['name'],
                              style: const TextStyle(fontSize: 14)),
                          subtitle: device['subtitle'] != null
                              ? Text(device['subtitle'],
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[600]))
                              : null,
                          value: selectedDevices.contains(device['id']),
                          activeColor: const Color(0xFF245C4C),
                          onChanged: (bool? value) {
                            setDialogState(() {
                              if (value == true) {
                                selectedDevices.add(device['id']);
                              } else {
                                selectedDevices.remove(device['id']);
                              }
                            });
                          },
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ))
                    .toList(),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  height: 1,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'Durasi waktu nyala:',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700]),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Minutes picker
                    Column(
                      children: [
                        Text('Menit',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_drop_up),
                                onPressed: () {
                                  setDialogState(() {
                                    if (selectedMinutes < 60) selectedMinutes++;
                                  });
                                },
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 8),
                                child: Text(
                                  selectedMinutes.toString().padLeft(2, '0'),
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_drop_down),
                                onPressed: () {
                                  setDialogState(() {
                                    if (selectedMinutes > 0) selectedMinutes--;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Text(':',
                        style: TextStyle(
                            fontSize: 32, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 20),
                    // Seconds picker
                    Column(
                      children: [
                        Text('Detik',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[600])),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_drop_up),
                                onPressed: () {
                                  setDialogState(() {
                                    selectedSeconds =
                                        (selectedSeconds + 5) % 60;
                                  });
                                },
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 8),
                                child: Text(
                                  selectedSeconds.toString().padLeft(2, '0'),
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_drop_down),
                                onPressed: () {
                                  setDialogState(() {
                                    selectedSeconds = selectedSeconds - 5 < 0
                                        ? 55
                                        : selectedSeconds - 5;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.timer, size: 16, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Total: ${selectedMinutes}m ${selectedSeconds}d',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedDevices.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pilih minimal 1 perangkat')),
                  );
                  return;
                }
                final totalSeconds = (selectedMinutes * 60) + selectedSeconds;
                if (totalSeconds > 0) {
                  // Apply timer to all selected devices
                  final endTime =
                      DateTime.now().add(Duration(seconds: totalSeconds));
                  setState(() {
                    for (final deviceId in selectedDevices) {
                      if (deviceId == 'pump') {
                        _pumpTimerEnd = endTime;
                        if (_pumpState != true) _togglePump(true);
                        TimerBackgroundService.setTimer(
                          deviceType: 'pump',
                          endTime: endTime,
                          nodeId: _pumpNodeId,
                        );
                      } else if (deviceId == 'audio_both') {
                        _audioBothTimerEnd = endTime;
                        if (_audioBothState != true) _toggleAudioBoth(true);
                        TimerBackgroundService.setTimer(
                          deviceType: 'audio_both',
                          endTime: endTime,
                          nodeId: _audioNodeId,
                        );
                      } else if (deviceId == 'audio_lmb') {
                        _audioLmbTimerEnd = endTime;
                        if (_audioLmbState != true) _toggleAudioLmb(true);
                        TimerBackgroundService.setTimer(
                          deviceType: 'audio_lmb',
                          endTime: endTime,
                          nodeId: _audioNodeId,
                        );
                      } else if (deviceId == 'audio_nest') {
                        _audioNestTimerEnd = endTime;
                        if (_audioNestState != true) _toggleAudioNest(true);
                        TimerBackgroundService.setTimer(
                          deviceType: 'audio_nest',
                          endTime: endTime,
                          nodeId: _audioNodeId,
                        );
                      }
                    }
                  });
                  _startActuatorTimer();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Timer ${selectedMinutes}m ${selectedSeconds}d diatur untuk ${selectedDevices.length} perangkat'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Pilih durasi minimal 5 detik')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF245C4C),
              ),
              child: const Text('Set Timer',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTimerDialog(
      String actuatorName, Function(int) onSetTimer) async {
    int selectedMinutes = 5;
    int selectedSeconds = 0;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Set Timer $actuatorName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pilih durasi waktu nyala',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Minutes picker
                  Column(
                    children: [
                      Text('Menit',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600])),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_drop_up),
                              onPressed: () {
                                setDialogState(() {
                                  if (selectedMinutes < 60) selectedMinutes++;
                                });
                              },
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 8),
                              child: Text(
                                selectedMinutes.toString().padLeft(2, '0'),
                                style: const TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_drop_down),
                              onPressed: () {
                                setDialogState(() {
                                  if (selectedMinutes > 0) selectedMinutes--;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Text(':',
                      style:
                          TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 20),
                  // Seconds picker
                  Column(
                    children: [
                      Text('Detik',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600])),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_drop_up),
                              onPressed: () {
                                setDialogState(() {
                                  selectedSeconds = (selectedSeconds + 5) % 60;
                                });
                              },
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 8),
                              child: Text(
                                selectedSeconds.toString().padLeft(2, '0'),
                                style: const TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_drop_down),
                              onPressed: () {
                                setDialogState(() {
                                  selectedSeconds = selectedSeconds - 5 < 0
                                      ? 55
                                      : selectedSeconds - 5;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.timer, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      'Total: ${selectedMinutes}m ${selectedSeconds}d',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                final totalSeconds = (selectedMinutes * 60) + selectedSeconds;
                if (totalSeconds > 0) {
                  onSetTimer(totalSeconds);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Pilih durasi minimal 5 detik')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF245C4C),
              ),
              child: const Text('Set Timer',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showLoginRequired() {
    // Show login required dialog or redirect to login
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Login Diperlukan'),
          content: const Text(
              'Silakan login terlebih dahulu untuk mengakses fitur kontrol.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacementNamed(context, '/login-page');
              },
              child: const Text('Login'),
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

        if (legacyAddress != null &&
            legacyAddress.isNotEmpty &&
            legacyFloors != null) {
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
        if (_hasDeviceInstalled) {
          await _loadSensorReadingsFromQuery();
          _initMetricsWithRealData();
          _startPeriodicRefresh();
        } else {
          _initDemoData();
        }
      }
    } catch (_) {
      // Use defaults on failure
      if (mounted) {
        setState(() {
          _hasValidKandang = false;
        });
      }
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

  // Initialize real metrics for a given floor from collected readings
  void _initFloorMetricsFromRealData(int floor) {
    final data = _latestByMetricPerFloor[floor];
    if (data == null) return;
    final tempMetric = _MetricState(
      name: 'Suhu Lantai $floor',
      icon: Icons.thermostat,
      unit: '°C',
      minY: 20,
      maxY: 40,
      points: const [],
      currentValue: (data['temperature'] as num?)?.toDouble() ?? 0.0,
      lastTime: _formatTime(
          DateTime.tryParse((data['timestamp'] ?? '').toString()) ??
              DateTime.now()),
      condition:
          _conditionForTemp((data['temperature'] as num?)?.toDouble() ?? 0.0),
    );
    final humidMetric = _MetricState(
      name: 'Kelembapan Lantai $floor',
      icon: Icons.water_drop_outlined,
      unit: '%',
      minY: 30,
      maxY: 100,
      points: const [],
      currentValue: (data['humidity'] as num?)?.toDouble() ?? 0.0,
      lastTime: _formatTime(
          DateTime.tryParse((data['timestamp'] ?? '').toString()) ??
              DateTime.now()),
      condition:
          _conditionForHumidity((data['humidity'] as num?)?.toDouble() ?? 0.0),
    );
    final ammoMetric = _MetricState(
      name: 'Amonia Lantai $floor',
      icon: Icons.science_outlined,
      unit: 'ppm',
      minY: 0,
      maxY: 100,
      points: const [],
      currentValue: (data['ammonia'] as num?)?.toDouble() ?? 0.0,
      lastTime: _formatTime(
          DateTime.tryParse((data['timestamp'] ?? '').toString()) ??
              DateTime.now()),
      condition:
          _conditionForAmmonia((data['ammonia'] as num?)?.toDouble() ?? 0.0),
    );
    if (floor == 1) {
      tempFloor1State = tempMetric;
      humidityFloor1State = humidMetric;
      ammoniaFloor1State = ammoMetric;
    }
    if (floor == 2) {
      tempFloor2State = tempMetric;
      humidityFloor2State = humidMetric;
      ammoniaFloor2State = ammoMetric;
    }
  }

  // Attempt to map node to floor using common keys or parsing code/name
  int? _floorForNode(String? nodeId) {
    if (nodeId == null) return null;
    final node = _nodes.firstWhere(
      (n) => (n['id']?.toString() == nodeId),
      orElse: () => {},
    );
    if (node.isEmpty) return null;
    final candidates = [
      'floor',
      'floor_level',
      'floor_number',
      'level',
      'lantai'
    ];
    for (final k in candidates) {
      if (node[k] != null) {
        final v = int.tryParse(node[k].toString());
        if (v != null) return v;
      }
    }
    final codeLike = (node['code'] ?? node['node_code'] ?? node['name'] ?? '')
        .toString()
        .toLowerCase();
    final match = RegExp(r'(?:f|lantai|floor)[ _-]?(\d)').firstMatch(codeLike);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    // Heuristic: trailing 3 digits like 001 / 002 => use last digit if 1-9
    final trailingDigits = RegExp(r'(\d{3})$').firstMatch(codeLike);
    if (trailingDigits != null) {
      final digits = trailingDigits.group(1)!; // e.g. 001
      final last = digits.substring(digits.length - 1);
      final parsed = int.tryParse(last);
      if (parsed != null && parsed >= 1 && parsed <= 9) return parsed;
    }
    return null;
  }

  // Detect actuator nodes and capture initial states
  void _maybeRegisterActuatorNode(Map<String, dynamic> n) {
    final type = (n['type'] ?? n['node_type'] ?? '').toString().toLowerCase();
    final hasAudio = n['has_audio'] == true;
    final hasPump = n['has_pump'] == true;
    print(
        '[ACTUATOR DEBUG] Node: ${n['id']} type=$type has_audio=$hasAudio has_pump=$hasPump state_audio=${n['state_audio']} state_pump=${n['state_pump']}');

    // Mist Spray / Pump - Enhanced detection for node_type='pump' and has_pump=true
    if (type.contains('pump') ||
        type.contains('mist') ||
        type.contains('spray') ||
        hasPump) {
      _pumpNodeId ??= n['id']?.toString();
      _pumpState ??=
          _extractBoolState(n, ['pump_state', 'state_pump', 'state', 'active']);
      print('[PUMP DETECTED] NodeId=$_pumpNodeId, State=$_pumpState');
    }
    // Audio / Speaker - Check has_audio flag (nest nodes can have audio)
    if (type.contains('audio') ||
        type.contains('tweeter') ||
        type.contains('sound') ||
        type.contains('speaker') ||
        hasAudio) {
      _audioNodeId ??= n['id']?.toString();
      _audioBothState ??= _extractBoolState(
          n, ['state_audio', 'audio_state', 'state', 'active']);
      _audioLmbState ??= _extractBoolState(
          n, ['state_audio_lmb', 'audio_lmb_state', 'lmb_state']);
      _audioNestState ??= _extractBoolState(
          n, ['state_audio_nest', 'audio_nest_state', 'nest_state']);
      print(
          '[AUDIO DETECTED] NodeId=$_audioNodeId, BothState=$_audioBothState, LmbState=$_audioLmbState, NestState=$_audioNestState, NodeType=$type');
    }
  }

  bool? _extractBoolState(Map<String, dynamic> n, List<String> keys) {
    for (final k in keys) {
      if (n[k] != null) {
        final v = n[k];
        print('[BOOL STATE DEBUG] Key=$k, Value=$v, Type=${v.runtimeType}');
        if (v is bool) return v;
        if (v is num) return v != 0;
        if (v is String)
          return ['1', 'true', 'on', 'active'].contains(v.toLowerCase());
      }
    }
    print(
        '[BOOL STATE DEBUG] No matching key found in ${keys.join(', ')} for node keys: ${n.keys.join(', ')}');
    return null;
  }

  Future<void> _togglePump(bool value) async {
    print(
        '[PUMP TOGGLE] Attempting to toggle pump to $value, nodeId=$_pumpNodeId, hasToken=${_authToken != null}');
    if (_pumpNodeId == null || _authToken == null) {
      print('[PUMP TOGGLE ERROR] Missing nodeId or auth token');
      return;
    }
    setState(() {
      _pumpLoading = true;
    });
    try {
      final res =
          await _nodeService.patchPump(_authToken!, _pumpNodeId!, value);
      print('[PUMP TOGGLE] API Response: $res');
      if (res['success'] == true) {
        setState(() {
          _pumpState = value;
          // Clear timer when manually turned off
          if (!value) {
            _pumpTimerEnd = null;
            TimerBackgroundService.clearTimer('pump');
          }
        });

        // Show notification when turned ON
        if (value) {
          final timerInfo = _pumpTimerEnd != null
              ? '\nTimer: ${_formatDuration(_pumpTimerEnd!.difference(DateTime.now()))}'
              : '';
          _pumpNotificationId = DateTime.now().millisecondsSinceEpoch % 100000;
          await LocalNotificationHelper().show(
            title: '💧 Mist Spray Dinyalakan',
            body:
                'Mist Spray telah dinyalakan pada ${_formatTime(DateTime.now())}$timerInfo',
            payload: 'pump_on',
            id: _pumpNotificationId,
          );
        } else {
          // Clear notification when turned off manually
          _pumpNotificationId = null;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Pump berhasil diubah ke ${value ? "ON" : "OFF"}'),
              backgroundColor: Colors.green));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Gagal update pump: ${res['message'] ?? res['statusCode']}')));
        }
      }
    } catch (e) {
      print('[PUMP TOGGLE ERROR] Exception: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error toggling pump: $e')));
      }
    }
    if (mounted)
      setState(() {
        _pumpLoading = false;
      });
  }

  Future<void> _toggleAudioBoth(bool value) async {
    print(
        '[AUDIO BOTH TOGGLE] Attempting to toggle both speakers to $value, nodeId=$_audioNodeId, hasToken=${_authToken != null}');
    if (_audioNodeId == null || _authToken == null) {
      print('[AUDIO BOTH TOGGLE ERROR] Missing nodeId or auth token');
      return;
    }
    setState(() {
      _audioBothLoading = true;
    });
    try {
      // Use call_bird action to activate both speakers (value 1=on, 0=off)
      final action = 'call_bird';
      final actionValue = value ? 1 : 0;

      final res = await _nodeService.controlAudio(
          _authToken!, _audioNodeId!, action, actionValue);
      print('[AUDIO BOTH TOGGLE] API Response: $res');
      if (res['success'] == true) {
        setState(() {
          _audioBothState = value;
          // When both are toggled, update individual states too
          if (value) {
            _audioLmbState = true;
            _audioNestState = true;
          } else {
            // Clear timer when manually turned off
            _audioBothTimerEnd = null;
            TimerBackgroundService.clearTimer('audio_both');
          }
        });

        // Show notification when turned ON
        if (value) {
          final timerInfo = _audioBothTimerEnd != null
              ? '\nTimer: ${_formatDuration(_audioBothTimerEnd!.difference(DateTime.now()))}'
              : '';
          _audioBothNotificationId =
              DateTime.now().millisecondsSinceEpoch % 100000;
          await LocalNotificationHelper().show(
            title: '🔊 Semua Speaker Dinyalakan',
            body:
                'Speaker LMB dan Nest telah dinyalakan pada ${_formatTime(DateTime.now())}$timerInfo',
            payload: 'audio_both_on',
            id: _audioBothNotificationId,
          );
        } else {
          // Clear notification when turned off manually
          _audioBothNotificationId = null;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Kedua Speaker berhasil ${value ? "dinyalakan" : "dimatikan"}'),
              backgroundColor: Colors.green));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Gagal update kedua speaker: ${res['message'] ?? res['statusCode']}')));
        }
      }
    } catch (e) {
      print('[AUDIO BOTH TOGGLE ERROR] Exception: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error toggling both speakers: $e')));
      }
    }
    if (mounted)
      setState(() {
        _audioBothLoading = false;
      });
  }

  Future<void> _toggleAudioLmb(bool value) async {
    print(
        '[AUDIO LMB TOGGLE] Attempting to toggle LMB speaker to $value, nodeId=$_audioNodeId, hasToken=${_authToken != null}');
    if (_audioNodeId == null || _authToken == null) {
      print('[AUDIO LMB TOGGLE ERROR] Missing nodeId or auth token');
      return;
    }
    setState(() {
      _audioLmbLoading = true;
    });
    try {
      // Use audio_set_lmb action with value 1 (on) or 0 (off)
      final action = 'audio_set_lmb';
      final actionValue = value ? 1 : 0;

      final res = await _nodeService.controlAudio(
          _authToken!, _audioNodeId!, action, actionValue);
      print('[AUDIO LMB TOGGLE] API Response: $res');
      if (res['success'] == true) {
        setState(() {
          _audioLmbState = value;
          // Clear timer when manually turned off
          if (!value) {
            _audioLmbTimerEnd = null;
            TimerBackgroundService.clearTimer('audio_lmb');
          }
        });

        // Show notification when turned ON
        if (value) {
          final timerInfo = _audioLmbTimerEnd != null
              ? '\nTimer: ${_formatDuration(_audioLmbTimerEnd!.difference(DateTime.now()))}'
              : '';
          _audioLmbNotificationId =
              DateTime.now().millisecondsSinceEpoch % 100000;
          await LocalNotificationHelper().show(
            title: '🔊 Speaker LMB Dinyalakan',
            body:
                'Speaker LMB telah dinyalakan pada ${_formatTime(DateTime.now())}$timerInfo',
            payload: 'audio_lmb_on',
            id: _audioLmbNotificationId,
          );
        } else {
          // Clear notification when turned off manually
          _audioLmbNotificationId = null;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Speaker LMB berhasil ${value ? "dinyalakan" : "dimatikan"}'),
              backgroundColor: Colors.green));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Gagal update speaker LMB: ${res['message'] ?? res['statusCode']}')));
        }
      }
    } catch (e) {
      print('[AUDIO LMB TOGGLE ERROR] Exception: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error toggling LMB speaker: $e')));
      }
    }
    if (mounted)
      setState(() {
        _audioLmbLoading = false;
      });
  }

  Future<void> _toggleAudioNest(bool value) async {
    print(
        '[AUDIO NEST TOGGLE] Attempting to toggle Nest speaker to $value, nodeId=$_audioNodeId, hasToken=${_authToken != null}');
    if (_audioNodeId == null || _authToken == null) {
      print('[AUDIO NEST TOGGLE ERROR] Missing nodeId or auth token');
      return;
    }
    setState(() {
      _audioNestLoading = true;
    });
    try {
      // Use audio_set_nest action with value 1 (on) or 0 (off)
      final action = 'audio_set_nest';
      final actionValue = value ? 1 : 0;

      final res = await _nodeService.controlAudio(
          _authToken!, _audioNodeId!, action, actionValue);
      print('[AUDIO NEST TOGGLE] API Response: $res');
      if (res['success'] == true) {
        setState(() {
          _audioNestState = value;
          // Clear timer when manually turned off
          if (!value) {
            _audioNestTimerEnd = null;
            TimerBackgroundService.clearTimer('audio_nest');
          }
        });

        // Show notification when turned ON
        if (value) {
          final timerInfo = _audioNestTimerEnd != null
              ? '\nTimer: ${_formatDuration(_audioNestTimerEnd!.difference(DateTime.now()))}'
              : '';
          _audioNestNotificationId =
              DateTime.now().millisecondsSinceEpoch % 100000;
          await LocalNotificationHelper().show(
            title: '🔊 Speaker Nest Dinyalakan',
            body:
                'Speaker Nest telah dinyalakan pada ${_formatTime(DateTime.now())}$timerInfo',
            payload: 'audio_nest_on',
            id: _audioNestNotificationId,
          );
        } else {
          // Clear notification when turned off manually
          _audioNestNotificationId = null;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Speaker Nest berhasil ${value ? "dinyalakan" : "dimatikan"}'),
              backgroundColor: Colors.green));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Gagal update speaker Nest: ${res['message'] ?? res['statusCode']}')));
        }
      }
    } catch (e) {
      print('[AUDIO NEST TOGGLE ERROR] Exception: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error toggling Nest speaker: $e')));
      }
    }
    if (mounted)
      setState(() {
        _audioNestLoading = false;
      });
  }

  // Test methods for audio endpoints
  Future<void> _testAudioEndpoint(String action) async {
    print('[TEST AUDIO] Testing action: $action');
    if (_authToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('No auth token available'),
          backgroundColor: Colors.red));
      return;
    }

    // Use first node if no audio node detected
    final testNodeId =
        _audioNodeId ?? (_nodeIds.isNotEmpty ? _nodeIds.first : null);
    if (testNodeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('No nodes available to test'),
          backgroundColor: Colors.red));
      return;
    }

    setState(() {
      _audioLmbLoading = true;
    });
    try {
      print('[TEST AUDIO] Using node: $testNodeId');
      final res =
          await _nodeService.controlAudio(_authToken!, testNodeId, action, 1);
      print('[TEST AUDIO] Response: $res');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Test $action: ${res['success'] == true ? "SUCCESS" : "FAILED"}\n${res['message'] ?? res['statusCode'] ?? ""}'),
          backgroundColor:
              res['success'] == true ? Colors.green : Colors.orange,
          duration: Duration(seconds: 3),
        ));
      }
    } catch (e) {
      print('[TEST AUDIO] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
    if (mounted)
      setState(() {
        _audioLmbLoading = false;
      });
  }

  Future<void> _testGetAudioState() async {
    print('[TEST AUDIO] Getting audio state');
    if (_authToken == null) return;

    final testNodeId =
        _audioNodeId ?? (_nodeIds.isNotEmpty ? _nodeIds.first : null);
    if (testNodeId == null) return;

    setState(() {
      _audioLmbLoading = true;
    });
    try {
      print('[TEST AUDIO] Getting state for node: $testNodeId');
      final res = await _nodeService.getAudioState(_authToken!, testNodeId);
      print('[TEST AUDIO] Audio state response: $res');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Audio State:\n${res['data']?.toString() ?? res.toString()}'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 4),
        ));
      }
    } catch (e) {
      print('[TEST AUDIO] Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
    if (mounted)
      setState(() {
        _audioLmbLoading = false;
      });
  }

  void _openSensorDetail(
      {required String metric,
      required String? sensorId,
      required String title,
      required String unit,
      int? floor}) {
    if (sensorId == null || sensorId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sensor ID tidak ditemukan untuk $title')));
      return;
    }
    Navigator.pushNamed(context, '/sensor-detail', arguments: {
      'sensorId': sensorId,
      'metric': metric,
      'title': title,
      'unit': unit,
      'floor': floor,
    });
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
    // Convert all displayed times to WIB (UTC+7)
    return TimeUtils.formatWibHHmm(t);
  }

  // Method to manually fetch and display latest three sensor data (DEPRECATED)
  Future<void> fetchAndDisplayLatestThree() async {
    print('\n=== FETCHING SENSOR DATA ===');
    print('Current sensor count: ${_sensors.length}');
    print('Current reading count: ${_sensorData.length}');
    print('========================================\n');
  }

  // Method to test API connection using ONLY readings endpoint
  Future<void> testAPIConnection() async {
    if (_authToken == null) {
      print('No authentication token available');
      return;
    }

    print('\n=== TESTING SENSOR READINGS API ===');

    try {
      for (final s in _sensors.take(3)) {
        final sid = s['id']?.toString();
        if (sid == null) continue;
        final res = await _sensorService
            .getReadings(_authToken!, sid, queryParams: {'limit': '3'});
        final list = res['data'] is List ? res['data'] as List : [];
        print('Sensor $sid -> ${list.length} readings');
      }
    } catch (e) {
      print('API Test Error: $e');
    }

    print('===============================\n');
  } // Navigate to cage selector, then reload cage data

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
            houseId: _selectedHouse!['id'].toString(),
            houseName: _selectedHouse!['name'] ?? 'Kandang',
          ),
        ),
      ).then((_) {
        // Reload device data when returning
        _checkDeviceInstallation();
      });
    }
  }

  /// Show AI Comprehensive Analysis Dialog
  /// Analyzes current environmental conditions using AI Engine with latest sensor data
  Future<void> _showAIAnalysisDialog() async {
    if (_authToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication required for AI analysis'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check if we have sensor data
    if (_latestByMetric == null ||
        _latestByMetric!['temperature'] == null ||
        _latestByMetric!['humidity'] == null ||
        _latestByMetric!['ammonia'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Data sensor tidak tersedia. Tunggu pembacaan sensor terbaru.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoadingAI = true;
    });

    try {
      // Get current sensor values
      final temperature = (_latestByMetric!['temperature'] as num).toDouble();
      final humidity = (_latestByMetric!['humidity'] as num).toDouble();
      final ammonia = (_latestByMetric!['ammonia'] as num).toDouble();

      print(
          '[AI ANALYSIS] Analyzing with current sensor data: T=$temperature H=$humidity A=$ammonia');

      // Get AI comprehensive analysis with current sensor data
      final analysis = await _aiService.getComprehensiveAnalysis(
        _authToken!,
        temperature: temperature,
        humidity: humidity,
        ammonia: ammonia,
        rbwId: _selectedHouse?['id']?.toString(),
        nodeId: _pumpNodeId,
      );

      setState(() {
        _aiAnalysis = analysis;
        _isLoadingAI = false;

        // Extract health scores from analysis for sensor badges
        _overallHealthScore =
            (analysis['overall_health_score'] as num?)?.toDouble();
        if (analysis['sensors'] != null) {
          final sensors = analysis['sensors'] as Map<String, dynamic>;
          _tempHealthScore =
              (sensors['temperature']?['health_score'] as num?)?.toDouble();
          _humidityHealthScore =
              (sensors['humidity']?['health_score'] as num?)?.toDouble();
          _ammoniaHealthScore =
              (sensors['ammonia']?['health_score'] as num?)?.toDouble();
        }

        print(
            '[AI ANALYSIS] Health scores - Overall: $_overallHealthScore, Temp: $_tempHealthScore, Humidity: $_humidityHealthScore, Ammonia: $_ammoniaHealthScore');
      });

      if (!mounted) return;

      // Show AI analysis results in dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.psychology,
                color: const Color(0xFF6A1B9A),
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Analisis AI',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Overall Health Score
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _getHealthScoreColor(
                        (_aiAnalysis?['overall_health_score'] as num?)
                                ?.toDouble() ??
                            0.0,
                      ).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getHealthScoreColor(
                          (_aiAnalysis?['overall_health_score'] as num?)
                                  ?.toDouble() ??
                              0.0,
                        ),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Skor Kesehatan Keseluruhan',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(_aiAnalysis?['overall_health_score'] as num?)?.toStringAsFixed(1) ?? '0.0'}/100',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: _getHealthScoreColor(
                              (_aiAnalysis?['overall_health_score'] as num?)
                                      ?.toDouble() ??
                                  0.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Sensor Status
                  if (_aiAnalysis?['sensors'] != null) ...[
                    const Text(
                      'Status Sensor:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._buildSensorStatusList(_aiAnalysis!['sensors']),
                  ],

                  const SizedBox(height: 16),

                  // Recommendations
                  if (_aiAnalysis?['recommendations'] != null &&
                      (_aiAnalysis!['recommendations'] as List).isNotEmpty) ...[
                    const Text(
                      'Rekomendasi:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...(_aiAnalysis!['recommendations'] as List).map((rec) {
                      final priority = rec['priority'] ?? 'info';
                      final color = _getRecommendationColor(priority);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: color.withOpacity(0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _getRecommendationIcon(priority),
                              color: color,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                rec['message'] ?? rec.toString(),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],

                  // Pump Recommendation
                  if (_aiAnalysis?['pump_recommendation'] != null) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Rekomendasi Pompa:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.water_drop,
                                  color: Colors.blue, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Status: ${_aiAnalysis!['pump_recommendation']['pump_state']}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (_aiAnalysis!['pump_recommendation']
                                  ['duration_minutes'] !=
                              null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, left: 26),
                              child: Text(
                                'Durasi: ${_aiAnalysis!['pump_recommendation']['duration_minutes']} menit',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],

                  // Grade Prediction - Harvest Quality
                  if (_aiAnalysis?['grade_prediction'] != null) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Prediksi Kualitas Panen:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final grade = (_aiAnalysis!['grade_prediction']['grade']
                                    as String?)
                                ?.toLowerCase() ??
                            'unknown';
                        final confidence = (_aiAnalysis!['grade_prediction']
                                    ['confidence'] as num?)
                                ?.toDouble() ??
                            0.0;

                        // Color coding based on grade
                        Color gradeColor;
                        IconData gradeIcon;
                        String gradeText;
                        String gradeDescription;

                        switch (grade) {
                          case 'bagus':
                            gradeColor = Colors.green;
                            gradeIcon = Icons.check_circle;
                            gradeText = 'BAGUS';
                            gradeDescription =
                                'Kondisi optimal untuk panen berkualitas tinggi';
                            break;
                          case 'sedang':
                            gradeColor = Colors.amber;
                            gradeIcon = Icons.info;
                            gradeText = 'SEDANG';
                            gradeDescription =
                                'Kondisi cukup baik, pertimbangkan perbaikan';
                            break;
                          case 'buruk':
                            gradeColor = Colors.red;
                            gradeIcon = Icons.warning;
                            gradeText = 'BURUK';
                            gradeDescription =
                                'Perbaiki kondisi lingkungan sebelum panen';
                            break;
                          default:
                            gradeColor = Colors.grey;
                            gradeIcon = Icons.help;
                            gradeText = 'TIDAK DIKETAHUI';
                            gradeDescription =
                                'Tidak dapat menentukan kualitas';
                        }

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: gradeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: gradeColor, width: 2),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(gradeIcon, color: gradeColor, size: 24),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Kualitas: $gradeText',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: gradeColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          gradeDescription,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tingkat Keyakinan: ${(confidence * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _isLoadingAI = false;
      });

      print('[AI ANALYSIS] Error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mendapatkan analisis AI: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Build sensor status list for AI analysis dialog
  List<Widget> _buildSensorStatusList(Map<String, dynamic> sensors) {
    List<Widget> widgets = [];

    sensors.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        final status = value['status'] ?? 'unknown';
        final statusColor = _getSensorStatusColor(status);

        widgets.add(
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  _getSensorIcon(key),
                  color: statusColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getSensorLabel(key),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${value['value']} ${value['unit'] ?? ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    });

    return widgets;
  }

  /// Get color based on health score
  Color _getHealthScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.amber;
    return Colors.red;
  }

  /// Get color based on sensor status
  Color _getSensorStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'optimal':
        return Colors.green;
      case 'normal':
        return Colors.blue;
      case 'low':
      case 'high':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  /// Get sensor icon
  IconData _getSensorIcon(String sensorType) {
    switch (sensorType.toLowerCase()) {
      case 'temperature':
        return Icons.thermostat;
      case 'humidity':
        return Icons.water_drop;
      case 'ammonia':
        return Icons.air;
      default:
        return Icons.sensors;
    }
  }

  /// Get sensor label
  String _getSensorLabel(String sensorType) {
    switch (sensorType.toLowerCase()) {
      case 'temperature':
        return 'Suhu';
      case 'humidity':
        return 'Kelembaban';
      case 'ammonia':
        return 'Amonia';
      default:
        return sensorType;
    }
  }

  /// Get recommendation color based on priority
  Color _getRecommendationColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.amber;
      default:
        return Colors.blue;
    }
  }

  /// Get recommendation icon based on priority
  IconData _getRecommendationIcon(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return Icons.error;
      case 'high':
        return Icons.warning;
      case 'medium':
        return Icons.info;
      default:
        return Icons.lightbulb;
    }
  }

  @override
  void dispose() {
    _stopPeriodicRefresh();
    _stopActuatorTimer();
    // Don't stop background service - it should continue running
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print(
        '[UI DEBUG] Actuator states - PumpNodeId: $_pumpNodeId, AudioNodeId: $_audioNodeId, HasValidKandang: $_hasValidKandang, HasDeviceInstalled: $_hasDeviceInstalled');
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
      body: _hasValidKandang
          ? (_hasDeviceInstalled
              ? SingleChildScrollView(
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
                                SizedBox(
                                  width: min(1, (width / 6))
                                      .toDouble(), // visual separator dot if very small screen
                                  height: 0,
                                ),
                                // Test notification button
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    await LocalNotificationHelper()
                                        .showWithSound(
                                      title: '🔔 Test Notification',
                                      body:
                                          'Notification berhasil! Timer akan menampilkan notifikasi seperti ini.',
                                      payload: 'test',
                                    );
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Notification sent! Check your notification panel.'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.notifications_active,
                                      size: 18),
                                  label: const Text('Test'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
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
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[700]),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Last Update: ' +
                                        (_latestSensorData != null
                                            ? _formatTime(DateTime.tryParse(
                                                    (_latestSensorData![
                                                                'recorded_at'] ??
                                                            '')
                                                        .toString()) ??
                                                DateTime.now())
                                            : 'No data'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _isLoading
                                      ? null
                                      : () async {
                                          setState(() {
                                            _isLoading = true;
                                          });
                                          try {
                                            await _loadSensorReadingsFromQuery();
                                            if (_sensorData.isNotEmpty) {
                                              _initMetricsWithRealData();
                                              setState(() {
                                                _hasDeviceInstalled = true;
                                              });
                                            } else {
                                              _initDemoData();
                                            }
                                            await testAPIConnection();
                                            if (mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      'Sensor data updated! Found ${_sensorData.length} data points.'),
                                                  duration: const Duration(
                                                      seconds: 3),
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                      'Error updating sensor data: $e'),
                                                  duration: const Duration(
                                                      seconds: 3),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                          if (mounted) {
                                            setState(() {
                                              _isLoading = false;
                                            });
                                          }
                                        },
                                  icon: _isLoading
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))
                                      : const Icon(Icons.refresh, size: 14),
                                  label: Text(
                                      _isLoading ? 'Loading...' : 'Refresh',
                                      style: const TextStyle(fontSize: 11)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF245C4C),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // AI Anomaly Warning Banner
                      if (_hasAnomalies && _anomalyData != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: Colors.red[300]!, width: 2),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded,
                                      color: Colors.red[700], size: 24),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '⚠️ Anomali Terdeteksi oleh AI',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red[700],
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.close,
                                        size: 18, color: Colors.red[700]),
                                    onPressed: () {
                                      setState(() {
                                        _hasAnomalies = false;
                                      });
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _aiService.getAnomalySummary(_anomalyData!),
                                style: TextStyle(
                                    fontSize: 12, color: Colors.red[800]),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () {
                                    _showAnomalyDetails();
                                  },
                                  icon: Icon(Icons.info_outline, size: 16),
                                  label: Text('Detail'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red[700],
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Section 1b: Floor 1 Sensors
                      if (tempFloor1State != null ||
                          humidityFloor1State != null ||
                          ammoniaFloor1State != null) ...[
                        _sectionCard(
                          title: 'Sensor Lantai 1',
                          child: Column(
                            children: [
                              if (tempFloor1State != null)
                                _metricRow(tempFloor1State!,
                                    sensorType: 'temperature', onTap: () {
                                  final sid = (_latestByMetricPerFloor[1]
                                          ?['temperatureSensorId']
                                      ?.toString());
                                  _openSensorDetail(
                                      metric: 'temperature',
                                      sensorId: sid,
                                      title: 'Suhu',
                                      unit: '°C',
                                      floor: 1);
                                })
                              else
                                _buildLoadingMetric(
                                    'Suhu Lantai 1', Icons.thermostat),
                              const SizedBox(height: 12),
                              if (humidityFloor1State != null)
                                _metricRow(humidityFloor1State!,
                                    sensorType: 'humidity', onTap: () {
                                  final sid = (_latestByMetricPerFloor[1]
                                          ?['humiditySensorId']
                                      ?.toString());
                                  _openSensorDetail(
                                      metric: 'humidity',
                                      sensorId: sid,
                                      title: 'Kelembapan',
                                      unit: '%',
                                      floor: 1);
                                })
                              else
                                _buildLoadingMetric('Kelembapan Lantai 1',
                                    Icons.water_drop_outlined),
                              const SizedBox(height: 12),
                              if (ammoniaFloor1State != null)
                                _metricRow(ammoniaFloor1State!,
                                    sensorType: 'ammonia', onTap: () {
                                  final sid = (_latestByMetricPerFloor[1]
                                          ?['ammoniaSensorId']
                                      ?.toString());
                                  _openSensorDetail(
                                      metric: 'ammonia',
                                      sensorId: sid,
                                      title: 'Amonia',
                                      unit: 'ppm',
                                      floor: 1);
                                })
                              else
                                _buildLoadingMetric(
                                    'Amonia Lantai 1', Icons.science_outlined),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Section 1c: Floor 2 Sensors
                      if (tempFloor2State != null ||
                          humidityFloor2State != null ||
                          ammoniaFloor2State != null) ...[
                        _sectionCard(
                          title: 'Sensor Lantai 2',
                          child: Column(
                            children: [
                              if (tempFloor2State != null)
                                _metricRow(tempFloor2State!,
                                    sensorType: 'temperature', onTap: () {
                                  final sid = (_latestByMetricPerFloor[2]
                                          ?['temperatureSensorId']
                                      ?.toString());
                                  _openSensorDetail(
                                      metric: 'temperature',
                                      sensorId: sid,
                                      title: 'Suhu',
                                      unit: '°C',
                                      floor: 2);
                                })
                              else
                                _buildLoadingMetric(
                                    'Suhu Lantai 2', Icons.thermostat),
                              const SizedBox(height: 12),
                              if (humidityFloor2State != null)
                                _metricRow(humidityFloor2State!,
                                    sensorType: 'humidity', onTap: () {
                                  final sid = (_latestByMetricPerFloor[2]
                                          ?['humiditySensorId']
                                      ?.toString());
                                  _openSensorDetail(
                                      metric: 'humidity',
                                      sensorId: sid,
                                      title: 'Kelembapan',
                                      unit: '%',
                                      floor: 2);
                                })
                              else
                                _buildLoadingMetric('Kelembapan Lantai 2',
                                    Icons.water_drop_outlined),
                              const SizedBox(height: 12),
                              if (ammoniaFloor2State != null)
                                _metricRow(ammoniaFloor2State!,
                                    sensorType: 'ammonia', onTap: () {
                                  final sid = (_latestByMetricPerFloor[2]
                                          ?['ammoniaSensorId']
                                      ?.toString());
                                  _openSensorDetail(
                                      metric: 'ammonia',
                                      sensorId: sid,
                                      title: 'Amonia',
                                      unit: 'ppm',
                                      floor: 2);
                                })
                              else
                                _buildLoadingMetric(
                                    'Amonia Lantai 2', Icons.science_outlined),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Section: Mist Spray Actuator
                      if (_pumpNodeId != null) ...[
                        _sectionCard(
                          title: 'Aktuator',
                          action: TextButton.icon(
                            onPressed: () {
                              _showMultiSelectTimerDialog('Aktuator', [
                                {
                                  'id': 'pump',
                                  'name': 'Mist Spray',
                                  'subtitle': 'Alat penyemprot kabut'
                                },
                              ]);
                            },
                            icon: const Icon(Icons.timer, size: 16),
                            label: const Text('Set Timer',
                                style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF245C4C),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                            ),
                          ),
                          child: Column(
                            children: [
                              _actuatorRow(
                                name: 'Mist Spray',
                                icon: Icons.waterfall_chart,
                                value: _pumpState ?? false,
                                loading: _pumpLoading,
                                onChanged: (v) => _togglePump(v),
                              ),
                              if (_pumpTimerEnd != null &&
                                  DateTime.now().isBefore(_pumpTimerEnd!)) ...[
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.orange[50],
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                              color: Colors.orange[200]!),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.timer,
                                                size: 14,
                                                color: Colors.orange[700]),
                                            const SizedBox(width: 4),
                                            Text(
                                              _formatDuration(_pumpTimerEnd!
                                                  .difference(DateTime.now())),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Section: Speaker Controls
                      if (_audioNodeId != null) ...[
                        _sectionCard(
                          title: 'Speaker',
                          action: TextButton.icon(
                            onPressed: () {
                              _showMultiSelectTimerDialog('Speaker', [
                                {
                                  'id': 'audio_both',
                                  'name': 'All Speaker',
                                  'subtitle': 'Kedua speaker sekaligus'
                                },
                                {
                                  'id': 'audio_lmb',
                                  'name': 'Speaker LMB',
                                  'subtitle': 'Speaker sarang burung'
                                },
                                {
                                  'id': 'audio_nest',
                                  'name': 'Speaker Nest',
                                  'subtitle': 'Speaker area nest'
                                },
                              ]);
                            },
                            icon: const Icon(Icons.timer, size: 16),
                            label: const Text('Set Timer',
                                style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF245C4C),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                            ),
                          ),
                          child: Column(
                            children: [
                              _actuatorRow(
                                name: 'All Speaker',
                                icon: Icons.speaker_group,
                                value: _audioBothState ?? false,
                                loading: _audioBothLoading,
                                onChanged: (v) => _toggleAudioBoth(v),
                              ),
                              if (_audioBothTimerEnd != null &&
                                  DateTime.now()
                                      .isBefore(_audioBothTimerEnd!)) ...[
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.orange[50],
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                              color: Colors.orange[200]!),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.timer,
                                                size: 14,
                                                color: Colors.orange[700]),
                                            const SizedBox(width: 4),
                                            Text(
                                              _formatDuration(
                                                  _audioBothTimerEnd!
                                                      .difference(
                                                          DateTime.now())),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 12),
                              _actuatorRow(
                                name: 'Speaker LMB',
                                icon: Icons.volume_up,
                                value: _audioLmbState ?? false,
                                loading: _audioLmbLoading,
                                onChanged: (v) => _toggleAudioLmb(v),
                              ),
                              if (_audioLmbTimerEnd != null &&
                                  DateTime.now()
                                      .isBefore(_audioLmbTimerEnd!)) ...[
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.orange[50],
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                              color: Colors.orange[200]!),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.timer,
                                                size: 14,
                                                color: Colors.orange[700]),
                                            const SizedBox(width: 4),
                                            Text(
                                              _formatDuration(_audioLmbTimerEnd!
                                                  .difference(DateTime.now())),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 12),
                              _actuatorRow(
                                name: 'Speaker Nest',
                                icon: Icons.surround_sound,
                                value: _audioNestState ?? false,
                                loading: _audioNestLoading,
                                onChanged: (v) => _toggleAudioNest(v),
                              ),
                              if (_audioNestTimerEnd != null &&
                                  DateTime.now()
                                      .isBefore(_audioNestTimerEnd!)) ...[
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.orange[50],
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                              color: Colors.orange[200]!),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.timer,
                                                size: 14,
                                                color: Colors.orange[700]),
                                            const SizedBox(width: 4),
                                            Text(
                                              _formatDuration(
                                                  _audioNestTimerEnd!
                                                      .difference(
                                                          DateTime.now())),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // AI Analysis Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed:
                                _isLoadingAI ? null : _showAIAnalysisDialog,
                            icon: _isLoadingAI
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.psychology, size: 20),
                            label: Text(
                              _isLoadingAI ? 'Loading...' : 'Analyze With AI',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  const Color(0xFF6A1B9A), // Purple for AI
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // TEST SECTION: Audio Controls (for debugging)

                      // Section 2: Sistem Suara per-floor

                      // Section 3: Water Level per-floor
                      // _sectionCard(
                      //   title: 'Water Level',
                      //   child: Column(
                      //     children: [
                      //       if (waterLevelPerFloor.isNotEmpty)
                      //         for (final w in waterLevelPerFloor) ...[
                      //           _metricRow(w),
                      //           const SizedBox(height: 12),
                      //         ]
                      //       else
                      //         _buildLoadingMetric('Water Level', Icons.water_drop),
                      //     ],
                      //   ),
                      // ),
                      // const SizedBox(height: 80),
                    ],
                  ),
                )
              : _buildNoDeviceState())
          : _buildEmptyState(),
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
                icon: Icons.devices,
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
              'Anda perlu menginstall device/sensor terlebih dahulu di kandang "$_cageName" untuk menggunakan fitur kontrol',
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

  Widget _sectionCard(
      {required String title, required Widget child, Widget? action}) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF245C4C),
                ),
              ),
              if (action != null) action,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  /// Helper to get anomaly info for a specific sensor
  Map<String, dynamic>? _getAnomalyForSensor(String sensorType) {
    if (_anomalyData == null || _anomalyData!['anomalies'] == null) {
      return null;
    }

    final anomalies = _anomalyData!['anomalies'] as List;
    for (var anomaly in anomalies) {
      final sensor = anomaly['sensor']?.toString().toLowerCase() ?? '';
      // Match temperature, humidity, ammonia
      if (sensor.contains(sensorType.toLowerCase())) {
        return anomaly;
      }
    }
    return null;
  }

  Widget _metricRow(_MetricState m,
      {VoidCallback? onTap, double? healthScore, String? sensorType}) {
    final anomaly =
        sensorType != null ? _getAnomalyForSensor(sensorType) : null;
    final hasAnomaly = anomaly != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                    child:
                        Icon(m.icon, color: const Color(0xFF245C4C), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                m.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF245C4C),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (healthScore != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getHealthScoreColor(healthScore)
                                      .withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _getHealthScoreColor(healthScore),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.favorite,
                                      size: 10,
                                      color: _getHealthScoreColor(healthScore),
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${healthScore.toInt()}',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            _getHealthScoreColor(healthScore),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
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
                    // Show full precision (as provided by server, without forced rounding)
                    '${m.currentValue.toString()} ${m.unit}',
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (hasAnomaly) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (anomaly['severity']?.toString() ==
                                          'critical' ||
                                      anomaly['severity']?.toString() == 'high')
                                  ? Colors.red
                                  : Colors.orange,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.warning_rounded,
                                size: 10,
                                color: (anomaly['severity']?.toString() ==
                                            'critical' ||
                                        anomaly['severity']?.toString() ==
                                            'high')
                                    ? Colors.red
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'Anomali',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: (anomaly['severity']?.toString() ==
                                              'critical' ||
                                          anomaly['severity']?.toString() ==
                                              'high')
                                      ? Colors.red
                                      : Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      _conditionChip(m.condition),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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

Widget _actuatorRow(
    {required String name,
    required IconData icon,
    required bool value,
    required bool loading,
    required ValueChanged<bool> onChanged}) {
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.grey[50],
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.grey[200]!),
    ),
    child: Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF245C4C).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF245C4C), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF245C4C),
                  ),
                ),
              ),
            ],
          ),
        ),
        loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Switch(
                value: value,
                activeColor: const Color(0xFF245C4C),
                onChanged: (v) => onChanged(v),
              ),
      ],
    ),
  );
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
