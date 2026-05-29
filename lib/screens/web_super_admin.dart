import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// ════════════════════════════════════════════════════════════════
//  WEB SUPER ADMIN — 5 sekme
// ════════════════════════════════════════════════════════════════

// ── FİRMALAR ────────────────────────────────────────────────────
class WebSuperAdminFirmalar extends StatefulWidget {
  const WebSuperAdminFirmalar({super.key});
  @override
  State<WebSuperAdminFirmalar> createState() => _WebSuperAdminFirmalarState();
}

class _WebSuperAdminFirmalarState extends State<WebSuperAdminFirmalar> {
  static const _navy   = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);
  String _aramaMetni = '';
  final _aramaCtrl = TextEditingController();

  @override
  void dispose() { _aramaCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      padding: const EdgeInsets.all(16), color: Colors.white,
      child: TextField(
        controller: _aramaCtrl,
        decoration: InputDecoration(
          hintText: 'Firma ara...',
          prefixIcon: const Icon(Icons.search, color: _navy, size: 18),
          filled: true, fillColor: const Color(0xFFF5F7FA),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
        ),
        onChanged: (v) => setState(() => _aramaMetni = v.toLowerCase()),
      ),
    ),
    Expanded(child: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('firms').snapshots(),
      builder: (_, snap) {
        var docs = snap.data?.docs ?? [];
        if (_aramaMetni.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return (data['firmaAdi'] ?? data['ad'] ?? '').toString()
                .toLowerCase().contains(_aramaMetni);
          }).toList();
        }
        if (docs.isEmpty) return const Center(child: Text('Firma bulunamadi'));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final durum = d['durum'] as String? ?? 'aktif';
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)]),
              child: Row(children: [
                Container(width: 44, height: 44,
                    decoration: BoxDecoration(color: _navy.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.business_outlined, color: _navy, size: 22)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d['firmaAdi'] ?? d['ad'] ?? 'Firma',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(d['email'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  Text('Lisans: ${d['lisansAy'] ?? '-'} ay',
                      style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: (durum == 'aktif' ? Colors.green : Colors.red).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(durum, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                        color: durum == 'aktif' ? Colors.green : Colors.red)),
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    _AksiyonBtn('Onayla', Colors.green, Icons.check_circle_outline, () async {
                      await FirebaseFirestore.instance.collection('firms').doc(docs[i].id)
                          .update({'durum': 'aktif'});
                    }),
                    const SizedBox(width: 6),
                    _AksiyonBtn('Askiya Al', Colors.orange, Icons.pause_circle_outline, () async {
                      await FirebaseFirestore.instance.collection('firms').doc(docs[i].id)
                          .update({'durum': 'askida'});
                    }),
                  ]),
                ]),
              ]),
            );
          },
        );
      },
    )),
  ]);
}

class _AksiyonBtn extends StatelessWidget {
  final String label; final Color renk; final IconData ikon; final VoidCallback onTap;
  const _AksiyonBtn(this.label, this.renk, this.ikon, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: renk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Row(children: [
        Icon(ikon, size: 12, color: renk),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, color: renk, fontWeight: FontWeight.bold)),
      ]),
    ),
  );
}

// ── LİSANSLAR ───────────────────────────────────────────────────
class WebSuperAdminLisanslar extends StatelessWidget {
  const WebSuperAdminLisanslar({super.key});
  @override
  Widget build(BuildContext context) => const Center(
    child: Text('Lisans Yonetimi — yakindan geliyor',
        style: TextStyle(color: Colors.grey, fontSize: 16)),
  );
}

// ── GLOBAL HARİTA ───────────────────────────────────────────────
class WebSuperAdminHarita extends StatefulWidget {
  const WebSuperAdminHarita({super.key});
  @override
  State<WebSuperAdminHarita> createState() => _WebSuperAdminHaritaState();
}

class _WebSuperAdminHaritaState extends State<WebSuperAdminHarita> {
  Set<Marker> _markers = {};
  List<Map<String, dynamic>> _aktifSoforler = [];

  @override
  void initState() { super.initState(); _yukle(); }

  Future<void> _yukle() async {
    final snap = await FirebaseFirestore.instance.collection('drivers')
        .where('servisAktif', isEqualTo: true).get();
    final Set<Marker> m = {};
    final List<Map<String, dynamic>> soforler = [];

    for (final d in snap.docs) {
      final data = d.data();
      soforler.add({'id': d.id, ...data});
      final k = data['konum'];
      if (k is GeoPoint) {
        m.add(Marker(
          markerId: MarkerId(d.id),
          position: LatLng(k.latitude, k.longitude),
          infoWindow: InfoWindow(title: data['ad'] ?? 'Sofor'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ));
      }
    }
    if (mounted) setState(() { _markers = m; _aktifSoforler = soforler; });
  }

  @override
  Widget build(BuildContext context) {
    // Web'de GoogleMap JS API gerekiyor — liste göster
    if (kIsWeb) {
      return Column(children: [
        Container(
          padding: const EdgeInsets.all(16), color: Colors.white,
          child: Row(children: [
            Container(width: 10, height: 10,
                decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text('${_markers.length} aktif servis',
                style: const TextStyle(fontWeight: FontWeight.bold,
                    fontSize: 15, color: Color(0xFF1a3a6b))),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.refresh_outlined, size: 14),
              label: const Text('Yenile', style: TextStyle(fontSize: 12)),
              onPressed: _yukle,
            ),
          ]),
        ),
        Expanded(child: _aktifSoforler.isEmpty
            ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.directions_bus_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Text('Aktif servis yok', style: TextStyle(color: Colors.grey)),
        ]))
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _aktifSoforler.length,
          itemBuilder: (_, i) {
            final s = _aktifSoforler[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]),
              child: Row(children: [
                Container(width: 8, height: 8,
                    decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s['ad'] ?? 'Sofor', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(s['aracPlaka'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ])),
                Text('${(s['hiz'] as num? ?? 0).toStringAsFixed(0)} km/s',
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ]),
            );
          },
        )),
      ]);
    }

    // Mobil — Google Map
    return Stack(children: [
      GoogleMap(
        initialCameraPosition: const CameraPosition(target: LatLng(39.1667, 35.6667), zoom: 6),
        markers: _markers,
        onMapCreated: (_) {},
      ),
      Positioned(top: 16, left: 16, child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)]),
        child: Row(children: [
          const Icon(Icons.circle, color: Colors.green, size: 12),
          const SizedBox(width: 6),
          Text('${_markers.length} aktif servis',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
      )),
    ]);
  }
}

// ── KULLANICILAR ─────────────────────────────────────────────────
class WebSuperAdminKullanicilar extends StatelessWidget {
  const WebSuperAdminKullanicilar({super.key});
  @override
  Widget build(BuildContext context) => const Center(
    child: Text('Kullanici Yonetimi — yakindan geliyor',
        style: TextStyle(color: Colors.grey, fontSize: 16)),
  );
}

// ── İSTATİSTİKLER ────────────────────────────────────────────────
class WebSuperAdminIstatistik extends StatelessWidget {
  const WebSuperAdminIstatistik({super.key});
  @override
  Widget build(BuildContext context) => const Center(
    child: Text('Genel Istatistikler — yakindan geliyor',
        style: TextStyle(color: Colors.grey, fontSize: 16)),
  );
}
