// ╔══════════════════════════════════════════════════════════════╗
// ║  DOSYA: lib/screens/konum_toplama_screen.dart
// ║  PROJE: servisim360
// ╚══════════════════════════════════════════════════════════════╝
import 'package:flutter/material.dart';
import 'yardim_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class KonumToplamaScreen extends StatefulWidget {
  const KonumToplamaScreen({super.key});

  @override
  State<KonumToplamaScreen> createState() => _KonumToplamaScreenState();
}

class _KonumToplamaScreenState extends State<KonumToplamaScreen> {
  static const navyBlue = Color(0xFF1a3a6b);
  static const turuncu = Color(0xFFFF8C00);

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  GoogleMapController? _mapController;
  String? _firmaId;
  String  _projeId  = '';
  String  _projeAdi = '';
  bool _yukleniyor = true;

  List<Map<String, dynamic>> _ogrenciler = [];
  Map<String, dynamic>? _seciliOgrenci;
  LatLng? _seciliKonum;
  final Set<Marker> _markers = {};
  bool _kaydediliyor = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await _db.collection('kullanicilar').doc(uid).get();
    if (!doc.exists) return;
    final firmaId = doc.data()?['firmaId'] ?? '';
    setState(() => _firmaId = firmaId);
    if (firmaId.isNotEmpty) {
      final snap = await _db
          .collection('firms')
          .doc(firmaId)
          .collection('students')
          .get();
      _ogrenciler =
          snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      // Mevcut konumlu ogrencileri haritaya ekle
      for (final o in _ogrenciler) {
        if (o['lat'] != null && o['lng'] != null) {
          _markers.add(Marker(
            markerId: MarkerId(o['id']),
            position: LatLng(
                (o['lat'] as num).toDouble(), (o['lng'] as num).toDouble()),
            infoWindow: InfoWindow(
                title: '${o['ad']} ${o['soyad']}',
                snippet: o['adres'] ?? ''),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen),
          ));
        }
      }
    }
    setState(() => _yukleniyor = false);
  }

  Future<void> _konumAl() async {
    try {
      LocationPermission izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied) {
        izin = await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() => _seciliKonum = latLng);
      _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(latLng, 16));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Konum alinamadi: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _konumKaydet() async {
    if (_firmaId == null || _seciliOgrenci == null || _seciliKonum == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Ogrenci ve konum secin.'),
            backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _kaydediliyor = true);
    await _db
        .collection('firms')
        .doc(_firmaId)
        .collection('students')
        .doc(_seciliOgrenci!['id'])
        .update({
      'lat': _seciliKonum!.latitude,
      'lng': _seciliKonum!.longitude,
    });
    setState(() {
      _kaydediliyor = false;
      _markers.removeWhere(
              (m) => m.markerId.value == _seciliOgrenci!['id']);
      _markers.add(Marker(
        markerId: MarkerId(_seciliOgrenci!['id']),
        position: _seciliKonum!,
        infoWindow: InfoWindow(
            title:
            '${_seciliOgrenci!['ad']} ${_seciliOgrenci!['soyad']}'),
        icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen),
      ));
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Konum kaydedildi.'),
            backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: navyBlue,
        actions: [YardimButonu(ekranAdi: 'Harita'), const SizedBox(width:8)],
        title: const Text('Konum Toplama',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(color: turuncu, height: 2),
        ),
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Kontrol paneli
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Ogrenci Sec',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  value: _seciliOgrenci?['id'],
                  items: _ogrenciler.map((o) {
                    return DropdownMenuItem<String>(
                      value: o['id'],
                      child: Text(
                          '${o['ad'] ?? ''} ${o['soyad'] ?? ''}'
                              .trim()),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _seciliOgrenci = _ogrenciler.firstWhere(
                              (o) => o['id'] == val,
                          orElse: () => {});
                    });
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: navyBlue,
                            foregroundColor: Colors.white),
                        icon: const Icon(Icons.my_location, size: 18),
                        label: const Text('Konum Al'),
                        onPressed: _konumAl,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white),
                        icon: _kaydediliyor
                            ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2))
                            : const Icon(Icons.save, size: 18),
                        label: const Text('Kaydet'),
                        onPressed:
                        _kaydediliyor ? null : _konumKaydet,
                      ),
                    ),
                  ],
                ),
                if (_seciliKonum != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Secili: ${_seciliKonum!.latitude.toStringAsFixed(5)}, ${_seciliKonum!.longitude.toStringAsFixed(5)}',
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
          // Harita
          Expanded(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                  target: LatLng(39.9208, 32.8541), zoom: 11),
              markers: {
                ..._markers,
                if (_seciliKonum != null)
                  Marker(
                    markerId: const MarkerId('secili'),
                    position: _seciliKonum!,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueRed),
                    infoWindow: const InfoWindow(title: 'Secili Konum'),
                  ),
              },
              onMapCreated: (c) => _mapController = c,
              onTap: (pos) => setState(() => _seciliKonum = pos),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            ),
          ),
        ],
      ),
    );
  }
}
