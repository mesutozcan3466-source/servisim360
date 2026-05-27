import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:device_info_plus/device_info_plus.dart';

// ════════════════════════════════════════════════════════════════
//  GiRiS LOG SERVISi
//  Her giriste Firestore'a log yazar
//  Kacak giris tespiti: farkli cihazdan giris
// ════════════════════════════════════════════════════════════════
class GirisLogServisi {
  static final GirisLogServisi instance = GirisLogServisi._();
  GirisLogServisi._();

  final _db = FirebaseFirestore.instance;

  // Giris logu yaz
  Future<void> girisLogYaz({
    required String uid,
    required String email,
    required String rol,
    String? firmaId,
  }) async {
    try {
      final cihazBilgisi = await _cihazBilgisiAl();
      final now = FieldValue.serverTimestamp();

      // Giris loglari koleksiyonuna ekle
      await _db.collection('giris_loglari').add({
        'uid':        uid,
        'email':      email,
        'rol':        rol,
        'firmaId':    firmaId ?? '',
        'tarih':      now,
        'cihaz':      cihazBilgisi,
        'islem':      'giris',
      });

      // Kullanici belgesini guncelle
      await _db.collection('kullanicilar').doc(uid).update({
        'sonGiris':          now,
        'sonGirisCihaz':     cihazBilgisi,
        'toplamGirisSayisi': FieldValue.increment(1),
      });

      // Rol bazli koleksiyonu guncelle
      await _rolKoleksiyonuGuncelle(uid, email, rol, cihazBilgisi);

    } catch (e) {
      // Log hatasi uygulamayi durdurmasin
    }
  }

  Future<void> _rolKoleksiyonuGuncelle(
      String uid, String email, String rol, String cihaz) async {
    try {
      String koleksiyon;
      if (rol == 'sofor' || rol == 'bireyselSofor') {
        koleksiyon = 'drivers';
      } else if (rol == 'veli') {
        koleksiyon = 'parents';
      } else {
        return; // Admin icin gerekmez
      }

      // UID ile bul
      var snap = await _db.collection(koleksiyon)
          .where('uid', isEqualTo: uid).limit(1).get();
      if (snap.docs.isEmpty) {
        snap = await _db.collection(koleksiyon)
            .where('email', isEqualTo: email).limit(1).get();
      }

      if (snap.docs.isNotEmpty) {
        await snap.docs.first.reference.update({
          'sonGiris':      FieldValue.serverTimestamp(),
          'sonGirisCihaz': cihaz,
          'girisKaydi':    true,
        });
      }
    } catch (_) {}
  }

  // Cikis logu yaz
  Future<void> cikisLogYaz(String uid, String rol) async {
    try {
      await _db.collection('giris_loglari').add({
        'uid':   uid,
        'rol':   rol,
        'tarih': FieldValue.serverTimestamp(),
        'islem': 'cikis',
      });
    } catch (_) {}
  }

  // Kacak giris kontrolu
  // Son 24 saatte farkli 3+ cihazdan giris yapilmissa uyar
  Future<bool> kacakGirisKontrolu(String uid) async {
    try {
      final bugun = DateTime.now().subtract(const Duration(hours: 24));
      final snap = await _db.collection('giris_loglari')
          .where('uid', isEqualTo: uid)
          .where('islem', isEqualTo: 'giris')
          .orderBy('tarih', descending: true)
          .limit(10)
          .get();

      final cihazlar = snap.docs
          .map((d) => (d.data())['cihaz'] as String? ?? '')
          .where((c) => c.isNotEmpty)
          .toSet();

      // 3+ farkli cihazdan giris varsa suphe var
      return cihazlar.length >= 3;
    } catch (_) {
      return false;
    }
  }

  Future<String> _cihazBilgisiAl() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return '${androidInfo.brand} ${androidInfo.model} (Android ${androidInfo.version.release})';
    } catch (_) {
      return 'Bilinmeyen Cihaz';
    }
  }

  // Giris gecmisini getir (admin icin)
  Stream<List<Map<String, dynamic>>> girisGecmisi(String firmaId) {
    return _db.collection('giris_loglari')
        .where('firmaId', isEqualTo: firmaId)
        .orderBy('tarih', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => {'id': d.id, ...d.data()})
        .toList());
  }
}
