import 'package:flutter/material.dart';
import 'package:swiftlead/services/rbw_service.dart';
import 'package:swiftlead/services/transaction_service.dart';
import 'package:swiftlead/utils/token_manager.dart';
import 'package:intl/intl.dart';

class AdminFinancePage extends StatefulWidget {
  const AdminFinancePage({super.key});

  @override
  State<AdminFinancePage> createState() => _AdminFinancePageState();
}

class _AdminFinancePageState extends State<AdminFinancePage> {
  final RbwService _rbwService = RbwService();
  final TransactionService _transactionService = TransactionService();
  String? _authToken;
  bool _isLoading = true;
  List<dynamic> _rbwList = [];
  List<dynamic> _transactions = [];
  String? _selectedRbwId;
  String? _selectedRbwName;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      _authToken = await TokenManager.getToken();
      
      if (_authToken != null) {
        final result = await _rbwService.listRbw(token: _authToken!);
        
        if (result['success'] == true) {
          setState(() {
            _rbwList = result['data'] ?? [];
            if (_rbwList.isNotEmpty && _selectedRbwId == null) {
              _selectedRbwId = _rbwList.first['id']?.toString();
              _selectedRbwName = _rbwList.first['name']?.toString();
            }
          });
          
          if (_selectedRbwId != null) {
            await _loadTransactions();
          }
        }
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTransactions() async {
    if (_selectedRbwId == null || _authToken == null) return;
    
    try {
      final result = await _transactionService.listTransactionsByRbw(
        token: _authToken!,
        rbwId: _selectedRbwId!,
        limit: 100,
      );
      
      if (result['success'] == true) {
        setState(() {
          _transactions = result['data'] ?? [];
        });
      }
    } catch (e) {
      print('Error loading transactions: $e');
    }
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _deleteTransaction(String transactionId) async {
    if (_authToken == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text('Are you sure you want to delete this transaction?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final result = await _transactionService.deleteTransaction(
          token: _authToken!,
          transactionId: transactionId,
        );
        
        if (result['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Transaction deleted successfully')),
            );
          }
          await _loadTransactions();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: ${result['message']}')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  void _showAddTransactionDialog() {
    Navigator.pushNamed(
      context,
      '/add-income',
      arguments: {'houseId': _selectedRbwId},
    ).then((_) => _loadTransactions());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacementNamed(context, '/admin-home'),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF245C4C)),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Finance Management',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF245C4C),
                    ),
                  ),
                  const SizedBox(height: 16),
                  

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedRbwId,
                        hint: const Text('Select RBW'),
                        items: _rbwList.map((rbw) {
                          final id = rbw['id']?.toString() ?? '';
                          final name = rbw['name']?.toString() ?? 'Unknown';
                          return DropdownMenuItem(
                            value: id,
                            child: Text(name),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedRbwId = value;
                            _selectedRbwName = _rbwList.firstWhere(
                              (rbw) => rbw['id']?.toString() == value,
                              orElse: () => {'name': 'Unknown'},
                            )['name']?.toString();
                          });
                          _loadTransactions();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _selectedRbwId != null ? _showAddTransactionDialog : null,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Transaction'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF245C4C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  

                  Text(
                    'Transactions: ${_transactions.length}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _transactions.isEmpty
                        ? const Center(
                            child: Text(
                              'No transactions found',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadTransactions,
                            child: ListView.builder(
                              itemCount: _transactions.length,
                              itemBuilder: (context, index) {
                                final transaction = _transactions[index];
                                final id = transaction['id']?.toString() ?? '';
                                final type = transaction['type']?.toString() ?? '';
                                final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
                                final description = transaction['description']?.toString() ?? '-';
                                final date = _formatDate(transaction['transaction_date']?.toString());
                                final isIncome = type == 'income';

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 2,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    leading: CircleAvatar(
                                      backgroundColor: isIncome
                                          ? Colors.green.withOpacity(0.2)
                                          : Colors.red.withOpacity(0.2),
                                      child: Icon(
                                        isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                                        color: isIncome ? Colors.green : Colors.red,
                                      ),
                                    ),
                                    title: Text(
                                      _formatCurrency(amount),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                        color: isIncome ? Colors.green[700] : Colors.red[700],
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text('Type: ${isIncome ? 'Income' : 'Expense'}'),
                                        Text('Description: $description'),
                                        Text('Date: $date'),
                                      ],
                                    ),
                                    isThreeLine: true,
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteTransaction(id),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
