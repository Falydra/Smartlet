import 'package:flutter/material.dart';
import 'package:swiftlead/services/service_request_service.dart';
import 'package:swiftlead/utils/token_manager.dart';
import 'package:swiftlead/components/custom_bottom_navigation.dart';
// profile page import not required here
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
  int _currentIndex = 1;

  @override
  void initState() {
    super.initState();
    _load();
    _loadTechnicians();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final token = await TokenManager.getToken();
    if (token == null) return setState(() => _loading = false);
    final res = await _service.list(token, queryParams: {'status': 'pending', 'per_page': '50'});
    if (res['success'] == true && res['data'] != null) {
      setState(() => _items = res['data'] as List<dynamic>);
    }
    setState(() => _loading = false);
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
          final data = body['data'] as List<dynamic>? ?? [];
          setState(() {
            _technicians = data;
            // if no technicians returned, ensure the special UUID is available as a fallback option
            const special = '00000000-0000-0000-0000-000000000002';
            final found = _technicians.isNotEmpty ? _technicians.firstWhere((e) => e['id']?.toString() == special, orElse: () => null) : null;
            if (found != null) {
              // move the found item to be first so the dialog default shows it
              _technicians.remove(found);
              _technicians.insert(0, found);
            } else if (_technicians.isEmpty) {
              // add a fallback technician entry so the dropdown still shows a selectable option
              // Use the known technician details as provided
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
          // ignore
        }
      }
    } catch (e) {
      print('Failed to load technicians: $e');
    }
  }

  Future<void> _assign(String id) async {
    final token = await TokenManager.getToken();
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not authenticated — please log in')));
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
        // Use backend assign endpoint: PATCH /service-requests/{id}/assign with { technician_id }
        final res = await _service.assign(token, id, {
          'technician_id': techId,
        });
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assigned')));
        await _load();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${res['message']}')));
      }
    }
  }

  Widget _adminBottomNav() {
    return BottomNavigationBar(
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
                setState(() {
                  _currentIndex = 0;
                });
              },
            ),
            label: ''),
        BottomNavigationBarItem(
            icon: CustomBottomNavigationItem(
              icon: Icons.build_circle,
              label: 'Installation',
              currentIndex: _currentIndex,
              itemIndex: 1,
              onTap: () {
                Navigator.pushReplacementNamed(context, '/installation-manager');
                setState(() {
                  _currentIndex = 1;
                });
              },
            ),
            label: ''),
        BottomNavigationBarItem(
            icon: CustomBottomNavigationItem(
              icon: Icons.group,
              label: 'Users',
              currentIndex: _currentIndex,
              itemIndex: 2,
              onTap: () {
                Navigator.pushReplacementNamed(context, '/user-manager');
                setState(() {
                  _currentIndex = 2;
                });
              },
            ),
            label: ''),
        BottomNavigationBarItem(
            icon: CustomBottomNavigationItem(
              icon: Icons.person,
              label: 'Profil',
              currentIndex: _currentIndex,
              itemIndex: 3,
              onTap: () {
                Navigator.pushReplacementNamed(context, '/profile-page');
                setState(() {
                  _currentIndex = 3;
                });
              },
            ),
            label: ''),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Installation Manager')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(children: const [SizedBox(height: 200), Center(child: Text('No pending installation requests'))])
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final item = _items[idx] as Map<String, dynamic>;
                        final id = item['id']?.toString() ?? '';
                        final issue = item['issue'] ?? item['type'] ?? 'Installation';
                        final rbw = item['rbw']?['name'] ?? item['rbw_id'] ?? '';
                        final status = item['status'] ?? '';
                        return ListTile(
                          title: Text(issue.toString()),
                          subtitle: Text('RBW: $rbw · Status: $status'),
                          trailing: ElevatedButton(onPressed: () => _assign(id), child: const Text('Assign')),
                          onTap: () => Navigator.pushNamed(context, '/service-request-detail', arguments: {'id': id}).then((_) => _load()),
                        );
                      },
                    ),
            ),
      bottomNavigationBar: _adminBottomNav(),
    );
  }
}
