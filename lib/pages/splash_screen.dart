import 'dart:async';

import 'package:flutter/material.dart';
import 'package:swiftlead/shared/theme.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    Timer(const Duration(seconds: 3), () {
      // var user = false;
      // if(user == null){
      //   Navigator.pushNamedAndRemoveUntil(context, '/get-started', (route) => false);
      // } else {
      //   context.read<AuthCubit>().getCurrentUser(user.uid);
      //   Navigator.pushNamedAndRemoveUntil(context, '/main', (route) => false);
      // }
      // Navigator.pushNamedAndRemoveUntil(
      //     context, '/landing-page', (route) => false);
    });
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    final user = _auth.currentUser;
    if (user != null) {
      Navigator.of(context).pushReplacementNamed('/home-page');
    } else {
      Navigator.of(context).pushReplacementNamed('/login-page');
    }
  }

  @override
  Widget build(BuildContext context) {
    dynamic parentWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: white,
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: parentWidth / 3,
            height: parentWidth / 3,
            margin: const EdgeInsets.only(bottom: 5),
            decoration: const BoxDecoration(
                image: DecorationImage(
              image: AssetImage('assets/img/logo.png'),
            )),
          ),
        ]),
      ),
    );
  }
}
