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
  
  // Store harvest IDs for deletion management
  Map<int, List<String>> _floorHarvestIds = {};

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
      // Organize by MONTH, not by floor
      // SIMPLIFIED LOGIC: Just count nests from pre-harvest and post-harvest
      double preHarvestTotal = 0.0;
      double postHarvestTotal = 0.0;
      double recommendedHarvest = 0.0;
      double harvestRatio = 0.0;
      bool followedRecommendation = false;

      // For breakdown display (optional, parsed from notes if available)
      double mangkok = 0.0, sudut = 0.0, oval = 0.0, patahan = 0.0;

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
      
      // Clear and prepare harvest IDs map
      Map<int, List<String>> floorHarvestIds = {};

      if (_authToken != null) {
        try {
          final harvests =
              await _harvestService.getAll(_authToken!, limit: 1000);

          // SIMPLE LOGIC: Pre-harvest vs Post-harvest based on notes
          // Post-harvest OVERRIDES pre-harvest
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

              // SIMPLE: If notes starts with PRE_HARVEST_PLAN = pre-harvest
              // Everything else = post-harvest
              if (notes.startsWith('PRE_HARVEST_PLAN')) {
                // PRE-HARVEST
                preHarvestTotal += nestsCount;
                final recMatch = RegExp(r'recommended:(\\d+(?:\\.\\d+)?)').firstMatch(notes);
                if (recMatch != null) {
                  recommendedHarvest += double.tryParse(recMatch.group(1) ?? '0') ?? 0.0;
                }
                if (floorNo > 0 && floorNo <= _selectedCageFloors) {
                  floorData[floorNo - 1]['mangkok'] = nestsCount.toStringAsFixed(1);
                  // Store harvest ID for deletion management
                  final harvestId = harvest['id']?.toString();
                  if (harvestId != null) {
                    floorHarvestIds.putIfAbsent(floorNo, () => []).add(harvestId);
                  }
                }
                print('[PRE] Floor $floorNo: $nestsCount nests');
              } else if (nestsCount > 0) {
                // POST-HARVEST (overrides pre-harvest)
                // ALWAYS use nestsCount as the source of truth
                postHarvestTotal += nestsCount;
                
                // Try to parse breakdown if available for pie chart distribution
                // Check for ANY breakdown keyword (Mangkok, Sudut, Oval, or Patahan)
                if (notes.contains('Mangkok:') || notes.contains('Sudut:') || 
                    notes.contains('Oval:') || notes.contains('Patahan:')) {
                  final m = double.tryParse(RegExp(r'Mangkok:\s*(\d+(?:\.\d+)?)', caseSensitive: false).firstMatch(notes)?.group(1) ?? '0') ?? 0.0;
                  final s = double.tryParse(RegExp(r'Sudut:\s*(\d+(?:\.\d+)?)', caseSensitive: false).firstMatch(notes)?.group(1) ?? '0') ?? 0.0;
                  final o = double.tryParse(RegExp(r'Oval:\s*(\d+(?:\.\d+)?)', caseSensitive: false).firstMatch(notes)?.group(1) ?? '0') ?? 0.0;
                  final p = double.tryParse(RegExp(r'Patahan:\s*(\d+(?:\.\d+)?)', caseSensitive: false).firstMatch(notes)?.group(1) ?? '0') ?? 0.0;
                  
                  // Verify breakdown matches nestsCount
                  double breakdownTotal = m + s + o + p;
                  if ((breakdownTotal - nestsCount).abs() < 0.1) {
                    // Breakdown is valid, use it
                    mangkok += m; sudut += s; oval += o; patahan += p;
                    if (floorNo > 0 && floorNo <= _selectedCageFloors) {
                      floorData[floorNo - 1]['mangkok'] = m.toStringAsFixed(1);
                      floorData[floorNo - 1]['sudut'] = s.toStringAsFixed(1);
                      floorData[floorNo - 1]['oval'] = o.toStringAsFixed(1);
                      floorData[floorNo - 1]['patahan'] = p.toStringAsFixed(1);
                      // Store harvest ID for deletion management
                      final harvestId = harvest['id']?.toString();
                      if (harvestId != null) {
                        floorHarvestIds.putIfAbsent(floorNo, () => []).add(harvestId);
                      }
                    }
                    print('[POST] Floor $floorNo: $nestsCount nests with breakdown M:$m S:$s O:$o P:$p');
                  } else {
                    // Breakdown doesn't match nestsCount, ignore breakdown
                    // Don't add to breakdown variables - this will show total without breakdown
                    print('[POST] Floor $floorNo: $nestsCount nests (breakdown mismatch: $breakdownTotal)');
                    if (floorNo > 0 && floorNo <= _selectedCageFloors) {
                      floorData[floorNo - 1]['mangkok'] = nestsCount.toStringAsFixed(1);
                      // Store harvest ID for deletion management
                      final harvestId = harvest['id']?.toString();
                      if (harvestId != null) {
                        floorHarvestIds.putIfAbsent(floorNo, () => []).add(harvestId);
                      }
                    }
                  }
                } else {
                  // No breakdown in notes
                  // Don't add to breakdown variables - this will show total without breakdown
                  if (floorNo > 0 && floorNo <= _selectedCageFloors) {
                    floorData[floorNo - 1]['mangkok'] = nestsCount.toStringAsFixed(1);
                    // Store harvest ID for deletion management
                    final harvestId = harvest['id']?.toString();
                    if (harvestId != null) {
                      floorHarvestIds.putIfAbsent(floorNo, () => []).add(harvestId);
                    }
                  }
                  print('[POST] Floor $floorNo: $nestsCount nests (no breakdown)');
                }
              }
            }
          }

          print('[RESULT] Pre: $preHarvestTotal, Post: $postHarvestTotal, Rec: $recommendedHarvest');
        } catch (apiError) {
          print('Error loading harvests from API: $apiError');
        }
      }

      // Calculate defaults
      if (recommendedHarvest == 0.0 && preHarvestTotal > 0.0) {
        recommendedHarvest = (preHarvestTotal * 0.75);
      }

      // Determine what to display:
      // - If we have both pre and post, check if post-harvest is complete
      // - Post-harvest is considered complete if it's >= 50% of pre-harvest
      // - Otherwise, we're still in progress, show pre-harvest data
      double displayTotal;
      bool hasBreakdown = (mangkok > 0 || sudut > 0 || oval > 0 || patahan > 0);
      
      if (postHarvestTotal > 0 && preHarvestTotal > 0) {
        // We have both pre and post data
        if (postHarvestTotal >= preHarvestTotal * 0.5) {
          // Post-harvest looks complete, use it
          // If we have breakdown data, use breakdown sum (this excludes non-breakdown entries)
          // Otherwise use postHarvestTotal (includes all entries)
          displayTotal = hasBreakdown ? (mangkok + sudut + oval + patahan) : postHarvestTotal;
          print('[DISPLAY] Using POST (complete): $displayTotal (breakdown: $hasBreakdown)');
        } else {
          // Post-harvest is too small compared to pre-harvest, likely incomplete
          // Show pre-harvest instead
          displayTotal = preHarvestTotal;
          // Clear breakdown since we're not using post-harvest
          hasBreakdown = false;
          print('[DISPLAY] Using PRE (post incomplete: $postHarvestTotal < ${preHarvestTotal * 0.5})');
        }
      } else if (postHarvestTotal > 0) {
        // Only post-harvest data
        // If we have breakdown data, use breakdown sum (this excludes non-breakdown entries)
        // Otherwise use postHarvestTotal (includes all entries)
        displayTotal = hasBreakdown ? (mangkok + sudut + oval + patahan) : postHarvestTotal;
        print('[DISPLAY] Using POST (only): $displayTotal (breakdown: $hasBreakdown)');
      } else {
        // Only pre-harvest data or no data
        displayTotal = preHarvestTotal;
        print('[DISPLAY] Using PRE (only): $preHarvestTotal');
      }

      if (mounted) {
        setState(() {
          _harvestData = {
            'mangkok': hasBreakdown ? mangkok : 0.0,
            'sudut': hasBreakdown ? sudut : 0.0,
            'oval': hasBreakdown ? oval : 0.0,
            'patahan': hasBreakdown ? patahan : 0.0,
          };
          _generalTotalSarang = displayTotal;
          _preHarvestTotal = preHarvestTotal;
          _recommendedHarvest = recommendedHarvest;
          _actualHarvest = postHarvestTotal;
          _harvestRatio = harvestRatio;
          _followedRecommendation = followedRecommendation;
          _floorData = floorData;
          _floorHarvestIds = floorHarvestIds;
        });
      }

      print('[FINAL] Display: $displayTotal, Breakdown: $hasBreakdown (M:$mangkok S:$sudut O:$oval P:$patahan)');
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
    // Calculate from _floorData (same as table and pie chart)
    double total = 0.0;
    for (var floor in _floorData) {
      total += double.tryParse(floor['mangkok'].toString()) ?? 0.0;
      total += double.tryParse(floor['sudut'].toString()) ?? 0.0;
      total += double.tryParse(floor['oval'].toString()) ?? 0.0;
      total += double.tryParse(floor['patahan'].toString()) ?? 0.0;
    }
    return total;
  }

  String get _totalIncome {
    double income = _totalHarvest * 50000;
    return 'Rp ${income.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  List<PieChartSectionData> _getChartData() {
    // USE THE SAME DATA SOURCE AS THE TABLE (_floorData)
    // Calculate totals from _floorData which is what the table displays
    double mangkok = 0.0, sudut = 0.0, oval = 0.0, patahan = 0.0;
    
    for (var floor in _floorData) {
      mangkok += double.tryParse(floor['mangkok'].toString()) ?? 0.0;
      sudut += double.tryParse(floor['sudut'].toString()) ?? 0.0;
      oval += double.tryParse(floor['oval'].toString()) ?? 0.0;
      patahan += double.tryParse(floor['patahan'].toString()) ?? 0.0;
    }
    
    bool hasBreakdown = (sudut > 0 || oval > 0 || patahan > 0);
    final totalNests = mangkok + sudut + oval + patahan;

    print('[PIE CHART] From _floorData - Total: $totalNests, hasBreakdown: $hasBreakdown, M:$mangkok S:$sudut O:$oval P:$patahan');

    // If no total, show placeholder
    if (totalNests == 0) {
      return [
        PieChartSectionData(
          value: 1,
          color: Colors.grey[300]!,
          title: 'No Data\nInput Pre-Harvest',
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ];
    }

    // If we have total but no breakdown (only mangkok), show as single section
    if (!hasBreakdown) {
      return [
        PieChartSectionData(
          value: totalNests,
          color: Colors.orange[300]!,
          title: 'Total: ${totalNests.toInt()} sarang\nKlik "Detail"\nuntuk breakdown',
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ];
    }

    // Build sections from _floorData (same as table)
    List<PieChartSectionData> sections = [];

    if (mangkok > 0) {
      final percentage = totalNests > 0
          ? (mangkok / totalNests * 100).toStringAsFixed(1)
          : '0';
      sections.add(PieChartSectionData(
        value: mangkok,
        color: const Color(0xFF245C4C),
        title: '${mangkok.toInt()}\n($percentage%)',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
    }

    if (sudut > 0) {
      final percentage = totalNests > 0
          ? (sudut / totalNests * 100).toStringAsFixed(1)
          : '0';
      sections.add(PieChartSectionData(
        value: sudut,
        color: const Color(0xFFffc200),
        title: '${sudut.toInt()}\n($percentage%)',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
    }

    if (oval > 0) {
      final percentage = totalNests > 0
          ? (oval / totalNests * 100).toStringAsFixed(1)
          : '0';
      sections.add(PieChartSectionData(
        value: oval,
        color: const Color(0xFF168AB5),
        title: '${oval.toInt()}\n($percentage%)',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
    }

    if (patahan > 0) {
      final percentage = totalNests > 0
          ? (patahan / totalNests * 100).toStringAsFixed(1)
          : '0';
      sections.add(PieChartSectionData(
        value: patahan,
        color: const Color(0xFFC20000),
        title: '${patahan.toInt()}\n($percentage%)',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ));
    }

    return sections;
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

  void _showHarvestManager() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_sweep, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text(
              'Kelola Panen',
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
            children: [
              Text(
                'Hapus data panen ${_months[_selectedMonth - 1]} $_selectedYear',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF245C4C),
                ),
              ),
              const SizedBox(height: 16),
              if (_floorHarvestIds.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Tidak ada data panen untuk dihapus',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                ..._floorData.map((floor) {
                  final floorNo = floor['floor'] as int;
                  final hasData = _floorHarvestIds.containsKey(floorNo) &&
                      _floorHarvestIds[floorNo]!.isNotEmpty;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: hasData
                            ? const Color(0xFF245C4C)
                            : Colors.grey[300],
                        child: Text(
                          '$floorNo',
                          style: TextStyle(
                            color: hasData ? Colors.white : Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        'Lantai $floorNo',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        hasData
                            ? '${_floorHarvestIds[floorNo]!.length} entri panen'
                            : 'Tidak ada data',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      trailing: hasData
                          ? IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                // Confirm deletion
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Konfirmasi Hapus'),
                                    content: Text(
                                      'Hapus semua data panen lantai $floorNo?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Batal'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        child: const Text('Hapus'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  await _deleteFloorHarvests(floorNo);
                                }
                              },
                            )
                          : null,
                    ),
                  );
                }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
          if (_floorHarvestIds.isNotEmpty)
            ElevatedButton(
              onPressed: () async {
                // Confirm delete all
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Konfirmasi Hapus Semua'),
                    content: const Text(
                      'Hapus SEMUA data panen bulan ini?\nTindakan ini tidak dapat dibatalkan.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Batal'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Hapus Semua'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await _deleteAllHarvests();
                  if (mounted) Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Hapus Semua'),
            ),
        ],
      ),
    );
  }

  Future<void> _deleteFloorHarvests(int floorNo) async {
    if (!_floorHarvestIds.containsKey(floorNo)) return;

    try {
      final harvestIds = _floorHarvestIds[floorNo]!;
      int successCount = 0;
      List<String> errors = [];

      for (final harvestId in harvestIds) {
        try {
          final result = await _harvestService.delete(_authToken!, harvestId);
          if (result['success'] == true) {
            successCount++;
          } else {
            errors.add(result['error'] ?? 'Unknown error');
            print('Error deleting harvest $harvestId: ${result['error']}');
          }
        } catch (e) {
          errors.add(e.toString());
          print('Exception deleting harvest $harvestId: $e');
        }
      }

      if (mounted) {
        if (successCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Berhasil menghapus $successCount data lantai $floorNo'),
              backgroundColor: const Color(0xFF245C4C),
            ),
          );
        } else if (errors.isNotEmpty) {
          // Show specific error message
          String errorMsg = errors.first;
          if (errorMsg.contains('403') || errorMsg.contains('forbidden')) {
            errorMsg = 'Tidak memiliki izin untuk menghapus data panen';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }

      // Reload harvest data
      await _loadHarvestData();
    } catch (e) {
      print('Error deleting floor harvests: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Terjadi kesalahan saat menghapus data'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteAllHarvests() async {
    try {
      int successCount = 0;
      List<String> errors = [];

      for (final harvestIds in _floorHarvestIds.values) {
        for (final harvestId in harvestIds) {
          try {
            final result = await _harvestService.delete(_authToken!, harvestId);
            if (result['success'] == true) {
              successCount++;
            } else {
              errors.add(result['error'] ?? 'Unknown error');
              print('Error deleting harvest $harvestId: ${result['error']}');
            }
          } catch (e) {
            errors.add(e.toString());
            print('Exception deleting harvest $harvestId: $e');
          }
        }
      }

      if (mounted) {
        if (successCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Berhasil menghapus $successCount data panen'),
              backgroundColor: const Color(0xFF245C4C),
            ),
          );
        } else if (errors.isNotEmpty) {
          // Show specific error message
          String errorMsg = errors.first;
          if (errorMsg.contains('403') || errorMsg.contains('forbidden')) {
            errorMsg = 'Tidak memiliki izin untuk menghapus data panen.\nHubungi administrator untuk akses penghapusan.';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }

      // Reload harvest data
      await _loadHarvestData();
    } catch (e) {
      print('Error deleting all harvests: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Terjadi kesalahan saat menghapus data'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDetailInputDialog() async {
    // Controllers for the breakdown input
    final mangkokController = TextEditingController();
    final sudutController = TextEditingController();
    final ovalController = TextEditingController();
    final patahanController = TextEditingController();

    // Pre-fill if we have total but no breakdown
    final totalNests = _generalTotalSarang;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit, color: Color(0xFF245C4C), size: 24),
            SizedBox(width: 8),
            Text(
              'Input Detail Jenis Sarang',
              style: TextStyle(
                color: Color(0xFF245C4C),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total sarang: ${totalNests.toInt()}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF245C4C),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: mangkokController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Mangkok',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.circle, color: Color(0xFF245C4C)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sudutController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Sudut',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.circle, color: Color(0xFFffc200)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ovalController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Oval',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.circle, color: Color(0xFF168AB5)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: patahanController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Patahan',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.circle, color: Color(0xFFC20000)),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '💡 Total harus sama dengan ${totalNests.toInt()} sarang',
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
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              // Validate and save the breakdown
              final mangkok = double.tryParse(mangkokController.text) ?? 0.0;
              final sudut = double.tryParse(sudutController.text) ?? 0.0;
              final oval = double.tryParse(ovalController.text) ?? 0.0;
              final patahan = double.tryParse(patahanController.text) ?? 0.0;
              final inputTotal = mangkok + sudut + sudut + oval + patahan;

              if ((inputTotal - totalNests).abs() > 0.1) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Total input (${inputTotal.toInt()}) harus sama dengan total sarang (${totalNests.toInt()})'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              // Update the harvest data with breakdown
              setState(() {
                _harvestData = {
                  'mangkok': mangkok,
                  'sudut': sudut,
                  'oval': oval,
                  'patahan': patahan,
                };
              });

              // TODO: Save this breakdown to API by updating the harvest notes
              // For now, just update the UI
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Detail sarang berhasil diinput'),
                  backgroundColor: Color(0xFF245C4C),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF245C4C),
              foregroundColor: Colors.white,
            ),
            child: const Text('Simpan'),
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

                  // Legend - Calculate from _floorData (same as table)
                  Expanded(
                    flex: 2,
                    child: Builder(
                      builder: (context) {
                        // Calculate totals from _floorData
                        double mangkok = 0.0, sudut = 0.0, oval = 0.0, patahan = 0.0;
                        for (var floor in _floorData) {
                          mangkok += double.tryParse(floor['mangkok'].toString()) ?? 0.0;
                          sudut += double.tryParse(floor['sudut'].toString()) ?? 0.0;
                          oval += double.tryParse(floor['oval'].toString()) ?? 0.0;
                          patahan += double.tryParse(floor['patahan'].toString()) ?? 0.0;
                        }
                        
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLegendItem(
                                'Mangkok',
                                '${mangkok.toInt()} sarang',
                                const Color(0xFF245C4C)),
                            const SizedBox(height: 8),
                            _buildLegendItem(
                                'Sudut',
                                '${sudut.toInt()} sarang',
                                const Color(0xFFffc200)),
                            const SizedBox(height: 8),
                            _buildLegendItem(
                                'Oval',
                                '${oval.toInt()} sarang',
                                const Color(0xFF168AB5)),
                            const SizedBox(height: 8),
                            _buildLegendItem(
                                'Patahan',
                                '${patahan.toInt()} sarang',
                                const Color(0xFFC20000)),
                          ],
                        );
                      },
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
                          '${_totalHarvest.toInt()}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF168AB5),
                          ),
                        ),
                        Text(
                          'Optimal: ${_preHarvestTotal > 0 ? (_preHarvestTotal * 0.75).toInt() : (_totalHarvest * 0.75).toInt()}',
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
                // Add Harvest Manager button
                IconButton(
                  onPressed: _showHarvestManager,
                  icon: const Icon(
                    Icons.settings,
                    color: Color(0xFF245C4C),
                    size: 20,
                  ),
                  tooltip: 'Kelola Panen',
                ),
                // Show "Add Detail" button if we have total but no breakdown
                if (_generalTotalSarang > 0 &&
                    _harvestData['mangkok'] == 0 &&
                    _harvestData['sudut'] == 0 &&
                    _harvestData['oval'] == 0 &&
                    _harvestData['patahan'] == 0)
                  TextButton.icon(
                    onPressed: _showDetailInputDialog,
                    icon: const Icon(Icons.add_circle_outline,
                        size: 16, color: Color(0xFFffc200)),
                    label: const Text(
                      'Detail',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFffc200),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      backgroundColor: const Color(0xFFFFF7CA),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Color(0xFFffc200)),
                      ),
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
            label: '',
          ),
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
            label: '',
          ),
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
            label: '',
          ),
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
            label: '',
          ),
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
            label: '',
          ),
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
