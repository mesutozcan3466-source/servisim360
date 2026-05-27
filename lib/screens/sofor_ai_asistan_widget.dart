import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/remote_config_service.dart';

// ════════════════════════════════════════════════════════════════
//  ŞOFÖR AI ASISTAN WİDGET
//  Sadece soforun kendi verilerine erisim var
//  Yetki siniri: kendi rotasi, ogrencileri, servis saati
// ════════════════════════════════════════════════════════════════
class SoforAiAsistanWidget extends StatefulWidget {
  final String surucuAd;
  final String surucuId;
  final String aracPlaka;
  final List<Map<String, dynamic>> ogrenciler;
  final int alinanSayisi;
  final String servisDurumu;
  final String sabahBaslangic;
  final String sabahBitis;
  final String aksamBaslangic;
  final String aksamBitis;

  const SoforAiAsistanWidget({
    super.key,
    required this.surucuAd,
    required this.surucuId,
    required this.aracPlaka,
    required this.ogrenciler,
    required this.alinanSayisi,
    required this.servisDurumu,
    this.sabahBaslangic = '06:30',
    this.sabahBitis     = '09:30',
    this.aksamBaslangic = '15:00',
    this.aksamBitis     = '18:30',
  });

  @override
  State<SoforAiAsistanWidget> createState() => _SoforAiAsistanWidgetState();
}

class _SoforAiAsistanWidgetState extends State<SoforAiAsistanWidget> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  final _tts       = FlutterTts();
  final _mesajCtrl = TextEditingController();

  bool   _yukleniyor = false;
  bool   _acik       = false;
  String _sonCevap   = '';
  final List<Map<String, String>> _gecmis = [];

  @override
  void initState() {
    super.initState();
    _ttsAyarla();
  }

  @override
  void dispose() {
    _tts.stop();
    _mesajCtrl.dispose();
    super.dispose();
  }

  Future<void> _ttsAyarla() async {
    await _tts.setLanguage('tr-TR');
    await _tts.setSpeechRate(0.85);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  String _sistemPrompt() {
    final bugun   = DateTime.now();
    final saat    = bugun.hour;
    final sabahMi = saat >= 5 && saat < 13;
    final servisAktif = widget.servisDurumu == 'basladi';

    // Ogrenci detaylari
    final bekleyenler = widget.ogrenciler
        .where((o) => !(o['bindi'] ?? false))
        .map((o) => '- ${o['ad'] ?? '?'} | Adres: ${o['adres'] ?? '-'} | Veli Tel: ${o['veliTel'] ?? '-'}')
        .join('\n');

    final alinanlar = widget.ogrenciler
        .where((o) => o['bindi'] == true)
        .map((o) => '- ${o['ad'] ?? '?'}')
        .join('\n');

    final tumOgrenciler = widget.ogrenciler
        .map((o) {
      final bindi = o['bindi'] ?? false;
      return '- ${o['ad'] ?? '?'} | ${bindi ? 'BINDI' : 'BEKLIYOR'} | Adres: ${o['adres'] ?? '-'} | Veli: ${o['veliAd'] ?? '-'} | Tel: ${o['veliTel'] ?? '-'}';
    })
        .join('\n');

    return '''Sen ${widget.surucuAd} adli okul servis soforune yardim eden AI asistanisin.
SADECE bu soforun kendi is bilgilerini paylas.

KESINLIKLE YAPMA:
- Baska soforlerin bilgilerini verme
- Firma yonetimi, fiyat, lisans, odeme bilgisi verme
- Admin yetkisi gerektiren islemler hakkinda yonlendirme
- Ticari veya is stratejisi sorusu cevaplama

YAPABILECEKLERIN:
- Kendi ogrencileri, veli telefonlari, servis saati
- Gunluk servis durumu, binis/inis sayilari
- Rota ve navigasyon yardimi
- Uygulama kullanimi: Servisi baslat, QR tara, Veli Ara, Rota menuleri
- Acil durumda ne yapilmali

UYGULAMA KULLANIMI (SOFOR):
- Servisi Baslat butonu: GPS baslar, rota ekrani acilir
- Rota butonu: Ogrenci sirasi, suru/atla/bindi islemleri
- Navigasyon: Google Maps ile ilk bekleyen ogrenciye yonlendir
- Veli Ara: Tum velilerin telefon listesi
- QR Tara: Ogrenci binis/inis dogrulama
- AI Asistan (bu): Soru-cevap yardimi

Kisa, net Turkce yanitlar ver. Maksimum 3 cumle.

SOFOR BILGILERI:
- Ad: ${widget.surucuAd}
- Arac Plaka: ${widget.aracPlaka}
- Servis Durumu: ${servisAktif ? 'AKTIF - Servis baslamis' : 'PASIF - Servis baslamadi'}
- Mod: ${sabahMi ? 'Sabah servisi' : 'Aksam servisi'}

SERVIS SAATLERI:
- Sabah: ${widget.sabahBaslangic} - ${widget.sabahBitis}
- Aksam: ${widget.aksamBaslangic} - ${widget.aksamBitis}

OGRENCI OZETI:
- Toplam: ${widget.ogrenciler.length} ogrenci
- Alinan: ${widget.alinanSayisi}
- Bekleyen: ${widget.ogrenciler.length - widget.alinanSayisi}

TUM OGRENCILER:
${tumOgrenciler.isEmpty ? 'Atanmis ogrenci yok' : tumOgrenciler}

BEKLEYENLER:
${bekleyenler.isEmpty ? 'Hepsi alindi!' : bekleyenler}

ALINANLAR:
${alinanlar.isEmpty ? 'Henuz kimse alinmadi' : alinanlar}

YAPABILECEKLERIN:
- Kac ogrenci bekliyor, kimler bindi sorusunu yanitla
- Ogrenci adresi ve veli telefonu sor
- Servis saatlerini hatirlat
- Rota sirasinda yardimci ol
- Devamsizlik durumunu acikla

YAPAMAYACAKLARIN:
- Baska soforlerin bilgilerini paylasmak
- Firma veya admin bilgisi vermek
- Fiyat veya odeme bilgisi vermek
- Diger ogrencilerin kisisel bilgilerini karsilastirmak
''';
  }

  Future<void> _soruSor(String soru) async {
    if (soru.trim().isEmpty) return;

    final apiKey = RemoteConfigService.instance.claudeApiKey;
    if (apiKey.isEmpty) {
      setState(() => _sonCevap = 'AI asistan su an kullanilamiyor.');
      return;
    }

    setState(() => _yukleniyor = true);
    _mesajCtrl.clear();

    // Gecmis konusmayi ekle (son 6 mesaj)
    _gecmis.add({'role': 'user', 'content': soru});
    if (_gecmis.length > 12) _gecmis.removeRange(0, 2);

    try {
      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-haiku-4-5-20251001',
          'max_tokens': RemoteConfigService.instance.aiMaxTokens,
          'system': _sistemPrompt(),
          'messages': _gecmis,
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data  = jsonDecode(response.body);
        final cevap = data['content'][0]['text'] as String;
        _gecmis.add({'role': 'assistant', 'content': cevap});
        setState(() => _sonCevap = cevap);
        await _tts.speak(cevap);
      } else {
        setState(() => _sonCevap = 'Hata olustu, tekrar deneyin.');
      }
    } catch (e) {
      setState(() => _sonCevap = 'Baglanti hatasi.');
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!RemoteConfigService.instance.aiAsistanAktif) {
      return const SizedBox.shrink();
    }

    final bekleyenSayi = widget.ogrenciler.length - widget.alinanSayisi;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        // Baslik
        GestureDetector(
          onTap: () => setState(() => _acik = !_acik),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF1a3a6b), Color(0xFF2a5298)]),
              borderRadius: BorderRadius.only(
                topLeft:     const Radius.circular(16),
                topRight:    const Radius.circular(16),
                bottomLeft:  Radius.circular(_acik ? 0 : 16),
                bottomRight: Radius.circular(_acik ? 0 : 16),
              ),
            ),
            child: Row(children: [
              Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                      color: _turuncu, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.auto_awesome,
                      color: Colors.white, size: 20)),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('AI Asistan', style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                Text(
                    bekleyenSayi > 0
                        ? '$bekleyenSayi ogrenci bekliyor'
                        : 'Tum ogrenciler alindi',
                    style: TextStyle(
                        color: bekleyenSayi > 0
                            ? Colors.orange[200] : Colors.green[200],
                        fontSize: 11)),
              ],
              )),
              if (_yukleniyor)
                const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              else
                Icon(_acik ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white60),
            ]),
          ),
        ),

        if (_acik) ...[
          // Son cevap
          if (_sonCevap.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _navy.withValues(alpha: 0.15))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.auto_awesome, color: _navy, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(_sonCevap,
                    style: const TextStyle(fontSize: 13, height: 1.5))),
                GestureDetector(
                    onTap: () => _tts.speak(_sonCevap),
                    child: const Icon(Icons.volume_up_outlined, color: _navy, size: 18)),
              ]),
            ),

          // Hizli sorular
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Wrap(
              spacing: 6, runSpacing: 6,
              children: [
                'Kac ogrenci bekliyor?',
                'Kimler bekliyor?',
                'Kac kisi bindi?',
                'Siradaki ogrenci kim?',
                'Servis saatlerim ne?',
                'Veli telefonlari?',
                'Bugunku rota?',
              ].map((s) => GestureDetector(
                onTap: () => _soruSor(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: _navy.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _navy.withValues(alpha: 0.15))),
                  child: Text(s, style: const TextStyle(
                      fontSize: 11, color: _navy, fontWeight: FontWeight.w500)),
                ),
              )).toList(),
            ),
          ),

          // Input
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Expanded(child: TextField(
                controller: _mesajCtrl,
                decoration: InputDecoration(
                    hintText: 'Sorunuzu yazin...',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                    filled: true, fillColor: const Color(0xFFF5F7FA),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    isDense: true),
                onSubmitted: _soruSor,
                textInputAction: TextInputAction.send,
              )),
              const SizedBox(width: 8),
              GestureDetector(
                  onTap: () => _soruSor(_mesajCtrl.text),
                  child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                          color: _yukleniyor ? Colors.grey : _navy,
                          shape: BoxShape.circle),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 18))),
            ]),
          ),
        ],
      ]),
    );
  }
}
