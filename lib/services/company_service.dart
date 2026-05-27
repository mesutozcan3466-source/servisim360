import 'package:cloud_firestore/cloud_firestore.dart';

// ─── Model ─────────────────────────────────────────────────────
class CompanyModel {
  final String id;
  final String name;
  final String code;
  final bool aktif;

  const CompanyModel({
    required this.id,
    required this.name,
    required this.code,
    required this.aktif,
  });

  factory CompanyModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CompanyModel(
      id: doc.id,
      name: d['firmaAd'] ?? d['name'] ?? '',
      code: d['firmaKodu'] ?? d['code'] ?? '',
      aktif: d['aktif'] ?? true,
    );
  }
}

// ─── Servis ────────────────────────────────────────────────────
class CompanyService {
  final _db = FirebaseFirestore.instance;

  /// Firma koduna göre aktif firma bul
  Future<CompanyModel?> findByCode(String kod) async {
    final kodUpper = kod.toUpperCase().trim();

    var snap = await _db
        .collection('firmalar')
        .where('firmaKodu', isEqualTo: kodUpper)
        .where('aktif', isEqualTo: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      snap = await _db
          .collection('firmalar')
          .where('firmaKodu', isEqualTo: kod.trim())
          .where('aktif', isEqualTo: true)
          .limit(1)
          .get();
    }

    if (snap.docs.isEmpty) return null;
    return CompanyModel.fromDoc(snap.docs.first);
  }

  /// Tüm aktif firmaları listele
  Future<List<CompanyModel>> aktifFirmalar() async {
    final snap = await _db
        .collection('firmalar')
        .where('aktif', isEqualTo: true)
        .orderBy('firmaAd')
        .get();
    return snap.docs.map(CompanyModel.fromDoc).toList();
  }

  /// Yeni firma oluştur
  Future<String> firmaOlustur({
    required String firmaAd,
    required String firmaKodu,
  }) async {
    final ref = await _db.collection('firmalar').add({
      'firmaAd': firmaAd,
      'firmaKodu': firmaKodu.toUpperCase(),
      'aktif': true,
      'olusturmaTarihi': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }
}
