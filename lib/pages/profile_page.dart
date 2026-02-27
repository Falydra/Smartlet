import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:swiftlead/components/custom_bottom_navigation.dart';
import 'package:swiftlead/components/admin_bottom_navigation.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:swiftlead/shared/theme.dart';
import 'package:swiftlead/services/auth_services.dart.dart';
import 'package:swiftlead/utils/token_manager.dart';
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
  String? _avatarUrl;
  bool _isLoading = true;
  bool _isAdmin = false;
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
            avatarUrl = 'https://api.swiftlead.fuadfakhruz.com$avatarUrl';
          }
          
          setState(() {
            _userName = ud['name'] ?? ud['full_name'] ?? ud['username'] ?? 'User';
            _userEmail = ud['email'] ?? ud['user_email'] ?? 'No email';
            _avatarUrl = avatarUrl;
            _authToken = token; // Ensure token is always fresh
            _isAdmin = (ud['role']?.toString() == 'admin');
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
    if (mounted) {
      setState(() {
        _userName = userName ?? 'User';
        _userEmail = userEmail ?? 'No email';
        _isAdmin = (userRole == 'admin');
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
        Uri.parse('https://api.swiftlead.fuadfakhruz.com/api/v1/uploads/avatar'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String avatarUrl = data['data']['url'];
        

        if (!avatarUrl.startsWith('http')) {
          avatarUrl = 'https://api.swiftlead.fuadfakhruz.com$avatarUrl';
        }
        
        print('Avatar URL received: $avatarUrl');
        

        final updateResponse = await http.patch(
          Uri.parse('https://api.swiftlead.fuadfakhruz.com/api/v1/users/me'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'avatar_url': avatarUrl}),
        );
        
        if (updateResponse.statusCode == 200) {

          await _cacheProfileImage(imageFile);
          
          setState(() {
            _avatarUrl = avatarUrl;
            _profileImage = imageFile; // Keep local file for display (storage is private)
            _authToken = token; // Ensure token is set for image loading
            _isUploadingImage = false;
          });
          print('Avatar URL set in state: $_avatarUrl');
          print('Auth token refreshed in state');
          print('⚠️  Using local cache - backend storage requires fix (enable public read or use pre-signed URLs)');
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Foto profil berhasil disimpan'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          throw Exception('Failed to update profile');
        }
      } else {
        throw Exception('Failed to upload image');
      }
    } catch (e) {
      setState(() => _isUploadingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengunggah foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto profil dihapus'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        throw Exception('Failed to delete avatar');
      }
    } catch (e) {
      setState(() => _isUploadingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickProfileImage() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
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
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Foto profil berhasil diperbarui'),
                        backgroundColor: Colors.green,
                      ),
                    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blue400,
      body: Stack(
        children: [
          SizedBox(
            width: width(context),
            height: height(context) * 0.35,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    GestureDetector(
                      onTap: _showImagePreview,
                      child: Container(
                        width: 96,
                        height: 96,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          image: DecorationImage(
                            image: _getProfileImageProvider(),
                            fit: BoxFit.cover,
                            onError: (exception, stackTrace) {
                              print('Error loading avatar image: $exception');
                              print('Avatar URL was: $_avatarUrl');
                            },
                          ),
                        ),
                        child: _isUploadingImage
                            ? Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withOpacity(0.5),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
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
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF245C4C),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10.0),
                if (_isLoading)
                  const CircularProgressIndicator(color: Colors.white)
                else ...[
                  Text(
                    _userName ?? 'User',
                    style: const TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 5.0),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 5.0,
                      horizontal: 20.0,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18.0),
                      color: blue300,
                    ),
                    child: Text(
                      _userEmail ?? 'No email',
                      style: const TextStyle(
                        fontSize: 16.0,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.only(top: 30, left: 10, right: 10),
            alignment: Alignment.centerLeft,
            margin: EdgeInsets.only(top: height(context) * 0.35),
            width: width(context),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20.0),
                topRight: Radius.circular(20.0),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  
                  TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.money_outlined),
                  label: const Text(
                    "Pendapatan",
                    style: TextStyle(color: Colors.black),
                  ),
                  style: TextButton.styleFrom(iconColor: Colors.black, alignment: Alignment.centerLeft),
                ),
                const Divider(
                  color: Color(0xff767676),
                  height: 0.3,
                ),
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.question_mark_outlined),
                  label: const Text(
                    "FAQ",
                    style: TextStyle(color: Colors.black),
                  ),
                  style: TextButton.styleFrom(iconColor: Colors.black, alignment: Alignment.centerLeft),
                ),
                const Divider(
                  color: Color(0xff767676),
                  height: 0.3,
                ),
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text(
                    "Tentang",
                    style: TextStyle(color: Colors.black),
                  ),
                  style: TextButton.styleFrom(iconColor: Colors.black, alignment: Alignment.centerLeft),
                ),
                const Divider(
                  color: Color(0xff767676),
                  height: 0.3,
                ),
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.info_outline),
                  label: const Text(
                    "Bantuan",
                    style: TextStyle(color: Colors.black),
                  ),
                  style: TextButton.styleFrom(iconColor: Colors.black, alignment: Alignment.centerLeft),
                ),
                const Divider(
                  color: Color(0xff767676),
                  height: 0.3,
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/reports-page');
                  },
                  icon: const Icon(Icons.summarize_outlined),
                  label: const Text(
                    "Laporan",
                    style: TextStyle(color: Colors.black),
                  ),
                  style: TextButton.styleFrom(iconColor: Colors.black, alignment: Alignment.centerLeft),
                ),
                const Divider(
                  color: Color(0xff767676),
                  height: 0.3,
                ),
                TextButton.icon(
                  onPressed: () async {

                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const EditProfilePage()),
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text(
                    "Edit Profil",
                    style: TextStyle(color: Colors.black),
                  ),
                  style: TextButton.styleFrom(iconColor: Colors.black, alignment: Alignment.centerLeft),
                ),
                const Divider(
                  color: Color(0xff767676),
                  height: 0.3,
                ),
                Container(
                  alignment: Alignment.bottomCenter,
                  child: ElevatedButton(
                    onPressed: _logout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.logout, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Logout', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 80), // Bottom padding for navigation bar
              ],
            ),
          ),
          ),
        ],
      ),
      bottomNavigationBar: _isAdmin
          ? const AdminBottomNavigation(currentIndex: 3)
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
                        Navigator.pushReplacementNamed(context, '/home-page');
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
                        Navigator.pushReplacementNamed(context, '/control-page');
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
                        Navigator.pushReplacementNamed(context, '/harvest/analysis');
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
                        Navigator.pushReplacementNamed(context, '/store-page');
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
                        Navigator.pushReplacementNamed(context, '/profile-page');
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
    _nameController.text = storedName ?? '';
    _emailController.text = storedEmail ?? '';
  }

  Future<void> _updateProfile() async {
    final token = await TokenManager.getToken();
    final payload = {
      'name': _nameController.text,
      'email': _emailController.text,
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
