import 'package:flutter/material.dart';
import 'package:swiftlead/pages/cage_data_page.dart';
import 'package:swiftlead/pages/home_page.dart';
import 'package:swiftlead/admin/admin_home_page.dart';
import 'package:swiftlead/utils/token_manager.dart';

class FarmerSetupPage extends StatefulWidget {
  const FarmerSetupPage({super.key});

  @override
  State<FarmerSetupPage> createState() => _FarmerSetupPageState();
}

class _FarmerSetupPageState extends State<FarmerSetupPage> {
  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final role = await TokenManager.getUserRole();
    if (role == 'admin' && mounted) {

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AdminHomePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [

              Container(
                margin: EdgeInsets.only(bottom: height * 0.01),
                child: Image.asset(
                  'assets/img/logo2.png',
                  width: 160,
                  height: 160,
                ),
              ),


              const Text(
                'Selamat Datang!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF245C4C),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),


              const Text(
                'Apakah Anda seorang peternak burung walet?',
                style: TextStyle(
                  fontSize: 18,
                  color: Color.fromARGB(255, 34, 137, 108),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              const Text(
                'Kami akan membantu Anda mengatur data kandang untuk pengalaman yang lebih personal.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color.fromARGB(255, 34, 137, 108),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 60),


              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7CA),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(
                  Icons.agriculture,
                  size: 60,
                  color: Color(0xFF245C4C),
                ),
              ),

              const SizedBox(height: 60),


              SizedBox(
                width: width * 0.8,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CageDataPage(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF245C4C),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Ya, Isi Data Kandang',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),


              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HomePage(),
                    ),
                  );
                },
                child: Text(
                  'Lewati langkah ini',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
