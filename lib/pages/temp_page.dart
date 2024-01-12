import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:swiftlead/shared/theme.dart';

class TempPage extends StatefulWidget {
  const TempPage({Key? key}) : super(key: key);

  @override
  _TempPageState createState() => _TempPageState();
}

class _TempPageState extends State<TempPage> {
  late FirebaseFirestore _firestore;
  late Stream<QuerySnapshot>? _temperatureStream;

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
      String userId = user.uid;
      print('User ID: $userId');

      _temperatureStream = _firestore
          .collection('users')
          .doc(userId)
          .collection('temperatures')
          .orderBy('date', descending: true)
          .snapshots();
      setState(() {});
    } else {
      print('User not logged in');
    }
  }

  List<BarChartGroupData> _getChartData(List<QueryDocumentSnapshot> documents) {
    return documents.asMap().entries.map((entry) {
      Map<String, dynamic> data = entry.value.data() as Map<String, dynamic>;
      int celcius = data['temp'];
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(toY: celcius.toDouble(), color: amber300),
        ],
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_temperatureStream == null) {
      return const CircularProgressIndicator();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Temperature Page'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _temperatureStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const CircularProgressIndicator();
          } else if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Text('Data not available');
          } else {
            List<QueryDocumentSnapshot> documents = snapshot.data!.docs;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 1.5,
                  child: BarChart(
                    BarChartData(
                      barGroups: _getChartData(documents),
                      borderData: FlBorderData(
                        show: true,
                        border: Border(
                          left: BorderSide(
                            color: const Color(0xff37434d),
                            width: 1,
                          ),
                          bottom: BorderSide(
                            color: const Color(0xff37434d),
                            width: 1,
                          ),
                        ),
                      ),
                      titlesData: FlTitlesData(),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      DataTable(
                        columns: const [
                          DataColumn(label: Text('Tanggal')),
                          DataColumn(label: Text('Suhu')),
                        ],
                        rows: documents.map((document) {
                          Map<String, dynamic> data =
                              document.data() as Map<String, dynamic>;
                          int celcius = data['temp'];
                          Timestamp dateTimestamp = data['date'];
                          DateTime date = dateTimestamp.toDate();
                      
                          return DataRow(cells: [
                            DataCell(Text(DateFormat('dd MMM yyyy').format(date))),
                            DataCell(Text('$celcius °C')),
                          ]);
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }
}
