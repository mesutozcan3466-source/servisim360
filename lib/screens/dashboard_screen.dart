import 'package:flutter/material.dart';
import 'ai_widget.dart';
import 'yardim_widget.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
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

  int _toplamOgrenci   = 0;
  int _toplamSofor     = 0;
  int _aktifServis     = 0;
  int _toplamVeli      = 0;
  int _bekleyenBasvuru = 0;

  static const _menuler = [
    {'ikon': Icons.home_outlined,           'etiket': 'Ana Ekran'},
    {'ikon': Icons.people_outline,          'etiket': 'Kayitlar'},
    {'ikon': Icons.directions_bus_outlined, 'etiket': 'Operasyon'},
    {'ikon': Icons.route_outlined,          'etiket': 'Rotalar'},
    {'ikon': Icons.settings_outlined,       'etiket': 'Yonetim'},
  ];

  @override
  void initState() { super.initState(); _yukle(); }

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
      var ogrQ = FirebaseFirestore.instance.collection('students').where('firmaId', isEqualTo: firmaId);
      var sofQ = FirebaseFirestore.instance.collection('drivers').where('firmaId', isEqualTo: firmaId);
      if (projeId.isNotEmpty) {
        ogrQ = ogrQ.where('projeId', isEqualTo: projeId);
        sofQ = sofQ.where('projeId', isEqualTo: projeId);
      }
      final results = await Future.wait([
        ogrQ.get(), sofQ.get(),
        FirebaseFirestore.instance.collection('parents').where('firmaId', isEqualTo: firmaId).get(),
        FirebaseFirestore.instance.collection('absence_requests')
            .where('firmaId', isEqualTo: firmaId).where('durum', isEqualTo: 'bekliyor').get(),
      ]);
      final aktif = results[1].docs.where((d) => (d.data() as Map)['servisAktif'] == true).length;
      if (mounted) setState(() {
        _toplamOgrenci   = results[0].docs.length;
        _toplamSofor     = results[1].docs.length;
        _toplamVeli      = results[2].docs.length;
        _aktifServis     = aktif;
        _bekleyenBasvuru = results[3].docs.length;
      });
    } catch (_) {}
  }

  void _projeSecimAc() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProjeSecScreen()))
        .then((_) => _yukle());
  }

  void _projeTemizle() {
    SessionService.instance.projeTemizle();
    setState(() { _projeId = ''; _projeAd = ''; });
    _yukle();
  }

  Widget _sayfa() {
    if (!_yuklendi) return const Center(child: CircularProgressIndicator(color: Color(0xFF1a3a6b)));
    switch (_seciliMenu) {
      case 0: return _AnaSayfa(
        firmaId: _firmaId, projeId: _projeId, projeAd: _projeAd,
        toplamOgrenci: _toplamOgrenci, toplamSofor: _toplamSofor,
        aktifServis: _aktifServis, toplamVeli: _toplamVeli,
        bekleyenBasvuru: _bekleyenBasvuru,
        onProjeSecimAc: _projeSecimAc, onTemizle: _projeTemizle,
      );
      case 1: return _KayitlarSayfasi(firmaId: _firmaId, projeId: _projeId);
      case 2: return _OperasyonSayfasi(firmaId: _firmaId, projeId: _projeId);
      case 3: return _RotalarSayfasi(firmaId: _firmaId, projeId: _projeId);
      case 4: return _YonetimSayfasi(firmaId: _firmaId, firmaAd: _firmaAd,
          projeId: _projeId, projeAd: _projeAd, onProjeSecimAc: _projeSecimAc);
      default: return _AnaSayfa(
        firmaId: _firmaId, projeId: _projeId, projeAd: _projeAd,
        toplamOgrenci: _toplamOgrenci, toplamSofor: _toplamSofor,
        aktifServis: _aktifServis, toplamVeli: _toplamVeli,
        bekleyenBasvuru: _bekleyenBasvuru,
        onProjeSecimAc: _projeSecimAc, onTemizle: _projeTemizle,
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
        title: Row(children: [
          Container(width: 30, height: 30,
              decoration: BoxDecoration(color: _turuncu, borderRadius: BorderRadius.circular(8)),
              child: const Center(child: Text('S', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_firmaAd.isNotEmpty ? _firmaAd : 'Servisim360',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
            if (_projeAd.isNotEmpty)
              Text(_projeAd, style: const TextStyle(fontSize: 10, color: _turuncu, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
          ])),
        ]),
        actions: [
          AiAsistanButonu(ekranAdi: 'Ana Ekran'),
          YardimButonu(ekranAdi: 'Ana Ekran'),
          GestureDetector(
            onTap: _projeSecimAc,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _projeAd.isNotEmpty ? _turuncu : Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.folder_outlined, size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Text(_projeAd.isNotEmpty ? 'Proje' : 'Proje Sec',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
            ),
          ),
          IconButton(
              icon: Container(padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: _turuncu.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.psychology_outlined, color: _turuncu, size: 18)),
              onPressed: () => Navigator.pushNamed(context, '/ai_asistan')),
          IconButton(
              icon: const Icon(Icons.logout_outlined),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) Navigator.pushReplacementNamed(context, '/login');
              }),
        ],
      ),
      body: GlobalAiAsistanWrapper(firmaId: _firmaId, firmaAd: _firmaAd, child: _sayfa()),
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
                  Text(_menuler[i]['etiket'] as String, style: TextStyle(fontSize: 9,
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

// ════════════════════════════════════════════════════════════════
//  ANA SAYFA — HARİTA BÜYÜK
// ════════════════════════════════════════════════════════════════
class _AnaSayfa extends StatefulWidget {
  final String firmaId, projeId, projeAd;
  final int toplamOgrenci, toplamSofor, aktifServis, toplamVeli, bekleyenBasvuru;
  final VoidCallback onProjeSecimAc, onTemizle;

  const _AnaSayfa({
    required this.firmaId, required this.projeId, required this.projeAd,
    required this.toplamOgrenci, required this.toplamSofor,
    required this.aktifServis, required this.toplamVeli,
    required this.bekleyenBasvuru,
    required this.onProjeSecimAc, required this.onTemizle,
  });

  @override
  State<_AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<_AnaSayfa> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  GoogleMapController? _mapCtrl;
  Set<Marker> _markerlar = {};
  bool _haritaYukleniyor = true;
  bool _statsGizli = false;

  List<Map<String, dynamic>> _soforler   = [];
  List<Map<String, dynamic>> _ogrenciler = [];

  Map<String, dynamic>? _seciliVeri;
  String _seciliTip = '';

  static const _merkez = CameraPosition(target: LatLng(39.1667, 35.6667), zoom: 6);

  @override
  void initState() { super.initState(); _haritaYukle(); }

  @override
  void dispose() { _mapCtrl?.dispose(); super.dispose(); }

  Future<void> _haritaYukle() async {
    if (widget.firmaId.isEmpty) { setState(() => _haritaYukleniyor = false); return; }
    try {
      var sofQ = FirebaseFirestore.instance.collection('drivers').where('firmaId', isEqualTo: widget.firmaId);
      var ogrQ = FirebaseFirestore.instance.collection('students').where('firmaId', isEqualTo: widget.firmaId);
      if (widget.projeId.isNotEmpty) {
        sofQ = sofQ.where('projeId', isEqualTo: widget.projeId);
        ogrQ = ogrQ.where('projeId', isEqualTo: widget.projeId);
      }
      final sofSnap = await sofQ.get();
      final ogrSnap = await ogrQ.get();
      _soforler   = sofSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      _ogrenciler = ogrSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      await _markerlarOlustur();
    } catch (_) {}
    if (mounted) setState(() => _haritaYukleniyor = false);
  }

  Future<void> _markerlarOlustur() async {
    final Set<Marker> yeni = {};
    for (final s in _soforler) {
      final k = _konumAl(s); if (k == null) continue;
      final aktif = s['servisAktif'] == true;
      yeni.add(Marker(
        markerId: MarkerId('sof_${s['id']}'), position: k,
        icon: BitmapDescriptor.defaultMarkerWithHue(aktif ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueBlue),
        onTap: () => setState(() { _seciliVeri = s; _seciliTip = 'sofor'; }),
      ));
    }
    for (final o in _ogrenciler) {
      final k = _konumAl(o); if (k == null) continue;
      final bindi = o['bindi'] == true;
      yeni.add(Marker(
        markerId: MarkerId('ogr_${o['id']}'), position: k,
        icon: BitmapDescriptor.defaultMarkerWithHue(bindi ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueOrange),
        onTap: () => setState(() { _seciliVeri = o; _seciliTip = 'ogrenci'; }),
      ));
    }
    if (mounted) setState(() => _markerlar = yeni);
    if (_markerlar.isNotEmpty && _mapCtrl != null) {
      Future.delayed(const Duration(milliseconds: 300), _kameraFit);
    }
  }

  LatLng? _konumAl(Map<String, dynamic> d) {
    final k = d['konum']; if (k == null) return null;
    try {
      double? lat, lng;
      if (k is Map) { lat = (k['latitude'] ?? k['lat'])?.toDouble(); lng = (k['longitude'] ?? k['lng'])?.toDouble(); }
      else { lat = k.latitude?.toDouble(); lng = k.longitude?.toDouble(); }
      if (lat != null && lng != null) return LatLng(lat, lng);
    } catch (_) {}
    return null;
  }

  void _kameraFit() {
    if (_markerlar.isEmpty || _mapCtrl == null) return;
    final pts = _markerlar.map((m) => m.position).toList();
    if (pts.length == 1) { _mapCtrl!.animateCamera(CameraUpdate.newLatLngZoom(pts.first, 14)); return; }
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _mapCtrl!.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: LatLng(minLat - 0.01, minLng - 0.01), northeast: LatLng(maxLat + 0.01, maxLng + 0.01)), 80));
  }

  Future<void> _mevcutKonumAl() async {
    try {
      bool svcOn = await Geolocator.isLocationServiceEnabled();
      if (!svcOn) return;
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return;
      }
      final pos = await Geolocator.getCurrentPosition();
      _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 14));
    } catch (_) {}
  }

  void _takipEtAc() {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent,
        builder: (_) => Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const Text('Servis Takip', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1a3a6b))),
            const SizedBox(height: 4),
            const Text('Takip etmek istediginiz servisi secin', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () { Navigator.pop(context); _kameraFit(); },
              child: Container(
                padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(color: _navy.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _navy.withValues(alpha: 0.2))),
                child: const Row(children: [
                  Icon(Icons.directions_bus_outlined, color: Color(0xFF1a3a6b), size: 20),
                  SizedBox(width: 12),
                  Expanded(child: Text('Tum Servisler', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1a3a6b)))),
                  Icon(Icons.chevron_right, color: Colors.grey),
                ]),
              ),
            ),
            ..._soforler.map((s) {
              final k = _konumAl(s);
              final aktif = s['servisAktif'] == true;
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  if (k != null) _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(k, 15));
                  setState(() { _seciliVeri = s; _seciliTip = 'sofor'; });
                },
                child: Container(
                  padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: aktif ? Colors.green.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2))),
                  child: Row(children: [
                    Container(width: 10, height: 10,
                        decoration: BoxDecoration(color: aktif ? Colors.green : Colors.grey, shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s['ad'] ?? 'Sofor', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(s['aracPlaka'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ])),
                    if (k != null) Icon(Icons.location_on, color: aktif ? Colors.green : Colors.grey, size: 16)
                    else const Text('Konum yok', style: TextStyle(fontSize: 10, color: Colors.red)),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 8),
          ]),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Proje banner
      if (widget.projeAd.isNotEmpty)
        Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: _turuncu,
            child: Row(children: [
              const Icon(Icons.folder_outlined, color: Colors.white, size: 14), const SizedBox(width: 8),
              Expanded(child: Text('Proje: ${widget.projeAd}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
              GestureDetector(onTap: widget.onTemizle, child: const Icon(Icons.close, color: Colors.white70, size: 14)),
            ]))
      else
        Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), color: _navy.withValues(alpha: 0.05),
            child: Row(children: [
              Icon(Icons.folder_open_outlined, color: _navy.withValues(alpha: 0.4), size: 14), const SizedBox(width: 8),
              Expanded(child: Text('Tum firma verileri', style: TextStyle(color: _navy.withValues(alpha: 0.5), fontSize: 11))),
              GestureDetector(onTap: widget.onProjeSecimAc,
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: _turuncu, borderRadius: BorderRadius.circular(6)),
                      child: const Text('Proje Sec', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))),
            ])),

      // Firma yoksa kurulum kartı
      if (widget.firmaId.isEmpty)
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1a3a6b), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.business_outlined, color: Color(0xFF1a3a6b), size: 22),
              SizedBox(width: 8),
              Text('Firma Kurulumu', style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1a3a6b))),
            ]),
            const SizedBox(height: 8),
            const Text('Sistemi kullanmak için önce firma bilgilerinizi girin. '
                'Daha sonra projeler ve rotalar oluşturabilirsiniz.',
                style: TextStyle(fontSize: 13, color: Colors.black54)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1a3a6b),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: () => Navigator.pushNamed(context, '/firma_ekle'),
                icon: const Icon(Icons.add_business_outlined, color: Colors.white, size: 18),
                label: const Text('Firma Oluştur', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF8C00),
                    side: const BorderSide(color: Color(0xFFFF8C00)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: () => Navigator.pushNamed(context, '/projeler'),
                icon: const Icon(Icons.folder_open_outlined, size: 18),
                label: const Text('Projeler', style: TextStyle(fontWeight: FontWeight.bold)),
              )),
            ]),
          ]),
        ),

      // Mini istatistikler (gizlenebilir)
      AnimatedSize(
        duration: const Duration(milliseconds: 250),
        child: _statsGizli ? const SizedBox.shrink() : Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(children: [
            Expanded(child: _MiniStat('${widget.toplamOgrenci}', 'Ogrenci', Icons.school_outlined, Colors.blue,
                    () => Navigator.of(context).pushNamed('/ogrenci'))),
            const SizedBox(width: 6),
            Expanded(child: _MiniStat('${widget.toplamSofor}', 'Sofor', Icons.directions_bus_outlined,
                widget.aktifServis > 0 ? Colors.green : _navy,
                    () => Navigator.of(context).pushNamed('/suruculer'),
                widget.aktifServis > 0 ? '${widget.aktifServis} aktif' : null)),
            const SizedBox(width: 6),
            Expanded(child: _MiniStat('${widget.toplamVeli}', 'Veli', Icons.family_restroom_outlined, Colors.purple)),
            const SizedBox(width: 6),
            Expanded(child: _MiniStat('${widget.bekleyenBasvuru}', 'Bekleyen', Icons.event_busy_outlined,
                widget.bekleyenBasvuru > 0 ? Colors.red : Colors.teal,
                widget.bekleyenBasvuru > 0 ? () => Navigator.of(context).pushNamed('/veli_basvurular') : null)),
          ]),
        ),
      ),

      // HARİTA — büyük
      Expanded(child: Stack(children: [
        GoogleMap(
          initialCameraPosition: _merkez,
          markers: _markerlar,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          onMapCreated: (c) { _mapCtrl = c; _haritaYukle(); },
          onTap: (_) => setState(() { _seciliVeri = null; _seciliTip = ''; }),
        ),

        if (_haritaYukleniyor)
          const Center(child: CircularProgressIndicator(color: Color(0xFF1a3a6b))),

        // Sol üst — istatistik gizle/göster
        Positioned(top: 10, left: 10, child: GestureDetector(
          onTap: () => setState(() => _statsGizli = !_statsGizli),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6)]),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_statsGizli ? Icons.expand_more : Icons.expand_less, color: _navy, size: 16),
              const SizedBox(width: 4),
              Text(_statsGizli ? 'Istatistik' : 'Gizle',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1a3a6b))),
            ]),
          ),
        )),

        // Sağ üst — Takip Et
        Positioned(top: 10, right: 10, child: GestureDetector(
          onTap: _takipEtAc,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: widget.aktifServis > 0 ? Colors.green : _navy,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6)],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(widget.aktifServis > 0 ? '${widget.aktifServis} Aktif' : 'Takip Et',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 10),
            ]),
          ),
        )),

        // Sağ alt — zoom + konum + yenile
        Positioned(right: 10, bottom: _seciliVeri != null ? 180 : 16, child: Column(children: [
          _MapBtn(Icons.add, () => _mapCtrl?.animateCamera(CameraUpdate.zoomIn())),
          const SizedBox(height: 6),
          _MapBtn(Icons.remove, () => _mapCtrl?.animateCamera(CameraUpdate.zoomOut())),
          const SizedBox(height: 6),
          _MapBtn(Icons.my_location, _mevcutKonumAl, renk: Colors.blue),
          const SizedBox(height: 6),
          _MapBtn(Icons.fit_screen, _kameraFit),
          const SizedBox(height: 6),
          _MapBtn(Icons.refresh, _haritaYukle),
        ])),

        // Sol alt — marker sayısı
        Positioned(left: 10, bottom: _seciliVeri != null ? 180 : 16, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6)]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.location_on, color: Colors.red, size: 12), const SizedBox(width: 4),
            Text('${_markerlar.length} nokta',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1a3a6b))),
          ]),
        )),

        // Alt popup — marker detay
        if (_seciliVeri != null)
          Positioned(bottom: 0, left: 0, right: 0, child: _MarkerPopup(
            veri: _seciliVeri!, tip: _seciliTip, ogrenciler: _ogrenciler,
            onKapat: () => setState(() { _seciliVeri = null; _seciliTip = ''; }),
            onNavigasyon: () async {
              final k = _konumAl(_seciliVeri!);
              if (k != null) {
                final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${k.latitude},${k.longitude}');
                if (await canLaunchUrl(url)) launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            onAra: () async {
              final tel = _seciliVeri!['telefon'] ?? _seciliVeri!['veliTel'] ?? '';
              if (tel.isNotEmpty) {
                final url = Uri.parse('tel:$tel');
                if (await canLaunchUrl(url)) launchUrl(url);
              }
            },
          )),
      ])),
    ]);
  }
}

// ── MİNİ İSTATİSTİK ──
class _MiniStat extends StatelessWidget {
  final String deger, baslik; final IconData icon; final Color renk;
  final VoidCallback? onTap; final String? alt;
  const _MiniStat(this.deger, this.baslik, this.icon, this.renk, [this.onTap, this.alt]);

  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)]),
        child: Column(children: [
          Icon(icon, color: renk, size: 18),
          const SizedBox(height: 3),
          Text(deger, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: renk)),
          Text(baslik, style: const TextStyle(fontSize: 9, color: Colors.grey)),
          if (alt != null) Text(alt!, style: TextStyle(fontSize: 8, color: renk, fontWeight: FontWeight.w600)),
        ]),
      ));
}

// ── HARİTA BUTONU ──
class _MapBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap; final Color renk;
  const _MapBtn(this.icon, this.onTap, {this.renk = const Color(0xFF1a3a6b)});

  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
      child: Container(width: 36, height: 36,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 4)]),
          child: Icon(icon, color: renk, size: 18)));
}

// ── MARKER POPUP ──
class _MarkerPopup extends StatelessWidget {
  final Map<String, dynamic> veri; final String tip;
  final List<Map<String, dynamic>> ogrenciler;
  final VoidCallback onKapat, onNavigasyon, onAra;

  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  const _MarkerPopup({required this.veri, required this.tip, required this.ogrenciler,
    required this.onKapat, required this.onNavigasyon, required this.onAra});

  LatLng? _konumAl(Map<String, dynamic> d) {
    final k = d['konum']; if (k == null) return null;
    try {
      double? lat, lng;
      if (k is Map) { lat = (k['latitude'] ?? k['lat'])?.toDouble(); lng = (k['longitude'] ?? k['lng'])?.toDouble(); }
      else { lat = k.latitude?.toDouble(); lng = k.longitude?.toDouble(); }
      if (lat != null && lng != null) return LatLng(lat, lng);
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isSofor = tip == 'sofor';
    final ad      = veri['ad'] ?? (isSofor ? 'Sofor' : 'Ogrenci');
    final aktif   = veri['servisAktif'] == true;
    final bindi   = veri['bindi'] == true;
    final telefon = veri['telefon'] ?? veri['veliTel'] ?? '';
    final plaka   = veri['aracPlaka'] ?? '';
    final adres   = veri['adres'] ?? '';
    final soforOgrencileri = isSofor
        ? ogrenciler.where((o) => (o['surucuId'] ?? '') == veri['id']).toList()
        : <Map<String, dynamic>>[];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, -4))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
        Row(children: [
          Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: (isSofor ? (aktif ? Colors.green : _navy) : _turuncu).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(isSofor ? Icons.directions_bus_outlined : Icons.school_outlined,
                  color: isSofor ? (aktif ? Colors.green : _navy) : _turuncu, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ad, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _navy)),
            Row(children: [
              Container(width: 8, height: 8, margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                      color: isSofor ? (aktif ? Colors.green : Colors.grey) : (bindi ? Colors.green : Colors.orange),
                      shape: BoxShape.circle)),
              Text(isSofor ? (aktif ? 'Aktif Servis' : 'Pasif') : (bindi ? 'Bindi' : 'Bekliyor'),
                  style: TextStyle(fontSize: 12,
                      color: isSofor ? (aktif ? Colors.green : Colors.grey) : (bindi ? Colors.green : Colors.orange))),
            ]),
          ])),
          GestureDetector(onTap: onKapat,
              child: Container(padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.close, color: Colors.grey, size: 16))),
        ]),
        if (plaka.isNotEmpty || adres.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(10)),
              child: Column(children: [
                if (plaka.isNotEmpty) Row(children: [
                  Icon(Icons.directions_car, color: Colors.grey[500], size: 14), const SizedBox(width: 6),
                  Text(plaka, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ]),
                if (adres.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.location_on_outlined, color: Colors.grey[500], size: 14), const SizedBox(width: 6),
                    Expanded(child: Text(adres, style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ]),
                ],
              ])),
        ],
        if (isSofor && soforOgrencileri.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.people_outline, color: _navy, size: 14), const SizedBox(width: 6),
            Text('${soforOgrencileri.length} Ogrenci',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _navy)),
          ]),
          const SizedBox(height: 6),
          SizedBox(height: 30, child: ListView(scrollDirection: Axis.horizontal,
              children: soforOgrencileri.map((o) {
                final b = o['bindi'] == true;
                return Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: b ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: b ? Colors.green : Colors.orange)),
                  child: Text(o['ad'] ?? '', style: TextStyle(fontSize: 11, color: b ? Colors.green : Colors.orange, fontWeight: FontWeight.w600)),
                );
              }).toList())),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 10),
        Row(children: [
          if (telefon.isNotEmpty) Expanded(child: GestureDetector(onTap: onAra,
              child: Container(padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3))),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.phone_outlined, color: Colors.green, size: 16), SizedBox(width: 6),
                    Text('Ara', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                  ])))),
          if (telefon.isNotEmpty) const SizedBox(width: 8),
          Expanded(child: GestureDetector(onTap: onNavigasyon,
              child: Container(padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(color: _navy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _navy.withValues(alpha: 0.2))),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.navigation_outlined, color: _navy, size: 16), SizedBox(width: 6),
                    Text('Navigasyon', style: TextStyle(color: _navy, fontWeight: FontWeight.bold, fontSize: 13)),
                  ])))),
        ]),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  DİĞER SAYFALAR
// ════════════════════════════════════════════════════════════════
class _KayitlarSayfasi extends StatelessWidget {
  final String firmaId, projeId;
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  const _KayitlarSayfasi({required this.firmaId, required this.projeId});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SekBaslik('Kayit Islemleri', Icons.assignment_outlined, _navy), const SizedBox(height: 12),
      GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.4,
          children: [
            _KayitKarti(ikon: Icons.link_outlined, renk: _navy, baslik: 'Kayit Linki', alt: 'WhatsApp ile paylas', onTap: () => Navigator.pushNamed(context, '/kayit_link')),
            _KayitKarti(ikon: Icons.qr_code_2, renk: Colors.teal, baslik: 'QR Afis', alt: 'QR tarat', onTap: () => Navigator.pushNamed(context, '/qr_afis')),
            _KayitKarti(ikon: Icons.person_add_outlined, renk: _turuncu, baslik: 'Yuz Yuze Kayit', alt: 'Admin ekle', onTap: () => Navigator.pushNamed(context, '/yuz_yuze_kayit')),
            _KayitKarti(ikon: Icons.upload_file_outlined, renk: Colors.indigo, baslik: 'Toplu Yukle', alt: 'Excel / PDF', onTap: () => Navigator.pushNamed(context, '/toplu_yukle')),
          ]),
      const SizedBox(height: 20),
      const _SekBaslik('Ogrenci Listesi', Icons.people_outline, Colors.blue), const SizedBox(height: 12),
      _OgrenciListesi(firmaId: firmaId, projeId: projeId),
      const SizedBox(height: 20),
      const _SekBaslik('Mesaj & Iletisim', Icons.message_outlined, Colors.green), const SizedBox(height: 12),
      _YonetimKarti(Icons.chat_outlined, const Color(0xFF25D366), 'Toplu WhatsApp', () => Navigator.pushNamed(context, '/toplu_whatsapp')),
      _YonetimKarti(Icons.message_outlined, Colors.blue, 'Toplu Bildirim', () => Navigator.pushNamed(context, '/toplu_mesaj')),
      _YonetimKarti(Icons.event_busy_outlined, Colors.red, 'Devamsizlik', () => Navigator.pushNamed(context, '/yoklama')),
      const SizedBox(height: 24),
    ]),
  );
}

class _OperasyonSayfasi extends StatelessWidget {
  final String firmaId, projeId;
  static const _navy = Color(0xFF1a3a6b);
  const _OperasyonSayfasi({required this.firmaId, required this.projeId});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SekBaslik('Canli Operasyon', Icons.directions_bus_outlined, Colors.green), const SizedBox(height: 12),
      _YonetimKarti(Icons.my_location_outlined, Colors.green, 'Canli Arac Takibi', () => Navigator.pushNamed(context, '/admin_takip')),
      _YonetimKarti(Icons.alt_route_outlined, Colors.orange, 'Canli Rota', () => Navigator.pushNamed(context, '/canli_rota')),
      _YonetimKarti(Icons.access_time_outlined, Colors.blue, 'Servis Saatleri', () => Navigator.pushNamed(context, '/servis_saati')),
      const SizedBox(height: 20),
      const _SekBaslik('Servisler', Icons.directions_bus_outlined, _navy), const SizedBox(height: 12),
      _YonetimKarti(Icons.directions_bus_filled_rounded, _navy, 'Servis Yonetimi', () => Navigator.pushNamed(context, '/suruculer')),
      _YonetimKarti(Icons.route_outlined, Colors.orange, 'Rotalar', () => Navigator.pushNamed(context, '/rotalar')),
      const SizedBox(height: 20),
      const _SekBaslik('Kayitlar', Icons.people_outlined, Colors.blue), const SizedBox(height: 12),
      _YonetimKarti(Icons.people_outlined, Colors.blue, 'Kayitlar & Ogrenciler', () => Navigator.pushNamed(context, '/ogrenci')),
      _YonetimKarti(Icons.event_busy_outlined, Colors.red, 'Devamsizlik', () => Navigator.pushNamed(context, '/yoklama')),
      const SizedBox(height: 20),
      const _SekBaslik('Yonetim', Icons.settings_outlined, Colors.purple), const SizedBox(height: 12),
      _YonetimKarti(Icons.description_outlined, Colors.teal, 'Sozlesme Yonetimi', () => Navigator.pushNamed(context, '/sozlesme_yonetim')),
      _YonetimKarti(Icons.attach_money_outlined, Colors.green, 'Fiyatlandirma', () => Navigator.pushNamed(context, '/fiyat_yonetim')),
      _YonetimKarti(Icons.history_outlined, Colors.purple, 'Guzergah Gecmisi', () => Navigator.pushNamed(context, '/guzergah_gecmis')),
      _YonetimKarti(Icons.archive_outlined, Colors.indigo, 'Proje Arsivi', () => Navigator.pushNamed(context, '/proje_arsiv')),
      const SizedBox(height: 24),
    ]),
  );
}

class _RotalarSayfasi extends StatelessWidget {
  final String firmaId, projeId;
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  const _RotalarSayfasi({required this.firmaId, required this.projeId});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SekBaslik('Rota Planlama', Icons.route_outlined, Color(0xFFFF8C00)), const SizedBox(height: 12),
      _YonetimKarti(Icons.add_road_outlined, _turuncu, 'Rota Olustur (AI)', () => Navigator.pushNamed(context, '/gruplama')),
      _YonetimKarti(Icons.list_alt_outlined, _navy, 'Mevcut Rotalar', () => Navigator.pushNamed(context, '/rotalar')),
      _YonetimKarti(Icons.map_outlined, Colors.teal, 'Harita', () => Navigator.pushNamed(context, '/harita')),
      const SizedBox(height: 20),
      const _SekBaslik('Guzergah', Icons.history_outlined, Colors.indigo), const SizedBox(height: 12),
      _YonetimKarti(Icons.add_location_outlined, Colors.indigo, 'Guzergah Kaydet', () => Navigator.pushNamed(context, '/guzergah_kayit')),
      _YonetimKarti(Icons.history_outlined, Colors.grey, 'Gecmis Guzergahlar', () => Navigator.pushNamed(context, '/guzergah_gecmis')),
      const SizedBox(height: 20),
      const _SekBaslik('Analiz', Icons.analytics_outlined, Colors.purple), const SizedBox(height: 12),
      _YonetimKarti(Icons.bar_chart_outlined, Colors.purple, 'Raporlar', () => Navigator.pushNamed(context, '/analiz')),
      _YonetimKarti(Icons.smart_toy_outlined, Colors.deepPurple, 'AI Asistan', () => Navigator.pushNamed(context, '/ai_asistan')),
      const SizedBox(height: 24),
    ]),
  );
}

class _YonetimSayfasi extends StatelessWidget {
  final String firmaId, firmaAd, projeId, projeAd;
  final VoidCallback onProjeSecimAc;
  static const _navy   = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);
  const _YonetimSayfasi({required this.firmaId, required this.firmaAd,
    required this.projeId, required this.projeAd, required this.onProjeSecimAc});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(gradient: const LinearGradient(
              colors: [_navy, Color(0xFF2a5298)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(firmaAd.isNotEmpty ? firmaAd : 'Firma',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
              const Icon(Icons.business_outlined, color: Colors.white30, size: 36),
            ]),
            const SizedBox(height: 10),
            GestureDetector(onTap: onProjeSecimAc,
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Icon(Icons.folder_outlined, color: _orange, size: 16), const SizedBox(width: 8),
                      Expanded(child: Text(projeAd.isNotEmpty ? projeAd : 'Proje secilmemis',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12))),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: _orange.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(6)),
                          child: const Text('Degistir', style: TextStyle(color: _orange, fontSize: 10, fontWeight: FontWeight.w700))),
                    ]))),
          ])),
      const SizedBox(height: 16),
      const _SekBaslik('Kayit Sistemi', Icons.assignment_outlined, Colors.indigo), const SizedBox(height: 10),
      _YonetimKarti(Icons.folder_outlined, Colors.indigo, 'Projeler', () => Navigator.pushNamed(context, '/projeler')),
      _YonetimKarti(Icons.link_outlined, _navy, 'Kayit Linki', () => Navigator.pushNamed(context, '/kayit_link')),
      _YonetimKarti(Icons.qr_code_2, Colors.teal, 'QR Afis', () => Navigator.pushNamed(context, '/qr_afis')),
      _YonetimKarti(Icons.person_add_outlined, _orange, 'Yuz Yuze Kayit', () => Navigator.pushNamed(context, '/yuz_yuze_kayit')),
      const SizedBox(height: 16),
      const _SekBaslik('Mesaj & Iletisim', Icons.message_outlined, Colors.green), const SizedBox(height: 10),
      _YonetimKarti(Icons.chat_outlined, const Color(0xFF25D366), 'Toplu WhatsApp', () => Navigator.pushNamed(context, '/toplu_whatsapp')),
      _YonetimKarti(Icons.send_outlined, Colors.blue, 'Toplu Bildirim', () => Navigator.pushNamed(context, '/toplu_mesaj')),
      _YonetimKarti(Icons.notifications_outlined, Colors.amber, 'Bildirimler', () => Navigator.pushNamed(context, '/bildirimler')),
      const SizedBox(height: 16),
      const _SekBaslik('Operasyon', Icons.settings_outlined, _navy), const SizedBox(height: 10),
      _YonetimKarti(Icons.access_time_outlined, Colors.blue, 'Servis Saatleri', () => Navigator.pushNamed(context, '/servis_saati')),
      _YonetimKarti(Icons.add_road_outlined, Colors.orange, 'Rota Olustur', () => Navigator.pushNamed(context, '/gruplama')),
      _YonetimKarti(Icons.drive_eta_outlined, _navy, 'Sofor Yonetimi', () => Navigator.pushNamed(context, '/suruculer')),
      _YonetimKarti(Icons.people_outline, Colors.indigo, 'Ogrenci Listesi', () => Navigator.pushNamed(context, '/ogrenci')),
      _YonetimKarti(Icons.location_on_outlined, Colors.red, 'Bolge Atama', () => Navigator.pushNamed(context, '/bolge_atama')),
      _YonetimKarti(Icons.call_split_outlined, Colors.purple, 'Servis Bol', () => Navigator.pushNamed(context, '/servis_bolme')),
      const SizedBox(height: 16),
      const _SekBaslik('Analiz & AI', Icons.analytics_outlined, Colors.purple), const SizedBox(height: 10),
      _YonetimKarti(Icons.bar_chart_outlined, Colors.teal, 'Raporlar', () => Navigator.pushNamed(context, '/analiz')),
      _YonetimKarti(Icons.smart_toy_outlined, Colors.purple, 'AI Asistan', () => Navigator.pushNamed(context, '/ai_asistan')),
      _YonetimKarti(Icons.attach_money_outlined, Colors.green, 'Fiyat Yonetimi', () => Navigator.pushNamed(context, '/fiyat_yonetim')),
      const SizedBox(height: 16),
      const _SekBaslik('Sistem', Icons.more_horiz, Colors.grey), const SizedBox(height: 10),
      _YonetimKarti(Icons.settings_outlined, Colors.grey, 'Ayarlar', () => Navigator.pushNamed(context, '/ayarlar')),
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

// ── ORTAK WIDGET'LAR ──
class _KayitKarti extends StatelessWidget {
  final IconData ikon; final Color renk; final String baslik, alt; final VoidCallback onTap;
  const _KayitKarti({required this.ikon, required this.renk, required this.baslik, required this.alt, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
      child: Container(padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)],
              border: Border.all(color: renk.withValues(alpha: 0.15))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: renk.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(ikon, color: renk, size: 22)),
            const SizedBox(height: 8),
            Text(baslik, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: renk)),
            Text(alt, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          ])));
}

class _OgrenciListesi extends StatelessWidget {
  final String firmaId, projeId;
  static const _navy = Color(0xFF1a3a6b);
  const _OgrenciListesi({required this.firmaId, required this.projeId});

  @override
  Widget build(BuildContext context) {
    if (firmaId.isEmpty) return const SizedBox.shrink();
    var q = FirebaseFirestore.instance.collection('students').where('firmaId', isEqualTo: firmaId);
    if (projeId.isNotEmpty) q = q.where('projeId', isEqualTo: projeId);
    return StreamBuilder<QuerySnapshot>(
      stream: q.orderBy('ad').snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return Container(padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: const Center(child: Text('Henuz ogrenci eklenmemis', style: TextStyle(color: Colors.grey))));
        return Column(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: _navy.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.people_outline, color: _navy, size: 16), const SizedBox(width: 8),
                Text('${docs.length} ogrenci', style: const TextStyle(fontWeight: FontWeight.w600, color: _navy, fontSize: 12)),
                const Spacer(),
                GestureDetector(onTap: () => Navigator.pushNamed(context, '/ogrenci'),
                    child: const Text('Tumunu Gor', style: TextStyle(color: _navy, fontSize: 11, fontWeight: FontWeight.w700))),
              ])),
          const SizedBox(height: 8),
          ...docs.take(5).map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            return Container(margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]),
                child: Row(children: [
                  CircleAvatar(radius: 16, backgroundColor: _navy.withValues(alpha: 0.1),
                      child: Text((d['ad'] ?? '?')[0].toUpperCase(),
                          style: const TextStyle(color: _navy, fontWeight: FontWeight.bold, fontSize: 12))),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d['ad'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(d['veliTel'] ?? d['adres'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ])),
                ]));
          }),
          if (docs.length > 5)
            TextButton(onPressed: () => Navigator.pushNamed(context, '/ogrenci'),
                child: Text('+${docs.length - 5} daha...', style: const TextStyle(color: _navy))),
        ]);
      },
    );
  }
}

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

class _SekBaslik extends StatelessWidget {
  final String baslik; final IconData ikon; final Color renk;
  const _SekBaslik(this.baslik, this.ikon, this.renk);

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(ikon, color: renk, size: 16), const SizedBox(width: 8),
    Text(baslik, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: renk)),
  ]);
}
