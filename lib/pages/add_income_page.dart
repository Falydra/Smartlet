import 'package:flutter/material.dart';
import 'package:swiftlead/services/transaction_service.dart';
import 'package:swiftlead/services/transaction_category_service.dart';
import 'package:swiftlead/services/house_services.dart';
import 'package:swiftlead/utils/token_manager.dart';

class AddIncomePage extends StatefulWidget {
  final Map<String, dynamic>? transaction; // Optional transaction for editing
  
  const AddIncomePage({super.key, this.transaction});

  @override
  State<AddIncomePage> createState() => _AddIncomePageState();
}

class _AddIncomePageState extends State<AddIncomePage> {
  final _formKey = GlobalKey<FormState>();
  final TransactionService _transactionService = TransactionService();
  final TransactionCategoryService _categoryService = TransactionCategoryService();
  final HouseService _houseService = HouseService();
  
  String? _authToken;
  bool _isLoading = false;
  
  // Form fields
  final TextEditingController _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  
  // Item list for invoice
  List<Map<String, dynamic>> _items = [];
  
  // Current item being added
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  
  // House selection
  List<dynamic> _houses = [];
  String? _selectedHouseId;

  // Category selection
  List<dynamic> _categories = [];
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    _authToken = await TokenManager.getToken();
    if (_authToken != null) {
      await Future.wait([
        _loadHouses(),
        _loadCategories(),
      ]);
    }
  }

  Future<void> _loadHouses() async {
    try {
      final houses = await _houseService.getAll(_authToken!);
      if (mounted) {
        setState(() {
          _houses = houses;
          if (_houses.isNotEmpty) {
            _selectedHouseId = _houses.first['id']?.toString();
          }
        });
      }
    } catch (e) {
      print('Error loading houses: $e');
    }
  }

  Future<void> _loadCategories() async {
    try {
      print('[CATEGORIES] Loading categories...');
      final categories = await _categoryService.getAll(_authToken!);
      print('[CATEGORIES] Received ${categories.length} categories');
      
      // Filter to only show income categories (those with "Penjualan" in name)
      final incomeCategories = categories.where((cat) {
        final name = (cat['name'] ?? '').toString().toLowerCase();
        return name.contains('penjualan');
      }).toList();
      
      print('[CATEGORIES] Filtered to ${incomeCategories.length} income categories');
      
      if (mounted) {
        setState(() {
          _categories = incomeCategories;
          // Auto-select first category if available and none selected
          if (_categories.isNotEmpty && _selectedCategoryId == null) {
            _selectedCategoryId = _categories.first['id']?.toString();
            print('[CATEGORIES] Auto-selected: $_selectedCategoryId');
          }
        });
      }
    } catch (e) {
      print('[CATEGORIES] Error loading categories: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat kategori: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _addItem() {
    if (_itemNameController.text.isEmpty || 
        _quantityController.text.isEmpty || 
        _priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap isi semua field item'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final quantity = int.tryParse(_quantityController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0.0;

    if (quantity <= 0 || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jumlah dan harga harus lebih dari 0'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _items.add({
        'name': _itemNameController.text,
        'quantity': quantity,
        'price': price,
        'subtotal': quantity * price,
      });
      
      // Clear fields
      _itemNameController.clear();
      _quantityController.clear();
      _priceController.clear();
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  double get _grandTotal {
    return _items.fold(0.0, (sum, item) => sum + (item['subtotal'] as double));
  }

  Future<void> _saveIncome() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Harap tambahkan minimal satu item'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = {
        'house_id': _selectedHouseId,
        'category_id': _selectedCategoryId,
        'type': 'income',
        'description': _descriptionController.text,
        'transaction_date': _selectedDate.toIso8601String(),
        'items': _items,
        'total_amount': _grandTotal,
      };

      final result = await _transactionService.createIncome(_authToken!, data);

      if (mounted) {
        setState(() => _isLoading = false);
        
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pendapatan berhasil ditambahkan'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        } else {
          // Check if it's a 500 error
          final statusCode = result['statusCode'];
          String errorMessage = result['message'] ?? 'Gagal menyimpan pendapatan';
          
          if (statusCode == 500) {
            errorMessage = 'Server error: Backend belum siap atau ada bug di server.\n\nData yang dikirim sudah benar. Hubungi developer backend untuk memperbaiki endpoint POST /api/v1/transactions';
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _itemNameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Tambah Pendapatan'),
        backgroundColor: const Color(0xFF245C4C),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF245C4C)))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // House Selection
                  const Text(
                    'Kandang',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF245C4C)),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedHouseId,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _houses.map((house) {
                      return DropdownMenuItem<String>(
                        value: house['id']?.toString(),
                        child: Text(house['name'] ?? 'Kandang ${house['id']}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedHouseId = value);
                    },
                    validator: (value) => value == null ? 'Pilih kandang' : null,
                  ),

                  const SizedBox(height: 16),

                  // Category Selection
                  const Text(
                    'Kategori',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF245C4C)),
                  ),
                  const SizedBox(height: 8),
                  _categories.isEmpty
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Memuat kategori...',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : DropdownButtonFormField<String>(
                        value: _selectedCategoryId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          hintText: 'Pilih kategori',
                        ),
                        items: _categories.map((category) {
                          return DropdownMenuItem<String>(
                            value: category['id']?.toString(),
                            child: Text(
                              category['name'] ?? 'Kategori ${category['id']}',
                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedCategoryId = value);
                        },
                        validator: (value) => value == null ? 'Pilih kategori' : null,
                      ),

                  const SizedBox(height: 16),

                  // Date Selection
                  const Text(
                    'Tanggal Transaksi',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF245C4C)),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _selectDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const Icon(Icons.calendar_today, color: Color(0xFF245C4C)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Description
                  const Text(
                    'Deskripsi',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF245C4C)),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      hintText: 'Contoh: Penjualan sarang walet grade A',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    maxLines: 2,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Deskripsi tidak boleh kosong';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  // Add Item Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF245C4C)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tambah Item',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF245C4C)),
                        ),
                        const SizedBox(height: 12),
                        
                        TextFormField(
                          controller: _itemNameController,
                          decoration: InputDecoration(
                            labelText: 'Nama Item',
                            hintText: 'Contoh: Sarang Walet Grade A',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _quantityController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Jumlah',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _priceController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Harga (Rp)',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _addItem,
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: const Text('Tambah Item', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF245C4C),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Items List
                  if (_items.isNotEmpty) ...[
                    const Text(
                      'Daftar Item',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF245C4C)),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        children: [
                          ..._items.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: index < _items.length - 1
                                      ? BorderSide(color: Colors.grey[200]!)
                                      : BorderSide.none,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['name'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${item['quantity']} × ${_formatCurrency(item['price'])}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          _formatCurrency(item['subtotal']),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF245C4C),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _removeItem(index),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7CA),
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Pendapatan',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _formatCurrency(_grandTotal),
                                  style: const TextStyle(
                                    fontSize: 18,
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
                  ],

                  const SizedBox(height: 32),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saveIncome,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF245C4C),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Simpan Pendapatan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
    );
  }
}
