import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TempPage extends StatefulWidget {
  const TempPage({Key? key}) : super(key: key);

  @override
  _TempPageState createState() => _TempPageState();
}

class _TempPageState extends State<TempPage> {
  late FirebaseFirestore _firestore;
  late Stream<DocumentSnapshot>? _temperatureStream;

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
  }

  Future<void> _initializeFirebase() async {
    await Firebase.initializeApp();
    _firestore = FirebaseFirestore.instance;
    _temperatureStream =
        _firestore.collection('temperatures').doc('atuy@gmail.com').snapshots();
    setState(() {}); // Trigger a rebuild after initialization
  }

  @override
  Widget build(BuildContext context) {
    if (_temperatureStream == null) {
      // Stream is not initialized yet, return loading indicator or other widget
      return CircularProgressIndicator();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Temperature Page'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _temperatureStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return CircularProgressIndicator();
          } else if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          } else if (!snapshot.hasData || !snapshot.data!.exists) {
            return Text('Data not available');
          } else {
            int celcius = snapshot.data!.get('celcius');
            Timestamp dateTimestamp = snapshot.data!.get('date');
            DateTime date = dateTimestamp.toDate();

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Current Temperature: $celcius °C'),
                  Text(
                      'Date: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(date)}'),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}
