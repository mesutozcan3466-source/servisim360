// lib/screens/sozlesme_screen.dart — Servisim360 Sözleşme Yönetimi
import 'package:flutter/material.dart';
import 'yardim_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/session_service.dart';

class SozlesmeScreen extends StatefulWidget {
  const SozlesmeScreen({super.key});
  @override
  State<SozlesmeScreen> createState() => _SozlesmeScreenState();
}

class _SozlesmeScreenState extends State<SozlesmeScreen>
    with SingleTickerProviderStateMixin {
  static const _navy   = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);

  late TabController _tab;
  bool _yukleniyor = true;
  String _firmaId  = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _yukle();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _yukle() async {
    final fId = await SessionService.instance.firmaIdAl();
    if (mounted) setState(() { _firmaId = fId ?? ''; _yukleniyor = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: _navy)));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white,
        title: const Text('Sozlesmeler', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.add_outlined),
              tooltip: 'Yeni Sablon',
              onPressed: () => Navigator.pushNamed(context, '/sozlesme_yonetim')),
          YardimButonu(ekranAdi: 'Sozlesmeler'),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: _orange,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.description_outlined, size: 18), text: 'Sablonlar'),
            Tab(icon: Icon(Icons.check_circle_outlined, size: 18), text: 'Imzalanan'),
            Tab(icon: Icon(Icons.pending_outlined, size: 18), text: 'Bekleyen'),
          ],
        ),
      ),
      body: TabBarView(controller: _tab, children: [
        _SablonlarSekme(firmaId: _firmaId),
        _ImzalananlarSekme(firmaId: _firmaId),
        _BekleyenlerSekme(firmaId: _firmaId),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.pushNamed(context, '/sozlesme_yonetim'),
        icon: const Icon(Icons.add_outlined),
        label: const Text('Yeni Sablon'),
      ),
    );
  }
}

// ════════ ŞABLONLAR ════════
class _SablonlarSekme extends StatelessWidget {
  final String firmaId;
  static const _navy = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);
  const _SablonlarSekme({required this.firmaId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sozlesme_sablonlari')
          .where('firmaId', isEqualTo: firmaId)
          .orderBy('olusturmaTarihi', descending: true)
          .snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return _bos(
          context,
          'Sozlesme sablonu yok',
          'Yeni sablon olusturmak icin + butonuna basin.',
          Icons.description_outlined,
        );
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final kat = d['kategori'] ?? 'genel';
            final renk = kat == 'ogrenci' ? Colors.blue
                : kat == 'personel' ? Colors.teal
                : kat == 'kvkk' ? Colors.purple
                : _navy;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)]),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: renk.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.description_outlined, color: renk, size: 22)),
                title: Text(d['baslik'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 4),
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: renk.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(5)),
                      child: Text(kat,
                          style: TextStyle(fontSize: 11, color: renk, fontWeight: FontWeight.bold))),
                  const SizedBox(height: 4),
                  Text('${(d['maddeler'] as List?)?.length ?? 0} madde',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ]),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18, color: _navy),
                    onPressed: () => Navigator.pushNamed(
                        context, '/sozlesme_yonetim',
                        arguments: {'sablonId': docs[i].id}),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, size: 18, color: Colors.red[300]),
                    onPressed: () => _silOnayla(context, docs[i].id, d['baslik'] ?? ''),
                  ),
                ]),
                onTap: () => _onizle(context, d),
              ),
            );
          },
        );
      },
    );
  }

  void _onizle(BuildContext context, Map<String, dynamic> d) {
    final maddeler = (d['maddeler'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.7, maxChildSize: 0.9,
        builder: (_, ctrl) => Column(children: [
          Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              const Icon(Icons.description_outlined, color: _navy),
              const SizedBox(width: 10),
              Expanded(child: Text(d['baslik'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            ]),
          ),
          const Divider(height: 20),
          Expanded(child: ListView.builder(
            controller: ctrl,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: maddeler.length,
            itemBuilder: (_, i) {
              final m = maddeler[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                        color: _navy.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12)),
                    child: Center(child: Text('${i + 1}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _navy))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(m['icerik'] ?? '',
                      style: const TextStyle(fontSize: 13, height: 1.5))),
                ]),
              );
            },
          )),
        ]),
      ),
    );
  }

  Future<void> _silOnayla(BuildContext context, String docId, String baslik) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sablonu Sil'),
        content: Text('"$baslik" sablonunu silmek istediginize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_, false), child: const Text('Vazgec')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(_, true),
              child: const Text('Sil')),
        ],
      ),
    );
    if (onay == true) {
      await FirebaseFirestore.instance
          .collection('sozlesme_sablonlari').doc(docId).delete();
    }
  }
}

// ════════ İMZALANANLAR ════════
class _ImzalananlarSekme extends StatelessWidget {
  final String firmaId;
  static const _navy = Color(0xFF1a3a6b);
  const _ImzalananlarSekme({required this.firmaId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sozlesmeler')
          .where('firmaId', isEqualTo: firmaId)
          .where('durum', isEqualTo: 'imzalandi')
          .orderBy('onayTarihi', descending: true)
          .snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return _bos(
            context, 'Imzalanmis sozlesme yok', '', Icons.check_circle_outline);
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final tarih = d['onayTarihi']?.toString().substring(0, 10) ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]),
              child: Row(children: [
                const Icon(Icons.check_circle_outline, color: Colors.green, size: 22),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d['ogrenciAd'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Veli: ${d['veliAd'] ?? ''}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  if ((d['ucret'] ?? 0) > 0)
                    Text('Ucret: ${d['ucret']} TL/ay',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.teal, fontWeight: FontWeight.w600)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(tarih, style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                  const SizedBox(height: 4),
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6)),
                      child: const Text('Imzalandi',
                          style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold))),
                ]),
              ]),
            );
          },
        );
      },
    );
  }
}

// ════════ BEKLEYENLER ════════
class _BekleyenlerSekme extends StatelessWidget {
  final String firmaId;
  static const _navy = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);
  const _BekleyenlerSekme({required this.firmaId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sozlesmeler')
          .where('firmaId', isEqualTo: firmaId)
          .where('durum', isEqualTo: 'bekliyor')
          .snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return _bos(
            context, 'Bekleyen sozlesme yok', 'Tum sozlesmeler imzalanmis.', Icons.pending_outlined);
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _orange.withValues(alpha: 0.3)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]),
              child: Row(children: [
                const Icon(Icons.pending_outlined, color: Color(0xFFFF8C00), size: 22),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d['ogrenciAd'] ?? d['kisi'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Veli: ${d['veliAd'] ?? ''}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ])),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _navy, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection('sozlesmeler').doc(docs[i].id)
                        .update({'durum': 'imzalandi',
                      'onayTarihi': FieldValue.serverTimestamp()});
                  },
                  child: const Text('Onayla', style: TextStyle(fontSize: 12)),
                ),
              ]),
            );
          },
        );
      },
    );
  }
}

// ════════ YARDIMCI ════════
Widget _bos(BuildContext context, String baslik, String alt, IconData ikon) =>
    Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(ikon, size: 64, color: Colors.grey[300]),
      const SizedBox(height: 14),
      Text(baslik, style: const TextStyle(
          fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold)),
      if (alt.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(alt, style: TextStyle(fontSize: 13, color: Colors.grey[400]),
            textAlign: TextAlign.center),
      ],
      const SizedBox(height: 20),
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1a3a6b), foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
        onPressed: () => Navigator.pushNamed(context, '/sozlesme_yonetim'),
        icon: const Icon(Icons.add_outlined, size: 16),
        label: const Text('Sablon Olustur'),
      ),
    ]));
