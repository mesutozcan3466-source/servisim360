// lib/services/akilli_rota_ai_service.dart
// Servisim360 – AI destekli rota optimizasyon servisi

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────
// Veri modeli
// ─────────────────────────────────────────────
class AkilliRotaSonuc {
  /// surucuId → ogrenciId listesi
  final Map<String, List<String>> atamalar;
  final String aciklama;
  final bool basarili;
  final int toplamAtanan;

  const AkilliRotaSonuc({
    required this.atamalar,
    required this.aciklama,
    this.basarili = true,
    this.toplamAtanan = 0,
  });

  /// Hata durumu için
  factory AkilliRotaSonuc.hata(String mesaj) => AkilliRotaSonuc(
    atamalar: {},
    aciklama: mesaj,
    basarili: false,
    toplamAtanan: 0,
  );
}

// ─────────────────────────────────────────────
// Servis
// ─────────────────────────────────────────────
class AkilliRotaAiService {
  static const _apiUrl = 'https://api.anthropic.com/v1/messages';
  static const _model  = 'claude-sonnet-4-20250514';

  /// AI'dan rota önerisi al
  static Future<AkilliRotaSonuc> rotaOner({
    required String firmaId,
    required List<Map<String, dynamic>> ogrenciler,
    required List<Map<String, dynamic>> suruculer,
  }) async {
    try {
      final prompt = _promptOlustur(ogrenciler, suruculer);

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type':      'application/json',
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model':      _model,
          'max_tokens': 1500,
          'system': '''Sen bir okul servis rota optimizasyon uzmanısın.
Verilen öğrenci ve sürücü listesini analiz ederek coğrafi konumlara göre
en verimli atamaları yaparsın. Cevabını YALNIZCA geçerli JSON formatında ver,
başka hiçbir metin ekleme. JSON şeması:
{
  "atamalar": { "surucuId": ["ogrenciId1", "ogrenciId2"] },
  "aciklama": "Kısa Türkçe özet (max 200 karakter)"
}''',
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
        }),
      );

      if (response.statusCode != 200) {
        return AkilliRotaSonuc.hata(
            'AI servisi hata verdi: ${response.statusCode}');
      }

      final body    = jsonDecode(utf8.decode(response.bodyBytes));
      final rawText = (body['content'] as List)
          .firstWhere((c) => c['type'] == 'text')['text'] as String;

      final clean = rawText.replaceAll(RegExp(r'```json|```'), '').trim();
      final Map<String, dynamic> parsed = jsonDecode(clean);

      final atamaRaw = parsed['atamalar'] as Map<String, dynamic>? ?? {};
      final Map<String, List<String>> atamalar = atamaRaw.map(
            (k, v) => MapEntry(k, List<String>.from(v as List)),
      );

      final toplamAtanan =
      atamalar.values.fold<int>(0, (sum, list) => sum + list.length);

      return AkilliRotaSonuc(
        atamalar:     atamalar,
        aciklama:     parsed['aciklama'] as String? ?? 'AI analizi tamamlandı.',
        basarili:     true,
        toplamAtanan: toplamAtanan,
      );
    } catch (e) {
      return AkilliRotaSonuc.hata('AI analizi başarısız: $e');
    }
  }

  /// Atamaları Firestore'a yaz — students / drivers koleksiyonları
  static Future<void> atamalariUygula(
      Map<String, List<String>> atamalar) async {
    final db    = FirebaseFirestore.instance;
    final batch = db.batch();

    for (final entry in atamalar.entries) {
      final surucuId   = entry.key;
      final ogrenciIdler = entry.value;

      // drivers koleksiyonu
      final surucuRef = db.collection('drivers').doc(surucuId);
      batch.update(surucuRef, {
        'atananOgrenciler':  ogrenciIdler,
        'guncellenmeTarihi': FieldValue.serverTimestamp(),
      });

      // students koleksiyonu
      for (final ogrenciId in ogrenciIdler) {
        final ogrRef = db.collection('students').doc(ogrenciId);
        batch.update(ogrRef, {
          'surucuId':          surucuId,
          'guncellenmeTarihi': FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();
  }

  // Prompt oluşturucu
  static String _promptOlustur(
      List<Map<String, dynamic>> ogrenciler,
      List<Map<String, dynamic>> suruculer,
      ) {
    final surucuMetni = suruculer.map((s) {
      final kapasite = s['kapasite'] ?? 17;
      final bolge    = s['bolge']    ?? 'belirtilmemiş';
      return '- ID: ${s['id']} | Ad: ${s['ad'] ?? '?'} '
          '| Kapasite: $kapasite | Bölge: $bolge';
    }).join('\n');

    final liste = ogrenciler.length > 80
        ? ogrenciler.sublist(0, 80)
        : ogrenciler;

    final ogrenciMetni = liste.map((o) {
      final konum = o['konum'];
      final lat   = o['lat'] ?? (konum is Map ? konum['latitude']  : null) ?? 'yok';
      final lng   = o['lng'] ?? (konum is Map ? konum['longitude'] : null) ?? 'yok';
      return '- ID: ${o['id']} | Ad: ${o['ad'] ?? '?'} '
          '| Lat: $lat | Lng: $lng';
    }).join('\n');

    return '''
SÜRÜCÜLER (${suruculer.length} adet):
$surucuMetni

ÖĞRENCİLER (${liste.length} adet):
$ogrenciMetni

Görev: Öğrencileri sürücülere, coğrafi yakınlığa ve araç kapasitesine göre
dengeli şekilde ata. Her sürücünün kapasitesini aşma.
Koordinat yoksa mevcut verilerle makul bir dağılım yap.
''';
  }
}
