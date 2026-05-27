import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/session_service.dart';
import 'dashboard_screen.dart';

class ProjeSecScreen extends StatefulWidget {
  const ProjeSecScreen({super.key});
  @override
  State<ProjeSecScreen> createState() => _ProjeSecScreenState();
}

class _ProjeSecScreenState extends State<ProjeSecScreen> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _orange  = Color(0xFFFF8C00);

  String _firmaId  = '';
  String _firmaAdi = '';
  bool   _yukleniyor = true;
  List<Map<String, dynamic>> _projeler = [];

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final firmaId  = await SessionService.instance.firmaIdAl();
    final firmaAdi = await SessionService.instance.firmaAdiAl();
    if (firmaId == null) return;
    _firmaId  = firmaId;
    _firmaAdi = firmaAdi ?? '';

    final snap = await FirebaseFirestore.instance
        .collection('projects')
        .where('firmaId', isEqualTo: firmaId)
        .where('aktif', isEqualTo: true)
        .orderBy('olusturmaTarihi', descending: true)
        .get();

    setState(() {
      _projeler = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      _yukleniyor = false;
    });
  }

  void _projeAc(Map<String, dynamic> proje) {
    SessionService.instance.aktifProjeAyarla(
      proje['id'] as String,
      proje['projeAd'] as String? ?? 'Proje',
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  void _yeniProjeOlustur() {
    Navigator.pushNamed(context, '/projeler');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: SafeArea(
        child: Column(children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_navy, Color(0xFF2a5298)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(10)),
                  child: const Center(child: Text('S', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20))),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Servisim360', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                  Text(_firmaAdi, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ]),
              const SizedBox(height: 24),
              const Text('Proje Seçin', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text('Hangi projede çalışmak istiyorsunuz?', style: TextStyle(color: Colors.white70, fontSize: 13)),
            ]),
          ),

          // İçerik
          Expanded(
            child: _yukleniyor
                ? const Center(child: CircularProgressIndicator())
                : _projeler.isEmpty
                ? _BosEkran(onYeniProje: _yeniProjeOlustur)
                : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                ..._projeler.map((proje) => _ProjeKarti(
                  proje: proje,
                  onTap: () => _projeAc(proje),
                )),
                const SizedBox(height: 12),
                // Yeni proje butonu
                GestureDetector(
                  onTap: _yeniProjeOlustur,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _orange.withValues(alpha: 0.4), width: 1.5),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: _orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.add_circle_outline, color: _orange, size: 22),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Yeni Proje Olustur', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _navy)),
                        Text('Yeni donem veya okul icin proje ac', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ])),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _ProjeKarti extends StatelessWidget {
  final Map<String, dynamic> proje;
  final VoidCallback onTap;
  static const _navy = Color(0xFF1a3a6b);

  const _ProjeKarti({required this.proje, required this.onTap});

  Color get _tipRenk => proje['tip'] == 'kolej'
      ? Colors.blue
      : proje['tip'] == 'personel'
      ? Colors.purple
      : _navy;

  IconData get _tipIkon => proje['tip'] == 'kolej'
      ? Icons.account_balance_outlined
      : proje['tip'] == 'personel'
      ? Icons.badge_outlined
      : Icons.school_outlined;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _tipRenk.withValues(alpha: 0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _tipRenk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(_tipIkon, color: _tipRenk, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(proje['projeAd'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _navy)),
            Text('${proje['donem'] ?? ''} · ${_tipAd(proje['tip'] ?? '')}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            if ((proje['not'] ?? '').isNotEmpty)
              Text(proje['not'], style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ])),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _tipRenk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.arrow_forward_ios, color: _tipRenk, size: 14),
          ),
        ]),
      ),
    );
  }

  static String _tipAd(String t) => t == 'kolej' ? 'Kolej' : t == 'personel' ? 'Personel' : 'Okul';
}

class _BosEkran extends StatelessWidget {
  final VoidCallback onYeniProje;
  static const _navy  = Color(0xFF1a3a6b);
  static const _orange= Color(0xFFFF8C00);
  const _BosEkran({required this.onYeniProje});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.folder_open_outlined, size: 80, color: Colors.grey[300]),
        const SizedBox(height: 20),
        const Text('Henuz proje yok', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 8),
        const Text('Baslamak icin bir proje olusturun.\nHer donem veya okul icin ayri proje acabilirsiniz.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5)),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _orange, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: onYeniProje,
            icon: const Icon(Icons.add),
            label: const Text('Ilk Projeyi Olustur', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ),
      ]),
    );
  }
}
