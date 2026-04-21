import 'package:flutter/material.dart';
import 'package:swiftlead/shared/theme.dart';
import 'package:swiftlead/components/technician_bottom_navigation.dart';
import 'package:swiftlead/services/service_request_service.dart';
import 'package:swiftlead/services/alert_service.dart';
import 'package:swiftlead/utils/token_manager.dart';
import 'package:swiftlead/utils/notification_manager.dart';

class TechnicianHomePage extends StatefulWidget {
  const TechnicianHomePage({super.key});

  @override
  State<TechnicianHomePage> createState() => _TechnicianHomePageState();
}

class _TechnicianHomePageState extends State<TechnicianHomePage> with WidgetsBindingObserver {
  double width(BuildContext context) => MediaQuery.of(context).size.width;
  double height(BuildContext context) => MediaQuery.of(context).size.height;

  final ServiceRequestService _serviceRequestService = ServiceRequestService();
  final AlertService _alertService = AlertService();
  final NotificationManager _notif = NotificationManager();

  bool _isLoading = true;
  String? _authToken;
  String _userName = 'Teknisi';

  int _assignedCount = 0;
  int _inProgressCount = 0;
  int _completedCount = 0;
  List<dynamic> _recentTasks = [];

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
      if (_authToken != null && mounted) {
        _loadAlerts();
      }
    }
  }

  Future<void> _initializeData() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      _authToken = await TokenManager.getToken();
      final name = await TokenManager.getUserName();
      if (name != null && name.isNotEmpty) {
        _userName = name;
      }

      if (_authToken != null) {
        await Future.wait([
          _loadAlerts(),
          _loadDashboardData(),
        ]).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            print('[TECH HOME] Dashboard data loading timeout');
            return [];
          },
        );
      }
    } catch (e) {
      print('[TECH HOME] Error initializing data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadDashboardData() async {
    if (_authToken == null) return;

    try {
      // Try myTasks first, fall back to list with filter
      Map<String, dynamic> result;
      try {
        result = await _serviceRequestService.myTasks(_authToken!);
      } catch (_) {
        result = await _serviceRequestService.list(_authToken!, queryParams: {'per_page': '100'});
      }

      if (result['success'] == true) {
        final data = (result['data'] as List?) ?? [];

        int assigned = 0;
        int inProgress = 0;
        int completed = 0;

        for (final item in data) {
          final status = (item['status'] ?? '').toString().toLowerCase();
          if (status == 'assigned') {
            assigned++;
          } else if (status == 'in_progress') {
            inProgress++;
          } else if (status == 'resolved' || status == 'completed') {
            completed++;
          }
        }

        if (mounted) {
          setState(() {
            _assignedCount = assigned;
            _inProgressCount = inProgress;
            _completedCount = completed;
            _recentTasks = data.take(5).toList();
          });
        }
      }
    } catch (e) {
      print('[TECH HOME] Error loading dashboard data: $e');
    }
  }

  Future<void> _loadAlerts() async {
    if (_authToken == null) return;
    try {
      final allRes = await _alertService.list(_authToken!, unreadOnly: false, perPage: 50);
      final allList = (allRes['data'] is List) ? List<Map<String, dynamic>>.from(allRes['data']) : <Map<String, dynamic>>[];
      _notif.replaceAll(allList);
    } catch (e) {
      print('[TECH HOME] Failed to load alerts: $e');
    }
  }

  Future<void> _showAlertsDialog() async {
    await _loadAlerts();
    if (!mounted) return;
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

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'assigned':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'resolved':
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'assigned':
        return 'Ditugaskan';
      case 'in_progress':
        return 'Sedang Dikerjakan';
      case 'resolved':
        return 'Selesai';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
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
                  Text('Memuat data teknisi...', style: TextStyle(color: Color(0xFF245C4C))),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _initializeData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: width(context) * 0.05, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Welcome header ---
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF245C4C), Color(0xFF2D7A65)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF245C4C).withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.engineering, color: Colors.white, size: 28),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Selamat Datang,',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white.withOpacity(0.8),
                                        ),
                                      ),
                                      Text(
                                        _userName,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Kelola tugas instalasi dan perawatan perangkat IoT',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.75),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // --- Stats cards ---
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Ditugaskan',
                              _assignedCount.toString(),
                              Icons.assignment_outlined,
                              Colors.orange[700]!,
                              () => Navigator.pushReplacementNamed(context, '/technician-tasks'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildStatCard(
                              'Dikerjakan',
                              _inProgressCount.toString(),
                              Icons.engineering,
                              Colors.blue[700]!,
                              () => Navigator.pushReplacementNamed(context, '/technician-installations'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildStatCard(
                              'Selesai',
                              _completedCount.toString(),
                              Icons.check_circle_outline,
                              Colors.green[700]!,
                              () {},
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // --- Quick actions ---
                      const Text(
                        'Aksi Cepat',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF245C4C),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildQuickActionCard(
                              'Lihat Tugas',
                              Icons.assignment,
                              const Color(0xFFFFF3E0),
                              Colors.orange[700]!,
                              () => Navigator.pushReplacementNamed(context, '/technician-tasks'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildQuickActionCard(
                              'Kelola Instalasi',
                              Icons.build_circle,
                              const Color(0xFFE3F2FD),
                              Colors.blue[700]!,
                              () => Navigator.pushReplacementNamed(context, '/technician-installations'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // --- Recent tasks ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Tugas Terbaru',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF245C4C),
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pushReplacementNamed(context, '/technician-tasks'),
                            child: const Text('Lihat Semua'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_recentTasks.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                'Belum ada tugas',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tugas akan muncul di sini saat admin menugaskan Anda',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        )
                      else
                        ...(_recentTasks.map((task) {
                          final issue = task['issue']?.toString() ?? task['type']?.toString() ?? 'Tugas';
                          final rbwName = task['rbw']?['name']?.toString() ?? task['rbw_id']?.toString() ?? '-';
                          final status = task['status']?.toString() ?? 'unknown';
                          final serviceType = task['type']?.toString() ?? '';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _statusColor(status).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  serviceType == 'installation' ? Icons.build : Icons.settings,
                                  color: _statusColor(status),
                                  size: 24,
                                ),
                              ),
                              title: Text(
                                issue,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                'RBW: $rbwName',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _statusColor(status).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _statusLabel(status),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _statusColor(status),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList()),

                      const SizedBox(height: 24),

                      // --- Profile quick link ---
                      InkWell(
                        onTap: () => Navigator.pushNamed(context, '/profile-page'),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF245C4C).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.person, color: Color(0xFF245C4C)),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Profil Saya', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                    Text('Lihat dan edit profil', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: Colors.grey),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
      bottomNavigationBar: const TechnicianBottomNavigation(currentIndex: 0),
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(
    String label,
    IconData icon,
    Color bgColor,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 32),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: iconColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
