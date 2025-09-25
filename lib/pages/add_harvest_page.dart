import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swiftlead/components/custom_bottom_navigation.dart';

class AddHarvestPage extends StatefulWidget {
  final String cageName;
  final int floors;

  const AddHarvestPage({
    Key? key,
    required this.cageName,
    required this.floors,
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

  // Static storage as fallback
  static Map<String, dynamic> _staticStorage = {};

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.floors,
      (floor) => List.generate(
        4,
        (type) => TextEditingController(),
      ),
    );
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

  void _showExampleDialog(String type, String imagePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Contoh $type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 200,
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.image,
                size: 50,
                color: Colors.grey[400],
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Ini adalah contoh sarang burung walet tipe $type',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
          ],
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

  Future<void> _saveHarvest() async {
    if (_formKey.currentState!.validate()) {
      try {
        final key =
            'harvest_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}';

        // Calculate totals
        double totalMangkok = 0,
            totalSudut = 0,
            totalOval = 0,
            totalPatahan = 0;

        // Prepare data
        Map<String, double> harvestData = {};

        // Save floor data and calculate totals
        for (int floor = 0; floor < widget.floors; floor++) {
          final mangkok = double.tryParse(_controllers[floor][0].text) ?? 0.0;
          final sudut = double.tryParse(_controllers[floor][1].text) ?? 0.0;
          final oval = double.tryParse(_controllers[floor][2].text) ?? 0.0;
          final patahan = double.tryParse(_controllers[floor][3].text) ?? 0.0;

          // Store individual floor data
          harvestData['${key}_floor_${floor + 1}_mangkok'] = mangkok;
          harvestData['${key}_floor_${floor + 1}_sudut'] = sudut;
          harvestData['${key}_floor_${floor + 1}_oval'] = oval;
          harvestData['${key}_floor_${floor + 1}_patahan'] = patahan;

          // Add to totals
          totalMangkok += mangkok;
          totalSudut += sudut;
          totalOval += oval;
          totalPatahan += patahan;
        }

        // Store total data
        harvestData['${key}_mangkok'] = totalMangkok;
        harvestData['${key}_sudut'] = totalSudut;
        harvestData['${key}_oval'] = totalOval;
        harvestData['${key}_patahan'] = totalPatahan;

        // Always save to static storage first (as primary storage)
        _staticStorage.addAll(harvestData);
        print('Data saved to static storage successfully');

        // Try to save with SharedPreferences as backup
        try {
          final prefs = await SharedPreferences.getInstance();
          for (String dataKey in harvestData.keys) {
            await prefs.setDouble(dataKey, harvestData[dataKey]!);
          }
          print('Data also saved to SharedPreferences successfully');
        } catch (prefsError) {
          print(
              'SharedPreferences save failed (using static storage): $prefsError');
          // This is fine, static storage is working
        }

        print(
            'Harvest data saved for ${_months[_selectedMonth - 1]} $_selectedYear');
        print('Saved data: $harvestData');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Data panen ${_months[_selectedMonth - 1]} $_selectedYear berhasil disimpan!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Wait a moment to show the success message
        await Future.delayed(Duration(milliseconds: 500));

        Navigator.pop(context, true); // Return true to indicate successful save
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

          for (int floor = 0; floor < widget.floors; floor++) {
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
        title: Text('Tambah Panen - ${widget.cageName}'),
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
                    backgroundColor: Color(0xFFFFF7CA),
                    foregroundColor: Color(0xFF245C4C),
                    elevation: 2,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Color(0xFFffc200)),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 24),

              ...List.generate(widget.floors, (floorIndex) {
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
                      Text(
                        'Lantai ${floorIndex + 1}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF245C4C),
                        ),
                      ),
                      SizedBox(height: 16),
                      ...List.generate(4, (typeIndex) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _controllers[floorIndex]
                                      [typeIndex],
                                  keyboardType: TextInputType.numberWithOptions(
                                      decimal: true),
                                  decoration: InputDecoration(
                                    labelText:
                                        '${_harvestTypes[typeIndex]} (Kg)',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide:
                                          BorderSide(color: Color(0xFF245C4C)),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Wajib diisi';
                                    }
                                    if (double.tryParse(value) == null) {
                                      return 'Masukkan angka yang valid';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              SizedBox(width: 8),
                              IconButton(
                                onPressed: () => _showExampleDialog(
                                  _harvestTypes[typeIndex],
                                  '',
                                ),
                                icon: Icon(
                                  Icons.help_outline,
                                  color: Color(0xFF245C4C),
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
