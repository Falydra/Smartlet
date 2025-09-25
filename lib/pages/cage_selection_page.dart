import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swiftlead/pages/analysis_alternate_page.dart';
import 'package:swiftlead/pages/cage_data_page.dart';
import 'package:swiftlead/components/custom_bottom_navigation.dart';

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

  @override
  void initState() {
    super.initState();
    _loadCages();
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
        final address = prefs.getString('kandang_${i}_address');
        final floors = prefs.getInt('kandang_${i}_floors');
        final image = prefs.getString('kandang_${i}_image');
        
        if (address != null && address.isNotEmpty && floors != null) {
          cageList.add({
            'id': 'kandang_$i',
            'name': 'Kandang $floors Lantai',
            'address': address,
            'floors': floors,
            'image': image,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pilih Kandang'),
        backgroundColor: Color(0xFF245C4C),
        foregroundColor: Colors.white,
      ),
      body: Padding(
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
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AnalysisPageAlternate(
                                    selectedCageId: cage['id'],
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFFFF7CA),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.home_work,
                                      color: Color(0xFF245C4C),
                                      size: 32,
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          cage['name'],
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF245C4C),
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          cage['address'],
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
