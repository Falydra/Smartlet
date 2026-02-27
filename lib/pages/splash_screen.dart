import 'dart:async';

import 'package:flutter/material.dart';
import 'package:swiftlead/shared/theme.dart';
import 'package:swiftlead/utils/token_manager.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  

  @override
  void initState() {
    super.initState();
    print('[SPLASH] initState called');
    Timer(const Duration(seconds: 3), () {
      print('[SPLASH] Timer complete');
    });
    _redirect();
  }

  Future<void> _redirect() async {
    try {
      print('[SPLASH] _redirect started');
      await Future.delayed(Duration.zero);
      if (!mounted) {
        print('[SPLASH] Not mounted, returning');
        return;
      }

      print('[SPLASH] Checking login status...');
      final loggedIn = await TokenManager.isLoggedIn();
      print('[SPLASH] Logged in: $loggedIn');
      
      if (loggedIn) {

        final role = await TokenManager.getUserRole();
        print('[SPLASH] User role: $role');
        if (role == 'admin') {
          print('[SPLASH] Navigating to admin-home');
          Navigator.of(context).pushReplacementNamed('/admin-home');
        } else {
          print('[SPLASH] Navigating to home-page');
          Navigator.of(context).pushReplacementNamed('/home-page');
        }
      } else {
        print('[SPLASH] Navigating to landing-page');
        Navigator.of(context).pushReplacementNamed('/landing-page');
      }
    } catch (e, stackTrace) {
      print('[SPLASH] Error in _redirect: $e');
      print('[SPLASH] Stack trace: $stackTrace');

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/landing-page');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('[SPLASH] build() called');
    dynamic parentWidth = MediaQuery.of(context).size.width;
    print('[SPLASH] Screen width: $parentWidth');

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: parentWidth / 3,
                height: parentWidth / 3,
                margin: const EdgeInsets.only(bottom: 5),
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/img/logo.png'),
                    fit: BoxFit.contain,
                  ),
                ),

                child: const Icon(
                  Icons.flutter_dash,
                  size: 100,
                  color: Color(0xff245C4C),
                ),
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(
                color: Color(0xff245C4C),
              ),
              const SizedBox(height: 20),
              const Text(
                'Loading Swiftlead...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff245C4C),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Please wait',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xff777777),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
