// lib/services/akilli_rota_ai_service.dart
// Servisim360 – AI destekli rota optimizasyon servisi
// Claude API ile öğrenci–sürücü ataması yapar ve Firestore'a yazar.

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

  const AkilliRotaSonuc({
    required this.atamalar,
    required this.aciklama,
  });
}

// ─────────────────────────────────────────────
// Servis
// ─────────────────────────────────────────────

class AkilliRotaAiService {
  static const _apiUrl = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-sonnet-4-20250514';

  // ── Ana metod: AI'dan öneri al ───────────────
  static Future<AkilliRotaSonuc> rotaOner({
    required String firmaId,
    required List<Map<String, dynamic>> ogrenciler,
    required List<Map<String, dynamic>> suruculer,
  }) async {
    final prompt = _promptOlustur(ogrenciler, suruculer);

    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'anthropic-version': '2023-06-01',
      },
      body: jsonEncode({
        'model': _model,
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
      throw Exception('AI servisi hata verdi: ${response.statusCode}');
    }

    final body = jsonDecode(utf8.decode(response.bodyBytes));
    final rawText = (body['content'] as List)
        .firstWhere((c) => c['type'] == 'text')['text'] as String;

    // JSON fence varsa temizle
    final clean =
    rawText.replaceAll(RegExp(r'```json|```'), '').trim();

    final Map<String, dynamic> parsed = jsonDecode(clean);

    final atamaRaw =
        parsed['atamalar'] as Map<String, dynamic>? ?? {};
    final Map<String, List<String>> atamalar = atamaRaw.map(
          (k, v) => MapEntry(k, List<String>.from(v as List)),
    );

    return AkilliRotaSonuc(
      atamalar: atamalar,
      aciklama: parsed['aciklama'] as String? ?? 'AI analizi tamamlandı.',
    );
  }

  // ── Atamaları Firestore'a yaz ─────────────────
  static Future<void> atamalariUygula(
      Map<String, List<String>> atamalar) async {
    final db = FirebaseFirestore.instance;
    final batch = db.batch();

    for (final entry in atamalar.entries) {
      final surucuId = entry.key;
      final ogrenciIdler = entry.value;

      // Sürücü belgesine atanan öğrencileri ekle
      final surucuRef = db.collection('suruculer').doc(surucuId);
      batch.update(surucuRef, {
        'atananOgrenciler': ogrenciIdler,
        'guncellenmeTarihi': FieldValue.serverTimestamp(),
      });

      // Her öğrenci belgesine sürücü bilgisini yaz
      for (final ogrenciId in ogrenciIdler) {
        final ogrRef = db.collection('ogrenciler').doc(ogrenciId);
        batch.update(ogrRef, {
          'atananSurucu': surucuId,
          'guncellenmeTarihi': FieldValue.serverTimestamp(),
        });
      }
    }

    await batch.commit();
  }

  // ── Prompt oluşturucu ─────────────────────────
  static String _promptOlustur(
      List<Map<String, dynamic>> ogrenciler,
      List<Map<String, dynamic>> suruculer,
      ) {
    // Sürücü listesi
    final surucuMetni = suruculer.map((s) {
      final kapasite = s['kapasite'] ?? 10;
      final bolge = s['bolge'] ?? 'belirtilmemiş';
      return '- ID: ${s['id']} | Ad: ${s['ad'] ?? '?'} '
          '| Kapasite: $kapasite | Bölge: $bolge';
    }).join('\n');

    // Öğrenci listesi (max 80 öğrenci – prompt sınırı)
    final liste =
    ogrenciler.length > 80 ? ogrenciler.sublist(0, 80) : ogrenciler;
    final ogrenciMetni = liste.map((o) {
      final lat = o['lat'] ?? o['konum']?['lat'] ?? 'yok';
      final lng = o['lng'] ?? o['konum']?['lng'] ?? 'yok';
      return '- ID: ${o['id']} | Ad: ${o['ad'] ?? '?'} '
          '| Lat: $lat | Lng: $lng';
    }).join('\n');

    return '''
SÜRÜCÜLER (${suruculer.length} adet):
$surucuMetni

ÖĞRENCİLER (${liste.length} adet):
$ogrenciMetni

Görev: Öğrencileri sürücülere, coğrafi yakınlığa ve araç kapasitesine göre
dengeli şekilde ata. Her sürücünün kapasitesini aşma. Koordinat yoksa
mevcut verilerle makul bir dağılım yap.
''';
  }
}
