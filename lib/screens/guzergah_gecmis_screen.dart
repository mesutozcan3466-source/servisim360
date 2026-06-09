import 'package:flutter/material.dart';
import 'yardim_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/guzergah_kayit_service.dart';
import '../services/session_service.dart';

class GuzergahGecmisScreen extends StatefulWidget {
  const GuzergahGecmisScreen({super.key});

  @override
  State<GuzergahGecmisScreen> createState() => _GuzergahGecmisScreenState();
}

class _GuzergahGecmisScreenState extends State<GuzergahGecmisScreen> {
  static const _navy = Color(0xFF1a3a6b);

  String? _firmaId;
  String  _projeId  = '';
  String  _projeAdi = '';
  String? _seciliSurucuId;
  String? _seciliSurucuAd;
  List<Map<String, dynamic>> _suruculer = [];
  bool _yukleniyor = true;
  int _seciligGunIndex = 0;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    _firmaId  = await SessionService.instance.firmaIdAl();
    _projeId  = SessionService.instance.aktifProjeId  ?? '';
    _projeAdi = SessionService.instance.aktifProjeAdi ?? '';
    if (_firmaId == null) return;

    // drivers koleksiyonu — Servisim360 yeni yapısı
    final snap = await FirebaseFirestore.instance
        .collection('drivers')
        .where('firmaId', isEqualTo: _firmaId)
        .get();

    if (mounted) {
      setState(() {
        _suruculer = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        if (_suruculer.isNotEmpty) {
          _seciliSurucuId = _suruculer[0]['id'];
          _seciliSurucuAd = _suruculer[0]['ad'];
        }
        _yukleniyor = false;
      });
    }
  }

  String _gunTarih(int index) {
    final gun = DateTime.now().subtract(Duration(days: index));
    return '${gun.year}-${gun.month.toString().padLeft(2, '0')}-${gun.day.toString().padLeft(2, '0')}';
  }

  String _gunEtiketi(int index) {
    switch (index) {
      case 0:  return 'Bugün';
      case 1:  return 'Dün';
      default: return '$index gün önce';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white, elevation: 0,
        title: const Text('Güzergah Geçmişi',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          YardimButonu(ekranAdi: 'Raporlar'),
          IconButton(
            icon: const Icon(Icons.cleaning_services_outlined),
            tooltip: 'Eski kayıtları temizle',
            onPressed: () async {
              if (_firmaId != null) {
                await GuzergahKayitService.eskiKayitlariTemizle(_firmaId!);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Eski kayıtlar temizlendi.'),
                        backgroundColor: Colors.green),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator(color: _navy))
          : Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(children: [
            DropdownButtonFormField<String>(
              value: _seciliSurucuId,
              decoration: InputDecoration(
                labelText: 'Şoför',
                prefixIcon: const Icon(Icons.drive_eta, color: _navy, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _navy, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: _suruculer.map((s) => DropdownMenuItem(
                value: s['id'] as String,
                child: Text(s['ad'] ?? 'Şoför'),
              )).toList(),
              onChanged: (v) => setState(() {
                _seciliSurucuId = v;
                _seciliSurucuAd = _suruculer.firstWhere((s) => s['id'] == v)['ad'];
              }),
            ),
            const SizedBox(height: 10),
            Row(
              children: List.generate(4, (i) {
                final secili = _seciligGunIndex == i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _seciligGunIndex = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: secili ? _navy : const Color(0xFFF0F2F5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _gunEtiketi(i),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: secili ? Colors.white : Colors.grey[600],
                          fontSize: 11,
                          fontWeight: secili ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ]),
        ),
        Expanded(
          child: _seciliSurucuId == null
              ? const Center(child: Text('Şoför seçin'))
              : _GuzergahDetay(
            surucuId:   _seciliSurucuId!,
            surucuAd:   _seciliSurucuAd ?? '',
            tarih:      _gunTarih(_seciligGunIndex),
            gunEtiketi: _gunEtiketi(_seciligGunIndex),
          ),
        ),
      ]),
    );
  }
}

class _GuzergahDetay extends StatefulWidget {
  final String surucuId, surucuAd, tarih, gunEtiketi;
  const _GuzergahDetay({required this.surucuId, required this.surucuAd,
    required this.tarih, required this.gunEtiketi});

  @override
  State<_GuzergahDetay> createState() => _GuzergahDetayState();
}

class _GuzergahDetayState extends State<_GuzergahDetay> {
  static const _navy = Color(0xFF1a3a6b);

  GoogleMapController? _mapCtrl;
  List<Map<String, dynamic>> _oturumlar = [];
  Map<String, dynamic>? _seciliOturum;
  Set<Polyline> _polylines = {};
  Set<Marker>   _markers   = {};
  bool _yukleniyor = true;

  @override
  void initState() { super.initState(); _oturumlariYukle(); }

  @override
  void didUpdateWidget(_GuzergahDetay old) {
    super.didUpdateWidget(old);
    if (old.tarih != widget.tarih || old.surucuId != widget.surucuId) {
      _oturumlariYukle();
    }
  }

  Future<void> _oturumlariYukle() async {
    setState(() => _yukleniyor = true);
    _oturumlar = await GuzergahKayitService.gunOturumlari(
        surucuId: widget.surucuId, tarih: widget.tarih);
    if (_oturumlar.isNotEmpty) {
      await _oturumSecildi(_oturumlar[0]);
    } else {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _oturumSecildi(Map<String, dynamic> oturum) async {
    setState(() { _seciliOturum = oturum; _yukleniyor = true; });

    final docId = '${widget.surucuId}_${widget.tarih}';
    final doc = await FirebaseFirestore.instance
        .collection('guzergah_kayitlar').doc(docId).get();

    if (!doc.exists) { if (mounted) setState(() => _yukleniyor = false); return; }

    final noktalar = (doc.data()?['noktalar'] as List<dynamic>?) ?? [];
    if (noktalar.isEmpty) { if (mounted) setState(() => _yukleniyor = false); return; }

    final latLngListesi = noktalar.map((n) =>
        LatLng((n['lat'] as num).toDouble(), (n['lng'] as num).toDouble())).toList();

    final polyline = Polyline(
      polylineId: const PolylineId('guzergah'),
      points: latLngListesi, color: _navy, width: 4, patterns: [],
    );

    final markers = <Marker>{};
    if (latLngListesi.isNotEmpty) {
      markers.add(Marker(
        markerId: const MarkerId('baslangic'), position: latLngListesi.first,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Başlangıç'),
      ));
      if (latLngListesi.length > 1) {
        markers.add(Marker(
          markerId: const MarkerId('bitis'), position: latLngListesi.last,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Bitiş'),
        ));
      }
    }

    if (mounted) setState(() { _polylines = {polyline}; _markers = markers; _yukleniyor = false; });

    if (_mapCtrl != null && latLngListesi.isNotEmpty) {
      _mapCtrl!.animateCamera(CameraUpdate.newLatLngBounds(_sinirHesapla(latLngListesi), 60));
    }
  }

  LatLngBounds _sinirHesapla(List<LatLng> n) {
    double minLat = n.first.latitude, maxLat = n.first.latitude;
    double minLng = n.first.longitude, maxLng = n.first.longitude;
    for (final p in n) {
      if (p.latitude  < minLat) minLat = p.latitude;
      if (p.latitude  > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
  }

  String _saatFormat(Timestamp? ts) {
    if (ts == null) return '--:--';
    final dt = ts.toDate();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) return const Center(child: CircularProgressIndicator(color: _navy));
    if (_oturumlar.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.route, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 12),
        Text('${widget.gunEtiketi} için kayıt bulunamadı',
            style: TextStyle(color: Colors.grey[500], fontSize: 14)),
        const SizedBox(height: 6),
        Text(widget.surucuAd,
            style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.w600)),
      ]));
    }

    return Column(children: [
      if (_oturumlar.length > 1)
        Container(
          height: 50, color: Colors.white,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: _oturumlar.length,
            itemBuilder: (_, i) {
              final o = _oturumlar[i];
              final secili = _seciliOturum?['id'] == o['id'];
              return GestureDetector(
                onTap: () => _oturumSecildi(o),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: secili ? _navy : const Color(0xFFF0F2F5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Sefer ${i + 1}  ${_saatFormat(o['baslangic'] as Timestamp?)}',
                    style: TextStyle(
                      color: secili ? Colors.white : Colors.grey[600],
                      fontSize: 11,
                      fontWeight: secili ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      if (_seciliOturum != null)
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            _StatKutu(ikon: Icons.access_time_outlined, etiket: 'Başlangıç',
                deger: _saatFormat(_seciliOturum!['baslangic'] as Timestamp?), renk: Colors.green),
            const SizedBox(width: 10),
            _StatKutu(ikon: Icons.flag_outlined, etiket: 'Bitiş',
                deger: _saatFormat(_seciliOturum!['bitis'] as Timestamp?), renk: Colors.red),
            const SizedBox(width: 10),
            _StatKutu(ikon: Icons.straighten_outlined, etiket: 'Toplam',
                deger: '${(_seciliOturum!['toplamKm'] ?? 0.0).toStringAsFixed(1)} km', renk: _navy),
          ]),
        ),
      Expanded(
        child: GoogleMap(
          initialCameraPosition: const CameraPosition(target: LatLng(39.9334, 32.8597), zoom: 12),
          polylines: _polylines, markers: _markers,
          onMapCreated: (c) {
            _mapCtrl = c;
            if (_polylines.isNotEmpty) {
              final noktalar = _polylines.first.points;
              if (noktalar.isNotEmpty) {
                c.animateCamera(CameraUpdate.newLatLngBounds(_sinirHesapla(noktalar), 60));
              }
            }
          },
          zoomControlsEnabled: true, myLocationButtonEnabled: false, mapToolbarEnabled: false,
        ),
      ),
    ]);
  }
}

class _StatKutu extends StatelessWidget {
  final IconData ikon; final String etiket, deger; final Color renk;
  const _StatKutu({required this.ikon, required this.etiket, required this.deger, required this.renk});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(color: renk.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Icon(ikon, color: renk, size: 16), const SizedBox(height: 2),
        Text(deger, style: TextStyle(color: renk, fontWeight: FontWeight.bold, fontSize: 13)),
        Text(etiket, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
      ]),
    ),
  );
}
