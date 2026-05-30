import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

// Web'de arka plan servisi yoktur.
// Mobilde flutter_background_service olmadan
// foreground stream ile konum guncellenir.

class ArkaplanKonumServisi {
  static final _notifications = FlutterLocalNotificationsPlugin();
  static StreamSubscription<Position>? _konumSub;
  static Timer? _saatTimer;
  static bool _aktif = false;

  static Future<void> baslatServisi() async {
    if (kIsWeb) return;
    await _notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
  }

  static Future<void> baslat({
    required String surucuDocId,
    required String firmaId,
  }) async {
    if (kIsWeb || _aktif) return;
    _aktif = true;

    final ss = await _saatleriOku(surucuDocId);

    if (_saatKontrol(ss)) {
      await _gpsBaslat(surucuDocId);
    }

    _saatTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      final saatler = await _saatleriOku(surucuDocId);
      final aktif = _saatKontrol(saatler);
      if (aktif && _konumSub == null) {
        await _gpsBaslat(surucuDocId);
        bildirimGonder(baslik: 'Servis Saati Basladi', mesaj: 'Konum paylasimi aktif.');
      } else if (!aktif && _konumSub != null) {
        await durdur(surucuDocId: surucuDocId);
        bildirimGonder(baslik: 'Servis Saati Bitti', mesaj: 'Konum paylasimi durduruldu.');
      }
    });
  }

  static Future<void> _gpsBaslat(String surucuDocId) async {
    _konumSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      ),
    ).listen((pos) async {
      try {
        await FirebaseFirestore.instance
            .collection('drivers').doc(surucuDocId).update({
          'konum':           GeoPoint(pos.latitude, pos.longitude),
          'hiz':             pos.speed * 3.6,
          'konumGuncelleme': FieldValue.serverTimestamp(),
          'servisAktif':     true,
        });
      } catch (_) {}
    });
  }

  static Future<void> durdur({String? surucuDocId}) async {
    if (kIsWeb) return;
    _saatTimer?.cancel();
    _saatTimer = null;
    _konumSub?.cancel();
    _konumSub = null;
    _aktif = false;
    if (surucuDocId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('drivers').doc(surucuDocId).update({
          'servisAktif': false,
          'servisBitis': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
  }

  static bool calisiyorMu() => _aktif;

  static Future<void> bildirimGonder({
    required String baslik,
    required String mesaj,
  }) async {
    if (kIsWeb) return;
    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      baslik,
      mesaj,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'servisim360_bildirim', 'Servis Bildirimleri',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
            presentAlert: true, presentSound: true),
      ),
    );
  }

  static Future<Map<String, dynamic>> _saatleriOku(String surucuDocId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('drivers').doc(surucuDocId).get();
      final ss = doc.data()?['servisSaati'] as Map<String, dynamic>?;
      return ss ?? {
        'sabahBaslangic': '06:30', 'sabahBitis': '09:30',
        'aksamBaslangic': '15:00', 'aksamBitis': '18:30',
      };
    } catch (_) {
      return {
        'sabahBaslangic': '06:30', 'sabahBitis': '09:30',
        'aksamBaslangic': '15:00', 'aksamBitis': '18:30',
      };
    }
  }

  static bool _saatKontrol(Map<String, dynamic> ss) {
    final now = TimeOfDay.now();
    final nowMin = now.hour * 60 + now.minute;
    int parse(String s) {
      final p = s.split(':');
      return int.parse(p[0]) * 60 + int.parse(p[1]);
    }
    final sB = parse(ss['sabahBaslangic'] ?? '06:30');
    final sE = parse(ss['sabahBitis']     ?? '09:30');
    final aB = parse(ss['aksamBaslangic'] ?? '15:00');
    final aE = parse(ss['aksamBitis']     ?? '18:30');
    return (nowMin >= sB && nowMin <= sE) ||
        (nowMin >= aB && nowMin <= aE);
  }
}