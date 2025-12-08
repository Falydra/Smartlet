import 'package:flutter/material.dart';

class TempPage extends StatelessWidget {
  const TempPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Suhu & Kelembaban')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Suhu & Kelembaban (Firestore) telah dihapus.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Fitur ini sekarang harus diambil dari API. Hubungi backend atau implementasikan endpoint yang sesuai.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Kembali'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
