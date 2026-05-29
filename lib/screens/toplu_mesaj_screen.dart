import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/session_service.dart';

class TopluMesajScreen extends StatefulWidget {
  const TopluMesajScreen({super.key});

  @override
  State<TopluMesajScreen> createState() => _TopluMesajScreenState();
}

class _TopluMesajScreenState extends State<TopluMesajScreen>
    with SingleTickerProviderStateMixin {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  late TabController _tabCtrl;
  String? _firmaId;
  bool _yukleniyor = true;

  List<Map<String, dynamic>> _veliler   = [];
  List<Map<String, dynamic>> _suruculer = [];
  Set<String> _seciliVeliler   = {};
  Set<String> _seciliSuruculer = {};

  final _mesajCtrl = TextEditingController();
  bool _tumVelilerSecili   = false;
  bool _tumSuruculerSecili = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _yukle();
  }

  @override
  void dispose() { _tabCtrl.dispose(); _mesajCtrl.dispose(); super.dispose(); }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    _firmaId = await SessionService.instance.firmaIdAl();
    if (_firmaId == null) { setState(() => _yukleniyor = false); return; }

    try {
      final db = FirebaseFirestore.instance;

      // Veliler → parents koleksiyonu (onaylılar)
      final veliSnap = await db
          .collection('parents')
          .where('firmaId', isEqualTo: _firmaId)
          .where('durum', isEqualTo: 'onayli')
          .get();

      // Şoförler → drivers koleksiyonu
      final surucuSnap = await db
          .collection('drivers')
          .where('firmaId', isEqualTo: _firmaId)
          .get();

      setState(() {
        _veliler = veliSnap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .where((v) => (v['telefon'] ?? '').toString().isNotEmpty)
            .toList();
        _suruculer = surucuSnap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .where((s) => (s['telefon'] ?? '').toString().isNotEmpty)
            .toList();
        _yukleniyor = false;
      });
    } catch (e) {
      setState(() => _yukleniyor = false);
    }
  }

  Future<void> _whatsappGonder(List<String> telefonlar, String mesaj) async {
    if (mesaj.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mesaj yazın'), backgroundColor: Colors.red));
      return;
    }
    if (telefonlar.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('En az bir kişi seçin'), backgroundColor: Colors.red));
      return;
    }
    for (final tel in telefonlar) {
      final numara = tel.replaceAll(RegExp(r'[^\d]'), '');
      final tr     = numara.startsWith('0') ? '90${numara.substring(1)}'
          : numara.startsWith('90') ? numara : '90$numara';
      final url = Uri.parse('https://wa.me/$tr?text=${Uri.encodeComponent(mesaj)}');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        await Future.delayed(const Duration(milliseconds: 800));
      }
    }
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${telefonlar.length} kişiye WhatsApp gönderildi'),
      backgroundColor: Colors.green, behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _smsGonder(List<String> telefonlar, String mesaj) async {
    if (telefonlar.isEmpty || mesaj.isEmpty) return;
    final url = Uri.parse('sms:${telefonlar.join(';')}?body=${Uri.encodeComponent(mesaj)}');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  List<String> get _seciliVeliTelefonlar => _veliler
      .where((v) => _seciliVeliler.contains(v['id']))
      .map((v) => v['telefon'].toString())
      .where((t) => t.isNotEmpty).toList();

  List<String> get _seciliSurucuTelefonlar => _suruculer
      .where((s) => _seciliSuruculer.contains(s['id']))
      .map((s) => s['telefon'].toString())
      .where((t) => t.isNotEmpty).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white, elevation: 0,
        title: const Text('Toplu Mesaj', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: _turuncu, indicatorWeight: 3,
          labelColor: Colors.white, unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.family_restroom, size: 18), text: 'Veliler'),
            Tab(icon: Icon(Icons.drive_eta,        size: 18), text: 'Şoförler'),
          ],
        ),
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator(color: _navy))
          : Column(children: [
        Container(
          color: Colors.white, padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _mesajCtrl, maxLines: 3, maxLength: 300,
            decoration: InputDecoration(
              hintText: 'Göndermek istediğiniz mesajı yazın...',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _navy, width: 2)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _kisiListesi(
                kisiler: _veliler, seciliSet: _seciliVeliler, tumSecili: _tumVelilerSecili,
                adAlan: (v) => v['veliAd'] ?? v['ad'] ?? 'Veli',
                onTumSecildi: (v) => setState(() {
                  _tumVelilerSecili = v;
                  _seciliVeliler = v ? _veliler.map((e) => e['id'] as String).toSet() : {};
                }),
                onSecildi: (id, sec) => setState(() {
                  if (sec) _seciliVeliler.add(id); else { _seciliVeliler.remove(id); _tumVelilerSecili = false; }
                }),
                onWhatsapp: () => _whatsappGonder(_seciliVeliTelefonlar, _mesajCtrl.text),
                onSms:      () => _smsGonder(_seciliVeliTelefonlar, _mesajCtrl.text),
                seciliSayi: _seciliVeliler.length,
              ),
              _kisiListesi(
                kisiler: _suruculer, seciliSet: _seciliSuruculer, tumSecili: _tumSuruculerSecili,
                adAlan: (s) => s['ad'] ?? 'Şoför',
                onTumSecildi: (v) => setState(() {
                  _tumSuruculerSecili = v;
                  _seciliSuruculer = v ? _suruculer.map((e) => e['id'] as String).toSet() : {};
                }),
                onSecildi: (id, sec) => setState(() {
                  if (sec) _seciliSuruculer.add(id); else { _seciliSuruculer.remove(id); _tumSuruculerSecili = false; }
                }),
                onWhatsapp: () => _whatsappGonder(_seciliSurucuTelefonlar, _mesajCtrl.text),
                onSms:      () => _smsGonder(_seciliSurucuTelefonlar, _mesajCtrl.text),
                seciliSayi: _seciliSuruculer.length,
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _kisiListesi({
    required List<Map<String, dynamic>> kisiler,
    required Set<String> seciliSet,
    required bool tumSecili,
    required String Function(Map<String, dynamic>) adAlan,
    required void Function(bool) onTumSecildi,
    required void Function(String, bool) onSecildi,
    required VoidCallback onWhatsapp,
    required VoidCallback onSms,
    required int seciliSayi,
  }) {
    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          Checkbox(value: tumSecili, activeColor: _navy, onChanged: (v) => onTumSecildi(v ?? false)),
          Text('Tümünü Seç (${kisiler.length})',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const Spacer(),
          if (seciliSayi > 0) ...[
            Text('$seciliSayi seçili', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(width: 10),
            _GonderButon(ikon: Icons.message, renk: const Color(0xFF25D366), onTap: onWhatsapp, tooltip: 'WhatsApp'),
            const SizedBox(width: 8),
            _GonderButon(ikon: Icons.sms,     renk: Colors.blue,             onTap: onSms,      tooltip: 'SMS'),
          ],
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: kisiler.isEmpty
            ? Center(child: Text('Telefon numarası olan kayıt yok', style: TextStyle(color: Colors.grey[500])))
            : ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: kisiler.length,
          itemBuilder: (_, i) {
            final kisi   = kisiler[i];
            final id     = kisi['id'] as String;
            final secili = seciliSet.contains(id);
            final ad     = adAlan(kisi);
            final tel    = kisi['telefon'] ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: secili
                    ? _navy.withValues(alpha: 0.4)
                    : Colors.grey.withValues(alpha: 0.15)),
              ),
              child: CheckboxListTile(
                value: secili, activeColor: _navy,
                onChanged: (v) => onSecildi(id, v ?? false),
                title: Text(ad, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                subtitle: Text(tel, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                secondary: CircleAvatar(
                  backgroundColor: _navy.withValues(alpha: 0.1), radius: 18,
                  child: Text(ad.isNotEmpty ? ad[0].toUpperCase() : '?',
                      style: const TextStyle(color: _navy, fontWeight: FontWeight.bold)),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

class _GonderButon extends StatelessWidget {
  final IconData ikon; final Color renk; final VoidCallback onTap; final String tooltip;
  const _GonderButon({required this.ikon, required this.renk, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: renk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(ikon, color: renk, size: 18),
      ),
    ),
  );
}
