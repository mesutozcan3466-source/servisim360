// ════════════════════════════════════════════════════════════════════════════
//  admin_arac_takip_screen.dart
// ════════════════════════════════════════════════════════════════════════════
// ignore_for_file: file_names
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/session_service.dart';

class AdminAracTakipScreen extends StatefulWidget {
  const AdminAracTakipScreen({super.key});
  @override
  State<AdminAracTakipScreen> createState() => _AdminAracTakipScreenState();
}

class _AdminAracTakipScreenState extends State<AdminAracTakipScreen> {
  static const _navy = Color(0xFF1a3a6b);
  GoogleMapController? _mapCtrl;
  Set<Marker> _markers = {};
  String? _firmaId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _firmaId = await SessionService.instance.firmaldAl();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _mapCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white,
        title: const Text('Canlı Araç Takip', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _firmaId == null
          ? const Center(child: CircularProgressIndicator(color: _navy))
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('drivers')
            .where('firmaId', isEqualTo: _firmaId)
            .where('servisAktif', isEqualTo: true)
            .snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          final markers = <Marker>{};
          for (final doc in docs) {
            final data  = doc.data() as Map<String, dynamic>;
            final konum = data['konum'];
            if (konum is! GeoPoint) continue;
            markers.add(Marker(
              markerId: MarkerId(doc.id),
              position: LatLng(konum.latitude, konum.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
              infoWindow: InfoWindow(
                title: data['ad'] ?? 'Şoför',
                snippet: data['aracPlaka'] ?? '',
              ),
            ));
          }
          return Stack(children: [
            GoogleMap(
              initialCameraPosition: const CameraPosition(
                  target: LatLng(39.9334, 32.8597), zoom: 12),
              markers: markers,
              onMapCreated: (c) => _mapCtrl = c,
              zoomControlsEnabled: true,
              myLocationButtonEnabled: false,
            ),
            Positioned(
              top: 12, left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6)],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 8, height: 8, margin: const EdgeInsets.only(right: 6),
                      decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                  Text('${docs.length} aktif araç',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
