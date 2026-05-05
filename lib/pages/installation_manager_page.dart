import 'package:flutter/material.dart';
import 'package:swiftlead/services/service_request_service.dart';
import 'package:swiftlead/utils/modern_snackbar.dart';
import 'package:swiftlead/utils/token_manager.dart';
import 'package:swiftlead/components/admin_bottom_navigation.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:swiftlead/services/api_constants.dart';

class InstallationManagerPage extends StatefulWidget {
  const InstallationManagerPage({super.key});

  @override
  State<InstallationManagerPage> createState() => _InstallationManagerPageState();
}

class _InstallationManagerPageState extends State<InstallationManagerPage> {
  final ServiceRequestService _service = ServiceRequestService();
  List<dynamic> _items = [];
  List<dynamic> _technicians = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _loadTechnicians();
  }

  Future<void> _load() async {
    setState(() { _loading = true; });
    final token = await TokenManager.getToken();
    if (token == null) {
      setState(() { _loading = false; });
      return;
    }
    final res = await _service.list(token, queryParams: {'per_page': '50'});
    if (!mounted) return;
    if (res['success'] == true) {
      final data = res['data'];
      setState(() {
        _items = (data is List) ? data : [];
        _loading = false;
      });
    } else {
      setState(() {
        _items = [];
        _loading = false;
      });
      if (mounted) {
        ModernSnackBar.error(context, 'Failed to load requests: ${res['message'] ?? res['statusCode'] ?? 'Unknown error'}');
      }
    }
  }

  Future<void> _loadTechnicians() async {
    final token = await TokenManager.getToken();
    if (token == null) return;
    try {
      final uri = Uri.parse('${ApiConstants.users}?role=technician&per_page=100');
      final resp = await http.get(uri, headers: ApiConstants.authHeaders(token));
      if (resp.statusCode == 200) {
        try {
          final body = jsonDecode(resp.body);
          final payload = body['data'];
          List<dynamic> data = [];
          if (payload is Map<String, dynamic> && payload.containsKey('users')) {
            data = payload['users'] as List<dynamic>? ?? [];
          } else if (payload is List) {
            data = payload;
          }
          setState(() {
            _technicians = data;

            const special = '00000000-0000-0000-0000-000000000002';
            final found = _technicians.isNotEmpty ? _technicians.firstWhere((e) => e['id']?.toString() == special, orElse: () => null) : null;
            if (found != null) {

              _technicians.remove(found);
              _technicians.insert(0, found);
            } else if (_technicians.isEmpty) {


              _technicians = [
                {
                  'id': special,
                  'name': 'Teknisi1',
                  'email': 'technician@swiftlead.id'
                }
              ];
            }
          });
        } catch (e) {

        }
      }
    } catch (e) {
      print('Failed to load technicians: $e');
    }
  }

  Future<void> _assign(String id) async {
    final token = await TokenManager.getToken();
    if (token == null) {
      ModernSnackBar.error(context, 'Not authenticated — please log in');
      return;
    }

    String? selectedTechId;

    final assigned = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Technician'),
        content: StatefulBuilder(builder: (context, setStateDialog) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedTechId ?? (_technicians.isNotEmpty ? _technicians.first['id']?.toString() : null),
                items: _technicians.map<DropdownMenuItem<String>>((t) {
                  final id = t['id']?.toString() ?? '';
                  final name = t['name'] ?? t['email'] ?? id;
                  return DropdownMenuItem(value: id, child: Text(name.toString()));
                }).toList(),
                onChanged: (v) => setStateDialog(() => selectedTechId = v),
                decoration: const InputDecoration(labelText: 'Technician'),
              ),
            ],
          );
        }),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Assign')),
        ],
      ),
    );

    if (assigned == true) {
      const defaultUuid = '00000000-0000-0000-0000-000000000002';
      final techId = (selectedTechId ?? (_technicians.isNotEmpty ? _technicians.first['id']?.toString() : defaultUuid))?.toString();
      if (techId == null || techId.isEmpty) return;

      final res = await _service.assignComposite(token, id, techId);
      if (!mounted) return;
      if (res['success'] == true) {
        ModernSnackBar.success(context, 'Technician assigned successfully');
        await _load();
      } else {
        ModernSnackBar.error(context, 'Failed to assign: ${res['message'] ?? res['statusCode'] ?? 'Unknown error'}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Installation Manager'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacementNamed(context, '/admin-home'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
                onRefresh: _load,
                child: _items.isEmpty
                  ? ListView(children: const [SizedBox(height: 200), Center(child: Text('No installation requests'))])
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (context, idx) {
                        final item = _items[idx] as Map<String, dynamic>;
                        final id = item['id']?.toString() ?? '';
                        final issue = item['issue'] ?? item['type'] ?? 'Installation';
                        final rbw = item['rbw']?['name'] ?? item['rbw_id'] ?? '';
                        final status = item['status']?.toString() ?? 'pending';
                        final isAssigned = item['assigned_to'] != null && item['assigned_to'].toString().isNotEmpty;
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF245C4C).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.build_circle, color: Color(0xFF245C4C), size: 28),
                            ),
                            title: Text(
                              issue.toString().toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF245C4C)),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.business, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        rbw,
                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: status.toLowerCase() == 'pending' ? Colors.orange.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        status.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 11, 
                                          fontWeight: FontWeight.bold, 
                                          color: status.toLowerCase() == 'pending' ? Colors.orange[800] : Colors.green[800]
                                        ),
                                      ),
                                    ),
                                    if (isAssigned) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.engineering, size: 12, color: Colors.blue[800]),
                                            const SizedBox(width: 4),
                                            Text(
                                              'ASSIGNED',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue[800]),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ]
                                  ],
                                ),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isAssigned ? Colors.white : const Color(0xFF245C4C),
                                foregroundColor: isAssigned ? const Color(0xFF245C4C) : Colors.white,
                                side: isAssigned ? const BorderSide(color: Color(0xFF245C4C)) : null,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              onPressed: () => _assign(id),
                              child: Text(isAssigned ? 'Reassign' : 'Assign'),
                            ),
                            onTap: () => Navigator.pushNamed(context, '/service-request-detail', arguments: {'id': id}).then((_) => _load()),
                          ),
                        );
                      },
                    ),
            ),
      bottomNavigationBar: const AdminBottomNavigation(currentIndex: 2),
    );
  }
}
