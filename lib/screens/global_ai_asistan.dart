import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

// ════════════════════════════════════════════════════════════════
//  GLOBAL AI ASISTAN
//  - Suruklenebilir floating buton
//  - Uzun basinca sesli komut
//  - Kis basinca chat panel acar
//  - TTS ile sesli cevap
// ════════════════════════════════════════════════════════════════
class GlobalAiAsistanWrapper extends StatefulWidget {
  final Widget child;
  final String firmaId;
  final String firmaAd;

  const GlobalAiAsistanWrapper({
    super.key,
    required this.child,
    this.firmaId = '',
    this.firmaAd = '',
  });

  @override
  State<GlobalAiAsistanWrapper> createState() => _GlobalAiAsistanWrapperState();
}

class _GlobalAiAsistanWrapperState extends State<GlobalAiAsistanWrapper>
    with SingleTickerProviderStateMixin {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  bool _acik = false;
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;

  // Surukleme pozisyonu
  double _dx = 0;
  double _dy = 0;
  bool _pozisyonBaslatildi = false;



  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // Ses metodu: flutter pub get sonrasi aktif olacak

  void _toggle() {
    setState(() => _acik = !_acik);
    if (_acik) {
      _animCtrl.forward();
    } else {
      _animCtrl.reverse();
    }
  }

  // Uzun basinca chat ac + text field'a odaklan
  Future<void> _sesKomutBaslat() async {
    HapticFeedback.heavyImpact();
    if (!_acik) _toggle();
    // Sesli komut yakinda eklenecek
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Sorunuzu yazin veya mikrofon icin flutter pub get calistirin'),
            backgroundColor: Color(0xFF1a3a6b),
            duration: Duration(seconds: 2)));
  }

  final GlobalKey<_AiChatPanelState> _chatPanelKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    // Baslangic pozisyonu (sag alt)
    if (!_pozisyonBaslatildi) {
      final size = MediaQuery.of(context).size;
      _dx = size.width  - 72;
      _dy = size.height - 160;
      _pozisyonBaslatildi = true;
    }

    return Stack(children: [
      widget.child,

      // Karanlik overlay
      if (_acik)
        GestureDetector(
            onTap: _toggle,
            child: Container(color: Colors.black.withValues(alpha: 0.4))),

      // Chat Panel
      if (_acik)
        Positioned(
          bottom: 90, right: 16, left: 16,
          child: ScaleTransition(
            scale: _scaleAnim,
            alignment: Alignment.bottomRight,
            child: _AiChatPanel(
              key: _chatPanelKey,
              firmaId: widget.firmaId,
              firmaAd: widget.firmaAd,
              onKapat: _toggle,
            ),
          ),
        ),



      // Suruklenebilir floating buton
      Positioned(
        left: _dx, top: _dy,
        child: GestureDetector(
          // Kisa tiklama — chat ac/kapat
          onTap: _toggle,
          // Uzun basma — ses komutu
          onLongPress: _sesKomutBaslat,
          // Surukleme
          onPanUpdate: (details) {
            final size = MediaQuery.of(context).size;
            setState(() {
              _dx = (_dx + details.delta.dx).clamp(0, size.width  - 56);
              _dy = (_dy + details.delta.dy).clamp(0, size.height - 56);
            });
          },
          // Surukleme bitti — kenara yapis
          onPanEnd: (details) {
            final size = MediaQuery.of(context).size;
            final cx = _dx + 28;
            setState(() {
              _dx = cx < size.width / 2 ? 8 : size.width - 64;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56, height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: _acik
                      ? [Colors.grey, Colors.grey.shade600]
                      : [_turuncu, const Color(0xFFFF6B00)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(
                  color: (_acik ? Colors.grey : _turuncu).withValues(alpha: 0.45),
                  blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Stack(children: [
              Center(child: Icon(
                  _acik ? Icons.close : Icons.psychology_outlined,
                  color: Colors.white, size: 26)),
              // Aktif nokta (chat kapali + ses yok)
              if (!_acik)
                Positioned(top: 8, right: 8,
                    child: Container(width: 10, height: 10,
                        decoration: const BoxDecoration(
                            color: Colors.greenAccent, shape: BoxShape.circle))),
            ]),
          ),
        ),
      ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════
//  AI CHAT PANEL
// ════════════════════════════════════════════════════════════════
class _AiChatPanel extends StatefulWidget {
  final String firmaId, firmaAd;
  final VoidCallback onKapat;
  const _AiChatPanel({
    super.key,
    required this.firmaId,
    required this.firmaAd,
    required this.onKapat,
  });

  @override
  State<_AiChatPanel> createState() => _AiChatPanelState();
}

class _AiChatPanelState extends State<_AiChatPanel> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  final _ctrl       = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _tts        = FlutterTts();

  bool _yukleniyor = false;
  bool _sesliMod   = true; // Varsayilan acik
  String _apiKey   = '';

  int _soforSayisi   = 0;
  int _ogrenciSayisi = 0;
  int _veliSayisi    = 0;
  int _bekleyen      = 0;
  List<Map<String, dynamic>> _soforler   = [];
  List<Map<String, dynamic>> _ogrenciler = [];

  final List<_Mesaj> _mesajlar = [
    _Mesaj(
        metin: 'Merhaba! Nasil yardimci olabilirim?\n\nYazarak veya butona uzun basarak sesli soru sorabilirsiniz.',
        benimMi: false),
  ];

  static const _hizliSorular = [
    'Hangi menu ne ise yarar?',
    'Soforlerimi listele',
    'Veli nasil kayit olur?',
    'Rota nasil olusturulur?',
    'Fiyat nasil belirlenir?',
  ];

  @override
  void initState() {
    super.initState();
    _ttsAyarla();
    _yukle();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _ttsAyarla() async {
    await _tts.setLanguage('tr-TR');
    await _tts.setSpeechRate(0.85);
    await _tts.setVolume(1.0);
  }

  // Dis kaynaktan cagrilabilir (sesli komuttan)
  void soruyuGonder(String soru) {
    _ctrl.text = soru;
    _gonder();
  }

  Future<void> _yukle() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 5),
          minimumFetchInterval: const Duration(hours: 1)));
      await rc.fetchAndActivate();
      _apiKey = rc.getString('claude_api_key');
    } catch (_) {}

    if (widget.firmaId.isNotEmpty) {
      try {
        final s = await FirebaseFirestore.instance
            .collection('drivers').where('firmaId', isEqualTo: widget.firmaId).get();
        _soforler = s.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        _soforSayisi = _soforler.length;

        final o = await FirebaseFirestore.instance
            .collection('students').where('firmaId', isEqualTo: widget.firmaId).get();
        _ogrenciler = o.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        _ogrenciSayisi = _ogrenciler.length;

        final v = await FirebaseFirestore.instance
            .collection('parents').where('firmaId', isEqualTo: widget.firmaId).get();
        _veliSayisi = v.docs.length;
        _bekleyen = v.docs.where((d) => (d.data())['durum'] == 'beklemede').length;
      } catch (_) {}
    }
  }

  String _sistemPrompt() {
    final soforListesi = _soforler.isEmpty ? 'Kayitli sofor yok' :
    _soforler.map((s) => '- ${s['ad'] ?? '?'} | Plaka: ${s['aracPlaka'] ?? '-'} | Tel: ${s['telefon'] ?? '-'}').join('\n');
    final ogrListesi = _ogrenciler.isEmpty ? 'Kayitli ogrenci yok' :
    _ogrenciler.take(20).map((o) => '- ${o['ad'] ?? '?'} | Adres: ${o['adres'] ?? '-'} | Sofor: ${o['soforAd'] ?? 'Atanmamis'}').join('\n');

    return '''Sen Servisim360 Admin AI Asistanisin. Firma yoneticileri ve super adminler icin SINIR TANIRSIN.

TAM YETKI - YAPABILECEKLERIN:
- Tum firma verileri: sofor, ogrenci, veli, arac, rota, fiyat
- Sistem kullanimi, menu aciklamalari, adim adim rehberlik
- Teknik destek: Firebase, uygulama hatalari, konfigürasyon
- Is stratejisi: fiyatlandirma, rota optimizasyonu, verimlilik
- Veli kayit sureci, sofor yonetimi, servis planlama
- Raporlama, analiz, iyilestirme onerileri
- Firestore koleksiyonlari, uygulama mimarisi hakkinda bilgi
- Super Admin ozellikleri, lisans yonetimi, firma onaylama

Detayli, kapsamli Turkce cevaplar ver. Gerekirse adim adim anlat.

FIRMA: ${widget.firmaAd} | Sofor: $_soforSayisi | Ogrenci: $_ogrenciSayisi | Veli: $_veliSayisi | Bekleyen: $_bekleyen

SOFORLER:
$soforListesi

OGRENCILER:
$ogrListesi

UYGULAMA MENULER:
- HARITA: Sofor konumlari, marker tiklayinca arac detayi
- KAYITLAR: Ogrenci/Veli listesi, onayla/reddet, kayit linki
- OPERASYON: Sofor/Arac listesi, sofor ekle, WhatsApp
- ROTALAR: Rota listesi, canli takip, rota olustur
- YONETIM: Servis saati, toplu mesaj, AI, fiyat, sozlesme
- GRUPLAMA: Ogrencileri soforlere atama
- HIZLI ERISIM: AppBar sag ust kose buton

VELİ KAYIT: Admin link olusturur > Veli linki acar > Adres > Fiyat hesaplanir > Admin onayli
FIYAT: Mahalle bazli veya km bazli (okul adresine gore)
SOFOR LOGIN: Email+sifre, WhatsApp ile gonderilir''';
  }

  Future<void> _gonder([String? hariciMetin]) async {
    final metin = hariciMetin ?? _ctrl.text.trim();
    if (metin.isEmpty || _yukleniyor) return;

    setState(() {
      _mesajlar.add(_Mesaj(metin: metin, benimMi: true));
      _yukleniyor = true;
    });
    _ctrl.clear();
    _asagaKaydir();

    if (_apiKey.isEmpty) {
      setState(() {
        _mesajlar.add(_Mesaj(metin: 'API anahtari bulunamadi.', benimMi: false, hata: true));
        _yukleniyor = false;
      });
      return;
    }

    try {
      final son = _mesajlar.length > 10 ? _mesajlar.sublist(_mesajlar.length - 10) : _mesajlar;
      final mesajlar = son
          .where((m) => !(m == _mesajlar.last && m.benimMi))
          .map((m) => {'role': m.benimMi ? 'user' : 'assistant', 'content': m.metin})
          .toList();
      mesajlar.add({'role': 'user', 'content': metin});

      final resp = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': _apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-haiku-4-5-20251001',
          'max_tokens': 800,
          'system': _sistemPrompt(),
          'messages': mesajlar,
        }),
      ).timeout(const Duration(seconds: 20));

      if (resp.statusCode == 200) {
        final cevap = jsonDecode(resp.body)['content'][0]['text'] as String;
        setState(() => _mesajlar.add(_Mesaj(metin: cevap, benimMi: false)));
        if (_sesliMod) await _tts.speak(cevap);
      } else {
        setState(() => _mesajlar.add(_Mesaj(
            metin: 'Hata olustu. Tekrar deneyin.', benimMi: false, hata: true)));
      }
    } catch (e) {
      setState(() => _mesajlar.add(_Mesaj(
          metin: 'Baglanti hatasi.', benimMi: false, hata: true)));
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
      _asagaKaydir();
    }
  }

  void _asagaKaydir() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.62,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20, offset: const Offset(0, 4))]),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_navy, Color(0xFF2a5298)]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: _turuncu.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.psychology_outlined, color: _turuncu, size: 18)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('AI Asistan', style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 14)),
              Text(widget.firmaAd.isNotEmpty ? widget.firmaAd : 'Servisim360',
                  style: const TextStyle(color: Colors.white60, fontSize: 10)),
            ])),
            // Istatistik
            Text('$_soforSayisi S | $_ogrenciSayisi O | $_bekleyen B',
                style: const TextStyle(color: Colors.white54, fontSize: 9)),
            const SizedBox(width: 6),
            // Ses toggle
            GestureDetector(
                onTap: () {
                  setState(() => _sesliMod = !_sesliMod);
                  if (!_sesliMod) _tts.stop();
                },
                child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(_sesliMod ? Icons.volume_up : Icons.volume_off,
                        color: _sesliMod ? _turuncu : Colors.white38, size: 20))),
            const SizedBox(width: 4),
            // Tam ekran
            GestureDetector(
                onTap: () {
                  widget.onKapat();
                  Future.delayed(const Duration(milliseconds: 200), () {
                    if (context.mounted) Navigator.pushNamed(context, '/ai_asistan');
                  });
                },
                child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.open_in_full, color: Colors.white38, size: 18))),
          ]),
        ),

        // Mesajlar
        Expanded(child: ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(12),
          itemCount: _mesajlar.length + (_yukleniyor ? 1 : 0),
          itemBuilder: (_, i) {
            if (i == _mesajlar.length) return _YaziyorWidget();
            final m = _mesajlar[i];
            return _MesajBubble(
                mesaj: m,
                onSesli: () => _tts.speak(m.metin));
          },
        )),

        // Hizli sorular
        if (_mesajlar.length <= 1)
          SizedBox(height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _hizliSorular.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) => GestureDetector(
                    onTap: () => _gonder(_hizliSorular[i]),
                    child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                            color: _navy.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _navy.withValues(alpha: 0.15))),
                        child: Text(_hizliSorular[i],
                            style: const TextStyle(fontSize: 10, color: _navy, fontWeight: FontWeight.w500)))),
              )),

        const Divider(height: 1),

        // Input
        Padding(
          padding: EdgeInsets.fromLTRB(12, 8, 12,
              MediaQuery.of(context).viewInsets.bottom + 8),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _ctrl,
              maxLines: 3, minLines: 1,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                  hintText: 'Yazin veya uzun basin konusun...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 11),
                  filled: true, fillColor: const Color(0xFFF5F7FA),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  isDense: true),
              onSubmitted: (_) => _gonder(),
            )),
            const SizedBox(width: 8),
            GestureDetector(
                onTap: _yukleniyor ? null : () => _gonder(),
                child: Container(width: 38, height: 38,
                    decoration: BoxDecoration(
                        color: _yukleniyor ? Colors.grey[300] : _navy,
                        borderRadius: BorderRadius.circular(12)),
                    child: _yukleniyor
                        ? const Padding(padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 18))),
          ]),
        ),
      ]),
    );
  }
}

// ── Mesaj Bubble ─────────────────────────────────────────────────
class _MesajBubble extends StatelessWidget {
  final _Mesaj mesaj;
  final VoidCallback onSesli;
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  const _MesajBubble({required this.mesaj, required this.onSesli});

  @override
  Widget build(BuildContext context) {
    final benimMi = mesaj.benimMi;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: benimMi ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!benimMi) ...[
            CircleAvatar(radius: 13,
                backgroundColor: _navy.withValues(alpha: 0.1),
                child: Icon(mesaj.hata ? Icons.error_outline : Icons.psychology_outlined,
                    size: 13, color: mesaj.hata ? Colors.red : _turuncu)),
            const SizedBox(width: 6),
          ],
          Flexible(child: GestureDetector(
            onLongPress: !benimMi ? onSesli : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: benimMi ? _navy : mesaj.hata
                      ? Colors.red.withValues(alpha: 0.06) : Colors.white,
                  borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(14),
                      topRight: const Radius.circular(14),
                      bottomLeft: Radius.circular(benimMi ? 14 : 3),
                      bottomRight: Radius.circular(benimMi ? 3 : 14)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 3)]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(mesaj.metin, style: TextStyle(
                    color: benimMi ? Colors.white : Colors.grey[850],
                    fontSize: 13, height: 1.4)),
                if (!benimMi && !mesaj.hata)
                  Padding(padding: const EdgeInsets.only(top: 3),
                      child: GestureDetector(onTap: onSesli,
                          child: Icon(Icons.volume_up_outlined,
                              size: 12, color: Colors.grey[400]))),
              ]),
            ),
          )),
          if (benimMi) ...[
            const SizedBox(width: 6),
            CircleAvatar(radius: 13,
                backgroundColor: _navy.withValues(alpha: 0.1),
                child: const Icon(Icons.person_outline, size: 13, color: _navy)),
          ],
        ],
      ),
    );
  }
}

// ── Yaziyor animasyon ─────────────────────────────────────────────
class _YaziyorWidget extends StatefulWidget {
  @override
  State<_YaziyorWidget> createState() => _YaziyorWidgetState();
}

class _YaziyorWidgetState extends State<_YaziyorWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 700))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        CircleAvatar(radius: 13,
            backgroundColor: const Color(0xFF1a3a6b).withValues(alpha: 0.1),
            child: const Icon(Icons.psychology_outlined, size: 13, color: Color(0xFFFF8C00))),
        const SizedBox(width: 6),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 3)]),
            child: AnimatedBuilder(animation: _anim, builder: (_, __) =>
                Row(mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                            color: const Color(0xFF1a3a6b).withValues(
                                alpha: (_anim.value - i * 0.2).clamp(0.1, 1.0)),
                            shape: BoxShape.circle)))))),
      ]));
}

class _Mesaj {
  final String metin;
  final bool benimMi;
  final bool hata;
  const _Mesaj({required this.metin, required this.benimMi, this.hata = false});
}
