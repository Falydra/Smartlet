import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swiftlead/components/custom_bottom_navigation.dart';
import 'package:swiftlead/pages/cage_selection_page.dart';

class ControlPage extends StatefulWidget {
  const ControlPage({Key? key}) : super(key: key);

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage> {
  int _currentIndex = 3;

  // Selected cage info (template, loaded from SharedPreferences)
  String _cageName = 'Kandang 1';
  String _cageAddress = 'Alamat kandang belum diisi';
  int _cageFloors = 3;

  // Environment metrics state (template for backend fetch)
  late _MetricState tempState;
  late _MetricState humidityState;
  late _MetricState ammoniaState;

  // Sistem Suara and Water Level per floor (template)
  late List<_FloorStatus> soundSystem;
  late List<_MetricState> waterLevelPerFloor;

  @override
  void initState() {
    super.initState();
    _loadCageData();
    _initDemoData();
  }

  Future<void> _loadCageData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _cageName = prefs.getString('cage_name') ?? 'Kandang 1';
        _cageAddress =
            prefs.getString('cage_address') ?? 'Alamat kandang belum diisi';
        _cageFloors = prefs.getInt('cage_floors') ?? 3;
      });
      // Rebuild per-floor lists when floors change
      _initPerFloorLists();
    } catch (_) {
      // Use defaults on failure
      _initPerFloorLists();
    }
  }

  void _initPerFloorLists() {
    soundSystem = List.generate(
      _cageFloors,
      (i) => _FloorStatus(
        floor: i + 1,
        active: i % 2 == 0,
        lastTime: _formatTime(DateTime.now()),
        condition: i % 3 == 0 ? 'Baik' : (i % 3 == 1 ? 'Normal' : 'Buruk'),
      ),
    );

    waterLevelPerFloor = List.generate(
      _cageFloors,
      (i) => _generateMetricState(
        name: 'Water Lvl Lantai ${i + 1}',
        minY: 0,
        maxY: 100,
        base: 60 + (i * 5),
        variance: 15,
        unit: '%',
        icon: Icons.water_drop,
        goodBad: (v) => _conditionForWater(v),
      ),
    );
  }

  void _initDemoData() {
    tempState = _generateMetricState(
      name: 'Suhu',
      minY: 20,
      maxY: 40,
      base: 28,
      variance: 4,
      unit: '°C',
      icon: Icons.thermostat,
      goodBad: (v) => _conditionForTemp(v),
    );

    humidityState = _generateMetricState(
      name: 'Kelembapan',
      minY: 30,
      maxY: 100,
      base: 75,
      variance: 10,
      unit: '%',
      icon: Icons.water_drop_outlined,
      goodBad: (v) => _conditionForHumidity(v),
    );

    ammoniaState = _generateMetricState(
      name: 'Amonia',
      minY: 0,
      maxY: 50,
      base: 8,
      variance: 6,
      unit: 'ppm',
      icon: Icons.science_outlined,
      goodBad: (v) => _conditionForAmmonia(v),
    );

    _initPerFloorLists();
  }

  // Template generator for 1-day data with 5-minute intervals
  _MetricState _generateMetricState({
    required String name,
    required double minY,
    required double maxY,
    required double base,
    required double variance,
    required String unit,
    required IconData icon,
    required String Function(double) goodBad,
  }) {
    final now = DateTime.now();
    // 24h * 12 points per hour = 288 points
    final points = <FlSpot>[];
    final rand = Random(name.hashCode ^ now.day ^ now.hour);
    final start = now.subtract(const Duration(hours: 24));
    for (int i = 0; i <= 288; i++) {
      final t = start.add(Duration(minutes: 5 * i));
      final x = t.millisecondsSinceEpoch.toDouble();
      final noise = (rand.nextDouble() * 2 - 1) * variance;
      double y = base + noise + sin(i / 14.0) * (variance / 2);
      y = y.clamp(minY, maxY);
      points.add(FlSpot(x, y));
    }
    final last = points.last.y;
    final timeStr = _formatTime(now);
    return _MetricState(
      name: name,
      icon: icon,
      unit: unit,
      minY: minY,
      maxY: maxY,
      points: points,
      currentValue: last,
      lastTime: timeStr,
      condition: goodBad(last),
    );
  }

  // Condition helpers
  String _conditionForTemp(double v) {
    if (v >= 26 && v <= 30) return 'Baik';
    if (v >= 24 && v <= 32) return 'Normal';
    return 'Buruk';
    // TODO: adjust thresholds per your domain
  }

  String _conditionForHumidity(double v) {
    if (v >= 70 && v <= 85) return 'Baik';
    if (v >= 60 && v <= 90) return 'Normal';
    return 'Buruk';
  }

  String _conditionForAmmonia(double v) {
    if (v < 10) return 'Baik';
    if (v < 20) return 'Normal';
    return 'Buruk';
  }

  String _conditionForWater(double v) {
    if (v >= 60) return 'Baik';
    if (v >= 40) return 'Normal';
    return 'Buruk';
  }

  String _formatTime(DateTime t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  // Navigate to cage selector, then reload cage data
  Future<void> _chooseCage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CageSelectionPage()),
    );
    await _loadCageData();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Kontrol'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF245C4C),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.95),
                Colors.white.withOpacity(0.8)
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kandang selector + separator + address
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _chooseCage,
                        icon: const Icon(Icons.business, size: 18),
                        label: Text(_cageName),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF245C4C),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      Container(
                        width: min(1, (width / 6))
                            .toDouble(), // visual separator dot if very small screen
                        height: 0,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    height: 1,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on,
                          color: Color(0xFF245C4C), size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _cageAddress,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 1: Environment Controls
            _sectionCard(
              title: 'Kontrol Lingkungan',
              child: Column(
                children: [
                  _metricRow(tempState),
                  const SizedBox(height: 12),
                  _metricRow(humidityState),
                  const SizedBox(height: 12),
                  _metricRow(ammoniaState),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 2: Sistem Suara per-floor
            _sectionCard(
              title: 'Sistem Suara',
              child: Column(
                children: [
                  for (final f in soundSystem) _soundRow(f),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 3: Water Level per-floor
            _sectionCard(
              title: 'Water Level',
              child: Column(
                children: [
                  for (final w in waterLevelPerFloor) ...[
                    _metricRow(w),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          switch (index) {
            case 0:
              Navigator.pushReplacementNamed(context, '/home-page');
              break;
            case 1:
              Navigator.pushReplacementNamed(context, '/monitoring-page');
              break;
            case 2:
              Navigator.pushReplacementNamed(context, '/analysis-page');
              break;
            case 3:
              // already here
              break;
            case 4:
              Navigator.pushReplacementNamed(context, '/profile-page');
              break;
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: CustomBottomNavigationItem(
              icon: Icons.home,
              label: 'Beranda',
              currentIndex: _currentIndex,
              itemIndex: 0,
              onTap: () =>
                  Navigator.pushReplacementNamed(context, '/home-page'),
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: CustomBottomNavigationItem(
              icon: Icons.store,
              label: 'Kontrol',
              currentIndex: _currentIndex,
              itemIndex: 1,
              onTap: () =>
                  Navigator.pushReplacementNamed(context, '/monitoring-page'),
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: CustomBottomNavigationItem(
              icon: Icons.pie_chart,
              label: 'Analisis',
              currentIndex: _currentIndex,
              itemIndex: 2,
              onTap: () =>
                  Navigator.pushReplacementNamed(context, '/analysis-page'),
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: CustomBottomNavigationItem(
              icon: Icons.dashboard_customize,
              label: 'Kontrol',
              currentIndex: _currentIndex,
              itemIndex: 3,
              onTap: () {},
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: CustomBottomNavigationItem(
              icon: Icons.person,
              label: 'Profil',
              currentIndex: _currentIndex,
              itemIndex: 4,
              onTap: () =>
                  Navigator.pushReplacementNamed(context, '/profile-page'),
            ),
            label: '',
          ),
        ],
      ),
    );
  }

  // UI helpers

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF245C4C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _metricRow(_MetricState m) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          // Left: icon + label + time
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFF245C4C).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(m.icon, color: const Color(0xFF245C4C), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF245C4C),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.access_time,
                              size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            m.lastTime,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Middle: 1-day line chart (5-min intervals)
          Expanded(
            flex: 4,
            child: SizedBox(
              height: 70,
              child: LineChart(
                LineChartData(
                  minY: m.minY,
                  maxY: m.maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (v, mctx) => Text(
                          v.toStringAsFixed(0),
                          style:
                              const TextStyle(fontSize: 8, color: Colors.grey),
                        ),
                        interval: (m.maxY - m.minY) / 2,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval:
                            (24 * 60 * 60 * 1000) / 4, // roughly 6h spacing
                        getTitlesWidget: (x, mctx) {
                          final d =
                              DateTime.fromMillisecondsSinceEpoch(x.toInt());
                          return Text('${d.hour}:00',
                              style: const TextStyle(
                                  fontSize: 8, color: Colors.grey));
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: m.points,
                      isCurved: true,
                      color: const Color(0xFF245C4C),
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFF245C4C).withOpacity(0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Right: current value + time, and condition chip
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${m.currentValue.toStringAsFixed(1)} ${m.unit}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF245C4C),
                  ),
                ),
                Text(
                  'Realtime ${m.lastTime}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                _conditionChip(m.condition),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _soundRow(_FloorStatus f) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          // Left: floor + status
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF245C4C).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.surround_sound,
                      color: Color(0xFF245C4C), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lantai ${f.floor}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF245C4C),
                        ),
                      ),
                      Text(
                        'Status: ${f.active ? 'active' : 'not'}',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Right: time + condition
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Icon(Icons.access_time, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(f.lastTime,
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 6),
                _conditionChip(f.condition),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _conditionChip(String condition) {
    Color bg;
    Color fg;
    switch (condition.toLowerCase()) {
      case 'baik':
      case 'good':
        bg = const Color(0xFF4CAF50).withOpacity(0.12);
        fg = const Color(0xFF2E7D32);
        break;
      case 'normal':
        bg = const Color(0xFFFFC107).withOpacity(0.12);
        fg = const Color(0xFF996C00);
        break;
      default: // 'buruk' or 'bad'
        bg = const Color(0xFFF44336).withOpacity(0.12);
        fg = const Color(0xFFB71C1C);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        condition[0].toUpperCase() + condition.substring(1).toLowerCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

// Data holders

class _MetricState {
  final String name;
  final IconData icon;
  final String unit;
  final double minY;
  final double maxY;
  final List<FlSpot> points;
  final double currentValue;
  final String lastTime;
  final String condition;

  _MetricState({
    required this.name,
    required this.icon,
    required this.unit,
    required this.minY,
    required this.maxY,
    required this.points,
    required this.currentValue,
    required this.lastTime,
    required this.condition,
  });
}

class _FloorStatus {
  final int floor;
  final bool active;
  final String lastTime;
  final String condition;

  _FloorStatus({
    required this.floor,
    required this.active,
    required this.lastTime,
    required this.condition,
  });
}

/*
TODO: Integrate backend data
- Replace _initDemoData and _generateMetricState with API or device reads.
- Update _loadCageData to use your cage data source (or keep SharedPreferences).
- Push/refresh per 5 minutes via timer or stream.
- For Sistem Suara and Water Level, fetch per-floor runtime state.
*/