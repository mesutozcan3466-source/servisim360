import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/session_service.dart';

class TopluWhatsappScreen extends StatefulWidget {
  const TopluWhatsappScreen({super.key});
  @override
  State<TopluWhatsappScreen> createState() => _TopluWhatsappScreenState();
}

class _TopluWhatsappScreenState extends State<TopluWhatsappScreen> {
  static const _navy   = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);
  static const _green  = Color(0xFF25D366);

  final _mesajCtrl = TextEditingController();
  List<Map<String, dynamic>> _veliler = [];
  List<String> _secili = [];
  bool _yukleniyor = true;
  bool _tumSecili  = false;
  String _filtre   = 'hepsi'; // hepsi, onayli, beklemede
  int _gonderilen  = 0;

  @override
  void initState() {
    super.initState();
    _yukle();
    _mesajCtrl.text = 'Sayin Velimiz,\n\nServisimizle ilgili onemli bir duyurumuz bulunmaktadir.\n\nLutfen uygulamayi kontrol edin.\n\nServisim360';
  }

  @override
  void dispose() {
    _mesajCtrl.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    final projeId = SessionService.instance.aktifProjeld ?? '';
    final firmaId = await SessionService.instance.firmaIdAl() ?? '';

    final query = projeId.isNotEmpty
        ? FirebaseFirestore.instance.collection('parents').where('projeId', isEqualTo: projeId)
        : FirebaseFirestore.instance.collection('parents').where('firmaId', isEqualTo: firmaId);

    final snap = await query.get();
    setState(() {
      _veliler = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      _yukleniyor = false;
    });
  }

  List<Map<String, dynamic>> get _filtrelenmis {
    if (_filtre == 'onayli')    return _veliler.where((v) => v['durum'] == 'onayli').toList();
    if (_filtre == 'beklemede') return _veliler.where((v) => v['durum'] == 'beklemede').toList();
    return _veliler;
  }

  void _tumunuSec() {
    setState(() {
      _tumSecili = !_tumSecili;
      if (_tumSecili) {
        _secili = _filtrelenmis
            .where((v) => (v['telefon'] ?? '').toString().isNotEmpty)
            .map((v) => v['id'] as String)
            .toList();
      } else {
        _secili = [];
      }
    });
  }

  Future<void> _gonder() async {
    if (_secili.isEmpty) {
      _snack('En az 1 veli secin!', Colors.orange);
      return;
    }
    if (_mesajCtrl.text.trim().isEmpty) {
      _snack('Mesaj bos olamaz!', Colors.orange);
      return;
    }

    setState(() => _gonderilen = 0);

    final secilenVeliler = _veliler.where((v) => _secili.contains(v['id'])).toList();

    for (final veli in secilenVeliler) {
      final tel = (veli['telefon'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '');
      if (tel.isEmpty) continue;

      var numara = tel;
      if (numara.startsWith('0')) numara = '9$numara';
      if (!numara.startsWith('90')) numara = '90$numara';

      final msg = Uri.encodeComponent(_mesajCtrl.text.trim());
      final url = Uri.parse('https://wa.me/$numara?text=$msg');

      try {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        setState(() => _gonderilen++);
        await Future.delayed(const Duration(seconds: 1));
      } catch (_) {}
    }

    _snack('$_gonderilen mesaj gonderildi!', Colors.green);
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final liste = _filtrelenmis;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white,
        title: const Text('Toplu WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_secili.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(20)),
              child: Text('${_secili.length} secili', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Column(children: [
        // Mesaj kutusu
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Mesaj', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _mesajCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Mesajinizi yazin...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
          ]),
        ),

        // Filtre ve toplu seç
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            // Filtre
            Expanded(child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _FiltreBadge('Hepsi (${_veliler.length})',        'hepsi',    _filtre, (v) => setState(() { _filtre = v; _secili = []; })),
                const SizedBox(width: 6),
                _FiltreBadge('Onayli (${_veliler.where((v) => v['durum'] == 'onayli').length})',        'onayli',    _filtre, (v) => setState(() { _filtre = v; _secili = []; })),
                const SizedBox(width: 6),
                _FiltreBadge('Bekleyen (${_veliler.where((v) => v['durum'] == 'beklemede').length})',   'beklemede', _filtre, (v) => setState(() { _filtre = v; _secili = []; })),
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

        // Veli listesi
        Expanded(
          child: _yukleniyor
              ? const Center(child: CircularProgressIndicator())
              : liste.isEmpty
              ? const Center(child: Text('Veli bulunamadi', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
            itemCount: liste.length,
            itemBuilder: (_, i) {
              final v      = liste[i];
              final id     = v['id'] as String;
              final secili = _secili.contains(id);
              final tel    = (v['telefon'] ?? '').toString();
              final adSoyad= '${v['ad'] ?? ''} ${v['soyad'] ?? ''}'.trim();
              return GestureDetector(
                onTap: () {
                  if (tel.isEmpty) return;
                  setState(() {
                    if (secili) _secili.remove(id);
                    else _secili.add(id);
                  });
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
                      child: Icon(secili ? Icons.check : Icons.circle_outlined,
                          color: secili ? Colors.white : Colors.grey, size: 14),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(adSoyad.isNotEmpty ? adSoyad : 'Isimsiz',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(tel.isNotEmpty ? tel : 'Telefon yok',
                          style: TextStyle(color: tel.isNotEmpty ? Colors.grey[600] : Colors.red, fontSize: 11)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: v['durum'] == 'onayli' ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: Text(v['durum'] == 'onayli' ? 'Onayli' : 'Bekliyor',
                          style: TextStyle(color: v['durum'] == 'onayli' ? Colors.green : Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
      ]),

      // Gönder butonu
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _green, foregroundColor: Colors.white,
        onPressed: _gonder,
        icon: const Icon(Icons.send),
        label: Text('Gonder (${_secili.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

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
