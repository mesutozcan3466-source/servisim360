// ╔══════════════════════════════════════════════════════════════╗
// ║  DOSYA: lib/screens/araclar_screen.dart
// ║  PROJE: servisim360
// ║  YENİ — Araç CRUD (Web + Mobil uyumlu)
// ║  Firestore koleksiyon: vehicles
// ╚══════════════════════════════════════════════════════════════╝
import 'package:flutter/material.dart';
import 'ai_widget.dart';
import 'yardim_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/session_service.dart';

class AraclarScreen extends StatefulWidget {
  const AraclarScreen({super.key});
  @override
  State<AraclarScreen> createState() => _AraclarScreenState();
}

class _AraclarScreenState extends State<AraclarScreen> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  String? _firmaId;
  String  _aramaMetni = '';
  String? _filtreDurum; // null = tümü
  List<Map<String, dynamic>> _soforler = [];
  final _aramaCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _yukle(); }

  @override
  void dispose() { _aramaCtrl.dispose(); super.dispose(); }

  Future<void> _yukle() async {
    final fId = await SessionService.instance.firmaIdAl();
    if (!mounted) return;
    setState(() => _firmaId = fId);
    if (fId == null) return;

    // Şoförleri yükle (araç atama için)
    final snap = await FirebaseFirestore.instance
        .collection('drivers')
        .where('firmaId', isEqualTo: fId)
        .where('aktif', isEqualTo: true)
        .get();
    if (mounted) {
      setState(() {
        _soforler = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      });
    }
  }

  bool _filtrele(Map<String, dynamic> data) {
    if (_filtreDurum != null && data['durum'] != _filtreDurum) return false;
    if (_aramaMetni.isEmpty) return true;
    final plaka = (data['plaka'] ?? '').toLowerCase();
    final model = (data['model'] ?? data['aracModeli'] ?? '').toLowerCase();
    final marka = (data['marka'] ?? '').toLowerCase();
    return plaka.contains(_aramaMetni) ||
           model.contains(_aramaMetni) ||
           marka.contains(_aramaMetni);
  }

  @override
  Widget build(BuildContext context) {
    if (_firmaId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final durumlar = [
      const MapEntry<String?, String>(null, 'Tümü'),
      const MapEntry('musait', 'Müsait'),
      const MapEntry('gorevde', 'Görevde'),
      const MapEntry('bakim', 'Bakımda'),
      const MapEntry('pasif', 'Pasif'),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: const Text('Araçlar',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          AiAsistanButonu(ekranAdi: 'Servisler'),
          YardimButonu(ekranAdi: 'Servisler'),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _yukle),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _turuncu,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.directions_bus_filled_rounded),
        label: const Text('Araç Ekle',
            style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _aracEkleDialog(context),
      ),
      body: Column(children: [
        // Arama
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _aramaCtrl,
            onChanged: (v) => setState(() => _aramaMetni = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Plaka, marka veya model ara...',
              prefixIcon: const Icon(Icons.search_rounded, color: _navy),
              suffixIcon: _aramaMetni.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear_rounded),
                      onPressed: () { _aramaCtrl.clear(); setState(() => _aramaMetni = ''); })
                  : null,
              filled: true, fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
            ),
          ),
        ),
        // Durum filtreleri
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: durumlar.map((e) {
            final secili = _filtreDurum == e.key;
            final renk   = _durumRenk(e.key);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: secili,
                label: Text(e.value, style: TextStyle(
                    fontSize: 12,
                    color: secili ? Colors.white : renk,
                    fontWeight: FontWeight.w600)),
                backgroundColor: renk.withValues(alpha: 0.08),
                selectedColor: renk,
                checkmarkColor: Colors.white,
                side: BorderSide(color: renk.withValues(alpha: 0.3)),
                onSelected: (_) => setState(() => _filtreDurum = e.key),
              ),
            );
          }).toList()),
        ),

        // Liste
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('vehicles')
                .where('firmaId', isEqualTo: _firmaId)
                .orderBy('olusturma', descending: true)
                .snapshots(),
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final araclar = (snap.data?.docs ?? [])
                  .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
                  .where(_filtrele)
                  .toList();

              if (araclar.isEmpty) {
                return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.directions_bus_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    _aramaMetni.isNotEmpty || _filtreDurum != null
                        ? 'Araç bulunamadı'
                        : 'Henüz araç eklenmedi',
                    style: const TextStyle(fontSize: 18,
                        fontWeight: FontWeight.bold, color: _navy)),
                  const SizedBox(height: 24),
                  if (_aramaMetni.isEmpty && _filtreDurum == null)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _turuncu, foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      onPressed: () => _aracEkleDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Araç Ekle',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                ]));
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                itemCount: araclar.length,
                itemBuilder: (_, i) => _AracKarti(
                  docId: araclar[i]['id'],
                  data: araclar[i],
                  soforler: _soforler,
                  onDuzenle: () => _aracDuzenleDialog(context, araclar[i]['id'], araclar[i]),
                  onSil: () => _silOnay(context, araclar[i]['id'], araclar[i]['plaka'] ?? ''),
                  onSoforAta: () => _soforAtaDialog(context, araclar[i]['id'], araclar[i]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // ARAÇ EKLE DİALOG
  // ════════════════════════════════════════════════════════════════
  void _aracEkleDialog(BuildContext context) {
    final plakaCtrl    = TextEditingController();
    final markaCtrl    = TextEditingController();
    final modelCtrl    = TextEditingController();
    final kapasiteCtrl = TextEditingController();
    final yilCtrl      = TextEditingController();
    String aracTipi    = 'minibus';
    bool   aktif       = true;
    bool   yukleniyor  = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 520,
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20), color: Colors.white),
            child: Column(children: [
              // Başlık
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                    color: _navy,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                child: Row(children: [
                  const Icon(Icons.directions_bus_filled_rounded,
                      color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Yeni Araç Ekle',
                      style: TextStyle(color: Colors.white,
                          fontSize: 18, fontWeight: FontWeight.bold))),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx)),
                ]),
              ),

              // Form
              Expanded(child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  _bolumBaslik('Araç Bilgileri', Icons.directions_bus_outlined),
                  const SizedBox(height: 8),
                  _inp2(plakaCtrl, 'Plaka *', Icons.badge_outlined),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _inp2(markaCtrl, 'Marka', Icons.directions_car_outlined)),
                    const SizedBox(width: 10),
                    Expanded(child: _inp2(modelCtrl, 'Model', Icons.car_rental_outlined)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _inp2(kapasiteCtrl, 'Kapasite *',
                        Icons.people_outlined, tip: TextInputType.number)),
                    const SizedBox(width: 10),
                    Expanded(child: _inp2(yilCtrl, 'Model Yılı',
                        Icons.calendar_today_outlined, tip: TextInputType.number)),
                  ]),
                  const SizedBox(height: 20),

                  _bolumBaslik('Araç Tipi', Icons.category_outlined),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _turBtn('minibus',  '🚌 Minibüs',  aracTipi, (v) => setSt(() => aracTipi = v)),
                    _turBtn('otobus',   '🚍 Otobüs',   aracTipi, (v) => setSt(() => aracTipi = v)),
                    _turBtn('panelvan', '🚐 Panelvan',  aracTipi, (v) => setSt(() => aracTipi = v)),
                    _turBtn('sedan',    '🚗 Sedan',     aracTipi, (v) => setSt(() => aracTipi = v)),
                    _turBtn('suv',      '🚙 SUV',       aracTipi, (v) => setSt(() => aracTipi = v)),
                  ]),
                  const SizedBox(height: 16),

                  Row(children: [
                    const Text('Aktif', style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Switch(value: aktif, activeColor: Colors.green,
                        onChanged: (v) => setSt(() => aktif = v)),
                  ]),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade200)),
                    child: const Row(children: [
                      Icon(Icons.info_outline, color: Colors.amber, size: 16),
                      SizedBox(width: 8),
                      Expanded(child: Text(
                        'Araç eklendikten sonra şoför ve rota atayabilirsiniz.',
                        style: TextStyle(fontSize: 12, color: Colors.amber),
                      )),
                    ]),
                  ),
                ]),
              )),

              // Butonlar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFEEEEEE)))),
                child: Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: const Text('İptal'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _navy, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    onPressed: yukleniyor ? null : () async {
                      if (plakaCtrl.text.trim().isEmpty) {
                        _snack(ctx, 'Plaka zorunlu!'); return;
                      }
                      if (kapasiteCtrl.text.trim().isEmpty) {
                        _snack(ctx, 'Kapasite zorunlu!'); return;
                      }

                      // Plaka kontrolü
                      final pKont = await FirebaseFirestore.instance
                          .collection('vehicles')
                          .where('firmaId', isEqualTo: _firmaId)
                          .where('plaka', isEqualTo: plakaCtrl.text.trim().toUpperCase())
                          .get();
                      if (pKont.docs.isNotEmpty) {
                        _snack(ctx, 'Bu plaka zaten kayıtlı!'); return;
                      }

                      setSt(() => yukleniyor = true);
                      try {
                        final now = FieldValue.serverTimestamp();
                        await FirebaseFirestore.instance.collection('vehicles').add({
                          'plaka'    : plakaCtrl.text.trim().toUpperCase(),
                          'marka'    : markaCtrl.text.trim(),
                          'model'    : modelCtrl.text.trim(),
                          'aracModeli': '${markaCtrl.text.trim()} ${modelCtrl.text.trim()}'.trim(),
                          'kapasite' : int.tryParse(kapasiteCtrl.text.trim()) ?? 0,
                          'aracKapasitesi': kapasiteCtrl.text.trim(),
                          'yil'      : int.tryParse(yilCtrl.text.trim()),
                          'aracTipi' : aracTipi,
                          'durum'    : aktif ? 'musait' : 'pasif',
                          'aktif'    : aktif,
                          'firmaId'  : _firmaId,
                          'surucuId' : null,
                          'surucuAd' : null,
                          'olusturma': now,
                          'updatedAt': now,
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setSt(() => yukleniyor = false);
                        _snack(ctx, 'Hata: $e');
                      }
                    },
                    icon: yukleniyor
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save_rounded),
                    label: Text(yukleniyor ? 'Kaydediliyor...' : 'Aracı Kaydet',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  )),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // ARAÇ DÜZENLE DİALOG
  // ════════════════════════════════════════════════════════════════
  void _aracDuzenleDialog(BuildContext context, String docId,
      Map<String, dynamic> data) {
    final plakaCtrl    = TextEditingController(text: data['plaka'] ?? '');
    final markaCtrl    = TextEditingController(text: data['marka'] ?? '');
    final modelCtrl    = TextEditingController(text: data['model'] ?? '');
    final kapasiteCtrl = TextEditingController(
        text: data['kapasite']?.toString() ?? data['aracKapasitesi'] ?? '');
    final yilCtrl      = TextEditingController(
        text: data['yil']?.toString() ?? '');
    bool aktif = data['aktif'] as bool? ?? true;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('${data['plaka'] ?? 'Araç'} — Düzenle'),
          content: SizedBox(width: 480, child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _inp2(plakaCtrl, 'Plaka *', Icons.badge_outlined),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _inp2(markaCtrl, 'Marka', Icons.directions_car_outlined)),
                const SizedBox(width: 8),
                Expanded(child: _inp2(modelCtrl, 'Model', Icons.car_rental_outlined)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _inp2(kapasiteCtrl, 'Kapasite',
                    Icons.people_outlined, tip: TextInputType.number)),
                const SizedBox(width: 8),
                Expanded(child: _inp2(yilCtrl, 'Yıl',
                    Icons.calendar_today_outlined, tip: TextInputType.number)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                const Text('Aktif', style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Switch(value: aktif, activeColor: Colors.green,
                    onChanged: (v) => setSt(() => aktif = v)),
              ]),
            ]),
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _navy, foregroundColor: Colors.white),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('vehicles').doc(docId).update({
                  'plaka'          : plakaCtrl.text.trim().toUpperCase(),
                  'marka'          : markaCtrl.text.trim(),
                  'model'          : modelCtrl.text.trim(),
                  'aracModeli'     : '${markaCtrl.text.trim()} ${modelCtrl.text.trim()}'.trim(),
                  'kapasite'       : int.tryParse(kapasiteCtrl.text.trim()) ?? 0,
                  'aracKapasitesi' : kapasiteCtrl.text.trim(),
                  'yil'            : int.tryParse(yilCtrl.text.trim()),
                  'aktif'          : aktif,
                  'durum'          : aktif ? 'musait' : 'pasif',
                  'updatedAt'      : FieldValue.serverTimestamp(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Kaydet')),
          ],
        ),
      ),
    );
  }

  // ── Şoför Ata Dialog ─────────────────────────────────────────
  void _soforAtaDialog(BuildContext context, String docId,
      Map<String, dynamic> data) {
    String? seciliSoforId;
    String  seciliSoforAd = '';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('${data['plaka']} — Şoför Ata'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Şoför Seç',
                prefixIcon: Icon(Icons.person_outlined),
                border: OutlineInputBorder(), isDense: true),
              hint: const Text('Şoför seçin'),
              value: seciliSoforId,
              items: [
                const DropdownMenuItem<String>(value: '', child: Text('Atamayı Kaldır')),
                ..._soforler.map((s) => DropdownMenuItem(
                  value: s['id'] as String,
                  child: Text('${s['adSoyad'] ?? s['ad'] ?? ''} — ${s['plaka'] ?? ''}'),
                )),
              ],
              onChanged: (v) => setSt(() {
                seciliSoforId = v;
                seciliSoforAd = _soforler.firstWhere(
                    (s) => s['id'] == v, orElse: () => {})['adSoyad'] ?? '';
              }),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _navy, foregroundColor: Colors.white),
              onPressed: seciliSoforId == null ? null : () async {
                final kaldir = seciliSoforId!.isEmpty;
                await FirebaseFirestore.instance
                    .collection('vehicles').doc(docId).update({
                  'surucuId' : kaldir ? null : seciliSoforId,
                  'surucuAd' : kaldir ? null : seciliSoforAd,
                  'durum'    : kaldir ? 'musait' : 'gorevde',
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                if (!kaldir) {
                  // Şoförün plakasını güncelle
                  await FirebaseFirestore.instance
                      .collection('drivers').doc(seciliSoforId).update({
                    'aracPlaka' : data['plaka'],
                    'plaka'     : data['plaka'],
                    'vehicleId' : docId,
                    'updatedAt' : FieldValue.serverTimestamp(),
                  });
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Ata')),
          ],
        ),
      ),
    );
  }

  // ── Sil Onay ─────────────────────────────────────────────────
  Future<void> _silOnay(BuildContext context, String docId, String plaka) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Aracı Sil'),
        content: Text('$plaka plakalı araç silinsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_, false), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(_, true),
            child: const Text('Sil', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (onay == true) {
      await FirebaseFirestore.instance
          .collection('vehicles').doc(docId).delete();
    }
  }

  // ── Yardımcılar ───────────────────────────────────────────────
  Color _durumRenk(String? d) {
    switch (d) {
      case 'musait':  return Colors.green;
      case 'gorevde': return Colors.blue;
      case 'bakim':   return Colors.orange;
      case 'pasif':   return Colors.grey;
      default:        return _navy;
    }
  }

  void _snack(BuildContext ctx, String m) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(m), backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating));
  }

  Widget _bolumBaslik(String text, IconData icon) => Row(children: [
    Icon(icon, color: _navy, size: 18),
    const SizedBox(width: 8),
    Text(text, style: const TextStyle(
        fontWeight: FontWeight.bold, fontSize: 14, color: _navy)),
  ]);

  InputDecoration _inputDec(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: _navy, size: 18),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );

  Widget _inp2(TextEditingController c, String label, IconData icon,
      {TextInputType tip = TextInputType.text}) =>
      TextField(controller: c, keyboardType: tip, decoration: _inputDec(label, icon));

  Widget _turBtn(String deger, String label, String secili, Function(String) onChange) {
    final sec = secili == deger;
    return GestureDetector(
      onTap: () => onChange(deger),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: sec ? _navy : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: sec ? _navy : Colors.grey.shade300)),
        child: Text(label, style: TextStyle(
            color: sec ? Colors.white : Colors.grey,
            fontSize: 12,
            fontWeight: sec ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ARAÇ KARTI
// ════════════════════════════════════════════════════════════════
class _AracKarti extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final List<Map<String, dynamic>> soforler;
  final VoidCallback onDuzenle, onSil, onSoforAta;

  static const _navy    = Color(0xFF1a3a6b);

  const _AracKarti({
    required this.docId,    required this.data,
    required this.soforler, required this.onDuzenle,
    required this.onSil,    required this.onSoforAta,
  });

  Color _durumRenk(String? d) {
    switch (d) {
      case 'musait':  return Colors.green;
      case 'gorevde': return Colors.blue;
      case 'bakim':   return Colors.orange;
      case 'pasif':   return Colors.grey;
      default:        return Colors.grey;
    }
  }

  String _durumLabel(String? d) {
    switch (d) {
      case 'musait':  return 'Müsait';
      case 'gorevde': return 'Görevde';
      case 'bakim':   return 'Bakımda';
      case 'pasif':   return 'Pasif';
      default:        return 'Bilinmiyor';
    }
  }

  String _aracTipiIkon(String? t) {
    switch (t) {
      case 'otobus':   return '🚍';
      case 'panelvan': return '🚐';
      case 'sedan':    return '🚗';
      case 'suv':      return '🚙';
      default:         return '🚌';
    }
  }

  @override
  Widget build(BuildContext context) {
    final plaka    = data['plaka'] ?? '-';
    final marka    = data['marka'] ?? '';
    final model    = data['model'] ?? '';
    final kapasite = data['kapasite']?.toString() ?? data['aracKapasitesi'] ?? '-';
    final yil      = data['yil']?.toString() ?? '';
    final durum    = data['durum'] as String? ?? 'musait';
    final surucuAd = data['surucuAd'] as String?;
    final aracTipi = data['aracTipi'] as String?;

    final durumRenk  = _durumRenk(durum);
    final durumLabel = _durumLabel(durum);
    final tipiIkon   = _aracTipiIkon(aracTipi);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Üst satır
          Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                  color: durumRenk.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text(tipiIkon, style: const TextStyle(fontSize: 24))),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(plaka, style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 17, color: _navy)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: durumRenk.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: durumRenk.withValues(alpha: 0.3))),
                  child: Text(durumLabel, style: TextStyle(
                      fontSize: 10, color: durumRenk, fontWeight: FontWeight.bold)),
                ),
              ]),
              const SizedBox(height: 3),
              Text('$marka $model${yil.isNotEmpty ? ' • $yil' : ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ])),
          ]),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Bilgi çipleri
          Row(children: [
            _bilgiCip(Icons.people_rounded, '$kapasite kişi', Colors.purple),
            const SizedBox(width: 8),
            if (surucuAd != null)
              Expanded(child: _bilgiCip(Icons.person_rounded, surucuAd, Colors.blue))
            else
              _bilgiCip(Icons.person_off_rounded, 'Şoför yok', Colors.grey),
          ]),

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Aksiyon butonları
          Row(children: [
            // Şoför Ata
            _akBtn(Icons.person_add_rounded, 'Şoför Ata', Colors.blue, onSoforAta),
            const SizedBox(width: 8),
            // Düzenle
            _akBtn(Icons.edit_rounded, 'Düzenle', _navy, onDuzenle),
            const Spacer(),
            // Durum toggle (Bakım)
            IconButton(
              icon: Icon(
                durum == 'bakim'
                    ? Icons.build_rounded
                    : Icons.build_outlined,
                color: durum == 'bakim' ? Colors.orange : Colors.grey,
              ),
              tooltip: durum == 'bakim' ? 'Bakımdan Çıkar' : 'Bakıma Al',
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('vehicles').doc(docId).update({
                  'durum'    : durum == 'bakim' ? 'musait' : 'bakim',
                  'updatedAt': FieldValue.serverTimestamp(),
                });
              },
            ),
            // Sil
            IconButton(
              icon: const Icon(Icons.delete_rounded, color: Colors.red),
              tooltip: 'Sil',
              onPressed: onSil,
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _bilgiCip(IconData icon, String label, Color renk) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: renk.withValues(alpha: 0.2))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: renk),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(
          fontSize: 11, color: renk, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _akBtn(IconData icon, String label, Color renk, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: renk.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: renk.withValues(alpha: 0.25))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: renk),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: renk)),
          ]),
        ),
      );
}
