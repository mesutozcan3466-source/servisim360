import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

// ════════════════════════════════════════════════════════════════
//  ARKA PLAN KONUM SERVİSİ
//
//  Ekran kapalı olsa bile çalışır.
//  Servis saati gelince otomatik GPS açar.
//  Servis saati bitince otomatik GPS kapatır.
//  Şoföre yaklaşınca veli'ye bildirim gönderir.
// ════════════════════════════════════════════════════════════════
class ArkaplanKonumServisi {
  static final _notifications = FlutterLocalNotificationsPlugin();

  // ── SERVİS BAŞLAT ───────────────────────────────────────────
  static Future<void> baslatServisi() async {
    // Bildirim kanalı
    await _notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'servisim360_konum',
        initialNotificationTitle: 'Servisim360',
        initialNotificationContent: 'Servis takibi aktif',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onBackground,
      ),
    );
  }

  // ── SERVİS BAŞLAT / DURDUR ──────────────────────────────────
  static Future<void> baslat() async {
    final service = FlutterBackgroundService();
    final calisiyorMu = await service.isRunning();
    if (!calisiyorMu) await service.startService();
  }

  static Future<void> durdur() async {
    FlutterBackgroundService().invoke('durdur');
  }

  static Future<bool> calisiyorMu() =>
      FlutterBackgroundService().isRunning();

  // ── BİLDİRİM GÖNDER ────────────────────────────────────────
  static Future<void> bildirimGonder({
    required String baslik,
    required String mesaj,
    String? payload,
  }) async {
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      baslik,
      mesaj,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'servisim360_bildirim',
          'Servis Bildirimleri',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true, presentSound: true,
        ),
      ),
      payload: payload,
    );
  }
}

// ── ARKA PLAN ENTRY POINT ─────────────────────────────────────
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('durdur').listen((_) => service.stopSelf());
  }

  // Şoför mı veli mi?
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) { service.stopSelf(); return; }

  final kulDoc = await FirebaseFirestore.instance
      .collection('kullanicilar').doc(uid).get();
  final rol      = kulDoc.data()?['rol']     as String? ?? '';
  final firmaId  = kulDoc.data()?['firmaId'] as String? ?? '';

  if (rol == 'sofor') {
    await _soforArkaplan(service, uid, firmaId);
  } else if (rol == 'veli') {
    await _veliArkaplan(service, uid, firmaId);
  } else {
    service.stopSelf();
  }
}

// ── ŞOFÖR ARKA PLAN ──────────────────────────────────────────
Future<void> _soforArkaplan(
    ServiceInstance service, String uid, String firmaId) async {

  String? surucuDocId;
  StreamSubscription<Position>? konumSub;
  Timer? saatTimer;

  // Şoför dokümanını bul
  final dSnap = await FirebaseFirestore.instance
      .collection('drivers')
      .where('firmaId', isEqualTo: firmaId)
      .where('uid', isEqualTo: uid)
      .limit(1).get();
  if (dSnap.docs.isNotEmpty) surucuDocId = dSnap.docs.first.id;

  // Şoförün servis saatlerini oku
  Future<Map<String, dynamic>> _saatleriOku() async {
    if (surucuDocId == null) return {};
    final doc = await FirebaseFirestore.instance
        .collection('drivers').doc(surucuDocId!).get();
    final ss = doc.data()?['servisSaati'] as Map<String, dynamic>?;
    return ss ?? {
      'sabahBaslangic': '06:30', 'sabahBitis': '09:30',
      'aksamBaslangic': '15:00', 'aksamBitis': '18:30',
    };
  }

  bool _saatKontrol(Map<String, dynamic> ss) {
    final now = TimeOfDay.now();
    int nowMin = now.hour * 60 + now.minute;

    _parse(String s) {
      final p = s.split(':');
      return int.parse(p[0]) * 60 + int.parse(p[1]);
    }

    final sB = _parse(ss['sabahBaslangic'] ?? '06:30');
    final sE = _parse(ss['sabahBitis']     ?? '09:30');
    final aB = _parse(ss['aksamBaslangic'] ?? '15:00');
    final aE = _parse(ss['aksamBitis']     ?? '18:30');
    return (nowMin >= sB && nowMin <= sE) ||
        (nowMin >= aB && nowMin <= aE);
  }

  void _gpsBaslat() {
    if (konumSub != null) return;
    konumSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      ),
    ).listen((pos) async {
      if (surucuDocId == null) return;
      try {
        await FirebaseFirestore.instance
            .collection('drivers').doc(surucuDocId!).update({
          'konum':           GeoPoint(pos.latitude, pos.longitude),
          'hiz':             pos.speed * 3.6,
          'konumGuncelleme': FieldValue.serverTimestamp(),
          'servisAktif':     true,
        });
      } catch (_) {}
    });
  }

  void _gpsDurdur() {
    konumSub?.cancel();
    konumSub = null;
    if (surucuDocId != null) {
      FirebaseFirestore.instance
          .collection('drivers').doc(surucuDocId!).update({
        'servisAktif': false,
        'servisBitis': FieldValue.serverTimestamp(),
      });
    }
  }

  bool _oncekiSaatDurumu = false;

  // Her dakika saat kontrolü
  saatTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
    final ss     = await _saatleriOku();
    final aktif  = _saatKontrol(ss);

    if (aktif && !_oncekiSaatDurumu) {
      // Servis saati başladı
      _gpsBaslat();
      _oncekiSaatDurumu = true;
      ArkaplanKonumServisi.bildirimGonder(
        baslik: 'Servis Saati Basladi',
        mesaj:  'Konum paylasimi otomatik baslatildi.',
      );
    } else if (!aktif && _oncekiSaatDurumu) {
      // Servis saati bitti
      _gpsDurdur();
      _oncekiSaatDurumu = false;
      ArkaplanKonumServisi.bildirimGonder(
        baslik: 'Servis Saati Bitti',
        mesaj:  'Konum paylasimi otomatik durduruldu.',
      );
    }
  });

  // İlk kontrol — servis saatindeyse hemen başlat
  final ss = await _saatleriOku();
  if (_saatKontrol(ss)) {
    _gpsBaslat();
    _oncekiSaatDurumu = true;
  }

  // Servis durdurulunca temizle
  service.on('durdur').listen((_) {
    saatTimer?.cancel();
    konumSub?.cancel();
    service.stopSelf();
  });
}

// ── VELİ ARKA PLAN ───────────────────────────────────────────
Future<void> _veliArkaplan(
    ServiceInstance service, String uid, String firmaId) async {

  String? ogrenciId;
  String? soforDocId;
  int     _oncekiKalanDurak = -1;
  StreamSubscription<DocumentSnapshot>? soforSub;

  // Velinin öğrencisini ve şoförünü bul
  final pSnap = await FirebaseFirestore.instance
      .collection('parents').where('uid', isEqualTo: uid).limit(1).get();
  if (pSnap.docs.isEmpty) { service.stopSelf(); return; }

  final oSnap = await FirebaseFirestore.instance
      .collection('students')
      .where('veliId', isEqualTo: pSnap.docs.first.id)
      .limit(1).get();
  if (oSnap.docs.isEmpty) { service.stopSelf(); return; }

  ogrenciId = oSnap.docs.first.id;
  soforDocId = oSnap.docs.first.data()['surucuId'] as String?;
  if (soforDocId == null || soforDocId!.isEmpty) {
    service.stopSelf(); return;
  }

  // Şoförü canlı dinle
  soforSub = FirebaseFirestore.instance
      .collection('drivers').doc(soforDocId!)
      .snapshots()
      .listen((snap) async {
    if (!snap.exists) return;
    final soforData = snap.data()!;
    final servisAktif = soforData['servisAktif'] == true;
    if (!servisAktif) return;

    // Durak sırası hesapla
    try {
      final allSnap = await FirebaseFirestore.instance
          .collection('students')
          .where('surucuId', isEqualTo: soforDocId)
          .orderBy('sira')
          .get();

      final docs      = allSnap.docs;
      final benimIdx  = docs.indexWhere((d) => d.id == ogrenciId);
      if (benimIdx < 0) return;

      final bekleyenIdx = docs.indexWhere((d) => d.data()['bindi'] != true);
      if (bekleyenIdx < 0) {
        // Herkes bindi
        if (_oncekiKalanDurak != 0) {
          _oncekiKalanDurak = 0;
          ArkaplanKonumServisi.bildirimGonder(
            baslik: 'Iyi Dersler!',
            mesaj:  '${docs[benimIdx].data()['ad'] ?? 'Ogrenci'} okula ulasti.',
          );
        }
        return;
      }

      final kalan = benimIdx - bekleyenIdx;

      if (kalan != _oncekiKalanDurak) {
        _oncekiKalanDurak = kalan;
        if (kalan == 2) {
          ArkaplanKonumServisi.bildirimGonder(
            baslik: '2 Durak Kaldi',
            mesaj:  'Servis 2 durak sonra sizin duraginizda. Hazirlanin!',
          );
        } else if (kalan == 1) {
          ArkaplanKonumServisi.bildirimGonder(
            baslik: '1 Durak Kaldi — Hazir Olun!',
            mesaj:  'Servis bir sonraki duraginizda!',
          );
        } else if (kalan <= 0) {
          ArkaplanKonumServisi.bildirimGonder(
            baslik: 'Servis Duraginizda!',
            mesaj:  'Servis simdi sizin duraginizda. Hemen cikmayi hazirlayin.',
          );
        }
      }
    } catch (_) {}
  });

  service.on('durdur').listen((_) {
    soforSub?.cancel();
    service.stopSelf();
  });
}

@pragma('vm:entry-point')
Future<bool> onBackground(ServiceInstance service) async => true;
