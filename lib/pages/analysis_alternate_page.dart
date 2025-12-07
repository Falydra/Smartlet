import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
// Removed local storage fallback imports; analysis will use API-only
import 'package:swiftlead/pages/add_harvest_page.dart';
import 'package:swiftlead/pages/general_harvest_input_page.dart';
import 'package:swiftlead/components/custom_bottom_navigation.dart';
import 'package:swiftlead/services/harvest_services.dart';
import 'package:swiftlead/services/house_services.dart';
import 'package:swiftlead/utils/token_manager.dart';

class AnalysisPageAlternate extends StatefulWidget {
  final String? selectedCageId;

  const AnalysisPageAlternate({super.key, this.selectedCageId});

  @override
  State<AnalysisPageAlternate> createState() => _AnalysisPageAlternateState();
}

class _AnalysisPageAlternateState extends State<AnalysisPageAlternate>
    with WidgetsBindingObserver {
  double width(BuildContext context) => MediaQuery.of(context).size.width;
  double height(BuildContext context) => MediaQuery.of(context).size.height;

  int _currentIndex = 2;

  // API Services
  final HarvestService _harvestService = HarvestService();
  final HouseService _houseService = HouseService();

  // State management
  // Removed unused _isLoading field (was not referenced)
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

  // Harvest ratio data (from post-harvest)
  double _preHarvestTotal = 0.0;
  double _recommendedHarvest = 0.0;
  double _actualHarvest = 0.0;
  double _harvestRatio = 0.0;
  bool _followedRecommendation = false;

  // Cage data
  String _selectedCageName = "Kandang 1";
  int _selectedCageFloors = 3;
  String? _selectedHouseId; // Changed to String to support UUID

  // Floor data template
  List<Map<String, dynamic>> _floorData = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize with default data first
    _initializeFloorData();
    // If this page was opened from the home carousel, widget.selectedCageId
    // may contain a value like 'house_<id>'. Extract the ID part.
    if (widget.selectedCageId != null) {
      try {
        _selectedHouseId = widget.selectedCageId!.replaceFirst('house_', '');
      } catch (e) {
        // ignore parse errors
      }
    }

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
    // Loading flag removed (unused); keep method lean

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

    // Loading complete
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
                _selectedHouseId = selectedHouse['id']?.toString();
                // API uses 'total_floors', fallback to 'floor_count' for compatibility
                _selectedCageFloors = selectedHouse['total_floors'] ??
                    selectedHouse['floor_count'] ??
                    3;
                _selectedCageName = selectedHouse['name'] ??
                    "Kandang ${_selectedCageFloors} Lantai";
              });
            }

            _initializeFloorData();
            return;
          }
        } catch (e) {
          print('Error loading houses from API: $e');
        }
      }

      // If API didn't provide houses, fallback to sensible defaults (no local storage)
      if (mounted) {
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
      // Build API-only harvest aggregate for selected month/year
      double mangkok = 0.0, sudut = 0.0, oval = 0.0, patahan = 0.0;
      double preHarvestMangkok = 0.0,
          preHarvestSudut = 0.0,
          preHarvestOval = 0.0,
          preHarvestPatahan = 0.0;
      bool hasDetailedData = false;
      bool hasPostHarvestData = false;
      bool hasPreHarvestBreakdown = false;

      // Prepare floorData template
      List<Map<String, dynamic>> floorData = List.generate(
          _selectedCageFloors,
          (index) => {
                'floor': index + 1,
                'mangkok': '0.0',
                'sudut': '0.0',
                'oval': '0.0',
                'patahan': '0.0',
              });

      double preHarvestTotal = 0.0;
      double recommendedHarvest = 0.0;
      double actualHarvest = 0.0;
      double harvestRatio = 0.0;
      bool followedRecommendation = false;

      if (_authToken != null) {
        try {
          final harvests =
              await _harvestService.getAll(_authToken!, limit: 1000);

          // First pass: collect pre-harvest and post-harvest data
          for (var harvest in harvests) {
            // Try several possible date fields
            DateTime? harvestDate;
            if (harvest['harvest_date'] != null) {
              harvestDate = DateTime.tryParse(harvest['harvest_date']);
            }
            if (harvestDate == null && harvest['harvested_at'] != null) {
              harvestDate = DateTime.tryParse(harvest['harvested_at']);
            }

            bool isCorrectHouse = _selectedHouseId == null ||
                (harvest['rbw_id']?.toString() == _selectedHouseId) ||
                (harvest['house_id']?.toString() == _selectedHouseId);

            if (harvestDate != null &&
                harvestDate.month == _selectedMonth &&
                harvestDate.year == _selectedYear &&
                isCorrectHouse) {
              final notes = (harvest['notes'] as String?) ?? '';
              final floorNo = (harvest['floor_no'] as int?) ?? 0;
              final nestsCount =
                  (harvest['nests_count'] as num?)?.toDouble() ?? 0.0;

              // Check if this is a pre-harvest plan (notes start with PRE_HARVEST_PLAN)
              if (notes.startsWith('PRE_HARVEST_PLAN')) {
                // Parse pre-harvest data from notes: PRE_HARVEST_PLAN|recommended:X|total:Y
                preHarvestTotal += nestsCount;

                // Extract recommended value from notes
                final recMatch = RegExp(r'recommended:(\d+)').firstMatch(notes);
                if (recMatch != null) {
                  recommendedHarvest +=
                      double.tryParse(recMatch.group(1) ?? '0') ?? 0.0;
                }

                // Try to parse breakdown from notes if available
                if (notes.contains('Mangkok:') || notes.contains('mangkok:')) {
                  hasPreHarvestBreakdown = true;
                  final mangkokMatch =
                      RegExp(r'Mangkok:\s*(\d+)', caseSensitive: false)
                          .firstMatch(notes);
                  final sudutMatch =
                      RegExp(r'Sudut:\s*(\d+)', caseSensitive: false)
                          .firstMatch(notes);
                  final ovalMatch =
                      RegExp(r'Oval:\s*(\d+)', caseSensitive: false)
                          .firstMatch(notes);
                  final patahanMatch =
                      RegExp(r'Patahan:\s*(\d+)', caseSensitive: false)
                          .firstMatch(notes);

                  double mangkokCount = mangkokMatch != null
                      ? (double.tryParse(mangkokMatch.group(1) ?? '0') ?? 0.0)
                      : 0.0;
                  double sudutCount = sudutMatch != null
                      ? (double.tryParse(sudutMatch.group(1) ?? '0') ?? 0.0)
                      : 0.0;
                  double ovalCount = ovalMatch != null
                      ? (double.tryParse(ovalMatch.group(1) ?? '0') ?? 0.0)
                      : 0.0;
                  double patahanCount = patahanMatch != null
                      ? (double.tryParse(patahanMatch.group(1) ?? '0') ?? 0.0)
                      : 0.0;

                  // Accumulate pre-harvest breakdown
                  preHarvestMangkok += mangkokCount;
                  preHarvestSudut += sudutCount;
                  preHarvestOval += ovalCount;
                  preHarvestPatahan += patahanCount;

                  // Update floor data with detailed breakdown (only if no post-harvest yet)
                  if (floorNo > 0 &&
                      floorNo <= _selectedCageFloors &&
                      !hasPostHarvestData) {
                    floorData[floorNo - 1]['mangkok'] =
                        mangkokCount.toStringAsFixed(1);
                    floorData[floorNo - 1]['sudut'] =
                        sudutCount.toStringAsFixed(1);
                    floorData[floorNo - 1]['oval'] =
                        ovalCount.toStringAsFixed(1);
                    floorData[floorNo - 1]['patahan'] =
                        patahanCount.toStringAsFixed(1);
                  }

                  print(
                      'Parsed PRE_HARVEST: Floor $floorNo - M:$mangkokCount S:$sudutCount O:$ovalCount P:$patahanCount');
                } else {
                  // No detailed breakdown, use total for mangkok column
                  if (floorNo > 0 &&
                      floorNo <= _selectedCageFloors &&
                      !hasPostHarvestData) {
                    floorData[floorNo - 1]['mangkok'] =
                        nestsCount.toStringAsFixed(1);
                  }
                }
              }
              // Check if this is a post-harvest (notes start with POST_HARVEST)
              else if (notes.startsWith('POST_HARVEST')) {
                hasPostHarvestData = true;
                hasDetailedData = true;

                // NEW FORMAT: POST_HARVEST|ratio:X%|followed:yes/no
                // Use nests_count directly as the actual harvest amount
                actualHarvest += nestsCount;

                // Extract ratio if available
                final ratioMatch = RegExp(r'ratio:([\d.]+)').firstMatch(notes);
                if (ratioMatch != null) {
                  harvestRatio =
                      (double.tryParse(ratioMatch.group(1) ?? '0') ?? 0.0) /
                          100.0;
                }

                // Extract followed recommendation flag
                final followedMatch =
                    RegExp(r'followed:(yes|no)').firstMatch(notes);
                if (followedMatch != null && followedMatch.group(1) == 'yes') {
                  followedRecommendation = true;
                }

                // Try to parse breakdown from notes if available
                if (notes.contains('Mangkok:') || notes.contains('mangkok:')) {
                  final mangkokMatch =
                      RegExp(r'Mangkok:\s*(\d+)', caseSensitive: false)
                          .firstMatch(notes);
                  final sudutMatch =
                      RegExp(r'Sudut:\s*(\d+)', caseSensitive: false)
                          .firstMatch(notes);
                  final ovalMatch =
                      RegExp(r'Oval:\s*(\d+)', caseSensitive: false)
                          .firstMatch(notes);
                  final patahanMatch =
                      RegExp(r'Patahan:\s*(\d+)', caseSensitive: false)
                          .firstMatch(notes);

                  double mangkokCount = mangkokMatch != null
                      ? (double.tryParse(mangkokMatch.group(1) ?? '0') ?? 0.0)
                      : 0.0;
                  double sudutCount = sudutMatch != null
                      ? (double.tryParse(sudutMatch.group(1) ?? '0') ?? 0.0)
                      : 0.0;
                  double ovalCount = ovalMatch != null
                      ? (double.tryParse(ovalMatch.group(1) ?? '0') ?? 0.0)
                      : 0.0;
                  double patahanCount = patahanMatch != null
                      ? (double.tryParse(patahanMatch.group(1) ?? '0') ?? 0.0)
                      : 0.0;

                  // Add to total breakdown
                  mangkok += mangkokCount;
                  sudut += sudutCount;
                  oval += ovalCount;
                  patahan += patahanCount;

                  // Update floor data with detailed breakdown
                  if (floorNo > 0 && floorNo <= _selectedCageFloors) {
                    floorData[floorNo - 1]['mangkok'] =
                        mangkokCount.toStringAsFixed(1);
                    floorData[floorNo - 1]['sudut'] =
                        sudutCount.toStringAsFixed(1);
                    floorData[floorNo - 1]['oval'] =
                        ovalCount.toStringAsFixed(1);
                    floorData[floorNo - 1]['patahan'] =
                        patahanCount.toStringAsFixed(1);
                  }

                  print(
                      'Parsed POST_HARVEST: Floor $floorNo - M:$mangkokCount S:$sudutCount O:$ovalCount P:$patahanCount');
                } else {
                  // No detailed breakdown, divide equally among 4 types for pie chart
                  // This ensures the pie chart shows all harvested nests
                  double perType = nestsCount / 4.0;
                  mangkok += perType;
                  sudut += perType;
                  oval += perType;
                  patahan += perType;

                  // Update floor data - show total in mangkok column for display
                  if (floorNo > 0 && floorNo <= _selectedCageFloors) {
                    floorData[floorNo - 1]['mangkok'] =
                        nestsCount.toStringAsFixed(1);
                  }

                  print(
                      'POST_HARVEST without breakdown: Floor $floorNo - Total:$nestsCount (divided equally for pie chart)');
                }
              }
              // Parse standard harvest data format: "Mangkok: X, Sudut: Y, Oval: Z, Patahan: W"
              else if (notes.contains('Mangkok:') ||
                  notes.contains('mangkok:')) {
                hasPostHarvestData = true;
                hasDetailedData = true;
                actualHarvest += nestsCount;

                // Parse the breakdown from notes
                final mangkokMatch =
                    RegExp(r'Mangkok:\s*(\d+)', caseSensitive: false)
                        .firstMatch(notes);
                final sudutMatch =
                    RegExp(r'Sudut:\s*(\d+)', caseSensitive: false)
                        .firstMatch(notes);
                final ovalMatch = RegExp(r'Oval:\s*(\d+)', caseSensitive: false)
                    .firstMatch(notes);
                final patahanMatch =
                    RegExp(r'Patahan:\s*(\d+)', caseSensitive: false)
                        .firstMatch(notes);

                double mangkokCount = mangkokMatch != null
                    ? (double.tryParse(mangkokMatch.group(1) ?? '0') ?? 0.0)
                    : 0.0;
                double sudutCount = sudutMatch != null
                    ? (double.tryParse(sudutMatch.group(1) ?? '0') ?? 0.0)
                    : 0.0;
                double ovalCount = ovalMatch != null
                    ? (double.tryParse(ovalMatch.group(1) ?? '0') ?? 0.0)
                    : 0.0;
                double patahanCount = patahanMatch != null
                    ? (double.tryParse(patahanMatch.group(1) ?? '0') ?? 0.0)
                    : 0.0;

                // Add to total breakdown
                mangkok += mangkokCount;
                sudut += sudutCount;
                oval += ovalCount;
                patahan += patahanCount;

                // Update floor data with detailed breakdown
                if (floorNo > 0 && floorNo <= _selectedCageFloors) {
                  floorData[floorNo - 1]['mangkok'] =
                      mangkokCount.toStringAsFixed(1);
                  floorData[floorNo - 1]['sudut'] =
                      sudutCount.toStringAsFixed(1);
                  floorData[floorNo - 1]['oval'] = ovalCount.toStringAsFixed(1);
                  floorData[floorNo - 1]['patahan'] =
                      patahanCount.toStringAsFixed(1);
                }

                print(
                    'Parsed harvest: Floor $floorNo - M:$mangkokCount S:$sudutCount O:$ovalCount P:$patahanCount');
              }
              // Catch any other harvest data without specific format
              else if (nestsCount > 0) {
                // This is harvest data without specific format markers
                // Treat as post-harvest and divide equally for pie chart
                hasPostHarvestData = true;
                actualHarvest += nestsCount;

                // Divide equally among 4 types for pie chart
                double perType = nestsCount / 4.0;
                mangkok += perType;
                sudut += perType;
                oval += perType;
                patahan += perType;

                // Update floor data - show total in mangkok column for display
                if (floorNo > 0 && floorNo <= _selectedCageFloors) {
                  floorData[floorNo - 1]['mangkok'] =
                      nestsCount.toStringAsFixed(1);
                }

                print(
                    'Generic harvest data: Floor $floorNo - Total:$nestsCount (divided equally for pie chart)');
              }
            }
          }

          print(
              'Loaded harvest data from API for house $_selectedHouseId: post-harvest total=$actualHarvest pre=$preHarvestTotal rec=$recommendedHarvest');
        } catch (apiError) {
          print('Error loading harvests from API: $apiError');
        }
      }

      // Try to get pre-harvest data from temporary storage if not loaded from API
      if (preHarvestTotal == 0.0) {
        try {
          final tempData = AddHarvestPage.getTempPreHarvestData();
          if (tempData.isNotEmpty) {
            preHarvestTotal =
                (tempData['totalPreHarvest'] as num?)?.toDouble() ?? 0.0;
            recommendedHarvest =
                (tempData['totalRecommended'] as num?)?.toDouble() ?? 0.0;
            print(
                'Loaded pre-harvest from temp storage: pre=$preHarvestTotal rec=$recommendedHarvest');
          }
        } catch (e) {
          print('Error loading temp pre-harvest data: $e');
        }
      }

      // If recommended/ratio missing, derive them
      if (recommendedHarvest == 0.0 && preHarvestTotal > 0.0) {
        recommendedHarvest = (preHarvestTotal * 0.75); // Changed to 75%
      }

      if (harvestRatio == 0.0 && preHarvestTotal > 0.0 && actualHarvest > 0.0) {
        double variance = preHarvestTotal > 0
            ? ((actualHarvest - recommendedHarvest).abs() / preHarvestTotal)
            : 0.0;
        if (variance <= 0.1) {
          harvestRatio = 0.75;
          followedRecommendation = true;
        } else {
          harvestRatio =
              preHarvestTotal > 0 ? (actualHarvest / preHarvestTotal) : 0.0;
        }
      }

      // Determine what to display in pie chart
      double generalTotal = 0.0;

      if (hasPostHarvestData && actualHarvest > 0.0) {
        // POST-HARVEST exists: show post-harvest data in pie chart
        // Use actual breakdown if we parsed it, otherwise divide equally
        if (mangkok > 0 || sudut > 0 || oval > 0 || patahan > 0) {
          // We have detailed breakdown from parsing notes
          generalTotal = mangkok + sudut + oval + patahan;
          hasDetailedData = true;
          print(
              'Using parsed harvest breakdown: M:$mangkok S:$sudut O:$oval P:$patahan Total:$generalTotal');
        } else {
          // No detailed breakdown, divide equally among 4 types for visualization
          final perType = actualHarvest / 4.0;
          mangkok = perType;
          sudut = perType;
          oval = perType;
          patahan = perType;
          generalTotal = actualHarvest;
          hasDetailedData = true;
          print(
              'Using POST_HARVEST data for pie chart: $actualHarvest divided equally');
        }
      } else if (preHarvestTotal > 0.0) {
        // Only PRE-HARVEST exists: show pre-harvest data in pie chart
        // Use actual breakdown if we parsed it, otherwise divide equally
        if (hasPreHarvestBreakdown &&
            (preHarvestMangkok > 0 ||
                preHarvestSudut > 0 ||
                preHarvestOval > 0 ||
                preHarvestPatahan > 0)) {
          // We have detailed breakdown from parsing PRE_HARVEST notes
          mangkok = preHarvestMangkok;
          sudut = preHarvestSudut;
          oval = preHarvestOval;
          patahan = preHarvestPatahan;
          generalTotal = mangkok + sudut + oval + patahan;
          hasDetailedData = true;
          print(
              'Using parsed PRE_HARVEST breakdown: M:$mangkok S:$sudut O:$oval P:$patahan Total:$generalTotal');
        } else {
          // No detailed breakdown, divide equally among 4 types for visualization
          final perType = preHarvestTotal / 4.0;
          mangkok = perType;
          sudut = perType;
          oval = perType;
          patahan = perType;
          generalTotal = preHarvestTotal;
          hasDetailedData = true;
          print(
              'Using PRE_HARVEST data for pie chart: $preHarvestTotal divided equally');
        }
      } else {
        // No data at all
        generalTotal = 0.0;
        hasDetailedData = false;
        print('No harvest data found for this period');
      }

      if (mounted) {
        setState(() {
          _harvestData = {
            'mangkok': mangkok,
            'sudut': sudut,
            'oval': oval,
            'patahan': patahan,
          };
          _generalTotalSarang = generalTotal;
          _preHarvestTotal = preHarvestTotal;
          _recommendedHarvest = recommendedHarvest;
          _actualHarvest = actualHarvest;
          _harvestRatio = harvestRatio;
          _followedRecommendation = followedRecommendation;
          _floorData = floorData;
        });
      }

      print(
          'Analysis data loaded: $_harvestData, hasDetailedData: $hasDetailedData');
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
    // Use API-derived floor data to determine whether detailed data exists
    bool hasDetailedData = _floorData.any((f) {
      double m = double.tryParse(f['mangkok']?.toString() ?? '0') ?? 0.0;
      double s = double.tryParse(f['sudut']?.toString() ?? '0') ?? 0.0;
      double o = double.tryParse(f['oval']?.toString() ?? '0') ?? 0.0;
      double p = double.tryParse(f['patahan']?.toString() ?? '0') ?? 0.0;
      return m > 0 || s > 0 || o > 0 || p > 0;
    });

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

    // Use nest counts instead of weight for pie chart
    List<PieChartSectionData> sections = [];
    final totalNests = _harvestData['mangkok'] +
        _harvestData['sudut'] +
        _harvestData['oval'] +
        _harvestData['patahan'];

    if (_harvestData['mangkok'] > 0) {
      final percentage = totalNests > 0
          ? (_harvestData['mangkok'] / totalNests * 100).toStringAsFixed(1)
          : '0';
      sections.add(PieChartSectionData(
        value: _harvestData['mangkok'],
        color: const Color(0xFF245C4C),
        title: '${_harvestData['mangkok'].toInt()}\n($percentage%)',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
    }

    if (_harvestData['sudut'] > 0) {
      final percentage = totalNests > 0
          ? (_harvestData['sudut'] / totalNests * 100).toStringAsFixed(1)
          : '0';
      sections.add(PieChartSectionData(
        value: _harvestData['sudut'],
        color: const Color(0xFFffc200),
        title: '${_harvestData['sudut'].toInt()}\n($percentage%)',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
    }

    if (_harvestData['oval'] > 0) {
      final percentage = totalNests > 0
          ? (_harvestData['oval'] / totalNests * 100).toStringAsFixed(1)
          : '0';
      sections.add(PieChartSectionData(
        value: _harvestData['oval'],
        color: const Color(0xFF168AB5),
        title: '${_harvestData['oval'].toInt()}\n($percentage%)',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
    }

    if (_harvestData['patahan'] > 0) {
      final percentage = totalNests > 0
          ? (_harvestData['patahan'] / totalNests * 100).toStringAsFixed(1)
          : '0';
      sections.add(PieChartSectionData(
        value: _harvestData['patahan'],
        color: const Color(0xFFC20000),
        title: '${_harvestData['patahan'].toInt()}\n($percentage%)',
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
        title: const Text('Pilih Bulan dan Tahun'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: _selectedMonth,
                decoration: const InputDecoration(
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
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _selectedYear,
                decoration: const InputDecoration(
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
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _loadHarvestData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF245C4C),
              foregroundColor: Colors.white,
            ),
            child: Text('OK'),
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
        title: const Row(
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
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7CA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFffc200)),
                ),
                child: Text(
                  recommendationText,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF245C4C),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
            child: const Text('Tutup'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to detailed harvest page
              // Build floorLimits from pre-harvest data
              Map<int, int> floorLimits = {};
              for (var floorItem in _floorData) {
                int floorNo = floorItem['floor'] as int;
                double preHarvestValue =
                    double.tryParse(floorItem['mangkok'].toString()) ?? 0.0;
                floorLimits[floorNo] = preHarvestValue.toInt();
              }

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddHarvestPage(
                    cageName: _selectedCageName,
                    floors: _selectedCageFloors,
                    houseId: _selectedHouseId,
                    floorLimits: floorLimits,
                    selectedMonth: _selectedMonth,
                    selectedYear: _selectedYear,
                  ),
                ),
              ).then((result) {
                if (result == true || result != null) {
                  _loadHarvestData();
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF245C4C),
              foregroundColor: Colors.white,
            ),
            child: Text('Tambah Panen'),
          ),
        ],
      ),
    );
  }

  String _generateHarvestRecommendation() {
    // Case 1: No pre-harvest data available
    if (_preHarvestTotal == 0 && _generalTotalSarang == 0) {
      return "Belum ada data pre-harvest untuk periode ini.\n\n"
          "Disarankan untuk:\n"
          "• Input data pre-harvest terlebih dahulu\n"
          "• Lakukan pemeriksaan kondisi sarang di setiap lantai\n"
          "• Catat jumlah sarang untuk analisis selanjutnya";
    }

    // Case 2: Has pre-harvest data but no post-harvest data yet
    if (_totalHarvest == 0 && _preHarvestTotal > 0) {
      return "Pre-Harvest Data:\n"
          "Total sarang: ${_preHarvestTotal.toInt()}\n"
          "Rekomendasi panen (60%): ${_recommendedHarvest.toInt()} sarang\n\n"
          "Status: Belum ada data hasil panen\n\n"
          "Rekomendasi:\n"
          "• Lakukan panen sesuai rekomendasi\n"
          "• Input hasil panen setelah pemanenan\n"
          "• Sistem akan menghitung ratio panen otomatis";
    }

    // Case 3: Has post-harvest data - show ratio analysis
    if (_actualHarvest > 0 && _preHarvestTotal > 0) {
      String ratioText = _followedRecommendation
          ? "75% (Mengikuti rekomendasi ✓)"
          : "${(_harvestRatio * 100).toStringAsFixed(1)}%";

      String performance = "";
      if (_harvestRatio <= 0.60) {
        performance = "Excellent! Panen dalam batas optimal.";
      } else if (_harvestRatio <= 0.75) {
        performance = "Good! Panen sedikit melebihi optimal namun masih baik.";
      } else {
        performance = "Warning! Panen melebihi batas yang disarankan.";
      }

      return "Analisis Panen:\n\n"
              "Pre-Harvest:\n"
              "• Total sarang: ${_preHarvestTotal.toInt()}\n"
              "• Rekomendasi: ${_recommendedHarvest.toInt()} sarang\n\n"
              "Post-Harvest:\n"
              "• Hasil panen: ${_actualHarvest.toStringAsFixed(1)} \n"
              "• Ratio panen: $ratioText\n\n"
              "Status: $performance\n\n"
              "Rekomendasi Berikutnya:\n" +
          (_harvestRatio <= 0.60
              ? "• Pertahankan pola panen saat ini\n"
                  "• Jaga konsistensi kondisi lingkungan\n"
                  "• Panen berikutnya dalam 40-45 hari"
              : "• Kurangi intensitas panen berikutnya\n"
                  "• Beri waktu istirahat lebih lama (50-60 hari)\n"
                  "• Monitor regenerasi sarang dengan teliti");
    }

    // Fallback to old logic if data structure doesn't match
    double harvestPercentage = (_generalTotalSarang > 0)
        ? (_totalHarvest / _generalTotalSarang) * 100
        : 0;

    if (harvestPercentage <= 60) {
      return "Total sarang: ${_generalTotalSarang.toInt()}\n"
          "Hasil panen: $_totalHarvest (${harvestPercentage.toStringAsFixed(1)}% dari sarang)\n\n"
          "Panen dalam batas optimal! Rekomendasi:\n"
          "• Pertahankan pola panen saat ini\n"
          "• Jaga konsistensi kondisi lingkungan\n"
          "• Panen berikutnya dalam 40-45 hari";
    }

    return "Total sarang: ${_generalTotalSarang.toInt()}\n"
        "Hasil panen: $_totalHarvest  (${harvestPercentage.toStringAsFixed(1)}% dari sarang)\n\n"
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
        foregroundColor: const Color(0xFF245C4C),
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
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Selection Button
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                child: ElevatedButton.icon(
                  onPressed: _showDatePicker,
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: Text(
                    '${_months[_selectedMonth - 1]} $_selectedYear',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF7CA),
                    foregroundColor: const Color(0xFF245C4C),
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Color(0xFFffc200)),
                    ),
                  ),
                ),
              ),
            ),

            // First Section: Pie Chart and Legend
            Container(
              height: height(context) * 0.32,
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
                        _buildLegendItem(
                            'Mangkok',
                            '${_harvestData['mangkok'].toInt()} sarang',
                            const Color(0xFF245C4C)),
                        const SizedBox(height: 8),
                        _buildLegendItem(
                            'Sudut',
                            '${_harvestData['sudut'].toInt()} sarang',
                            const Color(0xFFffc200)),
                        const SizedBox(height: 8),
                        _buildLegendItem(
                            'Oval',
                            '${_harvestData['oval'].toInt()} sarang',
                            const Color(0xFF168AB5)),
                        const SizedBox(height: 8),
                        _buildLegendItem(
                            'Patahan',
                            '${_harvestData['patahan'].toInt()} sarang',
                            const Color(0xFFC20000)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Second Section: Cycle, Sarang, and Income
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7CA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFffc200)),
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
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F8FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF168AB5)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Total Sarang',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF168AB5),
                          ),
                        ),
                        Text(
                          '${_generalTotalSarang.toInt()}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF168AB5),
                          ),
                        ),
                        Text(
                          'Optimal: ${_preHarvestTotal > 0 ? (_preHarvestTotal * 0.75).toInt() : (_generalTotalSarang * 0.75).toInt()}',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF168AB5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7CA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFffc200)),
                    ),
                    child: Text(
                      'Rekap Pendapatan\n$_totalIncome',
                      style: const TextStyle(
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

            const SizedBox(height: 16),

            // Time Selection for Table
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Data Panen ${_months[_selectedMonth - 1]} $_selectedYear',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF245C4C),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Third Section: Total and Floor Table (Same Width)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Sarang Dipetik',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF245C4C),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_totalHarvest.toStringAsFixed(0)} sarang',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFffc200),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 12),

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
                          padding: const EdgeInsets.symmetric(
                              vertical: 6, horizontal: 8),
                          decoration: const BoxDecoration(
                            color: Color(0xFF245C4C),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(7),
                              topRight: Radius.circular(7),
                            ),
                          ),
                          child: const Row(
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
                        ..._floorData.map((floor) => Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 6, horizontal: 8),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: Colors.grey[200]!),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Lt ${floor['floor']}',
                                      style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  Expanded(
                                      child: Text('${floor['mangkok']}',
                                          style: const TextStyle(fontSize: 8),
                                          textAlign: TextAlign.center)),
                                  Expanded(
                                      child: Text('${floor['sudut']}',
                                          style: const TextStyle(fontSize: 8),
                                          textAlign: TextAlign.center)),
                                  Expanded(
                                      child: Text('${floor['oval']}',
                                          style: const TextStyle(fontSize: 8),
                                          textAlign: TextAlign.center)),
                                  Expanded(
                                      child: Text('${floor['patahan']}',
                                          style: const TextStyle(fontSize: 8),
                                          textAlign: TextAlign.center)),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Build floorLimits from pre-harvest data
                      Map<int, int> floorLimits = {};
                      for (var floorItem in _floorData) {
                        int floorNo = floorItem['floor'] as int;
                        double preHarvestValue =
                            double.tryParse(floorItem['mangkok'].toString()) ??
                                0.0;
                        floorLimits[floorNo] = preHarvestValue.toInt();
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddHarvestPage(
                            cageName: _selectedCageName,
                            floors: _selectedCageFloors,
                            houseId: _selectedHouseId,
                            floorLimits: floorLimits,
                            selectedMonth: _selectedMonth,
                            selectedYear: _selectedYear,
                          ),
                        ),
                      ).then((result) {
                        // Always reload data when returning from add harvest page
                        // This ensures the table updates with any new detailed harvest data
                        _loadHarvestData();
                      });
                    },
                    icon: const Icon(Icons.add, color: Colors.white, size: 18),
                    label: const Text(
                      'Tambah Panen',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF245C4C),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Navigate to edit pre-harvest data
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GeneralHarvestInputPage(
                            cageName: _selectedCageName,
                            floors: _selectedCageFloors,
                            houseId: _selectedHouseId,
                            selectedMonth: _selectedMonth,
                            selectedYear: _selectedYear,
                          ),
                        ),
                      ).then((result) {
                        // Reload data after editing pre-harvest
                        _loadHarvestData();
                      });
                    },
                    icon: const Icon(Icons.edit, color: Colors.white, size: 18),
                    label: const Text(
                      'Edit Pre-Harvest',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5C7C4C),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Recommendation Button (full width)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Show harvest recommendation dialog
                  _showHarvestRecommendation();
                },
                icon: const Icon(Icons.lightbulb,
                    color: Color(0xFF245C4C), size: 18),
                label: const Text(
                  'Rekomendasi Panen',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF245C4C),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFF7CA),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFffc200)),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            const SizedBox(height: 80),
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
        const SizedBox(width: 6),
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
                style: const TextStyle(
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
