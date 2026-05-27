import 'package:cloud_firestore/cloud_firestore.dart';
import 'ai_service.dart';

// ================================================================
//  AI ROTA SERVİSİ - Servisim360
//  Öğrenci konumlarına göre en verimli rota sırası üretir
// ================================================================

class AiRotaService {

  // ── Ana metod: firmaId + projeId ile rota optimize et ────────
  static Future<AiRotaSonuc> rotaOptimizeEt({
    required String firmaId,
    required String projeId,
    required String aracId,
    required String okuldanBasla, // okul adresi
  }) async {
    try {
      // Öğrencileri Firestore'dan çek
      final snap = await FirebaseFirestore.instance
          .collection('students')
          .where('firmaId', isEqualTo: firmaId)
          .where('projeId', isEqualTo: projeId)
          .where('aracId', isEqualTo: aracId)
          .where('aktif', isEqualTo: true)
          .get();

      if (snap.docs.isEmpty) {
        return AiRotaSonuc(
          hata: 'Bu araçta aktif öğrenci bulunamadı.',
          ogrenciler: [],
          aciklama: '',
        );
      }

      final ogrenciler = snap.docs.map((d) {
        final data = d.data();
        return {
          'id':    d.id,
          'ad':    '${data['ad'] ?? ''} ${data['soyad'] ?? ''}',
          'adres': data['adres'] ?? '',
          'enlem': data['enlem']?.toString() ?? '',
          'boylam': data['boylam']?.toString() ?? '',
        };
      }).toList();

      final prompt = '''
Aşağıdaki öğrenciler için okul servisi rota optimizasyonu yap.

Başlangıç noktası: $okuldanBasla
Öğrenci sayısı: ${ogrenciler.length}

Öğrenciler:
${ogrenciler.asMap().entries.map((e) => '${e.key + 1}. ${e.value['ad']} - Adres: ${e.value['adres']} - Konum: (${e.value['enlem']}, ${e.value['boylam']})').join('\n')}

Görevin:
1. Yakınlık ve verimlilik bazlı en iyi rota sırasını belirle
2. Tahmini toplam süreyi hesapla
3. Her durak için bekleme süresi öner
4. Rotayı neden bu sıraya koyduğunu açıkla

JSON formatında döndür:
{
  "siralamalar": [
    {"id": "ogrenci_id", "ad": "ad", "sira": 1, "tahminiDakika": 5}
  ],
  "toplamSure": "45 dakika",
  "aciklama": "Rota optimizasyon açıklaması"
}
''';

      final sonuc = await AiService.sorJson(prompt);

      if (sonuc == null) {
        return AiRotaSonuc(
          hata: 'AI yanıt veremedi.',
          ogrenciler: [],
          aciklama: '',
        );
      }

      final siralamalar = (sonuc['siralamalar'] as List?)
          ?.map((s) => RotaSiralama(
        id:              s['id'] ?? '',
        ad:              s['ad'] ?? '',
        sira:            s['sira'] ?? 0,
        tahminiDakika:   s['tahminiDakika'] ?? 0,
      ))
          .toList() ?? [];

      return AiRotaSonuc(
        ogrenciler:  siralamalar,
        toplamSure:  sonuc['toplamSure'] ?? '',
        aciklama:    sonuc['aciklama'] ?? '',
      );
    } catch (e) {
      return AiRotaSonuc(
        hata: 'Hata: $e',
        ogrenciler: [],
        aciklama: '',
      );
    }
  }

  // ── Tek araç için hızlı rota tavsiyesi ───────────────────────
  static Future<String> hizliRotaTavsiye(List<String> adresler) async {
    if (adresler.isEmpty) return 'Adres bulunamadı.';

    final prompt = '''
Bu adresler için en verimli servis rotasını sırala ve kısa açıklama yap:
${adresler.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}

Kısa, pratik öneri ver. Türkçe yaz.
''';

    return AiService.sor(prompt);
  }

  // ── Rota değişikliği önerisi ──────────────────────────────────
  static Future<String> rotaDegisiklikOneri({
    required List<String> mevcutRota,
    required String yeniOgrenciAdres,
  }) async {
    final prompt = '''
Mevcut servis rotası:
${mevcutRota.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('\n')}

Yeni öğrenci adresi: $yeniOgrenciAdres

Bu yeni öğrenciyi rotaya en uygun şekilde eklemek için öneri ver.
Kısa ve net cevap ver.
''';

    return AiService.sor(prompt);
  }
}

// ── Model Sınıfları ───────────────────────────────────────────
class AiRotaSonuc {
  final List<RotaSiralama> ogrenciler;
  final String toplamSure;
  final String aciklama;
  final String? hata;

  AiRotaSonuc({
    required this.ogrenciler,
    required this.aciklama,
    this.toplamSure = '',
    this.hata,
  });

  bool get basarili => hata == null;
}

class RotaSiralama {
  final String id, ad;
  final int sira, tahminiDakika;

  RotaSiralama({
    required this.id,
    required this.ad,
    required this.sira,
    required this.tahminiDakika,
  });
}
