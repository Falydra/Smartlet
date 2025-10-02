import 'package:flutter/material.dart';
import 'package:swiftlead/components/custom_bottom_navigation.dart';
import 'package:swiftlead/services/harvest_services.dart';
import 'package:swiftlead/services/house_services.dart';
import 'package:swiftlead/utils/token_manager.dart';

class AddHarvestPage extends StatefulWidget {
  final String? cageName;
  final int? floors;
  final int? houseId;
  final Map<int, int>? floorLimits;
  final int? selectedMonth;
  final int? selectedYear;

  const AddHarvestPage({
    Key? key,
    this.cageName,
    this.floors,
    this.houseId,
    this.floorLimits,
    this.selectedMonth,
    this.selectedYear,
  }) : super(key: key);

  static Map<String, dynamic> getStoredData() {
    return Map<String, dynamic>.from(_AddHarvestPageState._staticStorage);
  }

  static void clearStoredData() {
    _AddHarvestPageState._staticStorage.clear();
  }

  static bool hasDataForPeriod(int year, int month) {
    final key = 'harvest_${year}_${month.toString().padLeft(2, '0')}';
    return _AddHarvestPageState._staticStorage.containsKey('${key}_mangkok');
  }

  @override
  State<AddHarvestPage> createState() => _AddHarvestPageState();
}

class _AddHarvestPageState extends State<AddHarvestPage> {
  final _formKey = GlobalKey<FormState>();

  late List<List<TextEditingController>> _controllers;

  final List<String> _harvestTypes = ['Mangkok', 'Sudut', 'Oval', 'Patahan'];
  int _currentIndex = 2;

  // API Services
  final HarvestService _harvestService = HarvestService();
  final HouseService _houseService = HouseService();
  
  // State management
  bool _isLoading = true;
  String? _authToken;
  
  // House data
  List<dynamic> _houses = [];
  Map<String, dynamic>? _selectedHouse;
  String _cageName = 'Kandang 1';
  int _cageFloors = 3;
  
  // Floor limits from general input
  Map<int, int> _floorLimits = {};

  // Increment settings
  double _selectedIncrement = 1;
  final List<double> _incrementOptions = [1, 5, 10];

  // Date selection
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

  // Static storage as fallback
  static Map<String, dynamic> _staticStorage = {};

  @override
  void initState() {
    super.initState();
    // Initialize date from parameters or use current date
    _selectedMonth = widget.selectedMonth ?? DateTime.now().month;
    _selectedYear = widget.selectedYear ?? DateTime.now().year;
    
    // Initialize floor limits from parameters
    _floorLimits = widget.floorLimits ?? {};
    
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
        // Load houses from API
        await _loadHouses();
        
        // Set selected house
        if (widget.houseId != null) {
          _selectedHouse = _houses.firstWhere(
            (house) => house['id'] == widget.houseId,
            orElse: () => _houses.isNotEmpty ? _houses.first : null,
          );
        } else if (_houses.isNotEmpty) {
          _selectedHouse = _houses.first;
        }
        
        if (_selectedHouse != null) {
          _cageName = _selectedHouse!['name'] ?? 'Kandang 1';
          _cageFloors = _selectedHouse!['floor_count'] ?? 3;
        }
      }
    } catch (e) {
      print('Error initializing harvest data: $e');
    }
    
    // Initialize controllers based on cage floors
    _controllers = List.generate(
      _cageFloors,
      (floor) => List.generate(
        4,
        (type) => TextEditingController(text: '0'),
      ),
    );
    
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

  @override
  void dispose() {
    for (var floorControllers in _controllers) {
      for (var controller in floorControllers) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  void _incrementValue(int floor, int type) {
    TextEditingController controller = _controllers[floor][type];
    int currentValue = int.tryParse(controller.text) ?? 0;
    int newValue = currentValue + _selectedIncrement.toInt();
    controller.text = newValue.toString();
  }

  void _decrementValue(int floor, int type) {
    TextEditingController controller = _controllers[floor][type];
    int currentValue = int.tryParse(controller.text) ?? 0;
    int newValue = (currentValue - _selectedIncrement.toInt()).clamp(0, 999999);
    controller.text = newValue.toString();
  }
  
  int _getCurrentFloorTotal(int floorIndex) {
    int total = 0;
    for (int i = 0; i < 4; i++) {
      total += int.tryParse(_controllers[floorIndex][i].text) ?? 0;
    }
    return total;
  }
  
  bool _isFloorTotalExceeded(int floorIndex) {
    if (!_floorLimits.containsKey(floorIndex)) return false;
    return _getCurrentFloorTotal(floorIndex) > _floorLimits[floorIndex]!;
  }

  void _showIncrementSelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pilih Nilai Increment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: _incrementOptions.map((increment) {
            return RadioListTile<double>(
              title: Text('+${increment.toInt()}'),
              value: increment,
              groupValue: _selectedIncrement,
              onChanged: (value) {
                setState(() {
                  _selectedIncrement = value!;
                });
                Navigator.pop(context);
              },
            );
          }).toList(),
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

  void _showExampleDialog(String type, String imagePath) {
    String description = '';
    String characteristics = '';
    String quality = '';
    
    switch (type.toLowerCase()) {
      case 'mangkok':
        description = 'Sarang berbentuk mangkok sempurna dengan struktur yang utuh dan rapi.';
        characteristics = '• Bentuk bulat sempurna\n• Tebal merata\n• Tidak ada retakan\n• Warna putih bersih';
        quality = 'Kualitas tertinggi - Harga jual paling mahal';
        break;
      case 'sudut':
        description = 'Sarang yang terbentuk di pojok atau sudut kandang dengan bentuk tidak sempurna.';
        characteristics = '• Bentuk menyesuaikan sudut\n• Satu sisi menempel dinding\n• Struktur cukup tebal\n• Sebagian bentuk tidak bulat';
        quality = 'Kualitas baik - Harga menengah ke atas';
        break;
      case 'oval':
        description = 'Sarang berbentuk lonjong atau oval dengan struktur yang baik namun tidak bulat sempurna.';
        characteristics = '• Bentuk lonjong/oval\n• Struktur cukup tebal\n• Permukaan relatif halus\n• Warna putih hingga krem';
        quality = 'Kualitas baik - Harga menengah';
        break;
      case 'patahan':
        description = 'Sarang yang rusak, patah, atau tidak sempurna akibat berbagai faktor.';
        characteristics = '• Ada bagian yang patah/rusak\n• Struktur tidak utuh\n• Mungkin ada kotoran\n• Bentuk tidak beraturan';
        quality = 'Kualitas rendah - Harga paling murah';
        break;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF245C4C)),
            SizedBox(width: 8),
            Text('Detail Sarang $type'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getTypeIcon(type.toLowerCase()),
                      size: 40,
                      color: Color(0xFF245C4C),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Sarang $type',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF245C4C),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Deskripsi:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 4),
              Text(description, style: TextStyle(fontSize: 14)),
              SizedBox(height: 12),
              Text(
                'Karakteristik:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 4),
              Text(characteristics, style: TextStyle(fontSize: 14)),
              SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFF245C4C).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nilai Ekonomi:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(quality, style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Mengerti'),
          ),
        ],
      ),
    );
  }
  
  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'mangkok':
        return Icons.circle;
      case 'sudut':
        return Icons.crop_square;
      case 'oval':
        return Icons.egg;
      case 'patahan':
        return Icons.broken_image;
      default:
        return Icons.help;
    }
  }



  Future<void> _saveHarvest() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedHouse == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tidak ada kandang yang dipilih'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Check if any floor exceeds its limit
      for (int i = 0; i < _cageFloors; i++) {
        if (_isFloorTotalExceeded(i)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lantai ${i + 1}: Detail sarang melebihi batas ${_floorLimits[i]} sarang'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }

      try {
        // Calculate totals
        int totalMangkok = 0,
            totalSudut = 0,
            totalOval = 0,
            totalPatahan = 0;

        // Calculate totals from all floors
        for (int floor = 0; floor < _cageFloors; floor++) {
          final mangkok = int.tryParse(_controllers[floor][0].text) ?? 0;
          final sudut = int.tryParse(_controllers[floor][1].text) ?? 0;
          final oval = int.tryParse(_controllers[floor][2].text) ?? 0;
          final patahan = int.tryParse(_controllers[floor][3].text) ?? 0;

          totalMangkok += mangkok;
          totalSudut += sudut;
          totalOval += oval;
          totalPatahan += patahan;
        }

        // Prepare harvest data for API
        Map<String, dynamic> harvestPayload = {
          'house_id': _selectedHouse!['id'],
          'harvest_date': '${_selectedYear}-${_selectedMonth.toString().padLeft(2, '0')}-01',
          'mangkok': totalMangkok,
          'sudut': totalSudut,
          'oval': totalOval,
          'patahan': totalPatahan,
          'floor_data': [],
        };

        // Add floor-specific data
        for (int floor = 0; floor < _cageFloors; floor++) {
          final mangkok = int.tryParse(_controllers[floor][0].text) ?? 0;
          final sudut = int.tryParse(_controllers[floor][1].text) ?? 0;
          final oval = int.tryParse(_controllers[floor][2].text) ?? 0;
          final patahan = int.tryParse(_controllers[floor][3].text) ?? 0;

          harvestPayload['floor_data'].add({
            'floor': floor + 1,
            'mangkok': mangkok,
            'sudut': sudut,
            'oval': oval,
            'patahan': patahan,
          });
        }

        // Save to API
        final result = await _harvestService.create(_authToken!, harvestPayload);
        
        if (result['success'] == true) {
          // Also save to static storage as backup
          final key = 'harvest_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}';
          Map<String, dynamic> localData = {
            '${key}_mangkok': totalMangkok.toDouble(),
            '${key}_sudut': totalSudut.toDouble(),
            '${key}_oval': totalOval.toDouble(),
            '${key}_patahan': totalPatahan.toDouble(),
          };
          
          // Store general floor totals separately for optimal harvest calculation
          int totalGeneralSarang = 0;
          for (int floor = 0; floor < _cageFloors; floor++) {
            int floorTotal = _floorLimits[floor] ?? 0;
            localData['${key}_floor_${floor + 1}_general_total'] = floorTotal.toDouble();
            totalGeneralSarang += floorTotal;
          }
          localData['${key}_general_total'] = totalGeneralSarang.toDouble();
          
          // Save floor data locally too
          for (int floor = 0; floor < _cageFloors; floor++) {
            final mangkok = int.tryParse(_controllers[floor][0].text) ?? 0;
            final sudut = int.tryParse(_controllers[floor][1].text) ?? 0;
            final oval = int.tryParse(_controllers[floor][2].text) ?? 0;
            final patahan = int.tryParse(_controllers[floor][3].text) ?? 0;
            
            localData['${key}_floor_${floor + 1}_mangkok'] = mangkok.toDouble();
            localData['${key}_floor_${floor + 1}_sudut'] = sudut.toDouble();
            localData['${key}_floor_${floor + 1}_oval'] = oval.toDouble();
            localData['${key}_floor_${floor + 1}_patahan'] = patahan.toDouble();
          }
          
          _staticStorage.addAll(localData);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Data panen ${_months[_selectedMonth - 1]} $_selectedYear berhasil disimpan!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
          
          // Wait a moment to show the success message
          await Future.delayed(Duration(milliseconds: 500));
          
          if (mounted) {
            Navigator.pop(context, true); // Return true to indicate successful save
          }
        } else {
          throw Exception(result['message'] ?? 'Failed to save harvest data');
        }
      } catch (e) {
        print('Error saving harvest data: $e');

        // Even if there's an error, still save to static storage
        try {
          final key =
              'harvest_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}';
          double totalMangkok = 0,
              totalSudut = 0,
              totalOval = 0,
              totalPatahan = 0;
          Map<String, double> harvestData = {};

          for (int floor = 0; floor < _cageFloors; floor++) {
            final mangkok = double.tryParse(_controllers[floor][0].text) ?? 0.0;
            final sudut = double.tryParse(_controllers[floor][1].text) ?? 0.0;
            final oval = double.tryParse(_controllers[floor][2].text) ?? 0.0;
            final patahan = double.tryParse(_controllers[floor][3].text) ?? 0.0;

            harvestData['${key}_floor_${floor + 1}_mangkok'] = mangkok;
            harvestData['${key}_floor_${floor + 1}_sudut'] = sudut;
            harvestData['${key}_floor_${floor + 1}_oval'] = oval;
            harvestData['${key}_floor_${floor + 1}_patahan'] = patahan;

            totalMangkok += mangkok;
            totalSudut += sudut;
            totalOval += oval;
            totalPatahan += patahan;
          }

          harvestData['${key}_mangkok'] = totalMangkok;
          harvestData['${key}_sudut'] = totalSudut;
          harvestData['${key}_oval'] = totalOval;
          harvestData['${key}_patahan'] = totalPatahan;
          
          // Store general floor totals for optimal harvest calculation
          double totalGeneralSarang = 0;
          for (int floor = 0; floor < _cageFloors; floor++) {
            double floorTotal = (_floorLimits[floor] ?? 0).toDouble();
            harvestData['${key}_floor_${floor + 1}_general_total'] = floorTotal;
            totalGeneralSarang += floorTotal;
          }
          harvestData['${key}_general_total'] = totalGeneralSarang;

          _staticStorage.addAll(harvestData);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Data panen ${_months[_selectedMonth - 1]} $_selectedYear berhasil disimpan! (Lokal)'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          await Future.delayed(Duration(milliseconds: 500));
          Navigator.pop(context, true);
        } catch (fallbackError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Terjadi kesalahan saat menyimpan data'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Static method to get stored data (for analysis page)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Tambah Panen - $_cageName'),
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
            padding: EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Input Data Panen per Lantai',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF245C4C),
                ),
              ),

              SizedBox(height: 8),

              Text(
                'Masukkan berat sarang (dalam Kg) untuk setiap jenis dan lantai',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),

              SizedBox(height: 16),

              // Date Selection (read-only from previous page)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Color(0xFF245C4C).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xFF245C4C).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month, size: 18, color: Color(0xFF245C4C)),
                    SizedBox(width: 8),
                    Text(
                      'Periode: ${_months[_selectedMonth - 1]} $_selectedYear',
                      style: TextStyle(
                        fontSize: 14, 
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF245C4C),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16),

              // Increment Selector
              Row(
                children: [
                  Text(
                    'Increment: ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF245C4C),
                    ),
                  ),
                  InkWell(
                    onTap: _showIncrementSelector,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Color(0xFFFFF7CA),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Color(0xFFffc200)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '+${_selectedIncrement.toInt()}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF245C4C),
                            ),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'increment',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF245C4C),
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_drop_down,
                            color: Color(0xFF245C4C),
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Spacer(),
                  
                ],
              ),

              SizedBox(height: 24),

              ...List.generate(_cageFloors, (floorIndex) {
                return Container(
                  margin: EdgeInsets.only(bottom: 24),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
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
                              color: Color(0xFF245C4C),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '${floorIndex + 1}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Lantai ${floorIndex + 1}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF245C4C),
                            ),
                          ),
                          Spacer(),
                          if (_floorLimits.containsKey(floorIndex))
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _isFloorTotalExceeded(floorIndex) 
                                  ? Colors.red.withOpacity(0.1)
                                  : Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _isFloorTotalExceeded(floorIndex)
                                    ? Colors.red
                                    : Colors.blue,
                                ),
                              ),
                              child: Text(
                                '${_getCurrentFloorTotal(floorIndex)}/${_floorLimits[floorIndex]} sarang',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _isFloorTotalExceeded(floorIndex)
                                    ? Colors.red[700]
                                    : Colors.blue[700],
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (_floorLimits.containsKey(floorIndex) && _isFloorTotalExceeded(floorIndex))
                        Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '⚠️ Total detail melebihi batas ${_floorLimits[floorIndex]} sarang!',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      SizedBox(height: 16),
                      ...List.generate(4, (typeIndex) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: [
                              // Minus Button
                              
                              
                              SizedBox(width: 8),
                              
                              // Text Input Field
                              Expanded(
                                child: TextFormField(
                                  controller: _controllers[floorIndex][typeIndex],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    labelText: '${_harvestTypes[typeIndex]}',
                                    hintText: 'Jumlah ${_harvestTypes[typeIndex].toLowerCase()}',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(color: Color(0xFF245C4C)),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Wajib diisi';
                                    }
                                    if (int.tryParse(value) == null) {
                                      return 'Masukkan angka yang valid';
                                    }
                                    if (int.tryParse(value)! < 0) {
                                      return 'Nilai tidak boleh negatif';
                                    }
                                    return null;
                                  },
                                  onChanged: (value) {
                                    // Trigger rebuild to update floor total display
                                    setState(() {});
                                  },
                                ),
                              ),
                              
                              SizedBox(width: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red[200]!),
                                ),
                                child: IconButton(
                                  onPressed: () => _decrementValue(floorIndex, typeIndex),
                                  icon: Icon(
                                    Icons.remove,
                                    color: Colors.red[600],
                                    size: 20,
                                  ),
                                  constraints: BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 40,
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                              SizedBox(width: 8),
                              
                              // Plus Button
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green[200]!),
                                ),
                                child: IconButton(
                                  onPressed: () => _incrementValue(floorIndex, typeIndex),
                                  icon: Icon(
                                    Icons.add,
                                    color: Colors.green[600],
                                    size: 20,
                                  ),
                                  constraints: BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 40,
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                              
                              SizedBox(width: 8),
                              
                              // Help Button
                              IconButton(
                                onPressed: () => _showExampleDialog(
                                  _harvestTypes[typeIndex],
                                  '',
                                ),
                                icon: Icon(
                                  Icons.help_outline,
                                  color: Color(0xFF245C4C),
                                ),
                                constraints: BoxConstraints(
                                  minWidth: 40,
                                  minHeight: 40,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }),

              SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveHarvest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF245C4C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Simpan Data Panen',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 80),
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
}
