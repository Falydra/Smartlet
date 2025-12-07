import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:swiftlead/pages/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swiftlead/services/house_services.dart';
import 'package:swiftlead/utils/token_manager.dart';

class CageDataPage extends StatefulWidget {
  const CageDataPage({super.key});

  @override
  State<CageDataPage> createState() => _CageDataPageState();
}

class _CageDataPageState extends State<CageDataPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _locationController = TextEditingController();
  final _floorCountController = TextEditingController();
  final _descriptionController = TextEditingController();

  double? _selectedLatitude;
  double? _selectedLongitude;
  bool _isLoading = false;

  double width(BuildContext context) => MediaQuery.of(context).size.width;
  double height(BuildContext context) => MediaQuery.of(context).size.height;

  void _openMapPicker() async {
    // Open a full screen dialog with Google Map to select a location
    final LatLng? result = await Navigator.push<LatLng?>(
      context,
      MaterialPageRoute(builder: (context) => _MapPickerPage(initialPosition: LatLng(-6.200000, 106.816666))),
    );

    if (result != null) {
      setState(() {
        _selectedLatitude = result.latitude;
        _selectedLongitude = result.longitude;
      });
    }
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
        // Get authentication token
      final token = await TokenManager.getToken();
      
      if (token != null) {
        // Validate location selected
        if (_selectedLatitude == null || _selectedLongitude == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Silakan pilih lokasi kandang melalui peta terlebih dahulu'), backgroundColor: Colors.red),
          );
          setState(() { _isLoading = false; });
          return;
        }

        // Generate RBW code based on location string and current RBW count
        final houseService = HouseService();
        int nextId = 1;
        try {
          final existing = await houseService.getAll(token);
          nextId = (existing.length) + 1;
        } catch (e) {
          print('Failed to fetch existing RBW count: $e');
          nextId = DateTime.now().millisecondsSinceEpoch % 100000; // fallback random-ish id
        }

  // Use user-provided code if present, otherwise generate one
  String codeSource = _locationController.text.isNotEmpty ? _locationController.text : _nameController.text;
  final generatedCode = _generateRbwCode(codeSource, nextId);
  final rbwCode = _codeController.text.trim().isNotEmpty ? _codeController.text.trim() : generatedCode;

        // parse floor count safely (validator already checked, but be defensive)
        final parsedFloors = int.tryParse(_floorCountController.text.trim()) ?? 0;

        final payload = {
          'code': rbwCode,
          'name': _nameController.text,
          'address': _locationController.text,
          'latitude': _selectedLatitude,
          'longitude': _selectedLongitude,
          // API expects `total_floors` (not floor_count)
          'total_floors': parsedFloors,
          'description': _descriptionController.text,
        };

        final apiResponse = await houseService.create(token, payload);
        print('RBW created via API: $apiResponse');

        // If API returned an explicit error, show it and DO NOT save locally.
        if (apiResponse.containsKey('error')) {
          final err = apiResponse['error'];
          final message = (err is Map) ? (err['message'] ?? err['detail'] ?? err.toString()) : err.toString();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal membuat RBW: $message'), backgroundColor: Colors.red),
          );
          setState(() { _isLoading = false; });
          return; // stop here — do not save locally
        }

        // If API successful, also save locally for offline support
        if (apiResponse['success'] == true || apiResponse['data'] != null) {
          await _saveToLocalStorage();

          setState(() {
            _isLoading = false;
          });

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Data kandang berhasil disimpan!'),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate to home page
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
            (route) => false,
          );
          return;
        }
      }
      
  // Fallback to local storage only
      await _saveToLocalStorage();
      
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data kandang disimpan secara lokal!'),
          backgroundColor: Colors.orange,
        ),
      );

      // Navigate to home page
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
        (route) => false,
      );
      
    } catch (e) {
      print('Error saving cage data: $e');
      
      // Fallback to local storage on API error
      try {
        await _saveToLocalStorage();
        
        setState(() {
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data kandang disimpan secara lokal!'),
            backgroundColor: Colors.orange,
          ),
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
          (route) => false,
        );
      } catch (localError) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan data: $localError'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveToLocalStorage() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get current kandang count
    int kandangCount = prefs.getInt('kandang_count') ?? 0;
    
    // Increment count for new kandang
    kandangCount++;
    
    // Save new kandang data
    await prefs.setString('kandang_${kandangCount}_name', _nameController.text);
  await prefs.setString('kandang_${kandangCount}_code', _codeController.text);
    await prefs.setString('kandang_${kandangCount}_address', _locationController.text);
    await prefs.setInt('kandang_${kandangCount}_floors', int.parse(_floorCountController.text));
    await prefs.setString('kandang_${kandangCount}_description', _descriptionController.text);
    // No image saved locally (image input replaced with map picker)
    
    // Update kandang count
    await prefs.setInt('kandang_count', kandangCount);

    // Also save in legacy format for backward compatibility
    await prefs.setString('cage_address', _locationController.text);
    await prefs.setInt('cage_floors', int.parse(_floorCountController.text));
  await prefs.setString('cage_code', _codeController.text);
    // legacy image no longer used

    print('Cage data saved locally');
  }

  Future<void> _skipForNow() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get current kandang count
      int kandangCount = prefs.getInt('kandang_count') ?? 0;
      
      // Increment count for new empty kandang
      kandangCount++;
      
      // Save empty kandang data (empty name indicates incomplete data)
      await prefs.setString('kandang_${kandangCount}_name', '');
      await prefs.setString('kandang_${kandangCount}_address', '');
      await prefs.setInt('kandang_${kandangCount}_floors', 3); // Default floors
      await prefs.setString('kandang_${kandangCount}_description', '');
      // Don't save image path
      
      // Update kandang count
      await prefs.setInt('kandang_count', kandangCount);

      print('Empty cage data saved for kandang_$kandangCount');
      
      // Show message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data kandang dapat dilengkapi nanti'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      print('Error saving empty cage data: $e');
    }

    setState(() {
      _isLoading = false;
    });

    // Navigate to home page
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _locationController.dispose();
    _floorCountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Data Kandang'),
        backgroundColor: const Color(0xFF245C4C),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'Lengkapi Data Kandang Anda',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF245C4C),
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Isi informasi kandang burung walet Anda untuk mendapatkan layanan yang lebih optimal.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 32),

              // Location (pick on map)
              const Text(
                'Lokasi (Pilih di Peta)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF245C4C),
                ),
              ),

              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.grey[300]!,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[50],
                ),
                child: InkWell(
                  onTap: _openMapPicker,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedLatitude != null && _selectedLongitude != null
                                  ? 'Lat: ${_selectedLatitude!.toStringAsFixed(6)}, Lng: ${_selectedLongitude!.toStringAsFixed(6)}'
                                  : 'Belum memilih lokasi',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[800],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _openMapPicker,
                              icon: const Icon(Icons.map),
                              label: const Text('Pilih di Peta'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF245C4C),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Center(
                            child: _selectedLatitude == null
                                ? const Text('Tap "Pilih di Peta" untuk menentukan lokasi kandang')
                                : const Text('Lokasi terpilih ditampilkan di atas'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Code Field (optional)
              const Text(
                'Kode RBW (opsional)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF245C4C),
                ),
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _codeController,
                decoration: InputDecoration(
                  hintText: 'Masukkan kode RBW jika tersedia (mis. RBW-ABC-1)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF245C4C)),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  suffixIcon: Icon(Icons.confirmation_number, color: Colors.grey[400]),
                ),
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty && value.trim().length < 3) {
                    return 'Kode terlalu pendek';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Name Field
              const Text(
                'Nama Kandang',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF245C4C),
                ),
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Masukkan nama kandang (contoh: Kandang Walet Utara)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF245C4C)),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  suffixIcon: Icon(Icons.home_work, color: Colors.grey[400]),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nama kandang tidak boleh kosong';
                  }
                  if (value.trim().length < 3) {
                    return 'Nama terlalu pendek (minimal 3 karakter)';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Location Field
              const Text(
                'Lokasi Kandang',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF245C4C),
                ),
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _locationController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Masukkan alamat lengkap kandang...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF245C4C)),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  suffixIcon: Icon(Icons.location_on, color: Colors.grey[400]),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Lokasi kandang tidak boleh kosong';
                  }
                  if (value.trim().length < 10) {
                    return 'Lokasi terlalu pendek (minimal 10 karakter)';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Floor Count Field
              const Text(
                'Jumlah Lantai',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF245C4C),
                ),
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _floorCountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Masukkan jumlah lantai kandang',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF245C4C)),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  suffixIcon: Icon(Icons.layers, color: Colors.grey[400]),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Jumlah lantai tidak boleh kosong';
                  }
                  final number = int.tryParse(value.trim());
                  if (number == null) {
                    return 'Masukkan angka yang valid';
                  }
                  if (number < 1) {
                    return 'Jumlah lantai minimal 1';
                  }
                  if (number > 20) {
                    return 'Jumlah lantai maksimal 20';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),

              // Description Field
              const Text(
                'Deskripsi Kandang',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF245C4C),
                ),
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Deskripsi kandang (opsional): ukuran, fitur khusus, dll...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF245C4C)),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  suffixIcon: Icon(Icons.description, color: Colors.grey[400]),
                ),
                validator: (value) {
                  // Description is optional, so no validation required
                  return null;
                },
              ),

              const SizedBox(height: 40),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF245C4C),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Simpan Data',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Cancel Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: TextButton(
                  onPressed: _isLoading
                      ? null
                      : _skipForNow,
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: Text(
                    'Lewati untuk Sekarang',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper to generate RBW code: RBW-<3letters>-<id>
String _generateRbwCode(String source, int id) {
  final cleaned = source.replaceAll(RegExp(r'[^A-Za-z]'), '').toUpperCase();
  String first = 'X';
  String middle = 'X';
  String last = 'X';
  if (cleaned.isNotEmpty) {
    first = cleaned[0];
    last = cleaned[cleaned.length - 1];
    middle = cleaned[(cleaned.length - 1) ~/ 2];
  }
  final letters = (first + middle + last).padRight(3, 'X').substring(0,3);
  return 'RBW-$letters-$id';
}

class _MapPickerPage extends StatefulWidget {
  final LatLng initialPosition;
  const _MapPickerPage({required this.initialPosition});

  @override
  State<_MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<_MapPickerPage> {
  LatLng? _picked;
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Lokasi'),
        backgroundColor: const Color(0xFF245C4C),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, _picked);
            },
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          center: widget.initialPosition,
          zoom: 15,
          onTap: (tapPosition, point) {
            setState(() {
              _picked = LatLng(point.latitude, point.longitude);
            });
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: const ['a', 'b', 'c'],
          ),
          if (_picked != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _picked!,
                  width: 80,
                  height: 80,
                  builder: (ctx) => const Icon(Icons.location_on, color: Colors.red, size: 40),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
