// ╔══════════════════════════════════════════════════════════════╗
// ║  DOSYA: lib/screens/dashboard_screen.dart
// ║  Mobil Admin Dashboard — Web ile aynı menü yapısı
// ╚══════════════════════════════════════════════════════════════╝
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/session_service.dart';
import 'yardim_widget.dart';
import 'ai_widget.dart';
import 'canli_takip_screen.dart';
import 'harita_screen.dart';
import 'sozlesme_yonetim_screen.dart';
import 'arsiv_screen.dart';
import 'plaka_tanima_screen.dart';
import 'analiz_screen.dart';
import 'ayarlar_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  int    _seciliMenu = 0;
  String _firmaId    = '';
  String _firmaAd    = '';
  String _projeId    = '';
  String _projeAd    = '';
  bool   _yuklendi   = false;

  int _toplamOgrenci   = 0;
  int _toplamSofor     = 0;
  int _aktifServis     = 0;
  int _toplamVeli      = 0;
  int _bekleyenBasvuru = 0;

  // Web ile aynı 7 menü
  static const _menuler = [
    {'ikon': Icons.home_outlined,           'etiket': 'Ana Ekran'},
    {'ikon': Icons.map_outlined,            'etiket': 'Harita'},
    {'ikon': Icons.directions_bus_outlined, 'etiket': 'Servisler'},
    {'ikon': Icons.people_outlined,         'etiket': 'Kayıtlar'},
    {'ikon': Icons.description_outlined,    'etiket': 'Sözleşme'},
    {'ikon': Icons.bar_chart_outlined,      'etiket': 'Raporlar'},
    {'ikon': Icons.more_horiz_outlined,     'etiket': 'Daha Fazla'},
  ];

  @override
  void initState() { super.initState(); _yukle(); }

  Future<void> _yukle() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc  = await FirebaseFirestore.instance
        .collection('kullanicilar').doc(uid).get();
    final data = doc.data() ?? {};
    final firmaId = data['firmaId'] as String? ?? '';
    String firmaAd = '';
    if (firmaId.isNotEmpty) {
      final fd = await FirebaseFirestore.instance
          .collection('firms').doc(firmaId).get();
      firmaAd = fd.data()?['firmaAdi'] ?? fd.data()?['ad'] ?? '';
    }
    final projeId = SessionService.instance.aktifProjeld  ?? '';
    final projeAd = SessionService.instance.aktifProjeAdi ?? '';
    if (firmaId.isNotEmpty) await _istatistikYukle(firmaId, projeId);
    if (mounted) setState(() {
      _firmaId  = firmaId; _firmaAd  = firmaAd;
      _projeId  = projeId; _projeAd  = projeAd;
      _yuklendi = true;
    });
  }

  Future<void> _istatistikYukle(String firmaId, String projeId) async {
    try {
      var ogrQ = FirebaseFirestore.instance.collection('students')
          .where('firmaId', isEqualTo: firmaId);
      var sofQ = FirebaseFirestore.instance.collection('drivers')
          .where('firmaId', isEqualTo: firmaId);
      if (projeId.isNotEmpty) {
        ogrQ = ogrQ.where('projeId', isEqualTo: projeId);
      }
      final results = await Future.wait([
        ogrQ.get(), sofQ.get(),
        FirebaseFirestore.instance.collection('veli_basvurular')
            .where('firmaId', isEqualTo: firmaId)
            .where('durum', isEqualTo: 'bekliyor').get(),
      ]);
      final soforler  = results[1].docs;
      final aktif     = soforler
          .where((s) => s.data()['servisAktif'] == true).length;
      if (mounted) setState(() {
        _toplamOgrenci   = results[0].docs.length;
        _toplamSofor     = soforler.length;
        _aktifServis     = aktif;
        _bekleyenBasvuru = results[2].docs.length;
      });
    } catch (e) { debugPrint('İstatistik hata: $e'); }
  }

  void _projeSecimAc() async {
    await Navigator.pushNamed(context, '/proje_sec');
    await _yukle();
  }

  Widget _sayfa() {
    if (!_yuklendi) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF1a3a6b)));
    }
    switch (_seciliMenu) {
      case 0: return _AnaSayfa(
        firmaId: _firmaId, projeId: _projeId, projeAd: _projeAd,
        toplamOgrenci: _toplamOgrenci, toplamSofor: _toplamSofor,
        aktifServis: _aktifServis, bekleyenBasvuru: _bekleyenBasvuru,
        onNavigate: (i) => setState(() => _seciliMenu = i),
        onProjeSecimAc: _projeSecimAc,
      );
      case 1: return const HaritaScreen();
      case 2: return _ServislerSayfasi(firmaId: _firmaId, projeId: _projeId);
      case 3: return _KayitlarSayfasi(firmaId: _firmaId, projeId: _projeId);
      case 4: return const SozlesmeYonetimScreen();
      case 5: return const AnalizScreen();
      case 6: return _DahaFazlaSayfasi(
        firmaId: _firmaId, firmaAd: _firmaAd,
        projeId: _projeId, projeAd: _projeAd,
        onProjeSecimAc: _projeSecimAc,
      );
      default: return _AnaSayfa(
        firmaId: _firmaId, projeId: _projeId, projeAd: _projeAd,
        toplamOgrenci: _toplamOgrenci, toplamSofor: _toplamSofor,
        aktifServis: _aktifServis, bekleyenBasvuru: _bekleyenBasvuru,
        onNavigate: (i) => setState(() => _seciliMenu = i),
        onProjeSecimAc: _projeSecimAc,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white, elevation: 0,
        automaticallyImplyLeading: false,
        title: GestureDetector(
          onTap: _projeSecimAc,
          child: Row(children: [
            Container(width: 32, height: 32,
                decoration: BoxDecoration(
                    color: _turuncu, borderRadius: BorderRadius.circular(8)),
                child: const Center(child: Text('S',
                    style: TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 16)))),
            const SizedBox(width: 10),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_firmaAd.isNotEmpty ? _firmaAd : 'Servisim360',
                  style: const TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 14), overflow: TextOverflow.ellipsis),
              Row(children: [
                const Icon(Icons.folder_outlined,
                    size: 11, color: _turuncu),
                const SizedBox(width: 3),
                Text(_projeAd.isNotEmpty ? _projeAd : 'Proje Seç',
                    style: const TextStyle(fontSize: 10,
                        color: _turuncu, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ]),
            ])),
          ]),
        ),
        actions: [
          AiAsistanButonu(ekranAdi: 'Ana Ekran'),
          YardimButonu(ekranAdi: 'Ana Ekran'),
          IconButton(
              icon: const Icon(Icons.logout_outlined, size: 20),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              }),
        ],
      ),
      body: _sayfa(),
      // Alt navigasyon — web gibi 7 menü
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8, offset: const Offset(0, -2))]),
        child: SafeArea(child: SizedBox(
          height: 58,
          child: Row(children: List.generate(_menuler.length, (i) {
            final aktif = _seciliMenu == i;
            final badge = i == 3 && _bekleyenBasvuru > 0;
            return Expanded(child: GestureDetector(
              onTap: () => setState(() => _seciliMenu = i),
              child: Stack(alignment: Alignment.center, children: [
                Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 3, vertical: 5),
                  decoration: BoxDecoration(
                      color: aktif ? _navy : Colors.transparent,
                      borderRadius: BorderRadius.circular(10)),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    Icon(_menuler[i]['ikon'] as IconData,
                        color: aktif ? Colors.white : Colors.grey,
                        size: 18),
                    const SizedBox(height: 1),
                    Text(_menuler[i]['etiket'] as String,
                        style: TextStyle(fontSize: 8,
                            color: aktif ? Colors.white : Colors.grey,
                            fontWeight: aktif
                                ? FontWeight.bold : FontWeight.normal),
                        overflow: TextOverflow.ellipsis),
                  ]),
                ),
                if (badge)
                  Positioned(top: 5, right: 5, child: Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                  )),
              ]),
            ));
          })),
        )),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ANA SAYFA
// ════════════════════════════════════════════════════════════════
class _AnaSayfa extends StatelessWidget {
  final String firmaId, projeId, projeAd;
  final int toplamOgrenci, toplamSofor, aktifServis, bekleyenBasvuru;
  final Function(int) onNavigate;
  final VoidCallback onProjeSecimAc;

  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  const _AnaSayfa({
    required this.firmaId, required this.projeId, required this.projeAd,
    required this.toplamOgrenci, required this.toplamSofor,
    required this.aktifServis, required this.bekleyenBasvuru,
    required this.onNavigate, required this.onProjeSecimAc,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Proje seçilmemişse uyarı
        if (projeAd.isEmpty)
          GestureDetector(
            onTap: onProjeSecimAc,
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: _turuncu.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: _turuncu.withValues(alpha: 0.4))),
              child: const Row(children: [
                Icon(Icons.folder_outlined, color: _turuncu, size: 20),
                SizedBox(width: 10),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Proje Seçilmedi',
                      style: TextStyle(fontWeight: FontWeight.bold,
                          color: _turuncu)),
                  Text('Çalışmak istediğiniz projeyi seçin',
                      style: TextStyle(fontSize: 11,
                          color: _turuncu)),
                ])),
                Icon(Icons.arrow_forward_ios_rounded,
                    color: _turuncu, size: 14),
              ]),
            ),
          ),

        // İstatistik kartları — web gibi
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10, mainAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: [
            _StatKart('Servisler', '$toplamSofor',
                Icons.directions_bus_rounded, _navy,
                alt: '$aktifServis aktif',
                onTap: () => onNavigate(2)),
            _StatKart('Kayıtlar', '$toplamOgrenci',
                Icons.people_outlined, Colors.blue,
                onTap: () => onNavigate(3)),
            _StatKart('Sözleşmeler', '',
                Icons.description_outlined, Colors.teal,
                alt: 'Yönet',
                onTap: () => onNavigate(4)),
            _StatKart('Bekleyen', '$bekleyenBasvuru',
                Icons.pending_outlined,
                bekleyenBasvuru > 0 ? Colors.red : Colors.green,
                alt: 'Başvuru',
                onTap: () => onNavigate(3)),
          ],
        ),
        const SizedBox(height: 16),

        // Hızlı erişim
        const Text('Hızlı Erişim', style: TextStyle(
            fontWeight: FontWeight.bold, fontSize: 14, color: _navy)),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8, mainAxisSpacing: 8,
          childAspectRatio: 1.1,
          children: [
            _HizliBtn('Servis Ekle', Icons.add_circle_outline,
                _navy, () => onNavigate(2)),
            _HizliBtn('Kayıt Ekle', Icons.person_add_outlined,
                Colors.blue,
                () => Navigator.of(context)
                    .pushNamed('/yuz_yuze_kayit')),
            _HizliBtn('Harita', Icons.map_outlined,
                Colors.green, () => onNavigate(1)),
            _HizliBtn('Rotalar', Icons.route_outlined,
                Colors.orange,
                () => Navigator.of(context).pushNamed('/rotalar')),
            _HizliBtn('QR Afiş', Icons.qr_code_outlined,
                Colors.purple,
                () => Navigator.of(context).pushNamed('/qr_afis')),
            _HizliBtn('Arşiv', Icons.archive_outlined,
                Colors.brown,
                () => Navigator.of(context).pushNamed('/arsiv')),
          ],
        ),
        const SizedBox(height: 16),

        // Son aktiviteler
        const Text('Son İşlemler', style: TextStyle(
            fontWeight: FontWeight.bold, fontSize: 14, color: _navy)),
        const SizedBox(height: 8),
        if (firmaId.isNotEmpty)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('veli_basvurular')
                .where('firmaId', isEqualTo: firmaId)
                .limit(5)
                .snapshots(),
            builder: (_, snap) {
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: Text(
                      'Henüz başvuru yok',
                      style: TextStyle(color: Colors.grey))),
                );
              }
              return Column(children: docs.map((d) {
                final data = d.data() as Map<String, dynamic>;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.grey.shade100)),
                  child: Row(children: [
                    const Icon(Icons.person_outline,
                        color: _navy, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(data['ogrenciAdi'] ?? '-',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                      Text(data['durum'] ?? 'bekliyor',
                          style: TextStyle(
                              fontSize: 11,
                              color: data['durum'] == 'onaylandi'
                                  ? Colors.green : Colors.orange)),
                    ])),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 12, color: Colors.grey),
                  ]),
                );
              }).toList());
            },
          ),
        const SizedBox(height: 80),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SERVİSLER SAYFASI
// ════════════════════════════════════════════════════════════════
class _ServislerSayfasi extends StatelessWidget {
  final String firmaId, projeId;
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  const _ServislerSayfasi({required this.firmaId, required this.projeId});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Servis Ekle butonu
      Container(
        color: Colors.white, padding: const EdgeInsets.all(14),
        child: SizedBox(width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _turuncu, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: () =>
                Navigator.pushNamed(context, '/suruculer'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Servis Ekle',
                style: TextStyle(fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ),
        ),
      ),

      // Servis listesi
      Expanded(child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('drivers')
            .where('firmaId', isEqualTo: firmaId).snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(child: Column(
                mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.directions_bus_outlined,
                  size: 64, color: Colors.grey[300]),
              const SizedBox(height: 12),
              const Text('Henüz servis eklenmedi',
                  style: TextStyle(color: Colors.grey, fontSize: 15)),
            ]));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final durum = d['soforDurum'] ?? 'bosta';
              Color durumRenk = Colors.orange;
              if (durum == 'projeyeDahil') durumRenk = Colors.blue;
              if (durum == 'aktifGorevde') durumRenk = Colors.green;
              if (durum == 'pasif') durumRenk = Colors.grey;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: durumRenk.withValues(alpha: 0.15),
                    child: Text(
                      (d['adSoyad'] ?? d['ad'] ?? 'S')
                          .toString().isNotEmpty
                          ? (d['adSoyad'] ?? d['ad'] ?? 'S')[0]
                          .toUpperCase() : 'S',
                      style: TextStyle(color: durumRenk,
                          fontWeight: FontWeight.bold)),
                  ),
                  title: Text(d['adSoyad'] ?? d['ad'] ?? '-',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      '${d['plaka'] ?? d['aracPlaka'] ?? '-'}'
                      '${(d['projeAdi'] ?? '').isNotEmpty ? " • ${d['projeAdi']}" : ""}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey[600])),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: durumRenk.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(_durumLabel(durum),
                        style: TextStyle(fontSize: 10,
                            color: durumRenk,
                            fontWeight: FontWeight.bold)),
                  ),
                  onTap: () => Navigator.pushNamed(
                      context, '/suruculer'),
                ),
              );
            },
          );
        },
      )),
    ]);
  }

  String _durumLabel(String d) {
    switch (d) {
      case 'projeyeDahil': return 'Görevde';
      case 'aktifGorevde': return 'Aktif';
      case 'pasif':        return 'Pasif';
      default:             return 'Boşta';
    }
  }
}

// ════════════════════════════════════════════════════════════════
// KAYITLAR SAYFASI
// ════════════════════════════════════════════════════════════════
class _KayitlarSayfasi extends StatelessWidget {
  final String firmaId, projeId;
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  const _KayitlarSayfasi({required this.firmaId, required this.projeId});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Üst butonlar
      Container(
        color: Colors.white, padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _navy, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () =>
                Navigator.pushNamed(context, '/yuz_yuze_kayit'),
            icon: const Icon(Icons.person_add_outlined, size: 16),
            label: const Text('Yüz Yüze Kayıt',
                style: TextStyle(fontSize: 12)),
          )),
          const SizedBox(width: 8),
          Expanded(child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _turuncu, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () =>
                Navigator.pushNamed(context, '/veli_basvurular'),
            icon: const Icon(Icons.pending_outlined, size: 16),
            label: const Text('Başvurular',
                style: TextStyle(fontSize: 12)),
          )),
        ]),
      ),

      // Öğrenci listesi
      Expanded(child: StreamBuilder<QuerySnapshot>(
        stream: () {
          var q = FirebaseFirestore.instance.collection('students')
              .where('firmaId', isEqualTo: firmaId);
          if (projeId.isNotEmpty) {
            q = q.where('projeId', isEqualTo: projeId);
          }
          return q.snapshots();
        }(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(child: Column(
                mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 12),
              const Text('Henüz kayıt yok',
                  style: TextStyle(color: Colors.grey, fontSize: 15)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _turuncu,
                    foregroundColor: Colors.white),
                onPressed: () =>
                    Navigator.pushNamed(context, '/yuz_yuze_kayit'),
                icon: const Icon(Icons.add_rounded),
                label: const Text('İlk Kaydı Ekle')),
            ]));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final durum = d['sozlesmeDurum'] ?? 'bekliyor';
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: _navy.withValues(alpha: 0.1),
                    radius: 18,
                    child: Text(
                      (d['ad'] ?? '-').toString().isNotEmpty
                          ? d['ad'][0].toUpperCase() : '?',
                      style: const TextStyle(color: _navy,
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  title: Text(
                      '${d['ad'] ?? ''} ${d['soyad'] ?? ''}'.trim(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  subtitle: Text(
                      '${d['okul'] ?? ''}'
                      '${(d['aylikUcret'] ?? '').toString().isNotEmpty ? " • ${d['aylikUcret']} TL" : ""}',
                      style: const TextStyle(fontSize: 11)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: durum == 'imzalandi'
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      durum == 'imzalandi' ? 'İmzalı' : 'Bekliyor',
                      style: TextStyle(fontSize: 10,
                          color: durum == 'imzalandi'
                              ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold)),
                  ),
                  onTap: () => Navigator.pushNamed(context, '/ogrenci'),
                ),
              );
            },
          );
        },
      )),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════
// DAHA FAZLA SAYFASI
// ════════════════════════════════════════════════════════════════
class _DahaFazlaSayfasi extends StatelessWidget {
  final String firmaId, firmaAd, projeId, projeAd;
  final VoidCallback onProjeSecimAc;
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  const _DahaFazlaSayfasi({
    required this.firmaId, required this.firmaAd,
    required this.projeId, required this.projeAd,
    required this.onProjeSecimAc,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _bolum('Operasyon', [
          _MenuKart('Rotalar', Icons.route_outlined, Colors.orange,
              () => Navigator.pushNamed(context, '/rotalar')),
          _MenuKart('Yoklama', Icons.fact_check_outlined, Colors.blue,
              () => Navigator.pushNamed(context, '/yoklama')),
          _MenuKart('Canlı Takip', Icons.my_location_outlined, Colors.green,
              () => Navigator.pushNamed(context, '/admin_takip')),
          _MenuKart('Güzergah', Icons.timeline_outlined, Colors.purple,
              () => Navigator.pushNamed(context, '/guzergah_gecmis')),
        ]),
        _bolum('Yönetim', [
          _MenuKart('Projeler', Icons.folder_outlined, _navy,
              () => Navigator.pushNamed(context, '/projeler')),
          _MenuKart('Fiyatlar', Icons.attach_money_outlined, Colors.teal,
              () => Navigator.pushNamed(context, '/fiyat_yonetim')),
          _MenuKart('Arşiv', Icons.archive_outlined, Colors.brown,
              () => Navigator.pushNamed(context, '/arsiv')),
          _MenuKart('Plaka Tanıma', Icons.camera_alt_outlined, Colors.red,
              () => Navigator.pushNamed(context, '/plaka_tanima')),
          _MenuKart('Proje Arşiv', Icons.folder_zip_outlined, Colors.indigo,
              () => Navigator.pushNamed(context, '/proje_arsiv')),
        ]),
        _bolum('Kayıt Sistemi', [
          _MenuKart('Link Oluştur', Icons.link_outlined, _turuncu,
              () => Navigator.pushNamed(context, '/kayit_link')),
          _MenuKart('QR Afiş', Icons.qr_code_outlined, Colors.deepPurple,
              () => Navigator.pushNamed(context, '/qr_afis')),
          _MenuKart('Toplu Mesaj', Icons.message_outlined, Colors.green,
              () => Navigator.pushNamed(context, '/toplu_whatsapp')),
          _MenuKart('Şoförler', Icons.person_outlined, _navy,
              () => Navigator.pushNamed(context, '/suruculer')),
        ]),
        _bolum('Sistem', [
          _MenuKart('AI Asistan', Icons.auto_awesome_outlined, _turuncu,
              () => Navigator.pushNamed(context, '/ai_asistan')),
          _MenuKart('Bildirimler', Icons.notifications_outlined, Colors.red,
              () => Navigator.pushNamed(context, '/bildirimler')),
          _MenuKart('Ayarlar', Icons.settings_outlined, Colors.grey,
              () => Navigator.pushNamed(context, '/ayarlar')),
          _MenuKart('Proje Seç', Icons.folder_open_outlined, Colors.orange,
              onProjeSecimAc),
        ]),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _bolum(String baslik, List<Widget> kartlar) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(baslik, style: const TextStyle(
          fontWeight: FontWeight.bold, fontSize: 13, color: _navy)),
    ),
    GridView.count(
      crossAxisCount: 4, shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8, mainAxisSpacing: 8,
      childAspectRatio: 0.9,
      children: kartlar,
    ),
    const SizedBox(height: 12),
  ]);
}

// ── Yardımcı widget'lar ───────────────────────────────────────
class _StatKart extends StatelessWidget {
  final String baslik, deger;
  final IconData ikon;
  final Color renk;
  final String? alt;
  final VoidCallback? onTap;

  const _StatKart(this.baslik, this.deger, this.ikon, this.renk,
      {this.alt, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: renk.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(ikon, color: renk, size: 18)),
            const Spacer(),
            if (deger.isNotEmpty)
              Text(deger, style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: renk)),
          ]),
          const Spacer(),
          Text(baslik, style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 12)),
          if (alt != null)
            Text(alt!, style: TextStyle(
                fontSize: 10, color: Colors.grey[500])),
        ]),
      ),
    );
  }
}

class _HizliBtn extends StatelessWidget {
  final String etiket;
  final IconData ikon;
  final Color renk;
  final VoidCallback onTap;

  const _HizliBtn(this.etiket, this.ikon, this.renk, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4)]),
        child: Column(mainAxisAlignment: MainAxisAlignment.center,
            children: [
          Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: renk.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(ikon, color: renk, size: 20)),
          const SizedBox(height: 5),
          Text(etiket, style: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _MenuKart extends StatelessWidget {
  final String etiket;
  final IconData ikon;
  final Color renk;
  final VoidCallback onTap;

  const _MenuKart(this.etiket, this.ikon, this.renk, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4)]),
        child: Column(mainAxisAlignment: MainAxisAlignment.center,
            children: [
          Icon(ikon, color: renk, size: 22),
          const SizedBox(height: 4),
          Text(etiket, style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.w600,
              color: Colors.grey[700]),
              textAlign: TextAlign.center,
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}
