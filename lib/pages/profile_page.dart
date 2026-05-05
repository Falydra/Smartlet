import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:swiftlead/components/custom_bottom_navigation.dart';
import 'package:swiftlead/components/admin_bottom_navigation.dart';
import 'package:swiftlead/components/technician_bottom_navigation.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:swiftlead/shared/theme.dart';
import 'package:swiftlead/services/auth_services.dart';
import 'package:swiftlead/utils/modern_snackbar.dart';
import 'package:swiftlead/utils/token_manager.dart';
import 'package:swiftlead/services/api_constants.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;


class AuthenticatedNetworkImage extends ImageProvider<AuthenticatedNetworkImage> {
  final String url;
  final String? token;
  final double scale;

  const AuthenticatedNetworkImage(this.url, {this.token, this.scale = 1.0});

  @override
  Future<AuthenticatedNetworkImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<AuthenticatedNetworkImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(AuthenticatedNetworkImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: key.scale,
      informationCollector: () sync* {
        yield ErrorDescription('Image URL: $url');
      },
    );
  }

  Future<ui.Codec> _loadAsync(AuthenticatedNetworkImage key, ImageDecoderCallback decode) async {
    try {
      final Uri resolved = Uri.parse(key.url);
      final Map<String, String> headers = {};
      
      print('AuthenticatedNetworkImage: Loading image from $resolved');
      print('AuthenticatedNetworkImage: Token available: ${key.token != null}');
      

      http.Response response = await http.get(resolved);
      print('AuthenticatedNetworkImage: Public access status: ${response.statusCode}');
      

      if (response.statusCode == 403 || response.statusCode == 401) {
        print('AuthenticatedNetworkImage: Trying with Authorization header...');
        if (key.token != null) {
          headers['Authorization'] = 'Bearer ${key.token}';
        }
        response = await http.get(resolved, headers: headers);
        print('AuthenticatedNetworkImage: Auth access status: ${response.statusCode}');
      }
      
      if (response.statusCode != 200) {
        print('AuthenticatedNetworkImage: WARNING - Storage requires backend fix (pre-signed URLs or public read)');
        throw NetworkImageLoadException(
          statusCode: response.statusCode,
          uri: resolved,
        );
      }

      final Uint8List bytes = response.bodyBytes;
      if (bytes.lengthInBytes == 0) {
        throw Exception('Image is empty');
      }

      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      return decode(buffer);
    } catch (e) {
      throw Exception('Failed to load image: $e');
    }
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is AuthenticatedNetworkImage
        && other.url == url
        && other.token == token
        && other.scale == scale;
  }

  @override
  int get hashCode => Object.hash(url, token, scale);

  @override
  String toString() => 'AuthenticatedNetworkImage("$url", scale: $scale)';
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _apiAuth = AuthService();

  int _currentIndex = 4;
  String? _userName;
  String? _userEmail;
  String? _userPhone;
  String? _avatarUrl;
  bool _isLoading = true;
  bool _isAdmin = false;
  bool _isTechnician = false;
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingImage = false;
  String? _authToken;

  double width(BuildContext context) => MediaQuery.of(context).size.width;
  double height(BuildContext context) => MediaQuery.of(context).size.height;

  @override
  void initState() {
    super.initState();
    _loadTokenAndUserData();
  }

  Future<void> _loadTokenAndUserData() async {
    final token = await TokenManager.getToken();
    print('Token loaded: ${token != null ? "YES (length: ${token?.length})" : "NO"}');
    setState(() {
      _authToken = token;
    });
    print('Token set in state: $_authToken');
    await _loadUserData();
    await _loadCachedProfileImage(); // Load cached image if exists
  }

  Future<void> _loadCachedProfileImage() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cachedImagePath = path.join(dir.path, 'cached_profile_avatar.jpg');
      final cachedFile = File(cachedImagePath);
      
      if (await cachedFile.exists()) {
        setState(() {
          _profileImage = cachedFile;
        });
        print('✓ Loaded cached profile image from: $cachedImagePath');
      }
    } catch (e) {
      print('Failed to load cached profile image: $e');
    }
  }

  Future<void> _cacheProfileImage(File imageFile) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cachedImagePath = path.join(dir.path, 'cached_profile_avatar.jpg');
      await imageFile.copy(cachedImagePath);
      print('✓ Cached profile image to: $cachedImagePath');
    } catch (e) {
      print('Failed to cache profile image: $e');
    }
  }

  Future<void> _loadUserData() async {


    final token = await TokenManager.getToken();
    if (token != null && token != 'firebase_user') {
      try {
        final Map<String, dynamic> response = await _apiAuth.profile(token);
        Map<String, dynamic>? userData;

        if (response['success'] == true && response['data'] is Map) {
          userData = Map<String, dynamic>.from(response['data']);
        } else if (response['data'] is Map) {
          userData = Map<String, dynamic>.from(response['data']);
        } else if (response['user'] is Map) {
          userData = Map<String, dynamic>.from(response['user']);
        } else if (response.containsKey('name') || response.containsKey('email')) {
          userData = Map<String, dynamic>.from(response);
        }

        if (userData != null) {
          final ud = userData; // non-nullable alias for null-safety
          String? avatarUrl = ud['avatar_url'];
          

          if (avatarUrl != null && !avatarUrl.startsWith('http')) {
            try {
              final urlResponse = await http.get(
                Uri.parse('${ApiConstants.baseUrl}/api/v1/files/url?path=$avatarUrl'),
                headers: {'Authorization': 'Bearer $token'},
              );
              if (urlResponse.statusCode == 200) {
                final urlData = jsonDecode(urlResponse.body);
                avatarUrl = urlData['url'];
              }
            } catch (e) {
              print('Failed to get presigned URL for avatar: $e');
              // Fallback to old hardcoded URL just in case, but using baseUrl
              avatarUrl = '${ApiConstants.baseUrl}/$avatarUrl';
            }
          }
          
          setState(() {
            _userName = ud['name'] ?? ud['full_name'] ?? ud['username'] ?? 'User';
            _userEmail = ud['email'] ?? ud['user_email'] ?? 'No email';
            _userPhone = ud['phone'] ?? ud['user_phone'] ?? '';
            _avatarUrl = avatarUrl;
            _authToken = token; // Ensure token is always fresh
            _isAdmin = (ud['role']?.toString() == 'admin');
            _isTechnician = (ud['role']?.toString() == 'technician');
            _isLoading = false;
          });
          print('Profile loaded. Avatar URL: $_avatarUrl');
          print('Auth token updated in _loadUserData');
          return;
        }
      } catch (e) {
        print('Failed to load profile from API: $e');
      }
    }


    final userName = await TokenManager.getUserName();
    final userEmail = await TokenManager.getUserEmail();
    final userRole = await TokenManager.getUserRole();
    final userPhone = await TokenManager.getUserPhone();
    if (mounted) {
      setState(() {
        _userName = userName ?? 'User';
        _userEmail = userEmail ?? 'No email';
        _userPhone = userPhone ?? '';
        _isAdmin = (userRole == 'admin');
        _isTechnician = (userRole == 'technician');
        _isLoading = false;
      });
    }
  }

  ImageProvider _getProfileImageProvider() {
    if (_profileImage != null) {
      print('Using FileImage for profile image');
      return FileImage(_profileImage!);
    } else if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      print('Using AuthenticatedNetworkImage for: $_avatarUrl');
      print('Token available for image: ${_authToken != null}');
      return AuthenticatedNetworkImage(_avatarUrl!, token: _authToken);
    } else {
      print('Using default AssetImage for profile');
      return const AssetImage("assets/img/profile.jpg");
    }
  }

  Future<void> _logout() async {
    bool confirmLogout = await _showLogoutConfirmDialog();
    if (!confirmLogout) return;

    try {


      final token = await TokenManager.getToken();
      if (token != null && token != 'firebase_user') {
        print("Logging out API user");
      }


      await TokenManager.clearAuthData();

      if (!mounted) return;


      Navigator.pushReplacementNamed(context, '/login-page');
      
    } catch (e) {
      print("Logout error: $e");
      _showErrorDialog("Gagal logout. Coba lagi.");
    }
  }

  Future<bool> _showLogoutConfirmDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Konfirmasi Logout"),
        content: const Text("Apakah Anda yakin ingin keluar dari akun?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Error"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showImagePreview() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: _getProfileImageProvider(),
                        fit: BoxFit.contain,
                        onError: (exception, stackTrace) {
                          print('Error loading preview image: $exception');
                        },
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 32),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _uploadImageToServer(File imageFile) async {
    setState(() => _isUploadingImage = true);
    
    try {
      final token = await TokenManager.getToken();
      if (token == null) throw Exception('No authentication token');
      

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConstants.baseUrl}/api/v1/users/me/avatar'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('avatar', imageFile.path));
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        String avatarUrl = data['file_url'] ?? '';
        

        print('Avatar upload successful. New URL: $avatarUrl');
        

        await _cacheProfileImage(imageFile);
        
        setState(() {
          _avatarUrl = avatarUrl;
          _profileImage = imageFile;
          _authToken = token;
          _isUploadingImage = false;
        });
        
        if (mounted) {
          ModernSnackBar.success(context, 'Foto profil berhasil diperbarui secara permanen');
        }
      } else {
        print('Upload failed with status: ${response.statusCode}');
        throw Exception('Gagal mengunggah foto');
      }
    } catch (e) {
      setState(() => _isUploadingImage = false);
      if (mounted) {
        ModernSnackBar.error(context, 'Gagal mengunggah foto: $e');
      }
    }
  }

  Future<void> _deleteProfileImage() async {
    setState(() => _isUploadingImage = true);
    
    try {
      final token = await TokenManager.getToken();
      if (token == null) throw Exception('No authentication token');
      

      final response = await http.patch(
        Uri.parse('https://api.swiftlead.fuadfakhruz.com/api/v1/users/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'avatar_url': null}),
      );
      
      if (response.statusCode == 200) {

        try {
          final dir = await getApplicationDocumentsDirectory();
          final cachedImagePath = path.join(dir.path, 'cached_profile_avatar.jpg');
          final cachedFile = File(cachedImagePath);
          if (await cachedFile.exists()) {
            await cachedFile.delete();
            print('✓ Deleted cached profile image');
          }
        } catch (e) {
          print('Failed to delete cached image: $e');
        }
        
        setState(() {
          _avatarUrl = null;
          _profileImage = null;
          _isUploadingImage = false;
        });
        
        if (mounted) {
          ModernSnackBar.warning(context, 'Foto profil dihapus');
        }
      } else {
        throw Exception('Failed to delete avatar');
      }
    } catch (e) {
      setState(() => _isUploadingImage = false);
      if (mounted) {
        ModernSnackBar.error(context, 'Gagal menghapus foto: $e');
      }
    }
  }

  Future<void> _pickProfileImage() async {
    
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bottomSheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Ambil Foto'),
                onTap: () async {
                  Navigator.pop(bottomSheetContext);
                  final XFile? image = await _picker.pickImage(
                    source: ImageSource.camera,
                    maxWidth: 512,
                    maxHeight: 512,
                    imageQuality: 85,
                  );
                  if (image != null && mounted) {
                    setState(() {
                      _profileImage = File(image.path);
                    });
                    ModernSnackBar.success(context, 'Foto profil berhasil diperbarui');
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Pilih dari Galeri'),
                onTap: () async {
                  Navigator.pop(bottomSheetContext);
                  final XFile? image = await _picker.pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 512,
                    maxHeight: 512,
                    imageQuality: 85,
                  );
                  if (image != null && mounted) {
                    setState(() {
                      _profileImage = File(image.path);
                    });

                    await _uploadImageToServer(File(image.path));
                  }
                },
              ),
              if (_avatarUrl != null || _profileImage != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Hapus Foto', style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    Navigator.pop(bottomSheetContext);
                    if (mounted) {
                      await _deleteProfileImage();
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuSection() {
    return Column(
      children: [
        _buildMenuItem(
          icon: Icons.edit_outlined,
          title: "Edit Profil",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EditProfilePage()),
            );
          },
        ),
        _buildMenuItem(
          icon: Icons.summarize_outlined,
          title: "Laporan",
          onTap: () {
            Navigator.pushNamed(context, '/reports-page');
          },
        ),
        _buildMenuItem(
          icon: Icons.money_outlined,
          title: "Pendapatan",
          onTap: () {},
        ),
        _buildMenuItem(
          icon: Icons.question_mark_outlined,
          title: "FAQ",
          onTap: () {},
        ),
        _buildMenuItem(
          icon: Icons.info_outline,
          title: "Bantuan",
          onTap: () {},
        ),
        _buildMenuItem(
          icon: Icons.fact_check_outlined,
          title: "Tentang Aplikasi",
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF245C4C).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF245C4C)),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Profil Saya",
          style: TextStyle(
            color: Color(0xFF245C4C),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF245C4C), Color(0xFF2d7a5f)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF245C4C).withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: _showImagePreview,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            image: DecorationImage(
                              image: _getProfileImageProvider(),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: _isUploadingImage
                              ? Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black.withOpacity(0.5),
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(color: Colors.white),
                                  ),
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickProfileImage,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, color: Color(0xFF245C4C), size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const CircularProgressIndicator(color: Colors.white)
                  else ...[
                    Text(
                      _userName ?? 'User',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _userEmail ?? 'No email',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    if (_userPhone != null && _userPhone!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _userPhone!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Menu Section
            _buildMenuSection(),

            const SizedBox(height: 24),

            // Logout Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text(
                    "Keluar Akun",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: _isAdmin
          ? const AdminBottomNavigation(currentIndex: 3)
          : _isTechnician
          ? const TechnicianBottomNavigation(currentIndex: 3)
          : BottomNavigationBar(
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
                        Navigator.pushNamed(context, '/home-page');
                        setState(() {
                          _currentIndex = 0;
                        });
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
                        Navigator.pushNamed(context, '/control-page');
                        setState(() {
                          _currentIndex = 1;
                        });
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
                        Navigator.pushNamed(context, '/harvest/analysis');
                        setState(() {
                          _currentIndex = 2;
                        });
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
                        Navigator.pushNamed(context, '/store-page');
                        setState(() {
                          _currentIndex = 3;
                        });
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
                        Navigator.pushNamed(context, '/profile-page');
                        setState(() {
                          _currentIndex = 4;
                        });
                      },
                    ),
                    label: ''),
              ],
            ),
    );
  }
}

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final AuthService _apiAuth = AuthService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  Future<void> _loadUserData() async {

    final token = await TokenManager.getToken();
    if (token != null && token != 'firebase_user') {
      try {
        final Map<String, dynamic> response = await _apiAuth.profile(token);
        Map<String, dynamic>? userData;

        if (response['success'] == true && response['data'] is Map) {
          userData = Map<String, dynamic>.from(response['data']);
        } else if (response['data'] is Map) {
          userData = Map<String, dynamic>.from(response['data']);
        } else if (response['user'] is Map) {
          userData = Map<String, dynamic>.from(response['user']);
        } else if (response.containsKey('name') || response.containsKey('email')) {
          userData = Map<String, dynamic>.from(response);
        }

        if (userData != null) {
          final ud = userData;
          _nameController.text = ud['name'] ?? ud['full_name'] ?? '';
          _emailController.text = ud['email'] ?? ud['user_email'] ?? '';
          return;
        }
      } catch (e) {
        print('API profile fetch failed: $e');
      }
    }


    final storedName = await TokenManager.getUserName();
    final storedEmail = await TokenManager.getUserEmail();
    final storedPhone = await TokenManager.getUserPhone();
    _nameController.text = storedName ?? '';
    _emailController.text = storedEmail ?? '';
    _phoneController.text = storedPhone ?? '';
  }

  Future<void> _updateProfile() async {
    final token = await TokenManager.getToken();
    final payload = {
      'name': _nameController.text,
      'email': _emailController.text,
      'phone': _phoneController.text,
    };

    if (token != null && token != 'firebase_user') {
      try {
        await _apiAuth.updateProfile(
          token: token,
          name: payload['name'],
          phone: payload['phone'],
        );
      } catch (e) {
        print('API update profile failed: $e');
      }
    }


    final storedToken = await TokenManager.getToken();
    final storedUserId = await TokenManager.getUserId();
    if (storedToken != null && storedUserId != null) {
      await TokenManager.saveAuthData(
        token: storedToken,
        userId: storedUserId,
        userName: _nameController.text,
        userEmail: _emailController.text,
        userPhone: _phoneController.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await _updateProfile();
                Navigator.pop(context);
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
