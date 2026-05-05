import 'package:flutter/material.dart';
import 'package:swiftlead/components/technician_bottom_navigation.dart';
import 'package:swiftlead/services/service_request_service.dart';
import 'package:swiftlead/services/node_service.dart';
import 'package:swiftlead/services/rbw_service.dart';
import 'package:swiftlead/utils/token_manager.dart';
import 'package:swiftlead/utils/modern_snackbar.dart';

class TechnicianInstallationsPage extends StatefulWidget {
  const TechnicianInstallationsPage({super.key});
  @override
  State<TechnicianInstallationsPage> createState() =>
      _TechnicianInstallationsPageState();
}

class _TechnicianInstallationsPageState
    extends State<TechnicianInstallationsPage> {
  final ServiceRequestService _srService = ServiceRequestService();
  final NodeService _nodeService = NodeService();
  final RbwService _rbwService = RbwService();
  bool _isLoading = true;
  String? _authToken;
  List<dynamic> _installations = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      _authToken = await TokenManager.getToken();
      if (_authToken == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      Map<String, dynamic> result;
      try {
        result = await _srService.myTasks(_authToken!);
      } catch (_) {
        result = await _srService
            .list(_authToken!, queryParams: {'per_page': '100'});
      }
      if (result['success'] == true) {
        final data = (result['data'] as List?) ?? [];

        // Enrich each task with RBW details (name, address, owner)
        final enriched = <dynamic>[];
        final rbwCache = <String, Map<String, dynamic>>{};
        for (final item in data) {
          final rbwId = item['rbw_id']?.toString() ?? '';
          if (rbwId.isNotEmpty && item['rbw'] == null) {
            if (!rbwCache.containsKey(rbwId)) {
              try {
                final rbwRes =
                    await _rbwService.getRbw(token: _authToken!, rbwId: rbwId);
                if (rbwRes['success'] == true && rbwRes['data'] != null) {
                  rbwCache[rbwId] = rbwRes['data'] as Map<String, dynamic>;
                }
              } catch (e) {
                print('[TECH INSTALL] Failed to fetch RBW $rbwId: $e');
              }
            }
            if (rbwCache.containsKey(rbwId)) {
              (item as Map<String, dynamic>)['rbw'] = rbwCache[rbwId];
            }
          }
          enriched.add(item);
        }

        if (mounted)
          setState(() {
            _installations = enriched;
            _isLoading = false;
          });
      } else {
        if (mounted)
          setState(() {
            _installations = [];
            _isLoading = false;
          });
      }
    } catch (e) {
      print('[TECH INSTALL] Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'assigned':
        return Colors.orange[700]!;
      case 'in_progress':
        return Colors.blue[700]!;
      case 'resolved':
      case 'completed':
        return Colors.green[700]!;
      case 'cancelled':
        return Colors.red[700]!;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String s) {
    switch (s.toLowerCase()) {
      case 'assigned':
        return 'Ditugaskan';
      case 'in_progress':
        return 'Dikerjakan';
      case 'resolved':
        return 'Selesai';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return s;
    }
  }

  String _nextStatus(String current) {
    switch (current.toLowerCase()) {
      case 'assigned':
        return 'in_progress';
      case 'in_progress':
        return 'resolved';
      default:
        return '';
    }
  }

  String _nextStatusLabel(String current) {
    switch (current.toLowerCase()) {
      case 'assigned':
        return 'Mulai Kerjakan';
      case 'in_progress':
        return 'Selesaikan';
      default:
        return '';
    }
  }

  Future<void> _changeStatus(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    final currentStatus = (item['status'] ?? '').toString();
    final next = _nextStatus(currentStatus);
    if (next.isEmpty || _authToken == null) return;

    if (next == 'resolved') {
      // When resolving, show node management first
      final rbwId =
          item['rbw_id']?.toString() ?? item['rbw']?['id']?.toString() ?? '';
      if (rbwId.isNotEmpty) {
        await _showNodeManagement(rbwId, id);
      } else {
        await _doStatusChange(id, next);
      }
    } else {
      await _doStatusChange(id, next);
    }
  }

  Future<void> _doStatusChange(String id, String newStatus) async {
    final res =
        await _srService.patchStatus(_authToken!, id, {'status': newStatus});
    if (!mounted) return;
    if (res['success'] == true) {
      ModernSnackBar.success(context, 'Status berhasil diubah');
      await _load();
    } else {
      // Try update fallback
      final res2 =
          await _srService.update(_authToken!, id, {'status': newStatus});
      if (!mounted) return;
      if (res2['success'] == true) {
        ModernSnackBar.success(context, 'Status berhasil diubah');
        await _load();
      } else {
        ModernSnackBar.error(
            context, 'Gagal mengubah status: ${res2['message'] ?? ''}');
      }
    }
  }

  Future<void> _showNodeManagement(
      String rbwId, String serviceRequestId) async {
    List<dynamic> nodes = [];
    bool loadingNodes = true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          // Load nodes on first build
          if (loadingNodes) {
            loadingNodes = false;
            _nodeService.listByRbw(_authToken!, rbwId).then((res) {
              if (res['success'] == true) {
                setSheetState(() {
                  nodes = (res['data'] as List?) ?? [];
                });
              } else {
                setSheetState(() {
                  nodes = [];
                });
              }
            });
          }

          return Container(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.95),
            padding: const EdgeInsets.only(bottom: 80),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Kelola Node & Perangkat IoT',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF245C4C))),
                        IconButton(
                          icon: const Icon(Icons.add_circle,
                              color: Color(0xFF245C4C), size: 28),
                          onPressed: () => _showAddNodeDialog(
                              ctx,
                              rbwId,
                              setSheetState,
                              nodes,
                              (n) => setSheetState(() => nodes = n)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: nodes.isEmpty
                        ? Center(
                            child:
                                Column(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.device_hub,
                                size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text('Belum ada node',
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 15)),
                            const SizedBox(height: 4),
                            Text('Tambahkan node untuk RBW ini',
                                style: TextStyle(
                                    color: Colors.grey[400], fontSize: 13)),
                          ]))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: nodes.length,
                            itemBuilder: (ctx, i) {
                              final node = nodes[i] as Map<String, dynamic>;
                              if (node['uninstalled_at'] != null)
                                return const SizedBox(); // Hide uninstalled

                              final nodeId = node['id']?.toString() ?? '';
                              final nodeCode =
                                  node['node_code']?.toString() ?? 'Unknown';
                              final type = node['node_type']?.toString() ?? '-';
                              final esp32 = node['esp32_uid']?.toString() ?? '-';
                              final status =
                                  node['status_node']?.toString() ?? 'offline';
                              final isOnline = status.toLowerCase() == 'online';
                              final hasAudio = node['has_audio'] == true;
                              final hasPump = node['has_pump'] == true;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: isOnline
                                          ? Colors.green[200]!
                                          : Colors.grey[200]!),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.03),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2))
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: (isOnline
                                                ? Colors.green
                                                : Colors.grey)
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(_nodeTypeIcon(type),
                                          color: isOnline
                                              ? Colors.green[700]
                                              : Colors.grey,
                                          size: 24),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(nodeCode,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 4),
                                        Text(
                                            'Tipe: ${type.toUpperCase()} · ESP32: $esp32',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600])),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isOnline
                                                    ? Colors.green[100]
                                                    : Colors.grey[200],
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(status.toUpperCase(),
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: isOnline
                                                          ? Colors.green[800]
                                                          : Colors.grey[800],
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ),
                                            if (hasAudio) ...[
                                              const SizedBox(width: 8),
                                              const Icon(Icons.speaker,
                                                  size: 14,
                                                  color: Colors.blueGrey),
                                            ],
                                            if (hasPump) ...[
                                              const SizedBox(width: 8),
                                              const Icon(Icons.water_drop,
                                                  size: 14,
                                                  color: Colors.blueAccent),
                                            ]
                                          ],
                                        ),
                                      ],
                                    )),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          size: 22, color: Colors.red),
                                      tooltip: 'Uninstall Node',
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: ctx,
                                          builder: (c) => AlertDialog(
                                            title: const Text('Uninstall Node?'),
                                            content: Text(
                                                'Apakah Anda yakin ingin melakukan uninstall pada node $nodeCode?'),
                                            actions: [
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(c, false),
                                                  child: const Text('Batal')),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.red,
                                                    foregroundColor:
                                                        Colors.white),
                                                onPressed: () =>
                                                    Navigator.pop(c, true),
                                                child: const Text('Uninstall'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          final payload = {
                                            'uninstalled_at': DateTime.now()
                                                .toUtc()
                                                .toIso8601String(),
                                            'status_node': 'offline'
                                          };
                                          final res = await _nodeService.update(
                                              _authToken!, nodeId, payload);
                                          if (res['success'] == true) {
                                            ModernSnackBar.success(context,
                                                'Node berhasil di-uninstall');
                                            final refreshRes = await _nodeService
                                                .listByRbw(_authToken!, rbwId);
                                            if (refreshRes['success'] == true) {
                                              setSheetState(() => nodes =
                                                  (refreshRes['data'] as List?) ??
                                                      []);
                                            }
                                          } else {
                                            ModernSnackBar.error(context,
                                                'Gagal uninstall node: ${res['message']}');
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  // Complete button
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _doStatusChange(serviceRequestId, 'resolved');
                        },
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Selesaikan Instalasi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            );
          },
        );
      },
    );
  }

  IconData _nodeTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'gateway':
        return Icons.router;
      case 'nest':
        return Icons.sensors;
      case 'lmb':
        return Icons.speaker;
      case 'pump':
        return Icons.water_drop;
      default:
        return Icons.device_hub;
    }
  }

  void _showAddNodeDialog(
      BuildContext ctx,
      String rbwId,
      StateSetter setSheetState,
      List<dynamic> nodes,
      Function(List<dynamic>) updateNodes) {
    final nodeCodeCtrl = TextEditingController();
    final esp32UidCtrl = TextEditingController();
    String selectedType = 'gateway';
    bool hasAudio = false;
    bool hasPump = false;
    bool isSubmitting = false;
    final types = ['gateway', 'nest', 'lmb', 'pump'];

    showDialog(
      context: ctx,
      builder: (dialogCtx) {
        return StatefulBuilder(builder: (dCtx, setDState) {
          return AlertDialog(
            title: const Text('Tambah Node',
                style: TextStyle(color: Color(0xFF245C4C))),
            content: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: nodeCodeCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Kode Node', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedType,
                items: types
                    .map((t) => DropdownMenuItem(
                        value: t, child: Text(t.toUpperCase())))
                    .toList(),
                onChanged: (v) =>
                    setDState(() => selectedType = v ?? 'gateway'),
                decoration: const InputDecoration(
                    labelText: 'Tipe Node', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: esp32UidCtrl,
                  decoration: const InputDecoration(
                      labelText: 'ESP32 UID (opsional)',
                      hintText: 'Contoh: 30AEA4123456 (MAC Address)',
                      border: OutlineInputBorder())),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Mendukung Audio',
                    style: TextStyle(fontSize: 14)),
                value: hasAudio,
                onChanged: (v) => setDState(() => hasAudio = v),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: const Text('Mendukung Pompa Air',
                    style: TextStyle(fontSize: 14)),
                value: hasPump,
                onChanged: (v) => setDState(() => hasPump = v),
                contentPadding: EdgeInsets.zero,
              ),
            ])),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.of(dCtx).pop(),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        print('[ADD NODE] === Tambah button pressed ===');
                        print('[ADD NODE] rbwId: $rbwId');
                        print('[ADD NODE] nodeCode: ${nodeCodeCtrl.text}');
                        print('[ADD NODE] selectedType: $selectedType');
                        print('[ADD NODE] esp32Uid: ${esp32UidCtrl.text}');
                        print(
                            '[ADD NODE] hasAudio: $hasAudio, hasPump: $hasPump');
                        print(
                            '[ADD NODE] authToken present: ${_authToken != null}');

                        if (nodeCodeCtrl.text.isEmpty) {
                          print('[ADD NODE] ERROR: Node code is empty');
                          ModernSnackBar.error(
                              context, 'Kode Node tidak boleh kosong');
                          return;
                        }

                        setDState(() => isSubmitting = true);

                        try {
                          final payload = {
                            'node_code': nodeCodeCtrl.text,
                            'node_type': selectedType,
                            if (esp32UidCtrl.text.isNotEmpty)
                              'esp32_uid': esp32UidCtrl.text,
                            'has_audio': hasAudio,
                            'has_pump': hasPump,
                            'installed_at':
                                DateTime.now().toUtc().toIso8601String(),
                          };
                          print('[ADD NODE] Payload: $payload');
                          print('[ADD NODE] Calling createUnderRbw...');

                          final res = await _nodeService.createUnderRbw(
                              _authToken!, rbwId, payload);
                          print('[ADD NODE] Response: $res');

                          // Close dialog after getting response
                          if (Navigator.canPop(dCtx)) {
                            Navigator.of(dCtx).pop();
                          }

                          if (res['success'] == true) {
                            print(
                                '[ADD NODE] SUCCESS! Refreshing node list...');
                            final refreshRes = await _nodeService.listByRbw(
                                _authToken!, rbwId);
                            if (refreshRes['success'] == true) {
                              updateNodes((refreshRes['data'] as List?) ?? []);
                            }
                            if (mounted) {
                              ModernSnackBar.success(
                                  context, 'Node berhasil ditambahkan!');
                            }
                          } else {
                            final msg = res['message'];
                            String errorMsg;
                            if (msg is Map) {
                              errorMsg =
                                  msg['message']?.toString() ?? msg.toString();
                            } else {
                              errorMsg = msg?.toString() ?? 'Unknown error';
                            }

                            // Translate technical errors
                            if (errorMsg.contains('uq_node_per_rbw')) {
                              errorMsg =
                                  'Kode Node "${nodeCodeCtrl.text}" sudah terdaftar untuk gedung ini. Gunakan kode lain.';
                            } else if (errorMsg.contains('duplicate key')) {
                              errorMsg = 'Data ini sudah ada di sistem.';
                            }

                            print('[ADD NODE] FAILED: $errorMsg');
                            if (mounted) {
                              ModernSnackBar.error(context, 'Gagal: $errorMsg');
                            }
                          }
                        } catch (e, stackTrace) {
                          print('[ADD NODE] EXCEPTION: $e');
                          print('[ADD NODE] STACK: $stackTrace');
                          setDState(() => isSubmitting = false);
                          if (mounted) {
                            ModernSnackBar.error(context, 'Error: $e');
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF245C4C),
                    foregroundColor: Colors.white),
                child: isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Tambah'),
              ),
            ],
          );
        });
      },
    );
  }

  void _showInstallationDetail(Map<String, dynamic> item) {
    final issue =
        item['issue']?.toString() ?? item['type']?.toString() ?? 'Instalasi';
    final rbwName =
        item['rbw']?['name']?.toString() ?? item['rbw_id']?.toString() ?? '-';
    final rbwAddr = item['rbw']?['address']?.toString() ?? '-';
    final owner = item['rbw']?['owner']?['name']?.toString() ??
        item['rbw']?['owner_name']?.toString() ??
        '-';
    final status = item['status']?.toString() ?? '';
    final type = item['type']?.toString() ?? '-';
    final desc =
        item['issue']?.toString() ?? item['description']?.toString() ?? '-';
    final notes = item['notes']?.toString() ?? '-';
    final schedule = item['schedule_date']?.toString() ?? '-';
    final next = _nextStatus(status);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.95),
        padding: const EdgeInsets.only(bottom: 80),
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2)))),
              Text(issue,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF245C4C))),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(_statusLabel(status),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _statusColor(status))),
              ),
              const SizedBox(height: 16),
              const Divider(),
              _dRow('Tipe', type),
              _dRow('RBW', rbwName),
              _dRow('Alamat', rbwAddr),
              _dRow('Pemilik', owner),
              _dRow('Deskripsi', desc),
              if (notes != '-') _dRow('Catatan', notes),
              _dRow('Jadwal', _fmtDate(schedule)),
              const SizedBox(height: 16),
              if (next.isNotEmpty)
                SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _changeStatus(item);
                      },
                      icon: Icon(next == 'resolved'
                          ? Icons.check_circle
                          : Icons.play_arrow),
                      label: Text(_nextStatusLabel(status)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: next == 'resolved'
                            ? Colors.green[700]
                            : Colors.blue[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    )),
              if (status.toLowerCase() == 'assigned' ||
                  status.toLowerCase() == 'in_progress' ||
                  status.toLowerCase() == 'resolved') ...[
                const SizedBox(height: 16),
                SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        final rbwId = item['rbw_id']?.toString() ??
                            item['rbw']?['id']?.toString() ??
                            '';
                        if (rbwId.isNotEmpty)
                          _showNodeManagement(
                              rbwId, item['id']?.toString() ?? '');
                      },
                      icon: const Icon(Icons.device_hub),
                      label: const Text('Kelola Node & Perangkat'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF245C4C),
                        side: const BorderSide(color: Color(0xFF245C4C)),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    )),
              ],
              const SizedBox(height: 80),
            ]),
          ),
        ),
      );
  }

  Widget _dRow(String l, String v) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 100,
            child: Text(l,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600]))),
        Expanded(
            child: Text(v,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500))),
      ]));

  String _fmtDate(String d) {
    if (d == '-' || d.isEmpty) return '-';
    try {
      final dt = DateTime.parse(d);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return d;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Kelola Instalasi',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF245C4C))),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF245C4C)),
              onPressed: _load)
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF245C4C)))
          : RefreshIndicator(
              onRefresh: _load,
              child: _installations.isEmpty
                  ? ListView(children: [
                      const SizedBox(height: 150),
                      Center(
                          child: Column(children: [
                        Icon(Icons.build_circle_outlined,
                            size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('Belum ada instalasi',
                            style: TextStyle(
                                fontSize: 16, color: Colors.grey[500])),
                      ])),
                    ])
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _installations.length,
                      itemBuilder: (ctx, i) {
                        final item = _installations[i] as Map<String, dynamic>;
                        final issue = item['issue']?.toString() ??
                            item['type']?.toString() ??
                            'Instalasi';
                        final rbwName = item['rbw']?['name']?.toString() ??
                            item['rbw_id']?.toString() ??
                            '-';
                        final status = item['status']?.toString() ?? '';
                        final next = _nextStatus(status);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey[200]!),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2))
                            ],
                          ),
                          child: InkWell(
                            onTap: () => _showInstallationDetail(item),
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                            color: _statusColor(status)
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        child: Icon(Icons.build,
                                            color: _statusColor(status),
                                            size: 24),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                            Text(issue,
                                                style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight:
                                                        FontWeight.w600),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis),
                                            const SizedBox(height: 4),
                                            Text('RBW: $rbwName',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600])),
                                          ])),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                            color: _statusColor(status)
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(20)),
                                        child: Text(_statusLabel(status),
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: _statusColor(status))),
                                      ),
                                    ]),
                                    if (next.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            TextButton.icon(
                                              onPressed: () =>
                                                  _changeStatus(item),
                                              icon: Icon(
                                                  next == 'resolved'
                                                      ? Icons.check_circle
                                                      : Icons.play_arrow,
                                                  size: 18),
                                              label: Text(
                                                  _nextStatusLabel(status),
                                                  style: const TextStyle(
                                                      fontSize: 13)),
                                              style: TextButton.styleFrom(
                                                  foregroundColor:
                                                      next == 'resolved'
                                                          ? Colors.green[700]
                                                          : Colors.blue[700]),
                                            ),
                                          ]),
                                    ],
                                  ]),
                            ),
                          ),
                        );
                      },
                    ),
            ),
      bottomNavigationBar: const TechnicianBottomNavigation(currentIndex: 2),
    );
  }
}
