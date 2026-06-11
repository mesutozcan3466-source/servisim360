// ╔══════════════════════════════════════════════════════════════╗
// ║  DOSYA: lib/screens/rotalar_screen.dart
// ║  PROJE: servisim360
// ║  v2 — Sabah/Akşam rota ayrımı + Servis bazlı görünüm
// ╚══════════════════════════════════════════════════════════════╝
import 'package:flutter/material.dart';
import 'ai_widget.dart';
import 'yardim_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/session_service.dart';

class RotalarScreen extends StatefulWidget {
  const RotalarScreen({super.key});
  @override
  State<RotalarScreen> createState() => _RotalarScreenState();
}

class _RotalarScreenState extends State<RotalarScreen>
    with SingleTickerProviderStateMixin {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  String? _firmaId;
  bool _yukleniyor = true;

  List<Map<String, dynamic>> _suruculer  = [];
  List<Map<String, dynamic>> _ogrenciler = [];
  List<Map<String, dynamic>> _servisler  = [];

  // Filtreler
  String _rotaTip   = 'tumu';
  Set<String> _devamsizIds = {};  // Bugün devamsız öğrenciler   // tumu | sabah | aksam | ogle
  String _aramaMetni = '';
  final _aramaCtrl = TextEditingController();

  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _yukle();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _aramaCtrl.dispose();
    super.dispose();
  }


  Future<void> _rotaKaydet(Map<String,dynamic> rota) async {
    if (_firmaId == null) return;
    try {
      await FirebaseFirestore.instance.collection('routes')
          .doc(rota['id'] ?? '')
          .set({
        ...rota,
        'firmaId': _firmaId,
        'guncellemeTarihi': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Rota kaydedildi'),
          backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Hata: $e'), backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating));
    }
  }

  // Akşam rotasını sabah rotasının tersi olarak hesapla
  List<dynamic> _aksamRotaOlustur(List<dynamic> sabahSirasi) {
    return sabahSirasi.reversed.toList();
  }

  // Devamsız filtreli öğrenci sayısı
  int _aktifOgrenciSayisi(List<dynamic> ogrenciler) {
    return ogrenciler.where((o) {
      final id = (o['id'] ?? o['ogrenciId'] ?? '').toString();
      return !_devamsizIds.contains(id);
    }).length;
  }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    _firmaId = await SessionService.instance.firmaIdAl();
    if (_firmaId == null) { setState(() => _yukleniyor = false); return; }

    final db = FirebaseFirestore.instance;
    final projeId = SessionService.instance.aktifProjeId ?? '';

    try {
      var surQuery = db.collection('drivers').where('firmaId', isEqualTo: _firmaId);
      var ogrQuery = db.collection('students').where('firmaId', isEqualTo: _firmaId);
      var serQuery = db.collection('services').where('firmaId', isEqualTo: _firmaId);

      if (projeId.isNotEmpty) {
        ogrQuery = ogrQuery.where('projeId', isEqualTo: projeId);
        serQuery  = serQuery.where('projeId', isEqualTo: projeId);
      }

      final results = await Future.wait([
        surQuery.get(),
        ogrQuery.get(),
        serQuery.get(),
      ]);

      setState(() {
        _suruculer  = results[0].docs.map((d) => {'id': d.id, ...d.data()}).toList();
        _ogrenciler = results[1].docs.map((d) => {'id': d.id, ...d.data()}).toList();
        _servisler  = results[2].docs.map((d) => {'id': d.id, ...d.data()}).toList();
        _yukleniyor = false;
      });
    } catch (e) {
      debugPrint('Rotalar yukle hata: $e');
      // Devamsız öğrenciler
      try {
        final devSnap = await FirebaseFirestore.instance
            .collection('absence_requests')
            .where('firmaId', isEqualTo: _firmaId)
            .where('durum', isEqualTo: 'onaylandi')
            .get();
        _devamsizIds = devSnap.docs
            .map((d) => (d.data()['ogrenciId'] ?? '').toString())
            .where((id) => id.isNotEmpty)
            .toSet();
      } catch (_) {}
      setState(() => _yukleniyor = false);
    }
  }

  List<Map<String, dynamic>> _surucuOgrencileri(String surucuId) =>
      _ogrenciler.where((o) => o['surucuId'] == surucuId).toList();

  List<Map<String, dynamic>> get _filtreliSuruculer {
    var liste = List<Map<String, dynamic>>.from(_suruculer);

    // Tip filtresi
    if (_rotaTip != 'tumu') {
      liste = liste.where((s) {
        final tip = s['servisTuru'] ?? s['servisTip'] ?? '';
        return tip == _rotaTip;
      }).toList();
    }

    // Arama
    if (_aramaMetni.isNotEmpty) {
      liste = liste.where((s) {
        final ad    = (s['adSoyad'] ?? s['ad'] ?? '').toLowerCase();
        final plaka = (s['plaka'] ?? s['aracPlaka'] ?? '').toLowerCase();
        return ad.contains(_aramaMetni) || plaka.contains(_aramaMetni);
      }).toList();
    }

    return liste;
  }

  Future<void> _whatsapp(String? tel) async {
    if (tel == null || tel.isEmpty) return;
    final url = Uri.parse('https://wa.me/90${tel.replaceAll(RegExp(r'[^\d]'), '')}');
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _ara(String? tel) async {
    if (tel == null || tel.isEmpty) return;
    final url = Uri.parse('tel:$tel');
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  // ── Rota tipi renk/ikon ───────────────────────────────────────
  Color _tipRenk(String? tip) {
    switch (tip) {
      case 'sabah':   return Colors.orange;
      case 'aksam':   return Colors.indigo;
      case 'ogle':    return Colors.teal;
      default:        return _navy;
    }
  }

  IconData _tipIkon(String? tip) {
    switch (tip) {
      case 'sabah':   return Icons.wb_sunny_outlined;
      case 'aksam':   return Icons.nights_stay_outlined;
      case 'ogle':    return Icons.wb_twilight_outlined;
      default:        return Icons.directions_bus_outlined;
    }
  }

  String _tipLabel(String? tip) {
    switch (tip) {
      case 'sabah':   return 'Sabah';
      case 'aksam':   return 'Akşam';
      case 'ogle':    return 'Öğle';
      default:        return 'Servis';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white,
        title: const Text('Rotalar', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          AiAsistanButonu(ekranAdi: 'Rotalar'),
          YardimButonu(ekranAdi: 'Rotalar'),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _yukle),
          IconButton(
            icon: const Icon(Icons.add_road_outlined),
            tooltip: 'Rota Oluştur',
            onPressed: () => Navigator.pushNamed(context, '/gruplama'),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: _turuncu, indicatorWeight: 3,
          labelColor: Colors.white, unselectedLabelColor: Colors.white54,
          tabs: [
            Tab(icon: const Icon(Icons.route_outlined, size: 18),
                text: 'Rotalar (${_filtreliSuruculer.length})'),
            Tab(
              icon: Badge(
                isLabelVisible: _ogrenciler.where((o) => (o['surucuId'] ?? '').isEmpty).isNotEmpty,
                label: Text('${_ogrenciler.where((o) => (o['surucuId'] ?? '').isEmpty).length}',
                    style: const TextStyle(fontSize: 9)),
                child: const Icon(Icons.person_off_outlined, size: 18),
              ),
              text: 'Atamasız',
            ),
            Tab(icon: const Icon(Icons.schedule_outlined, size: 18),
                text: 'Servisler (${_servisler.length})'),
          ],
        ),
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator(color: _navy))
          : Column(children: [
        _filtrePaneli(),
        Expanded(child: TabBarView(controller: _tabCtrl, children: [
          _buildRotalar(),
          _buildAtamasizlar(),
          _buildServisler(),
        ])),
      ]),
    );
  }

  // ── Filtre paneli ─────────────────────────────────────────────
  Widget _filtrePaneli() => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    child: Column(children: [
      // Arama
      TextField(
        controller: _aramaCtrl,
        onChanged: (v) => setState(() => _aramaMetni = v.toLowerCase()),
        decoration: InputDecoration(
          hintText: 'Şoför adı veya plaka ara...',
          hintStyle: const TextStyle(fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, color: _navy, size: 18),
          suffixIcon: _aramaMetni.isNotEmpty
              ? IconButton(
              icon: const Icon(Icons.clear_rounded, size: 16),
              onPressed: () { _aramaCtrl.clear(); setState(() => _aramaMetni = ''); })
              : null,
          filled: true, fillColor: const Color(0xFFF5F7FA),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
        ),
      ),
      const SizedBox(height: 8),
      // Tip filtresi
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _tipChip('tumu',  Icons.all_inclusive_rounded, 'Tümü'),
          const SizedBox(width: 6),
          _tipChip('sabah', Icons.wb_sunny_outlined,     'Sabah'),
          const SizedBox(width: 6),
          _tipChip('aksam', Icons.nights_stay_outlined,  'Akşam'),
          const SizedBox(width: 6),
          _tipChip('ogle',  Icons.wb_twilight_outlined,  'Öğle'),
        ]),
      ),
    ]),
  );

  Widget _tipChip(String tip, IconData icon, String label) {
    final secili = _rotaTip == tip;
    final renk   = tip == 'tumu' ? _navy : _tipRenk(tip);
    return GestureDetector(
      onTap: () => setState(() => _rotaTip = tip),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: secili ? renk : renk.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: renk.withValues(alpha: 0.3))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: secili ? Colors.white : renk),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: secili ? Colors.white : renk)),
        ]),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // TAB 1 — ROTALAR (şoför bazlı)
  // ════════════════════════════════════════════════════════════════
  Widget _buildRotalar() {
    final liste = _filtreliSuruculer;

    if (liste.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.route_outlined, size: 72, color: Colors.grey[300]),
        const SizedBox(height: 12),
        Text(_aramaMetni.isNotEmpty || _rotaTip != 'tumu'
            ? 'Arama sonucu bulunamadı'
            : 'Henüz rota oluşturulmadı',
            style: const TextStyle(color: Colors.grey, fontSize: 16)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _turuncu, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pushNamed(context, '/gruplama'),
            icon: const Icon(Icons.add_road_outlined),
            label: const Text('Rota Oluştur', style: TextStyle(fontWeight: FontWeight.bold))),
      ]));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: liste.length,
      itemBuilder: (_, i) {
        final s   = liste[i];
        final ogr = _surucuOgrencileri(s['id']);
        final tip = s['servisTuru'] ?? s['servisTip'] ?? '';
        final aktif = s['servisAktif'] == true;

        // Öğrencileri sabah/akşam olarak grupla
        final sabahOgr = ogr.where((o) => o['rotaTip'] == 'sabah' || o['rotaTip'] == null).toList();
        final aksamOgr = ogr.where((o) => o['rotaTip'] == 'aksam').toList();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: aktif ? 2 : 1,
          child: Column(children: [
            // Şoför başlık
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: aktif ? Colors.green.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.03),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14))),
              child: Row(children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: aktif
                      ? Colors.green.withValues(alpha: 0.15)
                      : _navy.withValues(alpha: 0.1),
                  child: Text(
                      (s['adSoyad'] ?? s['ad'] ?? 'Ş')[0].toUpperCase(),
                      style: TextStyle(
                          color: aktif ? Colors.green : _navy,
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s['adSoyad'] ?? s['ad'] ?? 'Şoför',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Row(children: [
                    Container(width: 7, height: 7,
                        decoration: BoxDecoration(
                            color: aktif ? Colors.green : Colors.grey,
                            shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text('${aktif ? "Aktif" : "Pasif"} • ${s['plaka'] ?? s['aracPlaka'] ?? '-'} • ${ogr.length} öğrenci',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ]),
                ])),

                // Tip badge
                if (tip.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: _tipRenk(tip).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_tipIkon(tip), size: 11, color: _tipRenk(tip)),
                      const SizedBox(width: 4),
                      Text(_tipLabel(tip),
                          style: TextStyle(fontSize: 10, color: _tipRenk(tip),
                              fontWeight: FontWeight.bold)),
                    ]),
                  ),

                const SizedBox(width: 8),
                // Ara & WA
                Row(mainAxisSize: MainAxisSize.min, children: [
                  if ((s['telefon'] ?? '').isNotEmpty)
                    IconButton(
                        icon: const Icon(Icons.phone_outlined, size: 18, color: Colors.green),
                        onPressed: () => _ara(s['telefon']),
                        tooltip: 'Ara'),
                  if ((s['telefon'] ?? '').isNotEmpty)
                    IconButton(
                        icon: const Icon(Icons.message_outlined, size: 18, color: Color(0xFF25D366)),
                        onPressed: () => _whatsapp(s['telefon']),
                        tooltip: 'WhatsApp'),
                ]),
              ]),
            ),

            // Sabah / Akşam bölümleri
            if (ogr.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Bu rotada öğrenci yok',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              )
            else ...[
              // Sabah gurubu
              _rotaGrubu(
                tip: 'sabah',
                baslik: 'Sabah Güzergahı',
                ogrenciler: sabahOgr.isNotEmpty ? sabahOgr : (aksamOgr.isEmpty ? ogr : []),
              ),
              if (aksamOgr.isNotEmpty)
                _rotaGrubu(
                  tip: 'aksam',
                  baslik: 'Akşam Güzergahı',
                  ogrenciler: aksamOgr,
                ),
            ],
          ]),
        );
      },
    );
  }

  Widget _rotaGrubu({required String tip, required String baslik,
    required List<Map<String, dynamic>> ogrenciler}) {
    if (ogrenciler.isEmpty) return const SizedBox.shrink();
    final renk = _tipRenk(tip);
    // Akşam rotası sabahın tersi — otomatik ters çevir
    final gosterilecek = tip == 'aksam'
        ? List<Map<String, dynamic>>.from(ogrenciler.reversed.toList())
        : ogrenciler;

    return ExpansionTile(
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
            color: renk.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(_tipIkon(tip), color: renk, size: 16),
      ),
      title: Row(children: [
        Text(baslik,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: renk)),
        if (tip == 'aksam') ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: Colors.indigo.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6)),
            child: const Text('Ters Rota', style: TextStyle(
                fontSize: 9, color: Colors.indigo, fontWeight: FontWeight.bold)),
          ),
        ],
      ]),
      subtitle: Text('${ogrenciler.length} öğrenci — Okul→Ev sırası',
          style: const TextStyle(fontSize: 11)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
              color: renk.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Text('${ogrenciler.length}',
              style: TextStyle(fontWeight: FontWeight.bold, color: renk, fontSize: 12)),
        ),
        const Icon(Icons.expand_more, color: Colors.grey, size: 18),
      ]),
      children: [
        ...ogrenciler.asMap().entries.map((e) {
          final idx = e.key + 1;
          final ogr = e.value;
          return ListTile(
            dense: true,
            leading: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                    color: renk.withValues(alpha: 0.1),
                    shape: BoxShape.circle),
                child: Center(child: Text('$idx',
                    style: TextStyle(fontSize: 10, color: renk,
                        fontWeight: FontWeight.bold))),
              ),
              const SizedBox(width: 6),
              CircleAvatar(
                radius: 14,
                backgroundColor: _turuncu.withValues(alpha: 0.1),
                child: Text((ogr['ad'] ?? '?')[0].toUpperCase(),
                    style: const TextStyle(color: _turuncu, fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
            ]),
            title: Text('${ogr['ad'] ?? ''} ${ogr['soyad'] ?? ''}'.trim(),
                style: const TextStyle(fontSize: 13)),
            subtitle: Text(ogr['adres'] ?? '',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: (ogr['veliTel'] ?? '').isNotEmpty
                ? Row(mainAxisSize: MainAxisSize.min, children: [
              GestureDetector(
                  onTap: () => _ara(ogr['veliTel']),
                  child: const Icon(Icons.phone_outlined, color: Colors.green, size: 16)),
              const SizedBox(width: 8),
              GestureDetector(
                  onTap: () => _whatsapp(ogr['veliTel']),
                  child: const Icon(Icons.message_outlined,
                      color: Color(0xFF25D366), size: 16)),
            ])
                : null,
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  // TAB 2 — ATAMASIZLAR
  // ════════════════════════════════════════════════════════════════
  Widget _buildAtamasizlar() {
    final atamasiz = _ogrenciler
        .where((o) => (o['surucuId'] ?? '').isEmpty)
        .toList();

    if (atamasiz.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.check_circle_outline, size: 72, color: Colors.green),
        SizedBox(height: 12),
        Text('Tüm öğrenciler atanmış! 🎉',
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
      ]));
    }

    return Column(children: [
      Container(
        color: Colors.orange.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          const Icon(Icons.warning_amber_outlined, color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          Text('${atamasiz.length} öğrenci henüz atanmadı',
              style: const TextStyle(color: Colors.orange,
                  fontWeight: FontWeight.w600, fontSize: 13)),
          const Spacer(),
          ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _navy, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () => Navigator.pushNamed(context, '/gruplama'),
              icon: const Icon(Icons.add_road_outlined, size: 14),
              label: const Text('Rota Oluştur', style: TextStyle(fontSize: 12))),
        ]),
      ),
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: atamasiz.length,
        itemBuilder: (_, i) {
          final ogr = atamasiz[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 18, backgroundColor: Colors.orange.withValues(alpha: 0.1),
                child: Text((ogr['ad'] ?? '?')[0].toUpperCase(),
                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${ogr['ad'] ?? ''} ${ogr['soyad'] ?? ''}'.trim(),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                if ((ogr['adres'] ?? '').isNotEmpty)
                  Text(ogr['adres'],
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                if ((ogr['okul'] ?? '').isNotEmpty)
                  Text(ogr['okul'],
                      style: const TextStyle(fontSize: 11, color: Colors.blue)),
              ])),
              Column(children: [
                const Icon(Icons.person_off_outlined, color: Colors.orange, size: 18),
                if ((ogr['veliTel'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                      onTap: () => _whatsapp(ogr['veliTel']),
                      child: const Icon(Icons.message_outlined,
                          color: Color(0xFF25D366), size: 16)),
                ],
              ]),
            ]),
          );
        },
      )),
    ]);
  }

  // ════════════════════════════════════════════════════════════════
  // TAB 3 — SERVİSLER (services koleksiyonu)
  // ════════════════════════════════════════════════════════════════
  Widget _buildServisler() {
    if (_servisler.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.schedule_outlined, size: 72, color: Colors.grey[300]),
        const SizedBox(height: 12),
        const Text('Henüz servis tanımlanmadı',
            style: TextStyle(color: Colors.grey, fontSize: 16)),
        const SizedBox(height: 8),
        const Text('Projeler → Servisler sekmesinden ekleyebilirsiniz',
            style: TextStyle(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center),
        const SizedBox(height: 20),
        ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _navy, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => Navigator.pushNamed(context, '/projeler'),
            icon: const Icon(Icons.folder_outlined),
            label: const Text('Projelere Git')),
      ]));
    }

    // Servisler tip bazlı grupla
    final sabahlar  = _servisler.where((s) => s['tip'] == 'sabah').toList();
    final aksamlar  = _servisler.where((s) => s['tip'] == 'aksam').toList();
    final diger     = _servisler.where((s) =>
    s['tip'] != 'sabah' && s['tip'] != 'aksam').toList();

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Özet kartları
        Row(children: [
          _ozet('Sabah', sabahlar.length, Colors.orange, Icons.wb_sunny_outlined),
          const SizedBox(width: 10),
          _ozet('Akşam', aksamlar.length, Colors.indigo, Icons.nights_stay_outlined),
          const SizedBox(width: 10),
          _ozet('Diğer', diger.length, _navy, Icons.directions_bus_outlined),
        ]),
        const SizedBox(height: 16),

        if (sabahlar.isNotEmpty) ...[
          _servisGrupBaslik('Sabah Servisleri', Colors.orange, Icons.wb_sunny_outlined),
          const SizedBox(height: 8),
          ...sabahlar.map((s) => _servisKarti(s)),
          const SizedBox(height: 16),
        ],

        if (aksamlar.isNotEmpty) ...[
          _servisGrupBaslik('Akşam Servisleri', Colors.indigo, Icons.nights_stay_outlined),
          const SizedBox(height: 8),
          ...aksamlar.map((s) => _servisKarti(s)),
          const SizedBox(height: 16),
        ],

        if (diger.isNotEmpty) ...[
          _servisGrupBaslik('Diğer Servisler', _navy, Icons.route_outlined),
          const SizedBox(height: 8),
          ...diger.map((s) => _servisKarti(s)),
        ],
      ],
    );
  }

  Widget _ozet(String label, int sayi, Color renk, IconData icon) =>
      Expanded(child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: renk.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: renk.withValues(alpha: 0.2))),
        child: Column(children: [
          Icon(icon, color: renk, size: 20),
          const SizedBox(height: 6),
          Text('$sayi', style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: renk)),
          Text(label, style: TextStyle(fontSize: 11, color: renk)),
        ]),
      ));

  Widget _servisGrupBaslik(String baslik, Color renk, IconData icon) =>
      Row(children: [
        Icon(icon, color: renk, size: 16),
        const SizedBox(width: 8),
        Text(baslik, style: TextStyle(
            fontWeight: FontWeight.bold, fontSize: 14, color: renk)),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: renk.withValues(alpha: 0.3))),
      ]);

  Widget _servisKarti(Map<String, dynamic> s) {
    final tip   = s['tip'] as String? ?? 'diger';
    final renk  = _tipRenk(tip);
    final aktif = s['aktif'] as bool? ?? true;

    // Şoför adını bul
    final surucuId = s['surucuId'] as String? ?? '';
    final soforAd  = surucuId.isNotEmpty
        ? (_suruculer.firstWhere((d) => d['id'] == surucuId,
        orElse: () => {})['adSoyad'] ??
        s['soforAd'] ?? 'Atanmadı')
        : (s['soforAd'] ?? 'Atanmadı');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: renk.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(_tipIkon(tip), color: renk, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s['servisAdi'] ?? s['ad'] ?? 'Servis',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 3),
            Wrap(spacing: 10, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.person_outlined, size: 12, color: Colors.grey),
                const SizedBox(width: 3),
                Text(soforAd, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ]),
              if ((s['aracPlaka'] ?? '').isNotEmpty)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.directions_bus_outlined, size: 12, color: Colors.grey),
                  const SizedBox(width: 3),
                  Text(s['aracPlaka'], style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ]),
              if ((s['saatBaslangic'] ?? '').isNotEmpty)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.access_time_rounded, size: 12, color: Colors.grey),
                  const SizedBox(width: 3),
                  Text('${s['saatBaslangic']} — ${s['saatBitis'] ?? ''}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ]),
            ]),
          ])),
          Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: aktif ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(aktif ? 'Aktif' : 'Pasif',
                  style: TextStyle(
                      color: aktif ? Colors.green : Colors.grey,
                      fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 4),
            Text('${s['ogrenciSayisi'] ?? 0} öğr',
                style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          ]),
        ]),
      ),
    );
  }
}
