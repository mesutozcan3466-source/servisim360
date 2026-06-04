import 'package:flutter/material.dart';
import 'yardim_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'firma_ekle_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SUPER ADMIN SHELL
// ═══════════════════════════════════════════════════════════════════════════

class SuperAdminShell extends StatefulWidget {
  const SuperAdminShell({super.key});
  @override
  State<SuperAdminShell> createState() => _SuperAdminShellState();
}

class _SuperAdminShellState extends State<SuperAdminShell> {
  int _seciliIndex = 0;
  static const _navy    = Color(0xFF0d1f3c);
  static const _navy2   = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  final List<_MenuItem> _menuler = const [
    _MenuItem(ikon: Icons.dashboard_rounded,     etiket: 'Dashboard'),
    _MenuItem(ikon: Icons.business_rounded,      etiket: 'Firmalar'),
    _MenuItem(ikon: Icons.card_membership,       etiket: 'Lisanslar'),
    _MenuItem(ikon: Icons.people_rounded,        etiket: 'Kullanicilar'),
    _MenuItem(ikon: Icons.support_agent_rounded, etiket: 'Destek'),
    _MenuItem(ikon: Icons.notifications_rounded, etiket: 'Bildirim'),
    _MenuItem(ikon: Icons.settings_rounded,      etiket: 'Ayarlar'),
  ];

  void _digerMenuAc(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ...List.generate(3, (i) {
              final idx = i + 4;
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: _navy2.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(_menuler[idx].ikon, color: _navy2, size: 20),
                ),
                title: Text(_menuler[idx].etiket, style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () { Navigator.pop(context); setState(() => _seciliIndex = idx); },
              );
            }),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.logout_rounded, color: Colors.red, size: 20),
              ),
              title: const Text('Cikis Yap', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.pop(context);
                await FirebaseAuth.instance.signOut();
                if (mounted) Navigator.pushReplacementNamed(context, '/login');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _aktifEkran() {
    switch (_seciliIndex) {
      case 0: return const _DashboardEkrani();
      case 1: return const _FirmalarEkrani();
      case 2: return const _LisansEkrani();
      case 3: return const _KullanicilarEkrani();
      case 4: return const _DestekEkrani();
      case 5: return const _BildirimEkrani();
      case 6: return const _AyarlarEkrani();
      default: return const _DashboardEkrani();
    }
  }

  @override
  Widget build(BuildContext context) {
    final genislik = MediaQuery.of(context).size.width;
    return genislik > 600 ? _tabletLayout() : _telefonLayout();
  }

  Widget _telefonLayout() {
    final bottomIndex = _seciliIndex > 3 ? 4 : _seciliIndex;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        backgroundColor: _navy, elevation: 0, titleSpacing: 16,
        title: Row(children: [
          Container(width: 32, height: 32,
              decoration: const BoxDecoration(color: _turuncu, shape: BoxShape.circle),
              child: const Center(child: Text('S', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)))),
          const SizedBox(width: 10),
          Text(_menuler[_seciliIndex].etiket,
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        ]),
        actions: [
          YardimButonu(ekranAdi: 'Ana Ekran'),
          _CanliBadge(ikon: Icons.business, renk: Colors.white70, koleksiyon: 'firms'),
          const SizedBox(width: 4),
          _CanliBadge(ikon: Icons.drive_eta, renk: Colors.white70, koleksiyon: 'drivers'),
          const SizedBox(width: 8),
        ],
      ),
      body: _aktifEkran(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: _navy,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          child: BottomNavigationBar(
            currentIndex: bottomIndex,
            onTap: (i) { if (i == 4) _digerMenuAc(context); else setState(() => _seciliIndex = i); },
            backgroundColor: _navy,
            selectedItemColor: _turuncu,
            unselectedItemColor: Colors.white38,
            type: BottomNavigationBarType.fixed,
            selectedFontSize: 10, unselectedFontSize: 10, elevation: 0,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded, size: 24),  label: 'Dashboard'),
              BottomNavigationBarItem(icon: Icon(Icons.business_rounded, size: 24),   label: 'Firmalar'),
              BottomNavigationBarItem(icon: Icon(Icons.card_membership, size: 24),    label: 'Lisanslar'),
              BottomNavigationBarItem(icon: Icon(Icons.people_rounded, size: 24),     label: 'Kullanicilar'),
              BottomNavigationBarItem(icon: Icon(Icons.more_horiz_rounded, size: 24), label: 'Diger'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabletLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      body: Row(children: [
        Container(
          width: 200,
          decoration: const BoxDecoration(color: _navy,
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(2, 0))]),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2)),
              child: Row(children: [
                Container(width: 40, height: 40,
                    decoration: const BoxDecoration(color: _turuncu, shape: BoxShape.circle),
                    child: const Center(child: Text('S', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)))),
                const SizedBox(width: 10),
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Servisim360', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Super Admin', style: TextStyle(color: Colors.white38, fontSize: 10)),
                ]),
              ]),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                itemCount: _menuler.length,
                itemBuilder: (context, i) {
                  final secili = _seciliIndex == i;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => _seciliIndex = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: secili ? _turuncu.withValues(alpha: 0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: secili ? Border.all(color: _turuncu.withValues(alpha: 0.3)) : null,
                        ),
                        child: Row(children: [
                          Icon(_menuler[i].ikon, color: secili ? _turuncu : Colors.white38, size: 22),
                          const SizedBox(width: 12),
                          Text(_menuler[i].etiket, style: TextStyle(
                              color: secili ? _turuncu : Colors.white60,
                              fontWeight: secili ? FontWeight.bold : FontWeight.normal,
                              fontSize: 13)),
                        ]),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                const Divider(color: Colors.white12),
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                    if (mounted) Navigator.pushReplacementNamed(context, '/login');
                  },
                  child: const Padding(padding: EdgeInsets.all(8),
                    child: Row(children: [
                      Icon(Icons.logout_rounded, color: Colors.red, size: 20),
                      SizedBox(width: 10),
                      Text('Cikis Yap', style: TextStyle(color: Colors.red, fontSize: 13)),
                    ]),
                  ),
                ),
              ]),
            ),
          ]),
        ),
        Expanded(
          child: Column(children: [
            Container(height: 56, color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Text(_menuler[_seciliIndex].etiket,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _navy)),
                const Spacer(),
                _CanliBadge(ikon: Icons.business, renk: _navy2, koleksiyon: 'firms'),
                const SizedBox(width: 8),
                _CanliBadge(ikon: Icons.drive_eta, renk: Colors.teal, koleksiyon: 'drivers'),
                const SizedBox(width: 16),
                const CircleAvatar(backgroundColor: _turuncu, radius: 16,
                    child: Text('SA', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                const SizedBox(width: 8),
              ]),
            ),
            const Divider(height: 1),
            Expanded(child: _aktifEkran()),
          ]),
        ),
      ]),
    );
  }
}

class _MenuItem {
  final IconData ikon;
  final String etiket;
  const _MenuItem({required this.ikon, required this.etiket});
}

class _CanliBadge extends StatelessWidget {
  final IconData ikon;
  final Color renk;
  final String koleksiyon;
  const _CanliBadge({required this.ikon, required this.renk, required this.koleksiyon});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AggregateQuerySnapshot>(
      future: FirebaseFirestore.instance.collection(koleksiyon).count().get(),
      builder: (context, snap) {
        final sayi = snap.data?.count ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: renk.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: renk.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(ikon, size: 13, color: renk),
            const SizedBox(width: 3),
            Text('$sayi', style: TextStyle(fontSize: 11, color: renk, fontWeight: FontWeight.bold)),
          ]),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// YARDIMCI
// ═══════════════════════════════════════════════════════════════════════════

class _DurumBadge extends StatelessWidget {
  final String durum;
  const _DurumBadge(this.durum);

  Color get _renk {
    switch (durum) {
      case 'aktif':     return Colors.green;
      case 'beklemede': return Colors.orange;
      case 'pasif':     return Colors.grey;
      case 'askida':    return Colors.red;
      default:          return Colors.blueGrey;
    }
  }

  String get _yazi {
    switch (durum) {
      case 'aktif':     return 'AKTiF';
      case 'beklemede': return 'ONAY BEKLiYOR';
      case 'pasif':     return 'PASiF';
      case 'askida':    return 'ASKIDA';
      default:          return durum.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _renk.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _renk.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Text(_yazi, style: TextStyle(fontSize: 10, color: _renk, fontWeight: FontWeight.bold)),
    );
  }
}

class _DetayRow extends StatelessWidget {
  final String etiket, deger;
  const _DetayRow(this.etiket, this.deger);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 90, child: Text(etiket,
            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey, fontSize: 13))),
        Expanded(child: Text(deger, style: const TextStyle(fontSize: 13))),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String etiket, deger;
  final Color renk;
  const _MiniStat(this.etiket, this.deger, this.renk);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: renk.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: renk.withValues(alpha: 0.2)),
        ),
        child: Column(children: [
          Text(deger, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: renk)),
          Text(etiket, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 1. DASHBOARD
// ═══════════════════════════════════════════════════════════════════════════

class _DashboardEkrani extends StatelessWidget {
  const _DashboardEkrani();

  Future<Map<String, int>> _istatistik() async {
    final fs = FirebaseFirestore.instance;
    final r = await Future.wait([
      fs.collection('firms').count().get(),
      fs.collection('drivers').count().get(),
      fs.collection('students').count().get(),
      fs.collection('parents').count().get(),
      fs.collection('licenses').where('durum', isEqualTo: 'aktif').count().get(),
      fs.collection('firms').where('durum', isEqualTo: 'beklemede').count().get(),
    ]);
    return {
      'firma': r[0].count ?? 0, 'sofor': r[1].count ?? 0,
      'ogrenci': r[2].count ?? 0, 'veli': r[3].count ?? 0,
      'aktifLisans': r[4].count ?? 0, 'bekleyenFirma': r[5].count ?? 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final telefon = MediaQuery.of(context).size.width <= 600;
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      body: FutureBuilder<Map<String, int>>(
        future: _istatistik(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final d = snap.data!;
          return SingleChildScrollView(
            padding: EdgeInsets.all(telefon ? 16 : 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GridView.count(
                crossAxisCount: telefon ? 2 : 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12, mainAxisSpacing: 12,
                childAspectRatio: telefon ? 1.6 : 1.8,
                children: [
                  _StatKart('Toplam Firma',   '${d['firma']}',         Icons.business_rounded,      const Color(0xFF1a3a6b), '+2 bu ay'),
                  _StatKart('Aktif Lisans',   '${d['aktifLisans']}',   Icons.verified_rounded,      Colors.green,           'Gecerli'),
                  _StatKart('Bekleyen',       '${d['bekleyenFirma']}', Icons.hourglass_top_rounded,  const Color(0xFFFF8C00), 'Onay bekliyor'),
                  _StatKart('Sofor',          '${d['sofor']}',         Icons.drive_eta_rounded,     Colors.teal,            'Aktif'),
                  _StatKart('Ogrenci',        '${d['ogrenci']}',       Icons.school_rounded,        Colors.purple,          'Kayitli'),
                  _StatKart('Veli',           '${d['veli']}',          Icons.family_restroom,       Colors.indigo,          'Kayitli'),
                ],
              ),
              const SizedBox(height: 24),
              if (telefon) ...[
                const Text('Son Kayit Eden Firmalar',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0d1f3c))),
                const SizedBox(height: 12),
                _SonFirmalarWidget(),
                const SizedBox(height: 20),
                const Text('Sistem Sagligi',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0d1f3c))),
                const SizedBox(height: 12),
                const _SistemSagligiWidget(),
              ] else ...[
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Son Kayit Eden Firmalar',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0d1f3c))),
                    const SizedBox(height: 12),
                    _SonFirmalarWidget(),
                  ])),
                  const SizedBox(width: 20),
                  const Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Sistem Sagligi',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0d1f3c))),
                    SizedBox(height: 12),
                    _SistemSagligiWidget(),
                  ])),
                ]),
              ],
            ]),
          );
        },
      ),
    );
  }
}

class _StatKart extends StatelessWidget {
  final String baslik, deger, alt;
  final IconData ikon;
  final Color renk;
  const _StatKart(this.baslik, this.deger, this.ikon, this.renk, this.alt);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: renk.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: renk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(ikon, color: renk, size: 22)),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(deger, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: renk)),
            Text(baslik, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            Text(alt, style: TextStyle(fontSize: 10, color: renk.withValues(alpha: 0.7), fontWeight: FontWeight.w500)),
          ],
        )),
      ]),
    );
  }
}

class _SonFirmalarWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('firms')
          .orderBy('kayitTarihi', descending: true).limit(5).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: const Center(child: Text('Henuz firma yok.')),
          );
        }
        return Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(children: docs.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            return ListTile(
              dense: true,
              leading: Container(width: 32, height: 32,
                  decoration: BoxDecoration(color: const Color(0xFF1a3a6b).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.business, color: Color(0xFF1a3a6b), size: 16)),
              title: Text(d['firmaAdi'] ?? 'Isimsiz',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              subtitle: Text(d['telefon'] ?? d['email'] ?? '-', style: const TextStyle(fontSize: 11)),
              trailing: _DurumBadge(d['durum'] ?? 'beklemede'),
            );
          }).toList()),
        );
      },
    );
  }
}

class _SistemSagligiWidget extends StatelessWidget {
  const _SistemSagligiWidget();

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Firebase', Icons.cloud_done_rounded, Colors.green),
      ('Bildirim', Icons.notifications_active, Colors.green),
      ('Harita API', Icons.map_rounded, Colors.green),
      ('Auth Servisi', Icons.security_rounded, Colors.green),
    ];
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(children: items.map((item) => ListTile(
        dense: true,
        leading: Container(width: 30, height: 30,
            decoration: BoxDecoration(color: item.$3.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(item.$2, color: item.$3, size: 15)),
        title: Text(item.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        trailing: Text('Aktif', style: TextStyle(fontSize: 11, color: item.$3, fontWeight: FontWeight.bold)),
      )).toList()),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 2. FIRMALAR — Ayri ekrana yonlendirme
// ═══════════════════════════════════════════════════════════════════════════

class _FirmalarEkrani extends StatefulWidget {
  const _FirmalarEkrani();
  @override
  State<_FirmalarEkrani> createState() => _FirmalarEkraniState();
}

class _FirmalarEkraniState extends State<_FirmalarEkrani> {
  String _filtre = 'hepsi';
  String _arama  = '';
  final List<String> _filtreler = ['hepsi', 'aktif', 'beklemede', 'pasif', 'askida'];

  Future<void> _whatsappGonder(String telefon, String mesaj) async {
    try {
      var numara = telefon.replaceAll(RegExp(r'[^0-9]'), '');
      if (numara.startsWith('0')) numara = '9$numara';
      if (!numara.startsWith('90')) numara = '90$numara';
      final url = Uri.parse('https://wa.me/$numara?text=${Uri.encodeComponent(mesaj)}');
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) { debugPrint('WA hata: $e'); }
  }

  Future<void> _durumGuncelle(String firmaId, String yeniDurum, {
    String? adminUid, String? telefon, String? email, String? firmaAdi,
  }) async {
    await FirebaseFirestore.instance.collection('firms').doc(firmaId).update({'durum': yeniDurum});
    if (adminUid != null && adminUid.isNotEmpty) {
      await FirebaseFirestore.instance.collection('kullanicilar').doc(adminUid).update({
        'durum': yeniDurum == 'aktif' ? 'onayli' : yeniDurum,
      });
    }
    if (yeniDurum == 'aktif' && telefon != null && telefon.isNotEmpty) {
      await _whatsappGonder(telefon,
          'Merhaba!\n\nServisim360 - ${firmaAdi ?? 'Firmaniz'} hesabiniz onaylandi.\n'
              '📧 E-posta: ${email ?? '-'}\n\n'
              'Uygulamayi indirip giris yapabilirsiniz.\n'
              'Servisim360 - Akilli Servis Yonetim Sistemi');
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(yeniDurum == 'aktif' ? '✅ Firma onaylandi!' : 'Durum guncellendi'),
        backgroundColor: yeniDurum == 'aktif' ? Colors.green : Colors.orange,
      ));
    }
  }

  void _firmaDetay(BuildContext context, DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final adminUid = d['adminUid'] as String? ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.8, maxChildSize: 0.95, minChildSize: 0.5,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          padding: const EdgeInsets.all(20),
          child: ListView(controller: ctrl, children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(children: [
              Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: d['durum'] == 'aktif' ? Colors.green.withValues(alpha: 0.1) : const Color(0xFF1a3a6b).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.business,
                      color: d['durum'] == 'aktif' ? Colors.green : const Color(0xFF1a3a6b), size: 24)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d['firmaAdi'] ?? 'Firma', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                _DurumBadge(d['durum'] ?? 'beklemede'),
              ])),
            ]),
            const Divider(height: 24),
            _DetayRow('Yetkili', d['yetkiliAd'] ?? '-'),
            _DetayRow('Email',   d['email']     ?? '-'),
            _DetayRow('Telefon', d['telefon']   ?? '-'),
            _DetayRow('Sehir',   '${d['sehir'] ?? '-'}${(d['ilce'] ?? '').toString().isNotEmpty ? ' / ${d['ilce']}' : ''}'),
            if ((d['adres'] ?? '').toString().isNotEmpty) _DetayRow('Adres', d['adres']),
            _DetayRow('Paket',   d['paket']     ?? '-'),
            if ((d['not'] ?? '').toString().isNotEmpty) _DetayRow('Not', d['not']),
            const SizedBox(height: 16),
            FutureBuilder<List<AggregateQuerySnapshot>>(
              future: Future.wait([
                FirebaseFirestore.instance.collection('drivers').where('firmaId', isEqualTo: doc.id).count().get(),
                FirebaseFirestore.instance.collection('students').where('firmaId', isEqualTo: doc.id).count().get(),
                FirebaseFirestore.instance.collection('parents').where('firmaId', isEqualTo: doc.id).count().get(),
              ]),
              builder: (context, snap) {
                if (!snap.hasData) return const SizedBox();
                return Row(children: [
                  _MiniStat('Sofor', '${snap.data![0].count}', Colors.teal),
                  const SizedBox(width: 8),
                  _MiniStat('Ogrenci', '${snap.data![1].count}', Colors.purple),
                  const SizedBox(width: 8),
                  _MiniStat('Veli', '${snap.data![2].count}', Colors.indigo),
                ]);
              },
            ),
            const SizedBox(height: 20),
            if (d['durum'] == 'beklemede') ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () {
                  Navigator.pop(context);
                  _durumGuncelle(doc.id, 'aktif', adminUid: adminUid,
                      telefon: d['telefon'] ?? '', email: d['email'] ?? '', firmaAdi: d['firmaAdi'] ?? '');
                },
                icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                label: const Text('Onayla ve Aktifle',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () { Navigator.pop(context); _durumGuncelle(doc.id, 'pasif', adminUid: adminUid); },
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Reddet'),
              ),
            ],
            if (d['durum'] == 'aktif') ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(color: const Color(0xFF1a3a6b), borderRadius: BorderRadius.circular(10)),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('FIRMA AKTiF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ]),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.orange, side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () { Navigator.pop(context); _durumGuncelle(doc.id, 'askida', adminUid: adminUid); },
                icon: const Icon(Icons.pause_circle_outline),
                label: const Text('Askiya Al'),
              ),
            ],
            if (d['durum'] == 'askida')
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () {
                  Navigator.pop(context);
                  _durumGuncelle(doc.id, 'aktif', adminUid: adminUid,
                      telefon: d['telefon'] ?? '', email: d['email'] ?? '', firmaAdi: d['firmaAdi'] ?? '');
                },
                icon: const Icon(Icons.play_circle_outline, color: Colors.white),
                label: const Text('Aktifle', style: TextStyle(color: Colors.white)),
              ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final sonuc = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const FirmaEkleScreen()),
          );
          if (sonuc == true && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('✅ Firma basariyla eklendi!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ));
          }
        },
        backgroundColor: const Color(0xFF1a3a6b),
        icon: const Icon(Icons.add_business_rounded, color: Colors.white),
        label: const Text('Firma Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'Firma ara...',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (v) => setState(() => _arama = v.toLowerCase()),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: _filtreler.map((f) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(f), selected: _filtre == f,
                  onSelected: (_) => setState(() => _filtre = f),
                  selectedColor: const Color(0xFF1a3a6b),
                  labelStyle: TextStyle(color: _filtre == f ? Colors.white : Colors.black87, fontSize: 12),
                ),
              )).toList()),
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('firms')
                .orderBy('kayitTarihi', descending: true).snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              var docs = snap.data!.docs;
              if (_filtre != 'hepsi') {
                docs = docs.where((d) => (d.data() as Map<String, dynamic>)['durum'] == _filtre).toList();
              }
              if (_arama.isNotEmpty) {
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return (data['firmaAdi'] ?? '').toLowerCase().contains(_arama) ||
                      (data['telefon'] ?? '').contains(_arama);
                }).toList();
              }
              if (docs.isEmpty) return const Center(child: Text('Firma bulunamadi.'));
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  final beklemede = d['durum'] == 'beklemede';
                  final aktif = d['durum'] == 'aktif';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: beklemede ? 3 : 1,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: aktif ? Colors.green.withValues(alpha: 0.12)
                              : beklemede ? Colors.orange.withValues(alpha: 0.12)
                              : const Color(0xFF1a3a6b).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.business,
                            color: aktif ? Colors.green : beklemede ? Colors.orange : const Color(0xFF1a3a6b),
                            size: 20),
                      ),
                      title: Row(children: [
                        Expanded(child: Text(d['firmaAdi'] ?? 'Isimsiz',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                        if (beklemede) Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(10)),
                          child: const Text('YENi', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                        if (aktif) Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(10)),
                          child: const Text('AKTiF', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ]),
                      subtitle: Text(
                        '${d['telefon'] ?? '-'}  •  ${d['sehir'] ?? '-'}${(d['ilce'] ?? '').toString().isNotEmpty ? ' / ${d['ilce']}' : ''}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: () => _firmaDetay(context, docs[i]),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 3. LISANS
// ═══════════════════════════════════════════════════════════════════════════

class _LisansEkrani extends StatefulWidget {
  const _LisansEkrani();
  @override
  State<_LisansEkrani> createState() => _LisansEkraniState();
}

class _LisansEkraniState extends State<_LisansEkrani> {
  String? _seciliFirmaId, _seciliFirmaAdi;
  int _ay = 1;
  bool _yukleniyor = false, _formAcik = false;

  Future<void> _lisansOlustur() async {
    if (_seciliFirmaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lutfen bir firma secin')));
      return;
    }
    setState(() => _yukleniyor = true);
    try {
      final baslangic = DateTime.now();
      final bitis = DateTime(baslangic.year, baslangic.month + _ay, baslangic.day);
      await FirebaseFirestore.instance.collection('licenses').add({
        'firmaId': _seciliFirmaId, 'firmaAdi': _seciliFirmaAdi,
        'durum': 'aktif', 'baslangic': Timestamp.fromDate(baslangic),
        'bitisTarihi': Timestamp.fromDate(bitis), 'sure': _ay,
        'olusturmaTarihi': FieldValue.serverTimestamp(),
      });
      await FirebaseFirestore.instance.collection('firms').doc(_seciliFirmaId).update({'durum': 'aktif'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$_ay aylik lisans olusturuldu'), backgroundColor: Colors.green));
        setState(() { _seciliFirmaId = null; _seciliFirmaAdi = null; _ay = 1; _formAcik = false; });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => setState(() => _formAcik = !_formAcik),
        backgroundColor: const Color(0xFF1a3a6b),
        icon: Icon(_formAcik ? Icons.close : Icons.add, color: Colors.white),
        label: Text(_formAcik ? 'Iptal' : 'Yeni Lisans', style: const TextStyle(color: Colors.white)),
      ),
      body: Column(children: [
        if (_formAcik)
          Container(
            color: Colors.white, padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Yeni Lisans', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0d1f3c))),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('firms').snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox();
                  return DropdownButtonFormField<String>(
                    value: _seciliFirmaId, hint: const Text('Firma secin'),
                    decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                    items: snap.data!.docs.map((doc) {
                      final d = doc.data() as Map<String, dynamic>;
                      return DropdownMenuItem(value: doc.id, child: Text(d['firmaAdi'] ?? doc.id, overflow: TextOverflow.ellipsis));
                    }).toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      final doc = snap.data!.docs.firstWhere((d) => d.id == val);
                      setState(() { _seciliFirmaId = val; _seciliFirmaAdi = (doc.data() as Map)['firmaAdi']; });
                    },
                  );
                },
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: DropdownButtonFormField<int>(
                  value: _ay,
                  decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  items: const [
                    DropdownMenuItem(value: 1,  child: Text('1 Ay')),
                    DropdownMenuItem(value: 3,  child: Text('3 Ay')),
                    DropdownMenuItem(value: 6,  child: Text('6 Ay')),
                    DropdownMenuItem(value: 12, child: Text('12 Ay')),
                  ],
                  onChanged: (val) => setState(() => _ay = val ?? 1),
                )),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1a3a6b),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: _yukleniyor ? null : _lisansOlustur,
                  child: _yukleniyor
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Olustur', style: TextStyle(color: Colors.white)),
                ),
              ]),
            ]),
          ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('licenses')
                .orderBy('olusturmaTarihi', descending: true).snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final lisanslar = snap.data!.docs;
              if (lisanslar.isEmpty) return const Center(child: Text('Henuz lisans yok.'));
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                itemCount: lisanslar.length,
                itemBuilder: (context, i) {
                  final d = lisanslar[i].data() as Map<String, dynamic>;
                  final bitis = (d['bitisTarihi'] as Timestamp?)?.toDate();
                  final bitisStr = bitis != null ? '${bitis.day}.${bitis.month}.${bitis.year}' : '-';
                  final kalanGun = bitis != null ? bitis.difference(DateTime.now()).inDays : null;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: ListTile(
                      leading: const Icon(Icons.card_membership, color: Color(0xFF1a3a6b)),
                      title: Text(d['firmaAdi'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${d['sure'] ?? '-'} ay  •  Bitis: $bitisStr${kalanGun != null ? '  •  $kalanGun gun' : ''}'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (kalanGun != null && kalanGun <= 7 && d['durum'] == 'aktif')
                          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                        const SizedBox(width: 4),
                        _DurumBadge(d['durum'] ?? '-'),
                        if (d['durum'] == 'aktif') ...[
                          const SizedBox(width: 4),
                          IconButton(icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
                              onPressed: () async {
                                await FirebaseFirestore.instance.collection('licenses').doc(lisanslar[i].id).update({'durum': 'iptal'});
                              }),
                        ],
                      ]),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 4. KULLANICILAR
// ═══════════════════════════════════════════════════════════════════════════

class _KullanicilarEkrani extends StatefulWidget {
  const _KullanicilarEkrani();
  @override
  State<_KullanicilarEkrani> createState() => _KullanicilarEkraniState();
}

class _KullanicilarEkraniState extends State<_KullanicilarEkrani> {
  String _arama = '', _rolFiltre = 'hepsi';

  void _kullaniciDetay(BuildContext context, DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    String secilenRol = d['rol'] ?? 'veli';
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Row(children: [
              CircleAvatar(backgroundColor: const Color(0xFF1a3a6b),
                  child: Text((d['email'] ?? 'U')[0].toUpperCase(), style: const TextStyle(color: Colors.white))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d['email'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                _DurumBadge(d['durum'] ?? 'aktif'),
              ])),
            ]),
            const Divider(height: 20),
            _DetayRow('Rol',   d['rol']     ?? '-'),
            _DetayRow('Firma', d['firmaId'] ?? '-'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: secilenRol,
              decoration: const InputDecoration(labelText: 'Rol Degistir', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'superAdmin', child: Text('Super Admin')),
                DropdownMenuItem(value: 'firmaAdmin', child: Text('Firma Admin')),
                DropdownMenuItem(value: 'sofor',      child: Text('Sofor')),
                DropdownMenuItem(value: 'veli',       child: Text('Veli')),
              ],
              onChanged: (val) => setModalState(() => secilenRol = val ?? secilenRol),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1a3a6b),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                onPressed: () async {
                  await FirebaseFirestore.instance.collection('kullanicilar').doc(doc.id).update({'rol': secilenRol});
                  if (context.mounted) Navigator.pop(context);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Rol "$secilenRol" olarak guncellendi'), backgroundColor: Colors.green));
                },
                child: const Text('Kaydet', style: TextStyle(color: Colors.white)),
              )),
              const SizedBox(width: 8),
              Expanded(child: d['durum'] != 'askida'
                  ? ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                onPressed: () async {
                  await FirebaseFirestore.instance.collection('kullanicilar').doc(doc.id).update({'durum': 'askida'});
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Askiya Al', style: TextStyle(color: Colors.white)),
              )
                  : ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                onPressed: () async {
                  await FirebaseFirestore.instance.collection('kullanicilar').doc(doc.id).update({'durum': 'onayli'});
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Aktifle', style: TextStyle(color: Colors.white)),
              )),
            ]),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      body: Column(children: [
        Container(color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(children: [
            TextField(
              decoration: InputDecoration(hintText: 'Email ile ara...', prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              onChanged: (v) => setState(() => _arama = v.toLowerCase()),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: ['hepsi', 'superAdmin', 'firmaAdmin', 'sofor', 'veli'].map((r) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(r == 'hepsi' ? 'Hepsi' : r), selected: _rolFiltre == r,
                  onSelected: (_) => setState(() => _rolFiltre = r),
                  selectedColor: const Color(0xFF1a3a6b),
                  labelStyle: TextStyle(color: _rolFiltre == r ? Colors.white : Colors.black87, fontSize: 12),
                ),
              )).toList()),
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('kullanicilar').limit(100).snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              var docs = snap.data!.docs;
              if (_rolFiltre != 'hepsi') docs = docs.where((d) => (d.data() as Map<String, dynamic>)['rol'] == _rolFiltre).toList();
              if (_arama.isNotEmpty) docs = docs.where((d) => ((d.data() as Map<String, dynamic>)['email'] ?? '').toLowerCase().contains(_arama)).toList();
              if (docs.isEmpty) return const Center(child: Text('Kullanici bulunamadi.'));
              return ListView.builder(
                padding: const EdgeInsets.all(12), itemCount: docs.length,
                itemBuilder: (context, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF1a3a6b).withValues(alpha: 0.1),
                        child: Text((d['email'] ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(color: Color(0xFF1a3a6b), fontWeight: FontWeight.bold)),
                      ),
                      title: Text(d['email'] ?? 'Email yok', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      subtitle: Text('Rol: ${d['rol'] ?? '-'}  •  Firma: ${d['firmaId'] ?? '-'}', style: const TextStyle(fontSize: 11)),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        _DurumBadge(d['durum'] ?? 'aktif'),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ]),
                      onTap: () => _kullaniciDetay(context, docs[i]),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 5. DESTEK
// ═══════════════════════════════════════════════════════════════════════════

class _DestekEkrani extends StatefulWidget {
  const _DestekEkrani();
  @override
  State<_DestekEkrani> createState() => _DestekEkraniState();
}

class _DestekEkraniState extends State<_DestekEkrani> {
  final _notCtrl = TextEditingController();
  String _kategori = 'Genel';
  bool _yukleniyor = false;
  final List<String> _kategoriler = ['Genel', 'Harita Sorunu', 'Sofor Sorunu', 'Veli Sorunu', 'Lisans Sorunu', 'Teknik'];

  @override
  void dispose() { _notCtrl.dispose(); super.dispose(); }

  Future<void> _logEkle() async {
    if (_notCtrl.text.trim().isEmpty) return;
    setState(() => _yukleniyor = true);
    try {
      await FirebaseFirestore.instance.collection('supportLogs').add({
        'mesaj': _notCtrl.text.trim(), 'kategori': _kategori,
        'tarih': FieldValue.serverTimestamp(),
        'olusturanUid': FirebaseAuth.instance.currentUser?.uid ?? '',
      });
      _notCtrl.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Log eklendi'), backgroundColor: Colors.green));
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      body: Column(children: [
        Container(color: Colors.white, padding: const EdgeInsets.all(12),
          child: Column(children: [
            DropdownButtonFormField<String>(
              value: _kategori,
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              items: _kategoriler.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
              onChanged: (v) => setState(() => _kategori = v ?? 'Genel'),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(
                controller: _notCtrl,
                decoration: InputDecoration(hintText: 'Not ekle...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              )),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1a3a6b),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                onPressed: _yukleniyor ? null : _logEkle,
                child: const Text('Ekle', style: TextStyle(color: Colors.white)),
              ),
            ]),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('supportLogs').orderBy('tarih', descending: true).limit(50).snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs;
              if (docs.isEmpty) return const Center(child: Text('Henuz log yok.'));
              return ListView.builder(
                padding: const EdgeInsets.all(12), itemCount: docs.length,
                itemBuilder: (context, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  final tarih = (d['tarih'] as Timestamp?)?.toDate();
                  final tarihStr = tarih != null
                      ? '${tarih.day}.${tarih.month}.${tarih.year} ${tarih.hour}:${tarih.minute.toString().padLeft(2, '0')}' : '-';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFF1a3a6b).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
                          child: Text(d['kategori'] ?? 'Genel', style: const TextStyle(fontSize: 10, color: Color(0xFF1a3a6b), fontWeight: FontWeight.bold))),
                      const SizedBox(width: 10),
                      Expanded(child: Text(d['mesaj'] ?? '-', style: const TextStyle(fontSize: 13))),
                      Text(tarihStr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ]),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 6. BILDIRIM
// ═══════════════════════════════════════════════════════════════════════════

class _BildirimEkrani extends StatefulWidget {
  const _BildirimEkrani();
  @override
  State<_BildirimEkrani> createState() => _BildirimEkraniState();
}

class _BildirimEkraniState extends State<_BildirimEkrani> {
  final _baslikCtrl = TextEditingController();
  final _mesajCtrl  = TextEditingController();
  String _hedef = 'hepsi';
  String? _hedefFirmaId;
  bool _yukleniyor = false;

  final List<Map<String, String>> _sablonlar = [
    {'baslik': 'Sistem Guncellendi',    'mesaj': 'Servisim360 yeni surume guncellendi.'},
    {'baslik': 'Sunucu Bakimi',          'mesaj': 'Sistem bakimi nedeniyle hizmetlerimiz gecici olarak kesintiye ugrayabilir.'},
    {'baslik': 'Lisans Doluyor',        'mesaj': 'Lisans surenizin dolmasina 7 gun kaldi.'},
    {'baslik': 'Yeni Ozellik',          'mesaj': 'Servisim360 uygulamasina yeni ozellikler eklendi.'},
    {'baslik': 'Acil Duyuru',            'mesaj': 'Sistem yoneticisinden acil bilgilendirme.'},
  ];

  @override
  void dispose() { _baslikCtrl.dispose(); _mesajCtrl.dispose(); super.dispose(); }

  Future<void> _bildirimGonder() async {
    if (_baslikCtrl.text.trim().isEmpty || _mesajCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Baslik ve mesaj zorunlu')));
      return;
    }
    setState(() => _yukleniyor = true);
    try {
      Query<Map<String, dynamic>> sorgu = FirebaseFirestore.instance.collection('kullanicilar');
      if (_hedef == 'firma' && _hedefFirmaId != null) sorgu = sorgu.where('firmaId', isEqualTo: _hedefFirmaId);
      else if (_hedef == 'adminler') sorgu = sorgu.where('rol', isEqualTo: 'firmaAdmin');
      else if (_hedef == 'soforler') sorgu = sorgu.where('rol', isEqualTo: 'sofor');
      else if (_hedef == 'veliler')  sorgu = sorgu.where('rol', isEqualTo: 'veli');
      final kullanicilar = await sorgu.get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in kullanicilar.docs) {
        final ref = FirebaseFirestore.instance.collection('notifications').doc();
        batch.set(ref, {
          'aliciId': doc.id, 'firmaId': doc.data()['firmaId'] ?? '',
          'baslik': _baslikCtrl.text.trim(), 'mesaj': _mesajCtrl.text.trim(),
          'okundu': false, 'tarih': FieldValue.serverTimestamp(), 'tip': 'sistem',
        });
      }
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${kullanicilar.docs.length} kullaniciya gonderildi'), backgroundColor: Colors.green));
        _baslikCtrl.clear(); _mesajCtrl.clear();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Hazir Sablonlar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0d1f3c))),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: _sablonlar.map((s) => GestureDetector(
              onTap: () { _baslikCtrl.text = s['baslik']!; _mesajCtrl.text = s['mesaj']!; },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFF8C00).withValues(alpha: 0.4))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.notifications_outlined, size: 14, color: Color(0xFFFF8C00)),
                  const SizedBox(width: 6),
                  Text(s['baslik']!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                ]),
              ),
            )).toList()),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Hedef', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _hedef,
                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                items: const [
                  DropdownMenuItem(value: 'hepsi',    child: Text('Tum Kullanicilar')),
                  DropdownMenuItem(value: 'adminler', child: Text('Sadece Adminler')),
                  DropdownMenuItem(value: 'soforler', child: Text('Sadece Soforler')),
                  DropdownMenuItem(value: 'veliler',  child: Text('Sadece Veliler')),
                  DropdownMenuItem(value: 'firma',    child: Text('Belirli Firma')),
                ],
                onChanged: (v) => setState(() => _hedef = v ?? 'hepsi'),
              ),
              if (_hedef == 'firma') ...[
                const SizedBox(height: 10),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('firms').snapshots(),
                  builder: (context, snap) {
                    if (!snap.hasData) return const SizedBox();
                    return DropdownButtonFormField<String>(
                      value: _hedefFirmaId, hint: const Text('Firma secin'),
                      decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                      items: snap.data!.docs.map((doc) {
                        final d = doc.data() as Map<String, dynamic>;
                        return DropdownMenuItem(value: doc.id, child: Text(d['firmaAdi'] ?? doc.id));
                      }).toList(),
                      onChanged: (v) => setState(() => _hedefFirmaId = v),
                    );
                  },
                ),
              ],
              const SizedBox(height: 14),
              const Text('Baslik', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              TextField(controller: _baslikCtrl, decoration: InputDecoration(hintText: 'Bildirim basligi...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
              const SizedBox(height: 12),
              const Text('Mesaj', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 8),
              TextField(controller: _mesajCtrl, maxLines: 4, decoration: InputDecoration(hintText: 'Bildirim mesaji...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF8C00),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: _yukleniyor ? null : _bildirimGonder,
                  icon: _yukleniyor
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send, color: Colors.white, size: 18),
                  label: const Text('Gonder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 7. AYARLAR
// ═══════════════════════════════════════════════════════════════════════════

class _AyarlarEkrani extends StatelessWidget {
  const _AyarlarEkrani();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          _AyarKarti(baslik: 'Uygulama', ikon: Icons.info_outline_rounded, renk: const Color(0xFF1a3a6b),
              icerik: const Column(children: [_AyarSatiri('Uygulama', 'Servisim360'), _AyarSatiri('Versiyon', 'v1.0.0')])),
          const SizedBox(height: 12),
          _AyarKarti(baslik: 'Firebase', ikon: Icons.cloud_rounded, renk: Colors.orange,
              icerik: const Column(children: [_AyarSatiri('Project ID', 'servis360-15b4a'), _AyarSatiri('Database', 'eur3')])),
          const SizedBox(height: 12),
          _AyarKarti(baslik: 'Super Admin', ikon: Icons.admin_panel_settings_rounded, renk: Colors.purple,
              icerik: const Column(children: [
                _AyarSatiri('Email', 'mesutozcan3466@gmail.com'),
                _AyarSatiri('Rol',   'superAdmin'),
              ])),
        ]),
      ),
    );
  }
}

class _AyarKarti extends StatelessWidget {
  final String baslik; final IconData ikon; final Color renk; final Widget icerik;
  const _AyarKarti({required this.baslik, required this.ikon, required this.renk, required this.icerik});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: renk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(ikon, color: renk, size: 18)),
          const SizedBox(width: 10),
          Text(baslik, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
        const SizedBox(height: 14),
        icerik,
      ]),
    );
  }
}

class _AyarSatiri extends StatelessWidget {
  final String etiket, deger;
  const _AyarSatiri(this.etiket, this.deger);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        SizedBox(width: 100, child: Text(etiket, style: const TextStyle(color: Colors.grey, fontSize: 13))),
        Expanded(child: Text(deger, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
      ]),
    );
  }
}
