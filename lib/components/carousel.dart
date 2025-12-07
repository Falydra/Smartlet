import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart' as cs;

final List<Map<String, dynamic>> contentList = [
  {
    'quarter': 'Q1 Jan - Mar',
    'date': '14 Feb 2024',
    'price': 'Rp5.850.000/kg',
    'pest': '28%',
    'temperature': '32°C',
    'humidity': 'Sedang',
    'security': '24%',
  },
  {
    'quarter': 'Q2 Apr - Jun',
    'date': '15 May 2024',
    'price': 'Rp6.200.000/kg',
    'pest': '25%',
    'temperature': '30°C',
    'humidity': 'Tinggi',
    'security': '30%',
  },
  {
    'quarter': 'Q3 Jul - Sep',
    'date': '16 Aug 2024',
    'price': 'Rp6.500.000/kg',
    'pest': '20%',
    'temperature': '28°C',
    'humidity': 'Rendah',
    'security': '35%',
  },
];

class CarouselHome extends StatelessWidget {
  const CarouselHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: CarouselWithIndicatorDemo());
  }
}

class CarouselWithIndicatorDemo extends StatefulWidget {
  const CarouselWithIndicatorDemo({super.key});

  @override
  State<StatefulWidget> createState() {
    return _CarouselWithIndicatorState();
  }
}

class _CarouselWithIndicatorState extends State<CarouselWithIndicatorDemo> {
  int _current = 0;
  final cs.CarouselController _controller = cs.CarouselController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Builder(
          builder: (context) {
            final double height = MediaQuery.of(context).size.height;

            return Stack(
              children: [
                cs.CarouselSlider(
                  carouselController: _controller,
                  items: contentList
                      .map(
                        (item) => Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.symmetric(vertical: 16.0),
                          decoration: BoxDecoration(
                            color: Colors.yellow[100],
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(2, 2),
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  item['quarter'],
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item['date'],
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item['price'],
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Rata-rata Statistik perangkat',
                                  style: TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    statBox('Hama', item['pest']),
                                    statBox('Suhu', item['temperature']),
                                    statBox('Kelembaban', item['humidity']),
                                    statBox('Keamanan', item['security']),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () {},
                                  child: const Text('Lihat Analisis Panen'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  options: cs.CarouselOptions(
                    height: height,
                    viewportFraction: 0.9,
                    enlargeCenterPage: true,
                    onPageChanged: (index, reason) {
                      setState(() {
                        _current = index;
                      });
                    },
                  ),
                ),
                Positioned(
                  bottom: 20.0,
                  left: 0.0,
                  right: 0.0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: contentList.asMap().entries.map((entry) {
                      return GestureDetector(
                        onTap: () => _controller.animateToPage(entry.key),
                        child: Container(
                          width: 12.0,
                          height: 12.0,
                          margin: const EdgeInsets.symmetric(
                              vertical: 8.0, horizontal: 4.0),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black)
                                .withOpacity(_current == entry.key ? 0.9 : 0.4),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget statBox(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}

void main() {
  runApp(const MaterialApp(home: CarouselHome()));
}
