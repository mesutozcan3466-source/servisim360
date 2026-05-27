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

  bool get onaylimi     => durum == 'onayli' || durum == 'onaylı';
  bool get superAdminmi => rol == Rol.superAdmin || rol == 'superadmin';
  bool get firmaAdminmi => rol == Rol.firmaAdmin;
  bool get soformu      => rol == Rol.sofor;
  bool get velimi       => rol == Rol.veli;

  factory AppKullanici.fromFirestore(String uid, Map<String, dynamic> data) {
    return AppKullanici(
      uid:       uid,
      email:     data['email']     ?? '',
      rol:       data['rol']       ?? Rol.veli,
      durum:     data['durum']     ?? 'beklemede',
      firmId:    data['firmId'],
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

  static const String _yeniKoleksiyon = 'users';
  static const String _eskiKoleksiyon = 'kullanicilar';

  bool _durumOnayli(String durum) {
    return durum == 'onayli' || durum == 'onaylı' || durum == 'aktif';
  }

  Future<Map<String, dynamic>?> _kullaniciVerisiCek(String uid) async {
    final yeni = await _db.collection(_yeniKoleksiyon).doc(uid).get();
    if (yeni.exists && yeni.data() != null) return yeni.data();

    final eski = await _db.collection(_eskiKoleksiyon).doc(uid).get();
    if (eski.exists && eski.data() != null) return eski.data();

    return null;
  }

  Future<String> _koleksiyonBul(String uid) async {
    final yeni = await _db.collection(_yeniKoleksiyon).doc(uid).get();
    return yeni.exists ? _yeniKoleksiyon : _eskiKoleksiyon;
  }

  Future<GirisSonucu> emailIleGiris({
    required String email,
    required String sifre,
  }) async {
    try {
      final kred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: sifre.trim(),
      );

      final uid  = kred.user!.uid;
      final data = await _kullaniciVerisiCek(uid);

      if (data == null) {
        await _auth.signOut();
        return const GirisSonucu(
          tip: GirisSonucTip.kullaniciBulunamadi,
          mesaj: 'Kullanıcı kaydı bulunamadı.',
        );
      }

      return _durumKontrol(uid, data);
    } on FirebaseAuthException catch (e) {
      return GirisSonucu(
        tip: GirisSonucTip.hatali,
        mesaj: _firebaseHataCevir(e.code),
      );
    } catch (e) {
      return GirisSonucu(
        tip: GirisSonucTip.hatali,
        mesaj: 'Beklenmeyen hata: $e',
      );
    }
  }

  Future<GirisSonucu> projeKoduIleGiris({
    required String projeKodu,
    required String kullaniciAdi,
    required String sifre,
    required String beklenenRol,
  }) async {
    try {
      final projeSnap = await _db
          .collection('projects')
          .where('projeKodu', isEqualTo: projeKodu.trim().toUpperCase())
          .limit(1)
          .get();

      if (projeSnap.docs.isEmpty) {
        return const GirisSonucu(
          tip: GirisSonucTip.hatali,
          mesaj: 'Geçersiz proje kodu.',
        );
      }

      final projeId = projeSnap.docs.first.id;

      QueryDocumentSnapshot? kulDoc;
      for (final koleksiyon in [_yeniKoleksiyon, _eskiKoleksiyon]) {
        final snap = await _db
            .collection(koleksiyon)
            .where('kullaniciAdi', isEqualTo: kullaniciAdi.trim())
            .where('projectId', isEqualTo: projeId)
            .where('rol', isEqualTo: beklenenRol)
            .limit(1)
            .get();

        if (snap.docs.isNotEmpty) {
          kulDoc = snap.docs.first;
          break;
        }
      }

      if (kulDoc == null) {
        return const GirisSonucu(
          tip: GirisSonucTip.kullaniciBulunamadi,
          mesaj: 'Kullanıcı adı veya şifre hatalı.',
        );
      }

      final data  = kulDoc.data() as Map<String, dynamic>;
      final email = data['email'] as String?;

      if (email == null) {
        return const GirisSonucu(
          tip: GirisSonucTip.hatali,
          mesaj: 'Kullanıcı e-posta bilgisi eksik.',
        );
      }

      await _auth.signInWithEmailAndPassword(
        email: email,
        password: sifre.trim(),
      );

      return _durumKontrol(kulDoc.id, data);
    } on FirebaseAuthException catch (e) {
      return GirisSonucu(
        tip: GirisSonucTip.hatali,
        mesaj: _firebaseHataCevir(e.code),
      );
    } catch (e) {
      return GirisSonucu(
        tip: GirisSonucTip.hatali,
        mesaj: 'Beklenmeyen hata: $e',
      );
    }
  }

  GirisSonucu _durumKontrol(String uid, Map<String, dynamic> data) {
    final durum = data['durum'] as String? ?? 'beklemede';

    if (durum == 'askiya_alindi' || durum == 'askida') {
      return const GirisSonucu(
        tip: GirisSonucTip.hesapAskida,
        mesaj: 'Hesabınız askıya alınmıştır. Yöneticinizle iletişime geçin.',
      );
    }
    if (durum == 'beklemede') {
      return const GirisSonucu(
        tip: GirisSonucTip.onayBekliyor,
        mesaj: 'Hesabınız henüz onaylanmamış.',
      );
    }
    if (durum == 'kapatildi' || durum == 'reddedildi') {
      return const GirisSonucu(
        tip: GirisSonucTip.hesapKapatildi,
        mesaj: 'Bu hesap kapatılmıştır.',
      );
    }

    // onayli, onaylı, aktif — hepsi geçer
    if (!_durumOnayli(durum)) {
      return GirisSonucu(
        tip: GirisSonucTip.hatali,
        mesaj: 'Hesap durumu geçersiz: $durum',
      );
    }

    final kullanici = AppKullanici.fromFirestore(uid, data);
    _aktifKullanici = kullanici;
    _girisIstatistikGuncelle(uid);

    return GirisSonucu(
      tip: GirisSonucTip.basarili,
      kullanici: kullanici,
    );
  }

  Future<AppKullanici?> sessionKontrol() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;

    try {
      final data = await _kullaniciVerisiCek(firebaseUser.uid);
      if (data == null) return null;

      final durum = data['durum'] as String? ?? 'beklemede';
      if (!_durumOnayli(durum)) {
        await cikisYap();
        return null;
      }

      _aktifKullanici = AppKullanici.fromFirestore(firebaseUser.uid, data);
      return _aktifKullanici;
    } catch (e) {
      debugPrint('Session kontrol hatası: $e');
      return null;
    }
  }

  String rolRotasi(AppKullanici kullanici) {
    final rol = kullanici.rol;
    if (rol == Rol.superAdmin || rol == 'superadmin') return '/super_admin';
    if (rol == Rol.firmaAdmin) return '/firma_admin';
    if (rol == Rol.sofor)      return '/sofor_panel';
    if (rol == Rol.veli)       return '/veli_panel';
    return '/login';
  }

  Future<void> sifreSifirla(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> cihazBilgisiGuncelle(Map<String, dynamic> cihaz) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final koleksiyon = await _koleksiyonBul(user.uid);
      await _db.collection(koleksiyon).doc(user.uid).update({
        'cihazBilgisi': cihaz,
      });
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
      case 'user-not-found':         return 'Bu e-posta ile kayıtlı kullanıcı bulunamadı.';
      case 'wrong-password':         return 'Şifre hatalı.';
      case 'invalid-email':          return 'Geçersiz e-posta adresi.';
      case 'user-disabled':          return 'Hesabınız devre dışı bırakılmıştır.';
      case 'too-many-requests':      return 'Çok fazla deneme yapıldı. Lütfen bekleyin.';
      case 'network-request-failed': return 'İnternet bağlantısı yok.';
      case 'invalid-credential':     return 'E-posta veya şifre hatalı.';
      default:                       return 'Giriş başarısız. ($kod)';
    }
  }
}