import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../services/session_service.dart';

class CanliRotaScreen extends StatefulWidget {
  const CanliRotaScreen({super.key});
  @override
  State<CanliRotaScreen> createState() => _CanliRotaScreenState();
}

class _CanliRotaScreenState extends State<CanliRotaScreen> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  GoogleMapController? _mapCtrl;
  Set<Marker>   _markers   = {};
  Set<Polyline> _polylines = {};

  String? _firmaId;
  String? _surucuDocId;
  bool    _servisAktif = false;
  bool    _yukleniyor  = true;

  Position?        _sonKonum;
  double           _toplamKm    = 0;
  int              _noktaSayisi = 0;
  DateTime?        _baslangicZaman;
  List<LatLng>     _rotaNoktalar = [];

  StreamSubscription<Position>? _konumStream;
  Timer? _konumTimer;

  List<Map<String, dynamic>> _ogrenciler = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _konumStream?.cancel();
    _konumTimer?.cancel();
    _mapCtrl?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _firmaId = await SessionService.instance.firmaIdAl();
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid != null && _firmaId != null) {
      // Şoför dokümanını bul
      final snap = await FirebaseFirestore.instance
          .collection('drivers')
          .where('firmaId', isEqualTo: _firmaId)
          .where('uid', isEqualTo: uid)
          .limit(1).get();

      if (snap.docs.isNotEmpty) {
        _surucuDocId = snap.docs.first.id;
        _servisAktif = snap.docs.first.data()['servisAktif'] ?? false;

        // Öğrencileri yükle
        final ogrSnap = await FirebaseFirestore.instance
            .collection('students')
            .where('surucuId', isEqualTo: _surucuDocId)
            .get();
        _ogrenciler = ogrSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      }
    }

    if (mounted) setState(() => _yukleniyor = false);

    // Eğer servis zaten aktifse GPS başlat
    if (_servisAktif) _gpsBaslat();
  }

  // ── GPS Başlat ──────────────────────────────────────────────────────────────
  Future<void> _gpsBaslat() async {
    final izin = await Geolocator.requestPermission();
    if (izin == LocationPermission.denied || izin == LocationPermission.deniedForever) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konum izni gerekli'), backgroundColor: Colors.red));
      return;
    }

    // Konum stream — 20 metre arayla güncelle
    _konumStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, distanceFilter: 20),
    ).listen(_konumGuncelle);

    // Ayrıca her 30 saniyede Firestore'a yaz
    _konumTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_sonKonum != null) _firestoreKaydet(_sonKonum!);
    });
  }

  // ── GPS Durdur ──────────────────────────────────────────────────────────────

  // Güzergah noktasını kaydet
  Future<void> _guzergahKaydet(double lat, double lng) async {
    try {
      await FirebaseFirestore.instance.collection('guzergah_kayitlar').add({
        'surucuId':  _surucuDocId ?? '',
        'firmaId':   _firmaId ?? '',
        'lat':       lat,
        'lng':       lng,
        'zaman':     FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  void _gpsDurdur() {
    _konumStream?.cancel();
    _konumTimer?.cancel();
    _konumStream = null;
    _konumTimer  = null;
  }

  // ── Konum Güncelle ──────────────────────────────────────────────────────────
  void _konumGuncelle(Position pos) {
    if (_sonKonum != null) {
      final mesafe = Geolocator.distanceBetween(
          _sonKonum!.latitude, _sonKonum!.longitude,
          pos.latitude, pos.longitude);
      setState(() => _toplamKm += mesafe / 1000);
    }

    final latLng = LatLng(pos.latitude, pos.longitude);
    setState(() {
      _sonKonum    = pos;
      _noktaSayisi++;
      _rotaNoktalar.add(latLng);

      // Polyline güncelle
      _polylines = {
        Polyline(
          polylineId: const PolylineId('rota'),
          points: _rotaNoktalar,
          color: _turuncu,
          width: 4,
        ),
      };

      // Kamera takip et
      _mapCtrl?.animateCamera(CameraUpdate.newLatLng(latLng));
    });

    // Her 30 saniyede Firestore'a yaz (timer da yapıyor ama ilk noktayı hemen yaz)
    if (_noktaSayisi == 1) _firestoreKaydet(pos);
  }

  // ── Firestore'a Konum Yaz ───────────────────────────────────────────────────
  Future<void> _firestoreKaydet(Position pos) async {
    if (_surucuDocId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(_surucuDocId)
          .update({
        'konum':             GeoPoint(pos.latitude, pos.longitude),
        'hiz':               pos.speed * 3.6,
        'konumGuncelleme':   FieldValue.serverTimestamp(),
        'servisAktif':       true,
      });
    } catch (_) {}
  }

  // ── Servis Başlat / Durdur ──────────────────────────────────────────────────
  Future<void> _servisBaslatDurdur() async {
    if (_surucuDocId == null) return;

    if (_servisAktif) {
      // Durdur
      _gpsDurdur();
      await FirebaseFirestore.instance
          .collection('drivers').doc(_surucuDocId).update({
        'servisAktif': false,
        'servisBitis': FieldValue.serverTimestamp(),
      });
      setState(() {
        _servisAktif    = false;
        _baslangicZaman = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Servis tamamlandi — \${_toplamKm.toStringAsFixed(1)} km'),
        backgroundColor: Colors.green, behavior: SnackBarBehavior.floating,
      ));
    } else {
      // Başlat
      setState(() {
        _servisAktif    = true;
        _toplamKm       = 0;
        _noktaSayisi    = 0;
        _rotaNoktalar   = [];
        _baslangicZaman = DateTime.now();
      });
      await FirebaseFirestore.instance
          .collection('drivers').doc(_surucuDocId).update({
        'servisAktif':     true,
        'servisBaslangic': FieldValue.serverTimestamp(),
      });
      await _gpsBaslat();
    }
  }

  String get _sureBicim {
    if (_baslangicZaman == null) return '--:--';
    final f = DateTime.now().difference(_baslangicZaman!);
    return '${f.inHours.toString().padLeft(2, '0')}:${(f.inMinutes % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white,
        title: const Text('Canli Rota', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_servisAktif)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.green, borderRadius: BorderRadius.circular(12)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.circle, size: 8, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(_sureBicim,
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold, fontSize: 12)),
                  ]),
                ),
              ),
            ),
        ],
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator(color: _navy))
          : Column(children: [
        // ── İstatistik bar ─────────────────────────────────────
        if (_servisAktif)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatKutu(Icons.straighten_outlined, '${_toplamKm.toStringAsFixed(1)} km', 'Mesafe', Colors.blue),
                _StatKutu(Icons.place_outlined, '$_noktaSayisi', 'Nokta', _navy),
                _StatKutu(Icons.speed_outlined,
                    '${((_sonKonum?.speed ?? 0) * 3.6).toStringAsFixed(0)} km/s',
                    'Hız', Colors.orange),
                _StatKutu(Icons.people_outline, '${_ogrenciler.length}', 'Öğrenci', Colors.green),
              ],
            ),
          ),

        // ── Harita ─────────────────────────────────────────────
        Expanded(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _sonKonum != null
                  ? LatLng(_sonKonum!.latitude, _sonKonum!.longitude)
                  : const LatLng(39.9334, 32.8597),
              zoom: 15,
            ),
            markers: _markers,
            polylines: _polylines,
            onMapCreated: (c) => _mapCtrl = c,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
          ),
        ),

        // ── Öğrenci listesi (kompakt) ──────────────────────────
        if (_ogrenciler.isNotEmpty && _servisAktif)
          Container(
            height: 80,
            color: Colors.white,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _ogrenciler.length,
              itemBuilder: (_, i) {
                final ogr    = _ogrenciler[i];
                final bindi = ogr['bindi'] ?? false;
                return GestureDetector(
                  onTap: () => _ogrenciBindi(ogr['id'], !bindi),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: bindi ? Colors.green.withValues(alpha: 0.1) : _navy.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: bindi ? Colors.green : _navy.withValues(alpha: 0.2)),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(bindi ? Icons.check_circle_outline : Icons.person_outline,
                          color: bindi ? Colors.green : _navy, size: 18),
                      const SizedBox(height: 2),
                      Text(ogr['ad'] ?? '?',
                          style: TextStyle(fontSize: 10,
                              color: bindi ? Colors.green : _navy,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                );
              },
            ),
          ),

        // ── Servis butonu ──────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _servisAktif ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
              onPressed: _servisBaslatDurdur,
              icon: Icon(_servisAktif ? Icons.stop : Icons.play_arrow, size: 26),
              label: Text(
                _servisAktif ? 'Servisi Durdur' : 'Servisi Başlat',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Future<void> _ogrenciBindi(String ogrenciId, bool bindi) async {
    await FirebaseFirestore.instance
        .collection('students').doc(ogrenciId).update({'bindi': bindi});
    final idx = _ogrenciler.indexWhere((o) => o['id'] == ogrenciId);
    if (idx != -1 && mounted) {
      setState(() => _ogrenciler[idx]['bindi'] = bindi);
    }
  }
}

class _StatKutu extends StatelessWidget {
  final IconData ikon; final String deger, etiket; final Color renk;
  const _StatKutu(this.ikon, this.deger, this.etiket, this.renk);

  @override
  Widget build(BuildContext context) => Column(children: [
    Icon(ikon, color: renk, size: 16),
    const SizedBox(height: 2),
    Text(deger, style: TextStyle(color: renk, fontWeight: FontWeight.bold, fontSize: 14)),
    Text(etiket, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
  ]);
}
