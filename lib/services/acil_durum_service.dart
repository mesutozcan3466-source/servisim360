import 'package:cloud_firestore/cloud_firestore.dart';

/// Acil durum bildirim servisi
class AcilDurumService {
  static final _db = FirebaseFirestore.instance;

  /// Şoförden acil durum gönder
  static Future<void> acilDurumGonder({
    required String surucuId,
    required String surucuAd,
    required String firmaId,
    String? plaka,
  }) async {
    final batch = _db.batch();

    // Acil durum kaydı oluştur
    final acilRef = _db.collection('acil_durumlar').doc();
    batch.set(acilRef, {
      'surucuId':  surucuId,
      'surucuAd':  surucuAd,
      'firmaId':   firmaId,
      'plaka':     plaka ?? '',
      'durum':     'aktif',
      'tarih':     FieldValue.serverTimestamp(),
    });

    // Sürücü belgesine acil durum flag'i ekle
    final surucuRef = _db.collection('drivers').doc(surucuId);
    batch.update(surucuRef, {
      'acilDurum':      true,
      'acilDurumZaman': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Acil durumu çözüldü olarak işaretle
  static Future<void> acilDurumCoz(String acilId, String surucuId) async {
    final batch = _db.batch();

    batch.update(_db.collection('acil_durumlar').doc(acilId), {
      'durum':       'cozuldu',
      'cozumZaman':  FieldValue.serverTimestamp(),
    });

    batch.update(_db.collection('drivers').doc(surucuId), {
      'acilDurum': false,
    });

    await batch.commit();
  }

  /// Firmaya ait aktif acil durumları dinle
  static Stream<QuerySnapshot> aktifAcilDurumlari(String firmaId) {
    return _db
        .collection('acil_durumlar')
        .where('firmaId', isEqualTo: firmaId)
        .where('durum', isEqualTo: 'aktif')
        .orderBy('tarih', descending: true)
        .snapshots();
  }

  /// Son acil durumları getir (geçmiş)
  static Future<List<Map<String, dynamic>>> sonAcilDurumlar(
      String firmaId, {int limit = 20}) async {
    final snap = await _db
        .collection('acil_durumlar')
        .where('firmaId', isEqualTo: firmaId)
        .orderBy('tarih', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }
}
