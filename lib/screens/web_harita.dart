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
  bool _detayPanelAcik = false;  // Servis detay panel
  List<Map<String, dynamic>> _projeler = [];  // Proje listesi

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

    // Projeleri de yükle
    try {
      final pSnap = await FirebaseFirestore.instance
          .collection('projects')
          .where('firmaId', isEqualTo: _firmaId)
          .where('aktif', isEqualTo: true)
          .get();
      _projeler = pSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (_) {}

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


  // ──────────────────────────────────────────────────────────────
  // SERVİS DETAY DİYALOGU
  // ──────────────────────────────────────────────────────────────
  void _servisDetayDialog(Map<String, dynamic> sofor, String soforId, int index) {
    final renk = _renkler[index % _renkler.length];
    final ogrenciler = _ogrenciler
        .where((o) => (o['surucuId'] ?? o['soforId'] ?? '') == soforId)
        .toList();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: SizedBox(
            width: 640,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Başlık
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    color: renk,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18))),
                child: Row(children: [
                  Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.directions_bus_outlined, color: Colors.white, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(sofor['ad'] ?? 'Servis',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('${sofor['aracPlaka'] ?? 'Plaka yok'}  •  ${ogrenciler.length} öğrenci',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                  ])),
                  IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                ]),
              ),

              // İçerik
              Flexible(child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // Servis Bilgileri
                  _detayBaslik('Servis Bilgileri', Icons.info_outline, renk),
                  const SizedBox(height: 10),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    _infoBant('Şoför', sofor['ad'] ?? '-', Icons.person_outlined, Colors.blue),
                    _infoBant('Plaka', sofor['aracPlaka'] ?? '-', Icons.directions_car_outlined, Colors.grey),
                    _infoBant('Proje', sofor['projeAd'] ?? sofor['projeId'] ?? '-', Icons.folder_outlined, _navy),
                    _infoBant('Sabah', sofor['sabahSaati'] ?? '-', Icons.wb_sunny_outlined, Colors.orange),
                    _infoBant('Aksam', sofor['aksamSaati'] ?? '-', Icons.nights_stay_outlined, Colors.indigo),
                    _infoBant('Kapasite', '${sofor['aracKapasitesi'] ?? sofor['kapasite'] ?? 17} koltuk',
                        Icons.people_outlined, Colors.teal),
                    _infoBant('Kullanici Adi', sofor['kullaniciAdi'] ?? '-',
                        Icons.account_circle_outlined, Colors.purple),
                  ]),

                  const SizedBox(height: 20),

                  // Öğrenci Listesi
                  Row(children: [
                    _detayBaslik('Bağlı Öğrenciler', Icons.school_outlined, renk),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: renk.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: Text('${ogrenciler.length}/${sofor['aracKapasitesi'] ?? sofor['kapasite'] ?? 17}',
                          style: TextStyle(color: renk, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  ogrenciler.isEmpty
                      ? Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200)),
                      child: const Row(children: [
                        Icon(Icons.person_off_outlined, color: Colors.grey, size: 18),
                        SizedBox(width: 10),
                        Text('Bu servise atanmış öğrenci yok',
                            style: TextStyle(color: Colors.grey)),
                      ]))
                      : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: ogrenciler.length,
                      itemBuilder: (_, i) {
                        final ogr = ogrenciler[i];
                        final bindi = ogr['bindi'] == true;
                        final konumVar = _konumAl(ogr) != null;
                        return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: bindi
                                    ? Colors.green.withValues(alpha: 0.3)
                                    : Colors.grey.shade200)),
                            child: Row(children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: renk.withValues(alpha: 0.12),
                                child: Text('${i + 1}',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: renk)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(ogr['ad'] ?? 'Öğrenci',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text(ogr['adres'] ?? ogr['sabahAdres'] ?? '',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              ])),
                              if (!konumVar)
                                Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6)),
                                    child: const Text('Konum yok',
                                        style: TextStyle(fontSize: 10, color: Colors.red))),
                              const SizedBox(width: 6),
                              Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                      color: (bindi ? Colors.green : Colors.orange).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6)),
                                  child: Text(bindi ? 'Bindi' : 'Bekliyor',
                                      style: TextStyle(
                                          fontSize: 10, fontWeight: FontWeight.bold,
                                          color: bindi ? Colors.green : Colors.orange))),
                            ]));
                      }),

                  const SizedBox(height: 20),

                  // Atanmamış Öğrenciler
                  _AtanmamisOgrenciler(
                    firmaId: _firmaId,
                    projeId: widget.projeId,
                    soforId: soforId,
                    soforAd: sofor['ad'] ?? '',
                    renk: renk,
                    onAtandi: () {
                      Navigator.pop(ctx);
                      _yukle();
                    },
                  ),
                ]),
              )),

              // Alt Butonlar
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFEEEEEE)))),
                child: Row(children: [
                  Expanded(child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: _navy,
                        side: const BorderSide(color: Color(0xFF1a3a6b)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pushNamed(context, '/gruplama');
                    },
                    icon: const Icon(Icons.route_outlined, size: 16),
                    label: const Text('Rota Olustur'),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF8C00),
                        side: const BorderSide(color: Color(0xFFFF8C00)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pushNamed(context, '/servis_bolme');
                    },
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('Otomatik Dagit'),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _navy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pushNamed(context, '/suruculer');
                    },
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Soforu Duzenle'),
                  )),
                ]),
              ),
            ]),
          ),
        );
      }),
    );
  }

  Widget _detayBaslik(String baslik, IconData ikon, Color renk) => Row(children: [
    Icon(ikon, color: renk, size: 16),
    const SizedBox(width: 8),
    Text(baslik, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: renk)),
  ]);

  Widget _infoBant(String label, String deger, IconData ikon, Color renk) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: renk.withValues(alpha: 0.2))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(ikon, size: 13, color: renk),
      const SizedBox(width: 6),
      Text('$label: ', style: TextStyle(fontSize: 11, color: renk, fontWeight: FontWeight.bold)),
      Text(deger, style: TextStyle(fontSize: 11, color: renk)),
    ]),
  );

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
                      _detayPanelAcik = !secili; // Detay panel aç/kapat
                    });
                    _markerlarOlustur();
                    if (!secili) {
                      final k = _konumAl(s);
                      if (k != null && _mapController != null) {
                        _mapController!.animateCamera(CameraUpdate.newLatLngZoom(k, 13));
                      }
                    }
                  },
                  onLongPress: () {
                    // Uzun basmada direkt detay dialog aç
                    _servisDetayDialog(s, sid, i);
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
                const Spacer(),
                // Detay Dialog Butonu
                GestureDetector(
                  onTap: () => _servisDetayDialog(
                      _seciliSofor!, _seciliSoforId!,
                      _seciliSofor!['_index'] as int? ?? 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: _navy,
                        borderRadius: BorderRadius.circular(8)),
                    child: const Row(children: [
                      Icon(Icons.info_outline, color: Colors.white, size: 13),
                      SizedBox(width: 5),
                      Text('Detay', style: TextStyle(
                          color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ),
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

// ════════════════════════════════════════════════════════════════
// ATANMAMIŞ ÖĞRENCİLER — Servise Ata bölümü
// ════════════════════════════════════════════════════════════════
class _AtanmamisOgrenciler extends StatefulWidget {
  final String firmaId, projeId, soforId, soforAd;
  final Color renk;
  final VoidCallback onAtandi;
  const _AtanmamisOgrenciler({
    required this.firmaId, required this.projeId,
    required this.soforId, required this.soforAd,
    required this.renk, required this.onAtandi,
  });
  @override State<_AtanmamisOgrenciler> createState() => _AtanmamisOgrencilerState();
}

class _AtanmamisOgrencilerState extends State<_AtanmamisOgrenciler> {
  static const _navy = Color(0xFF1a3a6b);
  List<String> _secilenIds = [];
  bool _ataniyor = false;

  Future<void> _serviseAta() async {
    if (_secilenIds.isEmpty) return;
    setState(() => _ataniyor = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final id in _secilenIds) {
        final ref = FirebaseFirestore.instance.collection('students').doc(id);
        batch.update(ref, {
          'surucuId': widget.soforId,
          'soforId':  widget.soforId,
          'soforAd':  widget.soforAd,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      widget.onAtandi();
    } catch (e) {
      setState(() => _ataniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: () {
        var q = FirebaseFirestore.instance.collection('students')
            .where('firmaId', isEqualTo: widget.firmaId)
            .where('surucuId', isEqualTo: '');
        if (widget.projeId.isNotEmpty) {
          q = q.where('projeId', isEqualTo: widget.projeId);
        }
        return q.snapshots();
      }(),
      builder: (_, snap) {
        final atanmamis = snap.data?.docs ?? [];
        if (atanmamis.isEmpty) return const SizedBox();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.person_add_outlined, color: widget.renk, size: 16),
            const SizedBox(width: 8),
            Text('Atanmamış Öğrenciler (${atanmamis.length})',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: widget.renk)),
            const Spacer(),
            if (_secilenIds.isNotEmpty)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _navy, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                onPressed: _ataniyor ? null : _serviseAta,
                icon: _ataniyor
                    ? const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check, size: 14),
                label: Text('${_secilenIds.length} Öğrenciyi Ata',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
          ]),
          const SizedBox(height: 8),
          ...atanmamis.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final secili = _secilenIds.contains(doc.id);
            return GestureDetector(
              onTap: () => setState(() {
                if (secili) _secilenIds.remove(doc.id);
                else _secilenIds.add(doc.id);
              }),
              child: Container(
                margin: const EdgeInsets.only(bottom: 5),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: secili ? widget.renk.withValues(alpha: 0.06) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: secili ? widget.renk : Colors.grey.shade200,
                        width: secili ? 1.5 : 1)),
                child: Row(children: [
                  Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                        color: secili ? widget.renk : Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                            color: secili ? widget.renk : Colors.grey.shade300)),
                    child: secili
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d['ad'] ?? d['adSoyad'] ?? 'Öğrenci',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    if ((d['adres'] ?? d['sabahAdres'] ?? '').isNotEmpty)
                      Text(d['adres'] ?? d['sabahAdres'] ?? '',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
                  if ((d['veliAd'] ?? '').isNotEmpty)
                    Text('Veli: ${d['veliAd']}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                ]),
              ),
            );
          }),
        ]);
      },
    );
  }
}
