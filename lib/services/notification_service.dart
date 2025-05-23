import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class Notifier {
  Notifier._();
  static final instance = Notifier._();

  final _plugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));
  }

  Future<void> show(String title, String body) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'sms_channel', // channel id
        'SMS results', // channel name
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(0, title, body, details);
  }
}
