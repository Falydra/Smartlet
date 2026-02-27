import 'package:flutter/material.dart';
import 'package:swiftlead/components/custom_bottom_navigation.dart';
import 'package:swiftlead/components/admin_bottom_navigation.dart';

import 'package:swiftlead/shared/theme.dart';
import 'package:swiftlead/services/auth_services.dart.dart';
import 'package:swiftlead/utils/token_manager.dart';

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
  bool _isLoading = true;
  bool _isAdmin = false;

  double width(BuildContext context) => MediaQuery.of(context).size.width;
  double height(BuildContext context) => MediaQuery.of(context).size.height;

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
          final ud = userData; // non-nullable alias for null-safety
          setState(() {
            _userName = ud['name'] ?? ud['full_name'] ?? ud['username'] ?? 'User';
            _userEmail = ud['email'] ?? ud['user_email'] ?? 'No email';
            _isAdmin = (ud['role']?.toString() == 'admin');
            _isLoading = false;
          });
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
                Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: AssetImage("assets/img/profile.jpg"),
                      fit: BoxFit.cover,
                    ),
                  ),
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
                  icon: const Icon(Icons.supervisor_account_outlined),
                  label: const Text(
                    "Teman",
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
                )
              ],
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
