import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class OsmLocationPicker extends StatefulWidget {
  final LatLng? initialPosition;
  final Function(LatLng position, String? address)? onLocationSelected;

  const OsmLocationPicker({
    Key? key,
    this.initialPosition,
    this.onLocationSelected,
  }) : super(key: key);

  @override
  State<OsmLocationPicker> createState() => _OsmLocationPickerState();
}

class _OsmLocationPickerState extends State<OsmLocationPicker> {
  final MapController _mapController = MapController();
  LatLng? _selectedPosition;
  String? _address;
  bool _isLoadingAddress = false;
  bool _isLoadingLocation = false;
  List<Marker> _markers = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialPosition != null) {
      _selectedPosition = widget.initialPosition;
      _updateMarker(_selectedPosition!);
      _getAddressFromLatLng(_selectedPosition!);
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Layanan lokasi tidak aktif')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Izin lokasi ditolak')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Izin lokasi ditolak secara permanen')),
          );
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      final newPosition = LatLng(position.latitude, position.longitude);

      setState(() {
        _selectedPosition = newPosition;
        _updateMarker(newPosition);
      });

      _mapController.move(newPosition, 16.0);

      await _getAddressFromLatLng(newPosition);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error mengambil lokasi: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    setState(() {
      _isLoadingAddress = true;
    });

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _address = [
            place.street,
            place.subLocality,
            place.locality,
            place.subAdministrativeArea,
            place.administrativeArea,
            place.postalCode,
          ].where((s) => s != null && s.isNotEmpty).join(', ');
        });
      }
    } catch (e) {
      print('Error getting address: $e');
      setState(() {
        _address = 'Alamat tidak tersedia';
      });
    } finally {
      setState(() {
        _isLoadingAddress = false;
      });
    }
  }

  void _updateMarker(LatLng position) {
    setState(() {
      _markers = [
        Marker(
          point: position,
          width: 40,
          height: 40,
          child: const Icon(
            Icons.location_on,
            color: Colors.red,
            size: 40,
          ),
        ),
      ];
    });
  }

  void _onMapTapped(TapPosition tapPosition, LatLng position) {
    setState(() {
      _selectedPosition = position;
      _updateMarker(position);
    });
    _getAddressFromLatLng(position);
  }

  void _onConfirm() {
    if (_selectedPosition != null) {
      if (widget.onLocationSelected != null) {
        widget.onLocationSelected!(_selectedPosition!, _address);
      }
      Navigator.pop(context, {
        'position': _selectedPosition,
        'address': _address,
      });
    }
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
            onPressed: _selectedPosition != null ? _onConfirm : null,
            child: Text(
              'OK',
              style: TextStyle(
                color: _selectedPosition != null ? Colors.white : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialPosition ??
                  LatLng(-6.200000, 106.816666),
              initialZoom: 15.0,
              onTap: _onMapTapped,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.swiftlead',
                maxZoom: 19,
              ),
              MarkerLayer(
                markers: _markers,
              ),
            ],
          ),

          Positioned(
            left: 10,
            right: 10,
            bottom: 10,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            color: Color(0xFF245C4C)),
                        const SizedBox(width: 8),
                        const Text(
                          'Koordinat:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_selectedPosition != null) ...[
                      Text(
                        'Latitude: ${_selectedPosition!.latitude.toStringAsFixed(6)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Longitude: ${_selectedPosition!.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Divider(),
                      const SizedBox(height: 8),
                      _isLoadingAddress
                          ? const Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                ),
                                SizedBox(width: 8),
                                Text('Mencari alamat...'),
                              ],
                            )
                          : Text(
                              _address ?? 'Tap pada peta untuk memilih lokasi',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                    ] else
                      const Text(
                        'Tap pada peta untuk memilih lokasi',
                        style: TextStyle(color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            right: 10,
            bottom: 200,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              onPressed: _isLoadingLocation ? null : _getCurrentLocation,
              child: _isLoadingLocation
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location, color: Color(0xFF245C4C)),
            ),
          ),

          Positioned(
            right: 10,
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '© OpenStreetMap',
                style: TextStyle(fontSize: 10, color: Colors.black54),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
