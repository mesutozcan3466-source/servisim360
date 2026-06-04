import 'package:flutter/material.dart';
import 'yardim_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;
import '../services/session_service.dart';

// ════════════════════════════════════════════════════════════════
//  BÖLGE ATAMA EKRANI — Manuel harita tıklama + şoföre atama
//  Çalışma mantığı:
//  1. Haritada öğrenciler nokta olarak görünür (atanmamışlar kırmızı)
//  2. Admin/Sekreter haritaya tıklayarak bölge çemberi çizer
//  3. Çember içindeki öğrenciler gruplanır
//  4. Gruba şoför atanır
// ════════════════════════════════════════════════════════════════
class BolgeAtamaScreen extends StatefulWidget {
  const BolgeAtamaScreen({super.key});
  @override
  State<BolgeAtamaScreen> createState() => _BolgeAtamaScreenState();
}

class _BolgeAtamaScreenState extends State<BolgeAtamaScreen>
    with SingleTickerProviderStateMixin {
  static const _navy    = Color(0xFF1a3a6b);
  static const _orange  = Color(0xFFFF8C00);

  GoogleMapController? _mapCtrl;
  late TabController   _tab;

  String _firmaId = '';
  String _projeId = '';

  List<Map<String, dynamic>> _ogrenciler = [];
  List<Map<String, dynamic>> _soforler   = [];
  bool   _yukleniyor = true;

  // Seçim modu
  bool   _secimModu    = false;
  LatLng? _merkezNokta;
  double  _yaricap     = 1000; // metre
  List<String> _secilenIds = [];

  Set<Marker>  _markers  = {};
  Set<Circle>  _circles  = {};

  // Renk paleti — her şoföre bir renk
  static const List<Color> _renkler = [
    Color(0xFF4CAF50), Color(0xFF2196F3), Color(0xFFE91E63),
    Color(0xFF9C27B0), Color(0xFFFF9800), Color(0xFF00BCD4),
    Color(0xFFFF5722), Color(0xFF795548),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _yukle();
  }

  @override
  void dispose() { _tab.dispose(); _mapCtrl?.dispose(); super.dispose(); }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    _firmaId = await SessionService.instance.firmaIdAl() ?? '';
    _projeId = SessionService.instance.aktifProjeld ?? '';
    try {
      final sSnap = await FirebaseFirestore.instance
          .collection('drivers').where('firmaId', isEqualTo: _firmaId).get();
      _soforler = sSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      var q = FirebaseFirestore.instance.collection('students').where('firmaId', isEqualTo: _firmaId);
      if (_projeId.isNotEmpty) q = q.where('projeId', isEqualTo: _projeId);
      final oSnap = await q.get();
      _ogrenciler = oSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      _haritaOlustur();
    } catch (e) { debugPrint('BolgeAtama hata: $e'); }
    if (mounted) setState(() => _yukleniyor = false);
  }

  void _haritaOlustur() {
    final Set<Marker> yeniMarker = {};
    final Set<Circle> yeniCircle = {};

    // Şoför renk haritası
    final soforRenk = <String, Color>{};
    for (int i = 0; i < _soforler.length; i++) {
      soforRenk[_soforler[i]['id'] as String] = _renkler[i % _renkler.length];
    }

    for (final ogr in _ogrenciler) {
      final konum = _konumAl(ogr);
      if (konum == null) continue;

      final surucuId = (ogr['surucuId'] ?? '').toString();
      final atanmis  = surucuId.isNotEmpty;
      final renk     = atanmis ? soforRenk[surucuId] : null;
      final secili   = _secilenIds.contains(ogr['id'] as String);

      // Marker rengi
      double hue;
      if (secili) {
        hue = BitmapDescriptor.hueYellow;
      } else if (renk != null) {
        hue = _colorToHue(renk);
      } else {
        hue = BitmapDescriptor.hueRed;
      }

      yeniMarker.add(Marker(
        markerId: MarkerId('ogr_${ogr['id']}'),
        position: konum,
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        infoWindow: InfoWindow(
          title: ogr['ad'] ?? 'Ogrenci',
          snippet: atanmis
              ? _soforAdKisa(surucuId)
              : 'Servis atanmamis — Tap ile sec',
        ),
        onTap: () => _markerTap(ogr),
      ));
    }

    // Seçim çemberi
    if (_merkezNokta != null) {
      yeniCircle.add(Circle(
        circleId: const CircleId('secim'),
        center: _merkezNokta!,
        radius: _yaricap,
        fillColor: _orange.withValues(alpha: 0.15),
        strokeColor: _orange,
        strokeWidth: 2,
      ));
    }

    if (mounted) setState(() { _markers = yeniMarker; _circles = yeniCircle; });
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

  double _colorToHue(Color c) {
    // Yaklaşık renk → BitmapDescriptor hue dönüşümü
    final r = c.red / 255.0, g = c.green / 255.0, b = c.blue / 255.0;
    final max = [r, g, b].reduce(math.max);
    final min = [r, g, b].reduce(math.min);
    double h = 0;
    if (max == min) return 0;
    final d = max - min;
    if (max == r) h = (g - b) / d + (g < b ? 6 : 0);
    else if (max == g) h = (b - r) / d + 2;
    else h = (r - g) / d + 4;
    return (h / 6 * 360).clamp(0, 360);
  }

  String _soforAdKisa(String surucuId) {
    final s = _soforler.firstWhere((s) => s['id'] == surucuId, orElse: () => {});
    return s.isNotEmpty ? '${s['ad'] ?? ''} ${s['aracPlaka'] ?? ''}'.trim() : 'Sofor';
  }

  // Haritaya tıklama — seçim modu açıksa çember çiz
  void _haritaTap(LatLng konum) {
    if (!_secimModu) return;
    setState(() => _merkezNokta = konum);
    _ceberIcindekilerSec(konum);
    _haritaOlustur();
  }

  void _ceberIcindekilerSec(LatLng merkez) {
    final yeniSecilen = <String>[];
    for (final ogr in _ogrenciler) {
      final k = _konumAl(ogr);
      if (k == null) continue;
      final mesafe = _mesafeHesapla(merkez, k);
      if (mesafe <= _yaricap) {
        yeniSecilen.add(ogr['id'] as String);
      }
    }
    setState(() => _secilenIds = yeniSecilen);
  }

  double _mesafeHesapla(LatLng a, LatLng b) {
    const R = 6371000.0;
    final dLat = (b.latitude  - a.latitude)  * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final x = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(a.latitude * math.pi / 180) * math.cos(b.latitude * math.pi / 180) *
            math.sin(dLng / 2) * math.sin(dLng / 2);
    return R * 2 * math.atan2(math.sqrt(x), math.sqrt(1 - x));
  }

  void _markerTap(Map<String, dynamic> ogr) {
    final id = ogr['id'] as String;
    if (_secimModu) {
      setState(() {
        _secilenIds.contains(id) ? _secilenIds.remove(id) : _secilenIds.add(id);
      });
      _haritaOlustur();
    } else {
      _ogrenciDetay(ogr);
    }
  }

  void _ogrenciDetay(Map<String, dynamic> ogr) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => _OgrenciAtaSheet(ogr: ogr, soforler: _soforler, onKayit: _yukle),
    );
  }

  // Seçilenleri şoföre toplu ata
  Future<void> _topluAta(String surucuId) async {
    if (_secilenIds.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final id in _secilenIds) {
      batch.update(FirebaseFirestore.instance.collection('students').doc(id), {'surucuId': surucuId});
    }
    await batch.commit();
    _snack('${_secilenIds.length} ogrenci atandi!', Colors.green);
    setState(() { _secilenIds = []; _merkezNokta = null; _secimModu = false; });
    _yukle();
  }

  void _snack(String msg, Color c) =>
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: c, behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white, elevation: 0,
        title: const Text('Bölge Atama', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          YardimButonu(ekranAdi: 'Fiyatlandirma'),
          if (_secilenIds.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(16)),
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
            Tab(icon: Icon(Icons.map_outlined, size: 18), text: 'Harita'),
            Tab(icon: Icon(Icons.list_alt_outlined, size: 18), text: 'Liste'),
          ],
        ),
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator(color: _navy))
          : TabBarView(controller: _tab, children: [
        _haritaSekmesi(),
        _listeSekmesi(),
      ]),
    );
  }

  // ── HARİTA SEKMESİ ──
  Widget _haritaSekmesi() {
    // İlk öğrenci konumunu bul
    LatLng merkez = const LatLng(39.9334, 32.8597);
    for (final ogr in _ogrenciler) {
      final k = _konumAl(ogr);
      if (k != null) { merkez = k; break; }
    }

    return Stack(children: [
      GoogleMap(
        initialCameraPosition: CameraPosition(target: merkez, zoom: 12),
        markers:  _markers,
        circles:  _circles,
        onMapCreated: (c) => _mapCtrl = c,
        onTap: _haritaTap,
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
      ),

      // Üst araç çubuğu
      Positioned(top: 10, left: 10, right: 10,
        child: Column(children: [
          // Seçim modu toggle
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)]),
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Row(children: [
                Icon(_secimModu ? Icons.touch_app : Icons.pan_tool_alt_outlined,
                    color: _secimModu ? _orange : Colors.grey, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  _secimModu
                      ? 'Haritaya dokun → Çevre içindeki öğrenciler seçilir'
                      : 'Noktalara dokun → Öğrenci detayı gösterilir',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                )),
                Switch(
                  value: _secimModu,
                  onChanged: (v) => setState(() {
                    _secimModu = v;
                    if (!v) { _secilenIds = []; _merkezNokta = null; _haritaOlustur(); }
                  }),
                  activeColor: _orange,
                ),
              ]),
              if (_secimModu) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.radio_button_checked, color: _orange, size: 14),
                  const SizedBox(width: 6),
                  Text('Yarıçap: ${(_yaricap / 1000).toStringAsFixed(1)} km',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _orange)),
                  Expanded(child: Slider(
                    value: _yaricap,
                    min: 200, max: 5000,
                    activeColor: _orange,
                    onChanged: (v) {
                      setState(() => _yaricap = v);
                      if (_merkezNokta != null) { _ceberIcindekilerSec(_merkezNokta!); _haritaOlustur(); }
                    },
                  )),
                ]),
              ],
            ]),
          ),

          // Seçilenleri ata butonu
          if (_secilenIds.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)]),
              padding: const EdgeInsets.all(10),
              child: Column(children: [
                Text('${_secilenIds.length} öğrenci seçildi — Şoför Ata:',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _navy)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: _soforler.map((s) {
                    final idx  = _soforler.indexOf(s);
                    final renk = _renkler[idx % _renkler.length];
                    return GestureDetector(
                      onTap: () => _topluAtaDialog(s),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(10)),
                        child: Text(
                          '${s['ad'] ?? 'Sofor'}\n${s['aracPlaka'] ?? ''}',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }).toList()),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () => setState(() { _secilenIds = []; _merkezNokta = null; _haritaOlustur(); }),
                  icon: const Icon(Icons.clear, size: 14, color: Colors.red),
                  label: const Text('Seçimi Temizle', style: TextStyle(color: Colors.red, fontSize: 11)),
                ),
              ]),
            ),
          ],
        ]),
      ),

      // Zoom kontrolü
      Positioned(bottom: 80, right: 12, child: Column(children: [
        FloatingActionButton.small(heroTag: 'zoomin', backgroundColor: Colors.white,
            onPressed: () => _mapCtrl?.animateCamera(CameraUpdate.zoomIn()),
            child: const Icon(Icons.add, color: _navy)),
        const SizedBox(height: 4),
        FloatingActionButton.small(heroTag: 'zoomout', backgroundColor: Colors.white,
            onPressed: () => _mapCtrl?.animateCamera(CameraUpdate.zoomOut()),
            child: const Icon(Icons.remove, color: _navy)),
      ])),

      // Legend
      Positioned(bottom: 16, left: 12,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6)]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _LegendItem(Colors.red, 'Atanmamis'),
            _LegendItem(_orange, 'Secili'),
            ..._soforler.take(4).map((s) {
              final idx = _soforler.indexOf(s);
              return _LegendItem(_renkler[idx % _renkler.length], s['ad'] ?? 'Sofor');
            }),
          ]),
        ),
      ),
    ]);
  }

  void _topluAtaDialog(Map<String, dynamic> sofor) {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Atamayı Onayla', style: TextStyle(fontWeight: FontWeight.bold, color: _navy)),
      content: Text(
        '${_secilenIds.length} öğrenci → ${sofor['ad'] ?? 'Sofor'} (${sofor['aracPlaka'] ?? ''})\n\nBu atama yapılsın mı?',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Iptal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _navy),
          onPressed: () { Navigator.pop(context); _topluAta(sofor['id'] as String); },
          child: const Text('Ata', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  // ── LİSTE SEKMESİ ──
  Widget _listeSekmesi() {
    // Şoförlere göre grupla
    final Map<String, List<Map<String, dynamic>>> gruplar = {};
    gruplar['__atanmamis__'] = [];
    for (final s in _soforler) { gruplar[s['id'] as String] = []; }
    for (final ogr in _ogrenciler) {
      final sId = (ogr['surucuId'] ?? '').toString();
      if (sId.isEmpty) {
        gruplar['__atanmamis__']!.add(ogr);
      } else {
        gruplar[sId]?.add(ogr);
      }
    }

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Atanmamış
        if (gruplar['__atanmamis__']!.isNotEmpty) ...[
          _GrupBaslik('Servis Atanmamış', gruplar['__atanmamis__']!.length, Colors.red),
          ...gruplar['__atanmamis__']!.map((o) => _ListeOgrencSatiri(o, _soforler, _yukle)),
          const SizedBox(height: 12),
        ],
        // Her şoför grubu
        ..._soforler.map((s) {
          final idx   = _soforler.indexOf(s);
          final renk  = _renkler[idx % _renkler.length];
          final liste = gruplar[s['id']] ?? [];
          if (liste.isEmpty) return const SizedBox.shrink();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _GrupBaslik('${s['ad'] ?? 'Sofor'} — ${s['aracPlaka'] ?? ''}', liste.length, renk),
            ...liste.map((o) => _ListeOgrencSatiri(o, _soforler, _yukle)),
            const SizedBox(height: 12),
          ]);
        }),
      ],
    );
  }
}

class _GrupBaslik extends StatelessWidget {
  final String baslik; final int sayi; final Color renk;
  const _GrupBaslik(this.baslik, this.sayi, this.renk);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: renk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
    child: Row(children: [
      Icon(Icons.directions_bus_outlined, color: renk, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(baslik, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: renk))),
      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(12)),
          child: Text('$sayi', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
    ]),
  );
}

class _ListeOgrencSatiri extends StatelessWidget {
  final Map<String, dynamic> ogr;
  final List<Map<String, dynamic>> soforler;
  final VoidCallback onGuncelle;
  static const _navy = Color(0xFF1a3a6b);
  const _ListeOgrencSatiri(this.ogr, this.soforler, this.onGuncelle);
  @override
  Widget build(BuildContext context) {
    final ad = '${ogr['ad'] ?? ''} ${ogr['soyad'] ?? ''}'.trim();
    return GestureDetector(
      onTap: () => showModalBottomSheet(context: context, backgroundColor: Colors.transparent,
          builder: (_) => _OgrenciAtaSheet(ogr: ogr, soforler: soforler, onKayit: onGuncelle)),
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
          const Icon(Icons.chevron_right, color: Colors.grey, size: 16),
        ]),
      ),
    );
  }
}

// Şoför ata sheet (detay)
class _OgrenciAtaSheet extends StatefulWidget {
  final Map<String, dynamic> ogr;
  final List<Map<String, dynamic>> soforler;
  final VoidCallback onKayit;
  const _OgrenciAtaSheet({required this.ogr, required this.soforler, required this.onKayit});
  @override
  State<_OgrenciAtaSheet> createState() => _OgrenciAtaSheetState();
}

class _OgrenciAtaSheetState extends State<_OgrenciAtaSheet> {
  static const _navy = Color(0xFF1a3a6b);
  String? _secili;
  bool _kaydediyor = false;

  @override
  void initState() { super.initState(); _secili = (widget.ogr['surucuId'] ?? '').toString().isNotEmpty ? widget.ogr['surucuId'] as String? : null; }

  Future<void> _kaydet() async {
    setState(() => _kaydediyor = true);
    await FirebaseFirestore.instance.collection('students').doc(widget.ogr['id']).update({'surucuId': _secili ?? ''});
    if (mounted) { Navigator.pop(context); widget.onKayit(); }
  }

  @override
  Widget build(BuildContext context) {
    final ad = '${widget.ogr['ad'] ?? ''} ${widget.ogr['soyad'] ?? ''}'.trim();
    return Container(
      padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 14),
        Row(children: [
          CircleAvatar(radius: 20, backgroundColor: _navy.withValues(alpha: 0.1),
              child: Text(ad.isNotEmpty ? ad[0].toUpperCase() : '?', style: const TextStyle(color: _navy, fontWeight: FontWeight.bold))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ad.isNotEmpty ? ad : 'Isimsiz', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text(widget.ogr['adres'] ?? '', style: TextStyle(color: Colors.grey[500], fontSize: 11), overflow: TextOverflow.ellipsis),
          ])),
        ]),
        const SizedBox(height: 16),
        DropdownButtonFormField<String?>(
          value: _secili,
          decoration: InputDecoration(
            labelText: 'Sofor / Arac Sec',
            prefixIcon: const Icon(Icons.directions_bus_outlined, color: _navy),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('Atamayı Kaldir', style: TextStyle(color: Colors.red))),
            ...widget.soforler.map((s) => DropdownMenuItem(
              value: s['id'] as String,
              child: Text('${s['ad'] ?? 'Sofor'} — ${s['aracPlaka'] ?? ''}', style: const TextStyle(fontSize: 13)),
            )),
          ],
          onChanged: (v) => setState(() => _secili = v),
        ),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: _kaydediyor ? null : _kaydet,
          child: _kaydediyor
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        )),
      ]),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color renk; final String etiket;
  const _LegendItem(this.renk, this.etiket);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: renk, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(etiket, style: const TextStyle(fontSize: 10)),
    ]),
  );
}
