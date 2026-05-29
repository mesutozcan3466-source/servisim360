import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) return const Center(child: CircularProgressIndicator(color: _navy));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

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
