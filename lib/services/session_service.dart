// ╔══════════════════════════════════════════════════════════════╗
// ║  DOSYA: lib/services/session_service.dart                    ║
// ║  Servisim360 — Oturum & Yetki Servisi                        ║
// ║  v3 — aktifProjeId typo fix + kullanıcı adı giriş desteği   ║
// ╚══════════════════════════════════════════════════════════════╝
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

  // ── Getterlar ────────────────────────────────────────────────
  /// DÜZELTME: aktifProjeld (l) → aktifProjeId (I)
  String? get aktifProjeId  => _aktifProjeId;
  /// Geriye dönük uyumluluk — yeni kodda aktifProjeId kullan
  String? get aktifProjeld  => _aktifProjeId;
  String? get aktifProjeAdi => _aktifProjeAdi;
  String? get cachedFirmaId => _firmaId;
  String? get uid           => _auth.currentUser?.uid;
  String? get email         => _auth.currentUser?.email;
  String? get rol           => _rol;

  bool _durumOnayli(String durum) =>
      durum == 'onayli' || durum == 'onaylı' || durum == 'aktif';

  // ── E-posta ile Giriş (Firma Admin) ──────────────────────────
  Future<Map<String, dynamic>> girisYap({
    required String email,
    required String sifre,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email, password: sifre);
      final uid = cred.user?.uid;
      if (uid == null) return {'basarili': false, 'hata': 'Kullanici bulunamadi'};
      return await _kullaniciyiYukle(uid);
    } on FirebaseAuthException catch (e) {
      return {'basarili': false, 'hata': _authHataMesaji(e.code)};
    } catch (e) {
      return {'basarili': false, 'hata': 'Hata: $e'};
    }
  }

  // ── Kullanıcı Adı ile Giriş (Şoför / Veli / Personel) ────────
  Future<Map<String, dynamic>> kullaniciAdiIleGiris({
    required String kullaniciAdi,
    required String sifre,
    String? beklenenRol,
  }) async {
    try {
      final sorgu = await _db
          .collection('kullanicilar')
          .where('kullaniciAdi', isEqualTo: kullaniciAdi.trim())
          .limit(1)
          .get();

      if (sorgu.docs.isEmpty) {
        return {'basarili': false, 'hata': 'Kullanici adi bulunamadi'};
      }

      final kulData = sorgu.docs.first.data();
      final eposta  = kulData['email'] as String? ?? '';

      if (eposta.isEmpty) {
        return {
          'basarili': false,
          'hata': 'Hesap yapilandirmasi eksik, yoneticinize basvurun'
        };
      }

      if (beklenenRol != null) {
        final kayitliRol = kulData['rol'] as String? ?? '';
        if (!_rolEslesiyor(kayitliRol, beklenenRol)) {
          return {
            'basarili': false,
            'hata': 'Bu giris tipi ile hesabiniza erisilemez'
          };
        }
      }

      final cred = await _auth.signInWithEmailAndPassword(
          email: eposta, password: sifre);
      final uid = cred.user?.uid;
      if (uid == null) return {'basarili': false, 'hata': 'Giris basarisiz'};

      return await _kullaniciyiYukle(uid);
    } on FirebaseAuthException catch (e) {
      return {'basarili': false, 'hata': _authHataMesaji(e.code)};
    } catch (e) {
      return {'basarili': false, 'hata': 'Hata: $e'};
    }
  }

  // ── Ortak Kullanıcı Yükleme ───────────────────────────────────
  Future<Map<String, dynamic>> _kullaniciyiYukle(String uid) async {
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

    if (_rol != 'superAdmin' && (_firmaId == null || _firmaId!.isEmpty)) {
      await _auth.signOut();
      return {
        'basarili': false,
        'hata': 'Hesabiniz bir firmaya baglanmamis. Yoneticinizle iletisime gecin.'
      };
    }

    try {
      await _db.collection('kullanicilar').doc(uid).update({
        'sonGiris':          FieldValue.serverTimestamp(),
        'toplamGirisSayisi': FieldValue.increment(1),
      });
    } catch (_) {}

    return {'basarili': true, 'rol': _rol, 'firmaId': _firmaId};
  }

  // ── Rol Eşleşme ───────────────────────────────────────────────
  bool _rolEslesiyor(String kayitliRol, String beklenen) {
    if (beklenen == 'sofor') {
      return kayitliRol == 'sofor' || kayitliRol == 'bireyselSofor';
    }
    if (beklenen == 'veli')     return kayitliRol == 'veli';
    if (beklenen == 'personel') {
      return kayitliRol == 'personel' || kayitliRol == 'staff';
    }
    return true;
  }

  // ── Çıkış ────────────────────────────────────────────────────
  Future<void> cikisYap() async {
    _firmaId       = null;
    _rol           = null;
    _aktifProjeId  = null;
    _aktifProjeAdi = null;
    await _auth.signOut();
  }

  // ── Şifre Sıfırla ────────────────────────────────────────────
  Future<Map<String, dynamic>> sifreSifirla(String eposta) async {
    try {
      await _auth.sendPasswordResetEmail(email: eposta);
      return {'basarili': true};
    } catch (e) {
      return {'basarili': false, 'hata': 'Gonderilemedi: $e'};
    }
  }

  // ── Giriş Kontrol (uygulama açılışı) ─────────────────────────
  Future<Map<String, dynamic>> girisKontrol() async {
    final user = _auth.currentUser;
    if (user == null) return {'girisYapilmis': false};

    try {
      final doc = await _db
          .collection('kullanicilar')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 8));

      if (!doc.exists) {
        await _auth.signOut();
        return {'girisYapilmis': false, 'hata': 'Hesap tanimli degil'};
      }

      final data  = doc.data()!;
      final durum = data['durum'] as String? ?? 'beklemede';

      if (durum == 'reddedildi' || durum == 'askida') {
        await _auth.signOut();
        return {'girisYapilmis': false, 'hata': durum};
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
      if (_rol != null) return {'girisYapilmis': true, 'rol': _rol};
      return {'girisYapilmis': false};
    }
  }

  // ── Yardımcı Getterlar ────────────────────────────────────────
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

  Future<String?> firmaldAl() => firmaIdAl();

  Future<String?> firmaIdAl() async {
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

  void cachedFirmaIdSet(String firmaId) => _firmaId = firmaId;

  Future<String?> firmaAdiAl() async {
    final firmaId = await firmaIdAl();
    if (firmaId == null) return null;
    try {
      final doc = await _db.collection('firms').doc(firmaId).get();
      if (!doc.exists) return null;
      return doc.data()?['ad']       as String?
          ?? doc.data()?['adi']      as String?
          ?? doc.data()?['firmaAdi'] as String?;
    } catch (_) { return null; }
  }

  Future<bool> lisansGecerliMi() async {
    final firmaId = await firmaIdAl();
    if (firmaId == null) return true;
    try {
      final doc   = await _db.collection('firms').doc(firmaId).get();
      final bitis = doc.data()?['lisansBitis'] as Timestamp?;
      if (bitis == null) return true;
      return bitis.toDate().isAfter(DateTime.now());
    } catch (_) { return true; }
  }

  void aktifProjeAyarla(String projeId, String projeAdi) {
    _aktifProjeId  = projeId;
    _aktifProjeAdi = projeAdi;
  }

  void projeTemizle() {
    _aktifProjeId  = null;
    _aktifProjeAdi = null;
  }

  // ── Auth Hata Mesajları ───────────────────────────────────────
  String _authHataMesaji(String code) {
    switch (code) {
      case 'user-not-found':     return 'Kullanici bulunamadi';
      case 'wrong-password':     return 'Hatali sifre';
      case 'invalid-email':      return 'Gecersiz e-posta';
      case 'too-many-requests':  return 'Cok fazla deneme, lutfen bekleyin';
      case 'invalid-credential': return 'E-posta veya sifre hatali';
      case 'user-disabled':      return 'Hesabiniz devre disi birakilmis';
      default:                   return 'Giris basarisiz ($code)';
    }
  }
}
