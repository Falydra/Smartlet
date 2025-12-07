import 'package:flutter/material.dart';
import 'package:swiftlead/utils/token_manager.dart';
import 'package:swiftlead/services/transaction_service.dart';
import 'package:swiftlead/pages/add_income_page.dart';
import 'package:swiftlead/pages/add_expense_page.dart';

class TransactionHistoryPage extends StatefulWidget {
  final List<dynamic> transactions;
  final List<dynamic> houses;
  final String selectedMonth;
  final String selectedYear;

  const TransactionHistoryPage({
    super.key,
    required this.transactions,
    required this.houses,
    required this.selectedMonth,
    required this.selectedYear,
  });

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  final TransactionService _transactionService = TransactionService();
  late List<dynamic> _transactions;

  @override
  void initState() {
    super.initState();
    _transactions = List.from(widget.transactions);
  }

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  Future<void> _deleteTransaction(String transactionId, int index) async {
    try {
      final token = await TokenManager.getToken();
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session expired. Please login again.')),
          );
        }
        return;
      }

      final result = await _transactionService.delete(token, transactionId);
      
      if (mounted) {
        if (result['success'] == true) {
          setState(() {
            _transactions.removeAt(index);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transaksi berhasil dihapus'),
              backgroundColor: Colors.green,
            ),
          );
          // Return true to indicate data has changed
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal menghapus transaksi: ${result['message']}')),
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

  void _showDeleteConfirmation(String transactionId, int index, String description) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Transaksi'),
        content: Text('Apakah Anda yakin ingin menghapus transaksi "$description"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteTransaction(transactionId, index);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Future<void> _editTransaction(Map<String, dynamic> transaction) async {
    // Determine if it's income or expense
    final categoryName = (transaction['category_name']?.toString() ?? '').toLowerCase();
    final isIncome = categoryName.contains('penjualan');
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => isIncome 
            ? AddIncomePage(transaction: transaction)
            : AddExpensePage(transaction: transaction),
      ),
    );
    
    if (result == true && mounted) {
      // Return true to indicate data has changed
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
        backgroundColor: const Color(0xFF245C4C),
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: Column(
        children: [
          // Header Info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Periode: ${widget.selectedMonth} ${widget.selectedYear}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF245C4C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total ${_transactions.length} transaksi',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF245C4C).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.receipt_long,
                        size: 16,
                        color: Color(0xFF245C4C),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_transactions.length}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF245C4C),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Transaction List
          Expanded(
            child: _transactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Belum ada transaksi',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
                      final transaction = _transactions[index];

                      // Get category name - API returns it directly as 'category_name'
                      final categoryName = (transaction['category_name']?.toString() ??
                          transaction['category']?['name']?.toString() ??
                          '').toLowerCase();
                      final isIncome = categoryName.contains('penjualan');

                      final amount = (transaction['total'] as num?)?.toDouble() ??
                          (transaction['total_amount'] as num?)?.toDouble() ??
                          0.0;
                      final date = transaction['date'] != null
                          ? DateTime.tryParse(transaction['date'])
                          : (transaction['transaction_date'] != null
                              ? DateTime.tryParse(transaction['transaction_date'])
                              : null);
                      final categoryNameForDisplay =
                          transaction['category_name']?.toString() ??
                              transaction['category']?['name']?.toString() ??
                              'Tanpa Kategori';

                      // Get house name - API returns it directly as 'rbw_name'
                      String houseName = transaction['rbw_name']?.toString() ??
                          transaction['house_name']?.toString() ??
                          '';

                      // If not in transaction, try to match from houses list
                      if (houseName.isEmpty) {
                        final transactionHouseId =
                            transaction['rbw_id']?.toString() ??
                                transaction['house_id']?.toString();
                        final house = widget.houses.firstWhere(
                          (h) => h['id']?.toString() == transactionHouseId,
                          orElse: () => {'name': 'Unknown'},
                        );
                        houseName = house['name']?.toString() ?? 'Unknown';
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // Icon
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isIncome
                                      ? const Color(0xFF245C4C).withOpacity(0.1)
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

                              // Transaction Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      transaction['note'] ??
                                          transaction['description'] ??
                                          'Transaksi',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(Icons.label_outline,
                                            size: 14, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            categoryNameForDisplay,
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
                                        Icon(Icons.home_outlined,
                                            size: 14, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Expanded(
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
                                            size: 14, color: Colors.grey[600]),
                                        const SizedBox(width: 4),
                                        Text(
                                          date != null
                                              ? '${date.day}/${date.month}/${date.year}'
                                              : 'No date',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Amount
                              Column(
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
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatCurrency(amount),
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isIncome
                                          ? const Color(0xFF245C4C)
                                          : Colors.red[700],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // Edit and Delete buttons
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Edit button
                                      InkWell(
                                        onTap: () => _editTransaction(transaction),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.blue[50],
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Icon(
                                            Icons.edit,
                                            size: 16,
                                            color: Colors.blue[700],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Delete button
                                      InkWell(
                                        onTap: () => _showDeleteConfirmation(
                                          transaction['id']?.toString() ?? '',
                                          index,
                                          transaction['note'] ?? transaction['description'] ?? 'Transaksi',
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.red[50],
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Icon(
                                            Icons.delete,
                                            size: 16,
                                            color: Colors.red[700],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
