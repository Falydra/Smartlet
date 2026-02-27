import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:swiftlead/services/harvest_services.dart';
import 'package:swiftlead/services/sensor_services.dart';
import 'package:swiftlead/services/house_services.dart';
import 'package:swiftlead/services/node_service.dart';
import 'package:swiftlead/utils/token_manager.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final HarvestService _harvestService = HarvestService();
  final SensorService _sensorService = SensorService();
  final HouseService _houseService = HouseService();
  final NodeService _nodeService = NodeService();
  
  String? _authToken;
  bool _isLoading = false;
  bool _isGenerating = false;
  

  String _reportType = 'harvest'; // 'harvest' or 'sensor'
  

  String _timePeriod = 'monthly'; // 'daily', 'weekly', 'monthly', 'annual'
  

  DateTime _selectedDate = DateTime.now();
  DateTime? _startDate;
  DateTime? _endDate;
  

  List<dynamic> _houses = [];
  Map<String, dynamic>? _selectedHouse;
  

  List<dynamic> _harvestData = [];
  Map<String, List<dynamic>> _sensorData = {};
  
  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }
  
  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    
    try {
      _authToken = await TokenManager.getToken();
      
      if (_authToken != null) {
        await _loadHouses();
      }
    } catch (e) {
      print('Error loading initial data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _loadHouses() async {
    try {
      final houses = await _houseService.getAll(_authToken!);
      setState(() {
        _houses = houses;
        if (_houses.isNotEmpty) {
          _selectedHouse = _houses.first as Map<String, dynamic>?;
        }
      });
    } catch (e) {
      print('Error loading houses: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading houses: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  Future<void> _loadReportData() async {
    if (_authToken == null || _selectedHouse == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      _calculateDateRange();
      
      if (_reportType == 'harvest') {
        await _loadHarvestData();
      } else {
        await _loadSensorData();
      }
    } catch (e) {
      print('Error loading report data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  void _calculateDateRange() {
    final now = _selectedDate;
    
    switch (_timePeriod) {
      case 'daily':
        _startDate = DateTime(now.year, now.month, now.day);
        _endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'weekly':
        final weekday = now.weekday;
        _startDate = now.subtract(Duration(days: weekday - 1));
        _endDate = _startDate!.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
        break;
      case 'monthly':
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
        break;
      case 'annual':
        _startDate = DateTime(now.year, 1, 1);
        _endDate = DateTime(now.year, 12, 31, 23, 59, 59);
        break;
    }
  }
  
  Future<void> _loadHarvestData() async {
    try {
      final rbwId = _selectedHouse!['id'].toString();
      
      final response = await _harvestService.getAll(
        _authToken!,
        rbwId: rbwId,
        limit: 1000,
      );
      

      final filtered = response.where((harvest) {
        try {
          if (harvest['harvested_at'] == null) return false;
          final harvestedAt = DateTime.parse(harvest['harvested_at']);
          return harvestedAt.isAfter(_startDate!) && harvestedAt.isBefore(_endDate!);
        } catch (e) {
          print('Error parsing harvest date: $e');
          return false;
        }
      }).toList();
      
      setState(() => _harvestData = filtered);
    } catch (e) {
      print('Error loading harvest data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  Future<void> _loadSensorData() async {
    try {
      final rbwId = _selectedHouse!['id'].toString();
      

      final nodesResponse = await _nodeService.listByRbw(_authToken!, rbwId);
      
      if (nodesResponse['success'] == true && nodesResponse['data'] != null) {
        final nodes = nodesResponse['data'] as List<dynamic>;
        
        _sensorData.clear();
        
        for (final node in nodes) {
          final sensors = node['sensors'] as List<dynamic>?;
          
          if (sensors != null) {
            for (final sensor in sensors) {
              final sensorId = sensor['id'].toString();
              final sensorType = sensor['sensor_type']?.toString() ?? 'unknown';
              
              try {
                final readingsResponse = await _sensorService.getReadings(
                  _authToken!,
                  sensorId,
                  queryParams: {
                    'limit': '1000',
                    'start_date': _startDate!.toIso8601String(),
                    'end_date': _endDate!.toIso8601String(),
                  },
                );
                
                if (readingsResponse['data'] is List) {
                  if (_sensorData[sensorType] == null) {
                    _sensorData[sensorType] = [];
                  }
                  _sensorData[sensorType]!.addAll(readingsResponse['data']);
                }
              } catch (e) {
                print('Error loading sensor $sensorId: $e');
              }
            }
          }
        }
        
        setState(() {});
      }
    } catch (e) {
      print('Error loading sensor data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading sensor: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  Future<void> _generatePDF() async {
    if (_authToken == null || _selectedHouse == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih kandang terlebih dahulu'), backgroundColor: Colors.orange),
        );
      }
      return;
    }
    

    if (_startDate == null || _endDate == null) {
      _calculateDateRange();
    }
    

    if (_reportType == 'harvest' && _harvestData.isEmpty) {
      await _loadReportData();
      if (_harvestData.isEmpty) {
        setState(() => _isGenerating = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tidak ada data panen untuk periode ini'), backgroundColor: Colors.orange),
          );
        }
        return;
      }
    } else if (_reportType == 'sensor' && _sensorData.isEmpty) {
      await _loadReportData();
      if (_sensorData.isEmpty) {
        setState(() => _isGenerating = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tidak ada data sensor untuk periode ini'), backgroundColor: Colors.orange),
          );
        }
        return;
      }
    }
    
    setState(() => _isGenerating = true);
    
    try {
      final pdf = pw.Document();
      
      if (_reportType == 'harvest') {
        _addHarvestReportPages(pdf);
      } else {
        _addSensorReportPages(pdf);
      }
      

      final output = await getTemporaryDirectory();
      final fileName = '${_reportType}_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final file = File('${output.path}/$fileName');
      await file.writeAsBytes(await pdf.save());
      
      setState(() => _isGenerating = false);
      

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Laporan berhasil dibuat: $fileName'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Buka',
              textColor: Colors.white,
              onPressed: () => OpenFile.open(file.path),
            ),
          ),
        );
      }
      

      await OpenFile.open(file.path);
      
    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  void _addHarvestReportPages(pw.Document pdf) {
    final houseName = _selectedHouse!['name'] ?? 'Unknown';
    final dateRangeStr = '${DateFormat('dd MMM yyyy').format(_startDate!)} - ${DateFormat('dd MMM yyyy').format(_endDate!)}';
    

    int totalNests = 0;
    double totalWeight = 0.0;
    final Map<String, int> gradeCount = {};
    final Map<int, int> floorCount = {};
    
    for (final harvest in _harvestData) {
      totalNests += (harvest['nests_count'] ?? 0) as int;
      totalWeight += ((harvest['weight_kg'] ?? 0.0) as num).toDouble();
      
      final grade = harvest['grade']?.toString() ?? 'Unknown';
      gradeCount[grade] = (gradeCount[grade] ?? 0) + 1;
      
      final floor = (harvest['floor_no'] ?? 0) as int;
      floorCount[floor] = (floorCount[floor] ?? 0) + 1;
    }
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [

          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'LAPORAN PANEN',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Text('Kandang: $houseName', style: const pw.TextStyle(fontSize: 14)),
                pw.Text('Periode: $dateRangeStr', style: const pw.TextStyle(fontSize: 14)),
                pw.Text('Jenis Laporan: ${_getPeriodLabel()}', style: const pw.TextStyle(fontSize: 14)),
                pw.Text('Tanggal Cetak: ${DateFormat('dd MMMM yyyy HH:mm').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 12)),
                pw.Divider(),
              ],
            ),
          ),
          

          pw.Header(
            level: 1,
            child: pw.Text('Ringkasan', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryBox('Total Panen', _harvestData.length.toString()),
              _buildSummaryBox('Total Sarang', totalNests.toString()),
              _buildSummaryBox('Total Berat', '${totalWeight.toStringAsFixed(2)} kg'),
            ],
          ),
          pw.SizedBox(height: 20),
          

          if (gradeCount.isNotEmpty) ...[
            pw.Header(
              level: 1,
              child: pw.Text('Distribusi Kualitas', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['Kualitas', 'Jumlah', 'Persentase'],
              data: gradeCount.entries.map((e) {
                final percentage = (_harvestData.length > 0) 
                    ? (e.value / _harvestData.length * 100).toStringAsFixed(1)
                    : '0.0';
                return [e.key, e.value.toString(), '$percentage%'];
              }).toList(),
            ),
            pw.SizedBox(height: 20),
          ],
          

          if (floorCount.isNotEmpty) ...[
            pw.Header(
              level: 1,
              child: pw.Text('Distribusi Per Lantai', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headers: ['Lantai', 'Jumlah Panen'],
              data: floorCount.entries.map((e) => [
                'Lantai ${e.key}',
                e.value.toString(),
              ]).toList(),
            ),
            pw.SizedBox(height: 20),
          ],
          

          pw.Header(
            level: 1,
            child: pw.Text('Detail Panen', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 10),
          pw.Table.fromTextArray(
            headers: ['Tanggal', 'Lantai', 'Sarang', 'Berat (kg)', 'Kualitas'],
            data: _harvestData.map((h) => [
              DateFormat('dd/MM/yyyy').format(DateTime.parse(h['harvested_at'])),
              (h['floor_no'] ?? '-').toString(),
              (h['nests_count'] ?? 0).toString(),
              ((h['weight_kg'] ?? 0.0) as num).toStringAsFixed(2),
              h['grade']?.toString() ?? '-',
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellHeight: 30,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.center,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.center,
            },
          ),
        ],
      ),
    );
  }
  
  void _addSensorReportPages(pw.Document pdf) {
    final houseName = _selectedHouse!['name'] ?? 'Unknown';
    final dateRangeStr = '${DateFormat('dd MMM yyyy').format(_startDate!)} - ${DateFormat('dd MMM yyyy').format(_endDate!)}';
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [

          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'LAPORAN SENSOR',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 10),
                pw.Text('Kandang: $houseName', style: const pw.TextStyle(fontSize: 14)),
                pw.Text('Periode: $dateRangeStr', style: const pw.TextStyle(fontSize: 14)),
                pw.Text('Jenis Laporan: ${_getPeriodLabel()}', style: const pw.TextStyle(fontSize: 14)),
                pw.Text('Tanggal Cetak: ${DateFormat('dd MMMM yyyy HH:mm').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 12)),
                pw.Divider(),
              ],
            ),
          ),
          

          if (_sensorData['temperature'] != null && _sensorData['temperature']!.isNotEmpty) ...[
            pw.Header(
              level: 1,
              child: pw.Text('Suhu (Temperature)', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 10),
            ..._buildSensorSection(_sensorData['temperature']!, 'Suhu', '°C'),
          ],
          

          if (_sensorData['humidity'] != null && _sensorData['humidity']!.isNotEmpty) ...[
            pw.Header(
              level: 1,
              child: pw.Text('Kelembapan (Humidity)', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 10),
            ..._buildSensorSection(_sensorData['humidity']!, 'Kelembapan', '%'),
          ],
          

          if (_sensorData['ammonia'] != null && _sensorData['ammonia']!.isNotEmpty) ...[
            pw.Header(
              level: 1,
              child: pw.Text('Amonia (Ammonia)', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 10),
            ..._buildSensorSection(_sensorData['ammonia']!, 'Amonia', 'ppm'),
          ],
        ],
      ),
    );
  }
  
  List<pw.Widget> _buildSensorSection(List<dynamic> readings, String label, String unit) {
    if (readings.isEmpty) return [];
    

    final values = readings.map((r) => ((r['value'] ?? 0.0) as num).toDouble()).toList();
    final avg = values.reduce((a, b) => a + b) / values.length;
    final max = values.reduce((a, b) => a > b ? a : b);
    final min = values.reduce((a, b) => a < b ? a : b);
    
    return [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryBox('Rata-rata', '${avg.toStringAsFixed(2)} $unit'),
          _buildSummaryBox('Maksimum', '${max.toStringAsFixed(2)} $unit'),
          _buildSummaryBox('Minimum', '${min.toStringAsFixed(2)} $unit'),
        ],
      ),
      pw.SizedBox(height: 10),
      pw.Text('Total Pembacaan: ${readings.length}', style: const pw.TextStyle(fontSize: 12)),
      pw.SizedBox(height: 20),
    ];
  }
  
  pw.Widget _buildSummaryBox(String title, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        children: [
          pw.Text(title, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
          pw.SizedBox(height: 5),
          pw.Text(value, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
  
  String _getPeriodLabel() {
    switch (_timePeriod) {
      case 'daily':
        return 'Harian';
      case 'weekly':
        return 'Mingguan';
      case 'monthly':
        return 'Bulanan';
      case 'annual':
        return 'Tahunan';
      default:
        return 'Unknown';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan'),
        backgroundColor: const Color(0xFF245C4C),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const Text(
                    'Buat Laporan',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pilih jenis laporan dan periode waktu untuk menghasilkan laporan PDF',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  

                  _buildSectionCard(
                    title: 'Pilih Kandang',
                    child: DropdownButtonFormField<Map<String, dynamic>>(
                      value: _selectedHouse,
                      decoration: _inputDecoration('Kandang'),
                      items: _houses.map<DropdownMenuItem<Map<String, dynamic>>>((house) {
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: house as Map<String, dynamic>,
                          child: Text(house['name'] ?? 'Unknown'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedHouse = value);
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  

                  _buildSectionCard(
                    title: 'Jenis Laporan',
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          title: const Text('Laporan Panen'),
                          subtitle: const Text('Data panen sarang burung walet'),
                          value: 'harvest',
                          groupValue: _reportType,
                          onChanged: (value) => setState(() => _reportType = value!),
                          activeColor: const Color(0xFF245C4C),
                        ),
                        RadioListTile<String>(
                          title: const Text('Laporan Sensor'),
                          subtitle: const Text('Data suhu, kelembapan, dan amonia'),
                          value: 'sensor',
                          groupValue: _reportType,
                          onChanged: (value) => setState(() => _reportType = value!),
                          activeColor: const Color(0xFF245C4C),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  

                  _buildSectionCard(
                    title: 'Periode Waktu',
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          title: const Text('Harian'),
                          value: 'daily',
                          groupValue: _timePeriod,
                          onChanged: (value) => setState(() => _timePeriod = value!),
                          activeColor: const Color(0xFF245C4C),
                        ),
                        RadioListTile<String>(
                          title: const Text('Mingguan'),
                          value: 'weekly',
                          groupValue: _timePeriod,
                          onChanged: (value) => setState(() => _timePeriod = value!),
                          activeColor: const Color(0xFF245C4C),
                        ),
                        RadioListTile<String>(
                          title: const Text('Bulanan'),
                          value: 'monthly',
                          groupValue: _timePeriod,
                          onChanged: (value) => setState(() => _timePeriod = value!),
                          activeColor: const Color(0xFF245C4C),
                        ),
                        RadioListTile<String>(
                          title: const Text('Tahunan'),
                          value: 'annual',
                          groupValue: _timePeriod,
                          onChanged: (value) => setState(() => _timePeriod = value!),
                          activeColor: const Color(0xFF245C4C),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  

                  _buildSectionCard(
                    title: 'Pilih Tanggal',
                    child: ListTile(
                      leading: const Icon(Icons.calendar_today, color: Color(0xFF245C4C)),
                      title: Text(DateFormat('dd MMMM yyyy').format(_selectedDate)),
                      trailing: const Icon(Icons.edit),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() => _selectedDate = date);
                        }
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _selectedHouse == null || _isLoading
                              ? null
                              : _loadReportData,
                          icon: const Icon(Icons.preview),
                          label: const Text('Muat Data'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _selectedHouse == null || _isGenerating
                              ? null
                              : _generatePDF,
                          icon: _isGenerating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.picture_as_pdf),
                          label: Text(_isGenerating ? 'Membuat...' : 'Buat PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF245C4C),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  

                  if (_reportType == 'harvest' && _harvestData.isNotEmpty) ...[
                    _buildPreviewSection(),
                  ] else if (_reportType == 'sensor' && _sensorData.isNotEmpty) ...[
                    _buildSensorPreviewSection(),
                  ],
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
  
  Widget _buildSectionCard({required String title, required Widget child}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF245C4C),
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
  
  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
  
  Widget _buildPreviewSection() {
    final totalNests = _harvestData.fold<int>(
      0,
      (sum, h) => sum + ((h['nests_count'] ?? 0) as int),
    );
    final totalWeight = _harvestData.fold<double>(
      0.0,
      (sum, h) => sum + ((h['weight_kg'] ?? 0.0) as num).toDouble(),
    );
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Preview Data',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatCard('Total Panen', _harvestData.length.toString(), Icons.calendar_today),
                _buildStatCard('Total Sarang', totalNests.toString(), Icons.grid_on),
                _buildStatCard('Total Berat', '${totalWeight.toStringAsFixed(1)} kg', Icons.scale),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSensorPreviewSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Preview Data Sensor',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._sensorData.entries.map((entry) {
              final type = entry.key;
              final readings = entry.value;
              final count = readings.length;
              
              String label = type;
              IconData icon = Icons.devices;
              
              if (type == 'temperature') {
                label = 'Suhu';
                icon = Icons.thermostat;
              } else if (type == 'humidity') {
                label = 'Kelembapan';
                icon = Icons.water_drop;
              } else if (type == 'ammonia') {
                label = 'Amonia';
                icon = Icons.science;
              }
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(icon, color: const Color(0xFF245C4C)),
                    const SizedBox(width: 12),
                    Text('$label: $count pembacaan'),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatCard(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 32, color: const Color(0xFF245C4C)),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
