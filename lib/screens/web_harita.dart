import 'package:flutter/material.dart';
import 'ai_widget.dart';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import '../services/session_service.dart';

class WebHarita extends StatefulWidget {
  final String firmaId;
  final String projeId;
  const WebHarita({super.key, this.firmaId = '', this.projeId = ''});
  @override
  State<WebHarita> createState() => _WebHaritaState();
}

class _WebHaritaState extends State<WebHarita> {
  static const Color _navy   = Color(0xFF1a3a6b);
  static const Color _orange = Color(0xFFFF8C00);

  static const List<Color> _renkler = [
    Color(0xFF2196F3), Color(0xFF4CAF50), Color(0xFFE91E63),
    Color(0xFF9C27B0), Color(0xFFFF9800), Color(0xFF00BCD4),
    Color(0xFFFF5722), Color(0xFF795548),
  ];

  String _firmaId = '';
  List<Map<String, dynamic>> _soforler   = [];
  List<Map<String, dynamic>> _ogrenciler = [];
  StreamSubscription? _sub;
  bool _yukleniyor = true;
  String? _seciliSoforId;
  Map<String, dynamic>? _seciliSofor;
  bool _detayPanelAcik = false;

  GoogleMapController? _mapController;
  Set<Marker>   _markerlar   = {};
  Set<Polyline> _polylineler = {};
  MapType  _mapTipi        = MapType.normal;
  DateTime _sonGuncelleme  = DateTime.now();

  static const CameraPosition _turkiyeMerkez = CameraPosition(
    target: LatLng(39.9334, 32.8597),
    zoom: 6,
  );

  @override
  void initState() {
    super.initState();
    _yukle();
    _aktifAraclariDinle();
    Future.delayed(const Duration(seconds: 30), _otomatikYenile);
  }

  Future<void> _otomatikYenile() async {
    if (!mounted) return;
    setState(() => _sonGuncelleme = DateTime.now());
    await _markerlarOlustur();
    if (mounted) Future.delayed(const Duration(seconds: 30), _otomatikYenile);
  }

  @override
  void didUpdateWidget(WebHarita oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projeId != widget.projeId || oldWidget.firmaId != widget.firmaId) {
      _yukle();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }


  // Aktif araçları dinle — surucu_konumlar koleksiyonu
  void _aktifAraclariDinle() {
    FirebaseFirestore.instance
        .collection('surucu_konumlar')
        .where('firmaId', isEqualTo: _firmaId)
        .where('aktif', isEqualTo: true)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final newMarkers = <Marker>{};
      final renkler = [
        const Color(0xFF1a3a6b), Colors.red, Colors.green,
        Colors.orange, Colors.purple, Colors.teal,
      ];
      for (int i = 0; i < snap.docs.length; i++) {
        final d = snap.docs[i].data();
        final konum = d['konum'];
        if (konum is! GeoPoint) continue;
        final pos = LatLng(konum.latitude, konum.longitude);
        final soforId = snap.docs[i].id;
        final renk = BitmapDescriptor.defaultMarkerWithHue(
            i % 6 == 0 ? BitmapDescriptor.hueBlue
                : i % 6 == 1 ? BitmapDescriptor.hueRed
                : i % 6 == 2 ? BitmapDescriptor.hueGreen
                : i % 6 == 3 ? BitmapDescriptor.hueOrange
                : i % 6 == 4 ? BitmapDescriptor.hueViolet
                : BitmapDescriptor.hueCyan);
        newMarkers.add(Marker(
          markerId: MarkerId('arac_$soforId'),
          position: pos,
          icon: renk,
          infoWindow: InfoWindow(
              title: 'Servis ${i + 1}',
              snippet: '${d['hiz']?.toStringAsFixed(0) ?? '0'} km/s'),
        ));
      }
      setState(() {
        // Araç markerlarını güncelle
        _markerlar.removeWhere((m) => m.markerId.value.startsWith('arac_'));
        _markerlar.addAll(newMarkers);
      });
    });
  }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);

    // Parametre olarak verilmisse kullan, yoksa session'dan al
    if (widget.firmaId.isNotEmpty) {
      _firmaId = widget.firmaId;
    } else {
      _firmaId = await SessionService.instance.firmaIdAl() ?? '';
    }

    if (_firmaId.isEmpty) {
      setState(() => _yukleniyor = false);
      return;
    }

    try {
      var ogrQuery = FirebaseFirestore.instance
          .collection('students')
          .where('firmaId', isEqualTo: _firmaId);
      if (widget.projeId.isNotEmpty) {
        ogrQuery = ogrQuery.where('projeId', isEqualTo: widget.projeId);
      }
      final oSnap = await ogrQuery.get();
      _ogrenciler = oSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) {
      debugPrint('Ogrenci yukle hata: $e');
    }

    _sub?.cancel();
    var sofQuery = FirebaseFirestore.instance
        .collection('drivers')
        .where('firmaId', isEqualTo: _firmaId);
    if (widget.projeId.isNotEmpty) {
      sofQuery = sofQuery.where('projeId', isEqualTo: widget.projeId);
    }

    _sub = sofQuery.snapshots().listen((snap) {
      if (!mounted) return;
      _soforler = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      // setState sadece şoförler değiştiyse çağır
      if (mounted) {
        _markerlarOlustur();
        setState(() => _sonGuncelleme = DateTime.now());
      }
    });

    if (mounted) setState(() => _yukleniyor = false);
  }

  // ── Mesafe hesaplama (Haversine) ─────────────────────────────
  double _mesafeHesapla(LatLng a, LatLng b) {
    const R = 6371000.0;
    final dLat = (b.latitude  - a.latitude)  * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final x = math.sin(dLat/2) * math.sin(dLat/2) +
        math.cos(a.latitude  * math.pi / 180) *
            math.cos(b.latitude  * math.pi / 180) *
            math.sin(dLng/2) * math.sin(dLng/2);
    return R * 2 * math.atan2(math.sqrt(x), math.sqrt(1 - x));
  }

  // ── Nearest Neighbor — en yakın komşu algoritması ─────────────
  // 17 öğrenci için bile saniyeler içinde en kısa rotayı bulur
  List<Map<String, dynamic>> _rotaSirala(
      List<Map<String, dynamic>> ogrenciler, LatLng? baslangic) {
    if (ogrenciler.isEmpty) return ogrenciler;

    // Konumu olan öğrencileri filtrele
    final konumluOgrenciler = ogrenciler
        .where((o) => _konumAl(o) != null).toList();
    final konumsuzlar = ogrenciler
        .where((o) => _konumAl(o) == null).toList();

    if (konumluOgrenciler.isEmpty) return ogrenciler;

    final siralananlar = <Map<String, dynamic>>[];
    final kalan = List<Map<String, dynamic>>.from(konumluOgrenciler);

    // Başlangıç noktası: şoför konumu yoksa ilk öğrenci
    LatLng mevcutKonum = baslangic ?? _konumAl(kalan.first)!;

    while (kalan.isNotEmpty) {
      // En yakın öğrenciyi bul
      double minMesafe = double.infinity;
      int enYakinIdx = 0;

      for (var i = 0; i < kalan.length; i++) {
        final k = _konumAl(kalan[i]);
        if (k == null) continue;
        final m = _mesafeHesapla(mevcutKonum, k);
        if (m < minMesafe) { minMesafe = m; enYakinIdx = i; }
      }

      final secilen = kalan.removeAt(enYakinIdx);
      siralananlar.add(secilen);
      mevcutKonum = _konumAl(secilen)!;
    }

    return [...siralananlar, ...konumsuzlar];
  }

  LatLng? _konumAl(Map<String, dynamic> d) {
    final k = d['konum'];
    if (k == null) return null;
    try {
      double? lat, lng;
      if (k is Map) {
        lat = (k['latitude'] ?? k['lat'])?.toDouble();
        lng = (k['longitude'] ?? k['lng'])?.toDouble();
      } else {
        lat = k.latitude?.toDouble();
        lng = k.longitude?.toDouble();
      }
      if (lat != null && lng != null) return LatLng(lat, lng);
    } catch (_) {}
    return null;
  }

  Future<void> _markerlarOlustur() async {
    final Set<Marker> yeniMarkerlar = {};
    final Set<Polyline> yeniPolylineler = {};

    for (int i = 0; i < _soforler.length; i++) {
      final s = _soforler[i];
      final sid = s['id'] as String;
      if (_seciliSoforId != null && sid != _seciliSoforId) continue;

      final renk = _renkler[i % _renkler.length];
      final aktif = s['servisAktif'] ?? false;

      final soforKonum = _konumAl(s);
      if (soforKonum != null) {
        yeniMarkerlar.add(Marker(
          markerId: MarkerId('sofor_$sid'),
          position: soforKonum,
          infoWindow: InfoWindow(
            title: s['ad'] ?? 'Sofor',
            snippet: aktif ? 'Aktif Servis' : 'Pasif',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            aktif ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueBlue,
          ),
        ));
      }

      // Öğrencileri en yakın komşu algoritmasıyla sırala
      final tumOgrenciler =
      _ogrenciler.where((o) => (o['surucuId'] ?? '') == sid).toList();
      final siraliOgrenciler = _rotaSirala(tumOgrenciler, soforKonum);
      final List<LatLng> rotaNoktalar = [];
      if (soforKonum != null) rotaNoktalar.add(soforKonum);

      for (var rotaIdx = 0; rotaIdx < siraliOgrenciler.length; rotaIdx++) {
        final ogr = siraliOgrenciler[rotaIdx];
        final ogrKonum = _konumAl(ogr);
        if (ogrKonum != null) {
          final bindi   = ogr['bindi'] ?? false;
          final siraNo  = rotaIdx + 1;
          yeniMarkerlar.add(Marker(
            markerId: MarkerId('ogr_${ogr['id']}'),
            position: ogrKonum,
            infoWindow: InfoWindow(
              title: '$siraNo. ${ogr['ad'] ?? 'Ogrenci'}',
              snippet: bindi
                  ? '✅ Bindi'
                  : '⏳ Bekliyor — ${(ogrKonum != null && soforKonum != null)
                  ? '${(_mesafeHesapla(soforKonum, ogrKonum) / 1000).toStringAsFixed(1)} km'
                  : ''}',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              bindi
                  ? BitmapDescriptor.hueGreen
                  : BitmapDescriptor.hueOrange,
            ),
          ));
          rotaNoktalar.add(ogrKonum);
        }
      }

      if (rotaNoktalar.length >= 2) {
        yeniPolylineler.add(Polyline(
          polylineId: PolylineId('rota_$sid'),
          points: rotaNoktalar,
          color: renk,
          width: 3,
          patterns: aktif ? [] : [PatternItem.dash(10), PatternItem.gap(5)],
        ));
      }
    }

    setState(() {
      _markerlar = yeniMarkerlar;
      _polylineler = yeniPolylineler;
    });

    if (_markerlar.isNotEmpty && _mapController != null) {
      _kameraFit();
    }
  }

  void _kameraFit() {
    if (_markerlar.isEmpty || _mapController == null) return;
    final noktalar = _markerlar.map((m) => m.position).toList();
    if (noktalar.length == 1) {
      _mapController!.animateCamera(CameraUpdate.newLatLngZoom(noktalar.first, 14));
      return;
    }
    double minLat = noktalar.first.latitude;
    double maxLat = noktalar.first.latitude;
    double minLng = noktalar.first.longitude;
    double maxLng = noktalar.first.longitude;
    for (final n in noktalar) {
      if (n.latitude < minLat) minLat = n.latitude;
      if (n.latitude > maxLat) maxLat = n.latitude;
      if (n.longitude < minLng) minLng = n.longitude;
      if (n.longitude > maxLng) maxLng = n.longitude;
    }
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(minLat - 0.01, minLng - 0.01),
        northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
      ),
      80,
    ));
  }

  int _ogrenciSayisi(String id) =>
      _ogrenciler.where((o) => (o['surucuId'] ?? '') == id).length;

  int _bindiSayisi(String id) =>
      _ogrenciler.where((o) => (o['surucuId'] ?? '') == id && o['bindi'] == true).length;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      // SOL PANEL
      Container(
        width: 260,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(right: BorderSide(color: Color(0xFFEEEEEE))),
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(14),
            color: _navy,
            child: Row(children: [
              const Icon(Icons.directions_bus_outlined, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Servisler',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                Text(
                    '${_sonGuncelleme.hour.toString().padLeft(2, '0')}:'
                        '${_sonGuncelleme.minute.toString().padLeft(2, '0')}'
                        ' güncellendi',
                    style: const TextStyle(color: Colors.white54, fontSize: 9)),
              ])),
              GestureDetector(
                onTap: () {
                  setState(() { _seciliSoforId = null; _seciliSofor = null; });
                  _markerlarOlustur();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Text('Tumu', style: TextStyle(color: Colors.white, fontSize: 11)),
                ),
              ),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFFF8F9FA),
            child: Row(children: [
              _OzetChip('${_soforler.length}', 'Servis', Colors.blue),
              const SizedBox(width: 8),
              _OzetChip('${_ogrenciler.length}', 'Ogrenci', _navy),
              const SizedBox(width: 8),
              _OzetChip(
                  '${_ogrenciler.where((o) => (o["surucuId"] ?? "").toString().isEmpty).length}',
                  'Atanmamis', Colors.red),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: _soforler.isEmpty
                ? const Center(child: Text('Henuz sofor eklenmemis', style: TextStyle(color: Colors.grey)))
                : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: _soforler.length,
              itemBuilder: (_, i) {
                final s = _soforler[i];
                final sid = s['id'] as String;
                final secili = _seciliSoforId == sid;
                final renk = _renkler[i % _renkler.length];
                final aktif = s['servisAktif'] ?? false;
                final ogrSayi = _ogrenciSayisi(sid);
                final bindiSayi = _bindiSayisi(sid);
                final konumVar = _konumAl(s) != null;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _seciliSoforId = secili ? null : sid;
                      _seciliSofor = secili ? null : {...s, '_index': i};
                    });
                    _markerlarOlustur();
                    if (!secili) {
                      final k = _konumAl(s);
                      if (k != null && _mapController != null) {
                        _mapController!.animateCamera(CameraUpdate.newLatLngZoom(k, 13));
                      }
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: secili ? renk.withValues(alpha: 0.08) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: secili ? renk : Colors.grey.shade200,
                          width: secili ? 2 : 1),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(width: 10, height: 10,
                            decoration: BoxDecoration(
                                color: aktif ? Colors.green : renk,
                                shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(s['ad'] ?? 'Sofor',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12,
                                color: secili ? renk : Colors.black87))),
                        Text('$ogrSayi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: renk)),
                      ]),
                      if (s['aracPlaka'] != null) ...[
                        const SizedBox(height: 2),
                        Text(s['aracPlaka'], style: const TextStyle(color: Colors.grey, fontSize: 10)),
                      ],
                      if (!konumVar)
                        const Text('Konum yok', style: TextStyle(color: Colors.red, fontSize: 9)),
                      if (secili && ogrSayi > 0) ...[
                        const SizedBox(height: 6),
                        Text('$bindiSayi/$ogrSayi bindi',
                            style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.w600)),
                      ],
                    ]),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFEEEEEE)))),
            child: Column(children: [
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: _orange, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8)),
                icon: const Icon(Icons.auto_awesome, size: 14),
                label: const Text('Otomatik Dagit', style: TextStyle(fontSize: 12)),
                onPressed: () => Navigator.pushNamed(context, '/servis_bolme'),
              )),
              const SizedBox(height: 6),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: _navy, side: const BorderSide(color: _navy),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8)),
                icon: const Icon(Icons.add_road_outlined, size: 14),
                label: const Text('Rota Olustur', style: TextStyle(fontSize: 12)),
                onPressed: () => Navigator.pushNamed(context, '/gruplama'),
              )),
            ]),
          ),
        ]),
      ),

      // SAG HARITA
      Expanded(child: Column(children: [
        Expanded(child: Stack(children: [
          GoogleMap(
            initialCameraPosition: _turkiyeMerkez,
            onMapCreated: (controller) {
              _mapController = controller;
              _markerlarOlustur();
            },
            markers: _markerlar,
            polylines: _polylineler,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            mapToolbarEnabled: false,
            mapType: _mapTipi,
          ),
          // Loading overlay - harita hep görünür kalır
          if (_yukleniyor)
            Container(
              color: Colors.white.withValues(alpha: 0.7),
              child: const Center(
                child: CircularProgressIndicator(color: _navy),
              ),
            ),
          Positioned(top: 12, right: 12, child: Column(children: [
            _HaritaBtn(icon: Icons.refresh, tooltip: 'Yenile', onTap: _yukle),
            const SizedBox(height: 6),
            _HaritaBtn(icon: Icons.fit_screen, tooltip: 'Hepsini Goster', onTap: _kameraFit),
            const SizedBox(height: 6),
            _HaritaBtn(
              icon: _mapTipi == MapType.normal
                  ? Icons.satellite_alt_outlined
                  : Icons.map_outlined,
              tooltip: _mapTipi == MapType.normal ? 'Uydu Gorunumu' : 'Normal Goruntu',
              onTap: () => setState(() {
                _mapTipi = _mapTipi == MapType.normal
                    ? MapType.satellite : MapType.normal;
              }),
            ),
            const SizedBox(height: 6),
            _HaritaBtn(icon: Icons.route, tooltip: 'Canli Rota',
                onTap: () => Navigator.pushNamed(context, '/canli_rota')),
          ])),
          Positioned(top: 12, left: 12, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6)]),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.location_on, color: Colors.red, size: 14),
              const SizedBox(width: 4),
              Text('${_markerlar.length} nokta',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _navy)),
            ]),
          )),
          if (_soforler.isEmpty)
            Center(child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)]),
              child: const Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.directions_bus_outlined, size: 48, color: Colors.grey),
                SizedBox(height: 12),
                Text('Henuz servis eklenmemis', style: TextStyle(color: Colors.grey, fontSize: 14)),
              ]),
            )),
        ])),
        if (_seciliSofor != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white,
                border: const Border(top: BorderSide(color: Color(0xFFEEEEEE))),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, -2))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 12, height: 12,
                    decoration: BoxDecoration(
                        color: _renkler[(_seciliSofor!['_index'] as int) % _renkler.length],
                        shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(child: Text(_seciliSofor!['ad'] ?? 'Sofor',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _navy))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (_seciliSofor!['servisAktif'] ?? false)
                        ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    (_seciliSofor!['servisAktif'] ?? false) ? '● Aktif' : '○ Pasif',
                    style: TextStyle(
                        color: (_seciliSofor!['servisAktif'] ?? false) ? Colors.green : Colors.grey,
                        fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() { _seciliSoforId = null; _seciliSofor = null; });
                    _markerlarOlustur();
                  },
                  child: const Icon(Icons.close, color: Colors.grey, size: 18),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                _DetayKart(Icons.directions_car, _seciliSofor!['aracPlaka'] ?? '-', Colors.blue),
                const SizedBox(width: 8),
                _DetayKart(Icons.people, '${_ogrenciSayisi(_seciliSoforId!)} ogrenci', _navy),
                const SizedBox(width: 8),
                _DetayKart(Icons.check_circle_outline, '${_bindiSayisi(_seciliSoforId!)} bindi', Colors.green),
                if (_seciliSofor!['hiz'] != null) ...[
                  const SizedBox(width: 8),
                  _DetayKart(Icons.speed, '${(_seciliSofor!['hiz'] as num).toStringAsFixed(0)} km/s', _orange),
                ],
              ]),
              if (_ogrenciSayisi(_seciliSoforId!) > 0) ...[
                const SizedBox(height: 10),
                SizedBox(height: 32, child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _ogrenciler.where((o) => (o['surucuId'] ?? '') == _seciliSoforId).map((ogr) {
                    final bindi = ogr['bindi'] ?? false;
                    return Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: bindi ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: bindi ? Colors.green : Colors.orange),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(bindi ? Icons.check : Icons.hourglass_empty,
                            size: 10, color: bindi ? Colors.green : Colors.orange),
                        const SizedBox(width: 3),
                        Text(ogr['ad'] ?? '', style: TextStyle(
                            fontSize: 10, color: bindi ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.w600)),
                      ]),
                    );
                  }).toList(),
                )),
              ],
            ]),
          ),
      ])),
    ]);
  }


  void _projeAta(BuildContext ctx, String soforId, Map<String, dynamic> sofor) {
    String? secProjeId = (sofor['projeId'] ?? '').toString().isNotEmpty ? sofor['projeId'] as String : null;
    Navigator.pop(ctx);
    showDialog(context: context, builder: (_) => StatefulBuilder(
        builder: (dCtx, setS) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Projeye Ata', style: TextStyle(color: Color(0xFF1a3a6b), fontWeight: FontWeight.bold)),
            content: SizedBox(width: 340, child: FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance.collection('projects')
                    .where('firmaId', isEqualTo: _firmaId).where('aktif', isEqualTo: true).get(),
                builder: (_, snap) {
                  final projeler = snap.data?.docs ?? [];
                  return SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    ...projeler.map((p) {
                      final d = p.data() as Map<String, dynamic>;
                      final secili = secProjeId == p.id;
                      return GestureDetector(
                          onTap: () => setS(() => secProjeId = p.id),
                          child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                  color: secili ? const Color(0xFF1a3a6b).withValues(alpha: 0.08) : Colors.grey[50],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: secili ? const Color(0xFF1a3a6b) : Colors.grey.shade200)),
                              child: Row(children: [
                                Icon(Icons.folder_outlined, color: secili ? const Color(0xFF1a3a6b) : Colors.grey, size: 16),
                                const SizedBox(width: 10),
                                Expanded(child: Text(d['projeAd'] ?? d['ad'] ?? '', style: TextStyle(
                                    fontWeight: secili ? FontWeight.bold : FontWeight.normal))),
                                if (secili) const Icon(Icons.check_circle, color: Color(0xFF1a3a6b), size: 16),
                              ])));
                    }),
                  ]));
                })),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Iptal')),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1a3a6b), foregroundColor: Colors.white),
                  onPressed: () async {
                    if (secProjeId == null) return;
                    await FirebaseFirestore.instance.collection('drivers').doc(soforId)
                        .update({'projeId': secProjeId, 'durum': 'projeye_dahil'});
                    if (dCtx.mounted) Navigator.pop(dCtx);
                    _yukle();
                  },
                  child: const Text('Ata')),
            ])));
  }
}



class _LegendItem extends StatelessWidget {
  final Color renk;
  final String metin;
  const _LegendItem(this.renk, this.metin);

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 8, height: 8,
        decoration: BoxDecoration(color: renk, shape: BoxShape.circle)),
    const SizedBox(width: 3),
    Text(metin, style: const TextStyle(fontSize: 9, color: Colors.grey)),
  ]);
}

class _HaritaBtn extends StatelessWidget {
  final IconData icon; final String tooltip; final VoidCallback onTap;
  const _HaritaBtn({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: Container(width: 36, height: 36,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6)]),
          child: Icon(icon, color: const Color(0xFF1a3a6b), size: 18)),
    ),
  );
}

class _OzetChip extends StatelessWidget {
  final String deger, etiket; final Color renk;
  const _OzetChip(this.deger, this.etiket, this.renk);

  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 5),
    decoration: BoxDecoration(color: renk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
    child: Column(children: [
      Text(deger, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: renk)),
      Text(etiket, style: TextStyle(fontSize: 9, color: renk)),
    ]),
  ));
}

class _DetayKart extends StatelessWidget {
  final IconData ikon; final String metin; final Color renk;
  const _DetayKart(this.ikon, this.metin, this.renk);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: renk.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(ikon, size: 12, color: renk), const SizedBox(width: 4),
      Text(metin, style: TextStyle(fontSize: 11, color: renk, fontWeight: FontWeight.w600)),
    ]),
  );



}
