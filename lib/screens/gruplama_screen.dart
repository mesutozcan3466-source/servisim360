import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/session_service.dart';

// ════════════════════════════════════════════════════════════════
//  GRUPLAMA & ATAMA EKRANI  —  Sadece Firma Admin
//
//  HARİTA SEKMESİ ÖZELLİKLERİ:
//  ─────────────────────────────
//  • Tüm öğrenci/personel konumları — tek tık aç/kapa
//  • Servislere böl  — yakınlık bazlı K-Means otomatik gruplama
//  • Bölgelere böl   — haritada çember çizerek manuel bölge
//  • Manuel böl      — tek tek marker tıklayarak seç + şoföre ata
//  • Uzaklık/yakınlık filtresi — okula en uzak/yakın önce sırala
//  • Rota çizgisi — atanan şoföre göre renk, tek tık aç/kapa
//  • Her şoför farklı renk, legend gösterimi
//  • Marker detay kartı — tap açar, ata/düzenle/navigasyon
// ════════════════════════════════════════════════════════════════
class GruplamaScreen extends StatefulWidget {
  const GruplamaScreen({super.key});
  @override
  State<GruplamaScreen> createState() => _GruplamaScreenState();
}

class _GruplamaScreenState extends State<GruplamaScreen>
    with SingleTickerProviderStateMixin {
  static const _navy    = Color(0xFF1a3a6b);
  static const _orange  = Color(0xFFFF8C00);

  late TabController _tab;
  GoogleMapController? _mapCtrl;

  String _firmaId = '';
  String _projeId = '';
  List<Map<String, dynamic>> _soforler   = [];
  List<Map<String, dynamic>> _ogrenciler = [];
  bool _yukleniyor = true;

  // Harita
  Set<Marker>   _markers   = {};
  Set<Polyline> _polylines = {};
  Set<Circle>   _circles   = {};

  // Katman toggle
  bool _ogrenciKatman = true;   // öğrenciler görünüyor mu
  bool _servisKatman  = true;   // şoförler görünüyor mu
  bool _rotaKatman    = false;  // rota çizgisi

  // Bölüm modu
  String _mod = 'normal'; // normal | cercle | manuel
  double _cerclYaricap = 1000;
  LatLng? _cerclMerkez;
  List<String> _manuelSecilen = [];

  // Seçili detay
  Map<String, dynamic>? _seciliDetay;
  String _seciliTip = ''; // ogrenci | sofor

  // Renk paleti
  static const List<Color> _renkler = [
    Color(0xFF2196F3), Color(0xFF4CAF50), Color(0xFFE91E63),
    Color(0xFF9C27B0), Color(0xFFFF9800), Color(0xFF00BCD4),
    Color(0xFFFF5722), Color(0xFF795548), Color(0xFF607D8B),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _yukle();
  }

  @override
  void dispose() { _tab.dispose(); _mapCtrl?.dispose(); super.dispose(); }

  // ── VERİ ──────────────────────────────────────────────────────
  Future<void> _yukle() async {
    if (mounted) setState(() => _yukleniyor = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance
            .collection('kullanicilar').doc(uid).get();
        _firmaId = doc.data()?['firmaId'] ?? '';
      }
      _firmaId = _firmaId.isEmpty
          ? (await SessionService.instance.firmaIdAl() ?? '')
          : _firmaId;
      _projeId = SessionService.instance.aktifProjeld ?? '';

      if (_firmaId.isEmpty) { setState(() => _yukleniyor = false); return; }

      final sSnap = await FirebaseFirestore.instance
          .collection('drivers').where('firmaId', isEqualTo: _firmaId).get();
      _soforler = sSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      var q = FirebaseFirestore.instance.collection('students')
          .where('firmaId', isEqualTo: _firmaId);
      if (_projeId.isNotEmpty) q = q.where('projeId', isEqualTo: _projeId);
      final oSnap = await q.get();
      _ogrenciler = oSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      _haritaOlustur();
    } catch (e) { debugPrint('Gruplama yukle: $e'); }
    finally { if (mounted) setState(() => _yukleniyor = false); }
  }

  // ── HARİTA OLUŞTUR ────────────────────────────────────────────
  void _haritaOlustur() {
    final Set<Marker>   yeni  = {};
    final Set<Polyline> yeniP = {};
    final Set<Circle>   yeniC = {};

    // Şoför renk haritası
    final Map<String, Color> soforRenk = {};
    for (int i = 0; i < _soforler.length; i++) {
      soforRenk[_soforler[i]['id'] as String] = _renkler[i % _renkler.length];
    }

    // ── ÖĞRENCİ MARKERLERİ ──
    if (_ogrenciKatman) {
      for (final ogr in _ogrenciler) {
        final konum = _konumAl(ogr); if (konum == null) continue;
        final surucuId  = (ogr['surucuId'] ?? ogr['soforId'] ?? '').toString();
        final secili    = _manuelSecilen.contains(ogr['id'] as String);
        final renk      = surucuId.isNotEmpty
            ? (soforRenk[surucuId] ?? Colors.red) : Colors.red;
        final hue       = secili
            ? BitmapDescriptor.hueYellow : _colorToHue(renk);

        // Atanmış servis adını marker snippet'ine yaz
        final soforObj = surucuId.isNotEmpty
            ? _soforler.firstWhere((s) => s['id'] == surucuId, orElse: () => {})
            : <String,dynamic>{};
        final soforAdKisa = soforObj.isNotEmpty
            ? '${soforObj['ad'] ?? ''} (${soforObj['aracPlaka'] ?? ''})'
            : '';

        yeni.add(Marker(
          markerId: MarkerId('o_${ogr['id']}'),
          position: konum,
          icon: BitmapDescriptor.defaultMarkerWithHue(hue),
          infoWindow: InfoWindow(
            title: ogr['ad'] ?? 'Ogrenci',
            snippet: surucuId.isNotEmpty
                ? 'Servis: $soforAdKisa'
                : ' Servis ATANMAMIS',
          ),
          onTap: () => _markerTap(ogr, 'ogrenci'),
          zIndex: secili ? 3.0 : (surucuId.isNotEmpty ? 1.5 : 1.0),
        ));
      }
    }

    // ── ŞOFÖR MARKERLERİ ──
    if (_servisKatman) {
      for (int i = 0; i < _soforler.length; i++) {
        final s     = _soforler[i];
        final konum = _konumAl(s); if (konum == null) continue;
        final renk  = _renkler[i % _renkler.length];
        final aktif = s['servisAktif'] == true;
        yeni.add(Marker(
          markerId: MarkerId('s_${s['id']}'),
          position: konum,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              aktif ? _colorToHue(renk) : BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(
            title: '${s['ad'] ?? 'Sofor'} ${aktif ? "(CANLI)" : ""}',
            snippet: s['aracPlaka'] ?? '',
          ),
          onTap: () => _markerTap(s, 'sofor'),
          zIndex: 3.0,
        ));
      }
    }

    // ── ROTA ÇİZGİLERİ ──
    if (_rotaKatman) {
      for (int i = 0; i < _soforler.length; i++) {
        final s   = _soforler[i];
        final renk = _renkler[i % _renkler.length];
        // Bu şoföre atanmış öğrencileri sıraya göre al
        final atananlar = _ogrenciler.where((o) =>
        (o['surucuId'] ?? o['soforId'] ?? '') == s['id']).toList();
        atananlar.sort((a, b) =>
            ((a['sira'] as int?) ?? 999).compareTo((b['sira'] as int?) ?? 999));
        final noktalar = atananlar.map(_konumAl).whereType<LatLng>().toList();
        // Şoför konumunu başa ekle
        final sKonum = _konumAl(s);
        if (sKonum != null) noktalar.insert(0, sKonum);
        if (noktalar.length > 1) {
          yeniP.add(Polyline(
            polylineId: PolylineId('rota_${s['id']}'),
            points: noktalar,
            color: renk,
            width: 3,
            patterns: [PatternItem.dash(12), PatternItem.gap(6)],
          ));
        }
      }
    }

    // ── ÇEMBER (bölge modu) ──
    if (_mod == 'cercle' && _cerclMerkez != null) {
      yeniC.add(Circle(
        circleId: const CircleId('bolge'),
        center: _cerclMerkez!,
        radius: _cerclYaricap,
        fillColor: _orange.withValues(alpha: 0.12),
        strokeColor: _orange,
        strokeWidth: 2,
      ));
    }

    if (mounted) setState(() {
      _markers   = yeni;
      _polylines = yeniP;
      _circles   = yeniC;
    });
  }

  LatLng? _konumAl(Map<String, dynamic> d) {
    final k = d['konum'];
    if (k is GeoPoint) return LatLng(k.latitude, k.longitude);
    if (k is Map) {
      final lat = (k['lat'] ?? k['latitude'])  as double?;
      final lng = (k['lng'] ?? k['longitude']) as double?;
      if (lat != null && lng != null) return LatLng(lat, lng);
    }
    final lat = (d['lat'] ?? d['latitude'])  as double?;
    final lng = (d['lng'] ?? d['longitude']) as double?;
    if (lat != null && lng != null) return LatLng(lat, lng);
    return null;
  }

  double _colorToHue(Color c) {
    final r = c.red/255.0, g = c.green/255.0, b = c.blue/255.0;
    final mx = [r,g,b].reduce(math.max);
    final mn = [r,g,b].reduce(math.min);
    if (mx == mn) return 0;
    final d = mx - mn; double h = 0;
    if (mx == r) h = (g-b)/d + (g<b ? 6 : 0);
    else if (mx == g) h = (b-r)/d + 2;
    else h = (r-g)/d + 4;
    return (h/6*360).clamp(0, 360);
  }

  String _soforAd(String id) {
    final s = _soforler.firstWhere((s) => s['id'] == id, orElse: () => {});
    return s.isNotEmpty ? '${s['ad'] ?? ''} (${s['aracPlaka'] ?? ''})' : 'Sofor';
  }

  double _mesafe(LatLng a, LatLng b) {
    const R = 6371000.0;
    final dLat = (b.latitude  - a.latitude)  * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final x = math.sin(dLat/2)*math.sin(dLat/2) +
        math.cos(a.latitude*math.pi/180)*math.cos(b.latitude*math.pi/180)*
            math.sin(dLng/2)*math.sin(dLng/2);
    return R * 2 * math.atan2(math.sqrt(x), math.sqrt(1-x));
  }

  // ── MARKER TAP ────────────────────────────────────────────────
  void _markerTap(Map<String, dynamic> data, String tip) {
    if (_mod == 'manuel') {
      final id = data['id'] as String;
      final surucuId = (data['surucuId'] ?? data['soforId'] ?? '').toString();
      // Atanmış öğrenci seçilmeye çalışılıyorsa uyar
      if (surucuId.isNotEmpty && !_manuelSecilen.contains(id)) {
        final sofor = _soforler.firstWhere(
                (s) => s['id'] == surucuId, orElse: () => {});
        final soforAd = sofor.isNotEmpty ? sofor['ad'] ?? 'Servis' : 'Servis';
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 22),
              SizedBox(width: 8),
              Text('Zaten Atanmis', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ]),
            content: Text(
              '"${data['ad'] ?? 'Ogrenci'}" zaten "$soforAd" servisine atanmis.\n\nYine de farkli bir servise tasinmak ister misiniz?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Iptal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1a3a6b)),
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => _manuelSecilen.add(id));
                  _haritaOlustur();
                },
                child: const Text('Evet, Tasin', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        return;
      }
      setState(() {
        if (_manuelSecilen.contains(id)) _manuelSecilen.remove(id);
        else _manuelSecilen.add(id);
      });
      _haritaOlustur();
    } else {
      setState(() { _seciliDetay = data; _seciliTip = tip; });
    }
  }

  // ── HARİTA TAP — çember çiz ───────────────────────────────────
  void _haritaTap(LatLng konum) {
    if (_mod != 'cercle') return;
    setState(() => _cerclMerkez = konum);
    // Çember içindeki öğrencileri seç
    final secilenler = <String>[];
    for (final ogr in _ogrenciler) {
      final k = _konumAl(ogr); if (k == null) continue;
      if (_mesafe(konum, k) <= _cerclYaricap) secilenler.add(ogr['id'] as String);
    }
    setState(() => _manuelSecilen = secilenler);
    _haritaOlustur();
    if (secilenler.isNotEmpty) _atamaPaneliAc();
  }

  // ── OTOMATİK GRUPLAMA (K-Means benzeri) ──────────────────────
  void _otomatikGrupla() {
    if (_soforler.isEmpty) {
      _snack('Once sofor ekleyin!', Colors.orange); return;
    }
    final konumlular = _ogrenciler.where((o) => _konumAl(o) != null).toList();
    if (konumlular.isEmpty) {
      _snack('Konumlu ogrenci yok', Colors.orange); return;
    }

    // Her şoföre en yakın öğrencileri ata
    final Map<String, List<String>> gruplar = {};
    for (final s in _soforler) { gruplar[s['id'] as String] = []; }

    // Kapasite bazlı dengeleme
    final kapasite = (konumlular.length / _soforler.length).ceil();

    for (final ogr in konumlular) {
      final ogrKonum = _konumAl(ogr)!;
      String? enYakinSoforId;
      double enYakinMesafe = double.infinity;

      for (final s in _soforler) {
        final sid = s['id'] as String;
        if ((gruplar[sid]?.length ?? 0) >= kapasite) continue; // dolu
        final sKonum = _konumAl(s);
        if (sKonum == null) continue;
        final m = _mesafe(ogrKonum, sKonum);
        if (m < enYakinMesafe) { enYakinMesafe = m; enYakinSoforId = sid; }
      }
      // En yakın doluysa herhangi boşa at
      enYakinSoforId ??= _soforler.firstWhere(
              (s) => (gruplar[s['id'] as String]?.length ?? 0) < kapasite * 2,
          orElse: () => _soforler.first)['id'] as String;
      gruplar[enYakinSoforId]!.add(ogr['id'] as String);
    }

    // Önizleme dialog
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Otomatik Gruplama', style: TextStyle(fontWeight: FontWeight.bold, color: _navy)),
      content: Column(mainAxisSize: MainAxisSize.min,
        children: [
          Text('${konumlular.length} ogrenci ${_soforler.length} servise bolunecek:',
              style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 12),
          ...gruplar.entries.map((e) {
            final s = _soforler.firstWhere((s) => s['id'] == e.key, orElse: () => {});
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                const Icon(Icons.directions_bus_outlined, size: 16, color: _navy),
                const SizedBox(width: 6),
                Expanded(child: Text(s['ad'] ?? 'Sofor',
                    style: const TextStyle(fontWeight: FontWeight.w600))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: _navy.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text('${e.value.length} ogr',
                      style: const TextStyle(color: _navy, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ]),
            );
          }),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Iptal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _navy),
          onPressed: () async {
            Navigator.pop(context);
            await _gruplamaUygula(gruplar);
          },
          child: const Text('Uygula', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  Future<void> _gruplamaUygula(Map<String, List<String>> gruplar) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final e in gruplar.entries) {
      for (final ogrId in e.value) {
        batch.update(FirebaseFirestore.instance.collection('students').doc(ogrId),
            {'surucuId': e.key, 'soforId': e.key});
      }
    }
    await batch.commit();
    _snack('Gruplama tamamlandi!', Colors.green);
    _yukle();
  }

  // Servise atanırken kapasite + tekrar atama kontrolü
  Future<bool> _atamaTeyitEt(String surucuId, List<String> secilenIds) async {
    final sofor = _soforler.firstWhere((s) => s['id'] == surucuId, orElse: () => {});
    final kapasite = (sofor['kapasite'] as int?) ?? 16;

    // Bu şoföre zaten kaç öğrenci atanmış?
    final mevcutAtanmis = _ogrenciler.where((o) =>
    (o['surucuId'] ?? o['soforId'] ?? '') == surucuId).length;
    final yeniToplam = mevcutAtanmis + secilenIds.length;

    // Zaten bu serviste olan öğrenciler
    final zatenAtanmis = secilenIds.where((id) {
      final ogr = _ogrenciler.firstWhere((o) => o['id'] == id, orElse: () => {});
      return (ogr['surucuId'] ?? ogr['soforId'] ?? '') == surucuId;
    }).length;

    if (zatenAtanmis > 0) {
      _snack('$zatenAtanmis ogrenci zaten bu serviste', Colors.blue);
    }

    if (yeniToplam > kapasite) {
      // Kapasite uyarısı
      final devam = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          SizedBox(width: 8),
          Text('Kapasite Asiliyor', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ]),
        content: Text(
          '${sofor['ad'] ?? 'Servis'} aracinin kapasitesi $kapasite kisi.\n'
              'Mevcut: $mevcutAtanmis | Eklenecek: ${secilenIds.length}\n'
              'Toplam: $yeniToplam kisi olacak.\n\nYine de devam edilsin mi?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Iptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Devam Et', style: TextStyle(color: Colors.white)),
          ),
        ],
      )) ?? false;
      return devam;
    }
    return true;
  }

  // ── MANUEL SEÇİLENLERİ AT ────────────────────────────────────
  void _atamaPaneliAc() {
    if (_manuelSecilen.isEmpty) { _snack('Once ogrenci secin', Colors.orange); return; }
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => _TopluAtamaSheet(
        secilenSayi: _manuelSecilen.length,
        soforler: _soforler,
        renkler: _renkler,
        onAta: (surucuId) async {
          // Kapasite + tekrar atama teyidi
          final tamam = await _atamaTeyitEt(surucuId, List.from(_manuelSecilen));
          if (!tamam) return;

          final sayi = _manuelSecilen.length;
          final batch = FirebaseFirestore.instance.batch();
          for (final id in _manuelSecilen) {
            batch.update(FirebaseFirestore.instance.collection('students').doc(id),
                {'surucuId': surucuId, 'soforId': surucuId});
          }
          await batch.commit();
          setState(() { _manuelSecilen = []; _cerclMerkez = null; _mod = 'normal'; });
          _snack('$sayi ogrenci atandi!', Colors.green);
          _yukle();
        },
      ),
    );
  }

  void _snack(String msg, Color c) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: c, behavior: SnackBarBehavior.floating));
  }

  void _haritaFitYap() {
    final tum = <LatLng>[
      ..._ogrenciler.map(_konumAl).whereType<LatLng>(),
      ..._soforler.map(_konumAl).whereType<LatLng>(),
    ];
    if (tum.isEmpty || _mapCtrl == null) return;
    double minLat = tum.first.latitude, maxLat = minLat;
    double minLng = tum.first.longitude, maxLng = minLng;
    for (final k in tum) {
      if (k.latitude  < minLat) minLat = k.latitude;
      if (k.latitude  > maxLat) maxLat = k.latitude;
      if (k.longitude < minLng) minLng = k.longitude;
      if (k.longitude > maxLng) maxLng = k.longitude;
    }
    _mapCtrl!.animateCamera(CameraUpdate.newLatLngBounds(LatLngBounds(
      southwest: LatLng(minLat - 0.01, minLng - 0.01),
      northeast: LatLng(maxLat + 0.01, maxLng + 0.01),
    ), 60));
  }

  // ── BUILD ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white, elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Gruplama & Atama', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          Text('${_ogrenciler.length} ogr • ${_soforler.length} servis',
              style: const TextStyle(fontSize: 10, color: Colors.white60)),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _yukle),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: _orange,
          labelColor: Colors.white, unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.map_outlined,            size: 17), text: 'Harita'),
            Tab(icon: Icon(Icons.directions_bus_outlined, size: 17), text: 'Araclar'),
            Tab(icon: Icon(Icons.people_outline,          size: 17), text: 'Ogrenciler'),
          ],
        ),
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator(color: _navy))
          : TabBarView(controller: _tab, children: [
        _haritaSekmesi(),
        _AraclarSekmesi(firmaId: _firmaId, soforler: _soforler,
            ogrenciler: _ogrenciler, onGuncelle: _yukle),
        _OgrencilerSekmesi(ogrenciler: _ogrenciler, soforler: _soforler,
            onAta: (o) => showModalBottomSheet(
                context: context, isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _OgrenciAtamaSheet(
                    ogrenci: o, soforler: _soforler, onKayit: _yukle)),
            onGuncelle: _yukle),
      ]),
    );
  }

  // ════ HARİTA SEKMESİ ══════════════════════════════════════════
  Widget _haritaSekmesi() {
    final atanmis   = _ogrenciler.where((o) =>
    (o['surucuId'] ?? o['soforId'] ?? '').toString().isNotEmpty).length;
    final atanmamis = _ogrenciler.length - atanmis;

    return Stack(children: [
      // ── HARİTA ──
      GoogleMap(
        initialCameraPosition: const CameraPosition(
            target: LatLng(39.9334, 32.8597), zoom: 11),
        markers:   _markers,
        polylines: _polylines,
        circles:   _circles,
        onMapCreated: (c) {
          _mapCtrl = c;
          Future.delayed(const Duration(milliseconds: 600), _haritaFitYap);
        },
        onTap: (konum) {
          if (_mod == 'cercle') {
            _haritaTap(konum);
          } else {
            setState(() { _seciliDetay = null; });
          }
        },
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
      ),

      // ── ÜST ARAÇ ÇUBUĞU ──
      Positioned(top: 0, left: 0, right: 0,
        child: Container(
          color: Colors.white,
          child: Column(children: [
            // Satır 1: Katman toggle'ları
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Row(children: [
                // Öğrenciler
                _KatmanBtn(
                  ikon: Icons.people_outline,
                  etiket: 'Ogrenci (${_ogrenciler.length})',
                  aktif: _ogrenciKatman,
                  renk: Colors.purple,
                  onTap: () {
                    setState(() => _ogrenciKatman = !_ogrenciKatman);
                    _haritaOlustur();
                  },
                ),
                const SizedBox(width: 6),
                // Servisler
                _KatmanBtn(
                  ikon: Icons.directions_bus_outlined,
                  etiket: 'Servis (${_soforler.length})',
                  aktif: _servisKatman,
                  renk: _navy,
                  onTap: () {
                    setState(() => _servisKatman = !_servisKatman);
                    _haritaOlustur();
                  },
                ),
                const SizedBox(width: 6),
                // Rota çizgisi
                _KatmanBtn(
                  ikon: Icons.route,
                  etiket: 'Rota',
                  aktif: _rotaKatman,
                  renk: _orange,
                  onTap: () {
                    setState(() => _rotaKatman = !_rotaKatman);
                    _haritaOlustur();
                  },
                ),
                const Spacer(),
                // Fit butonu
                GestureDetector(
                  onTap: _haritaFitYap,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: _navy.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.fit_screen, color: _navy, size: 18),
                  ),
                ),
              ]),
            ),

            // Satır 2: Bölme seçenekleri
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  // Otomatik: Servislere Böl
                  _BolBtn(
                    ikon: Icons.auto_fix_high,
                    etiket: 'Servislere Bol (Otomatik)',
                    renk: Colors.green,
                    aktif: false,
                    onTap: _otomatikGrupla,
                  ),
                  const SizedBox(width: 6),
                  // Bölgelere Böl (çember)
                  _BolBtn(
                    ikon: Icons.radio_button_checked,
                    etiket: _mod == 'cercle' ? 'Bolge: Haritaya Dokun' : 'Bolgeye Bol',
                    renk: _orange,
                    aktif: _mod == 'cercle',
                    onTap: () {
                      setState(() {
                        _mod = _mod == 'cercle' ? 'normal' : 'cercle';
                        _manuelSecilen = [];
                        _cerclMerkez  = null;
                      });
                      _haritaOlustur();
                    },
                  ),
                  const SizedBox(width: 6),
                  // Manuel Böl
                  _BolBtn(
                    ikon: Icons.touch_app_outlined,
                    etiket: _mod == 'manuel'
                        ? '${_manuelSecilen.length} Secili — Ata'
                        : 'Manuel Sec',
                    renk: Colors.indigo,
                    aktif: _mod == 'manuel',
                    onTap: () {
                      if (_mod == 'manuel' && _manuelSecilen.isNotEmpty) {
                        _atamaPaneliAc();
                      } else {
                        setState(() {
                          _mod = _mod == 'manuel' ? 'normal' : 'manuel';
                          _manuelSecilen = [];
                        });
                        _haritaOlustur();
                        if (_mod == 'manuel') {
                          _snack('Ogrenci markerlerine dokun, sonra "Ata" ya bas', Colors.indigo);
                        }
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                  // Uzak-yakın sırala
                  _BolBtn(
                    ikon: Icons.sort_by_alpha,
                    etiket: 'Uzakliga Gore Sirala',
                    renk: Colors.teal,
                    aktif: false,
                    onTap: _uzaklikSirala,
                  ),
                ]),
              ),
            ),

            // Çember modu: yarıçap slider
            if (_mod == 'cercle')
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                child: Row(children: [
                  const Icon(Icons.radio_button_checked, color: _orange, size: 14),
                  const SizedBox(width: 6),
                  Text('Yaricap: ${(_cerclYaricap/1000).toStringAsFixed(1)} km',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _orange)),
                  Expanded(child: Slider(
                    value: _cerclYaricap, min: 200, max: 5000,
                    activeColor: _orange,
                    onChanged: (v) {
                      setState(() => _cerclYaricap = v);
                      if (_cerclMerkez != null) {
                        final secilenler = _ogrenciler.where((o) {
                          final k = _konumAl(o); if (k == null) return false;
                          return _mesafe(_cerclMerkez!, k) <= v;
                        }).map((o) => o['id'] as String).toList();
                        setState(() => _manuelSecilen = secilenler);
                        _haritaOlustur();
                      }
                    },
                  )),
                  if (_manuelSecilen.isNotEmpty)
                    GestureDetector(
                      onTap: _atamaPaneliAc,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(8)),
                        child: Text('${_manuelSecilen.length} Ata',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ]),
              ),

            // Stat bar
            Container(
              color: const Color(0xFFF5F7FA),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(children: [
                _StatChip('$atanmis',   'Atanmis',   Colors.green),
                const SizedBox(width: 6),
                _StatChip('$atanmamis', 'Atanmamis', Colors.red),
                const SizedBox(width: 6),
                _StatChip('${_manuelSecilen.length}', 'Secili', _orange),
                const Spacer(),
                // İptal (mod çıkış)
                if (_mod != 'normal')
                  GestureDetector(
                    onTap: () {
                      setState(() { _mod = 'normal'; _manuelSecilen = []; _cerclMerkez = null; });
                      _haritaOlustur();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.close, size: 12, color: Colors.red),
                        SizedBox(width: 3),
                        Text('Iptal', style: TextStyle(color: Colors.red, fontSize: 11)),
                      ]),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
      ),

      // ── LEGEND ──
      Positioned(left: 10, bottom: _seciliDetay != null ? 210 : 80,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _LegItem(Colors.red, 'Atanmamis (${_ogrenciler.where((o) => (o['surucuId'] ?? o['soforId'] ?? '').toString().isEmpty).length})'),
            ..._soforler.asMap().entries.take(6).map((e) {
              final sid   = e.value['id'] as String;
              final sayi  = _ogrenciler.where((o) =>
              (o['surucuId'] ?? o['soforId'] ?? '') == sid).length;
              final renk  = _renkler[e.key % _renkler.length];
              final aktif = e.value['servisAktif'] == true;
              return _LegItem(renk,
                  '${e.value['ad'] ?? 'S${e.key+1}'} ($sayi ogr)${aktif ? ' ●' : ''}');
            }),
          ]),
        ),
      ),

      // ── ZOOM ──
      Positioned(right: 12, bottom: _seciliDetay != null ? 210 : 90,
        child: Column(children: [
          _ZoomBtn(Icons.add,    () => _mapCtrl?.animateCamera(CameraUpdate.zoomIn())),
          const SizedBox(height: 5),
          _ZoomBtn(Icons.remove, () => _mapCtrl?.animateCamera(CameraUpdate.zoomOut())),
        ]),
      ),

      // ── DETAY KARTI ──
      if (_seciliDetay != null)
        Positioned(bottom: 0, left: 0, right: 0,
          child: _DetayKarti(
            data: _seciliDetay!,
            tip: _seciliTip,
            soforler: _soforler,
            renkler: _renkler,
            onKapat: () => setState(() { _seciliDetay = null; }),
            onAta: (surucuId) async {
              await FirebaseFirestore.instance
                  .collection('students').doc(_seciliDetay!['id']).update(
                  {'surucuId': surucuId, 'soforId': surucuId});
              setState(() { _seciliDetay = null; });
              _yukle();
            },
            onNavigasyon: (k) async {
              final url = Uri.parse(
                  'https://www.google.com/maps/dir/?api=1&destination=${k.latitude},${k.longitude}&travelmode=driving');
              if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
            },
          ),
        ),
    ]);
  }

  // Uzaklık sırala — şoförsüz öğrencileri uzaklığa göre listele
  void _uzaklikSirala() {
    if (_soforler.isEmpty) { _tab.animateTo(2); return; }
    // Şoförlerin orta noktasını merkez al
    final soforKonumlar = _soforler.map(_konumAl).whereType<LatLng>().toList();
    if (soforKonumlar.isEmpty) { _snack('Soforlerin konumu yok', Colors.orange); return; }
    final merkLat = soforKonumlar.map((k) => k.latitude).reduce((a,b) => a+b) / soforKonumlar.length;
    final merkLng = soforKonumlar.map((k) => k.longitude).reduce((a,b) => a+b) / soforKonumlar.length;
    final merkez = LatLng(merkLat, merkLng);

    // Öğrencileri uzaklığa göre sırala
    final sirali = List<Map<String, dynamic>>.from(_ogrenciler)
      ..sort((a, b) {
        final ka = _konumAl(a), kb = _konumAl(b);
        if (ka == null) return 1; if (kb == null) return -1;
        return _mesafe(merkez, kb).compareTo(_mesafe(merkez, ka)); // uzak önce
      });

    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6, maxChildSize: 0.9,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          child: Column(children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const Text('Uzakliga Gore Sirali', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _navy)),
            const Text('En uzaktan en yakina', style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 8),
            Expanded(child: ListView.builder(
              controller: ctrl,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: sirali.length,
              itemBuilder: (_, i) {
                final o  = sirali[i];
                final k  = _konumAl(o);
                final km = k != null ? (_mesafe(merkez, k) / 1000).toStringAsFixed(1) : '?';
                final atanmis = (o['surucuId'] ?? o['soforId'] ?? '').toString().isNotEmpty;
                return ListTile(
                  leading: CircleAvatar(radius: 16,
                      backgroundColor: atanmis ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                      child: Text('${i+1}', style: TextStyle(
                          color: atanmis ? Colors.green : Colors.red, fontSize: 11, fontWeight: FontWeight.bold))),
                  title: Text(o['ad'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  subtitle: Text(o['adres'] ?? '', style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                  trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('$km km', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _navy)),
                    Text(atanmis ? 'Atanmis' : 'Atanmamis',
                        style: TextStyle(fontSize: 9, color: atanmis ? Colors.green : Colors.red)),
                  ]),
                  onTap: () {
                    Navigator.pop(context);
                    if (k != null) _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(k, 15));
                  },
                );
              },
            )),
          ]),
        ),
      ),
    );
  }
}

// ── TOPLU ATAMA SHEET ────────────────────────────────────────────
class _TopluAtamaSheet extends StatelessWidget {
  final int secilenSayi;
  final List<Map<String, dynamic>> soforler;
  final List<Color> renkler;
  final ValueChanged<String> onAta;
  static const _navy = Color(0xFF1a3a6b);
  const _TopluAtamaSheet({required this.secilenSayi, required this.soforler,
    required this.renkler, required this.onAta});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
      Text('$secilenSayi ogrenci hangi servise atansin?',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _navy)),
      const SizedBox(height: 16),
      ...soforler.asMap().entries.map((e) {
        final s    = e.value;
        final renk = renkler[e.key % renkler.length];
        return GestureDetector(
          onTap: () { Navigator.pop(context); onAta(s['id'] as String); },
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: renk.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: renk.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Icon(Icons.directions_bus_outlined, color: renk, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text('${s['ad'] ?? 'Sofor'} — ${s['aracPlaka'] ?? ''}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: renk))),
              Icon(Icons.chevron_right, color: renk, size: 18),
            ]),
          ),
        );
      }),
      const SizedBox(height: 4),
    ]),
  );
}

// ── DETAY KARTI ──────────────────────────────────────────────────
class _DetayKarti extends StatelessWidget {
  final Map<String, dynamic> data;
  final String tip;
  final List<Map<String, dynamic>> soforler;
  final List<Color> renkler;
  final VoidCallback onKapat;
  final ValueChanged<String> onAta;
  final ValueChanged<LatLng> onNavigasyon;
  static const _navy = Color(0xFF1a3a6b);

  const _DetayKarti({required this.data, required this.tip, required this.soforler,
    required this.renkler, required this.onKapat, required this.onAta, required this.onNavigasyon});

  LatLng? get _konum {
    final k = data['konum'];
    if (k is GeoPoint) return LatLng(k.latitude, k.longitude);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ad = '${data['ad'] ?? ''} ${data['soyad'] ?? ''}'.trim();
    final surucuId = (data['surucuId'] ?? data['soforId'] ?? '').toString();
    final soforIdx = soforler.indexWhere((s) => s['id'] == surucuId);
    final renk = soforIdx >= 0 ? renkler[soforIdx % renkler.length] : _navy;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12)]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
        Row(children: [
          CircleAvatar(radius: 22, backgroundColor: renk.withValues(alpha: 0.12),
              child: Text(ad.isNotEmpty ? ad[0].toUpperCase() : '?',
                  style: TextStyle(color: renk, fontWeight: FontWeight.bold, fontSize: 16))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ad.isNotEmpty ? ad : 'Bilgi Yok',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text(data['adres'] ?? data['aracPlaka'] ?? '',
                style: TextStyle(color: Colors.grey[500], fontSize: 12), overflow: TextOverflow.ellipsis),
            if (surucuId.isNotEmpty)
              Row(children: [
                Container(width: 8, height: 8, margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(color: renk, shape: BoxShape.circle)),
                Text(soforlar_adi(surucuId), style: TextStyle(color: renk, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
          ])),
          IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: onKapat),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          if (_konum != null)
            Expanded(child: _AkBtn(Icons.navigation_outlined, 'Navigasyon', Colors.blue,
                    () => onNavigasyon(_konum!))),
          if (_konum != null) const SizedBox(width: 8),
          if (tip == 'ogrenci') Expanded(child: _AtaBtn(soforler, renkler, onAta)),
          if ((data['veliTel'] ?? data['telefon'] ?? '').isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(child: _AkBtn(Icons.phone_outlined, 'Ara', Colors.green, () async {
              await launchUrl(Uri.parse('tel:${data['veliTel'] ?? data['telefon']}'));
            })),
          ],
        ]),
      ]),
    );
  }

  String soforlar_adi(String id) {
    final s = soforler.firstWhere((s) => s['id'] == id, orElse: () => {});
    return s.isNotEmpty ? s['ad'] ?? 'Sofor' : 'Atanmis';
  }
}

class _AtaBtn extends StatelessWidget {
  final List<Map<String, dynamic>> soforler;
  final List<Color> renkler;
  final ValueChanged<String> onAta;
  static const _navy = Color(0xFF1a3a6b);
  const _AtaBtn(this.soforler, this.renkler, this.onAta);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => showModalBottomSheet(
        context: context, backgroundColor: Colors.transparent,
        builder: (_) => _TopluAtamaSheet(
            secilenSayi: 1, soforler: soforler, renkler: renkler, onAta: onAta)),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(color: _navy.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _navy.withValues(alpha: 0.3))),
      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.directions_bus_outlined, size: 14, color: _navy),
        SizedBox(width: 5),
        Text('Servise Ata', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _navy)),
      ]),
    ),
  );
}

// ── ORTAK ────────────────────────────────────────────────────────
class _KatmanBtn extends StatelessWidget {
  final IconData ikon; final String etiket;
  final bool aktif; final Color renk; final VoidCallback onTap;
  const _KatmanBtn({required this.ikon, required this.etiket,
    required this.aktif, required this.renk, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
            color: aktif ? renk : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(ikon, color: aktif ? Colors.white : Colors.grey, size: 13),
          const SizedBox(width: 4),
          Text(etiket, style: TextStyle(
              color: aktif ? Colors.white : Colors.grey[600],
              fontSize: 10, fontWeight: aktif ? FontWeight.bold : FontWeight.normal)),
        ]),
      ));
}

class _BolBtn extends StatelessWidget {
  final IconData ikon; final String etiket;
  final Color renk; final bool aktif; final VoidCallback onTap;
  const _BolBtn({required this.ikon, required this.etiket,
    required this.renk, required this.aktif, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: aktif ? renk : renk.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: renk.withValues(alpha: 0.4))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(ikon, color: aktif ? Colors.white : renk, size: 13),
          const SizedBox(width: 5),
          Text(etiket, style: TextStyle(
              color: aktif ? Colors.white : renk,
              fontSize: 10, fontWeight: FontWeight.bold)),
        ]),
      ));
}

class _StatChip extends StatelessWidget {
  final String deger, etiket; final Color renk;
  const _StatChip(this.deger, this.etiket, this.renk);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: renk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(deger, style: TextStyle(color: renk, fontWeight: FontWeight.bold, fontSize: 11)),
      const SizedBox(width: 3),
      Text(etiket, style: TextStyle(color: renk, fontSize: 9)),
    ]),
  );
}

class _LegItem extends StatelessWidget {
  final Color renk; final String etiket;
  const _LegItem(this.renk, this.etiket);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 3),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: renk, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(etiket, style: const TextStyle(fontSize: 9)),
    ]),
  );
}

class _ZoomBtn extends StatelessWidget {
  final IconData ikon; final VoidCallback onTap;
  const _ZoomBtn(this.ikon, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
      child: Container(width: 38, height: 38,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)]),
          child: Icon(ikon, color: const Color(0xFF1a3a6b), size: 20)));
}

class _AkBtn extends StatelessWidget {
  final IconData ikon; final String label; final Color color; final VoidCallback onTap;
  const _AkBtn(this.ikon, this.label, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
      child: Container(padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(ikon, size: 14, color: color), const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ]),
      ));
}

// ════════════════════════════════════════════════════════════════
//  ARACLAR SEKMESİ (değişmedi, aynen korundu)
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
        if (docs.isEmpty) return _Bos('Sofor/arac eklenmemis', Icons.directions_bus_outlined);
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d   = docs[i].data() as Map<String, dynamic>;
            final did = docs[i].id;
            final aktif = d['servisAktif'] ?? false;
            final atananOgr = ogrenciler.where((o) =>
            (o['surucuId'] ?? o['soforId'] ?? '') == did).toList();
            final Color renk = [Colors.blue, Colors.green, Colors.purple,
              Colors.orange, Colors.teal, Colors.red, Colors.indigo][i % 7];

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: aktif ? Colors.green.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.15)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)]),
              child: Column(children: [
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
                        Text(d['aracPlaka'],
                            style: TextStyle(color: renk, fontSize: 11, fontWeight: FontWeight.w600)),
                      ]),
                    Text('${atananOgr.length} ogrenci',
                        style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                  ])),
                  Switch(value: aktif, activeColor: Colors.green,
                      onChanged: (v) => FirebaseFirestore.instance
                          .collection('drivers').doc(did).update({'servisAktif': v})),
                ])),
                if (atananOgr.isNotEmpty) ...[
                  Divider(height: 1, color: Colors.grey.withValues(alpha: 0.15)),
                  Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                    child: Column(children: atananOgr.take(5).map((ogr) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(children: [
                        Icon(Icons.person_outline, size: 13, color: renk),
                        const SizedBox(width: 6),
                        Expanded(child: Text(ogr['ad'] ?? '',
                            style: const TextStyle(fontSize: 12))),
                        Text(ogr['adres'] ?? '',
                            style: TextStyle(color: Colors.grey[400], fontSize: 10),
                            overflow: TextOverflow.ellipsis),
                      ]),
                    )).toList()),
                  ),
                  if (atananOgr.length > 5)
                    Padding(padding: const EdgeInsets.only(left: 14, bottom: 6),
                        child: Text('+${atananOgr.length-5} daha...',
                            style: TextStyle(fontSize: 10, color: Colors.grey[500]))),
                ],
                Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    child: Row(children: [
                      if ((d['telefon'] ?? '').isNotEmpty)
                        GestureDetector(
                          onTap: () async {
                            var n = d['telefon'].replaceAll(RegExp(r'[^0-9]'), '');
                            if (n.startsWith('0')) n = '9$n';
                            if (!n.startsWith('90')) n = '90$n';
                            await launchUrl(Uri.parse('https://wa.me/$n'),
                                mode: LaunchMode.externalApplication);
                          },
                          child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                  color: const Color(0xFF25D366).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Row(children: [
                                Icon(Icons.message_outlined, size: 13, color: Color(0xFF25D366)),
                                SizedBox(width: 4),
                                Text('WhatsApp', style: TextStyle(color: Color(0xFF25D366), fontSize: 11)),
                              ])),
                        ),
                      const Spacer(),
                    ])),
              ]),
            );
          },
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  ÖĞRENCİLER SEKMESİ
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
      final sid = (o['surucuId'] ?? o['soforId'] ?? '').toString();
      if (_filtre == 'atanmis'   && sid.isEmpty) return false;
      if (_filtre == 'atanmamis' && sid.isNotEmpty) return false;
      if (_arama.isNotEmpty &&
          !(o['ad'] ?? '').toString().toLowerCase().contains(_arama.toLowerCase())) return false;
      return true;
    }).toList();

    return Column(children: [
      Container(color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: Column(children: [
          TextField(
            onChanged: (v) => setState(() => _arama = v),
            decoration: InputDecoration(
                hintText: 'Ogrenci ara...',
                prefixIcon: const Icon(Icons.search, size: 19),
                filled: true, fillColor: const Color(0xFFF5F7FA),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
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
          final surucuId = (ogr['surucuId'] ?? ogr['soforId'] ?? '').toString();
          final sofor   = surucuId.isNotEmpty
              ? widget.soforler.firstWhere((s) => s['id'] == surucuId, orElse: () => {})
              : null;
          final atanmis = sofor != null && sofor.isNotEmpty;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: atanmis ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]),
            child: Row(children: [
              CircleAvatar(radius: 18,
                  backgroundColor: atanmis
                      ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                  child: Text((ogr['ad'] ?? '?')[0].toUpperCase(),
                      style: TextStyle(
                          color: atanmis ? Colors.green : Colors.orange, fontWeight: FontWeight.bold))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ogr['ad'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(ogr['adres'] ?? '', style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    overflow: TextOverflow.ellipsis),
                if (atanmis)
                  Text('Servis: ${sofor!['ad'] ?? ''}',
                      style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w600)),
              ])),
              GestureDetector(
                  onTap: () => widget.onAta(ogr),
                  child: Container(padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: _turuncu.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.directions_bus_outlined, size: 16, color: _turuncu))),
            ]),
          );
        },
      )),
    ]);
  }
}

// ── OGRENCİ ATAMA SHEET ──────────────────────────────────────────
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
    _secili = (widget.ogrenci['surucuId'] ?? widget.ogrenci['soforId']) as String?;
  }

  Future<void> _kaydet() async {
    setState(() => _yukleniyor = true);
    try {
      await FirebaseFirestore.instance.collection('students').doc(widget.ogrenci['id']).update({
        'surucuId': _secili ?? '',
        'soforId':  _secili ?? '',
      });
      if (mounted) { Navigator.pop(context); widget.onKayit(); }
    } catch (_) {} finally { if (mounted) setState(() => _yukleniyor = false); }
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
    padding: EdgeInsets.only(left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
      Text(widget.ogrenci['ad'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 16),
      DropdownButtonFormField<String?>(
        value: _secili,
        decoration: InputDecoration(labelText: 'Servis Sec',
            prefixIcon: const Icon(Icons.directions_bus_outlined, color: _navy),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
        items: [
          const DropdownMenuItem(value: null, child: Text('Atamayı Kaldir', style: TextStyle(color: Colors.red))),
          ...widget.soforler.map((s) => DropdownMenuItem(
              value: s['id'] as String,
              child: Text('${s['ad'] ?? 'Sofor'} — ${s['aracPlaka'] ?? ''}'))),
        ],
        onChanged: (v) => setState(() => _secili = v),
      ),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        onPressed: _yukleniyor ? null : _kaydet,
        child: _yukleniyor
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      )),
    ]),
  );
}

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
                fontSize: 12, fontWeight: aktif ? FontWeight.bold : FontWeight.normal))));
  }
}

Widget _Bos(String mesaj, IconData ikon) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
  Icon(ikon, size: 64, color: Colors.grey[300]),
  const SizedBox(height: 12),
  Text(mesaj, style: TextStyle(color: Colors.grey[500], fontSize: 14)),
]));

class OtomatikRotaButonu extends StatelessWidget {
  const OtomatikRotaButonu({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class SoforAyarSheet extends StatelessWidget {
  final String soforId;
  final Map<String, dynamic> soforData;
  final VoidCallback onGuncelle;
  const SoforAyarSheet({super.key, required this.soforId, required this.soforData, required this.onGuncelle});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
