import 'package:flutter/material.dart';
import 'yardim_widget.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/session_service.dart';

// ════════════════════════════════════════════════════════════════
//  TOPLU WHATSAPP EKRANI
//  - Sistemdeki veliler listelenir + secilir
//  - Manuel numara kutusu eklenebilir (tek tek veya virgülle toplu)
//  - Mesaj yazılır, seçilen herkese WhatsApp açılır
// ════════════════════════════════════════════════════════════════
class TopluWhatsappScreen extends StatefulWidget {
  const TopluWhatsappScreen({super.key});
  @override
  State<TopluWhatsappScreen> createState() => _TopluWhatsappScreenState();
}

class _TopluWhatsappScreenState extends State<TopluWhatsappScreen>
    with SingleTickerProviderStateMixin {
  static const _navy  = Color(0xFF1a3a6b);
  static const _green = Color(0xFF25D366);
  static const _orange = Color(0xFFFF8C00);

  late TabController _tab;

  // Mesaj
  final _mesajCtrl = TextEditingController();

  // Sistem velileri
  List<Map<String, dynamic>> _veliler  = [];
  List<String> _seciliVeli = [];
  bool _yukleniyor  = true;
  bool _tumSecili   = false;
  String _filtre    = 'hepsi';

  // Manuel numaralar — her biri bir kutucuk
  final List<String> _manuelNumaralar = [];
  final _manuelCtrl = TextEditingController();

  // İlerleme
  bool _gonderiyor  = false;
  int  _gonderilen  = 0;
  int  _toplam      = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _yukle();
    _mesajCtrl.text =
    'Sayin Velimiz,\n\nServisimizle ilgili onemli bir duyurumuz bulunmaktadir.\n\nLutfen uygulamayi kontrol edin.\n\nServisim360';
  }

  @override
  void dispose() {
    _tab.dispose();
    _mesajCtrl.dispose();
    _manuelCtrl.dispose();
    super.dispose();
  }

  // ── Sistem velilerini yükle ──
  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final projeId = SessionService.instance.aktifProjeld ?? '';
      final firmaId = await SessionService.instance.firmaIdAl() ?? '';
      var q = projeId.isNotEmpty
          ? FirebaseFirestore.instance.collection('parents').where('projeId', isEqualTo: projeId)
          : FirebaseFirestore.instance.collection('parents').where('firmaId', isEqualTo: firmaId);
      final snap = await q.get();
      setState(() {
        _veliler    = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        _yukleniyor = false;
      });
    } catch (_) { setState(() => _yukleniyor = false); }
  }

  // ── Filtre ──
  List<Map<String, dynamic>> get _filtrelenmis {
    if (_filtre == 'onayli')    return _veliler.where((v) => v['durum'] == 'onayli').toList();
    if (_filtre == 'beklemede') return _veliler.where((v) => v['durum'] == 'beklemede').toList();
    return _veliler;
  }

  void _tumunuSec() {
    setState(() {
      _tumSecili = !_tumSecili;
      _seciliVeli = _tumSecili
          ? _filtrelenmis.where((v) => _telAl(v).isNotEmpty).map((v) => v['id'] as String).toList()
          : [];
    });
  }

  String _telAl(Map<String, dynamic> v) =>
      (v['telefon'] ?? v['tel'] ?? v['veliTel'] ?? '').toString().trim();

  // ── Manuel numara kutucukları ──
  void _manuelEkle(String raw) {
    // Virgülle toplu girişi destekle
    final parcalar = raw.split(RegExp(r'[,;\n\s]+'))
        .map((s) => s.trim().replaceAll(RegExp(r'[^\d+]'), ''))
        .where((s) => s.length >= 10)
        .toList();
    for (final tel in parcalar) {
      if (!_manuelNumaralar.contains(tel)) {
        setState(() => _manuelNumaralar.add(tel));
      }
    }
    _manuelCtrl.clear();
  }

  void _manuelKaldir(int idx) => setState(() => _manuelNumaralar.removeAt(idx));

  // ── Gönder ──
  Future<void> _gonder() async {
    if (_mesajCtrl.text.trim().isEmpty) {
      _snack('Mesaj bos olamaz!', Colors.orange); return;
    }
    final secilenVeliler = _veliler.where((v) => _seciliVeli.contains(v['id'])).toList();
    final tumNumaralar = [
      ...secilenVeliler.map(_telAl).where((t) => t.isNotEmpty),
      ..._manuelNumaralar,
    ];
    if (tumNumaralar.isEmpty) {
      _snack('En az 1 numara secin veya girin!', Colors.orange); return;
    }

    setState(() { _gonderiyor = true; _gonderilen = 0; _toplam = tumNumaralar.length; });

    for (final tel in tumNumaralar) {
      var numara = tel.replaceAll(RegExp(r'[^\d]'), '');
      if (numara.startsWith('0')) numara = '9$numara';
      if (!numara.startsWith('90')) numara = '90$numara';
      final msg = Uri.encodeComponent(_mesajCtrl.text.trim());
      try {
        final url = Uri.parse('https://wa.me/$numara?text=$msg');
        await launchUrl(url, mode: LaunchMode.externalApplication);
        if (mounted) setState(() => _gonderilen++);
        await Future.delayed(const Duration(milliseconds: 800));
      } catch (_) {}
    }
    if (mounted) {
      setState(() => _gonderiyor = false);
      _snack('$_gonderilen / $_toplam mesaj gonderildi!', Colors.green);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }

  // ── Build ──
  @override
  Widget build(BuildContext context) {
    final sistemSayi  = _seciliVeli.length;
    final manuelSayi  = _manuelNumaralar.length;
    final toplamSecili = sistemSayi + manuelSayi;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white,
        title: const Text('Toplu WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          YardimButonu(ekranAdi: 'Raporlar'),
          if (toplamSecili > 0)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(20)),
              child: Text('$toplamSecili secili',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Column(children: [
        // ── MESAJ KUTUSU ──
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.chat_outlined, color: _navy, size: 16),
              const SizedBox(width: 6),
              const Text('Mesaj', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _navy)),
              const Spacer(),
              if (_gonderiyor)
                Text('$_gonderilen / $_toplam gonderildi',
                    style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 8),
            TextField(
              controller: _mesajCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Mesajinizi yazin...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(10),
                filled: true, fillColor: const Color(0xFFF8F9FA),
              ),
            ),
            if (_gonderiyor) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: _toplam > 0 ? _gonderilen / _toplam : 0,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(_green),
              ),
            ],
          ]),
        ),

        // ── SEKMELER: Sistemden Sec / Manuel Ekle ──
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tab,
            indicatorColor: _navy,
            labelColor: _navy, unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            tabs: [
              Tab(text: 'Sistemden (${_seciliVeli.length})'),
              Tab(text: 'Manuel (${_manuelNumaralar.length})'),
            ],
          ),
        ),

        Expanded(child: TabBarView(controller: _tab, children: [
          // ════ TAB 1: SİSTEM VELİLERİ ════
          _sistemVelileriTab(),
          // ════ TAB 2: MANUEL NUMARALAR ════
          _manuelNumaralarTab(),
        ])),
      ]),

      // Gönder FAB
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _gonderiyor ? Colors.grey : _green,
        foregroundColor: Colors.white,
        onPressed: _gonderiyor ? null : _gonder,
        icon: _gonderiyor
            ? const SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.send),
        label: Text(
          _gonderiyor ? 'Gonderiliyor...' : 'Gonder ($toplamSecili)',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // ── TAB 1 ──
  Widget _sistemVelileriTab() {
    final liste = _filtrelenmis;
    return Column(children: [
      // Filtre + Tümünü seç
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          Expanded(child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _FiltreBadge('Hepsi (${_veliler.length})',         'hepsi',    _filtre, (v) => setState(() { _filtre = v; _seciliVeli = []; })),
              const SizedBox(width: 6),
              _FiltreBadge('Onayli (${_veliler.where((v) => v['durum']=='onayli').length})',     'onayli',    _filtre, (v) => setState(() { _filtre = v; _seciliVeli = []; })),
              const SizedBox(width: 6),
              _FiltreBadge('Bekleyen (${_veliler.where((v) => v['durum']=='beklemede').length})', 'beklemede', _filtre, (v) => setState(() { _filtre = v; _seciliVeli = []; })),
            ]),
          )),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _tumunuSec,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: _tumSecili ? _navy : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8)),
              child: Text(_tumSecili ? 'Iptal' : 'Tumunu Sec',
                  style: TextStyle(color: _tumSecili ? Colors.white : _navy, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
      Expanded(
        child: _yukleniyor
            ? const Center(child: CircularProgressIndicator(color: _navy))
            : liste.isEmpty
            ? const Center(child: Text('Veli bulunamadi', style: TextStyle(color: Colors.grey)))
            : ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
            itemCount: liste.length,
            itemBuilder: (_, i) {
              final v      = liste[i];
              final id     = v['id'] as String;
              final secili = _seciliVeli.contains(id);
              final tel    = _telAl(v);
              final ad     = '${v['ad'] ?? ''} ${v['soyad'] ?? ''}'.trim();
              return GestureDetector(
                onTap: () {
                  if (tel.isEmpty) return;
                  setState(() { secili ? _seciliVeli.remove(id) : _seciliVeli.add(id); });
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: secili ? _navy.withValues(alpha: 0.08) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: secili ? _navy.withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.15)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 24, height: 24,
                      decoration: BoxDecoration(
                          color: secili ? _navy : Colors.grey.shade200,
                          shape: BoxShape.circle),
                      child: Icon(secili ? Icons.check : Icons.radio_button_unchecked,
                          color: secili ? Colors.white : Colors.grey, size: 14),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(ad.isNotEmpty ? ad : 'Isimsiz',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(tel.isNotEmpty ? tel : 'Telefon yok',
                          style: TextStyle(
                              color: tel.isNotEmpty ? Colors.grey[600] : Colors.red,
                              fontSize: 11)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: (v['durum'] == 'onayli' ? Colors.green : Colors.orange).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: Text(v['durum'] == 'onayli' ? 'Onayli' : 'Bekliyor',
                          style: TextStyle(
                              color: v['durum'] == 'onayli' ? Colors.green : Colors.orange,
                              fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                ),
              );
            }),
      ),
    ]);
  }

  // ── TAB 2: MANUEL NUMARALAR ──
  Widget _manuelNumaralarTab() {
    return Column(children: [
      // Giriş alanı
      Container(
        color: Colors.white,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Telefon Numarası Ekle',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _navy)),
          const SizedBox(height: 4),
          Text('Tek numara girin veya virgülle ayırarak birden fazla ekleyin.\nÖrnek: 05321234567, 05419876543',
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _manuelCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: '05XX XXX XX XX veya virgülle toplu...',
                  prefixIcon: const Icon(Icons.phone_outlined, color: _navy, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onSubmitted: _manuelEkle,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _navy, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () => _manuelEkle(_manuelCtrl.text),
              child: const Text('Ekle', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 8),
          // PDF/Kamera seçenekleri (bilgi notu)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: _orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _orange.withValues(alpha: 0.3))),
            child: Row(children: [
              const Icon(Icons.info_outline, color: _orange, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'PDF veya fotoğraftan numara eklemek için kopyala–yapıştır yapın. '
                    'Birden fazla numara virgül veya satır sonu ile ayrılabilir.',
                style: TextStyle(fontSize: 11, color: Colors.grey[700]),
              )),
            ]),
          ),
        ]),
      ),

      // Kutucuklar
      Expanded(
        child: _manuelNumaralar.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.dialpad_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          const Text('Henuz numara eklenmedi',
              style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 6),
          Text('Yukari alandan numara girin',
              style: TextStyle(color: Colors.grey[400], fontSize: 12)),
        ]))
            : ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
          children: [
            // Numara kutucukları — Wrap ile satır satır
            Wrap(
              spacing: 8, runSpacing: 8,
              children: List.generate(_manuelNumaralar.length, (i) {
                final tel = _manuelNumaralar[i];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: _green.withValues(alpha: 0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.phone_outlined, color: _green, size: 14),
                    const SizedBox(width: 6),
                    Text(tel, style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13, color: _green)),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _manuelKaldir(i),
                      child: const Icon(Icons.close, size: 14, color: Colors.red),
                    ),
                  ]),
                );
              }),
            ),
            const SizedBox(height: 12),
            // Toplu temizle
            if (_manuelNumaralar.isNotEmpty)
              TextButton.icon(
                onPressed: () => setState(() => _manuelNumaralar.clear()),
                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 16),
                label: const Text('Tümünü Temizle',
                    style: TextStyle(color: Colors.red, fontSize: 12)),
              ),
          ],
        ),
      ),
    ]);
  }
}

// ── Filtre Chip ──
class _FiltreBadge extends StatelessWidget {
  final String etiket, deger, secili;
  final ValueChanged<String> onSec;
  const _FiltreBadge(this.etiket, this.deger, this.secili, this.onSec);
  @override
  Widget build(BuildContext context) {
    final aktif = secili == deger;
    return GestureDetector(
      onTap: () => onSec(deger),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: aktif ? const Color(0xFF1a3a6b) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20)),
        child: Text(etiket, style: TextStyle(
            color: aktif ? Colors.white : Colors.grey[700],
            fontSize: 12, fontWeight: aktif ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }
}
