import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/remote_config_service.dart';

class VeliAiWidget extends StatefulWidget {
  final String ogrenciAdi;
  final String surucuAd;
  final String servisDurumu;
  final bool takipZamaniMi;

  const VeliAiWidget({
    super.key,
    required this.ogrenciAdi,
    required this.surucuAd,
    required this.servisDurumu,
    required this.takipZamaniMi,
  });

  @override
  State<VeliAiWidget> createState() => _VeliAiWidgetState();
}

class _VeliAiWidgetState extends State<VeliAiWidget> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  final _mesajCtrl = TextEditingController();
  bool   _yukleniyor = false;
  bool   _acik       = false;
  String _sonCevap   = '';

  final _hizliSorular = const [
    'Servis ne zaman gelir?',
    'Cocugum bindi mi?',
    'Sofor kim?',
    'Servis aktif mi?',
  ];

  @override
  void dispose() {
    _mesajCtrl.dispose();
    super.dispose();
  }

  Future<void> _soruSor(String soru) async {
    if (soru.trim().isEmpty) return;

    // API key Remote Config'den al
    final apiKey = RemoteConfigService.instance.claudeApiKey;
    if (apiKey.isEmpty) {
      setState(() => _sonCevap = 'AI asistan su an kullanilamiyor.');
      return;
    }

    setState(() => _yukleniyor = true);
    _mesajCtrl.clear();

    final sistemPrompt = '''
Sen Servisim360 okul servis uygulamasinin veli AI asistanisin.
Velilere kisa, net ve anlasilir Turkce yanitlar ver. Maksimum 2 cumle.

ANLIK DURUM:
- Ogrenci: ${widget.ogrenciAdi}
- Sofor: ${widget.surucuAd}
- Servis: ${widget.servisDurumu == 'basladi' ? 'Yolda' : 'Beklemede'}
- Takip zamani: ${widget.takipZamaniMi ? 'Aktif' : 'Pasif (servis saati disinda)'}
''';

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
          'system': sistemPrompt,
          'messages': [
            {'role': 'user', 'content': soru}
          ],
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() =>
        _sonCevap = data['content'][0]['text'] as String);
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
                width: 34, height: 34,
                decoration: BoxDecoration(
                    color: _turuncu,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.auto_awesome,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI Asistan', style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('Servis sorulariniz icin',
                      style: TextStyle(color: Colors.white60, fontSize: 11)),
                ],
              )),
              if (_yukleniyor)
                const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
              else
                Icon(_acik ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white60),
            ]),
          ),
        ),

        if (_acik) ...[
          if (_sonCevap.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _navy.withValues(alpha: 0.15)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome, color: _navy, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_sonCevap,
                      style: const TextStyle(fontSize: 13, height: 1.5))),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Wrap(
              spacing: 6, runSpacing: 6,
              children: _hizliSorular.map((s) => GestureDetector(
                onTap: () => _soruSor(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _navy.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _navy.withValues(alpha: 0.15)),
                  ),
                  child: Text(s, style: const TextStyle(
                      fontSize: 11, color: _navy, fontWeight: FontWeight.w500)),
                ),
              )).toList(),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _mesajCtrl,
                  decoration: InputDecoration(
                    hintText: 'Sorunuzu yazin...',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFFF5F7FA),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    isDense: true,
                  ),
                  onSubmitted: _soruSor,
                  textInputAction: TextInputAction.send,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _soruSor(_mesajCtrl.text),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _yukleniyor ? Colors.grey : _navy,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}
