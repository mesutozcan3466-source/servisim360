import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Yerel bildirim servisi
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _kuruldu = false;

  static Future<void> baslat() async {
    if (_kuruldu) return;
    _kuruldu = true;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings     = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
        android: androidSettings, iOS: iosSettings);

    await _plugin.initialize(initSettings,
        onDidReceiveNotificationResponse: (_) {});

    const channel = AndroidNotificationChannel(
      'servisim360_kanal',
      'Servisim360 Bildirimleri',
      description: 'Servis ve öğrenci bildirimleri',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> bildirimGoster({
    required String baslik,
    required String icerik,
    int id = 0,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'servisim360_kanal',
      'Servisim360 Bildirimleri',
      channelDescription: 'Servis ve öğrenci bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    const details    = NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _plugin.show(id, baslik, icerik, details);
  }

  static Future<void> tumBildirimleriTemizle() async => _plugin.cancelAll();
}
