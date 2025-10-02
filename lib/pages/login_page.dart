import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:swiftlead/auth/firebase_auth_services.dart';
import 'package:swiftlead/pages/home_page.dart';
import 'package:swiftlead/pages/register_page.dart';
import 'package:swiftlead/pages/farmer_setup_page.dart';
import 'package:swiftlead/services/auth_services.dart.dart';
import 'package:swiftlead/utils/token_manager.dart';

class LoginPage extends StatefulWidget {
  final TextEditingController? controller;

  const LoginPage({Key? key, required this.controller}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseAuthService _auth = FirebaseAuthService();
  final AuthService _apiAuth = AuthService();

  bool showPassword = false;
  bool _isLoading = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  double width(BuildContext context) => MediaQuery.of(context).size.width;
  double height(BuildContext context) => MediaQuery.of(context).size.height;

  @override
  void initState() {
    super.initState();
    showPassword = false;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
                  "Selamat Datang di Swiftlead",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Color(0xff245C4C)),
                ),
                const SizedBox(
                  height: 10,
                ),
                const Text(
                  "Login / Daftarkan Dirimu Sekarang Juga!",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Color(0xff245C4C)),
                ),
                const SizedBox(
                  height: 10,
                ),
                const Text(
                  "Email",
                  textAlign: TextAlign.left,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Color(0xff204941)),
                ),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xff204941))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xff204941))),
                    hintText: 'Email',
                    hintStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                        color: Color(0xff245C4C)),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 15, horizontal: 18),
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                const Text(
                  "Password",
                  textAlign: TextAlign.left,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Color(0xff204941)),
                ),
                TextField(
                  controller: _passwordController,
                  obscureText: !showPassword,
                  decoration: InputDecoration(
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xff204941))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xff204941))),
                    hintText: 'Password',
                    hintStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                        color: Color(0xff245C4C)),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 15, horizontal: 18),
                    suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            showPassword = !showPassword;
                          });
                        },
                        icon: Icon(showPassword
                            ? Icons.visibility
                            : Icons.visibility_off)),
                  ),
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(
                  height: 20,
                ),
                ElevatedButton(
                    onPressed: _isLoading ? null : () {
                      _signin();
                    },
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        backgroundColor: const Color(0xFF204941),
                        foregroundColor: Colors.white,
                        minimumSize: Size(
                            width(context) * 0.75, height(context) * 0.075)),
                    child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "Masuk",
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                                fontFamily: "TT Norms"),
                          )),
                const SizedBox(
                  height: 5,
                ),
                // Google Sign-In Button
                Padding(
                  padding: EdgeInsets.only(top: height(context) * 0.02),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _googleSignIn();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF204941),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      minimumSize:
                          Size(width(context) * 0.75, height(context) * 0.075),
                    ),
                    icon: Image.asset(
                      'assets/img/Google__G__logo.png', // Google logo path
                      height: 25,
                      width: 25,
                    ),
                    label: const Text(
                      "Sign in with Google",
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Belum punya akun? ",
                      style: TextStyle(
                          color: Color(0xff245C4C),
                          fontSize: 16,
                          fontWeight: FontWeight.w500),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(context,
                            MaterialPageRoute(builder: (context) {
                          return RegisterPage(
                            controller: TextEditingController(),
                          );
                        }));
                      },
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      child: const Text("Klik Disini",
                          style: TextStyle(
                              color: Color(0xff245C4C),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              fontFamily: "TT Norms")),
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

  // Email/Password Sign-In with API Integration
  void _signin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showErrorDialog("Email dan password tidak boleh kosong");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    String email = _emailController.text.trim();
    String password = _passwordController.text;

    try {
      // Try API login first
      final apiResponse = await _apiAuth.login(email, password);
      
      if (apiResponse['success'] == true && apiResponse['data'] != null) {
        // API login successful
        final userData = apiResponse['data'];
        final token = userData['token'];
        final user = userData['user'];
        
        // Save authentication data
        await TokenManager.saveAuthData(
          token: token,
          userId: user['id'].toString(),
          userName: user['name'] ?? '',
          userEmail: user['email'] ?? email,
        );
        
        if (!mounted) return;
        
        print("API Login successful");
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (context) => const FarmerSetupPage())
        );
        return;
      }
    } catch (e) {
      print("API Login failed: $e");
      // Continue to Firebase fallback
    }

    try {
      // Fallback to Firebase authentication
      User? user = await _auth.signInWithEmailAndPassword(email, password);

      if (!mounted) return;
      
      if (user != null) {
        print("Firebase Login successful");
        
        // Save basic user data for Firebase users
        await TokenManager.saveAuthData(
          token: 'firebase_user', // Placeholder token for Firebase users
          userId: user.uid,
          userName: user.displayName ?? '',
          userEmail: user.email ?? email,
        );
        
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (context) => const FarmerSetupPage())
        );
      } else {
        _showErrorDialog("Email atau password salah");
      }
    } catch (e) {
      print("Firebase Login failed: $e");
      _showErrorDialog("Gagal masuk. Periksa koneksi internet dan coba lagi.");
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

  // Google Sign-In
  void _googleSignIn() async {
    try {
      GoogleSignIn googleSignIn = GoogleSignIn(
        clientId:
            "615110452085-bl7rokvu2evs57846dosjpf1qd5ati2c.apps.googleusercontent.com", // Pass your web client ID here
      );
      GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        print("Google Sign-In canceled by user");
        return;
      }

      GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      print("Google Sign-In successful: ${userCredential.user}");
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => const HomePage()));
    } catch (e) {
      print("Error during Google Sign-In: $e");
    }
  }
}
