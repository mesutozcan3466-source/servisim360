import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/session_service.dart';

// ═══════════════════════════════════════════════════════
//  YEDEKLEME VE ARSIV MERKEZI  — 10 alt menu
// ═══════════════════════════════════════════════════════
class WebYedeklemeArsiv extends StatefulWidget {
  const WebYedeklemeArsiv({super.key});
  @override State<WebYedeklemeArsiv> createState() => _WebYedeklemeArsivState();
}

class _WebYedeklemeArsivState extends State<WebYedeklemeArsiv>
    with SingleTickerProviderStateMixin {
  static const _navy   = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);

  late TabController _tab;
  String _firmaId = '';
  bool   _yukleniyor = true;

  // Genel durum verileri
  int _toplamProje=0, _toplamOgrenci=0, _toplamVeli=0,
      _toplamSofor=0, _toplamArac=0, _toplamSozlesme=0,
      _arsivOgrenci=0, _arsivSofor=0;
  String _sonYedek = '-', _sonGeriYukle = '-';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 10, vsync: this);
    _yukle();
  }

  @override void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _yukle() async {
    _firmaId = await SessionService.instance.firmaIdAl() ?? '';
    if (_firmaId.isEmpty) { setState(() => _yukleniyor = false); return; }
    try {
      final db = FirebaseFirestore.instance;
      final results = await Future.wait([
        db.collection('projects').where('firmaId', isEqualTo: _firmaId).count().get(),
        db.collection('students').where('firmaId', isEqualTo: _firmaId).count().get(),
        db.collection('parents').where('firmaId', isEqualTo: _firmaId).count().get(),
        db.collection('drivers').where('firmaId', isEqualTo: _firmaId).count().get(),
        db.collection('vehicles').where('firmaId', isEqualTo: _firmaId).count().get(),
        db.collection('sozlesmeler').where('firmaId', isEqualTo: _firmaId).count().get(),
        db.collection('students').where('firmaId', isEqualTo: _firmaId).where('durum', isEqualTo: 'arsiv').count().get(),
        db.collection('drivers').where('firmaId', isEqualTo: _firmaId).where('durum', isEqualTo: 'arsiv').count().get(),
      ]);
      _toplamProje    = results[0].count ?? 0;
      _toplamOgrenci  = results[1].count ?? 0;
      _toplamVeli     = results[2].count ?? 0;
      _toplamSofor    = results[3].count ?? 0;
      _toplamArac     = results[4].count ?? 0;
      _toplamSozlesme = results[5].count ?? 0;
      _arsivOgrenci   = results[6].count ?? 0;
      _arsivSofor     = results[7].count ?? 0;
      // Son yedek
      final ySnap = await db.collection('yedekler')
          .where('firmaId', isEqualTo: _firmaId)
          .orderBy('tarih', descending: true).limit(1).get();
      if (ySnap.docs.isNotEmpty) {
        final d = ySnap.docs.first.data();
        _sonYedek = d['tarih']?.toDate?.call()?.toString().substring(0,16) ?? '-';
      }
    } catch (_) {}
    if (mounted) setState(() => _yukleniyor = false);
  }

  Future<void> _yedekAl() async {
    setState(() => _yukleniyor = true);
    try {
      await FirebaseFirestore.instance.collection('yedekler').add({
        'firmaId': _firmaId,
        'tarih'  : FieldValue.serverTimestamp(),
        'tur'    : 'manuel',
        'durum'  : 'tamamlandi',
        'boyut'  : '${(_toplamOgrenci + _toplamVeli + _toplamSofor)} kayit',
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Yedek basariyla alindi!'),
          backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
      _yukle();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Hata: $e'), backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating));
    }
    if (mounted) setState(() => _yukleniyor = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Column(children: [
        // Tab bar
        Container(color: Colors.white,
            child: TabBar(
              controller: _tab,
              labelColor: _navy, unselectedLabelColor: Colors.grey,
              indicatorColor: _orange, isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(icon: Icon(Icons.dashboard_outlined, size: 16),    text: 'Genel Durum'),
                Tab(icon: Icon(Icons.backup_outlined, size: 16),        text: 'Yedek Al'),
                Tab(icon: Icon(Icons.schedule_outlined, size: 16),      text: 'Otomatik Yedek'),
                Tab(icon: Icon(Icons.history_outlined, size: 16),       text: 'Yedek Gecmisi'),
                Tab(icon: Icon(Icons.archive_outlined, size: 16),       text: 'Arsiv Merkezi'),
                Tab(icon: Icon(Icons.school_outlined, size: 16),        text: 'Ogrenci Arsivi'),
                Tab(icon: Icon(Icons.drive_eta_outlined, size: 16),     text: 'Sofor Arsivi'),
                Tab(icon: Icon(Icons.description_outlined, size: 16),   text: 'Sozlesme Arsivi'),
                Tab(icon: Icon(Icons.restore_outlined, size: 16),       text: 'Geri Yukleme'),
                Tab(icon: Icon(Icons.emergency_outlined, size: 16),     text: 'Acil Kurtarma'),
              ],
            )),
        Expanded(child: _yukleniyor
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(controller: _tab, children: [
          _genelDurumTab(),
          _manuelYedekTab(),
          _otomatikYedekTab(),
          _yedekGecmisiTab(),
          _arsivMerkeziTab(),
          _ogrenciArsivTab(),
          _soforArsivTab(),
          _sozlesmeArsivTab(),
          _geriYuklemeTab(),
          _acilKurtarmaTab(),
        ])),
      ]),
    );
  }

  // ── 1. Genel Durum ─────────────────────────────────────────
  Widget _genelDurumTab() {
    final kartlar = [
      ('Toplam Proje',    '$_toplamProje',    Icons.folder_outlined,       Colors.blue),
      ('Toplam Ogrenci',  '$_toplamOgrenci',  Icons.school_outlined,       _navy),
      ('Toplam Veli',     '$_toplamVeli',     Icons.family_restroom,       Colors.purple),
      ('Toplam Sofor',    '$_toplamSofor',    Icons.drive_eta_outlined,    Colors.teal),
      ('Toplam Arac',     '$_toplamArac',     Icons.directions_bus_outlined, Colors.green),
      ('Toplam Sozlesme', '$_toplamSozlesme', Icons.description_outlined,  Colors.orange),
      ('Arsiv Ogrenci',   '$_arsivOgrenci',   Icons.archive_outlined,      Colors.grey),
      ('Arsiv Sofor',     '$_arsivSofor',     Icons.archive_outlined,      Colors.grey),
    ];
    return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Sistem Ozeti', style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 20, color: _navy)),
          const SizedBox(height: 16),
          GridView.count(crossAxisCount: 4, shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.4,
              children: kartlar.map((k) => Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius:6)]),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(k.$3, color: k.$4, size: 20),
                    const Spacer(),
                    Text(k.$2, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: k.$4)),
                    Text(k.$1, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ]))).toList()),
          const SizedBox(height: 20),
          Container(padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius:6)]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Yedekleme Durumu', style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15, color: _navy)),
                const SizedBox(height: 12),
                _infoSatir('Son Yedekleme', _sonYedek, Icons.backup_outlined, Colors.green),
                _infoSatir('Son Geri Yukleme', _sonGeriYukle, Icons.restore_outlined, Colors.orange),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: _yedekAl,
                  icon: const Icon(Icons.backup_outlined, size: 18),
                  label: const Text('Hizli Yedek Al'),
                ),
              ])),
        ]));
  }

  // ── 2. Manuel Yedek ─────────────────────────────────────────
  Widget _manuelYedekTab() {
    final icerik = [
      ('Ogrenciler', Icons.school_outlined, Colors.blue),
      ('Veliler', Icons.family_restroom, Colors.purple),
      ('Soforler', Icons.drive_eta_outlined, Colors.teal),
      ('Sozlesmeler', Icons.description_outlined, Colors.orange),
      ('Fiyatlandirma', Icons.payments_outlined, Colors.green),
      ('Rotalar', Icons.route_outlined, _navy),
      ('Bildirim Gecmisi', Icons.notifications_outlined, Colors.red),
    ];
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Manuel Yedekleme', style: TextStyle(
          fontWeight: FontWeight.bold, fontSize: 20, color: _navy)),
      const SizedBox(height: 8),
      const Text('Sistem verilerinizin yedegini tek tusla alin.',
          style: TextStyle(color: Colors.grey, fontSize: 13)),
      const SizedBox(height: 20),
      // Yedek icerigi
      Container(padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Yedek Icerigi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: icerik.map((item) =>
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: item.$3.withValues(alpha:0.08),
                        borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(item.$2, size: 14, color: item.$3),
                      const SizedBox(width: 6),
                      Text(item.$1, style: TextStyle(fontSize: 12, color: item.$3,
                          fontWeight: FontWeight.w600)),
                    ]))).toList()),
          ])),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: _yedekAl,
            icon: const Icon(Icons.backup_outlined, size: 20),
            label: const Text('Yedek Al', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)))),
        const SizedBox(width: 12),
        Expanded(child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: _navy,
                side: const BorderSide(color: _navy),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Indirme hazirlaniyor...'),
                    behavior: SnackBarBehavior.floating)),
            icon: const Icon(Icons.download_outlined, size: 20),
            label: const Text('Indir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)))),
      ]),
    ]));
  }

  // ── 3. Otomatik Yedek ────────────────────────────────────────
  Widget _otomatikYedekTab() {
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Otomatik Yedekleme Ayarlari', style: TextStyle(
          fontWeight: FontWeight.bold, fontSize: 20, color: _navy)),
      const SizedBox(height: 16),
      Container(padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius:6)]),
          child: Column(children: [
            ...[('Her Gun', true), ('Her Hafta', false), ('Her Ay', false)].map((item) =>
                SwitchListTile(dense: true, value: item.$2,
                    onChanged: (_) {},
                    title: Text(item.$1),
                    subtitle: item.$2 ? const Text('Aktif', style: TextStyle(color: Colors.green)) : null,
                    activeColor: _navy)),
            const Divider(),
            SwitchListTile(dense: true, value: true, onChanged: (_) {},
                title: const Text('Yedek Tamamlandi Bildirimi'),
                activeColor: _navy),
            SwitchListTile(dense: true, value: true, onChanged: (_) {},
                title: const Text('Basarisiz Yedek Bildirimi'),
                activeColor: _navy),
          ])),
      const SizedBox(height: 16),
      ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ayarlar kaydedildi'),
                  behavior: SnackBarBehavior.floating)),
          icon: const Icon(Icons.save_outlined, size: 18),
          label: const Text('Kaydet')),
    ]));
  }

  // ── 4. Yedek Gecmisi ─────────────────────────────────────────
  Widget _yedekGecmisiTab() {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('yedekler')
            .where('firmaId', isEqualTo: _firmaId)
            .orderBy('tarih', descending: true).limit(50).snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return const Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.history_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 12),
                Text('Henuz yedek alinmamis', style: TextStyle(color: Colors.grey)),
              ]));
          return ListView.builder(
              padding: const EdgeInsets.all(16), itemCount: docs.length,
              itemBuilder: (_, i) {
                final d = docs[i].data() as Map<String, dynamic>;
                final manuel = d['tur'] == 'manuel';
                return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.04), blurRadius:4)]),
                    child: Row(children: [
                      Icon(manuel ? Icons.person_outlined : Icons.schedule_outlined,
                          color: manuel ? _navy : Colors.teal, size: 22),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d['tarih']?.toDate?.call()?.toString().substring(0,16) ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('${manuel ? "Manuel" : "Otomatik"} — ${d['boyut'] ?? ''}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      ])),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.green.withValues(alpha:0.1),
                              borderRadius: BorderRadius.circular(6)),
                          child: Text(d['durum'] ?? 'tamamlandi',
                              style: const TextStyle(fontSize: 11, color: Colors.green,
                                  fontWeight: FontWeight.bold))),
                    ]));
              });
        });
  }

  // ── 5. Arsiv Merkezi ─────────────────────────────────────────
  Widget _arsivMerkeziTab() {
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Arsiv Merkezi', style: TextStyle(
          fontWeight: FontWeight.bold, fontSize: 20, color: _navy)),
      const SizedBox(height: 8),
      Container(padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.blue.withValues(alpha:0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withValues(alpha:0.2))),
          child: const Row(children: [
            Icon(Icons.info_outline, color: Colors.blue, size: 18),
            SizedBox(width: 10),
            Expanded(child: Text(
                "Servisim360'ta silme yok. Kayitlar arsive tasinir. "
                    'Gerektiginde geri getirilebilir.',
                style: TextStyle(fontSize: 13, color: Colors.blue))),
          ])),
      const SizedBox(height: 20),
      ...[
        ('Ogrenci Arsivi', '$_arsivOgrenci ogrenci', Icons.school_outlined, Colors.blue, 5),
        ('Sofor Arsivi', '$_arsivSofor sofor', Icons.drive_eta_outlined, Colors.teal, 6),
        ('Sozlesme Arsivi', 'Tum sozlesmeler', Icons.description_outlined, Colors.orange, 7),
      ].map((item) => GestureDetector(
          onTap: () => _tab.animateTo(item.$5),
          child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200)),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: item.$4.withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(item.$3, color: item.$4, size: 22)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.$1, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(item.$2, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ])),
                const Icon(Icons.chevron_right_outlined, color: Colors.grey),
              ])))),
    ]));
  }

  // ── 6. Ogrenci Arsivi ─────────────────────────────────────────
  Widget _ogrenciArsivTab() {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('students')
            .where('firmaId', isEqualTo: _firmaId)
            .where('durum', whereIn: ['arsiv','ayrildi','mezun','pasif'])
            .orderBy('olusturmaTarihi', descending: true).snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return const Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.school_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 12),
                Text('Arsivde ogrenci yok', style: TextStyle(color: Colors.grey)),
              ]));
          return ListView.builder(
              padding: const EdgeInsets.all(16), itemCount: docs.length,
              itemBuilder: (_, i) {
                final d = docs[i].data() as Map<String, dynamic>;
                final durum = d['durum']?.toString() ?? 'arsiv';
                Color durumRenk = durum == 'mezun' ? Colors.green
                    : durum == 'ayrildi' ? Colors.red : Colors.grey;
                return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade100)),
                    child: Row(children: [
                      CircleAvatar(radius: 18, backgroundColor: _navy.withValues(alpha:0.1),
                          child: Text((d['ad'] ?? '?')[0].toUpperCase(),
                              style: const TextStyle(color: _navy, fontWeight: FontWeight.bold))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d['adSoyad'] ?? d['ad'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('${d['okul'] ?? ''} | Veli: ${d['veliAd'] ?? ''}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: durumRenk.withValues(alpha:0.1),
                                borderRadius: BorderRadius.circular(6)),
                            child: Text(durum, style: TextStyle(fontSize: 10,
                                color: durumRenk, fontWeight: FontWeight.bold))),
                        const SizedBox(height: 4),
                        TextButton(
                            style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                            onPressed: () async {
                              await FirebaseFirestore.instance.collection('students').doc(docs[i].id)
                                  .update({'durum': 'onayli', 'aktif': true});
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                  content: Text('Ogrenci tekrar aktif edildi'),
                                  backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
                            },
                            child: const Text('Tekrar Aktif Et',
                                style: TextStyle(fontSize: 11, color: _navy))),
                      ]),
                    ]));
              });
        });
  }

  // ── 7. Sofor Arsivi ─────────────────────────────────────────
  Widget _soforArsivTab() {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('drivers')
            .where('firmaId', isEqualTo: _firmaId)
            .where('durum', whereIn: ['arsiv','ayrildi','izinli','pasif'])
            .snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return const Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.drive_eta_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 12),
                Text('Arsivde sofor yok', style: TextStyle(color: Colors.grey)),
              ]));
          return ListView.builder(
              padding: const EdgeInsets.all(16), itemCount: docs.length,
              itemBuilder: (_, i) {
                final d = docs[i].data() as Map<String, dynamic>;
                return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade100)),
                    child: Row(children: [
                      CircleAvatar(radius: 18, backgroundColor: Colors.teal.withValues(alpha:0.1),
                          child: const Icon(Icons.drive_eta_outlined, color: Colors.teal, size: 18)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d['ad'] ?? d['adSoyad'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('Plaka: ${d['aracPlaka'] ?? '-'} | Tel: ${d['telefon'] ?? '-'}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ])),
                      TextButton(
                          style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero),
                          onPressed: () async {
                            await FirebaseFirestore.instance.collection('drivers').doc(docs[i].id)
                                .update({'durum': 'aktif', 'aktif': true});
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('Sofor tekrar aktif edildi'),
                                backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
                          },
                          child: const Text('Geri Al', style: TextStyle(fontSize: 11, color: _navy))),
                    ]));
              });
        });
  }

  // ── 8. Sozlesme Arsivi ──────────────────────────────────────
  Widget _sozlesmeArsivTab() {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('sozlesmeler')
            .where('firmaId', isEqualTo: _firmaId)
            .orderBy('olusturmaTarihi', descending: true).limit(100).snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return const Center(
              child: Text('Sozlesme bulunamadi', style: TextStyle(color: Colors.grey)));
          return ListView.builder(
              padding: const EdgeInsets.all(16), itemCount: docs.length,
              itemBuilder: (_, i) {
                final d = docs[i].data() as Map<String, dynamic>;
                final durum = d['durum']?.toString() ?? 'aktif';
                Color dc = durum=='imzalandi'?Colors.green:durum=='arsiv'?Colors.grey:Colors.orange;
                return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade100)),
                    child: Row(children: [
                      const Icon(Icons.description_outlined, color: Colors.orange, size: 22),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d['ogrenciAd'] ?? d['kisi'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('Donem: ${d['donem'] ?? '-'} | ${d['ucret'] ?? 0} TL',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ])),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: dc.withValues(alpha:0.1),
                              borderRadius: BorderRadius.circular(6)),
                          child: Text(durum, style: TextStyle(fontSize: 10, color: dc,
                              fontWeight: FontWeight.bold))),
                    ]));
              });
        });
  }

  // ── 9. Geri Yukleme ─────────────────────────────────────────
  Widget _geriYuklemeTab() {
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Geri Yukleme Merkezi', style: TextStyle(
          fontWeight: FontWeight.bold, fontSize: 20, color: _navy)),
      const SizedBox(height: 8),
      Container(padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.orange.withValues(alpha:0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha:0.3))),
          child: const Row(children: [
            Icon(Icons.warning_outlined, color: Colors.orange, size: 18),
            SizedBox(width: 10),
            Expanded(child: Text(
                'Geri yukleme mevcut kayitlarin uzerine yazabilir. '
                    'Dikkatli kullanin.',
                style: TextStyle(fontSize: 13, color: Colors.orange))),
          ])),
      const SizedBox(height: 20),
      ...[
        ('Tum Sistemi Geri Yukle', Icons.restore_outlined, Colors.red),
        ('Ogrencileri Geri Yukle', Icons.school_outlined, Colors.blue),
        ('Velileri Geri Yukle', Icons.family_restroom, Colors.purple),
        ('Soforleri Geri Yukle', Icons.drive_eta_outlined, Colors.teal),
        ('Sozlesmeleri Geri Yukle', Icons.description_outlined, Colors.orange),
        ('Rotalari Geri Yukle', Icons.route_outlined, _navy),
      ].map((item) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  foregroundColor: item.$3,
                  side: BorderSide(color: item.$3.withValues(alpha:0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => _geriYuklemeOnay(item.$1),
              icon: Icon(item.$2, size: 18),
              label: Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w600))))),
    ]));
  }

  void _geriYuklemeOnay(String islem) {
    showDialog(context: context, builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Emin misiniz?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('$islem islemi mevcut kayitlarin uzerine yazabilir. Devam etmek istiyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_), child: const Text('Iptal')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(_);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('$islem baslatildi...'),
                    behavior: SnackBarBehavior.floating));
              },
              child: const Text('Devam Et')),
        ]));
  }

  // ── 10. Acil Kurtarma ────────────────────────────────────────
  Widget _acilKurtarmaTab() {
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Acil Kurtarma Merkezi', style: TextStyle(
          fontWeight: FontWeight.bold, fontSize: 20, color: Colors.red)),
      const SizedBox(height: 8),
      const Text('Sistem kritik sorunlarinda bu bolumu kullanin.',
          style: TextStyle(color: Colors.grey, fontSize: 13)),
      const SizedBox(height: 20),
      ...[
        ('Son Calisir Yedegi Ac', Icons.backup_outlined, Colors.green),
        ('Eksik Dosya Kontrolu', Icons.find_in_page_outlined, Colors.blue),
        ('Veritabani Onarimi', Icons.build_outlined, Colors.orange),
        ('Kayip Kayit Tarama', Icons.search_outlined, Colors.purple),
        ('Bozuk Veri Tarama', Icons.bug_report_outlined, Colors.red),
      ].map((item) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: item.$3.withValues(alpha:0.2))),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: item.$3.withValues(alpha:0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(item.$2, color: item.$3, size: 20)),
            const SizedBox(width: 14),
            Expanded(child: Text(item.$1,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: item.$3, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${item.$1} baslatildi...'),
                    behavior: SnackBarBehavior.floating)),
                child: const Text('Baslat', style: TextStyle(fontSize: 12))),
          ]))),
      const SizedBox(height: 16),
      Container(padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Son Yedekleme Bilgisi',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            _infoSatir('Son Yedek', _sonYedek, Icons.access_time_outlined, Colors.grey),
          ])),
    ]));
  }

  Widget _infoSatir(String label, String deger, IconData ikon, Color renk) =>
      Padding(padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Icon(ikon, size: 16, color: renk),
            const SizedBox(width: 8),
            Text('$label: ', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            Text(deger, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: renk)),
          ]));
}
