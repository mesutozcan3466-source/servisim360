import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/session_service.dart';
import 'web_soforler.dart';
import 'web_raporlar.dart';

class WebAdminPanel extends StatefulWidget {
  const WebAdminPanel({super.key});

  @override
  State<WebAdminPanel> createState() => _WebAdminPanelState();
}

class _WebAdminPanelState extends State<WebAdminPanel> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  int    _sekmе      = 0;
  String _firmaAdi   = '';
  String _kullaniciAd = '';
  bool   _yukleniyor  = true;

  // İstatistikler
  int _toplamSurucu   = 0;
  int _toplamOgrenci  = 0;
  int _toplamVeli     = 0;
  int _aktifServis    = 0;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final firmaId = await SessionService.instance.firmaldAl();

      final kulDoc = await FirebaseFirestore.instance
          .collection('kullanicilar').doc(user.uid).get();
      _kullaniciAd = kulDoc.data()?['ad'] ?? user.email ?? '';

      if (firmaId != null) {
        final firmaDoc = await FirebaseFirestore.instance
            .collection('firms').doc(firmaId).get();
        _firmaAdi = firmaDoc.data()?['ad'] ?? '';

        // İstatistikler
        final surucuSnap = await FirebaseFirestore.instance
            .collection('drivers')
            .where('firmaId', isEqualTo: firmaId).get();
        _toplamSurucu = surucuSnap.docs.length;
        _aktifServis  = surucuSnap.docs
            .where((d) => d.data()['servisAktif'] == true).length;

        final ogrSnap = await FirebaseFirestore.instance
            .collection('students')
            .where('firmaId', isEqualTo: firmaId).get();
        _toplamOgrenci = ogrSnap.docs.length;

        final veliSnap = await FirebaseFirestore.instance
            .collection('parents')
            .where('firmaId', isEqualTo: firmaId).get();
        _toplamVeli = veliSnap.docs.length;
      }
    } catch (e) {
      debugPrint('Admin panel yukle hata: $e');
    }

    if (mounted) setState(() => _yukleniyor = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return const Scaffold(
        backgroundColor: _navy,
        body: Center(child: CircularProgressIndicator(color: _turuncu)),
      );
    }

    return Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        body: Row(children: [

          // ── SOL MENÜ ──────────────────────────────────────────────
          Container(
          width: 240,
          color: _navy,
          child: Column(children: [
            // Logo & firma
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: _turuncu,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text('S',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Servisim360',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text(_firmaAdi,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12)),
                ],
              ),
            ),

            const Divider(color: Colors.white12),

            // Menü öğeleri
            ...[
              ('Dashboard', Icons.dashboard_outlined,      0),
              ('Soforler',  Icons.directions_car_outlined, 1),
              ('Ogrenciler',Icons.people_outline,          2),
              ('Raporlar',  Icons.bar_chart_outlined,      3),
              ('Ayarlar',   Icons.settings_outlined,       4),
            ].map((item) {
              final secili = _sekmе == item.$3;
              return GestureDetector(
              onTap: () => setState(() => _sekmе = item.$3),
              child: Container(
              margin: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 2),
              padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
              color: secili
              ? Colors.white.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: secili
              ? Border.all(
              color: _turuncu.withValues(alpha: 0.5))
                  : null,
              ),
              child: Row(children: [
              Icon(item.$2,
              color: secili ? _turuncu : Colors.white54,
              size: 20),
              const SizedBox(width: 12),
              Text(item.$1,
              style: TextStyle(
              color: secili
              ? Colors.white
                  : Colors.white60,
              fontWeight: secili
              ? FontWeight.bold
                  : FontWeight.normal,
              fontSize: 14)),
              ]),
              ),
              );
            }),

            const Spacer(),

            // Kullanici & çıkış
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: _turuncu,
                  child: Text(
                      _kullaniciAd.isNotEmpty
                          ? _kullaniciAd[0].toUpperCase()
                          : 'A',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_kullaniciAd,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  icon: const Icon(Icons.logout_outlined,
                      color: Colors.white38, size: 18),
                  onPressed: () async {
                    await SessionService.instance.cikisYap();
                    if (mounted) {
                      Navigator.pushReplacementNamed(context, '/');
                    }
                  },
                ),
              ]),
            ),
          ]),
        ),

        // ── IÇERIK ────────────────────────────────────────────────
        Expanded(
          child: Column(children: [

          // Üst bar
          Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 32, vertical: 16),
          color: Colors.white,
          child: Row(children: [
            Text(
              ['Dashboard', 'Soforler', 'Ogrenciler',
                'Raporlar', 'Ayarlar'][_sekmе],
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _navy),
            ),
            const Spacer(),
            if (_aktifServis > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('$_aktifServis Aktif Servis',
                      style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ]),
              ),
          ]),
        ),

        // Sekme içeriği
        Expanded(
          child: _sekmе == 0
          ? _DashboardSekme(
          toplamSurucu:  _toplamSurucu,
          toplamOgrenci: _toplamOgrenci,
          toplamVeli:    _toplamVeli,
          aktifServis:   _aktifServis,
        )
            : _sekmе == 1
        ? const WebSoforler()
        : _sekmе == 3
    ? const WebRaporlar()
        : Center(
    child: Text(
    ['', '', 'Ogrenciler', '', 'Ayarlar'][_sekmе],
    style: const TextStyle(
    fontSize: 24, color: Colors.grey),
    ),
    ),
    ),
    ]),
    ),
    ]),
    );
  }
}

// ── Dashboard Sekmesi ─────────────────────────────────────────────
class _DashboardSekme extends StatelessWidget {
  final int toplamSurucu, toplamOgrenci, toplamVeli, aktifServis;
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  const _DashboardSekme({
    required this.toplamSurucu,
    required this.toplamOgrenci,
    required this.toplamVeli,
    required this.aktifServis,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // İstatistik kartları
          Row(children: [
            _StatKart('Toplam Sofor',   '$toplamSurucu',
                Icons.directions_car_outlined, _navy),
            const SizedBox(width: 16),
            _StatKart('Toplam Ogrenci', '$toplamOgrenci',
                Icons.people_outline, Colors.blue),
            const SizedBox(width: 16),
            _StatKart('Toplam Veli',    '$toplamVeli',
                Icons.family_restroom_outlined, Colors.purple),
            const SizedBox(width: 16),
            _StatKart('Aktif Servis',   '$aktifServis',
                Icons.directions_bus_outlined, Colors.green),
          ]),
          const SizedBox(height: 32),

          const Text('Hizli Erisim',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _navy)),
          const SizedBox(height: 16),

          Wrap(spacing: 16, runSpacing: 16, children: [
            _HizliButon('Sofor Ekle',    Icons.person_add_outlined,    Colors.green),
            _HizliButon('Ogrenci Ekle',  Icons.school_outlined,        Colors.blue),
            _HizliButon('Rapor Al',      Icons.download_outlined,      _turuncu),
            _HizliButon('Canlı Harita',  Icons.map_outlined,           Colors.teal),
          ]),
        ],
      ),
    );
  }
}

class _StatKart extends StatelessWidget {
  final String baslik, deger;
  final IconData ikon;
  final Color renk;

  const _StatKart(this.baslik, this.deger, this.ikon, this.renk);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10),
        ],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: renk.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(ikon, color: renk, size: 24),
        ),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(deger,
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: renk)),
          Text(baslik,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey[600])),
        ]),
      ]),
    ),
  );
}

class _HizliButon extends StatelessWidget {
  final String etiket;
  final IconData ikon;
  final Color renk;

  const _HizliButon(this.etiket, this.ikon, this.renk);

  @override
  Widget build(BuildContext context) => Container(
    width: 160,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10),
      ],
    ),
    child: Column(children: [
      Icon(ikon, color: renk, size: 32),
      const SizedBox(height: 10),
      Text(etiket,
          style: TextStyle(
              color: renk,
              fontWeight: FontWeight.bold,
              fontSize: 13),
          textAlign: TextAlign.center),
    ]),
  );
}