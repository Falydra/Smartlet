import 'dart:async';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:swiftlead/services/node_service.dart';
import 'package:swiftlead/utils/token_manager.dart';
import 'package:swiftlead/utils/local_notification_helper.dart';

class TimerBackgroundService {
  static Future<void> initialize() async {
    print('[BACKGROUND SERVICE] Initializing background service...');
    try {
      final service = FlutterBackgroundService();

      print('[BACKGROUND SERVICE] Configuring service...');
      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: false,
          isForegroundMode: true,
          notificationChannelId: 'smartlet_timer_service',
          initialNotificationTitle: 'Smartlet Timer',
          initialNotificationContent: 'Timer berjalan di background',
          foregroundServiceNotificationId: 888,
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: onStart,
          onBackground: onIosBackground,
        ),
      );
      print('[BACKGROUND SERVICE] Service configured successfully');
    } catch (e, stackTrace) {
      print('[BACKGROUND SERVICE] Error initializing service: $e');
      print('[BACKGROUND SERVICE] Stack trace: $stackTrace');
      rethrow;
    }
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    print('[BACKGROUND SERVICE] onStart() called - Service starting...');
    DartPluginRegistrant.ensureInitialized();
    print('[BACKGROUND SERVICE] DartPluginRegistrant initialized');

    if (service is AndroidServiceInstance) {
      service.on('stopService').listen((event) {
        service.stopSelf();
      });

      service.setAsForegroundService();
    }

    print('[BACKGROUND SERVICE] Setting up Timer.periodic (5 second interval)');
    // Check timers every 5 seconds
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          await _checkAndExecuteTimers(service);
        }
      } else {
        await _checkAndExecuteTimers(service);
      }
    });
  }

  static Future<void> _checkAndExecuteTimers(ServiceInstance service) async {
    try {
      print('[BACKGROUND SERVICE] Checking timers at ${DateTime.now()}');
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      bool hasActiveTimers = false;
      List<String> expiredTimers = [];

      // Check pump timer
      final pumpTimerEnd = prefs.getString('pump_timer_end');
      if (pumpTimerEnd != null) {
        print('[BACKGROUND SERVICE] Pump timer found: $pumpTimerEnd');
        final endTime = DateTime.parse(pumpTimerEnd);
        final remaining = endTime.difference(now);
        print(
            '[BACKGROUND SERVICE] Pump timer remaining: ${remaining.inSeconds}s');
        if (now.isAfter(endTime)) {
          print('[BACKGROUND SERVICE] Pump timer EXPIRED!');
          expiredTimers.add('pump');
          await _turnOffDevice('pump', prefs);
          await prefs.remove('pump_timer_end');
        } else {
          hasActiveTimers = true;
        }
      }

      // Check audio both timer
      final audioBothTimerEnd = prefs.getString('audio_both_timer_end');
      if (audioBothTimerEnd != null) {
        final endTime = DateTime.parse(audioBothTimerEnd);
        if (now.isAfter(endTime)) {
          expiredTimers.add('audio_both');
          await _turnOffDevice('audio_both', prefs);
          await prefs.remove('audio_both_timer_end');
        } else {
          hasActiveTimers = true;
        }
      }

      // Check audio LMB timer
      final audioLmbTimerEnd = prefs.getString('audio_lmb_timer_end');
      if (audioLmbTimerEnd != null) {
        final endTime = DateTime.parse(audioLmbTimerEnd);
        if (now.isAfter(endTime)) {
          expiredTimers.add('audio_lmb');
          await _turnOffDevice('audio_lmb', prefs);
          await prefs.remove('audio_lmb_timer_end');
        } else {
          hasActiveTimers = true;
        }
      }

      // Check audio Nest timer
      final audioNestTimerEnd = prefs.getString('audio_nest_timer_end');
      if (audioNestTimerEnd != null) {
        final endTime = DateTime.parse(audioNestTimerEnd);
        if (now.isAfter(endTime)) {
          expiredTimers.add('audio_nest');
          await _turnOffDevice('audio_nest', prefs);
          await prefs.remove('audio_nest_timer_end');
        } else {
          hasActiveTimers = true;
        }
      }

      // Show notifications for expired timers
      if (expiredTimers.isNotEmpty) {
        print(
            '[BACKGROUND SERVICE] ${expiredTimers.length} timers expired: $expiredTimers');
      }

      for (final device in expiredTimers) {
        try {
          print('[BACKGROUND SERVICE] Sending notification for $device');
          // Initialize notification helper in background context
          await LocalNotificationHelper().init();
          await LocalNotificationHelper().showWithSound(
            title: '⏰ Timer Selesai',
            body: '${_getDeviceName(device)} telah dimatikan secara otomatis.',
            payload: 'timer_expired_$device',
          );
          print(
              '[BACKGROUND SERVICE] Notification sent successfully for $device');
        } catch (e) {
          print(
              '[BACKGROUND SERVICE] Error sending notification for $device: $e');
        }
      }

      // Update notification with remaining timers
      if (hasActiveTimers) {
        final remainingCount = [
              pumpTimerEnd,
              audioBothTimerEnd,
              audioLmbTimerEnd,
              audioNestTimerEnd,
            ].where((t) => t != null).length -
            expiredTimers.length;

        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: 'Smartlet Timer Aktif',
            content: '$remainingCount timer masih berjalan',
          );
        }
      } else {
        // No more active timers, stop the service
        service.stopSelf();
      }
    } catch (e) {
      print('[BACKGROUND SERVICE] Error checking timers: $e');
    }
  }

  static Future<void> _turnOffDevice(
      String deviceType, SharedPreferences prefs) async {
    try {
      final token = await TokenManager.getToken();
      if (token == null) return;

      final nodeService = NodeService();

      switch (deviceType) {
        case 'pump':
          final pumpNodeId = prefs.getString('pump_node_id');
          if (pumpNodeId != null) {
            await nodeService.patchPump(token, pumpNodeId, false);
            print('[BACKGROUND SERVICE] Pump turned off');
          }
          break;
        case 'audio_both':
          final audioNodeId = prefs.getString('audio_node_id');
          if (audioNodeId != null) {
            await nodeService.controlAudio(token, audioNodeId, 'call_bird', 0);
            print('[BACKGROUND SERVICE] Both speakers turned off');
          }
          break;
        case 'audio_lmb':
          final audioNodeId = prefs.getString('audio_node_id');
          if (audioNodeId != null) {
            await nodeService.controlAudio(
                token, audioNodeId, 'audio_set_lmb', 0);
            print('[BACKGROUND SERVICE] LMB speaker turned off');
          }
          break;
        case 'audio_nest':
          final audioNodeId = prefs.getString('audio_node_id');
          if (audioNodeId != null) {
            await nodeService.controlAudio(
                token, audioNodeId, 'audio_set_nest', 0);
            print('[BACKGROUND SERVICE] Nest speaker turned off');
          }
          break;
      }
    } catch (e) {
      print('[BACKGROUND SERVICE] Error turning off device $deviceType: $e');
    }
  }

  static String _getDeviceName(String deviceType) {
    switch (deviceType) {
      case 'pump':
        return 'Mist Spray';
      case 'audio_both':
        return 'Semua Speaker';
      case 'audio_lmb':
        return 'Speaker LMB';
      case 'audio_nest':
        return 'Speaker Nest';
      default:
        return deviceType;
    }
  }

  /// Start the background service
  static Future<void> startService() async {
    try {
      print('[BACKGROUND SERVICE] startService() called');
      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning();
      print('[BACKGROUND SERVICE] Service running status: $isRunning');
      if (!isRunning) {
        print('[BACKGROUND SERVICE] Attempting to start service...');
        await service.startService();
        print('[BACKGROUND SERVICE] Service started successfully');
        // Verify it started
        await Future.delayed(const Duration(milliseconds: 500));
        final nowRunning = await service.isRunning();
        print('[BACKGROUND SERVICE] Service running after start: $nowRunning');
      } else {
        print('[BACKGROUND SERVICE] Service already running');
      }
    } catch (e, stackTrace) {
      print('[BACKGROUND SERVICE] Error starting service: $e');
      print('[BACKGROUND SERVICE] Stack trace: $stackTrace');
    }
  }

  /// Stop the background service
  static Future<void> stopService() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
    print('[BACKGROUND SERVICE] Service stopped');
  }

  /// Save timer to SharedPreferences and start background service
  static Future<void> setTimer({
    required String deviceType,
    required DateTime endTime,
    required String? nodeId,
  }) async {
    print('[BACKGROUND SERVICE] Setting timer for $deviceType until $endTime');
    final prefs = await SharedPreferences.getInstance();

    // Save timer end time
    await prefs.setString('${deviceType}_timer_end', endTime.toIso8601String());
    print(
        '[BACKGROUND SERVICE] Timer saved to SharedPreferences: ${deviceType}_timer_end = ${endTime.toIso8601String()}');

    // Save node IDs for background service to use
    if (deviceType == 'pump') {
      await prefs.setString('pump_node_id', nodeId ?? '');
      print('[BACKGROUND SERVICE] Saved pump_node_id: $nodeId');
    } else if (deviceType.startsWith('audio')) {
      await prefs.setString('audio_node_id', nodeId ?? '');
      print('[BACKGROUND SERVICE] Saved audio_node_id: $nodeId');
    }

    // Start background service
    await startService();
    print(
        '[BACKGROUND SERVICE] Timer set successfully for $deviceType until $endTime');
  }

  /// Clear timer from SharedPreferences
  static Future<void> clearTimer(String deviceType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${deviceType}_timer_end');
    print('[BACKGROUND SERVICE] Timer cleared for $deviceType');

    // Check if any timers are still active
    final hasActiveTimers = prefs.getString('pump_timer_end') != null ||
        prefs.getString('audio_both_timer_end') != null ||
        prefs.getString('audio_lmb_timer_end') != null ||
        prefs.getString('audio_nest_timer_end') != null;

    if (!hasActiveTimers) {
      await stopService();
    }
  }

  /// Get remaining time for a timer
  static Future<Duration?> getRemainingTime(String deviceType) async {
    final prefs = await SharedPreferences.getInstance();
    final timerEndStr = prefs.getString('${deviceType}_timer_end');
    if (timerEndStr == null) return null;

    final endTime = DateTime.parse(timerEndStr);
    final now = DateTime.now();

    if (now.isAfter(endTime)) {
      await clearTimer(deviceType);
      return null;
    }

    return endTime.difference(now);
  }
}
