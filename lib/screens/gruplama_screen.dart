import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'servis_saati_screen.dart';

// ════════════════════════════════════════════════════════════════
//  GRUPLAMA & ATAMA EKRANI
//  - Harita: tum ogrenciler + soforler pinli
//  - Araclar: her arac kac ogrenci, sofor kim, km
//  - Ogrenciler: listele, araca ata, duzenle
// ════════════════════════════════════════════════════════════════
class GruplamaScreen extends StatefulWidget {
  const GruplamaScreen({super.key});
  @override
  State<GruplamaScreen> createState() => _GruplamaScreenState();
}

class _GruplamaScreenState extends State<GruplamaScreen>
    with SingleTickerProviderStateMixin {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  late TabController _tab;
  GoogleMapController? _mapCtrl;

  String _firmaId = '';
  List<Map<String, dynamic>> _soforler   = [];
  List<Map<String, dynamic>> _ogrenciler = [];
  Set<Marker> _markers = {};
  bool _yukleniyor = true;

  // Her sofor icin renk
  static const List<double> _hues = [
    BitmapDescriptor.hueGreen,  BitmapDescriptor.hueBlue,
    BitmapDescriptor.hueViolet, BitmapDescriptor.hueCyan,
    BitmapDescriptor.hueOrange, BitmapDescriptor.hueRose,
    BitmapDescriptor.hueYellow, BitmapDescriptor.hueAzure,
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _yukle();
  }

  @override
  void dispose() { _tab.dispose(); _mapCtrl?.dispose(); super.dispose(); }

  Future<void> _yukle() async {
    if (mounted) setState(() => _yukleniyor = true);
    try {
      // firmaId al
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance.collection('kullanicilar').doc(uid).get();
        _firmaId = doc.data()?['firmaId'] ?? '';
      }
      if (_firmaId.isEmpty) { setState(() => _yukleniyor = false); return; }

      // Soforler (drivers)
      final soforSnap = await FirebaseFirestore.instance
          .collection('drivers').where('firmaId', isEqualTo: _firmaId).get();
      _soforler = soforSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      // Ogrenciler (aktif + beklemede hepsi)
      final ogrSnap = await FirebaseFirestore.instance
          .collection('students').where('firmaId', isEqualTo: _firmaId).get();
      _ogrenciler = ogrSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      _haritaOlustur();
    } catch (e) {
      debugPrint('Gruplama yukle hata: $e');
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  void _haritaOlustur() {
    final yeni = <Marker>{};

    // Ogrenci markerları — soforId'ye gore renk
    final soforRenk = <String, double>{};
    for (int i = 0; i < _soforler.length; i++) {
      soforRenk[_soforler[i]['id'] as String] = _hues[i % _hues.length];
    }

    for (final ogr in _ogrenciler) {
      final konum = ogr['konum'] as Map<String, dynamic>?;
      if (konum == null) continue;
      final lat = (konum['lat'] ?? konum['latitude'])  as double?;
      final lng = (konum['lng'] ?? konum['longitude']) as double?;
      if (lat == null || lng == null) continue;

      final soforId = ogr['soforId'] as String?;
      final hue = soforId != null
          ? (soforRenk[soforId] ?? BitmapDescriptor.hueRed)
          : BitmapDescriptor.hueRed;

      yeni.add(Marker(
        markerId: MarkerId('ogr_${ogr['id']}'),
        position: LatLng(lat, lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
        infoWindow: InfoWindow(
          title: ogr['ad'] ?? 'Ogrenci',
          snippet: ogr['adres'] ?? '',
        ),
        onTap: () => _ogrenciDetay(ogr),
      ));
    }

    // Sofor markerları
    for (int i = 0; i < _soforler.length; i++) {
      final s = _soforler[i];
      final konum = s['konum'] as Map<String, dynamic>?;
      if (konum == null) continue;
      final lat = (konum['lat'] ?? konum['latitude'])  as double?;
      final lng = (konum['lng'] ?? konum['longitude']) as double?;
      if (lat == null || lng == null) continue;

      yeni.add(Marker(
        markerId: MarkerId('sof_${s['id']}'),
        position: LatLng(lat, lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(_hues[i % _hues.length]),
        infoWindow: InfoWindow(
          title: 'Sofor: ${s['ad'] ?? ''}',
          snippet: s['aracPlaka'] ?? '',
        ),
      ));
    }

    if (mounted) setState(() => _markers = yeni);
  }

  void _ogrenciDetay(Map<String, dynamic> ogr) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OgrenciAtamaSheet(
        ogrenci: ogr, soforler: _soforler,
        onKayit: _yukle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white, elevation: 0,
        title: const Text('Gruplama & Atama', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _yukle),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: _turuncu,
          labelColor: Colors.white, unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.map_outlined,            size: 18), text: 'Harita'),
            Tab(icon: Icon(Icons.directions_bus_outlined, size: 18), text: 'Araclar'),
            Tab(icon: Icon(Icons.people_outline,          size: 18), text: 'Ogrenciler'),
          ],
        ),
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator(color: _navy))
          : TabBarView(controller: _tab, children: [
        _haritaSekmesi(),
        _AraclarSekmesi(firmaId: _firmaId, soforler: _soforler, ogrenciler: _ogrenciler, onGuncelle: _yukle),
        _OgrencilerSekmesi(ogrenciler: _ogrenciler, soforler: _soforler, onAta: _ogrenciDetay, onGuncelle: _yukle),
      ]),
    );
  }

  Widget _haritaSekmesi() {
    return Stack(children: [
      GoogleMap(
        initialCameraPosition: const CameraPosition(target: LatLng(41.0082, 28.9784), zoom: 11),
        markers: _markers,
        onMapCreated: (c) {
          _mapCtrl = c;
          if (_markers.isNotEmpty) {
            Future.delayed(const Duration(milliseconds: 500), () =>
                _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(_markers.first.position, 12)));
          }
        },
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
      ),

      // Stat bant
      Positioned(top: 0, left: 0, right: 0,
        child: Container(
          color: Colors.white.withValues(alpha: 0.95),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            _StatChip('${_ogrenciler.length}', 'Ogrenci', Colors.purple),
            const SizedBox(width: 8),
            _StatChip('${_soforler.length}',  'Sofor',   _navy),
            const SizedBox(width: 8),
            _StatChip(
                '${_ogrenciler.where((o) => o['soforId'] != null).length}',
                'Atanmis', Colors.green),
            const SizedBox(width: 8),
            _StatChip(
                '${_ogrenciler.where((o) => o['soforId'] == null).length}',
                'Atanmamis', Colors.orange),
          ]),
        ),
      ),

      // Zoom butonlari
      Positioned(right: 12, bottom: 30, child: Column(children: [
        _MapBtn(Icons.add,    () => _mapCtrl?.animateCamera(CameraUpdate.zoomIn())),
        const SizedBox(height: 6),
        _MapBtn(Icons.remove, () => _mapCtrl?.animateCamera(CameraUpdate.zoomOut())),
      ])),

      // Bos mesaj
      if (_markers.isEmpty)
        Center(child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(12)),
          child: const Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.location_off_outlined, color: _navy, size: 32),
            SizedBox(height: 8),
            Text('Konumlu kayit yok', style: TextStyle(color: _navy, fontWeight: FontWeight.bold)),
            Text('Ogrencilerin konum bilgisi eklendikce haritada gorunur',
                style: TextStyle(color: Colors.grey, fontSize: 11), textAlign: TextAlign.center),
          ]),
        )),
    ]);
  }
}

class _StatChip extends StatelessWidget {
  final String deger, etiket; final Color renk;
  const _StatChip(this.deger, this.etiket, this.renk);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: renk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(deger, style: TextStyle(color: renk, fontWeight: FontWeight.bold, fontSize: 13)),
      const SizedBox(width: 4),
      Text(etiket, style: TextStyle(color: renk, fontSize: 10)),
    ]),
  );
}

class _MapBtn extends StatelessWidget {
  final IconData ikon; final VoidCallback onTap;
  const _MapBtn(this.ikon, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
      child: Container(width: 38, height: 38,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)]),
          child: Icon(ikon, color: const Color(0xFF1a3a6b), size: 20)));
}

// ════════════════════════════════════════════════════════════════
//  ARACLAR SEKMESİ
// ════════════════════════════════════════════════════════════════
class _AraclarSekmesi extends StatelessWidget {
  final String firmaId;
  final List<Map<String, dynamic>> soforler, ogrenciler;
  final VoidCallback onGuncelle;
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  const _AraclarSekmesi({required this.firmaId, required this.soforler,
    required this.ogrenciler, required this.onGuncelle});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('drivers')
          .where('firmaId', isEqualTo: firmaId).snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return _Bos('Henuz sofor/arac eklenmemis', Icons.directions_bus_outlined);
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d   = docs[i].data() as Map<String, dynamic>;
            final did = docs[i].id;
            final aktif = d['servisAktif'] ?? false;
            final atananOgr = ogrenciler.where((o) => o['soforId'] == did).toList();
            final Color renk = [Colors.blue, Colors.green, Colors.purple,
              Colors.orange, Colors.teal, Colors.red][i % 6];

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: aktif ? Colors.green.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.15)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)]),
              child: Column(children: [
                // Sofor satiri
                Padding(padding: const EdgeInsets.all(14), child: Row(children: [
                  CircleAvatar(radius: 22, backgroundColor: renk.withValues(alpha: 0.1),
                      child: Text((d['ad'] ?? '?')[0].toUpperCase(),
                          style: TextStyle(color: renk, fontWeight: FontWeight.bold, fontSize: 16))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d['ad'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    if ((d['aracPlaka'] ?? '').isNotEmpty)
                      Row(children: [
                        Icon(Icons.directions_bus_outlined, size: 11, color: renk),
                        const SizedBox(width: 3),
                        Text(d['aracPlaka'], style: TextStyle(color: renk, fontSize: 11, fontWeight: FontWeight.w600)),
                      ]),
                    Text('${atananOgr.length} ogrenci', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                  ])),
                  // Aktif toggle
                  Switch(
                    value: aktif, activeColor: Colors.green,
                    onChanged: (v) => FirebaseFirestore.instance.collection('drivers').doc(did).update({'servisAktif': v}),
                  ),
                ])),

                // Atanan ogrenciler
                if (atananOgr.isNotEmpty) ...[
                  Divider(height: 1, color: Colors.grey.withValues(alpha: 0.15)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                    child: Column(children: atananOgr.map((ogr) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(children: [
                        Icon(Icons.person_outline, size: 13, color: renk),
                        const SizedBox(width: 6),
                        Expanded(child: Text(ogr['ad'] ?? '', style: const TextStyle(fontSize: 12))),
                        Text(ogr['adres'] ?? '', style: TextStyle(color: Colors.grey[400], fontSize: 10),
                            overflow: TextOverflow.ellipsis),
                      ]),
                    )).toList()),
                  ),
                ],

                // Butonlar
                Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 10), child: Row(children: [
                  if ((d['telefon'] ?? '').isNotEmpty)
                    GestureDetector(
                      onTap: () async {
                        var n = d['telefon'].replaceAll(RegExp(r'[^0-9]'), '');
                        if (n.startsWith('0')) n = '9$n';
                        if (!n.startsWith('90')) n = '90$n';
                        await launchUrl(Uri.parse('https://wa.me/$n'), mode: LaunchMode.externalApplication);
                      },
                      child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: const Color(0xFF25D366).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Row(children: [
                            Icon(Icons.message_outlined, size: 13, color: Color(0xFF25D366)),
                            SizedBox(width: 4),
                            Text('WhatsApp', style: TextStyle(color: Color(0xFF25D366), fontSize: 11)),
                          ])),
                    ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => SoforAyarSheet(
                        soforId: did,
                        soforData: {...d, 'id': did},
                        onGuncelle: onGuncelle,
                      ),
                    ),
                    child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: _navy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                        child: const Row(children: [
                          Icon(Icons.settings_outlined, size: 13, color: _navy),
                          SizedBox(width: 4),
                          Text('Ayar', style: TextStyle(color: _navy, fontSize: 11)),
                        ])),
                  ),
                ])),
              ]),
            );
          },
        );
      },
    );
  }

  void _soforDuzenle(BuildContext context, String docId, Map<String, dynamic> d) {
    final adCtrl    = TextEditingController(text: d['ad'] ?? '');
    final telCtrl   = TextEditingController(text: d['telefon'] ?? '');
    final plakaCtrl = TextEditingController(text: d['aracPlaka'] ?? '');
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Sofor Duzenle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _navy)),
          const SizedBox(height: 14),
          _GrupAlan(adCtrl, 'Ad Soyad', Icons.person_outline),
          const SizedBox(height: 8),
          _GrupAlan(telCtrl, 'Telefon', Icons.phone_outlined, tipi: TextInputType.phone),
          const SizedBox(height: 8),
          _GrupAlan(plakaCtrl, 'Arac Plakasi', Icons.directions_bus_outlined),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(
                onPressed: () async {
                  await FirebaseFirestore.instance.collection('drivers').doc(docId).delete();
                  if (context.mounted) Navigator.pop(context);
                  onGuncelle();
                },
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                child: const Text('Sil'))),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
                onPressed: () async {
                  await FirebaseFirestore.instance.collection('drivers').doc(docId).update({
                    'ad': adCtrl.text.trim(),
                    'telefon': telCtrl.text.trim(),
                    'aracPlaka': plakaCtrl.text.trim().toUpperCase(),
                  });
                  if (context.mounted) Navigator.pop(context);
                  onGuncelle();
                },
                child: const Text('Kaydet'))),
          ]),
        ])),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  OGRENCİLER SEKMESİ
// ════════════════════════════════════════════════════════════════
class _OgrencilerSekmesi extends StatefulWidget {
  final List<Map<String, dynamic>> ogrenciler, soforler;
  final void Function(Map<String, dynamic>) onAta;
  final VoidCallback onGuncelle;
  const _OgrencilerSekmesi({required this.ogrenciler, required this.soforler,
    required this.onAta, required this.onGuncelle});
  @override
  State<_OgrencilerSekmesi> createState() => _OgrencilerSekmesiState();
}

class _OgrencilerSekmesiState extends State<_OgrencilerSekmesi> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  String _filtre = 'hepsi';
  String _arama  = '';

  @override
  Widget build(BuildContext context) {
    final liste = widget.ogrenciler.where((o) {
      if (_filtre == 'atanmis'   && (o['soforId'] == null || o['soforId'] == '')) return false;
      if (_filtre == 'atanmamis' && (o['soforId'] != null && o['soforId'] != '')) return false;
      if (_arama.isNotEmpty &&
          !(o['ad'] ?? '').toString().toLowerCase().contains(_arama.toLowerCase())) return false;
      return true;
    }).toList();

    return Column(children: [
      // Arama + filtre
      Container(color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: Column(children: [
          TextField(
            onChanged: (v) => setState(() => _arama = v),
            decoration: InputDecoration(
                hintText: 'Ogrenci ara...',
                prefixIcon: const Icon(Icons.search, size: 19),
                filled: true, fillColor: const Color(0xFFF5F7FA),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 10)),
          ),
          const SizedBox(height: 8),
          Row(children: [
            _FiltrBtn('Hepsi',     'hepsi',     _filtre, (v) => setState(() => _filtre = v)),
            const SizedBox(width: 8),
            _FiltrBtn('Atanmis',   'atanmis',   _filtre, (v) => setState(() => _filtre = v)),
            const SizedBox(width: 8),
            _FiltrBtn('Atanmamis', 'atanmamis', _filtre, (v) => setState(() => _filtre = v)),
          ]),
        ]),
      ),

      Expanded(child: liste.isEmpty
          ? _Bos('Ogrenci bulunamadi', Icons.search_off_outlined)
          : ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
        itemCount: liste.length,
        itemBuilder: (_, i) {
          final ogr     = liste[i];
          final soforId = ogr['soforId'] as String?;
          final sofor   = soforId != null
              ? widget.soforler.firstWhere((s) => s['id'] == soforId, orElse: () => {})
              : null;
          final atanmis = sofor != null && sofor.isNotEmpty;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: atanmis ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]),
            child: Row(children: [
              CircleAvatar(radius: 18,
                  backgroundColor: atanmis ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                  child: Text((ogr['ad'] ?? '?')[0].toUpperCase(),
                      style: TextStyle(color: atanmis ? Colors.green : Colors.orange, fontWeight: FontWeight.bold))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ogr['ad'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(ogr['adres'] ?? '', style: TextStyle(color: Colors.grey[500], fontSize: 11), overflow: TextOverflow.ellipsis),
                if (atanmis)
                  Text('Sofor: ${sofor!['ad'] ?? ''}',
                      style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w600)),
              ])),
              Row(children: [
                // Duzenle
                GestureDetector(
                    onTap: () => _ogrenciDuzenle(context, ogr),
                    child: Container(padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: _navy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.edit_outlined, size: 15, color: _navy))),
                const SizedBox(width: 6),
                // Ata
                GestureDetector(
                    onTap: () => widget.onAta(ogr),
                    child: Container(padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: _turuncu.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.directions_bus_outlined, size: 15, color: _turuncu))),
              ]),
            ]),
          );
        },
      )),
    ]);
  }

  void _ogrenciDuzenle(BuildContext ctx, Map<String, dynamic> ogr) {
    final adCtrl    = TextEditingController(text: ogr['ad'] ?? '');
    final adresCtrl = TextEditingController(text: ogr['adres'] ?? '');
    final vaCtrl    = TextEditingController(text: ogr['veliAd'] ?? '');
    final vtCtrl    = TextEditingController(text: ogr['veliTel'] ?? '');
    showModalBottomSheet(
      context: ctx, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Ogrenci Duzenle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _navy)),
          const SizedBox(height: 14),
          _GrupAlan(adCtrl,    'Ogrenci Adi',   Icons.school_outlined),
          const SizedBox(height: 8),
          _GrupAlan(adresCtrl, 'Adres',          Icons.location_on_outlined),
          const SizedBox(height: 8),
          _GrupAlan(vaCtrl,    'Veli Adi',       Icons.person_outline),
          const SizedBox(height: 8),
          _GrupAlan(vtCtrl,    'Veli Telefon',   Icons.phone_outlined, tipi: TextInputType.phone),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(
                onPressed: () async {
                  await FirebaseFirestore.instance.collection('students').doc(ogr['id']).delete();
                  if (ctx.mounted) Navigator.pop(ctx);
                  widget.onGuncelle();
                },
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                child: const Text('Sil'))),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
                onPressed: () async {
                  await FirebaseFirestore.instance.collection('students').doc(ogr['id']).update({
                    'ad': adCtrl.text.trim(),
                    'adres': adresCtrl.text.trim(),
                    'veliAd': vaCtrl.text.trim(),
                    'veliTel': vtCtrl.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  widget.onGuncelle();
                },
                child: const Text('Kaydet'))),
          ]),
        ])),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  OGRENCİ ATAMA SHEET
// ════════════════════════════════════════════════════════════════
class _OgrenciAtamaSheet extends StatefulWidget {
  final Map<String, dynamic> ogrenci;
  final List<Map<String, dynamic>> soforler;
  final VoidCallback onKayit;
  const _OgrenciAtamaSheet({required this.ogrenci, required this.soforler, required this.onKayit});
  @override
  State<_OgrenciAtamaSheet> createState() => _OgrenciAtamaSheetState();
}

class _OgrenciAtamaSheetState extends State<_OgrenciAtamaSheet> {
  static const _navy = Color(0xFF1a3a6b);
  String? _secili;
  bool _yukleniyor = false;

  @override
  void initState() {
    super.initState();
    _secili = widget.ogrenci['soforId'] as String?;
  }

  Future<void> _kaydet() async {
    setState(() => _yukleniyor = true);
    try {
      await FirebaseFirestore.instance.collection('students').doc(widget.ogrenci['id']).update({
        'soforId': _secili,
        'soforAd': _secili != null
            ? (widget.soforler.firstWhere((s) => s['id'] == _secili, orElse: () => {})['ad'] ?? '')
            : null,
      });
      if (mounted) {
        Navigator.pop(context);
        widget.onKayit();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Atama kaydedildi!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          Row(children: [
            CircleAvatar(radius: 20, backgroundColor: _navy.withValues(alpha: 0.1),
                child: Text((widget.ogrenci['ad'] ?? '?')[0].toUpperCase(),
                    style: const TextStyle(color: _navy, fontWeight: FontWeight.bold))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.ogrenci['ad'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text(widget.ogrenci['adres'] ?? '', style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  overflow: TextOverflow.ellipsis),
            ])),
          ]),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            value: _secili,
            decoration: InputDecoration(
              labelText: 'Sofor / Arac Sec',
              prefixIcon: const Icon(Icons.directions_bus_outlined, color: _navy),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _navy, width: 2)),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Atamayı Kaldir', style: TextStyle(color: Colors.red))),
              ...widget.soforler.map((s) => DropdownMenuItem(
                value: s['id'] as String,
                child: Text('${s['ad'] ?? 'Sofor'} — ${s['aracPlaka'] ?? ''}',
                    style: const TextStyle(fontSize: 13)),
              )),
            ],
            onChanged: (v) => setState(() => _secili = v),
          ),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _navy, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: _yukleniyor ? null : _kaydet,
            child: _yukleniyor
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          )),
        ]),
      ),
    );
  }
}

// ── Ortak ────────────────────────────────────────────────────────
class _FiltrBtn extends StatelessWidget {
  final String etiket, deger, secili; final ValueChanged<String> onSec;
  static const _navy = Color(0xFF1a3a6b);
  const _FiltrBtn(this.etiket, this.deger, this.secili, this.onSec);
  @override
  Widget build(BuildContext context) {
    final aktif = secili == deger;
    return GestureDetector(onTap: () => onSec(deger),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
              color: aktif ? _navy : const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(20)),
          child: Text(etiket, style: TextStyle(
              color: aktif ? Colors.white : Colors.grey[600],
              fontSize: 12, fontWeight: aktif ? FontWeight.bold : FontWeight.normal)),
        ));
  }
}

class _GrupAlan extends StatelessWidget {
  final TextEditingController ctrl;
  final String label; final IconData ikon; final TextInputType tipi;
  static const _navy = Color(0xFF1a3a6b);
  const _GrupAlan(this.ctrl, this.label, this.ikon, {this.tipi = TextInputType.text});
  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl, keyboardType: tipi,
    decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(ikon, color: _navy, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _navy, width: 2)),
        contentPadding: const EdgeInsets.all(12),
        filled: true, fillColor: Colors.white),
  );
}

Widget _Bos(String mesaj, IconData ikon) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
  Icon(ikon, size: 64, color: Colors.grey[300]),
  const SizedBox(height: 12),
  Text(mesaj, style: TextStyle(color: Colors.grey[500], fontSize: 14)),
]));

// OtomatikRotaButonu - placeholder
class OtomatikRotaButonu extends StatelessWidget {
  const OtomatikRotaButonu({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
