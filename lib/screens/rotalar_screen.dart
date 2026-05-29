import 'package:flutter/material.dart';
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
  List<Map<String, dynamic>> _suruculerList = [];
  List<Map<String, dynamic>> _ogrenciler    = [];
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _yukle();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    _firmaId = await SessionService.instance.firmaIdAl();
    if (_firmaId == null) { setState(() => _yukleniyor = false); return; }

    final db = FirebaseFirestore.instance;
    // drivers + students — Servisim360 yeni yapısı
    final surSnap = await db.collection('drivers').where('firmaId', isEqualTo: _firmaId).get();
    final ogrSnap = await db.collection('students').where('firmaId', isEqualTo: _firmaId).get();

    setState(() {
      _suruculerList = surSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      _ogrenciler    = ogrSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      _yukleniyor    = false;
    });
  }

  List<Map<String, dynamic>> _surucuOgrencileri(String surucuId) =>
      _ogrenciler.where((o) => o['surucuId'] == surucuId).toList();

  Future<void> _whatsapp(String? tel) async {
    if (tel == null || tel.isEmpty) return;
    final url = Uri.parse('https://wa.me/${tel.replaceAll(RegExp(r'[^\d]'), '')}');
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white, elevation: 0,
        title: const Text('Rotalar', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _yukle)],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: _turuncu, indicatorWeight: 3,
          labelColor: Colors.white, unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.drive_eta,     size: 18), text: 'Şoförler'),
            Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Atamasızlar'),
          ],
        ),
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator(color: _navy))
          : TabBarView(controller: _tabCtrl, children: [_buildSuruculer(), _buildAtamasizlar()]),
    );
  }

  Widget _buildSuruculer() {
    if (_suruculerList.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.drive_eta, size: 64, color: Color(0xFFCCCCCC)),
        SizedBox(height: 12),
        Text('Şoför bulunamadı', style: TextStyle(color: Colors.grey)),
      ]));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _suruculerList.length,
      itemBuilder: (_, i) {
        final s          = _suruculerList[i];
        final ogrenciler = _surucuOgrencileri(s['id']);
        final aktif      = s['servisAktif'] == true;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: aktif
                ? Colors.green.withValues(alpha: 0.3)
                : Colors.grey.withValues(alpha: 0.15)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
          ),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: aktif ? Colors.green.withValues(alpha: 0.15) : _navy.withValues(alpha: 0.1),
              child: Text(
                (s['ad'] ?? '?')[0].toUpperCase(),
                style: TextStyle(color: aktif ? Colors.green : _navy, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(s['ad'] ?? 'Şoför',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Row(children: [
              Container(width: 6, height: 6,
                  decoration: BoxDecoration(color: aktif ? Colors.green : Colors.grey, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text('${aktif ? "Aktif" : "Pasif"} • ${ogrenciler.length} öğrenci • ${s['plaka'] ?? s['aracPlaka'] ?? '-'}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ]),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _navy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                child: Text('${ogrenciler.length}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: _navy, fontSize: 13)),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more, color: Colors.grey),
            ]),
            children: [
              if (ogrenciler.isEmpty)
                const Padding(padding: EdgeInsets.all(16),
                    child: Text('Bu rotada öğrenci yok', style: TextStyle(color: Colors.grey, fontSize: 13)))
              else
                ...ogrenciler.map((ogr) => ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16, backgroundColor: _turuncu.withValues(alpha: 0.1),
                    child: Text((ogr['ad'] ?? '?')[0].toUpperCase(),
                        style: const TextStyle(color: _turuncu, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  title: Text('${ogr['ad'] ?? ''} ${ogr['soyad'] ?? ''}'.trim(),
                      style: const TextStyle(fontSize: 13)),
                  subtitle: Text(ogr['adres'] ?? '',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: (ogr['veliTel'] ?? '').isNotEmpty
                      ? GestureDetector(
                      onTap: () => _whatsapp(ogr['veliTel']),
                      child: const Icon(Icons.message_outlined, color: Color(0xFF25D366), size: 20))
                      : null,
                )),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAtamasizlar() {
    final atamasizlar = _ogrenciler.where((o) => (o['surucuId'] ?? '').isEmpty).toList();

    if (atamasizlar.isEmpty) {
      return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
        SizedBox(height: 12),
        Text('Tüm öğrenciler atanmış!',
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
      ]));
    }

    return Column(children: [
      Container(
        color: Colors.orange.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          const Icon(Icons.warning_amber_outlined, color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          Text('${atamasizlar.length} öğrenci henüz atanmadı',
              style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600, fontSize: 13)),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/gruplama'),
            child: const Text('Ata', style: TextStyle(color: _navy, fontSize: 12)),
          ),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: atamasizlar.length,
          itemBuilder: (_, i) {
            final ogr = atamasizlar[i];
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
                    Text(ogr['adres'], style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                const Icon(Icons.person_off_outlined, color: Colors.orange, size: 18),
              ]),
            );
          },
        ),
      ),
    ]);
  }
}
