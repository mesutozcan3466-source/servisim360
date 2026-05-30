import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
class OtomatikRotaService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _kuruldu = false;
  static const _kId = 'rota_kanal'; static const _kAd = 'Rota'; static const _kAc = 'Rota bildirimleri';
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
  }
  static List<Map<String,dynamic>> rotaOptimize({required LatLng baslangic,required List<Map<String,dynamic>> duraklar}) {
    if (duraklar.isEmpty) return [];
    final sonuc=<Map<String,dynamic>>[]; final bekleyen=List<Map<String,dynamic>>.from(duraklar);
    LatLng simdiki=baslangic;
    while (bekleyen.isNotEmpty) {
      double minM=double.infinity; int minI=0;
      for (int i=0;i<bekleyen.length;i++) {
        final k=bekleyen[i]['konum']; if(k==null) continue;
        double lat,lng;
        if(k is GeoPoint){lat=k.latitude;lng=k.longitude;}
        else if(k is Map){lat=(k['lat'] as num?)?.toDouble()??0;lng=(k['lng'] as num?)?.toDouble()??0;}
        else continue;
        final m=Geolocator.distanceBetween(simdiki.latitude,simdiki.longitude,lat,lng);
        if(m<minM){minM=m;minI=i;}
      }
      final s=bekleyen.removeAt(minI); sonuc.add({...s,'sira':sonuc.length+1});
      final k=s['konum']; if(k is GeoPoint) simdiki=LatLng(k.latitude,k.longitude);
    }
    return sonuc;
  }
  static double mesafeHesapla(LatLng a,LatLng b)=>Geolocator.distanceBetween(a.latitude,a.longitude,b.latitude,b.longitude);
  static double toplamMesafe(List<LatLng> n){double t=0;for(int i=0;i<n.length-1;i++)t+=mesafeHesapla(n[i],n[i+1]);return t;}
  static Future<void> bildirimGoster({required String baslik,required String govde}) async {
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch%100000, baslik, govde,
      const NotificationDetails(
        android: AndroidNotificationDetails(_kId,_kAd,channelDescription:_kAc,importance:Importance.low,priority:Priority.low,icon:'@mipmap/ic_launcher'),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
