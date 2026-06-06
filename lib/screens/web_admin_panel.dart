import 'package:flutter/material.dart';
import 'ai_widget.dart';
import 'yardim_widget.dart';
import 'arsiv_screen.dart';
import 'proje_arsiv_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/session_service.dart';
import 'responsive_wrapper.dart';
import 'web_soforler.dart';
import 'web_ayarlar.dart';
import 'sofor_sozlesme_screen.dart';
import 'araclar_screen.dart';
import 'plaka_tanima_screen.dart';
import 'sozlesme_yonetim_screen.dart';
import 'web_raporlar.dart';
import 'web_harita.dart';

class WebAdminPanel extends StatefulWidget {
  const WebAdminPanel({super.key});
  @override
  State<WebAdminPanel> createState() => _WebAdminPanelState();
}

class _WebAdminPanelState extends State<WebAdminPanel> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  int    _aktifSekme  = 0;
  String _firmaAdi    = '';
  String _kullaniciAd = '';
  String _firmaId     = '';
  String _projeId     = '';
  String _projeAd     = '';
  bool   _yukleniyor  = true;
  bool   _projeMenuAcik = false;

  // Istatistikler
  int _toplamSurucu  = 0;
  int _toplamOgrenci = 0;
  int _toplamVeli    = 0;
  int _aktifServis   = 0;
  int _bekleyenDevamsizlik = 0;

  List<Map<String, dynamic>> _projeler = [];

  static const List<_MenuItem> _menuler = [
    _MenuItem('Ana Ekran',   Icons.home_outlined,            0),
    _MenuItem('Harita',      Icons.map_outlined,             1),
    _MenuItem('Servisler',   Icons.directions_bus_outlined,  2),
    _MenuItem('Kayitlar',    Icons.people_outlined,          3),
    _MenuItem('Sozlesmeler', Icons.description_outlined,     4),
    _MenuItem('Raporlar',    Icons.bar_chart_outlined,       5),
    _MenuItem('Arsiv',       Icons.archive_outlined,          6),
    _MenuItem('Ayarlar',     Icons.settings_outlined,        7),
  ];

  @override
  void initState() { super.initState(); _yukle(); }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final fId = await SessionService.instance.firmaIdAl();
      _firmaId  = fId ?? '';

      final kulDoc = await FirebaseFirestore.instance
          .collection('kullanicilar').doc(user.uid).get();
      _kullaniciAd = kulDoc.data()?['ad'] ?? user.email ?? '';

      if (_firmaId.isNotEmpty) {
        final firmaDoc = await FirebaseFirestore.instance
            .collection('firms').doc(_firmaId).get();
        _firmaAdi = firmaDoc.data()?['firmaAdi'] ??
            firmaDoc.data()?['ad'] ?? '';

        // Projeleri cek
        final projSnap = await FirebaseFirestore.instance
            .collection('projects')
            .where('firmaId', isEqualTo: _firmaId)
            .where('aktif', isEqualTo: true)
            .orderBy('olusturmaTarihi', descending: true)
            .get();
        _projeler = projSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

        // Aktif projeyi session'dan al
        _projeId = SessionService.instance.aktifProjeld ?? '';
        _projeAd = SessionService.instance.aktifProjeAdi ?? '';

        await _istatistikYukle();
      }
    } catch (e) { debugPrint('Admin panel hata: $e'); }
    if (mounted) setState(() => _yukleniyor = false);
  }

  Future<void> _istatistikYukle() async {
    try {
      var sofQuery = FirebaseFirestore.instance
          .collection('drivers').where('firmaId', isEqualTo: _firmaId);
      var ogrQuery = FirebaseFirestore.instance
          .collection('students').where('firmaId', isEqualTo: _firmaId);
      var veliQuery = FirebaseFirestore.instance
          .collection('parents').where('firmaId', isEqualTo: _firmaId);
      var devQuery = FirebaseFirestore.instance
          .collection('absence_requests')
          .where('firmaId', isEqualTo: _firmaId)
          .where('durum', isEqualTo: 'bekliyor');

      if (_projeId.isNotEmpty) {
        ogrQuery = ogrQuery.where('projeId', isEqualTo: _projeId);
        sofQuery = sofQuery.where('projeId', isEqualTo: _projeId);
      }

      final results = await Future.wait([
        sofQuery.get(), ogrQuery.get(), veliQuery.get(), devQuery.get(),
      ]);

      final soforler = results[0].docs;
      final aktif = soforler.where((d) => (d.data() as Map)['servisAktif'] == true).length;

      if (mounted) setState(() {
        _toplamSurucu  = soforler.length;
        _toplamOgrenci = results[1].docs.length;
        _toplamVeli    = results[2].docs.length;
        _aktifServis   = aktif;
        _bekleyenDevamsizlik = results[3].docs.length;
      });
    } catch (_) {}
  }

  void _projeAyarla(String projeId, String projeAd) {
    SessionService.instance.aktifProjeAyarla(projeId, projeAd);
    setState(() {
      _projeId = projeId;
      _projeAd = projeAd;
      _projeMenuAcik = false;
    });
    _istatistikYukle();
  }

  void _projeTumFirma() {
    SessionService.instance.projeTemizle();
    setState(() {
      _projeId = '';
      _projeAd = '';
      _projeMenuAcik = false;
    });
    _istatistikYukle();
  }

  void _projeEkleDialog() {
    final adCtrl    = TextEditingController();
    final donemCtrl = TextEditingController(text: '2025-2026');
    String tip = 'okul';
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.folder_outlined, color: Color(0xFF1a3a6b)),
          SizedBox(width: 10),
          Text('Yeni Proje Olustur', style: TextStyle(color: Color(0xFF1a3a6b), fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        content: SizedBox(width: 360, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: adCtrl,
            decoration: InputDecoration(
              labelText: 'Proje Adi *',
              prefixIcon: const Icon(Icons.folder_outlined, color: Color(0xFF1a3a6b), size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: donemCtrl,
            decoration: InputDecoration(
              labelText: 'Donem',
              prefixIcon: const Icon(Icons.calendar_today_outlined, color: Color(0xFF1a3a6b), size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          const Align(alignment: Alignment.centerLeft,
              child: Text('Proje Tipi', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1a3a6b), fontSize: 13))),
          const SizedBox(height: 8),
          Row(children: [
            _TipBtn('okul',     'Okul',     Icons.school_outlined,          tip, (t) => setS(() => tip = t)),
            const SizedBox(width: 8),
            _TipBtn('kolej',    'Kolej',    Icons.account_balance_outlined,  tip, (t) => setS(() => tip = t)),
            const SizedBox(width: 8),
            _TipBtn('personel', 'Personel', Icons.badge_outlined,            tip, (t) => setS(() => tip = t)),
          ]),
        ])),
        actions: [
          AiAsistanButonu(ekranAdi: 'Ana Ekran'),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Iptal')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _turuncu, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              if (adCtrl.text.trim().isEmpty) return;
              final ref = await FirebaseFirestore.instance.collection('projects').add({
                'firmaId':         _firmaId,
                'projeAd':         adCtrl.text.trim(),
                'donem':           donemCtrl.text.trim(),
                'tip':             tip,
                'aktif':           true,
                'olusturmaTarihi': FieldValue.serverTimestamp(),
              });
              if (ctx.mounted) {
                Navigator.pop(ctx);
                // Yeni projeyi sec
                _projeler.add({'id': ref.id, 'projeAd': adCtrl.text.trim(), 'tip': tip});
                _projeAyarla(ref.id, adCtrl.text.trim());
              }
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Olustur', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return const Scaffold(backgroundColor: _navy,
          body: Center(child: CircularProgressIndicator(color: Color(0xFFFF8C00))));
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Row(children: [

        // ── SOL MENU ──
        Container(
          width: 220, color: _navy,
          child: Column(children: [
            // Logo + firma
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 36, height: 36,
                      decoration: BoxDecoration(color: _turuncu, borderRadius: BorderRadius.circular(8)),
                      child: const Center(child: Text('S',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)))),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Servisim360',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
                ]),
                const SizedBox(height: 6),
                Text(_firmaAdi, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              ]),
            ),

            // Proje secici
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _projeId.isNotEmpty
                    ? _turuncu.withValues(alpha: 0.6) : Colors.white24),
              ),
              child: Column(children: [
                GestureDetector(
                  onTap: () => setState(() => _projeMenuAcik = !_projeMenuAcik),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(children: [
                      Icon(Icons.folder_outlined,
                          color: _projeId.isNotEmpty ? _turuncu : Colors.white54, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        _projeAd.isNotEmpty ? _projeAd : 'Tum Firma',
                        style: TextStyle(
                            color: _projeAd.isNotEmpty ? _turuncu : Colors.white70,
                            fontSize: 12, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      )),
                      Icon(_projeMenuAcik ? Icons.expand_less : Icons.expand_more,
                          color: Colors.white54, size: 16),
                    ]),
                  ),
                ),
                if (_projeMenuAcik) ...[
                  const Divider(color: Colors.white12, height: 1),
                  // Tum firma secenegi
                  GestureDetector(
                    onTap: _projeTumFirma,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _projeId.isEmpty ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
                      ),
                      child: Row(children: [
                        Icon(Icons.business_outlined,
                            color: _projeId.isEmpty ? Colors.white : Colors.white54, size: 14),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Tum Firma',
                            style: TextStyle(
                                color: _projeId.isEmpty ? Colors.white : Colors.white60,
                                fontSize: 11,
                                fontWeight: _projeId.isEmpty ? FontWeight.bold : FontWeight.normal))),
                        if (_projeId.isEmpty)
                          const Icon(Icons.check, color: _turuncu, size: 12),
                      ]),
                    ),
                  ),
                  // Proje listesi
                  ..._projeler.map((prj) {
                    final secili = _projeId == prj['id'];
                    return GestureDetector(
                      onTap: () => _projeAyarla(prj['id'], prj['projeAd'] ?? ''),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: secili ? _turuncu.withValues(alpha: 0.15) : Colors.transparent,
                        ),
                        child: Row(children: [
                          Icon(Icons.folder_outlined,
                              color: secili ? _turuncu : Colors.white54, size: 14),
                          const SizedBox(width: 8),
                          Expanded(child: Text(prj['projeAd'] ?? '',
                              style: TextStyle(
                                  color: secili ? _turuncu : Colors.white60,
                                  fontSize: 11,
                                  fontWeight: secili ? FontWeight.bold : FontWeight.normal),
                              overflow: TextOverflow.ellipsis)),
                          if (secili) const Icon(Icons.check, color: _turuncu, size: 12),
                        ]),
                      ),
                    );
                  }),
                  // + Yeni Proje
                  const Divider(color: Colors.white12, height: 1),
                  GestureDetector(
                    onTap: () {
                      setState(() => _projeMenuAcik = false);
                      _projeEkleDialog();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                              color: _turuncu.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4)),
                          child: const Icon(Icons.add, color: _turuncu, size: 12),
                        ),
                        const SizedBox(width: 8),
                        const Text('Yeni Proje Olustur',
                            style: TextStyle(color: _turuncu, fontSize: 11, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 8),
            const Divider(color: Colors.white12),

            // Menu itemlari
            ..._menuler.map((item) {
              final secili = _aktifSekme == item.index;
              return GestureDetector(
                onTap: () => setState(() => _aktifSekme = item.index),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: secili ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: secili ? Border.all(color: _turuncu.withValues(alpha: 0.5)) : null,
                  ),
                  child: Row(children: [
                    Icon(item.ikon, color: secili ? _turuncu : Colors.white54, size: 18),
                    const SizedBox(width: 10),
                    Text(item.ad, style: TextStyle(
                        color: secili ? Colors.white : Colors.white60,
                        fontWeight: secili ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13)),
                    if (item.index == 99 && _bekleyenDevamsizlik > 0) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
                        child: Text('$_bekleyenDevamsizlik',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ]),
                ),
              );
            }),

            const Spacer(),

            // Alt kullanici + cikis
            Container(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                CircleAvatar(radius: 14, backgroundColor: _turuncu,
                    child: Text(_kullaniciAd.isNotEmpty ? _kullaniciAd[0].toUpperCase() : 'A',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                const SizedBox(width: 8),
                Expanded(child: Text(_kullaniciAd,
                    style: const TextStyle(color: Colors.white70, fontSize: 11), overflow: TextOverflow.ellipsis)),
                IconButton(
                  icon: const Icon(Icons.logout_outlined, color: Colors.white38, size: 16),
                  onPressed: () async {
                    await SessionService.instance.cikisYap();
                    if (mounted) Navigator.pushReplacementNamed(context, '/');
                  },
                ),
              ]),
            ),
          ]),
        ),

        // ── SAG ICERIK ──
        Expanded(child: Column(children: [

          // Ust bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            color: Colors.white,
            child: Row(children: [
              Text(_menuler[_aktifSekme].ad,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _navy)),
              if (_projeAd.isNotEmpty) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: _turuncu.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _turuncu.withValues(alpha: 0.3))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.folder_outlined, color: _turuncu, size: 12),
                    const SizedBox(width: 4),
                    Text(_projeAd, style: const TextStyle(color: _turuncu, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _projeTumFirma,
                      child: const Icon(Icons.close, color: _turuncu, size: 12),
                    ),
                  ]),
                ),
              ],
              const Spacer(),
              if (_aktifServis > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    Container(width: 8, height: 8,
                        decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('$_aktifServis Aktif Servis',
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                  ]),
                ),
            ]),
          ),

          Expanded(child: _sekmeIcerigi()),
        ])),
      ]),
    );
  }

  Widget _sekmeIcerigi() {
    switch (_aktifSekme) {
      case 0: return _WebAnaSayfa(
        firmaId: _firmaId, projeId: _projeId, projeAd: _projeAd,
        toplamSurucu: _toplamSurucu, toplamOgrenci: _toplamOgrenci,
        toplamVeli: _toplamVeli, aktifServis: _aktifServis,
        bekleyenDevamsizlik: _bekleyenDevamsizlik,
        onNavigate: (i) => setState(() => _aktifSekme = i),
      );
      case 1: return WebHarita(firmaId: _firmaId, projeId: _projeId);
      case 2: return _ServisYonetimSekme(firmaId: _firmaId, projeId: _projeId);
      case 3: return _KayitlarSekme(firmaId: _firmaId, projeId: _projeId);
      case 4: return const SozlesmeYonetimScreen();
      case 5: return const WebRaporlar();
      case 6: return const ProjeArsivScreen();
      case 7: return const WebAyarlar();
      default: return Center(child: Text(_menuler[_aktifSekme].ad,
          style: const TextStyle(fontSize: 20, color: Colors.grey)));
    }
  }
}

class _MenuItem {
  final String ad;
  final IconData ikon;
  final int index;
  const _MenuItem(this.ad, this.ikon, this.index);
}

// ════════════════════════════════════════════════════════════════
//  WEB ANA SAYFA
// ════════════════════════════════════════════════════════════════
class _WebAnaSayfa extends StatelessWidget {
  final String firmaId, projeId, projeAd;
  final int toplamSurucu, toplamOgrenci, toplamVeli, aktifServis, bekleyenDevamsizlik;
  final void Function(int) onNavigate;

  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  const _WebAnaSayfa({
    required this.firmaId, required this.projeId, required this.projeAd,
    required this.toplamSurucu, required this.toplamOgrenci,
    required this.toplamVeli, required this.aktifServis,
    required this.bekleyenDevamsizlik, required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Proje banner
        if (projeAd.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _turuncu.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _turuncu.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.folder_outlined, color: _turuncu, size: 16),
              const SizedBox(width: 8),
              Text('Filtre: $projeAd',
                  style: const TextStyle(color: _turuncu, fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              const Text('Sol menüden proje degistirin',
                  style: TextStyle(color: Colors.grey, fontSize: 11)),
            ]),
          ),

        // Aktif servis banner
        if (aktifServis > 0)
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Container(width: 12, height: 12,
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              Text('$aktifServis servis şu an aktif olarak devam ediyor',
                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              GestureDetector(
                onTap: () => onNavigate(1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8)),
                  child: const Text('Haritada Goster', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ]),
          ),

        // Stat kartlari
        Wrap(spacing: 14, runSpacing: 14, children: [
          _WebStatKart('Toplam Servis', '$toplamSurucu', Icons.directions_bus_rounded, _navy,
              alt: aktifServis > 0 ? '$aktifServis aktif' : null,
              onTap: () => onNavigate(2)),
          _WebStatKart('Toplam Kayit', '$toplamOgrenci', Icons.people_outlined, Colors.blue,
              onTap: () => onNavigate(3)),
          _WebStatKart('Toplam Veli', '$toplamVeli', Icons.family_restroom_outlined, Colors.purple,
              onTap: () => onNavigate(3)),
          _WebStatKart('Raporlar', '', Icons.bar_chart_outlined, Colors.green,
              alt: 'Analiz & Disa Aktar',
              onTap: () => onNavigate(5)),
        ]),

        const SizedBox(height: 28),

        // Alt kisim: harita + son devamsizliklar
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Harita
          Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.map_outlined, color: _navy, size: 16),
              const SizedBox(width: 8),
              const Text('Canli Konum Haritasi',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _navy)),
              const Spacer(),
              GestureDetector(
                onTap: () => onNavigate(1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(8)),
                  child: const Text('Tam Ekran', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Container(
              height: 380,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)],
              ),
              clipBehavior: Clip.antiAlias,
              child: WebHarita(firmaId: firmaId, projeId: projeId),
            ),
          ])),

          const SizedBox(width: 20),

          // Sag: son devamsizliklar + hizli erisim
          Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Hizli erisim
            const Text('Hizli Erisim',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _navy)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _WebHizliBtn(Icons.add_road_outlined, 'Rota Olustur', _turuncu, () {}),
              _WebHizliBtn(Icons.people_outline, 'Ogrenciler', Colors.blue, () => onNavigate(3)),
              _WebHizliBtn(Icons.directions_car_outlined, 'Soforler', _navy, () => onNavigate(2)),
              _WebHizliBtn(Icons.event_busy_outlined, 'Devamsizlik', Colors.red, () => onNavigate(5)),
              _WebHizliBtn(Icons.bar_chart_outlined, 'Raporlar', Colors.purple, () => onNavigate(6)),
              _WebHizliBtn(Icons.map_outlined, 'Harita', Colors.green, () => onNavigate(1)),
            ]),

            const SizedBox(height: 24),

            // Son devamsizliklar
            Row(children: [
              const Icon(Icons.event_busy_outlined, color: Colors.red, size: 16),
              const SizedBox(width: 8),
              const Text('Son Devamsizliklar',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _navy)),
              const Spacer(),
              GestureDetector(
                onTap: () => onNavigate(5),
                child: const Text('Tumunu Gor', style: TextStyle(color: _navy, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 12),
            _SonDevamsizliklar(firmaId: firmaId),
          ])),
        ]),
      ]),
    );
  }
}

class _WebStatKart extends StatelessWidget {
  final String baslik, deger;
  final IconData ikon;
  final Color renk;
  final String? alt;
  final VoidCallback? onTap;

  static const _navy = Color(0xFF1a3a6b);

  const _WebStatKart(this.baslik, this.deger, this.ikon, this.renk, {this.alt, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 180,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: renk.withValues(alpha: 0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: renk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(9)),
            child: Icon(ikon, color: renk, size: 20)),
        const SizedBox(height: 10),
        Text(deger, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: renk)),
        Text(baslik, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        if (alt != null)
          Text(alt!, style: TextStyle(fontSize: 11, color: renk, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

class _WebHizliBtn extends StatelessWidget {
  final IconData ikon; final String etiket; final Color renk; final VoidCallback onTap;
  const _WebHizliBtn(this.ikon, this.etiket, this.renk, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: renk.withValues(alpha: 0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ikon, color: renk, size: 14),
        const SizedBox(width: 6),
        Text(etiket, style: TextStyle(color: renk, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

class _SonDevamsizliklar extends StatelessWidget {
  final String firmaId;
  const _SonDevamsizliklar({required this.firmaId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('absence_requests')
          .where('firmaId', isEqualTo: firmaId)
          .orderBy('tarih', descending: true)
          .limit(5)
          .snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [
              Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
              SizedBox(width: 10),
              Text('Bekleyen devamsizlik bildirimi yok',
                  style: TextStyle(color: Colors.grey)),
            ]),
          );
        }
        return Column(children: docs.map((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final durum = d['durum'] as String? ?? 'bekliyor';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _durumRengi(durum).withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Icon(Icons.event_busy_outlined, color: _durumRengi(durum), size: 18),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d['ogrenciAd'] ?? 'Ogrenci', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(d['aciklama'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: _durumRengi(durum).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(durum, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _durumRengi(durum))),
              ),
            ]),
          );
        }).toList());
      },
    );
  }

  Color _durumRengi(String d) {
    switch (d) {
      case 'onaylandi':  return Colors.green;
      case 'reddedildi': return Colors.red;
      default:           return Colors.orange;
    }
  }
}

// ════════════════════════════════════════════════════════════════
//  OGRENCILER SEKMESI
// ════════════════════════════════════════════════════════════════
class _OgrencilerSekme extends StatefulWidget {
  final String firmaId, projeId;
  const _OgrencilerSekme({required this.firmaId, required this.projeId});
  @override
  State<_OgrencilerSekme> createState() => _OgrencilerSekmeState();
}

class _OgrencilerSekmeState extends State<_OgrencilerSekme> {
  static const _navy = Color(0xFF1a3a6b);
  String _aramaMetni = '';
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      padding: const EdgeInsets.all(16), color: Colors.white,
      child: TextField(
        controller: _ctrl,
        decoration: InputDecoration(
          hintText: 'Ogrenci ara...',
          prefixIcon: const Icon(Icons.search, color: _navy, size: 18),
          filled: true, fillColor: const Color(0xFFF5F7FA),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
        onChanged: (v) => setState(() => _aramaMetni = v.toLowerCase()),
      ),
    ),
    Expanded(child: StreamBuilder<QuerySnapshot>(
      stream: () {
        var q = FirebaseFirestore.instance.collection('students').where('firmaId', isEqualTo: widget.firmaId);
        if (widget.projeId.isNotEmpty) q = q.where('projeId', isEqualTo: widget.projeId);
        return q.snapshots();
      }(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        var docs = snap.data?.docs ?? [];
        if (_aramaMetni.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return (data['ad'] ?? '').toString().toLowerCase().contains(_aramaMetni);
          }).toList();
        }
        if (docs.isEmpty) return const Center(child: Text('Ogrenci bulunamadi', style: TextStyle(color: Colors.grey)));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final bindi = d['bindi'] == true;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]),
              child: Row(children: [
                CircleAvatar(radius: 20, backgroundColor: _navy.withValues(alpha: 0.1),
                    child: Text((d['ad'] ?? '?').isNotEmpty ? d['ad'][0].toUpperCase() : '?',
                        style: const TextStyle(color: _navy, fontWeight: FontWeight.bold))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d['ad'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(d['adres'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if ((d['sinif'] ?? '').isNotEmpty)
                    Text('Sinif: ${d['sinif']}', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: (bindi ? Colors.green : Colors.grey).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(bindi ? 'Bindi' : 'Bekliyor',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                          color: bindi ? Colors.green : Colors.grey)),
                ),
              ]),
            );
          },
        );
      },
    )),
  ]);
}

// ════════════════════════════════════════════════════════════════
//  VELILER SEKMESI
// ════════════════════════════════════════════════════════════════
class _VelilerSekme extends StatefulWidget {
  final String firmaId;
  const _VelilerSekme({required this.firmaId});
  @override
  State<_VelilerSekme> createState() => _VelilerSekmeState();
}

class _VelilerSekmeState extends State<_VelilerSekme> {
  static const _navy = Color(0xFF1a3a6b);
  String _aramaMetni = '';
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      padding: const EdgeInsets.all(16), color: Colors.white,
      child: TextField(
        controller: _ctrl,
        decoration: InputDecoration(
          hintText: 'Veli ara...',
          prefixIcon: const Icon(Icons.search, color: _navy, size: 18),
          filled: true, fillColor: const Color(0xFFF5F7FA),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
        onChanged: (v) => setState(() => _aramaMetni = v.toLowerCase()),
      ),
    ),
    Expanded(child: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('parents')
          .where('firmaId', isEqualTo: widget.firmaId).snapshots(),
      builder: (_, snap) {
        var docs = snap.data?.docs ?? [];
        if (_aramaMetni.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return (data['ad'] ?? data['email'] ?? '').toString().toLowerCase().contains(_aramaMetni);
          }).toList();
        }
        if (docs.isEmpty) return const Center(child: Text('Veli bulunamadi', style: TextStyle(color: Colors.grey)));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]),
              child: Row(children: [
                CircleAvatar(radius: 20, backgroundColor: Colors.purple.withValues(alpha: 0.1),
                    child: Text((d['ad'] ?? d['email'] ?? '?').isNotEmpty ? (d['ad'] ?? d['email'])[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d['ad'] ?? d['email'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(d['email'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  if (d['telefon'] != null)
                    Text(d['telefon'], style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: const Text('Veli', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple)),
                ),
              ]),
            );
          },
        );
      },
    )),
  ]);
}

// ════════════════════════════════════════════════════════════════
//  DEVAMSIZLIK SEKMESI
// ════════════════════════════════════════════════════════════════
class _DevamsizlikSekme extends StatefulWidget {
  final String firmaId;
  const _DevamsizlikSekme({required this.firmaId});
  @override
  State<_DevamsizlikSekme> createState() => _DevamsizlikSekmeState();
}

class _DevamsizlikSekmeState extends State<_DevamsizlikSekme> {
  static const _navy    = Color(0xFF1a3a6b);
  String _durumFiltre = 'Tumu';

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      padding: const EdgeInsets.all(16), color: Colors.white,
      child: Row(children: [
        const Text('Filtre:', style: TextStyle(fontWeight: FontWeight.bold, color: _navy)),
        const SizedBox(width: 12),
        ...['Tumu', 'bekliyor', 'onaylandi', 'reddedildi'].map((d) {
          final secili = _durumFiltre == d;
          return GestureDetector(
            onTap: () => setState(() => _durumFiltre = d),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: secili ? _navy : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(d, style: TextStyle(color: secili ? Colors.white : Colors.grey[700],
                  fontSize: 12, fontWeight: secili ? FontWeight.bold : FontWeight.normal)),
            ),
          );
        }),
      ]),
    ),
    Expanded(child: StreamBuilder<QuerySnapshot>(
      stream: _durumFiltre == 'Tumu'
          ? FirebaseFirestore.instance.collection('absence_requests')
          .where('firmaId', isEqualTo: widget.firmaId).orderBy('tarih', descending: true).snapshots()
          : FirebaseFirestore.instance.collection('absence_requests')
          .where('firmaId', isEqualTo: widget.firmaId)
          .where('durum', isEqualTo: _durumFiltre).orderBy('tarih', descending: true).snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const Center(child: Text('Devamsizlik bildirimi yok', style: TextStyle(color: Colors.grey)));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final durum = d['durum'] as String? ?? 'bekliyor';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _durumRengi(durum).withValues(alpha: 0.2))),
              child: Row(children: [
                Icon(Icons.event_busy_outlined, color: _durumRengi(durum), size: 22),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d['ogrenciAd'] ?? 'Ogrenci', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(d['aciklama'] ?? d['not'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  Text(d['tarih']?.toString().substring(0, 10) ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                ])),
                if (durum == 'bekliyor') Row(children: [
                  _AksBtn('Onayla', Colors.green, () async {
                    await FirebaseFirestore.instance.collection('absence_requests').doc(docs[i].id).update({'durum': 'onaylandi'});
                  }),
                  const SizedBox(width: 6),
                  _AksBtn('Reddet', Colors.red, () async {
                    await FirebaseFirestore.instance.collection('absence_requests').doc(docs[i].id).update({'durum': 'reddedildi'});
                  }),
                ]) else Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: _durumRengi(durum).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(durum, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _durumRengi(durum))),
                ),
              ]),
            );
          },
        );
      },
    )),
  ]);

  Color _durumRengi(String durum) {
    switch (durum) {
      case 'onaylandi':  return Colors.green;
      case 'reddedildi': return Colors.red;
      default:           return Colors.orange;
    }
  }
}

class _AksBtn extends StatelessWidget {
  final String label; final Color renk; final VoidCallback onTap;
  const _AksBtn(this.label, this.renk, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: renk.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: renk.withValues(alpha: 0.3))),
      child: Text(label, style: TextStyle(fontSize: 11, color: renk, fontWeight: FontWeight.bold)),
    ),
  );
}

// Proje tipi secim butonu (web dialog icin)
class _TipBtn extends StatelessWidget {
  final String deger, etiket, secili;
  final IconData ikon;
  final ValueChanged<String> onSec;
  const _TipBtn(this.deger, this.etiket, this.ikon, this.secili, this.onSec);

  @override
  Widget build(BuildContext context) {
    final aktif = secili == deger;
    const navy = Color(0xFF1a3a6b);
    return Expanded(child: GestureDetector(
      onTap: () => onSec(deger),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: aktif ? navy : Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: aktif ? navy : Colors.grey.shade300),
        ),
        child: Column(children: [
          Icon(ikon, color: aktif ? Colors.white : Colors.grey, size: 18),
          const SizedBox(height: 4),
          Text(etiket, style: TextStyle(
              fontSize: 11,
              color: aktif ? Colors.white : Colors.grey,
              fontWeight: aktif ? FontWeight.bold : FontWeight.normal)),
        ]),
      ),
    ));
  }
}


// ════════════════════════════════════════════════════════════════
// SERVİS YÖNETİM SEKMESİ
// 1 Servis = 1 Şoför = 1 Araç
// Servis Ekle → şoför + araç + hesap otomatik oluşur
// ════════════════════════════════════════════════════════════════
class _ServisYonetimSekme extends StatefulWidget {
  final String firmaId, projeId;
  const _ServisYonetimSekme({required this.firmaId, required this.projeId});
  @override
  State<_ServisYonetimSekme> createState() => _ServisYonetimSekmeState();
}

class _ServisYonetimSekmeState extends State<_ServisYonetimSekme>
    with SingleTickerProviderStateMixin {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  late TabController _tab;
  List<Map<String, dynamic>> _servisler = [];
  bool _yukleniyor = true;
  String _arama = '';
  final _aramaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _yukle();
  }

  @override
  void dispose() { _tab.dispose(); _aramaCtrl.dispose(); super.dispose(); }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      var q = FirebaseFirestore.instance
          .collection('drivers')
          .where('firmaId', isEqualTo: widget.firmaId);
      final snap = await q.get();
      _servisler = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) { debugPrint('ServisYonetim hata: $e'); }
    if (mounted) setState(() => _yukleniyor = false);
  }

  String _rastgeleKod() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final now = DateTime.now();
    final buf = StringBuffer();
    for (var i = 0; i < 6; i++) buf.write(chars[(now.microsecond + i * 7) % chars.length]);
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Üst bar
      Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(child: TextField(
            controller: _aramaCtrl,
            onChanged: (v) => setState(() => _arama = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Servis adı, plaka veya şoför ara...',
              prefixIcon: const Icon(Icons.search, color: _navy, size: 18),
              filled: true, fillColor: const Color(0xFFF5F7FA),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
              isDense: true,
            ),
          )),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _turuncu, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => _servisEkleDialog(),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Servis Ekle',
                style: TextStyle(fontWeight: FontWeight.bold))),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.refresh_rounded, color: _navy),
              onPressed: _yukle),
        ]),
      ),

      // Sayaç
      Container(
        color: const Color(0xFFF5F7FA),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(children: [
          Text('${_servisler.length} servis',
              style: const TextStyle(color: _navy, fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.circle, color: Colors.green, size: 8),
              const SizedBox(width: 4),
              Text(
                '${_servisler.where((s) => s['servisAktif'] == true).length} aktif',
                style: const TextStyle(color: Colors.green, fontSize: 11,
                    fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ),

      // Servis listesi
      Expanded(child: _yukleniyor
          ? const Center(child: CircularProgressIndicator(color: _navy))
          : _buildListe()),
    ]);
  }

  Widget _buildListe() {
    final filtrelenmis = _servisler.where((s) {
      if (_arama.isEmpty) return true;
      final ad    = (s['adSoyad'] ?? s['ad'] ?? '').toLowerCase();
      final plaka = (s['plaka'] ?? s['aracPlaka'] ?? '').toLowerCase();
      final kadi  = (s['kullaniciAdi'] ?? '').toLowerCase();
      return ad.contains(_arama) || plaka.contains(_arama) || kadi.contains(_arama);
    }).toList();

    if (filtrelenmis.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.directions_bus_outlined, size: 72, color: Colors.grey[300]),
        const SizedBox(height: 12),
        const Text('Henüz servis eklenmedi',
            style: TextStyle(fontSize: 16, color: Colors.grey)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: _turuncu,
              foregroundColor: Colors.white),
          onPressed: _servisEkleDialog,
          icon: const Icon(Icons.add_rounded),
          label: const Text('İlk Servisi Ekle')),
      ]));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 360, mainAxisExtent: 230,
          crossAxisSpacing: 12, mainAxisSpacing: 12),
      itemCount: filtrelenmis.length,
      itemBuilder: (_, i) => _ServisKarti(
        sofor: filtrelenmis[i],
        firmaId: widget.firmaId,
        onYukle: _yukle,
        onDuzenle: () => _servisDuzenleDialog(filtrelenmis[i]),
      ),
    );
  }

  // ── Servis Ekle Dialog ────────────────────────────────────────
  void _servisEkleDialog() {
    final adCtrl       = TextEditingController();
    final telCtrl      = TextEditingController();
    final plakaCtrl    = TextEditingController();
    final kapasiteCtrl = TextEditingController();
    final modelCtrl    = TextEditingController();
    final kulAdiCtrl   = TextEditingController();
    final sifreCtrl    = TextEditingController(text: _rastgeleKod());
    final tcCtrl       = TextEditingController();
    final ehliyetCtrl  = TextEditingController();
    final srcCtrl      = TextEditingController();
    final psikoCtrl    = TextEditingController();
    bool yukleniyor    = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 580,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: Colors.white),
            child: Column(children: [
              // Başlık
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                    color: _navy,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                child: Row(children: [
                  const Icon(Icons.directions_bus_filled_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Servis Ekle', style: TextStyle(color: Colors.white,
                        fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Şoför + Araç + Hesap otomatik oluşturulur',
                        style: TextStyle(color: Colors.white60, fontSize: 12)),
                  ])),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx)),
                ]),
              ),

              Expanded(child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // Servis Bilgileri
                  _bolum('1. Servis Bilgileri', Icons.directions_bus_outlined),
                  const SizedBox(height: 8),
                  _inp(adCtrl, 'Servis Adı / Şoför Adı Soyadı *', Icons.person_outlined),
                  const SizedBox(height: 8),
                  _inp(telCtrl, 'Telefon *', Icons.phone_outlined, tip: TextInputType.phone),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _inp(plakaCtrl, 'Araç Plakası *', Icons.badge_outlined)),
                    const SizedBox(width: 8),
                    Expanded(child: _inp(kapasiteCtrl, 'Kapasite *', Icons.people_outlined,
                        tip: TextInputType.number)),
                  ]),
                  const SizedBox(height: 8),
                  _inp(modelCtrl, 'Araç Modeli', Icons.directions_car_outlined),
                  const SizedBox(height: 20),

                  // Belgeler
                  _bolum('2. Belgeler (İsteğe Bağlı)', Icons.badge_outlined),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _inp(tcCtrl, 'TC Kimlik', Icons.credit_card_outlined,
                        tip: TextInputType.number)),
                    const SizedBox(width: 8),
                    Expanded(child: _inp(ehliyetCtrl, 'Ehliyet Sınıfı', Icons.drive_eta_outlined)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _inp(srcCtrl, 'SRC Belgesi', Icons.article_outlined)),
                    const SizedBox(width: 8),
                    Expanded(child: _inp(psikoCtrl, 'Psikoteknik Tarihi', Icons.calendar_today_outlined)),
                  ]),
                  const SizedBox(height: 20),

                  // Giriş Bilgileri
                  _bolum('3. Giriş Bilgileri', Icons.lock_outlined),
                  const SizedBox(height: 4),
                  const Text('Şoför bu bilgilerle uygulamaya giriş yapar',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 8),
                  _inp(kulAdiCtrl, 'Kullanıcı Adı *', Icons.account_circle_outlined),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _inp(sifreCtrl, 'Geçici Şifre *', Icons.key_outlined)),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: _navy),
                      onPressed: () => setSt(() => sifreCtrl.text = _rastgeleKod())),
                  ]),

                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade200)),
                    child: const Row(children: [
                      Icon(Icons.auto_awesome, color: Colors.blue, size: 14),
                      SizedBox(width: 8),
                      Expanded(child: Text(
                        'Kaydet butonuna basınca: Servis kaydı + Şoför kaydı + Araç kaydı + Giriş hesabı otomatik oluşturulur.',
                        style: TextStyle(fontSize: 11, color: Colors.blue),
                      )),
                    ]),
                  ),
                ]),
              )),

              // Butonlar
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('İptal'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _navy, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: yukleniyor ? null : () async {
                      if (adCtrl.text.trim().isEmpty || telCtrl.text.trim().isEmpty ||
                          plakaCtrl.text.trim().isEmpty || kapasiteCtrl.text.trim().isEmpty ||
                          kulAdiCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                            content: Text('Zorunlu alanları doldurun!'),
                            behavior: SnackBarBehavior.floating));
                        return;
                      }
                      setSt(() => yukleniyor = true);
                      try {
                        final now = FieldValue.serverTimestamp();
                        // 1. Şoför kaydı (drivers)
                        final driverRef = await FirebaseFirestore.instance
                            .collection('drivers').add({
                          'adSoyad'       : adCtrl.text.trim(),
                          'ad'            : adCtrl.text.trim(),
                          'telefon'       : telCtrl.text.trim(),
                          'plaka'         : plakaCtrl.text.trim(),
                          'aracPlaka'     : plakaCtrl.text.trim(),
                          'aracKapasitesi': kapasiteCtrl.text.trim(),
                          'aracModeli'    : modelCtrl.text.trim(),
                          'kullaniciAdi'  : kulAdiCtrl.text.trim(),
                          'geciciSifre'   : sifreCtrl.text.trim(),
                          'tcKimlik'      : tcCtrl.text.trim(),
                          'ehliyetSinifi' : ehliyetCtrl.text.trim(),
                          'srcBelgesi'    : srcCtrl.text.trim(),
                          'psikoTarih'    : psikoCtrl.text.trim(),
                          'firmaId'       : widget.firmaId,
                          'aktif'         : true,
                          'servisAktif'   : false,
                          'soforDurum'    : 'bosta',
                          'rol'           : 'sofor',
                          'projeler'      : [],
                          'sonGiris'      : null,
                          'olusturma'     : now,
                          'updatedAt'     : now,
                        });

                        // 2. Araç kaydı (vehicles)
                        await FirebaseFirestore.instance.collection('vehicles').add({
                          'plaka'     : plakaCtrl.text.trim(),
                          'model'     : modelCtrl.text.trim(),
                          'aracModeli': modelCtrl.text.trim(),
                          'kapasite'  : int.tryParse(kapasiteCtrl.text.trim()) ?? 0,
                          'firmaId'   : widget.firmaId,
                          'surucuId'  : driverRef.id,
                          'surucuAd'  : adCtrl.text.trim(),
                          'durum'     : 'musait',
                          'aktif'     : true,
                          'olusturma' : now,
                        });

                        // 3. Kullanıcı hesabı
                        await FirebaseFirestore.instance
                            .collection('kullanicilar').doc(driverRef.id).set({
                          'ad'          : adCtrl.text.trim(),
                          'telefon'     : telCtrl.text.trim(),
                          'kullaniciAdi': kulAdiCtrl.text.trim(),
                          'sifre'       : sifreCtrl.text.trim(),
                          'rol'         : 'sofor',
                          'firmaId'     : widget.firmaId,
                          'driverId'    : driverRef.id,
                          'aktif'       : true,
                          'ilkGiris'    : true,
                          'olusturma'   : now,
                        });

                        if (ctx.mounted) Navigator.pop(ctx);
                        await _yukle();

                        // Giriş bilgisi dialog
                        if (context.mounted) {
                          _girisGonderDialog(
                            adCtrl.text.trim(), telCtrl.text.trim(),
                            kulAdiCtrl.text.trim(), sifreCtrl.text.trim(),
                          );
                        }
                      } catch (e) {
                        setSt(() => yukleniyor = false);
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text('Hata: $e'), backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating));
                      }
                    },
                    icon: yukleniyor
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save_rounded),
                    label: Text(yukleniyor ? 'Kaydediliyor...' : 'Servisi Kaydet',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  )),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _servisDuzenleDialog(Map<String, dynamic> s) {
    final adCtrl    = TextEditingController(text: s['adSoyad'] ?? s['ad'] ?? '');
    final telCtrl   = TextEditingController(text: s['telefon'] ?? '');
    final plakaCtrl = TextEditingController(text: s['plaka'] ?? s['aracPlaka'] ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${s['adSoyad'] ?? ''} — Düzenle'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _inp(adCtrl, 'Ad Soyad', Icons.person_outlined),
          const SizedBox(height: 8),
          _inp(telCtrl, 'Telefon', Icons.phone_outlined),
          const SizedBox(height: 8),
          _inp(plakaCtrl, 'Plaka', Icons.badge_outlined),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('drivers').doc(s['id']).update({
                'adSoyad': adCtrl.text.trim(), 'ad': adCtrl.text.trim(),
                'telefon': telCtrl.text.trim(),
                'plaka': plakaCtrl.text.trim(), 'aracPlaka': plakaCtrl.text.trim(),
                'updatedAt': FieldValue.serverTimestamp(),
              });
              if (_.mounted) Navigator.pop(_);
              await _yukle();
            },
            child: const Text('Kaydet')),
        ],
      ),
    );
  }

  void _girisGonderDialog(String ad, String tel, String kulAdi, String sifre) {
    final mesaj = 'Servisim360 Giriş Bilgileri\n👤 $kulAdi\n🔑 $sifre';
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text('$ad — Giriş Bilgileri'),
      content: Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10)),
          child: Text(mesaj, style: const TextStyle(fontSize: 13))),
      actions: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white),
          onPressed: () async {
            Navigator.pop(_);
            final temiz = tel.replaceAll(RegExp(r'[^0-9]'), '');
            final url = Uri.parse('https://wa.me/90$temiz?text=${Uri.encodeComponent(mesaj)}');
            if (await canLaunchUrl(url)) launchUrl(url, mode: LaunchMode.externalApplication);
          },
          icon: const Icon(Icons.send_rounded, size: 16),
          label: const Text('WhatsApp')),
        TextButton(onPressed: () => Navigator.pop(_), child: const Text('Kapat')),
      ],
    ));
  }

  Widget _bolum(String text, IconData icon) => Row(children: [
    Icon(icon, color: _navy, size: 16),
    const SizedBox(width: 8),
    Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _navy)),
  ]);

  Widget _inp(TextEditingController c, String label, IconData icon,
      {TextInputType? tip}) =>
      TextField(controller: c, keyboardType: tip, decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 16, color: _navy),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ));
}

// ── Servis Kartı ──────────────────────────────────────────────────
class _ServisKarti extends StatelessWidget {
  final Map<String, dynamic> sofor;
  final VoidCallback onYukle, onDuzenle;
  final String firmaId;
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  const _ServisKarti({
    required this.sofor, required this.onYukle,
    required this.onDuzenle, required this.firmaId});

  void _projeAtaDialog(BuildContext context) async {
    // Firmanın projelerini yükle
    final snap = await FirebaseFirestore.instance
        .collection('projects')
        .where('firmaId', isEqualTo: firmaId)
        .where('aktif', isEqualTo: true)
        .get();
    final projeler = snap.docs
        .map((d) => {'id': d.id, ...d.data()}).toList();

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.link_rounded, color: Color(0xFF1a3a6b), size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(
            '${sofor['adSoyad'] ?? 'Servis'} — Proje Ata',
            style: const TextStyle(fontSize: 15))),
        ]),
        content: SizedBox(
          width: 350,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Mevcut proje bilgisi
            if ((sofor['projeId'] ?? '').isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.folder_outlined, color: Colors.blue, size: 14),
                  const SizedBox(width: 6),
                  Text('Mevcut: ${sofor['projeAdi'] ?? ''}',
                      style: const TextStyle(fontSize: 12, color: Colors.blue,
                          fontWeight: FontWeight.w600)),
                ]),
              ),

            if (projeler.isEmpty)
              const Text('Henüz aktif proje yok',
                  style: TextStyle(color: Colors.grey))
            else
              ...projeler.map((p) {
                final secili = p['id'] == sofor['projeId'];
                return GestureDetector(
                  onTap: () async {
                    await FirebaseFirestore.instance
                        .collection('drivers').doc(sofor['id']).update({
                      'projeId'   : p['id'],
                      'projeAdi'  : p['projeAd'] ?? p['ad'] ?? '',
                      'soforDurum': 'projeyeDahil',
                      'updatedAt' : FieldValue.serverTimestamp(),
                    });
                    if (_.mounted) Navigator.pop(_);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                          '${sofor['adSoyad']} → ${p['projeAd'] ?? p['ad']} projesine atandı'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating));
                    onYukle();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: secili ? _navy : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: secili ? _navy : Colors.grey.shade200)),
                    child: Row(children: [
                      Icon(Icons.folder_outlined,
                          color: secili ? Colors.white : _navy, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(p['projeAd'] ?? p['ad'] ?? '',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: secili ? Colors.white : Colors.black87)),
                        if ((p['donem'] ?? '').isNotEmpty)
                          Text(p['donem'],
                              style: TextStyle(
                                  fontSize: 11,
                                  color: secili ? Colors.white70 : Colors.grey)),
                      ])),
                      if (secili)
                        const Icon(Icons.check_circle_rounded,
                            color: Colors.white, size: 16),
                    ]),
                  ),
                );
              }),

            // Projeden çıkar
            if ((sofor['projeId'] ?? '').isNotEmpty) ...[
              const Divider(),
              TextButton.icon(
                onPressed: () async {
                  await FirebaseFirestore.instance
                      .collection('drivers').doc(sofor['id']).update({
                    'projeId'   : '',
                    'projeAdi'  : '',
                    'soforDurum': 'bosta',
                    'updatedAt' : FieldValue.serverTimestamp(),
                  });
                  if (_.mounted) Navigator.pop(_);
                  onYukle();
                },
                icon: const Icon(Icons.link_off_rounded, color: Colors.red, size: 16),
                label: const Text('Projeden Çıkar',
                    style: TextStyle(color: Colors.red))),
            ],
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_), child: const Text('Kapat')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ad     = sofor['adSoyad'] ?? sofor['ad'] ?? 'Servis';
    final plaka  = sofor['plaka'] ?? sofor['aracPlaka'] ?? '-';
    final tel    = sofor['telefon'] as String? ?? '';
    final kulAdi = sofor['kullaniciAdi'] ?? '';
    final aktif  = sofor['servisAktif'] == true;
    final durum  = sofor['soforDurum'] as String? ?? 'bosta';

    Color durumRenk = Colors.orange;
    String durumAd  = 'Boşta';
    if (durum == 'projeyeDahil') { durumRenk = Colors.blue; durumAd = 'Görevde'; }
    if (durum == 'aktifGorevde') { durumRenk = Colors.green; durumAd = 'Aktif'; }
    if (durum == 'pasif')        { durumRenk = Colors.grey; durumAd = 'Pasif'; }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: aktif
            ? Border.all(color: Colors.green.withValues(alpha: 0.4), width: 1.5)
            : Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 20, backgroundColor: durumRenk.withValues(alpha: 0.12),
            child: Text(ad.isNotEmpty ? ad[0].toUpperCase() : 'S',
                style: TextStyle(color: durumRenk, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ad, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _navy),
                overflow: TextOverflow.ellipsis),
            Text(plaka, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
                color: durumRenk.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(7)),
            child: Text(durumAd, style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.bold, color: durumRenk)),
          ),
        ]),
        const SizedBox(height: 10),
        if (tel.isNotEmpty)
          Row(children: [
            const Icon(Icons.phone_outlined, size: 11, color: Colors.grey),
            const SizedBox(width: 4),
            Text(tel, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        if (kulAdi.isNotEmpty)
          Row(children: [
            const Icon(Icons.account_circle_outlined, size: 11, color: Colors.grey),
            const SizedBox(width: 4),
            Text('@$kulAdi', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ]),
        const Spacer(),
        // Proje bilgisi
        if ((sofor['projeId'] ?? '').isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6)),
            child: Row(children: [
              const Icon(Icons.folder_outlined, size: 11, color: Colors.blue),
              const SizedBox(width: 4),
              Expanded(child: Text(sofor['projeAdi'] ?? 'Proje',
                  style: const TextStyle(fontSize: 10, color: Colors.blue,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis)),
            ]),
          ),
        const Divider(height: 12),
        Column(children: [
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: onDuzenle,
              icon: const Icon(Icons.edit_rounded, size: 13),
              label: const Text('Düzenle', style: TextStyle(fontSize: 11)),
            )),
            const SizedBox(width: 6),
            Expanded(child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _turuncu, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () => _projeAtaDialog(context),
              icon: const Icon(Icons.link_rounded, size: 13),
              label: const Text('Proje Ata', style: TextStyle(fontSize: 11)),
            )),
          ]),
          const SizedBox(height: 6),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _navy, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('drivers').doc(sofor['id']).update({
                'aktif'     : !(sofor['aktif'] as bool? ?? true),
                'soforDurum': (sofor['aktif'] as bool? ?? true) ? 'pasif' : 'bosta',
                'updatedAt' : FieldValue.serverTimestamp(),
              });
              onYukle();
            },
            icon: Icon((sofor['aktif'] as bool? ?? true)
                ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 13),
            label: Text((sofor['aktif'] as bool? ?? true) ? 'Pasif Yap' : 'Aktif Et',
                style: const TextStyle(fontSize: 11)),
          )),
        ]),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// KAYITLAR SEKMESİ — Öğrenci + Veli birleşik
// ════════════════════════════════════════════════════════════════
class _KayitlarSekme extends StatefulWidget {
  final String firmaId, projeId;
  const _KayitlarSekme({required this.firmaId, required this.projeId});
  @override
  State<_KayitlarSekme> createState() => _KayitlarSekmeState();
}

class _KayitlarSekmeState extends State<_KayitlarSekme> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  List<Map<String, dynamic>> _kayitlar  = [];
  List<Map<String, dynamic>> _servisler = [];
  bool _yukleniyor = true;
  String _arama = '';
  String _filtreDurum = 'hepsi';
  final _aramaCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _yukle(); }

  @override
  void dispose() { _aramaCtrl.dispose(); super.dispose(); }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      var q = FirebaseFirestore.instance.collection('students')
          .where('firmaId', isEqualTo: widget.firmaId);
      if (widget.projeId.isNotEmpty) q = q.where('projeId', isEqualTo: widget.projeId);
      final snap = await q.orderBy('ad').get();
      _kayitlar = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      final sSnap = await FirebaseFirestore.instance.collection('drivers')
          .where('firmaId', isEqualTo: widget.firmaId).get();
      _servisler = sSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) { debugPrint('Kayitlar hata: $e'); }
    if (mounted) setState(() => _yukleniyor = false);
  }

  String _servisAd(String? id) {
    if (id == null || id.isEmpty) return 'Atanmadı';
    final s = _servisler.firstWhere((s) => s['id'] == id, orElse: () => {});
    return s['adSoyad'] ?? s['ad'] ?? 'Servis';
  }

  @override
  Widget build(BuildContext context) {
    final filtrelenmis = _kayitlar.where((k) {
      if (_arama.isNotEmpty) {
        final ad = '${k['ad'] ?? ''} ${k['soyad'] ?? ''}'.toLowerCase();
        if (!ad.contains(_arama) &&
            !(k['veliTel'] ?? '').toString().contains(_arama)) return false;
      }
      if (_filtreDurum != 'hepsi' && k['sozlesmeDurum'] != _filtreDurum) return false;
      return true;
    }).toList();

    return Column(children: [
      // Üst bar
      Container(color: Colors.white, padding: const EdgeInsets.all(16),
        child: Row(children: [
          Expanded(child: TextField(
            controller: _aramaCtrl,
            onChanged: (v) => setState(() => _arama = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Öğrenci veya veli telefonu ara...',
              prefixIcon: const Icon(Icons.search, color: _navy, size: 18),
              filled: true, fillColor: const Color(0xFFF5F7FA),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none), isDense: true,
            ),
          )),
          const SizedBox(width: 12),
          // Durum filtresi
          DropdownButtonFormField<String>(
            value: _filtreDurum,
            isDense: true,
            decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            items: const [
              DropdownMenuItem(value: 'hepsi', child: Text('Tümü', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(value: 'bekliyor', child: Text('Bekliyor', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(value: 'onaylandi', child: Text('Onaylandı', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(value: 'imzalandi', child: Text('İmzalandı', style: TextStyle(fontSize: 12))),
            ],
            onChanged: (v) => setState(() => _filtreDurum = v ?? 'hepsi'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _turuncu, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pushNamed(context, '/yuz_yuze_kayit'),
            icon: const Icon(Icons.person_add_rounded, size: 16),
            label: const Text('Kayıt Ekle', style: TextStyle(fontWeight: FontWeight.bold))),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.refresh_rounded, color: _navy), onPressed: _yukle),
        ]),
      ),

      // Sayaç
      Container(
        color: const Color(0xFFF5F7FA),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(children: [
          Text('${filtrelenmis.length} kayıt',
              style: const TextStyle(color: _navy, fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          _sayac('Bekliyor', _kayitlar.where((k) => k['sozlesmeDurum'] == 'bekliyor').length, Colors.orange),
          const SizedBox(width: 8),
          _sayac('Onaylı', _kayitlar.where((k) => k['sozlesmeDurum'] == 'onaylandi').length, Colors.green),
        ]),
      ),

      // Tablo
      Expanded(child: _yukleniyor
          ? const Center(child: CircularProgressIndicator(color: _navy))
          : filtrelenmis.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.people_outline, size: 72, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  const Text('Kayıt bulunamadı', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: _turuncu, foregroundColor: Colors.white),
                    onPressed: () => Navigator.pushNamed(context, '/yuz_yuze_kayit'),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('İlk Kaydı Ekle')),
                ]))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    // Tablo başlığı
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                          color: _navy.withValues(alpha: 0.04),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
                      child: const Row(children: [
                        Expanded(flex: 3, child: Text('Öğrenci', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Expanded(flex: 2, child: Text('Veli / Tel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        Expanded(flex: 2, child: Text('Servis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        SizedBox(width: 80, child: Text('Ücret', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        SizedBox(width: 80, child: Text('Durum', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      ]),
                    ),
                    Container(
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)]),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filtrelenmis.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final k = filtrelenmis[i];
                          final durum = k['sozlesmeDurum'] as String? ?? 'bekliyor';
                          Color durumRenk = Colors.orange;
                          String durumAd  = 'Bekliyor';
                          if (durum == 'onaylandi') { durumRenk = Colors.green;  durumAd = 'Onaylı'; }
                          if (durum == 'imzalandi') { durumRenk = Colors.blue;   durumAd = 'İmzalı'; }

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Row(children: [
                              Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${k['ad'] ?? ''} ${k['soyad'] ?? ''}'.trim(),
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                if ((k['okul'] ?? '').isNotEmpty)
                                  Text(k['okul'], style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                              ])),
                              Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(k['veliAd'] ?? '-', style: const TextStyle(fontSize: 12)),
                                Text(k['veliTel'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                              ])),
                              Expanded(flex: 2, child: Text(_servisAd(k['surucuId']),
                                  style: TextStyle(fontSize: 12,
                                      color: (k['surucuId'] ?? '').isNotEmpty ? Colors.blue : Colors.grey))),
                              SizedBox(width: 80, child: Text(
                                (k['aylikUcret'] != null) ? '${k['aylikUcret']} TL' : '-',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                              SizedBox(width: 80, child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                    color: durumRenk.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6)),
                                child: Text(durumAd, style: TextStyle(
                                    fontSize: 10, color: durumRenk, fontWeight: FontWeight.bold)),
                              )),
                            ]),
                          );
                        },
                      ),
                    ),
                  ]),
                )),
    ]);
  }

  Widget _sayac(String label, int sayi, Color renk) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: renk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
    child: Text('$label: $sayi', style: TextStyle(color: renk, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}

// ── Web Servisler Sekmesi (eski — korunuyor) ──────────────────────
class _ServislerSekme extends StatefulWidget {
  final String firmaId;
  const _ServislerSekme({required this.firmaId});
  @override
  State<_ServislerSekme> createState() => _ServislerSekmeState();
}

class _ServislerSekmeState extends State<_ServislerSekme> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  List<Map<String, dynamic>> _projeler  = [];
  List<Map<String, dynamic>> _servisler = [];
  bool _yukleniyor = true;
  String? _seciliProjeId;

  @override
  void initState() { super.initState(); _yukle(); }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final pSnap = await FirebaseFirestore.instance
          .collection('projects')
          .where('firmaId', isEqualTo: widget.firmaId)
          .where('aktif', isEqualTo: true)
          .get();
      _projeler = pSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      if (_seciliProjeId == null && _projeler.isNotEmpty) {
        _seciliProjeId = _projeler.first['id'];
      }

      if (_seciliProjeId != null) {
        final sSnap = await FirebaseFirestore.instance
            .collection('services')
            .where('projeId', isEqualTo: _seciliProjeId)
            .orderBy('olusturma')
            .get();
        _servisler = sSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      }
    } catch (e) { debugPrint('ServislerSekme hata: $e'); }
    if (mounted) setState(() => _yukleniyor = false);
  }

  Color _tipRenk(String? tip) {
    switch (tip) {
      case 'sabah':   return Colors.orange;
      case 'aksam':   return Colors.indigo;
      case 'ogle':    return Colors.teal;
      default:        return _navy;
    }
  }

  IconData _tipIkon(String? tip) {
    switch (tip) {
      case 'sabah':   return Icons.wb_sunny_outlined;
      case 'aksam':   return Icons.nights_stay_outlined;
      case 'ogle':    return Icons.wb_twilight_outlined;
      default:        return Icons.route_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Üst bar
      Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: Row(children: [
          // Proje seçici
          if (_projeler.isNotEmpty)
            SizedBox(width: 280, child: DropdownButtonFormField<String>(
              value: _seciliProjeId,
              decoration: const InputDecoration(
                labelText: 'Proje',
                prefixIcon: Icon(Icons.folder_outlined),
                border: OutlineInputBorder(), isDense: true),
              items: _projeler.map((p) => DropdownMenuItem(
                value: p['id'] as String,
                child: Text(p['projeAd'] ?? ''),
              )).toList(),
              onChanged: (v) {
                setState(() { _seciliProjeId = v; _servisler = []; });
                _yukle();
              },
            )),
          const Spacer(),
          Text('${_servisler.length} servis',
              style: const TextStyle(color: _navy, fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _turuncu, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: _seciliProjeId == null ? null
                : () => Navigator.pushNamed(context, '/projeler'),
            icon: const Icon(Icons.add_road_outlined, size: 16),
            label: const Text('Servis Ekle',
                style: TextStyle(fontWeight: FontWeight.bold))),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.refresh_rounded, color: _navy),
              onPressed: _yukle),
        ]),
      ),

      // Servis listesi
      Expanded(child: _yukleniyor
          ? const Center(child: CircularProgressIndicator(color: _navy))
          : _servisler.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.route_outlined, size: 72, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  const Text('Bu projede servis yok',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text('Projeler → Servisler sekmesinden ekleyin',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ]))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    // Özet satır
                    Row(children: [
                      _ozet('Sabah', _servisler.where((s) => s['tip'] == 'sabah').length,
                          Colors.orange),
                      const SizedBox(width: 10),
                      _ozet('Akşam', _servisler.where((s) => s['tip'] == 'aksam').length,
                          Colors.indigo),
                      const SizedBox(width: 10),
                      _ozet('Diğer', _servisler.where((s) =>
                          s['tip'] != 'sabah' && s['tip'] != 'aksam').length, _navy),
                    ]),
                    const SizedBox(height: 16),
                    // Servis tablosu
                    Expanded(child: Container(
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8)]),
                      child: Column(children: [
                        // Başlık satırı
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                              color: _navy.withValues(alpha: 0.04),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(14))),
                          child: const Row(children: [
                            SizedBox(width: 32),
                            Expanded(flex: 3, child: Text('Servis Adı',
                                style: TextStyle(fontWeight: FontWeight.bold,
                                    fontSize: 12))),
                            Expanded(flex: 2, child: Text('Şoför',
                                style: TextStyle(fontWeight: FontWeight.bold,
                                    fontSize: 12))),
                            Expanded(flex: 2, child: Text('Araç',
                                style: TextStyle(fontWeight: FontWeight.bold,
                                    fontSize: 12))),
                            SizedBox(width: 80, child: Text('Saat',
                                style: TextStyle(fontWeight: FontWeight.bold,
                                    fontSize: 12))),
                            SizedBox(width: 70, child: Text('Durum',
                                style: TextStyle(fontWeight: FontWeight.bold,
                                    fontSize: 12))),
                          ]),
                        ),
                        // Satırlar
                        Expanded(child: ListView.separated(
                          itemCount: _servisler.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final s    = _servisler[i];
                            final tip  = s['tip'] as String? ?? 'diger';
                            final renk = _tipRenk(tip);
                            final aktif = s['aktif'] as bool? ?? true;

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(children: [
                                // Tip ikonu
                                Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(
                                      color: renk.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: Icon(_tipIkon(tip),
                                      color: renk, size: 16),
                                ),
                                Expanded(flex: 3, child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text(s['servisAdi'] ?? s['ad'] ?? '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                )),
                                Expanded(flex: 2, child: Text(
                                    s['soforAd'] ?? 'Atanmadı',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: (s['surucuId'] ?? '').isNotEmpty
                                            ? Colors.blue : Colors.grey))),
                                Expanded(flex: 2, child: Text(
                                    s['aracPlaka'] ?? 'Atanmadı',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: (s['vehicleId'] ?? '').isNotEmpty
                                            ? _navy : Colors.grey))),
                                SizedBox(width: 80, child: Text(
                                    (s['saatBaslangic'] ?? '').isNotEmpty
                                        ? '${s['saatBaslangic']} — ${s['saatBitis'] ?? ''}'
                                        : '-',
                                    style: const TextStyle(fontSize: 11,
                                        color: Colors.grey))),
                                SizedBox(width: 70, child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                      color: aktif
                                          ? Colors.green.withValues(alpha: 0.1)
                                          : Colors.grey.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: Text(aktif ? 'Aktif' : 'Pasif',
                                      style: TextStyle(
                                          color: aktif ? Colors.green : Colors.grey,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                )),
                              ]),
                            );
                          },
                        )),
                      ]),
                    )),
                  ]),
                )),
    ]);
  }

  Widget _ozet(String label, int sayi, Color renk) =>
      Expanded(child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: renk.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: renk.withValues(alpha: 0.2))),
        child: Row(children: [
          Text('$sayi', style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.bold, color: renk)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12, color: renk)),
        ]),
      ));
}
