import 'package:flutter/material.dart';
import 'package:swiftlead/services/service_request_service.dart';
import 'package:swiftlead/utils/token_manager.dart';

class CreateServiceRequestPage extends StatefulWidget {
  const CreateServiceRequestPage({super.key});

  @override
  State<CreateServiceRequestPage> createState() => _CreateServiceRequestPageState();
}

class _CreateServiceRequestPageState extends State<CreateServiceRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _rbwController = TextEditingController();
  final _nodeController = TextEditingController();
  final _typeController = TextEditingController();
  final _issueController = TextEditingController();
  final _scheduleController = TextEditingController();

  final ServiceRequestService _service = ServiceRequestService();
  bool _submitting = false;

  @override
  void dispose() {
    _rbwController.dispose();
    _nodeController.dispose();
    _typeController.dispose();
    _issueController.dispose();
    _scheduleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final token = await TokenManager.getToken();
    if (token == null) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not authenticated')));
      return;
    }

    final payload = {
      'rbw_id': _rbwController.text.trim(),
      if (_nodeController.text.trim().isNotEmpty) 'node_id': _nodeController.text.trim(),
      'type': _typeController.text.trim().isNotEmpty ? _typeController.text.trim() : 'installation',
      'issue': _issueController.text.trim(),
      if (_scheduleController.text.trim().isNotEmpty) 'schedule_date': _scheduleController.text.trim(),
    };

    final res = await _service.create(token, payload);
    setState(() => _submitting = false);
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service request created')));
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${res['message'] ?? 'unknown'}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Service Request')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _rbwController,
                decoration: const InputDecoration(labelText: 'RBW ID (uuid)'),
                validator: (v) => v == null || v.isEmpty ? 'RBW id required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nodeController,
                decoration: const InputDecoration(labelText: 'Node ID (optional)'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _typeController,
                decoration: const InputDecoration(labelText: 'Type (installation/maintenance)'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _issueController,
                decoration: const InputDecoration(labelText: 'Issue / Description'),
                minLines: 2,
                maxLines: 4,
                validator: (v) => v == null || v.isEmpty ? 'Describe the issue' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _scheduleController,
                decoration: const InputDecoration(labelText: 'Schedule date (RFC3339, optional)'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting ? const CircularProgressIndicator() : const Text('Create'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
