// ╔══════════════════════════════════════════════════════════════╗
// ║  DOSYA: lib/screens/sofor_panel_screen.dart
// ║  PROJE: servisim360
// ║  GÜNCELLEME: Boşta şoför ekranı eklendi
// ╚══════════════════════════════════════════════════════════════╝
import 'package:flutter/material.dart';
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
  List<Map<String, dynamic>> _ogrenciler = [];
  bool   _yukleniyor       = true;
  bool   _servisAktif      = false;
  bool   _surucuBulunamadi = false;
  bool   _aiAcik           = false;

  final _sesli = SesliYonlendirmeServisi();
  String  _surucuId = '';
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
        if (data != null && !data.containsKey('uid')) {
          try { await driverDoc.reference.update({'uid': user.uid}); } catch (_) {}
        }
        _aktifProjeId  = SessionService.instance.aktifProjeld ?? _driverDoc['aktifProjeId']  as String?;
        _aktifProjeAdi = SessionService.instance.aktifProjeAdi ?? _driverDoc['aktifProjeAdi'] as String?;
        await _projeleriYukle();
        await _ogrencileriYukle();
      } else {
        _surucuBulunamadi = true;
      }
    } catch (e) {
      debugPrint('Sofor yukle hata: $e');
    }
    if (mounted) setState(() => _yukleniyor = false);
    if (_surucuId.isNotEmpty) {
      if (_servisAktif) _gpsBaslat();
      _notifDinle();
      _fcmTokenKaydet();
      _servisSaatiKontrol();
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
      });
    } catch (_) {}
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
        doc.reference.update({'okundu': true});
      }
    });
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

    // ── BOŞTA ŞOFÖR EKRANI ──────────────────────────────────────
    // Proje atanmamış şoför — sadece bekleme ekranı görür
    final soforDurum = _soforData['durum'] as String? ?? 'bosta';
    final projeSayisi = _projeler.length;
    if (soforDurum == 'bosta' && projeSayisi == 0) {
      final ad = _soforData['ad'] ?? _soforData['email'] ?? 'Sofor';
      final firmaAd = _soforData['firmaAd'] ?? '';
      return Scaffold(
        backgroundColor: _navy,
        body: SafeArea(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            // Üst: Avatar + ad
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

            const Text('Servis Ataması Bekleniyor',
                style: TextStyle(color: Colors.white,
                    fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              'Yöneticiniz size bir proje ve servis atadığında '
                  'bu ekran otomatik olarak açılacak.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14, height: 1.6),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // Durum kartları
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12))),
              child: Column(children: [
                _bostaSatir(Icons.check_circle_outline,
                    'Sisteme kayıt edildiniz', true),
                const SizedBox(height: 12),
                _bostaSatir(Icons.radio_button_unchecked,
                    'Proje ataması bekleniyor', false),
                const SizedBox(height: 12),
                _bostaSatir(Icons.radio_button_unchecked,
                    'Öğrenci/personel listesi bekleniyor', false),
                const SizedBox(height: 12),
                _bostaSatir(Icons.radio_button_unchecked,
                    'Güzergah bağlantısı bekleniyor', false),
              ]),
            ),

            const Spacer(),

            // Alt: Profil + Çıkış
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
                label: const Text('Şifre Değiştir'),
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
                label: const Text('Çıkış Yap'),
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