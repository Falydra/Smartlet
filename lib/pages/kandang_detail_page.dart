import 'package:flutter/material.dart';
import 'package:swiftlead/services/rbw_service.dart';
import 'package:swiftlead/services/auth_services.dart.dart';
import 'package:swiftlead/services/node_service.dart';
import 'package:swiftlead/utils/token_manager.dart';
import 'package:swiftlead/shared/theme.dart';

class KandangDetailPage extends StatefulWidget {
  final String houseId;

  const KandangDetailPage({super.key, required this.houseId});

  @override
  State<KandangDetailPage> createState() => _KandangDetailPageState();
}

class _KandangDetailPageState extends State<KandangDetailPage> {
  final RbwService _rbwService = RbwService();
  final AuthService _authService = AuthService();
  final NodeService _nodeService = NodeService();
  String? _authToken;
  bool _isLoading = true;
  Map<String, dynamic>? _rbwData;
  String? _ownerName;
  List<dynamic> _nodes = [];
  bool _loadingNodes = false;

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
        final result = await _rbwService.getRbw(
          rbwId: widget.houseId,
          token: _authToken!,
        );
        
        if (result['success'] == true && result['data'] != null) {
          print('===== RBW DATA STRUCTURE =====');
          print('Full data: ${result['data']}');
          print('Owner field: ${result['data']['owner']}');
          print('Owner_name field: ${result['data']['owner_name']}');
          print('User field: ${result['data']['user']}');
          print('=============================');
          setState(() {
            _rbwData = result['data'];
          });
          

          await _fetchOwnerName();
          

          await _loadNodes();
        }
      }
    } catch (e) {
      print('Error loading RBW details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {

        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchOwnerName() async {
    if (_rbwData == null) return;
    

    if (_rbwData!['owner']?['name'] != null || 
        _rbwData!['owner_name'] != null || 
        _rbwData!['user']?['name'] != null) {
      return;
    }
    

    final ownerId = _rbwData!['owner_id'];
    if (ownerId != null && _authToken != null) {
      try {
        final usersResult = await _authService.listUsers(
          token: _authToken!,
          limit: 100, // Get a larger list to find the user
        );
        
        if (usersResult['success'] == true && usersResult['data'] is List) {
          final users = usersResult['data'] as List;
          final owner = users.firstWhere(
            (user) => user['id'] == ownerId,
            orElse: () => null,
          );
          
          if (owner != null && mounted) {
            setState(() {
              _ownerName = owner['name']?.toString() ?? 'Unknown';
            });
          }
        }
      } catch (e) {
        print('Error fetching owner name: $e');
      }
    }
  }

  Future<void> _loadNodes() async {
    if (_authToken == null) return;
    
    setState(() => _loadingNodes = true);
    
    try {
      final result = await _nodeService.listByRbw(
        _authToken!,
        widget.houseId,
      );
      
      if (result['success'] == true && mounted) {
        setState(() {
          _nodes = result['data'] ?? [];
        });
      }
    } catch (e) {
      print('Error loading nodes: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingNodes = false);
      }
    }
  }

  void _showNodesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.router, color: blue500),
            const SizedBox(width: 8),
            const Text('IoT Nodes'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: _loadingNodes
              ? const Center(child: CircularProgressIndicator())
              : _nodes.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No nodes found for this RBW'),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _nodes.length,
                      itemBuilder: (context, index) {
                        final node = _nodes[index];
                        final nodeType = node['node_type']?.toString() ?? 'Unknown';
                        final nodeCode = node['node_code']?.toString() ?? '-';
                        final status = node['status_node']?.toString() ?? 'offline';
                        final esp32Uid = node['esp32_uid']?.toString() ?? '-';
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: status == 'online'
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.1),
                              child: Icon(
                                Icons.device_hub,
                                color: status == 'online' ? Colors.green : Colors.grey,
                              ),
                            ),
                            title: Text(
                              nodeCode,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Type: $nodeType'),
                                Text('ESP32: $esp32Uid'),
                                Text(
                                  'Status: $status',
                                  style: TextStyle(
                                    color: status == 'online' ? Colors.green : Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RBW Details'),
        backgroundColor: blue500,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF245C4C)),
            )
          : _rbwData == null
              ? const Center(
                  child: Text('RBW not found'),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        Card(
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundColor: blue500.withOpacity(0.1),
                                      child: Icon(Icons.home_work, size: 30, color: blue500),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _rbwData!['name']?.toString() ?? 'Unknown',
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Code: ${_rbwData!['code']?.toString() ?? '-'}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),


                        Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Details',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Divider(height: 24),
                                _buildDetailRow('Owner', 
                                  _rbwData!['owner']?['name']?.toString() ?? 
                                  _rbwData!['owner_name']?.toString() ?? 
                                  _rbwData!['user']?['name']?.toString() ??
                                  _ownerName ??
                                  'Unknown'),
                                _buildDetailRow('Address', _rbwData!['address']?.toString() ?? '-'),
                                _buildDetailRow('Total Floors', _rbwData!['total_floors']?.toString() ?? '0'),
                                _buildDetailRow('Latitude', _rbwData!['latitude']?.toString() ?? '-'),
                                _buildDetailRow('Longitude', _rbwData!['longitude']?.toString() ?? '-'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),


                        if (_rbwData!['description'] != null && _rbwData!['description'].toString().isNotEmpty)
                          Card(
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Description',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _rbwData!['description'].toString(),
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        
                        if (_rbwData!['description'] != null && _rbwData!['description'].toString().isNotEmpty)
                          const SizedBox(height: 16),


                        const Text(
                          'Management',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),


                        Card(
                          elevation: 2,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: blue500.withOpacity(0.1),
                              child: Icon(Icons.router, color: blue500),
                            ),
                            title: Text(
                              'Nodes (IoT Devices)',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text('${_nodes.length} nodes installed'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: _showNodesDialog,
                          ),
                        ),
                        const SizedBox(height: 8),


                        Card(
                          elevation: 2,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green.withOpacity(0.1),
                              child: const Icon(Icons.agriculture, color: Colors.green),
                            ),
                            title: const Text(
                              'Harvest Records',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: const Text('View and manage harvest data'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              Navigator.pushNamed(context, '/admin-harvest');
                            },
                          ),
                        ),
                        const SizedBox(height: 8),


                        Card(
                          elevation: 2,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.orange.withOpacity(0.1),
                              child: const Icon(Icons.account_balance_wallet, color: Colors.orange),
                            ),
                            title: const Text(
                              'Finance & Transactions',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: const Text('Manage financial transactions'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              Navigator.pushNamed(context, '/admin-finance');
                            },
                          ),
                        ),
                        Divider(height: 36),
                      ],
                    ),
                    
                  ),
                ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
