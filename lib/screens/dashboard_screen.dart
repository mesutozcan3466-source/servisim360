import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../services/session_service.dart';
import 'global_ai_asistan.dart';
import 'proje_sec_screen.dart';

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

  static const _menuler = [
    {'ikon': Icons.map_outlined,             'etiket': 'Harita'},
    {'ikon': Icons.people_outline,           'etiket': 'Kayitlar'},
    {'ikon': Icons.directions_bus_outlined,  'etiket': 'Operasyon'},
    {'ikon': Icons.route_outlined,           'etiket': 'Rotalar'},
    {'ikon': Icons.settings_outlined,        'etiket': 'Yonetim'},
  ];

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc  = await FirebaseFirestore.instance.collection('kullanicilar').doc(uid).get();
    final data = doc.data() ?? {};
    final firmaId = data['firmaId'] as String? ?? '';
    String firmaAd = '';
    if (firmaId.isNotEmpty) {
      final fd = await FirebaseFirestore.instance.collection('firms').doc(firmaId).get();
      firmaAd = fd.data()?['firmaAdi'] ?? fd.data()?['ad'] ?? '';
    }

    final projeId  = SessionService.instance.aktifProjeld  ?? '';
    final projeAd  = SessionService.instance.aktifProjeAdi ?? '';

    if (mounted) setState(() {
      _firmaId  = firmaId;
      _firmaAd  = firmaAd;
      _projeId  = projeId;
      _projeAd  = projeAd;
      _yuklendi = true;
    });

    // Lisans kontrolü — firms koleksiyonundan direkt kontrol
    if (mounted && firmaId.isNotEmpty) {
      try {
        final fd2 = await FirebaseFirestore.instance.collection('firms').doc(firmaId).get();
        if (fd2.exists) {
          final durum = fd2.data()?['durum'] as String? ?? 'aktif';
          final lisansBitis = fd2.data()?['lisansBitis'];
          DateTime? bitis;
          if (lisansBitis is Timestamp) bitis = lisansBitis.toDate();
          if (durum == 'askida' && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Hesabiniz askiya alindi. Yoneticinizle iletisime gecin.'),
                backgroundColor: Colors.orange, duration: Duration(seconds: 5)));
          } else if (bitis != null && bitis.isBefore(DateTime.now()) && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Lisansiniz ${bitis.day}.${bitis.month}.${bitis.year} tarihinde doldu.'),
                backgroundColor: Colors.red, duration: const Duration(seconds: 6)));
          }
        }
      } catch (_) {}
    }

    // İlk açılışta proje seçilmemişse ProjeSecScreen'e yönlendir
    if (mounted && projeId.isEmpty && firmaId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ProjeSecScreen()),
          );
        }
      });
    }
  }

  void _projeVegistir() {
    SessionService.instance.projeTemizle();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ProjeSecScreen()),
    );
  }

  Widget _sayfa() {
    if (!_yuklendi) return const Center(child: CircularProgressIndicator(color: _navy));
    switch (_seciliMenu) {
      case 0:  return _HaritaPanel(firmaId: _firmaId, projeId: _projeId);
      case 1:  return _KayitlarSayfasi(firmaId: _firmaId, projeId: _projeId);
      case 2:  return _OperasyonSayfasi(firmaId: _firmaId, projeId: _projeId);
      case 3:  return _RotalarSayfasi(firmaId: _firmaId, projeId: _projeId);
      case 4:  return _YonetimSayfasi(firmaId: _firmaId, firmaAd: _firmaAd, projeId: _projeId, projeAd: _projeAd);
      default: return _HaritaPanel(firmaId: _firmaId, projeId: _projeId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a3a6b),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white, elevation: 0,
        automaticallyImplyLeading: false,
        title: GestureDetector(
          onTap: _projeVegistir,
          child: Row(children: [
            Container(width: 28, height: 28,
                decoration: BoxDecoration(color: _turuncu, borderRadius: BorderRadius.circular(7)),
                child: const Center(child: Text('S', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_firmaAd.isNotEmpty ? _firmaAd : 'Servisim360',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
              if (_projeAd.isNotEmpty)
                Row(children: [
                  const Icon(Icons.folder_outlined, size: 10, color: _turuncu),
                  const SizedBox(width: 3),
                  Expanded(child: Text(_projeAd,
                      style: const TextStyle(fontSize: 10, color: _turuncu, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis)),
                  const Icon(Icons.swap_horiz, size: 10, color: Colors.white54),
                ]),
            ])),
          ]),
        ),
        actions: [
          IconButton(
              icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: _turuncu.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.psychology_outlined, color: _turuncu, size: 18)),
              tooltip: 'AI Asistan',
              onPressed: () => Navigator.pushNamed(context, '/ai_asistan')),
          IconButton(icon: const Icon(Icons.apps_outlined), onPressed: () => _hizliErisimAc(context)),
          IconButton(
              icon: const Icon(Icons.logout_outlined),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) Navigator.pushReplacementNamed(context, '/login');
              }),
        ],
      ),
      body: GlobalAiAsistanWrapper(
        firmaId: _firmaId,
        firmaAd: _firmaAd,
        child: _sayfa(),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, -2))]),
        child: SafeArea(child: SizedBox(height: 60,
          child: Row(children: List.generate(_menuler.length, (i) {
            final aktif = _seciliMenu == i;
            return Expanded(child: GestureDetector(
              onTap: () => setState(() => _seciliMenu = i),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                decoration: BoxDecoration(color: aktif ? _navy : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(_menuler[i]['ikon'] as IconData, color: aktif ? Colors.white : Colors.grey, size: 20),
                  const SizedBox(height: 2),
                  Text(_menuler[i]['etiket'] as String,
                      style: TextStyle(fontSize: 9, color: aktif ? Colors.white : Colors.grey,
                          fontWeight: aktif ? FontWeight.bold : FontWeight.normal)),
                ]),
              ),
            ));
          })),
        )),
      ),
    );
  }

  void _hizliErisimAc(BuildContext context) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const Text('Hizli Erisim', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _navy)),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 4, shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.9,
            children: [
              _HizliBtn(Icons.folder_outlined,       'Projeler',     Colors.indigo,  () { Navigator.pop(context); Navigator.pushNamed(context, '/projeler'); }),
              _HizliBtn(Icons.link_outlined,         'Kayit Linki',  _navy,          () { Navigator.pop(context); Navigator.pushNamed(context, '/kayit_link'); }),
              _HizliBtn(Icons.qr_code_2,             'QR Afis',      Colors.teal,    () { Navigator.pop(context); Navigator.pushNamed(context, '/qr_afis'); }),
              _HizliBtn(Icons.person_add_outlined,   'Yuz Yuze Kyt', Colors.orange,  () { Navigator.pop(context); Navigator.pushNamed(context, '/yuz_yuze_kayit'); }),
              _HizliBtn(Icons.my_location_outlined,  'Canli Takip',  Colors.green,   () { Navigator.pop(context); Navigator.pushNamed(context, '/admin_takip'); }),
              _HizliBtn(Icons.add_road_outlined,     'Rota Olustur', Colors.deepOrange, () { Navigator.pop(context); Navigator.pushNamed(context, '/gruplama'); }),
              _HizliBtn(Icons.message_outlined,      'Toplu Mesaj',  Colors.blue,    () { Navigator.pop(context); Navigator.pushNamed(context, '/toplu_mesaj'); }),
              _HizliBtn(Icons.chat_outlined,         'WhatsApp',     const Color(0xFF25D366), () { Navigator.pop(context); Navigator.pushNamed(context, '/toplu_whatsapp'); }),
              _HizliBtn(Icons.smart_toy_outlined,    'AI Asistan',   Colors.purple,  () { Navigator.pop(context); Navigator.pushNamed(context, '/ai_asistan'); }),
              _HizliBtn(Icons.event_busy_outlined,   'Devamsizlik',  Colors.red,     () { Navigator.pop(context); setState(() => _seciliMenu = 1); }),
              _HizliBtn(Icons.location_on_outlined,  'Bolge Ata',    Colors.red,     () { Navigator.pop(context); Navigator.pushNamed(context, '/bolge_atama'); }),
              _HizliBtn(Icons.call_split_outlined,      'Servis Bol',   Colors.purple,  () { Navigator.pop(context); Navigator.pushNamed(context, '/servis_bolme'); }),
              _HizliBtn(Icons.bar_chart_outlined,    'Raporlar',     Colors.teal,    () { Navigator.pop(context); Navigator.pushNamed(context, '/analiz'); }),
              _HizliBtn(Icons.notifications_outlined,'Bildirimler',  Colors.amber,   () { Navigator.pop(context); Navigator.pushNamed(context, '/bildirimler'); }),
            ],
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  HARİTA PANELİ
// ════════════════════════════════════════════════════════════════
class _HaritaPanel extends StatefulWidget {
  final String firmaId, projeId;
  const _HaritaPanel({required this.firmaId, required this.projeId});
  @override
  State<_HaritaPanel> createState() => _HaritaPanelState();
}

class _HaritaPanelState extends State<_HaritaPanel> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  GoogleMapController? _mapCtrl;
  final Set<Marker>    _markerlar = {};
  bool _yukleniyor = true;

  static const _turkiyeMerkez = CameraPosition(
    target: LatLng(39.1667, 35.6667), zoom: 6,
  );

  @override
  void initState() { super.initState(); _markerYukle(); }

  @override
  void dispose() { _mapCtrl?.dispose(); super.dispose(); }

  Future<void> _markerYukle() async {
    if (widget.firmaId.isEmpty) { setState(() => _yukleniyor = false); return; }
    try {
      var q = FirebaseFirestore.instance.collection('students')
          .where('firmaId', isEqualTo: widget.firmaId);
      if (widget.projeId.isNotEmpty) {
        q = q.where('projeId', isEqualTo: widget.projeId);
      }
      final snap = await q.get();
      final Set<Marker> yeniMarkerlar = {};
      for (final doc in snap.docs) {
        final data = doc.data();
        final konum = data['konum'];
        double? lat, lng;
        if (konum is GeoPoint) { lat = konum.latitude; lng = konum.longitude; }
        else { lat = (data['lat'] as num?)?.toDouble(); lng = (data['lng'] as num?)?.toDouble(); }
        if (lat == null || lng == null) continue;
        yeniMarkerlar.add(Marker(
          markerId: MarkerId(doc.id),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: data['ad'] ?? 'Ogrenci',
            snippet: '${data['veliTel'] ?? ''} • ${data['servisNo'] ?? ''}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ));
      }
      if (mounted) setState(() { _markerlar
        ..clear()
        ..addAll(yeniMarkerlar);
      _yukleniyor = false;
      });
    } catch (_) { if (mounted) setState(() => _yukleniyor = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      GoogleMap(
        initialCameraPosition: _turkiyeMerkez,
        markers: _markerlar,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        zoomControlsEnabled: true,
        mapToolbarEnabled: false,
        onMapCreated: (c) { _mapCtrl = c; },
      ),
      if (_yukleniyor)
        const Center(child: CircularProgressIndicator(color: _navy)),
      Positioned(
        bottom: 16, right: 16,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          FloatingActionButton.small(
            heroTag: 'canli_takip',
            backgroundColor: Colors.green,
            onPressed: () => Navigator.pushNamed(context, '/admin_takip'),
            child: const Icon(Icons.my_location_outlined),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'harita_yenile',
            backgroundColor: _navy,
            onPressed: _markerYukle,
            child: const Icon(Icons.refresh_outlined),
          ),
        ]),
      ),
      Positioned(
        top: 12, left: 12, right: 12,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
          ),
          child: Row(children: [
            Icon(Icons.people_outline, color: _navy, size: 18),
            const SizedBox(width: 8),
            Text('${_markerlar.length} ogrenci haritada',
                style: const TextStyle(fontWeight: FontWeight.w600, color: _navy, fontSize: 13)),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/gruplama'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: _turuncu, borderRadius: BorderRadius.circular(8)),
                child: const Text('Rota Olustur',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════
//  KAYITLAR SAYFASI
// ════════════════════════════════════════════════════════════════
class _KayitlarSayfasi extends StatelessWidget {
  final String firmaId, projeId;
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  const _KayitlarSayfasi({required this.firmaId, required this.projeId});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SekBaslik('Kayit Islemleri', Icons.assignment_outlined, _navy),
        const SizedBox(height: 12),

        // Hizli kayit kartlari — 2x2 grid
        GridView.count(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.4,
          children: [
            _KayitKarti(
              ikon: Icons.link_outlined, renk: _navy,
              baslik: 'Kayit Linki', alt: 'WhatsApp ile paylas',
              onTap: () => Navigator.pushNamed(context, '/kayit_link'),
            ),
            _KayitKarti(
              ikon: Icons.qr_code_2, renk: Colors.teal,
              baslik: 'QR Kod Afis', alt: 'Yeri as, QR tarat',
              onTap: () => Navigator.pushNamed(context, '/qr_afis'),
            ),
            _KayitKarti(
              ikon: Icons.person_add_outlined, renk: _turuncu,
              baslik: 'Yuz Yuze Kayit', alt: 'Admin olarak ekle',
              onTap: () => Navigator.pushNamed(context, '/yuz_yuze_kayit'),
            ),
            _KayitKarti(
              ikon: Icons.upload_file_outlined, renk: Colors.indigo,
              baslik: 'Toplu Yukle', alt: 'Excel / PDF yukle',
              onTap: () => Navigator.pushNamed(context, '/toplu_yukle'),
            ),
          ],
        ),
        const SizedBox(height: 20),

        const _SekBaslik('Mevcut Ogrenciler', Icons.people_outline, Colors.blue),
        const SizedBox(height: 12),

        _OgrenciListesi(firmaId: firmaId, projeId: projeId),

        const SizedBox(height: 20),
        const _SekBaslik('WhatsApp & Mesaj', Icons.message_outlined, Colors.green),
        const SizedBox(height: 12),
        _YonetimKarti(Icons.chat_outlined,    const Color(0xFF25D366), 'Toplu WhatsApp',    () => Navigator.pushNamed(context, '/toplu_whatsapp')),
        _YonetimKarti(Icons.message_outlined, Colors.blue,             'Toplu Bildirim',    () => Navigator.pushNamed(context, '/toplu_mesaj')),
        _YonetimKarti(Icons.event_busy_outlined, Colors.red,           'Devamsizlik Listesi', () => Navigator.pushNamed(context, '/yoklama')),
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _KayitKarti extends StatelessWidget {
  final IconData ikon; final Color renk;
  final String baslik, alt; final VoidCallback onTap;
  const _KayitKarti({required this.ikon, required this.renk, required this.baslik, required this.alt, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)],
        border: Border.all(color: renk.withValues(alpha: 0.15)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: renk.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(ikon, color: renk, size: 22),
        ),
        const SizedBox(height: 8),
        Text(baslik, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: renk)),
        Text(alt, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
      ]),
    ),
  );
}

class _OgrenciListesi extends StatelessWidget {
  final String firmaId, projeId;
  static const _navy = Color(0xFF1a3a6b);
  const _OgrenciListesi({required this.firmaId, required this.projeId});

  @override
  Widget build(BuildContext context) {
    if (firmaId.isEmpty) return const _BosEkran('Firma bilgisi yuklenemiyor', Icons.business_outlined);
    var q = FirebaseFirestore.instance.collection('students').where('firmaId', isEqualTo: firmaId);
    if (projeId.isNotEmpty) q = q.where('projeId', isEqualTo: projeId);
    return StreamBuilder<QuerySnapshot>(
      stream: q.orderBy('ad').snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: _navy)));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const _BosEkran('Henuz ogrenci eklenmemis', Icons.person_outline);
        return Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: _navy.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.people_outline, color: _navy, size: 16),
              const SizedBox(width: 8),
              Text('${docs.length} ogrenci kayitli',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: _navy, fontSize: 12)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/ogrenci'),
                child: const Text('Tumunu Gor', style: TextStyle(color: _navy, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          ...docs.take(5).map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
              ),
              child: Row(children: [
                CircleAvatar(radius: 16, backgroundColor: _navy.withValues(alpha: 0.1),
                    child: Text((data['ad'] ?? '?')[0].toUpperCase(),
                        style: const TextStyle(color: _navy, fontWeight: FontWeight.bold, fontSize: 12))),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(data['ad'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(data['veliTel'] ?? data['adres'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (data['durum'] == 'onayli' ? Colors.green : Colors.orange).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(data['durum'] ?? 'beklemede',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                          color: data['durum'] == 'onayli' ? Colors.green : Colors.orange)),
                ),
              ]),
            );
          }),
          if (docs.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextButton(
                onPressed: () => Navigator.pushNamed(context, '/ogrenci'),
                child: Text('+${docs.length - 5} daha...', style: const TextStyle(color: _navy)),
              ),
            ),
        ]);
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  OPERASYON SAYFASI
// ════════════════════════════════════════════════════════════════
class _OperasyonSayfasi extends StatelessWidget {
  final String firmaId, projeId;
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  const _OperasyonSayfasi({required this.firmaId, required this.projeId});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SekBaslik('Canli Operasyon', Icons.directions_bus_outlined, Colors.green),
        const SizedBox(height: 12),
        _YonetimKarti(Icons.my_location_outlined,  Colors.green,    'Canli Arac Takibi', () => Navigator.pushNamed(context, '/admin_takip')),
        _YonetimKarti(Icons.alt_route_outlined,    Colors.orange,   'Canli Rota',        () => Navigator.pushNamed(context, '/canli_rota')),
        _YonetimKarti(Icons.access_time_outlined,  Colors.blue,     'Servis Saatleri',   () => Navigator.pushNamed(context, '/servis_saati')),

        const SizedBox(height: 20),
        const _SekBaslik('Arac & Sofor', Icons.local_taxi_outlined, _navy),
        const SizedBox(height: 12),
        _YonetimKarti(Icons.drive_eta_outlined,    _navy,           'Soforler',          () => Navigator.pushNamed(context, '/suruculer')),
        _YonetimKarti(Icons.route_outlined,        Colors.orange,   'Rotalar',           () => Navigator.pushNamed(context, '/rotalar')),
        _YonetimKarti(Icons.history_outlined,      Colors.purple,   'Guzergah Gecmisi',  () => Navigator.pushNamed(context, '/guzergah_gecmis')),

        const SizedBox(height: 20),
        const _SekBaslik('Yoklama & Devamsizlik', Icons.event_busy_outlined, Colors.red),
        const SizedBox(height: 12),
        _YonetimKarti(Icons.event_busy_outlined,   Colors.red,      'Devamsizlik Listesi', () => Navigator.pushNamed(context, '/yoklama')),
        _YonetimKarti(Icons.fact_check_outlined,   Colors.teal,     'Hazir Mesajlar',    () => Navigator.pushNamed(context, '/hazir_mesajlar')),

        const SizedBox(height: 24),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  ROTALAR SAYFASI
// ════════════════════════════════════════════════════════════════
class _RotalarSayfasi extends StatelessWidget {
  final String firmaId, projeId;
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  const _RotalarSayfasi({required this.firmaId, required this.projeId});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SekBaslik('Rota Planlama', Icons.route_outlined, _turuncu),
        const SizedBox(height: 12),
        _YonetimKarti(Icons.add_road_outlined,       _turuncu,      'Rota Olustur (AI)',   () => Navigator.pushNamed(context, '/gruplama')),
        _YonetimKarti(Icons.list_alt_outlined,       _navy,         'Mevcut Rotalar',      () => Navigator.pushNamed(context, '/rotalar')),
        _YonetimKarti(Icons.map_outlined,            Colors.teal,   'Harita Gorunumu',     () => Navigator.pushNamed(context, '/harita')),

        const SizedBox(height: 20),
        const _SekBaslik('Guzergah Kayitlari', Icons.history_outlined, Colors.indigo),
        const SizedBox(height: 12),
        _YonetimKarti(Icons.add_location_outlined,   Colors.indigo, 'Guzergah Kaydet',     () => Navigator.pushNamed(context, '/guzergah_kayit')),
        _YonetimKarti(Icons.history_outlined,        Colors.grey,   'Gecmis Guzergahlar',  () => Navigator.pushNamed(context, '/guzergah_gecmis')),

        const SizedBox(height: 20),
        const _SekBaslik('Analiz', Icons.analytics_outlined, Colors.purple),
        const SizedBox(height: 12),
        _YonetimKarti(Icons.bar_chart_outlined,      Colors.purple, 'Raporlar & Analiz',   () => Navigator.pushNamed(context, '/analiz')),
        _YonetimKarti(Icons.smart_toy_outlined,      Colors.deepPurple, 'AI Asistan',      () => Navigator.pushNamed(context, '/ai_asistan')),

        const SizedBox(height: 24),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  YÖNETİM SAYFASI — TAM MENÜ
// ════════════════════════════════════════════════════════════════
class _YonetimSayfasi extends StatelessWidget {
  final String firmaId, firmaAd, projeId, projeAd;
  static const _navy    = Color(0xFF1a3a6b);
  static const _orange  = Color(0xFFFF8C00);
  const _YonetimSayfasi({required this.firmaId, required this.firmaAd, required this.projeId, required this.projeAd});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // Firma + Proje kartı
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_navy, Color(0xFF2a5298)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(firmaAd.isNotEmpty ? firmaAd : 'Firma', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              Text('ID: $firmaId', style: const TextStyle(color: Colors.white54, fontSize: 10)),
            ])),
            const Icon(Icons.business_outlined, color: Colors.white30, size: 36),
          ]),
          if (projeAd.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.folder_outlined, color: _orange, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(projeAd, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13))),
                GestureDetector(
                  onTap: () {
                    SessionService.instance.projeTemizle();
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ProjeSecScreen()));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: _orange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                    child: const Text('Degistir', style: TextStyle(color: _orange, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 20),

      // ── KAYIT ──
      _SekBaslik('Kayit Sistemi', Icons.assignment_outlined, Colors.indigo), const SizedBox(height: 10),
      _YonetimKarti(Icons.folder_outlined,       Colors.indigo,  'Projeler',            () => Navigator.pushNamed(context, '/projeler')),
      _YonetimKarti(Icons.link_outlined,          _navy,          'Kayit Linki',         () => Navigator.pushNamed(context, '/kayit_link')),
      _YonetimKarti(Icons.qr_code_2,              Colors.teal,    'QR Kod Afis',         () => Navigator.pushNamed(context, '/qr_afis')),
      _YonetimKarti(Icons.person_add_outlined,    _orange,        'Yuz Yuze Kayit',      () => Navigator.pushNamed(context, '/yuz_yuze_kayit')),

      const SizedBox(height: 16),
      // ── MESAJ & İLETİŞİM ──
      _SekBaslik('Mesaj & Iletisim', Icons.message_outlined, Colors.green), const SizedBox(height: 10),
      _YonetimKarti(Icons.chat_outlined,          const Color(0xFF25D366), 'Toplu WhatsApp',   () => Navigator.pushNamed(context, '/toplu_whatsapp')),
      _YonetimKarti(Icons.send_outlined, Colors.blue, 'Toplu Bildirim',    () => Navigator.pushNamed(context, '/toplu_mesaj')),
      _YonetimKarti(Icons.fact_check_outlined,    Colors.orange,  'Hazir Mesajlar',      () => Navigator.pushNamed(context, '/hazir_mesajlar')),
      _YonetimKarti(Icons.notifications_outlined, Colors.amber,   'Bildirimler',         () => Navigator.pushNamed(context, '/bildirimler')),

      const SizedBox(height: 16),
      // ── OPERASYON ──
      _SekBaslik('Operasyon', Icons.settings_outlined, _navy), const SizedBox(height: 10),
      _YonetimKarti(Icons.access_time_outlined,   Colors.blue,    'Servis Saatleri',     () => Navigator.pushNamed(context, '/servis_saati')),
      _YonetimKarti(Icons.add_road_outlined,      Colors.orange,  'Rota Olustur',        () => Navigator.pushNamed(context, '/gruplama')),
      _YonetimKarti(Icons.drive_eta_outlined,     _navy,          'Sofor Yonetimi',      () => Navigator.pushNamed(context, '/suruculer')),
      _YonetimKarti(Icons.people_outline,         Colors.indigo,  'Ogrenci Listesi',     () => Navigator.pushNamed(context, '/ogrenci')),
      _YonetimKarti(Icons.assignment_ind_outlined, Colors.teal,   'Ogrenci Paneli',      () => Navigator.pushNamed(context, '/ogrenci_paneli')),
      _YonetimKarti(Icons.location_on_outlined,   Colors.red,     'Bolge Atama (Harita)',() => Navigator.pushNamed(context, '/bolge_atama')),
      _YonetimKarti(Icons.call_split_outlined,      Colors.purple,  'Servis Bol / 2. Servis', () => Navigator.pushNamed(context, '/servis_bolme')),

      const SizedBox(height: 16),
      // ── ANALİZ & AI ──
      _SekBaslik('Analiz & AI', Icons.analytics_outlined, Colors.purple), const SizedBox(height: 10),
      _YonetimKarti(Icons.bar_chart_outlined,     Colors.teal,    'Raporlar',            () => Navigator.pushNamed(context, '/analiz')),
      _YonetimKarti(Icons.smart_toy_outlined,     Colors.purple,  'AI Asistan',          () => Navigator.pushNamed(context, '/ai_asistan')),
      _YonetimKarti(Icons.attach_money_outlined,  Colors.green,   'Fiyat Yonetimi',      () => Navigator.pushNamed(context, '/fiyat_yonetim')),

      const SizedBox(height: 16),
      // ── SİSTEM ──
      _SekBaslik('Sistem', Icons.more_horiz, Colors.grey), const SizedBox(height: 10),
      _YonetimKarti(Icons.description_outlined,   Colors.blue,    'Sozlesme',            () => Navigator.pushNamed(context, '/sozlesme')),
      _YonetimKarti(Icons.settings_outlined,      Colors.grey,    'Ayarlar',             () => Navigator.pushNamed(context, '/ayarlar')),

      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red),
            padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        onPressed: () async {
          await FirebaseAuth.instance.signOut();
          if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
        },
        icon: const Icon(Icons.logout_outlined),
        label: const Text('Cikis Yap', style: TextStyle(fontWeight: FontWeight.bold)),
      )),
      const SizedBox(height: 40),
    ]),
  );
}

// ════════════════════════════════════════════════════════════════
//  ORTAK WIDGET'LAR
// ════════════════════════════════════════════════════════════════
class _YonetimKarti extends StatelessWidget {
  final IconData ikon; final Color renk; final String baslik; final VoidCallback onTap;
  const _YonetimKarti(this.ikon, this.renk, this.baslik, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
      child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: renk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(ikon, color: renk, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Text(baslik, style: const TextStyle(fontWeight: FontWeight.w600))),
            const Icon(Icons.chevron_right_outlined, color: Colors.grey),
          ])));
}

class _HizliBtn extends StatelessWidget {
  final IconData ikon; final String etiket; final Color renk; final VoidCallback onTap;
  const _HizliBtn(this.ikon, this.etiket, this.renk, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
      child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: renk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(ikon, color: renk, size: 22)),
            const SizedBox(height: 5),
            Text(etiket, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
          ])));
}

class _SekBaslik extends StatelessWidget {
  final String baslik; final IconData ikon; final Color renk;
  const _SekBaslik(this.baslik, this.ikon, this.renk);
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(ikon, color: renk, size: 16), const SizedBox(width: 8),
    Text(baslik, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: renk)),
  ]);
}

class _InputAlan extends StatelessWidget {
  final TextEditingController ctrl; final String label; final IconData ikon; final TextInputType tipi;
  static const _navy = Color(0xFF1a3a6b);
  const _InputAlan({required this.ctrl, required this.label, required this.ikon, this.tipi = TextInputType.text});
  @override
  Widget build(BuildContext context) => TextField(controller: ctrl, keyboardType: tipi,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(ikon, color: _navy, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _navy, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14)));
}

class _BosEkran extends StatelessWidget {
  final String mesaj; final IconData ikon;
  const _BosEkran(this.mesaj, this.ikon);
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(ikon, size: 72, color: Colors.grey[300]), const SizedBox(height: 16),
        Text(mesaj, style: TextStyle(color: Colors.grey[500], fontSize: 14), textAlign: TextAlign.center),
      ])));
}
