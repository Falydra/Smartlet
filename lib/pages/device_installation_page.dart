import 'package:flutter/material.dart';
// Deprecated DeviceInstallationService removed; use ServiceRequestService to create installation requests.
import 'package:swiftlead/services/service_request_service.dart';
import 'package:swiftlead/utils/token_manager.dart';

class DeviceInstallationPage extends StatefulWidget {
  final String houseId;
  final String houseName;
  
  const DeviceInstallationPage({
    super.key,
    required this.houseId,
    required this.houseName,
  });

  @override
  State<DeviceInstallationPage> createState() => _DeviceInstallationPageState();
}

class _DeviceInstallationPageState extends State<DeviceInstallationPage> {
  final ServiceRequestService _serviceRequestService = ServiceRequestService();
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
      // TODO: Use NodeService.listByRbw to check existing nodes for this RBW
      // Placeholder sets no devices
      setState(() {
        _hasDevices = false;
        _installedDevices = [];
      });
    } catch (e) {
      print('Error checking device installation: $e');
    }
  }

  // Manual installation removed; installation should be done via service request and technician workflow.

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
      final payload = {
        'rbw_id': widget.houseId,
        'type': 'installation',
        'issue': reason,
      };
      final result = await _serviceRequestService.create(_authToken!, payload);
      if (result['success'] == true) {
        _showMessage('Installation request submitted');
        _reasonController.clear();
        Navigator.pop(context);
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
          title: const Text('Request Installation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Request professional installation for ${widget.houseName}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _reasonController,
                decoration: const InputDecoration(
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
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isLoading ? null : _requestInstallation,
              child: _isLoading ? const CircularProgressIndicator() : const Text('Submit Request'),
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
        title: const Text('Device Installation'),
        backgroundColor: const Color(0xFF245C4C),
        foregroundColor: Colors.white,
      ),
      body: _isLoading ? 
        const Center(child: CircularProgressIndicator()) :
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // House Info
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.houseName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF245C4C),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            _hasDevices ? Icons.check_circle : Icons.warning,
                            color: _hasDevices ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 8),
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

              const SizedBox(height: 24),

              // Installed Devices List
              if (_hasDevices) ...[
                const Text(
                  'Installed Devices',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF245C4C),
                  ),
                ),
                const SizedBox(height: 12),
                ..._installedDevices.map((device) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.sensors, color: Color(0xFF245C4C)),
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
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.error, color: Colors.red),
                  ),
                )),
                const SizedBox(height: 24),
              ],

              const SizedBox(height: 24),

              // Request Professional Installation
              const Text(
                'Professional Installation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF245C4C),
                ),
              ),
              const SizedBox(height: 12),
              
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
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
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _showInstallationRequestDialog,
                          icon: const Icon(Icons.support_agent, color: Colors.white),
                          label: const Text(
                            'Request Installation',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 12),
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
    _reasonController.dispose();
    super.dispose();
  }
}