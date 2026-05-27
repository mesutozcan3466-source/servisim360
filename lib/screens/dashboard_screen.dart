import 'package:flutter/material.dart';
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

    // Aktif proje session'dan al
    final projeId  = SessionService.instance.aktifProjeld  ?? '';
    final projeAd  = SessionService.instance.aktifProjeAdi ?? '';

    if (mounted) setState(() {
      _firmaId  = firmaId;
      _firmaAd  = firmaAd;
      _projeId  = projeId;
      _projeAd  = projeAd;
      _yuklendi = true;
    });
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
              _HizliBtn(Icons.folder_outlined,       'Projeler',    Colors.indigo,  () { Navigator.pop(context); Navigator.pushNamed(context, '/projeler'); }),
              _HizliBtn(Icons.add_road_outlined,     'Rota Olustur',Colors.orange,  () { Navigator.pop(context); Navigator.pushNamed(context, '/gruplama'); }),
              _HizliBtn(Icons.my_location_outlined,  'Canli Takip', Colors.green,   () { Navigator.pop(context); Navigator.pushNamed(context, '/admin_takip'); }),
              _HizliBtn(Icons.message_outlined,      'Toplu Mesaj', Colors.blue,    () { Navigator.pop(context); Navigator.pushNamed(context, '/toplu_mesaj'); }),
              _HizliBtn(Icons.link_outlined,         'Kayit Linki', _navy,          () { Navigator.pop(context); Navigator.pushNamed(context, '/kayit_link'); }),
              _HizliBtn(Icons.event_busy_outlined,   'Devamsizlik', Colors.red,     () { Navigator.pop(context); setState(() => _seciliMenu = 1); }),
              _HizliBtn(Icons.smart_toy_outlined,    'AI Asistan',  Colors.purple,  () { Navigator.pop(context); Navigator.pushNamed(context, '/ai_asistan'); }),
              _HizliBtn(Icons.notifications_outlined,'Bildirimler', Colors.amber,   () { Navigator.pop(context); Navigator.pushNamed(context, '/bildirimler'); }),
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
  static const _navy = Color(0xFF1a3a6b);
  GoogleMapController? _mapCtrl;
  MapType _mapTipi = MapType.normal;

  @override
  void initState() { super.initState(); _konumAl(); }

  Future<void> _konumAl() async {
    try {
      final izin = await Geolocator.requestPermission();
      if (izin == LocationPermission.denied || izin == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 800), () =>
            _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 13)));
      }
    } catch (_) {}
  }

  static const List<double> _hues = [
    BitmapDescriptor.hueGreen, BitmapDescriptor.hueBlue,
    BitmapDescriptor.hueRed,   BitmapDescriptor.hueViolet,
    BitmapDescriptor.hueOrange,BitmapDescriptor.hueCyan,
  ];

  @override
  Widget build(BuildContext context) {
    // Proje bazlı sürücüleri göster
    final query = widget.projeId.isNotEmpty
        ? FirebaseFirestore.instance.collection('drivers').where('projeId', isEqualTo: widget.projeId)
        : FirebaseFirestore.instance.collection('drivers').where('firmaId', isEqualTo: widget.firmaId);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (_, soforSnap) {
        final soforler = soforSnap.data?.docs ?? [];
        final Set<Marker> markers = {};
        int ri = 0;
        for (final sofor in soforler) {
          final d = sofor.data() as Map<String, dynamic>;
          final konum = d['konum'] as Map<String, dynamic>?;
          if (konum == null) { ri++; continue; }
          final lat = (konum['lat'] ?? konum['latitude'])  as double?;
          final lng = (konum['lng'] ?? konum['longitude']) as double?;
          if (lat == null || lng == null) { ri++; continue; }
          final aktif = d['servisAktif'] ?? false;
          markers.add(Marker(
            markerId: MarkerId(sofor.id),
            position: LatLng(lat, lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(aktif ? _hues[ri % _hues.length] : BitmapDescriptor.hueAzure),
            infoWindow: InfoWindow(title: '${d['ad'] ?? ''} - ${d['aracPlaka'] ?? ''}', snippet: aktif ? 'Aktif' : 'Pasif'),
          ));
          ri++;
        }

        return Stack(children: [
          GoogleMap(
              onMapCreated: (ctrl) { _mapCtrl = ctrl; },
              initialCameraPosition: const CameraPosition(target: LatLng(41.0082, 28.9784), zoom: 11),
              mapType: _mapTipi, markers: markers,
              myLocationEnabled: true, myLocationButtonEnabled: false,
              zoomControlsEnabled: false, mapToolbarEnabled: false, compassEnabled: true),
          Positioned(right: 12, top: 12, child: GestureDetector(
              onTap: () => setState(() => _mapTipi = _mapTipi == MapType.normal ? MapType.satellite : MapType.normal),
              child: Container(padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)]),
                  child: Icon(_mapTipi == MapType.normal ? Icons.satellite_alt : Icons.map_outlined, color: _navy, size: 20)))),
          Positioned(right: 12, bottom: 80, child: Column(children: [
            _MapBtn(Icons.add,    () => _mapCtrl?.animateCamera(CameraUpdate.zoomIn())),
            const SizedBox(height: 6),
            _MapBtn(Icons.remove, () => _mapCtrl?.animateCamera(CameraUpdate.zoomOut())),
          ])),
        ]);
      },
    );
  }
}

class _MapBtn extends StatelessWidget {
  final IconData ikon; final VoidCallback onTap;
  const _MapBtn(this.ikon, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
      child: Container(width: 40, height: 40,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)]),
          child: Icon(ikon, color: const Color(0xFF1a3a6b), size: 20)));
}

// ════════════════════════════════════════════════════════════════
//  KAYITLAR SAYFASİ — Proje bazlı
// ════════════════════════════════════════════════════════════════
class _KayitlarSayfasi extends StatefulWidget {
  final String firmaId, projeId;
  const _KayitlarSayfasi({required this.firmaId, required this.projeId});
  @override
  State<_KayitlarSayfasi> createState() => _KayitlarSayfasiState();
}

class _KayitlarSayfasiState extends State<_KayitlarSayfasi> with SingleTickerProviderStateMixin {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  late TabController _tab;
  @override void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); }
  @override void dispose()   { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F7FA),
    appBar: AppBar(
      backgroundColor: _navy, foregroundColor: Colors.white, elevation: 0,
      automaticallyImplyLeading: false,
      title: const Text('Kayitlar', style: TextStyle(fontWeight: FontWeight.bold)),
      bottom: TabBar(controller: _tab, indicatorColor: _turuncu,
          labelColor: Colors.white, unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.school_outlined, size: 18), text: 'Ogrenciler'),
            Tab(icon: Icon(Icons.family_restroom_outlined, size: 18), text: 'Veliler'),
          ]),
    ),
    body: TabBarView(controller: _tab, children: [
      _OgrencilerTab(firmaId: widget.firmaId, projeId: widget.projeId),
      _VelilerTab(firmaId: widget.firmaId, projeId: widget.projeId),
    ]),
  );
}

class _OgrencilerTab extends StatelessWidget {
  final String firmaId, projeId;
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  const _OgrencilerTab({required this.firmaId, required this.projeId});

  @override
  Widget build(BuildContext context) {
    final query = projeId.isNotEmpty
        ? FirebaseFirestore.instance.collection('students').where('projeId', isEqualTo: projeId).orderBy('ad')
        : FirebaseFirestore.instance.collection('students').where('firmaId', isEqualTo: firmaId).orderBy('ad');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return _BosEkran('Henuz ogrenci yok', Icons.school_outlined);
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d  = docs[i].data() as Map<String, dynamic>;
              final id = docs[i].id;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]),
                child: Row(children: [
                  CircleAvatar(radius: 20, backgroundColor: Colors.green.withValues(alpha: 0.1),
                      child: Text((d['ad'] ?? '?')[0].toUpperCase(), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d['ad'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    if ((d['adres'] ?? '').isNotEmpty)
                      Text(d['adres'], style: TextStyle(color: Colors.grey[500], fontSize: 11), overflow: TextOverflow.ellipsis),
                    if ((d['veliAd'] ?? '').isNotEmpty)
                      Text('Veli: ${d['veliAd']}', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                  ])),
                  IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                      onPressed: () => FirebaseFirestore.instance.collection('students').doc(id).delete()),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

class _VelilerTab extends StatelessWidget {
  final String firmaId, projeId;
  static const _turuncu = Color(0xFFFF8C00);
  const _VelilerTab({required this.firmaId, required this.projeId});

  @override
  Widget build(BuildContext context) {
    final query = projeId.isNotEmpty
        ? FirebaseFirestore.instance.collection('parents').where('projeId', isEqualTo: projeId)
        : FirebaseFirestore.instance.collection('parents').where('firmaId', isEqualTo: firmaId);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _turuncu, foregroundColor: Colors.white,
        onPressed: () => Navigator.pushNamed(context, '/kayit_link'),
        icon: const Icon(Icons.link_outlined), label: const Text('Kayit Linki'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return _BosEkran('Henuz veli kaydi yok', Icons.family_restroom_outlined);
          final bekl = docs.where((d) => (d.data() as Map)['durum'] == 'beklemede').toList();
          final onay = docs.where((d) => (d.data() as Map)['durum'] != 'beklemede').toList();
          return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
            if (bekl.isNotEmpty) ...[
              _SekBaslik('Bekleyenler (${bekl.length})', Icons.pending_outlined, Colors.orange),
              const SizedBox(height: 8),
              ...bekl.map((d) => _VeliKart(id: d.id, data: d.data() as Map<String, dynamic>)),
              const SizedBox(height: 16),
            ],
            _SekBaslik('Onayli (${onay.length})', Icons.check_circle_outline, Colors.green),
            const SizedBox(height: 8),
            ...onay.map((d) => _VeliKart(id: d.id, data: d.data() as Map<String, dynamic>)),
          ]);
        },
      ),
    );
  }
}

class _VeliKart extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  static const _turuncu = Color(0xFFFF8C00);
  const _VeliKart({required this.id, required this.data});

  @override
  Widget build(BuildContext context) {
    final bekl   = (data['durum'] ?? '') == 'beklemede';
    final veliAd = data['ad'] ?? data['veliAd'] ?? '?';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bekl ? _turuncu.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
      ),
      child: Column(children: [
        Row(children: [
          CircleAvatar(radius: 18, backgroundColor: _turuncu.withValues(alpha: 0.1),
              child: Text(veliAd.toString().isNotEmpty ? veliAd.toString()[0].toUpperCase() : '?',
                  style: const TextStyle(color: _turuncu, fontWeight: FontWeight.bold))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(veliAd.toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text(data['telefon'] ?? '', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            if ((data['adres'] ?? '').isNotEmpty)
              Text(data['adres'], style: TextStyle(color: Colors.grey[400], fontSize: 11), overflow: TextOverflow.ellipsis),
            if ((data['fiyat'] ?? '').isNotEmpty)
              Text('Fiyat: ${data['fiyat']}', style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.w600)),
          ])),
        ]),
        if (bekl) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => FirebaseFirestore.instance.collection('parents').doc(id).update({'durum': 'reddedildi'}),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('Reddet', style: TextStyle(fontSize: 12)),
            )),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton(
              onPressed: () => FirebaseFirestore.instance.collection('parents').doc(id).update({'durum': 'onayli'}),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('Onayla', style: TextStyle(fontSize: 12)),
            )),
          ]),
        ],
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  OPERASYON SAYFASİ — Proje bazlı
// ════════════════════════════════════════════════════════════════
class _OperasyonSayfasi extends StatefulWidget {
  final String firmaId, projeId;
  const _OperasyonSayfasi({required this.firmaId, required this.projeId});
  @override
  State<_OperasyonSayfasi> createState() => _OperasyonSayfasiState();
}

class _OperasyonSayfasiState extends State<_OperasyonSayfasi> with SingleTickerProviderStateMixin {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  late TabController _tab;
  @override void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); }
  @override void dispose()   { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F7FA),
    appBar: AppBar(
      backgroundColor: _navy, foregroundColor: Colors.white, elevation: 0,
      automaticallyImplyLeading: false,
      title: const Text('Operasyon', style: TextStyle(fontWeight: FontWeight.bold)),
      bottom: TabBar(controller: _tab, indicatorColor: _turuncu,
          labelColor: Colors.white, unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.directions_bus_outlined, size: 18), text: 'Arac / Sofor'),
            Tab(icon: Icon(Icons.person_add_outlined, size: 18), text: 'Sofor Ekle'),
          ]),
    ),
    body: TabBarView(controller: _tab, children: [
      _AracSoforListesi(firmaId: widget.firmaId, projeId: widget.projeId),
      _SoforEkleFormu(firmaId: widget.firmaId, projeId: widget.projeId),
    ]),
  );
}

class _AracSoforListesi extends StatelessWidget {
  final String firmaId, projeId;
  static const _navy = Color(0xFF1a3a6b);
  const _AracSoforListesi({required this.firmaId, required this.projeId});

  @override
  Widget build(BuildContext context) {
    final query = projeId.isNotEmpty
        ? FirebaseFirestore.instance.collection('drivers').where('projeId', isEqualTo: projeId)
        : FirebaseFirestore.instance.collection('drivers').where('firmaId', isEqualTo: firmaId);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return _BosEkran('Henuz sofor eklenmemis', Icons.directions_bus_outlined);
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d  = docs[i].data() as Map<String, dynamic>;
            final id = docs[i].id;
            final aktif = d['servisAktif'] ?? false;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: aktif ? Colors.green.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.15)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)]),
              child: Row(children: [
                CircleAvatar(radius: 22, backgroundColor: _navy.withValues(alpha: 0.1),
                    child: Text((d['ad'] ?? '?')[0].toUpperCase(), style: const TextStyle(color: _navy, fontWeight: FontWeight.bold))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d['ad'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(d['telefon'] ?? '', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  if ((d['aracPlaka'] ?? '').isNotEmpty)
                    Row(children: [
                      const Icon(Icons.directions_bus_outlined, size: 11, color: Colors.blue),
                      const SizedBox(width: 3),
                      Text(d['aracPlaka'], style: const TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.w600)),
                    ]),
                ])),
                Column(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: aktif ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(aktif ? 'Aktif' : 'Pasif',
                        style: TextStyle(color: aktif ? Colors.green : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => FirebaseFirestore.instance.collection('drivers').doc(id).delete(),
                    child: Container(padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.delete_outline, color: Colors.red, size: 16)),
                  ),
                ]),
              ]),
            );
          },
        );
      },
    );
  }
}

class _SoforEkleFormu extends StatefulWidget {
  final String firmaId, projeId;
  const _SoforEkleFormu({required this.firmaId, required this.projeId});
  @override
  State<_SoforEkleFormu> createState() => _SoforEkleFormuState();
}

class _SoforEkleFormuState extends State<_SoforEkleFormu> {
  static const _navy = Color(0xFF1a3a6b);
  final _adCtrl    = TextEditingController();
  final _telCtrl   = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _plakaCtrl = TextEditingController();
  final _markaCtrl = TextEditingController();
  bool _yukleniyor = false;

  String _sifreUret() {
    const c = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(8, (_) => c[DateTime.now().microsecondsSinceEpoch % c.length]).join();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.blue.withValues(alpha: 0.2))),
        child: const Row(children: [
          Icon(Icons.info_outline, color: Colors.blue, size: 16), SizedBox(width: 8),
          Expanded(child: Text('Sofor eklendiginde giris bilgileri WhatsApp ile gonderilir.', style: TextStyle(color: Colors.blue, fontSize: 12))),
        ]),
      ),
      const SizedBox(height: 16),
      _InputAlan(ctrl: _adCtrl,    label: 'Ad Soyad *',           ikon: Icons.person_outline),
      const SizedBox(height: 10),
      _InputAlan(ctrl: _telCtrl,   label: 'Telefon (WhatsApp)',    ikon: Icons.phone_outlined, tipi: TextInputType.phone),
      const SizedBox(height: 10),
      _InputAlan(ctrl: _emailCtrl, label: 'E-posta * (giris)',     ikon: Icons.email_outlined,  tipi: TextInputType.emailAddress),
      const SizedBox(height: 10),
      _InputAlan(ctrl: _plakaCtrl, label: 'Arac Plakasi',          ikon: Icons.directions_bus_outlined),
      const SizedBox(height: 10),
      _InputAlan(ctrl: _markaCtrl, label: 'Arac Markasi',          ikon: Icons.build_outlined),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        onPressed: _yukleniyor ? null : () async {
          if (_adCtrl.text.trim().isEmpty || _emailCtrl.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ad ve email zorunlu!'), backgroundColor: Colors.red));
            return;
          }
          setState(() => _yukleniyor = true);
          final sifre = _sifreUret();
          await FirebaseFirestore.instance.collection('drivers').add({
            'firmaId':   widget.firmaId,
            'projeId':   widget.projeId,
            'ad':        _adCtrl.text.trim(),
            'telefon':   _telCtrl.text.trim(),
            'email':     _emailCtrl.text.trim(),
            'aracPlaka': _plakaCtrl.text.trim().toUpperCase(),
            'aracMarka': _markaCtrl.text.trim(),
            'sifre':     sifre,
            'aktif':     true,
            'servisAktif': false,
            'olusturma': FieldValue.serverTimestamp(),
          });
          final tel = _telCtrl.text.trim();
          if (tel.isNotEmpty) {
            final msg = 'Merhaba ${_adCtrl.text.trim()}!\n\nServisim360 giris bilgileri:\nE-posta: ${_emailCtrl.text.trim()}\nSifre: $sifre';
            var n = tel.replaceAll(RegExp(r'[^0-9]'), '');
            if (n.startsWith('0')) n = '9$n';
            if (!n.startsWith('90')) n = '90$n';
            await launchUrl(Uri.parse('https://wa.me/$n?text=${Uri.encodeComponent(msg)}'), mode: LaunchMode.externalApplication);
          }
          setState(() => _yukleniyor = false);
          _adCtrl.clear(); _telCtrl.clear(); _emailCtrl.clear(); _plakaCtrl.clear(); _markaCtrl.clear();
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sofor eklendi!'), backgroundColor: Colors.green));
        },
        icon: _yukleniyor
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.send_rounded),
        label: Text(_yukleniyor ? 'Ekleniyor...' : 'Ekle ve WhatsApp Gonder',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      )),
    ]),
  );
}

// ════════════════════════════════════════════════════════════════
//  ROTALAR SAYFASİ
// ════════════════════════════════════════════════════════════════
class _RotalarSayfasi extends StatelessWidget {
  final String firmaId, projeId;
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  const _RotalarSayfasi({required this.firmaId, required this.projeId});

  @override
  Widget build(BuildContext context) {
    final query = projeId.isNotEmpty
        ? FirebaseFirestore.instance.collection('routes').where('projeId', isEqualTo: projeId)
        : FirebaseFirestore.instance.collection('routes').where('firmaId', isEqualTo: firmaId);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white, elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Rotalar', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [TextButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/admin_takip'),
          icon: const Icon(Icons.my_location_outlined, color: Colors.white, size: 18),
          label: const Text('Canli', style: TextStyle(color: Colors.white, fontSize: 12)),
        )],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _turuncu, foregroundColor: Colors.white,
        onPressed: () => Navigator.pushNamed(context, '/gruplama'),
        icon: const Icon(Icons.add_road), label: const Text('Rota Olustur'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return _BosEkran('Henuz rota olusturulmamis', Icons.route_outlined);
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final durak = (d['duraklar'] as List?)?.length ?? 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.route_outlined, color: Colors.blue, size: 22)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d['rotaAd'] ?? 'Rota', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('$durak durak - ${d['aracPlaka'] ?? '-'}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ])),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/canli_rota'),
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(8)),
                        child: const Text('Goruntule', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
                  ),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  YÖNETİM SAYFASİ
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

      _SekBaslik('Projeler & Kayit', Icons.folder_outlined, Colors.indigo), const SizedBox(height: 10),
      _YonetimKarti(Icons.folder_outlined,      Colors.indigo, 'Projeler',       () => Navigator.pushNamed(context, '/projeler')),
      _YonetimKarti(Icons.link_outlined,         _navy,         'Kayit Linki',   () => Navigator.pushNamed(context, '/kayit_link')),
      _YonetimKarti(Icons.message_outlined,      Colors.green,  'Toplu Mesaj',   () => Navigator.pushNamed(context, '/toplu_mesaj')),

      const SizedBox(height: 16),
      _SekBaslik('Operasyon', Icons.settings_outlined, _navy), const SizedBox(height: 10),
      _YonetimKarti(Icons.access_time_outlined,  Colors.blue,   'Servis Saatleri',  () => Navigator.pushNamed(context, '/servis_saati')),
      _YonetimKarti(Icons.route_outlined,         Colors.orange, 'Guzergah Olustur', () => Navigator.pushNamed(context, '/gruplama')),

      const SizedBox(height: 16),
      _SekBaslik('Analiz & AI', Icons.analytics_outlined, Colors.purple), const SizedBox(height: 10),
      _YonetimKarti(Icons.bar_chart_outlined,    Colors.teal,   'Raporlar',      () => Navigator.pushNamed(context, '/analiz')),
      _YonetimKarti(Icons.smart_toy_outlined,    Colors.purple, 'AI Asistan',    () => Navigator.pushNamed(context, '/ai_asistan')),
      _YonetimKarti(Icons.attach_money_outlined, Colors.green,  'Fiyat Yonetimi',() => Navigator.pushNamed(context, '/fiyat_yonetim')),

      const SizedBox(height: 16),
      _SekBaslik('Diger', Icons.more_horiz, Colors.grey), const SizedBox(height: 10),
      _YonetimKarti(Icons.description_outlined,   Colors.blue,  'Sozlesme',    () => Navigator.pushNamed(context, '/sozlesme')),
      _YonetimKarti(Icons.notifications_outlined,  Colors.amber, 'Bildirimler', () => Navigator.pushNamed(context, '/bildirimler')),
      _YonetimKarti(Icons.settings_outlined,       Colors.grey,  'Ayarlar',     () => Navigator.pushNamed(context, '/ayarlar')),

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
