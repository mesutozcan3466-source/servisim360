import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  final _auth = FirebaseAuth.instance;
  final _db   = FirebaseFirestore.instance;

  String? _firmaId;
  String? _rol;
  String? _aktifProjeId;
  String? _aktifProjeAdi;

  String? get aktifProjeld  => _aktifProjeId;
  String? get aktifProjeAdi => _aktifProjeAdi;
  String? get cachedFirmaId => _firmaId;
  String? get uid   => _auth.currentUser?.uid;
  String? get email => _auth.currentUser?.email;

  bool _durumOnayli(String durum) {
    return durum == 'onayli' || durum == 'onaylı' || durum == 'aktif';
  }

  Future<Map<String, dynamic>> girisYap({
    required String email,
    required String sifre,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email, password: sifre);
      final uid = cred.user?.uid;
      if (uid == null) return {'basarili': false, 'hata': 'Kullanici bulunamadi'};

      final doc = await _db.collection('kullanicilar').doc(uid).get();

      if (!doc.exists) {
        await _auth.signOut();
        return {
          'basarili': false,
          'hata': 'Hesabiniz henuz tanimlanmamis. Yoneticinizle iletisime gecin.'
        };
      }

      final data  = doc.data()!;
      final durum = data['durum'] as String? ?? 'beklemede';

      if (durum == 'reddedildi') {
        await _auth.signOut();
        return {'basarili': false, 'hata': 'Hesabiniz reddedildi'};
      }
      if (durum == 'askida') {
        await _auth.signOut();
        return {'basarili': false, 'hata': 'Hesabiniz askiya alindi'};
      }
      if (durum == 'beklemede') {
        await _auth.signOut();
        return {'basarili': false, 'hata': 'onay_bekleniyor'};
      }
      if (!_durumOnayli(durum)) {
        await _auth.signOut();
        return {'basarili': false, 'hata': 'Hesabiniz aktif degil: $durum'};
      }

      _rol     = data['rol']     as String?;
      _firmaId = data['firmaId'] as String?;

      await _db.collection('kullanicilar').doc(uid).update({
        'sonGiris':           FieldValue.serverTimestamp(),
        'toplamGirisSayisi':  FieldValue.increment(1),
      });

      return {'basarili': true, 'rol': _rol, 'firmaId': _firmaId};
    } on FirebaseAuthException catch (e) {
      String mesaj = 'Giris basarisiz';
      switch (e.code) {
        case 'user-not-found':     mesaj = 'Kullanici bulunamadi';      break;
        case 'wrong-password':     mesaj = 'Hatali sifre';              break;
        case 'invalid-email':      mesaj = 'Gecersiz e-posta';          break;
        case 'too-many-requests':  mesaj = 'Cok fazla deneme, bekle';   break;
        case 'invalid-credential': mesaj = 'E-posta veya sifre hatali'; break;
        case 'user-disabled':      mesaj = 'Hesabiniz devre disi';      break;
      }
      return {'basarili': false, 'hata': mesaj};
    } catch (e) {
      return {'basarili': false, 'hata': 'Hata: $e'};
    }
  }

  Future<void> cikisYap() async {
    _firmaId       = null;
    _rol           = null;
    _aktifProjeId  = null;
    _aktifProjeAdi = null;
    await _auth.signOut();
  }

  Future<Map<String, dynamic>> sifreSifirla(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return {'basarili': true};
    } catch (e) {
      return {'basarili': false, 'hata': 'Gonderilemedi: $e'};
    }
  }

  Future<Map<String, dynamic>> girisKontrol() async {
    final user = _auth.currentUser;
    if (user == null) return {'girisYapilmis': false};

    try {
      final doc = await _db.collection('kullanicilar').doc(user.uid).get();

      if (!doc.exists) {
        await _auth.signOut();
        return {'girisYapilmis': false, 'hata': 'Hesap tanimli degil'};
      }

      final data  = doc.data()!;
      final durum = data['durum'] as String? ?? 'beklemede';

      if (durum == 'reddedildi') {
        await _auth.signOut();
        return {'girisYapilmis': false, 'hata': 'reddedildi'};
      }
      if (durum == 'askida') {
        await _auth.signOut();
        return {'girisYapilmis': false, 'hata': 'askida'};
      }
      if (durum == 'beklemede') {
        return {'girisYapilmis': false, 'hata': 'onay_bekleniyor'};
      }
      if (!_durumOnayli(durum)) {
        await _auth.signOut();
        return {'girisYapilmis': false, 'hata': 'Hesap aktif degil'};
      }

      _rol     = data['rol']     as String?;
      _firmaId = data['firmaId'] as String?;

      return {'girisYapilmis': true, 'rol': _rol, 'firmaId': _firmaId};
    } catch (_) {
      if (_rol != null) {
        return {'girisYapilmis': true, 'rol': _rol};
      }
      return {'girisYapilmis': false};
    }
  }

  Future<String?> rolAl() async {
    if (_rol != null) return _rol;
    final u = _auth.currentUser;
    if (u == null) return null;
    try {
      final doc = await _db.collection('kullanicilar').doc(u.uid).get();
      if (!doc.exists) return null;
      _rol = doc.data()?['rol'] as String?;
      return _rol;
    } catch (_) { return null; }
  }

  // Orijinal metod (degistirilmedi)
  Future<String?> firmaldAl() async {
    if (_firmaId != null) return _firmaId;
    final u = _auth.currentUser;
    if (u == null) return null;
    try {
      final doc = await _db.collection('kullanicilar').doc(u.uid).get();
      if (!doc.exists) return null;
      _firmaId = doc.data()?['firmaId'] as String?;
      return _firmaId;
    } catch (_) { return null; }
  }

  // YENİ: firmaIdAl - firmaldAl ile ayni, tutarlilik icin eklendi
  Future<String?> firmaIdAl() => firmaldAl();

  // YENİ: firmaAdiAl - firms koleksiyonundan firma adini getirir
  Future<String?> firmaAdiAl() async {
    final firmaId = await firmaldAl();
    if (firmaId == null) return null;
    try {
      final doc = await _db.collection('firms').doc(firmaId).get();
      if (!doc.exists) return null;
      return doc.data()?['ad'] as String?
          ?? doc.data()?['adi'] as String?
          ?? doc.data()?['firmaAdi'] as String?;
    } catch (_) { return null; }
  }

  Future<bool> lisansGecerliMi() async {
    final firmaId = await firmaldAl();
    if (firmaId == null) return true;
    try {
      final doc   = await _db.collection('firms').doc(firmaId).get();
      final bitis = doc.data()?['lisansBitis'] as Timestamp?;
      if (bitis == null) return true;
      return bitis.toDate().isAfter(DateTime.now());
    } catch (_) { return true; }
  }

  Future<void> cihazBilgisiDisaridan(Map<String, dynamic> cihaz) async {
    final u = _auth.currentUser;
    if (u == null) return;
    try {
      await _db.collection('kullanicilar').doc(u.uid).update({
        'cihazBilgisi': cihaz,
        'sonGiris':     FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  void aktifProjeAyarla(String projeId, String projeAdi) {
    _aktifProjeId  = projeId;
    _aktifProjeAdi = projeAdi;
  }

  void projeTemizle() {
    _aktifProjeId  = null;
    _aktifProjeAdi = null;
  }
}
