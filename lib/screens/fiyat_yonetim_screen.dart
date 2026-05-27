import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

// ════════════════════════════════════════════════════════════════
//  FİYAT YÖNETİMİ — Mahalle + Km (okul adresi bazlı)
// ════════════════════════════════════════════════════════════════
class FiyatYonetimScreen extends StatefulWidget {
  const FiyatYonetimScreen({super.key});
  @override
  State<FiyatYonetimScreen> createState() => _FiyatYonetimScreenState();
}

class _FiyatYonetimScreenState extends State<FiyatYonetimScreen>
    with SingleTickerProviderStateMixin {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  static const _mapsKey = 'AIzaSyBX-9HFavvc7PvH7MuM22Xd9ymJSeWDdSo';

  late TabController _tab;
  String _firmaId = '';
  bool   _yuklendi = false;

  // Okul adresi
  final _okulAdresCtrl = TextEditingController();
  bool _okulKaydediliyor = false;
  String _kayitliOkulAdres = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _yukle();
  }

  @override
  void dispose() {
    _tab.dispose();
    _okulAdresCtrl.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { setState(() => _yuklendi = true); return; }
    final doc = await FirebaseFirestore.instance.collection('kullanicilar').doc(uid).get();
    final firmaId = doc.data()?['firmaId'] as String? ?? '';

    // Kayitli okul adresini al
    if (firmaId.isNotEmpty) {
      final firmaDoc = await FirebaseFirestore.instance.collection('firms').doc(firmaId).get();
      _kayitliOkulAdres = firmaDoc.data()?['okulAdresi'] ?? '';
      _okulAdresCtrl.text = _kayitliOkulAdres;
    }

    if (mounted) setState(() { _firmaId = firmaId; _yuklendi = true; });
  }

  Future<void> _okulAdresKaydet() async {
    if (_okulAdresCtrl.text.trim().isEmpty || _firmaId.isEmpty) return;
    setState(() => _okulKaydediliyor = true);
    try {
      // Geocoding ile koordinat al
      final adres = Uri.encodeComponent('${_okulAdresCtrl.text.trim()}, Turkey');
      final resp  = await http.get(Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?address=$adres&key=$_mapsKey'));
      final json  = jsonDecode(resp.body);
      double? lat, lng;
      if (json['status'] == 'OK') {
        final loc = json['results'][0]['geometry']['location'];
        lat = loc['lat']?.toDouble();
        lng = loc['lng']?.toDouble();
      }

      await FirebaseFirestore.instance.collection('firms').doc(_firmaId).update({
        'okulAdresi': _okulAdresCtrl.text.trim(),
        if (lat != null) 'okulLat': lat,
        if (lng != null) 'okulLng': lng,
      });

      setState(() => _kayitliOkulAdres = _okulAdresCtrl.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Okul adresi kaydedildi!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _okulKaydediliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white, elevation: 0,
        title: const Text('Fiyat Yonetimi', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: _turuncu, indicatorWeight: 3,
          labelColor: Colors.white, unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.location_city_outlined, size: 18), text: 'Mahalle'),
            Tab(icon: Icon(Icons.straighten_outlined,    size: 18), text: 'Km Bazli'),
          ],
        ),
      ),
      body: !_yuklendi
          ? const Center(child: CircularProgressIndicator(color: _navy))
          : Column(children: [
        // Okul adresi bandi
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(children: [
            const Icon(Icons.school_outlined, color: _navy, size: 18),
            const SizedBox(width: 8),
            Expanded(child: TextField(
              controller: _okulAdresCtrl,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                  hintText: 'Okul adresi (km hesabi icin)',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true, fillColor: const Color(0xFFF5F7FA)),
            )),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _okulKaydediliyor ? null : _okulAdresKaydet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: _navy, borderRadius: BorderRadius.circular(8)),
                child: _okulKaydediliyor
                    ? const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Kaydet', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
        if (_kayitliOkulAdres.isNotEmpty)
          Container(
            color: Colors.green.withValues(alpha: 0.05),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            child: Row(children: [
              const Icon(Icons.check_circle_outline, color: Colors.green, size: 13),
              const SizedBox(width: 6),
              Expanded(child: Text('Okul: $_kayitliOkulAdres',
                  style: const TextStyle(color: Colors.green, fontSize: 11),
                  overflow: TextOverflow.ellipsis)),
            ]),
          ),
        Expanded(child: TabBarView(controller: _tab, children: [
          _MahalleFiyatlari(firmaId: _firmaId),
          _KmFiyatlari(firmaId: _firmaId),
        ])),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  MAHALLE FİYATLARI
// ══════════════════════════════════════════════════════════════
class _MahalleFiyatlari extends StatefulWidget {
  final String firmaId;
  const _MahalleFiyatlari({required this.firmaId});
  @override
  State<_MahalleFiyatlari> createState() => _MahalleFiyatlariState();
}

class _MahalleFiyatlariState extends State<_MahalleFiyatlari> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  String _filtre = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _navy, foregroundColor: Colors.white,
        onPressed: () => _ekleDialog(context),
        icon: const Icon(Icons.add), label: const Text('Ekle'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('fiyatlar')
            .where('firmaId', isEqualTo: widget.firmaId)
            .where('tip', isEqualTo: 'mahalle')
            .snapshots(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator(color: _navy));
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return _Bos('Henuz mahalle fiyati yok',
              'Ornek: Sultanbeyli / Adil Mah / 3400 TL', Icons.location_city_outlined);

          final ilceler = docs.map((d) =>
          (d.data() as Map)['ilce'] as String? ?? '').toSet().toList()..sort();
          final filtered = _filtre.isEmpty ? docs
              : docs.where((d) => (d.data() as Map)['ilce'] == _filtre).toList();

          return Column(children: [
            // Ilce filtresi
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: SingleChildScrollView(scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _Chip('Tumu', '', _filtre, (v) => setState(() => _filtre = v)),
                    const SizedBox(width: 6),
                    ...ilceler.map((i) => Padding(padding: const EdgeInsets.only(right: 6),
                        child: _Chip(i, i, _filtre, (v) => setState(() => _filtre = v)))),
                  ])),
            ),
            // Baslik
            Container(
              margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(8)),
              child: const Row(children: [
                Expanded(flex: 3, child: Text('Ilce', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(flex: 4, child: Text('Mahalle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                SizedBox(width: 80, child: Text('Fiyat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                SizedBox(width: 28),
              ]),
            ),
            Expanded(child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 100),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final doc = filtered[i];
                final d   = doc.data() as Map<String, dynamic>;
                final bg  = i.isEven ? Colors.white : const Color(0xFFF8F9FA);
                return Container(
                  decoration: BoxDecoration(color: bg,
                      border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.12)))),
                  child: Row(children: [
                    Expanded(flex: 3, child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        child: Text(d['ilce'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)))),
                    Expanded(flex: 4, child: Text(d['mahalle'] ?? '',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]))),
                    SizedBox(width: 80, child: Text(
                        '${(d['fiyat'] as num? ?? 0).toStringAsFixed(0)} TL',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: _turuncu, fontSize: 12),
                        textAlign: TextAlign.right)),
                    IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 14, color: Colors.grey),
                        onPressed: () => _duzenleDialog(context, doc.id, d),
                        splashRadius: 14, padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
                  ]),
                );
              },
            )),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: Colors.white,
              child: Row(children: [
                Text('${filtered.length} kayit', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                const Spacer(),
                if (_filtre.isNotEmpty)
                  Text(_filtre, style: const TextStyle(color: _navy, fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
            ),
          ]);
        },
      ),
    );
  }

  void _ekleDialog(BuildContext ctx) {
    final iCtrl = TextEditingController();
    final mCtrl = TextEditingController();
    final fCtrl = TextEditingController();
    bool yuk = false;
    showDialog(context: ctx, builder: (_) => StatefulBuilder(
      builder: (c, ss) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Fiyat Ekle', style: TextStyle(color: _navy, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _F(iCtrl, 'Ilce *',    Icons.location_city_outlined),
          const SizedBox(height: 8),
          _F(mCtrl, 'Mahalle *', Icons.maps_home_work_outlined),
          const SizedBox(height: 8),
          _F(fCtrl, 'Ucret (TL) *', Icons.attach_money, tipi: TextInputType.number),
          const SizedBox(height: 6),
          Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
              child: const Text('Ornek:\nSultanbeyli / Adil Mah / 3400',
                  style: TextStyle(fontSize: 11, color: Colors.blue))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Iptal')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
              onPressed: yuk ? null : () async {
                if (iCtrl.text.trim().isEmpty || mCtrl.text.trim().isEmpty || fCtrl.text.trim().isEmpty) return;
                ss(() => yuk = true);
                try {
                  await FirebaseFirestore.instance.collection('fiyatlar').add({
                    'firmaId': widget.firmaId, 'tip': 'mahalle',
                    'ilce': iCtrl.text.trim(), 'mahalle': mCtrl.text.trim(),
                    'fiyat': double.tryParse(fCtrl.text.trim()) ?? 0.0,
                    'olusturma': FieldValue.serverTimestamp(),
                  });
                  if (c.mounted) Navigator.pop(c);
                } catch (e) {
                  ss(() => yuk = false);
                  if (c.mounted) ScaffoldMessenger.of(c).showSnackBar(
                      SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
                }
              },
              child: yuk ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Ekle')),
        ],
      ),
    ));
  }

  void _duzenleDialog(BuildContext ctx, String id, Map<String, dynamic> d) {
    final iCtrl = TextEditingController(text: d['ilce'] ?? '');
    final mCtrl = TextEditingController(text: d['mahalle'] ?? '');
    final fCtrl = TextEditingController(text: (d['fiyat'] ?? 0).toString());
    bool yuk = false;
    showDialog(context: ctx, builder: (_) => StatefulBuilder(
      builder: (c, ss) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Duzenle', style: TextStyle(color: _navy, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _F(iCtrl, 'Ilce',   Icons.location_city_outlined),
          const SizedBox(height: 8),
          _F(mCtrl, 'Mahalle', Icons.maps_home_work_outlined),
          const SizedBox(height: 8),
          _F(fCtrl, 'Ucret (TL)', Icons.attach_money, tipi: TextInputType.number),
        ]),
        actions: [
          TextButton(onPressed: () async {
            await FirebaseFirestore.instance.collection('fiyatlar').doc(id).delete();
            if (c.mounted) Navigator.pop(c);
          }, child: const Text('Sil', style: TextStyle(color: Colors.red))),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Iptal')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
              onPressed: yuk ? null : () async {
                ss(() => yuk = true);
                await FirebaseFirestore.instance.collection('fiyatlar').doc(id).update({
                  'ilce': iCtrl.text.trim(), 'mahalle': mCtrl.text.trim(),
                  'fiyat': double.tryParse(fCtrl.text.trim()) ?? 0.0,
                });
                if (c.mounted) Navigator.pop(c);
              },
              child: yuk ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Kaydet')),
        ],
      ),
    ));
  }
}

// ══════════════════════════════════════════════════════════════
//  KM FİYATLARI
// ══════════════════════════════════════════════════════════════
class _KmFiyatlari extends StatelessWidget {
  final String firmaId;
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  const _KmFiyatlari({required this.firmaId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _navy, foregroundColor: Colors.white,
        onPressed: () => _ekleDialog(context),
        icon: const Icon(Icons.add), label: const Text('Aralik Ekle'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('fiyatlar')
            .where('firmaId', isEqualTo: firmaId)
            .where('tip', isEqualTo: 'km')
            .snapshots(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator(color: _navy));
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return _Bos('Henuz km fiyati yok',
              'Ornek: 0-3 km / 2500 TL', Icons.straighten_outlined);
          return Column(children: [
            Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(8)),
              child: const Row(children: [
                Expanded(child: Text('Km Araligi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                SizedBox(width: 90, child: Text('Aylik Ucret', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                SizedBox(width: 28),
              ]),
            ),
            Expanded(child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 100),
              itemCount: docs.length,
              itemBuilder: (_, i) {
                final doc = docs[i];
                final d   = doc.data() as Map<String, dynamic>;
                final kmB = (d['kmBaslangic'] ?? 0).toStringAsFixed(0);
                final kmE = (d['kmBitis']     ?? 0).toStringAsFixed(0);
                final bg  = i.isEven ? Colors.white : const Color(0xFFF8F9FA);
                return Container(
                  decoration: BoxDecoration(color: bg,
                      border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.12)))),
                  child: Row(children: [
                    Expanded(child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        child: Text('$kmB – $kmE km', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)))),
                    SizedBox(width: 90, child: Text(
                        '${(d['fiyat'] as num? ?? 0).toStringAsFixed(0)} TL',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: _turuncu, fontSize: 13),
                        textAlign: TextAlign.right)),
                    IconButton(
                        icon: const Icon(Icons.delete_outline, size: 14, color: Colors.red),
                        onPressed: () => FirebaseFirestore.instance.collection('fiyatlar').doc(doc.id).delete(),
                        splashRadius: 14, padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
                  ]),
                );
              },
            )),
          ]);
        },
      ),
    );
  }

  void _ekleDialog(BuildContext ctx) {
    final bCtrl = TextEditingController();
    final eCtrl = TextEditingController();
    final fCtrl = TextEditingController();
    bool yuk = false;
    showDialog(context: ctx, builder: (_) => StatefulBuilder(
      builder: (c, ss) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Km Aralik Fiyati', style: TextStyle(color: _navy, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(child: _F(bCtrl, 'Min Km', Icons.arrow_right_alt, tipi: TextInputType.number)),
            const SizedBox(width: 8),
            Expanded(child: _F(eCtrl, 'Max Km', Icons.arrow_right_alt, tipi: TextInputType.number)),
          ]),
          const SizedBox(height: 8),
          _F(fCtrl, 'Aylik Ucret (TL)', Icons.attach_money, tipi: TextInputType.number),
          const SizedBox(height: 6),
          Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
              child: const Text('Okul adresine gore mesafe hesaplanir.\nVeli adres girince otomatik fiyat cikacak.',
                  style: TextStyle(fontSize: 11, color: Colors.blue))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Iptal')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
              onPressed: yuk ? null : () async {
                if (bCtrl.text.isEmpty || eCtrl.text.isEmpty || fCtrl.text.isEmpty) return;
                ss(() => yuk = true);
                try {
                  await FirebaseFirestore.instance.collection('fiyatlar').add({
                    'firmaId': firmaId, 'tip': 'km',
                    'kmBaslangic': double.tryParse(bCtrl.text.trim()) ?? 0.0,
                    'kmBitis':     double.tryParse(eCtrl.text.trim()) ?? 0.0,
                    'fiyat':       double.tryParse(fCtrl.text.trim()) ?? 0.0,
                    'olusturma': FieldValue.serverTimestamp(),
                  });
                  if (c.mounted) Navigator.pop(c);
                } catch (e) {
                  ss(() => yuk = false);
                  if (c.mounted) ScaffoldMessenger.of(c).showSnackBar(
                      SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
                }
              },
              child: yuk ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Ekle')),
        ],
      ),
    ));
  }
}

// ════════════════════════════════════════════════════════════════
//  FİYAT HESAPLAMA SERVİSİ — veli_basvuru_screen'den cagrilir
// ════════════════════════════════════════════════════════════════
class FiyatHesaplamaServisi {
  static const _mapsKey = 'AIzaSyBX-9HFavvc7PvH7MuM22Xd9ymJSeWDdSo';

  /// Veli adresine gore fiyat hesapla
  /// Once mahalle eslesimi dener, sonra km hesabi yapar
  static Future<FiyatSonucu> hesapla({
    required String firmaId,
    required String veliAdresi,
  }) async {
    // 1. Firma okul adresini al
    final firmaDoc = await FirebaseFirestore.instance.collection('firms').doc(firmaId).get();
    final okulAdresi = firmaDoc.data()?['okulAdresi'] as String? ?? '';
    final okulLat    = firmaDoc.data()?['okulLat']    as double?;
    final okulLng    = firmaDoc.data()?['okulLng']    as double?;

    // 2. Mahalle eslesimi dene
    final mahalleSnap = await FirebaseFirestore.instance
        .collection('fiyatlar')
        .where('firmaId', isEqualTo: firmaId)
        .where('tip', isEqualTo: 'mahalle')
        .get();

    if (mahalleSnap.docs.isNotEmpty) {
      final adresLower = veliAdresi.toLowerCase();
      // Ilce + mahalle tam eslesmesi
      for (final doc in mahalleSnap.docs) {
        final d      = doc.data();
        final ilce   = (d['ilce']    ?? '').toString().toLowerCase();
        final mahalle= (d['mahalle'] ?? '').toString().toLowerCase();
        if (ilce.isNotEmpty && mahalle.isNotEmpty &&
            adresLower.contains(ilce) && adresLower.contains(mahalle)) {
          return FiyatSonucu(
            ucret: (d['fiyat'] as num?)?.toDouble() ?? 0,
            aciklama: '${d['ilce']} / ${d['mahalle']}',
            tip: 'mahalle',
          );
        }
      }
      // Sadece mahalle eslesimi
      for (final doc in mahalleSnap.docs) {
        final d      = doc.data();
        final mahalle= (d['mahalle'] ?? '').toString().toLowerCase();
        if (mahalle.isNotEmpty && adresLower.contains(mahalle)) {
          return FiyatSonucu(
            ucret: (d['fiyat'] as num?)?.toDouble() ?? 0,
            aciklama: '${d['ilce'] ?? ''} ${d['mahalle']} bolgesi',
            tip: 'mahalle',
          );
        }
      }
    }

    // 3. Km bazli hesap
    if (okulAdresi.isNotEmpty) {
      final km = await _mesafeHesapla(veliAdresi, okulLat, okulLng, okulAdresi);
      if (km != null) {
        final kmSnap = await FirebaseFirestore.instance
            .collection('fiyatlar')
            .where('firmaId', isEqualTo: firmaId)
            .where('tip', isEqualTo: 'km')
            .orderBy('kmBaslangic')
            .get();
        for (final doc in kmSnap.docs) {
          final d  = doc.data();
          final b  = (d['kmBaslangic'] ?? 0).toDouble();
          final e  = (d['kmBitis']     ?? 0).toDouble();
          if (km >= b && km <= e) {
            return FiyatSonucu(
              ucret: (d['fiyat'] as num?)?.toDouble() ?? 0,
              aciklama: '${km.toStringAsFixed(1)} km uzaklik (${b.toStringAsFixed(0)}-${e.toStringAsFixed(0)} km araligi)',
              tip: 'km',
              mesafeKm: km,
            );
          }
        }
        // Araliga girmeyen - en yakin araligi bul
        if (kmSnap.docs.isNotEmpty) {
          final son = kmSnap.docs.last.data();
          return FiyatSonucu(
            ucret: (son['fiyat'] as num?)?.toDouble() ?? 0,
            aciklama: '${km.toStringAsFixed(1)} km uzaklik',
            tip: 'km',
            mesafeKm: km,
          );
        }
      }
    }

    return FiyatSonucu(ucret: null, aciklama: 'Fiyat bulunamadi', tip: 'yok');
  }

  static Future<double?> _mesafeHesapla(
      String veliAdres, double? okulLat, double? okulLng, String okulAdres) async {
    try {
      // Veli adresinin koordinatlarini al
      final veliEnc = Uri.encodeComponent('$veliAdres, Turkey');
      final geoResp = await http.get(Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?address=$veliEnc&key=$_mapsKey'));
      final geoJson = jsonDecode(geoResp.body);
      if (geoJson['status'] != 'OK') return null;
      final veliLoc = geoJson['results'][0]['geometry']['location'];
      final veliLat = veliLoc['lat'].toDouble();
      final veliLng = veliLoc['lng'].toDouble();

      // Okul koordinati yoksa adresinden al
      double? oLat = okulLat, oLng = okulLng;
      if (oLat == null || oLng == null) {
        final okulEnc = Uri.encodeComponent('$okulAdres, Turkey');
        final okulResp = await http.get(Uri.parse(
            'https://maps.googleapis.com/maps/api/geocode/json?address=$okulEnc&key=$_mapsKey'));
        final okulJson = jsonDecode(okulResp.body);
        if (okulJson['status'] == 'OK') {
          final loc = okulJson['results'][0]['geometry']['location'];
          oLat = loc['lat'].toDouble();
          oLng = loc['lng'].toDouble();
        }
      }
      if (oLat == null || oLng == null) return null;

      // Distance Matrix API
      final distResp = await http.get(Uri.parse(
          'https://maps.googleapis.com/maps/api/distancematrix/json'
              '?origins=$veliLat,$veliLng'
              '&destinations=$oLat,$oLng'
              '&units=metric'
              '&key=$_mapsKey'));
      final distJson = jsonDecode(distResp.body);
      if (distJson['status'] == 'OK') {
        final element = distJson['rows'][0]['elements'][0];
        if (element['status'] == 'OK') {
          final metres = element['distance']['value'] as int;
          return metres / 1000.0;
        }
      }
      return null;
    } catch (_) { return null; }
  }
}

class FiyatSonucu {
  final double? ucret;
  final String  aciklama;
  final String  tip; // 'mahalle', 'km', 'yok'
  final double? mesafeKm;
  const FiyatSonucu({required this.ucret, required this.aciklama, required this.tip, this.mesafeKm});
}

// ── Ortak ────────────────────────────────────────────────────────
Widget _Bos(String baslik, String alt, IconData ikon) =>
    Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(ikon, size: 64, color: Colors.grey[300]),
      const SizedBox(height: 12),
      Text(baslik, style: TextStyle(color: Colors.grey[500])),
      const SizedBox(height: 4),
      Text(alt, style: const TextStyle(color: Colors.grey, fontSize: 12)),
    ]));

Widget _F(TextEditingController ctrl, String label, IconData ikon,
    {TextInputType tipi = TextInputType.text}) =>
    TextField(controller: ctrl, keyboardType: tipi,
        decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(ikon, color: const Color(0xFF1a3a6b), size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true));

class _Chip extends StatelessWidget {
  final String etiket, deger, secili; final ValueChanged<String> onSec;
  const _Chip(this.etiket, this.deger, this.secili, this.onSec);
  @override
  Widget build(BuildContext context) {
    final aktif = secili == deger;
    return GestureDetector(onTap: () => onSec(deger),
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
                color: aktif ? const Color(0xFF1a3a6b) : const Color(0xFFF0F2F5),
                borderRadius: BorderRadius.circular(20)),
            child: Text(etiket, style: TextStyle(
                color: aktif ? Colors.white : Colors.grey[600],
                fontSize: 11, fontWeight: aktif ? FontWeight.bold : FontWeight.normal))));
  }
}
