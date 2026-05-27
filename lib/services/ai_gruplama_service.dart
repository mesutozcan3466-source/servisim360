import 'package:cloud_firestore/cloud_firestore.dart';
import 'ai_service.dart';

// ================================================================
//  AI GRUPLAMA SERVİSİ - Servisim360
//  Öğrencileri yakınlık bazlı servislere otomatik dağıtır
// ================================================================

class AiGruplamaService {

  // ── Ana metod: projedeki tüm öğrencileri grupla ──────────────
  static Future<AiGruplamaSonuc> ogrencileriGrupla({
    required String firmaId,
    required String projeId,
    required int aracKapasitesi,
    required int aracSayisi,
  }) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('students')
          .where('firmaId', isEqualTo: firmaId)
          .where('projeId', isEqualTo: projeId)
          .where('aktif', isEqualTo: true)
          .get();

      if (snap.docs.isEmpty) {
        return AiGruplamaSonuc(hata: 'Aktif öğrenci bulunamadı.', gruplar: []);
      }

      final ogrenciler = snap.docs.map((d) {
        final data = d.data();
        return {
          'id':     d.id,
          'ad':     '${data['ad'] ?? ''} ${data['soyad'] ?? ''}',
          'adres':  data['adres'] ?? '',
          'ilce':   data['ilce'] ?? '',
          'mahalle':data['mahalle'] ?? '',
          'enlem':  data['enlem']?.toString() ?? '0',
          'boylam': data['boylam']?.toString() ?? '0',
        };
      }).toList();

      final prompt = '''
Aşağıdaki ${ogrenciler.length} öğrenciyi $aracSayisi servise böl.
Her servis maksimum $aracKapasitesi öğrenci taşıyabilir.

Öğrenciler (id | ad | ilçe | mahalle | konum):
${ogrenciler.map((o) => '${o['id']} | ${o['ad']} | ${o['ilce']} | ${o['mahalle']} | (${o['enlem']}, ${o['boylam']})').join('\n')}

Gruplama kuralları:
1. Aynı bölge/mahallede yaşayan öğrenciler aynı servise
2. Her servis doluluk oranı dengeli olsun
3. Toplam yol mesafesi minimum olsun
4. Servis adı renk bazlı olsun (Kırmızı Servis, Mavi Servis vb.)

JSON formatında döndür:
{
  "gruplar": [
    {
      "servisAdi": "Kırmızı Servis",
      "ogrenciIdler": ["id1", "id2"],
      "bolge": "Kadıköy - Moda",
      "tahminiSure": "35 dakika",
      "ogrenciSayisi": 2
    }
  ],
  "toplamOgrenci": ${ogrenciler.length},
  "aciklama": "Gruplama mantığı açıklaması"
}
''';

      final sonuc = await AiService.sorJson(prompt);

      if (sonuc == null) {
        return AiGruplamaSonuc(hata: 'AI yanıt veremedi.', gruplar: []);
      }

      final gruplar = (sonuc['gruplar'] as List?)?.map((g) => ServisGrubu(
        servisAdi:     g['servisAdi'] ?? 'Servis',
        ogrenciIdler:  List<String>.from(g['ogrenciIdler'] ?? []),
        bolge:         g['bolge'] ?? '',
        tahminiSure:   g['tahminiSure'] ?? '',
        ogrenciSayisi: g['ogrenciSayisi'] ?? 0,
      )).toList() ?? [];

      return AiGruplamaSonuc(
        gruplar:       gruplar,
        toplamOgrenci: sonuc['toplamOgrenci'] ?? ogrenciler.length,
        aciklama:      sonuc['aciklama'] ?? '',
      );
    } catch (e) {
      return AiGruplamaSonuc(hata: 'Hata: $e', gruplar: []);
    }
  }

  // ── Gruplama sonucunu Firestore'a kaydet ──────────────────────
  static Future<bool> gruplamaKaydet({
    required String firmaId,
    required String projeId,
    required List<ServisGrubu> gruplar,
    required List<String> aracIdler,
  }) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      for (int i = 0; i < gruplar.length; i++) {
        final grup  = gruplar[i];
        final aracId = i < aracIdler.length ? aracIdler[i] : '';

        for (final ogrenciId in grup.ogrenciIdler) {
          final ref = FirebaseFirestore.instance
              .collection('students')
              .doc(ogrenciId);
          batch.update(ref, {
            'aracId':      aracId,
            'servisAdi':   grup.servisAdi,
            'grupGuncelleme': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── Tek öğrenci için en uygun servis önerisi ─────────────────
  static Future<String> enUygunServisOner({
    required String ogrenciAdres,
    required List<Map<String, dynamic>> mevcutServisler,
  }) async {
    final prompt = '''
Yeni öğrenci adresi: $ogrenciAdres

Mevcut servisler:
${mevcutServisler.map((s) => '- ${s['ad']}: ${s['bolge']} (${s['ogrenciSayisi']}/${s['kapasite']} öğrenci)').join('\n')}

Bu öğrenci hangi servise eklenebilir? Kısa yanıt ver.
''';

    return AiService.sor(prompt);
  }
}

// ── Model Sınıfları ───────────────────────────────────────────
class AiGruplamaSonuc {
  final List<ServisGrubu> gruplar;
  final int toplamOgrenci;
  final String aciklama;
  final String? hata;

  AiGruplamaSonuc({
    required this.gruplar,
    this.toplamOgrenci = 0,
    this.aciklama = '',
    this.hata,
  });

  bool get basarili => hata == null;
}

class ServisGrubu {
  final String servisAdi, bolge, tahminiSure;
  final List<String> ogrenciIdler;
  final int ogrenciSayisi;

  ServisGrubu({
    required this.servisAdi,
    required this.ogrenciIdler,
    required this.bolge,
    required this.tahminiSure,
    required this.ogrenciSayisi,
  });
}
