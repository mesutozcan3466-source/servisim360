import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Firma {
  final String id;
  final String ad;
  final String whatsapp;
  final String email;

  Firma({required this.id, required this.ad, required this.whatsapp, required this.email});

  factory Firma.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Firma(id: doc.id, ad: d['ad'] ?? 'Firma', whatsapp: d['whatsapp'] ?? '', email: d['email'] ?? '');
  }
}

class Proje {
  final String id;
  final String ad;
  final String tip;
  final String firmaId;

  Proje({required this.id, required this.ad, required this.tip, required this.firmaId});

  factory Proje.fromFirestore(DocumentSnapshot doc, String firmaId) {
    final d = doc.data() as Map<String, dynamic>;
    return Proje(id: doc.id, ad: d['ad'] ?? 'Proje', tip: d['tip'] ?? 'okul', firmaId: firmaId);
  }

  String get tipIkonu {
    switch (tip) {
      case 'okul': return '🏫';
      case 'kolej': return '🎓';
      case 'anaokulu': return '🧒';
      case 'site': return '🏘️';
      case 'personel': return '👔';
      default: return '📋';
    }
  }
}

class ProjeProvider extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Firma? _aktifFirma;
  Proje? _aktifProje;
  List<Firma> _firmalar = [];
  List<Proje> _projeler = [];
  bool _yukleniyor = false;
  String? _hata;

  Firma? get aktifFirma => _aktifFirma;
  Proje? get aktifProje => _aktifProje;
  List<Firma> get firmalar => _firmalar;
  List<Proje> get projeler => _projeler;
  bool get yukleniyor => _yukleniyor;
  String? get hata => _hata;

  String? get projePath =>
      _aktifFirma != null && _aktifProje != null
          ? 'firmalar/${_aktifFirma!.id}/projeler/${_aktifProje!.id}'
          : null;

  CollectionReference? get ogrencilerRef => projePath != null ? _db.collection('$projePath/ogrenciler') : null;
  CollectionReference? get suruculerRef => projePath != null ? _db.collection('$projePath/suruculer') : null;
  CollectionReference? get servislerRef => projePath != null ? _db.collection('$projePath/servisler') : null;
  CollectionReference? get rotalarRef => projePath != null ? _db.collection('$projePath/rotalar') : null;
  CollectionReference? get yokluklarRef => projePath != null ? _db.collection('$projePath/yokluklar') : null;
  CollectionReference? get duyurularRef => projePath != null ? _db.collection('$projePath/duyurular') : null;
  CollectionReference? get suruculerKonumlarRef => projePath != null ? _db.collection('$projePath/surucu_konumlar') : null;

  Future<void> baslat() async {
    _yukleniyor = true;
    _hata = null;
    notifyListeners();

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _yukleniyor = false;
        notifyListeners();
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      String? kayitliFirmaId = prefs.getString('aktif_firma_id');
      String? kayitliProjeId = prefs.getString('aktif_proje_id');

      final kulDoc = await _db.collection('kullanicilar').doc(user.uid).get();
      String firmaId = '';
      if (kulDoc.exists) {
        final d = kulDoc.data() as Map<String, dynamic>;
        firmaId = d['firmaId'] ?? '';
      }

      final hedefFirmaId = kayitliFirmaId ?? firmaId;
      if (hedefFirmaId.isNotEmpty) {
        final firmaDoc = await _db.collection('firmalar').doc(hedefFirmaId).get();
        if (firmaDoc.exists) {
          _firmalar = [Firma.fromFirestore(firmaDoc)];
          _aktifFirma = _firmalar.first;

          final projeSnap = await _db
              .collection('firmalar')
              .doc(hedefFirmaId)
              .collection('projeler')
              .get();

          _projeler = projeSnap.docs
              .map((d) => Proje.fromFirestore(d, hedefFirmaId))
              .toList();

          if (_projeler.isNotEmpty) {
            if (kayitliProjeId != null) {
              final kayitli = _projeler.where((p) => p.id == kayitliProjeId).firstOrNull;
              _aktifProje = kayitli ?? _projeler.first;
            } else {
              _aktifProje = _projeler.first;
            }
          }
        }
      }
    } catch (e) {
      _hata = 'Hata: $e';
    }

    _yukleniyor = false;
    notifyListeners();
  }

  Future<void> projeleriYukle(String firmaId) async {
    try {
      final snap = await _db
          .collection('firmalar')
          .doc(firmaId)
          .collection('projeler')
          .get();
      _projeler = snap.docs.map((d) => Proje.fromFirestore(d, firmaId)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('projeleriYukle hata: $e');
    }
  }

  Future<void> firmasec(Firma firma) async {
    _aktifFirma = firma;
    _aktifProje = null;
    notifyListeners();
    await projeleriYukle(firma.id);
    _kaydet();
  }

  Future<void> projesec(Proje proje) async {
    _aktifProje = proje;
    notifyListeners();
    _kaydet();
  }

  void _kaydet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_aktifFirma != null) await prefs.setString('aktif_firma_id', _aktifFirma!.id);
      if (_aktifProje != null) await prefs.setString('aktif_proje_id', _aktifProje!.id);
    } catch (_) {}
  }

  Future<void> firmaVeProjeOlustur({
    required String firmaAd,
    required String projeAd,
    required String projeTip,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Firma oluştur
      final firmaRef = await _db.collection('firmalar').add({
        'ad': firmaAd,
        'whatsapp': '',
        'email': user.email ?? '',
        'olusturmaTarihi': FieldValue.serverTimestamp(),
        'adminUid': user.uid,
      });

      // Kullanıcıya firmaId yaz
      await _db.collection('kullanicilar').doc(user.uid).update({
        'firmaId': firmaRef.id,
      });

      final firma = Firma(id: firmaRef.id, ad: firmaAd, whatsapp: '', email: user.email ?? '');
      _firmalar = [firma];
      _aktifFirma = firma;

      // Proje oluştur
      final projeRef = await _db
          .collection('firmalar')
          .doc(firmaRef.id)
          .collection('projeler')
          .add({
        'ad': projeAd,
        'tip': projeTip,
        'firmaId': firmaRef.id,
        'aktif': true,
        'olusturmaTarihi': FieldValue.serverTimestamp(),
      });

      final proje = Proje(id: projeRef.id, ad: projeAd, tip: projeTip, firmaId: firmaRef.id);
      _projeler = [proje];
      _aktifProje = proje;

      _kaydet();
      notifyListeners();
    } catch (e) {
      _hata = 'Firma oluşturulamadı: $e';
      notifyListeners();
    }
  }

  Future<String?> projeOlustur({required String ad, required String tip, String? aciklama}) async {
    if (_aktifFirma == null) return null;
    try {
      final ref = await _db
          .collection('firmalar')
          .doc(_aktifFirma!.id)
          .collection('projeler')
          .add({
        'ad': ad,
        'tip': tip,
        'firmaId': _aktifFirma!.id,
        'aktif': true,
        if (aciklama != null) 'aciklama': aciklama,
        'olusturmaTarihi': FieldValue.serverTimestamp(),
      });
      await projeleriYukle(_aktifFirma!.id);
      if (_projeler.isNotEmpty && _aktifProje == null) {
        _aktifProje = _projeler.firstWhere((p) => p.id == ref.id, orElse: () => _projeler.first);
      }
      notifyListeners();
      return ref.id;
    } catch (e) {
      _hata = 'Proje oluşturulamadı: $e';
      notifyListeners();
      return null;
    }
  }

  void temizle() {
    _aktifFirma = null;
    _aktifProje = null;
    _firmalar = [];
    _projeler = [];
    _hata = null;
    notifyListeners();
  }
}