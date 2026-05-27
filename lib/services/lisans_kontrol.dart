import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/session_service.dart';

class LisansKontrol {
  static final _db = FirebaseFirestore.instance;

  /// Lisans durumunu kontrol et ve sonuç döndür
  static Future<LisansDurum> kontrol() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return LisansDurum.girisYapilmamis;

    try {
      final doc = await _db.collection('kullanicilar').doc(user.uid).get();
      if (!doc.exists) return LisansDurum.bulunamadi;

      final data = doc.data()!;
      final durum = data['durum'] ?? '';
      final rol = data['rol'] ?? '';

      // Süper admin kontrolü
      if (rol == 'superadmin') return LisansDurum.gecerli;

      // Durum kontrolü
      if (durum == 'beklemede') return LisansDurum.beklemede;
      if (durum == 'reddedildi') return LisansDurum.reddedildi;
      if (durum == 'askıya alındı') return LisansDurum.askiya;

      if (durum != 'onaylı' && durum != 'onaylandı' && durum != 'aktif') {
        return LisansDurum.beklemede;
      }

      // Lisans bitiş tarihi kontrolü
      final lisansBitis = data['lisansBitis'];
      if (lisansBitis != null) {
        final bitis = (lisansBitis as Timestamp).toDate();
        if (DateTime.now().isAfter(bitis)) return LisansDurum.suresiDolmus;
      }

      return LisansDurum.gecerli;
    } catch (e) {
      debugPrint('LisansKontrol hata: $e');
      return LisansDurum.hata;
    }
  }

  /// Aylık ödeme kaydı oluştur
  static Future<void> odemeKaydet({
    required String uid,
    required int ay,
  }) async {
    await _db.collection('lisans_odemeler').add({
      'uid': uid,
      'ay': ay,
      'durum': 'beklemede',
      'tarih': FieldValue.serverTimestamp(),
    });
  }

  /// Lisansı yenile (admin tarafından)
  static Future<void> lisansYenile({
    required String uid,
    required int ay, // 1, 3, 6, 12
  }) async {
    final bitis = DateTime.now().add(Duration(days: ay * 30));
    await _db.collection('kullanicilar').doc(uid).update({
      'lisansBitis': Timestamp.fromDate(bitis),
      'durum': 'onaylı',
      'lisansAy': ay,
      'lisansYenilemeTarihi': FieldValue.serverTimestamp(),
    });
  }

  /// Kullanıcının rolünü al
  static Future<String> rolAl(String uid) async {
    try {
      final doc = await _db.collection('kullanicilar').doc(uid).get();
      return doc.data()?['rol'] ?? 'veli';
    } catch (e) {
      return 'veli';
    }
  }

  /// Firma ID'sini al
  static Future<String?> firmaIdAl(String uid) async {
    try {
      final doc = await _db.collection('kullanicilar').doc(uid).get();
      return doc.data()?['firmaId'] as String?;
    } catch (e) {
      return null;
    }
  }
}

enum LisansDurum {
  gecerli,
  beklemede,
  reddedildi,
  askiya,
  suresiDolmus,
  bulunamadi,
  girisYapilmamis,
  hata,
}
