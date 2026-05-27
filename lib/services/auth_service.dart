import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class Rol {
  static const String superAdmin = 'superAdmin';
  static const String firmaAdmin = 'firmaAdmin';
  static const String sofor      = 'sofor';
  static const String veli       = 'veli';
}

class AppKullanici {
  final String  uid;
  final String  email;
  final String  rol;
  final String  durum;
  final String? firmId;
  final String? projectId;
  final String? vehicleId;
  final String? studentId;
  final bool    isActive;

  const AppKullanici({
    required this.uid,
    required this.email,
    required this.rol,
    required this.durum,
    this.firmId,
    this.projectId,
    this.vehicleId,
    this.studentId,
    this.isActive = true,
  });

  bool get onaylimi     => durum == 'onayli' || durum == 'onaylı' || durum == 'aktif';
  bool get superAdminmi => rol == Rol.superAdmin || rol == 'superadmin';
  bool get firmaAdminmi => rol == Rol.firmaAdmin || rol == 'admin' || rol == 'kolejAdmin';
  bool get soformu      => rol == Rol.sofor;
  bool get velimi       => rol == Rol.veli;

  // Admin rolleri onay beklemiyor
  bool get adminRolMu   => superAdminmi || firmaAdminmi ||
      rol == 'admin' || rol == 'firmaAdmin' || rol == 'kolejAdmin';

  factory AppKullanici.fromFirestore(String uid, Map<String, dynamic> data) {
    return AppKullanici(
      uid:       uid,
      email:     data['email']     ?? '',
      rol:       data['rol']       ?? Rol.veli,
      durum:     data['durum']     ?? 'beklemede',
      firmId:    data['firmaId']   ?? data['firmId'],
      projectId: data['projectId'],
      vehicleId: data['vehicleId'],
      studentId: data['studentId'],
      isActive:  data['isActive']  ?? true,
    );
  }
}

enum GirisSonucTip {
  basarili,
  kullaniciBulunamadi,
  hesapAskida,
  onayBekliyor,
  hesapKapatildi,
  hatali,
}

class GirisSonucu {
  final GirisSonucTip tip;
  final AppKullanici? kullanici;
  final String?       mesaj;

  const GirisSonucu({
    required this.tip,
    this.kullanici,
    this.mesaj,
  });

  bool get basarili => tip == GirisSonucTip.basarili;
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth      _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db   = FirebaseFirestore.instance;

  AppKullanici? _aktifKullanici;
  AppKullanici? get aktifKullanici => _aktifKullanici;

  static const String _anaKoleksiyon  = 'kullanicilar';
  static const String _yeniKoleksiyon = 'users';

  Future<Map<String, dynamic>?> _kullaniciVerisiCek(String uid) async {
    try {
      final ana = await _db.collection(_anaKoleksiyon).doc(uid).get();
      if (ana.exists && ana.data() != null) return ana.data();
      final yeni = await _db.collection(_yeniKoleksiyon).doc(uid).get();
      if (yeni.exists && yeni.data() != null) return yeni.data();
      return null;
    } catch (e) {
      debugPrint('Kullanici verisi cekme hatasi: $e');
      return null;
    }
  }

  Future<String> _koleksiyonBul(String uid) async {
    try {
      final ana = await _db.collection(_anaKoleksiyon).doc(uid).get();
      return ana.exists ? _anaKoleksiyon : _yeniKoleksiyon;
    } catch (e) {
      return _anaKoleksiyon;
    }
  }

  bool _adminRolMu(String? rol) {
    return rol == 'admin' || rol == 'firmaAdmin' || rol == 'kolejAdmin' ||
        rol == 'superAdmin' || rol == 'superadmin';
  }

  Future<GirisSonucu> emailIleGiris({
    required String email,
    required String sifre,
  }) async {
    try {
      final kred = await _auth.signInWithEmailAndPassword(
        email: email.trim(), password: sifre.trim(),
      );
      final uid  = kred.user!.uid;
      final data = await _kullaniciVerisiCek(uid);
      if (data == null) {
        await _auth.signOut();
        return const GirisSonucu(
          tip: GirisSonucTip.kullaniciBulunamadi,
          mesaj: 'Kullanici kaydi bulunamadi.',
        );
      }
      return _durumKontrol(uid, data);
    } on FirebaseAuthException catch (e) {
      return GirisSonucu(tip: GirisSonucTip.hatali, mesaj: _firebaseHataCevir(e.code));
    } catch (e) {
      return GirisSonucu(tip: GirisSonucTip.hatali, mesaj: 'Beklenmeyen hata: $e');
    }
  }

  Future<GirisSonucu> projeKoduIleGiris({
    required String projeKodu,
    required String kullaniciAdi,
    required String sifre,
    required String beklenenRol,
  }) async {
    try {
      final projeSnap = await _db.collection('projects')
          .where('projeKodu', isEqualTo: projeKodu.trim().toUpperCase())
          .limit(1).get();
      if (projeSnap.docs.isEmpty) {
        return const GirisSonucu(tip: GirisSonucTip.hatali, mesaj: 'Gecersiz proje kodu.');
      }
      final projeId = projeSnap.docs.first.id;
      QueryDocumentSnapshot? kulDoc;
      for (final koleksiyon in [_anaKoleksiyon, _yeniKoleksiyon]) {
        final snap = await _db.collection(koleksiyon)
            .where('kullaniciAdi', isEqualTo: kullaniciAdi.trim())
            .where('projectId', isEqualTo: projeId)
            .where('rol', isEqualTo: beklenenRol)
            .limit(1).get();
        if (snap.docs.isNotEmpty) { kulDoc = snap.docs.first; break; }
      }
      if (kulDoc == null) {
        return const GirisSonucu(tip: GirisSonucTip.kullaniciBulunamadi, mesaj: 'Kullanici adi veya sifre hatali.');
      }
      final data  = kulDoc.data() as Map<String, dynamic>;
      final email = data['email'] as String?;
      if (email == null) {
        return const GirisSonucu(tip: GirisSonucTip.hatali, mesaj: 'Kullanici e-posta bilgisi eksik.');
      }
      await _auth.signInWithEmailAndPassword(email: email, password: sifre.trim());
      return _durumKontrol(kulDoc.id, data);
    } on FirebaseAuthException catch (e) {
      return GirisSonucu(tip: GirisSonucTip.hatali, mesaj: _firebaseHataCevir(e.code));
    } catch (e) {
      return GirisSonucu(tip: GirisSonucTip.hatali, mesaj: 'Beklenmeyen hata: $e');
    }
  }

  GirisSonucu _durumKontrol(String uid, Map<String, dynamic> data) {
    final durum = data['durum'] ?? 'beklemede';
    final rol   = data['rol']   ?? '';

    // Admin rolleri durum kontrolü olmadan geçer
    if (_adminRolMu(rol)) {
      final kullanici = AppKullanici.fromFirestore(uid, data);
      _aktifKullanici = kullanici;
      _girisIstatistikGuncelle(uid);
      return GirisSonucu(tip: GirisSonucTip.basarili, kullanici: kullanici);
    }

    if (durum == 'askiya_alindi') {
      return const GirisSonucu(tip: GirisSonucTip.hesapAskida, mesaj: 'Hesabiniz askiya alinmistir.');
    }
    if (durum == 'beklemede') {
      return const GirisSonucu(tip: GirisSonucTip.onayBekliyor, mesaj: 'Hesabiniz henuz onaylanmamis.');
    }
    if (durum == 'kapatildi') {
      return const GirisSonucu(tip: GirisSonucTip.hesapKapatildi, mesaj: 'Bu hesap kapatilmistir.');
    }

    final kullanici = AppKullanici.fromFirestore(uid, data);
    _aktifKullanici = kullanici;
    _girisIstatistikGuncelle(uid);
    return GirisSonucu(tip: GirisSonucTip.basarili, kullanici: kullanici);
  }

  // Session kontrolü — admin için durum kontrolü yok
  Future<AppKullanici?> sessionKontrol() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;

    try {
      final data = await _kullaniciVerisiCek(firebaseUser.uid);
      if (data == null) return null;

      final rol   = data['rol']   as String? ?? '';
      final durum = data['durum'] as String? ?? 'beklemede';

      // Admin rolleri session'da da onay beklemez
      if (!_adminRolMu(rol)) {
        if (durum != 'onayli' && durum != 'onaylı' && durum != 'aktif') {
          await cikisYap();
          return null;
        }
      }

      _aktifKullanici = AppKullanici.fromFirestore(firebaseUser.uid, data);
      return _aktifKullanici;
    } catch (e) {
      debugPrint('Session kontrol hatasi: $e');
      return null;
    }
  }

  String rolRotasi(AppKullanici kullanici) {
    switch (kullanici.rol) {
      case Rol.superAdmin:
      case 'superadmin':   return '/super_admin';
      case Rol.firmaAdmin:
      case 'admin':
      case 'kolejAdmin':   return '/dashboard';
      case Rol.sofor:      return '/sofor_panel';
      case Rol.veli:       return '/veli_panel';
      default:             return '/login';
    }
  }

  Future<void> sifreSifirla(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> cihazBilgisiGuncelle(Map<String, dynamic> cihaz) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final koleksiyon = await _koleksiyonBul(user.uid);
      await _db.collection(koleksiyon).doc(user.uid).update({'cihazBilgisi': cihaz});
    } catch (_) {}
  }

  Future<void> cikisYap() async {
    _aktifKullanici = null;
    await _auth.signOut();
  }

  Future<void> _girisIstatistikGuncelle(String uid) async {
    try {
      final koleksiyon = await _koleksiyonBul(uid);
      await _db.collection(koleksiyon).doc(uid).update({
        'sonGiris':          FieldValue.serverTimestamp(),
        'toplamGirisSayisi': FieldValue.increment(1),
      });
    } catch (_) {}
  }

  String _firebaseHataCevir(String kod) {
    switch (kod) {
      case 'user-not-found':         return 'Bu e-posta ile kayitli kullanici bulunamadi.';
      case 'wrong-password':         return 'Sifre hatali.';
      case 'invalid-email':          return 'Gecersiz e-posta adresi.';
      case 'user-disabled':          return 'Hesabiniz devre disi birakilmistir.';
      case 'too-many-requests':      return 'Cok fazla deneme yapildi. Lutfen bekleyin.';
      case 'network-request-failed': return 'Internet baglantisi yok.';
      case 'invalid-credential':     return 'E-posta veya sifre hatali.';
      default:                       return 'Giris basarisiz. ($kod)';
    }
  }
}
