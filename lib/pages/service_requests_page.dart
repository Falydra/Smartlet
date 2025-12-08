import 'package:flutter/material.dart';
import 'package:swiftlead/services/service_request_service.dart';
import 'package:swiftlead/utils/token_manager.dart';

class ServiceRequestsPage extends StatefulWidget {
  const ServiceRequestsPage({super.key});

  @override
  State<ServiceRequestsPage> createState() => _ServiceRequestsPageState();
}

class _ServiceRequestsPageState extends State<ServiceRequestsPage> {
  final ServiceRequestService _service = ServiceRequestService();
  List<dynamic> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final token = await TokenManager.getToken();
    if (token == null) {
      setState(() => _loading = false);
      return;
    }

    final res = await _service.list(token);
    if (res['success'] == true && res['data'] != null) {
      setState(() {
        _items = res['data'] as List<dynamic>;
      });
    } else {
      // ignore: avoid_print
      print('ServiceRequestsPage._load error: ${res['message']}');
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Service Requests')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: const [SizedBox(height: 200), Center(child: Text('No service requests'))],
                    )
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, idx) {
                        final item = _items[idx] as Map<String, dynamic>;
                        final id = item['id']?.toString() ?? '';
                        final title = item['issue'] ?? item['type'] ?? 'Service Request';
                        final status = item['status'] ?? '';
                        final rbw = item['rbw']?['name'] ?? item['rbw_id'] ?? '';

                        return ListTile(
                          title: Text(title),
                          subtitle: Text('RBW: $rbw · Status: $status'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pushNamed(context, '/service-request-detail', arguments: {'id': id}).then((_) => _load()),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/create-service-request').then((_) => _load()),
        child: const Icon(Icons.add),
      ),
    );
  }
}
