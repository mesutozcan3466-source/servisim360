import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ════════════════════════════════════════════════════════════════
//  SERVİS SAATİ EKRANI
//  - Firma geneli varsayilan saatler
//  - Her sofor icin ayri saat ayari gruplama'dan acilir
// ════════════════════════════════════════════════════════════════
class ServisSaatiScreen extends StatefulWidget {
  const ServisSaatiScreen({super.key});
  @override
  State<ServisSaatiScreen> createState() => _ServisSaatiScreenState();
}

class _ServisSaatiScreenState extends State<ServisSaatiScreen> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  TimeOfDay _sabahB = const TimeOfDay(hour: 6,  minute: 30);
  TimeOfDay _sabahE = const TimeOfDay(hour: 9,  minute: 30);
  TimeOfDay _aksamB = const TimeOfDay(hour: 15, minute: 0);
  TimeOfDay _aksamE = const TimeOfDay(hour: 18, minute: 30);
  bool _yukleniyor  = false;
  String _firmaId   = '';

  @override
  void initState() { super.initState(); _yukle(); }

  Future<void> _yukle() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final kulDoc = await FirebaseFirestore.instance.collection('kullanicilar').doc(uid).get();
    _firmaId = kulDoc.data()?['firmaId'] ?? '';
    if (_firmaId.isEmpty) return;

    final doc = await FirebaseFirestore.instance.collection('firms').doc(_firmaId).get();
    final data = doc.data()?['servisSaati'] as Map<String, dynamic>?;
    if (data != null && mounted) setState(() {
      _sabahB = _parse(data['sabahBaslangic'] ?? '06:30');
      _sabahE = _parse(data['sabahBitis']     ?? '09:30');
      _aksamB = _parse(data['aksamBaslangic'] ?? '15:00');
      _aksamE = _parse(data['aksamBitis']     ?? '18:30');
    });
  }

  TimeOfDay _parse(String s) {
    final p = s.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';

  Future<void> _sec(TimeOfDay cur, void Function(TimeOfDay) cb) async {
    final t = await showTimePicker(context: context, initialTime: cur);
    if (t != null) setState(() => cb(t));
  }

  Future<void> _kaydet() async {
    if (_firmaId.isEmpty) return;
    setState(() => _yukleniyor = true);
    await FirebaseFirestore.instance.collection('firms').doc(_firmaId).update({
      'servisSaati': {
        'sabahBaslangic': _fmt(_sabahB),
        'sabahBitis':     _fmt(_sabahE),
        'aksamBaslangic': _fmt(_aksamB),
        'aksamBitis':     _fmt(_aksamE),
      },
    });
    if (mounted) {
      setState(() => _yukleniyor = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Varsayilan saatler kaydedildi.'),
          backgroundColor: Colors.green));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white,
        title: const Text('Servis Saati', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Bilgi kutusu
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.2))),
          child: const Row(children: [
            Icon(Icons.info_outline, color: Colors.blue, size: 16),
            SizedBox(width: 8),
            Expanded(child: Text(
                'Bu saatler firma geneli varsayilan saatlerdir. Her sofor icin ayri saat ayarlamak icin Operasyon menusunden soforun ayar butonunu kullanin.',
                style: TextStyle(color: Colors.blue, fontSize: 12))),
          ]),
        ),

        _Baslik('Sabah Servisi', Icons.wb_sunny_outlined),
        _Kart(Column(children: [
          _SaatSatir('Baslangic', _fmt(_sabahB), () => _sec(_sabahB, (t) => _sabahB = t)),
          const Divider(height: 1),
          _SaatSatir('Bitis',     _fmt(_sabahE), () => _sec(_sabahE, (t) => _sabahE = t)),
        ])),
        const SizedBox(height: 16),

        _Baslik('Aksam Servisi', Icons.nightlight_outlined),
        _Kart(Column(children: [
          _SaatSatir('Baslangic', _fmt(_aksamB), () => _sec(_aksamB, (t) => _aksamB = t)),
          const Divider(height: 1),
          _SaatSatir('Bitis',     _fmt(_aksamE), () => _sec(_aksamE, (t) => _aksamE = t)),
        ])),
        const SizedBox(height: 24),

        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: _turuncu, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: _yukleniyor ? null : _kaydet,
          child: _yukleniyor
              ? const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),

        const SizedBox(height: 32),
        _Baslik('Soforlere Ozel Saatler', Icons.directions_bus_outlined),
        const SizedBox(height: 8),
        Text('Operasyon → Arac/Sofor sekmesinde her soforun yanindaki ⚙️ butonundan ayarlayabilirsiniz.',
            style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        const SizedBox(height: 40),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  SOFOR AYAR SAYFASI — gruplama_screen'den cagrilir
// ════════════════════════════════════════════════════════════════
class SoforAyarSheet extends StatefulWidget {
  final String soforId;
  final Map<String, dynamic> soforData;
  final VoidCallback onGuncelle;
  const SoforAyarSheet({
    super.key,
    required this.soforId,
    required this.soforData,
    required this.onGuncelle,
  });
  @override
  State<SoforAyarSheet> createState() => _SoforAyarSheetState();
}

class _SoforAyarSheetState extends State<SoforAyarSheet>
    with SingleTickerProviderStateMixin {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  late TabController _tab;

  // Bilgi alanlari
  late TextEditingController _adCtrl;
  late TextEditingController _telCtrl;
  late TextEditingController _plakaCtrl;
  late TextEditingController _emailCtrl;

  // Servis saatleri
  TimeOfDay _sabahB = const TimeOfDay(hour: 6,  minute: 30);
  TimeOfDay _sabahE = const TimeOfDay(hour: 9,  minute: 30);
  TimeOfDay _aksamB = const TimeOfDay(hour: 15, minute: 0);
  TimeOfDay _aksamE = const TimeOfDay(hour: 18, minute: 30);

  bool _yukleniyor = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _adCtrl    = TextEditingController(text: widget.soforData['ad']       ?? '');
    _telCtrl   = TextEditingController(text: widget.soforData['telefon']  ?? '');
    _plakaCtrl = TextEditingController(text: widget.soforData['aracPlaka']?? '');
    _emailCtrl = TextEditingController(text: widget.soforData['email']    ?? '');
    _saatleriYukle();
  }

  @override
  void dispose() {
    _tab.dispose();
    _adCtrl.dispose(); _telCtrl.dispose();
    _plakaCtrl.dispose(); _emailCtrl.dispose();
    super.dispose();
  }

  void _saatleriYukle() {
    final ss = widget.soforData['servisSaati'] as Map<String, dynamic>?;
    if (ss != null) {
      _sabahB = _parse(ss['sabahBaslangic'] ?? '06:30');
      _sabahE = _parse(ss['sabahBitis']     ?? '09:30');
      _aksamB = _parse(ss['aksamBaslangic'] ?? '15:00');
      _aksamE = _parse(ss['aksamBitis']     ?? '18:30');
    }
  }

  TimeOfDay _parse(String s) {
    final p = s.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';

  Future<void> _secSaat(TimeOfDay cur, void Function(TimeOfDay) cb) async {
    final t = await showTimePicker(context: context, initialTime: cur);
    if (t != null) setState(() => cb(t));
  }

  Future<void> _kaydet() async {
    setState(() => _yukleniyor = true);
    try {
      await FirebaseFirestore.instance.collection('drivers').doc(widget.soforId).update({
        'ad':        _adCtrl.text.trim(),
        'telefon':   _telCtrl.text.trim(),
        'aracPlaka': _plakaCtrl.text.trim().toUpperCase(),
        'email':     _emailCtrl.text.trim(),
        'servisSaati': {
          'sabahBaslangic': _fmt(_sabahB),
          'sabahBitis':     _fmt(_sabahE),
          'aksamBaslangic': _fmt(_aksamB),
          'aksamBitis':     _fmt(_aksamE),
        },
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onGuncelle();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Sofor bilgileri kaydedildi!'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _soforSil() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Soforu Sil'),
        content: Text('${_adCtrl.text} silinecek. Emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Iptal')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sil', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (onay != true) return;
    await FirebaseFirestore.instance.collection('drivers').doc(widget.soforId).delete();
    if (mounted) {
      Navigator.pop(context);
      widget.onGuncelle();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(children: [
        // Handle
        Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 4),
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),

        // Baslik
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(children: [
            CircleAvatar(radius: 20, backgroundColor: _navy.withValues(alpha: 0.1),
                child: Text((widget.soforData['ad'] ?? '?')[0].toUpperCase(),
                    style: const TextStyle(color: _navy, fontWeight: FontWeight.bold))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.soforData['ad'] ?? 'Sofor',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _navy)),
              Text(widget.soforData['aracPlaka'] ?? '',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ])),
            IconButton(
                onPressed: _soforSil,
                icon: const Icon(Icons.delete_outline, color: Colors.red)),
          ]),
        ),

        // Tabs
        TabBar(
          controller: _tab,
          labelColor: _navy, unselectedLabelColor: Colors.grey,
          indicatorColor: _turuncu,
          tabs: const [
            Tab(icon: Icon(Icons.person_outline, size: 18), text: 'Bilgiler'),
            Tab(icon: Icon(Icons.access_time,    size: 18), text: 'Servis Saati'),
          ],
        ),

        // Icerik
        Expanded(child: TabBarView(controller: _tab, children: [
          // Tab 1: Bilgiler
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              _AyarAlan(_adCtrl,    'Ad Soyad',     Icons.person_outline),
              const SizedBox(height: 10),
              _AyarAlan(_telCtrl,   'Telefon',       Icons.phone_outlined, tipi: TextInputType.phone),
              const SizedBox(height: 10),
              _AyarAlan(_plakaCtrl, 'Arac Plakasi',  Icons.directions_bus_outlined),
              const SizedBox(height: 10),
              _AyarAlan(_emailCtrl, 'E-posta',       Icons.email_outlined, tipi: TextInputType.emailAddress),
            ]),
          ),

          // Tab 2: Servis Saati
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Baslik('Sabah Servisi', Icons.wb_sunny_outlined),
              _Kart(Column(children: [
                _SaatSatir('Baslangic', _fmt(_sabahB), () => _secSaat(_sabahB, (t) => _sabahB = t)),
                const Divider(height: 1),
                _SaatSatir('Bitis',     _fmt(_sabahE), () => _secSaat(_sabahE, (t) => _sabahE = t)),
              ])),
              const SizedBox(height: 16),
              _Baslik('Aksam Servisi', Icons.nightlight_outlined),
              _Kart(Column(children: [
                _SaatSatir('Baslangic', _fmt(_aksamB), () => _secSaat(_aksamB, (t) => _aksamB = t)),
                const Divider(height: 1),
                _SaatSatir('Bitis',     _fmt(_aksamE), () => _secSaat(_aksamE, (t) => _aksamE = t)),
              ])),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.2))),
                child: const Row(children: [
                  Icon(Icons.info_outline, color: Colors.green, size: 14),
                  SizedBox(width: 6),
                  Expanded(child: Text(
                      'Bu saatler sadece bu sofore ozgudur. Diger soforler etkilenmez.',
                      style: TextStyle(color: Colors.green, fontSize: 11))),
                ]),
              ),
            ]),
          ),
        ])),

        // Kaydet butonu
        Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _navy, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: _yukleniyor ? null : _kaydet,
            child: _yukleniyor
                ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          )),
        ),
      ]),
    );
  }
}

// ── Ortak Widget'lar ──────────────────────────────────────────────
Widget _Baslik(String baslik, IconData ikon) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Row(children: [
    Icon(ikon, color: const Color(0xFF1a3a6b), size: 16),
    const SizedBox(width: 8),
    Text(baslik, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1a3a6b))),
  ]),
);

Widget _Kart(Widget child) => Container(
  margin: const EdgeInsets.only(bottom: 4),
  decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
  child: child,
);

Widget _SaatSatir(String label, String saat, VoidCallback onTap) => ListTile(
  title: Text(label, style: const TextStyle(fontSize: 13)),
  trailing: GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
          color: const Color(0xFF1a3a6b).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8)),
      child: Text(saat, style: const TextStyle(
          color: Color(0xFF1a3a6b), fontWeight: FontWeight.bold, fontSize: 15)),
    ),
  ),
  dense: true,
);

class _AyarAlan extends StatelessWidget {
  final TextEditingController ctrl;
  final String label; final IconData ikon; final TextInputType tipi;
  static const _navy = Color(0xFF1a3a6b);
  const _AyarAlan(this.ctrl, this.label, this.ikon, {this.tipi = TextInputType.text});
  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl, keyboardType: tipi,
    decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(ikon, color: _navy, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _navy, width: 2)),
        contentPadding: const EdgeInsets.all(14),
        filled: true, fillColor: Colors.white),
  );
}
