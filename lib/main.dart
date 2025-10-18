
import 'package:flutter/material.dart';

import 'package:swiftlead/pages/analysis_alternate_page.dart';
import 'package:swiftlead/pages/analysis_page.dart';
import 'package:swiftlead/pages/community_page.dart';
import 'package:swiftlead/pages/control_page.dart';
import 'package:swiftlead/pages/login_page.dart';
import 'package:swiftlead/pages/pest_page.dart';
import 'package:swiftlead/pages/profile_page.dart';
import 'package:swiftlead/pages/register_page.dart';
import 'package:swiftlead/pages/home_page.dart';
import 'package:swiftlead/pages/security_page.dart';
import 'package:swiftlead/pages/splash_screen.dart';
import 'package:swiftlead/pages/temp_page.dart';
import 'package:swiftlead/pages/landing_page.dart';
import 'package:swiftlead/pages/blog_page.dart';
import 'package:swiftlead/pages/farmer_setup_page.dart';
import 'package:swiftlead/pages/cage_data_page.dart';
import 'package:swiftlead/pages/cage_selection_page.dart';
import 'package:swiftlead/pages/device_installation_page.dart';
import 'package:swiftlead/pages/sales_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
 

  runApp(const MyApp());
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
        '/landing-page': (context) => const LandingPage(),
        '/login-page': (context) => LoginPage(
              controller: TextEditingController(),
            ),
        '/register-page': (context) => RegisterPage(
              controller: TextEditingController(),
            ),
        '/farmer-setup': (context) => const FarmerSetupPage(),
        '/cage-data': (context) => const CageDataPage(),
        '/cage-selection': (context) => const CageSelectionPage(),
        '/harvest/analysis': (context) => const AnalysisPageAlternate(),
        '/device-installation': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return DeviceInstallationPage(
            houseId: args['houseId'],
            houseName: args['houseName'],
          );
        },
        '/home-page': (context) => const HomePage(),
        '/blog-page': (context) => const BlogPage(),
        '/store-page': (context) => const SalesPage(),
       
        '/community-page': (context) => const CommunityPage(),
        '/control-page': (context) => const ControlPage(),
        '/profile-page': (context) => const ProfilePage(),
        '/temp-page': (context) => const TempPage(),
        '/pest-page': (context) => const PestPage(),
        '/security-page': (context) => const SecurityPage(),
        '/analysis-page': (context) => const AnalysisPage(),
      },
    );
  }
}
 