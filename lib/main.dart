
import 'package:flutter/material.dart';
import 'utils/local_notification_helper.dart';
import 'utils/notification_manager.dart';

import 'package:swiftlead/pages/analysis_alternate_page.dart';
import 'package:swiftlead/pages/analysis_page.dart';
import 'package:swiftlead/pages/community_page.dart';
import 'package:swiftlead/pages/control_page.dart';
import 'package:swiftlead/pages/sensor_detail_page.dart';
import 'package:swiftlead/pages/login_page.dart';
import 'package:swiftlead/pages/pest_page.dart';
import 'package:swiftlead/pages/profile_page.dart';
import 'package:swiftlead/pages/register_page.dart';
import 'package:swiftlead/pages/home_page.dart';
import 'package:swiftlead/admin/admin_home_page.dart';
import 'package:swiftlead/admin/admin_rbw_page.dart';
import 'package:swiftlead/admin/admin_harvest_page.dart';
import 'package:swiftlead/admin/admin_users_page.dart';
import 'package:swiftlead/admin/admin_finance_page.dart';
import 'package:swiftlead/user/user_home_page.dart';
import 'package:swiftlead/pages/security_page.dart';
import 'package:swiftlead/pages/splash_screen.dart';
import 'package:swiftlead/pages/temp_page.dart';
import 'package:swiftlead/pages/landing_page.dart';
import 'package:swiftlead/pages/blog_page.dart';
import 'package:swiftlead/pages/farmer_setup_page.dart';
import 'package:swiftlead/pages/cage_data_page.dart';
import 'package:swiftlead/pages/cage_selection_page.dart';
import 'package:swiftlead/pages/device_installation_page.dart';
import 'package:swiftlead/pages/kandang_detail_page.dart';
import 'package:swiftlead/pages/sales_page.dart';
import 'package:swiftlead/pages/service_requests_page.dart';
import 'package:swiftlead/pages/create_service_request_page.dart';
import 'package:swiftlead/pages/service_request_detail_page.dart';
import 'package:swiftlead/pages/installation_manager_page.dart';
import 'package:swiftlead/pages/user_manager_page.dart';
import 'package:swiftlead/pages/reports_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LocalNotificationHelper().init();
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
      builder: (context, child) {
        
        NotificationManager();
        return child!;
      },
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
        '/kandang-detail': (context) {
          final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
          return KandangDetailPage(
            houseId: args['houseId'].toString(),
          );
        },
        '/home-page': (context) => const HomePage(),
        '/admin-home': (context) => const AdminHomePage(),
        '/admin-rbw': (context) => const AdminRbwPage(),
        '/admin-harvest': (context) => const AdminHarvestPage(),
        '/admin-users': (context) => const AdminUsersPage(),
        '/admin-finance': (context) => const AdminFinancePage(),
        '/user-home': (context) => const UserHomePage(),
        '/service-requests': (context) => const ServiceRequestsPage(),
        '/create-service-request': (context) => const CreateServiceRequestPage(),
        '/service-request-detail': (context) => const ServiceRequestDetailPage(),
        '/installation-manager': (context) => const InstallationManagerPage(),
        '/user-manager': (context) => const UserManagerPage(),
        '/blog-page': (context) => const BlogPage(),
        '/store-page': (context) => const SalesPage(),
       
        '/community-page': (context) => const CommunityPage(),
        '/control-page': (context) => const ControlPage(),
        '/sensor-detail': (context) => const SensorDetailPage(),
        '/profile-page': (context) => const ProfilePage(),
        '/reports-page': (context) => const ReportsPage(),
        '/temp-page': (context) => const TempPage(),
        '/pest-page': (context) => const PestPage(),
        '/security-page': (context) => const SecurityPage(),
        '/analysis-page': (context) => const AnalysisPage(),
      },
    );
  }
}
 