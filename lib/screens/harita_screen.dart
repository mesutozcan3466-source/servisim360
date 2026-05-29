import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/session_service.dart';

// ════════════════════════════════════════════════════════════════
//  HARİTA EKRANI — Admin tam harita
//
//  ÖZELLİKLER:
//  • Tüm öğrenciler renkli pin (şoföre göre renk)
//  • Tüm aktif servisler (şoförler) canlı konum
//  • Tek tık → öğrenci/şoför detay kartı
//  • Tek tık rota çizgisi → şoför rotası haritaya çizilir
//  • Rota aç/kapa toggle
//  • Filtre: Hepsi / Sadece öğrenciler / Sadece servisler / Tek servis
//  • Servise göre renk (her şoföre farklı renk)
// ════════════════════════════════════════════════════════════════
class HaritaScreen extends StatefulWidget {
  const HaritaScreen({super.key});
  @override
  State<HaritaScreen> createState() => _HaritaScreenState();
}

class _HaritaScreenState extends State<HaritaScreen> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _orange  = Color(0xFFFF8C00);

  GoogleMapController? _mapCtrl;
  String? _firmaId;
  String? _projeId;

  // Veriler
  List<Map<String, dynamic>> _ogrenciler = [];
  List<Map<String, dynamic>> _soforler   = [];
  bool _yukleniyor = true;

  // Harita
  Set<Marker>   _markers   = {};
  Set<Polyline> _polylines = {};
  Set<Circle>   _circles   = {};

  // Filtre
  String  _filtre       = 'hepsi'; // hepsi, ogrenci, servis, tekservis
  String? _seciliSoforId;
  bool    _rotaGoster   = false;
  bool    _ogrenciGoster = true;
  bool    _servisGoster  = true;

  // Seçili eleman detay
  Map<String, dynamic>? _seciliDetay;
  String _seciliTip = ''; // 'ogrenci' | 'sofor'

  // Canlı stream
  StreamSubscription<QuerySnapshot>? _soforStream;

  // Renk paleti
  static const List<Color> _renkler = [
    Color(0xFF2196F3), Color(0xFF4CAF50), Color(0xFFE91E63),
    Color(0xFF9C27B0), Color(0xFFFF9800), Color(0xFF00BCD4),
    Color(0xFFFF5722), Color(0xFF795548), Color(0xFF607D8B),
  ];

  @override
  void initState() { super.initState(); _init(); }

  @override
  void dispose() {
    _soforStream?.cancel();
    _mapCtrl?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _firmaId = await SessionService.instance.firmaIdAl();
    _projeId = SessionService.instance.aktifProjeld;
    await _yukle();
    _soforCanliBaglat();
  }

  Future<void> _yukle() async {
    if (_firmaId == null) { setState(() => _yukleniyor = false); return; }
    try {
      // Şoförler
      final sSnap = await FirebaseFirestore.instance
          .collection('drivers').where('firmaId', isEqualTo: _firmaId).get();
      _soforler = sSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      // Öğrenciler
      var q = FirebaseFirestore.instance.collection('students')
          .where('firmaId', isEqualTo: _firmaId);
      if (_projeId != null && _projeId!.isNotEmpty) {
        q = q.where('projeId', isEqualTo: _projeId);
      }
      final oSnap = await q.get();
      _ogrenciler = oSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) { debugPrint('Harita yukle hata: $e'); }

    if (mounted) {
      setState(() => _yukleniyor = false);
      _haritaOlustur();
      _haritaFitYap();
    }
  }

  // Şoförleri canlı dinle
  void _soforCanliBaglat() {
    if (_firmaId == null) return;
    _soforStream = FirebaseFirestore.instance
        .collection('drivers')
        .where('firmaId', isEqualTo: _firmaId)
        .snapshots()
        .listen((snap) {
      _soforler = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      if (mounted) _haritaOlustur();
    });
  }

  // Renk yardımcıları
  Color _soforRenk(String surucuId) {
    final idx = _soforler.indexWhere((s) => s['id'] == surucuId);
    if (idx < 0) return Colors.red;
    return _renkler[idx % _renkler.length];
  }

  double _colorToHue(Color c) {
    final r = c.r, g = c.g, b = c.b;
    final mx = [r,g,b].reduce(math.max);
    final mn = [r,g,b].reduce(math.min);
    if (mx == mn) return 0;
    final d = mx - mn;
    double h = 0;
    if (mx == r) h = (g-b)/d + (g<b ? 6 : 0);
    else if (mx == g) h = (b-r)/d + 2;
    else h = (r-g)/d + 4;
    return (h/6*360).clamp(0, 360);
  }

  // ── HARİTA OLUŞTUR ──────────────────────────────────────────────
  void _haritaOlustur() {
    final Set<Marker>   yeniMarker   = {};
    final Set<Polyline> yeniPolyline = {};

    // ── ÖĞRENCİ MARKERLERİ ──
    if (_ogrenciGoster) {
      for (final ogr in _ogrenciler) {
        if (_filtre == 'servis') break;
        if (_filtre == 'tekservis' && ogr['surucuId'] != _seciliSoforId) continue;

        final konum = _konumAl(ogr);
        if (konum == null) continue;

        final surucuId = (ogr['surucuId'] ?? '').toString();
        final renk     = surucuId.isNotEmpty ? _soforRenk(surucuId) : Colors.red;
        final hue      = _colorToHue(renk);
        final bindi    = ogr['bindi'] == true;

        yeniMarker.add(Marker(
          markerId: MarkerId('o_${ogr['id']}'),
          position: konum,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              bindi ? BitmapDescriptor.hueGreen : hue),
          infoWindow: InfoWindow(
            title: ogr['ad'] ?? 'Ogrenci',
            snippet: bindi ? 'Bindi' : (ogr['adres'] ?? ''),
          ),
          onTap: () => _detayAc(ogr, 'ogrenci'),
        ));
      }
    }

    // ── ŞOFÖR (SERVİS) MARKERLERİ ──
    if (_servisGoster) {
      for (int i = 0; i < _soforler.length; i++) {
        final s = _soforler[i];
        if (_filtre == 'ogrenci') break;
        if (_filtre == 'tekservis' && s['id'] != _seciliSoforId) continue;

        final konum = _konumAl(s);
        if (konum == null) continue;

        final aktif = s['servisAktif'] == true;
        final renk  = _renkler[i % _renkler.length];

        yeniMarker.add(Marker(
          markerId: MarkerId('s_${s['id']}'),
          position: konum,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              aktif ? _colorToHue(renk) : BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(
            title: '${aktif ? "CANLI" : "Bekliyor"}: ${s['ad'] ?? 'Sofor'}',
            snippet: '${s['aracPlaka'] ?? ''} • ${_ogrenciler.where((o) => o['surucuId'] == s['id']).length} ogrenci',
          ),
          onTap: () => _detayAc(s, 'sofor'),
        ));

        // ── ROTA ÇİZGİSİ ──
        if (_rotaGoster) {
          final rotaNoktalar = (s['rotaNoktalar'] as List?)?.map((p) {
            if (p is GeoPoint) return LatLng(p.latitude, p.longitude);
            if (p is Map) return LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble());
            return null;
          }).whereType<LatLng>().toList() ?? [];

          if (rotaNoktalar.length > 1) {
            yeniPolyline.add(Polyline(
              polylineId: PolylineId('rota_${s['id']}'),
              points: rotaNoktalar,
              color: renk,
              width: 4,
              patterns: aktif ? [] : [PatternItem.dash(20), PatternItem.gap(10)],
            ));
          }
        }
      }
    }

    if (mounted) setState(() {
      _markers   = yeniMarker;
      _polylines = yeniPolyline;
    });
  }

  LatLng? _konumAl(Map<String, dynamic> data) {
    final k = data['konum'];
    if (k is GeoPoint) return LatLng(k.latitude, k.longitude);
    final lat = (data['lat'] ?? data['latitude'])  as double?;
    final lng = (data['lng'] ?? data['longitude']) as double?;
    if (lat != null && lng != null) return LatLng(lat, lng);
    return null;
  }

  void _haritaFitYap() {
    final tumKonumlar = <LatLng>[];
    for (final ogr in _ogrenciler) {
      final k = _konumAl(ogr); if (k != null) tumKonumlar.add(k);
    }
    for (final s in _soforler) {
      final k = _konumAl(s); if (k != null) tumKonumlar.add(k);
    }
    if (tumKonumlar.isEmpty || _mapCtrl == null) return;

    double minLat = tumKonumlar.first.latitude;
    double maxLat = minLat;
    double minLng = tumKonumlar.first.longitude;
    double maxLng = minLng;
    for (final k in tumKonumlar) {
      if (k.latitude  < minLat) minLat = k.latitude;
      if (k.latitude  > maxLat) maxLat = k.latitude;
      if (k.longitude < minLng) minLng = k.longitude;
      if (k.longitude > maxLng) maxLng = k.longitude;
    }
    _mapCtrl!.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(minLat - 0.01, minLng - 0.01),
        northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
      ), 60,
    ));
  }

  void _detayAc(Map<String, dynamic> data, String tip) {
    setState(() { _seciliDetay = data; _seciliTip = tip; });
  }

  // ── BUILD ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final aktifSofor = _soforler.where((s) => s['servisAktif'] == true).length;

    return Scaffold(
      backgroundColor: _navy,
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white, elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Harita', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          Text('${_ogrenciler.length} ogr • $aktifSofor aktif servis',
              style: const TextStyle(fontSize: 10, color: Colors.white60)),
        ]),
        actions: [
          // Rota toggle
          IconButton(
            icon: Icon(_rotaGoster ? Icons.route : Icons.route_outlined,
                color: _rotaGoster ? _orange : Colors.white70),
            tooltip: 'Rota Cizgisi',
            onPressed: () { setState(() => _rotaGoster = !_rotaGoster); _haritaOlustur(); },
          ),
          IconButton(icon: const Icon(Icons.fit_screen), onPressed: _haritaFitYap),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _yukle),
        ],
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator(color: _orange))
          : Stack(children: [
        // ── HARİTA ──
        GoogleMap(
          initialCameraPosition: const CameraPosition(
              target: LatLng(39.9334, 32.8597), zoom: 12),
          markers:   _markers,
          polylines: _polylines,
          circles:   _circles,
          onMapCreated: (c) {
            _mapCtrl = c;
            Future.delayed(const Duration(milliseconds: 600), _haritaFitYap);
          },
          onTap: (_) => setState(() { _seciliDetay = null; _seciliTip = ''; }),
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: true,
        ),

        // ── ÜST FİLTRE BARI ──
        Positioned(top: 10, left: 10, right: 10,
          child: Column(children: [
            // Filtre seçenekleri
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8)]),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _FiltrBtn('Hepsi',    'hepsi',     _filtre, Icons.layers_outlined,      () => _filtreSet('hepsi')),
                  _FiltrBtn('Ogrenci',  'ogrenci',   _filtre, Icons.person_outline,        () => _filtreSet('ogrenci')),
                  _FiltrBtn('Servisler','servis',    _filtre, Icons.directions_bus_outlined,() => _filtreSet('servis')),
                  const SizedBox(width: 4),
                  Container(width: 1, height: 24, color: Colors.grey[200]),
                  const SizedBox(width: 4),
                  // Şoföre göre filtrele
                  ..._soforler.asMap().entries.map((e) {
                    final s    = e.value;
                    final renk = _renkler[e.key % _renkler.length];
                    final sec  = _filtre == 'tekservis' && _seciliSoforId == s['id'];
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _seciliSoforId = s['id'] as String;
                          _filtre = sec ? 'hepsi' : 'tekservis';
                        });
                        _haritaOlustur();
                        // Seçilen şoförün konumuna git
                        final k = _konumAl(s);
                        if (k != null) _mapCtrl?.animateCamera(
                            CameraUpdate.newLatLngZoom(k, 14));
                      },
                      child: Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: sec ? renk : renk.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: renk.withValues(alpha: 0.4)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                              (s['servisAktif'] == true)
                                  ? Icons.directions_bus : Icons.directions_bus_outlined,
                              color: sec ? Colors.white : renk, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            _kisaAd(s['ad'] ?? 'S${e.key+1}'),
                            style: TextStyle(
                                color: sec ? Colors.white : renk,
                                fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          if (s['servisAktif'] == true) ...[
                            const SizedBox(width: 3),
                            Container(width: 5, height: 5,
                                decoration: const BoxDecoration(
                                    color: Colors.green, shape: BoxShape.circle)),
                          ],
                        ]),
                      ),
                    );
                  }),
                ]),
              ),
            ),

            // İstatistik bar
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4)]),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatKutu(Icons.people_outline, '${_markers.where((m) => m.markerId.value.startsWith("o_")).length}', 'Ogr', Colors.blue),
                  _StatKutu(Icons.directions_bus_outlined, '${_soforler.length}', 'Servis', _navy),
                  _StatKutu(Icons.circle, '$aktifSofor', 'Aktif', Colors.green),
                  _StatKutu(Icons.person_off_outlined,
                      '${_ogrenciler.where((o) => (o['surucuId'] ?? '').isEmpty).length}',
                      'Atanamis', Colors.red),
                  _StatKutu(Icons.route, _rotaGoster ? 'Acik' : 'Kapali',
                      'Rota', _rotaGoster ? _orange : Colors.grey),
                ],
              ),
            ),
          ]),
        ),

        // ── ZOOM BUTONLARI ──
        Positioned(right: 12, bottom: _seciliDetay != null ? 220 : 80,
          child: Column(children: [
            _ZoomBtn(Icons.add, () => _mapCtrl?.animateCamera(CameraUpdate.zoomIn())),
            const SizedBox(height: 6),
            _ZoomBtn(Icons.remove, () => _mapCtrl?.animateCamera(CameraUpdate.zoomOut())),
            const SizedBox(height: 6),
            _ZoomBtn(Icons.my_location, _konumumAl),
            const SizedBox(height: 6),
            _ZoomBtn(Icons.fit_screen, _haritaFitYap),
          ]),
        ),

        // ── LEGENd ──
        Positioned(bottom: _seciliDetay != null ? 230 : 90, left: 12,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _LegItem(Colors.red, 'Servis Yok'),
              _LegItem(Colors.green, 'Bindi'),
              ..._soforler.asMap().entries.take(4).map((e) =>
                  _LegItem(_renkler[e.key % _renkler.length],
                      _kisaAd(e.value['ad'] ?? 'S${e.key+1}'))),
            ]),
          ),
        ),

        // ── DETAY KARTI ──
        if (_seciliDetay != null)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _DetayKarti(
              data: _seciliDetay!,
              tip: _seciliTip,
              soforler: _soforler,
              renkler: _renkler,
              ogrenciSayisi: _ogrenciler.where(
                      (o) => o['surucuId'] == _seciliDetay!['id']).length,
              onKapat: () => setState(() { _seciliDetay = null; _seciliTip = ''; }),
              onRotaGoster: (surucuId) {
                setState(() {
                  _seciliSoforId = surucuId;
                  _filtre = 'tekservis';
                  _rotaGoster = true;
                });
                _haritaOlustur();
                // Şoföre zoom yap
                final s = _soforler.firstWhere(
                        (s) => s['id'] == surucuId, orElse: () => {});
                final k = s.isNotEmpty ? _konumAl(s) : null;
                if (k != null) _mapCtrl?.animateCamera(
                    CameraUpdate.newLatLngZoom(k, 14));
              },
              onNavigasyon: (konum) async {
                final url = Uri.parse(
                    'https://www.google.com/maps/dir/?api=1&destination=${konum.latitude},${konum.longitude}&travelmode=driving');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ),
      ]),
    );
  }

  void _filtreSet(String f) {
    setState(() { _filtre = f; _seciliSoforId = null; });
    _haritaOlustur();
  }

  void _konumumAl() async {
    final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
    _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(
        LatLng(pos.latitude, pos.longitude), 15));
  }

  String _kisaAd(String ad) {
    final parts = ad.trim().split(' ');
    return parts.length > 1 ? '${parts[0][0]}.${parts.last}' : ad.length > 8 ? ad.substring(0, 8) : ad;
  }
}

// ── DETAY KARTI ─────────────────────────────────────────────────
class _DetayKarti extends StatelessWidget {
  final Map<String, dynamic> data;
  final String tip;
  final List<Map<String, dynamic>> soforler;
  final List<Color> renkler;
  final int ogrenciSayisi;
  final VoidCallback onKapat;
  final ValueChanged<String> onRotaGoster;
  final ValueChanged<LatLng> onNavigasyon;
  static const _navy = Color(0xFF1a3a6b);

  const _DetayKarti({
    required this.data, required this.tip, required this.soforler,
    required this.renkler, required this.ogrenciSayisi,
    required this.onKapat, required this.onRotaGoster, required this.onNavigasyon,
  });

  static String _soforAdiStr(List<Map<String, dynamic>> soforler, String id) {
    if (id.isEmpty) return '';
    final s = soforler.firstWhere((s) => s['id'] == id, orElse: () => {});
    return s.isNotEmpty ? '${s['ad'] ?? 'Sofor'} (${s['aracPlaka'] ?? ''})' : 'Sofor';
  }

  @override
  Widget build(BuildContext context) {
    final adSoyad  = '${data['ad'] ?? ''} ${data['soyad'] ?? ''}'.trim();
    final surucuId = (data['surucuId'] ?? data['soforId'] ?? '').toString();
    final soforIdx = soforler.indexWhere((s) => s['id'] == data['id']);
    final renk = soforIdx >= 0 ? renkler[soforIdx % renkler.length] : _navy;
    final aktif = data['servisAktif'] == true;

    // Konum
    LatLng? konum;
    final k = data['konum'];
    if (k is GeoPoint) konum = LatLng(k.latitude, k.longitude);

    return Container(
      padding: EdgeInsets.only(
          left: 16, right: 16, top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12)]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),

        Row(children: [
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: tip == 'sofor'
                ? renk.withValues(alpha: 0.15) : _navy.withValues(alpha: 0.1),
            child: Icon(
              tip == 'sofor' ? Icons.directions_bus_outlined : Icons.person_outline,
              color: tip == 'sofor' ? renk : _navy, size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(adSoyad.isNotEmpty ? adSoyad : 'Bilgi Yok',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            if (tip == 'sofor') ...[
              Row(children: [
                Container(width: 8, height: 8, margin: const EdgeInsets.only(right: 5),
                    decoration: BoxDecoration(
                        color: aktif ? Colors.green : Colors.grey, shape: BoxShape.circle)),
                Text(aktif ? 'Servis Aktif' : 'Beklemede',
                    style: TextStyle(color: aktif ? Colors.green : Colors.grey, fontSize: 12)),
                const SizedBox(width: 8),
                Text('$ogrenciSayisi ogrenci',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ]),
              if ((data['aracPlaka'] ?? '').isNotEmpty)
                Text(data['aracPlaka'], style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            ] else ...[
              Text(data['adres'] ?? '', style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  overflow: TextOverflow.ellipsis),
              Row(children: [
                Container(width: 8, height: 8, margin: const EdgeInsets.only(right: 5),
                    decoration: BoxDecoration(
                        color: data['bindi'] == true ? Colors.green : Colors.orange,
                        shape: BoxShape.circle)),
                Text(data['bindi'] == true ? 'Bindi' : 'Bekliyor',
                    style: TextStyle(
                        color: data['bindi'] == true ? Colors.green : Colors.orange,
                        fontSize: 12)),
              ]),
            ],
          ])),
          IconButton(onPressed: onKapat, icon: const Icon(Icons.close, color: Colors.grey)),
        ]),

        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),

        // Butonlar
        Row(children: [
          if (konum != null)
            Expanded(child: _AkBtn(
              Icons.navigation_outlined, 'Navigasyon', Colors.blue,
                  () => onNavigasyon(konum!),
            )),
          if (konum != null) const SizedBox(width: 8),
          // Atanmış göster
          if (tip == 'ogrenci') ...[
            if (surucuId.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: renk.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: renk.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    Container(width: 10, height: 10, margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(color: renk, shape: BoxShape.circle)),
                    const Text('Atanmis Servis: ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    Expanded(child: Text(_soforAdiStr(soforler, surucuId),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: renk))),
                  ]),
                ),
              ),
          ],
          if (tip == 'sofor') ...[
            Expanded(child: _AkBtn(
              Icons.route, 'Rotayi Goster', renk,
                  () => onRotaGoster(data['id'] as String),
            )),
            const SizedBox(width: 8),
          ],
          if ((data['telefon'] ?? data['veliTel'] ?? '').isNotEmpty)
            Expanded(child: _AkBtn(
              Icons.phone_outlined, 'Ara', Colors.green,
                  () async {
                final tel = data['telefon'] ?? data['veliTel'] ?? '';
                await launchUrl(Uri.parse('tel:$tel'));
              },
            )),
        ]),
      ]),
    );
  }
}

// ── YARDIMCI WİDGET'LAR ─────────────────────────────────────────
class _FiltrBtn extends StatelessWidget {
  final String etiket, deger, secili; final IconData ikon; final VoidCallback onTap;
  static const _navy = Color(0xFF1a3a6b);
  const _FiltrBtn(this.etiket, this.deger, this.secili, this.ikon, this.onTap);
  @override
  Widget build(BuildContext context) {
    final aktif = secili == deger;
    return GestureDetector(onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: aktif ? _navy : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(ikon, color: aktif ? Colors.white : Colors.grey, size: 13),
            const SizedBox(width: 4),
            Text(etiket, style: TextStyle(
                color: aktif ? Colors.white : Colors.grey[700],
                fontSize: 11, fontWeight: aktif ? FontWeight.bold : FontWeight.normal)),
          ]),
        ));
  }
}

class _StatKutu extends StatelessWidget {
  final IconData ikon; final String deger, etiket; final Color renk;
  const _StatKutu(this.ikon, this.deger, this.etiket, this.renk);
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(ikon, color: renk, size: 13),
    Text(deger, style: TextStyle(color: renk, fontWeight: FontWeight.bold, fontSize: 12)),
    Text(etiket, style: TextStyle(color: Colors.grey[400], fontSize: 9)),
  ]);
}

class _LegItem extends StatelessWidget {
  final Color renk; final String etiket;
  const _LegItem(this.renk, this.etiket);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: renk, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(etiket, style: const TextStyle(fontSize: 9)),
    ]),
  );
}

class _ZoomBtn extends StatelessWidget {
  final IconData ikon; final VoidCallback onTap;
  const _ZoomBtn(this.ikon, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
      child: Container(width: 40, height: 40,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)]),
          child: Icon(ikon, color: const Color(0xFF1a3a6b), size: 20)));
}

class _AkBtn extends StatelessWidget {
  final IconData ikon; final String label; final Color color; final VoidCallback onTap;
  const _AkBtn(this.ikon, this.label, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(ikon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ]),
      ));
}
