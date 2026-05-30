import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
class PushBildirimService {
  static final _fcm = FirebaseMessaging.instance;
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _kId = 'servisim_kanal'; static const _kAd = 'Servisim360'; static const _kAc = 'Servis bildirimleri';
  static const _kanal = AndroidNotificationChannel(_kId,_kAd,description:_kAc,importance:Importance.high);
  static Future<void> baslat() async {
    if (kIsWeb) return;
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(_kanal);
    await _fcm.requestPermission(alert:true,badge:true,sound:true);
    await _tokenKaydet();
    _fcm.onTokenRefresh.listen((_) => _tokenKaydet());
    FirebaseMessaging.onMessage.listen(_foregroundMesaj);
  }
  static Future<void> _tokenKaydet() async {
    try {
      final token = await _fcm.getToken(); if (token==null) return;
      final uid = FirebaseAuth.instance.currentUser?.uid; if (uid==null) return;
      await FirebaseFirestore.instance.collection('kullanicilar').doc(uid).update({'fcmToken':token,'fcmGuncelleme':FieldValue.serverTimestamp()});
    } catch(_) {}
  }
  static Future<void> tokenaPushGonder({required String token,required String baslik,required String govde,Map<String,String>? data}) async {}
  static void _foregroundMesaj(RemoteMessage message) {
    final notif = message.notification; if (notif==null) return;
    _plugin.show(
      notif.hashCode, notif.title, notif.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(_kId,_kAd,channelDescription:_kAc,importance:Importance.high,priority:Priority.high,icon:'@mipmap/ic_launcher'),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
