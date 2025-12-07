import 'package:flutter/material.dart';

import 'package:swiftlead/pages/login_page.dart';

import 'package:swiftlead/pages/register_page.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});
  double width(BuildContext context) => MediaQuery.of(context).size.width;

  double height(BuildContext context) => MediaQuery.of(context).size.height;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Column(children: [
      Container(
        width: width(context),
        height: height(context) * 0.5,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/img/landing_page.png'),
            fit: BoxFit.fill,
          ),
        ),
      ),
      SizedBox(
          width: width(context),
          height: height(context) * 0.5,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Selamat Datang di ",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 24,
                          color: Color(0xff0A4C44),
                          fontWeight: FontWeight.w600),
                    ),
                    Container(
                      //Image logo
                      alignment: Alignment.center,

                      width: width(context) * 0.2,
                      margin: const EdgeInsets.only(bottom: 4),
                      child: const Image(
                        image: AssetImage("assets/img/logo.png"),
                        fit: BoxFit.cover,
                      ),
                    )
                  ],
                ),
              ),
              Container(
                width: width(context) * 0.8,
                margin: const EdgeInsets.only(top: 16),
                child: const Text(
                  "Jadilah Bagian dari Komunitas Terbsesar Peternak Burung Walet Sekarang!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16,
                      color: Color(0xff0A4C44),
                      fontWeight: FontWeight.w400),
                  softWrap: true,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 24.0),
                child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => LoginPage(
                                    controller: TextEditingController(),
                                  )));
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      backgroundColor:
                          const Color(0xFF0A4C44), // Background color
                      foregroundColor: Colors.white, // Text color
                      minimumSize:
                          Size(width(context) * 0.75, height(context) * 0.075),
                    ),
                    child: const Text(
                      "Masuk",
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          fontFamily: "TT Norms"),
                    )),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 24.0),
                child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RegisterPage(
                                controller: TextEditingController()),
                          ));
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),

                      side:
                          const BorderSide(color: Color(0xFF0A4C44), width: 1),

                      foregroundColor: Colors.transparent, // Text color
                      minimumSize:
                          Size(width(context) * 0.75, height(context) * 0.075),
                    ),
                    child: const Text(
                      "Daftar",
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          fontFamily: "TT Norms",
                          color: Color(0xFF0A4C44)),
                    )),
              ),
            ],
          ))
    ]));
  }
}
