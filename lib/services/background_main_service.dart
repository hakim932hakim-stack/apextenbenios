import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';

Future<void> initializeBackgroundService() async {
  if (kIsWeb) return; // 🔥 Web'de bu servisi devre dışı bırak
  final service = FlutterBackgroundService();

  // Android Notification Channel
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'apex_background_service_channel', 
    'APEX Servis', 
    description: 'Uygulamanın arka planda çalışmasını sağlar.',
    importance: Importance.low, 
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  if (defaultTargetPlatform == TargetPlatform.android) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
  }

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false, // 🔥 Sadece odada başlayacak
      isForegroundMode: true,
      notificationChannelId: 'apex_background_service_channel',
      initialNotificationTitle: 'Apex Party',
      initialNotificationContent: 'Bağlantı aktif',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Dart tarafını initialize et
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });
  
  // Keep alive timer (Opsiyonel, garanti olsun)
  Timer.periodic(const Duration(seconds: 45), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: "APEX Hubs",
          content: "Bağlantı aktif",
        );
      }
    }
    
    print('FLUTTER BACKGROUND SERVICE ALIVE: ${DateTime.now()}');
  });
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}
