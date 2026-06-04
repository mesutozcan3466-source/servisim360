import 'dart:async'; import 'package:flutter/material.dart';
import 'ai_widget.dart'; import 'package:cloud_firestore/cloud_firestore.dart'; import 'package:firebase_auth/firebase_auth.dart'; import 'package:geolocator/geolocator.dart'; import 'package:google_maps_flutter/google_maps_flutter.dart'; import 'package:url_launcher/url_launcher.dart'; import '../services/session_service.dart'; import '../screens/qr_checkin_screen.dart'; import '../screens/veli_ai_asistan_widget.dart'; import '../screens/sifre_degistir_screen.dart';

// ── Durak Grubu Modeli ──────────────────────────────────────────────────────
class _DurakGrubu {
  final int    sira;
  final List<String> ogrenciIds;
  bool   hepsiBindi;
  final double lat, lng;

  _DurakGrubu({
    required this.sira,
    required this.ogrenciIds,
    required this.hepsiBindi,
    required this.lat,
    required this.lng,
  });
}

class VeliPanelScreen extends StatefulWidget {
  const VeliPanelScreen({super.key});
  @override
  State<VeliPanelScreen> createState() => _VeliPanelScreenState();
}

class _VeliPanelScreenState extends State<VeliPanelScreen> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  Map<String, dynamic> _veliData  = {};
  Map<String, dynamic>? _ogrenci;
  String? _ogrenciId;
  Map<String, dynamic>? _soforData;
  String? _soforDocId;
  bool   _yukleniyor = true;
  String? _firmaId;
  String? _veliId;

  // Harita
  GoogleMapController? _mapCtrl;
  LatLng? _veliKonum;
  LatLng? _soforKonum;
  bool _haritaAcik = false;

  // 500m alarm + durak sistemi
  StreamSubscription<Position>? _konumSub;
  StreamSubscription<DocumentSnapshot>? _soforSub;
  bool _alarmVerildi      = false;
  int  _kacDurakKaldi     = -1;
  bool durakBildirimi2   = false;
  bool durakBildirimi1   = false;
  bool _hazirolBildirimi  = false;   String _oncekiOgrenciAd = '';

  @override
  void initState() { super.initState(); _yukle(); }

  @override
  void dispose() {
    _konumSub?.cancel();
    _soforSub?.cancel();
    _mapCtrl?.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { setState(() => _yukleniyor = false); return; }
    _firmaId = await SessionService.instance.firmaldAl();
    try {       final kulDoc = await FirebaseFirestore.instance.collection('kullanicilar').doc(user.uid).get();
    _veliData = kulDoc.data() ?? {};
    var pSnap = await FirebaseFirestore.instance.collection('parents')           .where('uid', isEqualTo: user.uid).limit(1).get();
    if (pSnap.docs.isEmpty && user.email != null) {         pSnap = await FirebaseFirestore.instance.collection('parents')             .where('email', isEqualTo: user.email).limit(1).get();
    }
    if (pSnap.docs.isNotEmpty) {
      _veliId = pSnap.docs.first.id;
      _veliData = {..._veliData, ...pSnap.docs.first.data()};         if (!(pSnap.docs.first.data()).containsKey('uid')) {           await pSnap.docs.first.reference.update({'uid': user.uid});
      }
    }
    var ogrSnap = await FirebaseFirestore.instance.collection('students')           .where('veliId', isEqualTo: _veliId ?? user.uid).limit(1).get();
    if (ogrSnap.docs.isEmpty && user.email != null) {         ogrSnap = await FirebaseFirestore.instance.collection('students')             .where('veliEmail', isEqualTo: user.email).limit(1).get();
    }
    if (ogrSnap.docs.isNotEmpty) {
      _ogrenciId = ogrSnap.docs.first.id;         _ogrenci   = {'id': _ogrenciId, ...ogrSnap.docs.first.data()};         final surucuId = _ogrenci!['surucuId'] as String?;
      if (surucuId != null && surucuId.isNotEmpty) {           var dSnap = await FirebaseFirestore.instance.collection('drivers')               .where('uid', isEqualTo: surucuId).limit(1).get();
      if (dSnap.docs.isEmpty) {             final d = await FirebaseFirestore.instance.collection('drivers').doc(surucuId).get();
      if (d.exists) { _soforDocId = d.id; _soforData = d.data(); }
      } else {
        _soforDocId = dSnap.docs.first.id;
        _soforData  = dSnap.docs.first.data();
      }
      // Sofor konumunu canli dinle

      if (_soforDocId != null) _soforCanliDinle();
      }
    }     } catch (e) { debugPrint('Veli yukle hata: $e'); }

    if (mounted) {
      setState(() => _yukleniyor = false);
      _konumBaslat();
    }
  }

  // Sofor konumunu canli dinle
  void _soforCanliDinle() {
    if (_soforDocId == null) return;
    _soforSub = FirebaseFirestore.instance         .collection('drivers').doc(_soforDocId!).snapshots()
        .listen((snap) {
      if (!snap.exists || !mounted) return;
      final data = snap.data()!;
      setState(() => _soforData = data);
      final konum = data['konum'];
      if (konum != null) {
        final yeniKonum = konum is GeoPoint
            ? LatLng(konum.latitude, konum.longitude)
            : null;
        if (yeniKonum != null) {
          setState(() => _soforKonum = yeniKonum);
          // Harita aciksa markeri guncelle

          if (_haritaAcik && _mapCtrl != null) {
            _mapCtrl!.animateCamera(CameraUpdate.newLatLng(yeniKonum));
          }
          // 500m alarm

          if (_veliKonum != null && !_alarmVerildi) {
            final mesafe = Geolocator.distanceBetween(
                _veliKonum!.latitude, _veliKonum!.longitude,
                yeniKonum.latitude, yeniKonum.longitude);
            if (mesafe <= 500) {
              _alarmVerildi = true;
              _yaklasiyorDialog(mesafe.toInt());
            }
          }
        }
      }
      // Durak sırası güncelle
      _durakSirasiGuncelle();
    });
  }

  // Veli konumunu al
  Future<void> _konumBaslat() async {
    final izin = await Geolocator.requestPermission();
    if (izin == LocationPermission.denied || izin == LocationPermission.deniedForever) return;

    try {
      final pos = await Geolocator.getCurrentPosition(
      );
      if (mounted) setState(() => _veliKonum = LatLng(pos.latitude, pos.longitude));
    } catch (_) {}

    _konumSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 50),
    ).listen((pos) {
      if (mounted) setState(() => _veliKonum = LatLng(pos.latitude, pos.longitude));
    });
  }

  void _yaklasiyorDialog(int mesafe) {
    if (!mounted) return;
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.orange.shade50,
      title: const Row(children: [
        Icon(Icons.directions_bus, color: Colors.orange, size: 28),
        SizedBox(width: 8),         Text('Servis Yaklasiyor!', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
      ]),       content: Text('Servis yaklasik $mesafe metre uzakta. Cocugunuzu hazirlayin!'),
      actions: [
          AiAsistanButonu(ekranAdi: 'Veli Paneli'),ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          onPressed: () => Navigator.pop(context),           child: const Text('Tamam', style: TextStyle(color: Colors.white)))],
    ));
  }

  // ── Durak Sırası + Akıllı Bildirim (Aynı durakta N öğrenci desteği) ────────
  //
  //  MANTIK:   //  1. Şoförün tüm öğrencileri sira'ya göre sıralanır
  //  2. Öğrenciler KONUMA göre gruplanır (50m içindekiler = aynı durak)
  //  3. Benim durak grubum bulunur (hangi grup indeksi?)
  //  4. Şoförün şu an kaçıncı durak grubuna gittiği hesaplanır
  //  5. Fark = kalan durak sayısı → bildirim tetiklenir
  //  6. Aynı duraktaki TÜM velilere aynı anda bildirim gider
  //     (çünkü hepsi aynı durak grubunda, kalan durak = aynı)
  //
  Future<void> _durakSirasiGuncelle() async {
    if (_soforDocId == null || _ogrenciId == null) return;
    try {
      var q = FirebaseFirestore.instance
          .collection('students')           .where('surucuId', isEqualTo: _soforDocId)           .orderBy('sira');       if (_firmaId != null) q = q.where('firmaId', isEqualTo: _firmaId);
      final snap = await q.get();
      if (snap.docs.isEmpty) return;

      final docs = snap.docs;

      // ── DURAK GRUPLAMA ────────────────────────────────────────────
      // Konuma göre grupla: 50m içindekiler = aynı durak

      final List<_DurakGrubu> duraklar = [];
      for (final doc in docs) {
        final data  = doc.data();         final konum = data['konum'];
        double? lat, lng;
        if (konum is GeoPoint) {
          lat = konum.latitude; lng = konum.longitude;
        }         // Konum yoksa sira'ya göre tekil durak

        if (lat == null || lng == null) {
          duraklar.add(_DurakGrubu(
            sira: data['sira'] as int? ?? 999,
            ogrenciIds: [doc.id],             hepsiBindi: data['bindi'] == true,
            lat: 0, lng: 0,
          ));
          continue;
        }

        // Bu öğrenci mevcut bir gruba yakın mı? (50m eşiği)

        bool grupBulundu = false;
        for (final grup in duraklar) {
          if (grup.lat == 0 && grup.lng == 0) continue;
          final mesafe = _mesafeHesapla(lat, lng, grup.lat, grup.lng);
          if (mesafe <= 50) {
            // Aynı gruba ekle

            grup.ogrenciIds.add(doc.id);             if (data['bindi'] != true) grup.hepsiBindi = false;
            grupBulundu = true;
            break;
          }
        }
        if (!grupBulundu) {
          duraklar.add(_DurakGrubu(             sira: data['sira'] as int? ?? 999,
            ogrenciIds: [doc.id],             hepsiBindi: data['bindi'] == true,
            lat: lat, lng: lng,
          ));
        }
      }

      // Sıraya göre durakları sırala

      duraklar.sort((a, b) => a.sira.compareTo(b.sira));

      // ── BENİM DURAK GRUBUM ────────────────────────────────────────

      final benimGrupIdx = duraklar.indexWhere(
              (g) => g.ogrenciIds.contains(_ogrenciId));
      if (benimGrupIdx < 0) return;

      // ── ŞOFÖRÜN ŞU ANKİ HEDEFİ ───────────────────────────────────
      // Henüz hepsi binmemiş en küçük sıralı grup

      final hedefGrupIdx = duraklar.indexWhere((g) => !g.hepsiBindi);
      if (hedefGrupIdx < 0) {
        // Herkes bindi
        if (mounted) setState(() { _kacDurakKaldi = 0; _oncekiOgrenciAd = 'Herkes bindi'; });

        return;
      }

      final yeniKalan = benimGrupIdx - hedefGrupIdx;

      // Onceki durak aciklamasi
      String oncekiAd = '';
      if (yeniKalan > 0 && benimGrupIdx > 0) {
        final oncekiGrup  = duraklar[benimGrupIdx - 1];
        final oncekiBindi = oncekiGrup.hepsiBindi;
        if (oncekiBindi) {           oncekiAd = 'Onceki durak bindi';
        } else {
          // Önceki duraktaki öğrenci adlarını bul

          final adlar = docs
              .where((d) => oncekiGrup.ogrenciIds.contains(d.id))               .map((d) => d.data()['ad'] as String? ?? '')
              .where((a) => a.isNotEmpty)
              .toList();
          oncekiAd = adlar.isNotEmpty               ? '${adlar.join(' ve ')} duraksinda'               : 'Bir onceki duraksinda';
        }
      } else if (yeniKalan <= 0) {
        final benimGrup = duraklar[benimGrupIdx];
        final kacinciOgr = benimGrup.ogrenciIds.length;
        oncekiAd = kacinciOgr > 1             ? 'Sizin duraginizda ($kacinciOgr ogrenci)'             : 'Siz siradasiniz!';
      }

      if (mounted) setState(() {
        _kacDurakKaldi   = yeniKalan;
        _oncekiOgrenciAd = oncekiAd;
      });

      _akilliBildirimGonder(yeniKalan);     } catch (e) { debugPrint('Durak sirasi hata: \$e'); }
  }

  // Haversine — metre cinsinden mesafe
  double _mesafeHesapla(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000.0;
    final dLat = (lat2 - lat1) * 3.14159265358979 / 180;
    final dLng = (lng2 - lng1) * 3.14159265358979 / 180;
    final a = (dLat/2)*(dLat/2) +
        (lat1*3.14159265358979/180).abs() * (lat2*3.14159265358979/180).abs() *
            (dLng/2)*(dLng/2);
    return R * 2 * (a < 1 ? a : 1);
  }

  void _akilliBildirimGonder(int kalan) {
    if (!mounted) return;

    if (kalan > 2) {
      // Sıfırla — yeni tur başladı

      durakBildirimi2  = false;
      durakBildirimi1  = false;
      _hazirolBildirimi = false;
      return;
    }

    if (kalan == 2 && !durakBildirimi2) {
      durakBildirimi2 = true;       _snackBildirim('2 Durak Kaldi',           'Servis 2 durak sonra sizin duraginiza geliyor. Hazirlanmaya baslayin.',
          Colors.blue, Icons.directions_bus_outlined);
    }
    if (kalan == 1 && !durakBildirimi1) {
      durakBildirimi1 = true;       _snackBildirim('1 Durak Kaldi!',           'Servis bir sonraki duraginizda! Hemen cikmayi hazirlayin.',
          Colors.orange, Icons.directions_run);
    }
    if (kalan <= 0 && !_hazirolBildirimi) {
      _hazirolBildirimi = true;
      _yaklasiyorDurakDialog();
    }
  }

  void _snackBildirim(String baslik, String mesaj, Color renk, IconData ikon) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: const Duration(seconds: 6),
      behavior: SnackBarBehavior.floating,
      backgroundColor: renk,
      content: Row(children: [
        Icon(ikon, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(baslik, style: const TextStyle(fontWeight: FontWeight.bold,
                color: Colors.white, fontSize: 13)),
            Text(mesaj, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        )),
      ]),
    ));
  }

  void _yaklasiyorDurakDialog() {
    if (!mounted) return;
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.green.shade50,
      title: const Row(children: [
        Icon(Icons.where_to_vote_outlined, color: Colors.green, size: 28),
        SizedBox(width: 8),         Text('Servis Duraginizda!',
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 15)),
      ]),
      content: Text(         '${_ogrenci?['ad'] ?? 'Ogrenci'} hazir olsun! Servis simdi duraginizda.',
      ),
      actions: [ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          onPressed: () => Navigator.pop(context),           child: const Text('Tamam', style: TextStyle(color: Colors.white)))],
    ));
  }

  void _devamsizlikBildir() {
    if (_ogrenci == null) return;
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => _DevamsizlikSheet(ogrenci: _ogrenci!, firmaId: _firmaId));
  }

  Future<void> _soforeWhatsapp() async {     final tel = _soforData?['telefon'] as String?;
  if (tel == null || tel.isEmpty) {       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sofor telefon numarasi bulunamadi')));
  return;
  }     final n = tel.replaceAll(RegExp(r'[^\d]'), '');     final url = Uri.parse('https://wa.me/90$n');

  if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  String _tahminiVaris() {     if (_soforData == null || _soforKonum == null) return '--';     final ogrKonum = _ogrenci?['konum'];     if (ogrKonum == null) return '~10 dk';
  try {       final hiz = (_soforData!['hiz'] as num?)?.toDouble() ?? 30;
  double olat, olng;
  if (ogrKonum is GeoPoint) { olat = ogrKonum.latitude; olng = ogrKonum.longitude; }       else return '~10 dk';
  final mesafe = Geolocator.distanceBetween(
      _soforKonum!.latitude, _soforKonum!.longitude, olat, olng);
  final dk = ((mesafe / 1000) / (hiz > 0 ? hiz : 30) * 60).round();       if (dk <= 0) return '< 1 dk';       if (dk > 60) return '> 1 saat';       return '~$dk dk';     } catch (_) { return '~10 dk'; }
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) return const Scaffold(backgroundColor: _navy,
        body: Center(child: CircularProgressIndicator(color: _turuncu)));
    final ad     = _veliData['ad'] != null ? '${_veliData['ad']} ${_veliData['soyad'] ?? ''}'.trim() : _veliData['email'] ?? 'Veli';     final ogrAdi = _ogrenci != null ? '${_ogrenci!['ad'] ?? ''} ${_ogrenci!['soyad'] ?? ''}'.trim() : '';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: SafeArea(child: Column(children: [
        // Baslik

        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_navy, Color(0xFF2a5298)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight)),
          child: Row(children: [
            Container(width: 38, height: 38,
                decoration: const BoxDecoration(color: _turuncu, shape: BoxShape.circle),                 child: const Center(child: Text('S', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [               const Text('Servisim360', style: TextStyle(color: Colors.white70, fontSize: 11)),
              Text(ogrAdi.isNotEmpty ? ogrAdi : ad,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  overflow: TextOverflow.ellipsis),
            ])),
            // AI Asistan butonu

            GestureDetector(
                onTap: () => showModalBottomSheet(
                    context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
                    builder: (_) => Container(
                        height: MediaQuery.of(context).size.height * 0.7,
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(color: Colors.white,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                        child: VeliAiAsistanWidget(
                          veliAd:    ad,                           veliId:    _veliId ?? '',
                          cocuklar:  _ogrenci != null ? [_ogrenci!] : [],                           soforAd:   _soforData?['ad'] ?? '',                           soforTel:  _soforData?['telefon'] ?? '',                           servisDurumu: _soforData?['servisAktif'] == true ? 'basladi' : 'bekleniyor',
                        ))),
                child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: _turuncu.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.support_agent_outlined, color: _turuncu, size: 20))),
            const SizedBox(width: 4),
            // Sifre degistir

            IconButton(
                icon: const Icon(Icons.key_outlined, color: Colors.white54, size: 20),                 tooltip: 'Sifre Degistir',
                onPressed: () => Navigator.push(context, MaterialPageRoute(                     builder: (_) => const SifreDegistirScreen(rol: 'veli')))),
            IconButton(
                icon: const Icon(Icons.logout_outlined, color: Colors.white54, size: 20),
                onPressed: () async {
                  await SessionService.instance.cikisYap();                   if (mounted) Navigator.pushReplacementNamed(context, '/login');
                }),
          ]),
        ),

        Expanded(child: _ogrenci == null ? _bosEkran() : _anaIcerik(ogrAdi)),
      ])),
    );
  }

  Widget _bosEkran() => Center(child: Padding(padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.child_care_outlined, size: 72, color: Colors.grey[300]),
        const SizedBox(height: 16),         const Text('Kayitli ogrenci yok', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),         Text('Yoneticinize basvurarak ogrencilerinizi ekletebilirsiniz.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[500])),
        const SizedBox(height: 24),
        ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: _navy,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),             onPressed: () => Navigator.pushNamed(context, '/veli_basvuru'),             icon: const Icon(Icons.person_add_outlined), label: const Text('Basvuru Formu')),
      ])));

  Widget _anaIcerik(String ogrAdi) {     final servisAktif = _soforData?['servisAktif'] == true;

  return RefreshIndicator(
    onRefresh: _yukle,
    child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(children: [

        // 1. SERVIS DURUMU + HARITA KARTI
        _ServisDurumuHaritaKarti(
          soforData:       _soforData,
          ogrenci:         _ogrenci!,
          soforKonum:      _soforKonum,
          veliKonum:       _veliKonum,
          tahminiVaris:    _tahminiVaris(),
          haritaAcik:      _haritaAcik,
          kacDurakKaldi:   _kacDurakKaldi,
          oncekiOgrenciAd: _oncekiOgrenciAd,
          onHaritaToggle:  () => setState(() => _haritaAcik = !_haritaAcik),
          onMapCreated:    (ctrl) {
            _mapCtrl = ctrl;
            final hedef = _soforKonum ?? _veliKonum;
            if (hedef != null) {
              Future.delayed(const Duration(milliseconds: 500), () =>
                  _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(hedef, 14)));
            }
          },
        ),
        const SizedBox(height: 12),

        // 2. 4 ANA BUTON

        Row(children: [             Expanded(child: _AnaButon(ikon: Icons.location_on, etiket: 'Servis Nerede?', renk: Colors.blue,
            onTap: () => setState(() => _haritaAcik = true))),
          const SizedBox(width: 10),             Expanded(child: _AnaButon(ikon: Icons.event_busy, etiket: 'Bugun Gelmeyecek', renk: Colors.orange, onTap: _devamsizlikBildir)),
          const SizedBox(width: 10),             Expanded(child: _AnaButon(ikon: Icons.notifications, etiket: 'Bildirim ler', renk: _navy,                 onTap: () => Navigator.pushNamed(context, '/bildirimler'))),
          const SizedBox(width: 10),             Expanded(child: _AnaButon(ikon: Icons.message, etiket: 'Iletisim', renk: const Color(0xFF25D366), onTap: _soforeWhatsapp)),
        ]),
        const SizedBox(height: 16),

        // 3. OGRENCI KART
        _OgrenciDetayKarti(
            ogrenci: _ogrenci!, soforData: _soforData,
            onQrTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => OgrenciQrKodu(ogrenciId: _ogrenciId!, ogrenciAdi: ogrAdi)))),
        const SizedBox(height: 12),

        // 4. SOFOR KART

        if (_soforData != null)
          _SoforBilgiKarti(soforData: _soforData!, onAra: _soforeWhatsapp),
        const SizedBox(height: 12),

        // 5. AI ASISTAN

        if (servisAktif)
          VeliAiAsistanWidget(               veliAd:    _veliData['ad'] ?? 'Veli',               veliId:    _veliId ?? '',
            cocuklar:  _ogrenci != null ? [_ogrenci!] : [],               soforAd:   _soforData?['ad'] ?? '',               soforTel:  _soforData?['telefon'] ?? '',               servisDurumu: 'basladi',
          ),

        const SizedBox(height: 80),
      ]),
    ),
  );
  }
}

// =
//  SERVIS DURUMU + HARITA KARTI
// =
class _ServisDurumuHaritaKarti extends StatelessWidget {
  final Map<String, dynamic>? soforData;
  final Map<String, dynamic> ogrenci;
  final LatLng? soforKonum;
  final LatLng? veliKonum;
  final String tahminiVaris;
  final bool haritaAcik;
  final int    kacDurakKaldi;
  final String oncekiOgrenciAd;
  final VoidCallback onHaritaToggle;
  final Function(GoogleMapController) onMapCreated;

  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  const _ServisDurumuHaritaKarti({
    required this.soforData, required this.ogrenci,
    required this.soforKonum, required this.veliKonum,
    required this.tahminiVaris, required this.haritaAcik,
    required this.onHaritaToggle, required this.onMapCreated,
    this.kacDurakKaldi = -1,     this.oncekiOgrenciAd = '',
  });

  @override
  Widget build(BuildContext context) {     final servisAktif = soforData?['servisAktif'] == true;     final bindi       = ogrenci['bindi'] == true;

  Color durumRenk;
  String durumBaslik, durumAciklama;
  IconData durumIkon;
  if (bindi) {       durumRenk = Colors.green; durumBaslik = 'Serviste';       durumAciklama = '${ogrenci['ad'] ?? 'Ogrenci'} servise bindi';
  durumIkon = Icons.check_circle;
  } else if (servisAktif) {       durumRenk = _turuncu; durumBaslik = 'Servis Yolda';       durumAciklama = 'Tahmini varis: $tahminiVaris';
  durumIkon = Icons.directions_bus;
  } else {       durumRenk = Colors.grey; durumBaslik = 'Servis Baslamadi';       durumAciklama = 'Servis henuz yola cikmadi';
  durumIkon = Icons.access_time;
  }

  // Harita marker

  final markers = <Marker>{};
  // 🚌 Şoför marker — yeşil (canlı konum)

  if (soforKonum != null) {
    markers.add(Marker(           markerId: const MarkerId('sofor'),
        position: soforKonum!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(             title: '${soforData?['ad'] ?? 'Servis Araci'}',             snippet: soforData?['aracPlaka'] ?? '',
        )));
  }
  // 📍 Benim konumum — mavi

  if (veliKonum != null) {
    markers.add(Marker(           markerId: const MarkerId('veli'),
        position: veliKonum!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),           infoWindow: const InfoWindow(title: 'Benim Konumum')));
  }
  // Ogrenci duragi — turuncu
  final ogrKonum = ogrenci['konum'];
  if (ogrKonum is GeoPoint) {
    markers.add(Marker(           markerId: const MarkerId('ogrenci'),
        position: LatLng(ogrKonum.latitude, ogrKonum.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(             title: '${ogrenci['ad'] ?? ''} Duragi',             snippet: ogrenci['durakAdi'] ?? ogrenci['adres'] ?? '',
        )));
  }

  final baslangic = soforKonum ?? veliKonum ?? const LatLng(41.0082, 28.9784);

  return Container(
    decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [durumRenk, durumRenk.withValues(alpha: 0.7)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: durumRenk.withValues(alpha: 0.3),
            blurRadius: 12, offset: const Offset(0, 4))]),
    child: Column(children: [
      // Durum bilgisi

      Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(durumIkon, color: Colors.white, size: 26),
            const SizedBox(width: 10),
            Expanded(child: Text(durumBaslik, style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
            // Harita toggle butonu

            GestureDetector(
              onTap: onHaritaToggle,
              child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(haritaAcik ? Icons.map : Icons.map_outlined,
                        color: Colors.white, size: 16),
                    const SizedBox(width: 4),                       Text(haritaAcik ? 'Haritayi Kapat' : 'Haritada Goster',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ])),
            ),
          ]),
          const SizedBox(height: 6),
          Text(durumAciklama, style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9), fontSize: 13)),
          if (servisAktif && !bindi) ...[
            const SizedBox(height: 8),
            // Kalan durak göstergesi

            if (kacDurakKaldi >= 0 && kacDurakKaldi <= 5)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                    color: kacDurakKaldi == 0 ? Colors.green.withValues(alpha: 0.3)
                        : kacDurakKaldi == 1 ? Colors.orange.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.4))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                      kacDurakKaldi == 0 ? Icons.where_to_vote_outlined
                          : kacDurakKaldi == 1 ? Icons.directions_run
                          : Icons.directions_bus_outlined,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(                       kacDurakKaldi == 0 ? 'Servis Duraginizda!'                       : kacDurakKaldi == 1 ? ' 1 Durak Kaldi — Hazir Olun!'                       : ' $kacDurakKaldi Durak Kaldi',
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 13)),
                ]),
              ),
            if (oncekiOgrenciAd.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.person_pin_circle_outlined, color: Colors.white70, size: 14),
                  const SizedBox(width: 6),                     Text('Servis simdi: $oncekiOgrenciAd',
                      style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ]),
              ),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.timer_outlined, color: Colors.white, size: 16),
                  const SizedBox(width: 6),                     Text('Tahmini Varis: $tahminiVaris',
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 13)),
                ])),
          ],
        ]),
      ),

      // HARITA (aciksa)

      if (haritaAcik)
        ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
          child: SizedBox(
            height: 250,
            child: Stack(children: [
              GoogleMap(
                  onMapCreated: onMapCreated,
                  initialCameraPosition: CameraPosition(target: baslangic, zoom: 14),
                  markers: markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false),
              // Konum butonu

              Positioned(right: 12, bottom: 12,
                  child: GestureDetector(
                      onTap: () {
                        final hedef = soforKonum ?? veliKonum;
                        if (hedef != null) {}
                      },
                      child: Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)]),
                          child: const Icon(Icons.my_location, color: _navy, size: 20)))),
              // Sofor aktif gostergesi

              if (servisAktif && soforKonum != null)
                Positioned(top: 10, left: 10,
                    child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                          const SizedBox(width: 5),                             const Text('Canli Takip', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ]))),
            ]),
          ),
        ),
    ]),
  );
  }
}

// = Ortak widgetlar =
class _AnaButon extends StatelessWidget {
  final IconData ikon; final String etiket; final Color renk; final VoidCallback onTap;
  const _AnaButon({required this.ikon, required this.etiket, required this.renk, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
      child: Container(height: 80,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 8, offset: const Offset(0, 2))]),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: renk.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(ikon, color: renk, size: 22)),
            const SizedBox(height: 5),
            Text(etiket, textAlign: TextAlign.center,
                style: TextStyle(color: renk, fontSize: 10, fontWeight: FontWeight.bold)),
          ])));
}

class _OgrenciDetayKarti extends StatelessWidget {
  final Map<String, dynamic> ogrenci;
  final Map<String, dynamic>? soforData;
  final VoidCallback onQrTap;
  static const _navy = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  const _OgrenciDetayKarti({required this.ogrenci, required this.soforData, required this.onQrTap});
  @override
  Widget build(BuildContext context) {     final bindi   = ogrenci['bindi'] == true;     final ogrAdi  = '${ogrenci['ad'] ?? ''} ${ogrenci['soyad'] ?? ''}'.trim();     final sinif   = ogrenci['sinif'] as String? ?? '';     final durak   = ogrenci['durakAdi'] as String? ?? '';
  return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          border: bindi ? Border.all(color: Colors.green.withValues(alpha: 0.3)) : null,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
      child: Column(children: [
        Row(children: [
          CircleAvatar(radius: 26, backgroundColor: _navy.withValues(alpha: 0.1),                 child: Text(ogrAdi.isNotEmpty ? ogrAdi[0].toUpperCase() : 'O',
              style: const TextStyle(color: _navy, fontWeight: FontWeight.bold, fontSize: 20))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ogrAdi, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _navy)),
            if (sinif.isNotEmpty) Text(sinif, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            if (durak.isNotEmpty) Row(children: [
              const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
              const SizedBox(width: 2),
              Text(durak, style: const TextStyle(fontSize: 12, color: Colors.grey))]),
          ])),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: bindi ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20)),                 child: Text(bindi ? 'Serviste' : 'Bekliyor',
              style: TextStyle(color: bindi ? Colors.green : Colors.orange, fontSize: 12, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: _turuncu,
                side: BorderSide(color: _turuncu.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10)),
            onPressed: onQrTap,
            icon: const Icon(Icons.qr_code, size: 18),               label: const Text('Servis QR Kodumu Goster', style: TextStyle(fontWeight: FontWeight.bold)))),
      ]));
  }
}

class _SoforBilgiKarti extends StatelessWidget {
  final Map<String, dynamic> soforData; final VoidCallback onAra;
  static const _navy = Color(0xFF1a3a6b);
  const _SoforBilgiKarti({required this.soforData, required this.onAra});
  @override
  Widget build(BuildContext context) {     final soforAdi  = soforData['ad'] as String? ?? 'Sofor';     final plaka     = soforData['aracPlaka'] as String? ?? '-';     final servisAktif = soforData['servisAktif'] == true;
  return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _navy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.drive_eta, color: _navy, size: 24)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(soforAdi, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _navy)),             Text('Plaka: $plaka', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Row(children: [
            Container(width: 7, height: 7, margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(color: servisAktif ? Colors.green : Colors.grey, shape: BoxShape.circle)),               Text(servisAktif ? 'Servis aktif' : 'Servis baslamadi',
                style: TextStyle(fontSize: 11, color: servisAktif ? Colors.green : Colors.grey)),
          ]),
        ])),
        GestureDetector(onTap: onAra,
            child: Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF25D366).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.message, color: Color(0xFF25D366), size: 22))),
      ]));
  }
}

class _DevamsizlikSheet extends StatefulWidget {
  final Map<String, dynamic> ogrenci; final String? firmaId;
  const _DevamsizlikSheet({required this.ogrenci, required this.firmaId});
  @override State<_DevamsizlikSheet> createState() => _DevamsizlikSheetState();
}

class _DevamsizlikSheetState extends State<_DevamsizlikSheet> {
  static const _navy = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);   String _tip = 'hepsi'; bool _yukleniyor = false;

  Future<void> _gonder() async {
    setState(() => _yukleniyor = true);
    final ogr = widget.ogrenci;
    try {
      String aciklama;
      switch (_tip) {         case 'sabah': aciklama = 'Sadece sabah binecek'; break;         case 'aksam': aciklama = 'Sadece aksam binecek'; break;         default:      aciklama = 'Bugun hic gelmeyecek'; break;
      }       await FirebaseFirestore.instance.collection('absence_requests').add({         'ogrenciId': ogr['id'], 'ogrenciAd': '${ogr['ad']} ${ogr['soyad'] ?? ''}'.trim(),         'firmaId': widget.firmaId, 'surucuId': ogr['surucuId'],         'tip': _tip, 'aciklama': aciklama,         'tarih': FieldValue.serverTimestamp(), 'durum': 'bildirildi'});
      if (mounted) {
        Navigator.pop(context);         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bildirildi: $aciklama'), backgroundColor: Colors.green));
      }
    } catch (e) {       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _yukleniyor = false);
  }

  @override
  Widget build(BuildContext context) {     final ogrAdi = '${widget.ogrenci['ad'] ?? ''} ${widget.ogrenci['soyad'] ?? ''}'.trim();
  return Container(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),           const Text('Bugun Gelmeyecek', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _navy)),
        const SizedBox(height: 4),
        Text(ogrAdi, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        const SizedBox(height: 20),           _TipSecenegi(secili: _tip == 'hepsi', ikon: Icons.cancel_outlined,               baslik: 'Bugun Hic Gelmeyecek', aciklama: 'Sabah ve aksam servise binmeyecek',               renk: Colors.red, onTap: () => setState(() => _tip = 'hepsi')),
        const SizedBox(height: 8),           _TipSecenegi(secili: _tip == 'sabah', ikon: Icons.wb_sunny_outlined,               baslik: 'Sadece Sabah Binecek', aciklama: 'Sabah servise binecek, aksamki yok',               renk: Colors.orange, onTap: () => setState(() => _tip = 'sabah')),
        const SizedBox(height: 8),           _TipSecenegi(secili: _tip == 'aksam', ikon: Icons.nights_stay_outlined,               baslik: 'Sadece Aksam Binecek', aciklama: 'Sabahki yok, aksamki servise binecek',               renk: Colors.indigo, onTap: () => setState(() => _tip = 'aksam')),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 52,
            child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _turuncu,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: _yukleniyor ? null : _gonder,
                child: _yukleniyor
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))                       : const Text('Sofore Bildir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)))),
      ]));
  }
}

class _TipSecenegi extends StatelessWidget {
  final bool secili; final IconData ikon; final String baslik, aciklama;
  final Color renk; final VoidCallback onTap;
  const _TipSecenegi({required this.secili, required this.ikon, required this.baslik,
    required this.aciklama, required this.renk, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
      child: AnimatedContainer(duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: secili ? renk.withValues(alpha: 0.08) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: secili ? renk : Colors.grey.shade200, width: secili ? 2 : 1)),
          child: Row(children: [
            Icon(ikon, color: secili ? renk : Colors.grey, size: 24),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(baslik, style: TextStyle(fontWeight: FontWeight.bold,
                  color: secili ? renk : Colors.black87, fontSize: 14)),
              Text(aciklama, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ])),
            if (secili) Icon(Icons.check_circle, color: renk, size: 20),
          ])));
}
