import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:swiftlead/components/custom_bottom_navigation.dart';
import 'package:swiftlead/services/house_services.dart';
import 'package:swiftlead/services/transaction_service.dart';
import 'package:swiftlead/services/pdf_service.dart'
    if (dart.library.html) 'package:swiftlead/services/pdf_service_web.dart';
import 'package:swiftlead/utils/token_manager.dart';
import 'package:swiftlead/utils/modern_snackbar.dart';
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
  List<dynamic> _allTransactions = []; // All transactions for selected house (for Laporan Keuangan)
  List<dynamic> _houses = [];
  String? _selectedHouseId; // Track selected RBW
  double _totalIncome = 0.0;
  double _totalExpense = 0.0;
  double _netProfit = 0.0;


  String _recapType = 'monthly'; // 'monthly' or 'annual'
  double _annualTotalIncome = 0.0;
  double _annualTotalExpense = 0.0;
  double _annualNetProfit = 0.0;

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
        await _loadAllTransactions(); // Load all transactions for Laporan Keuangan
        await _loadAnnualData();
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

      print('[SALES PAGE] Loaded ${transactions.length} transactions from API');
      if (transactions.isNotEmpty) {
        print('[SALES PAGE] All transactions received:');
        for (var i = 0; i < transactions.length; i++) {
          final txn = transactions[i];
          print('  [$i] id: ${txn['id']}, date: ${txn['transaction_date']}, amount: ${txn['amount']}, type: ${txn['type']}');
        }
      }


      final filteredTransactions = transactions.where((transaction) {
        final transactionDateStr = transaction['transaction_date']?.toString();
        if (transactionDateStr == null) {
          print('[SALES PAGE] ⚠️ Transaction has no date, skipping');
          return false;
        }
        
        try {
          final transactionDate = DateTime.parse(transactionDateStr);
          final isCorrectMonth = transactionDate.month == _selectedMonth && transactionDate.year == _selectedYear;
          
          if (!isCorrectMonth) {
            print('[SALES PAGE] ❌ Filtering out: ${transactionDate.year}-${transactionDate.month.toString().padLeft(2, '0')}-${transactionDate.day.toString().padLeft(2, '0')} (expected: $_selectedYear-${_selectedMonth.toString().padLeft(2, '0')})');
          } else {
            print('[SALES PAGE] ✓ Including: ${transactionDate.year}-${transactionDate.month.toString().padLeft(2, '0')}-${transactionDate.day.toString().padLeft(2, '0')}');
          }
          
          return isCorrectMonth;
        } catch (e) {
          print('[SALES PAGE] ⚠️ Error parsing date: $transactionDateStr');
          return false;
        }
      }).toList();

      print('[SALES PAGE] After filtering: ${filteredTransactions.length} transactions for ${_months[_selectedMonth - 1]} $_selectedYear');


      double income = 0.0;
      double expense = 0.0;

      for (var transaction in filteredTransactions) {
        final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
        final type = transaction['type']?.toString() ?? '';

        if (type == 'income') {
          income += amount;
        } else if (type == 'expense') {
          expense += amount;
        }
      }

      print('[SALES PAGE] 📊 Monthly Summary for ${_months[_selectedMonth - 1]} $_selectedYear:');
      print('[SALES PAGE]   - Transactions: ${filteredTransactions.length}');
      print('[SALES PAGE]   - Income: Rp ${income.toStringAsFixed(0)}');
      print('[SALES PAGE]   - Expense: Rp ${expense.toStringAsFixed(0)}');
      print('[SALES PAGE]   - Net Profit: Rp ${(income - expense).toStringAsFixed(0)}');

      if (mounted) {
        setState(() {
          _transactions = filteredTransactions;
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

  Future<void> _loadAllTransactions() async {
    try {
      print('[SALES PAGE] Loading ALL transactions for house: $_selectedHouseId');
      
      if (_selectedHouseId == null) {
        if (mounted) {
          setState(() {
            _allTransactions = [];
          });
        }
        return;
      }


      final allTransactions = await _transactionService.listTransactionsByRbw(
        token: _authToken!,
        rbwId: _selectedHouseId!,
        limit: 100, // Get up to 100 transactions
      );

      final transactions = allTransactions['data'] ?? [];
      print('[SALES PAGE] Loaded ${transactions.length} total transactions for Laporan Keuangan');

      if (mounted) {
        setState(() {
          _allTransactions = transactions;
        });
      }
    } catch (e) {
      print('Error loading all transactions: $e');
      if (mounted) {
        setState(() {
          _allTransactions = [];
        });
      }
    }
  }

  Future<void> _loadAnnualData() async {
    try {
      print('[SALES PAGE] Loading annual data for $_selectedYear');
      
      double annualIncome = 0.0;
      double annualExpense = 0.0;
      Set<String> processedTransactionIds = {}; // Track unique transactions


      for (int month = 1; month <= 12; month++) {
        final transactions = await _transactionService.getAll(
          _authToken!,
          month: month,
          year: _selectedYear,
          houseId: _selectedHouseId,
        );

        print('[SALES PAGE] Month $month: Loaded ${transactions.length} transactions from API');

        for (var transaction in transactions) {

          final transactionDateStr = transaction['transaction_date']?.toString();
          if (transactionDateStr != null) {
            try {
              final transactionDate = DateTime.parse(transactionDateStr);
              if (transactionDate.year != _selectedYear) {
                print('[SALES PAGE] Skipping transaction from wrong year: ${transactionDate.year} (expected $_selectedYear)');
                continue;
              }
            } catch (e) {
              print('[SALES PAGE] Error parsing date for annual data: $transactionDateStr');
              continue;
            }
          }


          final transactionId = transaction['id']?.toString() ?? 
                                transaction['transaction_id']?.toString() ?? 
                                '${transaction['transaction_date']}_${transaction['amount']}_${transaction['description']}';
          

          if (processedTransactionIds.contains(transactionId)) {
            print('[SALES PAGE] Skipping duplicate transaction ID: $transactionId');
            continue;
          }
          processedTransactionIds.add(transactionId);

          final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
          final type = transaction['type']?.toString() ?? '';

          if (type == 'income') {
            annualIncome += amount;
          } else if (type == 'expense') {
            annualExpense += amount;
          }
        }
      }

      print('[SALES PAGE] 📊 Annual Summary for $_selectedYear:');
      print('[SALES PAGE]   - Unique Transactions: ${processedTransactionIds.length}');
      print('[SALES PAGE]   - Income: Rp ${annualIncome.toStringAsFixed(0)}');
      print('[SALES PAGE]   - Expense: Rp ${annualExpense.toStringAsFixed(0)}');
      print('[SALES PAGE]   - Net Profit: Rp ${(annualIncome - annualExpense).toStringAsFixed(0)}');

      if (mounted) {
        setState(() {
          _annualTotalIncome = annualIncome;
          _annualTotalExpense = annualExpense;
          _annualNetProfit = annualIncome - annualExpense;
        });
      }
    } catch (e) {
      print('Error loading annual data: $e');
      if (mounted) {
        setState(() {
          _annualTotalIncome = 0.0;
          _annualTotalExpense = 0.0;
          _annualNetProfit = 0.0;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    print('[SALES PAGE] 🔄 Manual refresh triggered');
    print('[SALES PAGE] Current month: ${_months[_selectedMonth - 1]} $_selectedYear');
    print('[SALES PAGE] Current house: $_selectedHouseId');
    
    await _loadHarvestSales();
    await _loadAllTransactions(); // Refresh all transactions
    await _loadAnnualData();
    
    if (mounted) {
      ModernSnackBar.success(context, 'Data berhasil dimuat ulang', duration: const Duration(seconds: 2));
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
              _loadAnnualData(); // Reload annual data
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
    if (kIsWeb) {
      ModernSnackBar.warning(context, 'Download PDF tidak didukung di versi web. Gunakan aplikasi Android.');
      return;
    }

    bool dialogShown = false;

    try {
      // Show loading spinner
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(
            child: CircularProgressIndicator(color: Color(0xFF245C4C)),
          ),
        );
        dialogShown = true;
      }

      // --- Resolve house name & period ---
      String houseName = 'Semua Kandang';
      if (_selectedHouseId != null) {
        final house = _houses.firstWhere(
          (h) => h['id']?.toString() == _selectedHouseId,
          orElse: () => <String, dynamic>{'name': 'Kandang'},
        );
        houseName = (house as Map<String, dynamic>)['name'] ?? 'Kandang';
      }
      final String period = type == 'bulanan'
          ? '${_months[_selectedMonth - 1]} $_selectedYear'
          : 'Tahun $_selectedYear';

      // --- Collect transactions ---
      List<dynamic> pdfTransactions = _transactions;
      double pdfIncome = _totalIncome;
      double pdfExpense = _totalExpense;
      double pdfNetProfit = _netProfit;

      if (type == 'tahunan') {
        final List<dynamic> yearTransactions = [];
        double yearIncome = 0.0;
        double yearExpense = 0.0;
        final Set<String> seen = {};

        for (int month = 1; month <= 12; month++) {
          // Each month call already has a 15-second timeout in TransactionService
          final monthTxns = await _transactionService.getAll(
            _authToken!,
            month: month,
            year: _selectedYear,
            houseId: _selectedHouseId,
          );
          for (final txn in monthTxns) {
            final dateStr = txn['transaction_date']?.toString();
            if (dateStr != null) {
              try {
                if (DateTime.parse(dateStr).year != _selectedYear) continue;
              } catch (_) {
                continue;
              }
            }
            final txnId = txn['id']?.toString() ??
                '${txn['transaction_date']}_${txn['amount']}_${txn['description']}';
            if (seen.contains(txnId)) continue;
            seen.add(txnId);
            yearTransactions.add(txn);
            final amount = (txn['amount'] as num?)?.toDouble() ?? 0.0;
            final t = txn['type']?.toString() ?? '';
            if (t == 'income') yearIncome += amount;
            if (t == 'expense') yearExpense += amount;
          }
        }

        pdfTransactions = yearTransactions;
        pdfIncome = yearIncome;
        pdfExpense = yearExpense;
        pdfNetProfit = yearIncome - yearExpense;
      }

      // --- Generate & save PDF (90-second hard timeout) ---
      final String filePath = await PdfService.generateEStatement(
        period: period,
        houseName: houseName,
        totalIncome: pdfIncome,
        totalExpense: pdfExpense,
        netProfit: pdfNetProfit,
        transactions: pdfTransactions,
        type: type,
      ).timeout(const Duration(seconds: 90));

      // Dismiss loading dialog
      if (dialogShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogShown = false;
      }

      // Show success dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext ctx) {
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
                  const Text('File berhasil dibuat'),
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
                    Navigator.of(ctx).pop();
                    try {
                      await PdfService.sharePdfFile(
                        filePath,
                        'E-Statement $period - Smartlet Management System',
                      );
                    } catch (e) {
                      if (ctx.mounted) {
                        ModernSnackBar.error(ctx, 'Gagal membagikan file');
                      }
                    }
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('Bagikan'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    final opened = await PdfService.openPdfFile(filePath);
                    if (!opened && ctx.mounted) {
                      ModernSnackBar.warning(
                        ctx,
                        'Tidak dapat membuka file PDF secara langsung. Gunakan tombol Bagikan.',
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
      print('[PDF ERROR] $e');
      final String msg = e is TimeoutException
          ? 'Koneksi timeout. Periksa jaringan internet dan coba lagi.'
          : 'Gagal membuat E-Statement: ${e.toString().split('\n').first}';
      if (mounted) ModernSnackBar.error(context, msg);
    } finally {
      // Always ensure the loading dialog is dismissed
      if (dialogShown && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
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
              const SizedBox(height: 32),
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
          transactions: _allTransactions,
          houses: _houses,
          selectedMonth: 'Semua',
          selectedYear: _selectedYear.toString(),
        ),
      ),
    );


    if (result == true) {
      print('[SALES PAGE] 🔄 Transaction edited/deleted, refreshing data...');
      print('[SALES PAGE] Current month: ${_months[_selectedMonth - 1]} $_selectedYear');
      
      if (mounted) {
        setState(() {
          _isLoading = true;
        });
      }
      
      await _loadHarvestSales();
      await _loadAllTransactions(); // Reload all transactions for Laporan Keuangan
      await _loadAnnualData(); // Reload annual data after editing/deleting transactions
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF245C4C)),
            tooltip: 'Muat Ulang Data',
            onPressed: _isLoading ? null : _refreshData,
          ),
        ],
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
          : RefreshIndicator(
              onRefresh: _refreshData,
              color: const Color(0xFF245C4C),
              child: SingleChildScrollView(
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
                                    _loadAllTransactions(); // Reload all transactions
                                    _loadAnnualData(); // Reload annual data for new house
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
                        const SizedBox(height: 12),

                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    if (mounted) {
                                      setState(() {
                                        _recapType = 'monthly';
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _recapType == 'monthly'
                                          ? Colors.white
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Bulanan',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _recapType == 'monthly'
                                            ? const Color(0xFF245C4C)
                                            : Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    if (mounted) {
                                      setState(() {
                                        _recapType = 'annual';
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _recapType == 'annual'
                                          ? Colors.white
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Tahunan',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _recapType == 'annual'
                                            ? const Color(0xFF245C4C)
                                            : Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _recapType == 'monthly'
                              ? '${_months[_selectedMonth - 1]} $_selectedYear'
                              : 'Tahun $_selectedYear',
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
                              _formatCurrency(_recapType == 'monthly' ? _totalIncome : _annualTotalIncome),
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
                              _formatCurrency(_recapType == 'monthly' ? _totalExpense : _annualTotalExpense),
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
                              _formatCurrency(_recapType == 'monthly' ? _netProfit : _annualNetProfit),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: (_recapType == 'monthly' ? _netProfit : _annualNetProfit) >= 0
                                    ? const Color(0xFFffc200)
                                    : Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _recapType == 'monthly'
                              ? '${_transactions.length} transaksi bulan ini'
                              : 'Tahun $_selectedYear',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),


                  if (_allTransactions.isNotEmpty) ...[
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final screenWidth = MediaQuery.of(context).size.width;
                        final isSmallScreen = screenWidth < 360;
                        
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                'Laporan Keuangan',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 16 : 18,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF245C4C),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: isSmallScreen ? 8 : 12,
                                  vertical: isSmallScreen ? 4 : 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF245C4C).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_allTransactions.length} transaksi',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 10 : 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF245C4C),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
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
                        children: _allTransactions.take(3).map((transaction) {
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

                          return LayoutBuilder(
                            builder: (context, constraints) {
                              final screenWidth = MediaQuery.of(context).size.width;
                              final isSmallScreen = screenWidth < 360;
                              final isVerySmallScreen = screenWidth < 340;
                              
                              return Container(
                                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: Colors.grey[200]!),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [

                                    Container(
                                      padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
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
                                        size: isSmallScreen ? 20 : 24,
                                      ),
                                    ),
                                    SizedBox(width: isSmallScreen ? 8 : 12),


                                    Expanded(
                                      flex: isVerySmallScreen ? 2 : 3,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            transaction['description'] ??
                                                'Transaksi',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: isSmallScreen ? 13 : 14,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          SizedBox(height: isSmallScreen ? 3 : 4),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.label_outline,
                                                  size: isSmallScreen ? 10 : 12,
                                                  color: Colors.grey[600]),
                                              const SizedBox(width: 2),
                                              Flexible(
                                                child: Text(
                                                  categoryNameForDisplay,
                                                  style: TextStyle(
                                                    fontSize: isSmallScreen ? 10 : 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: isSmallScreen ? 3 : 4),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.home_outlined,
                                                  size: isSmallScreen ? 10 : 12,
                                                  color: Colors.grey[600]),
                                              const SizedBox(width: 2),
                                              Flexible(
                                                child: Text(
                                                  houseName,
                                                  style: TextStyle(
                                                    fontSize: isSmallScreen ? 10 : 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: isSmallScreen ? 3 : 4),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.calendar_today,
                                                  size: isSmallScreen ? 10 : 12,
                                                  color: Colors.grey[600]),
                                              const SizedBox(width: 4),
                                              Text(
                                                date != null
                                                    ? '${date.day}/${date.month}/${date.year}'
                                                    : 'No date',
                                                style: TextStyle(
                                                  fontSize: isSmallScreen ? 10 : 11,
                                                  color: Colors.grey[500],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    SizedBox(width: isSmallScreen ? 4 : 8),

                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          isIncome ? '+' : '-',
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 11 : 14,
                                            fontWeight: FontWeight.bold,
                                            color: isIncome
                                                ? const Color(0xFF245C4C)
                                                : Colors.red[700],
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          _formatCurrency(amount),
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 11 : 14,
                                            fontWeight: FontWeight.bold,
                                            color: isIncome
                                                ? const Color(0xFF245C4C)
                                                : Colors.red[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
                    ),


                    if (_allTransactions.length > 0) ...[
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
                                builder: (context) => AddIncomePage(
                                  initialHouseId: _selectedHouseId,
                                ),
                              ),
                            );
                            if (result == true) {
                              print('[SALES PAGE] 🔄 Transaction added, refreshing data...');
                              print('[SALES PAGE] Current month: ${_months[_selectedMonth - 1]} $_selectedYear');
                              

                              if (mounted) {
                                setState(() {
                                  _isLoading = true;
                                });
                              }
                              

                              await _loadHarvestSales(); // Reload monthly data
                              await _loadAllTransactions(); // Reload all transactions for Laporan Keuangan
                              await _loadAnnualData(); // Reload annual data
                              
                              if (mounted) {
                                setState(() {
                                  _isLoading = false;
                                });
                                

                                ModernSnackBar.success(
                                  context,
                                  'Data berhasil dimuat ulang',
                                  duration: const Duration(seconds: 2),
                                );
                              }
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
                                builder: (context) => AddExpensePage(
                                  initialHouseId: _selectedHouseId,
                                ),
                              ),
                            );
                            if (result == true) {
                              print('[SALES PAGE] 🔄 Transaction added, refreshing data...');
                              print('[SALES PAGE] Current month: ${_months[_selectedMonth - 1]} $_selectedYear');
                              

                              if (mounted) {
                                setState(() {
                                  _isLoading = true;
                                });
                              }
                              

                              await _loadHarvestSales(); // Reload monthly data
                              await _loadAllTransactions(); // Reload all transactions for Laporan Keuangan
                              await _loadAnnualData(); // Reload annual data
                              
                              if (mounted) {
                                setState(() {
                                  _isLoading = false;
                                });
                                

                                ModernSnackBar.success(
                                  context,
                                  'Data berhasil dimuat ulang',
                                  duration: const Duration(seconds: 2),
                                );
                              }
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
