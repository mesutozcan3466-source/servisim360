import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math' as math;
import '../services/session_service.dart';

class WebHarita extends StatefulWidget {
  const WebHarita({super.key});
  @override
  State<WebHarita> createState() => _WebHaritaState();
}

class _WebHaritaState extends State<WebHarita> {
  static const _navy   = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);

  GoogleMapController? _mapCtrl;
  String _firmaId = '', _projeId = '';

  List<Map<String, dynamic>> _ogrenciler = [];
  List<Map<String, dynamic>> _soforler   = [];
  Set<Marker>   _markers   = {};
  Set<Polyline> _polylines = {};
  bool _yukleniyor = true;
  String? _seciliSoforId;
  bool _rotaGoster = true;
  StreamSubscription? _soforSub;

  static const List<Color> _renkler = [
    Color(0xFF2196F3), Color(0xFF4CAF50), Color(0xFFE91E63),
    Color(0xFF9C27B0), Color(0xFFFF9800), Color(0xFF00BCD4),
    Color(0xFFFF5722), Color(0xFF795548),
  ];

  @override
  void initState() { super.initState(); _yukle(); }

  @override
  void dispose() { _soforSub?.cancel(); _mapCtrl?.dispose(); super.dispose(); }

  Future<void> _yukle() async {
    _firmaId = await SessionService.instance.firmaIdAl() ?? '';
    _projeId = SessionService.instance.aktifProjeld ?? '';
    if (_firmaId.isEmpty) { setState(() => _yukleniyor = false); return; }
    try {
      var q = FirebaseFirestore.instance.collection('students')
          .where('firmaId', isEqualTo: _firmaId);
      if (_projeId.isNotEmpty) q = q.where('projeId', isEqualTo: _projeId);
      final snap = await q.get();
      _ogrenciler = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (_) {}
    _soforSub = FirebaseFirestore.instance.collection('drivers')
        .where('firmaId', isEqualTo: _firmaId)
        .snapshots().listen((snap) {
      _soforler = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      if (mounted) _haritaOlustur();
    });
    if (mounted) { setState(() => _yukleniyor = false); _haritaOlustur(); }
  }

  void _haritaOlustur() {
    final Set<Marker> yeniM = {};
    final Set<Polyline> yeniP = {};

    for (int i = 0; i < _soforler.length; i++) {
      final s = _soforler[i];
      if (_seciliSoforId != null && s['id'] != _seciliSoforId) continue;
      final renk = _renkler[i % _renkler.length];
      final k = _konumAl(s);
      if (k != null) {
        yeniM.add(Marker(
          markerId: MarkerId('s_${s['id']}'),
          position: k,
          icon: BitmapDescriptor.defaultMarkerWithHue(_colorToHue(renk)),
          infoWindow: InfoWindow(
            title: s['ad'] ?? 'Sofor',
            snippet: '${s['aracPlaka'] ?? ''} • ${_ogrenciler.where((o) => (o['surucuId'] ?? '') == s['id']).length} ogr',
          ),
        ));
      }
      if (_rotaGoster) {
        final noktalar = (s['rotaNoktalar'] as List?)?.map((p) {
          if (p is GeoPoint) return LatLng(p.latitude, p.longitude);
          if (p is Map) return LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble());
          return null;
        }).whereType<LatLng>().toList() ?? [];
        if (noktalar.length > 1) yeniP.add(Polyline(
          polylineId: PolylineId('r_${s['id']}'),
          points: noktalar, color: renk, width: 3,
        ));
      }
    }

    for (final ogr in _ogrenciler) {
      if (_seciliSoforId != null && (ogr['surucuId'] ?? '') != _seciliSoforId) continue;
      final k = _konumAl(ogr);
      if (k == null) continue;
      final sid = (ogr['surucuId'] ?? '').toString();
      final idx = _soforler.indexWhere((s) => s['id'] == sid);
      final renk = idx >= 0 ? _renkler[idx % _renkler.length] : Colors.red;
      yeniM.add(Marker(
        markerId: MarkerId('o_${ogr['id']}'),
        position: k,
        icon: BitmapDescriptor.defaultMarkerWithHue(
            sid.isEmpty ? BitmapDescriptor.hueRed : _colorToHue(renk)),
        infoWindow: InfoWindow(
          title: ogr['ad'] ?? 'Ogrenci',
          snippet: sid.isEmpty ? 'Atanmamis' : _soforlerden(sid),
        ),
      ));
    }

    if (mounted) setState(() { _markers = yeniM; _polylines = yeniP; });
  }

  LatLng? _konumAl(Map<String, dynamic> d) {
    final k = d['konum'];
    if (k is GeoPoint) return LatLng(k.latitude, k.longitude);
    final lat = (d['lat'] ?? d['latitude']) as double?;
    final lng = (d['lng'] ?? d['longitude']) as double?;
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

  String _soforlerden(String id) {
    final s = _soforler.firstWhere((s) => s['id'] == id, orElse: () => {});
    return s.isNotEmpty ? s['ad'] ?? 'Sofor' : 'Sofor';
  }

  @override
  Widget build(BuildContext context) {
    return _yukleniyor
        ? const Center(child: CircularProgressIndicator(color: _navy))
        : Stack(children: [
      GoogleMap(
        initialCameraPosition: const CameraPosition(target: LatLng(39.9334, 32.8597), zoom: 11),
        markers: _markers, polylines: _polylines,
        onMapCreated: (c) { _mapCtrl = c; },
        myLocationEnabled: true, myLocationButtonEnabled: false,
        zoomControlsEnabled: true, mapToolbarEnabled: false,
      ),

      // Üst kontroller
      Positioned(top: 16, left: 16, right: 16, child: Row(children: [
        // Şoför filtresi
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)]),
          child: DropdownButtonHideUnderline(child: DropdownButton<String?>(
            value: _seciliSoforId,
            hint: const Text('Tum Servisler', style: TextStyle(fontSize: 13)),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Tum Servisler')),
              ..._soforler.map((s) => DropdownMenuItem<String?>(
                value: s['id'] as String,
                child: Row(children: [
                  Container(width: 10, height: 10, margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                          color: _renkler[_soforler.indexOf(s) % _renkler.length],
                          shape: BoxShape.circle)),
                  Text(s['ad'] ?? 'Sofor', style: const TextStyle(fontSize: 13)),
                ]),
              )),
            ],
            onChanged: (v) { setState(() => _seciliSoforId = v); _haritaOlustur(); },
          )),
        ),
        const SizedBox(width: 10),
        // Rota toggle
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _ToggleBtn('Rota', Icons.route_outlined, _rotaGoster, () {
              setState(() => _rotaGoster = !_rotaGoster); _haritaOlustur();
            }),
          ]),
        ),
        const SizedBox(width: 10),
        // Gruplama butonu
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: _orange, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          icon: const Icon(Icons.add_road_outlined, size: 16),
          label: const Text('Rota Olustur', style: TextStyle(fontSize: 12)),
          onPressed: () => Navigator.pushNamed(context, '/gruplama'),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: _navy, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          icon: const Icon(Icons.location_on_outlined, size: 16),
          label: const Text('Bolge Ata', style: TextStyle(fontSize: 12)),
          onPressed: () => Navigator.pushNamed(context, '/bolge_atama'),
        ),
      ])),

      // Legend
      Positioned(bottom: 24, left: 16, child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _LegItem(Colors.red, 'Atanmamis (${_ogrenciler.where((o) => (o['surucuId'] ?? '').toString().isEmpty).length})'),
          ..._soforler.asMap().entries.take(6).map((e) {
            final sayi = _ogrenciler.where((o) => (o['surucuId'] ?? '') == e.value['id']).length;
            return _LegItem(_renkler[e.key % _renkler.length],
                '${e.value['ad'] ?? 'S${e.key+1}'} ($sayi)');
          }),
        ]),
      )),
    ]);
  }
}

class _ToggleBtn extends StatelessWidget {
  final String label; final IconData ikon; final bool aktif; final VoidCallback onTap;
  const _ToggleBtn(this.label, this.ikon, this.aktif, this.onTap);
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap,
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Icon(ikon, size: 16, color: aktif ? const Color(0xFF1a3a6b) : Colors.grey),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 12,
            color: aktif ? const Color(0xFF1a3a6b) : Colors.grey,
            fontWeight: aktif ? FontWeight.bold : FontWeight.normal)),
      ]),
    ),
  );
}

class _LegItem extends StatelessWidget {
  final Color renk; final String etiket;
  const _LegItem(this.renk, this.etiket);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10,
          decoration: BoxDecoration(color: renk, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(etiket, style: const TextStyle(fontSize: 11)),
    ]),
  );
}
