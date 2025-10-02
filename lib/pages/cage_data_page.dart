import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:swiftlead/pages/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swiftlead/services/house_services.dart';
import 'package:swiftlead/services/file_services.dart';
import 'package:swiftlead/utils/token_manager.dart';

class CageDataPage extends StatefulWidget {
  const CageDataPage({Key? key}) : super(key: key);

  @override
  State<CageDataPage> createState() => _CageDataPageState();
}

class _CageDataPageState extends State<CageDataPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _floorCountController = TextEditingController();
  final _descriptionController = TextEditingController();

  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  double width(BuildContext context) => MediaQuery.of(context).size.width;
  double height(BuildContext context) => MediaQuery.of(context).size.height;

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memilih gambar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _takePicture() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengambil foto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showImagePickerDialog() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pilih Sumber Gambar',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _takePicture();
                    },
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Color(0xFF245C4C),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.camera_alt,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Kamera'),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage();
                    },
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Color(0xFF245C4C),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.photo_library,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Galeri'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
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
        String? imageUrl;
        
        // Upload image first if selected
        if (_selectedImage != null) {
          try {
            final fileService = FileService();
            final imageUploadResponse = await fileService.uploadFile(
              token, 
              _selectedImage!,
              category: 'swiftlet_house',
              description: 'Kandang ${_nameController.text}',
            );
            
            if (imageUploadResponse['success'] == true) {
              imageUrl = imageUploadResponse['data']['file_url'];
            }
          } catch (e) {
            print('Error uploading image: $e');
            // Continue without image
          }
        }
        
        // Create house via API
        final houseService = HouseService();
        final payload = {
          'name': _nameController.text,
          'location': _locationController.text,
          'floor_count': int.parse(_floorCountController.text),
          'description': _descriptionController.text,
        };
        
        // Add image URL if uploaded successfully
        if (imageUrl != null) {
          payload['image_url'] = imageUrl;
        }
        
        final apiResponse = await houseService.create(token, payload);
        print('House created via API: $apiResponse');
        
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
    await prefs.setString('kandang_${kandangCount}_address', _locationController.text);
    await prefs.setInt('kandang_${kandangCount}_floors', int.parse(_floorCountController.text));
    await prefs.setString('kandang_${kandangCount}_description', _descriptionController.text);
    if (_selectedImage != null) {
      await prefs.setString('kandang_${kandangCount}_image', _selectedImage!.path);
    }
    
    // Update kandang count
    await prefs.setInt('kandang_count', kandangCount);

    // Also save in legacy format for backward compatibility
    await prefs.setString('cage_address', _locationController.text);
    await prefs.setInt('cage_floors', int.parse(_floorCountController.text));
    if (_selectedImage != null) {
      await prefs.setString('cage_image', _selectedImage!.path);
    }

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
        backgroundColor: Color(0xFF245C4C),
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
              Text(
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

              // Image Upload Section
              Text(
                'Foto Kandang',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF245C4C),
                ),
              ),

              const SizedBox(height: 12),

              GestureDetector(
                onTap: _showImagePickerDialog,
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.grey[300]!,
                      width: 2,
                      style: BorderStyle.solid,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[50],
                  ),
                  child: _selectedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            _selectedImage!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_a_photo,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Ketuk untuk menambah foto',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 24),

              // Name Field
              Text(
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
                    borderSide: BorderSide(color: Color(0xFF245C4C)),
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
              Text(
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
                    borderSide: BorderSide(color: Color(0xFF245C4C)),
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
              Text(
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
                    borderSide: BorderSide(color: Color(0xFF245C4C)),
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
              Text(
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
                    borderSide: BorderSide(color: Color(0xFF245C4C)),
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
                    backgroundColor: Color(0xFF245C4C),
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
