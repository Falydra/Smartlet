import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:swiftlead/firebase_options.dart';
import 'package:swiftlead/pages/community_page.dart';
import 'package:swiftlead/pages/control_page.dart';
import 'package:swiftlead/pages/login_page.dart';
import 'package:swiftlead/pages/profile_page.dart';
import 'package:swiftlead/pages/register_page.dart';
import 'package:swiftlead/pages/home_page.dart';
import 'package:swiftlead/pages/splash_screen.dart';
import 'package:swiftlead/pages/store_page.dart';
import 'package:swiftlead/pages/temp_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
      .then((_) => runApp(const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  double width(BuildContext context) => MediaQuery.of(context).size.width;
  double height(BuildContext context) => MediaQuery.of(context).size.height;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowMaterialGrid: false,
      theme: ThemeData(
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontFamily: 'TT Norms'),
        ),
      ),
      debugShowCheckedModeBanner: false,
      routes: {
        '/': (context) => const SplashScreen(),
        '/login-page': (context) => LoginPage(
              controller: TextEditingController(),
            ),
        '/register-page': (context) => RegisterPage(
              controller: TextEditingController(),
            ),
        '/home-page': (context) => const HomePage(),
        '/store-page': (context) => const StorePage(),
        '/community-page': (context) => const CommunityPage(),
        '/control-page': (context) => const ControlPage(),
        '/profile-page': (context) => const ProfilePage(),
        '/temp-page': (context) => const TempPage(),
      },
    );
  }
}
