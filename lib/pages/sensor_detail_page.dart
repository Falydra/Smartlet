import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:swiftlead/services/sensor_services.dart';
import 'package:swiftlead/utils/token_manager.dart';
import 'package:swiftlead/components/custom_bottom_navigation.dart';
import 'package:swiftlead/utils/time_utils.dart';

class SensorDetailPage extends StatefulWidget {
  const SensorDetailPage({super.key});

  @override
  State<SensorDetailPage> createState() => _SensorDetailPageState();
}

class _SensorDetailPageState extends State<SensorDetailPage> {
  final SensorService _sensorService = SensorService();
  String? _token;
  final Color _primary = const Color(0xFF245C4C);
  int _currentIndex = 1; // highlight Control tab by default

  // Route args - use safe defaults to avoid late init errors
  String sensorId = '';
  String metric = 'sensor'; // temperature | humidity | ammonia
  String title = 'Sensor'; // e.g., Suhu, Kelembapan, Amonia
  String unit = '';
  int? floor; // optional
  bool _argsInitialized = false;

  // UI State
  String _range = '1D'; // 1D | 1W | 1M
  bool _loading = true;
  List<FlSpot> _points = [];
  double? _latestValue;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Defer reading arguments until context is available
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _initializeFromRoute();
    });
  }

  Future<void> _initializeFromRoute() async {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      setState(() {
        sensorId = args['sensorId']?.toString() ?? '';
        metric = (args['metric'] ?? 'sensor').toString();
        title = (args['title'] ?? 'Sensor').toString();
        unit = (args['unit'] ?? '').toString();
        floor = args['floor'] is int ? args['floor'] as int : null;
        _argsInitialized = true;
      });
    } else {
      setState(() {
        _argsInitialized = true;
      });
    }
    _token = await TokenManager.getToken();
    if (sensorId.isNotEmpty) {
      await _loadData();
      _startAutoRefresh();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _loadData());
  }

  int _limitForRange(String r) {
    switch (r) {
      case '1W':
        return 1200; // about a week at ~5-10min steps (approx, backend-driven)
      case '1M':
        return 2000; // cap to prevent huge payloads
      case '1D':
      default:
        return 400; // ~1 day
    }
  }

  Future<void> _loadData() async {
    if (_token == null || sensorId.isEmpty) return;
    if(mounted){
      setState(() {
        _loading = true;
      });
    }
    try {
      final res = await _sensorService.getReadings(
        _token!,
        sensorId,
        queryParams: {
          'limit': _limitForRange(_range).toString(),
        },
      );
      final list = (res['data'] is List) ? List<Map<String, dynamic>>.from(res['data']) : <Map<String, dynamic>>[];
      // Sort by time ascending for LineChart
      list.sort((a, b) {
        final ta = DateTime.tryParse(a['recorded_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        final tb = DateTime.tryParse(b['recorded_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
        return ta.compareTo(tb);
      });
      final points = <FlSpot>[];
      for (final r in list) {
        final ts = DateTime.tryParse(r['recorded_at']?.toString() ?? '');
        final v = (r['value'] as num?)?.toDouble();
        if (ts != null && v != null) {
          // Keep absolute instant; convert only for display
          points.add(FlSpot(ts.millisecondsSinceEpoch.toDouble(), v));
        }
      }
      final latest = list.isNotEmpty ? list.last : null;
      setState(() {
        _points = points;
        _latestValue = (latest?['value'] as num?)?.toDouble();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat data: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Guard against building before route args are initialized
    if (!_argsInitialized) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: _primary,
          elevation: 0,
          title: const Text('Loading...'),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.95),
                  Colors.white.withOpacity(0.8),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
        body: Center(child: CircularProgressIndicator(color: _primary)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: _primary,
        elevation: 0,
        title: Text('$title${floor != null ? ' • Lantai $floor' : ''}'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.95),
                Colors.white.withOpacity(0.8),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            _rangeTabs(),
            // Limit chart to ~45% of screen height, not full expanded
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.38,
              child: _chartCard(),
            ),
            _actionBar(),
          ],
        ),
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
                  setState(() { _currentIndex = 0; });
                },
              ),
              label: ''),
          BottomNavigationBarItem(
              icon: CustomBottomNavigationItem(
                icon: Icons.electrical_services_sharp,
                label: 'Kontrol',
                currentIndex: _currentIndex,
                itemIndex: 1,
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/control-page');
                  setState(() { _currentIndex = 1; });
                },
              ),
              label: ''),
          BottomNavigationBarItem(
              icon: CustomBottomNavigationItem(
                icon: Icons.agriculture,
                label: 'Panen',
                currentIndex: _currentIndex,
                itemIndex: 2,
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/harvest/analysis');
                  setState(() { _currentIndex = 2; });
                },
              ),
              label: ''),
          BottomNavigationBarItem(
              icon: CustomBottomNavigationItem(
                icon: Icons.sell,
                label: 'Jual',
                currentIndex: _currentIndex,
                itemIndex: 3,
                onTap: () {
                  Navigator.pushReplacementNamed(context, '/store-page');
                  setState(() { _currentIndex = 3; });
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
                  setState(() { _currentIndex = 4; });
                },
              ),
              label: ''),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: TextStyle(color: _primary.withOpacity(0.7), fontSize: 12, letterSpacing: 1)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _latestValue?.toString() ?? '-',
                style: TextStyle(color: _primary, fontSize: 40, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(unit, style: const TextStyle(color: Colors.black54, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _chip('Realtime'),
              const SizedBox(width: 8),
              if (floor != null) _chip('Lantai $floor'),
            ],
          )
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primary.withOpacity(0.2)),
      ),
      child: Text(text, style: TextStyle(color: _primary, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _rangeTabs() {
    final ranges = ['1D','1W','1M'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: ranges.map((r) {
          final selected = _range == r;
          return Expanded(
            child: GestureDetector(
              onTap: () async {
                setState(() {
                  _range = r;
                });
                await _loadData();
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? _primary.withOpacity(0.12) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: selected ? _primary : Colors.grey[300]!),
                ),
                alignment: Alignment.center,
                child: Text(
                  r,
                  style: TextStyle(color: selected ? _primary : Colors.black54, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _chartCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: _loading
          ? Center(child: CircularProgressIndicator(color: _primary, strokeWidth: 2))
          : _points.isEmpty
              ? const Center(child: Text('Tidak ada data', style: TextStyle(color: Colors.black45)))
              : LineChart(
                  LineChartData(
                    minX: _points.first.x,
                    maxX: _points.last.x,
                    gridData: FlGridData(show: true, horizontalInterval: 1, drawVerticalLine: false, getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey[300]!, strokeWidth: 1)),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 36, getTitlesWidget: (v, _) => Text(v.toStringAsFixed(0), style: const TextStyle(color: Colors.black38, fontSize: 10)))),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 26, interval: (_points.last.x - _points.first.x) / 4, getTitlesWidget: (x, _) {
                        final utc = DateTime.fromMillisecondsSinceEpoch(x.toInt(), isUtc: true);
                        final wib = TimeUtils.toWIB(utc);
                        final hh = wib.hour.toString().padLeft(2, '0');
                        return Text(hh, style: const TextStyle(color: Colors.black38, fontSize: 10));
                      })),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    lineTouchData: LineTouchData(
                      enabled: true,
                      handleBuiltInTouches: true,
                      touchTooltipData: LineTouchTooltipData(
                       
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        getTooltipItems: (spots) {
                          return spots.map((s) {
                            final utc = DateTime.fromMillisecondsSinceEpoch(s.x.toInt(), isUtc: true);
                            final wib = TimeUtils.toWIB(utc);
                            final hh = wib.hour.toString().padLeft(2, '0');
                            final mm = wib.minute.toString().padLeft(2, '0');
                            return LineTooltipItem(
                              '${s.y}\u0020$unit\n$hh:$mm',
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey[300]!)),
                    lineBarsData: [
                      LineChartBarData(
                        spots: _points,
                        isCurved: true,
                        color: _primary,
                        barWidth: 2,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(show: true, color: _primary.withOpacity(0.12)),
                      )
                    ],
                  ),
                ),
    );
  }

  Widget _actionBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _loading ? null : _loadData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(_loading ? 'Loading...' : 'Refresh', style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
