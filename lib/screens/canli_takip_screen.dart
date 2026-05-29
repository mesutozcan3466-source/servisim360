import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/session_service.dart';
import 'sesli_yonlendirme_servisi.dart';

// ═══════════════════════════════════════════════════════════════════════════
// CANLI TAKİP EKRANI — VELİ
// Sadece kendi çocuğunun şoförünü gösterir.
// Servis saati dışında harita kilitlenir.
// ═══════════════════════════════════════════════════════════════════════════

class CanliTakipScreen extends StatefulWidget {
  const CanliTakipScreen({super.key});
  @override
  State<CanliTakipScreen> createState() => _CanliTakipScreenState();
}

class _CanliTakipScreenState extends State<CanliTakipScreen> {
  static const _navy    = Color(0xFF1a3a6b);
  // Servis saatleri
  // Sabah: 06:30 - 09:30
  // Aksam: 15:00 - 18:30
  static const _sabahBaslangic = TimeOfDay(hour: 6,  minute: 30);
  static const _sabahBitis     = TimeOfDay(hour: 9,  minute: 30);
  static const _aksamBaslangic = TimeOfDay(hour: 15, minute: 0);
  static const _aksamBitis     = TimeOfDay(hour: 18, minute: 30);

  GoogleMapController? _mapCtrl;
  StreamSubscription<DocumentSnapshot>? _soforSub;
  Timer? _saatTimer;

  // Ogrenci & Sofor bilgisi
  Map<String, dynamic>? _ogrenci;
  Map<String, dynamic>? _sofor;
  String? _soforDocId;
  String? _firmaId;

  // Harita
  LatLng? _soforKonum;
  LatLng? _veliKonum;
  LatLng? _durakKonum;
  final Set<Marker>   _markers   = {};
  final Set<Polyline> _polylines = {};

  // Durum
  bool _yukleniyor      = true;
  bool _hata            = false;
  int? _tahminiDakika;
  int? _mesafeMetre;
  String _oncekiOgrenci  = '';
  int    _benimSiram     = -1;   // Rota sırasında benim index'im
  int    _kacDurakKaldi  = -1;   // Bana kaç durak kaldı

  // Sesli yonlendirme
  final _sesli = SesliYonlendirmeServisi();
  bool _sesliAcik = true;

  // Servis saati durumu
  bool _servisSaatiMi   = false;
  String _servisMod     = ''; // 'sabah' | 'aksam' | ''
  String _sonrakiSaat   = '';

  @override
  void initState() {
    super.initState();
    _saatiGuncelle();
    // Her dakika saat kontrolu
    _saatTimer = Timer.periodic(
      const Duration(minutes: 1),
          (_) => _saatiGuncelle(),
    );
    _yukle();
    _sesli.baslat();
  }

  @override
  void dispose() {
    _soforSub?.cancel();
    _saatTimer?.cancel();
    _mapCtrl?.dispose();
    _sesli.dispose();
    super.dispose();
  }

  // ── Servis Saati Kontrolu ───────────────────────────────────────────────────
  void _saatiGuncelle() {
    final simdi = TimeOfDay.now();
    final dk    = simdi.hour * 60 + simdi.minute;

    final sabahBas = _sabahBaslangic.hour * 60 + _sabahBaslangic.minute;
    final sabahBit = _sabahBitis.hour    * 60 + _sabahBitis.minute;
    final aksamBas = _aksamBaslangic.hour * 60 + _aksamBaslangic.minute;
    final aksamBit = _aksamBitis.hour    * 60 + _aksamBitis.minute;

    bool saatIcinde = false;
    String mod      = '';
    String sonraki  = '';

    if (dk >= sabahBas && dk <= sabahBit) {
      saatIcinde = true;
      mod        = 'sabah';
    } else if (dk >= aksamBas && dk <= aksamBit) {
      saatIcinde = true;
      mod        = 'aksam';
    } else {
      // Sonraki servis saatini hesapla
      if (dk < sabahBas) {
        sonraki = '${_sabahBaslangic.hour.toString().padLeft(2, '0')}:${_sabahBaslangic.minute.toString().padLeft(2, '0')} sabah servisine';
      } else if (dk < aksamBas) {
        sonraki = '${_aksamBaslangic.hour.toString().padLeft(2, '0')}:${_aksamBaslangic.minute.toString().padLeft(2, '0')} aksam servisine';
      } else {
        sonraki = 'yarin sabah ${_sabahBaslangic.hour.toString().padLeft(2, '0')}:${_sabahBaslangic.minute.toString().padLeft(2, '0')} servisine';
      }
    }

    if (mounted) {
      setState(() {
        _servisSaatiMi = saatIcinde;
        _servisMod     = mod;
        _sonrakiSaat   = sonraki;
      });
    }
  }

  // Servis aktifse saat kisitlamasi kalkar
  bool get _takipAktif {
    final servisAktif = _sofor?['servisAktif'] == true;
    return _servisSaatiMi || servisAktif;
  }

  // ── Veri Yukle ─────────────────────────────────────────────────────────────
  Future<void> _yukle() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() { _yukleniyor = false; _hata = true; });
      return;
    }

    _firmaId = await SessionService.instance.firmaldAl();

    try {
      // Ogrenciyi bul — GUVENLIK: sadece kendi veliId'si
      var ogrSnap = await FirebaseFirestore.instance
          .collection('students')
          .where('veliId', isEqualTo: user.uid)
          .limit(1).get();
      if (ogrSnap.docs.isEmpty && user.email != null) {
        ogrSnap = await FirebaseFirestore.instance
            .collection('students')
            .where('veliEmail', isEqualTo: user.email)
            .limit(1).get();
      }
      if (ogrSnap.docs.isEmpty) {
        setState(() { _yukleniyor = false; _hata = true; });
        return;
      }

      _ogrenci = {
        'id': ogrSnap.docs.first.id,
        ...ogrSnap.docs.first.data()
      };

      // GUVENLIK: Ogrencinin firmasi ile kullanicinin firmasi eslesiyor mu?
      final ogrFirmaId = _ogrenci!['firmaId'] as String?;
      if (_firmaId != null && ogrFirmaId != null &&
          _firmaId != ogrFirmaId) {
        debugPrint('GUVENLIK: Firma eslesmiyor!');
        setState(() { _yukleniyor = false; _hata = true; });
        return;
      }

      // Durak konumunu al
      final durakKonum = _ogrenci!['konum'];
      if (durakKonum is GeoPoint) {
        _durakKonum = LatLng(durakKonum.latitude, durakKonum.longitude);
      }

      // Soforu bul — GUVENLIK: sadece kendi surucuId'si
      final surucuId = _ogrenci!['surucuId'] as String?;
      if (surucuId != null && surucuId.isNotEmpty) {
        // Once uid ile ara
        var dSnap = await FirebaseFirestore.instance
            .collection('drivers')
            .where('uid', isEqualTo: surucuId)
            .where('firmaId', isEqualTo: _firmaId)
            .limit(1).get();

        if (dSnap.docs.isEmpty) {
          // Doc ID ile dene
          final d = await FirebaseFirestore.instance
              .collection('drivers').doc(surucuId).get();
          if (d.exists &&
              d.data()?['firmaId'] == _firmaId) {
            _soforDocId = d.id;
            _sofor      = d.data();
          }
        } else {
          _soforDocId = dSnap.docs.first.id;
          _sofor      = dSnap.docs.first.data();
        }
      }

      // Rota sırasını Firestore'dan çek
      if (_ogrenci != null && _soforDocId != null) {
        try {
          var rotaQ = FirebaseFirestore.instance
              .collection('students')
              .where('surucuId', isEqualTo: _soforDocId)
              .orderBy('sira');
          if (_firmaId != null) rotaQ = rotaQ.where('firmaId', isEqualTo: _firmaId);
          final rotaSnap = await rotaQ.get();
          final rotaDocs  = rotaSnap.docs;
          _benimSiram = rotaDocs.indexWhere((d) => d.id == _ogrenci!['id']);
          // Şoförün şu anki hedefi
          final bekleyenIdx = rotaDocs.indexWhere(
                  (d) => d.data()['bindi'] != true);
          _kacDurakKaldi = _benimSiram >= 0 && bekleyenIdx >= 0
              ? _benimSiram - bekleyenIdx : -1;
        } catch (_) {}
      }

      // Veli konumunu al
      final izin = await Geolocator.requestPermission();
      if (izin != LocationPermission.denied &&
          izin != LocationPermission.deniedForever) {
        final pos = await Geolocator.getCurrentPosition();
        _veliKonum = LatLng(pos.latitude, pos.longitude);
      }

      // Sofor konumunu dinle — SADECE servis saatinde veya servis aktifse
      if (_soforDocId != null) {
        _soforSub = FirebaseFirestore.instance
            .collection('drivers')
            .doc(_soforDocId!)
            .snapshots()
            .listen(_soforGuncellendi);
      }
    } catch (e) {
      debugPrint('CanliTakip hata: $e');
    }

    if (mounted) setState(() => _yukleniyor = false);
  }

  // ── Sofor Konum Guncellemesi ────────────────────────────────────────────────
  void _soforGuncellendi(DocumentSnapshot doc) {
    if (!doc.exists || !mounted) return;
    final data = doc.data() as Map<String, dynamic>;

    // GUVENLIK: Firma dogrulamasi
    if (data['firmaId'] != _firmaId) {
      debugPrint('GUVENLIK: Sofor firma eslesmiyor!');
      return;
    }

    _sofor = data;

    // Servis aktif degilse ve saat disindaysa konum gizle
    if (!_takipAktif) {
      if (mounted) setState(() {
        _soforKonum = null;
        _saatiGuncelle();
      });
      return;
    }

    final konum = data['konum'];
    if (konum is! GeoPoint) return;

    final yeniKonum = LatLng(konum.latitude, konum.longitude);
    _soforKonum     = yeniKonum;

    // Mesafe ve tahmini sure
    if (_durakKonum != null) {
      final m = Geolocator.distanceBetween(
        yeniKonum.latitude, yeniKonum.longitude,
        _durakKonum!.latitude, _durakKonum!.longitude,
      ).round();
      _mesafeMetre   = m;
      final hiz      = (data['hiz'] as num?)?.toDouble() ?? 30;
      _tahminiDakika = ((m / 1000) / (hiz > 5 ? hiz : 30) * 60).round();
    }

    _oncekiOgrenciiBul();
    _sesliDurakBildirim();
    _haritaGuncelle();
    _mapCtrl?.animateCamera(CameraUpdate.newLatLng(yeniKonum));
  }

  void _sesliDurakBildirim() {
    if (!_sesliAcik || _kacDurakKaldi < 0) return;
    if (_kacDurakKaldi == 2) {
      _sesli.bildirim('Servis 2 durak sonra sizin duraginizda.');
    } else if (_kacDurakKaldi == 1) {
      _sesli.bildirim('Servis bir sonraki duraginizda! Hazirlanin.');
    } else if (_kacDurakKaldi == 0) {
      _sesli.bildirim('Servis simdi sizin duraginizda!', zorla: true);
    }
  }

  // ── Bir Onceki Ogrenci ──────────────────────────────────────────────────────
  Future<void> _oncekiOgrenciiBul() async {
    if (_soforDocId == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('students')
          .where('surucuId', isEqualTo: _ogrenci!['surucuId'])
          .where('bindi', isEqualTo: false)
          .get();

      if (snap.docs.isEmpty) {
        if (mounted) setState(() => _oncekiOgrenci = '');
        return;
      }

      final docs       = snap.docs;
      final benimIndex = docs.indexWhere((d) => d.id == _ogrenci!['id']);

      if (benimIndex > 0) {
        // Bir onceki ogrencinin adini goster — ama sadece ad, baska bilgi yok
        final onceki = docs[benimIndex - 1].data();
        final ad     = onceki['ad'] as String? ?? '';
        if (mounted) setState(() => _oncekiOgrenci = "$ad'de");
      } else if (benimIndex == 0) {
        if (mounted) setState(() => _oncekiOgrenci = 'Siz siradasiniz');
      }
    } catch (_) {}
  }

  // ── Harita Guncelle ─────────────────────────────────────────────────────────
  void _haritaGuncelle() {
    if (!mounted) return;
    setState(() {
      _markers.clear();
      _polylines.clear();

      if (!_takipAktif) return; // Saat disinda marker gosterme

      // Arac marker (yesil)
      if (_soforKonum != null) {
        _markers.add(Marker(
          markerId: const MarkerId('arac'),
          position: _soforKonum!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: '${_sofor?['ad'] ?? 'Servis Araci'}',
            snippet: _tahminiDakika != null
                ? 'Tahmini: $_tahminiDakika dk'
                : 'Aktif servis',
          ),
        ));
      }

      // Durak marker (mavi — sadece kendi duragi)
      if (_durakKonum != null) {
        _markers.add(Marker(
          markerId: const MarkerId('durak'),
          position: _durakKonum!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
            title: '${_ogrenci?['ad'] ?? ''} Duragi',
            snippet: _ogrenci?['durakAdi'] ?? '',
          ),
        ));
      }

      // Veli konumu (turuncu)
      if (_veliKonum != null) {
        _markers.add(Marker(
          markerId: const MarkerId('veli'),
          position: _veliKonum!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueOrange),
          infoWindow: const InfoWindow(title: 'Konumunuz'),
        ));
      }

      // Aractan duraga rota cizgisi
      if (_soforKonum != null && _durakKonum != null) {
        _polylines.add(Polyline(
          polylineId: const PolylineId('rota'),
          points: [_soforKonum!, _durakKonum!],
          color: _navy,
          width: 3,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ));
      }
    });
  }

  LatLng get _baslangicKonum {
    if (_soforKonum != null) return _soforKonum!;
    if (_durakKonum != null) return _durakKonum!;
    if (_veliKonum  != null) return _veliKonum!;
    return const LatLng(39.9334, 32.8597);
  }

  // ── Sofore WhatsApp ─────────────────────────────────────────────────────────
  Future<void> _soforeYaz() async {
    // Sadece servis saatinde iletisime izin ver
    if (!_takipAktif) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Soforle iletisim sadece servis saatlerinde aktiftir'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final tel = _sofor?['telefon'] as String?;
    if (tel == null || tel.isEmpty) return;
    final numara = tel.replaceAll(RegExp(r'[^\d]'), '');
    final url    = Uri.parse('https://wa.me/90$numara');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  // ── BUILD ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: Text(
          _ogrenci != null
              ? '${_ogrenci!['ad'] ?? ''} - Servis Takibi'
              : 'Canli Takip',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // Servis saati gostergesi
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _takipAktif
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    _takipAktif
                        ? Icons.radio_button_checked
                        : Icons.schedule,
                    size: 12,
                    color: _takipAktif ? Colors.green : Colors.white54,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _takipAktif
                        ? (_servisMod == 'sabah' ? 'Sabah' : 'Aksam')
                        : 'Kapali',
                    style: TextStyle(
                        fontSize: 11,
                        color: _takipAktif
                            ? Colors.green
                            : Colors.white54),
                  ),
                ]),
              ),
            ),
          ),
          if (_sofor != null && _takipAktif)
            IconButton(
              icon: const Icon(Icons.message,
                  color: Color(0xFF25D366)),
              onPressed: _soforeYaz,
              tooltip: 'Sofore Yaz',
            ),
        ],
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : _hata || _ogrenci == null
          ? _hataEkrani()
          : _icerik(),
    );
  }

  Widget _icerik() {
    // Servis saati disinda kilit ekrani goster
    if (!_takipAktif) {
      return _servisSaatiDisiEkrani();
    }

    final servisAktif = _sofor?['servisAktif'] == true;

    return Column(children: [
      _DurumBandi(
        servisAktif:   servisAktif,
        soforKonum:    _soforKonum,
        tahminiDakika: _tahminiDakika,
        mesafeMetre:   _mesafeMetre,
        oncekiOgrenci: _oncekiOgrenci,
        ogrenciBindi:  _ogrenci?['bindi'] == true,
        servisMod:     _servisMod,
        kacDurakKaldi: _kacDurakKaldi,
      ),
      Expanded(
        child: servisAktif && _soforKonum != null
            ? GoogleMap(
          initialCameraPosition: CameraPosition(
              target: _baslangicKonum, zoom: 14),
          markers:   _markers,
          polylines: _polylines,
          onMapCreated: (c) {
            _mapCtrl = c;
            _haritaGuncelle();
          },
          myLocationEnabled:       true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled:     false,
          mapToolbarEnabled:       false,
        )
            : _servisYokEkrani(servisAktif),
      ),
      if (_sofor != null)
        _SoforBilgiBandi(
          sofor:      _sofor!,
          onWhatsapp: _soforeYaz,
          aktif:      _takipAktif,
        ),
    ]);
  }

  // ── Servis Saati Disi Ekrani ─────────────────────────────────────────────────
  Widget _servisSaatiDisiEkrani() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _navy.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_clock_outlined,
                  size: 56, color: _navy),
            ),
            const SizedBox(height: 24),
            const Text(
              'Servis Takibi Kapali',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _navy),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8)
                ],
              ),
              child: Column(children: [
                _SaatSatiri(
                    ikon: Icons.wb_sunny_outlined,
                    etiket: 'Sabah Servisi',
                    saat: '06:30 - 09:30',
                    renk: Colors.orange),
                const Divider(height: 16),
                _SaatSatiri(
                    ikon: Icons.nights_stay_outlined,
                    etiket: 'Aksam Servisi',
                    saat: '15:00 - 18:30',
                    renk: Colors.indigo),
              ]),
            ),
            if (_sonrakiSaat.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '$_sonrakiSaat kadar bekleniyor',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            // Ogrenci durumu (saat disi de gozukur)
            if (_ogrenci != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6)
                  ],
                ),
                child: Row(children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _navy.withValues(alpha: 0.1),
                    child: Text(
                      (_ogrenci!['ad'] as String? ?? 'O')[0]
                          .toUpperCase(),
                      style: const TextStyle(
                          color: _navy, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_ogrenci!['ad'] ?? ''} ${_ogrenci!['soyad'] ?? ''}'.trim(),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _navy),
                      ),
                      Text(
                        _ogrenci!['durakAdi'] ?? '',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  )),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _servisYokEkrani(bool servisAktif) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              servisAktif
                  ? Icons.location_searching
                  : Icons.directions_bus_outlined,
              size: 72,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              servisAktif
                  ? 'Arac konumu bekleniyor...'
                  : 'Servis henuz baslamadi',
              style: TextStyle(color: Colors.grey[500], fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _hataEkrani() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_off_outlined,
              size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Kayitli ogrenci bulunamadi',
              style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _navy),
            onPressed: () => Navigator.pop(context),
            child: const Text('Geri Don'),
          ),
        ],
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// DURUM BANDI
// ═══════════════════════════════════════════════════════════════════════════
class _DurumBandi extends StatelessWidget {
  final bool servisAktif;
  final LatLng? soforKonum;
  final int? tahminiDakika;
  final int? mesafeMetre;
  final String oncekiOgrenci;
  final int    kacDurakKaldi;
  final bool ogrenciBindi;
  final String servisMod;

  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  const _DurumBandi({
    required this.servisAktif,
    required this.soforKonum,
    required this.tahminiDakika,
    required this.mesafeMetre,
    required this.oncekiOgrenci,
    this.kacDurakKaldi = -1,
    required this.ogrenciBindi,
    required this.servisMod,
  });

  @override
  Widget build(BuildContext context) {
    if (ogrenciBindi) {
      return Container(
        color: Colors.green,
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
        child: const Row(children: [
          Icon(Icons.check_circle, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text('Ogrenci servise bindi',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ]),
      );
    }

    if (!servisAktif) {
      return Container(
        color: Colors.grey.shade100,
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
        child: Row(children: [
          Icon(Icons.access_time, color: Colors.grey[500], size: 20),
          const SizedBox(width: 8),
          Text(
            servisMod == 'sabah'
                ? 'Sabah servisi baslamadi'
                : 'Aksam servisi baslamadi',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ]),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 12),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.directions_bus,
                    color: _navy, size: 18),
                const SizedBox(width: 6),
                Text(
                  tahminiDakika != null
                      ? 'Tahmini: $tahminiDakika dk'
                      : 'Konum aliniyor...',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _navy,
                      fontSize: 14),
                ),
              ]),
              if (mesafeMetre != null) ...[
                const SizedBox(height: 2),
                Text(
                  mesafeMetre! >= 1000
                      ? '${(mesafeMetre! / 1000).toStringAsFixed(1)} km uzakta'
                      : '$mesafeMetre metre uzakta',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ],
          ),
        ),
        // Kaç durak kaldı göstergesi
        if (kacDurakKaldi >= 0 && kacDurakKaldi <= 5)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: kacDurakKaldi == 0 ? Colors.green
                  : kacDurakKaldi == 1 ? Colors.orange
                  : Colors.blue,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                  kacDurakKaldi == 0 ? Icons.where_to_vote_outlined
                      : kacDurakKaldi == 1 ? Icons.directions_run
                      : Icons.directions_bus_outlined,
                  color: Colors.white, size: 14),
              const SizedBox(width: 6),
              Text(
                kacDurakKaldi == 0 ? 'Servis Duraginizda!'
                    : kacDurakKaldi == 1 ? '1 Durak Kaldi — Hazir Olun!'
                    : '$kacDurakKaldi Durak Kaldi',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ]),
          ),
        if (oncekiOgrenci.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _turuncu.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.person_pin_circle_outlined,
                  color: _turuncu, size: 14),
              const SizedBox(width: 4),
              Text(oncekiOgrenci,
                  style: const TextStyle(
                      color: _turuncu,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ]),
          ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SOFOR BİLGİ BANDI
// ═══════════════════════════════════════════════════════════════════════════
class _SoforBilgiBandi extends StatelessWidget {
  final Map<String, dynamic> sofor;
  final VoidCallback onWhatsapp;
  final bool aktif;

  static const _navy = Color(0xFF1a3a6b);

  const _SoforBilgiBandi({
    required this.sofor,
    required this.onWhatsapp,
    required this.aktif,
  });

  @override
  Widget build(BuildContext context) {
    final ad    = sofor['ad']       as String? ?? 'Sofor';
    final plaka = sofor['aracPlaka'] as String? ?? '-';
    final hiz   = (sofor['hiz'] as num?)?.toStringAsFixed(0) ?? '0';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _navy.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.drive_eta, color: _navy, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ad,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: _navy)),
              Text(
                  aktif
                      ? '$plaka  •  $hiz km/s'
                      : plaka,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
        // WhatsApp — sadece servis saatinde
        if (aktif)
          GestureDetector(
            onTap: onWhatsapp,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.message,
                  color: Color(0xFF25D366), size: 22),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.message,
                color: Colors.grey[300], size: 22),
          ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SAAT SATIRI
// ═══════════════════════════════════════════════════════════════════════════
class _SaatSatiri extends StatelessWidget {
  final IconData ikon;
  final String etiket;
  final String saat;
  final Color renk;

  const _SaatSatiri({
    required this.ikon,
    required this.etiket,
    required this.saat,
    required this.renk,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(ikon, color: renk, size: 20),
    const SizedBox(width: 10),
    Expanded(
      child: Text(etiket,
          style: TextStyle(
              fontWeight: FontWeight.w500, color: renk)),
    ),
    Text(saat,
        style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87)),
  ]);
}

