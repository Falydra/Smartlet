import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swiftlead/pages/cage_selection_page.dart';
import 'package:swiftlead/pages/add_harvest_page.dart';
import 'package:swiftlead/components/custom_bottom_navigation.dart';
import 'package:swiftlead/shared/theme.dart';

class AnalysisPageAlternate extends StatefulWidget {
  final String? selectedCageId;

  const AnalysisPageAlternate({Key? key, this.selectedCageId})
      : super(key: key);

  @override
  State<AnalysisPageAlternate> createState() => _AnalysisPageAlternateState();
}

class _AnalysisPageAlternateState extends State<AnalysisPageAlternate> {
  double width(BuildContext context) => MediaQuery.of(context).size.width;
  double height(BuildContext context) => MediaQuery.of(context).size.height;

  int _currentIndex = 2;

  // Date selection
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  final List<String> _months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember'
  ];

  // Default empty data template for harvest analysis
  Map<String, dynamic> _harvestData = {
    'mangkok': 0.0,
    'sudut': 0.0,
    'oval': 0.0,
    'patahan': 0.0,
  };

  // Cage data
  String _selectedCageName = "Kandang 1";
  int _selectedCageFloors = 3;

  // Floor data template
  late List<Map<String, dynamic>> _floorData;

  @override
  void initState() {
    super.initState();
    _loadCageData();
    _initializeFloorData();
    _loadHarvestData();
  }

  Future<void> _loadCageData() async {
    try {
      // Try SharedPreferences first, fallback to static data
      SharedPreferences? prefs;
      try {
        prefs = await SharedPreferences.getInstance();
        final savedFloors = prefs.getInt('cage_floors') ?? 3;

        setState(() {
          _selectedCageFloors = savedFloors;
          _selectedCageName = "Kandang $savedFloors Lantai";
        });
      } catch (e) {
        print('SharedPreferences not available, using default values: $e');
        setState(() {
          _selectedCageFloors = 3;
          _selectedCageName = "Kandang 3 Lantai";
        });
      }

      _initializeFloorData();
    } catch (e) {
      print('Error loading cage data: $e');
    }
  }

  void _initializeFloorData() {
    _floorData = List.generate(
        _selectedCageFloors,
        (index) => {
              'floor': index + 1,
              'mangkok': '0.0',
              'sudut': '0.0',
              'oval': '0.0',
              'patahan': '0.0',
            });
  }

  Future<void> _loadHarvestData() async {
    try {
      final key =
          'harvest_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}';

      double mangkok = 0.0, sudut = 0.0, oval = 0.0, patahan = 0.0;

      // Try SharedPreferences first
      try {
        final prefs = await SharedPreferences.getInstance();
        mangkok = prefs.getDouble('${key}_mangkok') ?? 0.0;
        sudut = prefs.getDouble('${key}_sudut') ?? 0.0;
        oval = prefs.getDouble('${key}_oval') ?? 0.0;
        patahan = prefs.getDouble('${key}_patahan') ?? 0.0;
        print('Loaded data from SharedPreferences');
      } catch (e) {
        print('SharedPreferences failed, using static storage: $e');
        // Fallback to static storage from AddHarvestPage
        try {
          final staticData = AddHarvestPage.getStoredData();
          mangkok = (staticData['${key}_mangkok'] as num?)?.toDouble() ?? 0.0;
          sudut = (staticData['${key}_sudut'] as num?)?.toDouble() ?? 0.0;
          oval = (staticData['${key}_oval'] as num?)?.toDouble() ?? 0.0;
          patahan = (staticData['${key}_patahan'] as num?)?.toDouble() ?? 0.0;
          print('Loaded data from static storage');
        } catch (staticError) {
          print('Static storage also failed: $staticError');
          // Use default values (already set to 0.0)
        }
      }

      // Load floor data
      List<Map<String, dynamic>> floorData = [];
      for (int i = 0; i < _selectedCageFloors; i++) {
        double floorMangkok = 0.0,
            floorSudut = 0.0,
            floorOval = 0.0,
            floorPatahan = 0.0;

        try {
          final prefs = await SharedPreferences.getInstance();
          floorMangkok =
              prefs.getDouble('${key}_floor_${i + 1}_mangkok') ?? 0.0;
          floorSudut = prefs.getDouble('${key}_floor_${i + 1}_sudut') ?? 0.0;
          floorOval = prefs.getDouble('${key}_floor_${i + 1}_oval') ?? 0.0;
          floorPatahan =
              prefs.getDouble('${key}_floor_${i + 1}_patahan') ?? 0.0;
        } catch (e) {
          // Fallback to static storage
          try {
            //getStoreddata
            final staticData = AddHarvestPage.getStoredData();
            floorMangkok = (staticData['${key}_floor_${i + 1}_mangkok'] as num?)
                    ?.toDouble() ??
                0.0;
            floorSudut = (staticData['${key}_floor_${i + 1}_sudut'] as num?)
                    ?.toDouble() ??
                0.0;
            floorOval = (staticData['${key}_floor_${i + 1}_oval'] as num?)
                    ?.toDouble() ??
                0.0;
            floorPatahan = (staticData['${key}_floor_${i + 1}_patahan'] as num?)
                    ?.toDouble() ??
                0.0;
          } catch (staticError) {
            print('Static storage failed for floor ${i + 1}: $staticError');
            // Use default values (already set to 0.0)
          }
        }

        floorData.add({
          'floor': i + 1,
          'mangkok': floorMangkok.toStringAsFixed(1),
          'sudut': floorSudut.toStringAsFixed(1),
          'oval': floorOval.toStringAsFixed(1),
          'patahan': floorPatahan.toStringAsFixed(1),
        });
      }

      setState(() {
        _harvestData = {
          'mangkok': mangkok,
          'sudut': sudut,
          'oval': oval,
          'patahan': patahan,
        };
        _floorData = floorData;
      });

      print('Analysis data loaded: $_harvestData');
    } catch (e) {
      print('Error loading harvest data: $e');
      // Set default zero data on error
      setState(() {
        _harvestData = {
          'mangkok': 0.0,
          'sudut': 0.0,
          'oval': 0.0,
          'patahan': 0.0,
        };
        _initializeFloorData();
      });
    }
  }

  double get _totalHarvest {
    return _harvestData.values.fold(0.0, (sum, value) => sum + value);
  }

  String get _totalIncome {
    double income = _totalHarvest * 50000;
    return 'Rp ${income.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  List<PieChartSectionData> _getChartData() {
    if (_totalHarvest == 0) {
      return [
        PieChartSectionData(
          value: 1,
          color: Colors.grey[300]!,
          title: 'No Data',
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ];
    }

    List<PieChartSectionData> sections = [];

    if (_harvestData['mangkok'] > 0) {
      sections.add(PieChartSectionData(
        value: _harvestData['mangkok'],
        color: const Color(0xFF245C4C),
        title: '${_harvestData['mangkok']} Kg',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
    }

    if (_harvestData['sudut'] > 0) {
      sections.add(PieChartSectionData(
        value: _harvestData['sudut'],
        color: const Color(0xFFffc200),
        title: '${_harvestData['sudut']} Kg',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
    }

    if (_harvestData['oval'] > 0) {
      sections.add(PieChartSectionData(
        value: _harvestData['oval'],
        color: const Color(0xFF168AB5),
        title: '${_harvestData['oval']} Kg',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
    }

    if (_harvestData['patahan'] > 0) {
      sections.add(PieChartSectionData(
        value: _harvestData['patahan'],
        color: const Color(0xFFC20000),
        title: '${_harvestData['patahan']} Kg',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
    }

    // Return the "No Data" chart if no sections have data
    return sections.isEmpty
        ? [
            PieChartSectionData(
              value: 1,
              color: Colors.grey[300]!,
              title: 'No Data',
              radius: 60,
              titleStyle: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ]
        : sections;
  }

  void _showDatePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pilih Bulan dan Tahun'),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: _selectedMonth,
                decoration: InputDecoration(
                  labelText: 'Bulan',
                  border: OutlineInputBorder(),
                ),
                items: List.generate(12, (index) {
                  return DropdownMenuItem(
                    value: index + 1,
                    child: Text(_months[index]),
                  );
                }),
                onChanged: (value) {
                  setState(() {
                    _selectedMonth = value!;
                  });
                },
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _selectedYear,
                decoration: InputDecoration(
                  labelText: 'Tahun',
                  border: OutlineInputBorder(),
                ),
                items: List.generate(10, (index) {
                  int year = DateTime.now().year - 5 + index;
                  return DropdownMenuItem(
                    value: year,
                    child: Text(year.toString()),
                  );
                }),
                onChanged: (value) {
                  setState(() {
                    _selectedYear = value!;
                  });
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _loadHarvestData();
            },
            child: Text('OK'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF245C4C),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Analisis Panen - $_selectedCageName'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Color(0xFF245C4C),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withOpacity(0.9),
                Colors.white.withOpacity(0.7),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Selection Button
            Center(
              child: Container(
                margin: EdgeInsets.only(bottom: 16),
                child: ElevatedButton.icon(
                  onPressed: _showDatePicker,
                  icon: Icon(Icons.calendar_month, size: 18),
                  label: Text(
                    '${_months[_selectedMonth - 1]} $_selectedYear',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFFF7CA),
                    foregroundColor: Color(0xFF245C4C),
                    elevation: 2,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Color(0xFFffc200)),
                    ),
                  ),
                ),
              ),
            ),

            // First Section: Pie Chart and Legend
            Container(
              height: height(context) * 0.32,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Pie Chart
                  Expanded(
                    flex: 3,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: PieChart(
                        PieChartData(
                          sections: _getChartData(),
                          centerSpaceRadius: 30,
                          sectionsSpace: 2,
                        ),
                      ),
                    ),
                  ),

                  // Legend
                  Expanded(
                    flex: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLegendItem('Mangkok',
                            '${_harvestData['mangkok']} Kg', Color(0xFF245C4C)),
                        SizedBox(height: 8),
                        _buildLegendItem('Sudut', '${_harvestData['sudut']} Kg',
                            Color(0xFFffc200)),
                        SizedBox(height: 8),
                        _buildLegendItem('Oval', '${_harvestData['oval']} Kg',
                            Color(0xFF168AB5)),
                        SizedBox(height: 8),
                        _buildLegendItem('Patahan',
                            '${_harvestData['patahan']} Kg', Color(0xFFC20000)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // Second Section: Cycle and Income (Same Width)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFFFFF7CA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Color(0xFFffc200)),
                    ),
                    child: const Text(
                      'Siklus Panen\n40-45 Hari',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF245C4C),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFFFFF7CA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Color(0xFFffc200)),
                    ),
                    child: Text(
                      'Rekap Pendapatan\n$_totalIncome',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF245C4C),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Time Selection for Table
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Data Panen ${_months[_selectedMonth - 1]} $_selectedYear',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF245C4C),
                  ),
                ),
              ],
            ),

            SizedBox(height: 8),

            // Third Section: Total and Floor Table (Same Width)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Sarang Dipetik',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF245C4C),
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '${_totalHarvest.toStringAsFixed(1)} Kg',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFffc200),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(width: 12),

                // Floor Table
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      children: [
                        // Table Header
                        Container(
                          padding:
                              EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          decoration: BoxDecoration(
                            color: Color(0xFF245C4C),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(7),
                              topRight: Radius.circular(7),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Lantai',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Expanded(
                                  child: Text('M',
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white),
                                      textAlign: TextAlign.center)),
                              Expanded(
                                  child: Text('S',
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white),
                                      textAlign: TextAlign.center)),
                              Expanded(
                                  child: Text('O',
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white),
                                      textAlign: TextAlign.center)),
                              Expanded(
                                  child: Text('P',
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white),
                                      textAlign: TextAlign.center)),
                            ],
                          ),
                        ),

                        // Table Rows
                        ..._floorData
                            .map((floor) => Container(
                                  padding: EdgeInsets.symmetric(
                                      vertical: 6, horizontal: 8),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom:
                                          BorderSide(color: Colors.grey[200]!),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Lt ${floor['floor']}',
                                          style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                      Expanded(
                                          child: Text('${floor['mangkok']}',
                                              style: TextStyle(fontSize: 8),
                                              textAlign: TextAlign.center)),
                                      Expanded(
                                          child: Text('${floor['sudut']}',
                                              style: TextStyle(fontSize: 8),
                                              textAlign: TextAlign.center)),
                                      Expanded(
                                          child: Text('${floor['oval']}',
                                              style: TextStyle(fontSize: 8),
                                              textAlign: TextAlign.center)),
                                      Expanded(
                                          child: Text('${floor['patahan']}',
                                              style: TextStyle(fontSize: 8),
                                              textAlign: TextAlign.center)),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            SizedBox(height: 20),

            // Add Harvest Button
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddHarvestPage(
                        cageName: _selectedCageName,
                        floors: _selectedCageFloors,
                      ),
                    ),
                  ).then((result) {
                    // Reload data when returning from add harvest page
                    if (result == true) {
                      _loadHarvestData();
                    }
                  });
                },
                icon: Icon(Icons.add, color: Colors.white, size: 20),
                label: Text(
                  'Tambah Panen',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF245C4C),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            SizedBox(height: 80),
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
                },
              ),
              label: ''),
          BottomNavigationBarItem(
              icon: CustomBottomNavigationItem(
                icon: Icons.chat_sharp,
                label: 'Panen',
                currentIndex: _currentIndex,
                itemIndex: 2,
                onTap: () {},
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
                },
              ),
              label: ''),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF245C4C),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
