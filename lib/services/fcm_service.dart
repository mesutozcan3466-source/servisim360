import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}
class FcmServisi {
  FcmServisi._(); static final FcmServisi instance = FcmServisi._();
  final _fcm = FirebaseMessaging.instance;
  final _plugin = FlutterLocalNotificationsPlugin();
  static const _kId = 'servisim_kanal'; static const _kAd = 'Servisim360'; static const _kAc = 'Servis bildirimleri';
  static const _kanal = AndroidNotificationChannel(_kId,_kAd,description:_kAc,importance:Importance.high);
  Future<void> baslat() async {
    if (kIsWeb) return;
    await _fcm.requestPermission(alert:true,badge:true,sound:true);
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(_kanal);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_foregroundMesaj);
    await _tokenKaydet();
    _fcm.onTokenRefresh.listen((_) => _tokenKaydet());
  }
  Future<void> _tokenKaydet() async {
    try { final t=await _fcm.getToken(); if(t==null) return; await FirebaseFunctions.instance.httpsCallable('fcmTokenKaydet').call({'token':t}); } catch(e) { debugPrint('$e'); }
  }
  void _foregroundMesaj(RemoteMessage m) {
    final n=m.notification; if(n==null) return;
    _plugin.show(
      n.hashCode, n.title, n.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(_kId,_kAd,channelDescription:_kAc,importance:Importance.high,priority:Priority.high,icon:'@mipmap/ic_launcher'),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
  Future<void> konuyaAbone(String k) => _fcm.subscribeToTopic(k);
  Future<void> konudanCik(String k) => _fcm.unsubscribeFromTopic(k);
}
