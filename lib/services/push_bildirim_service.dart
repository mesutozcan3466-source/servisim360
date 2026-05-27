import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// FCM Push Bildirim Servisi
class PushBildirimService {
  static final _fcm    = FirebaseMessaging.instance;
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> baslat() async {
    await _yerelBildirimKur();

    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // Token al ve kaydet
    final token = await _fcm.getToken();
    if (token != null) await _tokenKaydet(token);

    // Token yenilenince guncelle
    _fcm.onTokenRefresh.listen(_tokenKaydet);

    // On planda bildirim → yerel bildirim goster
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification != null) {
        _yerelBildirimGoster(
          baslik: notification.title ?? 'Servisim360',
          icerik: notification.body  ?? '',
        );
      }
    });

    // Arka plandan acilinca
    FirebaseMessaging.onMessageOpenedApp.listen((_) {
      // Ileride rota yonlendirmesi eklenebilir
    });
  }

  // ── Yerel Bildirim Kur ───────────────────────────────────────────────────────
  static Future<void> _yerelBildirimKur() async {
    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings =
    InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _plugin.initialize(initSettings);

    const channel = AndroidNotificationChannel(
      'servisim360_kanal',
      'Servisim360 Bildirimleri',
      description: 'Servis ve ogrenci bildirimleri',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // ── Yerel Bildirim Goster ────────────────────────────────────────────────────
  static Future<void> _yerelBildirimGoster({
    required String baslik,
    required String icerik,
    int id = 0,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'servisim360_kanal',
      'Servisim360 Bildirimleri',
      channelDescription: 'Servis ve ogrenci bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    const details =
    NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _plugin.show(id, baslik, icerik, details);
  }

  // ── Disaridan Bildirim Goster ────────────────────────────────────────────────
  static Future<void> bildirimGoster({
    required String baslik,
    required String icerik,
    int id = 0,
  }) =>
      _yerelBildirimGoster(baslik: baslik, icerik: icerik, id: id);

  // ── FCM Token Kaydet ─────────────────────────────────────────────────────────
  static Future<void> _tokenKaydet(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('kullanicilar')
          .doc(uid)
          .update({
        'fcmToken':        token,
        'tokenGuncelleme': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // ── Kullaniciya Bildirim Kaydi Olustur ───────────────────────────────────────
  // NOT: 'bildirimler' yerine 'notifications' koleksiyonu kullanilir
  // Cloud Functions ile tutarli olmasi icin
  static Future<void> kullaniciyaBildir({
    required String firmaId,
    required String baslik,
    required String icerik,
    String? hedefUid,
  }) async {
    await FirebaseFirestore.instance.collection('notifications').add({
      'firmaId':  firmaId,
      'baslik':   baslik,
      'mesaj':    icerik,
      'aliciId':  hedefUid ?? '',
      'okundu':   false,
      'tip':      'sistem',
      'tarih':    FieldValue.serverTimestamp(),
    });
  }

  // ── Konuya Abone Ol ──────────────────────────────────────────────────────────
  static Future<void> konuyaAbone(String konu) async =>
      _fcm.subscribeToTopic(konu);
  static Future<void> konudanCik(String konu) async =>
      _fcm.unsubscribeFromTopic(konu);

  // ── Tum Bildirimleri Temizle ─────────────────────────────────────────────────
  static Future<void> tumBildirimleriTemizle() async => _plugin.cancelAll();
}
