import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProjeService {
  static final _db = FirebaseFirestore.instance;

  /// Yeni proje oluştur
  static Future<String> projeOlustur({
    required String ad,
    required String tur,
    String? aciklama,
    String? telefon,
    String? adres,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final ref = await _db.collection('projeler').add({
      'ad': ad,
      'tur': tur,
      'aciklama': aciklama ?? '',
      'telefon': telefon ?? '',
      'adres': adres ?? '',
      'adminUid': uid,
      'suruculer': [],
      'olusturmaTarihi': FieldValue.serverTimestamp(),
      'durum': 'aktif',
    });

    // Varsayılan servis saati ayarları
    await ref.collection('ayarlar').doc('genel').set({
      'sabahBaslangic': '07:00',
      'sabahBitis': '09:00',
      'aksamBaslangic': '15:00',
      'aksamBitis': '18:30',
      'servisKapasitesi': 16,
      'guzergahKayitGun': 4,
      'otomatikRota': true,
      'veliCanlıTakip': true,
    });

    return ref.id;
  }

  /// Admin'e ait aktif projeleri stream olarak getir
  static Stream<QuerySnapshot> adminProjeleri(String adminUid) {
    return _db
        .collection('projeler')
        .where('adminUid', isEqualTo: adminUid)
        .where('durum', isEqualTo: 'aktif')
        .orderBy('olusturmaTarihi', descending: true)
        .snapshots();
  }

  /// Projeyi güncelle
  static Future<void> projeGuncelle(
      String projeId, Map<String, dynamic> data) async {
    await _db.collection('projeler').doc(projeId).update(data);
  }

  /// Projeyi soft delete ile sil
  static Future<void> projeSil(String projeId) async {
    await _db
        .collection('projeler')
        .doc(projeId)
        .update({'durum': 'silindi'});
  }

  /// Projeye şoför ekle
  static Future<void> soforEkle(String projeId, String surucuId) async {
    await _db.collection('projeler').doc(projeId).update({
      'suruculer': FieldValue.arrayUnion([surucuId]),
    });
  }

  /// Projeden şoför çıkar
  static Future<void> soforCikar(String projeId, String surucuId) async {
    await _db.collection('projeler').doc(projeId).update({
      'suruculer': FieldValue.arrayRemove([surucuId]),
    });
  }

  /// Proje istatistiklerini getir
  static Future<Map<String, int>> projeIstatistik(String projeId) async {
    final projeRef = _db.collection('projeler').doc(projeId);

    try {
      final results = await Future.wait([
        projeRef.collection('ogrenciler').count().get(),
        projeRef.collection('suruculer').count().get(),
        projeRef.collection('araclar').count().get(),
      ]);

      return {
        'ogrenci': results[0].count ?? 0,
        'sofor': results[1].count ?? 0,
        'arac': results[2].count ?? 0,
      };
    } catch (_) {
      return {'ogrenci': 0, 'sofor': 0, 'arac': 0};
    }
  }
}
