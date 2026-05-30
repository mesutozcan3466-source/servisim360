import 'package:flutter_local_notifications/flutter_local_notifications.dart';
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _kuruldu = false;
  static const _kId = 'servisim_kanal';
  static const _kAd = 'Servisim360';
  static const _kAc = 'Servis takip bildirimleri';
  static const _kanal = AndroidNotificationChannel(_kId,_kAd,description:_kAc,importance:Importance.high);
  static Future<void> baslat() async {
    if (_kuruldu) return; _kuruldu = true;
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(_kanal);
  }
  static Future<void> goster({required int id,required String baslik,required String govde,String? payload}) async {
    await _plugin.show(
      id, baslik, govde,
      const NotificationDetails(
        android: AndroidNotificationDetails(_kId,_kAd,channelDescription:_kAc,importance:Importance.high,priority:Priority.high,icon:'@mipmap/ic_launcher'),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }
  static Future<void> iptal(int id) => _plugin.cancel(id);
  static Future<void> hepsiniIptal() => _plugin.cancelAll();
}
