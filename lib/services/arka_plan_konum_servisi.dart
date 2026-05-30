import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
class ArkaPlanKonumServisi {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static StreamSubscription<Position>? _abonelik;
  static bool _kuruldu = false;
  static const _kId = 'konum_kanal'; static const _kAd = 'Konum'; static const _kAc = 'Konum bildirimleri';
  static const _kanal = AndroidNotificationChannel(_kId,_kAd,description:_kAc,importance:Importance.low);
  static Future<void> baslat() async {
    if (_kuruldu) return; _kuruldu = true;
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(_kanal);
    await _konumDinle();
  }
  static Future<void> baslatServisi({String? surucuDocId,String? firmaId}) async => baslat();
  static Future<void> _konumDinle() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    LocationPermission izin=await Geolocator.checkPermission();
    if(izin==LocationPermission.denied){izin=await Geolocator.requestPermission();if(izin==LocationPermission.denied) return;}
    if(izin==LocationPermission.deniedForever) return;
    _abonelik=Geolocator.getPositionStream(locationSettings:const LocationSettings(accuracy:LocationAccuracy.high,distanceFilter:30)).listen(_konumGuncelle);
  }
  static Future<void> _konumGuncelle(Position pos) async {
    final uid=FirebaseAuth.instance.currentUser?.uid; if(uid==null) return;
    try { await FirebaseFirestore.instance.collection('surucu_konumlar').doc(uid).set({'konum':GeoPoint(pos.latitude,pos.longitude),'hiz':pos.speed,'guncellemeZamani':FieldValue.serverTimestamp(),'servisAktif':true},SetOptions(merge:true)); } catch(_) {}
  }
  static void durdur() {
    _abonelik?.cancel(); _abonelik=null; _kuruldu=false;
    _plugin.show(
      0, 'Servis Durduruldu', 'Konum paylasimi kapatildi.',
      const NotificationDetails(
        android: AndroidNotificationDetails(_kId,_kAd,channelDescription:_kAc,importance:Importance.low,priority:Priority.low,icon:'@mipmap/ic_launcher'),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
  static Future<void> bildirimGoster({required int id,required String baslik,required String govde}) async {
    await _plugin.show(
      id, baslik, govde,
      const NotificationDetails(
        android: AndroidNotificationDetails(_kId,_kAd,channelDescription:_kAc,importance:Importance.high,priority:Priority.high,icon:'@mipmap/ic_launcher'),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
typedef ArkaplanKonumServisi = ArkaPlanKonumServisi;
