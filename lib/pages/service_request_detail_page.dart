import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:swiftlead/services/service_request_service.dart';
import 'package:swiftlead/services/node_service.dart';
import 'package:swiftlead/utils/token_manager.dart';
import 'package:swiftlead/services/api_constants.dart';
import 'package:swiftlead/services/auth_services.dart.dart';

class ServiceRequestDetailPage extends StatefulWidget {
  const ServiceRequestDetailPage({super.key});

  @override
  State<ServiceRequestDetailPage> createState() => _ServiceRequestDetailPageState();
}

class _ServiceRequestDetailPageState extends State<ServiceRequestDetailPage> {
  final ServiceRequestService _service = ServiceRequestService();
  final NodeService _nodeService = NodeService();
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _assigning = false;
  final _nodeCodeController = TextEditingController();
  final _espController = TextEditingController();
  bool _creatingNode = false;
  String? _role;
  String? _userId;
  List<dynamic> _technicians = [];
  String? _selectedTechnicianId;
  bool _isAssignedTech = false;

  String? _id;

  @override
  void dispose() {
    _nodeCodeController.dispose();
    _espController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    _id = args?['id']?.toString();
    _load();
  }
  
  Future<void> _load() async {
    if (_id == null) return;
    setState(() => _loading = true);
    final token = await TokenManager.getToken();
    if (token == null) {
      setState(() => _loading = false);
      return;
    }

    // Load service request detail
    final res = await _service.getById(token, _id!);
    if (res['success'] == true) {
      setState(() => _data = res['data'] as Map<String, dynamic>?);
    } else {
      // ignore: avoid_print
      print('ServiceRequestDetailPage._load ${res['message']}');
    }

    // Load profile (role and user id)
    try {
      final auth = AuthService();
      final profile = await auth.profile(token);
      setState(() {
        _role = profile['data']?['role']?.toString();
        _userId = profile['data']?['id']?.toString();
      });
    } catch (e) {
      print('Failed to load profile: $e');
    }

    // Determine if current user is assigned technician
    try {
      final assignedId = _data?['technician_id']?.toString() ?? _data?['technician']?['id']?.toString();
      setState(() {
        _isAssignedTech = assignedId != null && _userId != null && assignedId == _userId;
      });
    } catch (_) {}

    // Load technicians and set default selection (fallback to known technician if none)
    try {
      final uri = Uri.parse('${ApiConstants.users}?role=technician&per_page=100');
      final resp = await http.get(uri, headers: ApiConstants.authHeaders(token));
      if (resp.statusCode == 200) {
        try {
          final body = jsonDecode(resp.body);
          final data = body['data'] as List<dynamic>? ?? [];
          setState(() {
            _technicians = data;
            const special = '00000000-0000-0000-0000-000000000002';
            final found = _technicians.isNotEmpty ? _technicians.firstWhere((e) => e['id']?.toString() == special, orElse: () => null) : null;
            if (found != null) {
              _selectedTechnicianId = found['id']?.toString();
            } else if (_technicians.isNotEmpty) {
              _selectedTechnicianId = _technicians.first['id']?.toString();
            } else {
              _technicians = const [
                {'id': special, 'name': 'Teknisi1', 'email': 'technician@swiftlead.id'}
              ];
              _selectedTechnicianId = special;
            }
          });
        } catch (_) {}
      }
    } catch (e) {
      print('Failed to load technicians: $e');
    }

    setState(() => _loading = false);
  }

  Future<void> _assign() async {
    if (_id == null) return;
    if (_selectedTechnicianId == null || _selectedTechnicianId!.isEmpty) return;
    setState(() => _assigning = true);
    final token = await TokenManager.getToken();
    if (token == null) {
      setState(() => _assigning = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not authenticated — please log in')));
      return;
    }
    // Use backend assign endpoint: PATCH /service-requests/{id}/assign with { technician_id }
    final res = await _service.assign(token, _id!, {
      'technician_id': _selectedTechnicianId!,
    });
    setState(() => _assigning = false);
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assigned')));
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${res['message']}')));
    }
  }

  Future<void> _createNode() async {
    if (_data == null) return;
    final rbwId = _data!['rbw_id']?.toString() ?? _data!['rbw']?['id']?.toString();
    if (rbwId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('RBW id not available')));
      return;
    }

    final nodeCode = _nodeCodeController.text.trim();
    final esp = _espController.text.trim();
    if (nodeCode.isEmpty || esp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Node code and ESP UID required')));
      return;
    }

    setState(() => _creatingNode = true);
    final token = await TokenManager.getToken();
    if (token == null) return;

    final payload = {
      'node_type': 'nest',
      'node_code': nodeCode,
      'esp32_uid': esp,
      'has_audio': true,
      'has_pump': false,
    };

    final res = await _nodeService.createUnderRbw(token, rbwId, payload);
    setState(() => _creatingNode = false);
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Node created')));
      _nodeCodeController.clear();
      _espController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create node: ${res['message']}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Service Request')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? const Center(child: Text('No data'))
              : Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: ListView(
                    children: [
                      Text('Issue: ${_data!['issue'] ?? ''}'),
                      const SizedBox(height: 8),
                      Text('Type: ${_data!['type'] ?? ''}'),
                      const SizedBox(height: 8),
                      Text('Status: ${_data!['status'] ?? ''}'),
                      const SizedBox(height: 8),
                      Text('RBW: ${_data!['rbw']?['name'] ?? _data!['rbw_id'] ?? ''}'),
                      const SizedBox(height: 12),

                      // Assign (admin action)
                      const Divider(),
                      const Text('Assign Technician (admin only)'),
                      const SizedBox(height: 8),
                      if (_role == 'admin') ...[
                        DropdownButtonFormField<String>(
                          initialValue: _selectedTechnicianId,
                          items: _technicians.map<DropdownMenuItem<String>>((e) {
                            final id = e['id']?.toString() ?? '';
                            final name = e['name'] ?? e['email'] ?? id;
                            return DropdownMenuItem(value: id, child: Text(name.toString()));
                          }).toList(),
                          onChanged: (v) => setState(() => _selectedTechnicianId = v),
                          decoration: const InputDecoration(labelText: 'Select Technician'),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(onPressed: _assigning ? null : _assign, child: _assigning ? const CircularProgressIndicator() : const Text('Assign')),
                      ] else ...[
                        const Text('You are not allowed to assign technicians.'),
                      ],

                      const SizedBox(height: 20),

                      // Technician: add node when assigned / in_progress
                      const Divider(),
                      const Text('Technician Actions'),
                      const SizedBox(height: 8),
                      if (_role == 'technician' && _isAssignedTech) ...[
                        TextField(controller: _nodeCodeController, decoration: const InputDecoration(labelText: 'Node code')),
                        const SizedBox(height: 8),
                        TextField(controller: _espController, decoration: const InputDecoration(labelText: 'ESP32 UID (eg. 4C:C3:82:BF:09:E8)')),
                        const SizedBox(height: 8),
                        ElevatedButton(onPressed: _creatingNode ? null : _createNode, child: _creatingNode ? const CircularProgressIndicator() : const Text('Create Node for RBW')),
                      ] else ...[
                        const Text('Technician actions are available only to the assigned technician.'),
                      ],
                    ],
                  ),
                ),
    );
  }
}
