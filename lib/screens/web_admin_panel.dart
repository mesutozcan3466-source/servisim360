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

  int    _aktifSekme  = 0;
  String _firmaAdi    = '';
  String _kullaniciAd = '';
  String _firmaId     = '';
  bool   _yukleniyor  = true;

  int _toplamSurucu  = 0;
  int _toplamOgrenci = 0;
  int _toplamVeli    = 0;
  int _aktifServis   = 0;

  static const List<_MenuItem> _menuler = [
    _MenuItem('Dashboard',   Icons.dashboard_outlined,      0),
    _MenuItem('Soforler',    Icons.directions_car_outlined, 1),
    _MenuItem('Ogrenciler',  Icons.school_outlined,         2),
    _MenuItem('Veliler',     Icons.family_restroom_outlined,3),
    _MenuItem('Devamsizlik', Icons.event_busy_outlined,     4),
    _MenuItem('Raporlar',    Icons.bar_chart_outlined,      5),
    _MenuItem('Ayarlar',     Icons.settings_outlined,       6),
  ];

  @override
  void initState() { super.initState(); _yukle(); }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final fId = await SessionService.instance.firmaldAl();
      _firmaId  = fId ?? '';

      final kulDoc = await FirebaseFirestore.instance
          .collection('kullanicilar').doc(user.uid).get();
      _kullaniciAd = kulDoc.data()?['ad'] ?? user.email ?? '';

      if (_firmaId.isNotEmpty) {
        final firmaDoc = await FirebaseFirestore.instance
            .collection('firms').doc(_firmaId).get();
        _firmaAdi = firmaDoc.data()?['firmaAdi'] ??
            firmaDoc.data()?['ad'] ?? '';

        final s = await FirebaseFirestore.instance
            .collection('drivers')
            .where('firmaId', isEqualTo: _firmaId).get();
        _toplamSurucu = s.docs.length;
        _aktifServis  = s.docs
            .where((d) => d.data()['servisAktif'] == true).length;

        final o = await FirebaseFirestore.instance
            .collection('students')
            .where('firmaId', isEqualTo: _firmaId).get();
        _toplamOgrenci = o.docs.length;

        final v = await FirebaseFirestore.instance
            .collection('parents')
            .where('firmaId', isEqualTo: _firmaId).get();
        _toplamVeli = v.docs.length;
      }
    } catch (e) { debugPrint('Admin panel hata: $e'); }
    if (mounted) setState(() => _yukleniyor = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return const Scaffold(backgroundColor: _navy,
          body: Center(child: CircularProgressIndicator(
              color: Color(0xFFFF8C00))));
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Row(children: [

        // Sol menu
        Container(
          width: 220, color: _navy,
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment:
              CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                        color: _turuncu,
                        borderRadius: BorderRadius.circular(8)),
                    child: const Center(child: Text('S',
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18))),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Servisim360',
                      style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14))),
                ]),
                const SizedBox(height: 6),
                Text(_firmaAdi,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              ]),
            ),
            const Divider(color: Colors.white12),
            ..._menuler.map((item) {
              final secili = _aktifSekme == item.index;
              return GestureDetector(
                onTap: () => setState(() => _aktifSekme = item.index),
                child: Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 2),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: secili
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: secili ? Border.all(
                        color: _turuncu.withValues(alpha: 0.5)) : null,
                  ),
                  child: Row(children: [
                    Icon(item.ikon,
                        color: secili ? _turuncu : Colors.white54,
                        size: 18),
                    const SizedBox(width: 10),
                    Text(item.ad, style: TextStyle(
                        color: secili ? Colors.white : Colors.white60,
                        fontWeight: secili
                            ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13)),
                    if (item.index == 4 && _aktifServis > 0) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(10)),
                        child: Text('$_aktifServis',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ]),
                ),
              );
            }),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                CircleAvatar(
                  radius: 14, backgroundColor: _turuncu,
                  child: Text(
                      _kullaniciAd.isNotEmpty
                          ? _kullaniciAd[0].toUpperCase() : 'A',
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(_kullaniciAd,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11),
                    overflow: TextOverflow.ellipsis)),
                IconButton(
                  icon: const Icon(Icons.logout_outlined,
                      color: Colors.white38, size: 16),
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

        // Icerik
        Expanded(child: Column(children: [

          // Ust bar
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 28, vertical: 14),
            color: Colors.white,
            child: Row(children: [
              Text(_menuler[_aktifSekme].ad,
                  style: const TextStyle(fontSize: 20,
                      fontWeight: FontWeight.bold, color: _navy)),
              const Spacer(),
              if (_aktifServis > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    Container(width: 8, height: 8,
                        decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('$_aktifServis Aktif Servis',
                        style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ]),
                ),
            ]),
          ),

          Expanded(child: _sekmeIcerigi()),
        ])),
      ]),
    );
  }

  Widget _sekmeIcerigi() {
    switch (_aktifSekme) {
      case 0: return _DashboardSekme(
          toplamSurucu:  _toplamSurucu,
          toplamOgrenci: _toplamOgrenci,
          toplamVeli:    _toplamVeli,
          aktifServis:   _aktifServis,
          firmaId:       _firmaId,
          onNavigate:    (i) => setState(() => _aktifSekme = i));
      case 1: return WebSoforler(firmaId: _firmaId);
      case 2: return _OgrencilerSekme(firmaId: _firmaId);
      case 3: return _VelilerSekme(firmaId: _firmaId);
      case 4: return _DevamsizlikSekme(firmaId: _firmaId);
      case 5: return const WebRaporlar();
      default: return Center(child: Text(
          _menuler[_aktifSekme].ad,
          style: const TextStyle(fontSize: 20, color: Colors.grey)));
    }
  }
}

class _MenuItem {
  final String ad;
  final IconData ikon;
  final int index;
  const _MenuItem(this.ad, this.ikon, this.index);
}

// ════════════════════════════════════════════════════════════════
//  DASHBOARD
// ════════════════════════════════════════════════════════════════
class _DashboardSekme extends StatelessWidget {
  final int toplamSurucu, toplamOgrenci, toplamVeli, aktifServis;
  final String firmaId;
  final void Function(int) onNavigate;

  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  const _DashboardSekme({
    required this.toplamSurucu,
    required this.toplamOgrenci,
    required this.toplamVeli,
    required this.aktifServis,
    required this.firmaId,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat kartlari
          Wrap(spacing: 14, runSpacing: 14, children: [
            _StatKart('Toplam Sofor', '$toplamSurucu',
                Icons.directions_car_outlined, _navy,
                    () => onNavigate(1)),
            _StatKart('Toplam Ogrenci', '$toplamOgrenci',
                Icons.school_outlined, Colors.blue,
                    () => onNavigate(2)),
            _StatKart('Toplam Veli', '$toplamVeli',
                Icons.family_restroom_outlined, Colors.purple,
                    () => onNavigate(3)),
            _StatKart('Aktif Servis', '$aktifServis',
                Icons.directions_bus_outlined, Colors.green,
                    () => onNavigate(1)),
          ]),
          const SizedBox(height: 28),

          // Son devamsizliklar
          const Text('Son Devamsizlik Bildirimleri',
              style: TextStyle(fontSize: 16,
                  fontWeight: FontWeight.bold, color: _navy)),
          const SizedBox(height: 14),
          _SonDevamsizliklar(firmaId: firmaId),
        ],
      ),
    );
  }
}

class _StatKart extends StatelessWidget {
  final String baslik, deger;
  final IconData ikon;
  final Color renk;
  final VoidCallback onTap;

  const _StatKart(this.baslik, this.deger, this.ikon,
      this.renk, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 180,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                  color: renk.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(ikon, color: renk, size: 20),
            ),
            const SizedBox(height: 10),
            Text(deger, style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: renk)),
            Text(baslik, style: TextStyle(
                fontSize: 12, color: Colors.grey[600])),
          ]),
    ),
  );
}

class _SonDevamsizliklar extends StatelessWidget {
  final String firmaId;
  const _SonDevamsizliklar({required this.firmaId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('absence_requests')
          .where('firmaId', isEqualTo: firmaId)
          .orderBy('tarih', descending: true)
          .limit(5)
          .snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [
              Icon(Icons.check_circle_outline,
                  color: Colors.green, size: 20),
              SizedBox(width: 10),
              Text('Bekleyen devamsizlik bildirimi yok',
                  style: TextStyle(color: Colors.grey)),
            ]),
          );
        }
        return Column(
          children: docs.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final durum = d['durum'] as String? ?? 'bekliyor';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _durumRengi(durum).withValues(alpha: 0.3)),
                boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4)],
              ),
              child: Row(children: [
                Icon(Icons.event_busy_outlined,
                    color: _durumRengi(durum), size: 20),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d['ogrenciAd'] ?? 'Ogrenci',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold)),
                    Text(d['aciklama'] ?? '',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                )),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: _durumRengi(durum).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(durum, style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold,
                      color: _durumRengi(durum))),
                ),
              ]),
            );
          }).toList(),
        );
      },
    );
  }

  Color _durumRengi(String durum) {
    switch (durum) {
      case 'onaylandi': return Colors.green;
      case 'reddedildi': return Colors.red;
      default: return Colors.orange;
    }
  }
}

// ════════════════════════════════════════════════════════════════
//  OGRENCILER SEKMESI
// ════════════════════════════════════════════════════════════════
class _OgrencilerSekme extends StatefulWidget {
  final String firmaId;
  const _OgrencilerSekme({required this.firmaId});
  @override
  State<_OgrencilerSekme> createState() => _OgrencilerSekmeState();
}

class _OgrencilerSekmeState extends State<_OgrencilerSekme> {
  static const _navy = Color(0xFF1a3a6b);
  String _aramaMetni = '';
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      padding: const EdgeInsets.all(16), color: Colors.white,
      child: Row(children: [
        Expanded(child: TextField(
          controller: _ctrl,
          decoration: InputDecoration(
            hintText: 'Ogrenci ara...',
            prefixIcon: const Icon(Icons.search,
                color: _navy, size: 18),
            filled: true, fillColor: const Color(0xFFF5F7FA),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
          ),
          onChanged: (v) =>
              setState(() => _aramaMetni = v.toLowerCase()),
        )),
      ]),
    ),
    Expanded(child: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('students')
          .where('firmaId', isEqualTo: widget.firmaId)
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        var docs = snap.data?.docs ?? [];
        if (_aramaMetni.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return (data['ad'] ?? '').toString()
                .toLowerCase().contains(_aramaMetni);
          }).toList();
        }
        if (docs.isEmpty) {
          return const Center(child: Text('Ogrenci bulunamadi',
              style: TextStyle(color: Colors.grey)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final bindi = d['bindi'] == true;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4)],
              ),
              child: Row(children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _navy.withValues(alpha: 0.1),
                  child: Text(
                      (d['ad'] ?? '?').isNotEmpty
                          ? d['ad'][0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: _navy, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d['ad'] ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold)),
                    Text(d['adres'] ?? '',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (d['sinif'] != null && d['sinif'] != '')
                      Text('Sinif: ${d['sinif']}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[400])),
                  ],
                )),
                Column(crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: (bindi ? Colors.green : Colors.grey)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(bindi ? 'Bindi' : 'Bekliyor',
                            style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.bold,
                                color: bindi ? Colors.green : Colors.grey)),
                      ),
                      if (d['telefon'] != null && d['telefon'] != '') ...[
                        const SizedBox(height: 4),
                        Text(d['telefon'],
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[400])),
                      ],
                    ]),
              ]),
            );
          },
        );
      },
    )),
  ]);
}

// ════════════════════════════════════════════════════════════════
//  VELILER SEKMESI
// ════════════════════════════════════════════════════════════════
class _VelilerSekme extends StatefulWidget {
  final String firmaId;
  const _VelilerSekme({required this.firmaId});
  @override
  State<_VelilerSekme> createState() => _VelilerSekmeState();
}

class _VelilerSekmeState extends State<_VelilerSekme> {
  static const _navy = Color(0xFF1a3a6b);
  String _aramaMetni = '';
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      padding: const EdgeInsets.all(16), color: Colors.white,
      child: TextField(
        controller: _ctrl,
        decoration: InputDecoration(
          hintText: 'Veli ara...',
          prefixIcon: const Icon(Icons.search,
              color: _navy, size: 18),
          filled: true, fillColor: const Color(0xFFF5F7FA),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
        ),
        onChanged: (v) =>
            setState(() => _aramaMetni = v.toLowerCase()),
      ),
    ),
    Expanded(child: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('parents')
          .where('firmaId', isEqualTo: widget.firmaId)
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        var docs = snap.data?.docs ?? [];
        if (_aramaMetni.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return (data['ad'] ?? data['email'] ?? '').toString()
                .toLowerCase().contains(_aramaMetni);
          }).toList();
        }
        if (docs.isEmpty) {
          return const Center(child: Text('Veli bulunamadi',
              style: TextStyle(color: Colors.grey)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4)],
              ),
              child: Row(children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.purple.withValues(alpha: 0.1),
                  child: Text(
                      (d['ad'] ?? d['email'] ?? '?').isNotEmpty
                          ? (d['ad'] ?? d['email'])[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: Colors.purple,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d['ad'] ?? d['email'] ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold)),
                    Text(d['email'] ?? '',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500])),
                    if (d['telefon'] != null)
                      Text(d['telefon'],
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[400])),
                  ],
                )),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6)),
                  child: const Text('Veli', style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.bold,
                      color: Colors.purple)),
                ),
              ]),
            );
          },
        );
      },
    )),
  ]);
}

// ════════════════════════════════════════════════════════════════
//  DEVAMSIZLIK SEKMESI
// ════════════════════════════════════════════════════════════════
class _DevamsizlikSekme extends StatefulWidget {
  final String firmaId;
  const _DevamsizlikSekme({required this.firmaId});
  @override
  State<_DevamsizlikSekme> createState() => _DevamsizlikSekmeState();
}

class _DevamsizlikSekmeState extends State<_DevamsizlikSekme> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  String _durumFiltre = 'Tumu';

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      padding: const EdgeInsets.all(16), color: Colors.white,
      child: Row(children: [
        const Text('Filtre:', style: TextStyle(
            fontWeight: FontWeight.bold, color: _navy)),
        const SizedBox(width: 12),
        ...['Tumu', 'bekliyor', 'onaylandi', 'reddedildi'].map((d) {
          final secili = _durumFiltre == d;
          return GestureDetector(
            onTap: () => setState(() => _durumFiltre = d),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: secili ? _navy : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(d, style: TextStyle(
                  color: secili ? Colors.white : Colors.grey[700],
                  fontSize: 12,
                  fontWeight: secili
                      ? FontWeight.bold : FontWeight.normal)),
            ),
          );
        }),
      ]),
    ),
    Expanded(child: StreamBuilder<QuerySnapshot>(
      stream: _durumFiltre == 'Tumu'
          ? FirebaseFirestore.instance
          .collection('absence_requests')
          .where('firmaId', isEqualTo: widget.firmaId)
          .orderBy('tarih', descending: true)
          .snapshots()
          : FirebaseFirestore.instance
          .collection('absence_requests')
          .where('firmaId', isEqualTo: widget.firmaId)
          .where('durum', isEqualTo: _durumFiltre)
          .orderBy('tarih', descending: true)
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('Devamsizlik bildirimi yok',
              style: TextStyle(color: Colors.grey)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final durum = d['durum'] as String? ?? 'bekliyor';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _durumRengi(durum).withValues(alpha: 0.2)),
                boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4)],
              ),
              child: Row(children: [
                Icon(Icons.event_busy_outlined,
                    color: _durumRengi(durum), size: 22),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d['ogrenciAd'] ?? 'Ogrenci',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold)),
                    Text(d['aciklama'] ?? d['not'] ?? '',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500])),
                    Text(d['tarih']?.toString().substring(0, 10) ?? '',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[400])),
                  ],
                )),
                if (durum == 'bekliyor') Row(children: [
                  _AksBtn('Onayla', Colors.green, () async {
                    await FirebaseFirestore.instance
                        .collection('absence_requests')
                        .doc(docs[i].id)
                        .update({'durum': 'onaylandi'});
                  }),
                  const SizedBox(width: 6),
                  _AksBtn('Reddet', Colors.red, () async {
                    await FirebaseFirestore.instance
                        .collection('absence_requests')
                        .doc(docs[i].id)
                        .update({'durum': 'reddedildi'});
                  }),
                ]) else Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: _durumRengi(durum).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(durum, style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold,
                      color: _durumRengi(durum))),
                ),
              ]),
            );
          },
        );
      },
    )),
  ]);

  Color _durumRengi(String durum) {
    switch (durum) {
      case 'onaylandi':  return Colors.green;
      case 'reddedildi': return Colors.red;
      default:           return Colors.orange;
    }
  }
}

class _AksBtn extends StatelessWidget {
  final String label;
  final Color renk;
  final VoidCallback onTap;
  const _AksBtn(this.label, this.renk, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: renk.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: renk.withValues(alpha: 0.3))),
      child: Text(label, style: TextStyle(
          fontSize: 11, color: renk, fontWeight: FontWeight.bold)),
    ),
  );
}