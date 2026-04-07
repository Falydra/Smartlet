import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class LocalNotificationHelper {
  static final LocalNotificationHelper _instance =
      LocalNotificationHelper._internal();
  factory LocalNotificationHelper() => _instance;
  LocalNotificationHelper._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    try {
      print('[NOTIFICATION] Initializing notification helper...');


      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );

      final initialized = await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          try {
            print('[NOTIFICATION] Notification tapped: ${response.payload}');
          } catch (e) {
            print('[NOTIFICATION ERROR] Error in notification response: $e');
          }
        },
      );

      print('[NOTIFICATION] Initialize result: $initialized');


      try {
        await _requestPermissions();
      } catch (e) {
        print('[NOTIFICATION ERROR] Permission request failed (non-critical): $e');
      }

      _initialized = true;
      print('[NOTIFICATION] Notification helper initialized successfully!');
    } catch (e, stackTrace) {
      print('[NOTIFICATION ERROR] Failed to initialize notifications: $e');
      print('[NOTIFICATION ERROR] Stack trace: $stackTrace');
      print('[NOTIFICATION] Continuing without notifications (emulator limitation)');

      _initialized = true;
    }
  }

  Future<void> _requestPermissions() async {
    try {
      print('[NOTIFICATION] Requesting permissions...');

      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        try {
          final granted = await androidPlugin.requestNotificationsPermission();
          print('[NOTIFICATION] Android permission granted: $granted');
        } catch (e) {
          print('[NOTIFICATION ERROR] Android permission request failed: $e');
        }
      }

      final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();

      if (iosPlugin != null) {
        try {
          final granted = await iosPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
          print('[NOTIFICATION] iOS permission granted: $granted');
        } catch (e) {
          print('[NOTIFICATION ERROR] iOS permission request failed: $e');
        }
      }
    } catch (e, stackTrace) {
      print('[NOTIFICATION ERROR] Permission request failed: $e');
      print('[NOTIFICATION ERROR] Stack trace: $stackTrace');

    }
  }


  Future<void> show({
    required String title,
    required String body,
    int? id,
    String? payload,
  }) async {
    try {
      if (!_initialized) {
        try {
          await init();
        } catch (e) {
          print('[NOTIFICATION ERROR] Init failed in show(): $e');

        }
      }

      print('[NOTIFICATION] Showing notification: $title - $body');

      final androidDetails = AndroidNotificationDetails(
        'smartlet_alerts',
        'Smartlet Alerts',
        channelDescription:
            'Notifications for sensor conditions and timer alerts',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(''),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final notifDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      try {
        await _plugin.show(
          id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title,
          body,
          notifDetails,
          payload: payload,
        );
        print('[NOTIFICATION] Notification shown successfully!');
      } catch (e) {
        print('[NOTIFICATION ERROR] Failed to show notification: $e');

      }
    } catch (e, stackTrace) {
      print('[NOTIFICATION ERROR] Exception in show(): $e');
      print('[NOTIFICATION ERROR] Stack trace: $stackTrace');

    }
  }


  Future<void> showWithSound({
    required String title,
    required String body,
    int? id,
    String? payload,
  }) async {
    if (!_initialized) {
      try {
        await init();
      } catch (e) {
        print('[NOTIFICATION ERROR] Failed to initialize, using fallback: $e');

        await show(title: title, body: body, id: id, payload: payload);
        return;
      }
    }

    print('[NOTIFICATION] Showing notification with sound: $title - $body');

    try {
      final androidDetails = AndroidNotificationDetails(
        'smartlet_urgent',
        'Urgent Alerts',
        channelDescription: 'Urgent notifications requiring immediate attention',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
        playSound: true,


        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(body),
        color: const Color(0xFF245C4C),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final notifDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _plugin.show(
        id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        notifDetails,
        payload: payload,
      );
      print('[NOTIFICATION] Notification with sound shown successfully!');
    } catch (e) {
      print('[NOTIFICATION ERROR] Failed to show notification with sound: $e');

      try {
        await show(title: title, body: body, id: id, payload: payload);
      } catch (e2) {
        print('[NOTIFICATION ERROR] Fallback also failed: $e2');
      }
    }
  }


  Future<void> showProgress({
    required String title,
    required int progress,
    required int maxProgress,
    int? id,
  }) async {
    try {
      if (!_initialized) {
        try {
          await init();
        } catch (e) {
          print('[NOTIFICATION ERROR] Init failed in showProgress(): $e');
          return; // Can't show progress without initialization
        }
      }

      final androidDetails = AndroidNotificationDetails(
        'smartlet_timer',
        'Timer Progress',
        channelDescription: 'Shows timer countdown progress',
        importance: Importance.low,
        priority: Priority.low,
        showProgress: true,
        maxProgress: maxProgress,
        progress: progress,
        ongoing: true,
        autoCancel: false,
        icon: '@mipmap/ic_launcher',
      );

      final notifDetails = NotificationDetails(android: androidDetails);

      await _plugin.show(
        id ?? 999,
        title,
        'Timer running...',
        notifDetails,
      );
      print('[NOTIFICATION] Progress notification shown: $progress/$maxProgress');
    } catch (e) {
      print('[NOTIFICATION ERROR] Failed to show progress notification: $e');

    }
  }


  Future<void> cancel(int id) async {
    try {
      await _plugin.cancel(id);
      print('[NOTIFICATION] Cancelled notification $id');
    } catch (e) {
      print('[NOTIFICATION ERROR] Failed to cancel notification $id: $e');
    }
  }


  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
      print('[NOTIFICATION] Cancelled all notifications');
    } catch (e) {
      print('[NOTIFICATION ERROR] Failed to cancel all notifications: $e');
    }
  }


  Future<void> schedule({
    required String title,
    required String body,
    required DateTime scheduledTime,
    int? id,
    String? payload,
  }) async {
    try {
      if (!_initialized) {
        try {
          await init();
        } catch (e) {
          print('[NOTIFICATION ERROR] Init failed in schedule(): $e');
          return;
        }
      }

      const androidDetails = AndroidNotificationDetails(
        'smartlet_scheduled',
        'Scheduled Alerts',
        channelDescription: 'Scheduled notifications',
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );


      const notifDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      try {
        await _plugin.show(
          id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title,
          body,
          notifDetails,
          payload: payload,
        );
        print('[NOTIFICATION] Scheduled notification shown');
      } catch (e) {
        print('[NOTIFICATION ERROR] Failed to show scheduled notification: $e');
      }
    } catch (e, stackTrace) {
      print('[NOTIFICATION ERROR] Exception in schedule(): $e');
      print('[NOTIFICATION ERROR] Stack trace: $stackTrace');
    }
  }
}
