import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'ai_widget.dart';
import 'yardim_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/session_service.dart';

// ════════════════════════════════════════════════════════════════
//  ADMİN CANLI ARAÇ TAKİP
//
//  • Tüm aktif servisler canlı (realtime stream)
//  • Her servis farklı renk
//  • Tek servis seç → sadece o görünür
//  • Servisin rota izi (geçtiği yollar polyline)
//  • Tek tık → servis detay + öğrenci listesi + navigasyon
//  • Servis durumu: aktif/bekliyor/tüm gün
//  • Hız + km + süre istatistikleri
// ════════════════════════════════════════════════════════════════
class AdminAracTakipScreen extends StatefulWidget {
  const AdminAracTakipScreen({super.key});
  @override
  State<AdminAracTakipScreen> createState() => _AdminAracTakipScreenState();
}

class _AdminAracTakipScreenState extends State<AdminAracTakipScreen> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _orange  = Color(0xFFFF8C00);

  GoogleMapController? _mapCtrl;
  String? _firmaId;
  String? _projeId;

  List<Map<String, dynamic>> _soforler   = [];
  List<Map<String, dynamic>> _ogrenciler = [];
  bool _yukleniyor = true;

  Set<Marker>   _markers   = {};
  Set<Polyline> _polylines = {};

  String? _seciliSoforId;
  bool _rotaIziGoster = true;
  bool tumServisler  = true;

  Map<String, dynamic>? _seciliSofor;

  StreamSubscription<QuerySnapshot>? _stream;

  static const List<Color> _renkler = [
    Color(0xFF2196F3), Color(0xFF4CAF50), Color(0xFFE91E63),
    Color(0xFF9C27B0), Color(0xFFFF9800), Color(0xFF00BCD4),
    Color(0xFFFF5722), Color(0xFF795548),
  ];

  @override
  void initState() { super.initState(); _init(); }

  @override
  void dispose() { _stream?.cancel(); _mapCtrl?.dispose(); super.dispose(); }

  Future<void> _init() async {
    _firmaId = await SessionService.instance.firmaIdAl();
    _projeId = SessionService.instance.aktifProjeld;
    await _ogrencileriYukle();
    _soforleriDinle();
  }

  Future<void> _ogrencileriYukle() async {
    if (_firmaId == null) return;
    try {
      var q = FirebaseFirestore.instance.collection('students')
          .where('firmaId', isEqualTo: _firmaId);
      if (_projeId != null && _projeId!.isNotEmpty) {
        q = q.where('projeId', isEqualTo: _projeId);
      }
      final snap = await q.get();
      _ogrenciler = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (_) {}
  }

  void _soforleriDinle() {
    if (_firmaId == null) return;
    // Tüm şoförleri dinle (aktif + pasif)
    _stream = FirebaseFirestore.instance
        .collection('drivers')
        .where('firmaId', isEqualTo: _firmaId)
        .snapshots()
        .listen((snap) {
      _soforler = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      if (mounted) {
        setState(() => _yukleniyor = false);
        _haritaOlustur();
      }
    });
  }

  void _haritaOlustur() {
    final Set<Marker>   yeniMarker = {};
    final Set<Polyline> yeniLine   = {};



    for (int i = 0; i < _soforler.length; i++) {
      final s = _soforler[i];
      if (!tumServisler && s['id'] != _seciliSoforId) continue;

      final konum  = _konumAl(s);
      final renk   = _renkler[i % _renkler.length];
      final aktif  = s['servisAktif'] == true;
      final surucuId = s['id'] as String;

      if (konum == null) continue;

      // Şoför marker
      yeniMarker.add(Marker(
        markerId: MarkerId('s_$surucuId'),
        position: konum,
        icon: BitmapDescriptor.defaultMarkerWithHue(
            aktif ? _colorToHue(renk) : BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(
          title: '${aktif ? "CANLI" : ""} ${s['ad'] ?? 'Sofor'}'.trim(),
          snippet: '${s['aracPlaka'] ?? ''} '
              '• ${(s['hiz'] as num? ?? 0).toStringAsFixed(0)} km/s',
        ),
        onTap: () => _soforSec(s),
        zIndexInt: aktif ? 2 : 1,
      ));

      // Öğrenci marker'ları (küçük)
      if (surucuId == _seciliSoforId) {
        final buSoforunOgr = _ogrenciler.where((o) =>
        (o['surucuId'] ?? o['soforId'] ?? '') == surucuId).toList();
        for (final ogr in buSoforunOgr) {
          final ok = _konumAl(ogr);
          if (ok == null) continue;
          final bindi = ogr['bindi'] == true;
          yeniMarker.add(Marker(
            markerId: MarkerId('o_${ogr['id']}'),
            position: ok,
            icon: BitmapDescriptor.defaultMarkerWithHue(
                bindi ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueOrange),
            infoWindow: InfoWindow(
              title: ogr['ad'] ?? 'Ogrenci',
              snippet: bindi ? 'Bindi' : (ogr['adres'] ?? 'Bekliyor'),
            ),
          ));
        }
      }

      // Rota izi polyline
      if (_rotaIziGoster && aktif) {
        final rotaNoktalar = (s['rotaNoktalar'] as List?)?.map((p) {
          if (p is GeoPoint) return LatLng(p.latitude, p.longitude);
          if (p is Map) return LatLng(
              (p['lat'] as num).toDouble(), (p['lng'] as num).toDouble());
          return null;
        }).whereType<LatLng>().toList() ?? [];

        if (rotaNoktalar.length > 1) {
          yeniLine.add(Polyline(
            polylineId: PolylineId('iz_$surucuId'),
            points: rotaNoktalar,
            color: renk.withValues(alpha: 0.6),
            width: 3,
            patterns: [PatternItem.dash(15), PatternItem.gap(8)],
          ));
        }

        // Şoförün gidişi (anlık konum → son nokta arası)
        if (rotaNoktalar.isNotEmpty) {
          yeniLine.add(Polyline(
            polylineId: PolylineId('canli_$surucuId'),
            points: [...rotaNoktalar, konum],
            color: renk,
            width: 5,
          ));
        }
      }
    }

    if (mounted) setState(() { _markers = yeniMarker; _polylines = yeniLine; });
  }

  LatLng? _konumAl(Map<String, dynamic> data) {
    final k = data['konum'];
    if (k is GeoPoint) return LatLng(k.latitude, k.longitude);
    final lat = (data['lat'] ?? data['latitude'])  as double?;
    final lng = (data['lng'] ?? data['longitude']) as double?;
    if (lat != null && lng != null) return LatLng(lat, lng);
    return null;
  }

  double _colorToHue(Color c) {
    final r = c.r, g = c.g, b = c.b;
    final mx = [r,g,b].reduce(math.max);
    final mn = [r,g,b].reduce(math.min);
    if (mx == mn) return 0;
    final d = mx - mn; double h = 0;
    if (mx == r) h = (g-b)/d + (g<b ? 6 : 0);
    else if (mx == g) h = (b-r)/d + 2;
    else h = (r-g)/d + 4;
    return (h/6*360).clamp(0, 360);
  }

  void _soforSec(Map<String, dynamic> s) {
    final sid = s['id'] as String;
    setState(() {
      _seciliSofor    = s;
      _seciliSoforId  = sid;
      tumServisler   = false;
    });
    _haritaOlustur();
    // Seçilen şoföre zoom
    final k = _konumAl(s);
    if (k != null) _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(k, 14));
  }

  void _tumunuGoster() {
    setState(() { _seciliSofor = null; _seciliSoforId = null; tumServisler = true; });
    _haritaOlustur();
    _haritaFitYap();
  }

  void _haritaFitYap() {
    final tum = <LatLng>[];
    for (final s in _soforler) { final k = _konumAl(s); if (k != null) tum.add(k); }
    if (tum.isEmpty || _mapCtrl == null) return;
    double minLat = tum.first.latitude, maxLat = minLat;
    double minLng = tum.first.longitude, maxLng = minLng;
    for (final k in tum) {
      if (k.latitude  < minLat) minLat = k.latitude;
      if (k.latitude  > maxLat) maxLat = k.latitude;
      if (k.longitude < minLng) minLng = k.longitude;
      if (k.longitude > maxLng) maxLng = k.longitude;
    }
    _mapCtrl!.animateCamera(CameraUpdate.newLatLngBounds(LatLngBounds(
      southwest: LatLng(minLat - 0.01, minLng - 0.01),
      northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
    ), 70));
  }

  @override
  Widget build(BuildContext context) {
    final aktifSayi = _soforler.where((s) => s['servisAktif'] == true).length;

    return Scaffold(
      backgroundColor: _navy,
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white, elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Canli Arac Takip', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          Row(children: [
            Container(width: 7, height: 7, margin: const EdgeInsets.only(right: 5),
                decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
            Text('$aktifSayi aktif • ${_soforler.length} toplam',
                style: const TextStyle(fontSize: 10, color: Colors.white60)),
          ]),
        ]),
        actions: [
          AiAsistanButonu(ekranAdi: 'Harita'),
          YardimButonu(ekranAdi: 'Harita'),
          // Rota izi toggle
          IconButton(
            icon: Icon(_rotaIziGoster ? Icons.timeline : Icons.timeline_outlined,
                color: _rotaIziGoster ? _orange : Colors.white70),
            tooltip: 'Rota izi',
            onPressed: () { setState(() => _rotaIziGoster = !_rotaIziGoster); _haritaOlustur(); },
          ),
          if (!tumServisler)
            IconButton(
              icon: const Icon(Icons.layers_clear),
              tooltip: 'Tumunu Goster',
              onPressed: _tumunuGoster,
            ),
          IconButton(icon: const Icon(Icons.fit_screen), onPressed: _haritaFitYap),
        ],
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator(color: _orange))
          : Stack(children: [
        GoogleMap(
          initialCameraPosition: const CameraPosition(
              target: LatLng(39.9334, 32.8597), zoom: 12),
          markers:   _markers,
          polylines: _polylines,
          onMapCreated: (c) {
            _mapCtrl = c;
            Future.delayed(const Duration(milliseconds: 700), _haritaFitYap);
          },
          onTap: (_) {
            if (!tumServisler) return;
            setState(() { _seciliSofor = null; });
          },
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          trafficEnabled: true,
        ),

        // ── SERVİS LİSTESİ (yatay kaydırma) ──
        Positioned(top: 10, left: 0, right: 0,
          child: Column(children: [
            // Servis seçim bar
            SizedBox(height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  // Tümü butonu
                  GestureDetector(
                    onTap: _tumunuGoster,
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: tumServisler ? _navy : Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6)],
                      ),
                      child: Row(children: [
                        Icon(Icons.layers_outlined,
                            color: tumServisler ? Colors.white : _navy, size: 16),
                        const SizedBox(width: 6),
                        Text('Tumu ($aktifSayi aktif)',
                            style: TextStyle(
                                color: tumServisler ? Colors.white : _navy,
                                fontWeight: FontWeight.bold, fontSize: 12)),
                      ]),
                    ),
                  ),
                  // Her şoför
                  ..._soforler.asMap().entries.map((e) {
                    final s     = e.value;
                    final renk  = _renkler[e.key % _renkler.length];
                    final aktif = s['servisAktif'] == true;
                    final sec   = _seciliSoforId == s['id'];
                    final hiz   = (s['hiz'] as num? ?? 0).toStringAsFixed(0);
                    final ogrSayi = _ogrenciler.where((o) =>
                    (o['surucuId'] ?? o['soforId'] ?? '') == s['id']).length;

                    return GestureDetector(
                      onTap: () => _soforSec(s),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: sec ? renk : Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                              color: aktif ? renk : Colors.grey.shade300,
                              width: aktif ? 2 : 1),
                          boxShadow: [BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1), blurRadius: 6)],
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          // Canlı nokta
                          if (aktif)
                            Container(width: 7, height: 7, margin: const EdgeInsets.only(right: 5),
                                decoration: BoxDecoration(
                                    color: sec ? Colors.white : renk,
                                    shape: BoxShape.circle)),
                          Icon(Icons.directions_bus_outlined,
                              color: sec ? Colors.white : (aktif ? renk : Colors.grey),
                              size: 15),
                          const SizedBox(width: 5),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s['ad'] ?? 'Sofor',
                                style: TextStyle(
                                    color: sec ? Colors.white : Colors.black87,
                                    fontWeight: FontWeight.bold, fontSize: 11)),
                            Text(
                              aktif ? '$hiz km/s • $ogrSayi ogr' : '$ogrSayi ogr',
                              style: TextStyle(
                                  color: sec ? Colors.white70 : Colors.grey,
                                  fontSize: 9),
                            ),
                          ]),
                        ]),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // Seçili şoför detay bar
            if (!tumServisler && _seciliSofor != null) ...[
              const SizedBox(height: 6),
              _ServisDetayBar(
                sofor: _seciliSofor!,
                ogrenciler: _ogrenciler.where((o) =>
                (o['surucuId'] ?? o['soforId'] ?? '') == _seciliSofor!['id']).toList(),
                renk: _renkler[_soforler.indexWhere(
                        (s) => s['id'] == _seciliSofor!['id']) % _renkler.length],
                onNavigasyon: (konum) async {
                  final url = Uri.parse(
                      'https://www.google.com/maps/dir/?api=1&destination=${konum.latitude},${konum.longitude}&travelmode=driving');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],
          ]),
        ),

        // ── ZOOM BUTONLARI ──
        Positioned(right: 12, bottom: 80, child: Column(children: [
          _ZoomBtn(Icons.add, () => _mapCtrl?.animateCamera(CameraUpdate.zoomIn())),
          const SizedBox(height: 6),
          _ZoomBtn(Icons.remove, () => _mapCtrl?.animateCamera(CameraUpdate.zoomOut())),
        ])),

        // ── LEGEND ──
        Positioned(bottom: 24, left: 12,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ..._soforler.asMap().entries.take(5).map((e) {
                final s    = e.value;
                final renk = _renkler[e.key % _renkler.length];
                final aktif = s['servisAktif'] == true;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 10, height: 10,
                        decoration: BoxDecoration(
                            color: aktif ? renk : Colors.grey,
                            shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text(s['ad'] ?? 'S${e.key+1}',
                        style: const TextStyle(fontSize: 9)),
                    if (aktif) ...[
                      const SizedBox(width: 3),
                      const Text('●', style: TextStyle(color: Colors.green, fontSize: 8)),
                    ],
                  ]),
                );
              }),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── SERVİS DETAY BARI ───────────────────────────────────────────
class _ServisDetayBar extends StatelessWidget {
  final Map<String, dynamic> sofor;
  final List<Map<String, dynamic>> ogrenciler;
  final Color renk;
  final ValueChanged<LatLng> onNavigasyon;

  const _ServisDetayBar({
    required this.sofor, required this.ogrenciler,
    required this.renk, required this.onNavigasyon,
  });

  @override
  Widget build(BuildContext context) {
    final aktif   = sofor['servisAktif'] == true;
    final hiz     = (sofor['hiz'] as num? ?? 0).toStringAsFixed(0);
    final bindi   = ogrenciler.where((o) => o['bindi'] == true).length;
    final bekliyor = ogrenciler.length - bindi;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8)]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Başlık
        Row(children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(
              color: aktif ? renk : Colors.grey, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(child: Text(sofor['ad'] ?? 'Sofor',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          Text(sofor['aracPlaka'] ?? '',
              style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          const SizedBox(width: 8),
          // Navigasyon
          GestureDetector(
            onTap: () {
              final k = sofor['konum'];
              if (k is GeoPoint) onNavigasyon(LatLng(k.latitude, k.longitude));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.navigation_outlined, color: Colors.blue, size: 13),
                SizedBox(width: 3),
                Text('Git', style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 8),

        // İstatistikler
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _MiniStat('$hiz km/s', 'Hiz', Icons.speed_outlined, renk),
          _MiniStat('$bindi', 'Bindi', Icons.check_circle_outline, Colors.green),
          _MiniStat('$bekliyor', 'Bekliyor', Icons.hourglass_empty, Colors.orange),
          _MiniStat('${ogrenciler.length}', 'Toplam', Icons.people_outline, Colors.blue),
        ]),

        // Öğrenci listesi
        if (ogrenciler.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: ogrenciler.length,
              itemBuilder: (_, i) {
                final o = ogrenciler[i];
                final b = o['bindi'] == true;
                return Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: b ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: b ? Colors.green.withValues(alpha: 0.4) : Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    Icon(b ? Icons.check_circle_outline : Icons.person_outline,
                        color: b ? Colors.green : Colors.orange, size: 12),
                    const SizedBox(width: 4),
                    Text(o['ad'] ?? '?', style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w600,
                        color: b ? Colors.green : Colors.orange)),
                  ]),
                );
              },
            ),
          ),
        ],
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String deger, etiket; final IconData ikon; final Color renk;
  const _MiniStat(this.deger, this.etiket, this.ikon, this.renk);
  @override
  Widget build(BuildContext context) => Column(children: [
    Icon(ikon, color: renk, size: 14),
    Text(deger, style: TextStyle(color: renk, fontWeight: FontWeight.bold, fontSize: 13)),
    Text(etiket, style: TextStyle(color: Colors.grey[400], fontSize: 9)),
  ]);
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
