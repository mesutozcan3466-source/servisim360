import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/session_service.dart';

class WebSoforler extends StatefulWidget {
  const WebSoforler({super.key});
  @override
  State<WebSoforler> createState() => _WebSoforlerState();
}

class _WebSoforlerState extends State<WebSoforler> {
  static const _navy   = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);

  List<Map<String, dynamic>> _soforler    = [];
  List<Map<String, dynamic>> _filtreliSof = [];
  bool _yukleniyor = true;
  final _aramaCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _yukle(); }

  @override
  void dispose() { _aramaCtrl.dispose(); super.dispose(); }

  Future<void> _yukle() async {
    final firmaId = await SessionService.instance.firmaIdAl() ?? '';
    if (firmaId.isEmpty) { setState(() => _yukleniyor = false); return; }
    try {
      final snap = await FirebaseFirestore.instance.collection('drivers')
          .where('firmaId', isEqualTo: firmaId).orderBy('ad').get();
      _soforler = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      // Her şoföre öğrenci sayısını ekle
      final projeId = SessionService.instance.aktifProjeld ?? '';
      for (final s in _soforler) {
        var q = FirebaseFirestore.instance.collection('students')
            .where('surucuId', isEqualTo: s['id']);
        if (projeId.isNotEmpty) q = q.where('projeId', isEqualTo: projeId);
        final c = await q.count().get();
        s['ogrenciSayi'] = c.count ?? 0;
      }
    } catch (_) {}
    _filtrele();
    if (mounted) setState(() => _yukleniyor = false);
  }

  void _filtrele() {
    var liste = List<Map<String, dynamic>>.from(_soforler);
    final ara = _aramaCtrl.text.toLowerCase();
    if (ara.isNotEmpty) {
      liste = liste.where((s) =>
      (s['ad'] ?? '').toString().toLowerCase().contains(ara) ||
          (s['telefon'] ?? '').toString().contains(ara) ||
          (s['aracPlaka'] ?? '').toString().toLowerCase().contains(ara)
      ).toList();
    }
    setState(() => _filtreliSof = liste);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Üst bar
      Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: Row(children: [
          Expanded(child: TextField(
            controller: _aramaCtrl,
            decoration: InputDecoration(
              hintText: 'Sofor ara (isim, plaka, telefon...)',
              prefixIcon: const Icon(Icons.search, color: _navy, size: 18),
              filled: true, fillColor: const Color(0xFFF5F7FA),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onChanged: (_) => _filtrele(),
          )),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _navy, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            icon: const Icon(Icons.person_add_outlined, size: 16),
            label: const Text('Sofor Ekle', style: TextStyle(fontSize: 12)),
            onPressed: () => Navigator.pushNamed(context, '/suruculer'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _orange, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            icon: const Icon(Icons.add_road_outlined, size: 16),
            label: const Text('Rota Olustur', style: TextStyle(fontSize: 12)),
            onPressed: () => Navigator.pushNamed(context, '/gruplama'),
          ),
        ]),
      ),

      // Sayaç
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        color: const Color(0xFFF5F7FA),
        child: Row(children: [
          Text('${_filtreliSof.length} sofor', style: const TextStyle(
              color: _navy, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(width: 8),
          Text('/ ${_soforler.length} toplam',
              style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          const SizedBox(width: 16),
          Container(width: 8, height: 8,
              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(
            '${_soforler.where((s) => s['servisAktif'] == true).length} aktif',
            style: const TextStyle(color: Colors.green, fontSize: 12),
          ),
        ]),
      ),

      // Kartlar grid
      Expanded(child: _yukleniyor
          ? const Center(child: CircularProgressIndicator(color: _navy))
          : _filtreliSof.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.directions_bus_outlined, size: 64, color: Colors.grey),
        const SizedBox(height: 12),
        Text('Sofor bulunamadi', style: TextStyle(color: Colors.grey[400])),
      ]))
          : GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 340, mainAxisExtent: 200,
          crossAxisSpacing: 12, mainAxisSpacing: 12,
        ),
        itemCount: _filtreliSof.length,
        itemBuilder: (_, i) => _SoforKarti(
          sofor: _filtreliSof[i],
          onDuzenle: () => Navigator.pushNamed(context, '/suruculer'),
          onRota: () => Navigator.pushNamed(context, '/gruplama'),
        ),
      )),
    ]);
  }
}

class _SoforKarti extends StatelessWidget {
  final Map<String, dynamic> sofor;
  final VoidCallback onDuzenle, onRota;
  static const _navy = Color(0xFF1a3a6b);

  const _SoforKarti({required this.sofor, required this.onDuzenle, required this.onRota});

  @override
  Widget build(BuildContext context) {
    final aktif      = sofor['servisAktif'] == true;
    final ogrSayi    = sofor['ogrenciSayi'] as int? ?? 0;
    final hiz        = (sofor['hiz'] as num? ?? 0).toStringAsFixed(0);
    final ad         = sofor['ad'] as String? ?? 'Sofor';
    final plaka      = sofor['aracPlaka'] as String? ?? '-';
    final tel        = sofor['telefon'] as String? ?? '-';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: aktif ? Border.all(color: Colors.green.withValues(alpha: 0.4), width: 1.5) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: aktif
                ? Colors.green.withValues(alpha: 0.15)
                : _navy.withValues(alpha: 0.1),
            child: Text(ad[0].toUpperCase(),
                style: TextStyle(color: aktif ? Colors.green : _navy,
                    fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ad, style: const TextStyle(fontWeight: FontWeight.bold,
                fontSize: 14, color: _navy), overflow: TextOverflow.ellipsis),
            Text(plaka, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: (aktif ? Colors.green : Colors.grey).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Text(aktif ? 'Aktif' : 'Bosta',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                    color: aktif ? Colors.green : Colors.grey)),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _MiniInfo(Icons.people_outline, '$ogrSayi ogr', Colors.blue),
          const SizedBox(width: 12),
          _MiniInfo(Icons.phone_outlined, tel, Colors.grey),
          if (aktif) ...[
            const SizedBox(width: 12),
            _MiniInfo(Icons.speed_outlined, '$hiz km/s', Colors.green),
          ],
        ]),
        const Spacer(),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                foregroundColor: _navy,
                side: const BorderSide(color: _navy),
                padding: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            icon: const Icon(Icons.edit_outlined, size: 14),
            label: const Text('Duzenle', style: TextStyle(fontSize: 11)),
            onPressed: onDuzenle,
          )),
          const SizedBox(width: 8),
          Expanded(child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _navy, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            icon: const Icon(Icons.route_outlined, size: 14),
            label: const Text('Rota', style: TextStyle(fontSize: 11)),
            onPressed: onRota,
          )),
        ]),
      ]),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  final IconData ikon; final String metin; final Color renk;
  const _MiniInfo(this.ikon, this.metin, this.renk);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(ikon, size: 13, color: renk),
    const SizedBox(width: 4),
    Text(metin, style: TextStyle(fontSize: 11, color: renk)),
  ]);
}
