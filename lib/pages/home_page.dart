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

  // List of kandang (cages)
  List<Map<String, dynamic>> _kandangList = [];

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
    _loadKandangData();
  }

  @override
  void dispose() {
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
            final address = prefs.getString('kandang_${i}_address') ?? '';
            final floors = prefs.getInt('kandang_${i}_floors') ?? 3;
            final image = prefs.getString('kandang_${i}_image');

            if (address.isNotEmpty) {
              kandangList.add({
                'id': 'kandang_$i',
                'name': 'Kandang $floors Lantai',
                'address': address,
                'floors': floors,
                'image': image,
                'harvestCycle': _defaultHarvestCycle
                    .map<Map<String, dynamic>>(
                        (e) => Map<String, dynamic>.from(e))
                    .toList(),
              });
            }
          } catch (e) {
            print('Error loading kandang $i: $e');
          }
        }
      }

      // Add default kandang if no kandang exists
      if (kandangList.isEmpty) {
        kandangList.add({
          'id': 'kandang_default',
          'name': 'Kandang Demo',
          'address': 'Jl Jawa No 23, Semarang',
          'floors': 3,
          'image': null,
          'harvestCycle': _defaultHarvestCycle
              .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
              .toList(),
        });
      }

      setState(() {
        _kandangList = kandangList;
      });
    } catch (e) {
      print('Error loading kandang data: $e');
      // Set default kandang on error
      setState(() {
        _kandangList = [
          {
            'id': 'kandang_default',
            'name': 'Kandang Demo',
            'address': 'Jl Jawa No 23, Semarang',
            'floors': 3,
            'image': null,
            'harvestCycle': _defaultHarvestCycle
                .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
                .toList(),
          }
        ];
      });
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
            'kandang_${index}_address', kandang['address'] ?? '');
        await prefs.setInt('kandang_${index}_floors', kandang['floors'] ?? 3);
        if (kandang['image'] != null) {
          await prefs.setString('kandang_${index}_image', kandang['image']);
        }
      }
    } catch (e) {
      print('Error saving kandang list: $e');
    }
  }

  Map<String, dynamic> get _currentKandang {
    if (_kandangList.isEmpty) return {};
    if (_currentKandangIndex >= _kandangList.length) return _kandangList.first;
    return _kandangList[_currentKandangIndex];
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

  void _navigateToAnalysis() {
    if (_kandangList.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AnalysisPageAlternate(
            selectedCageId: _currentKandang['id'] ?? 'kandang_default',
          ),
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
      body: SingleChildScrollView(
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
                icon: Icons.store,
                label: 'Kontrol',
                currentIndex: _currentIndex,
                itemIndex: 1,
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/monitoring-page');
                  setState(() {
                    _currentIndex = 1;
                  });
                },
              ),
              label: ''),
          BottomNavigationBarItem(
              icon: CustomBottomNavigationItem(
                icon: Icons.chat_sharp,
                label: 'Panen',
                currentIndex: _currentIndex,
                itemIndex: 2,
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/community-page');
                  setState(() {
                    _currentIndex = 2;
                  });
                },
              ),
              label: ''),
          BottomNavigationBarItem(
              icon: CustomBottomNavigationItem(
                icon: Icons.dataset_sharp,
                label: 'Jual',
                currentIndex: _currentIndex,
                itemIndex: 3,
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/control-page');
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.only(top: 16),
          alignment: Alignment.center,
          width: width(context) * 0.85,
          height: height(context) * 0.40,
          decoration: BoxDecoration(
            border: Border.all(
              color: Color(0xFFffc200),
            ),
            color: Color(0xFFfffcee),
            borderRadius: BorderRadius.circular(8),
          ),
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

              // Statistics label
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, top: 16),
                    child: const Text(
                      "Rata-rata statistik perangkat",
                      style: TextStyle(fontSize: 12, color: Colors.black),
                    ),
                  ),
                ],
              ),

              // Device statistics with icons and data
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatCard(
                    "Temp",
                    "${_deviceData['temperature']}°C",
                    Icons.thermostat,
                    Colors.orange,
                  ),
                  _buildStatCard(
                    "Humidity",
                    "${_deviceData['humidity']}%",
                    Icons.water_drop,
                    Colors.blue,
                  ),
                  _buildStatCard(
                    "Ammonia",
                    "${_deviceData['ammonia']}ppm",
                    Icons.air,
                    Colors.purple,
                  ),
                  _buildStatCard(
                    "Twitter",
                    _deviceData['twitter']?.toString() ?? 'Not Active',
                    _deviceData['twitter'] == 'Active'
                        ? Icons.check_circle
                        : Icons.cancel,
                    _deviceData['twitter'] == 'Active'
                        ? Colors.green
                        : Colors.red,
                  ),
                ],
              ),

              // Harvest Cycle Table
              Padding(
                padding:
                    const EdgeInsets.only(top: 16.0, left: 16.0, right: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Siklus Panen 2024",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF245C4C),
                      ),
                    ),
                    SizedBox(height: 8),
                    _buildHarvestTable(
                        kandang['harvestCycle'] as List<Map<String, dynamic>>?),
                  ],
                ),
              ),

              // Analysis button
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
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
                        padding: const EdgeInsets.symmetric(vertical: 10),
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
          constraints: BoxConstraints(
            minHeight: height(context) * 0.60,
            maxHeight: height(context) * 0.60,
          ),
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

  Widget _buildHarvestTable(List<Map<String, dynamic>>? harvestCycle) {
    // Safely handle null harvestCycle
    final List<Map<String, dynamic>> cycle = harvestCycle ??
        _defaultHarvestCycle
            .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
            .toList();

    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey[300]!)),
      child: Column(
        children: [
          // First row: Jan-Jun
          Container(
            padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children:
                  cycle.take(6).map((month) => _buildMonthCell(month)).toList(),
            ),
          ),
          Divider(height: 1, color: Colors.grey[300]),
          // Second row: Jul-Dec
          Container(
            padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: cycle
                  .skip(6)
                  .take(6)
                  .map((month) => _buildMonthCell(month))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthCell(Map<String, dynamic> monthData) {
    Color statusColor;
    // Safely access the status with null checking
    final status = monthData['status']?.toString() ?? 'Planned';

    switch (status) {
      case 'Complete':
        statusColor = Colors.green;
        break;
      case 'In Progress':
        statusColor = Colors.orange;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Column(
      children: [
        Text(
          monthData['month']?.toString() ?? '',
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w600,
            color: Color(0xFF245C4C),
          ),
        ),
        SizedBox(height: 2),
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: statusColor,
            shape: BoxShape.circle,
          ),
        ),
        if (monthData['yield']?.toString() != '-' && monthData['yield'] != null)
          Text(
            monthData['yield'].toString(),
            style: TextStyle(
              fontSize: 6,
              color: Colors.grey[600],
            ),
          ),
      ],
    );
  }
}
