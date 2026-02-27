import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swiftlead/services/house_services.dart';
import 'package:swiftlead/utils/token_manager.dart';

class EditCagePage extends StatefulWidget {
  final Map<String, dynamic> cage;

  const EditCagePage({super.key, required this.cage});

  @override
  State<EditCagePage> createState() => _EditCagePageState();
}

class _EditCagePageState extends State<EditCagePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _locationController;
  late TextEditingController _floorController;
  late TextEditingController _descriptionController;

  double? _lat;
  double? _lng;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final c = widget.cage;
    _nameController = TextEditingController(text: c['name']?.toString() ?? '');
    _codeController = TextEditingController(text: c['code']?.toString() ?? c['apiCode']?.toString() ?? '');
    _locationController = TextEditingController(text: c['address']?.toString() ?? '');
    _floorController = TextEditingController(text: (c['floors'] ?? c['total_floors'] ?? '').toString());
    _descriptionController = TextEditingController(text: c['description']?.toString() ?? '');
    _lat = (c['latitude'] is num) ? (c['latitude'] as num).toDouble() : (c['latitude'] != null ? double.tryParse(c['latitude'].toString()) : null);
    _lng = (c['longitude'] is num) ? (c['longitude'] as num).toDouble() : (c['longitude'] != null ? double.tryParse(c['longitude'].toString()) : null);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _locationController.dispose();
    _floorController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _openMapPicker() async {
    final LatLng? result = await Navigator.push<LatLng?>(
      context,
      MaterialPageRoute(builder: (context) => _MapPickerPage(initialPosition: LatLng(_lat ?? -6.2, _lng ?? 106.816666))),
    );

    if (result != null) {
      setState(() {
        _lat = result.latitude;
        _lng = result.longitude;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; });

    try {
      final token = await TokenManager.getToken();
      final parsedFloors = int.tryParse(_floorController.text.trim()) ?? 0;
      final payload = {
        'code': _codeController.text.trim(),
        'name': _nameController.text.trim(),
        'address': _locationController.text.trim(),
        'latitude': _lat,
        'longitude': _lng,
        'total_floors': parsedFloors,
        'description': _descriptionController.text.trim(),
      };


      if (widget.cage['isFromAPI'] == true && widget.cage['apiId'] != null && token != null) {
        final id = widget.cage['apiId'].toString();
        final hs = HouseService();
        final res = await hs.update(token, id, payload);
        if (res['success'] == true || res['data'] != null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perubahan berhasil disimpan'), backgroundColor: Colors.green));
          Navigator.of(context).pop(true); // signal success
          return;
        } else {
          final message = res['message'] ?? res['error'] ?? 'Failed to update';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan perubahan: $message'), backgroundColor: Colors.red));
          setState(() { _isLoading = false; });
          return;
        }
      }


      final prefs = await SharedPreferences.getInstance();
      final idRaw = widget.cage['id']?.toString() ?? '';
      final idx = int.tryParse(idRaw.replaceAll(RegExp(r'[^0-9]'), ''));
      if (idx != null) {
        await prefs.setString('kandang_${idx}_name', _nameController.text.trim());
        await prefs.setString('kandang_${idx}_address', _locationController.text.trim());
        await prefs.setInt('kandang_${idx}_floors', parsedFloors);
        await prefs.setString('kandang_${idx}_description', _descriptionController.text.trim());
        await prefs.setString('kandang_${idx}_code', _codeController.text.trim());
      }

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perubahan disimpan secara lokal'), backgroundColor: Colors.orange));
      Navigator.of(context).pop(true);
    } catch (e) {
      print('Error updating cage: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: Colors.red));
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Kandang'),
        backgroundColor: const Color(0xFF245C4C),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: 'Kode RBW (opsional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nama Kandang'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama tidak boleh kosong' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Alamat Kandang'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Alamat tidak boleh kosong' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _floorController,
                      decoration: const InputDecoration(labelText: 'Jumlah Lantai'),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Jumlah lantai tidak boleh kosong';
                        final n = int.tryParse(v.trim());
                        if (n == null) return 'Masukkan angka yang valid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _openMapPicker,
                    icon: const Icon(Icons.map),
                    label: const Text('Pilih Lokasi'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Deskripsi (opsional)'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF245C4C)),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Simpan Perubahan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapPickerPage extends StatefulWidget {
  final LatLng initialPosition;
  const _MapPickerPage({required this.initialPosition});

  @override
  State<_MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<_MapPickerPage> {
  LatLng? _picked;
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _onMapTapped(LatLng position) {
    setState(() {
      _picked = position;
      _markers.clear();
      _markers.add(
        Marker(
          markerId: const MarkerId('selected_location'),
          position: position,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Lokasi'),
        backgroundColor: const Color(0xFF245C4C),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _picked),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target: widget.initialPosition,
          zoom: 15,
        ),
        onTap: _onMapTapped,
        markers: _markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        zoomControlsEnabled: true,
        mapToolbarEnabled: false,
      ),
    );
  }
}
