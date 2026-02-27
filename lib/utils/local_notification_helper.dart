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

        print('[NOTIFICATION] Notification tapped: ${response.payload}');
      },
    );

    print('[NOTIFICATION] Initialize result: $initialized');


    await _requestPermissions();

    _initialized = true;
    print('[NOTIFICATION] Notification helper initialized successfully!');
  }

  Future<void> _requestPermissions() async {
    print('[NOTIFICATION] Requesting permissions...');

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      print('[NOTIFICATION] Android permission granted: $granted');
    }

    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      print('[NOTIFICATION] iOS permission granted: $granted');
    }
  }


  Future<void> show({
    required String title,
    required String body,
    int? id,
    String? payload,
  }) async {
    if (!_initialized) await init();

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
  }


  Future<void> showWithSound({
    required String title,
    required String body,
    int? id,
    String? payload,
  }) async {
    if (!_initialized) await init();

    print('[NOTIFICATION] Showing notification with sound: $title - $body');

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
      sound: const RawResourceAndroidNotificationSound('notification'),
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(body), // Non-const is correct
      color: const Color(0xFF245C4C),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'notification.aiff',
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
      print('[NOTIFICATION] Notification with sound shown successfully!');
    } catch (e) {
      print('[NOTIFICATION ERROR] Failed to show notification with sound: $e');
    }
  }


  Future<void> showProgress({
    required String title,
    required int progress,
    required int maxProgress,
    int? id,
  }) async {
    if (!_initialized) await init();

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
  }


  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }


  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }


  Future<void> schedule({
    required String title,
    required String body,
    required DateTime scheduledTime,
    int? id,
    String? payload,
  }) async {
    if (!_initialized) await init();

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



    await _plugin.show(
      id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notifDetails,
      payload: payload,
    );
  }
}
