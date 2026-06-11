import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/session_service.dart';

// ════════════════════════════════════════════════════════════════
//  BİLDİRİMLER EKRANI v2
//  - Gelen bildirimler listesi
//  - Manuel bildirim gönder
//  - Bildirim türleri
// ════════════════════════════════════════════════════════════════
class BildirimlerScreen extends StatefulWidget {
  const BildirimlerScreen({super.key});
  @override
  State<BildirimlerScreen> createState() => _BildirimlerScreenState();
}

class _BildirimlerScreenState extends State<BildirimlerScreen>
    with SingleTickerProviderStateMixin {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  late TabController _tab;
  String _firmaId = '';
  String _projeId = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _yukle();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _yukle() async {
    _firmaId = await SessionService.instance.firmaIdAl() ?? '';
    _projeId = SessionService.instance.aktifProjeId ?? '';
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      color: Colors.white,
      child: TabBar(
        controller: _tab,
        labelColor: _navy,
        unselectedLabelColor: Colors.grey,
        indicatorColor: _turuncu,
        tabs: const [
          Tab(icon: Icon(Icons.notifications_outlined), text: 'Bildirimler'),
          Tab(icon: Icon(Icons.send_outlined), text: 'Gönder'),
          Tab(icon: Icon(Icons.auto_awesome_outlined), text: 'Otomatik'),
        ],
      ),
    ),
    Expanded(child: TabBarView(controller: _tab, children: [
      _BildirimListesi(firmaId: _firmaId, projeId: _projeId),
      _BildirimGonder(firmaId: _firmaId, projeId: _projeId),
    ])),
  ]);
}

// ── Bildirim Listesi ──────────────────────────────────────────
class _BildirimListesi extends StatelessWidget {
  final String firmaId, projeId;
  static const _navy = Color(0xFF1a3a6b);
  const _BildirimListesi({required this.firmaId, required this.projeId});

  @override
  Widget build(BuildContext context) {
    if (firmaId.isEmpty) return const Center(
        child: CircularProgressIndicator(color: _navy));

    Query q = FirebaseFirestore.instance
        .collection('bildirimler')
        .where('firmaId', isEqualTo: firmaId)
        .orderBy('zaman', descending: true)
        .limit(50);

    if (projeId.isNotEmpty) {
      q = q.where('projeId', isEqualTo: projeId);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: q.snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _navy));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.notifications_none_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 12),
              Text('Henüz bildirim yok', style: TextStyle(color: Colors.grey, fontSize: 16)),
            ],
          ));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d   = docs[i].data() as Map<String, dynamic>;
            final tip = d['tip'] as String? ?? 'genel';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _tipRenk(tip).withValues(alpha: 0.2)),
                boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03), blurRadius: 4)],
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: _tipRenk(tip).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(_tipIkon(tip), color: _tipRenk(tip), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d['mesaj'] as String? ?? '',
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 13)),
                  if ((d['ogrenciAd'] ?? d['soforAd'] ?? '').isNotEmpty)
                    Text(d['ogrenciAd'] ?? d['soforAd'] ?? '',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[500])),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: _tipRenk(tip).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(_tipAd(tip),
                      style: TextStyle(
                          fontSize: 10,
                          color: _tipRenk(tip),
                          fontWeight: FontWeight.bold)),
                ),
              ]),
            );
          },
        );
      },
    );
  }

  Color _tipRenk(String tip) {
    switch (tip) {
      case 'servis_basladi': return Colors.green;
      case 'yaklasisyor':    return const Color(0xFFFF8C00);
      case 'devamsizlik':    return Colors.red;
      case 'ogrenci_alindi': return Colors.blue;
      case 'acil':           return Colors.red;
      default:               return const Color(0xFF1a3a6b);
    }
  }

  IconData _tipIkon(String tip) {
    switch (tip) {
      case 'servis_basladi': return Icons.play_circle_outlined;
      case 'yaklasisyor':    return Icons.directions_bus_outlined;
      case 'devamsizlik':    return Icons.event_busy_outlined;
      case 'ogrenci_alindi': return Icons.check_circle_outlined;
      case 'acil':           return Icons.emergency_outlined;
      default:               return Icons.notifications_outlined;
    }
  }

  String _tipAd(String tip) {
    switch (tip) {
      case 'servis_basladi': return 'Servis';
      case 'yaklasisyor':    return 'Yaklaşıyor';
      case 'devamsizlik':    return 'Devamsızlık';
      case 'ogrenci_alindi': return 'Alındı';
      case 'acil':           return 'ACİL';
      default:               return 'Genel';
    }
  }
}

// ── Manuel Bildirim Gönder ────────────────────────────────────
class _BildirimGonder extends StatefulWidget {
  final String firmaId, projeId;
  const _BildirimGonder({required this.firmaId, required this.projeId});
  @override
  State<_BildirimGonder> createState() => _BildirimGonderState();
}

class _BildirimGonderState extends State<_BildirimGonder> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  final _mesajCtrl = TextEditingController();
  String _hedef    = 'tumu'; // tumu | soforler | veliler
  String _tip      = 'genel';
  bool   _gonderiliyor = false;

  @override
  void dispose() { _mesajCtrl.dispose(); super.dispose(); }

  Future<void> _gonder() async {
    if (_mesajCtrl.text.trim().isEmpty) return;
    setState(() => _gonderiliyor = true);
    try {
      await FirebaseFirestore.instance.collection('bildirimler').add({
        'firmaId' : widget.firmaId,
        'projeId' : widget.projeId,
        'mesaj'   : _mesajCtrl.text.trim(),
        'tip'     : _tip,
        'hedef'   : _hedef,
        'zaman'   : FieldValue.serverTimestamp(),
        'okundu'  : false,
        'manuel'  : true,
      });
      _mesajCtrl.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Bildirim gönderildi!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating));
    }
    setState(() => _gonderiliyor = false);
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.send_outlined, color: _navy, size: 20),
            SizedBox(width: 8),
            Text('Manuel Bildirim Gönder',
                style: TextStyle(fontWeight: FontWeight.bold,
                    color: _navy, fontSize: 16)),
          ]),
          const Divider(height: 24),

          // Hedef kitle
          const Text('Hedef Kitle',
              style: TextStyle(fontWeight: FontWeight.bold,
                  color: _navy, fontSize: 13)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            _hedefChip('tumu',     'Tümü',    Icons.people_outline),
            _hedefChip('soforler', 'Şoförler', Icons.directions_car_outlined),
            _hedefChip('veliler',  'Veliler',  Icons.family_restroom_outlined),
          ]),
          const SizedBox(height: 16),

          // Bildirim tipi
          const Text('Bildirim Türü',
              style: TextStyle(fontWeight: FontWeight.bold,
                  color: _navy, fontSize: 13)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _tipChip('genel',          'Genel',       Icons.notifications_outlined),
            _tipChip('servis_basladi', 'Servis',      Icons.play_circle_outlined),
            _tipChip('yaklasisyor',    'Yaklaşıyor',  Icons.directions_bus_outlined),
            _tipChip('devamsizlik',    'Devamsızlık', Icons.event_busy_outlined),
            _tipChip('acil',           'Acil Durum',  Icons.emergency_outlined),
          ]),
          const SizedBox(height: 16),

          // Mesaj
          TextField(
            controller: _mesajCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Bildirim Mesajı *',
              hintText: 'Velilere veya şoförlere iletmek istediğiniz mesajı yazın...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 60),
                  child: Icon(Icons.message_outlined, color: _navy)),
            ),
          ),
          const SizedBox(height: 20),

          // Gönder butonu
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _navy, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              onPressed: _gonderiliyor ? null : _gonder,
              icon: _gonderiliyor
                  ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_outlined),
              label: Text(_gonderiliyor ? 'Gönderiliyor...' : 'Bildirim Gönder',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),

          // Bilgi notu
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10)),
            child: const Row(children: [
              Icon(Icons.info_outline, size: 16, color: Colors.blue),
              SizedBox(width: 8),
              Expanded(child: Text(
                  'Push bildirim için FCM entegrasyonu gereklidir. '
                      'Uygulama içi bildirimler anlık çalışır.',
                  style: TextStyle(fontSize: 12, color: Colors.blue))),
            ]),
          ),
        ]),
      ),
    )),
  );

  Widget _hedefChip(String deger, String etiket, IconData ikon) {
    final secili = _hedef == deger;
    return GestureDetector(
      onTap: () => setState(() => _hedef = deger),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: secili ? _navy : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: secili ? _navy : Colors.grey.shade300),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(ikon, size: 14, color: secili ? Colors.white : Colors.grey),
          const SizedBox(width: 6),
          Text(etiket, style: TextStyle(
              fontSize: 12,
              color: secili ? Colors.white : Colors.grey[700],
              fontWeight: secili ? FontWeight.bold : FontWeight.normal)),
        ]),
      ),
    );
  }

  Widget _tipChip(String deger, String etiket, IconData ikon) {
    final secili = _tip == deger;
    return GestureDetector(
      onTap: () => setState(() => _tip = deger),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: secili ? _turuncu.withValues(alpha: 0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: secili ? _turuncu : Colors.grey.shade200),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(ikon, size: 13,
              color: secili ? _turuncu : Colors.grey),
          const SizedBox(width: 5),
          Text(etiket, style: TextStyle(
              fontSize: 11,
              color: secili ? _turuncu : Colors.grey[600],
              fontWeight: secili ? FontWeight.bold : FontWeight.normal)),
        ]),
      ),
    );
  }
}


// ════════ OTOMATİK BİLDİRİMLER ════════
class _OtomatikBildirimler extends StatefulWidget {
  final String firmaId;
  const _OtomatikBildirimler({required this.firmaId});
  @override State<_OtomatikBildirimler> createState() => _OtomatikBildirimlerState();
}

class _OtomatikBildirimlerState extends State<_OtomatikBildirimler> {
  static const _navy = Color(0xFF1a3a6b);

  final Map<String, bool> _aktif = {
    'servisBasladi':   true,
    'servisYaklasıyor': true,
    'aracGeldi':       true,
    'ogrenciAlindi':   true,
    'okulaUlasti':     true,
    'eveBirakildi':    true,
    'servisTamamlandi': true,
  };

  final Map<String, String> _etiket = {
    'servisBasladi':    'Servis Başladı',
    'servisYaklasıyor': 'Servis Yaklaşıyor (500m)',
    'aracGeldi':        'Araç Geldi',
    'ogrenciAlindi':    'Öğrenci Alındı',
    'okulaUlasti':      'Okula Ulaştı',
    'eveBirakildi':     'Eve Bırakıldı',
    'servisTamamlandi': 'Servis Tamamlandı',
  };

  final Map<String, IconData> _ikon = {
    'servisBasladi':    Icons.play_circle_outlined,
    'servisYaklasıyor': Icons.near_me_outlined,
    'aracGeldi':        Icons.directions_bus_outlined,
    'ogrenciAlindi':    Icons.person_add_outlined,
    'okulaUlasti':      Icons.school_outlined,
    'eveBirakildi':     Icons.home_outlined,
    'servisTamamlandi': Icons.check_circle_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2))),
            child: const Row(children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text(
                  'Otomatik bildirimler, şoför eylemleri gerçekleşince velilere otomatik gönderilir.',
                  style: TextStyle(fontSize: 12, color: Colors.blue))),
            ])),
        const SizedBox(height: 16),
        const Text('Aktif Bildirimler',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _navy)),
        const SizedBox(height: 10),
        ..._aktif.entries.map((e) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]),
          child: Row(children: [
            Icon(_ikon[e.key], color: e.value ? _navy : Colors.grey, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(_etiket[e.key] ?? e.key,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
            Switch(
              value: e.value,
              activeColor: _navy,
              onChanged: (v) async {
                setState(() => _aktif[e.key] = v);
                await FirebaseFirestore.instance
                    .collection('firms').doc(widget.firmaId)
                    .set({'bildirimAyarlari': _aktif}, SetOptions(merge: true));
              },
            ),
          ]),
        )),
        const SizedBox(height: 16),
        const Text('Şoför Bildirimleri',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _navy)),
        const SizedBox(height: 8),
        ...[
          ('yeniOgrenciAtandi', 'Yeni Öğrenci Atandı', Icons.person_add_outlined),
          ('rotaGuncellendi',   'Rota Güncellendi',    Icons.route_outlined),
          ('devamsizlikGeldi',  'Devamsızlık Geldi',   Icons.event_busy_outlined),
          ('servisSaatiYaklasıyor', 'Servis Saati Yaklaşıyor', Icons.alarm_outlined),
        ].map((item) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200)),
          child: Row(children: [
            Icon(item.$3, color: Colors.teal, size: 18),
            const SizedBox(width: 12),
            Expanded(child: Text(item.$2,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
            const Icon(Icons.check_circle, color: Colors.teal, size: 16),
          ]),
        )),
      ]),
    );
  }
}
