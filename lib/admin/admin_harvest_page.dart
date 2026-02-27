import 'package:flutter/material.dart';
import 'package:swiftlead/services/harvest_service.dart';
import 'package:swiftlead/utils/token_manager.dart';
import 'package:intl/intl.dart';

class AdminHarvestPage extends StatefulWidget {
  const AdminHarvestPage({super.key});

  @override
  State<AdminHarvestPage> createState() => _AdminHarvestPageState();
}

class _AdminHarvestPageState extends State<AdminHarvestPage> {
  final HarvestService _harvestService = HarvestService();
  String? _authToken;
  bool _isLoading = true;
  List<dynamic> _harvestList = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      _authToken = await TokenManager.getToken();
      
      if (_authToken != null) {
        final result = await _harvestService.list(
          token: _authToken!,
          queryParams: {'limit': '100'},
        );
        
        if (result['success'] == true) {
          setState(() {
            _harvestList = result['data'] ?? [];
          });
        }
      }
    } catch (e) {
      print('Error loading harvest list: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: Image(
                image: AssetImage("assets/img/logo.png"),
                width: 64.0,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacementNamed(context, '/admin-home'),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF245C4C)),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Harvest Management',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF245C4C),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total: ${_harvestList.length} harvests',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _harvestList.isEmpty
                          ? const Center(
                              child: Text(
                                'No harvests found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _harvestList.length,
                              itemBuilder: (context, index) {
                                final harvest = _harvestList[index];
                                final rbwName = harvest['rbw']?['name']?.toString() ?? 
                                                harvest['rbw_name']?.toString() ?? 
                                                'Unknown RBW';
                                final nestsCount = harvest['nests_count']?.toString() ?? '0';
                                final weightKg = harvest['weight_kg']?.toString() ?? '0';
                                final grade = harvest['grade']?.toString() ?? '-';
                                final harvestedAt = _formatDate(harvest['harvested_at']?.toString());
                                final floorNo = harvest['floor_no']?.toString() ?? '-';

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 2,
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    leading: CircleAvatar(
                                      backgroundColor: const Color(0xFF245C4C).withOpacity(0.1),
                                      child: const Icon(
                                        Icons.agriculture,
                                        color: Color(0xFF245C4C),
                                      ),
                                    ),
                                    title: Text(
                                      rbwName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text('Date: $harvestedAt'),
                                        Text('Nests: $nestsCount | Weight: $weightKg kg'),
                                        Text('Grade: $grade | Floor: $floorNo'),
                                      ],
                                    ),
                                    isThreeLine: true,
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () {

                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Harvest Details'),
                                          content: SingleChildScrollView(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text('RBW: $rbwName'),
                                                const SizedBox(height: 8),
                                                Text('Date: $harvestedAt'),
                                                Text('Floor: $floorNo'),
                                                Text('Nests Count: $nestsCount'),
                                                Text('Weight: $weightKg kg'),
                                                Text('Grade: $grade'),
                                                if (harvest['notes'] != null)
                                                  Text('Notes: ${harvest['notes']}'),
                                              ],
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text('Close'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
