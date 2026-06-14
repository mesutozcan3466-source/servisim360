// ╔══════════════════════════════════════════════════════════════╗
// ║  DOSYA: lib/screens/sofor_panel_screen.dart
// ║  PROJE: servisim360
// ║  GUNCELLEME: Bosta sofor ekrani eklendi
// ╚══════════════════════════════════════════════════════════════╝
import 'package:flutter/material.dart';
import 'ai_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/arka_plan_konum_servisi.dart';
import 'sesli_yonlendirme_servisi.dart';
import '../screens/acil_durum_widget.dart';
import '../screens/qr_checkin_screen.dart';
import '../screens/sofor_rota_screen.dart';
import '../screens/sofor_ai_asistan_widget.dart';
import '../screens/sifre_degistir_screen.dart';
import '../services/session_service.dart';

class SoforPanelScreen extends StatefulWidget {
  const SoforPanelScreen({super.key});
  @override
  State<SoforPanelScreen> createState() => _SoforPanelScreenState();
}

class _SoforPanelScreenState extends State<SoforPanelScreen> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  Map<String, dynamic> _soforData  = {};
  Map<String, dynamic> _driverDoc  = {};
  Map<String, dynamic> _servisDoc  = {};  // services koleksiyonundan
  List<Map<String, dynamic>> _ogrenciler = [];
  bool   _yukleniyor       = true;
  bool   _servisAktif      = false;
  bool   _surucuBulunamadi = false;
  bool   _aiAcik           = false;

  final _sesli = SesliYonlendirmeServisi();
  String  _surucuId = '';
  String  _soforAd  = '';
  String? _firmaId;

  List<Map<String, dynamic>> _projeler  = [];
  String? _aktifProjeId;
  String? _aktifProjeAdi;

  StreamSubscription<Position>?      _konumStream;
  StreamSubscription<QuerySnapshot>? _notifStream;
  Timer?    _konumTimer;
  Position? _sonKonum;

  @override
  void initState() {
    super.initState();
    _girisKaydet();
    _yukle();
  }

  @override
  void dispose() {
    _konumStream?.cancel();
    _konumTimer?.cancel();
    _notifStream?.cancel();
    super.dispose();
  }

  Future<DocumentSnapshot?> _surucuDokumaniBul(String uid, String? email) async {
    final col = FirebaseFirestore.instance.collection('drivers');
    var q = await col.where('firmaId', isEqualTo: _firmaId).where('uid', isEqualTo: uid).limit(1).get();
    if (q.docs.isNotEmpty) return q.docs.first;
    q = await col.where('uid', isEqualTo: uid).limit(1).get();
    if (q.docs.isNotEmpty) return q.docs.first;
    if (email != null && email.isNotEmpty) {
      q = await col.where('email', isEqualTo: email).limit(1).get();
      if (q.docs.isNotEmpty) return q.docs.first;
    }
    final doc = await col.doc(uid).get();
    if (doc.exists) return doc;
    return null;
  }


  Future<void> _girisKaydet() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (uid.isEmpty) return;
      await FirebaseFirestore.instance.collection('giris_loglari').add({
        'kullanici': uid,
        'rol': 'sofor',
        'tarih': FieldValue.serverTimestamp(),
        'cihaz': 'mobil',
      });
    } catch (_) {}
  }

  Future<void> _yukle() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() { _yukleniyor = false; _surucuBulunamadi = true; });
      return;
    }
    _firmaId = await SessionService.instance.firmaldAl();
    try {
      final kulDoc = await FirebaseFirestore.instance.collection('kullanicilar').doc(user.uid).get();
      _soforData = kulDoc.data() ?? {};
      final driverDoc = await _surucuDokumaniBul(user.uid, user.email);
      if (driverDoc != null) {
        _driverDoc   = driverDoc.data() as Map<String, dynamic>;
        _servisAktif = _driverDoc['servisAktif'] ?? false;
        _surucuId    = driverDoc.id;
        final data = driverDoc.data() as Map<String, dynamic>?;
        _soforAd = (_driverDoc['ad'] ?? _driverDoc['adSoyad'] ?? '').toString();
        if (data != null && !data.containsKey('uid')) {
          try { await driverDoc.reference.update({'uid': user.uid}); } catch (_) {}
        }
        _aktifProjeId  = SessionService.instance.aktifProjeId ?? _driverDoc['aktifProjeId']  as String?;
        _aktifProjeAdi = SessionService.instance.aktifProjeAdi ?? _driverDoc['aktifProjeAdi'] as String?;
        await _projeleriYukle();
        await _ogrencileriYukle();
      } else {
        _surucuBulunamadi = true;
      }
    } catch (e) {
      debugPrint('Sofor yukle hata: $e');
    }
    // Akilli proje onerisi - saat bazli
    if (_aktifProjeId == null || _aktifProjeId!.isEmpty) {
      try {
        final now = TimeOfDay.now();
        final nowMin = now.hour * 60 + now.minute;
        // Soforun projelerini tara - saatine en yakin servisi oner
        final sofSnap = await FirebaseFirestore.instance
            .collection('services')
            .where('soforId', isEqualTo: _surucuId)
            .where('aktif', isEqualTo: true).get();
        String? onerilProjeId;
        String? onerilProjeAd;
        int enYakin = 9999;
        for (final doc in sofSnap.docs) {
          final d = doc.data();
          for (final saatField in ['sabahSaati', 'aksamSaati']) {
            final saatStr = d[saatField] as String? ?? '';
            if (saatStr.isEmpty) continue;
            final parts = saatStr.split(':');
            if (parts.length < 2) continue;
            final servisMin = (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
            final fark = (servisMin - nowMin).abs();
            if (fark < enYakin && fark <= 60) { // 60 dk icindeki servis
              enYakin = fark;
              onerilProjeId = d['projeId'] as String?;
              // Proje adini al
              if (onerilProjeId != null && onerilProjeId.isNotEmpty) {
                final prjSnap = await FirebaseFirestore.instance
                    .collection('projects').doc(onerilProjeId).get();
                onerilProjeAd = prjSnap.data()?['projeAd'] ?? prjSnap.data()?['ad'] ?? '';
              }
            }
          }
        }
        if (onerilProjeId != null && onerilProjeId.isNotEmpty && mounted) {
          SessionService.instance.aktifProjeAyarla(onerilProjeId, onerilProjeAd ?? '');
          setState(() { _aktifProjeId = onerilProjeId; _aktifProjeAdi = onerilProjeAd ?? ''; });
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _yukleniyor = false);
    if (_surucuId.isNotEmpty) {
      if (_servisAktif) _gpsBaslat();
      _notifDinle();
      _fcmTokenKaydet();
      _servisSaatiKontrol();
      _gelmeyecekDinle(); // Veli gelmeyecek secince anlik guncelle
      _sesli.baslat();
      await ArkaplanKonumServisi.baslatServisi();
    }
  }

  Future<void> _projeleriYukle() async {
    if (_surucuId.isEmpty || _firmaId == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('projects').where('firmaId', isEqualTo: _firmaId).get();
      final liste = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        final data      = doc.data();
        final surucular = data['surucular'];
        final projeIds  = _driverDoc['projeIds'];
        bool atanmis    = false;
        if (surucular is List) {
          atanmis = surucular.contains(_surucuId) ||
              surucular.contains(FirebaseAuth.instance.currentUser?.uid);
        }
        if (projeIds is List) atanmis = atanmis || projeIds.contains(doc.id);
        if (atanmis || (surucular == null && projeIds == null)) {
          liste.add({'id': doc.id, 'ad': data['ad'] ?? data['projeAdi'] ?? doc.id, ...data});
        }
      }
      _projeler = liste;
      if ((_aktifProjeId == null || _aktifProjeId!.isEmpty) && _projeler.isNotEmpty) {
        _aktifProjeId  = _projeler.first['id'];
        _aktifProjeAdi = _projeler.first['ad'];
        SessionService.instance.aktifProjeAyarla(_aktifProjeId!, _aktifProjeAdi ?? '');
        // Saate gore en yakin servisi liste basina tasi
        final now = TimeOfDay.now();
        final nowMin = now.hour * 60 + now.minute;
        _projeler.sort((a, b) {
          int saatFark(Map<String,dynamic> p) {
            final s = (p['saatBaslangic'] ?? p['sabahSaati'] ?? '').toString();
            if (!s.contains(':')) return 999999;
            final parts = s.split(':');
            final sMin = (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
            return (sMin - nowMin).abs();
          }
          return saatFark(a).compareTo(saatFark(b));
        });
      }
    } catch (e) {
      debugPrint('Proje yukle hata: $e');
    }
  }

  Future<void> _ogrencileriYukle() async {
    if (_surucuId.isEmpty) return;
    try {
      var q = FirebaseFirestore.instance.collection('students').where('surucuId', isEqualTo: _surucuId);
      if (_aktifProjeId != null && _aktifProjeId!.isNotEmpty) {
        q = q.where('projeId', isEqualTo: _aktifProjeId);
      }
      final snap = await q.get();
      _ogrenciler = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) {
      debugPrint('Ogrenci yukle hata: $e');
    }
    // services koleksiyonundan servis bilgisi yukle
    try {
      final servisId = _driverDoc['servisId'] as String? ?? '';
      if (servisId.isNotEmpty) {
        final sDoc = await FirebaseFirestore.instance
            .collection('services').doc(servisId).get();
        if (sDoc.exists && mounted) {
          setState(() => _servisDoc = sDoc.data() ?? {});
        }
      }
    } catch (_) {}
  }

  // ── COKLU GOREV SECIM EKRANI ────────────────────────────────
  Widget _cokluGorevSecimEkrani() {
    final ad = _soforData['ad'] ?? _driverDoc['adSoyad'] ?? 'Sofor';
    return Scaffold(
      backgroundColor: _navy,
      body: SafeArea(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          // Ust bar
          Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: Text(ad.isNotEmpty ? ad[0].toUpperCase() : 'S',
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(ad,
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 16))),
            IconButton(
                icon: const Icon(Icons.logout_outlined, color: Colors.white54),
                onPressed: () async {
                  await SessionService.instance.cikisYap();
                  if (mounted) Navigator.pushReplacementNamed(context, '/login');
                }),
          ]),
          const Spacer(),

          // Baslik
          const Icon(Icons.work_history_outlined, color: Colors.white54, size: 56),
          const SizedBox(height: 20),
          const Text('Servis Secin', style: TextStyle(
              color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Bugun ${_projeler.length} goreviniz var.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
          const SizedBox(height: 32),

          // Proje/servis kartlari
          ..._projeler.map((proje) {
            final projeAd  = proje['ad'] as String? ?? proje['projeAd'] ?? 'Proje';
            final tip      = proje['tip'] ?? proje['servisTuru'] ?? '';
            final saat     = proje['saatBaslangic'] ?? '';
            final saatBitis = proje['saatBitis'] ?? '';

            Color tipRenk = Colors.white;
            IconData tipIkon = Icons.directions_bus_rounded;
            if (tip == 'sabah') { tipRenk = Colors.orange; tipIkon = Icons.wb_sunny_outlined; }
            else if (tip == 'aksam') { tipRenk = Colors.indigo.shade200; tipIkon = Icons.nights_stay_outlined; }
            else if (tip == 'ogle') { tipRenk = Colors.teal.shade200; tipIkon = Icons.wb_twilight_outlined; }

            return GestureDetector(
              onTap: () => _projeGec(proje),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2))),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: tipRenk.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(tipIkon, color: tipRenk, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(projeAd, style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    if (saat.isNotEmpty)
                      Text('$saat — $saatBitis',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                  ])),
                  Icon(Icons.arrow_forward_ios_rounded,
                      color: Colors.white.withValues(alpha: 0.5), size: 16),
                ]),
              ),
            );
          }),

          const Spacer(),
          Text('Goreve baslamak icin servis secin',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
        ]),
      )),
    );
  }

  Future<void> _projeGec(Map<String, dynamic> proje) async {
    final yeniId  = proje['id'] as String;
    final yeniAdi = proje['ad'] as String;
    if (yeniId == _aktifProjeId) return;
    if (_servisAktif) {
      _gpsDurdur();
      await FirebaseFirestore.instance.collection('drivers').doc(_surucuId).update({
        'servisAktif': false, 'servisBitis': FieldValue.serverTimestamp(),
      });
      try {
        await FirebaseFirestore.instance.collection('surucu_konumlar').doc(_surucuId)
            .set({'aktif': false, 'bitisTarihi': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      } catch (_) {}
    }
    setState(() { _aktifProjeId = yeniId; _aktifProjeAdi = yeniAdi; _servisAktif = false; _yukleniyor = true; });
    SessionService.instance.aktifProjeAyarla(yeniId, yeniAdi);
    try {
      await FirebaseFirestore.instance.collection('drivers').doc(_surucuId)
          .update({'aktifProjeId': yeniId, 'aktifProjeAdi': yeniAdi});
    } catch (_) {}
    await _ogrencileriYukle();
    if (mounted) setState(() => _yukleniyor = false);
  }

  Future<void> _gpsBaslat() async {
    final izin = await Geolocator.requestPermission();
    if (izin == LocationPermission.denied || izin == LocationPermission.deniedForever) return;
    _konumStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 30),
    ).listen((pos) { _sonKonum = pos; _firestoreKaydet(pos); });
    _konumTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_sonKonum != null) _firestoreKaydet(_sonKonum!);
    });
  }

  void _gpsDurdur() {
    _konumStream?.cancel(); _konumTimer?.cancel();
    _konumStream = null; _konumTimer = null;
  }

  Future<void> _firestoreKaydet(Position pos) async {
    if (_surucuId.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('drivers').doc(_surucuId).update({
        'konum': GeoPoint(pos.latitude, pos.longitude),
        'hiz': pos.speed * 3.6,
        'konumGuncelleme': FieldValue.serverTimestamp(),
        'servisAktif': _servisAktif,
      });
      // Ayrica surucu_konumlar koleksiyonuna kaydet (admin harita icin)
      if (_servisAktif && _firmaId != null) {
        await FirebaseFirestore.instance
            .collection('surucu_konumlar').doc(_surucuId).set({
          'firmaId'   : _firmaId,
          'soforId'   : _surucuId,
          'konum'     : GeoPoint(pos.latitude, pos.longitude),
          'hiz'       : pos.speed * 3.6,
          'guncelleme': FieldValue.serverTimestamp(),
          'aktif'     : true,
        }, SetOptions(merge: true));
      }
      // Yaklasiyor kontrolu — her konum guncellemesinde
      await _yaklasiyorKontrol(pos);
    } catch (_) {}
  }

  // ── YAKLASIYOR BILDIRIMI ─────────────────────────────────────
  final Set<String> _yaklasiyorBildirimGonderildi = {};

  Future<void> _yaklasiyorKontrol(Position soforPos) async {
    // Gelmeyecek ogrencileri filtrele
    final bekleyenler = _ogrenciler.where((o) {
      if (o['bindi'] == true) return false;
      if (o['bugunGelmeyecek'] == true) return false;
      return true;
    }).toList();

    for (final ogr in bekleyenler) {
      final konum = ogr['konum'];
      if (konum == null) continue;
      double ogrLat, ogrLng;
      if (konum is GeoPoint) { ogrLat = konum.latitude; ogrLng = konum.longitude; }
      else continue;

      final mesafe = Geolocator.distanceBetween(
          soforPos.latitude, soforPos.longitude, ogrLat, ogrLng);

      final ogrId = ogr['id'] as String;

      // 700m — Servis yaklasiyor bildirimi
      if (mesafe <= 700 && !_yaklasiyorBildirimGonderildi.contains('700_$ogrId')) {
        _yaklasiyorBildirimGonderildi.add('700_$ogrId');
        final dakika = (mesafe / 300).ceil(); // 300m/dk ortalama hiz
        await _veliBildirimGonder(ogr, '🚍 Servis Yaklasiyor',
            'Servis ${mesafe.toInt()} metre uzakta, tahmini $dakika dakika.');
      }

      // 100m — Kapinizdayiz bildirimi
      if (mesafe <= 100 && !_yaklasiyorBildirimGonderildi.contains('100_$ogrId')) {
        _yaklasiyorBildirimGonderildi.add('100_$ogrId');
        await _veliBildirimGonder(ogr, '🚍 Kapinizdayiz',
            'Servis kapinizda bekliyor. Lutfen hazir olun!');
      }
    }
  }

  Future<void> _veliBildirimGonder(
      Map<String, dynamic> ogr, String baslik, String mesaj) async {
    try {
      final veliId = ogr['veliId'] ?? ogr['id'];
      await FirebaseFirestore.instance.collection('bildirimler').add({
        'aliciId'  : veliId,
        'firmaId'  : _firmaId,
        'surucuId' : _surucuId,
        'ogrenciId': ogr['id'],
        'baslik'   : baslik,
        'mesaj'    : mesaj,
        'tip'      : 'yaklasiyor',
        'okundu'   : false,
        'tarih'    : FieldValue.serverTimestamp(),
      });
    } catch (e) { debugPrint('Bildirim hata: $e'); }
  }

  // ── BUGUN GELMEYECEK — ROTA GUNCELLEMESI ────────────────────
  Future<void> _gelmeyecekGuncelle() async {
    // Firestore'dan guncel gelmeyecek durumunu cek
    try {
      final snap = await FirebaseFirestore.instance
          .collection('students')
          .where('surucuId', isEqualTo: _surucuId)
          .get();

      final guncelliste = snap.docs.map((d) {
        final data = d.data();
        return {
          'id'              : d.id,
          ...data,
          // Gelmeyecek ogrencileri listede tut ama filtrele
          'bugunGelmeyecek': data['bugunGelmeyecek'] ?? false,
        };
      }).toList();

      // Sirala: gelmeyecekler sona
      guncelliste.sort((a, b) {
        final aGelm = a['bugunGelmeyecek'] == true ? 1 : 0;
        final bGelm = b['bugunGelmeyecek'] == true ? 1 : 0;
        return aGelm.compareTo(bGelm);
      });

      if (mounted) setState(() => _ogrenciler = guncelliste);
    } catch (e) { debugPrint('Gelmeyecek guncelle hata: $e'); }
  }

  Future<void> _fcmTokenKaydet() async {
    if (_surucuId.isEmpty) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await FirebaseFirestore.instance.collection('drivers').doc(_surucuId)
            .update({'fcmToken': token});
      }
    } catch (e) {
      debugPrint('FCM token hata: $e');
    }
  }

  void _servisSaatiKontrol() {
    Timer.periodic(const Duration(minutes: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      final now    = TimeOfDay.now();
      final sabahB = _saatParse(_driverDoc['servisSaati']?['sabahBaslangic'] ?? '06:30');
      final sabahE = _saatParse(_driverDoc['servisSaati']?['sabahBitis']     ?? '09:30');
      final aksamB = _saatParse(_driverDoc['servisSaati']?['aksamBaslangic'] ?? '15:00');
      final aksamE = _saatParse(_driverDoc['servisSaati']?['aksamBitis']     ?? '18:30');
      final saatAktif = _saatAraliginda(now, sabahB, sabahE) || _saatAraliginda(now, aksamB, aksamE);
      if (saatAktif && !_servisAktif && _surucuId.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Servis saati basladi. Servisi baslatmak ister misiniz?'),
            backgroundColor: _navy, duration: Duration(seconds: 8), behavior: SnackBarBehavior.floating,
          ));
        }
      }
      if (!saatAktif && _servisAktif) {
        _gpsDurdur();
        FirebaseFirestore.instance.collection('drivers').doc(_surucuId).update({
          'servisAktif': false, 'servisBitis': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          setState(() => _servisAktif = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Servis saati bitti — Servis otomatik durduruldu.'),
            backgroundColor: Colors.orange, behavior: SnackBarBehavior.floating,
          ));
        }
      }
    });
  }

  TimeOfDay _saatParse(String saat) {
    try {
      final p = saat.split(':');
      return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
    } catch (_) {
      return const TimeOfDay(hour: 0, minute: 0);
    }
  }

  bool _saatAraliginda(TimeOfDay now, TimeOfDay bas, TimeOfDay bit) {
    final nowMin = now.hour * 60 + now.minute;
    final basMin = bas.hour * 60 + bas.minute;
    final bitMin = bit.hour * 60 + bit.minute;
    return nowMin >= basMin && nowMin <= bitMin;
  }

  void _gelmeyecekDinle() {
    if (_surucuId.isEmpty) return;
    // Ogrencilerin bugunGelmeyecek alanini dinle — veli degistirince anlik guncelle
    FirebaseFirestore.instance
        .collection('students')
        .where('surucuId', isEqualTo: _surucuId)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final liste = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      liste.sort((a, b) {
        final aGelm = a['bugunGelmeyecek'] == true ? 1 : 0;
        final bGelm = b['bugunGelmeyecek'] == true ? 1 : 0;
        return aGelm.compareTo(bGelm);
      });
      setState(() => _ogrenciler = liste);
    });
  }

  void _notifDinle() {
    if (_surucuId.isEmpty) return;
    _notifStream = FirebaseFirestore.instance
        .collection('notifications')
        .where('aliciId', isEqualTo: _surucuId)
        .where('okundu', isEqualTo: false)
        .snapshots()
        .listen((snap) {
      for (final doc in snap.docs) {
        final data = doc.data();
        if (!mounted) return;
        final tip = data['tip'] ?? '';

        // Rota onerisi — ozel dialog
        if (tip == 'rota_oneri') {
          _rotaOneriGoster(
            data['baslik'] ?? 'Rota Onerisi',
            data['mesaj']  ?? '',
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.notifications_outlined, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(data['baslik'] ?? 'Bildirim', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                Text(data['mesaj'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.white70)),
              ])),
            ]),
            backgroundColor: _navy, duration: const Duration(seconds: 5), behavior: SnackBarBehavior.floating,
            action: SnackBarAction(label: 'Tamam', textColor: _turuncu, onPressed: () {}),
          ));
        }
        doc.reference.update({'okundu': true});
      }
    });
  }

  void _rotaOneriGoster(String baslik, String mesaj) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.blue.shade50,
        title: Row(children: [
          Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.alt_route_outlined,
                  color: Colors.blue, size: 24)),
          const SizedBox(width: 10),
          Expanded(child: Text(baslik,
              style: const TextStyle(color: Colors.blue,
                  fontWeight: FontWeight.bold, fontSize: 15))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(mesaj,
              style: const TextStyle(fontSize: 13, height: 1.6)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10)),
            child: const Row(children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 14),
              SizedBox(width: 6),
              Expanded(child: Text(
                  'Google Maps acarak trafik durumunu kontrol edebilirsiniz.',
                  style: TextStyle(fontSize: 11, color: Colors.blue))),
            ]),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(_),
              child: const Text('Kapat')),
          ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                Navigator.pop(_);
                _navigasyonAc(); // Navigasyonu dogrudan ac
              },
              icon: const Icon(Icons.navigation_outlined, size: 16),
              label: const Text('Navigasyonu Ac')),
        ],
      ),
    );
  }

  Widget _bostaSatir(IconData icon, String text, bool tamam) =>
      Row(children: [
        Icon(icon,
            color: tamam ? Colors.greenAccent : Colors.white38,
            size: 18),
        const SizedBox(width: 12),
        Text(text, style: TextStyle(
            color: tamam ? Colors.white : Colors.white54,
            fontSize: 13)),
      ]);

  Future<void> _servisBaslatDurdur() async {
    if (_surucuId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Sofor kaydi bulunamadi'), backgroundColor: Colors.red));
      return;
    }
    final yeniDurum = !_servisAktif;
    if (yeniDurum) {
      final izin = await Geolocator.requestPermission();
      if (izin == LocationPermission.denied || izin == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Konum izni gerekli'), backgroundColor: Colors.red));
        }
        return;
      }
      await FirebaseFirestore.instance.collection('drivers').doc(_surucuId).update({
        'servisAktif': true, 'servisBaslangic': FieldValue.serverTimestamp(),
      });
      setState(() => _servisAktif = true);
      _gpsBaslat();
      if (mounted) Navigator.pushNamed(context, '/canli_rota');
    } else {
      _gpsDurdur();
      ArkaplanKonumServisi.durdur();
      await FirebaseFirestore.instance.collection('drivers').doc(_surucuId).update({
        'servisAktif': false, 'servisBitis': FieldValue.serverTimestamp(),
      });
      // Gunluk raporu kaydet
      try {
        final bindi   = _ogrenciler.where((o) => o['bindi']  == true).length;
        final gelmed  = _ogrenciler.where((o) => o['gelmedi'] == true).length;
        final firmaId = SessionService.instance.cachedFirmaId ?? '';
        await FirebaseFirestore.instance.collection('servis_raporlari').add({
          'firmaId'       : firmaId,
          'projeId'       : _aktifProjeId ?? '',
          'soforId'       : _surucuId,
          'tarih'         : FieldValue.serverTimestamp(),
          'toplamOgrenci' : _ogrenciler.length,
          'bindiler'      : bindi,
          'gelmediler'    : gelmed,
          'tamamlandi'    : true,
        });
      } catch (_) {}
      setState(() => _servisAktif = false);
    }
  }

  Future<void> _navigasyonAc() async {
    if (_ogrenciler.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Atanmis ogrenci bulunamadi'), backgroundColor: Colors.orange));
      return;
    }
    final ilk = _ogrenciler.firstWhere((o) => !(o['bindi'] ?? false), orElse: () => _ogrenciler.first);
    final konum = ilk['konum'];
    double? lat, lng;
    if (konum is GeoPoint) { lat = konum.latitude; lng = konum.longitude; }
    if (lat != null && lng != null) {
      final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
      if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) Navigator.pushNamed(context, '/canli_rota');
    }
  }



  void _gunlukRaporGoster() {
    final bindi  = _ogrenciler.where((o) => o['bindi'] == true).length;
    final gelmed = _ogrenciler.where((o) => o['gelmedi'] == true).length;
    final bekl   = _ogrenciler.length - bindi - gelmed;
    showDialog(context: context, builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(children: [
          Icon(Icons.assessment_outlined, color: Color(0xFF1a3a6b)),
          SizedBox(width: 10),
          Text('Gunluk Raporlarim', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _raporSatir('Toplam Ogrenci', '${_ogrenciler.length}', Icons.people_outlined, Colors.blue),
          _raporSatir('Araca Bindi',    '$bindi',  Icons.check_circle_outline, Colors.green),
          _raporSatir('Gelmedi',        '$gelmed', Icons.person_off_outlined,  Colors.red),
          _raporSatir('Bekliyor',       '$bekl',   Icons.hourglass_empty,      Colors.orange),
          const Divider(),
          _raporSatir('Servis Durumu',  _servisAktif ? 'Aktif' : 'Tamamlandi', Icons.directions_bus_outlined,
              _servisAktif ? Colors.green : Colors.grey),
        ]),
        actions: [
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1a3a6b), foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(_),
              child: const Text('Kapat')),
        ]));
  }

  Widget _raporSatir(String baslik, String deger, IconData ikon, Color renk) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [
        Icon(ikon, size: 18, color: renk),
        const SizedBox(width: 10),
        Expanded(child: Text(baslik, style: const TextStyle(fontSize: 13))),
        Text(deger, style: TextStyle(fontWeight: FontWeight.bold, color: renk, fontSize: 14)),
      ]));

  void _acilDurumDialog() {
    String? seciliTur;
    showDialog(
        context: context,
        builder: (_) => StatefulBuilder(
            builder: (dCtx, setS) => AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                title: const Row(children: [
                  Icon(Icons.emergency_outlined, color: Colors.red, size: 24),
                  SizedBox(width: 10),
                  Text('Acil Durum', style: TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold)),
                ]),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Acil durum turunu secin:',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 12),
                  ...['Arac Arizasi','Trafik Kazasi','Trafik Yogunlugu',
                    'Gecikme','Saglik Durumu','Diger'].map((tur) =>
                      GestureDetector(
                          onTap: () => setS(() => seciliTur = tur),
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                                color: seciliTur == tur
                                    ? Colors.red.withValues(alpha: 0.08) : Colors.grey[50],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: seciliTur == tur ? Colors.red : Colors.grey.shade200)),
                            child: Text(tur, style: TextStyle(
                                fontWeight: seciliTur == tur
                                    ? FontWeight.bold : FontWeight.normal,
                                color: seciliTur == tur ? Colors.red : Colors.grey[700])),
                          ))),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dCtx),
                      child: const Text('Iptal')),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red, foregroundColor: Colors.white),
                      onPressed: seciliTur == null ? null : () async {
                        await FirebaseFirestore.instance.collection('acil_durumlar').add({
                          'firmaId'  : _firmaId,
                          'soforId'  : _surucuId,
                          'soforAd'  : _soforAd,
                          'tur'      : seciliTur,
                          'tarih'    : FieldValue.serverTimestamp(),
                          'durum'    : 'bekliyor',
                        });
                        if (dCtx.mounted) {
                          Navigator.pop(dCtx);
                          ScaffoldMessenger.of(dCtx).showSnackBar(const SnackBar(
                              content: Text('Acil durum bildirimi gonderildi'),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating));
                        }
                      },
                      child: const Text('Gonder')),
                ])));
  }


  void _konumKaydet(Map<String, dynamic> ogr) async {
    final pos = await Geolocator.getCurrentPosition();
    final id  = ogr['id'] ?? ogr['docId'] ?? '';
    if (id.isEmpty) return;
    await FirebaseFirestore.instance.collection('students').doc(id).update({
      'konum': {'lat': pos.latitude, 'lng': pos.longitude},
      'konumVar': true,
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Konum kaydedildi'), backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating));
  }

  void _rotaYonetimine() {
    final ad = _soforData['ad'] ?? _soforData['email'] ?? 'Sofor';
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => SoforRotaScreen(surucuId: _surucuId, surucuAd: ad))).then((_) => _yukle());
  }

  void _velerileriAra() {
    showModalBottomSheet(
        context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
        builder: (_) => _VeliAraSheet(ogrenciler: _ogrenciler));
  }

  void _projeSecimAc() {
    if (_projeler.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Size atanmis baska proje yok'), backgroundColor: Colors.orange));
      return;
    }
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const Text('Proje Sec', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _navy)),
          const SizedBox(height: 16),
          ..._projeler.map((proje) {
            final secili = proje['id'] == _aktifProjeId;
            return GestureDetector(
              onTap: () { Navigator.pop(context); _projeGec(proje); },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: secili ? _navy : Colors.grey[50], borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: secili ? _navy : Colors.grey.shade200),
                ),
                child: Row(children: [
                  Icon(Icons.folder_outlined, color: secili ? Colors.white : _navy, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(proje['ad'] ?? '',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14,
                          color: secili ? Colors.white : Colors.black87))),
                  if (secili) const Icon(Icons.check_circle_outlined, color: _turuncu, size: 20),
                ]),
              ),
            );
          }),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return const Scaffold(backgroundColor: _navy,
          body: Center(child: CircularProgressIndicator(color: _turuncu)));
    }
    if (_surucuBulunamadi) {
      return Scaffold(backgroundColor: _navy,
          body: Center(child: Padding(padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.person_off_outlined, color: Colors.white54, size: 64),
                const SizedBox(height: 20),
                const Text('Sofor Kaydi Bulunamadi',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text('Hesabiniz henuz bir sofor profiline baglanmamis.\nYoneticinizle iletisime gecin.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
                    textAlign: TextAlign.center),
                const SizedBox(height: 30),
                OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38)),
                    onPressed: () async {
                      await SessionService.instance.cikisYap();
                      if (mounted) Navigator.pushReplacementNamed(context, '/login');
                    },
                    icon: const Icon(Icons.logout_outlined),
                    label: const Text('Cikis Yap')),
              ]))));
    }

    // Hic projeye atanmamis sofor
    if ((_projeler.isEmpty) && !_surucuBulunamadi) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child:
        Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.directions_bus_outlined, size: 72, color: Color(0xFF1a3a6b)),
          const SizedBox(height: 20),
          const Text('Henuz Proje Atanmadi',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1a3a6b))),
          const SizedBox(height: 10),
          const Text('Firma yoneticinizle gorusun.\nSize bir projeye atanmaniz gerekiyor.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 15)),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1a3a6b), foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) Navigator.pushReplacementNamed(context, '/');
            },
            icon: const Icon(Icons.logout_outlined),
            label: const Text('Cikis Yap'),
          ),
        ]))),
      );
    }


    // ── COKLU GOREV / BEKLEME EKRANLARI ─────────────────────────
    final soforDurum = (_driverDoc['soforDurum'] ?? _soforData['soforDurum'] ?? _soforData['durum']) as String? ?? 'bosta';
    final projeSayisi = _projeler.length;

    // Birden fazla proje varsa ve aktif proje secilmemisse → SECIM EKRANI
    if (projeSayisi > 1 && (_aktifProjeId == null || _aktifProjeId!.isEmpty)) {
      return _cokluGorevSecimEkrani();
    }

    if (soforDurum == 'bosta' && projeSayisi == 0) {
      final ad = _soforData['ad'] ?? _soforData['email'] ?? 'Sofor';
      final firmaAd = _soforData['firmaAd'] ?? '';
      return Scaffold(
        backgroundColor: _navy,
        body: SafeArea(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            // Ust: Avatar + ad
            Row(children: [
              CircleAvatar(radius: 24,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(ad.isNotEmpty ? ad[0].toUpperCase() : 'S',
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 20))),
              const SizedBox(width: 14),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ad, style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold,
                        fontSize: 16)),
                    if (firmaAd.isNotEmpty)
                      Text(firmaAd, style: const TextStyle(
                          color: Colors.white54, fontSize: 12)),
                  ])),
              IconButton(
                  icon: const Icon(Icons.logout_outlined,
                      color: Colors.white54),
                  onPressed: () async {
                    await SessionService.instance.cikisYap();
                    if (mounted) Navigator.pushReplacementNamed(
                        context, '/login');
                  }),
            ]),

            const Spacer(),

            // Ana ikon
            Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.pending_actions_outlined,
                    color: Colors.white54, size: 56)),
            const SizedBox(height: 24),

            const Text('Servis Atamasi Bekleniyor',
                style: TextStyle(color: Colors.white,
                    fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              'Yoneticiniz size bir proje ve servis atadiginda '
                  'bu ekran otomatik olarak acilacak.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14, height: 1.6),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // Durum kartlari
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12))),
              child: Column(children: [
                _bostaSatir(Icons.check_circle_outline,
                    'Sisteme kayit edildiniz', true),
                const SizedBox(height: 12),
                _bostaSatir(Icons.radio_button_unchecked,
                    'Proje atamasi bekleniyor', false),
                const SizedBox(height: 12),
                _bostaSatir(Icons.radio_button_unchecked,
                    'Ogrenci/personel listesi bekleniyor', false),
                const SizedBox(height: 12),
                _bostaSatir(Icons.radio_button_unchecked,
                    'Guzergah baglantisi bekleniyor', false),
              ]),
            ),

            const Spacer(),

            // Alt: Profil + Cikis
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                onPressed: () => Navigator.pushNamed(context, '/sifre_degistir'),
                icon: const Icon(Icons.key_outlined),
                label: const Text('Sifre Degistir'),
              )),
              const SizedBox(width: 12),
              Expanded(child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                onPressed: () async {
                  await SessionService.instance.cikisYap();
                  if (mounted) Navigator.pushReplacementNamed(
                      context, '/login');
                },
                icon: const Icon(Icons.logout_outlined),
                label: const Text('Cikis Yap'),
              )),
            ]),
            const SizedBox(height: 16),
          ]),
        )),
      );
    }

    final ad = _soforData['ad'] ?? _soforData['email'] ?? 'Sofor';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          decoration: const BoxDecoration(gradient: LinearGradient(
              colors: [_navy, Color(0xFF2a5298)],
              begin: Alignment.topLeft, end: Alignment.bottomRight)),
          child: Column(children: [
            Row(children: [
              CircleAvatar(radius: 22, backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(ad.isNotEmpty ? ad[0].toUpperCase() : 'S',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ad, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Row(children: [
                  Container(width: 8, height: 8, margin: const EdgeInsets.only(right: 5),
                      decoration: BoxDecoration(color: _servisAktif ? Colors.green : Colors.white38, shape: BoxShape.circle)),
                  Text(_servisAktif ? 'Servis Aktif' : 'Hazir',
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ])),
              GestureDetector(
                  onTap: () => setState(() => _aiAcik = !_aiAcik),
                  child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: _aiAcik ? _turuncu : Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.psychology_outlined,
                          color: _aiAcik ? Colors.white : Colors.white70, size: 20))),
              const SizedBox(width: 4),
              IconButton(icon: const Icon(Icons.key_outlined, color: Colors.white70),
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SifreDegistirScreen(rol: 'sofor')))),
              IconButton(icon: const Icon(Icons.logout_outlined, color: Colors.white70),
                  onPressed: () async {
                    await SessionService.instance.cikisYap();
                    if (mounted) Navigator.pushReplacementNamed(context, '/login');
                  }),
            ]),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _projeSecimAc,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  const Icon(Icons.folder_outlined, color: _turuncu, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    _aktifProjeAdi?.isNotEmpty == true ? _aktifProjeAdi!
                        : (_projeler.isEmpty ? 'Proje atanmamis' : 'Proje sec'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                  )),
                  if (_projeler.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: _turuncu.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(6)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.swap_horiz, color: _turuncu, size: 14),
                        const SizedBox(width: 4),
                        Text('${_projeler.length} proje',
                            style: const TextStyle(color: _turuncu, fontSize: 10, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                ]),
              ),
            ),
          ]),
        ),
        if (_firmaId != null) AcilDurumPaneli(firmaId: _firmaId!),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            if (_aiAcik) ...[
              SoforAiAsistanWidget(
                surucuAd: ad, surucuId: _surucuId, aracPlaka: _driverDoc['aracPlaka'] ?? '',
                ogrenciler: _ogrenciler,
                alinanSayisi: _ogrenciler.where((o) => o['bindi'] == true).length,
                servisDurumu: _servisAktif ? 'basladi' : 'bekleniyor',
                sabahBaslangic: _driverDoc['servisSaati']?['sabahBaslangic'] ?? '06:30',
                sabahBitis: _driverDoc['servisSaati']?['sabahBitis'] ?? '09:30',
                aksamBaslangic: _driverDoc['servisSaati']?['aksamBaslangic'] ?? '15:00',
                aksamBitis: _driverDoc['servisSaati']?['aksamBitis'] ?? '18:30',
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity, height: 72,
              child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _servisAktif ? Colors.red : Colors.green,
                      foregroundColor: Colors.white, elevation: 6,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  onPressed: _servisBaslatDurdur,
                  icon: Icon(_servisAktif ? Icons.stop_circle_outlined : Icons.play_circle_outlined, size: 30),
                  label: Text(_servisAktif ? 'Servisi Durdur' : 'Servisi Baslat',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _BuyukButon(ikon: Icons.navigation_outlined, etiket: 'Navigasyon', renk: Colors.blue, onTap: _navigasyonAc)),
              const SizedBox(width: 12),
              Expanded(child: _BuyukButon(ikon: Icons.route, etiket: 'Rota\n${_ogrenciler.length} kisi', renk: _navy, onTap: _rotaYonetimine)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _BuyukButon(ikon: Icons.phone_outlined, etiket: 'Veli Ara', renk: Colors.green, onTap: _velerileriAra)),
              const SizedBox(width: 12),
              Expanded(child: _BuyukButon(ikon: Icons.map_outlined, etiket: 'Harita', renk: Colors.teal,
                  onTap: () => Navigator.pushNamed(context, '/canli_rota'))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _BuyukButon(ikon: Icons.emergency_outlined, etiket: 'Acil Durum',
                  renk: Colors.red, onTap: _acilDurumDialog)),
              const SizedBox(width: 12),
              Expanded(child: _BuyukButon(ikon: Icons.assessment_outlined, etiket: 'Raporlarim',
                  renk: Colors.purple, onTap: _gunlukRaporGoster)),
            ]),
            const SizedBox(height: 12),
            if (_servisAktif) ...[
              Row(children: [
                Expanded(child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
                    label: const Text('Binis Tara', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const QrCheckInScreen(tip: 'binis'))).then((_) => _yukle()))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: _turuncu,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
                    label: const Text('Inis Tara', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const QrCheckInScreen(tip: 'inis'))).then((_) => _yukle()))),
              ]),
              const SizedBox(height: 12),
            ],
            if (_surucuId.isNotEmpty)
              AcilDurumButonu(surucuId: _surucuId, surucuAd: ad, plaka: _soforData['aracPlaka']),
            const SizedBox(height: 12),
            if (_servisAktif)
              Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3))),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _MiniIstat('${_ogrenciler.where((o) => o['bindi'] == true).length}', 'Bindi', Icons.check_circle_outline, Colors.green),
                    _MiniIstat('${_ogrenciler.where((o) => !(o['bindi'] ?? false)).length}', 'Bekliyor', Icons.hourglass_empty, Colors.orange),
                    _MiniIstat('${_ogrenciler.length}', 'Toplam', Icons.people_outline, _navy),
                  ])),
            const SizedBox(height: 80),
          ]),
        )),
      ])),
    );
  }
}

class _BuyukButon extends StatelessWidget {
  final IconData ikon; final String etiket; final Color renk; final VoidCallback onTap;
  const _BuyukButon({required this.ikon, required this.etiket, required this.renk, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(height: 80,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 8)]),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(ikon, color: renk, size: 28),
          const SizedBox(height: 6),
          Text(etiket, style: TextStyle(color: renk, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center),
        ])),
  );
}

class _MiniIstat extends StatelessWidget {
  final String deger, etiket; final IconData ikon; final Color renk;
  const _MiniIstat(this.deger, this.etiket, this.ikon, this.renk);
  @override
  Widget build(BuildContext context) => Column(children: [
    Icon(ikon, color: renk, size: 16),
    Text(deger, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: renk)),
    Text(etiket, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
  ]);
}

// ── OGRENCI DETAY KARTI ─────────────────────────────────────
class _OgrenciDetaySheet extends StatelessWidget {
  final Map<String, dynamic> ogr;
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  const _OgrenciDetaySheet({required this.ogr});

  @override
  Widget build(BuildContext context) {
    final ad      = '${ogr['ad'] ?? ''} ${ogr['soyad'] ?? ''}'.trim();
    final adres   = ogr['adres'] ?? ogr['address'] ?? '-';
    final babaTel = ogr['babaTel'] ?? ogr['veliTel'] ?? '';
    final anneTel = ogr['anneTel'] ?? '';
    final ogrTel  = ogr['ogrenciTel'] ?? '';
    final sinif   = ogr['sinif'] ?? '';
    final okul    = ogr['okul'] ?? '';
    final notlar  = ogr['notlar'] ?? ogr['not'] ?? '';
    final bindi   = ogr['bindi'] ?? false;

    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),

        // Ogrenci baslik
        Row(children: [
          CircleAvatar(radius: 24,
              backgroundColor: _navy.withValues(alpha: 0.1),
              child: Text(ad.isNotEmpty ? ad[0].toUpperCase() : '?',
                  style: const TextStyle(color: _navy,
                      fontWeight: FontWeight.bold, fontSize: 18))),
          const SizedBox(width: 14),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ad, style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 17)),
            if (sinif.isNotEmpty || okul.isNotEmpty)
              Text('$sinif${sinif.isNotEmpty && okul.isNotEmpty ? " • " : ""}$okul',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: bindi ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8)),
            child: Text(bindi ? '✅ Bindi' : '⏳ Bekliyor',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                    color: bindi ? Colors.green : Colors.orange)),
          ),
          const SizedBox(width: 8),
          // Devamsiz uyarisi
          if (ogr['bugunGelmeyecek'] == true || ogr['devamsiz'] == true)
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                child: const Text('⚠️ Devamsiz', style: TextStyle(fontSize: 12,
                    fontWeight: FontWeight.bold, color: Colors.red))),
        ]),
        const SizedBox(height: 8),
        // Gelmedi / Birakildi butonlari
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              final sid = ogr['id'] ?? ogr['docId'] ?? '';
              if (sid.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('students').doc(sid)
                    .update({'gelmedi': true, 'bugunDurumu': 'gelmedi'});
                await FirebaseFirestore.instance
                    .collection('absence_requests').add({
                  'firmaId': ogr['firmaId'] ?? '',
                  'ogrenciId': sid,
                  'ogrenciAd': ogr['adSoyad'] ?? ogr['ad'] ?? '',
                  'tarih': FieldValue.serverTimestamp(),
                  'durum': 'onaylandi', 'kaynak': 'sofor',
                });
              }
              Navigator.pop(context);
            },
            icon: const Icon(Icons.person_off_outlined, size: 16),
            label: const Text('Gelmedi', style: TextStyle(fontSize: 12)),
          )),
          const SizedBox(width: 8),
          Expanded(child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              final id = ogr['id'] ?? ogr['docId'] ?? '';
              if (id.isNotEmpty) {
                await FirebaseFirestore.instance.collection('students').doc(id)
                    .update({'bindi': true, 'bugunDurumu': 'bindi'});
              }
              Navigator.pop(context);
            },
            icon: const Icon(Icons.check_circle_outline, size: 16),
            label: const Text('Bindi', style: TextStyle(fontSize: 12)),
          )),
        ]),
        const Divider(height: 20),

        // Adres
        _detayRow(Icons.location_on_outlined, 'Adres', adres, Colors.blue),
        if (notlar.isNotEmpty)
          _detayRow(Icons.notes_outlined, 'Not', notlar, Colors.purple),
        const SizedBox(height: 12),

        // Telefon butonlari
        if (babaTel.isNotEmpty)
          _telBtn('Baba / Veli', babaTel, Colors.green, context),
        if (anneTel.isNotEmpty) ...[
          const SizedBox(height: 8),
          _telBtn('Anne', anneTel, Colors.pink, context),
        ],
        if (ogrTel.isNotEmpty) ...[
          const SizedBox(height: 8),
          _telBtn('Ogrenci', ogrTel, _navy, context),
        ],
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _detayRow(IconData ikon, String label, String deger, Color renk) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(ikon, size: 16, color: renk),
          const SizedBox(width: 8),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            Text(deger, style: const TextStyle(fontSize: 13)),
          ])),
        ]),
      );

  Widget _telBtn(String label, String tel, Color renk, BuildContext ctx) =>
      SizedBox(width: double.infinity, child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
            backgroundColor: renk, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10))),
        onPressed: () async {
          final uri = Uri.parse('tel:$tel');
          try {
            // ignore: deprecated_member_use
            await launchUrl(uri);
          } catch (_) {}
        },
        icon: const Icon(Icons.phone_outlined, size: 18),
        label: Text('$label — $tel',
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ));
}

class _VeliAraSheet extends StatelessWidget {
  final List<Map<String, dynamic>> ogrenciler;
  static const _navy = Color(0xFF1a3a6b);
  const _VeliAraSheet({required this.ogrenciler});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
      const SizedBox(height: 16),
      const Text('Veli Ara', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _navy)),
      const SizedBox(height: 16),
      if (ogrenciler.isEmpty)
        const Padding(padding: EdgeInsets.all(20), child: Text('Atanmis ogrenci yok', style: TextStyle(color: Colors.grey)))
      else
        ...ogrenciler.map((ogr) {
          final tel = ogr['veliTel'] ?? ogr['veliTelefon'] ?? '';
          return ListTile(
              leading: CircleAvatar(backgroundColor: _navy.withValues(alpha: 0.1),
                  child: Text((ogr['ad'] ?? '?')[0].toUpperCase(),
                      style: const TextStyle(color: _navy, fontWeight: FontWeight.bold))),
              title: Text(ogr['ad'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(tel.isNotEmpty ? tel : 'Telefon yok', style: TextStyle(color: Colors.grey[500])),
              trailing: tel.isNotEmpty ? Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(Icons.phone_outlined, color: Colors.green),
                    onPressed: () async { final url = Uri.parse('tel:$tel'); if (await canLaunchUrl(url)) await launchUrl(url); }),
                IconButton(icon: const Icon(Icons.message_outlined, color: Color(0xFF25D366)),
                    onPressed: () async {
                      final n = tel.replaceAll(RegExp(r'\D'), '');
                      final url = Uri.parse('https://wa.me/90$n');
                      if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
                    }),
              ]) : null);
        }),
      const SizedBox(height: 20),
    ]),
  );
}