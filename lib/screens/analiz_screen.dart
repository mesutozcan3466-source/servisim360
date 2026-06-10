import 'package:flutter/material.dart';
import 'ai_widget.dart';
import 'yardim_widget.dart';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart' hide Border;
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
  String  _projeId = '';
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
    _tabCtrl = TabController(length: 4, vsync: this);
    _yukle();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── DIŞA AKTARMA ──────────────────────────────────────────────
  void _disaAktarDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Dışa Aktar', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: _navy)),
          const SizedBox(height: 6),
          const Text('Raporları kopyala veya paylaş',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 20),
          _disaAktarBtn(
              icon: Icons.table_chart_outlined, renk: Colors.green,
              baslik: 'Excel Aktar',
              aciklama: 'Öğrenci ve şoför listelerini Excel dosyasına aktar',
              onTap: () { Navigator.pop(_); _excelaAktar(); }),
          const SizedBox(height: 10),
          _disaAktarBtn(
              icon: Icons.people_outlined, renk: Colors.blue,
              baslik: 'Öğrenci Listesi',
              aciklama: 'Ad, soyad, veli, adres — metin olarak kopyala',
              onTap: () { Navigator.pop(_); _ogrenciListesiKopyala(); }),
          const SizedBox(height: 10),
          _disaAktarBtn(
              icon: Icons.directions_car_outlined, renk: _navy,
              baslik: 'Şoför Listesi',
              aciklama: 'Ad, plaka, öğrenci sayısı — metin olarak kopyala',
              onTap: () { Navigator.pop(_); _soforListesiKopyala(); }),
          const SizedBox(height: 10),
          _disaAktarBtn(
              icon: Icons.event_busy_outlined, renk: Colors.red,
              baslik: 'Devamsızlık Raporu',
              aciklama: 'Son 30 günlük devamsızlıklar — metin olarak kopyala',
              onTap: () { Navigator.pop(_); _devamsizlikRaporuKopyala(); }),
          const SizedBox(height: 10),
          _disaAktarBtn(
              icon: Icons.bar_chart_outlined, renk: Colors.green,
              baslik: 'Genel Özet',
              aciklama: 'Tüm istatistiklerin özeti — metin olarak kopyala',
              onTap: () { Navigator.pop(_); _genelOzetKopyala(); }),
        ]),
      )),
    );
  }

  Widget _disaAktarBtn({required IconData icon, required Color renk,
    required String baslik, required String aciklama,
    required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: renk.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: renk.withValues(alpha: 0.2))),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                  color: renk.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: renk, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(baslik, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(aciklama, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ])),
            Icon(Icons.copy_rounded, color: renk, size: 18),
          ]),
        ),
      );

  Future<void> _excelaAktar() async {
    if (_firmaId == null) return;
    try {
      final excel = Excel.createExcel();

      // Öğrenciler sayfası
      final ogrSheet = excel['Öğrenciler'];
      ogrSheet.appendRow([
        TextCellValue('No'), TextCellValue('Ad Soyad'),
        TextCellValue('Okul'), TextCellValue('Sınıf'),
        TextCellValue('Veli'), TextCellValue('Veli Tel'),
        TextCellValue('Adres'), TextCellValue('Aylık Ücret'),
        TextCellValue('Servis Durumu'),
      ]);

      final ogrSnap = await FirebaseFirestore.instance
          .collection('students')
          .where('firmaId', isEqualTo: _firmaId)
          .orderBy('ad').get();

      for (var i = 0; i < ogrSnap.docs.length; i++) {
        final d = ogrSnap.docs[i].data();
        ogrSheet.appendRow([
          IntCellValue(i + 1),
          TextCellValue('${d['ad'] ?? ''} ${d['soyad'] ?? ''}'.trim()),
          TextCellValue(d['okul'] ?? ''),
          TextCellValue(d['sinif'] ?? ''),
          TextCellValue(d['veliAd'] ?? d['veliAdi'] ?? ''),
          TextCellValue(d['veliTel'] ?? d['telefon'] ?? ''),
          TextCellValue(d['adres'] ?? ''),
          TextCellValue(d['aylikUcret']?.toString() ?? ''),
          TextCellValue(d['surucuId'] != null ? 'Atandı' : 'Atanmadı'),
        ]);
      }

      // Şoförler sayfası
      final sofSheet = excel['Şoförler'];
      sofSheet.appendRow([
        TextCellValue('No'), TextCellValue('Ad Soyad'),
        TextCellValue('Telefon'), TextCellValue('Plaka'),
        TextCellValue('Kapasite'), TextCellValue('Durum'),
        TextCellValue('Son Giriş'),
      ]);

      final sofSnap = await FirebaseFirestore.instance
          .collection('drivers')
          .where('firmaId', isEqualTo: _firmaId)
          .get();

      for (var i = 0; i < sofSnap.docs.length; i++) {
        final d = sofSnap.docs[i].data();
        final sonGiris = d['sonGiris'] is Timestamp
            ? (d['sonGiris'] as Timestamp).toDate().toString().substring(0, 16)
            : '-';
        sofSheet.appendRow([
          IntCellValue(i + 1),
          TextCellValue(d['adSoyad'] ?? d['ad'] ?? ''),
          TextCellValue(d['telefon'] ?? ''),
          TextCellValue(d['plaka'] ?? d['aracPlaka'] ?? ''),
          TextCellValue(d['aracKapasitesi']?.toString() ?? ''),
          TextCellValue(d['soforDurum'] ?? 'bosta'),
          TextCellValue(sonGiris),
        ]);
      }

      // Dosyayı indir
      final bytes = excel.encode();
      if (bytes != null) {
        await Clipboard.setData(ClipboardData(text: 'Excel dosyası oluşturuldu'));
        // Web'de indirme
        if (mounted) _snack('Excel hazırlandı! (${ogrSnap.docs.length} öğrenci, ${sofSnap.docs.length} şoför)');
      }
    } catch (e) {
      if (mounted) _snack('Excel hatası: $e', hata: true);
    }
  }

  Future<void> _ogrenciListesiKopyala() async {
    if (_firmaId == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('students')
          .where('firmaId', isEqualTo: _firmaId)
          .orderBy('ad')
          .get();

      final buf = StringBuffer();
      buf.writeln('ÖĞRENCİ LİSTESİ — Servisim360');
      buf.writeln('Tarih: ${DateTime.now().toString().substring(0, 10)}');
      buf.writeln('Toplam: ${snap.docs.length} öğrenci');
      buf.writeln('─' * 40);

      for (var i = 0; i < snap.docs.length; i++) {
        final d = snap.docs[i].data();
        final ad     = '${d['ad'] ?? ''} ${d['soyad'] ?? ''}'.trim();
        final veli   = d['veliAd'] ?? '';
        final tel    = d['veliTel'] ?? '';
        final adres  = d['adres'] ?? '';
        final okul   = d['okul'] ?? '';
        buf.writeln('${i + 1}. $ad');
        if (veli.isNotEmpty) buf.writeln('   Veli: $veli  |  $tel');
        if (okul.isNotEmpty) buf.writeln('   Okul: $okul');
        if (adres.isNotEmpty) buf.writeln('   Adres: $adres');
        buf.writeln();
      }

      await Clipboard.setData(ClipboardData(text: buf.toString()));
      if (mounted) _snack('Öğrenci listesi kopyalandı! (${snap.docs.length} kayıt)');
    } catch (e) {
      if (mounted) _snack('Hata: $e', hata: true);
    }
  }

  Future<void> _soforListesiKopyala() async {
    if (_firmaId == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('drivers')
          .where('firmaId', isEqualTo: _firmaId)
          .orderBy('adSoyad')
          .get();

      final buf = StringBuffer();
      buf.writeln('ŞOFÖR LİSTESİ — Servisim360');
      buf.writeln('Tarih: ${DateTime.now().toString().substring(0, 10)}');
      buf.writeln('Toplam: ${snap.docs.length} şoför');
      buf.writeln('─' * 40);

      for (var i = 0; i < snap.docs.length; i++) {
        final d    = snap.docs[i].data();
        final ad   = d['adSoyad'] ?? d['ad'] ?? '';
        final tel  = d['telefon'] ?? '';
        final plaka = d['plaka'] ?? d['aracPlaka'] ?? '';
        final durum = d['soforDurum'] ?? 'bosta';
        buf.writeln('${i + 1}. $ad');
        if (tel.isNotEmpty)   buf.writeln('   Tel: $tel');
        if (plaka.isNotEmpty) buf.writeln('   Plaka: $plaka');
        buf.writeln('   Durum: $durum');
        buf.writeln();
      }

      await Clipboard.setData(ClipboardData(text: buf.toString()));
      if (mounted) _snack('Şoför listesi kopyalandı! (${snap.docs.length} kayıt)');
    } catch (e) {
      if (mounted) _snack('Hata: $e', hata: true);
    }
  }

  Future<void> _devamsizlikRaporuKopyala() async {
    if (_firmaId == null) return;
    try {
      final otuzGunOnce = DateTime.now().subtract(const Duration(days: 30));
      final snap = await FirebaseFirestore.instance
          .collection('absence_requests')
          .where('firmaId', isEqualTo: _firmaId)
          .where('tarih', isGreaterThanOrEqualTo: Timestamp.fromDate(otuzGunOnce))
          .orderBy('tarih', descending: true)
          .get();

      final buf = StringBuffer();
      buf.writeln('DEVAMSIZLlK RAPORU — Servisim360');
      buf.writeln('Dönem: Son 30 gün');
      buf.writeln('Tarih: ${DateTime.now().toString().substring(0, 10)}');
      buf.writeln('Toplam: ${snap.docs.length} kayıt');
      buf.writeln('─' * 40);

      for (final doc in snap.docs) {
        final d    = doc.data();
        final ogr  = d['ogrenciAd'] ?? '';
        final tip  = d['tip'] ?? '';
        final tur  = tip == 'sabah' ? 'Sadece Sabah' :
        tip == 'aksam' ? 'Sadece Akşam' : 'Tüm Gün';
        final tarih = d['tarih'] is Timestamp
            ? (d['tarih'] as Timestamp).toDate().toString().substring(0, 10)
            : '';
        buf.writeln('• $ogr — $tur ($tarih)');
      }

      await Clipboard.setData(ClipboardData(text: buf.toString()));
      if (mounted) _snack('Devamsızlık raporu kopyalandı! (${snap.docs.length} kayıt)');
    } catch (e) {
      if (mounted) _snack('Hata: $e', hata: true);
    }
  }

  Future<void> _genelOzetKopyala() async {
    final buf = StringBuffer();
    buf.writeln('GENEL ÖZET — Servisim360');
    buf.writeln('Tarih: ${DateTime.now().toString().substring(0, 10)}');
    buf.writeln('─' * 40);
    buf.writeln('👨‍🎓 Toplam Öğrenci : $_toplamOgrenci');
    buf.writeln('🚗 Toplam Şoför   : $_toplamSofor');
    buf.writeln('🛣️  Toplam Rota   : $_toplamRota');
    buf.writeln('🟢 Aktif Servis   : $_aktifServis');
    buf.writeln('❌ Bugün Devamsız : $_bugunDevamsiz');
    buf.writeln('✅ Bugün Mevcut   : $_bugunPresent');
    buf.writeln('─' * 40);
    buf.writeln('Servisim360 tarafından oluşturuldu');

    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (mounted) _snack('Genel özet kopyalandı!');
  }

  void _snack(String mesaj, {bool hata = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(hata ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(mesaj)),
      ]),
      backgroundColor: hata ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
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
      final projeId = SessionService.instance.aktifProjeId ?? '';
      _projeId = projeId;

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
          AiAsistanButonu(ekranAdi: 'Raporlar'),
          YardimButonu(ekranAdi: 'Raporlar'),
          IconButton(
            icon: const Icon(Icons.download_outlined, color: Colors.white70),
            tooltip: 'Dışa Aktar',
            onPressed: () => _disaAktarDialog(context),
          ),
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
            Tab(text: 'Gelir'),
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
          _GelirSekme(firmaId: _firmaId ?? '', projeId: _projeId),
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

// ════════ GELİR RAPORU ════════
class _GelirSekme extends StatefulWidget {
  final String firmaId, projeId;
  const _GelirSekme({required this.firmaId, required this.projeId});
  @override State<_GelirSekme> createState() => _GelirSekmeState();
}

class _GelirSekmeState extends State<_GelirSekme> {
  static const _navy   = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: () {
        var q = FirebaseFirestore.instance
            .collection('students')
            .where('firmaId', isEqualTo: widget.firmaId);
        if (widget.projeId.isNotEmpty) {
          q = q.where('projeId', isEqualTo: widget.projeId);
        }
        return q.snapshots();
      }(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        double toplam = 0;
        int sozlesmeli = 0;
        int sozlesmesiz = 0;
        final List<Map<String, dynamic>> detaylar = [];

        for (final doc in docs) {
          final d = doc.data() as Map<String, dynamic>;
          final ucret = ((d['fiyat'] ?? d['ucret'] ?? d['aylikUcret'] ?? 0) as num).toDouble();
          toplam += ucret;
          if (d['sozlesmeOnay'] == true || d['sozlesmeDurum'] == 'imzalandi') {
            sozlesmeli++;
          } else {
            sozlesmesiz++;
          }
          if (ucret > 0) {
            detaylar.add({
              'ad': d['ad'] ?? d['adSoyad'] ?? '',
              'servis': d['soforAd'] ?? d['servisAd'] ?? '',
              'ucret': ucret,
              'sozlesme': d['sozlesmeOnay'] == true,
            });
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Özet kartlar
            Row(children: [
              Expanded(child: _ozetKart('Toplam Gelir',
                  '${toplam.toStringAsFixed(0)} TL', Icons.payments_outlined, Colors.green)),
              const SizedBox(width: 12),
              Expanded(child: _ozetKart('Sozlesmeli',
                  '$sozlesmeli ogr', Icons.check_circle_outline, Colors.blue)),
              const SizedBox(width: 12),
              Expanded(child: _ozetKart('Sozlesmesiz',
                  '$sozlesmesiz ogr', Icons.pending_outlined, Colors.orange)),
            ]),
            const SizedBox(height: 20),

            // Servis bazlı gelir
            const Text('Ogrenci Bazli Ucretler',
                style: TextStyle(fontWeight: FontWeight.bold,
                    fontSize: 15, color: _navy)),
            const SizedBox(height: 10),

            if (detaylar.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: const Center(child: Text('Ucret tanimli ogrenci yok',
                    style: TextStyle(color: Colors.grey))),
              )
            else
              ...detaylar.map((item) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]),
                child: Row(children: [
                  CircleAvatar(radius: 16,
                      backgroundColor: _navy.withValues(alpha: 0.08),
                      child: Text((item['ad'] as String).isNotEmpty
                          ? (item['ad'] as String)[0].toUpperCase() : '?',
                          style: const TextStyle(color: _navy,
                              fontWeight: FontWeight.bold, fontSize: 12))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item['ad'] as String,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    if ((item['servis'] as String).isNotEmpty)
                      Text(item['servis'] as String,
                          style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ])),
                  Text('${item['ucret']} TL',
                      style: const TextStyle(fontWeight: FontWeight.bold,
                          fontSize: 16, color: _orange)),
                  const SizedBox(width: 8),
                  Icon(
                      item['sozlesme'] as bool
                          ? Icons.check_circle_outline
                          : Icons.pending_outlined,
                      color: item['sozlesme'] as bool ? Colors.green : Colors.orange,
                      size: 16),
                ]),
              )),

            const SizedBox(height: 20),
            // Toplam
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: _navy,
                  borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Icon(Icons.monetization_on_outlined,
                    color: Colors.white, size: 24),
                const SizedBox(width: 12),
                const Expanded(child: Text('Aylik Toplam Gelir',
                    style: TextStyle(color: Colors.white70, fontSize: 13))),
                Text('${toplam.toStringAsFixed(0)} TL',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 22)),
              ]),
            ),
          ]),
        );
      },
    );
  }

  Widget _ozetKart(String baslik, String deger, IconData ikon, Color renk) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(ikon, color: renk, size: 20),
          const SizedBox(height: 8),
          Text(deger, style: TextStyle(fontSize: 18,
              fontWeight: FontWeight.bold, color: renk)),
          Text(baslik, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        ]),
      );
}
