import 'package:flutter/material.dart';
import 'package:swiftlead/services/device_installation_service.dart';
import 'package:swiftlead/utils/token_manager.dart';

class DeviceInstallationPage extends StatefulWidget {
  final int houseId;
  final String houseName;
  
  const DeviceInstallationPage({
    Key? key,
    required this.houseId,
    required this.houseName,
  }) : super(key: key);

  @override
  State<DeviceInstallationPage> createState() => _DeviceInstallationPageState();
}

class _DeviceInstallationPageState extends State<DeviceInstallationPage> {
  final DeviceInstallationService _installationService = DeviceInstallationService();
  final TextEditingController _installCodeController = TextEditingController();
  final TextEditingController _floorController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();

  bool _isLoading = false;
  bool _hasDevices = false;
  List<dynamic> _installedDevices = [];
  String? _authToken;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _authToken = await TokenManager.getToken();
      if (_authToken != null) {
        await _checkDeviceInstallation();
      }
    } catch (e) {
      print('Error initializing data: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _checkDeviceInstallation() async {
    if (_authToken == null) return;

    try {
      final result = await _installationService.checkDeviceInstallation(_authToken!, widget.houseId);
      
      if (result['success'] == true) {
        setState(() {
          _hasDevices = result['hasDevices'] ?? false;
          _installedDevices = result['devices'] ?? [];
        });
      }
    } catch (e) {
      print('Error checking device installation: $e');
    }
  }

  Future<void> _installDevice() async {
    if (_authToken == null) return;

    final installCode = _installCodeController.text.trim();
    final floorText = _floorController.text.trim();

    if (installCode.isEmpty || floorText.isEmpty) {
      _showMessage('Please fill in all fields', isError: true);
      return;
    }

    final floor = int.tryParse(floorText);
    if (floor == null || floor < 1) {
      _showMessage('Please enter a valid floor number', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _installationService.installDevice(
        _authToken!,
        installCode,
        widget.houseId,
        floor,
      );

      if (result['success'] == true) {
        _showMessage(result['message'] ?? 'Device installed successfully');
        _installCodeController.clear();
        _floorController.clear();
        await _checkDeviceInstallation();
      } else {
        _showMessage(result['message'] ?? 'Failed to install device', isError: true);
      }
    } catch (e) {
      _showMessage('Error installing device: $e', isError: true);
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _requestInstallation() async {
    if (_authToken == null) return;

    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      _showMessage('Please provide a reason for the installation request', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _installationService.requestInstallation(
        _authToken!,
        widget.houseId,
        reason,
      );

      if (result['success'] == true) {
        _showMessage(result['message'] ?? 'Installation request submitted successfully');
        _reasonController.clear();
        Navigator.pop(context); // Close the dialog
      } else {
        _showMessage(result['message'] ?? 'Failed to submit installation request', isError: true);
      }
    } catch (e) {
      _showMessage('Error submitting request: $e', isError: true);
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _showInstallationRequestDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Request Installation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Request professional installation for ${widget.houseName}',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _reasonController,
                decoration: InputDecoration(
                  labelText: 'Reason for installation',
                  hintText: 'Describe why you need device installation...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _reasonController.clear();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isLoading ? null : _requestInstallation,
              child: _isLoading ? CircularProgressIndicator() : Text('Submit Request'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Device Installation'),
        backgroundColor: Color(0xFF245C4C),
        foregroundColor: Colors.white,
      ),
      body: _isLoading ? 
        Center(child: CircularProgressIndicator()) :
        SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // House Info
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.houseName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF245C4C),
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            _hasDevices ? Icons.check_circle : Icons.warning,
                            color: _hasDevices ? Colors.green : Colors.orange,
                          ),
                          SizedBox(width: 8),
                          Text(
                            _hasDevices 
                              ? '${_installedDevices.length} device(s) installed'
                              : 'No devices installed',
                            style: TextStyle(
                              color: _hasDevices ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 24),

              // Installed Devices List
              if (_hasDevices) ...[
                Text(
                  'Installed Devices',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF245C4C),
                  ),
                ),
                SizedBox(height: 12),
                ..._installedDevices.map((device) => Card(
                  margin: EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(Icons.sensors, color: Color(0xFF245C4C)),
                    title: Text(device['device_name'] ?? 'ESP32 Device'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Installation Code: ${device['install_code']}'),
                        Text('Floor: ${device['floor']}'),
                        Text('Status: ${device['status'] == 1 ? 'Active' : 'Inactive'}'),
                      ],
                    ),
                    trailing: device['status'] == 1 
                      ? Icon(Icons.check_circle, color: Colors.green)
                      : Icon(Icons.error, color: Colors.red),
                  ),
                )).toList(),
                SizedBox(height: 24),
              ],

              // Manual Installation Section
              Text(
                'Manual Device Installation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF245C4C),
                ),
              ),
              SizedBox(height: 12),
              
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _installCodeController,
                        decoration: InputDecoration(
                          labelText: 'Installation Code',
                          hintText: 'ESP32_YGY_001_L1',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.qr_code),
                        ),
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: _floorController,
                        decoration: InputDecoration(
                          labelText: 'Floor Number',
                          hintText: '1',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.layers),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _installDevice,
                          icon: Icon(Icons.add_circle, color: Colors.white),
                          label: Text(
                            'Install Device',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF245C4C),
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 24),

              // Request Professional Installation
              Text(
                'Professional Installation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF245C4C),
                ),
              ),
              SizedBox(height: 12),
              
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Need help with device installation? Request professional installation service.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _showInstallationRequestDialog,
                          icon: Icon(Icons.support_agent, color: Colors.white),
                          label: Text(
                            'Request Installation',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }

  @override
  void dispose() {
    _installCodeController.dispose();
    _floorController.dispose();
    _reasonController.dispose();
    super.dispose();
  }
}