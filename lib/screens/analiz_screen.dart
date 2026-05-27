import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/session_service.dart';

class AnalizScreen extends StatefulWidget {
  const AnalizScreen({super.key});
  @override
  State<AnalizScreen> createState() => _AnalizScreenState();
}

class _AnalizScreenState extends State<AnalizScreen>
    with SingleTickerProviderStateMixin {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  late final TabController _tabCtrl;
  String? _firmaId;
  bool _yukleniyor = true;

  int _toplamOgrenci   = 0;
  int _toplamSofor     = 0;
  int _toplamRota      = 0;
  int _aktifServis     = 0;
  int _bugunDevamsiz   = 0;
  int _bugunPresent    = 0;

  List<_GunlukVeri>   _yoklamaVerisi      = [];
  List<_RotaVeri>     _rotaDolulukVerisi  = [];
  List<_SaatVeri>     _servisSaatiVerisi  = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _yukle();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    _firmaId = await SessionService.instance.firmaldAl();
    if (_firmaId == null) {
      setState(() => _yukleniyor = false);
      return;
    }

    final db    = FirebaseFirestore.instance;
    final bugun = DateTime.now();

    try {
      final results = await Future.wait([
        db.collection('students').where('firmaId', isEqualTo: _firmaId).count().get(),
        db.collection('drivers').where('firmaId', isEqualTo: _firmaId).count().get(),
        db.collection('routes').where('firmaId', isEqualTo: _firmaId).count().get(),
        db.collection('drivers')
            .where('firmaId', isEqualTo: _firmaId)
            .where('servisAktif', isEqualTo: true)
            .count().get(),
      ]);

      _toplamOgrenci = results[0].count ?? 0;
      _toplamSofor   = results[1].count ?? 0;
      _toplamRota    = results[2].count ?? 0;
      _aktifServis   = results[3].count ?? 0;

      final devamsizSnap = await db
          .collection('absence_requests')
          .where('firmaId', isEqualTo: _firmaId)
          .where('tarih', isGreaterThanOrEqualTo:
      Timestamp.fromDate(DateTime(bugun.year, bugun.month, bugun.day)))
          .get();
      _bugunDevamsiz = devamsizSnap.docs.length;
      _bugunPresent  = (_toplamOgrenci - _bugunDevamsiz).clamp(0, _toplamOgrenci);

      _yoklamaVerisi     = _ornekYoklamaVerisi();
      _rotaDolulukVerisi = await _rotaDolulukCek(db);
      _servisSaatiVerisi = _ornekSaatVerisi();
    } catch (e) {
      debugPrint('Analiz yukle hata: $e');
    }

    if (mounted) setState(() => _yukleniyor = false);
  }

  List<_GunlukVeri> _ornekYoklamaVerisi() {
    final gunler = ['Pzt', 'Sal', 'Car', 'Per', 'Cum', 'Cmt', 'Paz'];
    final baz = _toplamOgrenci > 0 ? _toplamOgrenci : 20;
    return List.generate(7, (i) {
      final katsayi = i == 6 ? 0.0 : (0.82 + (i % 3) * 0.06);
      return _GunlukVeri(
        gun: gunler[i],
        gelen: (baz * katsayi).round(),
        devamsiz: (baz * (1 - katsayi)).round(),
      );
    });
  }

  List<_SaatVeri> _ornekSaatVerisi() => [
    _SaatVeri('06:00', 2), _SaatVeri('06:30', 5),
    _SaatVeri('07:00', 12), _SaatVeri('07:30', 18),
    _SaatVeri('08:00', 8), _SaatVeri('08:30', 3),
  ];

  Future<List<_RotaVeri>> _rotaDolulukCek(FirebaseFirestore db) async {
    try {
      // Önce routes koleksiyonunu dene
      final routesSnap = await db.collection('routes')
          .where('firmaId', isEqualTo: _firmaId).limit(8).get();
      if (routesSnap.docs.isNotEmpty) {
        return routesSnap.docs.map((d) {
          final data     = d.data();
          final kapasite = (data['kapasite']     as num?)?.toDouble() ?? 20;
          final mevcut   = (data['ogrenciSayisi'] as num?)?.toDouble() ?? 0;
          return _RotaVeri(
            ad: data['ad'] as String? ?? 'Rota',
            dolulukYuzdesi: kapasite > 0 ? (mevcut / kapasite * 100).clamp(0, 100) : 0,
            kapasite: kapasite.round(),
            mevcut: mevcut.round(),
          );
        }).toList();
      }

      // Routes boşsa drivers + students bazlı hesapla
      final driverSnap = await db.collection('drivers')
          .where('firmaId', isEqualTo: _firmaId).get();
      final projeId = SessionService.instance.aktifProjeld ?? '';

      final liste = <_RotaVeri>[];
      for (final dDoc in driverSnap.docs) {
        final dData = dDoc.data();
        final ad    = '${dData['ad'] ?? 'Sofor'} — ${dData['aracPlaka'] ?? ''}';
        final kapasite = (dData['kapasite'] as num?)?.toInt() ?? 16;

        // Bu şoföre atanmış öğrenci sayısı
        var q = db.collection('students')
            .where('firmaId', isEqualTo: _firmaId)
            .where('surucuId', isEqualTo: dDoc.id);
        if (projeId.isNotEmpty) q = q.where('projeId', isEqualTo: projeId);
        final ogrSnap = await q.get();
        final mevcut  = ogrSnap.docs.length;

        liste.add(_RotaVeri(
          ad: ad,
          dolulukYuzdesi: kapasite > 0 ? (mevcut / kapasite * 100).clamp(0, 100) : 0,
          kapasite: kapasite,
          mevcut: mevcut,
        ));
      }
      return liste;
    } catch (_) { return []; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: const Text('Analiz & Raporlar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined, color: Colors.white70),
            onPressed: () { setState(() => _yukleniyor = true); _yukle(); },
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: _turuncu,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Genel'),
            Tab(text: 'Yoklama'),
            Tab(text: 'Rotalar'),
          ],
        ),
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator(color: _navy))
          : TabBarView(
        controller: _tabCtrl,
        children: [
          _genelTab(),
          _yoklamaTab(),
          _rotalarTab(),
        ],
      ),
    );
  }

  // ── GENEL TAB ─────────────────────────────────────────────────────────────
  Widget _genelTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Ozet kartlar
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12, mainAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _OzetKart('Ogrenci', '$_toplamOgrenci', Icons.people_outline, Colors.blue),
            _OzetKart('Sofor', '$_toplamSofor', Icons.drive_eta_outlined, _navy),
            _OzetKart('Rota', '$_toplamRota', Icons.route_outlined, Colors.teal),
            _OzetKart('Aktif Servis', '$_aktifServis',
                Icons.directions_bus_outlined, Colors.green),
          ],
        ),
        const SizedBox(height: 16),

        // Bugun ozeti
        _baslik('Bugun Ozeti'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _kart(),
          child: Column(children: [
            // Halka grafik — CustomPaint ile
            if (_toplamOgrenci > 0)
              SizedBox(
                height: 160,
                child: CustomPaint(
                  painter: _HalkaGrafik(
                    gelen: _bugunPresent,
                    devamsiz: _bugunDevamsiz,
                    toplam: _toplamOgrenci,
                  ),
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('${_toplamOgrenci > 0
                          ? ((_bugunPresent / _toplamOgrenci) * 100).round()
                          : 0}%',
                          style: const TextStyle(fontSize: 22,
                              fontWeight: FontWeight.bold, color: _navy)),
                      const Text('Katilim', style: TextStyle(
                          fontSize: 11, color: Colors.grey)),
                    ]),
                  ),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Veri yok', style: TextStyle(color: Colors.grey)),
              ),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _renkliBadge(Colors.green, 'Gelen', '$_bugunPresent'),
              _renkliBadge(Colors.red.shade300, 'Devamsiz', '$_bugunDevamsiz'),
              _renkliBadge(_navy, 'Toplam', '$_toplamOgrenci'),
            ]),
          ]),
        ),
        const SizedBox(height: 16),

        // Servis saati dagilimu
        _baslik('Servis Saati Dagilimi'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _kart(),
          child: Column(
            children: _servisSaatiVerisi.map((s) {
              final maxSayi = _servisSaatiVerisi
                  .map((x) => x.servisSayisi)
                  .reduce((a, b) => a > b ? a : b);
              final oran = maxSayi > 0 ? s.servisSayisi / maxSayi : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  SizedBox(width: 44,
                      child: Text(s.saat,
                          style: const TextStyle(fontSize: 11, color: Colors.grey))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: oran.toDouble(),
                        backgroundColor: Colors.grey.withValues(alpha: 0.12),
                        valueColor: const AlwaysStoppedAnimation(_navy),
                        minHeight: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${s.servisSayisi}',
                      style: const TextStyle(fontSize: 12,
                          fontWeight: FontWeight.bold, color: _navy)),
                ]),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }

  // ── YOKLAMA TAB ───────────────────────────────────────────────────────────
  Widget _yoklamaTab() {
    final maxGelen = _yoklamaVerisi.isEmpty ? 1
        : _yoklamaVerisi.map((v) => v.gelen).reduce((a, b) => a > b ? a : b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _baslik('Son 7 Gun Yoklama'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _kart(),
          child: Column(children: [
            // Bar grafik
            SizedBox(
              height: 200,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _yoklamaVerisi.map((v) {
                  final gelenOran  = maxGelen > 0 ? v.gelen  / maxGelen : 0.0;
                  final devOran    = maxGelen > 0 ? v.devamsiz / maxGelen : 0.0;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('${v.gelen}',
                          style: const TextStyle(fontSize: 9, color: Colors.grey)),
                      const SizedBox(height: 2),
                      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        // Gelen bar
                        Container(
                          width: 14,
                          height: (gelenOran * 140).clamp(2, 140).toDouble(),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(3)),
                          ),
                        ),
                        const SizedBox(width: 2),
                        // Devamsiz bar
                        Container(
                          width: 14,
                          height: (devOran * 140).clamp(2, 140).toDouble(),
                          decoration: BoxDecoration(
                            color: Colors.red.shade200,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(3)),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Text(v.gun,
                          style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _lejant(Colors.green, 'Gelen'),
              const SizedBox(width: 20),
              _lejant(Colors.red.shade200, 'Devamsiz'),
            ]),
          ]),
        ),
        const SizedBox(height: 16),

        _baslik("Bugunun Devamsizliklari"),
        const SizedBox(height: 8),
        Container(
          decoration: _kart(),
          child: _firmaId == null || _bugunDevamsiz == 0
              ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Bugun devamsiz ogrenci yok!',
                  style: TextStyle(color: Colors.green,
                      fontWeight: FontWeight.bold))))
              : _DevamsizListesi(firmaId: _firmaId!),
        ),
      ]),
    );
  }

  // ── ROTALAR TAB ───────────────────────────────────────────────────────────
  Widget _rotalarTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _baslik('Rota Doluluk Oranlari'),
        const SizedBox(height: 8),
        if (_rotaDolulukVerisi.isEmpty)
          Container(
            padding: const EdgeInsets.all(32), decoration: _kart(),
            child: const Center(child: Text('Rota verisi bulunamadi',
                style: TextStyle(color: Colors.grey))),
          )
        else
          ..._rotaDolulukVerisi.map((r) => _RotaKarti(rota: r)),
        const SizedBox(height: 16),

        if (_rotaDolulukVerisi.isNotEmpty) ...[
          _baslik('Doluluk Karsilastirmasi'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16), decoration: _kart(),
            child: Column(
              children: _rotaDolulukVerisi.map((r) {
                final renk = r.dolulukYuzdesi > 85
                    ? Colors.red
                    : r.dolulukYuzdesi > 65 ? _turuncu : Colors.green;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    SizedBox(
                      width: 70,
                      child: Text(
                        r.ad.length > 8 ? '${r.ad.substring(0, 8)}..' : r.ad,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: r.dolulukYuzdesi / 100,
                          backgroundColor: Colors.grey.withValues(alpha: 0.12),
                          valueColor: AlwaysStoppedAnimation(renk),
                          minHeight: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('%${r.dolulukYuzdesi.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 12,
                            fontWeight: FontWeight.bold, color: renk)),
                  ]),
                );
              }).toList(),
            ),
          ),
        ],
      ]),
    );
  }

  // ── Yardimcilar ─────────────────────────────────────────────────────────────
  Widget _baslik(String t) => Align(
    alignment: Alignment.centerLeft,
    child: Text(t, style: const TextStyle(fontSize: 15,
        fontWeight: FontWeight.bold, color: _navy)),
  );

  Widget _lejant(Color renk, String etiket) => Row(children: [
    Container(width: 12, height: 12,
        decoration: BoxDecoration(color: renk,
            borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 6),
    Text(etiket, style: const TextStyle(fontSize: 12, color: Colors.grey)),
  ]);

  Widget _renkliBadge(Color renk, String etiket, String deger) => Column(children: [
    Text(deger, style: TextStyle(fontSize: 20,
        fontWeight: FontWeight.bold, color: renk)),
    Text(etiket, style: const TextStyle(fontSize: 11, color: Colors.grey)),
  ]);

  BoxDecoration _kart() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06),
        blurRadius: 8, offset: const Offset(0, 2))],
  );
}

// ── Halka Grafik (CustomPainter) ──────────────────────────────────────────────
class _HalkaGrafik extends CustomPainter {
  final int gelen, devamsiz, toplam;
  const _HalkaGrafik(
      {required this.gelen, required this.devamsiz, required this.toplam});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = (size.shortestSide / 2) - 10;

    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..color = Colors.grey.withValues(alpha: 0.1);

    final gelenPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round
      ..color = Colors.green;

    final devPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round
      ..color = Colors.red.shade200;

    const startAngle = -1.5708; // -pi/2
    final gelenSweep = toplam > 0 ? (gelen / toplam) * 6.2832 : 0.0;
    final devSweep   = toplam > 0 ? (devamsiz / toplam) * 6.2832 : 0.0;

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    canvas.drawArc(rect, 0, 6.2832, false, bgPaint);
    if (gelenSweep > 0) {
      canvas.drawArc(rect, startAngle, gelenSweep, false, gelenPaint);
    }
    if (devSweep > 0) {
      canvas.drawArc(
          rect, startAngle + gelenSweep, devSweep, false, devPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ── Alt Widget'lar ─────────────────────────────────────────────────────────────
class _OzetKart extends StatelessWidget {
  final String baslik, deger;
  final IconData ikon;
  final Color renk;
  static const _navy = Color(0xFF1a3a6b);
  const _OzetKart(this.baslik, this.deger, this.ikon, this.renk);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 6)],
    ),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: renk.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(ikon, color: renk, size: 22),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(deger, style: TextStyle(fontSize: 22,
            fontWeight: FontWeight.bold, color: renk)),
        Text(baslik, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ]),
    ]),
  );
}

class _RotaKarti extends StatelessWidget {
  final _RotaVeri rota;
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  const _RotaKarti({required this.rota});

  @override
  Widget build(BuildContext context) {
    final renk = rota.dolulukYuzdesi > 85
        ? Colors.red
        : rota.dolulukYuzdesi > 65 ? _turuncu : Colors.green;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6)],
      ),
      child: Column(children: [
        Row(children: [
          Expanded(child: Text(rota.ad,
              style: const TextStyle(fontWeight: FontWeight.bold, color: _navy))),
          Text('${rota.mevcut}/${rota.kapasite} kisi',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: renk.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('%${rota.dolulukYuzdesi.toStringAsFixed(0)}',
                style: TextStyle(color: renk, fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: rota.dolulukYuzdesi / 100,
            backgroundColor: Colors.grey.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(renk),
            minHeight: 8,
          ),
        ),
      ]),
    );
  }
}

class _DevamsizListesi extends StatelessWidget {
  final String firmaId;
  const _DevamsizListesi({required this.firmaId});

  @override
  Widget build(BuildContext context) {
    final bugun = DateTime.now();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('absence_requests')
          .where('firmaId', isEqualTo: firmaId)
          .where('tarih', isGreaterThanOrEqualTo: Timestamp.fromDate(
          DateTime(bugun.year, bugun.month, bugun.day)))
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Padding(padding: EdgeInsets.all(20),
              child: Center(child: Text('Devamsiz ogrenci yok',
                  style: TextStyle(color: Colors.grey))));
        }
        return Column(
          children: docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.red.withValues(alpha: 0.1),
                child: const Icon(Icons.person_off_outlined,
                    color: Colors.red, size: 18),
              ),
              title: Text(data['ogrenciAd'] as String? ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(data['sebep'] as String? ?? 'Sebep belirtilmedi',
                  style: const TextStyle(fontSize: 12)),
              trailing: Text(data['rotaAdi'] as String? ?? '',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            );
          }).toList(),
        );
      },
    );
  }
}

// ── Veri Modelleri ─────────────────────────────────────────────────────────────
class _GunlukVeri {
  final String gun;
  final int gelen, devamsiz;
  const _GunlukVeri(
      {required this.gun, required this.gelen, required this.devamsiz});
}

class _RotaVeri {
  final String ad;
  final double dolulukYuzdesi;
  final int kapasite, mevcut;
  const _RotaVeri({required this.ad, required this.dolulukYuzdesi,
    required this.kapasite, required this.mevcut});
}

class _SaatVeri {
  final String saat;
  final int servisSayisi;
  const _SaatVeri(this.saat, this.servisSayisi);
}
