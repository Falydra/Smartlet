import 'package:flutter/material.dart';
import 'package:swiftlead/components/custom_bottom_navigation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:swiftlead/shared/theme.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int _currentIndex = 4;

  double width(BuildContext context) => MediaQuery.of(context).size.width;
  double height(BuildContext context) => MediaQuery.of(context).size.height;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   automaticallyImplyLeading: false,
      //   title: Row(
      //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
      //     children: [
      //       const Padding(
      //         padding: EdgeInsets.only(left: 8.0),
      //         child: Image(
      //           image: AssetImage("assets/img/logo.png"),
      //           width: 64.0,
      //         ),
      //       ),
      //       IconButton(
      //         icon: const Icon(Icons.logout),
      //         onPressed: () async {
      //           // Perform the logout action
      //           await FirebaseAuth.instance.signOut();
      //           Navigator.pushReplacementNamed(context, '/login-page');
      //         },
      //       ),
      //     ],
      //   ),
      // ),
      backgroundColor: blue400,
      body: Stack(children: [
        SizedBox(
          width: width(context),
          height: height(context) * 0.35,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: AssetImage("assets/img/profile.jpg"),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 10.0),
              // const Text(
              //   'Faishal',
              //   style: TextStyle(
              //     fontSize: 24.0,
              //     fontWeight: FontWeight.bold,
              //   ),
              // ),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 5.0,
                  horizontal: 20.0,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18.0),
                  color: blue300,
                ),
                child: Text(
                  '${_auth.currentUser!.email}',
                  style: const TextStyle(
                    fontSize: 16.0,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.only(top: 60, left: 10, right: 10),
          alignment: Alignment.centerLeft,
          margin: EdgeInsets.only(top: height(context) * 0.35),
          width: width(context),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20.0),
              topRight: Radius.circular(20.0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: () {},
                icon: Icon(Icons.shopping_bag_outlined),
                label: Text(
                  "Toko Saya",
                  style: TextStyle(color: Colors.black),
                ),
                style: TextButton.styleFrom(iconColor: Colors.black),
              ),

              Divider(
                color: Color(0xff767676),
                height: 1,
              ),

              TextButton.icon(
                onPressed: () {},
                icon: Icon(Icons.money_outlined),
                label: Text(
                  "Pendapatan",
                  style: TextStyle(color: Colors.black),
                ),
                style: TextButton.styleFrom(iconColor: Colors.black),
              ),

              Divider(
                color: Color(0xff767676),
                height: 1,
              ),

              TextButton.icon(
                onPressed: () {},
                icon: Icon(Icons.supervisor_account_outlined),
                label: Text(
                  "Teman",
                  style: TextStyle(color: Colors.black),
                ),
                style: TextButton.styleFrom(iconColor: Colors.black),
              ),

              Divider(
                color: Color(0xff767676),
                height: 1,
              ),

              TextButton.icon(
                onPressed: () {},
                icon: Icon(Icons.question_mark_outlined),
                label: Text(
                  "FAQ",
                  style: TextStyle(color: Colors.black),
                ),
                style: TextButton.styleFrom(iconColor: Colors.black),
              ),

              Divider(
                color: Color(0xff767676),
                height: 1,
              ),

              TextButton.icon(
                onPressed: () {},
                icon: Icon(Icons.fact_check_outlined),
                label: Text(
                  "Tentang",
                  style: TextStyle(color: Colors.black),
                ),
                style: TextButton.styleFrom(iconColor: Colors.black),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                margin: EdgeInsets.only(top: height(context) * 0.3),
                decoration: BoxDecoration(
                  color: sky50,
                  borderRadius: BorderRadius.circular(10),
                ),
                width: width(context) / 3.5,
                height: 80,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.create_outlined, color: blue500,),
                    Text("Edit Profil", style: TextStyle(color: blue500, fontWeight: FontWeight.w500),)
                  ],
                ),
              ),
              Container(
                margin: EdgeInsets.only(top: height(context) * 0.3),
                decoration: BoxDecoration(
                  color: sky50,
                  borderRadius: BorderRadius.circular(10),
                ),
                width: width(context) / 3.5,
                height: 80,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.settings_outlined, color: blue500,),
                    Text("Pengaturan", style: TextStyle(color: blue500, fontWeight: FontWeight.w500),)
                  ],
                ),
              ),
              Container(
                margin: EdgeInsets.only(top: height(context) * 0.3),
                decoration: BoxDecoration(
                  color: sky50,
                  borderRadius: BorderRadius.circular(10),
                ),
                width: width(context) / 3.5,
                height: 80,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, color: blue500,),
                    Text("Bantuan", style: TextStyle(color: blue500, fontWeight: FontWeight.w500),)
                  ],
                ),
              ),
            ],
          ),
        ),

        Positioned(
          top: 20,
          right: 0,
          child: IconButton(
              icon: const Icon(Icons.logout),
              color: Colors.red,
              onPressed: () async {
                // Perform the logout action
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacementNamed(context, '/login-page');
              },
            ),
        )
      ]),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
              icon: CustomBottomNavigationItem(
                icon: Icons.home,
                label: 'Beranda',
                currentIndex: _currentIndex,
                itemIndex: 0,
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/home-page');
                  setState(() {
                    _currentIndex = 0;
                  });
                },
              ),
              label: ''),
          BottomNavigationBarItem(
              icon: CustomBottomNavigationItem(
                icon: Icons.store,
                label: 'Toko',
                currentIndex: _currentIndex,
                itemIndex: 1,
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/store-page');
                  setState(() {
                    _currentIndex = 1;
                  });
                },
              ),
              label: ''),
          BottomNavigationBarItem(
              icon: CustomBottomNavigationItem(
                icon: Icons.chat_sharp,
                label: 'Komunitas',
                currentIndex: _currentIndex,
                itemIndex: 2,
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/community-page');
                  setState(() {
                    _currentIndex = 2;
                  });
                },
              ),
              label: ''),
          BottomNavigationBarItem(
              icon: CustomBottomNavigationItem(
                icon: Icons.dataset_sharp,
                label: 'kontrol',
                currentIndex: _currentIndex,
                itemIndex: 3,
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/control-page');
                  setState(() {
                    _currentIndex = 3;
                  });
                },
              ),
              label: ''),
          BottomNavigationBarItem(
              icon: CustomBottomNavigationItem(
                icon: Icons.person,
                label: 'Profil',
                currentIndex: _currentIndex,
                itemIndex: 4,
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/profile-page');
                  setState(() {
                    _currentIndex = 4;
                  });
                },
              ),
              label: ''),
        ],
      ),
    );
  }
}
