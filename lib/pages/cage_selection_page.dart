import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swiftlead/pages/analysis_alternate_page.dart';
import 'package:swiftlead/pages/cage_data_page.dart';
import 'package:swiftlead/components/custom_bottom_navigation.dart';
import 'package:swiftlead/services/house_services.dart';
import 'package:swiftlead/pages/edit_cage_page.dart';

import 'package:swiftlead/utils/token_manager.dart';

class CageSelectionPage extends StatefulWidget {
  const CageSelectionPage({super.key});

  @override
  State<CageSelectionPage> createState() => _CageSelectionPageState();
}

class _CageSelectionPageState extends State<CageSelectionPage> {
  double width(BuildContext context) => MediaQuery.of(context).size.width;
  double height(BuildContext context) => MediaQuery.of(context).size.height;

  List<Map<String, dynamic>> _cageList = [];
  int _currentIndex = 0;
  

  final HouseService _houseService = HouseService();

  

  String? _authToken;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      _authToken = await TokenManager.getToken();
      
      if (_authToken != null) {

        await _loadCagesFromAPI();
      }
      

      if (_cageList.isEmpty) {
        await _loadCages();
      }
    } catch (e) {
      print('Error initializing cage data: $e');

      await _loadCages();
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadCagesFromAPI() async {
    try {
      final houses = await _houseService.getAll(_authToken!);
      
      List<Map<String, dynamic>> cageList = [];
      for (var house in houses) {

        bool hasDeviceInstalled = false;
        List<String> installationCodes = [];


        
        cageList.add({
          'id': 'house_${house['id']}',
          'apiId': house['id'].toString(),

          'name': house['name'] ?? 'Kandang ${house['total_floors'] ?? house['floor_count'] ?? 1} Lantai',
          'address': house['address'] ?? house['location'] ?? 'Lokasi tidak tersedia',
          'floors': house['total_floors'] ?? house['floor_count'] ?? 3,
          'description': house['description'] ?? '',
          'image': house['image_url'],
          'latitude': house['latitude'],
          'longitude': house['longitude'],
          'code': house['code'],
          'isEmpty': false,
          'isFromAPI': true,
          'hasDeviceInstalled': hasDeviceInstalled,
          'installationCodes': installationCodes,
        });
      }
      
      setState(() {
        _cageList = cageList;
      });
      
      print('Loaded ${cageList.length} cages from API');
    } catch (e) {
      print('Error loading cages from API: $e');

    }
  }

  Future<void> _loadCages() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> cageList = [];
    

    int kandangCount = prefs.getInt('kandang_count') ?? 0;
    
    if (kandangCount > 0) {

      for (int i = 1; i <= kandangCount; i++) {
        final name = prefs.getString('kandang_${i}_name');
        final address = prefs.getString('kandang_${i}_address');
        final floors = prefs.getInt('kandang_${i}_floors');
        final description = prefs.getString('kandang_${i}_description');
        final image = prefs.getString('kandang_${i}_image');
        

        if (floors != null) {
          final isEmpty = name == null || name.isEmpty || address == null || address.isEmpty;
          cageList.add({
            'id': 'kandang_$i',
            'name': isEmpty ? 'Empty' : name,
            'address': isEmpty ? 'Data belum lengkap' : address,
            'floors': floors,
            'description': description ?? '',
            'image': image,
            'isEmpty': isEmpty,
          });
        }
      }
    } else {

      final savedAddress = prefs.getString('cage_address');
      final savedFloors = prefs.getInt('cage_floors');
      final savedImage = prefs.getString('cage_image');

      if (savedAddress != null && savedAddress.isNotEmpty && savedFloors != null) {
        cageList.add({
          'id': 'cage_1',
          'name': 'Kandang $savedFloors Lantai',
          'address': savedAddress,
          'floors': savedFloors,
          'image': savedImage,
        });
      }
    }

    setState(() {
      _cageList = cageList;
    });
  } catch (e) {
    print('Error loading cages: $e');
  }
}

  void _showDeleteDialog(Map<String, dynamic> cage) {
    final isFromAPI = cage['isFromAPI'] == true;
    final hasDevice = cage['hasDeviceInstalled'] == true;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Hapus Kandang'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Apakah Anda yakin ingin menghapus kandang "${cage['name']}"?'),
              const SizedBox(height: 8),
              if (isFromAPI) 
                Text(
                  '• Kandang akan dihapus dari database server',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                )
              else
                Text(
                  '• Kandang hanya akan dihapus dari penyimpanan lokal',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              if (hasDevice)
                Text(
                  '• Perangkat yang terpasang mungkin perlu dikonfigurasi ulang',
                  style: TextStyle(fontSize: 12, color: Colors.orange[600]),
                ),
              const SizedBox(height: 8),
              const Text(
                'Tindakan ini tidak dapat dibatalkan.',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Batal',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteCage(cage);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteCage(Map<String, dynamic> cage) async {
    try {

      if (cage['isFromAPI'] == true && cage['apiId'] != null && _authToken != null) {
        try {

          final dynamic rawId = cage['apiId'];
          final String apiId = rawId?.toString() ?? '';

          if (apiId.isEmpty) {
            throw Exception('Invalid apiId for cage: ${cage['apiId']}');
          }


          final apiResponse = await _houseService.delete(_authToken!, apiId);

          if (apiResponse['success'] == true || apiResponse['message'] != null || apiResponse['data'] != null) {
            print('House deleted from database: $apiId');
          } else {
            throw Exception('API deletion failed: ${apiResponse['error'] ?? 'Unknown error'}');
          }
        } catch (apiError) {
          print('Error deleting house from API: $apiError');
          

          final shouldDeleteLocal = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Gagal Hapus dari Server'),
                content: Text(
                  'Kandang tidak dapat dihapus dari server. Hapus hanya dari penyimpanan lokal?\n\nError: $apiError',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Batal'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    child: const Text('Hapus Lokal Saja'),
                  ),
                ],
              );
            },
          );
          
          if (shouldDeleteLocal != true) {
            return; // User cancelled
          }
        }
      }
      

      final prefs = await SharedPreferences.getInstance();
    final cageId = cage['id'].toString();
      

      final cageNumber = int.tryParse(cageId.replaceAll('kandang_', '').replaceAll('cage_', '').replaceAll('house_', ''));
      
      if (cageNumber != null) {

        await prefs.remove('kandang_${cageNumber}_name');
        await prefs.remove('kandang_${cageNumber}_address');
        await prefs.remove('kandang_${cageNumber}_floors');
        await prefs.remove('kandang_${cageNumber}_description');
        await prefs.remove('kandang_${cageNumber}_image');
        

        final legacyAddress = prefs.getString('cage_address');
        final legacyFloors = prefs.getInt('cage_floors');
        
        if (legacyAddress == cage['address'] && legacyFloors == cage['floors']) {
          await prefs.remove('cage_address');
          await prefs.remove('cage_floors');
          await prefs.remove('cage_image');
        }
        

        await _reorganizeKandangData();
      }
      

      await _initializeData();
      

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kandang berhasil dihapus'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error deleting cage: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus kandang: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _reorganizeKandangData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final kandangCount = prefs.getInt('kandang_count') ?? 0;
      
      List<Map<String, dynamic>> validKandang = [];
      

      for (int i = 1; i <= kandangCount; i++) {
        final name = prefs.getString('kandang_${i}_name');
        final address = prefs.getString('kandang_${i}_address');
        final floors = prefs.getInt('kandang_${i}_floors');
        final description = prefs.getString('kandang_${i}_description');
        final image = prefs.getString('kandang_${i}_image');
        
        if (floors != null) {
          validKandang.add({
            'name': name ?? '',
            'address': address ?? '',
            'floors': floors,
            'description': description ?? '',
            'image': image,
          });
        }
      }
      

      for (int i = 1; i <= kandangCount; i++) {
        await prefs.remove('kandang_${i}_name');
        await prefs.remove('kandang_${i}_address');
        await prefs.remove('kandang_${i}_floors');
        await prefs.remove('kandang_${i}_description');
        await prefs.remove('kandang_${i}_image');
      }
      

      for (int i = 0; i < validKandang.length; i++) {
        final kandang = validKandang[i];
        final newIndex = i + 1;
        
        await prefs.setString('kandang_${newIndex}_name', kandang['name']);
        await prefs.setString('kandang_${newIndex}_address', kandang['address']);
        await prefs.setInt('kandang_${newIndex}_floors', kandang['floors']);
        await prefs.setString('kandang_${newIndex}_description', kandang['description']);
        if (kandang['image'] != null) {
          await prefs.setString('kandang_${newIndex}_image', kandang['image']);
        }
      }
      

      await prefs.setInt('kandang_count', validKandang.length);
    } catch (e) {
      print('Error reorganizing kandang data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Kandang'),
        backgroundColor: const Color(0xFF245C4C),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Color(0xFF245C4C)),
                SizedBox(height: 16),
                Text('Memuat data kandang...'),
              ],
            ),
          )
        : Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pilih kandang untuk analisis panen',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF245C4C),
                  ),
                ),
    
                const SizedBox(height: 24),
    
                Expanded(
                  child: _cageList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.home_work_outlined,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Belum ada kandang terdaftar',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _cageList.length,
                      itemBuilder: (context, index) {
                        final cage = _cageList[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 3,
                          child: InkWell(
                            onTap: () {
                              if (cage['isEmpty'] == true) {

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const CageDataPage(),
                                  ),
                                );
                              } else {

                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AnalysisPageAlternate(
                                      selectedCageId: cage['id'],
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: cage['isEmpty'] == true 
                                          ? Colors.orange[100] 
                                          : const Color(0xFFFFF7CA),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      cage['isEmpty'] == true 
                                          ? Icons.warning_amber
                                          : Icons.home_work,
                                      color: cage['isEmpty'] == true 
                                          ? Colors.orange[600]
                                          : const Color(0xFF245C4C),
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                cage['name'] ?? 'Kandang Tidak Dikenal',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF245C4C),
                                                ),
                                              ),
                                            ),
                                            if (cage['isFromAPI'] == true)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: cage['hasDeviceInstalled'] == true ? Colors.green : Colors.orange,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  cage['hasDeviceInstalled'] == true ? 'Device OK' : 'No Device',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          cage['address'] ?? 'Alamat tidak tersedia',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${cage['floors']} Lantai',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFFffc200),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  IconButton(
                                    onPressed: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => EditCagePage(cage: cage)),
                                      );
                                      if (result == true) {

                                        await _initializeData();
                                      }
                                    },
                                    icon: Icon(
                                      Icons.edit_outlined,
                                      color: Colors.blue[600],
                                      size: 20,
                                    ),
                                  ),

                                  IconButton(
                                    onPressed: () => _showDeleteDialog(cage),
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color: Colors.red[400],
                                      size: 20,
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.grey[400],
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),


            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CageDataPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Tambah Kandang',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF245C4C),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
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
}
