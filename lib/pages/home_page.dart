import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:swiftlead/pages/analysis_alternate_page.dart';
import 'package:swiftlead/shared/theme.dart';
import 'package:swiftlead/pages/blog_page.dart';
import 'package:swiftlead/pages/blog_menu.dart';
import 'package:swiftlead/components/custom_bottom_navigation.dart';
import 'package:swiftlead/pages/cage_selection_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swiftlead/services/house_services.dart';
import 'package:swiftlead/services/devices.services.dart';
import 'package:swiftlead/services/device_installation_service.dart';
import 'package:swiftlead/services/sensor_services.dart';
import 'package:swiftlead/utils/token_manager.dart';
import 'package:swiftlead/pages/device_installation_page.dart';
import 'dart:async';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  double width(BuildContext context) => MediaQuery.of(context).size.width;
  double height(BuildContext context) => MediaQuery.of(context).size.height;

  int _currentIndex = 0;
  PageController _pageController = PageController();
  int _currentKandangIndex = 0;

  // API Services
  final HouseService _houseService = HouseService();
  final DeviceService _deviceService = DeviceService();
  final DeviceInstallationService _installationService = DeviceInstallationService();
  final SensorService _sensorService = SensorService();

  // State management
  bool _isLoading = true;
  String? _authToken;

  // List of kandang (cages)
  List<Map<String, dynamic>> _kandangList = [];

  // Real-time sensor data
  Timer? _refreshTimer;

  // Static device data template
  final Map<String, dynamic> _deviceData = {
    'temperature': 28.5,
    'humidity': 75.2,
    'ammonia': 12.1,
    'twitter': 'Active', // Active / Not Active
  };

  // Default harvest cycle data template
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
    _initializeData();
  }

  Future<void> _initializeData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    
    try {
      // Get authentication token
      _authToken = await TokenManager.getToken();
      
      if (_authToken != null) {
        // Try to load from API first
        await _loadKandangFromAPI();
      }
      
      // If API failed or no token, fallback to local data
      if (_kandangList.isEmpty) {
        await _loadKandangData();
      }
    } catch (e) {
      print('Error initializing data: $e');
      // Fallback to local data
      await _loadKandangData();
    }
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadKandangFromAPI() async {
    try {
      final houses = await _houseService.getAll(_authToken!);
      
      List<Map<String, dynamic>> kandangList = [];
      for (var house in houses) {
        // Load device data for this house
        Map<String, dynamic> deviceData = Map<String, dynamic>.from(_deviceData); // Default device data
        try {
          final devices = await _deviceService.getAll(_authToken!);
          // Find devices for this house (you might need to filter by house_id)
          if (devices.isNotEmpty) {
            // Use the first device data or filter by house ID
            var houseDevice = devices.firstWhere(
              (device) => device['house_id'] == house['id'],
              orElse: () => devices.first,
            );
            deviceData = {
              'temperature': houseDevice['temperature']?.toDouble() ?? 28.5,
              'humidity': houseDevice['humidity']?.toDouble() ?? 75.2,
              'ammonia': houseDevice['ammonia']?.toDouble() ?? 12.1,
              'twitter': houseDevice['status'] ?? 'Active',
            };
          }
        } catch (e) {
          print('Failed to load device data for house ${house['id']}: $e');
          // Use default device data
        }

        // Check device installation status
        bool hasDeviceInstalled = false;
        List<String> installationCodes = [];
        try {
          final installCheck = await _installationService.checkDeviceInstallation(_authToken!, house['id']);
          hasDeviceInstalled = installCheck['hasDevices'] ?? false;
          installationCodes = List<String>.from(installCheck['installationCodes'] ?? []);
        } catch (e) {
          print('Failed to check device installation for house ${house['id']}: $e');
        }

        // Load real sensor data if device is installed
        if (hasDeviceInstalled && installationCodes.isNotEmpty) {
          try {
            final sensorData = await _loadSensorDataForHouse(installationCodes.first);
            if (sensorData != null) {
              deviceData = {
                'temperature': sensorData['suhu'] ?? _deviceData['temperature'],
                'humidity': sensorData['kelembaban'] ?? _deviceData['humidity'],
                'ammonia': sensorData['amonia'] ?? _deviceData['ammonia'],
                'twitter': 'Active', // Keep this as is
              };
            }
          } catch (e) {
            print('Failed to load sensor data for house ${house['id']}: $e');
          }
        }

        kandangList.add({
          'id': 'house_${house['id']}',
          'apiId': house['id'],
          'name': house['name'] ?? 'Kandang ${house['floor_count'] ?? 1} Lantai',
          'address': house['location'] ?? 'Lokasi tidak tersedia',
          'floors': house['floor_count'] ?? 3,
          'description': house['description'] ?? '',
          'image': house['image_url'],
          'isEmpty': false,
          'deviceData': deviceData,
          'harvestCycle': _defaultHarvestCycle
              .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
              .toList(),
          'isFromAPI': true,
          'hasDeviceInstalled': hasDeviceInstalled,
          'installationCodes': installationCodes,
        });
      }
      
      if (mounted) {
        setState(() {
          _kandangList = kandangList;
        });
      }
      
      // Start periodic refresh for real-time sensor data
      _startPeriodicRefresh();
      
      print('Loaded ${kandangList.length} kandang from API');
    } catch (e) {
      print('Error loading kandang from API: $e');
      // Don't throw, let it fallback to local data
    }
  }

  Future<Map<String, dynamic>?> _loadSensorDataForHouse(String installCode) async {
    try {
      final response = await _sensorService.getDataByInstallCode(_authToken!, installCode, limit: 1);
      if (response['success'] == true && response['data'] != null && response['data'].isNotEmpty) {
        return response['data'][0];
      }
    } catch (e) {
      print('Error loading sensor data for install code $installCode: $e');
    }
    return null;
  }

  void _startPeriodicRefresh() {
    // Cancel existing timer if any
    _refreshTimer?.cancel();

    // Refresh sensor data every 5 minutes
    _refreshTimer = Timer.periodic(Duration(minutes: 5), (timer) async {
      if (_authToken != null && mounted) {
        await _loadKandangFromAPI();
      }
    });
  }

  void _stopPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  @override
  void dispose() {
    _stopPeriodicRefresh();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadKandangData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load all stored kandang
      List<Map<String, dynamic>> kandangList = [];

      // Get saved kandang count
      int kandangCount = prefs.getInt('kandang_count') ?? 0;

      if (kandangCount == 0) {
        // Check for legacy single kandang data
        final savedAddress = prefs.getString('cage_address');
        final savedFloors = prefs.getInt('cage_floors');
        final savedImage = prefs.getString('cage_image');

        if (savedAddress != null &&
            savedAddress.isNotEmpty &&
            savedFloors != null) {
          // Convert legacy data to new format
          kandangList.add({
            'id': 'kandang_1',
            'name': 'Kandang $savedFloors Lantai',
            'address': savedAddress,
            'floors': savedFloors,
            'image': savedImage,
            'harvestCycle': _defaultHarvestCycle
                .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
                .toList(),
          });

          // Save in new format
          await _saveKandangList(kandangList);
        }
      } else {
        // Load all kandang from new format
        for (int i = 1; i <= kandangCount; i++) {
          try {
            // Load individual preferences for each kandang
            final name = prefs.getString('kandang_${i}_name') ?? '';
            final address = prefs.getString('kandang_${i}_address') ?? '';
            final floors = prefs.getInt('kandang_${i}_floors') ?? 3;
            final description = prefs.getString('kandang_${i}_description') ?? '';
            final image = prefs.getString('kandang_${i}_image');

            // Check if data is complete
            final isEmpty = name.isEmpty || address.isEmpty;

            // Always add kandang entry, even if incomplete
            kandangList.add({
              'id': 'kandang_$i',
              'name': isEmpty ? 'Empty' : name,
              'address': isEmpty ? 'Data belum lengkap' : address,
              'floors': floors,
              'description': description,
              'image': image,
              'isEmpty': isEmpty, // Flag to identify incomplete data
              'harvestCycle': _defaultHarvestCycle
                  .map<Map<String, dynamic>>(
                      (e) => Map<String, dynamic>.from(e))
                  .toList(),
            });
          } catch (e) {
            print('Error loading kandang $i: $e');
          }
        }
      }

      // Don't add default kandang - let the empty state show
      // if (kandangList.isEmpty) {
      //   kandangList.add({
      //     'id': 'kandang_default',
      //     'name': 'Kandang Demo',
      //     'address': 'Jl Jawa No 23, Semarang',
      //     'floors': 3,
      //     'image': null,
      //     'harvestCycle': _defaultHarvestCycle
      //         .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
      //         .toList(),
      //   });
      // }

      if (mounted) {
        setState(() {
          _kandangList = kandangList;
        });
      }
    } catch (e) {
      print('Error loading kandang data: $e');
      // Set empty kandang list on error - let the empty state show
      if (mounted) {
        setState(() {
          _kandangList = [];
        });
      }
    }
  }

  Future<void> _saveKandangList(List<Map<String, dynamic>> kandangList) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save kandang count
      await prefs.setInt('kandang_count', kandangList.length);

      // Save each kandang individually
      for (int i = 0; i < kandangList.length; i++) {
        final kandang = kandangList[i];
        final index = i + 1;

        await prefs.setString(
            'kandang_${index}_name', kandang['name'] ?? '');
        await prefs.setString(
            'kandang_${index}_address', kandang['address'] ?? '');
        await prefs.setInt('kandang_${index}_floors', kandang['floors'] ?? 3);
        await prefs.setString(
            'kandang_${index}_description', kandang['description'] ?? '');
        if (kandang['image'] != null) {
          await prefs.setString('kandang_${index}_image', kandang['image']);
        }
      }
    } catch (e) {
      print('Error saving kandang list: $e');
    }
  }



  void _navigateToKandangManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CageSelectionPage()),
    ).then((_) {
      // Reload kandang data when returning
      _loadKandangData();
    });
  }

  void _navigateToDeviceInstallation(Map<String, dynamic> kandang) {
    if (kandang['apiId'] != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DeviceInstallationPage(
            houseId: kandang['apiId'],
            houseName: kandang['name'],
          ),
        ),
      ).then((_) {
        // Reload kandang data when returning
        _initializeData();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
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
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: IconButton(
              icon: Icon(Icons.notifications_on_outlined, color: blue500),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: _isLoading 
        ? Center(
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
                // Kandang Carousel Section
                Container(
                  height: height(context) * 0.45,
                  child: _kandangList.isEmpty
                      ? _buildEmptyKandangCard()
                      : _buildKandangCarousel(),
                ),

            // News section
            Column(
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    left: width(context) * 0.044,
                    top: height(context) * 0.02,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => BlogMenu()));
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
                Padding(
                  padding: EdgeInsets.only(
                      left: width(context) * 0.077,
                      bottom: height(context) * 0.02),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const Text(
                        "Baca berita terkini mengenai dunia burung walet.",
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w200),
                      ),
                    ],
                  ),
                ),

                // News cards (existing code)
                Padding(
                  padding: EdgeInsets.only(bottom: height(context) * 0.0001),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (context) => BlogPage()));
                    },
                    child: Container(
                      alignment: Alignment.center,
                      width: width(context) * 0.8,
                      height: height(context) * 0.25,
                      decoration: BoxDecoration(
                        color: Color(0xFFFFF7CA),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: List<BoxShadow>.from([
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 2,
                            offset: Offset(2, 2),
                          ),
                        ]),
                      ),
                      child: Stack(
                        children: [
                          Container(
                            width: width(context) * 0.8,
                            height: height(context) * 0.20,
                            decoration: BoxDecoration(
                                image: DecorationImage(
                                    image:
                                        AssetImage("assets/img/Frame_19.png"),
                                    fit: BoxFit.cover,
                                    scale: 0.6),
                                borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(8),
                                    topRight: Radius.circular(8))),
                          ),
                          Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 8.0, top: 8),
                                    child: Container(
                                      width: width(context) * 0.1,
                                      height: height(context) * 0.02,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withAlpha(140),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceAround,
                                        children: [
                                          Icon(
                                            Icons.visibility,
                                            color: Color((0xFF245C4C)),
                                            size: 10,
                                          ),
                                          const Text(
                                            "1,2rb",
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF245C4C),
                                            ),
                                            textAlign: TextAlign.center,
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                width: width(context) * 0.8,
                                height: height(context) * 0.05,
                                alignment: Alignment.centerLeft,
                                padding: EdgeInsets.only(left: 8),
                                decoration: BoxDecoration(
                                  color: Color(0xffe9f9ff),
                                ),
                                child: const Text(
                                  "Cara Melakukan Budidaya Burung Walet",
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.black,
                                      fontWeight: FontWeight.w400),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),

                // Second news card (existing code)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0, top: 24),
                  child: Container(
                    alignment: Alignment.center,
                    width: width(context) * 0.8,
                    height: height(context) * 0.25,
                    decoration: BoxDecoration(
                      color: Color.fromARGB(255, 73, 164, 118),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: List<BoxShadow>.from([
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 2,
                          offset: Offset(2, 2),
                        ),
                      ]),
                    ),
                    child: Stack(
                      children: [
                        Container(
                          width: width(context) * 0.8,
                          height: height(context) * 0.20,
                          decoration: BoxDecoration(
                              image: DecorationImage(
                                  image:
                                      AssetImage("assets/img/images_(1).jpg"),
                                  fit: BoxFit.cover),
                              borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  topRight: Radius.circular(8))),
                        ),
                        Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.only(left: 8.0, top: 8),
                                  child: Container(
                                    width: width(context) * 0.1,
                                    height: height(context) * 0.02,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withAlpha(140),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        Icon(
                                          Icons.visibility,
                                          color: Color((0xFF245C4C)),
                                          size: 10,
                                        ),
                                        Text(
                                          "1,2rb",
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Color(0xFF245C4C),
                                          ),
                                          textAlign: TextAlign.center,
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              width: width(context) * 0.8,
                              height: height(context) * 0.05,
                              alignment: Alignment.centerLeft,
                              padding: EdgeInsets.only(left: 8),
                              decoration: BoxDecoration(
                                color: Color(0xffe9f9ff),
                              ),
                              child: const Text(
                                "Tips Meningkatkan Kualitas Sarang Walet",
                                style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black,
                                    fontWeight: FontWeight.w400),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ],
            )
          ],
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
                icon: Icons.pest_control,
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
        // Kandang indicator and management button
        Padding(
          padding: EdgeInsets.symmetric(horizontal: width(context) * 0.075),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Kandang indicators
              if (_kandangList.length > 1)
                Row(
                  children: List.generate(
                    _kandangList.length,
                    (index) => Container(
                      margin: EdgeInsets.only(right: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentKandangIndex == index
                            ? Color(0xFF245C4C)
                            : Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              if (_kandangList.length <= 1) Container(),

              // Manage kandang button
              TextButton.icon(
                onPressed: _navigateToKandangManagement,
                icon: Icon(Icons.settings, size: 16, color: Color(0xFF245C4C)),
                label: Text(
                  'Kelola',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF245C4C),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        // PageView for kandang cards
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
    // Check if kandang data is empty/incomplete
    bool isEmpty = kandang['isEmpty'] == true;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      
      children: [
        Container(
          padding: EdgeInsets.only(top: 16),
          width: width(context) * 0.85,
          height: height(context) * 0.35,
          decoration: BoxDecoration(
            border: Border.all(
              color: isEmpty ? Colors.grey[300]! : Color(0xFFffc200),
            ),
            color: isEmpty ? Colors.grey[50] : Color(0xFFfffcee),
            borderRadius: BorderRadius.circular(8),
          ),
          child: isEmpty ? _buildEmptyKandangContent(kandang) : SingleChildScrollView(
            child: Column(
            children: [
              // Header with kandang info
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Text(
                      kandang['name']?.toString() ?? 'Kandang',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF245C4C),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: Text(
                        kandang['address']?.toString() ??
                            'Alamat tidak tersedia',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                ],
              ),

              // Device Installation Status
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
                        SizedBox(width: 4),
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
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
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

              // Statistics label
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

              // Device statistics with icons and data or installation prompt
              if (kandang['hasDeviceInstalled'] ?? false)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCard(
                      "Temp",
                      "${kandang['deviceData']?['temperature'] ?? _deviceData['temperature']}°C",
                      Icons.thermostat,
                      Colors.orange,
                    ),
                    _buildStatCard(
                      "Humidity",
                      "${kandang['deviceData']?['humidity'] ?? _deviceData['humidity']}%",
                      Icons.water_drop,
                      Colors.blue,
                    ),
                    _buildStatCard(
                      "Ammonia",
                      "${kandang['deviceData']?['ammonia'] ?? _deviceData['ammonia']}ppm",
                      Icons.air,
                      Colors.purple,
                    ),
                    _buildStatCard(
                      "Twitter",
                      kandang['deviceData']?['twitter']?.toString() ?? _deviceData['twitter']?.toString() ?? 'Not Active',
                      (kandang['deviceData']?['twitter'] ?? _deviceData['twitter']) == 'Active'
                          ? Icons.check_circle
                          : Icons.cancel,
                      (kandang['deviceData']?['twitter'] ?? _deviceData['twitter']) == 'Active'
                          ? Colors.green
                          : Colors.red,
                    ),
                  ],
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
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
                        SizedBox(height: 8),
                        Text(
                          'No sensors installed',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Install devices to monitor your kandang',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: () => _navigateToDeviceInstallation(kandang),
                          icon: Icon(Icons.add_circle, size: 16, color: Colors.white),
                          label: Text(
                            'Request Installation',
                            style: TextStyle(fontSize: 12, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Harvest Cycle Table
              // Padding(
              //   padding:
              //       const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
              //   child: Column(
              //     crossAxisAlignment: CrossAxisAlignment.start,
              //     children: [
              //       Text(
              //         "Siklus Panen 2024",
              //         style: TextStyle(
              //           fontSize: 12,
              //           fontWeight: FontWeight.w600,
              //           color: Color(0xFF245C4C),
              //         ),
              //       ),
              //       SizedBox(height: 8),
              //       _buildHarvestTable(
              //           kandang['harvestCycle'] as List<Map<String, dynamic>>?),
              //     ],
              //   ),
              // ),

              // Analysis button
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
                            width(context) * 0.75, height(context) * 0.055)),
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
      ],
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
        SizedBox(height: 16),
        Text(
          'Empty',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.orange[600],
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Data kandang belum lengkap',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 4),
        Text(
          'Silakan lengkapi data kandang\nuntuk menggunakan fitur analisis',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _navigateToKandangManagement,
          icon: Icon(Icons.edit, color: Colors.white),
          label: Text(
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(24),
          alignment: Alignment.center,
          width: width(context) * 0.85,
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
              SizedBox(height: 16),
              Text(
                'Belum Ada Kandang',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Tambahkan kandang pertama Anda\nuntuk mulai menganalisis panen',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _navigateToKandangManagement,
                icon: Icon(Icons.add, color: Colors.white),
                label: Text(
                  'Tambah Kandang',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF245C4C),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Container(
        width: width(context) * 0.15,
        height: height(context) * 0.09,
        decoration: BoxDecoration(
            color: Color(0xFFFFF7CA), borderRadius: BorderRadius.circular(8)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 16,
            ),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.black,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            Text(
              label,
              style: TextStyle(
                  fontSize: 8,
                  color: Colors.black,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }



}
