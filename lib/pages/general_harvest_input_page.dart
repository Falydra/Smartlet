import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:swiftlead/components/custom_bottom_navigation.dart';
import 'package:swiftlead/services/house_services.dart';
import 'package:swiftlead/services/harvest_services.dart';
import 'package:swiftlead/services/node_service.dart';
import 'package:swiftlead/utils/token_manager.dart';
import 'package:swiftlead/pages/add_harvest_page.dart';

class GeneralHarvestInputPage extends StatefulWidget {
  final String? cageName;
  final int? floors;
  final String? houseId; // Changed to String to support UUID
  final int? selectedMonth;
  final int? selectedYear;

  const GeneralHarvestInputPage({
    super.key,
    this.cageName,
    this.floors,
    this.houseId,
    this.selectedMonth,
    this.selectedYear,
  });

  @override
  State<GeneralHarvestInputPage> createState() => _GeneralHarvestInputPageState();
}

class _GeneralHarvestInputPageState extends State<GeneralHarvestInputPage> {
  final _formKey = GlobalKey<FormState>();
  

  late List<TextEditingController> _floorControllers;
  

  final HouseService _houseService = HouseService();
  final HarvestService _harvestService = HarvestService();
  final NodeService _nodeService = NodeService();
  

  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasSavedData = false;
  bool _hasExistingData = false; // Track if editing existing data
  Map<int, String> _existingRecordIds = {}; // Store existing harvest record IDs by floor number
  String? _authToken;
  

  List<dynamic> _houses = [];
  Map<String, dynamic>? _selectedHouse;
  String _cageName = 'Kandang 1';
  int _cageFloors = 3;
  

  List<dynamic> _nodes = [];
  Map<String, dynamic>? _selectedNode;
  

  int _currentIndex = 2;
  

  late int _selectedMonth;
  late int _selectedYear;

  final List<String> _months = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  @override
  void initState() {
    super.initState();

    _selectedMonth = widget.selectedMonth ?? DateTime.now().month;
    _selectedYear = widget.selectedYear ?? DateTime.now().year;
    _initializeData();
  }

  Future<void> _initializeData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    
    try {

      _authToken = await TokenManager.getToken();
      
      if (_authToken == null) {
        throw Exception('Token autentikasi tidak tersedia. Silakan login kembali.');
      }
      

      await _loadHouses();
      

      if (widget.houseId != null && _houses.isNotEmpty) {
        try {
          _selectedHouse = _houses.firstWhere(
            (house) => house['id']?.toString() == widget.houseId,
          );
        } catch (e) {
          print('House with id ${widget.houseId} not found in API response: $e');

          if (_houses.isNotEmpty) {
            _selectedHouse = _houses.first;
          }
        }
      } else if (_houses.isNotEmpty) {
        _selectedHouse = _houses.first;
      }
      
      if (_selectedHouse == null) {
        throw Exception('Tidak ada data kandang tersedia');
      }
      

      _cageName = _selectedHouse!['name'] ?? _cageName;
      _cageFloors = _selectedHouse!['total_floors'] ?? _selectedHouse!['floor_count'] ?? _cageFloors;
      

      await _loadNodes(rbwId: _selectedHouse!['id']?.toString());
      
    } catch (e) {
      print('Error initializing general harvest data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat data kandang: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    

    _floorControllers = List.generate(
      _cageFloors,
      (index) => TextEditingController(text: '0'),
    );
    

    for (var controller in _floorControllers) {
      controller.addListener(_updateTotals);
    }
    

    await _loadExistingPreHarvestData();
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadHouses() async {
    try {
      final houses = await _houseService.getAll(_authToken!);
      if (mounted) {
        setState(() {
          _houses = houses;
        });
      }
    } catch (e) {
      print('Error loading houses: $e');
    }
  }

  Future<void> _loadNodes({String? rbwId}) async {
    if (_authToken == null || rbwId == null || rbwId.isEmpty) {
      print('Cannot load nodes: missing token or rbwId');
      return;
    }
    
    try {
      final response = await _nodeService.listByRbw(_authToken!, rbwId);
      if (response['success'] == true && response['data'] != null) {
        final nodes = response['data'] as List<dynamic>;
        if (mounted) {
          setState(() {
            _nodes = nodes;

            if (_nodes.isNotEmpty) {
              _selectedNode = _nodes.first;
            }
          });
        }
        print('Loaded ${nodes.length} nodes for house $rbwId');
      } else {
        print('Failed to load nodes: ${response['message']}');
      }
    } catch (e) {
      print('Error loading nodes: $e');
    }
  }

  Future<void> _loadExistingPreHarvestData() async {
    if (_authToken == null || _selectedHouse == null) {
      print('Cannot load existing pre-harvest data: missing auth or house');
      return;
    }
    
    try {
      final rbwId = _selectedHouse!['id']?.toString();
      if (rbwId == null) return;
      
      print('Loading existing pre-harvest data for rbwId=$rbwId, month=$_selectedMonth, year=$_selectedYear');
      

      final harvests = await _harvestService.getAll(
        _authToken!,
        rbwId: rbwId,
      );
      
      print('Found ${harvests.length} harvest records total');
      
      bool foundData = false;
      

      for (var harvest in harvests) {
        final harvestedAt = harvest['harvested_at'];
        if (harvestedAt != null) {
          final date = DateTime.tryParse(harvestedAt);
          if (date != null && 
              date.month == _selectedMonth && 
              date.year == _selectedYear) {
            
            final notes = (harvest['notes'] as String?) ?? '';
            final floorNo = (harvest['floor_no'] as int?) ?? 0;
            
            print('Checking record: floor=$floorNo, notes=$notes');
            

            final recordId = harvest['id']?.toString();
            if (recordId != null && floorNo > 0) {
              _existingRecordIds[floorNo] = recordId;
              print('Stored record ID for floor $floorNo: $recordId');
            }
            

            if (notes.startsWith('PRE_HARVEST_PLAN')) {
              foundData = true;
              

              final nestsCount = (harvest['nests_count'] as num?)?.toInt() ?? 0;
              
              print('Parsed pre-harvest floor $floorNo: nests_count=$nestsCount');
              

              if (floorNo > 0 && floorNo <= _cageFloors) {
                final floorIndex = floorNo - 1;
                _floorControllers[floorIndex].text = nestsCount.toString();
                
                print('Set controller for floor $floorNo (index $floorIndex) to $nestsCount');
              }
            }
          }
        }
      }
      
      if (foundData) {

        _updateTotals();
        
        if (mounted) {
          setState(() {
            _hasExistingData = true;
          });
        }
      }
      
      print('Loaded existing pre-harvest data: foundData=$foundData');
    } catch (e) {
      print('Error loading existing pre-harvest data: $e');
    }
  }

  @override
  void dispose() {
    for (var controller in _floorControllers) {
      controller.removeListener(_updateTotals);
      controller.dispose();
    }
    super.dispose();
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF245C4C)),
            SizedBox(width: 8),
            Text('Informasi Pre-Harvest'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tahap Pre-Harvest:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text('1. Input total sarang mentah untuk setiap lantai'),
            Text('2. Sistem akan menghitung rekomendasi panen (75% dari total)'),
            Text('3. Simpan data untuk melanjutkan ke tahap panen'),
            SizedBox(height: 12),
            Text(
              'Rekomendasi Panen:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text('• 75% dari total sarang adalah jumlah optimal'),
            Text('• Menjaga regenerasi sarang untuk siklus berikutnya'),
            Text('• Anda bisa memanen lebih atau kurang dari rekomendasi'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  void _showDatePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pilih Bulan dan Tahun Panen'),
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
                  return DropdownMenuItem<int>(
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
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _selectedYear,
                decoration: const InputDecoration(
                  labelText: 'Tahun',
                  border: OutlineInputBorder(),
                ),
                items: List.generate(10, (index) {
                  int year = DateTime.now().year - 5 + index;
                  return DropdownMenuItem<int>(
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
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
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

  int get _totalSarang {
    return _floorControllers.fold(0, (sum, controller) {
      return sum + (int.tryParse(controller.text) ?? 0);
    });
  }

  void _updateTotals() {
    if (mounted) {
      setState(() {

      });
    }
  }



  Future<void> _saveHarvestData() async {
    if (_formKey.currentState!.validate()) {
      if (_totalSarang == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Minimal satu lantai harus memiliki sarang'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (mounted) {
        setState(() {
          _isSaving = true;
        });
      }

      try {

        int recommendedHarvest = (_totalSarang * 0.75).round();


        


        if (_authToken == null) {
          if (mounted) {
            setState(() {
              _isSaving = false;
            });
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Akses API diperlukan — silakan masuk terlebih dahulu'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }


        String? rbwId;
        if (_selectedHouse != null) {
          rbwId = _selectedHouse!['id']?.toString();
        }

        if (rbwId == null || rbwId.isEmpty) {
          if (mounted) {
            setState(() {
              _isSaving = false;
            });
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ID Kandang tidak tersedia, Pilih kandang terlebih dahulu'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }


        final harvestedAt = DateTime.utc(_selectedYear, _selectedMonth, 1).toIso8601String();


        if (_selectedNode == null || _selectedNode!['id'] == null) {
          if (mounted) {
            setState(() {
              _isSaving = false;
            });
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Node tidak tersedia. Silakan pilih node terlebih dahulu.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final nodeId = _selectedNode!['id']?.toString();



        try {
          int successCount = 0;
          List<String> errors = [];
          
          for (int floor = 0; floor < _cageFloors; floor++) {
            final floorTotal = int.tryParse(_floorControllers[floor].text) ?? 0;
            if (floorTotal == 0) continue; // Skip empty floors
            
            final floorRecommended = (floorTotal * 0.75).round();
            

            final apiPayload = <String, dynamic>{
              'rbw_id': rbwId,
              'node_id': nodeId, // Required: node from node management table
              'floor_no': floor + 1,
              'harvested_at': harvestedAt,
              'nests_count': floorTotal,

              'grade': 'good', // Default grade for pre-harvest plan
              'notes': 'PRE_HARVEST_PLAN|recommended:$floorRecommended|total:$_totalSarang',
            };

            print('Saving pre-harvest for floor ${floor + 1}: $apiPayload');
            print('Payload JSON: ${jsonEncode(apiPayload)}');
            

            final floorNum = floor + 1;
            Map<String, dynamic> response;
            
            if (_existingRecordIds.containsKey(floorNum)) {

              final recordId = _existingRecordIds[floorNum]!;
              print('Updating existing record $recordId for floor $floorNum');
              response = await _harvestService.update(_authToken!, recordId, apiPayload);
            } else {

              print('Creating new pre-harvest record for floor $floorNum');
              response = await _harvestService.create(_authToken!, apiPayload);
            }
            
            if (response['success'] == true || response['data'] != null) {
              successCount++;
              print('Floor ${floor + 1} saved successfully');
            } else {
              final errorMsg = response['error'] ?? 'Unknown error';
              final statusCode = response['statusCode'] ?? 'N/A';
              final fullError = 'Status: $statusCode, Error: $errorMsg';
              errors.add('Lantai ${floor + 1}: $fullError');
              print('Floor ${floor + 1} failed: $fullError');
              

              if (mounted && errors.length == 1) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Debug: API Error'),
                    content: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Status: $statusCode'),
                          const SizedBox(height: 8),
                          Text('Error: $errorMsg'),
                          const SizedBox(height: 8),
                          const Text('Payload:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(jsonEncode(apiPayload), style: const TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              }
            }
          }

          if (successCount > 0) {
            if (mounted) {
              setState(() {
                _hasSavedData = true;
                _isSaving = false;
              });
            }
            
            String message = 'Data pre-harvest tersimpan di server ($successCount lantai). Rekomendasi: $recommendedHarvest sarang';
            if (errors.isNotEmpty) {
              message += '\n\nPeringatan: Beberapa lantai gagal:\n${errors.join('\n')}';
            }
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: errors.isEmpty ? Colors.green : Colors.orange,
                duration: const Duration(seconds: 5),
              ),
            );
          } else {

            if (mounted) {
              setState(() {
                _isSaving = false;
              });
            }
            
            String errorMessage = 'Gagal menyimpan data pre-harvest';
            if (errors.isNotEmpty) {
              errorMessage += ':\n${errors.join('\n')}';
            }
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _isSaving = false;
            });
          }
          print('Error saving pre-harvest to API: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal terhubung ke server: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        print('Error saving harvest data: $e');
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showOptimalHarvestSummary() {
    if (_totalSarang == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan masukkan data sarang terlebih dahulu'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    int totalSarang = _totalSarang;
    int optimalHarvest = (totalSarang * 0.75).round(); // 75% of total
    

    List<Map<String, int>> floorRecommendations = [];
    for (int i = 0; i < _cageFloors; i++) {
      int floorTotal = int.tryParse(_floorControllers[i].text) ?? 0;
      int floorOptimal = (floorTotal * 0.75).round();
      floorRecommendations.add({
        'floor': i + 1,
        'total': floorTotal,
        'recommended': floorOptimal,
      });
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
      
        title: const Row(
          children: [
            Text('Rekomendasi Panen'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF245C4C),
                      const Color(0xFF2d7a5f),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Sarang',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Text(
                      '$totalSarang sarang',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white30),
                    const SizedBox(height: 12),
                    const Text(
                      'Rekomendasi Panen (75%)',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Text(
                      '$optimalHarvest sarang',
                      style: const TextStyle(
                        color: Colors.yellowAccent,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              const Text(
                'Detail per Lantai:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              
              ...floorRecommendations.map((floor) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Lantai ${floor['floor']}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${floor['total']} sarang',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          Text(
                            '→ ${floor['recommended']} sarang',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF245C4C),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
              
              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF245C4C).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF245C4C).withOpacity(0.3)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: const Color(0xFF245C4C)),
                        const SizedBox(width: 8),
                        const Text(
                          'Catatan Penting',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF245C4C),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Panen 75% menjaga regenerasi optimal\n'
                      '• Anda bebas memanen lebih atau kurang\n'
                      '• Ratio panen akan dihitung otomatis saat input hasil',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          Row(children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _proceedToDetail();
              },
              
              icon: const Icon(Icons.forward, size: 18),
              label: const Text('Input Hasil Panen', style: TextStyle(fontSize: 12),),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF245C4C),
                foregroundColor: Colors.white,
              ),
            ),

          ],),
        ],
      ),
    );
  }

  void _proceedToDetail() {
    if (_formKey.currentState!.validate()) {

      Map<int, int> floorLimits = {};
      for (int i = 0; i < _cageFloors; i++) {
        floorLimits[i] = int.tryParse(_floorControllers[i].text) ?? 0;
      }

      if (floorLimits.values.every((limit) => limit == 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Minimal satu lantai harus memiliki sarang'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }


      String? selectedHouseId;
      if (_selectedHouse != null) {
        selectedHouseId = _selectedHouse!['id']?.toString();
      }


      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddHarvestPage(
            cageName: _cageName,
            floors: _cageFloors,
            houseId: selectedHouseId,
            floorLimits: floorLimits,
            selectedMonth: _selectedMonth,
            selectedYear: _selectedYear,
          ),
        ),
      ).then((result) {
        if (result == true) {


          Navigator.pop(context, {
            'success': true,
            'generalTotal': _totalSarang,
            'floorTotals': Map<int, int>.from(floorLimits),
          });
        }
      });
    }
  }

  Future<void> _showHarvestListDialog() async {
    if (_authToken == null) return;
    

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF245C4C)),
      ),
    );
    
    try {

      final rbwId = _selectedHouse?['id']?.toString() ?? '';
      final harvests = await _harvestService.getAll(
        _authToken!,
        rbwId: rbwId,
      );
      

      if (mounted) Navigator.of(context).pop();
      

      final filteredHarvests = harvests.where((harvest) {
        final harvestedAt = harvest['harvested_at'];
        if (harvestedAt != null) {
          final date = DateTime.tryParse(harvestedAt);
          if (date != null) {
            return date.month == _selectedMonth && date.year == _selectedYear;
          }
        }
        return false;
      }).toList();
      
      if (!mounted) return;
      

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.list_alt, color: Color(0xFF245C4C)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Daftar Panen ${_months[_selectedMonth - 1]} $_selectedYear',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: filteredHarvests.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Belum ada data panen',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: filteredHarvests.length,
                  itemBuilder: (context, index) {
                    final harvest = filteredHarvests[index];
                    final floorNumber = harvest['floor_no'] ?? index + 1;
                    final amount = harvest['nests_count'] ?? harvest['amount'] ?? harvest['total'] ?? 0;
                    final date = harvest['harvested_at'] ?? harvest['harvest_date'] ?? harvest['date'] ?? '';
                    final notes = harvest['notes'] ?? '';
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF245C4C),
                          child: Text(
                            'L$floorNumber',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        title: Text(
                          '$amount sarang',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Lantai $floorNumber'),
                            if (date.isNotEmpty) Text('Tanggal: ${date.toString().split('T')[0]}'),
                            if (notes.isNotEmpty) Text('Catatan: $notes', style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                              onPressed: () {
                                Navigator.of(context).pop();
                                _editHarvest(harvest);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                              onPressed: () {
                                _confirmDeleteHarvest(context, harvest);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
    } catch (e) {

      if (mounted) Navigator.of(context).pop();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat daftar panen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteHarvest(BuildContext context, Map<String, dynamic> harvest) async {
    final floorNumber = harvest['floor_no'] ?? 1;
    final amount = harvest['nests_count'] ?? harvest['amount'] ?? 0;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Data Panen?'),
        content: Text('Apakah Anda yakin ingin menghapus data panen Lantai $floorNumber ($amount sarang)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await _deleteHarvest(harvest);
    }
  }

  Future<void> _deleteHarvest(Map<String, dynamic> harvest) async {
    if (_authToken == null) return;
    
    try {
      final harvestId = harvest['id']?.toString();
      if (harvestId == null) {
        throw Exception('ID panen tidak ditemukan');
      }
      
      await _harvestService.delete(_authToken!, harvestId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data panen berhasil dihapus'),
            backgroundColor: Colors.green,
          ),
        );
        

        Navigator.of(context).pop(); // Close current dialog
        _showHarvestListDialog(); // Reopen with refreshed data
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus data panen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _editHarvest(Map<String, dynamic> harvest) {

    final floorNumber = (harvest['floor_no'] ?? 1) - 1; // Convert to 0-indexed
    final amount = harvest['nests_count'] ?? harvest['amount'] ?? harvest['total'] ?? 0;
    
    if (floorNumber >= 0 && floorNumber < _floorControllers.length) {
      setState(() {
        _floorControllers[floorNumber].text = amount.toString();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Data Lantai ${floorNumber + 1} dimuat untuk diedit. Silakan ubah dan simpan.'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 3),
        ),
      );
      


    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Input Panen - $_cageName'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF245C4C),
        actions: [
          IconButton(
            onPressed: _showInfoDialog,
            icon: const Icon(Icons.help_outline),
          ),
        ],
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
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pre-Harvest: Input Data Sarang',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF245C4C),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _hasExistingData 
                                ? 'Edit data sarang burung walet untuk setiap lantai'
                                : 'Masukkan total jumlah sarang burung walet untuk setiap lantai',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_hasExistingData)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange[300]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit, size: 16, color: Colors.orange[700]),
                              const SizedBox(width: 4),
                              Text(
                                'Mode Edit',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),


                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showDatePicker,
                      icon: const Icon(Icons.calendar_month, size: 18),
                      label: Text(
                        'Periode: ${_months[_selectedMonth - 1]} $_selectedYear',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF245C4C),
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: const Color(0xFF245C4C).withOpacity(0.3)),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),


                  

                  const SizedBox(height: 24),


                  ...List.generate(_cageFloors, (floorIndex) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF245C4C),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    '${floorIndex + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Lantai ${floorIndex + 1}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF245C4C),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 12),
                          
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _floorControllers[floorIndex],
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Total Sarang',
                                    hintText: 'Masukkan jumlah sarang',
                                    suffixText: 'sarang',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(color: Color(0xFF245C4C)),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return null; // Allow empty for optional floors
                                    }
                                    int? intValue = int.tryParse(value);
                                    if (intValue == null || intValue < 0) {
                                      return 'Masukkan angka yang valid';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                children: [
                                

                                  Container(
                                    width: 40,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF245C4C),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.add, color: Colors.white, size: 20),
                                      padding: EdgeInsets.zero,
                                      onPressed: () {
                                        int currentValue = int.tryParse(_floorControllers[floorIndex].text) ?? 0;
                                        setState(() {
                                          _floorControllers[floorIndex].text = (currentValue + 1).toString();
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  Container(
                                    width: 40,
                                    height: 54,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[400],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.remove, color: Colors.white, size: 20),
                                      padding: EdgeInsets.zero,
                                      onPressed: () {
                                        int currentValue = int.tryParse(_floorControllers[floorIndex].text) ?? 0;
                                        if (currentValue > 0) {
                                          setState(() {
                                            _floorControllers[floorIndex].text = (currentValue - 1).toString();
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 16),


                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Column(
                      children: [
                        Text(
                          'Analisis Panen',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF245C4C),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),


                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF245C4C).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF245C4C).withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Total Sarang Keseluruhan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF245C4C),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$_totalSarang sarang',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF245C4C),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),


                  Column(
                    children: [

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: (_totalSarang > 0 && !_isSaving) ? _saveHarvestData : null,
                          icon: _isSaving 
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.save, size: 18),
                          label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Data Pre-Harvest'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF245C4C),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: (_hasSavedData && _totalSarang > 0) ? _showOptimalHarvestSummary : null,
                          icon: const Icon(Icons.agriculture, size: 18),
                          label: const Text('Lihat Rekomendasi Panen'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _hasSavedData ? const Color(0xFFffc200) : Colors.grey,
                            foregroundColor: _hasSavedData ? Colors.black : Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _hasSavedData ? _proceedToDetail : null,
                          icon: const Icon(Icons.arrow_forward, size: 18),
                          label: const Text('Lanjut ke Input Hasil Panen →'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _hasSavedData ? const Color(0xFF245C4C) : Colors.grey,
                            side: BorderSide(
                              color: _hasSavedData ? const Color(0xFF245C4C) : Colors.grey,
                              width: 2,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _showHarvestListDialog,
                          icon: const Icon(Icons.list_alt, size: 18),
                          label: const Text('Kelola Daftar Panen'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange[700],
                            side: BorderSide(
                              color: Colors.orange[700]!,
                              width: 2,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 80),
                ],
              ),
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
                icon: Icons.devices,
                label: 'Kontrol',
                currentIndex: _currentIndex,
                itemIndex: 1,
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/control-page');
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


}