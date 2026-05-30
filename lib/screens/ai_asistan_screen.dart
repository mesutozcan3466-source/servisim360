import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_tts/flutter_tts.dart';

class AiAsistanScreen extends StatefulWidget {
  const AiAsistanScreen({super.key});
  @override
  State<AiAsistanScreen> createState() => _AiAsistanScreenState();
}

class _AiAsistanScreenState extends State<AiAsistanScreen> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  static const _proxyUrl =
      'https://us-central1-servis360-15b4a.cloudfunctions.net/aiProxy';

  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _odakNode   = FocusNode();
  final List<_Mesaj> _mesajlar = [];
  final _tts = FlutterTts();

  bool   _sesliMod   = false;
  bool   _yukleniyor = false;
  String _firmaId    = '';
  String _firmaAdi   = '';

  int _soforSayisi     = 0;
  int _ogrenciSayisi   = 0;
  int _veliSayisi      = 0;
  int _bekleyenBasvuru = 0;
  List<Map<String, dynamic>> _soforler   = [];
  List<Map<String, dynamic>> _ogrenciler = [];

  @override
  void initState() {
    super.initState();
    _ttsAyarla();
    _yukle();
  }

  Future<void> _ttsAyarla() async {
    await _tts.setLanguage('tr-TR');
    await _tts.setSpeechRate(0.85);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    _odakNode.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _yukle() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance
          .collection('kullanicilar').doc(uid).get();
      _firmaId = doc.data()?['firmaId'] ?? '';
    }

    if (_firmaId.isNotEmpty) {
      final firmaDoc = await FirebaseFirestore.instance
          .collection('firms').doc(_firmaId).get();
      _firmaAdi = firmaDoc.data()?['firmaAdi'] ??
          firmaDoc.data()?['ad'] ?? '';

      final soforSnap = await FirebaseFirestore.instance
          .collection('drivers')
          .where('firmaId', isEqualTo: _firmaId).get();
      _soforler = soforSnap.docs
          .map((d) => {'id': d.id, ...d.data()}).toList();
      _soforSayisi = _soforler.length;

      final ogrSnap = await FirebaseFirestore.instance
          .collection('students')
          .where('firmaId', isEqualTo: _firmaId).get();
      _ogrenciler = ogrSnap.docs
          .map((d) => {'id': d.id, ...d.data()}).toList();
      _ogrenciSayisi = _ogrenciler.length;

      final veliSnap = await FirebaseFirestore.instance
          .collection('parents')
          .where('firmaId', isEqualTo: _firmaId).get();
      _veliSayisi = veliSnap.docs.length;
      _bekleyenBasvuru = veliSnap.docs
          .where((d) => d.data()['durum'] == 'beklemede')
          .length;
    }

    if (mounted) {
      setState(() {
        _mesajlar.add(_Mesaj(
          metin: 'Merhaba! Ben Servisim360 AI Asistaniyim\n\n'
              '${_firmaAdi.isNotEmpty ? "$_firmaAdi firmasinin" : "Firmanizin"} '
              'verilerine erisimim var. Size nasil yardimci olabilirim?\n\n'
              'Yapabileceklerim:\n'
              '- Sofor, veli, ogrenci bilgileri\n'
              '- Rota planlama ve optimizasyon\n'
              '- Ogrenci atama onerileri\n'
              '- Sistem kullanimi rehberligi',
          benimMi: false,
          zaman: DateTime.now(),
        ));
      });
    }
  }

  String _sistemPrompt() {
    final soforListesi = _soforler.isEmpty
        ? 'Sofor yok'
        : _soforler.map((s) =>
    '- ${s['ad'] ?? 'Isimsiz'} | '
        'Plaka: ${s['aracPlaka'] ?? '-'} | '
        'Tel: ${s['telefon'] ?? '-'}').join('\n');

    final ogrListesi = _ogrenciler.isEmpty
        ? 'Ogrenci yok'
        : _ogrenciler.take(30).map((o) =>
    '- ${o['ad'] ?? 'Isimsiz'} | '
        'Adres: ${o['adres'] ?? '-'} | '
        'Sofor: ${o['soforAd'] ?? 'Atanmamis'}').join('\n');

    return '''Sen Servisim360 AI Asistanisin. Turkiye okul servis yonetim sistemi.

FIRMA: $_firmaAdi | ID: $_firmaId
Sofor: $_soforSayisi | Ogrenci: $_ogrenciSayisi | Veli: $_veliSayisi | Bekleyen: $_bekleyenBasvuru

SOFORLER:
$soforListesi

OGRENCILER:
$ogrListesi

GOREVLERIN:
- Turkce, samimi, kisa cevaplar ver
- Firma verilerini kullanarak kisisellestir
- Rota optimizasyonu: yakin ogrencileri grupla
- Hangi menu ne ise yarar acikla
- Adim adim rehberlik yap
''';
  }

  Future<void> _gonder() async {
    final metin = _controller.text.trim();
    if (metin.isEmpty || _yukleniyor) return;

    setState(() {
      _mesajlar.add(_Mesaj(
          metin: metin, benimMi: true, zaman: DateTime.now()));
      _yukleniyor = true;
    });
    _controller.clear();
    _asagaKaydir();

    try {
      final son = _mesajlar.length > 12
          ? _mesajlar.sublist(_mesajlar.length - 12)
          : _mesajlar;

      final mesajlar = son
          .where((m) => !(m == _mesajlar.last && m.benimMi))
          .map((m) => {
        'role':    m.benimMi ? 'user' : 'assistant',
        'content': m.metin,
      })
          .toList();
      mesajlar.add({'role': 'user', 'content': metin});

      final response = await http.post(
        Uri.parse(_proxyUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model':      'claude-haiku-4-5-20251001',
          'max_tokens': 1500,
          'system':     _sistemPrompt(),
          'messages':   mesajlar,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data  = jsonDecode(response.body);
        final cevap = data['content'][0]['text'] as String;
        setState(() => _mesajlar.add(
            _Mesaj(metin: cevap, benimMi: false, zaman: DateTime.now())));
        if (_sesliMod) await _tts.speak(cevap);
      } else {
        final err = jsonDecode(response.body);
        _hataEkle('API Hatasi (${response.statusCode}): '
            '${err['error']?['message'] ?? 'Bilinmeyen hata'}');
      }
    } catch (e) {
      _hataEkle('Baglanti hatasi: $e');
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
      _asagaKaydir();
    }
  }

  void _hataEkle(String hata) {
    if (!mounted) return;
    setState(() => _mesajlar.add(_Mesaj(
        metin: 'Hata: $hata\n\nLutfen tekrar deneyin.',
        benimMi: false,
        zaman: DateTime.now(),
        hata: true)));
  }

  void _asagaKaydir() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut);
      }
    });
  }

  void _temizle() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Sohbeti Temizle'),
        content: const Text('Tum mesajlar silinecek. Emin misin?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Iptal')),
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _mesajlar.clear());
                _yukle();
              },
              child: const Text('Temizle',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  static const _oneriler = [
    'Rota nasil optimize edilir?',
    'Ogrencileri soforlere nasil atayabilirim?',
    'Velilere kayit linki nasil gonderirim?',
    'Sofor bilgilerini goster',
    'Atanmamis ogrenciler var mi?',
    'Bekleyen basvurulari nasil onaylayabilirim?',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: _turuncu.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.psychology_outlined,
                color: _turuncu, size: 20),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI Asistan',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                Text(_firmaAdi.isNotEmpty ? _firmaAdi : 'Servisim360',
                    style: const TextStyle(
                        fontSize: 10, color: Colors.white60)),
              ]),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () async {
              setState(() => _mesajlar.clear());
              await _yukle();
            },
          ),
          IconButton(
            icon: Icon(
                _sesliMod ? Icons.volume_up : Icons.volume_off,
                color: _sesliMod ? _turuncu : Colors.white54),
            onPressed: () {
              setState(() => _sesliMod = !_sesliMod);
              if (!_sesliMod) _tts.stop();
            },
          ),
          if (_mesajlar.length > 1)
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.white70),
              onPressed: _temizle,
            ),
        ],
      ),
      body: Column(children: [
        // Stats
        if (_firmaId.isNotEmpty)
          Container(
            color: _navy.withValues(alpha: 0.05),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 6),
            child: Row(children: [
              _StatBant('$_soforSayisi', 'Sofor',
                  Icons.directions_bus, Colors.blue),
              _StatBant('$_ogrenciSayisi', 'Ogrenci',
                  Icons.school, Colors.green),
              _StatBant('$_veliSayisi', 'Veli',
                  Icons.family_restroom, Colors.purple),
              if (_bekleyenBasvuru > 0)
                _StatBant('$_bekleyenBasvuru', 'Bekleyen',
                    Icons.pending_actions, Colors.orange),
            ]),
          ),

        // Mesajlar
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.all(16),
            itemCount: _mesajlar.length + (_yukleniyor ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == _mesajlar.length) return _YaziyorBubble();
              return _MesajBalonu(mesaj: _mesajlar[i]);
            },
          ),
        ),

        // Hizli sorular
        if (_mesajlar.length <= 1)
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _oneriler.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ActionChip(
                label: Text(_oneriler[i],
                    style: const TextStyle(fontSize: 11)),
                backgroundColor: Colors.white,
                side: BorderSide(
                    color: _navy.withValues(alpha: 0.2)),
                onPressed: () {
                  _controller.text = _oneriler[i];
                  _gonder();
                },
              ),
            ),
          ),

        // Input
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, -2))],
          ),
          child: SafeArea(
            top: false,
            child: Row(children: [
              Expanded(child: TextField(
                controller: _controller,
                focusNode: _odakNode,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Sorunuzu yazin...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: const Color(0xFFF5F7FA),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _gonder(),
              )),
              const SizedBox(width: 8),
              Material(
                color: _yukleniyor ? Colors.grey[300] : _navy,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _yukleniyor ? null : _gonder,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── Yardimci Widget'lar ────────────────────────────────────────
class _StatBant extends StatelessWidget {
  final String deger, etiket;
  final IconData ikon;
  final Color renk;
  const _StatBant(this.deger, this.etiket, this.ikon, this.renk);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(ikon, size: 12, color: renk),
        const SizedBox(width: 3),
        Text(deger, style: TextStyle(
            color: renk, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(width: 2),
        Text(etiket, style: TextStyle(color: renk, fontSize: 9)),
      ],
    ),
  );
}

class _MesajBalonu extends StatelessWidget {
  final _Mesaj mesaj;
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  const _MesajBalonu({required this.mesaj});

  @override
  Widget build(BuildContext context) {
    final benimMi = mesaj.benimMi;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: benimMi
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!benimMi) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: mesaj.hata
                  ? Colors.red.withValues(alpha: 0.1)
                  : _navy.withValues(alpha: 0.1),
              child: Icon(
                  mesaj.hata
                      ? Icons.error_outline
                      : Icons.psychology_outlined,
                  size: 16,
                  color: mesaj.hata ? Colors.red : _turuncu),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: benimMi
                    ? _navy
                    : mesaj.hata
                    ? Colors.red.withValues(alpha: 0.08)
                    : Colors.white,
                borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(benimMi ? 18 : 4),
                    bottomRight: Radius.circular(benimMi ? 4 : 18)),
                boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mesaj.metin,
                      style: TextStyle(
                          color: benimMi
                              ? Colors.white
                              : Colors.grey[850],
                          fontSize: 14,
                          height: 1.5)),
                  if (!benimMi && !mesaj.hata)
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => FlutterTts().speak(mesaj.metin),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Icon(Icons.volume_up_outlined,
                              size: 14, color: Colors.grey[400]),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (benimMi) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: _navy.withValues(alpha: 0.1),
              child: const Icon(Icons.person_outline,
                  size: 16, color: _navy),
            ),
          ],
        ],
      ),
    );
  }
}

class _YaziyorBubble extends StatefulWidget {
  @override
  State<_YaziyorBubble> createState() => _YaziyorBubbleState();
}

class _YaziyorBubbleState extends State<_YaziyorBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      CircleAvatar(
        radius: 16,
        backgroundColor: const Color(0xFF1a3a6b).withValues(alpha: 0.1),
        child: const Icon(Icons.psychology_outlined,
            size: 16, color: Color(0xFFFF8C00)),
      ),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomRight: Radius.circular(18),
              bottomLeft: Radius.circular(4)),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4)],
        ),
        child: AnimatedBuilder(
          animation: _anim,
          builder: (_, __) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3,
                    (i) => _Nokta(gecikme: i * 0.2, anim: _anim)),
          ),
        ),
      ),
    ]),
  );
}

class _Nokta extends StatelessWidget {
  final double gecikme;
  final Animation<double> anim;
  const _Nokta({required this.gecikme, required this.anim});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 2),
    width: 8, height: 8,
    decoration: BoxDecoration(
        color: const Color(0xFF1a3a6b).withValues(
            alpha: (anim.value - gecikme).clamp(0.1, 1.0)),
        shape: BoxShape.circle),
  );
}

class _Mesaj {
  final String metin;
  final bool benimMi;
  final DateTime zaman;
  final bool hata;
  const _Mesaj({
    required this.metin,
    required this.benimMi,
    required this.zaman,
    this.hata = false,
  });
}