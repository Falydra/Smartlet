import 'package:flutter/material.dart';
import 'package:swiftlead/components/admin_bottom_navigation.dart';
import 'package:swiftlead/services/rbw_service.dart';
import 'package:swiftlead/services/auth_services.dart.dart';
import 'package:swiftlead/utils/token_manager.dart';

class AdminRbwPage extends StatefulWidget {
  const AdminRbwPage({super.key});

  @override
  State<AdminRbwPage> createState() => _AdminRbwPageState();
}

class _AdminRbwPageState extends State<AdminRbwPage> {
  final RbwService _rbwService = RbwService();
  final AuthService _authService = AuthService();
  String? _authToken;
  bool _isLoading = true;
  List<dynamic> _rbwList = [];
  Map<String, String> _ownerNames = {};

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
        final result = await _rbwService.listRbw(token: _authToken!);
        
        if (result['success'] == true) {
          setState(() {
            _rbwList = result['data'] ?? [];
          });
          

          await _fetchOwnerNames();
        }
      }
    } catch (e) {
      print('Error loading RBW list: $e');
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

  Future<void> _fetchOwnerNames() async {
    if (_rbwList.isEmpty || _authToken == null) return;
    

    final ownerIdsToFetch = <String>{};
    for (final rbw in _rbwList) {
      if (rbw['owner']?['name'] == null && 
          rbw['owner_name'] == null && 
          rbw['owner_id'] != null) {
        ownerIdsToFetch.add(rbw['owner_id'].toString());
      }
    }
    
    if (ownerIdsToFetch.isEmpty) return;
    
    try {
      final usersResult = await _authService.listUsers(
        token: _authToken!,
        limit: 100,
      );
      
      if (usersResult['success'] == true && usersResult['data'] is List) {
        final users = usersResult['data'] as List;
        final ownerNamesMap = <String, String>{};
        
        for (final user in users) {
          final userId = user['id']?.toString();
          final userName = user['name']?.toString();
          if (userId != null && userName != null && ownerIdsToFetch.contains(userId)) {
            ownerNamesMap[userId] = userName;
          }
        }
        
        if (mounted && ownerNamesMap.isNotEmpty) {
          setState(() {
            _ownerNames = ownerNamesMap;
          });
        }
      }
    } catch (e) {
      print('Error fetching owner names: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
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
                      'RBW Management',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF245C4C),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total: ${_rbwList.length} RBW',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _rbwList.isEmpty
                          ? const Center(
                              child: Text(
                                'No RBW found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _rbwList.length,
                              itemBuilder: (context, index) {
                                final rbw = _rbwList[index];
                                final name = rbw['name']?.toString() ?? 'Unknown';
                                final code = rbw['code']?.toString() ?? '-';
                                final address = rbw['address']?.toString() ?? '-';
                                final floors = rbw['total_floors']?.toString() ?? '0';
                                final ownerId = rbw['owner_id']?.toString();
                                final ownerName = rbw['owner']?['name']?.toString() ?? 
                                                  rbw['owner_name']?.toString() ?? 
                                                  (ownerId != null ? _ownerNames[ownerId] : null) ??
                                                  'Unknown Owner';

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
                                        Icons.home_work,
                                        color: Color(0xFF245C4C),
                                      ),
                                    ),
                                    title: Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text('Code: $code'),
                                        Text('Owner: $ownerName'),
                                        Text('Address: $address'),
                                        Text('Floors: $floors'),
                                      ],
                                    ),
                                    isThreeLine: true,
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/kandang-detail',
                                        arguments: {'houseId': rbw['id']},
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
      bottomNavigationBar: const AdminBottomNavigation(currentIndex: 1),
    );
  }
}
