import 'package:flutter/material.dart';
import 'package:swiftlead/components/custom_bottom_navigation.dart';
import 'package:swiftlead/shared/theme.dart';
import '../components/product_card.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StorePage extends StatefulWidget {
  const StorePage({super.key});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  late FirebaseFirestore _firestore;
  late Stream<QuerySnapshot>? _storeStream;
  final String storageUrl = 'gs://swiftlead-44444.appspot.com';
  final String imagePath = 'product/default.png';

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
  }

  Future<void> _initializeFirebase() async {
    await Firebase.initializeApp();
    _firestore = FirebaseFirestore.instance;

    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _storeStream = _firestore.collection('product').snapshots();
      setState(() {});
    } else {
      print('User not logged in');
    }
  }

  int _currentIndex = 1;
  @override
  Widget build(BuildContext context) {
    double width(BuildContext context) => MediaQuery.of(context).size.width;
    double height(BuildContext context) => MediaQuery.of(context).size.height;

    if (_storeStream == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          surfaceTintColor: white,
          title: const Row(
            children: [
              Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Image(
                  image: AssetImage("assets/img/logo.png"),
                  width: 64.0,
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Cari Produk...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.filter_list),
                    onPressed: () {},
                  ),
                ),
                onChanged: (query) {},
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _storeStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Text('Data not available');
                  } else {
                    List<QueryDocumentSnapshot> documents = snapshot.data!.docs;
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: GridView.builder(
                        gridDelegate:
                         SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: width(context) / (height(context)),
                        ),
                        scrollDirection: Axis.vertical,
                        shrinkWrap: true,
                        itemBuilder: (context, index) {
                          // Extract data from each document
                          String title = documents[index]['title'] ?? '';
                          String imgUrl = documents[index]['img_url'] ?? '';
                          int price = documents[index]['price'] ?? '';
                          String location = documents[index]['location'] ?? '';
                          int sold = documents[index]['sold'] ?? 0;

                          return ProductCard(
                            storageUrl: storageUrl,
                            imagePath: imgUrl,
                            title: title,
                            description: '$location | Terjual: $sold',
                            price: price,
                          );
                        },
                        itemCount: documents.length,
                      ),
                    );
                  }
                },
              ),
            ),
          ],
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
        ));
  }
}
