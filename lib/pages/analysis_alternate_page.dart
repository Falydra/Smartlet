import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:graphic/graphic.dart' as graphic;
import 'package:swiftlead/shared/theme.dart';

class AnalysisPageAlternate extends StatefulWidget {
  const AnalysisPageAlternate({super.key});

  @override
  State<AnalysisPageAlternate> createState() => _AnalysisPageAlternateState();
}

class _AnalysisPageAlternateState extends State<AnalysisPageAlternate> {
  final TextEditingController _numFloorsController = TextEditingController();
  final TextEditingController _numRoomsController =
      TextEditingController(); // Second input
  final Map<int, TextEditingController> _floorControllers = {};

  double width(BuildContext context) => MediaQuery.of(context).size.width;
  double height(BuildContext context) => MediaQuery.of(context).size.height;

  Map<int, int> _floorBirds = {};
  Map<int, double> _pieData = {};
  Map<int, double> _remainingBirds = {};

  int _numFloors = 0;

  bool _showForm = false; // New state variable to show form
  bool _analysisDone = false; // New state variable for analysis done

  void _generateFloorInputs(int numFloors) {
    _floorControllers.clear();
    for (int i = 1; i <= numFloors; i++) {
      _floorControllers[i] = TextEditingController();
    }
  }

  void _analyzeData() {
    setState(() {
      _floorBirds = _floorControllers.map((key, controller) {
        return MapEntry(key, int.parse(controller.text.trim()));
      });

      _pieData = _floorBirds.map((key, value) {
        double savedBirds = value * 0.75;
        _remainingBirds[key] = value * 0.25;
        return MapEntry(key, savedBirds);
      });

      _analysisDone = true; // Set analysis done to true
    });
  }

  List<PieChartSectionData> _getPieSections() {
    return _pieData.entries.map((entry) {
      return PieChartSectionData(
        value: entry.value,
        title: '${entry.value.toStringAsFixed(1)}',
        color: _getColorForKey(entry.key), // Custom color function
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white, // Text color
        ),
      );
    }).toList();
  }

  Color _getColorForKey(int key) {
    switch (key) {
      case 1:
        return blue700;
      case 2:
        return sky700;
      case 3:
        return amber700;
      default:
        return red;
    }
  }

  List<Widget> _buildLegend() {
    String _getBelong(int key) {
      switch (key) {
        case 1:
          return "Mangkok";
        case 2:
          return "Sudut";
        case 3:
          return "Oval";
        default:
          return "Patahan";
      }
    }

    return _pieData.entries.map((entry) {
      return Padding(
        padding: EdgeInsets.only(
            top: height(context) * 0.01,
            left: width(context) * 0.045,
            right: width(context) * 0.045),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  '${_getBelong(entry.key)}',
                  style: TextStyle(
                      color: _getColorForKey(entry.key),
                      fontWeight: FontWeight.w500,
                      fontSize: 18),
                ),
              ],
            ),
            Row(
              children: [
                Text('${entry.value.toStringAsFixed(1)}',
                    style: TextStyle(
                        color: _getColorForKey(entry.key),
                        fontWeight: FontWeight.w500,
                        fontSize: 18)),
              ],
            )
          ],
        ),
      );
    }).toList();
  }

  double _getTotalSavedBirds() {
    return _pieData.values.fold(0.0, (sum, value) => sum + value);
  }

  List<Map<String, dynamic>> _getChartData() {
    return _pieData.entries.map((entry) {
      return {
        'floor': 'Lantai ${entry.key}',
        'savedBirds': entry.value,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis Page'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (!_showForm) ...[
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _showForm = true;
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text("Tambah Analisis Panen"),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                          vertical: height(context) * 0.02,
                          horizontal: width(context) * 0.05),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      backgroundColor:
                          const Color(0xFF0010A2), // Background color
                      foregroundColor: Colors.white, // Text color
                    ),
                  ),
                ),
              ],
              if (_showForm) ...[
                if (!_analysisDone) ...[
                  TextField(
                    controller: _numFloorsController,
                    decoration: const InputDecoration(
                      labelText: 'Masukkan Jumlah Lantai ',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        _numFloors = int.tryParse(value) ?? 0;
                        _generateFloorInputs(_numFloors);
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  const SizedBox(height: 10),
                  ..._floorControllers.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5.0),
                      child: TextField(
                        controller: entry.value,
                        decoration: InputDecoration(
                          labelText:
                              'Masukkan Jumlah burung di lantai ${entry.key}',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      _analyzeData();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                          vertical: height(context) * 0.015),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      backgroundColor:
                          const Color(0xFF0010A2), // Background color
                      foregroundColor: Colors.white, // Text color
                      minimumSize:
                          Size(width(context) * 0.25, height(context) * 0.07),
                    ),
                    child: const Text(
                      "Analisis",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        fontFamily: "TT Norms",
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                if (_pieData.isNotEmpty)
                  SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sections: _getPieSections(),
                        centerSpaceRadius: 40,
                        sectionsSpace: 4,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                if (_pieData.isNotEmpty)
                  Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.only(
                          top: height(context) * 0.03,
                          bottom: height(context) * 0.015,
                          left: width(context) * 0.045,
                          right: width(context) * 0.045,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              alignment: Alignment.center,
                              width: width(context) * 0.3,
                              height: height(context) * 0.1,
                              decoration: BoxDecoration(
                                color: amber50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('Panen Diterima',
                                      style: TextStyle(
                                          color: blue700,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14)),
                                  Text('${_getTotalSavedBirds() * 0.75}',
                                      style: TextStyle(
                                          color: blue700,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 18)),
                                ],
                              ),
                            ),
                            Container(
                              alignment: Alignment.center,
                              width: width(context) * 0.3,
                              height: height(context) * 0.1,
                              decoration: BoxDecoration(
                                color: sky50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('Sisa burung',
                                      style: TextStyle(
                                          color: amber700,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14)),
                                  Text('${_getTotalSavedBirds()}',
                                      style: TextStyle(
                                          color: amber700,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 18)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      ..._buildLegend(),
                    ],
                  ),
                const SizedBox(height: 40),
                if (_pieData.isNotEmpty)
                  SizedBox(
                    width: width(context) * 0.9,
                    height: 300,
                    child: graphic.Chart(
                      data: _getChartData(),
                      variables: {
                        'floor': graphic.Variable(
                          accessor: (Map map) => map['floor'] as String,
                        ),
                        'savedBirds': graphic.Variable(
                          accessor: (Map map) => map['savedBirds'] as num,
                        ),
                      },
                      marks: [
                        graphic.IntervalMark(
                          color: graphic.ColorEncode(
                              variable: 'floor',
                              values: [blue700, amber700, red]),
                          elevation: graphic.ElevationEncode(value: 0),
                        )
                      ],
                      axes: [
                        graphic.Defaults.horizontalAxis,
                        graphic.Defaults.verticalAxis,
                      ],
                    ),
                  ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
