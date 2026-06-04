// ╔══════════════════════════════════════════════════════════════╗
// ║  DOSYA: lib/screens/ai_widget.dart
// ║  Her ekrana gömülebilen bağlamsal AI asistan widget'ı
// ║  Ekrana özel sorular + sesli cevap + tam asistana yönlendirme
// ╚══════════════════════════════════════════════════════════════╝
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ════════════════════════════════════════════════════════════════
// AI ASISTAN BUTONU — AppBar'a eklenir
// ════════════════════════════════════════════════════════════════
class AiAsistanButonu extends StatelessWidget {
  final String ekranAdi;
  final Map<String, String> baglamVerisi;

  const AiAsistanButonu({
    super.key,
    required this.ekranAdi,
    this.baglamVerisi = const {},
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Stack(children: [
        const Icon(Icons.auto_awesome_rounded, color: Colors.white),
        Positioned(
          right: 0, top: 0,
          child: Container(
            width: 7, height: 7,
            decoration: const BoxDecoration(
                color: Color(0xFFFF8C00), shape: BoxShape.circle),
          ),
        ),
      ]),
      tooltip: 'AI Asistan',
      onPressed: () => AiPanel.goster(context, ekranAdi, baglamVerisi),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// AI PANEL — BottomSheet olarak açılır
// ════════════════════════════════════════════════════════════════
class AiPanel {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  static const _proxy   =
      'https://us-central1-servis360-15b4a.cloudfunctions.net/aiProxy';

  static void goster(BuildContext context, String ekranAdi,
      Map<String, String> baglamVerisi) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AiPanelIcerik(
          ekranAdi: ekranAdi, baglamVerisi: baglamVerisi),
    );
  }
}

class _AiPanelIcerik extends StatefulWidget {
  final String ekranAdi;
  final Map<String, String> baglamVerisi;
  const _AiPanelIcerik(
      {required this.ekranAdi, required this.baglamVerisi});
  @override
  State<_AiPanelIcerik> createState() => _AiPanelIcerikState();
}

class _AiPanelIcerikState extends State<_AiPanelIcerik> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  final _ctrl     = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _tts      = FlutterTts();
  final List<Map<String, dynamic>> _mesajlar = [];
  bool _yukleniyor = false;
  bool _sesliMod   = false;

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('tr-TR');
    _tts.setSpeechRate(0.85);
    // Karşılama mesajı
    _mesajlar.add({
      'metin' : _karsilamaMesaji(),
      'benimMi': false,
    });
  }

  @override
  void dispose() {
    _ctrl.dispose(); _scrollCtrl.dispose(); _tts.stop(); super.dispose();
  }

  String _karsilamaMesaji() {
    final sorular = _ekranSorulari[widget.ekranAdi] ??
        _ekranSorulari['Genel']!;
    return '${widget.ekranAdi} ekranındasınız. Size nasıl yardımcı olabilirim?\n\n'
        'Hızlı sorular:\n${sorular.map((s) => '• $s').join('\n')}';
  }

  // ── Ekrana özel hızlı sorular ──────────────────────────────────
  static const Map<String, List<String>> _ekranSorulari = {
    'Servisler': [
      'Servis nasıl eklerim?',
      'Şoförü projeye nasıl atarım?',
      'Şoför giriş bilgilerini nasıl gönderirim?',
    ],
    'Kayitlar': [
      'Yüz yüze kayıt nasıl yapılır?',
      'Veli kayıt linkini nasıl oluştururum?',
      'Öğrenciyi servise nasıl atarım?',
    ],
    'Harita': [
      '17 öğrenciyi en kısa rotada nasıl sıralarım?',
      'Şoförün konumu neden görünmüyor?',
      'Uydu görünümüne nasıl geçerim?',
    ],
    'Rotalar': [
      'Akşam rotası neden otomatik tersine dönüyor?',
      'Atamasız öğrencileri nasıl servise eklerim?',
      'Rota sırasını değiştirebilir miyim?',
    ],
    'Sozlesmeler': [
      'Proje için sözleşme şablonu nasıl oluştururum?',
      'Firma bilgilerini sözleşmeye nasıl eklerim?',
      'PDF oluşturup veliye nasıl gönderirim?',
    ],
    'Fiyatlandirma': [
      'Mahalle bazlı fiyat nasıl tanımlarım?',
      'Km bazlı fiyat hesaplama nasıl çalışır?',
      'Veli adres girince fiyat otomatik çıkmıyor, neden?',
    ],
    'Projeler': [
      'Yeni proje nasıl oluştururum?',
      'Farklı okul için ayrı proje mi açmalıyım?',
      'Projeye sözleşme şablonu nasıl atarım?',
    ],
    'Raporlar': [
      'Excel raporu nasıl alırım?',
      'Devamsızlık raporunu nasıl görürüm?',
      'Şoför listesini nasıl kopyalarım?',
    ],
    'Arsiv': [
      'İmzalanan sözleşme neden silinemiyor?',
      'Sözleşmeyi arşive nasıl kaldırırım?',
      'Proje dosyalarına nasıl erişirim?',
    ],
    'Sofor Paneli': [
      'Servisi nasıl başlatırım?',
      'Öğrenci bindi bilgisini nasıl kaydederim?',
      'Navigasyonu nasıl açarım?',
    ],
    'Veli Paneli': [
      'Çocuğumun servisini nasıl takip ederim?',
      'Devamsızlık bildirimi nasıl gönderirim?',
      'Şoförle nasıl iletişim kurarım?',
    ],
    'Ana Ekran': [
      'Sisteme nereden başlamalıyım?',
      'Proje seçimi neden önemli?',
      'İstatistik kartları ne anlama geliyor?',
    ],
    'Genel': [
      'Nasıl yardımcı olabilirim?',
      'Hangi menü ne işe yarar?',
      'Adım adım rehberlik alabilir miyim?',
    ],
  };

  String _sistemPrompt() {
    final baglamMetni = widget.baglamVerisi.entries
        .map((e) => '${e.key}: ${e.value}')
        .join('\n');

    return '''Sen Servisim360 uygulamasının yapay zeka asistanısın.
Kullanici su anda "${widget.ekranAdi}" ekraninda.

${baglamMetni.isNotEmpty ? 'EKRAN BAGLAMI:\n$baglamMetni\n' : ''}

GOREVLERIN:
- Kisa, net, Turkce cevaplar ver (max 150 kelime)
- "${widget.ekranAdi}" ekranina ozel adim adim rehberlik yap
- Rota optimizasyonu sorularinda: en yakin komsuy algoritmasi
- Sofor sorularinda: panel kullanimi, bindi kaydi, devamsizlik
- Harita sorularinda: uydu toggle, konum sorunu, siralamayi acikla
- Sözlesme sorularinda: sablon olusturma, proje atama, PDF gonderme
- Emoji kullan, samimi ol ama profesyonel kal
- Cevap sonuna ilgili bir ipucu ekle 💡''';
  }

  Future<void> _gonder([String? hazirSoru]) async {
    final metin = hazirSoru ?? _ctrl.text.trim();
    if (metin.isEmpty || _yukleniyor) return;

    setState(() {
      _mesajlar.add({'metin': metin, 'benimMi': true});
      _yukleniyor = true;
    });
    _ctrl.clear();
    _asagaKaydir();

    try {
      final mesajlar = _mesajlar
          .where((m) => m['benimMi'] == true || m['benimMi'] == false)
          .skip(1) // karşılama mesajını atla
          .map((m) => {
        'role'   : m['benimMi'] ? 'user' : 'assistant',
        'content': m['metin'],
      }).toList();

      final response = await http.post(
        Uri.parse(AiPanel._proxy),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model'    : 'claude-haiku-4-5-20251001',
          'max_tokens': 800,
          'system'   : _sistemPrompt(),
          'messages' : mesajlar,
        }),
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final data  = jsonDecode(response.body);
        final cevap = data['content'][0]['text'] as String;
        setState(() {
          _mesajlar.add({'metin': cevap, 'benimMi': false});
          _yukleniyor = false;
        });
        if (_sesliMod) await _tts.speak(cevap);
        _asagaKaydir();
      } else {
        _hataEkle('Bağlanamadım. Tekrar deneyin.');
      }
    } catch (e) {
      _hataEkle('Hata: $e');
    }
  }

  void _hataEkle(String mesaj) {
    setState(() {
      _mesajlar.add({'metin': mesaj, 'benimMi': false, 'hata': true});
      _yukleniyor = false;
    });
  }

  void _asagaKaydir() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(children: [
        // Tutamaç
        Container(margin: const EdgeInsets.only(top: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2))),

        // Başlık
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF1a3a6b), Color(0xFF2d5a9e)]),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Text('AI Asistan',
                  style: TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 15, color: _navy)),
              Text(widget.ekranAdi,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ])),

            // Sesli mod toggle
            GestureDetector(
              onTap: () {
                setState(() => _sesliMod = !_sesliMod);
                if (!_sesliMod) _tts.stop();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: _sesliMod
                        ? _turuncu.withValues(alpha: 0.1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _sesliMod
                            ? _turuncu.withValues(alpha: 0.4)
                            : Colors.grey.shade200)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_sesliMod
                      ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                      color: _sesliMod ? _turuncu : Colors.grey, size: 14),
                  const SizedBox(width: 4),
                  Text(_sesliMod ? 'Sesli' : 'Sessiz',
                      style: TextStyle(fontSize: 10,
                          color: _sesliMod ? _turuncu : Colors.grey,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
            const SizedBox(width: 6),

            // Tam asistana git
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/ai_asistan');
              },
              icon: const Icon(Icons.open_in_full_rounded, size: 13),
              label: const Text('Tam', style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(
                  foregroundColor: _navy,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
            ),

            IconButton(icon: const Icon(Icons.close_rounded, color: Colors.grey),
                onPressed: () { _tts.stop(); Navigator.pop(context); }),
          ]),
        ),

        const Divider(height: 12),

        // Mesaj listesi
        Expanded(child: ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          itemCount: _mesajlar.length + (_yukleniyor ? 1 : 0),
          itemBuilder: (_, i) {
            if (i == _mesajlar.length) {
              return _YaziyorGostergesi();
            }
            final m = _mesajlar[i];
            return _MesajBalonu(
              metin: m['metin'],
              benimMi: m['benimMi'],
              hata: m['hata'] ?? false,
              onHizliSoru: i == 0 ? (s) => _gonder(s) : null,
              ekranAdi: widget.ekranAdi,
            );
          },
        )),

        // Hızlı soru butonları
        if (_mesajlar.length <= 2)
          _HizliSorular(
            sorular: _AiPanelIcerikState._ekranSorulari[widget.ekranAdi] ??
                _AiPanelIcerikState._ekranSorulari['Genel']!,
            onTap: _gonder,
          ),

        // Giriş alanı
        Container(
          padding: EdgeInsets.fromLTRB(12, 8, 12,
              MediaQuery.of(context).viewInsets.bottom + 12),
          decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade100))),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _ctrl,
              onSubmitted: (_) => _gonder(),
              decoration: InputDecoration(
                hintText: '${widget.ekranAdi} hakkında soru sor...',
                hintStyle: const TextStyle(fontSize: 13),
                filled: true, fillColor: const Color(0xFFF5F7FA),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
            )),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _gonder(),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF1a3a6b), Color(0xFF2d5a9e)]),
                    borderRadius: BorderRadius.circular(20)),
                child: _yukleniyor
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 18),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Mesaj balonu ──────────────────────────────────────────────
class _MesajBalonu extends StatelessWidget {
  final String metin;
  final bool benimMi, hata;
  final Function(String)? onHizliSoru;
  final String ekranAdi;

  const _MesajBalonu({
    required this.metin, required this.benimMi,
    this.hata = false, this.onHizliSoru, required this.ekranAdi,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: benimMi
            ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!benimMi) ...[
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF1a3a6b), Color(0xFF2d5a9e)]),
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 12),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: benimMi
                    ? const Color(0xFF1a3a6b)
                    : hata ? Colors.red.shade50 : const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(benimMi ? 16 : 4),
                    bottomRight: Radius.circular(benimMi ? 4 : 16))),
            child: Text(metin, style: TextStyle(
                fontSize: 13, height: 1.5,
                color: benimMi ? Colors.white
                    : hata ? Colors.red : Colors.black87)),
          )),
        ],
      ),
    );
  }
}

// ── Yazıyor göstergesi ────────────────────────────────────────
class _YaziyorGostergesi extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF1a3a6b), Color(0xFF2d5a9e)]),
              borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.auto_awesome_rounded,
              color: Colors.white, size: 12),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(16)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            _Nokta(delay: 0),
            SizedBox(width: 4),
            _Nokta(delay: 150),
            SizedBox(width: 4),
            _Nokta(delay: 300),
          ]),
        ),
      ]),
    );
  }
}

class _Nokta extends StatefulWidget {
  final int delay;
  const _Nokta({required this.delay});
  @override
  State<_Nokta> createState() => _NoktaState();
}

class _NoktaState extends State<_Nokta>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _opAnim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _opAnim = Tween(begin: 0.3, end: 1.0).animate(_anim);
    Future.delayed(Duration(milliseconds: widget.delay),
        () { if (mounted) _anim.forward(); });
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opAnim,
      child: Container(width: 6, height: 6,
          decoration: const BoxDecoration(
              color: Color(0xFF1a3a6b), shape: BoxShape.circle)),
    );
  }
}

// ── Hızlı sorular ─────────────────────────────────────────────
class _HizliSorular extends StatelessWidget {
  final List<String> sorular;
  final Function(String) onTap;
  const _HizliSorular({required this.sorular, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sorular.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => onTap(sorular[i]),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: const Color(0xFFFF8C00).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFFFF8C00).withValues(alpha: 0.3))),
            child: Text(sorular[i], style: const TextStyle(
                fontSize: 11, color: Color(0xFFFF8C00),
                fontWeight: FontWeight.w500)),
          ),
        ),
      ),
    );
  }
}
