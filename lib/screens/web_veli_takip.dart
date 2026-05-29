import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// ════════════════════════════════════════════════════════════════
//  WEB VELİ TAKİP — Kayıt linki web'de açılınca görünür
//  Giriş yapmış veli → çocuğunun servisini takip eder
//  Giriş yapmamış → kayıt formuna yönlendirir
// ════════════════════════════════════════════════════════════════
class WebVeliTakip extends StatefulWidget {
  const WebVeliTakip({super.key});
  @override
  State<WebVeliTakip> createState() => _WebVeliTakipState();
}

class _WebVeliTakipState extends State<WebVeliTakip> {
  static const _navy   = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);

  GoogleMapController? _mapCtrl;
  Map<String, dynamic>? _ogrenci;
  Map<String, dynamic>? _sofor;
  LatLng? _soforKonum;
  LatLng? _durakKonum;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _yukleniyor = true;
  bool _girisYapilmis = false;
  int? _kacDurakKaldi;
  int? _tahminiDakika;

  @override
  void initState() { super.initState(); _kontrol(); }

  Future<void> _kontrol() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() { _girisYapilmis = false; _yukleniyor = false; });
      return;
    }
    _girisYapilmis = true;
    await _yukle(user.uid);
  }

  Future<void> _yukle(String uid) async {
    try {
      final oSnap = await FirebaseFirestore.instance.collection('students')
          .where('veliId', isEqualTo: uid).limit(1).get();
      if (oSnap.docs.isEmpty) { setState(() => _yukleniyor = false); return; }

      _ogrenci = {'id': oSnap.docs.first.id, ...oSnap.docs.first.data()};
      final k = _ogrenci!['konum'];
      if (k is GeoPoint) _durakKonum = LatLng(k.latitude, k.longitude);

      final sid = _ogrenci!['surucuId'] as String? ?? '';
      if (sid.isNotEmpty) {
        final sDoc = await FirebaseFirestore.instance.collection('drivers').doc(sid).get();
        if (sDoc.exists) {
          _sofor = sDoc.data();
          final sk = _sofor!['konum'];
          if (sk is GeoPoint) _soforKonum = LatLng(sk.latitude, sk.longitude);
        }
        // Canlı dinle
        FirebaseFirestore.instance.collection('drivers').doc(sid)
            .snapshots().listen((snap) {
          if (!snap.exists || !mounted) return;
          _sofor = snap.data();
          final nk = _sofor!['konum'];
          if (nk is GeoPoint) _soforKonum = LatLng(nk.latitude, nk.longitude);
          _haritaGuncelle();
        });
      }
    } catch (_) {}
    _haritaGuncelle();
    if (mounted) setState(() => _yukleniyor = false);
  }

  void _haritaGuncelle() {
    if (!mounted) return;
    final Set<Marker> m = {};
    final Set<Polyline> p = {};
    if (_soforKonum != null) {
      m.add(Marker(markerId: const MarkerId('arac'), position: _soforKonum!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: _sofor?['ad'] ?? 'Servis Araci'),
      ));
    }
    if (_durakKonum != null) {
      m.add(Marker(markerId: const MarkerId('durak'), position: _durakKonum!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: InfoWindow(title: '${_ogrenci?['ad'] ?? ''} Duragi'),
      ));
    }
    if (_soforKonum != null && _durakKonum != null) {
      p.add(Polyline(polylineId: const PolylineId('hat'),
          points: [_soforKonum!, _durakKonum!],
          color: _navy, width: 3,
          patterns: [PatternItem.dash(15), PatternItem.gap(8)]));
    }
    setState(() { _markers = m; _polylines = p; });
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: _navy)));

    if (!_girisYapilmis) return _girisEkrani();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white,
        title: Text(_ogrenci != null
            ? '${_ogrenci!['ad']} - Servis Takibi' : 'Servis Takibi',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_sofor != null && _sofor!['servisAktif'] == true)
            IconButton(
              icon: const Icon(Icons.message, color: Color(0xFF25D366)),
              onPressed: () async {
                final tel = (_sofor!['telefon'] ?? '').toString()
                    .replaceAll(RegExp(r'[^\d]'), '');
                if (tel.isNotEmpty) {
                  final url = Uri.parse('https://wa.me/90$tel');
                  if (await canLaunchUrl(url)) await launchUrl(url);
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) setState(() { _girisYapilmis = false; });
            },
          ),
        ],
      ),
      body: Column(children: [
        // Durum bandı
        if (_sofor != null) Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: _sofor!['servisAktif'] == true ? Colors.white : Colors.grey.shade100,
          child: Row(children: [
            Container(width: 10, height: 10, margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                    color: _sofor!['servisAktif'] == true ? Colors.green : Colors.grey,
                    shape: BoxShape.circle)),
            Text(
              _sofor!['servisAktif'] == true ? 'Servis Aktif' : 'Servis Beklemede',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _sofor!['servisAktif'] == true ? Colors.green : Colors.grey),
            ),
            const SizedBox(width: 12),
            if (_tahminiDakika != null)
              Text('Tahmini: $_tahminiDakika dk',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ]),
        ),

        // Harita
        Expanded(child: _soforKonum != null
            ? GoogleMap(
          initialCameraPosition: CameraPosition(
              target: _soforKonum!, zoom: 14),
          markers: _markers, polylines: _polylines,
          onMapCreated: (c) => _mapCtrl = c,
          myLocationEnabled: false, zoomControlsEnabled: true,
        )
            : Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.directions_bus_outlined, size: 72, color: Colors.grey),
          const SizedBox(height: 12),
          Text('Servis henuz baslamadi', style: TextStyle(color: Colors.grey[500])),
        ]))),

        // Şoför bilgi bandı
        if (_sofor != null) Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          color: Colors.white,
          child: Row(children: [
            Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _navy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.drive_eta, color: _navy, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_sofor!['ad'] ?? 'Sofor',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(_sofor!['aracPlaka'] ?? '',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ])),
            // Mobil uygulama indirme
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: _navy,
                  side: const BorderSide(color: _navy)),
              icon: const Icon(Icons.android_outlined, size: 14),
              label: const Text('Uygulamayi Indir', style: TextStyle(fontSize: 12)),
              onPressed: () async {
                const url = 'https://play.google.com/store/apps/details?id=com.servisim.servisim';
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url));
                }
              },
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _girisEkrani() => Scaffold(
    backgroundColor: _navy,
    body: Center(child: Container(
      width: 420,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 60, height: 60,
            decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(14)),
            child: const Center(child: Text('S',
                style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)))),
        const SizedBox(height: 16),
        const Text('Servisim360', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _navy)),
        const SizedBox(height: 4),
        const Text('Servis takibi icin giris yapin', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: _navy, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          icon: const Icon(Icons.login_outlined),
          label: const Text('Giris Yap', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () => Navigator.pushNamed(context, '/login'),
        )),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: _navy,
              side: const BorderSide(color: _navy),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          icon: const Icon(Icons.app_registration_outlined),
          label: const Text('Kayit Ol', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () => Navigator.pushNamed(context, '/veli_basvuru'),
        )),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.grey,
              side: const BorderSide(color: Colors.grey)),
          icon: const Icon(Icons.android_outlined, size: 14),
          label: const Text('Android Uygulamasini Indir', style: TextStyle(fontSize: 12)),
          onPressed: () async {
            const url = 'https://play.google.com/store/apps/details?id=com.servisim.servisim';
            if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url));
          },
        ),
      ]),
    )),
  );
}
