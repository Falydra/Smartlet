import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:swiftlead/auth/firebase_auth_services.dart';
import 'package:swiftlead/pages/login_page.dart';
import 'package:swiftlead/services/auth_services.dart.dart';
import 'package:swiftlead/utils/token_manager.dart';


class RegisterPage extends StatefulWidget {
  final TextEditingController? controller;

  const RegisterPage({Key? key, required this.controller}) : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}


class _RegisterPageState extends State<RegisterPage> {

  final FirebaseAuthService _auth = FirebaseAuthService();
  final AuthService _apiAuth = AuthService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isLoading = false;


  double width(BuildContext context) => MediaQuery.of(context).size.width;
  double height(BuildContext context) => MediaQuery.of(context).size.height;

  @override
  // Menghindari memori bocor
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffffffff),
      body: Column(
        children: [
          Container(
            margin: EdgeInsets.only(top: width(context) * 0.25),
            // decoration: BoxDecoration(border: Border.all(width: 2)),
            width: width(context) * 0.375,
            child: const Image(
              image: AssetImage("assets/img/logo2.png"),
              fit: BoxFit.cover,
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                  width(context) * 0.08, 5, width(context) * 0.08, 0),
              children: [
                const Text(
                  "Daftarkan Akun anda",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Color(0xff000744)),
                ),
                const SizedBox(
                  height: 10,
                ),

                // name
                const Text(
                  "Nama Lengkap",
                  textAlign: TextAlign.left,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Color(0xff0010A2)),
                ),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(
                                0xff0010A2)) // Ganti dengan warna yang diinginkan
                        ),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(
                                0xff0010A2)) // Ganti dengan warna yang diinginkan
                        ),
                    hintText: 'Nama Lengkap',
                    hintStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                        color: Color(0xff545FC1)),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 15, horizontal: 18),
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),

                // email
                const Text(
                  "Email",
                  textAlign: TextAlign.left,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Color(0xff0010A2)),
                ),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(
                                0xff0010A2)) // Ganti dengan warna yang diinginkan
                        ),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(
                                0xff0010A2)) // Ganti dengan warna yang diinginkan
                        ),
                    hintText: 'Email',
                    hintStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                        color: Color(0xff545FC1)),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 15, horizontal: 18),
                  ),
                ),
                // email
                const SizedBox(
                  height: 10,
                ),
                // password
                const Text(
                  "Password",
                  textAlign: TextAlign.left,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Color(0xff0010A2)),
                ),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(
                                0xff0010A2)) // Ganti dengan warna yang diinginkan
                        ),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(
                                0xff0010A2)) // Ganti dengan warna yang diinginkan
                        ),
                    hintText: 'Password',
                    hintStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                        color: Color(0xff545FC1)),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 15, horizontal: 18),
                  ),
                ),
                // password
                // Konfirmasi password
                const SizedBox(
                  height: 10,
                ),
                // password
                const Text(
                  "Konfirmasi Password",
                  textAlign: TextAlign.left,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Color(0xff0010A2)),
                ),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(
                                0xff0010A2)) // Ganti dengan warna yang diinginkan
                        ),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(
                                0xff0010A2)) // Ganti dengan warna yang diinginkan
                        ),
                    hintText: 'Konfirmasi Password',
                    hintStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                        color: Color(0xff545FC1)),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 15, horizontal: 18),
                  ),
                ),
                // password
                const SizedBox(
                  height: 20,
                ),
                ElevatedButton(
                    onPressed: _isLoading ? null : () {
                      _signup();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      backgroundColor:
                          const Color(0xFF0010A2), // Background color
                      foregroundColor: Colors.white,
                      minimumSize: Size(width(context) * 0.75, height(context
                        ) * 0.075) // Text color
                    ),
                    child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "Daftar",
                            style:
                                TextStyle(fontSize: 20, fontWeight: FontWeight.w500, fontFamily: "TT Norms"),
                          )),
                    const SizedBox(
                      height: 5,
                    ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Sudah punya akun? ", style: TextStyle(color: Color(0xff000744), fontSize: 16, fontWeight: FontWeight.w500),),
                    TextButton(
                      onPressed: () {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (context) {
                          return LoginPage(
                            controller: TextEditingController(),
                          );
                        }));
                        // Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero),
                      child: const Text("Klik Disini",
                          style: TextStyle(
                              color: Color(0xff545FC1),
                              fontSize: 16,
                              fontWeight: FontWeight.w500, fontFamily: "TT Norms")),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _signup() async {
    // Validation
    if (_nameController.text.isEmpty || 
        _emailController.text.isEmpty || 
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      _showErrorDialog("Semua field harus diisi");
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showErrorDialog("Password dan konfirmasi password tidak sama");
      return;
    }

    if (_passwordController.text.length < 6) {
      _showErrorDialog("Password minimal 6 karakter");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    String name = _nameController.text.trim();
    String email = _emailController.text.trim();
    String password = _passwordController.text;

    try {
      // Try API registration first
      final apiResponse = await _apiAuth.register(name, email, password);
      
      if (apiResponse['success'] == true) {
        // API registration successful
        if (!mounted) return;
        
        print("API Registration successful");
        _showSuccessDialog("Registrasi berhasil! Silakan login dengan akun Anda.");
        return;
      } else {
        // API registration failed, show error message
        String errorMessage = "Registrasi gagal";
        if (apiResponse['message'] != null) {
          errorMessage = apiResponse['message'];
        }
        _showErrorDialog(errorMessage);
        return;
      }
    } catch (e) {
      print("API Registration failed: $e");
      // Continue to Firebase fallback
    }

    try {
      // Fallback to Firebase authentication
      User? user = await _auth.signUpWithEmailAndPassword(email, password);

      if (!mounted) return;
      
      if (user != null) {
        print("Firebase Registration successful");
        
        // Save basic user data for Firebase users
        await TokenManager.saveAuthData(
          token: 'firebase_user', // Placeholder token for Firebase users
          userId: user.uid,
          userName: name,
          userEmail: user.email ?? email,
        );
        
        _showSuccessDialog("Registrasi berhasil! Silakan login dengan akun Anda.");
      } else {
        _showErrorDialog("Registrasi gagal. Coba lagi.");
      }
    } catch (e) {
      print("Firebase Registration failed: $e");
      if (e.toString().contains('email-already-in-use')) {
        _showErrorDialog("Email sudah terdaftar. Gunakan email lain atau login.");
      } else if (e.toString().contains('weak-password')) {
        _showErrorDialog("Password terlalu lemah. Gunakan password yang lebih kuat.");
      } else if (e.toString().contains('invalid-email')) {
        _showErrorDialog("Format email tidak valid.");
      } else {
        _showErrorDialog("Registrasi gagal. Periksa koneksi internet dan coba lagi.");
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
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

  void _showSuccessDialog(String message) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Berhasil"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Navigate to login page
              Navigator.pushReplacement(context, 
                MaterialPageRoute(builder: (context) {
                  return LoginPage(controller: TextEditingController());
                })
              );
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

}
