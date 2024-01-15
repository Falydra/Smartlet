import 'dart:math';

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

      _temperatureStream = _firestore
          .collection('users')
          .doc(userId)
          .collection('temperatures')
          .orderBy('date')
          .snapshots();
      setState(() {});
    } else {
      print('User not logged in');
    }
  }

  List<LineChartBarData> _getChartData(List<QueryDocumentSnapshot> documents) {
    return [
      LineChartBarData(
        spots: documents.asMap().entries.map((entry) {
          Map<String, dynamic> data =
              entry.value.data() as Map<String, dynamic>;
          int celcius = data['temp'];
          return FlSpot(entry.key.toDouble(), celcius.toDouble());
        }).toList(),
        color: amber300,
        dotData: FlDotData(show: true),
        belowBarData: BarAreaData(show: false),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_temperatureStream == null) {
      return const CircularProgressIndicator();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suhu & Kelembaban'),
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
                  child: Padding(
                    padding: const EdgeInsets.only(right: 22.0, top: 16),
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        lineBarsData: _getChartData(documents),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                Map<String, dynamic> data =
                                    documents[value.toInt()].data()
                                        as Map<String, dynamic>;
                                Timestamp dateTimestamp = data['date'];
                                DateTime date = dateTimestamp.toDate();
                                return Text(
                                  DateFormat('dd').format(date),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: const Border(
                            left: BorderSide(
                              color: Colors.black,
                              width: 1,
                            ),
                            bottom: BorderSide(
                              color: Colors.black,
                              width: 1,
                            ),
                          ),
                        ),
                        minX: 0,
                        maxX: documents.length.toDouble() - 1,
                        minY: max(
                            documents.map((document) {
                                  Map<String, dynamic> data =
                                      document.data() as Map<String, dynamic>;
                                  int celcius = data['temp'];
                                  return celcius;
                                }).reduce(min) -
                                1,
                            0),
                        maxY: max(
                            documents.map((document) {
                                  Map<String, dynamic> data =
                                      document.data() as Map<String, dynamic>;
                                  int celcius = data['temp'];
                                  return celcius;
                                }).reduce(max) +
                                1,
                            0),
                      ),
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
                          DataColumn(label: Text('Kelembaban')),
                        ],
                        rows: documents.map((document) {
                          Map<String, dynamic> data =
                              document.data() as Map<String, dynamic>;
                          int celcius = data['temp'];
                          Timestamp dateTimestamp = data['date'];
                          DateTime date = dateTimestamp.toDate();
                          String humidity = data['humidity'];

                          return DataRow(cells: [
                            DataCell(
                                Text(DateFormat('dd MMM yyyy').format(date))),
                            DataCell(Text('$celcius °C')),
                            DataCell(Text('$humidity')),
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
