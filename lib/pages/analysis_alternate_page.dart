import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swiftlead/pages/cage_selection_page.dart';
import 'package:swiftlead/pages/add_harvest_page.dart';
import 'package:swiftlead/pages/general_harvest_input_page.dart';
import 'package:swiftlead/components/custom_bottom_navigation.dart';
import 'package:swiftlead/shared/theme.dart';
import 'package:swiftlead/services/harvest_services.dart';
import 'package:swiftlead/services/house_services.dart';
import 'package:swiftlead/utils/token_manager.dart';

class AnalysisPageAlternate extends StatefulWidget {
  final String? selectedCageId;

  const AnalysisPageAlternate({Key? key, this.selectedCageId})
      : super(key: key);

  @override
  State<AnalysisPageAlternate> createState() => _AnalysisPageAlternateState();
}

class _AnalysisPageAlternateState extends State<AnalysisPageAlternate> with WidgetsBindingObserver {
  double width(BuildContext context) => MediaQuery.of(context).size.width;
  double height(BuildContext context) => MediaQuery.of(context).size.height;

  int _currentIndex = 2;

  // API Services
  final HarvestService _harvestService = HarvestService();
  final HouseService _houseService = HouseService();
  
  // State management
  bool _isLoading = true;
  String? _authToken;

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
  
  // General floor totals for optimal harvest calculation
  double _generalTotalSarang = 0.0;

  // Cage data
  String _selectedCageName = "Kandang 1";
  int _selectedCageFloors = 3;
  int? _selectedHouseId;

  // Floor data template
  List<Map<String, dynamic>> _floorData = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize with default data first
    _initializeFloorData();
    _initializeData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Refresh harvest data when app resumes to ensure latest data is shown
      _loadHarvestData();
    }
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
      
      // Load cage data
      await _loadCageData();
      _initializeFloorData();
      
      // Load harvest data (try API first, then local)
      await _loadHarvestData();
    } catch (e) {
      print('Error initializing analysis data: $e');
    }
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCageData() async {
    try {
      // Try to load house data from API first
      if (_authToken != null) {
        try {
          final houses = await _houseService.getAll(_authToken!);
          if (houses.isNotEmpty) {
            // Use the first house or find by selectedCageId
            var selectedHouse = houses.first;
            if (widget.selectedCageId != null) {
              final houseId = widget.selectedCageId!.replaceFirst('house_', '');
              selectedHouse = houses.firstWhere(
                (house) => house['id'].toString() == houseId,
                orElse: () => houses.first,
              );
            }
            
            if (mounted) {
              setState(() {
                _selectedHouseId = selectedHouse['id'];
                _selectedCageFloors = selectedHouse['floor_count'] ?? 3;
                _selectedCageName = selectedHouse['name'] ?? "Kandang ${selectedHouse['floor_count'] ?? 3} Lantai";
              });
            }
            
            _initializeFloorData();
            return;
          }
        } catch (e) {
          print('Error loading houses from API: $e');
        }
      }
      
      // Fallback to SharedPreferences
      SharedPreferences? prefs;
      try {
        prefs = await SharedPreferences.getInstance();
        final savedFloors = prefs.getInt('cage_floors') ?? 3;

        if (mounted) {
          setState(() {
            _selectedCageFloors = savedFloors;
            _selectedCageName = "Kandang $savedFloors Lantai";
          });
        }
      } catch (e) {
        print('SharedPreferences not available, using default values: $e');
        if (mounted) {
          setState(() {
            _selectedCageFloors = 3;
            _selectedCageName = "Kandang 3 Lantai";
          });
        }
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
      bool hasDetailedData = false;

      // Try API first if token available
      if (_authToken != null) {
        try {
          final harvests = await _harvestService.getAll(_authToken!, limit: 1000);
          
          // Filter harvests for the selected month/year and house
          for (var harvest in harvests) {
            final harvestDate = DateTime.tryParse(harvest['harvest_date'] ?? '');
            bool isCorrectHouse = _selectedHouseId == null || harvest['house_id'] == _selectedHouseId;
            
            if (harvestDate != null && 
                harvestDate.month == _selectedMonth && 
                harvestDate.year == _selectedYear &&
                isCorrectHouse) {
              // Convert from API integer values to double
              mangkok += (harvest['mangkok'] as num?)?.toDouble() ?? 0.0;
              sudut += (harvest['sudut'] as num?)?.toDouble() ?? 0.0;
              oval += (harvest['oval'] as num?)?.toDouble() ?? 0.0;
              patahan += (harvest['patahan'] as num?)?.toDouble() ?? 0.0;
            }
          }
          print('Loaded harvest data from API for house $_selectedHouseId: M:$mangkok S:$sudut O:$oval P:$patahan');
        } catch (apiError) {
          print('API failed, falling back to local storage: $apiError');
        }
      }

      // Only load detailed data from AddHarvestPage saves (not from general input)
      if (mangkok == 0.0 && sudut == 0.0 && oval == 0.0 && patahan == 0.0) {
        try {
          // Check static storage from AddHarvestPage for detailed data
          final staticData = AddHarvestPage.getStoredData();
          mangkok = (staticData['${key}_mangkok'] as num?)?.toDouble() ?? 0.0;
          sudut = (staticData['${key}_sudut'] as num?)?.toDouble() ?? 0.0;
          oval = (staticData['${key}_oval'] as num?)?.toDouble() ?? 0.0;
          patahan = (staticData['${key}_patahan'] as num?)?.toDouble() ?? 0.0;
          
          // Check if we have actual detailed data (not just equal distribution)
          if (mangkok > 0 || sudut > 0 || oval > 0 || patahan > 0) {
            // Verify this is from detailed input by checking if floor data exists
            bool hasFloorDetails = false;
            for (int i = 0; i < _selectedCageFloors; i++) {
              if (staticData.containsKey('${key}_floor_${i + 1}_mangkok')) {
                hasFloorDetails = true;
                break;
              }
            }
            hasDetailedData = hasFloorDetails;
          }
          
          print('Loaded detailed data from AddHarvestPage: $hasDetailedData');
        } catch (staticError) {
          print('Static storage failed: $staticError');
          // Use default values (already set to 0.0)
        }
      } else {
        hasDetailedData = true; // Data from API is considered detailed
      }

      // Load floor data
      List<Map<String, dynamic>> floorData = [];
      for (int i = 0; i < _selectedCageFloors; i++) {
        double floorMangkok = 0.0,
            floorSudut = 0.0,
            floorOval = 0.0,
            floorPatahan = 0.0;

        // First try AddHarvestPage static storage for detailed data
        try {
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
          
          // Fallback to SharedPreferences
          try {
            final prefs = await SharedPreferences.getInstance();
            floorMangkok =
                prefs.getDouble('${key}_floor_${i + 1}_mangkok') ?? 0.0;
            floorSudut = prefs.getDouble('${key}_floor_${i + 1}_sudut') ?? 0.0;
            floorOval = prefs.getDouble('${key}_floor_${i + 1}_oval') ?? 0.0;
            floorPatahan =
                prefs.getDouble('${key}_floor_${i + 1}_patahan') ?? 0.0;
          } catch (prefsError) {
            print('SharedPreferences failed for floor ${i + 1}: $prefsError');
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
        
        // Log floor data for debugging
        print('Floor ${i + 1} data loaded: M:${floorMangkok.toStringAsFixed(1)} S:${floorSudut.toStringAsFixed(1)} O:${floorOval.toStringAsFixed(1)} P:${floorPatahan.toStringAsFixed(1)}');
      }

      // Load general total sarang for optimal harvest calculation
      double generalTotal = 0.0;
      try {
        if (_authToken != null) {
          // Try to get from API response if available
          final prefs = await SharedPreferences.getInstance();
          generalTotal = prefs.getDouble('${key}_general_total') ?? 0.0;
        } else {
          final prefs = await SharedPreferences.getInstance();
          generalTotal = prefs.getDouble('${key}_general_total') ?? 0.0;
        }
        
        // Fallback: calculate from static storage
        if (generalTotal == 0.0) {
          final staticData = AddHarvestPage.getStoredData();
          generalTotal = (staticData['${key}_general_total'] as num?)?.toDouble() ?? 0.0;
        }
      } catch (e) {
        print('Error loading general total: $e');
        generalTotal = 0.0;
      }

      if (mounted) {
        setState(() {
          _harvestData = {
            'mangkok': hasDetailedData ? mangkok : 0.0,
            'sudut': hasDetailedData ? sudut : 0.0,
            'oval': hasDetailedData ? oval : 0.0,
            'patahan': hasDetailedData ? patahan : 0.0,
          };
          _generalTotalSarang = generalTotal;
          _floorData = floorData;
        });
      }

            print('Analysis data loaded: $_harvestData, hasDetailedData: $hasDetailedData');
    } catch (e) {
      print('Error loading harvest data: $e');
      // Set default zero data on error
      if (mounted) {
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
  }

  // Public method to refresh harvest data (can be called from other pages)
  void refreshHarvestData() {
    _loadHarvestData();
  }

  double get _totalHarvest {
    return _harvestData.values.fold(0.0, (sum, value) => sum + value);
  }

  String get _totalIncome {
    double income = _totalHarvest * 50000;
    return 'Rp ${income.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  List<PieChartSectionData> _getChartData() {
    // Check if we have detailed harvest data (from AddHarvestPage)
    final key = 'harvest_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}';
    final staticData = AddHarvestPage.getStoredData();
    bool hasDetailedData = staticData.containsKey('${key}_mangkok') && 
                          (staticData['${key}_mangkok'] as num? ?? 0) > 0;
    
    if (_totalHarvest == 0 || !hasDetailedData) {
      return [
        PieChartSectionData(
          value: 1,
          color: Colors.grey[300]!,
          title: hasDetailedData ? 'No Data' : 'Input Detail\nTerlebih Dahulu',
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
                  if (mounted) {
                    setState(() {
                      _selectedMonth = value!;
                    });
                  }
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
                  if (mounted) {
                    setState(() {
                      _selectedYear = value!;
                    });
                  }
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

  void _showHarvestRecommendation() {
    String recommendationText = _generateHarvestRecommendation();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lightbulb, color: Color(0xFFffc200), size: 24),
            SizedBox(width: 8),
            Text(
              'Rekomendasi Panen',
              style: TextStyle(
                color: Color(0xFF245C4C),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFFFF7CA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xFFffc200)),
                ),
                child: Text(
                  recommendationText,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF245C4C),
                    height: 1.4,
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                '💡 Tips: Lakukan panen secara berkala setiap 40-45 hari untuk hasil optimal.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tutup'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to add harvest page
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GeneralHarvestInputPage(
                    cageName: _selectedCageName,
                    floors: _selectedCageFloors,
                  ),
                ),
              ).then((result) {
                if (result == true) {
                  _loadHarvestData();
                }
              });
            },
            child: Text('Tambah Panen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF245C4C),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String _generateHarvestRecommendation() {
    int optimalHarvest = (_generalTotalSarang * 0.6).round();
    
    if (_generalTotalSarang == 0) {
      return "Belum ada data sarang untuk periode ini. Disarankan untuk:\n\n"
             "• Input data sarang terlebih dahulu\n"
             "• Lakukan pemeriksaan kondisi sarang di setiap lantai\n"
             "• Catat jumlah sarang untuk analisis selanjutnya";
    }
    
    if (_totalHarvest == 0) {
      return "Total sarang: ${_generalTotalSarang.toInt()}\n"
             "Panen optimal yang disarankan: $optimalHarvest sarang (60%)\n\n"
             "Rekomendasi:\n"
             "• Mulai lakukan panen rutin setiap 40-45 hari\n"
             "• Panen tidak lebih dari 60% untuk menjaga regenerasi\n"
             "• Periksa kondisi sarang di setiap lantai";
    }
    
    double harvestPercentage = (_totalHarvest / _generalTotalSarang) * 100;
    
    if (harvestPercentage <= 60) {
      return "Total sarang: ${_generalTotalSarang.toInt()}\n"
             "Hasil panen: $_totalHarvest kg (${harvestPercentage.toStringAsFixed(1)}% dari sarang)\n\n"
             "Panen dalam batas optimal! Rekomendasi:\n"
             "• Pertahankan pola panen saat ini\n"
             "• Jaga konsistensi kondisi lingkungan\n"
             "• Panen berikutnya dalam 40-45 hari";
    }
    
    return "Total sarang: ${_generalTotalSarang.toInt()}\n"
           "Hasil panen: $_totalHarvest kg (${harvestPercentage.toStringAsFixed(1)}% dari sarang)\n\n"
           "Panen melebihi batas optimal (60%)! Rekomendasi:\n"
           "• Kurangi intensitas panen berikutnya\n"
           "• Beri waktu istirahat lebih lama (50-60 hari)\n"
           "• Monitor regenerasi sarang dengan teliti";
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

            // Second Section: Cycle, Sarang, and Income
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(16),
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
                SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFFF0F8FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Color(0xFF168AB5)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Total Sarang',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF168AB5),
                          ),
                        ),
                        Text(
                          '${_generalTotalSarang.toInt()}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF168AB5),
                          ),
                        ),
                        Text(
                          'Optimal: ${(_generalTotalSarang * 0.6).toInt()}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF168AB5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 8),
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

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GeneralHarvestInputPage(
                            cageName: _selectedCageName,
                            floors: _selectedCageFloors,
                            houseId: _selectedHouseId,
                          ),
                        ),
                      ).then((result) {
                        // Always reload data when returning from add harvest page
                        // This ensures the table updates with any new detailed harvest data
                        _loadHarvestData();
                      });
                    },
                    icon: Icon(Icons.add, color: Colors.white, size: 18),
                    label: Text(
                      'Tambah Panen',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF245C4C),
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Show harvest recommendation dialog
                      _showHarvestRecommendation();
                    },
                    icon: Icon(Icons.lightbulb, color: Color(0xFF245C4C), size: 18),
                    label: Text(
                      'Rekomendasi Panen',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF245C4C),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFFFF7CA),
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Color(0xFFffc200)),
                      ),
                    ),
                  ),
                ),
              ],
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
                  setState(() {
                    _currentIndex = 0;
                  });
                },
              ),
              label: ''),
          BottomNavigationBarItem(
              icon: CustomBottomNavigationItem(
                icon: Icons.electrical_services_sharp,
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
