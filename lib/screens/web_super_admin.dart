import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/session_service.dart';

// ════════════════════════════════════════════════════════════════
//  WEB SUPER ADMIN — Ana Shell
// ════════════════════════════════════════════════════════════════
class WebSuperAdminSayfasi extends StatefulWidget {
  const WebSuperAdminSayfasi({super.key});
  @override
  State<WebSuperAdminSayfasi> createState() =>
      _WebSuperAdminSayfasiState();
}

class _WebSuperAdminSayfasiState extends State<WebSuperAdminSayfasi> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  int _aktifSekme = 0;

  static const List<_SuperMenuItem> _menuler = [
    _SuperMenuItem('Istatistikler', Icons.bar_chart_outlined,       0),
    _SuperMenuItem('Firmalar',      Icons.business_outlined,        1),
    _SuperMenuItem('Global Harita', Icons.map_outlined,             2),
    _SuperMenuItem('Kullanicilar',  Icons.people_outline,           3),
    _SuperMenuItem('Lisanslar',     Icons.card_membership_outlined, 4),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Row(children: [
        // Sol menu
        Container(
          width: 240, color: _navy,
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(24),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                      color: _turuncu,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Center(child: Text('S',
                      style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 20))),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Servisim360', style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold,
                        fontSize: 14)),
                    Text('Super Admin', style: TextStyle(
                        color: Color(0xFFFF8C00), fontSize: 11)),
                  ],
                )),
              ]),
            ),
            const Divider(color: Colors.white12),
            ..._menuler.map((item) {
              final secili = _aktifSekme == item.index;
              return GestureDetector(
                onTap: () => setState(() => _aktifSekme = item.index),
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
                    border: secili ? Border.all(
                        color: _turuncu.withValues(alpha: 0.5)) : null,
                  ),
                  child: Row(children: [
                    Icon(item.ikon,
                        color: secili ? _turuncu : Colors.white54,
                        size: 20),
                    const SizedBox(width: 12),
                    Text(item.ad, style: TextStyle(
                        color: secili ? Colors.white : Colors.white60,
                        fontWeight: secili
                            ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14)),
                  ]),
                ),
              );
            }),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await SessionService.instance.cikisYap();
                    if (mounted) {
                      Navigator.pushReplacementNamed(context, '/login');
                    }
                  },
                  icon: const Icon(Icons.logout_outlined,
                      color: Colors.white54, size: 16),
                  label: const Text('Cikis Yap',
                      style: TextStyle(
                          color: Colors.white54, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white12)),
                ),
              ),
            ),
          ]),
        ),

        // Icerik
        Expanded(child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 32, vertical: 16),
            color: Colors.white,
            child: Row(children: [
              Text(_menuler[_aktifSekme].ad,
                  style: const TextStyle(fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _navy)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _turuncu.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(children: [
                  Icon(Icons.admin_panel_settings_outlined,
                      color: Color(0xFFFF8C00), size: 16),
                  SizedBox(width: 6),
                  Text('Super Admin', style: TextStyle(
                      color: Color(0xFFFF8C00),
                      fontWeight: FontWeight.bold, fontSize: 13)),
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
      case 0: return const WebSuperAdminIstatistik();
      case 1: return const WebSuperAdminFirmalar();
      case 2: return const WebSuperAdminHarita();
      case 3: return const WebSuperAdminKullanicilar();
      case 4: return const WebSuperAdminLisanslar();
      default: return const SizedBox();
    }
  }
}

class _SuperMenuItem {
  final String ad;
  final IconData ikon;
  final int index;
  const _SuperMenuItem(this.ad, this.ikon, this.index);
}

// ════════════════════════════════════════════════════════════════
//  ISTATISTIKLER
// ════════════════════════════════════════════════════════════════
class WebSuperAdminIstatistik extends StatefulWidget {
  const WebSuperAdminIstatistik({super.key});
  @override
  State<WebSuperAdminIstatistik> createState() =>
      _WebSuperAdminIstatistikState();
}

class _WebSuperAdminIstatistikState
    extends State<WebSuperAdminIstatistik> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  int  _toplamFirma  = 0;
  int  _aktifFirma   = 0;
  int  _toplamSurucu = 0;
  int  _aktifServis  = 0;
  int  _toplamVeli   = 0;
  int  _toplamOgrenci= 0;
  bool _yukleniyor   = true;

  @override
  void initState() { super.initState(); _yukle(); }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final firmaSnap = await FirebaseFirestore.instance
          .collection('firms').get();
      _toplamFirma = firmaSnap.docs.length;
      _aktifFirma  = firmaSnap.docs
          .where((d) => d.data()['durum'] == 'aktif').length;

      final surucuSnap = await FirebaseFirestore.instance
          .collection('drivers').get();
      _toplamSurucu = surucuSnap.docs.length;
      _aktifServis  = surucuSnap.docs
          .where((d) => d.data()['servisAktif'] == true).length;

      final veliSnap = await FirebaseFirestore.instance
          .collection('parents').get();
      _toplamVeli = veliSnap.docs.length;

      final ogrSnap = await FirebaseFirestore.instance
          .collection('students').get();
      _toplamOgrenci = ogrSnap.docs.length;
    } catch (e) {
      debugPrint('Istatistik hata: $e');
    }
    if (mounted) setState(() => _yukleniyor = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF1a3a6b)));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Genel Bakis', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold,
              color: _navy)),
          const SizedBox(height: 20),

          // Istatistik kartlari — Wrap ile responsive
          Wrap(spacing: 16, runSpacing: 16, children: [
            _IstatKart('Toplam Firma',   '$_toplamFirma',
                Icons.business_outlined,          _navy,    180),
            _IstatKart('Aktif Firma',    '$_aktifFirma',
                Icons.check_circle_outline,        Colors.green, 180),
            _IstatKart('Toplam Sofor',   '$_toplamSurucu',
                Icons.directions_car_outlined,     Colors.blue,  180),
            _IstatKart('Aktif Servis',   '$_aktifServis',
                Icons.directions_bus_outlined,     _turuncu,     180),
            _IstatKart('Toplam Veli',    '$_toplamVeli',
                Icons.family_restroom_outlined,    Colors.purple,180),
            _IstatKart('Toplam Ogrenci', '$_toplamOgrenci',
                Icons.school_outlined,             Colors.teal,  180),
          ]),

          const SizedBox(height: 32),
          TextButton.icon(
            onPressed: _yukle,
            icon: const Icon(Icons.refresh_outlined, size: 16),
            label: const Text('Yenile'),
          ),
        ],
      ),
    );
  }
}

class _IstatKart extends StatelessWidget {
  final String baslik, deger;
  final IconData ikon;
  final Color renk;
  final double genislik;
  const _IstatKart(this.baslik, this.deger, this.ikon,
      this.renk, this.genislik);

  @override
  Widget build(BuildContext context) => Container(
    width: genislik,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10)],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: renk.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(ikon, color: renk, size: 22),
      ),
      const SizedBox(height: 12),
      Text(deger, style: TextStyle(
          fontSize: 32, fontWeight: FontWeight.bold, color: renk)),
      Text(baslik, style: TextStyle(
          fontSize: 13, color: Colors.grey[600])),
    ]),
  );
}

// ════════════════════════════════════════════════════════════════
//  FIRMALAR
// ════════════════════════════════════════════════════════════════
class WebSuperAdminFirmalar extends StatefulWidget {
  const WebSuperAdminFirmalar({super.key});
  @override
  State<WebSuperAdminFirmalar> createState() =>
      _WebSuperAdminFirmalarState();
}

class _WebSuperAdminFirmalarState
    extends State<WebSuperAdminFirmalar> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  String _aramaMetni = '';
  final _aramaCtrl = TextEditingController();

  @override
  void dispose() { _aramaCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Column(children: [
    // Arama + Firma Ekle butonu
    Container(
      padding: const EdgeInsets.all(16), color: Colors.white,
      child: Row(children: [
        Expanded(child: TextField(
          controller: _aramaCtrl,
          decoration: InputDecoration(
            hintText: 'Firma ara...',
            prefixIcon: const Icon(Icons.search, color: _navy, size: 18),
            filled: true, fillColor: const Color(0xFFF5F7FA),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
          ),
          onChanged: (v) =>
              setState(() => _aramaMetni = v.toLowerCase()),
        )),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: () => _firmaEkleDialog(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: _navy,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
          ),
          icon: const Icon(Icons.add, color: Colors.white, size: 18),
          label: const Text('Firma Ekle',
              style: TextStyle(color: Colors.white)),
        ),
      ]),
    ),

    Expanded(child: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('firms').snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        var docs = snap.data?.docs ?? [];
        if (_aramaMetni.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return (data['firmaAdi'] ?? data['ad'] ?? '')
                .toString().toLowerCase().contains(_aramaMetni);
          }).toList();
        }
        if (docs.isEmpty) {
          return const Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.business_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 12),
              Text('Firma bulunamadi',
                  style: TextStyle(color: Colors.grey)),
            ],
          ));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final durum = d['durum'] as String? ?? 'aktif';
            final firmaAdi = d['firmaAdi'] ?? d['ad'] ?? 'Firma';
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6)],
              ),
              child: Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                      color: _navy.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text(
                      firmaAdi.isNotEmpty
                          ? firmaAdi[0].toUpperCase() : 'F',
                      style: const TextStyle(
                          color: _navy, fontWeight: FontWeight.bold,
                          fontSize: 20))),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(firmaAdi, style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(d['email'] ?? '',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500])),
                    const SizedBox(height: 2),
                    Row(children: [
                      Icon(Icons.phone_outlined,
                          size: 12, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(d['telefon'] ?? d['tel'] ?? '-',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[400])),
                      const SizedBox(width: 12),
                      Icon(Icons.card_membership_outlined,
                          size: 12, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text('Lisans: ${d['lisansAy'] ?? '-'} ay',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[400])),
                    ]),
                  ],
                )),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Durum badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: _durumRengi(durum).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(durum, style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold,
                            color: _durumRengi(durum))),
                      ),
                      const SizedBox(height: 8),
                      // Aksiyon butonlari
                      Row(children: [
                        _AksiyonBtn('Onayla', Colors.green,
                            Icons.check_circle_outline, () async {
                              await FirebaseFirestore.instance
                                  .collection('firms').doc(docs[i].id)
                                  .update({'durum': 'aktif'});
                            }),
                        const SizedBox(width: 6),
                        _AksiyonBtn('Askiya Al', Colors.orange,
                            Icons.pause_circle_outline, () async {
                              await FirebaseFirestore.instance
                                  .collection('firms').doc(docs[i].id)
                                  .update({'durum': 'askida'});
                            }),
                        const SizedBox(width: 6),
                        _AksiyonBtn('Detay', Colors.blue,
                            Icons.info_outline, () =>
                                _firmaDetayDialog(context, docs[i].id, d)),
                      ]),
                    ]),
              ]),
            );
          },
        );
      },
    )),
  ]);

  Color _durumRengi(String durum) {
    switch (durum) {
      case 'aktif':  return Colors.green;
      case 'askida': return Colors.orange;
      case 'pasif':  return Colors.red;
      default:       return Colors.grey;
    }
  }

  void _firmaDetayDialog(BuildContext context, String firmaId,
      Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(data['firmaAdi'] ?? data['ad'] ?? 'Firma'),
        content: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetayRow('Email', data['email'] ?? '-'),
              _DetayRow('Telefon', data['telefon'] ?? '-'),
              _DetayRow('Durum', data['durum'] ?? '-'),
              _DetayRow('Lisans', '${data['lisansAy'] ?? '-'} ay'),
              _DetayRow('Firma ID', firmaId),
            ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  void _firmaEkleDialog(BuildContext context) {
    final adCtrl    = TextEditingController();
    final emailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Yeni Firma'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: adCtrl,
              decoration: const InputDecoration(labelText: 'Firma Adi')),
          const SizedBox(height: 12),
          TextField(controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Email')),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1a3a6b)),
            onPressed: () async {
              if (adCtrl.text.trim().isEmpty) return;
              await FirebaseFirestore.instance
                  .collection('firms').add({
                'firmaAdi': adCtrl.text.trim(),
                'ad':       adCtrl.text.trim(),
                'email':    emailCtrl.text.trim(),
                'durum':    'aktif',
                'olusturma': FieldValue.serverTimestamp(),
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Ekle',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _DetayRow extends StatelessWidget {
  final String label, deger;
  const _DetayRow(this.label, this.deger);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      SizedBox(width: 80,
          child: Text(label, style: const TextStyle(
              color: Colors.grey, fontSize: 13))),
      Expanded(child: Text(deger,
          style: const TextStyle(fontWeight: FontWeight.w600,
              fontSize: 13))),
    ]),
  );
}

class _AksiyonBtn extends StatelessWidget {
  final String label;
  final Color renk;
  final IconData ikon;
  final VoidCallback onTap;
  const _AksiyonBtn(this.label, this.renk, this.ikon, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
          color: renk.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: renk.withValues(alpha: 0.3))),
      child: Row(children: [
        Icon(ikon, size: 12, color: renk),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(
            fontSize: 10, color: renk, fontWeight: FontWeight.bold)),
      ]),
    ),
  );
}

// ════════════════════════════════════════════════════════════════
//  GLOBAL HARITA
// ════════════════════════════════════════════════════════════════
class WebSuperAdminHarita extends StatefulWidget {
  const WebSuperAdminHarita({super.key});
  @override
  State<WebSuperAdminHarita> createState() =>
      _WebSuperAdminHaritaState();
}

class _WebSuperAdminHaritaState extends State<WebSuperAdminHarita> {
  Set<Marker> _markers = {};
  List<Map<String, dynamic>> _tumSoforler = [];
  List<Map<String, dynamic>> _aktifSoforler = [];
  bool _sadaceAktif = false;
  bool _yukleniyor  = true;

  @override
  void initState() { super.initState(); _yukle(); }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      // Tüm sürücüleri çek (aktif filtresi kaldırıldı)
      final snap = await FirebaseFirestore.instance
          .collection('drivers').get();

      final Set<Marker> m = {};
      final List<Map<String, dynamic>> tumSoforler = [];
      final List<Map<String, dynamic>> aktifSoforler = [];

      for (final d in snap.docs) {
        final data = d.data();
        final sofor = {'id': d.id, ...data};
        tumSoforler.add(sofor);

        if (data['servisAktif'] == true) {
          aktifSoforler.add(sofor);
        }

        final k = data['konum'];
        if (k is GeoPoint) {
          m.add(Marker(
            markerId: MarkerId(d.id),
            position: LatLng(k.latitude, k.longitude),
            infoWindow: InfoWindow(
                title: data['ad'] ?? 'Sofor',
                snippet: data['aracPlaka'] ?? ''),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                data['servisAktif'] == true
                    ? BitmapDescriptor.hueGreen
                    : BitmapDescriptor.hueBlue),
          ));
        }
      }

      if (mounted) {
        setState(() {
          _markers      = m;
          _tumSoforler  = tumSoforler;
          _aktifSoforler = aktifSoforler;
          _yukleniyor   = false;
        });
      }
    } catch (e) {
      debugPrint('Harita hata: $e');
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gosterilecek = _sadaceAktif ? _aktifSoforler : _tumSoforler;

    if (_yukleniyor) {
      return const Center(child: CircularProgressIndicator());
    }

    if (kIsWeb) {
      return Column(children: [
        // Ust bar
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          color: Colors.white,
          child: Row(children: [
            Container(width: 10, height: 10,
                decoration: const BoxDecoration(
                    color: Colors.green, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text('${_aktifSoforler.length} aktif servis',
                style: const TextStyle(fontWeight: FontWeight.bold,
                    fontSize: 15, color: Color(0xFF1a3a6b))),
            const SizedBox(width: 16),
            Container(width: 10, height: 10,
                decoration: const BoxDecoration(
                    color: Colors.blue, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text('${_tumSoforler.length - _aktifSoforler.length} pasif sofor',
                style: TextStyle(fontSize: 13,
                    color: Colors.grey[600])),
            const Spacer(),
            // Filtre toggle
            Row(children: [
              const Text('Sadece Aktif',
                  style: TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              Switch(
                value: _sadaceAktif,
                onChanged: (v) => setState(() => _sadaceAktif = v),
                activeColor: Colors.green,
              ),
            ]),
            const SizedBox(width: 12),
            TextButton.icon(
              icon: const Icon(Icons.refresh_outlined, size: 14),
              label: const Text('Yenile',
                  style: TextStyle(fontSize: 12)),
              onPressed: _yukle,
            ),
          ]),
        ),

        // Sofor listesi
        Expanded(
          child: gosterilecek.isEmpty
              ? Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.directions_bus_outlined,
                    size: 64, color: Colors.grey),
                const SizedBox(height: 12),
                Text(_sadaceAktif
                    ? 'Aktif servis yok'
                    : 'Sofor bulunamadi',
                    style: const TextStyle(color: Colors.grey)),
              ]))
              : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: gosterilecek.length,
              itemBuilder: (_, i) {
                final s = gosterilecek[i];
                final aktif = s['servisAktif'] == true;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: aktif
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.grey.withValues(alpha: 0.2)),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4)],
                  ),
                  child: Row(children: [
                    Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                          color: aktif
                              ? Colors.green : Colors.grey[300],
                          shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s['ad'] ?? 'Sofor',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                        Row(children: [
                          Text(s['aracPlaka'] ?? '',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500])),
                          if (s['firmaId'] != null) ...[
                            const SizedBox(width: 8),
                            Text('• ${s['firmaId']}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[400])),
                          ],
                        ]),
                      ],
                    )),
                    if (aktif) ...[
                      Text(
                          '${(s['hiz'] as num? ?? 0).toStringAsFixed(0)} km/s',
                          style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: (aktif
                              ? Colors.green : Colors.grey)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(aktif ? 'Aktif' : 'Pasif',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: aktif
                                  ? Colors.green : Colors.grey)),
                    ),
                  ]),
                );
              }),
        ),
      ]);
    }

    // Mobil — Google Map
    return Stack(children: [
      GoogleMap(
        initialCameraPosition: const CameraPosition(
            target: LatLng(39.1667, 35.6667), zoom: 6),
        markers: _markers,
        onMapCreated: (_) {},
      ),
      Positioned(top: 16, left: 16,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8)]),
          child: Row(children: [
            const Icon(Icons.circle, color: Colors.green, size: 12),
            const SizedBox(width: 6),
            Text('${_aktifSoforler.length} aktif',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13)),
          ]),
        ),
      ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════
//  KULLANICILAR
// ════════════════════════════════════════════════════════════════
class WebSuperAdminKullanicilar extends StatefulWidget {
  const WebSuperAdminKullanicilar({super.key});
  @override
  State<WebSuperAdminKullanicilar> createState() =>
      _WebSuperAdminKullanicilarState();
}

class _WebSuperAdminKullanicilarState
    extends State<WebSuperAdminKullanicilar> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  String _aramaMetni = '';
  String _rolFiltre  = 'Tumu';
  final _aramaCtrl = TextEditingController();

  static const List<String> _roller = [
    'Tumu', 'superAdmin', 'admin', 'firmaAdmin', 'sofor', 'veli'
  ];

  @override
  void dispose() { _aramaCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Column(children: [
    // Filtre bar
    Container(
      padding: const EdgeInsets.all(16), color: Colors.white,
      child: Row(children: [
        Expanded(child: TextField(
          controller: _aramaCtrl,
          decoration: InputDecoration(
            hintText: 'Kullanici ara...',
            prefixIcon: const Icon(Icons.search, color: _navy, size: 18),
            filled: true, fillColor: const Color(0xFFF5F7FA),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
          ),
          onChanged: (v) =>
              setState(() => _aramaMetni = v.toLowerCase()),
        )),
        const SizedBox(width: 12),
        DropdownButton<String>(
          value: _rolFiltre,
          onChanged: (v) => setState(() => _rolFiltre = v!),
          items: _roller.map((r) =>
              DropdownMenuItem(value: r, child: Text(r))).toList(),
        ),
      ]),
    ),

    Expanded(child: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('kullanicilar').snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        var docs = snap.data?.docs ?? [];
        if (_aramaMetni.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return (data['email'] ?? data['ad'] ?? '')
                .toString().toLowerCase().contains(_aramaMetni);
          }).toList();
        }
        if (_rolFiltre != 'Tumu') {
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return data['rol'] == _rolFiltre;
          }).toList();
        }
        if (docs.isEmpty) {
          return const Center(child: Text('Kullanici bulunamadi',
              style: TextStyle(color: Colors.grey)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final rol   = d['rol']   as String? ?? '-';
            final email = d['email'] as String? ?? '-';
            final ad    = d['ad']    as String? ?? email;
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
                  backgroundColor: _rolRengi(rol).withValues(alpha: 0.15),
                  child: Text(ad.isNotEmpty ? ad[0].toUpperCase() : '?',
                      style: TextStyle(
                          color: _rolRengi(rol),
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ad, style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(email, style: TextStyle(
                        fontSize: 12, color: Colors.grey[500])),
                    if (d['firmaId'] != null)
                      Text('Firma: ${d['firmaId']}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[400])),
                  ],
                )),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: _rolRengi(rol).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(rol, style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold,
                      color: _rolRengi(rol))),
                ),
              ]),
            );
          },
        );
      },
    )),
  ]);

  Color _rolRengi(String rol) {
    switch (rol) {
      case 'superAdmin': return const Color(0xFFFF8C00);
      case 'admin':
      case 'firmaAdmin': return const Color(0xFF1a3a6b);
      case 'sofor':      return Colors.green;
      case 'veli':       return Colors.purple;
      default:           return Colors.grey;
    }
  }
}

// ════════════════════════════════════════════════════════════════
//  LISANSLAR
// ════════════════════════════════════════════════════════════════
class WebSuperAdminLisanslar extends StatefulWidget {
  const WebSuperAdminLisanslar({super.key});
  @override
  State<WebSuperAdminLisanslar> createState() =>
      _WebSuperAdminLisanslarState();
}

class _WebSuperAdminLisanslarState
    extends State<WebSuperAdminLisanslar> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      padding: const EdgeInsets.all(16), color: Colors.white,
      child: Row(children: [
        const Text('Lisans Yonetimi', style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold,
            color: _navy)),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: () => _lisansEkleDialog(context),
          style: ElevatedButton.styleFrom(
              backgroundColor: _navy),
          icon: const Icon(Icons.add, color: Colors.white, size: 16),
          label: const Text('Lisans Ekle',
              style: TextStyle(color: Colors.white)),
        ),
      ]),
    ),
    Expanded(child: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('licenses').snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.card_membership_outlined,
                  size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Lisans bulunamadi',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _lisansEkleDialog(context),
                style: ElevatedButton.styleFrom(
                    backgroundColor: _navy),
                icon: const Icon(Icons.add,
                    color: Colors.white, size: 16),
                label: const Text('Ilk Lisansi Ekle',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final durum = d['durum'] as String? ?? 'aktif';
            final bitis = d['bitisTarihi'];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4)],
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: _navy.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.card_membership_outlined,
                      color: _navy, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d['firmaId'] ?? 'Firma ID',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold)),
                    Text('${d['sure'] ?? d['lisansAy'] ?? '-'} ay lisans',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500])),
                    if (bitis != null)
                      Text('Bitis: ${bitis.toString().substring(0, 10)}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[400])),
                  ],
                )),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: (durum == 'aktif'
                          ? Colors.green : Colors.red)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(durum, style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold,
                      color: durum == 'aktif'
                          ? Colors.green : Colors.red)),
                ),
              ]),
            );
          },
        );
      },
    )),
  ]);

  void _lisansEkleDialog(BuildContext context) {
    final firmaIdCtrl = TextEditingController();
    final sureCtrl    = TextEditingController(text: '12');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Lisans Ekle'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: firmaIdCtrl,
              decoration: const InputDecoration(
                  labelText: 'Firma ID')),
          const SizedBox(height: 12),
          TextField(controller: sureCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Sure (Ay)')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Iptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _navy),
            onPressed: () async {
              if (firmaIdCtrl.text.trim().isEmpty) return;
              final sure = int.tryParse(sureCtrl.text) ?? 12;
              final bitis = DateTime.now()
                  .add(Duration(days: sure * 30));
              await FirebaseFirestore.instance
                  .collection('licenses').add({
                'firmaId':     firmaIdCtrl.text.trim(),
                'sure':        sure,
                'lisansAy':    sure,
                'durum':       'aktif',
                'bitisTarihi': bitis.toIso8601String()
                    .substring(0, 10),
                'olusturma':   FieldValue.serverTimestamp(),
              });
              // Firma doc güncelle
              await FirebaseFirestore.instance
                  .collection('firms')
                  .doc(firmaIdCtrl.text.trim())
                  .update({
                'lisansAy':    sure,
                'lisansBitis': bitis.toIso8601String()
                    .substring(0, 10),
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Ekle',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}