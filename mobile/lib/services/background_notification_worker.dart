import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'local_notification_service.dart';

const String notificationCheckTask = 'medical_notification_check_task';
const String _bgTokenKey = 'jwt_token_bg';
const String _bgBaseUrlKey = 'api_base_url_bg';
const String _seenIdsKey = 'bg_seen_notification_ids';

bool _isUnread(dynamic value) {
  if (value is int) return value == 0;
  if (value is bool) return value == false;
  final s = value?.toString().trim().toLowerCase();
  return s == '0' || s == 'false' || s == 'null' || s == null;
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != notificationCheckTask) return true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_bgTokenKey);
      final baseUrl = prefs.getString(_bgBaseUrlKey) ?? 'http://127.0.0.1:5001/api';

      if (token == null || token.isEmpty) return true;

      final url = Uri.parse('$baseUrl/notifications');
      final res = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (res.statusCode < 200 || res.statusCode >= 300) return true;

      final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final notifications = List<Map<String, dynamic>>.from(body['notifications'] ?? []);

      final seen = prefs.getStringList(_seenIdsKey)?.toSet() ?? <String>{};

      final plugin = FlutterLocalNotificationsPlugin();
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      await plugin.initialize(const InitializationSettings(android: androidInit));

      final channel = AndroidNotificationChannel(
        medicalNotificationChannelId,
        medicalNotificationChannelName,
        description: medicalNotificationChannelDescription,
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
        vibrationPattern: medicalVibrationPattern,
      );

      await plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      for (final n in notifications) {
        final id = int.tryParse(n['id']?.toString() ?? '');
        final isUnread = _isUnread(n['is_read']);
        if (id == null || !isUnread) continue;

        final key = id.toString();
        if (seen.contains(key)) continue;

        seen.add(key);

        await plugin.show(
          id,
          (n['title']?.toString().isNotEmpty ?? false)
              ? n['title'].toString()
              : 'Nouvelle notification',
          (n['body']?.toString().isNotEmpty ?? false)
              ? n['body'].toString()
              : 'Vous avez une nouvelle alerte.',
          NotificationDetails(
            android: AndroidNotificationDetails(
              medicalNotificationChannelId,
              medicalNotificationChannelName,
              channelDescription: medicalNotificationChannelDescription,
              importance: Importance.high,
              priority: Priority.max,
              playSound: true,
              enableVibration: true,
              vibrationPattern: medicalVibrationPattern,
            ),
          ),
        );
      }

      await prefs.setStringList(_seenIdsKey, seen.toList());
      return true;
    } catch (_) {
      return true;
    }
  });
}
