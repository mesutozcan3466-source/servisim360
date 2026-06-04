import 'package:flutter/material.dart';
import 'ai_widget.dart';
import 'yardim_widget.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:math';
import 'lisans_uyari_ekrani_screen.dart';
import '../services/session_service.dart';

// ════════════════════════════════════════════════════════════════
//  PROJELER EKRANI
// ════════════════════════════════════════════════════════════════
class ProjelerScreen extends StatefulWidget {
  const ProjelerScreen({super.key});
  @override
  State<ProjelerScreen> createState() => _ProjelerScreenState();
}

class _ProjelerScreenState extends State<ProjelerScreen> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  String _firmaId  = '';
  bool   _yuklendi = false;

  @override
  void initState() {
    super.initState();
    _firmaIdAl();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LisansKontrolHelper.kontrol(context);
    });
  }

  Future<void> _firmaIdAl() async {
    // Önce SessionService'ten dene
    final sessionFirmaId = await SessionService.instance.firmaIdAl();
    if (sessionFirmaId != null && sessionFirmaId.isNotEmpty) {
      if (mounted) setState(() { _firmaId = sessionFirmaId; _yuklendi = true; });
      return;
    }

    // Sonra kullanicilar koleksiyonundan al
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _yuklendi = true);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('kullanicilar').doc(uid).get();
      final fId = doc.data()?['firmaId'] as String? ?? '';

      // kullanicilar'da yoksa firms koleksiyonunda ara
      if (fId.isEmpty) {
        final firmaSnap = await FirebaseFirestore.instance
            .collection('firms')
            .where('adminUid', isEqualTo: uid)
            .limit(1).get();
        if (firmaSnap.docs.isNotEmpty) {
          if (mounted) setState(() {
            _firmaId  = firmaSnap.docs.first.id;
            _yuklendi = true;
          });
          return;
        }
      }

      if (mounted) setState(() { _firmaId = fId; _yuklendi = true; });
    } catch (e) {
      debugPrint('firmaIdAl hata: $e');
      if (mounted) setState(() => _yuklendi = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white,
        title: const Text('Projeler', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          AiAsistanButonu(ekranAdi: 'Projeler'),
          YardimButonu(ekranAdi: 'Projeler'),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _yuklendi ? () => _projeEkleDialog(context) : null,
          ),
        ],
      ),
      body: _yuklendi
          ? _icerik()
          : const Center(child: CircularProgressIndicator(color: _navy)),
    );
  }

  Widget _icerik() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .where('firmaId', isEqualTo: _firmaId)
          .orderBy('olusturmaTarihi', descending: true)
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _navy));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.folder_open_outlined, size: 72, color: Color(0xFFCCCCCC)),
            const SizedBox(height: 16),
            const Text('Henuz proje eklenmemis', style: TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _turuncu, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _projeEkleDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Ilk Projeyi Olustur', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ]));
        }
        return Column(children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              const Icon(Icons.folder_outlined, color: _navy, size: 18),
              const SizedBox(width: 8),
              Text('${docs.length} proje',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: _navy)),
              const Spacer(),
              Text(
                '${docs.where((d) => (d.data() as Map)['aktif'] == true).length} aktif',
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ]),
          ),
          Expanded(child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (_, i) => _ProjeKarti(
              projeId: docs[i].id,
              data: docs[i].data() as Map<String, dynamic>,
              firmaId: _firmaId,
            ),
          )),
        ]);
      },
    );
  }

  void _projeEkleDialog(BuildContext context) {
    final adCtrl    = TextEditingController();
    final donemCtrl = TextEditingController(text: '2025-2026');
    final notCtrl   = TextEditingController();
    String tip = 'okul';
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (bsCtx) => StatefulBuilder(builder: (ctx, setS) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(bsCtx).viewInsets.bottom),
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Padding(padding: const EdgeInsets.all(24), child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: _navy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.folder_outlined, color: _navy)),
              const SizedBox(width: 12),
              const Text('Yeni Proje Olustur',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _navy)),
            ]),
            const SizedBox(height: 20),
            _InputAlan(ctrl: adCtrl, label: 'Proje Adi *', ikon: Icons.folder_outlined),
            const SizedBox(height: 10),
            _InputAlan(ctrl: donemCtrl, label: 'Donem', ikon: Icons.calendar_today_outlined),
            const SizedBox(height: 12),
            const Text('Proje Tipi', style: TextStyle(fontWeight: FontWeight.bold, color: _navy, fontSize: 13)),
            const SizedBox(height: 8),
            Row(children: [
              _TipChip('okul',     'Okul',     Icons.school_outlined,           tip, (t) => setS(() => tip = t)),
              const SizedBox(width: 8),
              _TipChip('kolej',    'Kolej',    Icons.account_balance_outlined,  tip, (t) => setS(() => tip = t)),
              const SizedBox(width: 8),
              _TipChip('personel', 'Personel', Icons.badge_outlined,            tip, (t) => setS(() => tip = t)),
            ]),
            const SizedBox(height: 12),
            _InputAlan(ctrl: notCtrl, label: 'Not (opsiyonel)', ikon: Icons.notes_outlined, satir: 2),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _turuncu, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                if (adCtrl.text.trim().isEmpty) return;
                // firmaId kontrolü — boşsa tekrar yükle
                if (_firmaId.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content: Text('Firma bilgisi yükleniyor, lütfen bekleyin'),
                      behavior: SnackBarBehavior.floating));
                  return;
                }
                try {
                  await FirebaseFirestore.instance.collection('projects').add({
                    'firmaId'        : _firmaId,
                    'projeAd'        : adCtrl.text.trim(),
                    'ad'             : adCtrl.text.trim(),
                    'donem'          : donemCtrl.text.trim(),
                    'tip'            : tip,
                    'not'            : notCtrl.text.trim(),
                    'aktif'          : true,
                    'olusturmaTarihi': FieldValue.serverTimestamp(),
                    'createdAt'      : FieldValue.serverTimestamp(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text('Hata: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating));
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Projeyi Olustur', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            )),
          ],
        )),
      )),
    );
  }
}

// ── Proje Karti ──────────────────────────────────────────────────
class _ProjeKarti extends StatelessWidget {
  final String projeId, firmaId;
  final Map<String, dynamic> data;
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  const _ProjeKarti({required this.projeId, required this.data, required this.firmaId});

  Color get _tipRenk => data['tip'] == 'kolej' ? Colors.blue : data['tip'] == 'personel' ? Colors.purple : _navy;
  IconData get _tipIkon => data['tip'] == 'kolej' ? Icons.account_balance_outlined : data['tip'] == 'personel' ? Icons.badge_outlined : Icons.school_outlined;

  @override
  Widget build(BuildContext context) {
    final aktif = data['aktif'] ?? true;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: aktif ? _tipRenk.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _tipRenk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(_tipIkon, color: _tipRenk, size: 24)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(data['projeAd'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text('${data['donem'] ?? ''} · ${_tipAd(data['tip'] ?? '')}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              if ((data['not'] ?? '').isNotEmpty)
                Text(data['not'], style: TextStyle(color: Colors.grey[400], fontSize: 11)),
            ])),
            Column(children: [
              Switch(value: aktif, activeColor: Colors.green,
                  onChanged: (v) => FirebaseFirestore.instance.collection('projects').doc(projeId).update({'aktif': v})),
              Text(aktif ? 'Aktif' : 'Pasif',
                  style: TextStyle(fontSize: 10, color: aktif ? Colors.green : Colors.grey, fontWeight: FontWeight.bold)),
            ]),
          ]),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('students').where('projeId', isEqualTo: projeId).snapshots(),
          builder: (_, snapStd) => StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('drivers').where('projeId', isEqualTo: projeId).snapshots(),
            builder: (_, snapDrv) => StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('vehicles').where('projeId', isEqualTo: projeId).snapshots(),
              builder: (_, snapVeh) => Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF5F7FA), borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _MiniStat('${snapStd.data?.docs.length ?? 0}', 'Ogrenci', Icons.school_outlined, Colors.green),
                  Container(width: 1, height: 40, color: Colors.grey[200]),
                  _MiniStat('${snapDrv.data?.docs.length ?? 0}', 'Sofor',   Icons.person_outline,  Colors.blue),
                  Container(width: 1, height: 40, color: Colors.grey[200]),
                  _MiniStat('${snapVeh.data?.docs.length ?? 0}', 'Arac',    Icons.directions_bus_outlined, Colors.orange),
                ]),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(children: [
            Expanded(child: _AksiyonButon(Icons.open_in_new_outlined, 'Ac',       _navy,        () => _detayAc(context))),
            const SizedBox(width: 6),
            Expanded(child: _AksiyonButon(Icons.school_outlined,      'Ogrenci',  Colors.green, () => _detayAc(context, sekme: 1))),
            const SizedBox(width: 6),
            Expanded(child: _AksiyonButon(Icons.person_outline,       'Sofor',    Colors.blue,  () => _detayAc(context, sekme: 2))),
            const SizedBox(width: 6),
            Expanded(child: _AksiyonButon(Icons.edit_outlined,        'Duzenle',  Colors.grey,  () => _duzenleDialog(context))),
            const SizedBox(width: 6),
            Expanded(child: _AksiyonButon(Icons.delete_outline,       'Sil',      Colors.red,   () => _silDialog(context))),
          ]),
        ),
      ]),
    );
  }

  void _detayAc(BuildContext context, {int sekme = 0}) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ProjeDetayScreen(projeId: projeId, data: data, firmaId: firmaId, baslangicSekme: sekme),
    ));
  }

  void _duzenleDialog(BuildContext ctx) {
    final adCtrl    = TextEditingController(text: data['projeAd']);
    final donemCtrl = TextEditingController(text: data['donem']);
    final notCtrl   = TextEditingController(text: data['not']);
    showDialog(context: ctx, builder: (dCtx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Projeyi Duzenle', style: TextStyle(color: _navy, fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _InputAlan(ctrl: adCtrl,    label: 'Proje Adi',  ikon: Icons.folder_outlined),
        const SizedBox(height: 10),
        _InputAlan(ctrl: donemCtrl, label: 'Donem',      ikon: Icons.calendar_today_outlined),
        const SizedBox(height: 10),
        _InputAlan(ctrl: notCtrl,   label: 'Not',        ikon: Icons.notes_outlined, satir: 2),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Iptal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
          onPressed: () async {
            await FirebaseFirestore.instance.collection('projects').doc(projeId).update({
              'projeAd': adCtrl.text.trim(),
              'donem':   donemCtrl.text.trim(),
              'not':     notCtrl.text.trim(),
            });
            if (dCtx.mounted) Navigator.pop(dCtx);
          },
          child: const Text('Kaydet'),
        ),
      ],
    ));
  }

  void _silDialog(BuildContext ctx) {
    showDialog(context: ctx, builder: (dCtx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Projeyi Sil', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      content: Text('"${data['projeAd']}" projesini silmek istediginize emin misiniz?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Iptal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          onPressed: () async {
            await FirebaseFirestore.instance.collection('projects').doc(projeId).delete();
            if (dCtx.mounted) Navigator.pop(dCtx);
          },
          child: const Text('Sil'),
        ),
      ],
    ));
  }

  static String _tipAd(String t) => t == 'kolej' ? 'Kolej' : t == 'personel' ? 'Personel' : 'Okul';
}

// ════════════════════════════════════════════════════════════════
//  PROJE DETAY EKRANI
// ════════════════════════════════════════════════════════════════
class ProjeDetayScreen extends StatefulWidget {
  final String projeId, firmaId;
  final Map<String, dynamic> data;
  final int baslangicSekme;
  const ProjeDetayScreen({
    super.key,
    required this.projeId,
    required this.data,
    required this.firmaId,
    this.baslangicSekme = 0,
  });
  @override
  State<ProjeDetayScreen> createState() => _ProjeDetayScreenState();
}

class _ProjeDetayScreenState extends State<ProjeDetayScreen>
    with SingleTickerProviderStateMixin {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 8, vsync: this, initialIndex: widget.baslangicSekme);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white,
        title: Text(widget.data['projeAd'] ?? 'Proje',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: _turuncu,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.info_outline,           size: 18), text: 'Genel'),
            Tab(icon: Icon(Icons.school_outlined,         size: 18), text: 'Ogrenciler'),
            Tab(icon: Icon(Icons.person_outline,          size: 18), text: 'Soforler'),
            Tab(icon: Icon(Icons.directions_bus_outlined, size: 18), text: 'Araclar'),
            Tab(icon: Icon(Icons.attach_money_outlined,   size: 18), text: 'Fiyatlar'),
            Tab(icon: Icon(Icons.description_outlined,    size: 18), text: 'Sozlesme'),
            Tab(icon: Icon(Icons.route_outlined,           size: 18), text: 'Servisler'),
            Tab(icon: Icon(Icons.link_outlined,           size: 18), text: 'Kayit Linki'),
          ],
        ),
      ),
      body: TabBarView(controller: _tab, children: [
        _GenelTab(projeId: widget.projeId, data: widget.data),
        OgrencilerTab(projeId: widget.projeId, firmaId: widget.firmaId),
        SoforlerTab(projeId: widget.projeId, firmaId: widget.firmaId),
        AraclarTab(projeId: widget.projeId, firmaId: widget.firmaId),
        _ProjeFiyatTab(projeId: widget.projeId, firmaId: widget.firmaId),
        _ProjeSozlesmeTab(projeId: widget.projeId),
        ServislerTab(projeId: widget.projeId, firmaId: widget.firmaId),
        _ProjeKayitLinkiTab(projeId: widget.projeId, firmaId: widget.firmaId, projeAdi: widget.data['projeAd'] ?? ''),
      ]),
    );
  }
}

// ── Genel Tab ────────────────────────────────────────────────────
class _GenelTab extends StatelessWidget {
  final String projeId;
  final Map<String, dynamic> data;
  static const _navy = Color(0xFF1a3a6b);
  const _GenelTab({required this.projeId, required this.data});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_navy, Color(0xFF2a5298)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data['projeAd'] ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${data['donem'] ?? ''} · ${data['tip'] ?? ''}',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            if ((data['not'] ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(data['not'], style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ],
          ]),
        ),
        const SizedBox(height: 16),
        _HizliLink(Icons.map_outlined,           Colors.teal,   'Haritada Goruntule', () => Navigator.pushNamed(context, '/harita')),
        const SizedBox(height: 8),
        _HizliLink(Icons.my_location_outlined,   Colors.green,  'Canli Takip',        () => Navigator.pushNamed(context, '/admin_takip')),
        const SizedBox(height: 8),
        _HizliLink(Icons.notifications_outlined, _navy,         'Velilere Bildir',    () => Navigator.pushNamed(context, '/toplu_mesaj')),
        const SizedBox(height: 8),
        _HizliLink(Icons.share_outlined,         Colors.orange, 'Kayit Linki Gonder', () => _kayitLinki(context)),
      ]),
    );
  }

  void _kayitLinki(BuildContext context) {
    final link = 'https://servis360-15b4a.web.app/kayit?projeId=$projeId';
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Veli Kayit Linki', style: TextStyle(color: _navy, fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Bu linki velilere gonderin:', style: TextStyle(fontSize: 13)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Expanded(child: Text(link, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
            IconButton(icon: const Icon(Icons.copy, size: 18), onPressed: () {
              Clipboard.setData(ClipboardData(text: link));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link kopyalandi!'), backgroundColor: Colors.green));
            }),
          ]),
        ),
      ]),
      actions: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white),
          onPressed: () async {
            final msg = Uri.encodeComponent('Servisim360 veli kaydi icin: $link');
            await launchUrl(Uri.parse('https://wa.me/?text=$msg'));
            if (ctx.mounted) Navigator.pop(ctx);
          },
          icon: const Icon(Icons.send),
          label: const Text('WhatsApp ile Gonder'),
        ),
      ],
    ));
  }
}

// ════════════════════════════════════════════════════════════════
//  OGRENCILER SEKMESI
// ════════════════════════════════════════════════════════════════
class OgrencilerTab extends StatefulWidget {
  final String projeId, firmaId;
  const OgrencilerTab({super.key, required this.projeId, required this.firmaId});
  @override
  State<OgrencilerTab> createState() => _OgrencilerTabState();
}

class _OgrencilerTabState extends State<OgrencilerTab> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  String _arama = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _turuncu, foregroundColor: Colors.white,
        onPressed: () => _ogrenciEkleDialog(context),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Ogrenci Ekle'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: (v) => setState(() => _arama = v),
            decoration: InputDecoration(
              hintText: 'Ogrenci ara...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true, fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        Expanded(child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('students')
              .where('projeId', isEqualTo: widget.projeId)
              .orderBy('ad')
              .snapshots(),
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _navy));
            }
            var docs = snap.data?.docs ?? [];
            if (_arama.isNotEmpty) {
              docs = docs.where((d) {
                final ad = ((d.data() as Map)['ad'] ?? '').toString().toLowerCase();
                return ad.contains(_arama.toLowerCase());
              }).toList();
            }
            if (docs.isEmpty) {
              return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.school_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 12),
                const Text('Henuz ogrenci eklenmemis', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _ogrenciEkleDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Ogrenci Ekle'),
                ),
              ]));
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
              itemCount: docs.length,
              itemBuilder: (_, i) {
                final d  = docs[i].data() as Map<String, dynamic>;
                final id = docs[i].id;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]),
                  child: Row(children: [
                    CircleAvatar(radius: 20, backgroundColor: _turuncu.withValues(alpha: 0.1),
                        child: Text((d['ad'] ?? '?')[0].toUpperCase(),
                            style: const TextStyle(color: _turuncu, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d['ad'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      if ((d['adres'] ?? '').isNotEmpty)
                        Text(d['adres'], style: TextStyle(color: Colors.grey[500], fontSize: 11), overflow: TextOverflow.ellipsis),
                      if ((d['veliAd'] ?? '').isNotEmpty)
                        Text('Veli: ${d['veliAd']}  ${d['veliTel'] ?? ''}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                      if ((d['soforAd'] ?? '').isNotEmpty)
                        Text('Sofor: ${d['soforAd']}', style: const TextStyle(color: Colors.blue, fontSize: 11)),
                    ])),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.grey, size: 18),
                          onPressed: () => _ogrenciDuzenle(context, id, d)),
                      IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                          onPressed: () => _ogrenciSil(context, id, d['ad'] ?? '')),
                    ]),
                  ]),
                );
              },
            );
          },
        )),
      ]),
    );
  }

  void _ogrenciEkleDialog(BuildContext context) {
    final adCtrl     = TextEditingController();
    final adresCtrl  = TextEditingController();
    final veliAdCtrl = TextEditingController();
    final veliTelCtrl= TextEditingController();
    String? seciliSoforId;
    String? seciliSoforAd;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ogrenci Ekle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _navy)),
            const SizedBox(height: 16),
            _InputAlan(ctrl: adCtrl,      label: 'Ogrenci Adi *', ikon: Icons.person_outline),
            const SizedBox(height: 10),
            _InputAlan(ctrl: adresCtrl,   label: 'Adres',          ikon: Icons.location_on_outlined),
            const SizedBox(height: 10),
            _InputAlan(ctrl: veliAdCtrl,  label: 'Veli Adi',       ikon: Icons.family_restroom_outlined),
            const SizedBox(height: 10),
            _InputAlan(ctrl: veliTelCtrl, label: 'Veli Telefon',   ikon: Icons.phone_outlined, tipi: TextInputType.phone),
            const SizedBox(height: 12),
            const Text('Sofor Ata (opsiyonel)', style: TextStyle(fontWeight: FontWeight.bold, color: _navy, fontSize: 13)),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('drivers').where('projeId', isEqualTo: widget.projeId).snapshots(),
              builder: (_, snap) {
                final soforler = snap.data?.docs ?? [];
                if (soforler.isEmpty) return const Text('Bu projede sofor yok', style: TextStyle(color: Colors.grey, fontSize: 12));
                return Wrap(spacing: 8, runSpacing: 8, children: soforler.map((s) {
                  final sd = s.data() as Map<String, dynamic>;
                  final secili = seciliSoforId == s.id;
                  return GestureDetector(
                    onTap: () => setS(() { seciliSoforId = secili ? null : s.id; seciliSoforAd = secili ? null : sd['ad']; }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: secili ? _navy : Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: secili ? _navy : Colors.grey.shade300),
                      ),
                      child: Text(sd['ad'] ?? '', style: TextStyle(color: secili ? Colors.white : Colors.black87, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  );
                }).toList());
              },
            ),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: _turuncu, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                if (adCtrl.text.trim().isEmpty) return;
                await FirebaseFirestore.instance.collection('students').add({
                  'firmaId': widget.firmaId, 'projeId': widget.projeId,
                  'ad': adCtrl.text.trim(), 'adres': adresCtrl.text.trim(),
                  'veliAd': veliAdCtrl.text.trim(), 'veliTel': veliTelCtrl.text.trim(),
                  'soforId': seciliSoforId ?? '', 'soforAd': seciliSoforAd ?? '',
                  'aktif': true, 'bindi': false, 'olusturma': FieldValue.serverTimestamp(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              icon: const Icon(Icons.add),
              label: const Text('Ogrenci Ekle', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            )),
          ],
        )),
      )),
    );
  }

  void _ogrenciDuzenle(BuildContext context, String id, Map<String, dynamic> d) {
    final adCtrl     = TextEditingController(text: d['ad']);
    final adresCtrl  = TextEditingController(text: d['adres']);
    final veliAdCtrl = TextEditingController(text: d['veliAd']);
    final veliTelCtrl= TextEditingController(text: d['veliTel']);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Ogrenci Duzenle', style: TextStyle(color: _navy, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _InputAlan(ctrl: adCtrl,      label: 'Ogrenci Adi',  ikon: Icons.person_outline),
        const SizedBox(height: 10),
        _InputAlan(ctrl: adresCtrl,   label: 'Adres',         ikon: Icons.location_on_outlined),
        const SizedBox(height: 10),
        _InputAlan(ctrl: veliAdCtrl,  label: 'Veli Adi',      ikon: Icons.family_restroom_outlined),
        const SizedBox(height: 10),
        _InputAlan(ctrl: veliTelCtrl, label: 'Veli Telefon',  ikon: Icons.phone_outlined),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Iptal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
          onPressed: () async {
            await FirebaseFirestore.instance.collection('students').doc(id).update({
              'ad': adCtrl.text.trim(), 'adres': adresCtrl.text.trim(),
              'veliAd': veliAdCtrl.text.trim(), 'veliTel': veliTelCtrl.text.trim(),
            });
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Kaydet'),
        ),
      ],
    ));
  }

  void _ogrenciSil(BuildContext context, String id, String ad) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Ogrenci Sil', style: TextStyle(color: Colors.red)),
      content: Text('"$ad" silinecek. Emin misiniz?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Iptal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          onPressed: () async {
            await FirebaseFirestore.instance.collection('students').doc(id).delete();
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Sil'),
        ),
      ],
    ));
  }
}

// ════════════════════════════════════════════════════════════════
//  SOFORLER SEKMESI
// ════════════════════════════════════════════════════════════════
class SoforlerTab extends StatefulWidget {
  final String projeId, firmaId;
  const SoforlerTab({super.key, required this.projeId, required this.firmaId});
  @override
  State<SoforlerTab> createState() => _SoforlerTabState();
}

class _SoforlerTabState extends State<SoforlerTab> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  static const _apiKey  = 'AIzaSyDtuxahEVj78OTSIZKaa6z8Q69CNWymO78';

  String _sifreUret() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<String?> _kullaniciOlustur(String email, String sifre) async {
    try {
      final resp = await http.post(
        Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': sifre, 'returnSecureToken': true}),
      );
      final data = jsonDecode(resp.body);
      if (resp.statusCode == 200) return data['localId'] as String?;
      return null;
    } catch (_) { return null; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _navy, foregroundColor: Colors.white,
        onPressed: () => _soforEkleDialog(context),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Sofor Ekle'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('drivers').where('projeId', isEqualTo: widget.projeId).snapshots(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _navy));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.person_outline, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 12),
              const Text('Henuz sofor eklenmemis', style: TextStyle(color: Colors.grey)),
            ]));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d     = docs[i].data() as Map<String, dynamic>;
              final id    = docs[i].id;
              final aktif = d['servisAktif'] ?? false;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: aktif ? Colors.green.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.15)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
                ),
                child: Column(children: [
                  Row(children: [
                    CircleAvatar(radius: 22, backgroundColor: _navy.withValues(alpha: 0.1),
                        child: Text((d['ad'] ?? '?')[0].toUpperCase(), style: const TextStyle(color: _navy, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d['ad'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(d['telefon'] ?? '', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      if ((d['aracPlaka'] ?? '').isNotEmpty)
                        Text('Plaka: ${d['aracPlaka']}', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                      if ((d['email'] ?? '').isNotEmpty)
                        Text('Email: ${d['email']}', style: TextStyle(color: Colors.blue[700], fontSize: 11)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: aktif ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(aktif ? 'Aktif' : 'Pasif',
                          style: TextStyle(color: aktif ? Colors.green : Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _SoforAksiyon(Icons.edit_outlined,   'Duzenle', Colors.grey,  () => _soforDuzenle(context, id, d))),
                    const SizedBox(width: 6),
                    Expanded(child: _SoforAksiyon(Icons.send_outlined,   'WhatsApp',Colors.green, () => _wpGonder(d))),
                    const SizedBox(width: 6),
                    Expanded(child: _SoforAksiyon(Icons.qr_code_outlined,'QR Kod',  Colors.blue,  () => _qrGoster(context, d))),
                    const SizedBox(width: 6),
                    Expanded(child: _SoforAksiyon(Icons.delete_outline,  'Sil',     Colors.red,   () => _soforSil(context, id, d['ad'] ?? ''))),
                  ]),
                ]),
              );
            },
          );
        },
      ),
    );
  }

  void _soforEkleDialog(BuildContext context) {
    final adCtrl    = TextEditingController();
    final telCtrl   = TextEditingController();
    final plakaCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final markaCtrl = TextEditingController();
    bool yukleniyor = false;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sofor Ekle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _navy)),
            const SizedBox(height: 16),
            _InputAlan(ctrl: adCtrl,    label: 'Ad Soyad *',           ikon: Icons.person_outline),
            const SizedBox(height: 10),
            _InputAlan(ctrl: telCtrl,   label: 'Telefon (WhatsApp)',    ikon: Icons.phone_outlined, tipi: TextInputType.phone),
            const SizedBox(height: 10),
            _InputAlan(ctrl: emailCtrl, label: 'E-posta * (giris icin)',ikon: Icons.email_outlined, tipi: TextInputType.emailAddress),
            const SizedBox(height: 10),
            _InputAlan(ctrl: plakaCtrl, label: 'Arac Plakasi',          ikon: Icons.directions_bus_outlined),
            const SizedBox(height: 10),
            _InputAlan(ctrl: markaCtrl, label: 'Arac Markasi',          ikon: Icons.build_outlined),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: yukleniyor ? null : () async {
                if (adCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty) return;
                setS(() => yukleniyor = true);
                final sifre = _sifreUret();
                final uid   = await _kullaniciOlustur(emailCtrl.text.trim(), sifre);
                final docRef = await FirebaseFirestore.instance.collection('drivers').add({
                  'firmaId': widget.firmaId, 'projeId': widget.projeId,
                  'ad': adCtrl.text.trim(), 'telefon': telCtrl.text.trim(),
                  'email': emailCtrl.text.trim(), 'aracPlaka': plakaCtrl.text.trim(),
                  'aracMarka': markaCtrl.text.trim(), 'sifre': sifre,
                  'uid': uid ?? '', 'aktif': true, 'servisAktif': false,
                  'rol': 'sofor', 'olusturma': FieldValue.serverTimestamp(),
                });
                if (uid != null) {
                  await FirebaseFirestore.instance.collection('kullanicilar').doc(uid).set({
                    'firmaId': widget.firmaId, 'projeId': widget.projeId,
                    'email': emailCtrl.text.trim(), 'rol': 'sofor', 'durum': 'onayli',
                    'soforId': docRef.id, 'ad': adCtrl.text.trim(), 'olusturma': FieldValue.serverTimestamp(),
                  });
                }
                final tel = telCtrl.text.trim();
                if (tel.isNotEmpty) {
                  final msg = 'Merhaba ${adCtrl.text.trim()}!\n\nServisim360 giris bilgileriniz:\nE-posta: ${emailCtrl.text.trim()}\nSifre: $sifre';
                  var numara = tel.replaceAll(RegExp(r'[^0-9]'), '');
                  if (numara.startsWith('0')) numara = '9$numara';
                  if (!numara.startsWith('90')) numara = '90$numara';
                  await launchUrl(Uri.parse('https://wa.me/$numara?text=${Uri.encodeComponent(msg)}'), mode: LaunchMode.externalApplication);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              icon: yukleniyor ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send_rounded),
              label: Text(yukleniyor ? 'Ekleniyor...' : 'Ekle ve WhatsApp Gonder', style: const TextStyle(fontWeight: FontWeight.bold)),
            )),
          ],
        )),
      )),
    );
  }

  void _soforDuzenle(BuildContext context, String id, Map<String, dynamic> d) {
    final adCtrl    = TextEditingController(text: d['ad']);
    final telCtrl   = TextEditingController(text: d['telefon']);
    final plakaCtrl = TextEditingController(text: d['aracPlaka']);
    final markaCtrl = TextEditingController(text: d['aracMarka']);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Sofor Duzenle', style: TextStyle(color: _navy, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _InputAlan(ctrl: adCtrl,    label: 'Ad Soyad',    ikon: Icons.person_outline),
        const SizedBox(height: 10),
        _InputAlan(ctrl: telCtrl,   label: 'Telefon',     ikon: Icons.phone_outlined),
        const SizedBox(height: 10),
        _InputAlan(ctrl: plakaCtrl, label: 'Arac Plakasi',ikon: Icons.directions_bus_outlined),
        const SizedBox(height: 10),
        _InputAlan(ctrl: markaCtrl, label: 'Arac Markasi',ikon: Icons.build_outlined),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Iptal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
          onPressed: () async {
            await FirebaseFirestore.instance.collection('drivers').doc(id).update({
              'ad': adCtrl.text.trim(), 'telefon': telCtrl.text.trim(),
              'aracPlaka': plakaCtrl.text.trim(), 'aracMarka': markaCtrl.text.trim(),
            });
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Kaydet'),
        ),
      ],
    ));
  }

  void _wpGonder(Map<String, dynamic> d) async {
    final tel   = d['telefon'] ?? '';
    final email = d['email']   ?? '';
    final sifre = d['sifre']   ?? '(sifre kayitli degil)';
    if (tel.isEmpty) return;
    final msg = 'Merhaba ${d['ad'] ?? ''}!\n\nServisim360 giris bilgileriniz:\nE-posta: $email\nSifre: $sifre';
    var numara = tel.replaceAll(RegExp(r'[^0-9]'), '');
    if (numara.startsWith('0')) numara = '9$numara';
    if (!numara.startsWith('90')) numara = '90$numara';
    await launchUrl(Uri.parse('https://wa.me/$numara?text=${Uri.encodeComponent(msg)}'), mode: LaunchMode.externalApplication);
  }

  void _qrGoster(BuildContext context, Map<String, dynamic> d) {
    final email = d['email'] ?? '';
    final sifre = d['sifre'] ?? '';
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(d['ad'] ?? 'Sofor', style: const TextStyle(color: _navy, fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            const Icon(Icons.qr_code_2, size: 80, color: _navy),
            const SizedBox(height: 12),
            Text('E-posta: $email', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Text('Sifre: $sifre', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ),
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: 'Email: $email\nSifre: $sifre'));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kopyalandi!'), backgroundColor: Colors.green));
          },
          icon: const Icon(Icons.copy),
          label: const Text('Kopyala'),
        ),
      ]),
      actions: [ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white), onPressed: () => Navigator.pop(ctx), child: const Text('Kapat'))],
    ));
  }

  void _soforSil(BuildContext context, String id, String ad) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Sofor Sil', style: TextStyle(color: Colors.red)),
      content: Text('"$ad" silinecek. Emin misiniz?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Iptal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          onPressed: () async {
            await FirebaseFirestore.instance.collection('drivers').doc(id).delete();
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: const Text('Sil'),
        ),
      ],
    ));
  }
}

class _SoforAksiyon extends StatelessWidget {
  final IconData ikon; final String etiket; final Color renk; final VoidCallback onTap;
  const _SoforAksiyon(this.ikon, this.etiket, this.renk, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
          color: renk.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8),
          border: Border.all(color: renk.withValues(alpha: 0.2))),
      child: Column(children: [
        Icon(ikon, color: renk, size: 16),
        const SizedBox(height: 2),
        Text(etiket, style: TextStyle(color: renk, fontSize: 9, fontWeight: FontWeight.w600)),
      ]),
    ),
  );
}

// ════════════════════════════════════════════════════════════════
//  ARACLAR SEKMESI
// ════════════════════════════════════════════════════════════════

// ════════════════════════════════════════════════════════════════
// SERVİSLER TAB — Proje içi servis yönetimi
// Koleksiyon: services
// ════════════════════════════════════════════════════════════════
class ServislerTab extends StatefulWidget {
  final String projeId, firmaId;
  const ServislerTab({super.key, required this.projeId, required this.firmaId});
  @override
  State<ServislerTab> createState() => _ServislerTabState();
}

class _ServislerTabState extends State<ServislerTab> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  List<Map<String, dynamic>> _soforler = [];
  List<Map<String, dynamic>> _araclar  = [];

  @override
  void initState() {
    super.initState();
    _destekleriYukle();
  }

  Future<void> _destekleriYukle() async {
    final sSnap = await FirebaseFirestore.instance
        .collection('drivers')
        .where('firmaId', isEqualTo: widget.firmaId)
        .where('aktif', isEqualTo: true)
        .get();
    final aSnap = await FirebaseFirestore.instance
        .collection('vehicles')
        .where('firmaId', isEqualTo: widget.firmaId)
        .get();
    if (mounted) setState(() {
      _soforler = sSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      _araclar  = aSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    });
  }

  String _soforAd(String? id) {
    if (id == null || id.isEmpty) return 'Atanmadı';
    final s = _soforler.firstWhere((s) => s['id'] == id, orElse: () => {});
    return s['adSoyad'] ?? s['ad'] ?? 'Şoför';
  }

  String _aracAd(String? id) {
    if (id == null || id.isEmpty) return 'Atanmadı';
    final a = _araclar.firstWhere((a) => a['id'] == id, orElse: () => {});
    return a['plaka'] ?? '-';
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
      default:        return Icons.directions_bus_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _turuncu, foregroundColor: Colors.white,
        icon: const Icon(Icons.add_road_outlined),
        label: const Text('Servis Ekle', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _servisEkleDialog(context),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('services')
            .where('projeId', isEqualTo: widget.projeId)
            .snapshots(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.route_outlined, size: 80, color: Colors.grey[300]),
              const SizedBox(height: 16),
              const Text('Henüz servis eklenmedi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _navy)),
              const SizedBox(height: 8),
              Text('Proje içindeki servis güzergahlarını burada oluşturun',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _turuncu, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () => _servisEkleDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Servis Ekle', style: TextStyle(fontWeight: FontWeight.bold))),
            ]));
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d   = docs[i].data() as Map<String, dynamic>;
              final id  = docs[i].id;
              final tip = d['tip'] as String? ?? 'diger';
              final aktif = d['aktif'] as bool? ?? true;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 1.5,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                            color: _tipRenk(tip).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10)),
                        child: Icon(_tipIkon(tip), color: _tipRenk(tip), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d['servisAdi'] ?? d['ad'] ?? 'Servis',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(_tipLabel(tip),
                            style: TextStyle(color: _tipRenk(tip), fontSize: 12, fontWeight: FontWeight.w500)),
                      ])),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: aktif ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(aktif ? 'Aktif' : 'Pasif',
                            style: TextStyle(
                                color: aktif ? Colors.green : Colors.grey,
                                fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, size: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onSelected: (v) {
                          if (v == 'duzenle') _servisDuzenleDialog(context, id, d);
                          if (v == 'sil')     _silOnay(context, id, d['servisAdi'] ?? '');
                          if (v == 'pasif') {
                            FirebaseFirestore.instance.collection('services').doc(id)
                                .update({'aktif': !aktif, 'updatedAt': FieldValue.serverTimestamp()});
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'duzenle',
                              child: Row(children: [Icon(Icons.edit_rounded, color: Colors.blue, size: 16), SizedBox(width: 8), Text('Düzenle')])),
                          PopupMenuItem(value: 'pasif',
                              child: Row(children: [Icon(aktif ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.orange, size: 16), const SizedBox(width: 8), Text(aktif ? 'Pasif Yap' : 'Aktif Yap')])),
                          const PopupMenuItem(value: 'sil',
                              child: Row(children: [Icon(Icons.delete_rounded, color: Colors.red, size: 16), SizedBox(width: 8), Text('Sil', style: TextStyle(color: Colors.red))])),
                        ],
                      ),
                    ]),
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    Wrap(spacing: 12, runSpacing: 6, children: [
                      _bilgiCip(Icons.person_rounded,
                          _soforAd(d['surucuId']), Colors.blue),
                      _bilgiCip(Icons.directions_bus_rounded,
                          _aracAd(d['vehicleId']), Colors.teal),
                      if ((d['saatBaslangic'] ?? '').isNotEmpty)
                        _bilgiCip(Icons.access_time_rounded,
                            '${d['saatBaslangic']} — ${d['saatBitis'] ?? ''}', Colors.purple),
                      _bilgiCip(Icons.people_rounded,
                          '${d['ogrenciSayisi'] ?? 0} öğrenci', Colors.green),
                    ]),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _tipLabel(String tip) {
    switch (tip) {
      case 'sabah':   return 'Sabah Servisi';
      case 'aksam':   return 'Akşam Servisi';
      case 'ogle':    return 'Öğle Servisi';
      case 'tum_gun': return 'Tam Gün Servis';
      default:        return 'Diğer Servis';
    }
  }

  Widget _bilgiCip(IconData icon, String label, Color renk) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: renk.withValues(alpha: 0.2))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: renk),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(fontSize: 11, color: renk, fontWeight: FontWeight.w600)),
    ]),
  );

  void _servisEkleDialog(BuildContext context) {
    final adCtrl        = TextEditingController();
    final saatBCtrl     = TextEditingController();
    final saatECtrl     = TextEditingController();
    String tip          = 'sabah';
    String? surucuId;
    String? vehicleId;
    bool   aktif        = true;
    bool   yukleniyor   = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 500,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: Colors.white),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                    color: _navy,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                child: Row(children: [
                  const Icon(Icons.add_road_outlined, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Servis Ekle', style: TextStyle(color: Colors.white,
                        fontSize: 17, fontWeight: FontWeight.bold)),
                    Text('Proje → Servis → Araç → Şoför zinciri',
                        style: TextStyle(color: Colors.white60, fontSize: 11)),
                  ])),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx)),
                ]),
              ),
              Expanded(child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // Servis adı
                  const Text('Servis Adı', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _navy)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: adCtrl,
                    decoration: InputDecoration(
                      hintText: 'Sabah Servisi 1, Akşam Servisi...',
                      prefixIcon: const Icon(Icons.route_outlined, color: _navy, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Servis tipi
                  const Text('Servis Tipi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _navy)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _tipBtn('sabah',   '🌅 Sabah',   tip, (v) => setSt(() => tip = v)),
                    _tipBtn('aksam',   '🌙 Akşam',   tip, (v) => setSt(() => tip = v)),
                    _tipBtn('ogle',    '☀️ Öğle',   tip, (v) => setSt(() => tip = v)),
                    _tipBtn('tum_gun', '🔄 Tam Gün', tip, (v) => setSt(() => tip = v)),
                    _tipBtn('diger',   '🚐 Diğer',   tip, (v) => setSt(() => tip = v)),
                  ]),
                  const SizedBox(height: 14),

                  // Saatler
                  const Text('Servis Saatleri', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _navy)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: TextField(
                      controller: saatBCtrl,
                      decoration: InputDecoration(
                        labelText: 'Başlangıç (07:30)',
                        prefixIcon: const Icon(Icons.access_time_rounded, color: _navy, size: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(
                      controller: saatECtrl,
                      decoration: InputDecoration(
                        labelText: 'Bitiş (09:00)',
                        prefixIcon: const Icon(Icons.access_time_rounded, color: _navy, size: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    )),
                  ]),
                  const SizedBox(height: 14),

                  // Şoför seç
                  const Text('Şoför Ata (İsteğe Bağlı)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _navy)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                        labelText: 'Şoför seç',
                        prefixIcon: Icon(Icons.person_outlined),
                        border: OutlineInputBorder(), isDense: true),
                    value: surucuId,
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Şoför atanmadı')),
                      ..._soforler.map((s) => DropdownMenuItem(
                        value: s['id'] as String,
                        child: Text(s['adSoyad'] ?? s['ad'] ?? ''),
                      )),
                    ],
                    onChanged: (v) => setSt(() => surucuId = v?.isEmpty == true ? null : v),
                  ),
                  const SizedBox(height: 10),

                  // Araç seç
                  const Text('Araç Ata (İsteğe Bağlı)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _navy)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                        labelText: 'Araç seç',
                        prefixIcon: Icon(Icons.directions_bus_outlined),
                        border: OutlineInputBorder(), isDense: true),
                    value: vehicleId,
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Araç atanmadı')),
                      ..._araclar.map((a) => DropdownMenuItem(
                        value: a['id'] as String,
                        child: Text('${a['plaka'] ?? ''} — ${a['model'] ?? a['aracModeli'] ?? ''}'),
                      )),
                    ],
                    onChanged: (v) => setSt(() => vehicleId = v?.isEmpty == true ? null : v),
                  ),
                  const SizedBox(height: 10),

                  Row(children: [
                    const Text('Aktif', style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Switch(value: aktif, activeColor: Colors.green,
                        onChanged: (v) => setSt(() => aktif = v)),
                  ]),
                ]),
              )),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('İptal'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _navy, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: yukleniyor ? null : () async {
                      if (adCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                            content: Text('Servis adı zorunlu!'),
                            behavior: SnackBarBehavior.floating));
                        return;
                      }
                      setSt(() => yukleniyor = true);
                      try {
                        final now = FieldValue.serverTimestamp();
                        final soforAd = surucuId != null
                            ? _soforler.firstWhere((s) => s['id'] == surucuId, orElse: () => {})['adSoyad'] ?? ''
                            : '';
                        final aracPlaka = vehicleId != null
                            ? _araclar.firstWhere((a) => a['id'] == vehicleId, orElse: () => {})['plaka'] ?? ''
                            : '';

                        await FirebaseFirestore.instance.collection('services').add({
                          'servisAdi'     : adCtrl.text.trim(),
                          'ad'            : adCtrl.text.trim(),
                          'tip'           : tip,
                          'projeId'       : widget.projeId,
                          'firmaId'       : widget.firmaId,
                          'surucuId'      : surucuId,
                          'soforAd'       : soforAd,
                          'vehicleId'     : vehicleId,
                          'aracPlaka'     : aracPlaka,
                          'saatBaslangic' : saatBCtrl.text.trim(),
                          'saatBitis'     : saatECtrl.text.trim(),
                          'aktif'         : aktif,
                          'ogrenciSayisi' : 0,
                          'olusturma'     : now,
                          'updatedAt'     : now,
                        });

                        // Şoför ve araç güncelle
                        if (surucuId != null) {
                          await FirebaseFirestore.instance.collection('drivers').doc(surucuId).update({
                            'soforDurum': 'projeyeDahil',
                            'projeId': widget.projeId,
                            'updatedAt': now,
                          });
                        }
                        if (vehicleId != null) {
                          await FirebaseFirestore.instance.collection('vehicles').doc(vehicleId).update({
                            'durum': 'gorevde', 'updatedAt': now,
                          });
                        }

                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        setSt(() => yukleniyor = false);
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text('Hata: $e'),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating));
                      }
                    },
                    icon: yukleniyor
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save_rounded),
                    label: Text(yukleniyor ? 'Kaydediliyor...' : 'Servisi Kaydet',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  )),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _tipBtn(String deger, String label, String secili, Function(String) onChange) {
    final sec = secili == deger;
    return GestureDetector(
      onTap: () => onChange(deger),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
            color: sec ? _navy : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: sec ? _navy : Colors.grey.shade300)),
        child: Text(label, style: TextStyle(
            color: sec ? Colors.white : Colors.grey,
            fontSize: 12, fontWeight: sec ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  void _servisDuzenleDialog(BuildContext context, String id, Map<String, dynamic> d) {
    final adCtrl    = TextEditingController(text: d['servisAdi'] ?? d['ad'] ?? '');
    final saatBCtrl = TextEditingController(text: d['saatBaslangic'] ?? '');
    final saatECtrl = TextEditingController(text: d['saatBitis'] ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Servisi Düzenle'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: adCtrl,
              decoration: const InputDecoration(labelText: 'Servis Adı', border: OutlineInputBorder(), isDense: true)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: saatBCtrl,
                decoration: const InputDecoration(labelText: 'Başlangıç', border: OutlineInputBorder(), isDense: true))),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: saatECtrl,
                decoration: const InputDecoration(labelText: 'Bitiş', border: OutlineInputBorder(), isDense: true))),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('services').doc(id).update({
                'servisAdi'     : adCtrl.text.trim(),
                'ad'            : adCtrl.text.trim(),
                'saatBaslangic' : saatBCtrl.text.trim(),
                'saatBitis'     : saatECtrl.text.trim(),
                'updatedAt'     : FieldValue.serverTimestamp(),
              });
              if (_.mounted) Navigator.pop(_);
            },
            child: const Text('Kaydet')),
        ],
      ),
    );
  }

  Future<void> _silOnay(BuildContext context, String id, String ad) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Servisi Sil'),
        content: Text('$ad silinsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_, false), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(_, true),
            child: const Text('Sil', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (onay == true) {
      await FirebaseFirestore.instance.collection('services').doc(id).delete();
    }
  }
}

class AraclarTab extends StatelessWidget {
  final String projeId, firmaId;
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  const AraclarTab({super.key, required this.projeId, required this.firmaId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _turuncu, foregroundColor: Colors.white,
        onPressed: () => _aracEkleDialog(context),
        icon: const Icon(Icons.directions_bus_outlined),
        label: const Text('Arac Ekle'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('vehicles').where('projeId', isEqualTo: projeId).snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.directions_bus_outlined, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 12),
              const Text('Henuz arac eklenmemis', style: TextStyle(color: Colors.grey)),
            ]));
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d     = docs[i].data() as Map<String, dynamic>;
              final id    = docs[i].id;
              final aktif = d['servisAktif'] ?? false;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
                ),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: aktif ? Colors.green.withValues(alpha: 0.1) : _navy.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.directions_bus_outlined, color: aktif ? Colors.green : _navy, size: 22)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d['plaka'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('${d['marka'] ?? ''} · ${d['kapasite'] ?? 0} kisilik', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    if ((d['soforAd'] ?? '').isNotEmpty)
                      Text('Sofor: ${d['soforAd']}', style: TextStyle(color: Colors.blue[700], fontSize: 11)),
                  ])),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: aktif ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(aktif ? 'Aktif' : 'Pasif', style: TextStyle(color: aktif ? Colors.green : Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                        onPressed: () => FirebaseFirestore.instance.collection('vehicles').doc(id).delete()),
                  ]),
                ]),
              );
            },
          );
        },
      ),
    );
  }

  void _aracEkleDialog(BuildContext context) {
    final plakaCtrl    = TextEditingController();
    final markaCtrl    = TextEditingController();
    final kapasiteCtrl = TextEditingController();
    String? seciliSoforId;
    String? seciliSoforAd;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Padding(padding: const EdgeInsets.all(24), child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Arac Ekle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _navy)),
            const SizedBox(height: 16),
            _InputAlan(ctrl: plakaCtrl,    label: 'Plaka *',  ikon: Icons.directions_bus_outlined),
            const SizedBox(height: 10),
            _InputAlan(ctrl: markaCtrl,    label: 'Marka',    ikon: Icons.build_outlined),
            const SizedBox(height: 10),
            _InputAlan(ctrl: kapasiteCtrl, label: 'Kapasite', ikon: Icons.people_outline, tipi: TextInputType.number),
            const SizedBox(height: 12),
            const Text('Sofor Ata', style: TextStyle(fontWeight: FontWeight.bold, color: _navy, fontSize: 13)),
            const SizedBox(height: 8),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('drivers').where('projeId', isEqualTo: projeId).snapshots(),
              builder: (_, snap) {
                final soforler = snap.data?.docs ?? [];
                if (soforler.isEmpty) return const Text('Bu projede sofor yok', style: TextStyle(color: Colors.grey, fontSize: 12));
                return Wrap(spacing: 8, runSpacing: 8, children: soforler.map((s) {
                  final sd  = s.data() as Map<String, dynamic>;
                  final sec = seciliSoforId == s.id;
                  return GestureDetector(
                    onTap: () => setS(() { seciliSoforId = sec ? null : s.id; seciliSoforAd = sec ? null : sd['ad']; }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: sec ? _navy : Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: sec ? _navy : Colors.grey.shade300)),
                      child: Text(sd['ad'] ?? '', style: TextStyle(color: sec ? Colors.white : Colors.black87, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  );
                }).toList());
              },
            ),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () async {
                if (plakaCtrl.text.trim().isEmpty) return;
                await FirebaseFirestore.instance.collection('vehicles').add({
                  'firmaId': firmaId, 'projeId': projeId,
                  'plaka': plakaCtrl.text.trim().toUpperCase(), 'marka': markaCtrl.text.trim(),
                  'kapasite': int.tryParse(kapasiteCtrl.text) ?? 0,
                  'soforId': seciliSoforId ?? '', 'soforAd': seciliSoforAd ?? '',
                  'servisAktif': false, 'olusturma': FieldValue.serverTimestamp(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Arac Ekle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            )),
          ],
        )),
      )),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  FİYATLAR SEKMESİ
// ════════════════════════════════════════════════════════════════
class _ProjeFiyatTab extends StatefulWidget {
  final String projeId, firmaId;
  const _ProjeFiyatTab({required this.projeId, required this.firmaId});
  @override
  State<_ProjeFiyatTab> createState() => _ProjeFiyatTabState();
}

class _ProjeFiyatTabState extends State<_ProjeFiyatTab> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  String _filtre = '';

  Widget _fiyatInput(TextEditingController ctrl, String label, IconData ikon,
      {TextInputType tipi = TextInputType.text}) =>
      TextField(controller: ctrl, keyboardType: tipi,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(ikon, color: _navy, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _navy, foregroundColor: Colors.white,
        onPressed: () => _ekleDialog(context),
        icon: const Icon(Icons.add), label: const Text('Fiyat Ekle'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('fiyatlar').where('projeId', isEqualTo: widget.projeId).snapshots(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: _navy));
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.attach_money_outlined, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 12),
              const Text('Henuz fiyat eklenmemis', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 4),
              const Text('Ornek: Kadikoy / Moda / 1500 TL', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ]));
          }
          final ilceler = docs.map((d) => (d.data() as Map)['ilce'] as String? ?? '').toSet().toList()..sort();
          final filtered = _filtre.isEmpty ? docs : docs.where((d) => (d.data() as Map)['ilce'] == _filtre).toList();
          return Column(children: [
            Container(color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: SingleChildScrollView(scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _FiyatChip('Tumu', '', _filtre, (v) => setState(() => _filtre = v)),
                  const SizedBox(width: 6),
                  ...ilceler.map((i) => Padding(padding: const EdgeInsets.only(right: 6),
                      child: _FiyatChip(i, i, _filtre, (v) => setState(() => _filtre = v)))),
                ]),
              ),
            ),
            Container(margin: const EdgeInsets.fromLTRB(12, 8, 12, 0), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(8)),
              child: const Row(children: [
                Expanded(flex: 3, child: Text('Ilce',    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                Expanded(flex: 4, child: Text('Mahalle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                SizedBox(width: 90, child: Text('Fiyat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
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
                  decoration: BoxDecoration(color: bg, border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.12)))),
                  child: Row(children: [
                    Expanded(flex: 3, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        child: Text(d['ilce'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)))),
                    Expanded(flex: 4, child: Text(d['mahalle'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[700]))),
                    SizedBox(width: 90, child: Text('${(d['fiyat'] as num? ?? 0).toStringAsFixed(0)} TL',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: _turuncu, fontSize: 12), textAlign: TextAlign.right)),
                    IconButton(icon: const Icon(Icons.edit_outlined, size: 14, color: Colors.grey),
                        onPressed: () => _duzenleDialog(context, doc.id, d),
                        splashRadius: 14, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
                  ]),
                );
              },
            )),
            Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), color: Colors.white,
              child: Row(children: [
                Text('${filtered.length} kayit', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                const Spacer(),
                if (_filtre.isNotEmpty) Text(_filtre, style: const TextStyle(color: _navy, fontSize: 11, fontWeight: FontWeight.bold)),
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
    showDialog(context: ctx, builder: (_) => StatefulBuilder(builder: (c, ss) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Fiyat Ekle', style: TextStyle(color: Color(0xFF1a3a6b), fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _fiyatInput(iCtrl, 'Ilce *',       Icons.location_city_outlined),
        const SizedBox(height: 8),
        _fiyatInput(mCtrl, 'Mahalle *',    Icons.maps_home_work_outlined),
        const SizedBox(height: 8),
        _fiyatInput(fCtrl, 'Ucret (TL) *', Icons.attach_money, tipi: TextInputType.number),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Iptal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1a3a6b), foregroundColor: Colors.white),
          onPressed: yuk ? null : () async {
            if (iCtrl.text.trim().isEmpty || mCtrl.text.trim().isEmpty || fCtrl.text.trim().isEmpty) return;
            ss(() => yuk = true);
            await FirebaseFirestore.instance.collection('fiyatlar').add({
              'firmaId': widget.firmaId, 'projeId': widget.projeId, 'tip': 'mahalle',
              'ilce': iCtrl.text.trim(), 'mahalle': mCtrl.text.trim(),
              'fiyat': double.tryParse(fCtrl.text.trim()) ?? 0.0, 'olusturma': FieldValue.serverTimestamp(),
            });
            if (c.mounted) Navigator.pop(c);
          },
          child: yuk ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Ekle'),
        ),
      ],
    )));
  }

  void _duzenleDialog(BuildContext ctx, String id, Map<String, dynamic> d) {
    final iCtrl = TextEditingController(text: d['ilce'] ?? '');
    final mCtrl = TextEditingController(text: d['mahalle'] ?? '');
    final fCtrl = TextEditingController(text: (d['fiyat'] ?? 0).toString());
    showDialog(context: ctx, builder: (_) => StatefulBuilder(builder: (c, ss) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Duzenle', style: TextStyle(color: Color(0xFF1a3a6b), fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        _fiyatInput(iCtrl, 'Ilce',    Icons.location_city_outlined),
        const SizedBox(height: 8),
        _fiyatInput(mCtrl, 'Mahalle', Icons.maps_home_work_outlined),
        const SizedBox(height: 8),
        _fiyatInput(fCtrl, 'Ucret',   Icons.attach_money, tipi: TextInputType.number),
      ]),
      actions: [
        TextButton(onPressed: () async { await FirebaseFirestore.instance.collection('fiyatlar').doc(id).delete(); if (c.mounted) Navigator.pop(c); },
            child: const Text('Sil', style: TextStyle(color: Colors.red))),
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Iptal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1a3a6b), foregroundColor: Colors.white),
          onPressed: () async {
            await FirebaseFirestore.instance.collection('fiyatlar').doc(id).update({
              'ilce': iCtrl.text.trim(), 'mahalle': mCtrl.text.trim(), 'fiyat': double.tryParse(fCtrl.text.trim()) ?? 0.0,
            });
            if (c.mounted) Navigator.pop(c);
          },
          child: const Text('Kaydet'),
        ),
      ],
    )));
  }
}

// ════════════════════════════════════════════════════════════════
//  SÖZLEŞME SEKMESİ
// ════════════════════════════════════════════════════════════════
class _ProjeSozlesmeTab extends StatefulWidget {
  final String projeId;
  const _ProjeSozlesmeTab({required this.projeId});
  @override
  State<_ProjeSozlesmeTab> createState() => _ProjeSozlesmeTabState();
}

class _ProjeSozlesmeTabState extends State<_ProjeSozlesmeTab> {
  static const _navy   = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);

  final _bilgiCtrl = TextEditingController();
  bool _yukleniyor   = true;
  bool _kaydediliyor = false;

  String? _firmaId;
  String? _seciliSablonId;
  String  _seciliSablonAd = '';
  List<Map<String, dynamic>> _sablonlar = [];

  @override
  void initState() { super.initState(); _yukle(); }

  @override
  void dispose() { _bilgiCtrl.dispose(); super.dispose(); }

  Future<void> _yukle() async {
    try {
      // Proje verisini yükle
      final projeDoc = await FirebaseFirestore.instance
          .collection('projects').doc(widget.projeId).get();
      _bilgiCtrl.text = projeDoc.data()?['bilgilendirme'] ?? '';
      _seciliSablonId = projeDoc.data()?['sozlesmeSablonId'] as String?;
      _firmaId        = projeDoc.data()?['firmaId'] as String?;

      // Firma şablonlarını yükle
      if (_firmaId != null) {
        final sabSnap = await FirebaseFirestore.instance
            .collection('firms').doc(_firmaId)
            .collection('sozlesme_sablonlar').get();
        _sablonlar = sabSnap.docs
            .map((d) => {'id': d.id, ...d.data()}).toList();

        if (_seciliSablonId != null) {
          _seciliSablonAd = _sablonlar.firstWhere(
              (s) => s['id'] == _seciliSablonId,
              orElse: () => {})['ad'] ?? '';
        }
      }
    } catch (e) { debugPrint('ProjeSozlesme hata: $e'); }
    if (mounted) setState(() => _yukleniyor = false);
  }

  Future<void> _kaydet() async {
    setState(() => _kaydediliyor = true);
    try {
      await FirebaseFirestore.instance
          .collection('projects').doc(widget.projeId).update({
        'bilgilendirme'    : _bilgiCtrl.text.trim(),
        'sozlesmeSablonId' : _seciliSablonId,
        'sozlesmeSablonAd' : _seciliSablonAd,
        'updatedAt'        : FieldValue.serverTimestamp(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kaydedildi!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _kaydediliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Bilgi notu
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _orange.withValues(alpha: 0.3))),
          child: Row(children: [
            const Icon(Icons.info_outline, color: _orange, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(
              'Seçilen şablon velilere kayıt formunda gösterilecektir.',
              style: TextStyle(fontSize: 12,
                  color: Colors.orange.shade800, fontWeight: FontWeight.w600))),
          ]),
        ),
        const SizedBox(height: 20),

        // Şablon seçici
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6)]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: _navy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.description_outlined, color: _navy, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Sözleşme Şablonu', style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14)),
                Text('Bu proje için kullanılacak sözleşme',
                    style: TextStyle(color: Colors.grey, fontSize: 11)),
              ])),
              TextButton.icon(
                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                label: const Text('Şablon Yönet', style: TextStyle(fontSize: 11)),
                onPressed: () => Navigator.pushNamed(context, '/sozlesme_yonetim'),
              ),
            ]),
            const SizedBox(height: 14),

            if (_sablonlar.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200)),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.orange, size: 18),
                  const SizedBox(width: 10),
                  const Expanded(child: Text(
                    'Henüz sözlesme sablonu olusturulmadi. '
                    '"Sablon Yonet" butonuna tiklayarak olusturun.',
                    style: TextStyle(fontSize: 12, color: Colors.orange))),
                ]),
              )
            else
              DropdownButtonFormField<String>(
                value: _seciliSablonId,
                decoration: const InputDecoration(
                    labelText: 'Şablon Seç',
                    prefixIcon: Icon(Icons.description_outlined),
                    border: OutlineInputBorder(), isDense: true),
                hint: const Text('Şablon seçin'),
                items: [
                  const DropdownMenuItem<String>(
                      value: '', child: Text('Şablon kullanma')),
                  ..._sablonlar.map((s) => DropdownMenuItem(
                    value: s['id'] as String,
                    child: Row(children: [
                      Text(s['ad'] ?? ''),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4)),
                        child: Text(s['tip'] ?? '',
                            style: const TextStyle(
                                fontSize: 10, color: Colors.blue)),
                      ),
                    ]),
                  )),
                ],
                onChanged: (v) => setState(() {
                  _seciliSablonId = v?.isEmpty == true ? null : v;
                  _seciliSablonAd = _sablonlar.firstWhere(
                      (s) => s['id'] == v, orElse: () => {})['ad'] ?? '';
                }),
              ),

            // Seçili şablon önizleme
            if (_seciliSablonId != null && _seciliSablonId!.isNotEmpty) ...[
              const SizedBox(height: 12),
              FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('firms').doc(_firmaId)
                    .collection('sozlesme_sablonlar')
                    .doc(_seciliSablonId).get(),
                builder: (_, snap) {
                  if (!snap.hasData) return const SizedBox.shrink();
                  final data = snap.data?.data() as Map<String,dynamic>? ?? {};
                  final maddeler = List<Map<String,dynamic>>.from(
                      data['maddeler'] ?? [])
                      .where((m) => m['aktif'] == true).toList();
                  final ozel = List<Map<String,dynamic>>.from(
                      data['ozelMaddeler'] ?? []);
                  final toplam = maddeler.length + ozel.length;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade200)),
                    child: Row(children: [
                      const Icon(Icons.check_circle_outline,
                          color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Text('$toplam madde seçili — $_seciliSablonAd',
                          style: const TextStyle(
                              color: Colors.green, fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ]),
                  );
                },
              ),
            ],
          ]),
        ),
        const SizedBox(height: 16),

        // Bilgilendirme metni
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.info_outlined, color: Colors.blue, size: 18),
              SizedBox(width: 8),
              Text('Bilgilendirme Metni',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ]),
            const SizedBox(height: 4),
            const Text('Kayıt formunun üstünde gösterilir',
                style: TextStyle(color: Colors.grey, fontSize: 11)),
            const SizedBox(height: 12),
            TextField(
              controller: _bilgiCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Örnek: 2026-2027 okul servisi kayıt formu...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                filled: true, fillColor: const Color(0xFFF8F9FA),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        // Kaydet
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _kaydediliyor ? null : _kaydet,
          style: ElevatedButton.styleFrom(
              backgroundColor: _orange, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          icon: _kaydediliyor
              ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.save_rounded),
          label: Text(_kaydediliyor ? 'Kaydediliyor...' : 'Kaydet',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold)),
        )),
      ]),
    );
  }
}

class _SozlesmeKart extends StatelessWidget {
  final String baslik, aciklama, hint;
  final IconData ikon; final Color renk;
  final TextEditingController ctrl; final int satir;
  static const _navy = Color(0xFF1a3a6b);
  const _SozlesmeKart({required this.baslik, required this.aciklama, required this.hint, required this.ikon, required this.renk, required this.ctrl, required this.satir});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))]),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: renk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(ikon, color: renk, size: 18)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(baslik, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
            Text(aciklama, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ]),
        ]),
        const SizedBox(height: 14),
        TextField(controller: ctrl, maxLines: satir, style: const TextStyle(fontSize: 13, height: 1.6),
          decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _navy)),
              contentPadding: const EdgeInsets.all(14)),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  KAYIT LİNKİ SEKMESİ
// ════════════════════════════════════════════════════════════════
class _ProjeKayitLinkiTab extends StatefulWidget {
  final String projeId, firmaId, projeAdi;
  const _ProjeKayitLinkiTab({required this.projeId, required this.firmaId, required this.projeAdi});
  @override
  State<_ProjeKayitLinkiTab> createState() => _ProjeKayitLinkiTabState();
}

class _ProjeKayitLinkiTabState extends State<_ProjeKayitLinkiTab> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _orange  = Color(0xFFFF8C00);
  static const _baseUrl = 'https://servis360-15b4a.web.app/kayit';
  final _mesajCtrl    = TextEditingController();
  bool _olusturuluyor = false;
  bool _yukleniyor    = true;
  List<Map<String, dynamic>> _linkler = [];
  String _firmaAdi = '';

  @override
  void initState() { super.initState(); _yukle(); }

  @override
  void dispose() { _mesajCtrl.dispose(); super.dispose(); }

  Future<void> _yukle() async {
    final firmaDoc = await FirebaseFirestore.instance.collection('firms').doc(widget.firmaId).get();
    _firmaAdi = firmaDoc.data()?['firmaAdi'] ?? firmaDoc.data()?['ad'] ?? '';
    final snap = await FirebaseFirestore.instance.collection('kayit_linkleri')
        .where('projeId', isEqualTo: widget.projeId).where('aktif', isEqualTo: true)
        .orderBy('olusturma', descending: true).get();
    setState(() {
      _linkler = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      _yukleniyor = false;
    });
  }

  Future<void> _linkOlustur() async {
    setState(() => _olusturuluyor = true);
    try {
      final gecerlilikBitis = DateTime.now().add(const Duration(days: 30));
      final docRef = await FirebaseFirestore.instance.collection('kayit_linkleri').add({
        'firmaId': widget.firmaId, 'firmaAdi': _firmaAdi,
        'projeId': widget.projeId, 'projeAdi': widget.projeAdi,
        'ozelMesaj': _mesajCtrl.text.trim(), 'aktif': true, 'kullanim': 0,
        'gecerlilikGun': 30, 'gecerlilikBitis': Timestamp.fromDate(gecerlilikBitis), 'olusturma': Timestamp.now(),
      });
      setState(() {
        _linkler.insert(0, {'id': docRef.id, 'firmaAdi': _firmaAdi, 'projeAdi': widget.projeAdi,
          'ozelMesaj': _mesajCtrl.text.trim(), 'kullanim': 0, 'gecerlilikBitis': Timestamp.fromDate(gecerlilikBitis)});
        _mesajCtrl.clear(); _olusturuluyor = false;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link olusturuldu!'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
    } catch (e) {
      setState(() => _olusturuluyor = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
    }
  }

  String _wpMesaji(String linkId) {
    final url = '$_baseUrl?link=$linkId';
    return 'Sayin Velimiz,\n\n${_firmaAdi.isNotEmpty ? '$_firmaAdi - ' : ''}${widget.projeAdi} icin Servisim360 uygulamasina kayit olmanizi rica ediyoruz.\n\n--- Kayit Adimlariniz ---\n\n1. Asagidaki linkten kayit formunu doldurun:\n$url\n\n2. Uygulamayi Play Store\'dan indirin:\nhttps://play.google.com/store/apps/details?id=com.servisim.servisim\n\n3. Kaydiniz onaylandiktan sonra giris yapabilirsiniz.\n\nServisim360 - Akilli Servis Yonetimi';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))]),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 4, height: 22, decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              const Text('Yeni Kayit Linki Olustur', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0d1f3c))),
            ]),
            const SizedBox(height: 14),
            Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: _navy.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.folder_outlined, color: _navy, size: 16), const SizedBox(width: 8),
                Expanded(child: Text(widget.projeAdi, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _navy))),
              ]),
            ),
            const SizedBox(height: 12),
            TextField(controller: _mesajCtrl, maxLines: 2, style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(hintText: 'Ozel mesaj (opsiyonel)...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _navy)),
                  contentPadding: const EdgeInsets.all(12)),
            ),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: _olusturuluyor ? null : _linkOlustur,
              style: ElevatedButton.styleFrom(backgroundColor: _orange, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _olusturuluyor ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Link Olustur', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            )),
          ]),
        ),
        const SizedBox(height: 20),
        if (_yukleniyor) const Center(child: CircularProgressIndicator())
        else if (_linkler.isNotEmpty) ...[
          const Text('Aktif Linkler', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0d1f3c))),
          const SizedBox(height: 12),
          ..._linkler.map((link) => _LinkKarti(
            link: link, baseUrl: _baseUrl, whatsappMesaji: _wpMesaji(link['id']),
            onDeaktif: () async {
              await FirebaseFirestore.instance.collection('kayit_linkleri').doc(link['id']).update({'aktif': false});
              setState(() => _linkler.remove(link));
            },
          )),
        ],
      ]),
    );
  }
}

class _LinkKarti extends StatelessWidget {
  final Map<String, dynamic> link;
  final String baseUrl, whatsappMesaji;
  final VoidCallback onDeaktif;
  static const _navy = Color(0xFF1a3a6b);
  const _LinkKarti({required this.link, required this.baseUrl, required this.whatsappMesaji, required this.onDeaktif});

  @override
  Widget build(BuildContext context) {
    final linkId   = link['id'] as String;
    final url      = '$baseUrl?link=$linkId';
    final kullanim = link['kullanim'] ?? 0;
    final Timestamp? bitis = link['gecerlilikBitis'];
    String bitisStr = '';
    if (bitis != null) { final d = bitis.toDate(); bitisStr = '${d.day}.${d.month}.${d.year}'; }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: const BoxDecoration(color: _navy, borderRadius: BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14))),
          child: Row(children: [
            const Icon(Icons.link, color: Colors.white70, size: 16), const SizedBox(width: 8),
            Expanded(child: Text(url, style: const TextStyle(color: Colors.white, fontSize: 11), overflow: TextOverflow.ellipsis)),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                child: Text('$kullanim kayit', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
          ]),
        ),
        Padding(padding: const EdgeInsets.all(12), child: Column(children: [
          if (bitisStr.isNotEmpty)
            Padding(padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [const Icon(Icons.access_time, size: 13, color: Colors.grey), const SizedBox(width: 6),
                  Text('Gecerlilik: $bitisStr', style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600))])),
          Row(children: [
            Expanded(child: _LinkBtn(Icons.copy, 'Kopyala', _navy, () {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link kopyalandi!'), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
            })),
            const SizedBox(width: 8),
            Expanded(child: _LinkBtn(Icons.chat, 'WhatsApp', const Color(0xFF25D366), () {
              Clipboard.setData(ClipboardData(text: whatsappMesaji));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('WhatsApp mesaji kopyalandi!'), backgroundColor: Color(0xFF25D366), behavior: SnackBarBehavior.floating));
            })),
            const SizedBox(width: 8),
            _LinkBtn(Icons.delete_outline, '', Colors.red, onDeaktif, small: true),
          ]),
        ])),
      ]),
    );
  }
}

class _LinkBtn extends StatelessWidget {
  final IconData ikon; final String label; final Color color; final VoidCallback onTap; final bool small;
  const _LinkBtn(this.ikon, this.label, this.color, this.onTap, {this.small = false});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: small ? 12 : 10, vertical: 10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.2))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(ikon, size: 16, color: color),
          if (label.isNotEmpty) ...[const SizedBox(width: 6), Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color))],
        ]),
      ));
}

class _FiyatChip extends StatelessWidget {
  final String etiket, deger, secili; final ValueChanged<String> onSec;
  const _FiyatChip(this.etiket, this.deger, this.secili, this.onSec);
  @override
  Widget build(BuildContext context) {
    final aktif = secili == deger;
    return GestureDetector(onTap: () => onSec(deger),
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: aktif ? const Color(0xFF1a3a6b) : const Color(0xFFF0F2F5), borderRadius: BorderRadius.circular(20)),
            child: Text(etiket, style: TextStyle(color: aktif ? Colors.white : Colors.grey[600], fontSize: 11, fontWeight: aktif ? FontWeight.bold : FontWeight.normal))));
  }
}

// ════════════════════════════════════════════════════════════════
//  ORTAK WIDGET'LAR
// ════════════════════════════════════════════════════════════════
class _InputAlan extends StatelessWidget {
  final TextEditingController ctrl;
  final String label; final IconData ikon;
  final TextInputType tipi; final int satir;
  static const _navy = Color(0xFF1a3a6b);
  const _InputAlan({required this.ctrl, required this.label, required this.ikon, this.tipi = TextInputType.text, this.satir = 1});
  @override
  Widget build(BuildContext context) => TextField(controller: ctrl, keyboardType: tipi, maxLines: satir,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(ikon, color: _navy, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _navy, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14)));
}

class _TipChip extends StatelessWidget {
  final String deger, etiket, secili; final IconData ikon; final ValueChanged<String> onSec;
  static const _navy = Color(0xFF1a3a6b);
  const _TipChip(this.deger, this.etiket, this.ikon, this.secili, this.onSec);
  @override
  Widget build(BuildContext context) {
    final aktif = secili == deger;
    return Expanded(child: GestureDetector(onTap: () => onSec(deger),
        child: Container(padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: aktif ? _navy : Colors.grey[50], borderRadius: BorderRadius.circular(10),
                border: Border.all(color: aktif ? _navy : Colors.grey.withValues(alpha: 0.3))),
            child: Column(children: [
              Icon(ikon, color: aktif ? Colors.white : Colors.grey, size: 18),
              const SizedBox(height: 4),
              Text(etiket, style: TextStyle(fontSize: 11, color: aktif ? Colors.white : Colors.grey, fontWeight: aktif ? FontWeight.bold : FontWeight.normal)),
            ]))));
  }
}

class _MiniStat extends StatelessWidget {
  final String deger, etiket; final IconData ikon; final Color renk;
  const _MiniStat(this.deger, this.etiket, this.ikon, this.renk);
  @override
  Widget build(BuildContext context) => Column(children: [
    Icon(ikon, color: renk, size: 18),
    const SizedBox(height: 4),
    Text(deger, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: renk)),
    Text(etiket, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
  ]);
}

class _AksiyonButon extends StatelessWidget {
  final IconData ikon; final String etiket; final Color renk; final VoidCallback onTap;
  const _AksiyonButon(this.ikon, this.etiket, this.renk, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
      child: Container(padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: renk.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: renk.withValues(alpha: 0.2))),
          child: Column(children: [Icon(ikon, color: renk, size: 16), const SizedBox(height: 3), Text(etiket, style: TextStyle(color: renk, fontSize: 9, fontWeight: FontWeight.w600))])));
}

class _HizliLink extends StatelessWidget {
  final IconData ikon; final Color renk; final String baslik; final VoidCallback onTap;
  const _HizliLink(this.ikon, this.renk, this.baslik, this.onTap);
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12),
      child: Container(padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: renk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(ikon, color: renk, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Text(baslik, style: const TextStyle(fontWeight: FontWeight.w500))),
            const Icon(Icons.arrow_forward_ios_outlined, size: 14, color: Colors.grey),
          ])));
}
