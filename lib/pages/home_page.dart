import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:swiftlead/pages/analysis_alternate_page.dart';
import 'package:swiftlead/shared/theme.dart';
import 'package:swiftlead/pages/blog_page.dart';
import 'package:swiftlead/pages/blog_menu.dart';
import 'package:swiftlead/components/custom_bottom_navigation.dart';
import 'package:swiftlead/pages/cage_selection_page.dart';
import 'package:swiftlead/services/house_services.dart';
import 'package:swiftlead/services/node_service.dart';
import 'package:swiftlead/services/sensor_services.dart';
import 'package:swiftlead/services/harvest_service.dart';
import 'package:fl_chart/fl_chart.dart';




import 'package:swiftlead/services/auth_services.dart.dart';
import 'package:swiftlead/services/service_request_service.dart';
import 'package:swiftlead/utils/token_manager.dart';
import 'package:swiftlead/utils/time_utils.dart';
import 'package:swiftlead/pages/device_installation_page.dart'; // Still used for creating installation service-requests
import 'dart:async';
import 'package:swiftlead/services/alert_service.dart';
import 'package:swiftlead/utils/notification_manager.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  double width(BuildContext context) => MediaQuery.of(context).size.width;
  double height(BuildContext context) => MediaQuery.of(context).size.height;

  int _currentIndex = 0;
  final PageController _pageController = PageController();
  int _currentKandangIndex = 0;


  final HouseService _houseService = HouseService();
  final NodeService _nodeService = NodeService();
  final SensorService _sensorService = SensorService();
  final HarvestService _harvestService = HarvestService();
  final AuthService _authService = AuthService();





  bool _isLoading = true;
  String? _authToken;
  final AlertService _alertService = AlertService();
  final NotificationManager _notif = NotificationManager();

  // User profile data
  String? _userName;
  String? _userEmail;
  String? _userAvatarUrl;

  // Harvest statistics for current month
  double _currentMonthHarvest = 0.0;
  double _averagePerHouse = 0.0;
  int _harvestCount = 0;
  
  // Harvest breakdown by nest type
  Map<String, double> _harvestBreakdown = {
    'mangkok': 0.0,
    'sudut': 0.0,
    'oval': 0.0,
    'patahan': 0.0,
  };

  // Market price constant (7.1g per nest)
  static const double GRAMS_PER_NEST = 7.1;
  
  // Market price data by nest type (price per kg)
  final Map<String, double> _nestTypePrices = {
    'Mangkok Putih Kapas': 7930000,
    'Oval Putih Kapas': 6980000,
    'Sudut Putih Kapas': 5997000,
    'Patahan Putih Kapas': 3930000,
  };
  
  // Selected nest type and unit
  String _selectedNestType = 'Mangkok Putih Kapas';
  String _selectedUnit = 'Kg'; // 'Kg' or 'Gram'
  
  // Format number to Indonesian rupiah format (7.930.000 for millions)
  String _formatRupiah(double amount, {bool showDecimals = false}) {
    if (showDecimals) {
      // Split integer and decimal parts
      final parts = amount.toStringAsFixed(2).split('.');
      // Format integer part with dots as thousand separator
      final integerPart = parts[0].replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      );
      // Use comma as decimal separator (Indonesian format)
      return '$integerPart,${parts[1]}';
    } else {
      // Format whole number with dots as thousand separator
      final rounded = amount.round();
      return rounded.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      );
    }
  }


  List<Map<String, dynamic>> _kandangList = [];


  Timer? _refreshTimer;


  final Map<String, dynamic> _fallbackDeviceData = {
    'temperature': null,
    'humidity': null,
    'ammonia': null,
    'mist_spray': 'Inactive',
    'speaker': 'Inactive',
  };


  final List<Map<String, dynamic>> _defaultHarvestCycle = [
    {'month': 'Jan', 'status': 'Complete', 'yield': '12kg'},
    {'month': 'Feb', 'status': 'Complete', 'yield': '15kg'},
    {'month': 'Mar', 'status': 'Complete', 'yield': '18kg'},
    {'month': 'Apr', 'status': 'In Progress', 'yield': '-'},
    {'month': 'May', 'status': 'Planned', 'yield': '-'},
    {'month': 'Jun', 'status': 'Planned', 'yield': '-'},
    {'month': 'Jul', 'status': 'Planned', 'yield': '-'},
    {'month': 'Aug', 'status': 'Planned', 'yield': '-'},
    {'month': 'Sep', 'status': 'Planned', 'yield': '-'},
    {'month': 'Oct', 'status': 'Planned', 'yield': '-'},
    {'month': 'Nov', 'status': 'Planned', 'yield': '-'},
    {'month': 'Dec', 'status': 'Planned', 'yield': '-'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {

      print('[HOME] App resumed, refreshing data...');
      if (_authToken != null && mounted) {
        _refreshSensorDataOnly();
      }
    }
  }

  Future<void> _showAlertsDialog() async {
    await _loadAlerts();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Notifikasi'),
          content: SizedBox(
            width: double.maxFinite,
            child: ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: _notif.alerts,
              builder: (context, list, _) {
                if (list.isEmpty) return const Text('Tidak ada notifikasi');
                return SingleChildScrollView(
                  child: Column(
                    children: list.map((a) {
                      final isUnread = !(a['is_read'] == true);
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          a['title']?.toString() ?? 'Alert',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isUnread ? Colors.black : Colors.black54,
                          ),
                        ),
                        subtitle: Text(a['message']?.toString() ?? ''),
                        trailing: isUnread ? const Icon(Icons.fiber_new, color: Colors.redAccent, size: 16) : null,
                        onTap: () async {
                          if (_authToken != null && a['synthetic'] != true) {
                            try { await _alertService.markRead(_authToken!, a['id'].toString()); } catch (_) {}
                          }
                          _notif.markRead(a['id'].toString());
                        },
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _initializeData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    
    try {

      _authToken = await TokenManager.getToken();
      
      if (_authToken != null) {
        // Load user profile
        await _loadUserProfile().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print('User profile API timeout');
          },
        );

        await _loadKandangFromAPI().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            print('Kandang API timeout after 30s - continuing with partial data');
          },
        );

        // Load harvest statistics for current month
        await _loadHarvestStatistics().timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            print('Harvest statistics API timeout');
          },
        );

        await _loadAlerts().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            print('Alerts API timeout');
          },
        );
      }
      

      if (_kandangList.isEmpty) {
        print('No kandang data loaded from API');
      } else {
        print('Successfully loaded ${_kandangList.length} kandang from API');

        _startPeriodicRefresh();
      }
    } catch (e) {
      print('Error initializing data: $e');

    } finally {

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadAlerts() async {
    if (_authToken == null) return;
    try {
      final allRes = await _alertService.list(_authToken!, unreadOnly: false, perPage: 50);
      final allList = (allRes['data'] is List) ? List<Map<String, dynamic>>.from(allRes['data']) : <Map<String, dynamic>>[];
      _notif.replaceAll(allList);
    } catch (e) {

    }
  }

  Future<void> _loadUserProfile() async {
    if (_authToken == null) return;
    try {
      final profileRes = await _authService.getProfile(_authToken!);
      if (profileRes['success'] == true && profileRes['data'] != null) {
        final userData = profileRes['data'];
        if (mounted) {
          setState(() {
            _userName = userData['name']?.toString() ?? 'User';
            _userEmail = userData['email']?.toString() ?? '';
            _userAvatarUrl = userData['avatar_url']?.toString();
          });
        }
        print('[HOME] Loaded user profile: $_userName ($_userEmail)');
      }
    } catch (e) {
      print('[HOME] Error loading user profile: $e');
    }
  }

  Future<void> _loadHarvestStatistics() async {
    if (_authToken == null) return;
    try {
      final now = DateTime.now();
      final currentMonth = now.month;
      final currentYear = now.year;

      // Get all harvests for the current month
      final harvestRes = await _harvestService.list(
        token: _authToken!,
        queryParams: {
          'per_page': '1000',
        },
      );

      if (harvestRes['success'] == true && harvestRes['data'] != null) {
        final List<dynamic> allHarvests = harvestRes['data'] as List<dynamic>;

        double totalNests = 0.0;
        int count = 0;
        
        // Breakdown by nest type
        double mangkok = 0.0;
        double sudut = 0.0;
        double oval = 0.0;
        double patahan = 0.0;

        for (var harvest in allHarvests) {
          // Parse harvest date
          DateTime? harvestDate;
          if (harvest['harvest_date'] != null) {
            harvestDate = DateTime.tryParse(harvest['harvest_date']);
          }
          if (harvestDate == null && harvest['harvested_at'] != null) {
            harvestDate = DateTime.tryParse(harvest['harvested_at']);
          }

          // Check if harvest is in current month
          if (harvestDate != null &&
              harvestDate.month == currentMonth &&
              harvestDate.year == currentYear) {
            // Only count post-harvest (exclude PRE_HARVEST_PLAN)
            final notes = (harvest['notes'] as String?) ?? '';
            if (!notes.startsWith('PRE_HARVEST_PLAN')) {
              final nestsCount = (harvest['nests_count'] as num?)?.toDouble() ?? 0.0;
              if (nestsCount > 0) {
                totalNests += nestsCount;
                count++;
                
                // Parse breakdown from notes
                if (notes.contains('Mangkok:') || notes.contains('Sudut:') || 
                    notes.contains('Oval:') || notes.contains('Patahan:')) {
                  // Extract nest type counts from notes
                  final mangkokMatch = RegExp(r'Mangkok:\s*(\d+(?:\.\d+)?)').firstMatch(notes);
                  final sudutMatch = RegExp(r'Sudut:\s*(\d+(?:\.\d+)?)').firstMatch(notes);
                  final ovalMatch = RegExp(r'Oval:\s*(\d+(?:\.\d+)?)').firstMatch(notes);
                  final patahanMatch = RegExp(r'Patahan:\s*(\d+(?:\.\d+)?)').firstMatch(notes);
                  
                  if (mangkokMatch != null) {
                    mangkok += double.tryParse(mangkokMatch.group(1) ?? '0') ?? 0.0;
                  }
                  if (sudutMatch != null) {
                    sudut += double.tryParse(sudutMatch.group(1) ?? '0') ?? 0.0;
                  }
                  if (ovalMatch != null) {
                    oval += double.tryParse(ovalMatch.group(1) ?? '0') ?? 0.0;
                  }
                  if (patahanMatch != null) {
                    patahan += double.tryParse(patahanMatch.group(1) ?? '0') ?? 0.0;
                  }
                } else {
                  // If no breakdown, add to mangkok as default
                  mangkok += nestsCount;
                }
              }
            }
          }
        }

        // Calculate average per house
        double avgPerHouse = _kandangList.isNotEmpty
            ? totalNests / _kandangList.length
            : 0.0;

        if (mounted) {
          setState(() {
            _currentMonthHarvest = totalNests;
            _averagePerHouse = avgPerHouse;
            _harvestCount = count;
            _harvestBreakdown = {
              'mangkok': mangkok,
              'sudut': sudut,
              'oval': oval,
              'patahan': patahan,
            };
          });
        }
        print('[HOME] Loaded harvest stats: Total=$totalNests nests, Count=$count, Avg/house=$avgPerHouse');
        print('[HOME] Breakdown: M=$mangkok, S=$sudut, O=$oval, P=$patahan');
      }
    } catch (e) {
      print('[HOME] Error loading harvest statistics: $e');
    }
  }

  Future<void> _loadKandangFromAPI() async {
    try {
      print('Loading houses from API...');
      final houses = await _houseService.getAll(_authToken!);
      print('Loaded ${houses.length} houses from API');
      
      List<Map<String, dynamic>> kandangList = [];
      

      for (var house in houses) {
        kandangList.add({
          'id': 'house_${house['id']}',
          'apiId': house['id'],
          'name': house['name'] ?? 'Kandang ${house['floor_count'] ?? 1} Lantai',
          'address': house['address'] ?? 'Lokasi tidak tersedia',
          'floors': house['total_floors'] ?? 3,
          'description': house['description'] ?? '',
          'image': house['image_url'],
          'isEmpty': false,
          'deviceData': Map<String, dynamic>.from(_fallbackDeviceData),
          'harvestCycle': _defaultHarvestCycle
              .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
              .toList(),
          'isFromAPI': true,
          'hasDeviceInstalled': false,
          'nodeIds': <String>[],
          'sensors': <Map<String, dynamic>>[],
        });
      }
      
      print('Created ${kandangList.length} houses, now loading sensor data...');
      

      for (int i = 0; i < houses.length; i++) {
        var house = houses[i];
        print('Loading sensors for house ${i}: ${house['name']}');
        

        Map<String, dynamic> deviceData = Map<String, dynamic>.from(_fallbackDeviceData);
        




        bool hasDeviceInstalled = false;
        List<String> nodeIds = [];
        List<Map<String, dynamic>> sensorsCollected = [];
        try {
          final rbwId = house['id']?.toString() ?? '';
          print('RBW ID: $rbwId');
          if (rbwId.isNotEmpty) {

            print('Loading nodes for RBW: $rbwId (calling /api/v1/rbw/$rbwId/nodes)');
            final nodesRes = await _nodeService.listByRbw(_authToken!, rbwId, queryParams: {'per_page': '50'}).timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                print('⚠️ Nodes loading timeout after 15s for house ${house['name']}');
                return {'success': false, 'message': 'timeout'};
              },
            );
            
            print('Nodes response: success=${nodesRes['success']}, data count=${(nodesRes['data'] as List?)?.length ?? 0}');
            if (nodesRes['message'] != null) {
              print('Nodes response message: ${nodesRes['message']}');
            }
            if (nodesRes['success'] == true) {
              final List<dynamic> nodes = (nodesRes['data'] as List<dynamic>? ) ?? [];
              hasDeviceInstalled = nodes.isNotEmpty;
              print('Found ${nodes.length} nodes, hasDeviceInstalled=$hasDeviceInstalled');
              nodeIds = nodes.map((n) => n['id']?.toString() ?? '').where((id) => id.isNotEmpty).cast<String>().toList();
              print('Node IDs: $nodeIds');
              

              if (nodeIds.isNotEmpty) {
                try {

                  String mistSprayStatus = 'Inactive';
                  String speakerStatus = 'Inactive';
                  

                  bool anyAudioActive = false;
                  

                  if (nodeIds.isNotEmpty) {
                    try {
                      final nodeId = nodeIds.first;
                      final nodeDetailRes = await _nodeService.getById(_authToken!, nodeId).timeout(
                        const Duration(seconds: 3),
                        onTimeout: () => {'success': false},
                      );
                      
                      if (nodeDetailRes['success'] == true && nodeDetailRes['data'] != null) {
                        final nodeData = nodeDetailRes['data'];
                        print('[HOME NODE STATE] Node ID: $nodeId');
                        print('[HOME NODE STATE] state_pump: ${nodeData['state_pump']}');
                        print('[HOME NODE STATE] state_audio: ${nodeData['state_audio']}');
                        print('[HOME NODE STATE] state_audio_lmb: ${nodeData['state_audio_lmb']}');
                        print('[HOME NODE STATE] state_audio_nest: ${nodeData['state_audio_nest']}');
                        

                        final statePump = nodeData['state_pump'];
                        mistSprayStatus = (statePump == 1 || statePump == '1' || statePump == true) ? 'Active' : 'Inactive';
                        

                        final stateAudio = nodeData['state_audio'];
                        final stateAudioLmb = nodeData['state_audio_lmb'];
                        final stateAudioNest = nodeData['state_audio_nest'];
                        

                        anyAudioActive = (stateAudio == 1 || stateAudio == '1' || stateAudio == true) ||
                                        (stateAudioLmb == 1 || stateAudioLmb == '1' || stateAudioLmb == true) ||
                                        (stateAudioNest == 1 || stateAudioNest == '1' || stateAudioNest == true);
                        
                        speakerStatus = anyAudioActive ? 'Active' : 'Inactive';
                        
                        print('[HOME NODE STATE] 🌫️ Mist Spray Status: $mistSprayStatus (from state_pump=$statePump)');
                        print('[HOME NODE STATE] 🔊 Speaker Status: $speakerStatus (All=$stateAudio, LMB=$stateAudioLmb, Nest=$stateAudioNest, anyActive=$anyAudioActive)');
                      }
                    } catch (e) {
                      print('[HOME NODE STATE] Error fetching node state: $e');
                    }
                  }
                  

                  for (final nodeId in nodeIds) {
                    final sensorsRes = await _nodeService.getSensorsByNode(_authToken!, nodeId).timeout(
                      const Duration(seconds: 3),
                      onTimeout: () => {'success': false},
                    );
                    if (sensorsRes['success'] == true) {
                      final List<dynamic> nodeSensors = (sensorsRes['data'] as List<dynamic>? ) ?? [];
                      print('Node $nodeId has ${nodeSensors.length} sensors');
                      for (final s in nodeSensors) {
                        if (s is Map<String, dynamic>) {
                          sensorsCollected.add(Map<String,dynamic>.from(s));
                        }
                      }
                    }
                  }
                  

                  if (sensorsCollected.isNotEmpty) {
                    deviceData = await _aggregateLatestReadingsFromQuery(sensorsCollected, mistSprayStatus, speakerStatus).timeout(
                      const Duration(seconds: 5),
                      onTimeout: () {
                        print('Sensor readings timeout for house ${house['name']}');
                        return Map<String, dynamic>.from(_fallbackDeviceData);
                      },
                    );
                  } else {

                    deviceData['mist_spray'] = mistSprayStatus;
                    deviceData['speaker'] = speakerStatus;
                  }
                } catch (e) {
                  print('Error loading sensors/readings for ${house['name']}: $e');
                }
              }
            }
          }
        } catch (e) {

          print('Failed to load nodes for RBW ${house['id']}: $e');
        }


        print('Updating house ${i} with hasDeviceInstalled=$hasDeviceInstalled, sensors=${sensorsCollected.length}');
        kandangList[i]['deviceData'] = deviceData;
        kandangList[i]['hasDeviceInstalled'] = hasDeviceInstalled;
        kandangList[i]['nodeIds'] = nodeIds;
        kandangList[i]['sensors'] = sensorsCollected;
      }
      
      print('Finished loading sensor data for all houses');
      

      if (mounted) {
        setState(() {
          _kandangList = kandangList;
        });
      }
      
      print('Loaded ${kandangList.length} kandang from API');
    } catch (e) {
      print('Error loading kandang from API: $e');

    }
  }


  Future<void> _refreshSensorDataOnly() async {
    if (_authToken == null || _kandangList.isEmpty) return;
    
    try {

      for (int i = 0; i < _kandangList.length; i++) {
        final house = _kandangList[i];
        final nodeIds = house['nodeIds'] as List<String>? ?? [];
        
        if (nodeIds.isEmpty) continue;
        
        try {

          String mistSprayStatus = 'Inactive';
          String speakerStatus = 'Inactive';
          
          if (nodeIds.isNotEmpty) {
            final nodeId = nodeIds.first;
            final nodeDetailRes = await _nodeService.getById(_authToken!, nodeId).timeout(
              const Duration(seconds: 3),
              onTimeout: () => {'success': false},
            );
            
            if (nodeDetailRes['success'] == true && nodeDetailRes['data'] != null) {
              final nodeData = nodeDetailRes['data'];
              final statePump = nodeData['state_pump'];
              mistSprayStatus = (statePump == 1 || statePump == '1' || statePump == true) ? 'Active' : 'Inactive';
              
              final stateAudio = nodeData['state_audio'];
              final stateAudioLmb = nodeData['state_audio_lmb'];
              final stateAudioNest = nodeData['state_audio_nest'];
              
              final anyAudioActive = (stateAudio == 1 || stateAudio == '1' || stateAudio == true) ||
                                    (stateAudioLmb == 1 || stateAudioLmb == '1' || stateAudioLmb == true) ||
                                    (stateAudioNest == 1 || stateAudioNest == '1' || stateAudioNest == true);
              
              speakerStatus = anyAudioActive ? 'Active' : 'Inactive';
            }
          }
          

          List<Map<String, dynamic>> sensorsCollected = List<Map<String, dynamic>>.from(house['sensors'] ?? []);
          

          Map<String, dynamic> deviceData = Map<String, dynamic>.from(_fallbackDeviceData);
          if (sensorsCollected.isNotEmpty) {
            deviceData = await _aggregateLatestReadingsFromQuery(sensorsCollected, mistSprayStatus, speakerStatus).timeout(
              const Duration(seconds: 5),
              onTimeout: () => Map<String, dynamic>.from(_fallbackDeviceData),
            );
          } else {
            deviceData['mist_spray'] = mistSprayStatus;
            deviceData['speaker'] = speakerStatus;
          }
          

          if (mounted) {
            setState(() {
              _kandangList[i]['deviceData'] = deviceData;
            });
          }
        } catch (e) {
          print('Error refreshing sensor data for house $i: $e');
        }
      }
    } catch (e) {
      print('Error in _refreshSensorDataOnly: $e');
    }
  }




  void _startPeriodicRefresh() {

    _refreshTimer?.cancel();


    _refreshTimer = Timer.periodic(const Duration(minutes: 10), (timer) async {
      if (_authToken != null && mounted) {
        await _refreshSensorDataOnly();
      }
    });
  }

  void _stopPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPeriodicRefresh();
    _pageController.dispose();
    super.dispose();
  }



  void _navigateToKandangManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CageSelectionPage()),
    ).then((_) {

      _loadKandangFromAPI();
    });
  }

  void _navigateToDeviceInstallation(Map<String, dynamic> kandang) {
    final dynamic apiIdRaw = kandang['apiId'];
    final String? apiIdStr = apiIdRaw?.toString();

  if (apiIdStr != null && apiIdStr.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DeviceInstallationPage(
            houseId: apiIdStr,
            houseName: kandang['name'],
          ),
        ),
      ).then((_) {
        _initializeData();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kandang harus disimpan ke database terlebih dahulu'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Row(
          children: [
            Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: Image(
                image: AssetImage("assets/img/logo.png"),
                width: 64.0,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: ValueListenableBuilder<int>(
              valueListenable: _notif.unreadCount,
              builder: (context, count, _) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: Icon(Icons.notifications_on_outlined, color: blue500),
                      onPressed: () async {
                        await _showAlertsDialog();
                      },
                    ),
                    if (count > 0)
                      Positioned(
                        right: 4,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            count.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Color(0xFF245C4C)),
                SizedBox(height: 16),
                Text('Memuat data kandang...', style: TextStyle(color: Color(0xFF245C4C))),
              ],
            ),
          )
        : SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // User Profile Section
                _buildUserProfileSection(),

                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.only(
                    left: 16,
                    bottom: 16
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    
                    children: [
                      
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          const Text("Statistik Perangkat", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF245C4C))),
                          const Text("Monitoring kondisi kandang secara real-time", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w200)),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(

                  height: height(context) * 0.35,
                  child: _kandangList.isEmpty
                      ? _buildEmptyKandangCard()
                      : _buildKandangCarousel(),
                ),

                const SizedBox(height: 12),

                // Harvest Statistics Section
                _buildHarvestStatsSection(),

                const SizedBox(height: 12),

                // Market Price Section
                _buildMarketPriceSection(),

                const SizedBox(height: 12),

                // News Section
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    top: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const BlogMenu()));
                        },
                        child: const Text("Berita Terkini",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF245C4C),
                            )),
                      )
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(
                      left: 28,
                      bottom: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        "Baca berita terkini mengenai dunia burung walet.",
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w200),
                      ),
                    ],
                  ),
                ),


                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (context) => const BlogPage()));
                    },
                    child: Container(
                      width: double.infinity,
                      height: height(context) * 0.25,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7CA),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          const BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(8),
                                topRight: Radius.circular(8),
                              ),
                              child: Image.asset(
                                "assets/img/Frame_19.png",
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xffe9f9ff),
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(8),
                                bottomRight: Radius.circular(8),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    "Cara Melakukan Budidaya Burung Walet",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.visibility,
                                        color: Color(0xFF245C4C),
                                        size: 12,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        "1,2rb",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF245C4C),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),


                Padding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: 24,
                  ),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (context) => const BlogPage()));
                    },
                    child: Container(
                      width: double.infinity,
                      height: height(context) * 0.25,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7CA),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          const BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(8),
                                topRight: Radius.circular(8),
                              ),
                              child: Image.asset(
                                "assets/img/images_(1).jpg",
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: const BoxDecoration(
                              color: Color(0xffe9f9ff),
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(8),
                                bottomRight: Radius.circular(8),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    "Tips Meningkatkan Kualitas Sarang Walet",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.visibility,
                                        color: Color(0xFF245C4C),
                                        size: 12,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        "1,2rb",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Color(0xFF245C4C),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            )],
            ),
          ),
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
                  Navigator.pushReplacementNamed(context, '/control-page');
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

  Widget _buildKandangCarousel() {
    return Column(
      children: [

        if (_kandangList.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _kandangList.length,
                (index) => Container(
                  margin: const EdgeInsets.only(right: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentKandangIndex == index
                        ? const Color(0xFF245C4C)
                        : Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),


        Expanded(
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentKandangIndex = index;
              });
            },
            itemCount: _kandangList.length,
            itemBuilder: (context, index) {
              return _buildKandangCard(_kandangList[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildKandangCard(Map<String, dynamic> kandang) {

    bool isEmpty = kandang['isEmpty'] == true;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.only(top: 16),
        width: double.infinity,
        height: height(context) * 0.75,
        decoration: BoxDecoration(
            border: Border.all(
              color: isEmpty ? Colors.grey[300]! : const Color(0xFFffc200),
            ),
            color: isEmpty ? Colors.grey[50] : const Color(0xFFfffcee),
            borderRadius: BorderRadius.circular(8),
        ),
        child: isEmpty ? _buildEmptyKandangContent(kandang) : SingleChildScrollView(
            child: Column(
            children: [

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            kandang['name']?.toString() ?? 'Kandang',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF245C4C),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            kandang['address']?.toString() ??
                                'Alamat tidak tersedia',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: TextButton.icon(
                      onPressed: _navigateToKandangManagement,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.settings, size: 16, color: Color(0xFF245C4C)),
                      label: const Text(
                        'Kelola',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF245C4C),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),


              Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          (kandang['hasDeviceInstalled'] ?? false) 
                            ? Icons.sensors 
                            : Icons.sensors_off,
                          size: 16,
                          color: (kandang['hasDeviceInstalled'] ?? false) 
                            ? Colors.green 
                            : Colors.red,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          (kandang['hasDeviceInstalled'] ?? false) 
                            ? 'Device Installed' 
                            : 'Device Not Installed',
                          style: TextStyle(
                            fontSize: 10,
                            color: (kandang['hasDeviceInstalled'] ?? false) 
                              ? Colors.green 
                              : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    if (!(kandang['hasDeviceInstalled'] ?? false))
                      GestureDetector(
                        onTap: () => _navigateToDeviceInstallation(kandang),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Install',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),


              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, top: 12),
                    child: Text(
                      (kandang['hasDeviceInstalled'] ?? false) 
                        ? "Rata-rata statistik perangkat" 
                        : "Control Device / Sensor not installed",
                      style: TextStyle(
                        fontSize: 12, 
                        color: (kandang['hasDeviceInstalled'] ?? false) 
                          ? Colors.black 
                          : Colors.red
                      ),
                    ),
                  ),
                ],
              ),


              if (kandang['hasDeviceInstalled'] ?? false)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Flexible(
                        child: _buildStatCard(
                          "Suhu",
                          _formatMetric(kandang['deviceData']?['temperature'], suffix: '°C'),
                          Icons.thermostat,
                          Colors.orange,
                        ),
                      ),
                      Flexible(
                        child: _buildStatCard(
                          "Kelembapan",
                          _formatMetric(kandang['deviceData']?['humidity'], suffix: '%'),
                          Icons.water_drop,
                          Colors.blue,
                        ),
                      ),
                      Flexible(
                        child: _buildStatCard(
                          "Amonia",
                          _formatMetric(kandang['deviceData']?['ammonia'], suffix: 'ppm'),
                          Icons.air,
                          Colors.purple,
                        ),
                      ),
                      Flexible(
                        child: _buildStatCard(
                          "Speaker",
                          (kandang['deviceData']?['speaker'] ?? 'Inactive') == 'Active' 
                              ? 'Active' 
                              : 'Inactive',
                          (kandang['deviceData']?['speaker'] ?? 'Inactive') == 'Active'
                              ? Icons.volume_up
                              : Icons.volume_off,
                          (kandang['deviceData']?['speaker'] ?? 'Inactive') == 'Active'
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                      Flexible(
                        child: _buildStatCard(
                          "Mist",
                          (kandang['deviceData']?['mist_spray'] ?? 'Inactive') == 'Active' 
                              ? 'Active' 
                              : 'Inactive',
                          (kandang['deviceData']?['mist_spray'] ?? 'Inactive') == 'Active'
                              ? Icons.water_drop_outlined
                              : Icons.block,
                          (kandang['deviceData']?['mist_spray'] ?? 'Inactive') == 'Active'
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.sensors_off,
                          size: 48,
                          color: Colors.red[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No sensors installed',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Install devices to monitor your kandang',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => _navigateToDeviceInstallation(kandang),
                          icon: const Icon(Icons.add_circle, size: 16, color: Colors.white),
                          label: const Text(
                            'Request Installation',
                            style: TextStyle(fontSize: 12, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
























              Padding(
                padding: const EdgeInsets.only(top: 16.0, bottom: 16.0),
              
                child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AnalysisPageAlternate(
                            selectedCageId:
                                kandang['id']?.toString() ?? 'kandang_default',
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        backgroundColor: const Color(0xFF245C4C),
                        foregroundColor: Colors.white,
                        minimumSize: Size(
                            width(context) * 0.81, height(context) * 0.055)),
                    child: const Text(
                      "Lihat Analisis Panen",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          fontFamily: "TT Norms"),
                    )),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyKandangContent(Map<String, dynamic> kandang) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.warning_amber_outlined,
          size: 64,
          color: Colors.orange[400],
        ),
        const SizedBox(height: 16),
        Text(
          'Empty',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.orange[600],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Data kandang belum lengkap',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Silakan lengkapi data kandang\nuntuk menggunakan fitur analisis',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _navigateToKandangManagement,
          icon: const Icon(Icons.edit, color: Colors.white),
          label: const Text(
            'Lengkapi Data',
            style: TextStyle(color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange[600],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyKandangCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        width: double.infinity,
        height: height( context) * 0.8 ,
        decoration: BoxDecoration(
            border: Border.all(
              color: Colors.grey[300]!,
              style: BorderStyle.solid,
            ),
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.home_work_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Belum Ada Kandang',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tambahkan kandang pertama Anda\nuntuk mulai menganalisis panen',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _navigateToKandangManagement,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Tambah Kandang',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF245C4C),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2.0),
      child: Container(
        width: width(context) * 0.14,
        height: height(context) * 0.10,
        decoration: BoxDecoration(
            color: const Color(0xFFFFF7CA), 
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300, width: 1)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                  fontSize: 9,
                  color: Colors.black,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 8,
                  color: Colors.black,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _formatMetric(dynamic value, {required String suffix}) {
    if (value == null) return '--';
    if (value is num) return '${value.toStringAsFixed(1)}$suffix';
    final parsed = double.tryParse(value.toString());
    return parsed != null ? '${parsed.toStringAsFixed(1)}$suffix' : '--';
  }

  // User Profile Section
  Widget _buildUserProfileSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF245C4C), Color(0xFF2d7a5f)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        
        children: [
          // Avatar
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: _userAvatarUrl != null && _userAvatarUrl!.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      _userAvatarUrl!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.person, size: 35, color: Color(0xFF245C4C));
                      },
                    ),
                  )
                : const Icon(Icons.person, size: 35, color: Color(0xFF245C4C)),
          ),
          const SizedBox(width: 16),
          // User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName ?? 'User',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _userEmail ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Harvest Statistics Section
  // Harvest Statistics Section
  Widget _buildHarvestStatsSection() {
    final now = DateTime.now();
    final monthNames = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    final currentMonthName = monthNames[now.month - 1];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.agriculture, color: Color(0xFF245C4C), size: 20),
              const SizedBox(width: 8),
              Text(
                'Statistik Panen $currentMonthName',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF245C4C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Statistics Row - Above Chart
          Row(
            children: [
              Expanded(
                child: _buildHarvestStatItem(
                  'Total Sarang',
                  '${_currentMonthHarvest.toStringAsFixed(0)}',
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHarvestStatItem(
                  'Jumlah Panen',
                  '$_harvestCount',
                  Colors.green,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Pie Chart and Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Pie Chart
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 110,
                  child: PieChart(
                    PieChartData(
                      sections: _getHarvestChartSections(),
                      centerSpaceRadius: 25,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 32),
              
              // Legend
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildChartLegendItem('Mangkok', _harvestBreakdown['mangkok']!, const Color(0xFF245C4C)),
                    const SizedBox(height: 6),
                    _buildChartLegendItem('Sudut', _harvestBreakdown['sudut']!, const Color(0xFFffc200)),
                    const SizedBox(height: 6),
                    _buildChartLegendItem('Oval', _harvestBreakdown['oval']!, const Color(0xFF168AB5)),
                    const SizedBox(height: 6),
                    _buildChartLegendItem('Patahan', _harvestBreakdown['patahan']!, const Color(0xFFC20000)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _getHarvestChartSections() {
    final mangkok = _harvestBreakdown['mangkok'] ?? 0.0;
    final sudut = _harvestBreakdown['sudut'] ?? 0.0;
    final oval = _harvestBreakdown['oval'] ?? 0.0;
    final patahan = _harvestBreakdown['patahan'] ?? 0.0;
    
    final totalNests = mangkok + sudut + oval + patahan;
    
    // If no data, show empty state
    if (totalNests == 0) {
      return [
        PieChartSectionData(
          value: 1,
          color: Colors.grey[300]!,
          title: 'No Data',
          radius: 40,
          titleStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ];
    }
    
    // Check if has breakdown
    bool hasBreakdown = (sudut > 0 || oval > 0 || patahan > 0);
    
    // If no breakdown, show single section
    if (!hasBreakdown) {
      return [
        PieChartSectionData(
          value: totalNests,
          color: Colors.orange[300]!,
          title: '${totalNests.toInt()}\nsarang',
          radius: 40,
          titleStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ];
    }
    
    // Show breakdown sections
    List<PieChartSectionData> sections = [];
    
    if (mangkok > 0) {
      final percentage = (mangkok / totalNests * 100).toStringAsFixed(1);
      sections.add(PieChartSectionData(
        value: mangkok,
        color: const Color(0xFF245C4C),
        title: '${mangkok.toInt()}\n($percentage%)',
        radius: 40,
        titleStyle: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
    }
    
    if (sudut > 0) {
      final percentage = (sudut / totalNests * 100).toStringAsFixed(1);
      sections.add(PieChartSectionData(
        value: sudut,
        color: const Color(0xFFffc200),
        title: '${sudut.toInt()}\n($percentage%)',
        radius: 40,
        titleStyle: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
    }
    
    if (oval > 0) {
      final percentage = (oval / totalNests * 100).toStringAsFixed(1);
      sections.add(PieChartSectionData(
        value: oval,
        color: const Color(0xFF168AB5),
        title: '${oval.toInt()}\n($percentage%)',
        radius: 40,
        titleStyle: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
    }
    
    if (patahan > 0) {
      final percentage = (patahan / totalNests * 100).toStringAsFixed(1);
      sections.add(PieChartSectionData(
        value: patahan,
        color: const Color(0xFFC20000),
        title: '${patahan.toInt()}\n($percentage%)',
        radius: 40,
        titleStyle: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
    }
    
    return sections;
  }

  Widget _buildChartLegendItem(String label, double value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                '${value.toInt()} sarang',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHarvestStatItem(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Market Price Section
  Widget _buildMarketPriceSection() {
    final pricePerKg = _nestTypePrices[_selectedNestType] ?? 0;
    final pricePerGram = pricePerKg / 1000;
    final pricePerNest = GRAMS_PER_NEST * pricePerGram;
    
    // Calculate display price based on selected unit
    final displayPrice = _selectedUnit == 'Kg' ? pricePerKg : pricePerGram;
    final displayLabel = _selectedUnit == 'Kg' ? 'Per Kg' : 'Per Gram';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sell, color: Color(0xFF245C4C), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Harga Terbaru dari Pasar',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF245C4C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Nest Type Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7CA).withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFffc200).withOpacity(0.5)),
            ),
            child: Row(
              children: [
                const Text(
                  'Jenis: ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF245C4C),
                  ),
                ),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedNestType,
                      isDense: true,
                      isExpanded: true,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF245C4C),
                        fontWeight: FontWeight.w500,
                      ),
                      items: _nestTypePrices.keys.map((String type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedNestType = newValue;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Unit Selection Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7CA).withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFffc200).withOpacity(0.5)),
            ),
            child: Row(
              children: [
                const Text(
                  'Satuan: ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF245C4C),
                  ),
                ),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedUnit,
                      isDense: true,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF245C4C),
                        fontWeight: FontWeight.w500,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Kg', child: Text('Kilogram (Kg)')),
                        DropdownMenuItem(value: 'Gram', child: Text('Gram')),
                      ],
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedUnit = newValue;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildPriceItem(
                  displayLabel,
                  'Rp ${_formatRupiah(displayPrice)}',
                  Icons.scale,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPriceItem(
                  'Per Sarang\n(${GRAMS_PER_NEST}g)',
                  'Rp ${_formatRupiah(pricePerNest)}',
                  Icons.egg,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7CA).withOpacity(0.3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16, color: Color(0xFF245C4C)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Harga berdasarkan rata-rata pasar saat ini. 1 sarang = ${GRAMS_PER_NEST}g',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[800],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceItem(String label, String price, IconData icon) {
    return Container(
      height: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFffc200).withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFFffc200), size: 22),
          const SizedBox(height: 6),
          Text(
            price,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF245C4C),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _aggregateLatestReadingsFromQuery(
    List<Map<String, dynamic>> sensors,
    String mistSprayStatus,
    String speakerStatus,
  ) async {

    double? temperature; double? humidity; double? ammonia; 
    DateTime? latestTs;
    String? temperatureSensorId; String? humiditySensorId; String? ammoniaSensorId;

    for (final sensor in sensors) {
      final sensorId = sensor['id']?.toString();
      if (sensorId == null || sensorId.isEmpty) continue;

      try {
        final res = await _sensorService.getReadings(_authToken!, sensorId, queryParams: {'limit':'10'});
        if (res['data'] is List) {
          final List<dynamic> readings = res['data'];
          readings.sort((a, b) {
            final aTime = DateTime.tryParse(a['recorded_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = DateTime.tryParse(b['recorded_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime); // newest first
          });
          if (readings.isNotEmpty) {
            final newest = readings.first;
            if (newest is Map<String,dynamic>) {
              final metric = _classifySensorMetric(sensor);
              final value = (newest['value'] as num?)?.toDouble();
              final tsRaw = DateTime.tryParse(newest['recorded_at']?.toString() ?? '');

              final ts = tsRaw != null ? TimeUtils.toWIB(tsRaw) : null;

              print('[HOME] Sensor $sensorId type=${sensor['type'] ?? sensor['name'] ?? sensor['label']} classified=$metric value=$value at ${newest['recorded_at']}');

              if (metric == 'temperature' && value != null) { 
                temperature = value; 
                temperatureSensorId = sensorId; 
                latestTs = _pickLatest(latestTs, ts); 
              }
              else if (metric == 'humidity' && value != null) { 
                humidity = value; 
                humiditySensorId = sensorId; 
                latestTs = _pickLatest(latestTs, ts); 
              }
              else if (metric == 'ammonia' && value != null) { 
                ammonia = value; 
                ammoniaSensorId = sensorId; 
                latestTs = _pickLatest(latestTs, ts); 
              }

            }
          }
        }
      } catch (e) {
        print('[HOME] Error fetching readings for sensor $sensorId: $e');
      }
    }

    final result = {
      'temperature': temperature,
      'humidity': humidity,
      'ammonia': ammonia,
      'mist_spray': mistSprayStatus,  // From node state_pump
      'speaker': speakerStatus,        // From node state_audio

      'timestamp': latestTs?.toIso8601String(),
      'temperatureSensorId': temperatureSensorId,
      'humiditySensorId': humiditySensorId,
      'ammoniaSensorId': ammoniaSensorId,
    };

    print('=== AGGREGATED READINGS (HOME) ===');
    print('Temperature: $temperature°C (sensor=$temperatureSensorId)');
    print('Humidity: $humidity% (sensor=$humiditySensorId)');
    print('Ammonia: $ammonia ppm (sensor=$ammoniaSensorId)');
    print('Mist Spray: $mistSprayStatus (from node state_pump)');
    print('Speaker: $speakerStatus (from node state_audio)');
    print('Latest timestamp: ${latestTs?.toIso8601String()}');
    print('=================================');

    return result;
  }



  String? _classifySensorMetric(Map<String,dynamic> s) {
    final raw = (s['type'] ?? s['name'] ?? s['label'] ?? '').toString().toLowerCase();
    final unit = (s['unit']?.toString() ?? '').toLowerCase();
    
    print('[HOME CLASSIFY] Sensor: type="${s['type']}", name="${s['name']}", label="${s['label']}", unit="${s['unit']}"');
    print('[HOME CLASSIFY] Raw string: "$raw"');
    

    const tempKeys = ['temp','temperature','suhu','heat','panas'];
    const humidityKeys = ['humid','humidity','kelembaban','lembab'];
    const ammoniaKeys = ['ammon','ammonia','amonia','nh3'];
    const mistSprayKeys = ['mist','spray','kabut','semprot','mist_spray','mistspray'];
    const speakerKeys = ['speaker','audio','sound','suara','bunyi'];
    bool match(List<String> keys) => keys.any((k) => raw.contains(k));

    if (match(tempKeys) || unit.contains('c')) {
      print('[HOME CLASSIFY] ✅ Matched as: temperature');
      return 'temperature';
    }
    if (match(humidityKeys) || unit.contains('%')) {
      print('[HOME CLASSIFY] ✅ Matched as: humidity');
      return 'humidity';
    }
    if (match(ammoniaKeys) || unit.contains('ppm')) {
      print('[HOME CLASSIFY] ✅ Matched as: ammonia');
      return 'ammonia';
    }
    if (match(mistSprayKeys)) {
      print('[HOME CLASSIFY] ✅ Matched as: mist_spray');
      return 'mist_spray';
    }
    if (match(speakerKeys)) {
      print('[HOME CLASSIFY] ✅ Matched as: speaker');
      return 'speaker';
    }
    
    print('[HOME CLASSIFY] ❌ No match found');
    return null;
  }

  DateTime? _pickLatest(DateTime? a, DateTime? b) {
    if (a == null) return b;
    if (b == null) return a;
    return b.isAfter(a) ? b : a;
  }



}
