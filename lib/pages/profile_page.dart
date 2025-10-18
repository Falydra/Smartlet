import 'package:flutter/material.dart';
import 'package:swiftlead/components/custom_bottom_navigation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:swiftlead/shared/theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:swiftlead/services/auth_services.dart.dart';
import 'package:swiftlead/utils/token_manager.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _apiAuth = AuthService();

  int _currentIndex = 4;
  String? _userName;
  String? _userEmail;
  bool _isLoading = true;

  double width(BuildContext context) => MediaQuery.of(context).size.width;
  double height(BuildContext context) => MediaQuery.of(context).size.height;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      // Try to get user data from TokenManager first
      final token = await TokenManager.getToken();
      if (token != null && token != 'firebase_user') {
        // API user
        final response = await _apiAuth.profile(token);
        if (response['success'] == true && response['data'] != null) {
          setState(() {
            _userName = response['data']['name'];
            _userEmail = response['data']['email'];
            _isLoading = false;
          });
          return;
        }
      }
    } catch (e) {
      print("Failed to load API user data: $e");
    }

    // Fallback to Firebase or TokenManager stored data
    final userName = await TokenManager.getUserName();
    final userEmail = await TokenManager.getUserEmail();
    final currentUser = _auth.currentUser;
    
    if (mounted) {
      setState(() {
        _userName = userName ?? currentUser?.displayName ?? 'User';
        _userEmail = userEmail ?? currentUser?.email ?? 'No email';
        _isLoading = false;
      });

    }
  }

  Future<void> _logout() async {
    bool confirmLogout = await _showLogoutConfirmDialog();
    if (!confirmLogout) return;

    try {
      // Try API logout first if user has API token
      final token = await TokenManager.getToken();
      if (token != null && token != 'firebase_user') {
        try {
          await _apiAuth.logout(token);
          print("API logout successful");
        } catch (e) {
          print("API logout failed: $e");
          // Continue with local logout even if API fails
        }
      }

      // Firebase logout
      await FirebaseAuth.instance.signOut();
      
      // Clear local storage
      await TokenManager.clearAuthData();
      
      if (!mounted) return;
      
      // Navigate to login page
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
            child: ListView(
              children: [
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: const Text(
                    "Toko Saya",
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
                    // Navigate to the edit profile page
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => EditProfilePage()),
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
      bottomNavigationBar: BottomNavigationBar(
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
                icon: Icons.electrical_services_sharp,
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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        setState(() {
          _nameController.text = userDoc['name'];
          _emailController.text = user.email ?? '';
        });
      }
    }
  }

  Future<void> _updateProfile() async {
    User? user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'name': _nameController.text,
        'email': _emailController.text,
      });
      user.updateEmail(_emailController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                await _updateProfile();
                Navigator.pop(context);
              },
              child: Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
