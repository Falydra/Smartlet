import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class Monitoring extends StatefulWidget {
  final FirebaseDatabase secondaryDatabase;

  const Monitoring({super.key, required this.secondaryDatabase});

  @override
  State<Monitoring> createState() => _MonitoringState();
}

class _MonitoringState extends State<Monitoring> {
  late DatabaseReference databaseRef;

  @override
  void initState() {
    super.initState();

    databaseRef = widget.secondaryDatabase.ref().child('device/032-02-0821');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Firebase Monitoring"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder(
          stream: databaseRef.onValue,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red, fontSize: 18),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasData) {
              final event = snapshot.data as DatabaseEvent;
              final data = event.snapshot.value;

              return Center(
                child: Text(
                  data != null ? data.toString() : "No data available",
                  style: const TextStyle(fontSize: 20),
                ),
              );
            }

            return const Center(
              child: Text("No data received"),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          try {

            await databaseRef.push().set("Hello from Flutter!");
            print('Data written to Firebase');
          } catch (e) {
            print('Error writing to Firebase: $e');
          }
        },
        child: const Icon(Icons.send),
      ),
    );
  }
}
