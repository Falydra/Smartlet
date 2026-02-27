import 'package:flutter/material.dart';
import 'package:swiftlead/components/custom_bottom_navigation.dart';
import 'package:swiftlead/services/harvest_services.dart';
import 'package:swiftlead/services/house_services.dart';
import 'package:swiftlead/services/node_service.dart';
import 'package:swiftlead/utils/token_manager.dart';

class AddHarvestPage extends StatefulWidget {
  final String? cageName;
  final int? floors;
  final String? houseId;
  final Map<int, int>? floorLimits;
  final int? selectedMonth;
  final int? selectedYear;

  const AddHarvestPage({
    super.key,
    this.cageName,
    this.floors,
    this.houseId,
    this.floorLimits,
    this.selectedMonth,
    this.selectedYear,
  });

  static Map<String, dynamic> getTempPreHarvestData() {
    return Map<String, dynamic>.from(
        _AddHarvestPageState._tempPreHarvestStorage);
  }

  static void clearTempPreHarvestData() {
    _AddHarvestPageState._tempPreHarvestStorage.clear();
  }

  @override
  State<AddHarvestPage> createState() => _AddHarvestPageState();
}

class _AddHarvestPageState extends State<AddHarvestPage> {
  final _formKey = GlobalKey<FormState>();
  late List<TextEditingController> _floorControllers;
  

  List<Map<String, int>> _floorBreakdown = [];
  
  int _currentIndex = 2;


  final HarvestService _harvestService = HarvestService();
  final HouseService _houseService = HouseService();
  final NodeService _nodeService = NodeService();


  bool _isLoading = true;
  bool _hasExistingData = false;
  Map<int, String> _existingRecordIds = {};
  String? _authToken;


  List<dynamic> _houses = [];
  Map<String, dynamic>? _selectedHouse;
  String _cageName = 'Kandang 1';
  int _cageFloors = 3;


  List<dynamic> _nodes = [];
  Map<String, dynamic>? _selectedNode;


  Map<int, int> _floorRecommended = {};
  Map<int, int> _floorPreHarvest = {};
  double _totalPreHarvest = 0;
  double _totalRecommended = 0;


  static final Map<String, dynamic> _tempPreHarvestStorage = {};


  late int _selectedMonth;
  late int _selectedYear;

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

  @override
  void initState() {
    super.initState();
    _selectedMonth = widget.selectedMonth ?? DateTime.now().month;
    _selectedYear = widget.selectedYear ?? DateTime.now().year;

    _floorRecommended = widget.floorLimits ?? {};
    _floorPreHarvest = widget.floorLimits ?? {};

    _totalRecommended =
        _floorRecommended.values.fold(0, (sum, value) => sum + value * 0.75);
    _totalPreHarvest =
        _floorPreHarvest.values.fold(0, (sum, value) => sum + value.toDouble());

    _tempPreHarvestStorage['totalPreHarvest'] = _totalPreHarvest;
    _tempPreHarvestStorage['totalRecommended'] = _totalRecommended;
    _tempPreHarvestStorage['floorPreHarvest'] =
        Map<int, int>.from(_floorPreHarvest);

    _initializeData();
  }

  Future<void> _initializeData() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      _authToken = await TokenManager.getToken();
      if (_authToken == null) {
        throw Exception(
            'Token autentikasi tidak tersedia. Silakan login kembali.');
      }

      await _loadHouses();

      if (widget.houseId != null && _houses.isNotEmpty) {
        try {
          _selectedHouse = _houses
              .firstWhere((house) => house['id']?.toString() == widget.houseId);
        } catch (e) {
          if (_houses.isNotEmpty) _selectedHouse = _houses.first;
        }
      } else if (_houses.isNotEmpty) {
        _selectedHouse = _houses.first;
      }

      if (_selectedHouse == null) {
        throw Exception('Tidak ada data kandang tersedia');
      }

      _cageName = _selectedHouse!['name'] ?? _cageName;
      _cageFloors = _selectedHouse!['total_floors'] ??
          _selectedHouse!['floor_count'] ??
          _cageFloors;

      await _loadNodes(rbwId: _selectedHouse!['id']?.toString());
    } catch (e) {
      print('Error initializing harvest data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Gagal memuat data kandang: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    }

    _floorControllers =
        List.generate(_cageFloors, (index) => TextEditingController());
    

    _floorBreakdown = List.generate(
        _cageFloors, 
        (index) => {'mangkok': 0, 'sudut': 0, 'oval': 0, 'patahan': 0}
    );
    await _loadExistingHarvestData();

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadHouses() async {
    try {
      final houses = await _houseService.getAll(_authToken!);
      if (mounted) setState(() => _houses = houses);
    } catch (e) {
      print('Error loading houses: $e');
    }
  }

  Future<void> _loadNodes({String? rbwId}) async {
    if (_authToken == null || rbwId == null || rbwId.isEmpty) return;

    try {
      final response = await _nodeService.listByRbw(_authToken!, rbwId);
      if (response['success'] == true && response['data'] != null) {
        final nodes = response['data'] as List<dynamic>;
        if (mounted) {
          setState(() {
            _nodes = nodes;
            if (_nodes.isNotEmpty) _selectedNode = _nodes.first;
          });
        }
      }
    } catch (e) {
      print('Error loading nodes: $e');
    }
  }

  Future<void> _loadExistingHarvestData() async {
    if (_authToken == null || _selectedHouse == null) return;

    try {
      final rbwId = _selectedHouse!['id']?.toString();
      if (rbwId == null) return;

      final harvests = await _harvestService.getAll(_authToken!, rbwId: rbwId);
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

            final recordId = harvest['id']?.toString();
            if (recordId != null && floorNo > 0) {
              _existingRecordIds[floorNo] = recordId;
            }

            if (notes.startsWith('POST_HARVEST')) {
              foundData = true;
              final nestsCount = (harvest['nests_count'] as num?)?.toInt() ?? 0;
              if (floorNo > 0 && floorNo <= _cageFloors) {
                _floorControllers[floorNo - 1].text = nestsCount.toString();
                

                final mangkokMatch = RegExp(r'Mangkok:(\d+)').firstMatch(notes);
                final sudutMatch = RegExp(r'Sudut:(\d+)').firstMatch(notes);
                final ovalMatch = RegExp(r'Oval:(\d+)').firstMatch(notes);
                final patahanMatch = RegExp(r'Patahan:(\d+)').firstMatch(notes);
                
                if (mangkokMatch != null || sudutMatch != null || ovalMatch != null || patahanMatch != null) {
                  _floorBreakdown[floorNo - 1] = {
                    'mangkok': int.tryParse(mangkokMatch?.group(1) ?? '0') ?? 0,
                    'sudut': int.tryParse(sudutMatch?.group(1) ?? '0') ?? 0,
                    'oval': int.tryParse(ovalMatch?.group(1) ?? '0') ?? 0,
                    'patahan': int.tryParse(patahanMatch?.group(1) ?? '0') ?? 0,
                  };
                }
              }
            }
          }
        }
      }

      if (mounted) setState(() => _hasExistingData = foundData);
    } catch (e) {
      print('Error loading existing harvest data: $e');
    }
  }

  @override
  void dispose() {
    for (var controller in _floorControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _isFloorTotalExceeded(int floorIndex) {
    if (!_floorPreHarvest.containsKey(floorIndex)) return false;
    final inputValue = int.tryParse(_floorControllers[floorIndex].text) ?? 0;
    return inputValue > _floorPreHarvest[floorIndex]!;
  }

  Future<void> _saveHarvest() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedHouse == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Tidak ada kandang yang dipilih'),
            backgroundColor: Colors.red),
      );
      return;
    }

    for (int i = 0; i < _cageFloors; i++) {
      if (_isFloorTotalExceeded(i)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Lantai ${i + 1}: Jumlah panen (${_floorControllers[i].text}) melebihi data pre-harvest (${_floorPreHarvest[i]}) sarang'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
    }

    int totalActualHarvest = _floorControllers.fold(
        0, (sum, controller) => sum + (int.tryParse(controller.text) ?? 0));

    if (totalActualHarvest == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Minimal satu lantai harus memiliki hasil panen'),
            backgroundColor: Colors.red),
      );
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    try {
      double harvestRatio;
      bool followedRecommendation = false;

      if (_totalRecommended > 0) {
        double variance =
            (totalActualHarvest - _totalRecommended).abs() / _totalRecommended;
        if (variance <= 0.1) {
          harvestRatio = 0.75;
          followedRecommendation = true;
        } else {
          harvestRatio = _totalPreHarvest > 0
              ? (totalActualHarvest / _totalPreHarvest)
              : 0;
        }
      } else {
        harvestRatio =
            _totalPreHarvest > 0 ? (totalActualHarvest / _totalPreHarvest) : 0;
      }

      final harvestedAt =
          DateTime.utc(_selectedYear, _selectedMonth, 1).toIso8601String();
      final rbwId = _selectedHouse!['id']?.toString();

      if (_selectedNode == null || _selectedNode!['id'] == null) {
        if (mounted) setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Node tidak tersedia. Silakan pilih node terlebih dahulu.'),
              backgroundColor: Colors.red),
        );
        return;
      }

      final nodeId = _selectedNode!['id']?.toString();
      int successCount = 0;

      for (int floor = 0; floor < _cageFloors; floor++) {
        final floorHarvest = int.tryParse(_floorControllers[floor].text) ?? 0;
        if (floorHarvest == 0) continue;


        String notesText = 'POST_HARVEST|ratio:${(harvestRatio * 100).toStringAsFixed(1)}%|followed:${followedRecommendation ? 'yes' : 'no'}';
        

        final breakdown = _floorBreakdown[floor];
        final hasBreakdown = breakdown.values.any((v) => v > 0);
        if (hasBreakdown) {
          notesText += '|Mangkok:${breakdown['mangkok']}';
          notesText += '|Sudut:${breakdown['sudut']}';
          notesText += '|Oval:${breakdown['oval']}';
          notesText += '|Patahan:${breakdown['patahan']}';
        }

        final apiPayload = <String, dynamic>{
          'rbw_id': rbwId,
          'node_id': nodeId,
          'floor_no': floor + 1,
          'harvested_at': harvestedAt,
          'nests_count': floorHarvest,
          'weight_kg': floorHarvest * 0.028,
          'grade': 'good',
          'notes': notesText,
        };

        final floorNum = floor + 1;
        Map<String, dynamic> result;

        if (_existingRecordIds.containsKey(floorNum)) {
          result = await _harvestService.update(
              _authToken!, _existingRecordIds[floorNum]!, apiPayload);
        } else {
          result = await _harvestService.create(_authToken!, apiPayload);
        }

        if (result['success'] == true || result['data'] != null) successCount++;
      }

      if (successCount > 0) {
        if (mounted) {
          String ratioText = followedRecommendation
              ? 'Ratio: 75% (Mengikuti rekomendasi ✓)'
              : 'Ratio: ${(harvestRatio * 100).toStringAsFixed(1)}%';

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Data panen ${_months[_selectedMonth - 1]} $_selectedYear berhasil disimpan ($successCount lantai)!'),
                  Text(ratioText, style: const TextStyle(fontSize: 12)),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }

        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) Navigator.pop(context, true);
      } else {
        if (mounted) setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Gagal menyimpan data post-harvest'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print('Error saving harvest: $e');
      if (mounted) setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Terjadi kesalahan: $e'),
            backgroundColor: Colors.red),
      );
    }
  }


  bool _hasBreakdown(int floorIndex) {
    if (floorIndex < 0 || floorIndex >= _floorBreakdown.length) return false;
    final breakdown = _floorBreakdown[floorIndex];
    return breakdown.values.any((v) => v > 0);
  }


  Widget _buildBreakdownChip(String label, int value, Color color) {
    return Column(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF245C4C),
          ),
        ),
      ],
    );
  }


  void _showBreakdownDialog(int floorIndex) {

    if (floorIndex < 0 || floorIndex >= _floorBreakdown.length) return;
    
    final floorNo = floorIndex + 1;
    final currentTotal = int.tryParse(_floorControllers[floorIndex].text) ?? 0;
    

    final mangkokController = TextEditingController(
      text: _floorBreakdown[floorIndex]['mangkok'].toString()
    );
    final sudutController = TextEditingController(
      text: _floorBreakdown[floorIndex]['sudut'].toString()
    );
    final ovalController = TextEditingController(
      text: _floorBreakdown[floorIndex]['oval'].toString()
    );
    final patahanController = TextEditingController(
      text: _floorBreakdown[floorIndex]['patahan'].toString()
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.pie_chart, color: Color(0xFF245C4C), size: 24),
            const SizedBox(width: 8),
            Text(
              'Detail Breakdown Lantai $floorNo',
              style: const TextStyle(
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
              if (currentTotal > 0)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7CA),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFffc200)),
                  ),
                  child: Text(
                    'Total sarang: $currentTotal',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF245C4C),
                    ),
                  ),
                ),
              
              TextField(
                controller: mangkokController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Mangkok',
                  prefixIcon: Container(
                    margin: const EdgeInsets.all(12),
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Color(0xFF245C4C),
                      shape: BoxShape.circle,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF245C4C)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              TextField(
                controller: sudutController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Sudut',
                  prefixIcon: Container(
                    margin: const EdgeInsets.all(12),
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Color(0xFFffc200),
                      shape: BoxShape.circle,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF245C4C)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              TextField(
                controller: ovalController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Oval',
                  prefixIcon: Container(
                    margin: const EdgeInsets.all(12),
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Color(0xFF168AB5),
                      shape: BoxShape.circle,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF245C4C)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              TextField(
                controller: patahanController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Patahan',
                  prefixIcon: Container(
                    margin: const EdgeInsets.all(12),
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Color(0xFFC20000),
                      shape: BoxShape.circle,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF245C4C)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              if (currentTotal > 0)
                Text(
                  '💡 Total breakdown harus sama dengan $currentTotal sarang',
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
              final m = int.tryParse(mangkokController.text) ?? 0;
              final s = int.tryParse(sudutController.text) ?? 0;
              final o = int.tryParse(ovalController.text) ?? 0;
              final p = int.tryParse(patahanController.text) ?? 0;
              final breakdownTotal = m + s + o + p;


              if (currentTotal > 0 && breakdownTotal != currentTotal) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Total breakdown ($breakdownTotal) harus sama dengan total sarang ($currentTotal)',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }


              setState(() {
                _floorBreakdown[floorIndex] = {
                  'mangkok': m,
                  'sudut': s,
                  'oval': o,
                  'patahan': p,
                };
              });

              Navigator.pop(context);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Detail breakdown Lantai $floorNo berhasil disimpan'),
                  backgroundColor: const Color(0xFF245C4C),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Post-Harvest: Input Hasil Panen - $_cageName'),
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
                Colors.white.withOpacity(0.7)
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
                  Text('Memuat data kandang...',
                      style: TextStyle(color: Color(0xFF245C4C))),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: _buildFormContent(),
              ),
            ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildFormContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 8),
        _buildDescription(),
        const SizedBox(height: 16),
        _buildSummaryCard(),
        const SizedBox(height: 8),
        _buildHint(),
        const SizedBox(height: 16),
        
        const SizedBox(height: 16),
        _buildDateDisplay(),
        const SizedBox(height: 16),
        ..._buildFloorInputs(),
        const SizedBox(height: 24),
        _buildSaveButton(),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Expanded(
          child: Text(
            'Post-Harvest: Input Hasil Panen',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF245C4C)),
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
                Text('Mode Edit',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[700])),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDescription() {
    return Text(
      _hasExistingData
          ? 'Edit jumlah hasil panen untuk setiap lantai'
          : 'Masukkan jumlah sarang yang dipanen untuk setiap lantai',
      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF245C4C), Color(0xFF2d7a5f)]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Data Pre-Harvest',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Sarang',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('${_totalPreHarvest.toInt()} sarang',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              Container(width: 2, height: 40, color: Colors.white30),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Rekomendasi (75%)',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('${_totalRecommended.toInt()} sarang',
                      style: const TextStyle(
                          color: Colors.yellowAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHint() {
    return Text(
      '💡 Sistem akan menghitung ratio panen otomatis: 75% jika mengikuti rekomendasi',
      style: TextStyle(
          fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey[600]),
    );
  }

  
  Widget _buildDateDisplay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF245C4C).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF245C4C).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month, size: 18, color: Color(0xFF245C4C)),
          const SizedBox(width: 8),
          Text(
            'Periode: ${_months[_selectedMonth - 1]} $_selectedYear',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF245C4C)),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFloorInputs() {
    return List.generate(_cageFloors, (floorIndex) {
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
                offset: const Offset(0, 2))
          ],
          border: Border.all(
            color: _isFloorTotalExceeded(floorIndex)
                ? Colors.red
                : Colors.grey[300]!,
            width: _isFloorTotalExceeded(floorIndex) ? 2 : 1,
          ),
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
                      borderRadius: BorderRadius.circular(8)),
                  child: Center(
                      child: Text('${floorIndex + 1}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold))),
                ),
                const SizedBox(width: 12),
                Text('Lantai ${floorIndex + 1}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF245C4C))),
                const Spacer(),
                if (_floorPreHarvest.containsKey(floorIndex))
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFFF7CA),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      'Max: ${_floorPreHarvest[floorIndex]} sarang',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF245C4C)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _floorControllers[floorIndex],
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Jumlah yang Dipanen',
                hintText: 'Masukkan jumlah sarang',
                suffixText: 'sarang',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF245C4C))),
                errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.red)),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return null;
                int? intValue = int.tryParse(value);
                if (intValue == null || intValue < 0)
                  return 'Masukkan angka yang valid';
                if (_floorPreHarvest.containsKey(floorIndex) &&
                    intValue > _floorPreHarvest[floorIndex]!) {
                  return 'Melebihi batas pre-harvest (${_floorPreHarvest[floorIndex]})';
                }
                return null;
              },
              onChanged: (value) => setState(() {}),
            ),
            const SizedBox(height: 12),
            

            OutlinedButton.icon(
              onPressed: () => _showBreakdownDialog(floorIndex),
              icon: const Icon(Icons.settings, size: 18),
              label: Text(
                _hasBreakdown(floorIndex) ? 'Detail ✓' : 'Detail',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: _hasBreakdown(floorIndex) ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _hasBreakdown(floorIndex) 
                    ? const Color(0xFF245C4C) 
                    : Colors.grey[700],
                side: BorderSide(
                  color: _hasBreakdown(floorIndex) 
                      ? const Color(0xFF245C4C) 
                      : Colors.grey[400]!,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            

            if (_hasBreakdown(floorIndex) && floorIndex < _floorBreakdown.length)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F8FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF245C4C).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildBreakdownChip('M', _floorBreakdown[floorIndex]['mangkok']!, const Color(0xFF245C4C)),
                    _buildBreakdownChip('S', _floorBreakdown[floorIndex]['sudut']!, const Color(0xFFffc200)),
                    _buildBreakdownChip('O', _floorBreakdown[floorIndex]['oval']!, const Color(0xFF168AB5)),
                    _buildBreakdownChip('P', _floorBreakdown[floorIndex]['patahan']!, const Color(0xFFC20000)),
                  ],
                ),
              ),
            
            if (_isFloorTotalExceeded(floorIndex))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.warning, size: 16, color: Colors.red),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text('Melebihi data pre-harvest!',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.red[700],
                              fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _saveHarvest,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF245C4C),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('Simpan Data Panen',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
      ),
    );
  }

  BottomNavigationBar _buildBottomNav() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: _currentIndex,
      onTap: (index) => setState(() => _currentIndex = index),
      items: [
        BottomNavigationBarItem(
          icon: CustomBottomNavigationItem(
            icon: Icons.home,
            label: 'Beranda',
            currentIndex: _currentIndex,
            itemIndex: 0,
            onTap: () => Navigator.pushReplacementNamed(context, '/home-page'),
          ),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: CustomBottomNavigationItem(
            icon: Icons.store,
            label: 'Kontrol',
            currentIndex: _currentIndex,
            itemIndex: 1,
            onTap: () =>
                Navigator.pushReplacementNamed(context, '/monitoring-page'),
          ),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: CustomBottomNavigationItem(
            icon: Icons.chat_sharp,
            label: 'Panen',
            currentIndex: _currentIndex,
            itemIndex: 2,
            onTap: () {},
          ),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: CustomBottomNavigationItem(
            icon: Icons.dataset_sharp,
            label: 'Jual',
            currentIndex: _currentIndex,
            itemIndex: 3,
            onTap: () =>
                Navigator.pushReplacementNamed(context, '/control-page'),
          ),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: CustomBottomNavigationItem(
            icon: Icons.person,
            label: 'Profil',
            currentIndex: _currentIndex,
            itemIndex: 4,
            onTap: () =>
                Navigator.pushReplacementNamed(context, '/profile-page'),
          ),
          label: '',
        ),
      ],
    );
  }
}
