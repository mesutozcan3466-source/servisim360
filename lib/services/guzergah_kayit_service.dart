import 'package:cloud_firestore/cloud_firestore.dart';

/// Güzergah kayıt ve geçmiş servisi
class GuzergahKayitService {
  static final _db = FirebaseFirestore.instance;

  // ── Oturum Başlat ───────────────────────────────────────────────────────────
  static Future<String> oturumBaslat({
    required String surucuId,
    required String firmaId,
  }) async {
    final tarih  = _bugunKey();
    final docId  = '${surucuId}_$tarih';
    final oturumId = DateTime.now().millisecondsSinceEpoch.toString();

    final ref = _db.collection('guzergah_kayitlar').doc(docId);
    final doc = await ref.get();

    if (!doc.exists) {
      await ref.set({
        'surucuId':  surucuId,
        'firmaId':   firmaId,
        'tarih':     tarih,
        'oturumlar': [],
        'noktalar':  [],
      });
    }

    // Oturum ekle
    await ref.update({
      'oturumlar': FieldValue.arrayUnion([{
        'id':        oturumId,
        'baslangic': FieldValue.serverTimestamp(),
        'bitis':     null,
        'toplamKm':  0.0,
      }]),
    });

    // Sürücü aktif durumunu güncelle
    await _db.collection('drivers').doc(surucuId).update({
      'servisAktif':       true,
      'aktifOturumId':     oturumId,
      'servisBaslangic':   FieldValue.serverTimestamp(),
    });

    return oturumId;
  }

  // ── Oturum Bitir ────────────────────────────────────────────────────────────
  static Future<void> oturumBitir({
    required String oturumId,
    required double toplamKm,
  }) async {
    // Tüm belgelerde bu oturumu bul ve güncelle
    final snap = await _db
        .collection('guzergah_kayitlar')
        .where('oturumlar', arrayContains: {'id': oturumId})
        .limit(1)
        .get();

    // Direkt güncelleme için surucuId'yi al
    final surucuSnap = await _db
        .collection('drivers')
        .where('aktifOturumId', isEqualTo: oturumId)
        .limit(1)
        .get();

    if (surucuSnap.docs.isNotEmpty) {
      final surucuId = surucuSnap.docs.first.id;
      final tarih    = _bugunKey();
      final docId    = '${surucuId}_$tarih';

      final ref = _db.collection('guzergah_kayitlar').doc(docId);
      final doc = await ref.get();

      if (doc.exists) {
        final oturumlar = List<Map<String, dynamic>>.from(
            doc.data()?['oturumlar'] ?? []);
        final idx = oturumlar.indexWhere((o) => o['id'] == oturumId);
        if (idx != -1) {
          oturumlar[idx]['bitis']    = Timestamp.now();
          oturumlar[idx]['toplamKm'] = toplamKm;
          await ref.update({'oturumlar': oturumlar});
        }
      }

      // Sürücü durumunu güncelle
      await _db.collection('drivers').doc(surucuId).update({
        'servisAktif':   false,
        'aktifOturumId': null,
        'servisBitis':   FieldValue.serverTimestamp(),
      });
    }
  }

  // ── Konum Kaydet ────────────────────────────────────────────────────────────
  static Future<void> konumKaydet({
    required String surucuId,
    required String firmaId,
    required double lat,
    required double lng,
    double hiz = 0,
  }) async {
    final tarih = _bugunKey();
    final docId = '${surucuId}_$tarih';
    final ref   = _db.collection('guzergah_kayitlar').doc(docId);

    // Nokta ekle (array union ile)
    await ref.set({
      'surucuId': surucuId,
      'firmaId':  firmaId,
      'tarih':    tarih,
      'noktalar': FieldValue.arrayUnion([{
        'lat':  lat,
        'lng':  lng,
        'hiz':  hiz,
        'zaman': Timestamp.now().millisecondsSinceEpoch,
      }]),
    }, SetOptions(merge: true));

    // Sürücü konumunu da güncelle (canlı takip için)
    await _db.collection('drivers').doc(surucuId).update({
      'konum':          GeoPoint(lat, lng),
      'hiz':            hiz,
      'konumGuncelleme': FieldValue.serverTimestamp(),
    });
  }

  // ── Günün Oturumlarını Getir ────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> gunOturumlari({
    required String surucuId,
    required String tarih,
  }) async {
    final docId = '${surucuId}_$tarih';
    try {
      final doc = await _db.collection('guzergah_kayitlar').doc(docId).get();
      if (!doc.exists) return [];

      final oturumlar = List<Map<String, dynamic>>.from(
          doc.data()?['oturumlar'] ?? []);

      // Timestamp'leri düzenle
      return oturumlar.map((o) {
        return {
          'id':        o['id'],
          'baslangic': o['baslangic'],
          'bitis':     o['bitis'],
          'toplamKm':  (o['toplamKm'] as num?)?.toDouble() ?? 0.0,
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Eski Kayıtları Temizle (4 günden eski) ──────────────────────────────────
  static Future<void> eskiKayitlariTemizle(String firmaId) async {
    final sinir = DateTime.now().subtract(const Duration(days: 4));
    final sinirKey =
        '${sinir.year}-${sinir.month.toString().padLeft(2, '0')}-${sinir.day.toString().padLeft(2, '0')}';

    try {
      final snap = await _db
          .collection('guzergah_kayitlar')
          .where('firmaId', isEqualTo: firmaId)
          .where('tarih', isLessThan: sinirKey)
          .get();

      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (_) {}
  }

  // ── Yardımcı ────────────────────────────────────────────────────────────────
  static String _bugunKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}
