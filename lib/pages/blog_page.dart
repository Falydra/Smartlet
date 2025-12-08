import 'package:flutter/material.dart';
import 'package:swiftlead/components/custom_bottom_navigation.dart';

class BlogPage extends StatefulWidget {
  const BlogPage({super.key});

  @override
  State<BlogPage> createState() => _BlogPageState();
}

class _BlogPageState extends State<BlogPage> {
  double width(BuildContext context) => MediaQuery.of(context).size.width;

  double height(BuildContext context) => MediaQuery.of(context).size.height;

  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Berita'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              Text("Cara Melakukan Budidaya Burung Walet", style: TextStyle(fontSize: width(context) * 0.05, color: Colors.black, fontWeight: FontWeight.w600),),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
               Padding(
                 padding: const EdgeInsets.only(top: 16.0),
                 child: Container(
                             width: width(context) * 0.8,
                            height: height(context) * 0.20,
                            decoration: const BoxDecoration(
                              image: DecorationImage(
                                image: AssetImage("assets/img/Frame_19.png"),
                                fit: BoxFit.cover
                              ),
                              borderRadius: BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8))
                            ),
                            ),
               ),
            ],
            ),
            Container(
              margin: const EdgeInsets.all(24),
              child: const Text("Burung walet, dengan keindahan suaranya dan manfaat sarangnya, telah menjadi perhatian banyak orang. Jika Anda tertarik untuk membuka usaha sarang burung walet atau hanya ingin menciptakan lingkungan yang ramah bagi mereka, berikut ini panduan langkah demi langkah untuk melakukan budidaya sarang burung walet, dari pembuatan hingga panen.", style: TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w300), textAlign: TextAlign.justify,)
              ),
              Padding(
                padding: EdgeInsets.only(left: width(context) * 0.07, right: width(context) * 0.07),
                child: Container(
                
                child:  const Text("1. Pembuatan & Persiapan Tempat Sarang Burung Walet .", style: TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w500),)
                
                ),
              ),
              Container(
              margin: const EdgeInsets.only(left: 40, right: 24, top: 24),
              child: const Text("Pertama-tama, buat habitat yang mirip dengan kondisi asli mereka. Tempatkan rumah burung walet di lokasi yang memiliki pencahayaan minimal agar burung lebih mudah beradaptasi. Pastikan rumah tersebut disusun dengan cermat untuk menciptakan lingkungan yang sesuai dengan habitat alami burung walet.", style: TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w300), textAlign: TextAlign.justify),
              ),
              Padding(
                padding: EdgeInsets.only(left: width(context) * 0.07, right: width(context) * 0.07, top: height(context) * 0.02),
                child: Container(
                
                child: const Text("2. Mengundang, Memberikan Makan, dan Perawatan", style: TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w500),)
                
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Container(
                margin: const EdgeInsets.only(left: 40, right: 24, top: 24),
                child: const Text("Cara terbaik untuk memikat burung walet agar bersarang adalah dengan menggunakan rekaman suara burung walet. Tempatkan rekaman ini di dalam rumah buatan untuk menarik perhatian burung. Selain itu, memberikan makanan yang mudah dijangkau oleh burung walet akan membantu mereka merasa nyaman. Burung walet cenderung mencari makan sendiri, jadi pastikan ada cukup sumber makanan di sekitar tempat sarang. Perawatan melibatkan pemantauan kondisi sarang dan lingkungan sekitar. Pastikan sarang tetap bersih dan aman. Sistem ventilasi yang baik juga diperlukan untuk menjaga suhu dan kelembaban yang sesuai.", style: TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.w300), textAlign: TextAlign.justify),
                ),
              )

          ],
        ),
      ),
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