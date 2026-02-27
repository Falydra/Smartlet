import 'package:flutter/material.dart';
import 'package:swiftlead/shared/theme.dart';
import 'package:swiftlead/components/admin_bottom_navigation.dart';
import 'package:swiftlead/services/rbw_service.dart';
import 'package:swiftlead/services/harvest_service.dart';
import 'package:swiftlead/services/auth_services.dart.dart';
import 'package:swiftlead/services/transaction_service.dart';
import 'package:swiftlead/utils/token_manager.dart';
import 'package:swiftlead/services/alert_service.dart';
import 'package:swiftlead/utils/notification_manager.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> with WidgetsBindingObserver {
  double width(BuildContext context) => MediaQuery.of(context).size.width;
  double height(BuildContext context) => MediaQuery.of(context).size.height;


  final AlertService _alertService = AlertService();
  final NotificationManager _notif = NotificationManager();
  final RbwService _rbwService = RbwService();
  final HarvestService _harvestService = HarvestService();
  final AuthService _authService = AuthService();
  final TransactionService _transactionService = TransactionService();


  bool _isLoading = true;
  String? _authToken;
  int _rbwCount = 0;
  int _harvestCount = 0;
  int _userCount = 0;
  int _transactionCount = 0;
  List<dynamic> _recentRbw = [];
  List<dynamic> _recentHarvests = [];
  List<dynamic> _recentUsers = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      print('[ADMIN HOME] App resumed, refreshing data...');
      if (_authToken != null && mounted) {
        _loadAlerts();
      }
    }
  }

  Future<void> _initializeData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    
    try {
      _authToken = await TokenManager.getToken();
      
      if (_authToken != null) {
        await Future.wait([
          _loadAlerts(),
          _loadDashboardData(),
        ]).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            print('Dashboard data loading timeout');
            return [];
          },
        );
      }
    } catch (e) {
      print('Error initializing admin data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadDashboardData() async {
    if (_authToken == null) return;
    
    try {

      final rbwResult = await _rbwService.listRbw(token: _authToken!, limit: 5);
      if (rbwResult['success'] == true) {
        setState(() {
          _recentRbw = (rbwResult['data'] as List).take(5).toList();
          _rbwCount = rbwResult['meta']?['total'] ?? _recentRbw.length;
        });
      }


      final harvestResult = await _harvestService.list(
        token: _authToken!,
        queryParams: {'limit': '5'},
      );
      if (harvestResult['success'] == true) {
        setState(() {
          _recentHarvests = (harvestResult['data'] as List).take(5).toList();
          _harvestCount = harvestResult['meta']?['total'] ?? _recentHarvests.length;
        });
      }


      final userResult = await _authService.listUsers(
        token: _authToken!,
        limit: 5,
      );
      if (userResult['success'] == true) {
        setState(() {
          _recentUsers = (userResult['data'] as List).take(5).toList();
          _userCount = userResult['meta']?['total'] ?? _recentUsers.length;
        });
      }


      if (_recentRbw.isNotEmpty) {
        final firstRbwId = _recentRbw.first['id']?.toString();
        if (firstRbwId != null) {
          final txResult = await _transactionService.listTransactionsByRbw(
            token: _authToken!,
            rbwId: firstRbwId,
            limit: 1,
          );
          if (txResult['success'] == true) {
            setState(() {
              _transactionCount = txResult['meta']?['total'] ?? 0;
            });
          }
        }
      }
    } catch (e) {
      print('Error loading dashboard data: $e');
    }
  }

  Future<void> _loadAlerts() async {
    if (_authToken == null) return;
    try {
      final allRes = await _alertService.list(_authToken!, unreadOnly: false, perPage: 50);
      final allList = (allRes['data'] is List) ? List<Map<String, dynamic>>.from(allRes['data']) : <Map<String, dynamic>>[];
      _notif.replaceAll(allList);
    } catch (e) {
      print('Failed to load alerts: $e');
    }
  }

  Future<void> _showAlertsDialog() async {
    await _loadAlerts();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Notifikasi'),
          content: SizedBox(
            width: double.maxFinite,
            child: ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: _notif.alerts,
              builder: (context, list, _) {
                if (list.isEmpty) return const Text('Tidak ada notifikasi');
                return SingleChildScrollView(
                  child: Column(
                    children: list.map((a) {
                      final isUnread = !(a['is_read'] == true);
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          a['title']?.toString() ?? 'Alert',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isUnread ? Colors.black : Colors.black54,
                          ),
                        ),
                        subtitle: Text(a['message']?.toString() ?? ''),
                        trailing: isUnread ? const Icon(Icons.fiber_new, color: Colors.redAccent, size: 16) : null,
                        onTap: () async {
                          if (_authToken != null && a['synthetic'] != true) {
                            try { 
                              await _alertService.markRead(_authToken!, a['id'].toString()); 
                            } catch (_) {}
                          }
                          _notif.markRead(a['id'].toString());
                        },
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: ValueListenableBuilder<int>(
              valueListenable: _notif.unreadCount,
              builder: (context, count, _) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: Icon(Icons.notifications_on_outlined, color: blue500),
                      onPressed: () async {
                        await _showAlertsDialog();
                      },
                    ),
                    if (count > 0)
                      Positioned(
                        right: 4,
                        top: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            count.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Color(0xFF245C4C)),
                SizedBox(height: 16),
                Text('Memuat data admin...', style: TextStyle(color: Color(0xFF245C4C))),
              ],
            ),
          )
        : SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: width(context) * 0.05, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const Text(
                    'Admin Dashboard',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF245C4C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kelola sistem dan permintaan pengguna',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),


                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'RBW',
                          _rbwCount.toString(),
                          Icons.home_work,
                          const Color(0xFF245C4C),
                          () => Navigator.pushNamed(context, '/admin-rbw'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Harvests',
                          _harvestCount.toString(),
                          Icons.agriculture,
                          Colors.green[700]!,
                          () => Navigator.pushNamed(context, '/admin-harvest'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Users',
                          _userCount.toString(),
                          Icons.people,
                          Colors.blue[700]!,
                          () => Navigator.pushNamed(context, '/admin-users'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Transactions',
                          _transactionCount.toString(),
                          Icons.account_balance_wallet,
                          Colors.orange[700]!,
                          () => Navigator.pushNamed(context, '/admin-finance'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),


                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.settings, color: Color(0xFF245C4C), size: 24),
                              SizedBox(width: 8),
                              Text(
                                'Admin Tools',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.people, color: Colors.blue),
                            title: const Text('User Management'),
                            subtitle: const Text('Manage users and permissions'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.pushNamed(context, '/admin-users'),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.agriculture, color: Colors.green),
                            title: const Text('Harvest Management'),
                            subtitle: const Text('View and manage harvest records'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.pushNamed(context, '/admin-harvest'),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.account_balance_wallet, color: Colors.orange),
                            title: const Text('Finance & Transactions'),
                            subtitle: const Text('Manage financial transactions'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.pushNamed(context, '/admin-finance'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),


                  if (_recentRbw.isNotEmpty) ...[
                    _buildSectionCard(
                      title: 'Recent RBW',
                      icon: Icons.home_work,
                      color: const Color(0xFF245C4C),
                      count: _rbwCount,
                      onViewAll: () => Navigator.pushNamed(context, '/admin-rbw'),
                      children: _recentRbw.map((rbw) {
                        final name = rbw['name']?.toString() ?? 'Unknown';
                        final code = rbw['code']?.toString() ?? '-';
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.home_work, size: 20),
                          title: Text(name, style: const TextStyle(fontSize: 14)),
                          subtitle: Text('Code: $code', style: const TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right, size: 16),
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/kandang-detail',
                            arguments: {'houseId': rbw['id']},
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],


                  if (_recentHarvests.isNotEmpty) ...[
                    _buildSectionCard(
                      title: 'Recent Harvests',
                      icon: Icons.agriculture,
                      color: Colors.green[700]!,
                      count: _harvestCount,
                      onViewAll: () => Navigator.pushNamed(context, '/admin-harvest'),
                      children: _recentHarvests.map((harvest) {
                        final rbwName = harvest['rbw']?['name']?.toString() ?? 'Unknown';
                        final nestsCount = harvest['nests_count']?.toString() ?? '0';
                        final weightKg = harvest['weight_kg']?.toString() ?? '0';
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.agriculture, size: 20),
                          title: Text(rbwName, style: const TextStyle(fontSize: 14)),
                          subtitle: Text('$nestsCount nests, $weightKg kg', style: const TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right, size: 16),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],


                  if (_recentUsers.isNotEmpty) ...[
                    _buildSectionCard(
                      title: 'Recent Users',
                      icon: Icons.people,
                      color: Colors.blue[700]!,
                      count: _userCount,
                      onViewAll: () => Navigator.pushNamed(context, '/admin-users'),
                      children: _recentUsers.map((user) {
                        final name = user['name']?.toString() ?? 'Unknown';
                        final email = user['email']?.toString() ?? '-';
                        final role = user['role']?.toString() ?? 'farmer';
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.person, size: 20),
                          title: Text(name, style: const TextStyle(fontSize: 14)),
                          subtitle: Text('$email · $role', style: const TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.chevron_right, size: 16),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
      bottomNavigationBar: const AdminBottomNavigation(currentIndex: 0),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required int count,
    required VoidCallback onViewAll,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: onViewAll,
                  child: Text('View All ($count)'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}
