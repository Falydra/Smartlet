import 'package:flutter/material.dart';
import 'package:swiftlead/shared/theme.dart';
import 'package:swiftlead/components/technician_bottom_navigation.dart';
import 'package:swiftlead/services/service_request_service.dart';
import 'package:swiftlead/utils/token_manager.dart';

class TechnicianTasksPage extends StatefulWidget {
  const TechnicianTasksPage({super.key});

  @override
  State<TechnicianTasksPage> createState() => _TechnicianTasksPageState();
}

class _TechnicianTasksPageState extends State<TechnicianTasksPage> {
  final ServiceRequestService _service = ServiceRequestService();

  bool _isLoading = true;
  String? _authToken;
  List<dynamic> _allTasks = [];
  List<dynamic> _filteredTasks = [];
  String _selectedFilter = 'all';

  final List<Map<String, String>> _filters = [
    {'key': 'all', 'label': 'Semua'},
    {'key': 'assigned', 'label': 'Ditugaskan'},
    {'key': 'in_progress', 'label': 'Dikerjakan'},
    {'key': 'resolved', 'label': 'Selesai'},
  ];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      _authToken = await TokenManager.getToken();
      if (_authToken == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Try myTasks endpoint first, fall back to list
      Map<String, dynamic> result;
      try {
        result = await _service.myTasks(_authToken!);
      } catch (_) {
        result = await _service.list(_authToken!, queryParams: {'per_page': '100'});
      }

      if (result['success'] == true) {
        final data = (result['data'] as List?) ?? [];
        if (mounted) {
          setState(() {
            _allTasks = data;
            _applyFilter();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _allTasks = [];
            _filteredTasks = [];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('[TECH TASKS] Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    if (_selectedFilter == 'all') {
      _filteredTasks = List.from(_allTasks);
    } else {
      _filteredTasks = _allTasks.where((task) {
        final status = (task['status'] ?? '').toString().toLowerCase();
        return status == _selectedFilter;
      }).toList();
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.amber[700]!;
      case 'approved':
        return Colors.teal;
      case 'assigned':
        return Colors.orange[700]!;
      case 'in_progress':
        return Colors.blue[700]!;
      case 'resolved':
      case 'completed':
        return Colors.green[700]!;
      case 'rejected':
      case 'cancelled':
        return Colors.red[700]!;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Menunggu';
      case 'approved':
        return 'Disetujui';
      case 'assigned':
        return 'Ditugaskan';
      case 'in_progress':
        return 'Dikerjakan';
      case 'resolved':
        return 'Selesai';
      case 'completed':
        return 'Selesai';
      case 'rejected':
        return 'Ditolak';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  IconData _serviceTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'installation':
        return Icons.build;
      case 'maintenance':
        return Icons.settings;
      case 'uninstall':
        return Icons.delete_outline;
      default:
        return Icons.assignment;
    }
  }

  String _serviceTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'installation':
        return 'Instalasi';
      case 'maintenance':
        return 'Perawatan';
      case 'uninstall':
        return 'Uninstall';
      default:
        return type;
    }
  }

  void _showTaskDetail(Map<String, dynamic> task) {
    final id = task['id']?.toString() ?? '';
    final issue = task['issue']?.toString() ?? task['type']?.toString() ?? 'Tugas';
    final description = task['description']?.toString() ?? '-';
    final rbwName = task['rbw']?['name']?.toString() ?? task['rbw_id']?.toString() ?? '-';
    final rbwAddress = task['rbw']?['address']?.toString() ?? '-';
    final ownerName = task['rbw']?['owner']?['name']?.toString() ?? task['user']?['name']?.toString() ?? '-';
    final status = task['status']?.toString() ?? 'unknown';
    final serviceType = task['type']?.toString() ?? '-';
    final scheduleDate = task['schedule_date']?.toString() ?? '-';
    final createdAt = task['created_at']?.toString() ?? '-';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _statusColor(status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_serviceTypeIcon(serviceType), color: _statusColor(status), size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  issue,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _statusColor(status).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _statusLabel(status),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _statusColor(status),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),

                      // Detail fields
                      _detailRow('Tipe Layanan', _serviceTypeLabel(serviceType)),
                      _detailRow('RBW', rbwName),
                      _detailRow('Alamat', rbwAddress),
                      _detailRow('Pemilik', ownerName),
                      _detailRow('Deskripsi', description),
                      _detailRow('Jadwal', _formatDate(scheduleDate)),
                      _detailRow('Dibuat', _formatDate(createdAt)),

                      const SizedBox(height: 20),

                      // Action buttons
                      if (status.toLowerCase() == 'assigned' || status.toLowerCase() == 'in_progress')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              // Navigate to installation management
                              Navigator.pushReplacementNamed(context, '/technician-installations');
                            },
                            icon: const Icon(Icons.build),
                            label: const Text('Kelola Instalasi'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF245C4C),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr == '-' || dateStr.isEmpty) return '-';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Tugas Saya',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF245C4C),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF245C4C)),
            onPressed: _loadTasks,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter['key'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(
                        filter['label']!,
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF245C4C),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      selectedColor: const Color(0xFF245C4C),
                      backgroundColor: const Color(0xFF245C4C).withOpacity(0.08),
                      checkmarkColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF245C4C) : const Color(0xFF245C4C).withOpacity(0.3),
                        ),
                      ),
                      onSelected: (selected) {
                        setState(() {
                          _selectedFilter = filter['key']!;
                          _applyFilter();
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Task count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  '${_filteredTasks.length} tugas',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          // Task list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF245C4C)),
                  )
                : RefreshIndicator(
                    onRefresh: _loadTasks,
                    child: _filteredTasks.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 120),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[300]),
                                    const SizedBox(height: 16),
                                    Text(
                                      _selectedFilter == 'all'
                                          ? 'Belum ada tugas'
                                          : 'Tidak ada tugas dengan status ini',
                                      style: TextStyle(fontSize: 16, color: Colors.grey[500], fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            itemCount: _filteredTasks.length,
                            itemBuilder: (context, index) {
                              final task = _filteredTasks[index] as Map<String, dynamic>;
                              final issue = task['issue']?.toString() ?? task['type']?.toString() ?? 'Tugas';
                              final rbwName = task['rbw']?['name']?.toString() ?? task['rbw_id']?.toString() ?? '-';
                              final status = task['status']?.toString() ?? 'unknown';
                              final serviceType = task['type']?.toString() ?? '';
                              final scheduleDate = task['schedule_date']?.toString() ?? '';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.grey[200]!),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: InkWell(
                                  onTap: () => _showTaskDetail(task),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      children: [
                                        // Icon
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: _statusColor(status).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            _serviceTypeIcon(serviceType),
                                            color: _statusColor(status),
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Content
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                issue,
                                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(Icons.home_work, size: 14, color: Colors.grey[500]),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      'RBW: $rbwName',
                                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (scheduleDate.isNotEmpty && scheduleDate != 'null') ...[
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    Icon(Icons.schedule, size: 14, color: Colors.grey[500]),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      _formatDate(scheduleDate),
                                                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Status badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: const TechnicianBottomNavigation(currentIndex: 1),
    );
  }
}
