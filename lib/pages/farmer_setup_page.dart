import 'package:flutter/material.dart';
import 'package:swiftlead/pages/cage_data_page.dart';
import 'package:swiftlead/pages/home_page.dart';
import 'package:swiftlead/shared/theme.dart';

class FarmerSetupPage extends StatelessWidget {
  const FarmerSetupPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double width(BuildContext context) => MediaQuery.of(context).size.width;
    double height(BuildContext context) => MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo
              Container(
                margin: EdgeInsets.only(bottom: height(context) * 0.05),
                child: Image.asset(
                  'assets/img/logo2.png',
                  width: 160,
                  height: 160,
                ),
              ),

              // Welcome Text
              Text(
                'Selamat Datang!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF245C4C),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Question
              Text(
                'Apakah Anda seorang peternak burung walet?',
                style: TextStyle(
                  fontSize: 18,
                  color: Color.fromARGB(255, 34, 137, 108),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                'Kami akan membantu Anda mengatur data kandang untuk pengalaman yang lebih personal.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color.fromARGB(255, 34, 137, 108),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 60),

              // Farmer Icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color(0xFFFFF7CA),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Icon(
                  Icons.agriculture,
                  size: 60,
                  color: Color(0xFF245C4C),
                ),
              ),

              const SizedBox(height: 60),

              // Yes Button
              SizedBox(
                width: width(context) * 0.8,
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
                    backgroundColor: Color(0xFF245C4C),
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

              // Skip Button
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
