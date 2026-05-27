import 'package:cloud_firestore/cloud_firestore.dart';

/// Hazır mesaj ve konuşma servisi
class HazirMesajService {
  static final _db = FirebaseFirestore.instance;

  // ── Mesajları Stream Olarak Dinle ───────────────────────────────────────────
  static Stream<QuerySnapshot> mesajlariDinle({
    required String firmaId,
    required String tip, // 'veli' | 'sofor'
  }) {
    return _db
        .collection('hazir_mesajlar')
        .where('firmaId', isEqualTo: firmaId)
        .where('tip', isEqualTo: tip)
        .orderBy('sira')
        .snapshots();
  }

  // ── Mesajları Bir Kez Getir ─────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> mesajlariGetir({
    required String firmaId,
    required String tip,
  }) async {
    try {
      final snap = await _db
          .collection('hazir_mesajlar')
          .where('firmaId', isEqualTo: firmaId)
          .where('tip', isEqualTo: tip)
          .orderBy('sira')
          .get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Mesaj Ekle ──────────────────────────────────────────────────────────────
  static Future<void> mesajEkle({
    required String firmaId,
    required String metin,
    required String tip,
    String ikon = 'message',
  }) async {
    // Mevcut en yüksek sırayı bul
    final snap = await _db
        .collection('hazir_mesajlar')
        .where('firmaId', isEqualTo: firmaId)
        .where('tip', isEqualTo: tip)
        .orderBy('sira', descending: true)
        .limit(1)
        .get();

    final sonSira = snap.docs.isEmpty
        ? 0
        : (snap.docs.first.data()['sira'] as int? ?? 0);

    await _db.collection('hazir_mesajlar').add({
      'firmaId':   firmaId,
      'metin':     metin,
      'tip':       tip,
      'ikon':      ikon,
      'sira':      sonSira + 1,
      'olusturma': FieldValue.serverTimestamp(),
    });
  }

  // ── Mesaj Güncelle ──────────────────────────────────────────────────────────
  static Future<void> mesajGuncelle(
      String docId, Map<String, dynamic> data) async {
    await _db.collection('hazir_mesajlar').doc(docId).update(data);
  }

  // ── Mesaj Sil ───────────────────────────────────────────────────────────────
  static Future<void> mesajSil(String docId) async {
    await _db.collection('hazir_mesajlar').doc(docId).delete();
  }

  // ── Mesaj Gönder (konuşma kaydı) ────────────────────────────────────────────
  static Future<void> mesajGonder({
    required String firmaId,
    required String gonderen,    // 'veli' | 'sofor'
    required String gonderenId,
    required String gonderenAd,
    required String aliciId,
    required String mesajMetni,
    String? surucuId,
    String? veliId,
  }) async {
    await _db.collection('konusmalar').add({
      'firmaId':    firmaId,
      'gonderen':   gonderen,
      'gonderenId': gonderenId,
      'gonderenAd': gonderenAd,
      'aliciId':    aliciId,
      'metin':      mesajMetni,
      'surucuId':   surucuId,
      'veliId':     veliId,
      'tarih':      FieldValue.serverTimestamp(),
      'okundu':     false,
    });
  }

  // ── Konuşmayı Dinle ─────────────────────────────────────────────────────────
  static Stream<QuerySnapshot> konusmaDinle({
    required String surucuId,
    required String veliId,
  }) {
    return _db
        .collection('konusmalar')
        .where('surucuId', isEqualTo: surucuId)
        .where('veliId',   isEqualTo: veliId)
        .orderBy('tarih',  descending: true)
        .limit(50)
        .snapshots();
  }

  // ── Okunmamış Mesaj Sayısı ──────────────────────────────────────────────────
  static Future<int> okunmamisSayisi({
    required String aliciId,
  }) async {
    try {
      final snap = await _db
          .collection('konusmalar')
          .where('aliciId', isEqualTo: aliciId)
          .where('okundu',  isEqualTo: false)
          .count()
          .get();
      return snap.count ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
