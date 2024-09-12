import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:swiftlead/shared/theme.dart';

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({Key? key}) : super(key: key);

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  double width(BuildContext context) => MediaQuery.of(context).size.width;
  double height(BuildContext context) => MediaQuery.of(context).size.height;

  late FirebaseFirestore _firestore;
  Stream<QuerySnapshot>? _analysisStream;

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

      DateTime yesterdayStart =
          DateTime.now().subtract(const Duration(days: 1));
      DateTime yesterdayEnd = DateTime.now();

      _analysisStream = _firestore
          .collection('users')
          .doc(userId)
          .collection('analysis')
          .where('date', isGreaterThanOrEqualTo: yesterdayStart)
          .where('date', isLessThan: yesterdayEnd)
          .limit(1)
          .snapshots();

      setState(() {});
    } else {
      print('User not logged in');
    }
  }

  List<PieChartSectionData> _getChartData(
      List<QueryDocumentSnapshot> documents) {
    List<PieChartSectionData> sections = [];

    for (QueryDocumentSnapshot document in documents) {
      Map<String, dynamic> data = document.data() as Map<String, dynamic>;
      double bowl = data['bowl'] ?? 0.0;
      double corner = data['corner'] ?? 0.0;
      double oval = data['oval'] ?? 0.0;
      double fault = data['fault'] ?? 0.0;

      sections.add(
        PieChartSectionData(
          value: bowl,
          color: const Color(0xff000B73),
          title: '$bowl Kg',
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
      sections.add(
        PieChartSectionData(
          value: corner,
          color: const Color(0xffB58A00),
          title: '$corner Kg',
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
      sections.add(
        PieChartSectionData(
          value: oval,
          color: const Color(0xff168AB5),
          title: '$oval Kg',
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
      sections.add(
        PieChartSectionData(
          value: fault,
          color: const Color(0xffC20000),
          title: '$fault Kg',
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return sections;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analisis Panen'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _analysisStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Data not available'));
          } else {
            List<QueryDocumentSnapshot> documents = snapshot.data!.docs;
            List data = documents.map((document) {
              Map<String, dynamic> data =
                  document.data() as Map<String, dynamic>;
              return data;
            }).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AspectRatio(
                  aspectRatio: 1.5,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: PieChart(
                      PieChartData(
                        sections: _getChartData(documents),
                        centerSpaceRadius: 50,
                        sectionsSpace: 5,
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
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 10),
                    child: ListView(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              height: 100,
                              width: width(context) / 2.5,
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                shape: BoxShape.rectangle,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Panen Diterima",
                                    style: TextStyle(
                                        fontSize: 14, color: Colors.blue),
                                  ),
                                  Text(
                                    "0.0 Kg",
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue),
                                  )
                                ],
                              ),
                            ),
                            Container(
                              height: 100,
                              width: width(context) / 2.5,
                              decoration: BoxDecoration(
                                color: amber50,
                                shape: BoxShape.rectangle,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Panen Diterima",
                                    style: TextStyle(
                                        fontSize: 14, color: Colors.blue),
                                  ),
                                  Text(
                                    "0.0 Kg",
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue),
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Mangkok",
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.blue),
                            ),
                            Text(
                              '${data[0]['bowl'].toString()} Kg',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.blue),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Sudut",
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.amber),
                            ),
                            Text(
                              '${data[0]['corner'].toString()} Kg',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.amber),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Oval",
                              style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
                                  color: Colors.blue),
                            ),
                            Text(
                              '${data[0]['oval'].toString()} Kg',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
                                  color: Colors.blue),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Fault",
                              style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
                                  color: Colors.red),
                            ),
                            Text(
                              '${data[0]['fault'].toString()} Kg',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
                                  color: Colors.red),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              ],
            );
          }
        },
      ),
    );
  }
}
