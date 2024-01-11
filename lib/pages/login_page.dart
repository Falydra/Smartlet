import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:swiftlead/auth/firebase_auth_services.dart';
import 'package:swiftlead/pages/home_page.dart';
import 'package:swiftlead/pages/register_page.dart';

class LoginPage extends StatefulWidget {
  final TextEditingController? controller;

  const LoginPage({Key? key, required this.controller}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
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
      body: Stack(
        children: [
          Container(
            // decoration: BoxDecoration(border: Border.all(width: 2)),
            height: height(context),
            padding: const EdgeInsets.symmetric(horizontal: 37),
            margin: EdgeInsets.only(top: height(context) * 0.475),
            child: Form(
              child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const Text(
                  "Masuk",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w500),
                ),

                // email
                const Text(
                  "Email",
                  textAlign: TextAlign.left,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
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

                // password
                const Text(
                  "Password",
                  textAlign: TextAlign.left,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
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

                ElevatedButton(onPressed: (){
                  _signin();
                  // databaseReference.child('users').set({
                  //   'email': emailController.text.toString(),
                  //   'password': passwordController.text.toString(),
                  //   'id': DateTime.now().microsecond.toString(),
                  // });
                }, child: const Text("Masuk")),
                TextButton(
                        onPressed: () {
                          Navigator.push(context,
                              MaterialPageRoute(builder: (context) {
                            return RegisterPage(controller: TextEditingController(),);
                          }));
                          // Navigator.pop(context);
                        },
                        style: TextButton.styleFrom(
                            foregroundColor: const Color.fromRGBO(0, 0, 0, 0.27),
                            padding: EdgeInsets.zero),
                        child: const Text("Sign Up",
                            style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w500)),
                      ),
              ],
            )),
          ),
          Image(
            image: const AssetImage("assets/img/register_login.png"),
            height: height(context) / 1.75,
            // height:200,
            width: width(context),
            fit: BoxFit.cover,
          ),
        ],
      ),
    );
  }

  void _signin() async {
    String email = _emailController.text;
    String password = _passwordController.text;

    User? user = await _auth.signInWithEmailAndPassword(email, password);

    if (user != null) {
      print("User Sign in");
      Navigator.push(context, 
            MaterialPageRoute(builder: (context) {
            return const HomePage();
          })
        );
    }else{
      print("Something erorr");
    }
  }
}
