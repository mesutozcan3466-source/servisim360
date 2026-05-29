import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../services/session_service.dart';

class BireyselSoforScreen extends StatefulWidget {
  const BireyselSoforScreen({super.key});
  @override
  State<BireyselSoforScreen> createState() => _BireyselSoforScreenState();
}

class _BireyselSoforScreenState extends State<BireyselSoforScreen>
    with SingleTickerProviderStateMixin {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  late final TabController _tabCtrl;

  Map<String, dynamic> _soforData = {};
  List<Map<String, dynamic>> _ogrenciler = [];
  bool   _yukleniyor  = true;
  bool   _servisAktif = false;
  String _surucuId    = '';
  String? _firmaId;

  StreamSubscription<Position>? _konumStream;
  Timer? _konumTimer;
  Position? _sonKonum;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _yukle();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _konumStream?.cancel();
    _konumTimer?.cancel();
    super.dispose();
  }

  Future<void> _yukle() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { setState(() => _yukleniyor = false); return; }

    _firmaId = await SessionService.instance.firmaIdAl();

    try {
      final kulDoc = await FirebaseFirestore.instance
          .collection('kullanicilar').doc(user.uid).get();
      _soforData = kulDoc.data() ?? {};

      // 3 kademeli driver arama
      final db  = FirebaseFirestore.instance;
      DocumentSnapshot? driverDoc;

      var q = await db.collection('drivers')
          .where('uid', isEqualTo: user.uid).limit(1).get();
      if (q.docs.isNotEmpty) driverDoc = q.docs.first;

      if (driverDoc == null && user.email != null) {
        q = await db.collection('drivers')
            .where('email', isEqualTo: user.email).limit(1).get();
        if (q.docs.isNotEmpty) driverDoc = q.docs.first;
      }

      if (driverDoc == null) {
        final d = await db.collection('drivers').doc(user.uid).get();
        if (d.exists) driverDoc = d;
      }

      if (driverDoc != null) {
        final dd = driverDoc.data() as Map<String, dynamic>;
        _servisAktif = dd['servisAktif'] ?? false;
        _surucuId    = driverDoc.id;
        _soforData   = {..._soforData, ...dd};

        if (!dd.containsKey('uid')) {
          await driverDoc.reference.update({'uid': user.uid});
        }

        final ogrSnap = await db.collection('students')
            .where('surucuId', isEqualTo: _surucuId).get();
        _ogrenciler = ogrSnap.docs
            .map((d) => {'id': d.id, ...d.data()}).toList();
      }
    } catch (e) {
      debugPrint('BireyselSofor yukle hata: $e');
    }

    if (mounted) setState(() => _yukleniyor = false);
    if (_servisAktif && _surucuId.isNotEmpty) _gpsBaslat();
  }

  Future<void> _gpsBaslat() async {
    final izin = await Geolocator.requestPermission();
    if (izin == LocationPermission.denied ||
        izin == LocationPermission.deniedForever) return;

    _konumStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, distanceFilter: 30),
    ).listen((pos) {
      _sonKonum = pos;
      _konumKaydet(pos);
    });

    _konumTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_sonKonum != null) _konumKaydet(_sonKonum!);
    });
  }

  void _gpsDurdur() {
    _konumStream?.cancel();
    _konumTimer?.cancel();
    _konumStream = null;
    _konumTimer  = null;
  }

  Future<void> _konumKaydet(Position pos) async {
    if (_surucuId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('drivers').doc(_surucuId).update({
        'konum':           GeoPoint(pos.latitude, pos.longitude),
        'hiz':             pos.speed * 3.6,
        'konumGuncelleme': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> _servisToggle() async {
    if (_surucuId.isEmpty) return;
    final yeni = !_servisAktif;
    if (yeni) {
      final izin = await Geolocator.requestPermission();
      if (izin == LocationPermission.denied ||
          izin == LocationPermission.deniedForever) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Konum izni gerekli'),
                backgroundColor: Colors.red));
        return;
      }
      await FirebaseFirestore.instance
          .collection('drivers').doc(_surucuId).update({
        'servisAktif': true,
        'servisBaslangic': FieldValue.serverTimestamp(),
      });
      setState(() => _servisAktif = true);
      _gpsBaslat();
    } else {
      _gpsDurdur();
      await FirebaseFirestore.instance
          .collection('drivers').doc(_surucuId).update({
        'servisAktif': false,
        'servisBitis': FieldValue.serverTimestamp(),
      });
      setState(() => _servisAktif = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return const Scaffold(
        backgroundColor: _navy,
        body: Center(child: CircularProgressIndicator(color: _turuncu)),
      );
    }

    final ad = _soforData['ad'] ?? _soforData['email'] ?? 'Sofor';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ad, style: const TextStyle(fontSize: 15,
              fontWeight: FontWeight.bold)),
          Row(children: [
            Container(width: 7, height: 7,
                margin: const EdgeInsets.only(right: 5),
                decoration: BoxDecoration(
                    color: _servisAktif ? Colors.green : Colors.white38,
                    shape: BoxShape.circle)),
            Text(_servisAktif ? 'Servis Aktif' : 'Hazir',
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ]),
        ]),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _turuncu.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('Bireysel',
                style: TextStyle(color: _turuncu, fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined, color: Colors.white70),
            onPressed: () async {
              await SessionService.instance.cikisYap();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: _turuncu,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Panel'),
            Tab(text: 'Ogrenciler'),
            Tab(text: 'Ayarlar'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _panelTab(ad),
          _ogrencilerTab(),
          _ayarlarTab(),
        ],
      ),
    );
  }

  Widget _panelTab(String ad) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Servis butonu
        SizedBox(
          width: double.infinity, height: 72,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _servisAktif ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
              elevation: 6,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _servisToggle,
            icon: Icon(_servisAktif
                ? Icons.stop_circle_outlined
                : Icons.play_circle_outlined, size: 30),
            label: Text(
              _servisAktif ? 'Servisi Durdur' : 'Servisi Baslat',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 16),

        Row(children: [
          Expanded(child: _Buton(
            ikon: Icons.navigation_outlined, etiket: 'Navigasyon',
            renk: Colors.blue,
            onTap: () => Navigator.pushNamed(context, '/canli_rota'),
          )),
          const SizedBox(width: 12),
          Expanded(child: _Buton(
            ikon: Icons.map_outlined, etiket: 'Harita',
            renk: Colors.teal,
            onTap: () => Navigator.pushNamed(context, '/harita'),
          )),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _Buton(
            ikon: Icons.phone_outlined, etiket: 'Veli Ara',
            renk: Colors.green,
            onTap: _veliAra,
          )),
          const SizedBox(width: 12),
          Expanded(child: _Buton(
            ikon: Icons.bar_chart_outlined, etiket: 'Analiz',
            renk: _navy,
            onTap: () => Navigator.pushNamed(context, '/analiz'),
          )),
        ]),
        const SizedBox(height: 16),

        // Ozet
        if (_servisAktif && _ogrenciler.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Mini(
                    '${_ogrenciler.where((o) => o['bindi'] == true).length}',
                    'Bindi', Icons.check_circle_outline, Colors.green),
                _Mini(
                    '${_ogrenciler.where((o) => !(o['bindi'] ?? false)).length}',
                    'Bekliyor', Icons.hourglass_empty, Colors.orange),
                _Mini('${_ogrenciler.length}', 'Toplam',
                    Icons.people_outline, _navy),
              ],
            ),
          ),
      ]),
    );
  }

  Widget _ogrencilerTab() {
    if (_ogrenciler.isEmpty) {
      return const Center(child: Text('Atanmis ogrenci yok',
          style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _ogrenciler.length,
      itemBuilder: (_, i) {
        final ogr   = _ogrenciler[i];
        final bindi = ogr['bindi'] == true;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: bindi
                  ? Colors.green.withValues(alpha: 0.1)
                  : _navy.withValues(alpha: 0.1),
              child: Text(
                (ogr['ad'] as String? ?? 'O')[0].toUpperCase(),
                style: TextStyle(
                    color: bindi ? Colors.green : _navy,
                    fontWeight: FontWeight.bold),
              ),
            ),
            title: Text('${ogr['ad'] ?? ''} ${ogr['soyad'] ?? ''}'.trim(),
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(ogr['sinif'] as String? ?? '',
                style: const TextStyle(fontSize: 12)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: bindi
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(bindi ? 'Bindi' : 'Bekliyor',
                    style: TextStyle(
                        color: bindi ? Colors.green : Colors.orange,
                        fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: Icon(
                  bindi ? Icons.remove_circle_outline
                      : Icons.check_circle_outline,
                  color: bindi ? Colors.red : Colors.green,
                ),
                onPressed: () => _bindiToggle(ogr, !bindi),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _ayarlarTab() {
    final plaka = _soforData['aracPlaka'] as String? ?? '-';
    final tel   = _soforData['telefon']  as String? ?? '-';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _BilgiKarti('Arac Plaka', plaka, Icons.directions_car_outlined),
        _BilgiKarti('Telefon',    tel,   Icons.phone_outlined),
        _BilgiKarti('Firma ID',   _firmaId ?? '-', Icons.business_outlined),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.notifications_outlined, color: _navy),
          title: const Text('Bildirimler'),
          trailing: const Icon(Icons.arrow_forward_ios_outlined,
              size: 14, color: Colors.grey),
          onTap: () => Navigator.pushNamed(context, '/bildirimler'),
        ),
        ListTile(
          leading: const Icon(Icons.schedule_outlined, color: _navy),
          title: const Text('Servis Saatleri'),
          trailing: const Icon(Icons.arrow_forward_ios_outlined,
              size: 14, color: Colors.grey),
          onTap: () => Navigator.pushNamed(context, '/servis_saati'),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout_outlined, color: Colors.red),
          title: const Text('Cikis Yap',
              style: TextStyle(color: Colors.red)),
          onTap: () async {
            await SessionService.instance.cikisYap();
            if (mounted) Navigator.pushReplacementNamed(context, '/login');
          },
        ),
      ],
    );
  }

  Future<void> _bindiToggle(Map<String, dynamic> ogr, bool deger) async {
    try {
      await FirebaseFirestore.instance
          .collection('students').doc(ogr['id'] as String).update({
        'bindi': deger,
        'bindiZaman': FieldValue.serverTimestamp(),
      });
      final idx = _ogrenciler.indexWhere((o) => o['id'] == ogr['id']);
      if (idx != -1) setState(() => _ogrenciler[idx]['bindi'] = deger);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
    }
  }

  void _veliAra() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _VeliAraSheet(ogrenciler: _ogrenciler),
    );
  }
}

// ── Kucuk Widgetlar ───────────────────────────────────────────────────────────
class _Buton extends StatelessWidget {
  final IconData ikon;
  final String etiket;
  final Color renk;
  final VoidCallback onTap;
  const _Buton({required this.ikon, required this.etiket,
    required this.renk, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.07), blurRadius: 8)],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(ikon, color: renk, size: 26),
        const SizedBox(height: 6),
        Text(etiket, style: TextStyle(color: renk,
            fontWeight: FontWeight.bold, fontSize: 12)),
      ]),
    ),
  );
}

class _Mini extends StatelessWidget {
  final String deger, etiket;
  final IconData ikon;
  final Color renk;
  const _Mini(this.deger, this.etiket, this.ikon, this.renk);

  @override
  Widget build(BuildContext context) => Column(children: [
    Icon(ikon, color: renk, size: 16),
    Text(deger, style: TextStyle(fontSize: 18,
        fontWeight: FontWeight.bold, color: renk)),
    Text(etiket, style: const TextStyle(fontSize: 10, color: Colors.grey)),
  ]);
}

class _BilgiKarti extends StatelessWidget {
  final String etiket, deger;
  final IconData ikon;
  static const _navy = Color(0xFF1a3a6b);
  const _BilgiKarti(this.etiket, this.deger, this.ikon);

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
    ),
    child: Row(children: [
      Icon(ikon, color: _navy, size: 20),
      const SizedBox(width: 12),
      Text(etiket, style: const TextStyle(color: Colors.grey, fontSize: 13)),
      const Spacer(),
      Text(deger, style: const TextStyle(
          fontWeight: FontWeight.bold, color: _navy)),
    ]),
  );
}

class _VeliAraSheet extends StatelessWidget {
  final List<Map<String, dynamic>> ogrenciler;
  static const _navy = Color(0xFF1a3a6b);
  const _VeliAraSheet({required this.ogrenciler});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        const Text('Veli Ara', style: TextStyle(fontSize: 18,
            fontWeight: FontWeight.bold, color: _navy)),
        const SizedBox(height: 16),
        if (ogrenciler.isEmpty)
          const Text('Ogrenci yok', style: TextStyle(color: Colors.grey))
        else
          ...ogrenciler.map((ogr) {
            final tel = ogr['veliTel'] ?? ogr['veliTelefon'] ?? '';
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: _navy.withValues(alpha: 0.1),
                child: Text((ogr['ad'] ?? '?')[0].toUpperCase(),
                    style: const TextStyle(
                        color: _navy, fontWeight: FontWeight.bold)),
              ),
              title: Text(ogr['ad'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(tel.isNotEmpty ? tel : 'Telefon yok'),
              trailing: tel.isNotEmpty
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  icon: const Icon(Icons.phone_outlined,
                      color: Colors.green),
                  onPressed: () async {
                    final url = Uri.parse('tel:$tel');
                    if (await canLaunchUrl(url)) await launchUrl(url);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.message_outlined,
                      color: Color(0xFF25D366)),
                  onPressed: () async {
                    final n = tel.replaceAll(RegExp(r'[^\d]'), '');
                    final url = Uri.parse('https://wa.me/90$n');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ])
                  : null,
            );
          }),
        const SizedBox(height: 20),
      ]),
    );
  }
}
