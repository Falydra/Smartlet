import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swiftlead/components/custom_bottom_navigation.dart';
import 'package:swiftlead/services/house_services.dart';
import 'package:swiftlead/utils/token_manager.dart';
import 'package:swiftlead/pages/add_harvest_page.dart';

class GeneralHarvestInputPage extends StatefulWidget {
  final String? cageName;
  final int? floors;
  final int? houseId;

  const GeneralHarvestInputPage({
    Key? key,
    this.cageName,
    this.floors,
    this.houseId,
  }) : super(key: key);

  @override
  State<GeneralHarvestInputPage> createState() => _GeneralHarvestInputPageState();
}

class _GeneralHarvestInputPageState extends State<GeneralHarvestInputPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers for general input per floor
  late List<TextEditingController> _floorControllers;
  
  // API Services
  final HouseService _houseService = HouseService();
  
  // State management
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasSavedData = false;
  String? _authToken;
  
  // House data
  List<dynamic> _houses = [];
  Map<String, dynamic>? _selectedHouse;
  String _cageName = 'Kandang 1';
  int _cageFloors = 3;
  
  // Navigation
  int _currentIndex = 2;
  
  // Date selection
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  final List<String> _months = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
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
      print('Error initializing general harvest data: $e');
    }
    
    // Initialize controllers for each floor
    _floorControllers = List.generate(
      _cageFloors,
      (index) => TextEditingController(text: '0'),
    );
    
    // Add listeners to update total automatically
    for (var controller in _floorControllers) {
      controller.addListener(_updateTotals);
    }
    
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
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF245C4C)),
            SizedBox(width: 8),
            Text('Informasi Input'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cara Penggunaan:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text('1. Masukkan total sarang untuk setiap lantai'),
            Text('2. Klik tombol "Lanjut ke Detail" untuk input detail jenis sarang'),
            Text('3. Detail jenis sarang tidak boleh melebihi total sarang per lantai'),
            SizedBox(height: 12),
            Text(
              'Jenis Sarang:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text('• Mangkok: Sarang berbentuk mangkok sempurna'),
            Text('• Sudut: Sarang di pojok/sudut kandang'),
            Text('• Oval: Sarang berbentuk lonjong/oval'),
            Text('• Patahan: Sarang yang rusak/patah'),
          ],
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

  void _showDatePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pilih Bulan dan Tahun Panen'),
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
              SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _selectedYear,
                decoration: InputDecoration(
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
            child: Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
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

  int get _totalSarang {
    return _floorControllers.fold(0, (sum, controller) {
      return sum + (int.tryParse(controller.text) ?? 0);
    });
  }

  void _updateTotals() {
    if (mounted) {
      setState(() {
        // Update UI when controllers change
      });
    }
  }



  Future<void> _saveHarvestData() async {
    if (_formKey.currentState!.validate()) {
      if (_totalSarang == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
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



        // Save general totals to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final key = 'harvest_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}';
        
        await prefs.setDouble('${key}_general_total', _totalSarang.toDouble());

        // Save floor data to SharedPreferences
        for (int floor = 0; floor < _cageFloors; floor++) {
          final floorTotal = int.tryParse(_floorControllers[floor].text) ?? 0;
          await prefs.setDouble('${key}_floor_${floor + 1}_general_total', floorTotal.toDouble());
        }

        // Also save to AddHarvestPage static storage for consistency
        final staticData = AddHarvestPage.getStoredData();
        staticData['${key}_general_total'] = _totalSarang.toDouble();

        if (mounted) {
          setState(() {
            _hasSavedData = true;
            _isSaving = false;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Data panen berhasil disimpan'),
            backgroundColor: Colors.green,
          ),
        );
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
    int totalSarang = _totalSarang;
    int optimalHarvest = (totalSarang * 0.6).round(); // 60% of total
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            SizedBox(width: 8),
            Text('Rekomendasi Panen'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Sarang: $totalSarang',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Panen Optimal (60%): $optimalHarvest sarang',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF245C4C),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Detail per Lantai:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            ...List.generate(_cageFloors, (index) {
              int floorTotal = int.tryParse(_floorControllers[index].text) ?? 0;
              int floorOptimal = (floorTotal * 0.6).round();
              return Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('Lantai ${index + 1}: $floorTotal → $floorOptimal sarang'),
              );
            }),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFF245C4C).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Catatan: Panen 60% dari total sarang memastikan regenerasi yang optimal untuk siklus berikutnya.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tutup'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _proceedToDetail();
            },
            child: Text('Lanjut ke Detail'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF245C4C),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _proceedToDetail() {
    if (_formKey.currentState!.validate()) {
      // Prepare floor limits for detail page
      Map<int, int> floorLimits = {};
      for (int i = 0; i < _cageFloors; i++) {
        floorLimits[i] = int.tryParse(_floorControllers[i].text) ?? 0;
      }

      if (floorLimits.values.every((limit) => limit == 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Minimal satu lantai harus memiliki sarang'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Navigate to detail harvest page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddHarvestPage(
            cageName: _cageName,
            floors: _cageFloors,
            houseId: _selectedHouse?['id'],
            floorLimits: floorLimits,
            selectedMonth: _selectedMonth,
            selectedYear: _selectedYear,
          ),
        ),
      ).then((result) {
        if (result == true) {
          // If harvest was saved successfully, go back to previous page
          // Pass back the general totals for optimal harvest calculation
          Navigator.pop(context, {
            'success': true,
            'generalTotal': _totalSarang,
            'floorTotals': Map<int, int>.from(floorLimits),
          });
        }
      });
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
        foregroundColor: Color(0xFF245C4C),
        actions: [
          IconButton(
            onPressed: _showInfoDialog,
            icon: Icon(Icons.help_outline),
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
                    'Input Total Sarang per Lantai',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF245C4C),
                    ),
                  ),

                  SizedBox(height: 8),

                  Text(
                    'Masukkan total jumlah sarang untuk setiap lantai terlebih dahulu',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),

                  SizedBox(height: 16),

                  // Date Selection
                  Container(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showDatePicker,
                      icon: Icon(Icons.calendar_month, size: 18),
                      label: Text(
                        'Periode: ${_months[_selectedMonth - 1]} $_selectedYear',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Color(0xFF245C4C),
                        elevation: 2,
                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Color(0xFF245C4C).withOpacity(0.3)),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 24),

                  // Floor inputs
                  ...List.generate(_cageFloors, (floorIndex) {
                    return Container(
                      margin: EdgeInsets.only(bottom: 16),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: Offset(0, 2),
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
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF245C4C),
                                ),
                              ),
                            ],
                          ),
                          
                          SizedBox(height: 12),
                          
                          TextFormField(
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
                                borderSide: BorderSide(color: Color(0xFF245C4C)),
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
                        ],
                      ),
                    );
                  }),

                  SizedBox(height: 16),

                  // Pie Chart Section
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
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

                  SizedBox(height: 16),

                  // Total summary
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFF245C4C).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Color(0xFF245C4C).withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Total Sarang Keseluruhan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF245C4C),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '$_totalSarang sarang',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF245C4C),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  // Action buttons
                  Column(
                    children: [
                      // Confirm Save Button
                      Container(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: (_totalSarang > 0 && !_isSaving) ? _saveHarvestData : null,
                          icon: _isSaving 
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Icon(Icons.check, size: 18),
                          label: Text(_isSaving ? 'Menyimpan...' : 'Konfirmasi & Simpan'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _hasSavedData ? Color(0xff245C4C) : Color(0xFF245C4C),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 12),
                      
                      // Secondary buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: (_hasSavedData && _totalSarang > 0) ? _showOptimalHarvestSummary : null,
                              icon: Icon(Icons.agriculture, size: 18),
                              label: Text('Panen Optimal'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _hasSavedData ? Color(0xff245C4C) : Colors.grey,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _hasSavedData ? _proceedToDetail : null,
                              icon: Icon(Icons.arrow_forward, size: 18),
                              label: Text('Detail (Opsional)'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _hasSavedData ? Color(0xff245C4C) : Colors.grey,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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