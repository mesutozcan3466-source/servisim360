// â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
// â•‘  DOSYA: lib/screens/proje_sec_screen.dart
// â•‘  PROJE: servisim360
// â•‘  DÃœZELTME: Proje oluÅŸturduktan sonra seÃ§im ekranÄ±na dÃ¶n
// â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/session_service.dart';
import 'dashboard_screen.dart';

class ProjeSecScreen extends StatefulWidget {
  const ProjeSecScreen({super.key});
  @override
  State<ProjeSecScreen> createState() => _ProjeSecScreenState();
}

class _ProjeSecScreenState extends State<ProjeSecScreen> {
  static const _navy   = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);

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
    setState(() => _yukleniyor = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() => _yukleniyor = false);
        return;
      }

      // Firestore'dan direkt oku â€” session'a guvenmiyoruz
      final kulDoc = await FirebaseFirestore.instance
          .collection('kullanicilar').doc(uid).get();
      final firmaId = kulDoc.data()?['firmaId'] as String? ?? '';

      if (firmaId.isEmpty) {
        setState(() => _yukleniyor = false);
        return;
      }

      _firmaId = firmaId;

      // Firma adini al
      final firmaDoc = await FirebaseFirestore.instance
          .collection('firms').doc(firmaId).get();
      _firmaAdi = firmaDoc.data()?['firmaAdi'] ??
          firmaDoc.data()?['ad'] ?? '';

      // Projeleri cek
      final snap = await FirebaseFirestore.instance
          .collection('projects')
          .where('firmaId', isEqualTo: firmaId)
          .where('aktif', isEqualTo: true)
          .orderBy('olusturmaTarihi', descending: true)
          .get();

      setState(() {
        _projeler = snap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList();
        _yukleniyor = false;
      });
    } catch (e) {
      debugPrint('ProjeSecScreen hata: $e');
      setState(() => _yukleniyor = false);
    }
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

  void _tumFirmaGor() {
    SessionService.instance.projeTemizle();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  void _yeniProjeOlustur() {
    Navigator.pushNamed(context, '/projeler').then((_) => _yukle());
  }

  Future<void> _cikisYap() async {
    await SessionService.instance.cikisYap();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
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
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_navy, Color(0xFF2a5298)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 40, height: 40,
                    decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(10)),
                    child: const Center(child: Text('S',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Servisim360',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                  if (_firmaAdi.isNotEmpty)
                    Text(_firmaAdi, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ])),
                // Cikis butonu
                GestureDetector(
                  onTap: _cikisYap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3))),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.logout, color: Colors.white, size: 14),
                      SizedBox(width: 5),
                      Text('Cikis', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              const Text('Proje Secin',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text('Hangi projede calismak istiyorsunuz?',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ]),
          ),

          // Icerik
          Expanded(
            child: _yukleniyor
                ? const Center(child: CircularProgressIndicator(color: _navy))
                : RefreshIndicator(
              onRefresh: _yukle,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Tum firma secenegi
                  GestureDetector(
                    onTap: _tumFirmaGor,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _navy.withValues(alpha: 0.2)),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
                      ),
                      child: Row(children: [
                        Container(padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: _navy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.business_outlined, color: _navy, size: 22)),
                        const SizedBox(width: 14),
                        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Tum Firma', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _navy)),
                          Text('Proje filtresi olmadan tum verileri gor', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ])),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ]),
                    ),
                  ),

                  // Proje listesi
                  if (_projeler.isEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
                      ),
                      child: Column(children: [
                        Icon(Icons.folder_open_outlined, size: 72, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text('Henuz proje yok',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
                        const SizedBox(height: 8),
                        const Text(
                          'Baslamak icin bir proje olusturun.\nHer donem veya okul icin ayri proje acabilirsiniz.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(width: double.infinity, child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: _orange, foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: _yeniProjeOlustur,
                          icon: const Icon(Icons.add),
                          label: const Text('Ilk Projeyi Olustur',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        )),
                      ]),
                    ),
                  ] else ...[
                    ..._projeler.map((proje) => _ProjeKarti(
                      proje: proje,
                      onTap: () => _projeAc(proje),
                      secili: SessionService.instance.aktifProjeld == proje['id'],
                    )),
                  ],

                  const SizedBox(height: 12),

                  // Yeni proje olustur butonu (her zaman gorunur)
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
                        Container(padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                                color: _orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.add_circle_outline, color: _orange, size: 22)),
                        const SizedBox(width: 14),
                        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Yeni Proje Olustur',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _navy)),
                          Text('Yeni donem veya okul icin proje ac',
                              style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ])),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Farkli hesapla giris
                  Center(child: TextButton.icon(
                    onPressed: _cikisYap,
                    icon: const Icon(Icons.switch_account_outlined, color: Colors.grey, size: 16),
                    label: const Text('Farkli Hesapla Giris Yap',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  )),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// â”€â”€ Proje Karti â”€â”€
class _ProjeKarti extends StatelessWidget {
  final Map<String, dynamic> proje;
  final VoidCallback onTap;
  final bool secili;
  static const _navy = Color(0xFF1a3a6b);

  const _ProjeKarti({required this.proje, required this.onTap, this.secili = false});

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
          color: secili ? _navy.withValues(alpha: 0.03) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: secili ? _navy : _tipRenk.withValues(alpha: 0.2),
              width: secili ? 2 : 1),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: _tipRenk.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(_tipIkon, color: _tipRenk, size: 26)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(proje['projeAd'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _navy)),
            Text(
              '${proje['donem'] ?? ''} Â· ${_tipAd(proje['tip'] ?? '')}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if ((proje['not'] ?? '').isNotEmpty)
              Text(proje['not'], style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ])),
          secili
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: _navy,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Text('Aktif',
                      style: TextStyle(color: Colors.white,
                          fontSize: 11, fontWeight: FontWeight.w700)))
              : Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: _tipRenk.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.arrow_forward_ios, color: _tipRenk, size: 14)),
        ]),
      ),
    );
  }

  static String _tipAd(String t) =>
      t == 'kolej' ? 'Kolej' : t == 'personel' ? 'Personel' : 'Okul';
}


