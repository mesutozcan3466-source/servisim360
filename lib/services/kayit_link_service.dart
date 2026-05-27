import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';

/// Veli kayıt linki oluşturma ve gönderme servisi
class KayitLinkService {
  static final _db = FirebaseFirestore.instance;

  // ── Link Oluştur ─────────────────────────────────────────────────────────────
  /// Yeni kayıt linki oluşturur, Firestore'a kaydeder ve URL döner
  static Future<String> linkOlustur({
    required String firmaId,
    required String projeId,
    required String projeAdi,
    String ozelMesaj = '',
    int gecerlilikGun = 30,
  }) async {
    final kod    = _rastgeleKod();
    final bitis  = DateTime.now().add(Duration(days: gecerlilikGun));

    final ref = await _db.collection('kayit_linkleri').add({
      'firmaId':          firmaId,
      'projeId':          projeId,
      'projeAdi':         projeAdi,
      'kod':              kod,
      'ozelMesaj':        ozelMesaj,
      'gecerlilikBitis':  Timestamp.fromDate(bitis),
      'kullanim':         0,
      'aktif':            true,
      'olusturma':        FieldValue.serverTimestamp(),
    });

    return 'https://servis360.app/kayit?link=${ref.id}&kod=$kod';
  }

  // ── Firma Linklerini Stream Olarak Dinle ──────────────────────────────────────
  static Stream<QuerySnapshot> firmaLinkleri(String firmaId) {
    return _db
        .collection('kayit_linkleri')
        .where('firmaId', isEqualTo: firmaId)
        .where('aktif',   isEqualTo: true)
        .orderBy('olusturma', descending: true)
        .snapshots();
  }

  // ── WhatsApp ile Tek Kişiye Gönder ────────────────────────────────────────────
  static Future<void> whatsappGonder({
    required String telefon,
    required String link,
    required String projeAdi,
    String ozelMesaj = '',
  }) async {
    final mesajMetni = ozelMesaj.isNotEmpty
        ? ozelMesaj
        : '$projeAdi servis kayıt linki 🚌';

    final mesaj = Uri.encodeComponent(
        '🚌 *$projeAdi*\n\n$mesajMetni\n\n📎 Kayıt linki:\n$link\n\nServisim360');

    final numara = _temizle(telefon);
    final url    = Uri.parse('https://wa.me/$numara?text=$mesaj');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  // ── WhatsApp ile Toplu Gönder ──────────────────────────────────────────────────
  static Future<void> topluWhatsappGonder({
    required List<String> telefonlar,
    required String link,
    required String projeAdi,
    String ozelMesaj = '',
  }) async {
    for (final tel in telefonlar) {
      await whatsappGonder(
        telefon:   tel,
        link:      link,
        projeAdi:  projeAdi,
        ozelMesaj: ozelMesaj,
      );
      await Future.delayed(const Duration(milliseconds: 700));
    }
  }

  // ── SMS ile Gönder ────────────────────────────────────────────────────────────
  static Future<void> smsGonder({
    required String telefon,
    required String link,
    required String projeAdi,
  }) async {
    final mesaj = Uri.encodeComponent('$projeAdi servis kaydı: $link');
    final numara = _temizle(telefon);
    final url    = Uri.parse('sms:$numara?body=$mesaj');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  // ── Linki Devre Dışı Bırak ───────────────────────────────────────────────────
  static Future<void> linkDevreDisi(String docId) async {
    await _db.collection('kayit_linkleri').doc(docId).update({
      'aktif': false,
      'devreDisiTarih': FieldValue.serverTimestamp(),
    });
  }

  // ── Kullanım Sayısını Artır ───────────────────────────────────────────────────
  static Future<void> kullanimArtir(String docId) async {
    await _db.collection('kayit_linkleri').doc(docId).update({
      'kullanim': FieldValue.increment(1),
    });
  }

  // ── Kodu Doğrula ve Firma ID Döndür ──────────────────────────────────────────
  static Future<String?> koduDogrula(String kod) async {
    try {
      final snap = await _db
          .collection('kayit_linkleri')
          .where('kod',    isEqualTo: kod)
          .where('aktif',  isEqualTo: true)
          .limit(1).get();
      if (snap.docs.isEmpty) return null;
      final doc   = snap.docs.first;
      final bitis = doc.data()['gecerlilikBitis'] as Timestamp?;
      if (bitis != null && bitis.toDate().isBefore(DateTime.now())) return null;
      return doc.data()['firmaId'] as String?;
    } catch (_) { return null; }
  }

  // ── Yardımcı ─────────────────────────────────────────────────────────────────
  static String _rastgeleKod() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand  = Random.secure();
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  static String _temizle(String tel) {
    final numara = tel.replaceAll(RegExp(r'[^\d]'), '');
    if (numara.startsWith('0'))  return '90${numara.substring(1)}';
    if (numara.startsWith('90')) return numara;
    return '90$numara';
  }
}
