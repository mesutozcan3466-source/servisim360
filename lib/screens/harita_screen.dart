import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/session_service.dart';

class HaritaScreen extends StatefulWidget {
  const HaritaScreen({super.key});
  @override
  State<HaritaScreen> createState() => _HaritaScreenState();
}

class _HaritaScreenState extends State<HaritaScreen> {
  static const _navy = Color(0xFF1a3a6b);
  GoogleMapController? _mapCtrl;
  Set<Marker>   _markers   = {};
  Set<Polyline> _polylines = {};
  String? _firmaId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _firmaId = await SessionService.instance.firmaldAl();
    await _yukle();
  }

  Future<void> _yukle() async {
    if (_firmaId == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('students')
        .where('firmaId', isEqualTo: _firmaId)
        .get();

    final yeni = <Marker>{};
    for (final doc in snap.docs) {
      final data  = doc.data();
      final konum = data['konum'];
      if (konum is! GeoPoint) continue;
      yeni.add(Marker(
        markerId: MarkerId(doc.id),
        position: LatLng(konum.latitude, konum.longitude),
        infoWindow: InfoWindow(
          title: data['ad'] ?? 'Öğrenci',
          snippet: data['adres'] ?? '',
        ),
      ));
    }
    if (mounted) setState(() => _markers = yeni);
  }

  @override
  void dispose() { _mapCtrl?.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white,
        title: const Text('Harita', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _yukle)],
      ),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
            target: LatLng(39.9334, 32.8597), zoom: 12),
        markers:   _markers,
        polylines: _polylines,
        onMapCreated: (c) => _mapCtrl = c,
        zoomControlsEnabled: true,
        myLocationButtonEnabled: false,
      ),
    );
  }
}