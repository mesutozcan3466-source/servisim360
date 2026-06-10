import 'package:flutter/material.dart';
import 'yardim_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;
import '../services/session_service.dart';

// ════════════════════════════════════════════════════════════════
//  SERVİS BÖLME EKRANI
//
//  MANTIK:
//  1. Haritada öğrenciler görünür — renk = hangi servise atandığı
//  2. "Servis Böl" modu: Admin bir bölge seçer (çember veya tek tek)
//  3. Seçilen öğrenciler 2. servise (yeni veya mevcut şoföre) atanır
//  4. Sistem kontrol eder: 2 servis aynı sokakta çakışıyor mu?
//     Çakışma varsa uyarı verir, admin düzeltebilir
//  5. Her şoförün rotası coğrafi olarak birbirinden ayrı kalır
//
//  ÇAKIŞMA KONTROLÜ:
//  - Her şoförün öğrencilerinin merkezi (centroid) hesaplanır
//  - İki şoförün öğrencileri birbirine 300m'den yakınsa uyarı
//  - Admin "yine de kaydet" veya "düzelt" seçer
// ════════════════════════════════════════════════════════════════
class ServisBolmeScreen extends StatefulWidget {
  const ServisBolmeScreen({super.key});
  @override
  State<ServisBolmeScreen> createState() => _ServisBolmeScreenState();
}

class _ServisBolmeScreenState extends State<ServisBolmeScreen>
    with SingleTickerProviderStateMixin {
  static const _navy   = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);

  late TabController _tab;
  GoogleMapController? _mapCtrl;

  String _firmaId = '';
  String _projeId = '';
  List<Map<String, dynamic>> _ogrenciler = [];
  List<Map<String, dynamic>> _soforler   = [];
  bool   _yukleniyor = true;

  // Harita
  Set<Marker> _markers  = {};
  Set<Circle> _circles  = {};
  Set<Polygon> _polygons = {};

  // Seçim modu
  bool   _secimModu   = false;
  double _yaricap     = 800; // metre
  LatLng? _merkez;
  List<String> _secilenIds = [];

  // Renk paleti — her şoföre sabit renk
  static const List<Color> _renkler = [
    Color(0xFF2196F3), // Mavi   — 1. servis
    Color(0xFF4CAF50), // Yeşil  — 2. servis
    Color(0xFFE91E63), // Pembe  — 3. servis
    Color(0xFF9C27B0), // Mor    — 4. servis
    Color(0xFFFF9800), // Turuncu— 5. servis
    Color(0xFF00BCD4), // Cyan   — 6. servis
    Color(0xFFFF5722), // Kızıl  — 7. servis
    Color(0xFF795548), // Kahve  — 8. servis
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _yukle();
  }

  @override
  void dispose() { _tab.dispose(); _mapCtrl?.dispose(); super.dispose(); }

  // ── VERİ YÜKLE ──────────────────────────────────────────────────
  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    _firmaId = await SessionService.instance.firmaIdAl() ?? '';
    _projeId = SessionService.instance.aktifProjeId ?? '';
    try {
      final sSnap = await FirebaseFirestore.instance
          .collection('drivers').where('firmaId', isEqualTo: _firmaId).get();
      _soforler = sSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      var q = FirebaseFirestore.instance.collection('students')
          .where('firmaId', isEqualTo: _firmaId);
      if (_projeId.isNotEmpty) q = q.where('projeId', isEqualTo: _projeId);
      final oSnap = await q.get();
      _ogrenciler = oSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      _haritaOlustur();
    } catch (e) { debugPrint('ServisBolme hata: $e'); }
    if (mounted) setState(() => _yukleniyor = false);
  }

  // ── HARİTA OLUŞTUR ──────────────────────────────────────────────
  void _haritaOlustur() {
    final Set<Marker> yeni = {};
    final Map<String, int> soforIndex = {};
    for (int i = 0; i < _soforler.length; i++) {
      soforIndex[_soforler[i]['id'] as String] = i;
    }

    for (final ogr in _ogrenciler) {
      final konum = _konumAl(ogr);
      if (konum == null) continue;
      final surucuId = (ogr['surucuId'] ?? ogr['soforId'] ?? '').toString();
      final secili   = _secilenIds.contains(ogr['id'] as String);
      final idx      = soforIndex[surucuId];
      final renk     = idx != null ? _renkler[idx % _renkler.length] : Colors.red;
      final hue      = secili ? BitmapDescriptor.hueYellow : _colorToHue(renk);

      yeni.add(Marker(
        markerId: MarkerId('o_${ogr['id']}'),
        position: konum,
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        infoWindow: InfoWindow(
          title: ogr['ad'] ?? 'Ogrenci',
          snippet: surucuId.isNotEmpty ? _soforAd(surucuId) : 'Atanmamis',
        ),
        onTap: () => _markerTap(ogr),
      ));
    }

    // Çember (seçim modu)
    final Set<Circle> yeniCircle = {};
    if (_merkez != null && _secimModu) {
      yeniCircle.add(Circle(
        circleId: const CircleId('secim'),
        center: _merkez!,
        radius: _yaricap,
        fillColor: _orange.withValues(alpha: 0.12),
        strokeColor: _orange,
        strokeWidth: 2,
      ));
    }

    if (mounted) setState(() { _markers = yeni; _circles = yeniCircle; });
  }

  LatLng? _konumAl(Map<String, dynamic> ogr) {
    final k = ogr['konum'];
    if (k is GeoPoint) return LatLng(k.latitude, k.longitude);
    if (k is Map) {
      final lat = (k['lat'] ?? k['latitude'])  as double?;
      final lng = (k['lng'] ?? k['longitude']) as double?;
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    final lat = (ogr['lat'] ?? ogr['latitude'])  as double?;
    final lng = (ogr['lng'] ?? ogr['longitude']) as double?;
    if (lat != null && lng != null) return LatLng(lat, lng);
    return null;
  }

  String _soforAd(String surucuId) {
    final s = _soforler.firstWhere(
            (s) => s['id'] == surucuId, orElse: () => {});
    return s.isNotEmpty ? '${s['ad'] ?? ''} (${s['aracPlaka'] ?? ''})' : 'Sofor';
  }

  double _colorToHue(Color c) {
    final r = c.red / 255.0, g = c.green / 255.0, b = c.blue / 255.0;
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

  // ── HARİTA TAP — çember çiz ve içindekileri seç ─────────────────
  void _haritaTap(LatLng konum) {
    if (!_secimModu) return;
    setState(() => _merkez = konum);
    _cerberIcindekilerSec(konum);
    _haritaOlustur();
  }

  void _cerberIcindekilerSec(LatLng m) {
    final yeni = <String>[];
    for (final ogr in _ogrenciler) {
      final k = _konumAl(ogr);
      if (k == null) continue;
      if (_mesafe(m, k) <= _yaricap) yeni.add(ogr['id'] as String);
    }
    setState(() => _secilenIds = yeni);
  }

  double _mesafe(LatLng a, LatLng b) {
    const R = 6371000.0;
    final dLat = (b.latitude  - a.latitude)  * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final x = math.sin(dLat/2)*math.sin(dLat/2) +
        math.cos(a.latitude*math.pi/180)*math.cos(b.latitude*math.pi/180)*
            math.sin(dLng/2)*math.sin(dLng/2);
    return R * 2 * math.atan2(math.sqrt(x), math.sqrt(1-x));
  }

  void _markerTap(Map<String, dynamic> ogr) {
    if (_secimModu) {
      final id = ogr['id'] as String;
      setState(() {
        _secilenIds.contains(id) ? _secilenIds.remove(id) : _secilenIds.add(id);
      });
      _haritaOlustur();
    } else {
      _tekliAtamaAc(ogr);
    }
  }

  // ── ÇAKIŞMA KONTROLÜ ───────────────────────────────────────────
  // İki şoförün öğrencileri arasında coğrafi örtüşme var mı?
  List<_CakismaUyari> _cakismaKontrol() {
    final List<_CakismaUyari> uyarilar = [];
    // Her şoförün öğrencilerinin centroid'ini hesapla
    final Map<String, List<LatLng>> soforKonumlar = {};
    for (final ogr in _ogrenciler) {
      final surucuId = (ogr['surucuId'] ?? ogr['soforId'] ?? '').toString();
      if (surucuId.isEmpty) continue;
      final k = _konumAl(ogr);
      if (k == null) continue;
      soforKonumlar.putIfAbsent(surucuId, () => []).add(k);
    }

    final soforIds = soforKonumlar.keys.toList();
    for (int i = 0; i < soforIds.length; i++) {
      for (int j = i+1; j < soforIds.length; j++) {
        final aId = soforIds[i];
        final bId = soforIds[j];
        final aKonumlar = soforKonumlar[aId]!;
        final bKonumlar = soforKonumlar[bId]!;

        // Her A öğrencisi ile her B öğrencisi arasındaki min mesafeyi bul
        int cakisan = 0;
        for (final ak in aKonumlar) {
          for (final bk in bKonumlar) {
            if (_mesafe(ak, bk) < 200) cakisan++; // 200m içinde = çakışma
          }
        }

        if (cakisan > 0) {
          uyarilar.add(_CakismaUyari(
            sofor1Id: aId, sofor1Ad: _soforAd(aId),
            sofor2Id: bId, sofor2Ad: _soforAd(bId),
            cakisanSayi: cakisan,
          ));
        }
      }
    }
    return uyarilar;
  }

  // ── TOPLU ATA ───────────────────────────────────────────────────
  Future<void> _topluAta(String surucuId) async {
    if (_secilenIds.isEmpty) return;

    // Atamadan önce çakışma kontrolü
    // Geçici olarak seçilenleri bu şoföre ata ve kontrol et
    final Map<String, String> gecici = {};
    for (final ogr in _ogrenciler) {
      final surId = (ogr['surucuId'] ?? ogr['soforId'] ?? '').toString();
      gecici[ogr['id'] as String] = surId;
    }
    for (final id in _secilenIds) { gecici[id] = surucuId; }

    // Çakışma var mı kontrol et
    final cakismalar = _cakismaKontrolGecici(gecici);
    if (cakismalar.isNotEmpty) {
      final devam = await _cakismaDialogGoster(cakismalar, surucuId);
      if (!devam) return;
    }

    // Firestore batch write
    final batch = FirebaseFirestore.instance.batch();
    for (final id in _secilenIds) {
      batch.update(
          FirebaseFirestore.instance.collection('students').doc(id),
          {'surucuId': surucuId, 'soforId': surucuId});
    }
    await batch.commit();
    _snack('${_secilenIds.length} ogrenci atandi!', Colors.green);
    setState(() { _secilenIds = []; _merkez = null; _secimModu = false; });
    _yukle();
  }

  List<_CakismaUyari> _cakismaKontrolGecici(Map<String, String> gecici) {
    final Map<String, List<LatLng>> soforKonumlar = {};
    for (final ogr in _ogrenciler) {
      final surucuId = gecici[ogr['id'] as String] ?? '';
      if (surucuId.isEmpty) continue;
      final k = _konumAl(ogr);
      if (k == null) continue;
      soforKonumlar.putIfAbsent(surucuId, () => []).add(k);
    }

    final List<_CakismaUyari> uyarilar = [];
    final soforIds = soforKonumlar.keys.toList();
    for (int i = 0; i < soforIds.length; i++) {
      for (int j = i+1; j < soforIds.length; j++) {
        int cakisan = 0;
        for (final ak in soforKonumlar[soforIds[i]]!) {
          for (final bk in soforKonumlar[soforIds[j]]!) {
            if (_mesafe(ak, bk) < 200) cakisan++;
          }
        }
        if (cakisan > 0) {
          uyarilar.add(_CakismaUyari(
            sofor1Id: soforIds[i], sofor1Ad: _soforAd(soforIds[i]),
            sofor2Id: soforIds[j], sofor2Ad: _soforAd(soforIds[j]),
            cakisanSayi: cakisan,
          ));
        }
      }
    }
    return uyarilar;
  }

  Future<bool> _cakismaDialogGoster(
      List<_CakismaUyari> cakismalar, String hedefSoforId) async {
    return await showDialog<bool>(
      context: context, barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: const [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 22),
          SizedBox(width: 8),
          Text('Rota Cakismasi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${cakismalar.length} cakisma tespit edildi:',
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 10),
            ...cakismalar.map((c) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${c.sofor1Ad}  ↔  ${c.sofor2Ad}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text('${c.cakisanSayi} ogrenci 200m icinde',
                    style: TextStyle(color: Colors.orange[700], fontSize: 11)),
              ]),
            )),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8)),
              child: const Text(
                'Cakisan noktalarda iki servis arayi da ayni sokaga girecek.\n'
                    '"Yine de Ata" secerseniz sonra duzeltebilirsiniz.',
                style: TextStyle(fontSize: 11, color: Colors.blueGrey),
              ),
            ),
          ],
        ),
        actions: [
          YardimButonu(ekranAdi: 'Rotalar'),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Iptal — Duzelt', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _navy),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yine de Ata', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;
  }

  // Tekli atama sheet (marker tap)
  void _tekliAtamaAc(Map<String, dynamic> ogr) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => _TekliAtamaSheet(
          ogr: ogr, soforler: _soforler,
          renkler: _renkler, onKayit: _yukle),
    );
  }

  void _snack(String msg, Color c) =>
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: c,
              behavior: SnackBarBehavior.floating));

  // ── BUILD ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cakismalar = _yukleniyor ? <_CakismaUyari>[] : _cakismaKontrol();
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white, elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Servis Bolme', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          Text('${_ogrenciler.length} ogr · ${_soforler.length} servis',
              style: const TextStyle(fontSize: 10, color: Colors.white60)),
        ]),
        actions: [
          if (cakismalar.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 4),
              child: IconButton(
                icon: Stack(children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  Positioned(right: 0, top: 0, child: Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  )),
                ]),
                tooltip: '${cakismalar.length} rota cakismasi',
                onPressed: () => _cakismaListesiGoster(cakismalar),
              ),
            ),
          if (_secilenIds.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(14)),
              child: Text('${_secilenIds.length} secili',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _yukle),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: _orange,
          labelColor: Colors.white, unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.map_outlined, size: 17), text: 'Harita'),
            Tab(icon: Icon(Icons.directions_bus_outlined, size: 17), text: 'Servisler'),
            Tab(icon: Icon(Icons.list_alt_outlined, size: 17), text: 'Ogrenciler'),
          ],
        ),
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator(color: _navy))
          : TabBarView(controller: _tab, children: [
        _haritaTab(),
        _servislerTab(),
        _ogrencilerTab(),
      ]),
    );
  }

  // ════ TAB 1: HARİTA ════════════════════════════════════════════
  Widget _haritaTab() {
    LatLng merkez = const LatLng(39.9334, 32.8597);
    for (final ogr in _ogrenciler) {
      final k = _konumAl(ogr); if (k != null) { merkez = k; break; }
    }

    return Stack(children: [
      GoogleMap(
        initialCameraPosition: CameraPosition(target: merkez, zoom: 13),
        markers:  _markers,
        circles:  _circles,
        polygons: _polygons,
        onMapCreated: (c) {
          _mapCtrl = c;
          if (_markers.isNotEmpty) {
            Future.delayed(const Duration(milliseconds: 500), () =>
                _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(merkez, 13)));
          }
        },
        onTap: _haritaTap,
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
      ),

      // ── ÜST PANEL ──
      Positioned(top: 8, left: 8, right: 8,
        child: Column(children: [
          // Seçim modu kontrol
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6)]),
            child: Column(children: [
              Row(children: [
                Icon(_secimModu ? Icons.touch_app : Icons.pan_tool_alt_outlined,
                    color: _secimModu ? _orange : Colors.grey, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  _secimModu
                      ? 'Haritaya bas → cember ciz ve sec'
                      : 'Noktaya dokun → tek atama',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                )),
                Switch(value: _secimModu, activeColor: _orange,
                    onChanged: (v) => setState(() {
                      _secimModu = v;
                      if (!v) { _secilenIds = []; _merkez = null; _haritaOlustur(); }
                    })),
              ]),
              if (_secimModu) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.radio_button_checked, color: _orange, size: 14),
                  const SizedBox(width: 6),
                  Text('Yari cap: ${(_yaricap/1000).toStringAsFixed(1)} km',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _orange)),
                  Expanded(child: Slider(
                    value: _yaricap, min: 200, max: 3000, activeColor: _orange,
                    onChanged: (v) {
                      setState(() => _yaricap = v);
                      if (_merkez != null) { _cerberIcindekilerSec(_merkez!); _haritaOlustur(); }
                    },
                  )),
                ]),
              ],
            ]),
          ),

          // Seçilenler → Şoföre ata paneli
          if (_secilenIds.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6)]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.people_outline, color: _navy, size: 16),
                  const SizedBox(width: 6),
                  Text('${_secilenIds.length} ogrenci secildi',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _navy)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() { _secilenIds = []; _haritaOlustur(); }),
                    child: const Icon(Icons.clear, size: 16, color: Colors.red),
                  ),
                ]),
                const SizedBox(height: 6),
                const Text('Hangi servise ata:',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    ..._soforler.asMap().entries.map((e) {
                      final renk = _renkler[e.key % _renkler.length];
                      final s    = e.value;
                      final atananSayi = _ogrenciler.where((o) =>
                      (o['surucuId'] ?? o['soforId'] ?? '') == s['id']).length;
                      return GestureDetector(
                        onTap: () => _topluAta(s['id'] as String),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(10)),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(s['ad'] ?? 'Sofor',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            Text('${s['aracPlaka'] ?? ''}  •  $atananSayi kisi',
                                style: const TextStyle(color: Colors.white70, fontSize: 9)),
                          ]),
                        ),
                      );
                    }),
                    // + Yeni servis aç
                    GestureDetector(
                      onTap: _yeniServisAc,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid)),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.add_circle_outline, color: _navy, size: 18),
                          const Text('Yeni Servis', style: TextStyle(color: _navy, fontSize: 9, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ],
        ]),
      ),

      // Legend
      Positioned(bottom: 16, left: 10,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6)]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _LegItem(Colors.red, 'Atanmamis'),
            _LegItem(_orange, 'Secili'),
            ..._soforler.asMap().entries.take(5).map((e) =>
                _LegItem(_renkler[e.key % _renkler.length], e.value['ad'] ?? 'Servis ${e.key+1}')),
          ]),
        ),
      ),

      // Zoom butonları
      Positioned(bottom: 80, right: 12, child: Column(children: [
        _ZoomBtn(Icons.add,    () => _mapCtrl?.animateCamera(CameraUpdate.zoomIn())),
        const SizedBox(height: 6),
        _ZoomBtn(Icons.remove, () => _mapCtrl?.animateCamera(CameraUpdate.zoomOut())),
      ])),
    ]);
  }

  // ── Yeni servis (2. araç) aç ────────────────────────────────────
  void _yeniServisAc() {
    showDialog(
      context: context,
      builder: (_) => _YeniServisDialog(
        firmaId: _firmaId,
        projeId: _projeId,
        secilenIds: List.from(_secilenIds),
        onKayit: () {
          setState(() { _secilenIds = []; _secimModu = false; });
          _yukle();
        },
      ),
    );
  }

  // ════ TAB 2: SERVİSLER ═════════════════════════════════════════
  Widget _servislerTab() {
    final cakismalar = _cakismaKontrol();
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Çakışma uyarıları
        if (cakismalar.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                const SizedBox(width: 8),
                Text('${cakismalar.length} Rota Cakismasi',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 13)),
              ]),
              const SizedBox(height: 8),
              ...cakismalar.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  const Icon(Icons.sync_problem_outlined, size: 14, color: Colors.orange),
                  const SizedBox(width: 6),
                  Expanded(child: Text('${c.sofor1Ad}  ↔  ${c.sofor2Ad}  (${c.cakisanSayi} nokta)',
                      style: const TextStyle(fontSize: 11))),
                ]),
              )),
              const SizedBox(height: 6),
              const Text(
                'Bu servislerin guzergahlari birbirine 200m den yakin. '
                    'Ogrencileri yeniden bolmek icin Harita sekmesini kullanin.',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ]),
          ),
        ],

        // Servisler
        ..._soforler.asMap().entries.map((e) {
          final idx   = e.key;
          final s     = e.value;
          final renk  = _renkler[idx % _renkler.length];
          final atananlar = _ogrenciler.where((o) =>
          (o['surucuId'] ?? o['soforId'] ?? '') == s['id']).toList();
          final kapasite  = (s['kapasite'] as num?)?.toInt() ?? 16;
          final doluluk   = kapasite > 0 ? atananlar.length / kapasite : 0.0;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: renk.withValues(alpha: 0.3)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
            ),
            child: Column(children: [
              // Başlık
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: renk.withValues(alpha: 0.08),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14))),
                child: Row(children: [
                  Container(width: 14, height: 14, decoration: BoxDecoration(color: renk, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s['ad'] ?? 'Sofor', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('${s['aracPlaka'] ?? ''}  •  ${atananlar.length}/$kapasite kisi',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    if ((s['projeAd'] ?? '').isNotEmpty)
                      Text(s['projeAd'], style: const TextStyle(fontSize: 10, color: Colors.blue)),
                    if ((s['sabahServisSaati'] ?? s['morningStartTime'] ?? '').isNotEmpty)
                      Text('Sabah: ${s['sabahServisSaati'] ?? s['morningStartTime']}  Akşam: ${s['aksamServisSaati'] ?? s['eveningStartTime'] ?? '-'}',
                          style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                  ])),
                  // Üç nokta menüsü
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_outlined, color: Colors.grey, size: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'duzenle',
                          child: Row(children: [Icon(Icons.edit_outlined, size: 16), SizedBox(width: 8), Text('Düzenle', style: TextStyle(fontSize: 13))])),
                      const PopupMenuItem(value: 'proje_ata',
                          child: Row(children: [Icon(Icons.folder_outlined, size: 16), SizedBox(width: 8), Text('Projeye Ata', style: TextStyle(fontSize: 13))])),
                      const PopupMenuItem(value: 'sofor_degistir',
                          child: Row(children: [Icon(Icons.swap_horiz_outlined, size: 16), SizedBox(width: 8), Text('Şoförü Değiştir', style: TextStyle(fontSize: 13))])),
                      PopupMenuItem(value: s['aktif'] == false ? 'aktif' : 'pasif',
                          child: Row(children: [
                            Icon(s['aktif'] == false ? Icons.play_circle_outline : Icons.pause_circle_outline, size: 16),
                            const SizedBox(width: 8),
                            Text(s['aktif'] == false ? 'Aktife Al' : 'Pasife Al', style: const TextStyle(fontSize: 13)),
                          ])),
                      const PopupMenuItem(value: 'sil',
                          child: Row(children: [Icon(Icons.delete_outline, size: 16, color: Colors.red), SizedBox(width: 8), Text('Sil', style: TextStyle(fontSize: 13, color: Colors.red))])),
                    ],
                    onSelected: (val) => _servisMenuIslem(s, val),
                  ),
                  // Doluluk çubuğu
                  SizedBox(width: 60, child: Column(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
                      value: doluluk.clamp(0.0, 1.0),
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                          doluluk > 0.9 ? Colors.red : doluluk > 0.7 ? Colors.orange : Colors.green),
                      minHeight: 6,
                    )),
                    const SizedBox(height: 3),
                    Text('%${(doluluk*100).toInt()}', style: TextStyle(fontSize: 9, color: Colors.grey[500])),
                  ])),
                ]),
              ),

              // Çakışma uyarısı bu servis için
              if (cakismalar.any((c) => c.sofor1Id == s['id'] || c.sofor2Id == s['id']))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: Colors.orange.withValues(alpha: 0.06),
                  child: Row(children: [
                    const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange),
                    const SizedBox(width: 6),
                    Expanded(child: Text('Bu servis baska bir servisle guzergah cakismasi yasiyor',
                        style: const TextStyle(fontSize: 10, color: Colors.orange))),
                  ]),
                ),

              // Öğrenci listesi
              if (atananlar.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Column(children: atananlar.take(5).map((ogr) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(children: [
                      Icon(Icons.person_pin_circle_outlined, size: 13, color: renk),
                      const SizedBox(width: 6),
                      Expanded(child: Text(ogr['ad'] ?? '', style: const TextStyle(fontSize: 12))),
                      Text(ogr['adres'] ?? '', style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                          overflow: TextOverflow.ellipsis),
                    ]),
                  )).toList()),
                ),
              if (atananlar.length > 5)
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 6),
                  child: Text('+${atananlar.length-5} daha...',
                      style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                ),

              // Alt butonlar
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Row(children: [
                  Expanded(child: _AltBtn(Icons.map_outlined, 'Haritada Goster', renk,
                          () { _tab.animateTo(0); _soforHaritaOdakla(s['id'] as String); })),
                  const SizedBox(width: 8),
                  Expanded(child: _AltBtn(Icons.call_split_outlined, 'Bol / Duzenle', _navy,
                          () { _tab.animateTo(0); setState(() => _secimModu = true); })),
                ]),
              ),
            ]),
          );
        }),

        // Yeni servis ekle
        GestureDetector(
          onTap: () => _yeniServisEkleDialog(),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _navy.withValues(alpha: 0.2), style: BorderStyle.solid),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.add_circle_outline, color: _navy),
              SizedBox(width: 10),
              Text('2. Servis / Yeni Sofor Ekle',
                  style: TextStyle(fontWeight: FontWeight.bold, color: _navy)),
            ]),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── Servis Menü İşlemleri ────────────────────────────────────
  void _servisMenuIslem(Map<String, dynamic> s, String islem) {
    switch (islem) {
      case 'duzenle':      _servisDuzenleDialog(s);  break;
      case 'proje_ata':    _servisProjeAtaDialog(s); break;
      case 'sofor_degistir': _soforDegistirDialog(s); break;
      case 'pasif':        _servisDurumDegistir(s, false); break;
      case 'aktif':        _servisDurumDegistir(s, true);  break;
      case 'sil':          _servisSilOnay(s); break;
    }
  }

  Future<void> _servisDurumDegistir(Map<String, dynamic> s, bool aktif) async {
    await FirebaseFirestore.instance.collection('drivers').doc(s['id']).update({
      'aktif': aktif, 'aktifMi': aktif,
    });
    _yukle();
    _snack(aktif ? 'Servis aktife alındı' : 'Servis pasife alındı',
        aktif ? Colors.green : Colors.orange);
  }

  Future<void> _servisSilOnay(Map<String, dynamic> s) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Servisi Sil'),
        content: Text('"${s['ad'] ?? 'Servis'}" silinecek. Bu işlem geri alınamaz.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (onay != true) return;
    await FirebaseFirestore.instance.collection('drivers').doc(s['id']).delete();
    _yukle();
    _snack('Servis silindi', Colors.red);
  }

  void _servisDuzenleDialog(Map<String, dynamic> s) {
    final adCtrl     = TextEditingController(text: s['ad'] ?? '');
    final plakaCtrl  = TextEditingController(text: s['aracPlaka'] ?? s['plaka'] ?? '');
    final sabahCtrl  = TextEditingController(text: s['sabahServisSaati'] ?? s['morningStartTime'] ?? '');
    final aksamCtrl  = TextEditingController(text: s['aksamServisSaati'] ?? s['eveningStartTime'] ?? '');
    final kapCtrl    = TextEditingController(text: s['kapasite']?.toString() ?? '17');
    bool autoStart   = s['autoStartEnabled'] as bool? ?? false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: EdgeInsets.zero,
          content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: _navy,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
              child: Row(children: [
                const Icon(Icons.edit_outlined, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Expanded(child: Text('Servis Düzenle',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                IconButton(icon: const Icon(Icons.close, color: Colors.white54, size: 16),
                    onPressed: () => Navigator.pop(ctx),
                    padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              ]),
            ),
            Padding(padding: const EdgeInsets.all(16), child: Column(children: [
              _duzenleAlan(adCtrl, 'Şoför / Servis Adı', Icons.person_outline),
              const SizedBox(height: 10),
              _duzenleAlan(plakaCtrl, 'Araç Plakası', Icons.airport_shuttle_outlined),
              const SizedBox(height: 10),
              _duzenleAlan(kapCtrl, 'Kapasite', Icons.people_outline,
                  tip: TextInputType.number),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _duzenleAlan(sabahCtrl, 'Sabah Saati',
                    Icons.wb_sunny_outlined, hint: '07:30')),
                const SizedBox(width: 10),
                Expanded(child: _duzenleAlan(aksamCtrl, 'Akşam Saati',
                    Icons.nights_stay_outlined, hint: '16:30')),
              ]),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200)),
                child: Row(children: [
                  const Icon(Icons.auto_mode_outlined, color: _navy, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Otomatik Başlatma',
                      style: TextStyle(fontSize: 13))),
                  Switch(value: autoStart,
                      onChanged: (v) => setD(() => autoStart = v),
                      activeColor: const Color(0xFFFF8C00)),
                ]),
              ),
            ])),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(width: double.infinity, height: 44,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  onPressed: () async {
                    await FirebaseFirestore.instance.collection('drivers')
                        .doc(s['id']).update({
                      'ad'               : adCtrl.text.trim(),
                      'aracPlaka'        : plakaCtrl.text.trim(),
                      'plaka'            : plakaCtrl.text.trim(),
                      'kapasite'         : int.tryParse(kapCtrl.text) ?? 17,
                      'sabahServisSaati' : sabahCtrl.text.trim(),
                      'morningStartTime' : sabahCtrl.text.trim(),
                      'aksamServisSaati' : aksamCtrl.text.trim(),
                      'eveningStartTime' : aksamCtrl.text.trim(),
                      'autoStartEnabled' : autoStart,
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                    _yukle();
                    _snack('Servis güncellendi ✓', Colors.green);
                  },
                  icon: const Icon(Icons.save_outlined, size: 16),
                  label: const Text('Kaydet',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ])),
        ),
      ),
    );
  }

  Widget _duzenleAlan(TextEditingController ctrl, String label, IconData ikon,
      {String? hint, TextInputType? tip}) =>
      TextField(
        controller: ctrl,
        keyboardType: tip,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(ikon, color: _navy, size: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      );

  Future<void> _servisProjeAtaDialog(Map<String, dynamic> s) async {
    String? secilenProjeId = s['projeId'] as String?;
    if (secilenProjeId?.isEmpty ?? true) secilenProjeId = null;

    final projeler = <Map<String, dynamic>>[];
    try {
      final snap = await FirebaseFirestore.instance.collection('projects')
          .where('firmaId', isEqualTo: _firmaId)
          .where('durum', isEqualTo: 'aktif').get();
      projeler.addAll(snap.docs.map((d) => {'id': d.id, ...d.data()}));
    } catch (_) {}

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.folder_outlined, color: _navy),
          SizedBox(width: 8),
          Text('Projeye Ata', style: TextStyle(fontSize: 15)),
        ]),
        content: SizedBox(width: 360, child: Column(mainAxisSize: MainAxisSize.min, children: [
          RadioListTile<String?>(
            value: null, groupValue: secilenProjeId,
            onChanged: (v) => setD(() => secilenProjeId = v),
            title: const Text('Projesiz (Boşta)'),
            activeColor: _navy,
          ),
          ...projeler.map((p) => RadioListTile<String?>(
            value: p['id'] as String,
            groupValue: secilenProjeId,
            onChanged: (v) => setD(() => secilenProjeId = v),
            title: Text(p['projeAd'] as String? ?? 'Proje'),
            activeColor: _navy,
          )),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
            onPressed: () async {
              final projeAd = secilenProjeId != null
                  ? projeler.firstWhere((p) => p['id'] == secilenProjeId,
                  orElse: () => {})['projeAd'] ?? '' : '';
              await FirebaseFirestore.instance.collection('drivers').doc(s['id']).update({
                'projeId' : secilenProjeId ?? '',
                'projeAd' : projeAd,
                'durum'   : secilenProjeId != null ? 'projeye_dahil' : 'bosta',
              });
              if (ctx.mounted) Navigator.pop(ctx);
              _yukle();
              _snack('Proje atandı ✓', Colors.green);
            },
            child: const Text('Kaydet'),
          ),
        ],
      )),
    );
  }

  Future<void> _soforDegistirDialog(Map<String, dynamic> s) async {
    final adCtrl   = TextEditingController(text: s['ad'] ?? '');
    final telCtrl  = TextEditingController(text: s['telefon'] ?? '');
    final kulCtrl  = TextEditingController(text: s['kullaniciAdi'] ?? '');
    final sifCtrl  = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(color: _navy,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
            child: const Row(children: [
              Icon(Icons.swap_horiz_outlined, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Şoförü Değiştir',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ]),
          ),
          Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8)),
              child: const Row(children: [
                Icon(Icons.info_outline, size: 14, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(child: Text(
                    'Mevcut şoförün bilgilerini değiştiriyorsunuz. '
                        'Servis geçmişi ve öğrenciler korunur.',
                    style: TextStyle(fontSize: 11, color: Colors.orange))),
              ]),
            ),
            const SizedBox(height: 12),
            _duzenleAlan(adCtrl, 'Yeni Şoför Adı', Icons.person_outline),
            const SizedBox(height: 10),
            _duzenleAlan(telCtrl, 'Telefon', Icons.phone_outlined,
                tip: TextInputType.phone),
            const SizedBox(height: 10),
            _duzenleAlan(kulCtrl, 'Kullanıcı Adı', Icons.person_pin_outlined),
            const SizedBox(height: 10),
            _duzenleAlan(sifCtrl, 'Yeni Şifre (boş = değiştirme)', Icons.lock_outline),
          ])),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(width: double.infinity, height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: _navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                onPressed: () async {
                  final guncelleme = <String, dynamic>{
                    'ad'          : adCtrl.text.trim(),
                    'telefon'     : telCtrl.text.trim(),
                    'kullaniciAdi': kulCtrl.text.trim(),
                  };
                  if (sifCtrl.text.trim().isNotEmpty) {
                    guncelleme['geciciSifre'] = sifCtrl.text.trim();
                    guncelleme['sifre']       = sifCtrl.text.trim();
                  }
                  await FirebaseFirestore.instance.collection('drivers')
                      .doc(s['id']).update(guncelleme);
                  // kullanicilar koleksiyonunu da güncelle
                  await FirebaseFirestore.instance.collection('kullanicilar')
                      .doc(s['id']).update({
                    'ad'          : adCtrl.text.trim(),
                    'telefon'     : telCtrl.text.trim(),
                    'kullaniciAdi': kulCtrl.text.trim(),
                    if (sifCtrl.text.trim().isNotEmpty) 'sifre': sifCtrl.text.trim(),
                  });
                  if (context.mounted) Navigator.pop(context);
                  _yukle();
                  _snack('Şoför bilgileri güncellendi ✓', Colors.green);
                },
                icon: const Icon(Icons.save_outlined, size: 16),
                label: const Text('Güncelle', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ])),
      ),
    );
  }


  void _soforHaritaOdakla(String surucuId) {
    final ogrenciler = _ogrenciler.where((o) =>
    (o['surucuId'] ?? o['soforId'] ?? '') == surucuId).toList();
    if (ogrenciler.isEmpty) return;
    final k = _konumAl(ogrenciler.first);
    if (k != null) _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(k, 14));
  }

  void _yeniServisEkleDialog() {
    showDialog(context: context,
        builder: (_) => _YeniServisDialog(
            firmaId: _firmaId, projeId: _projeId,
            secilenIds: const [], onKayit: _yukle));
  }

  void _cakismaListesiGoster(List<_CakismaUyari> cakismalar) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const Text('Rota Cakismalari', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _navy)),
          const SizedBox(height: 12),
          ...cakismalar.map((c) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3))),
            child: Row(children: [
              const Icon(Icons.sync_problem_outlined, color: Colors.orange, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${c.sofor1Ad}  ↔  ${c.sofor2Ad}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('${c.cakisanSayi} ogrenci 200m icinde',
                    style: TextStyle(color: Colors.orange[700], fontSize: 11)),
              ])),
            ]),
          )),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: _navy),
            onPressed: () { Navigator.pop(context); _tab.animateTo(0); setState(() => _secimModu = true); },
            icon: const Icon(Icons.edit_location_outlined, size: 16),
            label: const Text('Haritadan Duzenle'),
          )),
        ]),
      ),
    );
  }

  // ════ TAB 3: ÖĞRENCİLER ════════════════════════════════════════
  Widget _ogrencilerTab() {
    final atanmamis = _ogrenciler.where((o) =>
    (o['surucuId'] ?? o['soforId'] ?? '').toString().isEmpty).toList();
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        if (atanmamis.isNotEmpty) ...[
          _GrupBaslikW('Servis Atanmamis', atanmamis.length, Colors.red),
          ...atanmamis.map((o) => _OgrSatiri(o, _soforler, _renkler, _yukle)),
          const SizedBox(height: 12),
        ],
        ..._soforler.asMap().entries.map((e) {
          final renk = _renkler[e.key % _renkler.length];
          final s    = e.value;
          final liste = _ogrenciler.where((o) =>
          (o['surucuId'] ?? o['soforId'] ?? '') == s['id']).toList();
          if (liste.isEmpty) return const SizedBox.shrink();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _GrupBaslikW('${s['ad'] ?? 'Sofor ${e.key+1}'} — ${s['aracPlaka'] ?? ''}',
                liste.length, renk),
            ...liste.map((o) => _OgrSatiri(o, _soforler, _renkler, _yukle)),
            const SizedBox(height: 10),
          ]);
        }),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  YENİ SERVİS DIALOG
// ════════════════════════════════════════════════════════════════
class _YeniServisDialog extends StatefulWidget {
  final String firmaId, projeId;
  final List<String> secilenIds;
  final VoidCallback onKayit;
  const _YeniServisDialog({required this.firmaId, required this.projeId,
    required this.secilenIds, required this.onKayit});
  @override
  State<_YeniServisDialog> createState() => _YeniServisDialogState();
}

class _YeniServisDialogState extends State<_YeniServisDialog> {
  static const _navy = Color(0xFF1a3a6b);
  final _adCtrl    = TextEditingController();
  final _telCtrl   = TextEditingController();
  final _plakaCtrl = TextEditingController();
  final _kapCtrl   = TextEditingController(text: '16');
  bool _kaydediyor = false;

  @override
  void dispose() { _adCtrl.dispose(); _telCtrl.dispose(); _plakaCtrl.dispose(); _kapCtrl.dispose(); super.dispose(); }

  Future<void> _kaydet() async {
    if (_adCtrl.text.trim().isEmpty || _plakaCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ad ve plaka zorunlu!'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _kaydediyor = true);
    try {
      final docRef = await FirebaseFirestore.instance.collection('drivers').add({
        'firmaId':   widget.firmaId,
        'projeId':   widget.projeId,
        'ad':        _adCtrl.text.trim(),
        'telefon':   _telCtrl.text.trim(),
        'aracPlaka': _plakaCtrl.text.trim().toUpperCase(),
        'kapasite':  int.tryParse(_kapCtrl.text.trim()) ?? 16,
        'servisAktif': false,
        'olusturma':   FieldValue.serverTimestamp(),
      });

      // Seçili öğrencileri bu şoföre ata
      if (widget.secilenIds.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final id in widget.secilenIds) {
          batch.update(FirebaseFirestore.instance.collection('students').doc(id),
              {'surucuId': docRef.id, 'soforId': docRef.id});
        }
        await batch.commit();
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onKayit();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(widget.secilenIds.isNotEmpty
                ? 'Yeni servis olusturuldu, ${widget.secilenIds.length} ogrenci atandi!'
                : 'Yeni servis olusturuldu!'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
    } finally { if (mounted) setState(() => _kaydediyor = false); }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: const [
        Icon(Icons.add_circle_outline, color: _navy, size: 20),
        SizedBox(width: 8),
        Expanded(child: Text('Yeni Servis Ekle', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _navy))),
      ]),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (widget.secilenIds.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3))),
            child: Row(children: [
              const Icon(Icons.people_outline, color: Colors.green, size: 16),
              const SizedBox(width: 8),
              Text('${widget.secilenIds.length} ogrenci bu servise atanacak',
                  style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600)),
            ]),
          ),
        _FrmAlan(_adCtrl,    'Sofor Adi *',  Icons.person_outline),
        const SizedBox(height: 8),
        _FrmAlan(_telCtrl,   'Telefon',      Icons.phone_outlined, tip: TextInputType.phone),
        const SizedBox(height: 8),
        _FrmAlan(_plakaCtrl, 'Arac Plakasi *', Icons.directions_bus_outlined),
        const SizedBox(height: 8),
        _FrmAlan(_kapCtrl,   'Kapasite',     Icons.event_seat_outlined, tip: TextInputType.number),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Iptal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _navy),
          onPressed: _kaydediyor ? null : _kaydet,
          child: _kaydediyor
              ? const SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Olustur', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  TEKLİ ATAMA SHEET
// ════════════════════════════════════════════════════════════════
class _TekliAtamaSheet extends StatefulWidget {
  final Map<String, dynamic> ogr;
  final List<Map<String, dynamic>> soforler;
  final List<Color> renkler;
  final VoidCallback onKayit;
  const _TekliAtamaSheet({required this.ogr, required this.soforler,
    required this.renkler, required this.onKayit});
  @override
  State<_TekliAtamaSheet> createState() => _TekliAtamaSheetState();
}

class _TekliAtamaSheetState extends State<_TekliAtamaSheet> {
  static const _navy = Color(0xFF1a3a6b);
  String? _secili;
  bool _kaydediyor = false;

  @override
  void initState() {
    super.initState();
    _secili = (widget.ogr['surucuId'] ?? widget.ogr['soforId'] ?? '')
        .toString().isEmpty ? null
        : (widget.ogr['surucuId'] ?? widget.ogr['soforId'] ?? '') as String?;
  }

  Future<void> _kaydet() async {
    setState(() => _kaydediyor = true);
    await FirebaseFirestore.instance
        .collection('students').doc(widget.ogr['id']).update({
      'surucuId': _secili ?? '',
      'soforId':  _secili ?? '',
    });
    if (mounted) { Navigator.pop(context); widget.onKayit(); }
  }

  @override
  Widget build(BuildContext context) {
    final ad = '${widget.ogr['ad'] ?? ''} ${widget.ogr['soyad'] ?? ''}'.trim();
    return Container(
      padding: EdgeInsets.only(left: 20, right: 20, top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
        Row(children: [
          CircleAvatar(radius: 20, backgroundColor: _navy.withValues(alpha: 0.1),
              child: Text(ad.isNotEmpty ? ad[0].toUpperCase() : '?',
                  style: const TextStyle(color: _navy, fontWeight: FontWeight.bold))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ad.isNotEmpty ? ad : 'Ogrenci',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text(widget.ogr['adres'] ?? '',
                style: TextStyle(color: Colors.grey[500], fontSize: 11),
                overflow: TextOverflow.ellipsis),
          ])),
        ]),
        const SizedBox(height: 14),
        // Şoförler renk butonu listesi
        const Text('Servis Sec:', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          GestureDetector(
            onTap: () => setState(() => _secili = null),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: _secili == null ? Colors.red.withValues(alpha: 0.15) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _secili == null ? Colors.red : Colors.grey.shade200)),
              child: const Text('Kaldir', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
          ...widget.soforler.asMap().entries.map((e) {
            final s    = e.value;
            final renk = widget.renkler[e.key % widget.renkler.length];
            final sec  = _secili == s['id'];
            return GestureDetector(
              onTap: () => setState(() => _secili = s['id'] as String),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: sec ? renk : renk.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: renk.withValues(alpha: 0.5))),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(s['ad'] ?? 'Sofor',
                      style: TextStyle(color: sec ? Colors.white : renk,
                          fontSize: 12, fontWeight: FontWeight.bold)),
                  Text(s['aracPlaka'] ?? '',
                      style: TextStyle(color: sec ? Colors.white70 : renk.withValues(alpha: 0.7), fontSize: 10)),
                ]),
              ),
            );
          }),
        ]),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: _kaydediyor ? null : _kaydet,
          child: _kaydediyor
              ? const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        )),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  YARDIMCI MODEL + WIDGET'LAR
// ════════════════════════════════════════════════════════════════
class _CakismaUyari {
  final String sofor1Id, sofor1Ad, sofor2Id, sofor2Ad;
  final int cakisanSayi;
  const _CakismaUyari({required this.sofor1Id, required this.sofor1Ad,
    required this.sofor2Id, required this.sofor2Ad, required this.cakisanSayi});
}

class _GrupBaslikW extends StatelessWidget {
  final String baslik; final int sayi; final Color renk;
  const _GrupBaslikW(this.baslik, this.sayi, this.renk);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: renk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
    child: Row(children: [
      Icon(Icons.directions_bus_outlined, color: renk, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(baslik, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: renk),
          overflow: TextOverflow.ellipsis)),
      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(12)),
          child: Text('$sayi', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
    ]),
  );
}

class _OgrSatiri extends StatelessWidget {
  final Map<String, dynamic> ogr;
  final List<Map<String, dynamic>> soforler;
  final List<Color> renkler;
  final VoidCallback onGuncelle;
  static const _navy = Color(0xFF1a3a6b);
  const _OgrSatiri(this.ogr, this.soforler, this.renkler, this.onGuncelle);
  @override
  Widget build(BuildContext context) {
    final ad = '${ogr['ad'] ?? ''} ${ogr['soyad'] ?? ''}'.trim();
    return GestureDetector(
      onTap: () => showModalBottomSheet(context: context, backgroundColor: Colors.transparent,
          builder: (_) => _TekliAtamaSheet(ogr: ogr, soforler: soforler,
              renkler: renkler, onKayit: onGuncelle)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]),
        child: Row(children: [
          CircleAvatar(radius: 14, backgroundColor: _navy.withValues(alpha: 0.1),
              child: Text((ad.isNotEmpty ? ad[0] : '?').toUpperCase(),
                  style: const TextStyle(color: _navy, fontWeight: FontWeight.bold, fontSize: 11))),
          const SizedBox(width: 10),
          Expanded(child: Text(ad.isNotEmpty ? ad : 'Isimsiz',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
          Text(ogr['adres'] ?? '', style: TextStyle(fontSize: 10, color: Colors.grey[400]),
              overflow: TextOverflow.ellipsis),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, color: Colors.grey, size: 16),
        ]),
      ),
    );
  }
}

class _LegItem extends StatelessWidget {
  final Color renk; final String etiket;
  const _LegItem(this.renk, this.etiket);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: renk, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(etiket, style: const TextStyle(fontSize: 10)),
    ]),
  );
}

class _ZoomBtn extends StatelessWidget {
  final IconData ikon; final VoidCallback onTap;
  const _ZoomBtn(this.ikon, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
      child: Container(width: 38, height: 38,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)]),
          child: Icon(ikon, color: const Color(0xFF1a3a6b), size: 20)));
}

class _AltBtn extends StatelessWidget {
  final IconData ikon; final String etiket; final Color renk; final VoidCallback onTap;
  const _AltBtn(this.ikon, this.etiket, this.renk, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
      child: Container(padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: renk.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: renk.withValues(alpha: 0.25))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(ikon, size: 14, color: renk),
            const SizedBox(width: 5),
            Text(etiket, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: renk)),
          ])));
}

class _FrmAlan extends StatelessWidget {
  final TextEditingController ctrl;
  final String label; final IconData ikon; final TextInputType tip;
  static const _navy = Color(0xFF1a3a6b);
  const _FrmAlan(this.ctrl, this.label, this.ikon, {this.tip = TextInputType.text});
  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl, keyboardType: tip,
    decoration: InputDecoration(labelText: label,
        prefixIcon: Icon(ikon, color: _navy, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
  );
}
