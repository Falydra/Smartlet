import 'package:flutter/material.dart';



class Carousel extends StatelessWidget {
  double width(BuildContext context) => MediaQuery.of(context).size.width;
  double height(BuildContext context) => MediaQuery.of(context).size.height;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            contentContainer(
              quarter: 'Q1 Jan - Mar',
              date: '14 Feb 2024',
              price: 'Rp5.850.000/kg',
              pest: '28%',
              temperature: '32°C',
              humidity: 'Sedang',
              security: '24%',
            ),
            SizedBox(height: 16),
            contentContainer(
              quarter: 'Q2 Apr - Jun',
              date: '15 May 2024',
              price: 'Rp6.200.000/kg',
              pest: '25%',
              temperature: '30°C',
              humidity: 'Tinggi',
              security: '30%',
            ),
          ],
        ),
      ),
    );
  }

  Widget contentContainer({
    required String quarter,
    required String date,
    required String price,
    required String pest,
    required String temperature,
    required String humidity,
    required String security,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.yellow[100],
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(2, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(quarter, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 4),
          Text(date, style: TextStyle(color: Colors.grey)),
          SizedBox(height: 8),
          Text(price, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text('Rata-rata Statistik perangkat', style: TextStyle(fontSize: 16)),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              statBox('Hama', pest),
              statBox('Suhu', temperature),
              statBox('Kelembaban', humidity),
              statBox('Keamanan', security),
            ],
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {},
            child: Text('Lihat Analisis Panen'),
          ),
        ],
      ),
    );
  }

  Widget statBox(String label, String value) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.grey)),
      ],
    );
  }
}
