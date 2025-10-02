import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swiftlead/pages/analysis_alternate_page.dart';
import 'package:swiftlead/pages/cage_data_page.dart';
import 'package:swiftlead/components/custom_bottom_navigation.dart';
import 'package:swiftlead/services/house_services.dart';
import 'package:swiftlead/services/device_installation_service.dart';
import 'package:swiftlead/utils/token_manager.dart';

class CageSelectionPage extends StatefulWidget {
  const CageSelectionPage({Key? key}) : super(key: key);

  @override
  State<CageSelectionPage> createState() => _CageSelectionPageState();
}

class _CageSelectionPageState extends State<CageSelectionPage> {
  double width(BuildContext context) => MediaQuery.of(context).size.width;
  double height(BuildContext context) => MediaQuery.of(context).size.height;

  List<Map<String, dynamic>> _cageList = [];
  int _currentIndex = 0;
  
  // API Services
  final HouseService _houseService = HouseService();
  final DeviceInstallationService _installationService = DeviceInstallationService();
  
  // Authentication
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
        // Try to load from API first
        await _loadCagesFromAPI();
      }
      
      // If API failed or no token, fallback to local data
      if (_cageList.isEmpty) {
        await _loadCages();
      }
    } catch (e) {
      print('Error initializing cage data: $e');
      // Fallback to local data
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
        // Check device installation status
        bool hasDeviceInstalled = false;
        List<String> installationCodes = [];
        try {
          final installCheck = await _installationService.checkDeviceInstallation(_authToken!, house['id']);
          hasDeviceInstalled = installCheck['hasDevices'] ?? false;
          installationCodes = List<String>.from(installCheck['installationCodes'] ?? []);
        } catch (e) {
          print('Failed to check device installation for house ${house['id']}: $e');
        }
        
        cageList.add({
          'id': 'house_${house['id']}',
          'apiId': house['id'],
          'name': house['name'] ?? 'Kandang ${house['floor_count'] ?? 1} Lantai',
          'address': house['location'] ?? 'Lokasi tidak tersedia',
          'floors': house['floor_count'] ?? 3,
          'description': house['description'] ?? '',
          'image': house['image_url'],
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
      // Don't throw, let it fallback to local data
    }
  }

  Future<void> _loadCages() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> cageList = [];
    
    // Get kandang count
    int kandangCount = prefs.getInt('kandang_count') ?? 0;
    
    if (kandangCount > 0) {
      // Load all kandang from new format
      for (int i = 1; i <= kandangCount; i++) {
        final name = prefs.getString('kandang_${i}_name');
        final address = prefs.getString('kandang_${i}_address');
        final floors = prefs.getInt('kandang_${i}_floors');
        final description = prefs.getString('kandang_${i}_description');
        final image = prefs.getString('kandang_${i}_image');
        
        // Include all kandang entries, even empty ones
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
      // Check for legacy single kandang data
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
          title: Text('Hapus Kandang'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Apakah Anda yakin ingin menghapus kandang "${cage['name']}"?'),
              SizedBox(height: 8),
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
              SizedBox(height: 8),
              Text(
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
              child: Text('Hapus'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteCage(Map<String, dynamic> cage) async {
    try {
      // Check if this cage is from API and has an API ID
      if (cage['isFromAPI'] == true && cage['apiId'] != null && _authToken != null) {
        try {
          // Delete from database first
          final apiResponse = await _houseService.delete(_authToken!, cage['apiId']);
          
          if (apiResponse['success'] == true || apiResponse['message'] != null) {
            print('House deleted from database: ${cage['apiId']}');
          } else {
            throw Exception('API deletion failed: ${apiResponse['error'] ?? 'Unknown error'}');
          }
        } catch (apiError) {
          print('Error deleting house from API: $apiError');
          
          // Show error message but ask if user wants to delete locally anyway
          final shouldDeleteLocal = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('Gagal Hapus dari Server'),
                content: Text(
                  'Kandang tidak dapat dihapus dari server. Hapus hanya dari penyimpanan lokal?\n\nError: $apiError',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text('Batal'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    child: Text('Hapus Lokal Saja'),
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
      
      // Handle local storage cleanup for local cages or fallback
      final prefs = await SharedPreferences.getInstance();
      final cageId = cage['id'].toString();
      
      // Extract the cage number from the ID (e.g., "kandang_1" -> 1)
      final cageNumber = int.tryParse(cageId.replaceAll('kandang_', '').replaceAll('cage_', '').replaceAll('house_', ''));
      
      if (cageNumber != null) {
        // Remove the specific cage data
        await prefs.remove('kandang_${cageNumber}_name');
        await prefs.remove('kandang_${cageNumber}_address');
        await prefs.remove('kandang_${cageNumber}_floors');
        await prefs.remove('kandang_${cageNumber}_description');
        await prefs.remove('kandang_${cageNumber}_image');
        
        // Also remove legacy data if it matches
        final legacyAddress = prefs.getString('cage_address');
        final legacyFloors = prefs.getInt('cage_floors');
        
        if (legacyAddress == cage['address'] && legacyFloors == cage['floors']) {
          await prefs.remove('cage_address');
          await prefs.remove('cage_floors');
          await prefs.remove('cage_image');
        }
        
        // Update kandang count by removing gaps and reorganizing
        await _reorganizeKandangData();
      }
      
      // Reload the cage list from API to get updated data
      await _initializeData();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
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
      
      // Collect all valid kandang data
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
      
      // Clear all existing kandang data
      for (int i = 1; i <= kandangCount; i++) {
        await prefs.remove('kandang_${i}_name');
        await prefs.remove('kandang_${i}_address');
        await prefs.remove('kandang_${i}_floors');
        await prefs.remove('kandang_${i}_description');
        await prefs.remove('kandang_${i}_image');
      }
      
      // Save reorganized data
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
      
      // Update kandang count
      await prefs.setInt('kandang_count', validKandang.length);
    } catch (e) {
      print('Error reorganizing kandang data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pilih Kandang'),
        backgroundColor: Color(0xFF245C4C),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
        ? Center(
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
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pilih kandang untuk analisis panen',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF245C4C),
                  ),
                ),
    
                SizedBox(height: 24),
    
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
                          SizedBox(height: 16),
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
                          margin: EdgeInsets.only(bottom: 16),
                          elevation: 3,
                          child: InkWell(
                            onTap: () {
                              if (cage['isEmpty'] == true) {
                                // Navigate to cage data page to complete the data
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CageDataPage(),
                                  ),
                                );
                              } else {
                                // Navigate to analysis page
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
                              padding: EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: cage['isEmpty'] == true 
                                          ? Colors.orange[100] 
                                          : Color(0xFFFFF7CA),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      cage['isEmpty'] == true 
                                          ? Icons.warning_amber
                                          : Icons.home_work,
                                      color: cage['isEmpty'] == true 
                                          ? Colors.orange[600]
                                          : Color(0xFF245C4C),
                                      size: 32,
                                    ),
                                  ),
                                  SizedBox(width: 16),
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
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF245C4C),
                                                ),
                                              ),
                                            ),
                                            if (cage['isFromAPI'] == true)
                                              Container(
                                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: cage['hasDeviceInstalled'] == true ? Colors.green : Colors.orange,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  cage['hasDeviceInstalled'] == true ? 'Device OK' : 'No Device',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          cage['address'] ?? 'Alamat tidak tersedia',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          '${cage['floors']} Lantai',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFFffc200),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Delete button
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

            // Add Cage Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CageDataPage(),
                    ),
                  );
                },
                icon: Icon(Icons.add, color: Colors.white),
                label: Text(
                  'Tambah Kandang',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF245C4C),
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
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/community-page');
                },
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
