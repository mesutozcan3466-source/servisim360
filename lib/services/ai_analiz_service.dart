import 'package:cloud_firestore/cloud_firestore.dart';
import 'ai_service.dart';

// ================================================================
//  AI ANALİZ SERVİSİ - Servisim360
//  Devamsızlık analizi, şoför performansı, rota raporu
// ================================================================

class AiAnalizService {

  // ── Devamsızlık analizi ───────────────────────────────────────
  static Future<String> devamsizlikAnaliz({
    required String firmaId,
    required String projeId,
    int gunSayisi = 30,
  }) async {
    try {
      final baslangic = DateTime.now().subtract(Duration(days: gunSayisi));

      final snap = await FirebaseFirestore.instance
          .collection('yoklama')
          .where('firmaId', isEqualTo: firmaId)
          .where('projeId', isEqualTo: projeId)
          .where('tarih', isGreaterThan: Timestamp.fromDate(baslangic))
          .where('durum', isEqualTo: 'gelmiyor')
          .get();

      if (snap.docs.isEmpty) {
        return 'Son $gunSayisi günde devamsızlık kaydı bulunmuyor.';
      }

      // Öğrenci bazlı say
      final sayac = <String, int>{};
      final adlar  = <String, String>{};
      for (final d in snap.docs) {
        final data       = d.data();
        final ogrenciId  = data['ogrenciId'] ?? '';
        final ogrenciAd  = data['ogrenciAd'] ?? 'Bilinmiyor';
        sayac[ogrenciId] = (sayac[ogrenciId] ?? 0) + 1;
        adlar[ogrenciId] = ogrenciAd;
      }

      final siralama = sayac.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final ozet = siralama.take(10).map((e) =>
      '${adlar[e.key]}: ${e.value} gün devamsızlık').join('\n');

      final prompt = '''
Son $gunSayisi günlük okul servisi devamsızlık verileri:

$ozet

Toplam devamsızlık kaydı: ${snap.docs.length}

Bu verileri analiz et ve şunları belirt:
1. Dikkat çeken örüntüler
2. Olası nedenler
3. Admin için öneriler
4. Risk taşıyan öğrenciler

Kısa ve net Türkçe rapor yaz.
''';

      return AiService.sor(prompt);
    } catch (e) {
      return 'Analiz hatası: $e';
    }
  }

  // ── Şoför performans analizi ──────────────────────────────────
  static Future<String> soforPerformansAnaliz({
    required String firmaId,
    required String soforId,
    int gunSayisi = 7,
  }) async {
    try {
      final baslangic = DateTime.now().subtract(Duration(days: gunSayisi));

      final snap = await FirebaseFirestore.instance
          .collection('guzergah_kayitlari')
          .where('firmaId', isEqualTo: firmaId)
          .where('soforId', isEqualTo: soforId)
          .where('tarih', isGreaterThan: Timestamp.fromDate(baslangic))
          .orderBy('tarih', descending: true)
          .get();

      if (snap.docs.isEmpty) {
        return 'Bu şoför için son $gunSayisi günde kayıt bulunamadı.';
      }

      final kayitlar = snap.docs.map((d) {
        final data = d.data();
        return {
          'tarih':     (data['tarih'] as Timestamp?)?.toDate().toString() ?? '',
          'sure':      data['sure']?.toString() ?? '0',
          'mesafe':    data['mesafe']?.toString() ?? '0',
          'gecikme':   data['gecikme']?.toString() ?? '0',
          'ogrenciSayisi': data['ogrenciSayisi']?.toString() ?? '0',
        };
      }).toList();

      final prompt = '''
Şoför performans verileri (son $gunSayisi gün):

${kayitlar.map((k) => 'Tarih: ${k['tarih']} | Süre: ${k['sure']}dk | Mesafe: ${k['mesafe']}km | Gecikme: ${k['gecikme']}dk | Öğrenci: ${k['ogrenciSayisi']}').join('\n')}

Bu verileri analiz et:
1. Ortalama performans değerlendirmesi
2. Gecikme örüntüleri
3. İyileştirme önerileri
4. Genel değerlendirme (İyi / Orta / Geliştirilmeli)

Kısa Türkçe rapor yaz.
''';

      return AiService.sor(prompt);
    } catch (e) {
      return 'Analiz hatası: $e';
    }
  }

  // ── Genel sistem raporu ───────────────────────────────────────
  static Future<String> sistemRaporu({required String firmaId}) async {
    try {
      // Paralel veri çek
      final futures = await Future.wait([
        FirebaseFirestore.instance.collection('students').where('firmaId', isEqualTo: firmaId).where('aktif', isEqualTo: true).count().get(),
        FirebaseFirestore.instance.collection('drivers').where('firmaId', isEqualTo: firmaId).count().get(),
        FirebaseFirestore.instance.collection('vehicles').where('firmaId', isEqualTo: firmaId).count().get(),
        FirebaseFirestore.instance.collection('projects').where('firmaId', isEqualTo: firmaId).where('aktif', isEqualTo: true).count().get(),
      ]);

      final ogrenciSayisi = futures[0].count ?? 0;
      final soforSayisi   = futures[1].count ?? 0;
      final aracSayisi    = futures[2].count ?? 0;
      final projeSayisi   = futures[3].count ?? 0;

      final prompt = '''
Servisim360 sistem durumu:
- Aktif öğrenci: $ogrenciSayisi
- Şoför sayısı: $soforSayisi
- Araç sayısı: $aracSayisi
- Aktif proje: $projeSayisi

Bu verilere bakarak:
1. Sistemin genel durumunu değerlendir
2. Dikkat edilmesi gereken noktaları belirt
3. Optimizasyon önerileri sun

3-4 cümle kısa rapor yaz.
''';

      return AiService.sor(prompt);
    } catch (e) {
      return 'Rapor oluşturulamadı: $e';
    }
  }

  // ── Rota verimliliği analizi ─────────────────────────────────
  static Future<String> rotaVerimliligiAnaliz({
    required String firmaId,
    required String aracId,
  }) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('guzergah_kayitlari')
          .where('firmaId', isEqualTo: firmaId)
          .where('aracId', isEqualTo: aracId)
          .orderBy('tarih', descending: true)
          .limit(10)
          .get();

      if (snap.docs.isEmpty) return 'Bu araç için kayıt bulunamadı.';

      final ortalamaSure = snap.docs
          .map((d) => (d.data()['sure'] ?? 0) as num)
          .reduce((a, b) => a + b) / snap.docs.length;

      final ortalamaMesafe = snap.docs
          .map((d) => (d.data()['mesafe'] ?? 0) as num)
          .reduce((a, b) => a + b) / snap.docs.length;

      final prompt = '''
Son 10 sefer verisi:
- Ortalama süre: ${ortalamaSure.toStringAsFixed(0)} dakika
- Ortalama mesafe: ${ortalamaMesafe.toStringAsFixed(1)} km

Rota verimliliğini değerlendir ve iyileştirme önerileri sun.
Kısa ve pratik cevap ver.
''';

      return AiService.sor(prompt);
    } catch (e) {
      return 'Analiz hatası: $e';
    }
  }
}
