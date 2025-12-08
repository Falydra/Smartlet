import 'package:flutter/foundation.dart';

class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  // Unread badge counter
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  // Simple in-memory store of alerts
  final ValueNotifier<List<Map<String,dynamic>>> alerts = ValueNotifier<List<Map<String,dynamic>>>([]);

  void setUnreadCount(int count) {
    unreadCount.value = count < 0 ? 0 : count;
  }

  void addAlert(Map<String,dynamic> alert) {
    final list = List<Map<String,dynamic>>.from(alerts.value);
    list.insert(0, alert);
    alerts.value = list;
    setUnreadCount(unreadCount.value + 1);
  }

  void markRead(String alertId) {
    final list = List<Map<String,dynamic>>.from(alerts.value);
    for (final a in list) {
      if (a['id']?.toString() == alertId) {
        a['is_read'] = true;
        break;
      }
    }
    alerts.value = list;
    setUnreadCount(unreadCount.value - 1);
  }

  void replaceAll(List<Map<String,dynamic>> newAlerts) {
    alerts.value = newAlerts;
    final unread = newAlerts.where((a) => a['is_read'] == false || a['read_at'] == null).length;
    setUnreadCount(unread);
  }
}
