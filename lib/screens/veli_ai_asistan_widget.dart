import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/remote_config_service.dart';

// ════════════════════════════════════════════════════════════════
//  VELİ AI ASISTAN WİDGET
//  Kisitli erisim: Sadece kendi cocugu, servis durumu, devamsizlik
//  Ticari/firma bilgisi yok
// ════════════════════════════════════════════════════════════════
class VeliAiAsistanWidget extends StatefulWidget {
  final String veliAd;
  final String veliId;
  final List<Map<String, dynamic>> cocuklar;   // Velinin cocuklari
  final String soforAd;
  final String soforTel;
  final String servisDurumu;    // 'basladi', 'bekleniyor', 'bitti'
  final String sabahBaslangic;
  final String sabahBitis;
  final String aksamBaslangic;
  final String aksamBitis;
  final String? tahminiVarisZamani;

  const VeliAiAsistanWidget({
    super.key,
    required this.veliAd,
    required this.veliId,
    required this.cocuklar,
    this.soforAd = '',
    this.soforTel = '',
    this.servisDurumu = 'bekleniyor',
    this.sabahBaslangic = '06:30',
    this.sabahBitis     = '09:30',
    this.aksamBaslangic = '15:00',
    this.aksamBitis     = '18:30',
    this.tahminiVarisZamani,
  });

  @override
  State<VeliAiAsistanWidget> createState() => _VeliAiAsistanWidgetState();
}

class _VeliAiAsistanWidgetState extends State<VeliAiAsistanWidget> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  final _tts       = FlutterTts();
  final _mesajCtrl = TextEditingController();

  bool   _yukleniyor = false;
  bool   _acik       = false;
  String _sonCevap   = '';

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
  }

  String _sistemPrompt() {
    final bugun   = DateTime.now();
    final saat    = bugun.hour;
    final sabahMi = saat >= 5 && saat < 13;
    final servisAktif = widget.servisDurumu == 'basladi';

    final cocukListesi = widget.cocuklar.isEmpty ? 'Kayitli cocuk yok' :
    widget.cocuklar.map((c) =>
    '- ${c['ad'] ?? '?'} | Durum: ${(c['bindi'] ?? false) ? 'Servise bindi' : 'Bekleniyor'} | Adres: ${c['adres'] ?? '-'}'
    ).join('\n');

    return '''Sen ${widget.veliAd} adli veliye yardim eden Servisim360 AI asistanisin.
SADECE bu velinin kendi bilgilerini paylas. Basit, samimi Turkce konuş.

KESINLIKLE YAPMA:
- Baska velilerin veya ogrencilerin bilgilerini verme
- Firma yonetimi, fiyat politikasi, ticari bilgi verme
- Sofor kisisel bilgileri (adres, maas vs) paylaşma
- Admin yetkisi gerektiren islemler yapma
- Diger ailelerin bilgilerini karsilastirma

COCUK BILGILERI:
$cocukListesi

SOFOR BILGISI:
- Sofor: ${widget.soforAd.isNotEmpty ? widget.soforAd : 'Atanmamis'}
- Telefon: ${widget.soforTel.isNotEmpty ? widget.soforTel : 'Bilgi yok'}

SERVIS DURUMU:
- Mod: ${sabahMi ? 'Sabah servisi' : 'Aksam servisi'}
- Durum: ${servisAktif ? 'AKTIF - Servis yolda' : 'Servis henuz baslamadi'}
- Sabah: ${widget.sabahBaslangic} - ${widget.sabahBitis}
- Aksam: ${widget.aksamBaslangic} - ${widget.aksamBitis}
${widget.tahminiVarisZamani != null ? '- Tahmini varis: ${widget.tahminiVarisZamani}' : ''}

YAPABILECEKLERIN:
- Cocugun servis durumunu soyle (bindi/bekliyor)
- Servis saatlerini hatirlat
- Sofor telefon numarasini ver
- Devamsizlik bildirimi nasil yapilir acikla
- Uygulama kullanimi: Konum takip, devamsizlik bildirimi
- Cocugun guvenligi ile ilgili sorulara yardim

UYGULAMA KULLANIMI (VELİ):
- Ana ekran: Soforun canli konumunu goster (servis saatlerinde)
- Devamsizlik butonu: Bugün gelmeyecek bildir
- Sofor ara: Soforun telefon numarasi
- Bildirimler: Servis basladi/bitti bildirimleri

Kisa, sicak, anlasilir Turkce cevaplar ver. Maksimum 2-3 cumle.''';
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
          'messages': [{'role': 'user', 'content': soru}],
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data  = jsonDecode(response.body);
        final cevap = data['content'][0]['text'] as String;
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

    final servisAktif = widget.servisDurumu == 'basladi';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(children: [
        // Baslik
        GestureDetector(
          onTap: () => setState(() => _acik = !_acik),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: servisAktif
                        ? [Colors.green.shade700, Colors.green.shade500]
                        : [_navy, const Color(0xFF2a5298)]),
                borderRadius: BorderRadius.only(
                    topLeft:     const Radius.circular(16),
                    topRight:    const Radius.circular(16),
                    bottomLeft:  Radius.circular(_acik ? 0 : 16),
                    bottomRight: Radius.circular(_acik ? 0 : 16))),
            child: Row(children: [
              Container(width: 36, height: 36,
                  decoration: BoxDecoration(
                      color: _turuncu, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.support_agent_outlined, color: Colors.white, size: 20)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Yardim & Destek', style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                Text(
                    servisAktif ? 'Servis yolda' : 'Soru sorabilirsiniz',
                    style: TextStyle(
                        color: servisAktif ? Colors.greenAccent[100] : Colors.white60,
                        fontSize: 11)),
              ])),
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
                const Icon(Icons.support_agent_outlined, color: _navy, size: 16),
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
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              'Cocugum bindi mi?',
              'Servis ne zaman gelir?',
              'Bugun gelmeyecek nasil bildiririm?',
              'Sofor telefonu?',
              'Servis saatleri?',
            ].map((s) => GestureDetector(
                onTap: () => _soruSor(s),
                child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: _navy.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _navy.withValues(alpha: 0.15))),
                    child: Text(s, style: const TextStyle(
                        fontSize: 11, color: _navy, fontWeight: FontWeight.w500))))).toList()),
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      isDense: true),
                  onSubmitted: _soruSor,
                  textInputAction: TextInputAction.send)),
              const SizedBox(width: 8),
              GestureDetector(
                  onTap: () => _soruSor(_mesajCtrl.text),
                  child: Container(width: 40, height: 40,
                      decoration: BoxDecoration(
                          color: _yukleniyor ? Colors.grey : _navy,
                          shape: BoxShape.circle),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 18))),
            ]),
          ),
        ],
      ]),
    );
  }
}
