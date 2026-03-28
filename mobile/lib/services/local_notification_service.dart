import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const String medicalNotificationChannelId = 'medical_notifications_v2';
const String medicalNotificationChannelName = 'Medical Notifications';
const String medicalNotificationChannelDescription =
  'Alertes de notifications médicales';
final Int64List medicalVibrationPattern =
  Int64List.fromList(<int>[0, 300, 200, 500]);

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    final channel = AndroidNotificationChannel(
      medicalNotificationChannelId,
      medicalNotificationChannelName,
      description: medicalNotificationChannelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      vibrationPattern: medicalVibrationPattern,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  static Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      medicalNotificationChannelId,
      medicalNotificationChannelName,
      channelDescription: medicalNotificationChannelDescription,
      importance: Importance.high,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: medicalVibrationPattern,
    );

    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
  }
}
