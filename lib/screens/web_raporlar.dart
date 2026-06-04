import 'package:flutter/material.dart';
import 'ai_widget.dart';
import 'package:flutter/services.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/session_service.dart';

class WebRaporlar extends StatefulWidget {
  const WebRaporlar({super.key});
  @override
  State<WebRaporlar> createState() => _WebRaporlarState();
}

class _WebRaporlarState extends State<WebRaporlar> {
  static const _navy   = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);

  bool _yukleniyor = true;
  int _ogrenciSayi = 0, _soforSayi = 0, _devamsizlikSayi = 0, _aktifServis = 0;
  Map<String, int> _gunlukDevamsizlik = {};
  Map<String, int> _soforDoluluk = {};
  String _firmaId = '';

  @override
  void initState() { super.initState(); _yukle(); }

  Future<void> _yukle() async {
    _firmaId = await SessionService.instance.firmaIdAl() ?? '';
    final projeId = SessionService.instance.aktifProjeld ?? '';
    if (_firmaId.isEmpty) { setState(() => _yukleniyor = false); return; }
    try {
      final now = DateTime.now();
      final baslangic = now.subtract(const Duration(days: 7));

      final results = await Future.wait([
        FirebaseFirestore.instance.collection('students')
            .where('firmaId', isEqualTo: _firmaId)
            .where('projeId', isEqualTo: projeId).count().get(),
        FirebaseFirestore.instance.collection('drivers')
            .where('firmaId', isEqualTo: _firmaId).count().get(),
        FirebaseFirestore.instance.collection('absence_requests')
            .where('firmaId', isEqualTo: _firmaId).count().get(),
        FirebaseFirestore.instance.collection('drivers')
            .where('firmaId', isEqualTo: _firmaId)
            .where('servisAktif', isEqualTo: true).count().get(),
      ]);

      _ogrenciSayi    = results[0].count ?? 0;
      _soforSayi      = results[1].count ?? 0;
      _devamsizlikSayi = results[2].count ?? 0;
      _aktifServis    = results[3].count ?? 0;

      // Son 7 gün devamsızlık
      final devSnap = await FirebaseFirestore.instance.collection('absence_requests')
          .where('firmaId', isEqualTo: _firmaId)
          .where('tarih', isGreaterThan: Timestamp.fromDate(baslangic))
          .get();

      final gunMap = <String, int>{};
      for (var i = 6; i >= 0; i--) {
        final gun = now.subtract(Duration(days: i));
        gunMap['${gun.day}.${gun.month}'] = 0;
      }
      for (final doc in devSnap.docs) {
        final t = doc.data()['tarih'] as Timestamp?;
        if (t != null) {
          final k = '${t.toDate().day}.${t.toDate().month}';
          gunMap[k] = (gunMap[k] ?? 0) + 1;
        }
      }
      _gunlukDevamsizlik = gunMap;

      // Şoför doluluk
      final soforSnap = await FirebaseFirestore.instance.collection('drivers')
          .where('firmaId', isEqualTo: _firmaId).get();
      final ogrSnap = await FirebaseFirestore.instance.collection('students')
          .where('firmaId', isEqualTo: _firmaId)
          .where('projeId', isEqualTo: projeId).get();

      final doluluk = <String, int>{};
      for (final s in soforSnap.docs) {
        final ad = s.data()['ad'] as String? ?? 'Sofor';
        final sayi = ogrSnap.docs.where((o) =>
        (o.data()['surucuId'] ?? '') == s.id).length;
        doluluk[ad] = sayi;
      }
      _soforDoluluk = doluluk;
    } catch (_) {}
    if (mounted) setState(() => _yukleniyor = false);
  }

  // ── DIŞA AKTARMA ──────────────────────────────────────────────
  void _disaAktarDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.download_outlined, color: _navy, size: 22),
          SizedBox(width: 10),
          Text('Raporu Dışa Aktar'),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _disaBtn(Icons.table_chart_outlined,     Colors.green,  'Excel Aktar',      _excelaAktar),
          const SizedBox(height: 8),
          _disaBtn(Icons.people_outlined,          Colors.blue,   'Öğrenci Listesi',    _ogrenciListesiKopyala),
          const SizedBox(height: 8),
          _disaBtn(Icons.directions_car_outlined,  _navy,         'Şoför Listesi',      _soforListesiKopyala),
          const SizedBox(height: 8),
          _disaBtn(Icons.event_busy_outlined,      Colors.red,    'Devamsızlık Raporu', _devamsizlikKopyala),
          const SizedBox(height: 8),
          _disaBtn(Icons.bar_chart_outlined,       Colors.green,  'Genel Özet',         _genelOzetKopyala),
        ]),
        actions: [
          AiAsistanButonu(ekranAdi: 'Raporlar'),TextButton(onPressed: () => Navigator.pop(_), child: const Text('Kapat'))],
      ),
    );
  }

  Widget _disaBtn(IconData icon, Color renk, String label, VoidCallback onTap) =>
      GestureDetector(
        onTap: () { Navigator.pop(context); onTap(); },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: renk.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: renk.withValues(alpha: 0.2))),
          child: Row(children: [
            Icon(icon, color: renk, size: 18),
            const SizedBox(width: 12),
            Expanded(child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
            Icon(Icons.copy_rounded, color: renk, size: 16),
          ]),
        ),
      );

  Future<void> _excelaAktar() async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Öğrenciler'];
      sheet.appendRow([
        TextCellValue('No'), TextCellValue('Ad Soyad'),
        TextCellValue('Veli'), TextCellValue('Tel'),
        TextCellValue('Adres'), TextCellValue('Servis'),
      ]);
      final snap = await FirebaseFirestore.instance
          .collection('students').where('firmaId', isEqualTo: _firmaId)
          .orderBy('ad').get();
      for (var i = 0; i < snap.docs.length; i++) {
        final d = snap.docs[i].data();
        sheet.appendRow([
          IntCellValue(i + 1),
          TextCellValue('${d['ad'] ?? ''} ${d['soyad'] ?? ''}'.trim()),
          TextCellValue(d['veliAd'] ?? ''),
          TextCellValue(d['veliTel'] ?? ''),
          TextCellValue(d['adres'] ?? ''),
          TextCellValue(d['surucuId'] != null ? 'Atandı' : 'Atanmadı'),
        ]);
      }
      final bytes = excel.encode();
      if (bytes != null) {
        _snack('Excel hazırlandı (${snap.docs.length} kayıt)');
      }
    } catch (e) { _snack('Excel hatası: $e', hata: true); }
  }

  Future<void> _ogrenciListesiKopyala() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('students').where('firmaId', isEqualTo: _firmaId)
          .orderBy('ad').get();
      final buf = StringBuffer();
      buf.writeln('ÖĞRENCİ LİSTESİ — Servisim360');
      buf.writeln('Tarih: ${_bugun()}  |  Toplam: ${snap.docs.length}');
      buf.writeln('─' * 42);
      for (var i = 0; i < snap.docs.length; i++) {
        final d = snap.docs[i].data();
        buf.writeln('${i+1}. ${d['ad'] ?? ''} ${d['soyad'] ?? ''}'.trim());
        if ((d['veliAd'] ?? '').isNotEmpty) buf.writeln('   Veli: ${d['veliAd']}  ${d['veliTel'] ?? ''}');
        if ((d['adres'] ?? '').isNotEmpty)  buf.writeln('   Adres: ${d['adres']}');
        buf.writeln();
      }
      await Clipboard.setData(ClipboardData(text: buf.toString()));
      _snack('Öğrenci listesi kopyalandı (${snap.docs.length} kayıt)');
    } catch (e) { _snack('Hata: $e', hata: true); }
  }

  Future<void> _soforListesiKopyala() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('drivers').where('firmaId', isEqualTo: _firmaId)
          .get();
      final buf = StringBuffer();
      buf.writeln('ŞOFÖR LİSTESİ — Servisim360');
      buf.writeln('Tarih: ${_bugun()}  |  Toplam: ${snap.docs.length}');
      buf.writeln('─' * 42);
      for (var i = 0; i < snap.docs.length; i++) {
        final d = snap.docs[i].data();
        buf.writeln('${i+1}. ${d['adSoyad'] ?? d['ad'] ?? ''}');
        if ((d['telefon'] ?? '').isNotEmpty)         buf.writeln('   Tel: ${d['telefon']}');
        if ((d['plaka'] ?? d['aracPlaka'] ?? '').isNotEmpty) buf.writeln('   Plaka: ${d['plaka'] ?? d['aracPlaka']}');
        buf.writeln('   Durum: ${d['soforDurum'] ?? 'bosta'}');
        buf.writeln();
      }
      await Clipboard.setData(ClipboardData(text: buf.toString()));
      _snack('Şoför listesi kopyalandı (${snap.docs.length} kayıt)');
    } catch (e) { _snack('Hata: $e', hata: true); }
  }

  Future<void> _devamsizlikKopyala() async {
    try {
      final otuzGun = DateTime.now().subtract(const Duration(days: 30));
      final snap = await FirebaseFirestore.instance
          .collection('absence_requests')
          .where('firmaId', isEqualTo: _firmaId)
          .where('tarih', isGreaterThanOrEqualTo: Timestamp.fromDate(otuzGun))
          .orderBy('tarih', descending: true).get();
      final buf = StringBuffer();
      buf.writeln('DEVAMSIZLlK RAPORU — Servisim360');
      buf.writeln('Dönem: Son 30 gün  |  Tarih: ${_bugun()}');
      buf.writeln('Toplam: ${snap.docs.length} kayıt');
      buf.writeln('─' * 42);
      for (final doc in snap.docs) {
        final d = doc.data();
        final t = d['tarih'] is Timestamp
            ? (d['tarih'] as Timestamp).toDate()
            : DateTime.now();
        final tip = d['tip'] == 'sabah' ? 'Sadece Sabah' :
                    d['tip'] == 'aksam' ? 'Sadece Akşam' : 'Tüm Gün';
        buf.writeln('• ${d['ogrenciAd'] ?? '-'} — $tip (${t.day}.${t.month}.${t.year})');
      }
      await Clipboard.setData(ClipboardData(text: buf.toString()));
      _snack('Devamsızlık raporu kopyalandı (${snap.docs.length} kayıt)');
    } catch (e) { _snack('Hata: $e', hata: true); }
  }

  void _genelOzetKopyala() async {
    final buf = StringBuffer();
    buf.writeln('GENEL ÖZET — Servisim360');
    buf.writeln('Tarih: ${_bugun()}');
    buf.writeln('─' * 42);
    buf.writeln('👨‍🎓 Toplam Öğrenci : $_ogrenciSayi');
    buf.writeln('🚗 Toplam Şoför   : $_soforSayi');
    buf.writeln('🟢 Aktif Servis   : $_aktifServis');
    buf.writeln('❌ Devamsızlık    : $_devamsizlikSayi');
    buf.writeln('─' * 42);
    buf.writeln('Servisim360 tarafından oluşturuldu');
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    _snack('Genel özet kopyalandı');
  }

  String _bugun() {
    final now = DateTime.now();
    return '${now.day}.${now.month}.${now.year}';
  }

  void _snack(String m, {bool hata = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(hata ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(m)),
      ]),
      backgroundColor: hata ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) return const Center(child: CircularProgressIndicator(color: _navy));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Üst bar — dışa aktarma butonu
        Row(children: [
          const Text('Raporlar', style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: _navy)),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _navy, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: _disaAktarDialog,
            icon: const Icon(Icons.download_outlined, size: 16),
            label: const Text('Dışa Aktar', style: TextStyle(fontWeight: FontWeight.bold))),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _navy,
                side: const BorderSide(color: _navy),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () { setState(() => _yukleniyor = true); _yukle(); },
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Yenile')),
        ]),
        const SizedBox(height: 16),

        // Özet kartlar
        Row(children: [
          _RaporKart('Toplam Ogrenci', '$_ogrenciSayi', Icons.people_outline, Colors.blue),
          const SizedBox(width: 14),
          _RaporKart('Toplam Sofor', '$_soforSayi', Icons.directions_bus_outlined, _navy),
          const SizedBox(width: 14),
          _RaporKart('Aktif Servis', '$_aktifServis', Icons.my_location_outlined, Colors.green),
          const SizedBox(width: 14),
          _RaporKart('Toplam Devamsizlik', '$_devamsizlikSayi', Icons.event_busy_outlined, Colors.red),
        ]),

        const SizedBox(height: 20),

        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Son 7 gün devamsızlık grafiği
          Expanded(flex: 3, child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Son 7 Gun Devamsizlik',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _navy)),
              const SizedBox(height: 20),
              SizedBox(height: 200, child: _gunlukDevamsizlik.isEmpty
                  ? const Center(child: Text('Veri yok'))
                  : BarChart(BarChartData(
                barGroups: _gunlukDevamsizlik.entries.toList().asMap().entries.map((e) =>
                    BarChartGroupData(x: e.key, barRods: [
                      BarChartRodData(toY: e.value.value.toDouble(),
                          color: _orange, width: 20, borderRadius: BorderRadius.circular(4)),
                    ])).toList(),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true, reservedSize: 30,
                    getTitlesWidget: (v, _) {
                      final keys = _gunlukDevamsizlik.keys.toList();
                      if (v.toInt() < keys.length) return Text(keys[v.toInt()],
                          style: const TextStyle(fontSize: 9));
                      return const Text('');
                    },
                  )),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: true),
              ))),
            ]),
          )),

          const SizedBox(width: 14),

          // Şoför doluluk
          Expanded(flex: 2, child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Servis Dolulugu',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _navy)),
              const SizedBox(height: 16),
              ..._soforDoluluk.entries.map((e) {
                final max = 16;
                final oran = (e.value / max).clamp(0.0, 1.0);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(e.key,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                      Text('${e.value}/$max',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ]),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: oran,
                      backgroundColor: Colors.grey.shade200,
                      color: oran > 0.85 ? Colors.red : oran > 0.6 ? _orange : Colors.green,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ]),
                );
              }),
            ]),
          )),
        ]),

        const SizedBox(height: 14),

        // Devamsızlık listesi
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('Devamsizlik Listesi',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _navy)),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.open_in_full_outlined, size: 14),
                label: const Text('Tumunu Gor', style: TextStyle(fontSize: 12)),
                onPressed: () => Navigator.pushNamed(context, '/yoklama'),
              ),
            ]),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('absence_requests')
                  .where('firmaId', isEqualTo: _firmaId)
                  .orderBy('tarih', descending: true).limit(10).snapshots(),
              builder: (_, snap) {
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) return const Center(child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Devamsizlik yok'),
                ));
                return Table(
                  columnWidths: const {
                    0: FixedColumnWidth(200),
                    1: FlexColumnWidth(),
                    2: FixedColumnWidth(120),
                    3: FixedColumnWidth(100),
                  },
                  children: [
                    const TableRow(children: [
                      Padding(padding: EdgeInsets.only(bottom: 8),
                          child: Text('Ogrenci', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Padding(padding: EdgeInsets.only(bottom: 8),
                          child: Text('Aciklama', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Padding(padding: EdgeInsets.only(bottom: 8),
                          child: Text('Tarih', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Padding(padding: EdgeInsets.only(bottom: 8),
                          child: Text('Durum', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    ]),
                    ...docs.map((doc) {
                      final d = doc.data() as Map<String, dynamic>;
                      final t = d['tarih'] as Timestamp?;
                      return TableRow(children: [
                        Padding(padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(d['ogrenciAd'] ?? '-', style: const TextStyle(fontSize: 12))),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(d['aciklama'] ?? '-', style: const TextStyle(fontSize: 12))),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(t != null
                                ? '${t.toDate().day}.${t.toDate().month}.${t.toDate().year}'
                                : '-', style: const TextStyle(fontSize: 12))),
                        Padding(padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4)),
                              child: const Text('Bildiridi',
                                  style: TextStyle(fontSize: 10, color: Colors.orange,
                                      fontWeight: FontWeight.bold)),
                            )),
                      ]);
                    }),
                  ],
                );
              },
            ),
          ]),
        ),
      ]),
    );
  }
}

class _RaporKart extends StatelessWidget {
  final String baslik, deger; final IconData ikon; final Color renk;
  const _RaporKart(this.baslik, this.deger, this.ikon, this.renk);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)]),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: renk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(ikon, color: renk, size: 22)),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(deger, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: renk)),
        Text(baslik, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ]),
    ]),
  ));
}
