import 'package:flutter/material.dart';
import 'package:swiftlead/components/custom_bottom_navigation.dart';
import 'package:swiftlead/services/house_services.dart';
import 'package:swiftlead/services/transaction_service.dart';
import 'package:swiftlead/services/pdf_service.dart';
import 'package:swiftlead/utils/token_manager.dart';
import 'package:swiftlead/pages/add_income_page.dart';
import 'package:swiftlead/pages/add_expense_page.dart';
import 'package:swiftlead/pages/transaction_history_page.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {

  final HouseService _houseService = HouseService();
  final TransactionService _transactionService = TransactionService();


  bool _isLoading = true;
  String? _authToken;


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


  List<dynamic> _transactions = [];
  List<dynamic> _houses = [];
  String? _selectedHouseId; // Track selected RBW
  double _totalIncome = 0.0;
  double _totalExpense = 0.0;
  double _netProfit = 0.0;

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

      _authToken = await TokenManager.getToken();

      if (_authToken != null) {

        await _loadHouses();
        await _loadHarvestSales();
      }
    } catch (e) {
      print('Error initializing sales data: $e');
    } finally {

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadHouses() async {
    try {
      final houses = await _houseService.getAll(_authToken!);
      if (mounted) {
        setState(() {
          _houses = houses;

          if (houses.isNotEmpty && _selectedHouseId == null) {
            _selectedHouseId = houses.first['id']?.toString();
            print('[SALES PAGE] Selected default house: $_selectedHouseId');
          }
        });
      }
    } catch (e) {
      print('Error loading houses: $e');
    }
  }

  Future<void> _loadHarvestSales() async {
    try {
      print(
          '[SALES PAGE] Loading transactions for ${_months[_selectedMonth - 1]} $_selectedYear');
      print('[SALES PAGE] Selected house ID: $_selectedHouseId');


      final transactions = await _transactionService.getAll(
        _authToken!,
        month: _selectedMonth,
        year: _selectedYear,
        houseId: _selectedHouseId, // Pass the selected house ID
      );

      print('[SALES PAGE] Loaded ${transactions.length} transactions');
      if (transactions.isNotEmpty) {
        print('[SALES PAGE] First transaction sample: ${transactions.first}');
        print('[SALES PAGE] Sample transaction fields:');
        print('  - type: ${transactions.first['type']}');
        print('  - amount: ${transactions.first['amount']}');
        print('  - description: ${transactions.first['description']}');
        print('  - transaction_date: ${transactions.first['transaction_date']}');
        print('  - rbw_id: ${transactions.first['rbw_id']}');
      }


      double income = 0.0;
      double expense = 0.0;

      for (var transaction in transactions) {
        final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
        final type = transaction['type']?.toString() ?? '';

        print(
            '[SALES PAGE] Transaction: type=$type, amount=$amount');

        if (type == 'income') {
          income += amount;
        } else if (type == 'expense') {
          expense += amount;
        }
      }

      print(
          '[SALES PAGE] Totals - Income: $income, Expense: $expense, Net: ${income - expense}');

      if (mounted) {
        setState(() {
          _transactions = transactions;
          _totalIncome = income;
          _totalExpense = expense;
          _netProfit = income - expense;
        });
      }
    } catch (e) {
      print('Error loading transactions: $e');
      if (mounted) {
        setState(() {
          _transactions = [];
          _totalIncome = 0.0;
          _totalExpense = 0.0;
          _netProfit = 0.0;
        });
      }
    }
  }

  void _showDatePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pilih Periode'),
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
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _selectedYear,
                decoration: const InputDecoration(
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
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _loadHarvestSales(); // Reload data for new period
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

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  Future<void> _downloadEStatement(String type) async {

    try {

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF245C4C)),
          );
        },
      );


      String houseName = 'Semua Kandang';
      if (_selectedHouseId != null) {
        final house = _houses.firstWhere(
          (h) => h['id']?.toString() == _selectedHouseId,
          orElse: () => {'name': 'Kandang'},
        );
        houseName = house['name'] ?? 'Kandang';
      }


      String period = type == 'bulanan'
          ? '${_months[_selectedMonth - 1]} $_selectedYear'
          : 'Tahun $_selectedYear';


      final filePath = await PdfService.generateEStatement(
        period: period,
        houseName: houseName,
        totalIncome: _totalIncome,
        totalExpense: _totalExpense,
        netProfit: _netProfit,
        transactions: _transactions,
        type: type,
      );


      if (mounted) Navigator.of(context).pop();


      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Row(
                children: const [
                  Icon(Icons.check_circle, color: Colors.green, size: 28),
                  SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'E-Statement Berhasil Dibuat!',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('File tersimpan di folder Download'),
                  const SizedBox(height: 8),
                  Text(
                    'Nama file: ${filePath.split('/').last}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              actions: [
                TextButton.icon(
                  onPressed: () async {
                    Navigator.of(context).pop();

                    try {
                      await PdfService.sharePdfFile(
                        filePath,
                        'E-Statement $period - Smartlet Management System',
                      );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Gagal membagikan file: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('Bagikan'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(context).pop();

                    final opened = await PdfService.openPdfFile(filePath);
                    if (!opened && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Tidak dapat membuka file PDF. Silakan buka dari folder Download.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Buka File'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {

      if (mounted) Navigator.of(context).pop();


      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Gagal membuat E-Statement: $e'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDownloadOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Download E-Statement',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF245C4C),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pilih tipe statement yang ingin diunduh',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),


              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF245C4C).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.calendar_today,
                      color: Color(0xFF245C4C)),
                ),
                title: const Text(
                  'Statement Bulanan',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Periode: ${_months[_selectedMonth - 1]} $_selectedYear',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.download, color: Color(0xFF245C4C)),
                onTap: () {
                  Navigator.pop(context);
                  _downloadEStatement('bulanan');
                },
              ),
              const Divider(),


              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF245C4C).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.calendar_view_month,
                      color: Color(0xFF245C4C)),
                ),
                title: const Text(
                  'Statement Tahunan',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Periode: Tahun $_selectedYear',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.download, color: Color(0xFF245C4C)),
                onTap: () {
                  Navigator.pop(context);
                  _downloadEStatement('tahunan');
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  void _showAllTransactionsDialog() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionHistoryPage(
          transactions: _transactions,
          houses: _houses,
          selectedMonth: _months[_selectedMonth - 1],
          selectedYear: _selectedYear.toString(),
        ),
      ),
    );


    if (result == true) {
      _loadHarvestSales();
    }
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
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF245C4C)),
                  SizedBox(height: 16),
                  Text('Memuat data penjualan...',
                      style: TextStyle(color: Color(0xFF245C4C))),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Center(
                    child: Column(
                      children: [

                        if (_houses.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFF245C4C)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedHouseId,
                                isExpanded: true,
                                hint: const Text('Pilih Kandang'),
                                icon: const Icon(Icons.arrow_drop_down,
                                    color: Color(0xFF245C4C)),
                                items: _houses.map((house) {
                                  return DropdownMenuItem<String>(
                                    value: house['id']?.toString(),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.home,
                                            size: 16, color: Color(0xFF245C4C)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            house['name'] ??
                                                'Kandang ${house['id']}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF245C4C),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (mounted && value != null) {
                                    setState(() {
                                      _selectedHouseId = value;
                                    });
                                    _loadHarvestSales(); // Reload data for new house
                                  }
                                },
                              ),
                            ),
                          ),

                        Container(
                          child: ElevatedButton.icon(
                            onPressed: _showDatePicker,
                            icon: const Icon(Icons.calendar_month, size: 18),
                            label: Text(
                              'Periode: ${_months[_selectedMonth - 1]} $_selectedYear',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFF7CA),
                              foregroundColor: const Color(0xFF245C4C),
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side:
                                    const BorderSide(color: Color(0xFFffc200)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),


                  const Text(
                    'Penjualan per Kandang',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF245C4C),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 2,
                          blurRadius: 5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: _houses.isEmpty
                          ? [
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  children: [
                                    Icon(Icons.home_work_outlined,
                                        size: 48, color: Colors.grey[400]),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Belum ada kandang terdaftar',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                            ]
                          : _houses.map((house) {
                              double houseIncome = 0.0;
                              double houseExpense = 0.0;

                              for (var transaction in _transactions) {

                                final transactionHouseId =
                                    transaction['rbw_id']?.toString() ??
                                        transaction['house_id']?.toString();
                                if (transactionHouseId ==
                                    house['id']?.toString()) {
                                  final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
                                  final type = transaction['type']?.toString() ?? '';

                                  if (type == 'income') {
                                    houseIncome += amount;
                                  } else if (type == 'expense') {
                                    houseExpense += amount;
                                  }
                                }
                              }

                              final houseNet = houseIncome - houseExpense;

                              return Container(
                                padding: const EdgeInsets.all(16),
                                margin: const EdgeInsets.only(bottom: 1),
                                decoration: BoxDecoration(
                                  border: Border(
                                      bottom:
                                          BorderSide(color: Colors.grey[200]!)),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            house['name'] ??
                                                'Kandang ${house['id']}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF245C4C),
                                            ),
                                          ),
                                          Text(
                                            house['address'] ??
                                                house['location'] ??
                                                '-',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      _formatCurrency(houseNet),
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: houseNet > 0
                                            ? Colors.green[600]
                                            : (houseNet < 0
                                                ? Colors.red[600]
                                                : Colors.grey[500]),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                    ),
                  ),

                  const SizedBox(height: 24),


                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF245C4C),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.2),
                          spreadRadius: 2,
                          blurRadius: 5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Rekap Transaksi',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_months[_selectedMonth - 1]} $_selectedYear',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 16),


                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Pendapatan:',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.white70),
                            ),
                            Text(
                              _formatCurrency(_totalIncome),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.greenAccent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),


                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Pengeluaran:',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.white70),
                            ),
                            Text(
                              _formatCurrency(_totalExpense),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(color: Colors.white30),
                        const SizedBox(height: 12),


                        Column(
                          children: [
                            const Text(
                              'Total Pendapatan',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatCurrency(_netProfit),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: _netProfit >= 0
                                    ? const Color(0xFFffc200)
                                    : Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_transactions.length} transaksi',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),


                  if (_transactions.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Laporan Keuangan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF245C4C),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF245C4C).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_transactions.length} transaksi',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF245C4C),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: _transactions.take(3).map((transaction) {
                          final type = transaction['type']?.toString() ?? '';
                          final isIncome = type == 'income';

                          final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
                          final date = transaction['transaction_date'] != null
                              ? DateTime.tryParse(transaction['transaction_date'])
                              : null;
                          final categoryNameForDisplay = isIncome ? 'Pendapatan' : 'Pengeluaran';


                          String houseName =
                              transaction['rbw_name']?.toString() ??
                                  transaction['house_name']?.toString() ??
                                  '';


                          if (houseName.isEmpty) {
                            final transactionHouseId =
                                transaction['rbw_id']?.toString() ??
                                    transaction['house_id']?.toString();
                            final house = _houses.firstWhere(
                              (h) => h['id']?.toString() == transactionHouseId,
                              orElse: () => {'name': 'Unknown'},
                            );
                            houseName = house['name']?.toString() ?? 'Unknown';
                          }

                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Colors.grey[200]!),
                              ),
                            ),
                            child: Row(
                              children: [

                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isIncome
                                        ? const Color(0xFF245C4C)
                                            .withOpacity(0.1)
                                        : Colors.red[50],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    isIncome
                                        ? Icons.trending_up
                                        : Icons.trending_down,
                                    color: isIncome
                                        ? const Color(0xFF245C4C)
                                        : Colors.red[700],
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),


                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        transaction['description'] ??
                                            'Transaksi',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.label_outline,
                                              size: 12,
                                              color: Colors.grey[600]),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              categoryNameForDisplay,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(Icons.home_outlined,
                                              size: 12,
                                              color: Colors.grey[600]),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              houseName,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_today,
                                              size: 12,
                                              color: Colors.grey[600]),
                                          const SizedBox(width: 4),
                                          Text(
                                            date != null
                                                ? '${date.day}/${date.month}/${date.year}'
                                                : 'No date',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),


                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        isIncome ? '+' : '-',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isIncome
                                              ? const Color(0xFF245C4C)
                                              : Colors.red[700],
                                        ),
                                      ),
                                      Text(
                                        _formatCurrency(amount),
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: isIncome
                                              ? const Color(0xFF245C4C)
                                              : Colors.red[700],
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),


                    if (_transactions.length > 0) ...[
                      const SizedBox(height: 12),
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            _showAllTransactionsDialog();
                          },
                          icon: const Icon(Icons.arrow_forward, size: 18),
                          label: const Text(
                            'Lihat Semua Riwayat Transaksi',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF245C4C),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                  ],

                  const SizedBox(height: 8),


                  Column(
                    children: [

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AddIncomePage(),
                              ),
                            );
                            if (result == true) {
                              _loadHarvestSales(); // Reload data
                            }
                          },
                          icon: const Icon(Icons.add_shopping_cart,
                              color: Colors.white, size: 20),
                          label: const Text(
                            'Tambah Penjualan Transaksi',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF245C4C),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),


                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AddExpensePage(),
                              ),
                            );
                            if (result == true) {
                              _loadHarvestSales(); // Reload data
                            }
                          },
                          icon: const Icon(Icons.receipt_long,
                              color: Colors.white, size: 20),
                          label: const Text(
                            'Tambah Pengeluaran',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[700],
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _showDownloadOptions,
                          icon: const Icon(Icons.download,
                              color: Colors.white, size: 20),
                          label: const Text(
                            'Download Financial Summary',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF245C4C),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                      height: 80), // Bottom padding for navigation bar
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
                icon: Icons.devices,
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
