import 'package:flutter/material.dart';
import 'package:swiftlead/services/transaction_service.dart';
import 'package:swiftlead/services/transaction_category_service.dart';
import 'package:swiftlead/services/house_services.dart';
import 'package:swiftlead/utils/token_manager.dart';
import 'package:swiftlead/utils/modern_snackbar.dart';
import 'package:swiftlead/utils/currency_input_formatter.dart';

class AddIncomePage extends StatefulWidget {
  final Map<String, dynamic>? transaction; // Optional transaction for editing
  final String? initialHouseId; // Pre-selected house ID from parent page
  
  const AddIncomePage({super.key, this.transaction, this.initialHouseId});

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
  

  final TextEditingController _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  

  List<Map<String, dynamic>> _items = [];
  

  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _totalPriceController = TextEditingController();
  

  List<dynamic> _houses = [];
  String? _selectedHouseId;


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

          if (widget.initialHouseId != null) {
            _selectedHouseId = widget.initialHouseId;
            print('[ADD INCOME] Using pre-selected house: $_selectedHouseId');
          } else if (_houses.isNotEmpty) {
            _selectedHouseId = _houses.first['id']?.toString();
            print('[ADD INCOME] Auto-selecting first house: $_selectedHouseId');
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
      

      final incomeCategories = categories.where((cat) {
        final name = (cat['name'] ?? '').toString().toLowerCase();
        return name.contains('penjualan');
      }).toList();
      
      print('[CATEGORIES] Filtered to ${incomeCategories.length} income categories');
      
      if (mounted) {
        setState(() {
          _categories = incomeCategories;

          if (_categories.isNotEmpty && _selectedCategoryId == null) {
            _selectedCategoryId = _categories.first['id']?.toString();
            print('[CATEGORIES] Auto-selected: $_selectedCategoryId');
          }
        });
      }
    } catch (e) {
      print('[CATEGORIES] Error loading categories: $e');
      if (mounted) {
        ModernSnackBar.error(context, 'Gagal memuat kategori');
      }
    }
  }

  void _addItem() {
    if (_itemNameController.text.isEmpty || 
        _quantityController.text.isEmpty || 
        _totalPriceController.text.isEmpty) {
      ModernSnackBar.warning(context, 'Harap isi semua field item');
      return;
    }

    final quantity = int.tryParse(_quantityController.text) ?? 0;
    final total = CurrencyHelper.parse(_totalPriceController.text);

    if (quantity <= 0 || total <= 0) {
      ModernSnackBar.warning(context, 'Jumlah dan total harga harus lebih dari 0');
      return;
    }

    setState(() {
      _items.add({
        'name': _itemNameController.text,
        'quantity': quantity,
        'subtotal': total,
      });
      

      _itemNameController.clear();
      _quantityController.clear();
      _totalPriceController.clear();
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
      ModernSnackBar.warning(context, 'Harap tambahkan minimal satu item');
      return;
    }

    setState(() => _isLoading = true);

    try {

      if (_selectedHouseId == null || _selectedHouseId!.isEmpty) {
        throw Exception('Rumah walet belum dipilih');
      }
      if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
        throw Exception('Kategori belum dipilih');
      }


      final selectedHouse = _houses.firstWhere(
        (h) => h['id']?.toString() == _selectedHouseId,
        orElse: () => {'name': 'Unknown'},
      );
      print('[ADD INCOME] 💰 Saving income transaction:');
      print('[ADD INCOME]   - House ID: $_selectedHouseId');
      print('[ADD INCOME]   - House Name: ${selectedHouse['name']}');
      print('[ADD INCOME]   - Category ID: $_selectedCategoryId');
      print('[ADD INCOME]   - Amount: $_grandTotal');
      print('[ADD INCOME]   - Date: $_selectedDate');


      final result = await _transactionService.createIncome(
        token: _authToken!,
        rbwId: _selectedHouseId!,
        categoryId: _selectedCategoryId!,
        amount: _grandTotal,
        description: _descriptionController.text.isNotEmpty 
            ? _descriptionController.text 
            : null,
        transactionDate: _selectedDate,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        
        if (result['success'] == true) {
          ModernSnackBar.success(context, 'Pendapatan berhasil ditambahkan');
          Navigator.pop(context, true);
        } else {

          final statusCode = result['statusCode'];
          String errorMessage = result['message'] ?? 'Gagal menyimpan pendapatan';
          
          switch (statusCode) {
            case 400:
              errorMessage = 'Data tidak valid: $errorMessage';
              break;
            case 401:
              errorMessage = 'Sesi berakhir. Silakan login kembali';
              break;
            case 404:
              errorMessage = 'Rumah walet atau kategori tidak ditemukan';
              break;
            case 422:
              errorMessage = 'Validasi gagal: $errorMessage';
              break;
            case 500:
              errorMessage = 'Server error. Hubungi administrator';
              break;
          }
          
          ModernSnackBar.error(
            context,
            errorMessage,
            duration: const Duration(seconds: 4),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ModernSnackBar.error(context, 'Gagal menyimpan pendapatan');
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
    _totalPriceController.dispose();
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

                  if (_selectedHouseId != null && _houses.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF245C4C).withOpacity(0.1),
                        border: Border.all(color: const Color(0xFF245C4C), width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.home, color: Color(0xFF245C4C), size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Transaksi akan ditambahkan ke:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF245C4C),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _houses.firstWhere(
                                    (h) => h['id']?.toString() == _selectedHouseId,
                                    orElse: () => {'name': 'Unknown'},
                                  )['name'] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF245C4C),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.check_circle, color: Color(0xFF245C4C), size: 24),
                        ],
                      ),
                    ),

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
                              flex: 1,
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
                              flex: 2,
                              child: TextFormField(
                                controller: _totalPriceController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [CurrencyInputFormatter()],
                                decoration: InputDecoration(
                                  labelText: 'Total Harga (Rp)',
                                  hintText: 'Masukkan total harga',
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
                                          'Qty: ${item['quantity']}',
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
