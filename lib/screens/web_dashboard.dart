import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/session_service.dart';

// ════════════════════════════════════════════════════════════════
//  WEB DASHBOARD — Firma Admin Ana Sayfa
//  Özet kartlar + son devamsızlıklar + aktif servisler
// ════════════════════════════════════════════════════════════════
class WebDashboard extends StatefulWidget {
  const WebDashboard({super.key});
  @override
  State<WebDashboard> createState() => _WebDashboardState();
}

class _WebDashboardState extends State<WebDashboard> {
  static const _navy   = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);

  String _firmaId = '';
  String _projeId = '';
  int _ogrenciSayi = 0, _soforSayi = 0, _aktifServis = 0, _bekleyenBasvuru = 0;
  bool _yukleniyor = true;

  @override
  void initState() { super.initState(); _yukle(); }

  Future<void> _yukle() async {
    _firmaId = await SessionService.instance.firmaIdAl() ?? '';
    _projeId = SessionService.instance.aktifProjeId ?? '';
    if (_firmaId.isEmpty) { setState(() => _yukleniyor = false); return; }

    try {
      // Paralel sorgular
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('students')
            .where('firmaId', isEqualTo: _firmaId)
            .where('projeId', isEqualTo: _projeId).count().get(),
        FirebaseFirestore.instance.collection('drivers')
            .where('firmaId', isEqualTo: _firmaId).count().get(),
        FirebaseFirestore.instance.collection('drivers')
            .where('firmaId', isEqualTo: _firmaId)
            .where('servisAktif', isEqualTo: true).count().get(),
        FirebaseFirestore.instance.collection('parents')
            .where('firmaId', isEqualTo: _firmaId)
            .where('durum', isEqualTo: 'beklemede').count().get(),
      ]);

      if (mounted) setState(() {
        _ogrenciSayi     = results[0].count ?? 0;
        _soforSayi       = results[1].count ?? 0;
        _aktifServis     = results[2].count ?? 0;
        _bekleyenBasvuru = results[3].count ?? 0;
        _yukleniyor      = false;
      });
    } catch (_) { if (mounted) setState(() => _yukleniyor = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) return const Center(child: CircularProgressIndicator(color: _navy));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── ÖZET KARTLAR ──
        Row(children: [
          _OzetKart('Toplam Ogrenci', '$_ogrenciSayi',
              Icons.people_outline, Colors.blue, 'Aktif kayitli'),
          const SizedBox(width: 16),
          _OzetKart('Servisler', '$_soforSayi',
              Icons.directions_bus_outlined, _navy, 'Toplam sofor'),
          const SizedBox(width: 16),
          _OzetKart('Aktif Servis', '$_aktifServis',
              Icons.my_location_outlined, Colors.green, 'Simdi yolda'),
          const SizedBox(width: 16),
          _OzetKart('Bekleyen Basvuru', '$_bekleyenBasvuru',
              Icons.pending_outlined, _orange, 'Onay bekliyor',
              vurgu: _bekleyenBasvuru > 0),
        ]),

        const SizedBox(height: 24),

        // ── ALT SATIR ──
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Son devamsızlıklar
          Expanded(flex: 3, child: _SonDevamsizliklar(firmaId: _firmaId)),
          const SizedBox(width: 16),
          // Aktif servisler
          Expanded(flex: 2, child: _AktifServisler(firmaId: _firmaId)),
        ]),

        const SizedBox(height: 24),

        // ── HIZLI ERİŞİM ──
        const Text('Hizli Erisim',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _navy)),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, children: [
          _HizliBtn(Icons.person_add_outlined, 'Yuz Yuze Kayit', Colors.teal,
                  () => Navigator.pushNamed(context, '/yuz_yuze_kayit')),
          _HizliBtn(Icons.link_outlined, 'Kayit Linki Olustur', _navy,
                  () => Navigator.pushNamed(context, '/kayit_link')),
          _HizliBtn(Icons.add_road_outlined, 'Rota Olustur', _orange,
                  () => Navigator.pushNamed(context, '/gruplama')),
          _HizliBtn(Icons.upload_file_outlined, 'Excel Yukle', Colors.indigo,
                  () => Navigator.pushNamed(context, '/toplu_yukle')),
          _HizliBtn(Icons.chat_outlined, 'Toplu WhatsApp', const Color(0xFF25D366),
                  () => Navigator.pushNamed(context, '/toplu_whatsapp')),
          _HizliBtn(Icons.my_location_outlined, 'Canli Takip', Colors.green,
                  () => Navigator.pushNamed(context, '/admin_takip')),
          _HizliBtn(Icons.attach_money_outlined, 'Fiyat Yonetimi', Colors.purple,
                  () => Navigator.pushNamed(context, '/fiyat_yonetim')),
          _HizliBtn(Icons.bar_chart_outlined, 'Raporlar', Colors.deepOrange,
                  () => Navigator.pushNamed(context, '/analiz')),
        ]),
      ]),
    );
  }
}

// ── ÖZET KART ────────────────────────────────────────────────────
class _OzetKart extends StatelessWidget {
  final String baslik, deger, alt;
  final IconData ikon;
  final Color renk;
  final bool vurgu;
  const _OzetKart(this.baslik, this.deger, this.ikon, this.renk, this.alt,
      {this.vurgu = false});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: vurgu ? Border.all(color: renk.withValues(alpha: 0.5), width: 2) : null,
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
    ),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: renk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(ikon, color: renk, size: 26),
      ),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(deger, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: renk)),
        Text(baslik, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)),
        Text(alt, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ])),
    ]),
  ));
}

// ── SON DEVAMSIZLIKLAR ────────────────────────────────────────────
class _SonDevamsizliklar extends StatelessWidget {
  final String firmaId;
  const _SonDevamsizliklar({required this.firmaId});
  static const _navy = Color(0xFF1a3a6b);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.event_busy_outlined, color: _navy, size: 18),
        const SizedBox(width: 8),
        const Text('Son Devamsizliklar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _navy)),
        const Spacer(),
        TextButton(onPressed: () => Navigator.pushNamed(context, '/yoklama'),
            child: const Text('Tumunu Gor', style: TextStyle(color: _navy, fontSize: 12))),
      ]),
      const SizedBox(height: 12),
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('absence_requests')
            .where('firmaId', isEqualTo: firmaId)
            .orderBy('tarih', descending: true).limit(8).snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Devamsizlik bildirimi yok', style: TextStyle(color: Colors.grey[400])),
          ));
          return Column(children: docs.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final tarih = d['tarih'] as Timestamp?;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                CircleAvatar(radius: 16, backgroundColor: Colors.red.withValues(alpha: 0.1),
                    child: Text((d['ogrenciAd'] ?? '?')[0].toUpperCase(),
                        style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold))),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d['ogrenciAd'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(d['aciklama'] ?? d['tip'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ])),
                if (tarih != null)
                  Text(
                    '${tarih.toDate().day}.${tarih.toDate().month}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
              ]),
            );
          }).toList());
        },
      ),
    ]),
  );
}

// ── AKTİF SERVİSLER ──────────────────────────────────────────────
class _AktifServisler extends StatelessWidget {
  final String firmaId;
  const _AktifServisler({required this.firmaId});
  static const _navy = Color(0xFF1a3a6b);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.directions_bus_outlined, color: Colors.green, size: 18),
        const SizedBox(width: 8),
        const Text('Aktif Servisler', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _navy)),
      ]),
      const SizedBox(height: 12),
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('drivers')
            .where('firmaId', isEqualTo: firmaId)
            .where('servisAktif', isEqualTo: true).snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Icon(Icons.directions_bus_outlined, size: 40, color: Colors.grey),
              const SizedBox(height: 8),
              Text('Aktif servis yok', style: TextStyle(color: Colors.grey[400])),
            ]),
          ));
          return Column(children: docs.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final hiz = (d['hiz'] as num? ?? 0).toStringAsFixed(0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Container(width: 8, height: 8,
                    decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d['ad'] ?? 'Sofor', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(d['aracPlaka'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text('$hiz km/s', style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ]),
            );
          }).toList());
        },
      ),
    ]),
  );
}

// ── HIZLI BUTON ──────────────────────────────────────────────────
class _HizliBtn extends StatelessWidget {
  final IconData ikon; final String etiket; final Color renk; final VoidCallback onTap;
  const _HizliBtn(this.ikon, this.etiket, this.renk, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: renk.withValues(alpha: 0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: renk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(ikon, color: renk, size: 18)),
        const SizedBox(width: 10),
        Expanded(child: Text(etiket, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: renk))),
      ]),
    ),
  );
}
