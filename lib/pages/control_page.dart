import 'dart:async';

import 'package:flutter/material.dart';
import 'package:swiftlead/components/custom_bottom_navigation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:swiftlead/shared/theme.dart';

class ControlPage extends StatefulWidget {
  const ControlPage({super.key});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  late FirebaseFirestore _firestore;
  late Stream<QuerySnapshot>? _controlStream;
  String? _selectedDocumentId;

  bool isPlaying = false;
  bool isLoading = true;
  double progress = 1.0;
  int remainingTime = 600;

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
      _controlStream = _firestore.collection('device').snapshots();
      setState(() {});
    } else {
      print('User not logged in');
    }
  }

  int _currentIndex = 3;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
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
      body: StreamBuilder<QuerySnapshot>(
        stream: _controlStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Text('Data not available');
          } else {
            List<QueryDocumentSnapshot> documents = snapshot.data!.docs;

            documents.sort((a, b) {
              int deviceIdA = a['device_id'] ?? 0;
              int deviceIdB = b['device_id'] ?? 0;
              return deviceIdA.compareTo(deviceIdB);
            });

            return Column(
              children: [
                if (_selectedDocumentId != null)
                  FutureBuilder<DocumentSnapshot>(
                    future: _firestore
                        .collection('device')
                        .doc(_selectedDocumentId)
                        .get(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting && isLoading) {
                        return const CircularProgressIndicator();
                      } else if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      } else if (!snapshot.hasData || !snapshot.data!.exists) {
                        return const Text('Device not found');
                      } else {
                        Map<String, dynamic> deviceData =
                            snapshot.data!.data() as Map<String, dynamic>;
                        return CircleInfoWidget(deviceData: deviceData);
                      }
                    },
                  ),
                Expanded(
                  child: ListView.builder(
                    itemCount: documents.length,
                    itemBuilder: (context, index) {
                      int deviceId =
                          documents[index]['device_id'] ?? 'Unknown Device';
                      bool isActive =
                          documents[index].id == _selectedDocumentId;

                      return Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(horizontal: 10),
                          title: Text(
                            'Perangkat $deviceId',
                            style: TextStyle(fontSize: 18, fontWeight: bold),
                          ),
                          tileColor: isActive ? sky50 : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                                12.0), // Sesuaikan dengan kebutuhan Anda
                          ),
                          onTap: () {
                            setState(() {
                              isLoading = true;
                              _selectedDocumentId = documents[index].id;
                            });
                          },
                          trailing: SizedBox(
                            width: 125,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  isLoading = false;
                                  _selectedDocumentId = documents[index].id;
                                  if (isPlaying) {
                                    isPlaying = false;
                                    remainingTime = 600;
                                    progress = 1.0;
                                  } else {
                                    isPlaying = true;
                                    startTimer();
                                  }
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.all(5),
                                backgroundColor: blue500,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(5.0),
                                ),
                              ),
                              icon: Icon(
                                isPlaying && isActive
                                    ? Icons.multitrack_audio
                                    : Icons.play_arrow,
                                color: Colors.white,
                              ),
                              label: Text(
                                isPlaying && isActive
                                    ? '${(remainingTime ~/ 60).toString().padLeft(2, '0')}:${(remainingTime % 60).toString().padLeft(2, '0')}'
                                    : 'Play Sound', style: TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          }
        },
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

  void startTimer() {
    const duration = Duration(seconds: 1);
    Timer.periodic(duration, (timer) {
      if (!isPlaying) {
        timer.cancel();
      } else if (remainingTime > 0) {
        setState(() {
          progress = remainingTime / 600;
        });
        remainingTime--;
      } else {
        setState(() {
          isPlaying = false;
          progress = 1.0;
          remainingTime = 600;
        });
        timer.cancel();
      }
    });
  }
}

class ResponsiveCircleWidget extends StatelessWidget {
  final String label;
  final String value;

  const ResponsiveCircleWidget({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    // Dapatkan lebar layar perangkat
    double screenWidth = MediaQuery.of(context).size.width;

    // Hitung nilai width dan height berdasarkan persentase
    double circleSize = screenWidth * 0.2;

    return Column(
      children: [
        Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: amber50,
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                  color: amber700,
                  fontSize: circleSize * 0.2,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 8.0),
        Text(label),
      ],
    );
  }
}

class CircleInfoWidget extends StatelessWidget {
  final Map<String, dynamic> deviceData;

  CircleInfoWidget({required this.deviceData});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ResponsiveCircleWidget(
              label: 'Hama', value: deviceData['pest'].toString()),
          const SizedBox(height: 8.0),
          ResponsiveCircleWidget(
              label: 'Suhu', value: deviceData['temp'].toString()),
          const SizedBox(height: 8.0),
          ResponsiveCircleWidget(
              label: 'Kelembaban', value: deviceData['humidity'].toString()),
          const SizedBox(height: 8.0),
          ResponsiveCircleWidget(
              label: 'Keamanan', value: deviceData['security'].toString()),
          const SizedBox(height: 8.0),
        ],
      ),
    );
  }
}
