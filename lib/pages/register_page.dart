import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:swiftlead/auth/firebase_auth_services.dart';
import 'package:swiftlead/pages/login_page.dart';

class RegisterPage extends StatefulWidget {
  final TextEditingController? controller;

  const RegisterPage({Key? key, required this.controller}) : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}


class _RegisterPageState extends State<RegisterPage> {

  final FirebaseAuthService _auth = FirebaseAuthService();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  double width(BuildContext context) => MediaQuery.of(context).size.width;
  double height(BuildContext context) => MediaQuery.of(context).size.height;

  @override
  // Menghindari memomi bocor
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
                  // controller: _passwordController,
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
                SizedBox(
                  height: 20,
                ),
                ElevatedButton(
                    onPressed: () {
                      _signup();
                      // databaseReference.child('users').set({
                      //   'email': emailController.text.toString(),
                      //   'password': passwordController.text.toString(),
                      //   'id': DateTime.now().microsecond.toString(),
                      // });
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      backgroundColor:
                          const Color(0xFF0010A2), // Background color
                      foregroundColor: Colors.white, // Text color
                    ),
                    child: const Text(
                      "Daftar",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w500, fontFamily: "TT Norms"),
                    )),
                    SizedBox(
                      height: 5,
                    ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Sudah punya akun? ", style: TextStyle(color: Color(0xff000744), fontSize: 16, fontWeight: FontWeight.w500),),
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
    String email = _emailController.text;
    String password = _passwordController.text;

    User? user = await _auth.signUpWithEmailAndPassword(email, password);

    if (user != null) {
      print("User created");
      Navigator.push(context, 
            MaterialPageRoute(builder: (context) {
            return LoginPage(controller: TextEditingController(),);
          })
        );
    }else{
      print("Something erorr");
    }
  }

}
