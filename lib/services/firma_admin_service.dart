import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ================================================================
//  FİRMA ADMİN EKRANI - Servisim360
//  Panel | Projeler | Araçlar | Şoförler | Öğrenciler | Ayarlar
// ================================================================

class FirmaAdminScreen extends StatefulWidget {
  const FirmaAdminScreen({super.key});

  @override
  State<FirmaAdminScreen> createState() => _FirmaAdminScreenState();
}

class _FirmaAdminScreenState extends State<FirmaAdminScreen> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  int _seciliMenu = 0;

  static const _menuler = [
    {'ikon': Icons.dashboard_outlined,      'etiket': 'Panel'},
    {'ikon': Icons.folder_outlined,         'etiket': 'Projeler'},
    {'ikon': Icons.directions_bus_outlined, 'etiket': 'Araçlar'},
    {'ikon': Icons.person_outline,          'etiket': 'Şoförler'},
    {'ikon': Icons.school_outlined,         'etiket': 'Öğrenciler'},
    {'ikon': Icons.settings_outlined,       'etiket': 'Ayarlar'},
  ];

  String? _firmaId;
  Map<String, dynamic>? _firmaData;
  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    _firmaYukle();
  }

  Future<void> _firmaYukle() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { setState(() => _yukleniyor = false); return; }

    try {
      final kulDoc = await FirebaseFirestore.instance
          .collection('kullanicilar').doc(uid).get();
      final firmaId = kulDoc.data()?['firmaId'] as String?;

      if (firmaId != null) {
        // firms koleksiyonu — Servisim360 yeni yapısı
        final firmaDoc = await FirebaseFirestore.instance
            .collection('firms').doc(firmaId).get();
        if (mounted) {
          setState(() {
            _firmaId    = firmaId;
            _firmaData  = firmaDoc.data();
            _yukleniyor = false;
          });
        }
      } else {
        if (mounted) setState(() => _yukleniyor = false);
      }
    } catch (e) {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Widget _sayfaGetir() {
    if (_firmaId == null) return const _FirmaYok();
    switch (_seciliMenu) {
      case 0:  return _FirmaPanel(firmaId: _firmaId!, data: _firmaData ?? {});
      case 1:  return _FirmaProjeler(firmaId: _firmaId!);
      case 2:  return _FirmaAraclar(firmaId: _firmaId!);
      case 3:  return _FirmaSoforler(firmaId: _firmaId!);
      case 4:  return _FirmaOgrenciler(firmaId: _firmaId!);
      case 5:  return _FirmaAyarlar(firmaId: _firmaId!, data: _firmaData ?? {});
      default: return _FirmaPanel(firmaId: _firmaId!, data: _firmaData ?? {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF1a3a6b))),
      );
    }

    final firmaAd = _firmaData?['firmaAdi'] ?? _firmaData?['name'] ?? 'Firma Admin';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white, elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(color: _turuncu, borderRadius: BorderRadius.circular(8)),
            child: const Center(
              child: Text('S', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(firmaAd,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              overflow: TextOverflow.ellipsis)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: _sayfaGetir(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, -2))],
        ),
        child: SafeArea(child: SizedBox(height: 64,
          child: Row(children: List.generate(_menuler.length, (i) {
            final aktif = _seciliMenu == i;
            return Expanded(child: GestureDetector(
              onTap: () => setState(() => _seciliMenu = i),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                decoration: BoxDecoration(
                  color: aktif ? _navy : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(_menuler[i]['ikon'] as IconData,
                      color: aktif ? Colors.white : Colors.grey, size: 20),
                  const SizedBox(height: 2),
                  Text(_menuler[i]['etiket'] as String,
                      style: TextStyle(fontSize: 9,
                          color: aktif ? Colors.white : Colors.grey,
                          fontWeight: aktif ? FontWeight.bold : FontWeight.normal)),
                ]),
              ),
            ));
          })),
        )),
      ),
    );
  }
}

class _FirmaYok extends StatelessWidget {
  const _FirmaYok();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.business_outlined, size: 72, color: Color(0xFFCCCCCC)),
      SizedBox(height: 16),
      Text('Firma bulunamadı', style: TextStyle(color: Colors.grey, fontSize: 16)),
      SizedBox(height: 8),
      Text('Bu hesaba bağlı bir firma yok.', style: TextStyle(color: Colors.grey, fontSize: 13)),
    ]),
  );
}

// ── 0. Panel ────────────────────────────────────────────────────
class _FirmaPanel extends StatelessWidget {
  final String firmaId;
  final Map<String, dynamic> data;
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  const _FirmaPanel({required this.firmaId, required this.data});

  @override
  Widget build(BuildContext context) {
    final firmaAd = data['firmaAdi'] ?? data['name'] ?? 'Firma';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [_navy, Color(0xFF2a5298)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(firmaAd,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Yönetim Paneli', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ])),
            const Icon(Icons.business_outlined, color: Colors.white30, size: 48),
          ]),
        ),
        const SizedBox(height: 20),

        _FirmaIstatistik(firmaId: firmaId),
        const SizedBox(height: 20),

        const _SecBaslik('Hızlı Erişim', Icons.grid_view_outlined),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.1,
          children: [
            _HizliKart(Icons.route_outlined,         'Güzergah',   Colors.orange, () => Navigator.pushNamed(context, '/gruplama')),
            _HizliKart(Icons.bar_chart_outlined,     'Raporlar',   Colors.teal,   () => Navigator.pushNamed(context, '/analiz')),
            _HizliKart(Icons.message_outlined,       'Mesajlar',   Colors.blue,   () => Navigator.pushNamed(context, '/toplu_mesaj')),
            _HizliKart(Icons.notifications_outlined, 'Bildirimler',Colors.purple, () => Navigator.pushNamed(context, '/bildirimler')),
            _HizliKart(Icons.map_outlined,           'Canlı Takip',Colors.red,    () => Navigator.pushNamed(context, '/admin_takip')),
            _HizliKart(Icons.link_outlined,          'Kayıt Linki',_navy,         () => Navigator.pushNamed(context, '/kayit_link')),
          ],
        ),
        const SizedBox(height: 40),
      ]),
    );
  }
}

class _FirmaIstatistik extends StatelessWidget {
  final String firmaId;
  const _FirmaIstatistik({required this.firmaId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects').where('firmaId', isEqualTo: firmaId).snapshots(),
      builder: (_, snapProje) => StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('drivers').where('firmaId', isEqualTo: firmaId).snapshots(),
        builder: (_, snapSofor) => StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('students').where('firmaId', isEqualTo: firmaId).snapshots(),
          builder: (_, snapOgr) => GridView.count(
            crossAxisCount: 3, shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.4,
            children: [
              _MiniIstat('${snapProje.data?.docs.length ?? 0}', 'Proje',    const Color(0xFF1a3a6b)),
              _MiniIstat('${snapSofor.data?.docs.length ?? 0}', 'Şoför',    Colors.green),
              _MiniIstat('${snapOgr.data?.docs.length ?? 0}',   'Öğrenci',  Colors.purple),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 1. Projeler ─────────────────────────────────────────────────
class _FirmaProjeler extends StatelessWidget {
  final String firmaId;
  static const _navy = Color(0xFF1a3a6b);
  const _FirmaProjeler({required this.firmaId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects').where('firmaId', isEqualTo: firmaId).snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        return ListView(padding: const EdgeInsets.all(16), children: [
          if (docs.isEmpty) const _BosEkran('Henüz proje eklenmemiş', Icons.folder_open_outlined),
          ...docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: _navy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.folder_outlined, color: _navy, size: 22)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(data['projeAd'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('${data['donem'] ?? ''} · ${data['tip'] ?? ''}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ])),
                Switch(
                  value: data['aktif'] ?? true, activeColor: Colors.green,
                  onChanged: (v) => FirebaseFirestore.instance
                      .collection('projects').doc(d.id).update({'aktif': v}),
                ),
              ]),
            );
          }),
          const SizedBox(height: 80),
        ]);
      },
    );
  }
}

// ── 2. Araçlar ──────────────────────────────────────────────────
class _FirmaAraclar extends StatelessWidget {
  final String firmaId;
  static const _navy = Color(0xFF1a3a6b);
  const _FirmaAraclar({required this.firmaId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('vehicles').where('firmaId', isEqualTo: firmaId).snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const _BosEkran('Henüz araç eklenmemiş', Icons.directions_bus_outlined);
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data  = docs[i].data() as Map<String, dynamic>;
            final aktif = data['servisAktif'] ?? false;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: aktif ? Colors.green.withValues(alpha: 0.1) : _navy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.directions_bus_outlined, color: aktif ? Colors.green : _navy, size: 22)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(data['plaka'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${data['marka'] ?? ''} · ${data['kapasite'] ?? 0} kişilik',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: aktif ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(aktif ? 'Aktif' : 'Pasif',
                      style: TextStyle(color: aktif ? Colors.green : Colors.grey,
                          fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ]),
            );
          },
        );
      },
    );
  }
}

// ── 3. Şoförler ─────────────────────────────────────────────────
class _FirmaSoforler extends StatelessWidget {
  final String firmaId;
  static const _navy = Color(0xFF1a3a6b);
  const _FirmaSoforler({required this.firmaId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('drivers').where('firmaId', isEqualTo: firmaId).snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const _BosEkran('Henüz şoför eklenmemiş', Icons.person_outline);
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
              child: Row(children: [
                CircleAvatar(radius: 22, backgroundColor: _navy.withValues(alpha: 0.1),
                    child: Text((data['ad'] ?? '?')[0].toUpperCase(),
                        style: const TextStyle(color: _navy, fontWeight: FontWeight.bold))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(data['ad'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(data['telefon'] ?? '', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  if ((data['aracPlaka'] ?? '').isNotEmpty)
                    Text('Araç: ${data['aracPlaka']}', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                ])),
                Icon(Icons.circle, size: 10, color: (data['aktif'] ?? true) ? Colors.green : Colors.grey),
              ]),
            );
          },
        );
      },
    );
  }
}

// ── 4. Öğrenciler ───────────────────────────────────────────────
class _FirmaOgrenciler extends StatelessWidget {
  final String firmaId;
  static const _navy = Color(0xFF1a3a6b);
  const _FirmaOgrenciler({required this.firmaId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('students').where('firmaId', isEqualTo: firmaId).snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const _BosEkran('Henüz öğrenci eklenmemiş', Icons.school_outlined);
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]),
              child: Row(children: [
                CircleAvatar(radius: 18, backgroundColor: Colors.purple.withValues(alpha: 0.1),
                    child: Text((data['ad'] ?? '?')[0].toUpperCase(),
                        style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 13))),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(data['ad'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(data['adres'] ?? '', style: TextStyle(color: Colors.grey[500], fontSize: 11),
                      overflow: TextOverflow.ellipsis),
                ])),
              ]),
            );
          },
        );
      },
    );
  }
}

// ── 5. Ayarlar ──────────────────────────────────────────────────
class _FirmaAyarlar extends StatelessWidget {
  final String firmaId;
  final Map<String, dynamic> data;
  static const _navy = Color(0xFF1a3a6b);
  const _FirmaAyarlar({required this.firmaId, required this.data});

  @override
  Widget build(BuildContext context) {
    final firmaAd = data['firmaAdi'] ?? data['name'] ?? '-';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Firma Bilgileri',
                style: TextStyle(fontWeight: FontWeight.bold, color: _navy, fontSize: 14)),
            const Divider(height: 20),
            _BilgiSatir('Firma Adı', firmaAd),
            _BilgiSatir('Firma ID',  firmaId),
          ]),
        ),
        const SizedBox(height: 12),
        _AyarKarti(Icons.route_outlined,         'Güzergah Yönetimi',  Colors.orange, () => Navigator.pushNamed(context, '/gruplama')),
        _AyarKarti(Icons.notifications_outlined, 'Bildirim Ayarları',  Colors.purple, () => Navigator.pushNamed(context, '/ayarlar')),
        _AyarKarti(Icons.sell_outlined,          'Fiyat Yönetimi',     Colors.green,  () => Navigator.pushNamed(context, '/fiyat_yonetim')),
        _AyarKarti(Icons.description_outlined,   'Sözleşme',           Colors.blue,   () => Navigator.pushNamed(context, '/sozlesme')),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () async {
            await FirebaseAuth.instance.signOut();
            if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
          },
          icon: const Icon(Icons.logout_outlined),
          label: const Text('Çıkış Yap', style: TextStyle(fontWeight: FontWeight.bold)),
        )),
      ]),
    );
  }
}

class _BilgiSatir extends StatelessWidget {
  final String etiket, deger;
  const _BilgiSatir(this.etiket, this.deger);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      SizedBox(width: 90, child: Text(etiket, style: TextStyle(color: Colors.grey[500], fontSize: 12))),
      Expanded(child: Text(deger, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
    ]),
  );
}

class _AyarKarti extends StatelessWidget {
  final IconData ikon; final String baslik; final Color renk; final VoidCallback onTap;
  const _AyarKarti(this.ikon, this.baslik, this.renk, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: renk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(ikon, color: renk, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Text(baslik, style: const TextStyle(fontWeight: FontWeight.w600))),
        const Icon(Icons.chevron_right_outlined, color: Colors.grey),
      ]),
    ),
  );
}

// ── Ortak Widget'lar ────────────────────────────────────────────
class _SecBaslik extends StatelessWidget {
  final String baslik; final IconData ikon;
  static const _navy = Color(0xFF1a3a6b);
  const _SecBaslik(this.baslik, this.ikon);

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(ikon, color: _navy, size: 16), const SizedBox(width: 8),
    Text(baslik, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _navy)),
  ]);
}

class _HizliKart extends StatelessWidget {
  final IconData ikon; final String etiket; final Color renk; final VoidCallback onTap;
  const _HizliKart(this.ikon, this.etiket, this.renk, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: renk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(ikon, color: renk, size: 22)),
        const SizedBox(height: 6),
        Text(etiket, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
      ]),
    ),
  );
}

class _MiniIstat extends StatelessWidget {
  final String deger, etiket; final Color renk;
  const _MiniIstat(this.deger, this.etiket, this.renk);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(deger, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: renk)),
      Text(etiket, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
    ]),
  );
}

class _BosEkran extends StatelessWidget {
  final String mesaj; final IconData ikon;
  const _BosEkran(this.mesaj, this.ikon);

  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(ikon, size: 72, color: Colors.grey[300]),
      const SizedBox(height: 16),
      Text(mesaj, style: TextStyle(color: Colors.grey[500], fontSize: 14), textAlign: TextAlign.center),
    ]),
  ));
}
