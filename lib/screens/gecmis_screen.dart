import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'yardim_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class GecmisScreen extends StatefulWidget {
  const GecmisScreen({super.key});

  @override
  State<GecmisScreen> createState() => _GecmisScreenState();
}

class _GecmisScreenState extends State<GecmisScreen>
    with SingleTickerProviderStateMixin {
  static const navyBlue = Color(0xFF1a3a6b);
  static const turuncu = Color(0xFFFF8C00);

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late TabController _tabController;

  String? _firmaId;
  String  _projeId  = '';
  String  _projeAdi = '';
  bool _yukleniyor = true;

  // Filtre
  String _gecmisFiltre = 'hepsi';

  // Özet verileri
  int _bugunkuBinenler = 0;
  int _bugunkuGelmeyenler = 0;
  int _toplamOgrenci = 0;
  int _aktifSofor = 0;
  int _bugunYapilanSefer = 0;

  // Haftalık yokluk
  List<Map<String, dynamic>> _yokluklar = [];
  bool _yoklukYukleniyor = false;
  DateTime _seciliHafta = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await _db.collection('kullanicilar').doc(uid).get();
    if (!doc.exists) return;
    _firmaId = doc.data()?['firmaId'] ?? '';
    if (_firmaId != null && _firmaId!.isNotEmpty) {
      await Future.wait([
        _ozetVerileriniYukle(),
        _yokluklariYukle(),
      ]);
    }
    setState(() => _yukleniyor = false);
  }

  // ─── ÖZET VERİLER ─────────────────────────────────────────────────
  Future<void> _ozetVerileriniYukle() async {
    if (_firmaId == null) return;
    try {
      // Toplam öğrenci
      final ogrSnap = await _db
          .collection('firms')
          .doc(_firmaId)
          .collection('students')
          .get();
      _toplamOgrenci = ogrSnap.docs.length;

      // Bugün binen öğrenciler
      _bugunkuBinenler = ogrSnap.docs
          .where((d) => d.data()['bindiMi'] == true)
          .length;

      // Bugün gelmeyenler
      final bugun = _bugunKey();
      final yokSnap = await _db
          .collection('firms')
          .doc(_firmaId)
          .collection('yokluklar')
          .where('tarih', isEqualTo: bugun)
          .where('geliyor', isEqualTo: false)
          .get();
      _bugunkuGelmeyenler = yokSnap.docs.length;

      // Aktif şoförler
      final surucuSnap = await _db
          .collection('firms')
          .doc(_firmaId)
          .collection('drivers')
          .get();
      _aktifSofor = surucuSnap.docs
          .where((d) => d.data()['servisDurumu'] == 'basladi')
          .length;

      // Bugün yapılan sefer sayısı (gecmis koleksiyonundan)
      final seferSnap = await _db
          .collection('firms')
          .doc(_firmaId)
          .collection('gecmis')
          .where('tip', isEqualTo: 'sefer')
          .where('tarihKey', isEqualTo: bugun)
          .get();
      _bugunYapilanSefer = seferSnap.docs.length;

      setState(() {});
    } catch (e) {
      debugPrint('Özet hata: $e');
    }
  }

  // ─── YOKLUKLAR ────────────────────────────────────────────────────
  Future<void> _yokluklariYukle() async {
    if (_firmaId == null) return;
    setState(() => _yoklukYukleniyor = true);
    try {
      // Seçili haftanın Pazartesi ve Pazar günleri
      final haftaBasi = _haftaBasi(_seciliHafta);
      final haftaSonu = haftaBasi.add(const Duration(days: 6));

      final snap = await _db
          .collection('firms')
          .doc(_firmaId)
          .collection('yokluklar')
          .where('tarih', isGreaterThanOrEqualTo: _tarihKey(haftaBasi))
          .where('tarih', isLessThanOrEqualTo: _tarihKey(haftaSonu))
          .orderBy('tarih', descending: true)
          .get();

      setState(() {
        _yokluklar =
            snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        _yoklukYukleniyor = false;
      });
    } catch (e) {
      setState(() => _yoklukYukleniyor = false);
      debugPrint('Yokluk hata: $e');
    }
  }

  // ─── PDF RAPOR ────────────────────────────────────────────────────
  Future<void> _pdfRaporOlustur() async {
    final pdf = pw.Document();
    final bugun = DateTime.now();
    final tarihStr =
        '${bugun.day.toString().padLeft(2, '0')}.${bugun.month.toString().padLeft(2, '0')}.${bugun.year}';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          // Başlık
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('1a3a6b'),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Servisim360',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Günlük Rapor — $tarihStr',
                      style: const pw.TextStyle(
                          color: PdfColors.white, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Özet istatistikler
          pw.Text('Günlük Özet',
              style: pw.TextStyle(
                  fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              pw.TableRow(
                decoration:
                const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1a3a6b)),
                children: [
                  _pdfHucre('Metrik', beyaz: true, bold: true),
                  _pdfHucre('Değer', beyaz: true, bold: true),
                ],
              ),
              _pdfSatir('Toplam Öğrenci', '$_toplamOgrenci'),
              _pdfSatir('Bugün Binen', '$_bugunkuBinenler'),
              _pdfSatir('Bugün Gelmeyen', '$_bugunkuGelmeyenler'),
              _pdfSatir('Aktif Şoför', '$_aktifSofor'),
              _pdfSatir(
                  'Devam Oranı',
                  _toplamOgrenci > 0
                      ? '%${((_toplamOgrenci - _bugunkuGelmeyenler) / _toplamOgrenci * 100).toStringAsFixed(1)}'
                      : '-'),
            ],
          ),
          pw.SizedBox(height: 20),

          // Bu haftaki yokluklar
          if (_yokluklar.isNotEmpty) ...[
            pw.Text('Bu Hafta Yokluklar',
                style: pw.TextStyle(
                    fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFFF8C00)),
                  children: [
                    _pdfHucre('Öğrenci', beyaz: true, bold: true),
                    _pdfHucre('Tarih', beyaz: true, bold: true),
                    _pdfHucre('Durum', beyaz: true, bold: true),
                  ],
                ),
                ..._yokluklar.map((y) => pw.TableRow(children: [
                  _pdfHucre(y['ogrenciAd'] ?? '-'),
                  _pdfHucre(y['tarih'] ?? '-'),
                  _pdfHucre(
                      (y['geliyor'] ?? true) ? 'Geldi' : 'Gelmedi'),
                ])),
              ],
            ),
          ],

          pw.SizedBox(height: 20),
          pw.Divider(),
          pw.Text(
            'Servisim360 — Akıllı Servis Yönetim Sistemi | $tarihStr',
            style: const pw.TextStyle(
                color: PdfColors.grey, fontSize: 9),
          ),
        ],
      ),
    );

    final Uint8List bytes = await pdf.save();
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  pw.Widget _pdfHucre(String metin,
      {bool beyaz = false, bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        metin,
        style: pw.TextStyle(
          color: beyaz ? PdfColors.white : PdfColors.black,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: 11,
        ),
      ),
    );
  }

  pw.TableRow _pdfSatir(String label, String deger) {
    return pw.TableRow(children: [
      _pdfHucre(label),
      _pdfHucre(deger),
    ]);
  }

  // ─── YARDIMCI ─────────────────────────────────────────────────────
  String _bugunKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _tarihKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  DateTime _haftaBasi(DateTime dt) {
    final gun = dt.weekday; // 1=Pzt, 7=Paz
    return dt.subtract(Duration(days: gun - 1));
  }

  String _tarihFormat(dynamic ts) {
    if (ts == null) return '-';
    DateTime dt;
    if (ts is Timestamp) {
      dt = ts.toDate();
    } else {
      return ts.toString();
    }
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _haftaBaslikYazdir() {
    final bas = _haftaBasi(_seciliHafta);
    final son = bas.add(const Duration(days: 6));
    return '${bas.day.toString().padLeft(2, '0')}.${bas.month.toString().padLeft(2, '0')} – '
        '${son.day.toString().padLeft(2, '0')}.${son.month.toString().padLeft(2, '0')}.${son.year}';
  }

  IconData _tipIkonu(String tip) {
    switch (tip) {
      case 'ogrenci': return Icons.person;
      case 'surucu': return Icons.drive_eta;
      case 'rota': return Icons.route;
      case 'yoklama': return Icons.fact_check;
      case 'giris': return Icons.login;
      case 'sefer': return Icons.directions_bus;
      default: return Icons.history;
    }
  }

  Color _tipRengi(String tip) {
    switch (tip) {
      case 'ogrenci': return Colors.blue;
      case 'surucu': return Colors.green;
      case 'rota': return Colors.purple;
      case 'yoklama': return Colors.teal;
      case 'giris': return Colors.orange;
      case 'sefer': return navyBlue;
      default: return Colors.grey;
    }
  }

  Stream<QuerySnapshot>? get _gecmisStream {
    if (_firmaId == null || _firmaId!.isEmpty) return null;
    Query q = _db
        .collection('firms')
        .doc(_firmaId)
        .collection('gecmis')
        .orderBy('tarih', descending: true)
        .limit(100);
    if (_gecmisFiltre != 'hepsi') {
      q = q.where('tip', isEqualTo: _gecmisFiltre);
    }
    return q.snapshots();
  }

  // ─── BUILD ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: navyBlue,
        title: const Text('Raporlar & Geçmiş',
            style: TextStyle(color: Colors.white, fontSize: 17)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          YardimButonu(ekranAdi: 'Raporlar'),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            tooltip: 'PDF Rapor Al',
            onPressed: _pdfRaporOlustur,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () async {
              setState(() => _yukleniyor = true);
              await _ozetVerileriniYukle();
              await _yokluklariYukle();
              setState(() => _yukleniyor = false);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: turuncu,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard, size: 18), text: 'Özet'),
            Tab(icon: Icon(Icons.fact_check, size: 18), text: 'Yokluklar'),
            Tab(icon: Icon(Icons.history, size: 18), text: 'Geçmiş'),
          ],
        ),
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator(color: navyBlue))
          : _firmaId == null || _firmaId!.isEmpty
          ? const Center(
          child: Text('Firma bilgisi bulunamadı.',
              style: TextStyle(color: Colors.grey)))
          : TabBarView(
        controller: _tabController,
        children: [
          _ozetTab(),
          _yoklukTab(),
          _gecmisTab(),
        ],
      ),
    );
  }

  // ─── ÖZET TAB ─────────────────────────────────────────────────────
  Widget _ozetTab() {
    final devamOrani = _toplamOgrenci > 0
        ? ((_toplamOgrenci - _bugunkuGelmeyenler) /
        _toplamOgrenci *
        100)
        .toStringAsFixed(1)
        : '0';

    return RefreshIndicator(
      onRefresh: _ozetVerileriniYukle,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tarih başlığı
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [navyBlue, Color(0xFF2a5298)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      color: Colors.white70, size: 18),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Bugünkü Rapor',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                      Text(_tarihYazdir(DateTime.now()),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _pdfRaporOlustur,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: turuncu,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.picture_as_pdf,
                              color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text('PDF',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Stat kartları 2x2
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                _statKart(
                  ikon: Icons.people,
                  deger: '$_toplamOgrenci',
                  label: 'Toplam Öğrenci',
                  renk: navyBlue,
                ),
                _statKart(
                  ikon: Icons.directions_bus,
                  deger: '$_bugunkuBinenler',
                  label: 'Bugün Binen',
                  renk: Colors.green,
                ),
                _statKart(
                  ikon: Icons.person_off,
                  deger: '$_bugunkuGelmeyenler',
                  label: 'Gelmeyen',
                  renk: _bugunkuGelmeyenler > 0
                      ? Colors.red
                      : Colors.grey,
                ),
                _statKart(
                  ikon: Icons.drive_eta,
                  deger: '$_aktifSofor',
                  label: 'Aktif Şoför',
                  renk: _aktifSofor > 0 ? Colors.blue : Colors.grey,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Devam oranı
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6)
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.trending_up,
                          color: navyBlue, size: 18),
                      const SizedBox(width: 8),
                      const Text('Bugün Devam Oranı',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: navyBlue)),
                      const Spacer(),
                      Text('$devamOrani%',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: double.tryParse(devamOrani)! >= 80
                                  ? Colors.green
                                  : Colors.orange)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _toplamOgrenci > 0
                          ? (_toplamOgrenci - _bugunkuGelmeyenler) /
                          _toplamOgrenci
                          : 0,
                      backgroundColor: Colors.grey[200],
                      color: double.tryParse(devamOrani)! >= 80
                          ? Colors.green
                          : Colors.orange,
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$_toplamOgrenci öğrenciden ${_toplamOgrenci - _bugunkuGelmeyenler} tanesi bugün serviste',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Hızlı geçiş
            Row(
              children: [
                Expanded(
                  child: _hizliBtn(
                    ikon: Icons.fact_check,
                    label: 'Yokluklar',
                    renk: Colors.teal,
                    onTap: () => _tabController.animateTo(1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _hizliBtn(
                    ikon: Icons.history,
                    label: 'Geçmiş',
                    renk: Colors.purple,
                    onTap: () => _tabController.animateTo(2),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _statKart({
    required IconData ikon,
    required String deger,
    required String label,
    required Color renk,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: renk.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(ikon, color: renk, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(deger,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: renk)),
              Text(label,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[500])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hizliBtn({
    required IconData ikon,
    required String label,
    required Color renk,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6)
          ],
        ),
        child: Column(
          children: [
            Icon(ikon, color: renk, size: 24),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  String _tarihYazdir(DateTime dt) {
    const aylar = [
      '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    const gunler = [
      '', 'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe',
      'Cuma', 'Cumartesi', 'Pazar'
    ];
    return '${gunler[dt.weekday]}, ${dt.day} ${aylar[dt.month]} ${dt.year}';
  }

  // ─── YOKLUK TAB ───────────────────────────────────────────────────
  Widget _yoklukTab() {
    // Hafta günlerine göre grupla
    final gruplar = <String, List<Map<String, dynamic>>>{};
    for (final y in _yokluklar) {
      final tarih = y['tarih'] as String? ?? '';
      gruplar.putIfAbsent(tarih, () => []).add(y);
    }
    final tarihler = gruplar.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      children: [
        // Hafta seçici
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _seciliHafta =
                        _seciliHafta.subtract(const Duration(days: 7));
                  });
                  _yokluklariYukle();
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: navyBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.chevron_left,
                      color: navyBlue, size: 20),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    _haftaBaslikYazdir(),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: navyBlue),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  final sonrakiHafta =
                  _seciliHafta.add(const Duration(days: 7));
                  if (sonrakiHafta.isBefore(
                      DateTime.now().add(const Duration(days: 1)))) {
                    setState(() => _seciliHafta = sonrakiHafta);
                    _yokluklariYukle();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: navyBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.chevron_right,
                      color: navyBlue, size: 20),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        _yoklukYukleniyor
            ? const Expanded(
            child: Center(
                child: CircularProgressIndicator(color: navyBlue)))
            : _yokluklar.isEmpty
            ? Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 64, color: Colors.grey[300]),
                const SizedBox(height: 12),
                const Text('Bu hafta yokluk kaydı yok',
                    style: TextStyle(
                        fontSize: 15, color: Colors.grey)),
                const SizedBox(height: 8),
                Text('Tüm öğrenciler devam etti! 🎉',
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.green[400])),
              ],
            ),
          ),
        )
            : Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: tarihler.length,
            itemBuilder: (ctx, i) {
              final tarih = tarihler[i];
              final liste = gruplar[tarih]!;
              final gelmeyenler =
                  liste.where((y) => y['geliyor'] == false).length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tarih başlığı
                  Padding(
                    padding:
                    const EdgeInsets.only(bottom: 6, top: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 16,
                          decoration: BoxDecoration(
                              color: gelmeyenler > 0
                                  ? Colors.red
                                  : Colors.green,
                              borderRadius:
                              BorderRadius.circular(2)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _tarihGoster(tarih),
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.grey[700]),
                        ),
                        const SizedBox(width: 8),
                        if (gelmeyenler > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red
                                  .withValues(alpha: 0.1),
                              borderRadius:
                              BorderRadius.circular(6),
                            ),
                            child: Text(
                                '$gelmeyenler gelmeyen',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.red,
                                    fontWeight:
                                    FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                  // O güne ait yokluklar
                  ...liste.map((y) => _yoklukKarti(y)),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _yoklukKarti(Map<String, dynamic> yokluk) {
    final geliyor = yokluk['geliyor'] ?? true;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(
            left: BorderSide(
                color: geliyor ? Colors.green : Colors.red, width: 3)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4)
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor:
            geliyor ? Colors.green : Colors.red,
            child: Text(
              (yokluk['ogrenciAd'] ?? '?')[0].toUpperCase(),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              yokluk['ogrenciAd'] ?? '-',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: geliyor
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              geliyor ? '✅ Geldi' : '❌ Gelmedi',
              style: TextStyle(
                  color: geliyor ? Colors.green : Colors.red,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String _tarihGoster(String tarihKey) {
    try {
      final parcalar = tarihKey.split('-');
      if (parcalar.length != 3) return tarihKey;
      return '${parcalar[2]}.${parcalar[1]}.${parcalar[0]}';
    } catch (_) {
      return tarihKey;
    }
  }

  // ─── GEÇMİŞ TAB ───────────────────────────────────────────────────
  Widget _gecmisTab() {
    return Column(
      children: [
        // Filtreler
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _filtreBtn('hepsi', 'Hepsi', Colors.grey),
              const SizedBox(width: 8),
              _filtreBtn('ogrenci', 'Öğrenci', Colors.blue),
              const SizedBox(width: 8),
              _filtreBtn('surucu', 'Şoför', Colors.green),
              const SizedBox(width: 8),
              _filtreBtn('rota', 'Rota', Colors.purple),
              const SizedBox(width: 8),
              _filtreBtn('yoklama', 'Yoklama', Colors.teal),
              const SizedBox(width: 8),
              _filtreBtn('sefer', 'Sefer', navyBlue),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _gecmisStream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: navyBlue));
              }
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history,
                          size: 72, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('Geçmiş kaydı bulunamadı',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 15)),
                    ],
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: snap.data!.docs.length,
                itemBuilder: (context, i) {
                  final d =
                  snap.data!.docs[i].data() as Map<String, dynamic>;
                  final tip = d['tip'] ?? 'diger';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border(
                          left: BorderSide(
                              color: _tipRengi(tip), width: 4)),
                      boxShadow: [
                        BoxShadow(
                            color:
                            Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4)
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _tipRengi(tip)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(_tipIkonu(tip),
                              color: _tipRengi(tip), size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d['aciklama'] ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                              const SizedBox(height: 2),
                              Text(
                                '${d['kullanici'] ?? ''} · ${_tarihFormat(d['tarih'])}',
                                style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _filtreBtn(String deger, String metin, Color renk) {
    final secili = _gecmisFiltre == deger;
    return GestureDetector(
      onTap: () => setState(() => _gecmisFiltre = deger),
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: secili ? renk : renk.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(metin,
            style: TextStyle(
                color: secili ? Colors.white : renk,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      ),
    );
  }
}
