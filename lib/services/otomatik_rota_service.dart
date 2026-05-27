import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class OtomatikRotaService {
  static final _db = FirebaseFirestore.instance;

  /// Ogrencileri surucülere yakinligina gore otomatik ata
  static Future<OtomatikRotaSonuc> ogrencileriGrupla({
    required String firmaId,
    required List<Map<String, dynamic>> ogrenciler,
    required List<Map<String, dynamic>> suruculer,
    int kapasitePerArac = 16,
  }) async {
    if (ogrenciler.isEmpty || suruculer.isEmpty) {
      return OtomatikRotaSonuc(atamalar: {}, mesaj: 'Ogrenci veya surucu bulunamadi');
    }

    // Koordinati olan ogrencileri filtrele
    final koordinatliOgrenciler = ogrenciler
        .where((o) => o['lat'] != null && o['lng'] != null)
        .toList();

    if (koordinatliOgrenciler.isEmpty) {
      return OtomatikRotaSonuc(
          atamalar: {}, mesaj: 'Koordinati olan ogrenci bulunamadi. Once OCR kayit ile adresleri tanitin.');
    }

    // Her ogrenciyi en yakin surucuye ata (kapasiteye dikkat et)
    final Map<String, List<String>> suruciOgrenciMap = {};
    final Map<String, int> suruciKapasite = {};

    for (final surucu in suruculer) {
      suruciOgrenciMap[surucu['id']] = [];
      suruciKapasite[surucu['id']] = 0;
    }

    // Her ogrenci icin en yakin surucuyu bul
    for (final ogr in koordinatliOgrenciler) {
      final ogrLat = (ogr['lat'] as num).toDouble();
      final ogrLng = (ogr['lng'] as num).toDouble();

      String? enYakinSurucuId;
      double enYakinMesafe = double.infinity;

      for (final surucu in suruculer) {
        // Kapasite doluysa atla
        if ((suruciKapasite[surucu['id']] ?? 0) >= kapasitePerArac) continue;

        final surucuLat = (surucu['lat'] as num?)?.toDouble();
        final surucuLng = (surucu['lng'] as num?)?.toDouble();

        if (surucuLat == null || surucuLng == null) continue;

        final mesafe = Geolocator.distanceBetween(
            ogrLat, ogrLng, surucuLat, surucuLng);

        if (mesafe < enYakinMesafe) {
          enYakinMesafe = mesafe;
          enYakinSurucuId = surucu['id'];
        }
      }

      if (enYakinSurucuId != null) {
        suruciOgrenciMap[enYakinSurucuId]!.add(ogr['id']);
        suruciKapasite[enYakinSurucuId] =
            (suruciKapasite[enYakinSurucuId] ?? 0) + 1;
      }
    }

    // Koordinati olmayan ogrencileri kalan kapasitelere dagit
    final koordinatsizOgrenciler = ogrenciler
        .where((o) => o['lat'] == null || o['lng'] == null)
        .toList();

    for (final ogr in koordinatsizOgrenciler) {
      // En az ogrencisi olan surucuya ata
      String? enBosId;
      int enBosKapasite = kapasitePerArac + 1;

      for (final entry in suruciKapasite.entries) {
        if (entry.value < enBosKapasite && entry.value < kapasitePerArac) {
          enBosKapasite = entry.value;
          enBosId = entry.key;
        }
      }

      if (enBosId != null) {
        suruciOgrenciMap[enBosId]!.add(ogr['id']);
        suruciKapasite[enBosId] = (suruciKapasite[enBosId] ?? 0) + 1;
      }
    }

    return OtomatikRotaSonuc(
      atamalar: suruciOgrenciMap,
      mesaj:
      '${koordinatliOgrenciler.length} ogrenci koordinata gore, ${koordinatsizOgrenciler.length} ogrenci kapasiteye gore atandi.',
      koordinatliSayisi: koordinatliOgrenciler.length,
      koordinatsizSayisi: koordinatsizOgrenciler.length,
    );
  }

  /// Atama sonucunu Firestore'a kaydet
  static Future<void> atamalariKaydet({
    required Map<String, List<String>> atamalar,
    required String firmaId,
  }) async {
    final batch = _db.batch();

    for (final entry in atamalar.entries) {
      final surucuId = entry.key;
      final ogrenciIdler = entry.value;

      for (final ogrenciId in ogrenciIdler) {
        final ref = _db.collection('ogrenciler').doc(ogrenciId);
        batch.update(ref, {
          'surucuId': surucuId,
          'otomatikAtama': true,
          'atamaTarihi': FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();
    debugPrint('Otomatik atama tamamlandi: ${atamalar.length} surucu');
  }

  /// Tum atamalari sifirla
  static Future<void> atamalariSifirla(String firmaId) async {
    final snap = await _db
        .collection('ogrenciler')
        .where('firmaId', isEqualTo: firmaId)
        .get();

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {
        'surucuId': null,
        'otomatikAtama': false,
      });
    }
    await batch.commit();
  }

  /// Belirli bir bolgedeki ogrencileri getir (harita icin)
  static List<Map<String, dynamic>> bolgeFiltrele({
    required List<Map<String, dynamic>> ogrenciler,
    required double merkezLat,
    required double merkezLng,
    required double yaricapKm,
  }) {
    return ogrenciler.where((ogr) {
      final lat = (ogr['lat'] as num?)?.toDouble();
      final lng = (ogr['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return false;

      final mesafe = Geolocator.distanceBetween(
          merkezLat, merkezLng, lat, lng) /
          1000;
      return mesafe <= yaricapKm;
    }).toList();
  }
}

class OtomatikRotaSonuc {
  final Map<String, List<String>> atamalar;
  final String mesaj;
  final int koordinatliSayisi;
  final int koordinatsizSayisi;

  OtomatikRotaSonuc({
    required this.atamalar,
    required this.mesaj,
    this.koordinatliSayisi = 0,
    this.koordinatsizSayisi = 0,
  });

  int get toplamAtanan =>
      atamalar.values.fold(0, (sum, list) => sum + list.length);
}
