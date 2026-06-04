import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Servisim360 — Multi-tenant firma izolasyon servisi.
/// Tüm Firestore sorguları bu servis üzerinden yapılmalıdır.
/// Kullanım:
///   final firma = FirmaIzolasyonService();
///   await firma.baslat();           // login sonrası çağır
///   firma.temizle();                // signOut öncesi çağır
///   firma.kullanicilarSorgu()       // izole koleksiyon referansı
class FirmaIzolasyonService extends ChangeNotifier {
  // ── Singleton ────────────────────────────────────────────────────────────
  static final FirmaIzolasyonService _instance =
  FirmaIzolasyonService._internal();
  factory FirmaIzolasyonService() => _instance;
  FirmaIzolasyonService._internal();

  // ── State ─────────────────────────────────────────────────────────────────
  String? _firmaId;
  String? _firmaAdi;
  String? _rol;
  bool _hazir = false;

  String? get firmaId => _firmaId;
  String? get firmaAdi => _firmaAdi;
  String? get rol => _rol;
  bool get hazir => _hazir;
  bool get superAdmin => _rol == 'superadmin';

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Başlat ────────────────────────────────────────────────────────────────
  /// Auth login sonrası veya oturum devam kontrolünde çağır.
  Future<void> baslat() async {
    final user = _auth.currentUser;
    if (user == null) {
      temizle();
      return;
    }

    try {
      // Önce kullanicilar koleksiyonuna bak
      final kulDoc =
      await _db.collection('kullanicilar').doc(user.uid).get();

      if (kulDoc.exists) {
        final d = kulDoc.data()!;
        _rol = d['rol'] as String?;

        if (_rol == 'superadmin') {
          _firmaId = null; // superadmin tüm firmalara erişir
          _firmaAdi = 'Süper Admin';
          _hazir = true;
          notifyListeners();
          return;
        }

        // Firma bağlantısını bul
        _firmaId = d['firmaId'] as String?;

        if (_firmaId != null) {
          final firmaDoc =
          await _db.collection('firms').doc(_firmaId).get();
          if (firmaDoc.exists) {
            final fd = firmaDoc.data()!;
            _firmaAdi = fd['firmaAdi'] ?? fd['name'] ?? 'Firma';
          }
        }

        _hazir = true;
        notifyListeners();
        return;
      }

      // kullanicilar'da yoksa firms/projects/users yapısına bak
      final firmaSnap = await _db
          .collectionGroup('users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (firmaSnap.docs.isNotEmpty) {
        final d = firmaSnap.docs.first.data();
        _rol = d['rol'] as String?;
        // firms/{firmaId}/projects/{projectId}/users/{uid}
        final ref = firmaSnap.docs.first.reference;
        // firms seviyesine çık
        _firmaId = ref.parent.parent?.parent?.parent?.id;
        if (_firmaId != null) {
          final firmaDoc =
          await _db.collection('firms').doc(_firmaId).get();
          if (firmaDoc.exists) {
            final fd = firmaDoc.data()!;
            _firmaAdi = fd['firmaAdi'] ?? fd['name'] ?? 'Firma';
          }
        }
      }

      _hazir = true;
      notifyListeners();
    } catch (e) {
      debugPrint('FirmaIzolasyonService.baslat hatası: $e');
      _hazir = true;
      notifyListeners();
    }
  }

  /// signOut öncesi çağır — state temizle.
  void temizle() {
    _firmaId = null;
    _firmaAdi = null;
    _rol = null;
    _hazir = false;
    notifyListeners();
  }

  // ── İzole Koleksiyon Referansları ─────────────────────────────────────────

  /// Öğrenciler — firma bazlı izole
  CollectionReference<Map<String, dynamic>> get ogrencilerRef {
    _kontrolEt();
    if (superAdmin) return _db.collection('students');
    return _db
        .collection('firms')
        .doc(_firmaId)
        .collection('students');
  }

  /// Şoförler — firma bazlı izole
  CollectionReference<Map<String, dynamic>> get soforlerRef {
    _kontrolEt();
    if (superAdmin) return _db.collection('soforler');
    return _db
        .collection('firms')
        .doc(_firmaId)
        .collection('soforler');
  }

  /// Araçlar — firma bazlı izole
  CollectionReference<Map<String, dynamic>> get araclarRef {
    _kontrolEt();
    if (superAdmin) return _db.collection('vehicles');
    return _db
        .collection('firms')
        .doc(_firmaId)
        .collection('vehicles');
  }

  /// Rotalar — firma bazlı izole
  CollectionReference<Map<String, dynamic>> get rotalarRef {
    _kontrolEt();
    if (superAdmin) return _db.collection('rotalar');
    return _db
        .collection('firms')
        .doc(_firmaId)
        .collection('rotalar');
  }

  /// Kullanıcılar — firma bazlı izole
  CollectionReference<Map<String, dynamic>> get kullanicilarRef {
    _kontrolEt();
    if (superAdmin) return _db.collection('kullanicilar');
    return _db
        .collection('firms')
        .doc(_firmaId)
        .collection('kullanicilar');
  }

  /// Devamsızlık istekleri — firma bazlı izole
  CollectionReference<Map<String, dynamic>> get devamsizlikRef {
    _kontrolEt();
    if (superAdmin) return _db.collection('absence_requests');
    return _db
        .collection('firms')
        .doc(_firmaId)
        .collection('absence_requests');
  }

  /// Duraklar — firma bazlı izole
  CollectionReference<Map<String, dynamic>> get duraklarRef {
    _kontrolEt();
    if (superAdmin) return _db.collection('duraklar');
    return _db
        .collection('firms')
        .doc(_firmaId)
        .collection('duraklar');
  }

  // ── Sorgu Yardımcıları ────────────────────────────────────────────────────

  /// Firma bazlı filtrelenmiş sorgu döner (flat koleksiyonlar için)
  Query<Map<String, dynamic>> firmaFiltreli(String koleksiyon) {
    if (superAdmin) return _db.collection(koleksiyon);
    return _db
        .collection(koleksiyon)
        .where('firmaId', isEqualTo: _firmaId);
  }

  /// Belge ekle — firmaId otomatik eklenir
  Future<DocumentReference> ekle(
      CollectionReference<Map<String, dynamic>> ref,
      Map<String, dynamic> veri) {
    if (!superAdmin && _firmaId != null) {
      veri['firmaId'] = _firmaId;
    }
    veri['olusturmaTarihi'] = FieldValue.serverTimestamp();
    return ref.add(veri);
  }

  /// Belge güncelle — firmaId korunur
  Future<void> guncelle(
      DocumentReference ref, Map<String, dynamic> veri) {
    veri['guncellemeTarihi'] = FieldValue.serverTimestamp();
    return ref.update(veri);
  }

  // ── Destek Modu ───────────────────────────────────────────────────────────
  String? _destekFirmaId;
  bool get destekModuAktif => _destekFirmaId != null;

  /// Süper admin başka firma adına işlem yapar
  Future<void> destekModuBaslat(String firmaId) async {
    if (!superAdmin) return;
    _destekFirmaId = firmaId;

    final firmaDoc = await _db.collection('firms').doc(firmaId).get();
    if (firmaDoc.exists) {
      final fd = firmaDoc.data()!;
      _firmaAdi = fd['firmaAdi'] ?? fd['name'] ?? 'Firma';
    }

    // İşlem kaydı
    await _db.collection('islem_kayitlari').add({
      'tip': 'destek_modu_baslat',
      'firmaId': firmaId,
      'yapan': _auth.currentUser?.email ?? '',
      'tarih': FieldValue.serverTimestamp(),
    });

    notifyListeners();
  }

  void destekModuBitir() {
    _destekFirmaId = null;
    _firmaAdi = 'Süper Admin';
    notifyListeners();
  }

  // ── Yardımcılar ───────────────────────────────────────────────────────────
  void _kontrolEt() {
    if (!_hazir) {
      throw StateError(
          'FirmaIzolasyonService henüz başlatılmadı. önce baslat() çağır.');
    }
  }

  /// Aktif firma ID'si (destek modunda hedef firma, normal modda kendi firması)
  String? get aktifFirmaId => superAdmin ? _destekFirmaId : _firmaId;

  @override
  String toString() =>
      'FirmaIzolasyonService(firmaId: $_firmaId, rol: $_rol, hazir: $_hazir)';
}
