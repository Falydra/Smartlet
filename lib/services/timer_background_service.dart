import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:swiftlead/services/node_service.dart';
import 'package:swiftlead/utils/token_manager.dart';
import 'package:swiftlead/utils/local_notification_helper.dart';

class TimerBackgroundService {


  static const bool FORCE_DISABLE_BACKGROUND_SERVICE = true;
  
  static bool _isEmulator = false;
  static bool _emulatorCheckDone = false;


  static Future<bool> isRunningOnEmulator() async {
    if (FORCE_DISABLE_BACKGROUND_SERVICE) return true;
    return await _checkIfEmulator();
  }


  static Future<bool> _checkIfEmulator() async {
    if (_emulatorCheckDone) return _isEmulator;

    try {
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        

        _isEmulator = !androidInfo.isPhysicalDevice ||
            androidInfo.model.toLowerCase().contains('sdk') ||
            androidInfo.model.toLowerCase().contains('emulator') ||
            androidInfo.model.toLowerCase().contains('bluestacks') ||
            androidInfo.product.toLowerCase().contains('sdk') ||
            androidInfo.product.toLowerCase().contains('emulator') ||
            androidInfo.manufacturer.toLowerCase().contains('genymotion') ||
            androidInfo.brand.toLowerCase() == 'generic' ||
            androidInfo.device.toLowerCase().contains('generic');
        
        print('[BACKGROUND SERVICE] Emulator detection:');
        print('  - Physical device: ${androidInfo.isPhysicalDevice}');
        print('  - Model: ${androidInfo.model}');
        print('  - Product: ${androidInfo.product}');
        print('  - Manufacturer: ${androidInfo.manufacturer}');
        print('  - Brand: ${androidInfo.brand}');
        print('  - Device: ${androidInfo.device}');
        print('  - Is Emulator: $_isEmulator');
      } else {
        _isEmulator = false; // iOS simulators handle background differently
      }
    } catch (e, stackTrace) {
      print('[BACKGROUND SERVICE] Error detecting emulator: $e');
      print('[BACKGROUND SERVICE] Stack trace: $stackTrace');

      _isEmulator = true;
      print('[BACKGROUND SERVICE] Assuming emulator due to detection error (safer default)');
    }

    _emulatorCheckDone = true;
    return _isEmulator;
  }

  static Future<void> initialize() async {
    print('[BACKGROUND SERVICE] Initializing background service...');
    
    if (FORCE_DISABLE_BACKGROUND_SERVICE) {
      print('[BACKGROUND SERVICE] FORCE DISABLED via kill switch - background service completely disabled');
      return;
    }
    

    final isEmulator = await _checkIfEmulator();
    if (isEmulator) {
      print('[BACKGROUND SERVICE] Running on emulator - skipping background service initialization');
      print('[BACKGROUND SERVICE] Timer will work but notifications may be limited');
      return; // Skip initialization on emulators
    }
    
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
      print('[BACKGROUND SERVICE] Service may not work on this device/emulator');


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


      if (expiredTimers.isNotEmpty) {
        print(
            '[BACKGROUND SERVICE] ${expiredTimers.length} timers expired: $expiredTimers');
      }

      for (final device in expiredTimers) {
        try {
          print('[BACKGROUND SERVICE] Sending notification for $device');

          try {
            await LocalNotificationHelper().init();
          } catch (initError) {
            print(
                '[BACKGROUND SERVICE] Notification init failed (non-critical): $initError');
          }
          

          try {
            await LocalNotificationHelper().showWithSound(
              title: '⏰ Timer Selesai',
              body:
                  '${_getDeviceName(device)} telah dimatikan secara otomatis.',
              payload: 'timer_expired_$device',
            );
          } catch (soundNotifError) {
            print(
                '[BACKGROUND SERVICE] showWithSound failed, using simple notification: $soundNotifError');
            await LocalNotificationHelper().show(
              title: '⏰ Timer Selesai',
              body:
                  '${_getDeviceName(device)} telah dimatikan secara otomatis.',
              payload: 'timer_expired_$device',
            );
          }
          print(
              '[BACKGROUND SERVICE] Notification sent successfully for $device');
        } catch (e) {
          print(
              '[BACKGROUND SERVICE] Error sending notification for $device: $e');

        }
      }


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


  static Future<void> startService() async {
    if (FORCE_DISABLE_BACKGROUND_SERVICE) {
      print('[BACKGROUND SERVICE] FORCE DISABLED - skipping service start');
      return;
    }
    

    final isEmulator = await _checkIfEmulator();
    if (isEmulator) {
      print('[BACKGROUND SERVICE] Skipping service start on emulator');
      print('[BACKGROUND SERVICE] Timer data saved but background notifications disabled');
      return; // Don't attempt to start service on emulators
    }
    
    try {
      print('[BACKGROUND SERVICE] startService() called');
      final service = FlutterBackgroundService();
      

      bool isRunning = false;
      try {
        isRunning = await service.isRunning();
      } catch (e) {
        print('[BACKGROUND SERVICE] Error checking service status: $e');

      }
      
      print('[BACKGROUND SERVICE] Service running status: $isRunning');
      
      if (!isRunning) {
        print('[BACKGROUND SERVICE] Attempting to start service...');
        try {
          await service.startService();
          print('[BACKGROUND SERVICE] Service started successfully');

          await Future.delayed(const Duration(milliseconds: 500));
          
          try {
            final nowRunning = await service.isRunning();
            print('[BACKGROUND SERVICE] Service running after start: $nowRunning');
          } catch (e) {
            print('[BACKGROUND SERVICE] Cannot verify service status (non-critical): $e');
          }
        } catch (startError) {
          print('[BACKGROUND SERVICE] Failed to start service (may work in background): $startError');


        }
      } else {
        print('[BACKGROUND SERVICE] Service already running');
      }
    } catch (e, stackTrace) {
      print('[BACKGROUND SERVICE] Error in startService: $e');
      print('[BACKGROUND SERVICE] Stack trace: $stackTrace');

      print('[BACKGROUND SERVICE] Timer will be saved to SharedPreferences anyway');
    }
  }


  static Future<void> stopService() async {
    if (FORCE_DISABLE_BACKGROUND_SERVICE) {
      print('[BACKGROUND SERVICE] FORCE DISABLED - skipping service stop');
      return;
    }
    

    final isEmulator = await _checkIfEmulator();
    if (isEmulator) {
      print('[BACKGROUND SERVICE] Skipping service stop on emulator (service not running)');
      return;
    }
    
    final service = FlutterBackgroundService();
    service.invoke('stopService');
    print('[BACKGROUND SERVICE] Service stopped');
  }


  static Future<void> setTimer({
    required String deviceType,
    required DateTime endTime,
    required String? nodeId,
  }) async {
    print('[BACKGROUND SERVICE] Setting timer for $deviceType until $endTime');
    final prefs = await SharedPreferences.getInstance();


    await prefs.setString('${deviceType}_timer_end', endTime.toIso8601String());
    print(
        '[BACKGROUND SERVICE] Timer saved to SharedPreferences: ${deviceType}_timer_end = ${endTime.toIso8601String()}');


    if (deviceType == 'pump') {
      await prefs.setString('pump_node_id', nodeId ?? '');
      print('[BACKGROUND SERVICE] Saved pump_node_id: $nodeId');
    } else if (deviceType.startsWith('audio')) {
      await prefs.setString('audio_node_id', nodeId ?? '');
      print('[BACKGROUND SERVICE] Saved audio_node_id: $nodeId');
    }

    // Always ensure foreground watcher is running when a timer is set
    startForegroundTimerWatcher();

    await startService();
    print(
        '[BACKGROUND SERVICE] Timer set successfully for $deviceType until $endTime');
  }


  static Future<void> clearTimer(String deviceType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${deviceType}_timer_end');
    print('[BACKGROUND SERVICE] Timer cleared for $deviceType');


    final hasActiveTimers = prefs.getString('pump_timer_end') != null ||
        prefs.getString('audio_both_timer_end') != null ||
        prefs.getString('audio_lmb_timer_end') != null ||
        prefs.getString('audio_nest_timer_end') != null;

    if (!hasActiveTimers) {
      await stopService();
    }
  }


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

  /// Foreground timer checker - runs from main.dart to handle expired timers
  /// even when the user is on a different page from the control page.
  static bool _foregroundCheckRunning = false;
  static Timer? _foregroundTimer;

  static void startForegroundTimerWatcher() {
    _foregroundTimer?.cancel();
    _foregroundTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      await checkExpiredTimersInForeground();
    });
    print('[FOREGROUND WATCHER] Started global timer watcher');
  }

  static void stopForegroundTimerWatcher() {
    _foregroundTimer?.cancel();
    _foregroundTimer = null;
    print('[FOREGROUND WATCHER] Stopped global timer watcher');
  }

  static Future<void> checkExpiredTimersInForeground() async {
    if (_foregroundCheckRunning) return; // Prevent concurrent checks
    _foregroundCheckRunning = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      List<String> expiredTimers = [];
      bool hasActiveTimers = false;

      final timerTypes = ['pump', 'audio_both', 'audio_lmb', 'audio_nest'];
      for (final type in timerTypes) {
        final timerEndStr = prefs.getString('${type}_timer_end');
        if (timerEndStr != null) {
          final endTime = DateTime.parse(timerEndStr);
          if (now.isAfter(endTime)) {
            print('[FOREGROUND WATCHER] $type timer EXPIRED! Turning off device...');
            expiredTimers.add(type);
            await _turnOffDevice(type, prefs);
            await prefs.remove('${type}_timer_end');
          } else {
            hasActiveTimers = true;
          }
        }
      }

      // Send notifications for expired timers
      for (final device in expiredTimers) {
        try {
          await LocalNotificationHelper().show(
            title: '⏰ Timer Selesai',
            body: '${_getDeviceName(device)} telah dimatikan secara otomatis.',
            payload: 'timer_expired_$device',
          );
          print('[FOREGROUND WATCHER] Notification sent for $device');
        } catch (e) {
          print('[FOREGROUND WATCHER] Notification error for $device: $e');
        }
      }

      // Stop the watcher if no more active timers
      if (!hasActiveTimers && expiredTimers.isEmpty) {
        // No timers at all, no need to keep checking
      }
    } catch (e) {
      print('[FOREGROUND WATCHER] Error: $e');
    } finally {
      _foregroundCheckRunning = false;
    }
  }
}
