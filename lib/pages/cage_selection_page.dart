import 'package:flutter/material.dart';
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
      } else {
        _cageList = [];
      }
    } catch (e) {
      print('Error initializing cage data: $e');
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
      setState(() {
        _cageList = [];
      });
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
              Text(
                isFromAPI
                    ? '• Kandang akan dihapus dari database server'
                    : '• Kandang ini bukan data server dan tidak bisa dihapus dari halaman ini',
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
      if (_authToken == null) {
        throw Exception('Sesi login tidak ditemukan. Silakan login ulang.');
      }

      if (cage['isFromAPI'] != true || cage['apiId'] == null) {
        throw Exception('Kandang ini tidak berasal dari database server.');
      }

      final String apiId = cage['apiId'].toString();
      final apiResponse = await _houseService.delete(_authToken!, apiId);
      if (apiResponse['success'] != true) {
        final statusCode = apiResponse['statusCode'] as int?;
        final apiMessage = apiResponse['message']?.toString();
        if (statusCode == 403) {
          throw Exception(apiMessage ?? 'Anda tidak punya izin menghapus kandang ini.');
        }
        throw Exception(apiMessage ?? 'Penghapusan kandang gagal di server.');
      }

      print('House deleted from database: $apiId');
      await _loadCagesFromAPI();
      

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kandang berhasil dihapus'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error deleting cage: $e');
      final cleanMessage = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus kandang: $cleanMessage'),
          backgroundColor: Colors.red,
        ),
      );
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
                                    onPressed: cage['isFromAPI'] == true
                                        ? () => _showDeleteDialog(cage)
                                        : null,
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
