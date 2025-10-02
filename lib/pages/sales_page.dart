import 'package:flutter/material.dart';
import 'package:swiftlead/components/custom_bottom_navigation.dart';
import 'package:swiftlead/services/market_services.dart';
import 'package:swiftlead/services/house_services.dart';
import 'package:swiftlead/utils/token_manager.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  // Services
  final MarketService _marketService = MarketService();
  final HouseService _houseService = HouseService();
  
  // State management
  bool _isLoading = true;
  String? _authToken;
  
  // Date selection
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  
  final List<String> _months = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];
  
  // Data
  List<dynamic> _harvestSales = [];
  List<dynamic> _houses = [];
  double _totalRevenue = 0.0;

  int _currentIndex = 3;

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
        // Load houses and sales data
        await Future.wait([
          _loadHouses(),
          _loadHarvestSales(),
        ]);
      }
    } catch (e) {
      print('Error initializing sales data: $e');
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

  Future<void> _loadHarvestSales() async {
    try {
      final sales = await _marketService.getHarvestSales(_authToken!, limit: 100);
      
      // Filter sales by selected month and year
      final filteredSales = sales.where((sale) {
        final saleDate = DateTime.tryParse(sale['sale_date'] ?? '');
        return saleDate != null && 
               saleDate.month == _selectedMonth && 
               saleDate.year == _selectedYear;
      }).toList();
      
      // Calculate total revenue
      double total = 0.0;
      for (var sale in filteredSales) {
        total += (sale['total_amount'] as num?)?.toDouble() ?? 0.0;
      }
      
      if (mounted) {
        setState(() {
          _harvestSales = filteredSales;
          _totalRevenue = total;
        });
      }
    } catch (e) {
      print('Error loading harvest sales: $e');
    }
  }

  void _showDatePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pilih Periode'),
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
                  if (mounted) {
                    setState(() {
                      _selectedMonth = value!;
                    });
                  }
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
            child: Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _loadHarvestSales(); // Reload data for new period
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

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Row(
          children: [
            Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: Image(
                image: AssetImage("assets/img/logo.png"),
                width: 64.0,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: _isLoading
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Color(0xFF245C4C)),
                SizedBox(height: 16),
                Text('Memuat data penjualan...', style: TextStyle(color: Color(0xFF245C4C))),
              ],
            ),
          )
        : SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1st Content: Title with Period Selection
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Pendapatan',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF245C4C),
                        ),
                      ),
                      SizedBox(height: 16),
                      Container(
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
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(color: Color(0xFFffc200)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 24),

                // 2nd Content: Kandang List with Sales Profit
                Text(
                  'Penjualan per Kandang',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF245C4C),
                  ),
                ),
                SizedBox(height: 12),
                
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: _houses.isEmpty 
                      ? [
                          Padding(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              children: [
                                Icon(Icons.home_work_outlined, size: 48, color: Colors.grey[400]),
                                SizedBox(height: 12),
                                Text(
                                  'Belum ada kandang terdaftar',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                        ]
                      : _houses.map((house) {
                          double houseRevenue = 0.0;
                          for (var sale in _harvestSales) {
                            if (sale['house_id'] == house['id']) {
                              houseRevenue += (sale['total_amount'] as num?)?.toDouble() ?? 0.0;
                            }
                          }
                          
                          return Container(
                            padding: EdgeInsets.all(16),
                            margin: EdgeInsets.only(bottom: 1),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        house['name'] ?? 'Kandang ${house['id']}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF245C4C),
                                        ),
                                      ),
                                      Text(
                                        house['location'] ?? 'Lokasi tidak tersedia',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  _formatCurrency(houseRevenue),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: houseRevenue > 0 ? Colors.green[600] : Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                  ),
                ),

                SizedBox(height: 24),

                // 3rd Content: Rekap Transaksi
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Color(0xFF245C4C),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Rekap Transaksi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '${_months[_selectedMonth - 1]} $_selectedYear',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        _formatCurrency(_totalRevenue),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFffc200),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '${_harvestSales.length} transaksi',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 32),

                // 4th Content: Action Buttons
                Column(
                  children: [
                    // First Button: Tambah Penjualan Transaksi
                    Container(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // TODO: Navigate to add sales transaction page
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Fitur Tambah Penjualan akan segera hadir'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        },
                        icon: Icon(Icons.add_shopping_cart, color: Colors.white, size: 20),
                        label: Text(
                          'Tambah Penjualan Transaksi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF245C4C),
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Second Button: Ajukan Penjualan Sarang Walet
                    Container(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // TODO: Navigate to request bird nest sales page
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Fitur Ajukan Penjualan akan segera hadir'),
                              backgroundColor: Colors.blue,
                            ),
                          );
                        },
                        icon: Icon(Icons.request_quote, color: Color(0xFF245C4C), size: 20),
                        label: Text(
                          'Ajukan Penjualan Sarang Walet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF245C4C),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFFFF7CA),
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Color(0xFFffc200)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 80), // Bottom padding for navigation bar
              ],
            ),
          ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          if (mounted) {
            setState(() {
              _currentIndex = index;
            });
          }
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
                  if (mounted) {
                    setState(() {
                      _currentIndex = 0;
                    });
                  }
                },
              ),
              label: ''),
          BottomNavigationBarItem(
              icon: CustomBottomNavigationItem(
                icon: Icons.pest_control,
                label: 'Kontrol',
                currentIndex: _currentIndex,
                itemIndex: 1,
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/control-page');
                  if (mounted) {
                    setState(() {
                      _currentIndex = 1;
                    });
                  }
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
                  if (mounted) {
                    setState(() {
                      _currentIndex = 2;
                    });
                  }
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
                  if (mounted) {
                    setState(() {
                      _currentIndex = 3;
                    });
                  }
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
                  if (mounted) {
                    setState(() {
                      _currentIndex = 4;
                    });
                  }
                },
              ),
              label: ''),
        ],
      ),
    );
  }
}