// lib/screens/web_fiyat.dart — Servisim360 Web Fiyatlandırma v2
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/session_service.dart';

class WebFiyat extends StatefulWidget {
  const WebFiyat({super.key});
  @override
  State<WebFiyat> createState() => _WebFiyatState();
}

class _WebFiyatState extends State<WebFiyat> with SingleTickerProviderStateMixin {
  static const _navy   = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);
  late TabController _tab;
  String _firmaId = '';
  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _yukle();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _yukle() async {
    _firmaId = await SessionService.instance.firmaIdAl() ?? '';
    if (mounted) setState(() => _yukleniyor = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) return const Center(
        child: CircularProgressIndicator(color: _navy));
    return Column(children: [
      Container(
        color: Colors.white,
        child: TabBar(
          controller: _tab,
          labelColor: _navy, unselectedLabelColor: Colors.grey,
          indicatorColor: _orange,
          tabs: const [
            Tab(icon: Icon(Icons.attach_money_outlined, size: 18), text: 'Fiyat Listesi'),
            Tab(icon: Icon(Icons.receipt_outlined, size: 18), text: 'Fatura & Ödemeler'),
          ],
        ),
      ),
      Expanded(child: TabBarView(controller: _tab, children: [
        _FiyatListesi(firmaId: _firmaId),
        _FaturaListesi(firmaId: _firmaId),
      ])),
    ]);
  }
}

// ════════ FİYAT LİSTESİ ════════
class _FiyatListesi extends StatefulWidget {
  final String firmaId;
  const _FiyatListesi({required this.firmaId});
  @override
  State<_FiyatListesi> createState() => _FiyatListesiState();
}

class _FiyatListesiState extends State<_FiyatListesi> {
  static const _navy   = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);

  final _bolgeCtrl = TextEditingController();
  final _fiyatCtrl = TextEditingController();
  final _aciklamaCtrl = TextEditingController();
  String _tip = 'bolge';

  @override
  void dispose() {
    _bolgeCtrl.dispose(); _fiyatCtrl.dispose(); _aciklamaCtrl.dispose();
    super.dispose();
  }

  void _ekleDialog() {
    _bolgeCtrl.clear(); _fiyatCtrl.clear(); _aciklamaCtrl.clear();
    _tip = 'bolge';
    showDialog(context: context, builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Yeni Fiyat Ekle',
              style: TextStyle(color: _navy, fontWeight: FontWeight.bold)),
          content: SizedBox(width: 380, child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Tip seçimi
            Row(children: [
              for (final t in [
                ('bolge', 'Bölge'), ('mahalle', 'Mahalle'),
                ('km', 'Km Bazlı'), ('manuel', 'Manuel'),
              ])
                Expanded(child: GestureDetector(
                  onTap: () => setS(() => _tip = t.$1),
                  child: Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                        color: _tip == t.$1 ? _navy : Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _tip == t.$1 ? _navy : Colors.grey.shade300)),
                    child: Center(child: Text(t.$2,
                        style: TextStyle(
                            fontSize: 11,
                            color: _tip == t.$1 ? Colors.white : Colors.grey[700],
                            fontWeight: _tip == t.$1 ? FontWeight.bold : FontWeight.normal))),
                  ),
                )),
            ]),
            const SizedBox(height: 12),
            TextField(controller: _bolgeCtrl,
                decoration: InputDecoration(
                    labelText: 'Bölge / Mahalle / Açıklama *',
                    prefixIcon: const Icon(Icons.location_on_outlined, color: _navy, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12))),
            const SizedBox(height: 10),
            TextField(controller: _fiyatCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: 'Aylık Fiyat (TL) *',
                    prefixIcon: const Icon(Icons.attach_money_outlined, color: _navy, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12))),
            const SizedBox(height: 10),
            TextField(controller: _aciklamaCtrl,
                decoration: InputDecoration(
                    labelText: 'Açıklama (opsiyonel)',
                    prefixIcon: const Icon(Icons.notes_outlined, color: _navy, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12))),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _orange, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () async {
                if (_bolgeCtrl.text.trim().isEmpty || _fiyatCtrl.text.trim().isEmpty) return;
                await FirebaseFirestore.instance.collection('fiyatlar').add({
                  'firmaId':   widget.firmaId,
                  'bolge':     _bolgeCtrl.text.trim(),
                  'tip':       _tip,
                  'fiyat':     double.tryParse(_fiyatCtrl.text) ?? 0,
                  'ucret':     double.tryParse(_fiyatCtrl.text) ?? 0,
                  'aciklama':  _aciklamaCtrl.text.trim(),
                  'aktif':     true,
                  'olusturmaTarihi': FieldValue.serverTimestamp(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Ekle'),
            ),
          ],
        )));
  }

  @override
  Widget build(BuildContext context) => widget.firmaId.isEmpty
      ? const Center(child: Text('Firma bilgisi yükleniyor...'))
      : Padding(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Fiyat Tanımları',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _navy)),
        const Spacer(),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: _navy, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: _ekleDialog,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Fiyat Ekle'),
        ),
      ]),
      const SizedBox(height: 16),
      Expanded(child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('fiyatlar')
            .where('firmaId', isEqualTo: widget.firmaId)
            .snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.attach_money_outlined, size: 56, color: Colors.grey[300]),
              const SizedBox(height: 12),
              const Text('Fiyat tanımı yok',
                  style: TextStyle(color: Colors.grey, fontSize: 16)),
              const SizedBox(height: 8),
              const Text('Yukarıdan fiyat ekleyebilirsiniz.',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ));
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final tip = d['tip'] ?? 'bolge';
              final renk = tip == 'mahalle' ? Colors.purple
                  : tip == 'km' ? Colors.blue
                  : tip == 'manuel' ? Colors.teal
                  : _navy;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: renk.withValues(alpha: 0.15)),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)]),
                child: Row(children: [
                  Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: renk.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.location_on_outlined, color: renk, size: 18)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d['bolge'] ?? d['tip'] ?? 'Fiyat',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    if ((d['aciklama'] ?? '').isNotEmpty)
                      Text(d['aciklama'], style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: renk.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4)),
                        child: Text(tip,
                            style: TextStyle(fontSize: 10, color: renk, fontWeight: FontWeight.bold))),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${d['ucret'] ?? d['fiyat'] ?? 0} TL',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18, color: _orange)),
                    const Text('/ ay',
                        style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ]),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                    onPressed: () => FirebaseFirestore.instance
                        .collection('fiyatlar').doc(docs[i].id).delete(),
                    padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                  ),
                ]),
              );
            },
          );
        },
      )),
    ]),
  );
}

// ════════ FATURA & ÖDEMELER ════════
class _FaturaListesi extends StatelessWidget {
  final String firmaId;
  static const _navy = Color(0xFF1a3a6b);
  const _FaturaListesi({required this.firmaId});

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('students')
        .where('firmaId', isEqualTo: firmaId)
        .where('fiyat', isGreaterThan: 0)
        .snapshots(),
    builder: (_, snap) {
      final docs = snap.data?.docs ?? [];
      if (docs.isEmpty) return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('Ücret tanımlı öğrenci yok',
              style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('Öğrencilere fiyat tanımlandıkça burada görünür.',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ));
      double toplam = 0;
      for (final doc in docs) {
        final d = doc.data() as Map<String, dynamic>;
        toplam += ((d['fiyat'] ?? d['ucret'] ?? 0) as num).toDouble();
      }
      return Column(children: [
        // Özet kartı
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: _navy,
              borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            const Icon(Icons.payments_outlined, color: Colors.white, size: 28),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Toplam Aylık Gelir',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text('${toplam.toStringAsFixed(0)} TL',
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 24)),
              Text('${docs.length} öğrenci',
                  style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ])),
          ]),
        ),
        // Öğrenci listesi
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final sozl = d['sozlesmeOnay'] == true;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]),
              child: Row(children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _navy.withValues(alpha: 0.08),
                  child: Text((d['ad'] ?? '?').isNotEmpty ? d['ad'][0].toUpperCase() : '?',
                      style: const TextStyle(color: _navy, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d['ad'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(d['soforAd'] ?? d['servisAd'] ?? '',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ])),
                Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: (sozl ? Colors.green : Colors.orange).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(sozl ? 'Onaylı' : 'Bekl.',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold,
                            color: sozl ? Colors.green : Colors.orange))),
                const SizedBox(width: 8),
                Text('${d['fiyat'] ?? d['ucret'] ?? 0} TL',
                    style: const TextStyle(fontWeight: FontWeight.bold,
                        fontSize: 15, color: Color(0xFFFF8C00))),
              ]),
            );
          },
        )),
      ]);
    },
  );
}
