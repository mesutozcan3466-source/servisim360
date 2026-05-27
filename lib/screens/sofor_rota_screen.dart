import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../screens/sofor_ai_asistan_widget.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/session_service.dart';

class SoforRotaScreen extends StatefulWidget {
  final String surucuId;
  final String surucuAd;

  const SoforRotaScreen({
    super.key,
    required this.surucuId,
    required this.surucuAd,
  });

  @override
  State<SoforRotaScreen> createState() => _SoforRotaScreenState();
}

class _SoforRotaScreenState extends State<SoforRotaScreen>
    with SingleTickerProviderStateMixin {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  late TabController _tab;
  GoogleMapController? _mapCtrl;

  List<Map<String, dynamic>> _ogrenciler = [];
  Map<String, dynamic>? _soforData;
  String? _firmaId;
  String _aracPlaka = '';
  bool _yukleniyor = true;

  LatLng? _soforKonum;
  StreamSubscription<Position>? _gpsSub;
  Set<String> _devamsizOgrIds = {};

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _yukle();
    _gpsBaslat();
  }

  @override
  void dispose() {
    _tab.dispose();
    _mapCtrl?.dispose();
    _gpsSub?.cancel();
    super.dispose();
  }

  Future<void> _yukle() async {
    _firmaId = await SessionService.instance.firmaldAl();

    try {
      var dSnap = await FirebaseFirestore.instance
          .collection('drivers')
          .where('uid', isEqualTo: widget.surucuId).limit(1).get();
      if (dSnap.docs.isNotEmpty) {
        _soforData = dSnap.docs.first.data();
        _aracPlaka = _soforData?['aracPlaka'] ?? '';
      }

      final ogrSnap = await FirebaseFirestore.instance
          .collection('students')
          .where('surucuId', isEqualTo: widget.surucuId)
          .where('aktif', isEqualTo: true)
          .get();

      var liste = ogrSnap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList();

      liste.sort((a, b) {
        final siraA = a['sira'] as int? ?? 999;
        final siraB = b['sira'] as int? ?? 999;
        if (siraA != siraB) return siraA.compareTo(siraB);
        return (a['ad'] ?? '').compareTo(b['ad'] ?? '');
      });

      final bugun = DateTime.now();
      final baslangic = DateTime(bugun.year, bugun.month, bugun.day);
      final devSnap = await FirebaseFirestore.instance
          .collection('absence_requests')
          .where('surucuId', isEqualTo: widget.surucuId)
          .where('tarih', isGreaterThanOrEqualTo: Timestamp.fromDate(baslangic))
          .get();

      _devamsizOgrIds = devSnap.docs
          .map((d) => d.data()['ogrenciId'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      setState(() {
        _ogrenciler = liste;
        _yukleniyor = false;
      });
    } catch (e) {
      debugPrint('SoforRota yukle hata: $e');
      setState(() => _yukleniyor = false);
    }
  }

  Future<void> _gpsBaslat() async {
    final izin = await Geolocator.requestPermission();
    if (izin == LocationPermission.denied ||
        izin == LocationPermission.deniedForever) return;

    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, distanceFilter: 20),
    ).listen((pos) {
      if (mounted) {
        setState(() => _soforKonum = LatLng(pos.latitude, pos.longitude));
      }
    });
  }

  Future<void> _siraGuncelle(int eskiIndex, int yeniIndex) async {
    if (eskiIndex == yeniIndex) return;
    setState(() {
      final item = _ogrenciler.removeAt(eskiIndex);
      _ogrenciler.insert(yeniIndex, item);
    });
    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < _ogrenciler.length; i++) {
      final ref = FirebaseFirestore.instance
          .collection('students')
          .doc(_ogrenciler[i]['id'] as String);
      batch.update(ref, {'sira': i});
    }
    await batch.commit();
  }

  Future<void> _ogrenciAtla(String ogrId) async {
    await FirebaseFirestore.instance
        .collection('students')
        .doc(ogrId)
        .update({'atla': true, 'atlaZaman': FieldValue.serverTimestamp()});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ogrenci bu sefer atlanacak'),
              backgroundColor: Colors.orange));
    }
  }

  Future<void> _bindiIsaretle(String ogrId) async {
    await FirebaseFirestore.instance
        .collection('students')
        .doc(ogrId)
        .update({'bindi': true, 'bindiZaman': FieldValue.serverTimestamp()});
    setState(() {
      final idx = _ogrenciler.indexWhere((o) => o['id'] == ogrId);
      if (idx != -1) _ogrenciler[idx]['bindi'] = true;
    });
  }

  Future<void> _navigasyonAc(Map<String, dynamic> ogrenci) async {
    final konum = ogrenci['konum'];
    double? lat, lng;
    if (konum is GeoPoint) {
      lat = konum.latitude;
      lng = konum.longitude;
    } else {
      lat = ogrenci['lat'] as double?;
      lng = ogrenci['lng'] as double?;
    }
    if (lat == null || lng == null) return;
    final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  String _etaHesapla(Map<String, dynamic> ogrenci) {
    if (_soforKonum == null) return '--';
    final konum = ogrenci['konum'];
    if (konum is! GeoPoint) return '--';
    int bekleyenOnce = 0;
    for (final o in _ogrenciler) {
      if (o['id'] == ogrenci['id']) break;
      if (o['bindi'] != true && !_devamsizOgrIds.contains(o['id'])) bekleyenOnce++;
    }
    final mesafe = Geolocator.distanceBetween(
        _soforKonum!.latitude, _soforKonum!.longitude,
        konum.latitude, konum.longitude);
    final dk = ((mesafe / 1000) / 30 * 60 + bekleyenOnce * 2).round();
    if (dk <= 0) return '< 1 dk';
    if (dk > 60) return '> 1 sa';
    return '~$dk dk';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white,
        title: const Text('Rota Yonetimi',
            style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: _turuncu,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.people, size: 18), text: 'Ogrenciler'),
            Tab(icon: Icon(Icons.map,    size: 18), text: 'Harita'),
          ],
        ),
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(controller: _tab, children: [
        _ogrenciListesi(),
        _haritaEkrani(),
      ]),
    );
  }

  Widget _ogrenciListesi() {
    if (_ogrenciler.isEmpty) {
      return const Center(child: Text('Atanmis ogrenci yok',
          style: TextStyle(color: Colors.grey)));
    }

    final bekleyenler = _ogrenciler.where((o) => o['bindi'] != true).length;
    final bindi = _ogrenciler.length - bekleyenler;

    return Column(children: [
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          _OzetChip('${_ogrenciler.length}', 'Toplam',   _navy),
          const SizedBox(width: 8),
          _OzetChip('$bekleyenler', 'Bekliyor', Colors.orange),
          const SizedBox(width: 8),
          _OzetChip('$bindi',  'Bindi',    Colors.green),
          const SizedBox(width: 8),
          _OzetChip('${_devamsizOgrIds.length}', 'Devamsiz', Colors.red),
          const Spacer(),
          Text('Tut-surukle ile sirala',
              style: TextStyle(fontSize: 10, color: Colors.grey[400])),
        ]),
      ),
      const Divider(height: 1),

      // AI Asistan — yeni parametrelerle
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: SoforAiAsistanWidget(
          surucuAd:     widget.surucuAd,
          surucuId:     widget.surucuId,
          aracPlaka:    _aracPlaka,
          ogrenciler:   _ogrenciler,
          alinanSayisi: _ogrenciler.where((o) => o['bindi'] == true).length,
          servisDurumu: 'basladi',
          sabahBaslangic: _soforData?['servisSaati']?['sabahBaslangic'] ?? '06:30',
          sabahBitis:     _soforData?['servisSaati']?['sabahBitis']     ?? '09:30',
          aksamBaslangic: _soforData?['servisSaati']?['aksamBaslangic'] ?? '15:00',
          aksamBitis:     _soforData?['servisSaati']?['aksamBitis']     ?? '18:30',
        ),
      ),

      Expanded(
        child: ReorderableListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _ogrenciler.length,
          onReorder: _siraGuncelle,
          itemBuilder: (context, i) {
            final ogr     = _ogrenciler[i];
            final ogrId   = ogr['id'] as String;
            final bindi   = ogr['bindi'] == true;
            final devamsiz = _devamsizOgrIds.contains(ogrId);
            final atla    = ogr['atla'] == true;
            final eta     = _etaHesapla(ogr);

            return _OgrenciRotaKarti(
              key: ValueKey(ogrId),
              siraNo: i + 1,
              ogrenci: ogr,
              bindi: bindi,
              devamsiz: devamsiz,
              atla: atla,
              eta: eta,
              onBindi: () => _bindiIsaretle(ogrId),
              onAtla: () => _ogrenciAtla(ogrId),
              onNavigasyon: () => _navigasyonAc(ogr),
              onVeliAra: () async {
                final tel = ogr['veliTel'] ?? ogr['veliTelefon'] ?? '';
                if (tel.isEmpty) return;
                final url = Uri.parse('tel:$tel');
                if (await canLaunchUrl(url)) await launchUrl(url);
              },
            );
          },
        ),
      ),
    ]);
  }

  Widget _haritaEkrani() {
    final markers = <Marker>{};
    final polylinePoints = <LatLng>[];

    if (_soforKonum != null) {
      markers.add(Marker(
        markerId: const MarkerId('sofor'),
        position: _soforKonum!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: widget.surucuAd, snippet: 'Arac konumu'),
      ));
      polylinePoints.add(_soforKonum!);
    }

    for (int i = 0; i < _ogrenciler.length; i++) {
      final ogr   = _ogrenciler[i];
      final ogrId = ogr['id'] as String;
      if (ogr['bindi'] == true) continue;
      if (_devamsizOgrIds.contains(ogrId)) continue;
      final konum = ogr['konum'];
      if (konum is! GeoPoint) continue;
      final pos = LatLng(konum.latitude, konum.longitude);
      polylinePoints.add(pos);
      markers.add(Marker(
        markerId: MarkerId('ogr_$ogrId'),
        position: pos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: InfoWindow(
            title: '${i + 1}. ${ogr['ad'] ?? ''}',
            snippet: _etaHesapla(ogr)),
      ));
    }

    final polylines = <Polyline>{};
    if (polylinePoints.length >= 2) {
      polylines.add(Polyline(
          polylineId: const PolylineId('rota'),
          points: polylinePoints,
          color: _navy, width: 4));
    }

    final baslangic = _soforKonum ??
        (polylinePoints.isNotEmpty ? polylinePoints.first : null) ??
        const LatLng(41.0082, 28.9784);

    return Stack(children: [
      GoogleMap(
          initialCameraPosition: CameraPosition(target: baslangic, zoom: 13),
          markers: markers,
          polylines: polylines,
          onMapCreated: (c) => _mapCtrl = c,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: false),
      Positioned(top: 12, right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)]),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.people, color: _navy, size: 16),
              const SizedBox(width: 6),
              Text(
                  '${markers.where((m) => m.markerId.value.startsWith('ogr_')).length} durak',
                  style: const TextStyle(fontWeight: FontWeight.bold,
                      color: _navy, fontSize: 13)),
            ]),
          )),
    ]);
  }
}

class _OgrenciRotaKarti extends StatelessWidget {
  final int siraNo;
  final Map<String, dynamic> ogrenci;
  final bool bindi, devamsiz, atla;
  final String eta;
  final VoidCallback onBindi, onAtla, onNavigasyon, onVeliAra;
  static const _navy = Color(0xFF1a3a6b);

  const _OgrenciRotaKarti({
    super.key,
    required this.siraNo, required this.ogrenci,
    required this.bindi, required this.devamsiz, required this.atla,
    required this.eta, required this.onBindi, required this.onAtla,
    required this.onNavigasyon, required this.onVeliAra,
  });

  Color get _durumRenk {
    if (bindi) return Colors.green;
    if (devamsiz) return Colors.red;
    if (atla) return Colors.orange;
    return _navy;
  }

  String get _durumMetin {
    if (bindi) return 'Bindi';
    if (devamsiz) return 'Devamsiz';
    if (atla) return 'Atla';
    return 'Bekliyor';
  }

  @override
  Widget build(BuildContext context) {
    final ad = '${ogrenci['ad'] ?? ''} ${ogrenci['soyad'] ?? ''}'.trim();
    final adres = ogrenci['adres'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
          color: bindi ? Colors.green.withValues(alpha: 0.05)
              : devamsiz ? Colors.red.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _durumRenk.withValues(alpha: 0.2)),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)]),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
          child: Row(children: [
            Container(width: 32, height: 32,
                decoration: BoxDecoration(color: _durumRenk, shape: BoxShape.circle),
                child: Center(child: Text(bindi ? '✓' : '$siraNo',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 13)))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ad, style: TextStyle(fontWeight: FontWeight.bold,
                  fontSize: 14, color: bindi || devamsiz ? Colors.grey : _navy,
                  decoration: devamsiz ? TextDecoration.lineThrough : null)),
              if (adres.isNotEmpty)
                Row(children: [
                  const Icon(Icons.location_on_outlined, size: 11, color: Colors.grey),
                  const SizedBox(width: 2),
                  Expanded(child: Text(adres,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      overflow: TextOverflow.ellipsis)),
                ]),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (!bindi && !devamsiz)
                Text(eta, style: TextStyle(fontSize: 13,
                    fontWeight: FontWeight.bold, color: Colors.grey[700])),
              const SizedBox(height: 2),
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: _durumRenk.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(_durumMetin, style: TextStyle(fontSize: 11,
                      color: _durumRenk, fontWeight: FontWeight.bold))),
            ]),
            const Padding(padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.drag_handle, color: Colors.grey, size: 20)),
          ]),
        ),
        if (!bindi && !devamsiz)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(children: [
              Expanded(child: _MiniButon(ikon: Icons.check, etiket: 'Bindi',
                  renk: Colors.green, onTap: onBindi)),
              const SizedBox(width: 6),
              Expanded(child: _MiniButon(ikon: Icons.navigation, etiket: 'Git',
                  renk: Colors.blue, onTap: onNavigasyon)),
              const SizedBox(width: 6),
              Expanded(child: _MiniButon(ikon: Icons.phone, etiket: 'Ara',
                  renk: Colors.teal, onTap: onVeliAra)),
              const SizedBox(width: 6),
              Expanded(child: _MiniButon(ikon: Icons.skip_next, etiket: 'Atla',
                  renk: Colors.orange, onTap: onAtla)),
            ]),
          ),
      ]),
    );
  }
}

class _MiniButon extends StatelessWidget {
  final IconData ikon; final String etiket;
  final Color renk; final VoidCallback onTap;
  const _MiniButon({required this.ikon, required this.etiket,
    required this.renk, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
            color: renk.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: renk.withValues(alpha: 0.2))),
        child: Column(children: [
          Icon(ikon, color: renk, size: 16),
          const SizedBox(height: 2),
          Text(etiket, style: TextStyle(color: renk, fontSize: 9,
              fontWeight: FontWeight.bold)),
        ]),
      ));
}

class _OzetChip extends StatelessWidget {
  final String deger, etiket; final Color renk;
  const _OzetChip(this.deger, this.etiket, this.renk);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: renk.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(deger, style: TextStyle(fontWeight: FontWeight.bold,
            color: renk, fontSize: 13)),
        const SizedBox(width: 4),
        Text(etiket, style: TextStyle(fontSize: 10, color: renk)),
      ]));
}
