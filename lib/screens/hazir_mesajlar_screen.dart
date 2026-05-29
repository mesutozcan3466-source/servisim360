import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/hazir_mesaj_service.dart';
import '../services/session_service.dart';
import 'package:url_launcher/url_launcher.dart';

class HazirMesajlarScreen extends StatefulWidget {
  const HazirMesajlarScreen({super.key});

  @override
  State<HazirMesajlarScreen> createState() => _HazirMesajlarScreenState();
}

class _HazirMesajlarScreenState extends State<HazirMesajlarScreen>
    with SingleTickerProviderStateMixin {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  late final TabController _tabCtrl;
  String? _firmaId;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _firmaIdYukle();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _firmaIdYukle() async {
    final id = await SessionService.instance.firmaldAl();
    if (mounted) setState(() => _firmaId = id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white, elevation: 0,
        title: const Text('Hazır Mesajlar', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: _turuncu, indicatorWeight: 3,
          labelColor: Colors.white, unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.family_restroom, size: 18), text: 'Veli'),
            Tab(icon: Icon(Icons.drive_eta,        size: 18), text: 'Şoför'),
          ],
        ),
      ),
      body: _firmaId == null
          ? const Center(child: CircularProgressIndicator(color: _navy))
          : TabBarView(
        controller: _tabCtrl,
        children: [
          _MesajListesi(firmaId: _firmaId!, tip: 'veli'),
          _MesajListesi(firmaId: _firmaId!, tip: 'sofor'),
        ],
      ),
    );
  }
}

class _MesajListesi extends StatelessWidget {
  final String firmaId, tip;
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  static const _ikonlar = {
    'location': Icons.location_on_outlined,
    'time':     Icons.access_time_outlined,
    'cancel':   Icons.cancel_outlined,
    'bus':      Icons.directions_bus_outlined,
    'bell':     Icons.notifications_outlined,
    'check':    Icons.check_circle_outlined,
    'school':   Icons.school_outlined,
    'message':  Icons.message_outlined,
  };
  const _MesajListesi({required this.firmaId, required this.tip});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _navy, foregroundColor: Colors.white,
        icon: const Icon(Icons.add), label: const Text('Mesaj Ekle'),
        onPressed: () => _mesajEkleDialog(context),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: HazirMesajService.mesajlariDinle(firmaId: firmaId, tip: tip),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _navy));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.message_outlined, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text('Henüz mesaj eklenmemiş.', style: TextStyle(color: Colors.grey[500])),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
                icon: const Icon(Icons.add), label: const Text('İlk Mesajı Ekle'),
                onPressed: () => _mesajEkleDialog(context),
              ),
            ]));
          }
          return ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: docs.length,
            onReorder: (old, neu) => _siraDegistir(docs, old, neu),
            itemBuilder: (context, i) {
              final doc    = docs[i];
              final data   = doc.data() as Map<String, dynamic>;
              final ikonAdi = data['ikon'] ?? 'message';
              final ikon   = _ikonlar[ikonAdi] ?? Icons.message_outlined;
              return Container(
                key: ValueKey(doc.id),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: _navy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                    child: Icon(ikon, color: _navy, size: 20),
                  ),
                  title: Text(data['metin'] ?? '',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    tip == 'veli' ? 'Veli gönderebilir' : 'Şoför gönderebilir',
                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                  ),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    // WhatsApp ile gönder
                    IconButton(
                      icon: const Icon(Icons.send_outlined, size: 18, color: Color(0xFF25D366)),
                      tooltip: 'WhatsApp ile Gonder',
                      onPressed: () => _whatsappGonder(context, data['metin'] ?? ''),
                      splashRadius: 18,
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                      onPressed: () => _mesajDuzenleDialog(context, doc.id, data),
                      splashRadius: 18,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      onPressed: () => _silOnay(context, doc.id),
                      splashRadius: 18,
                    ),
                    const Icon(Icons.drag_handle, color: Colors.grey, size: 20),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }


  // WhatsApp ile hazır mesaj gönder — kişi seçimi dialog
  void _whatsappGonder(BuildContext context, String metin) {
    final telCtrl = TextEditingController();
    showModalBottomSheet(
      context: context, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const Text('WhatsApp Gonder', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _navy)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
            child: Text(metin, style: const TextStyle(fontSize: 13)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: telCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Telefon Numarasi (opsiyonel)',
              hintText: 'Bos birakırsaniz kisi secimi acar',
              prefixIcon: const Icon(Icons.phone_outlined, color: _navy),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              style: OutlinedButton.styleFrom(foregroundColor: _navy, side: const BorderSide(color: _navy)),
              child: const Text('Iptal'),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366), foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              icon: const Icon(Icons.chat_outlined, size: 18),
              label: const Text('Gonder', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                Navigator.pop(ctx);
                final tel = telCtrl.text.trim().replaceAll(RegExp(r'[^\d]'), '');
                Uri url;
                if (tel.length >= 10) {
                  final numara = tel.startsWith('90') ? tel : '90$tel';
                  url = Uri.parse('https://wa.me/$numara?text=${Uri.encodeComponent(metin)}');
                } else {
                  url = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(metin)}');
                }
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
            )),
          ]),
        ]),
      ),
    );
  }

  Future<void> _siraDegistir(List<QueryDocumentSnapshot> docs, int old, int neu) async {
    if (neu > old) neu--;
    final batch = FirebaseFirestore.instance.batch();
    final liste = List.from(docs);
    final item  = liste.removeAt(old);
    liste.insert(neu, item);
    for (int i = 0; i < liste.length; i++) {
      batch.update(FirebaseFirestore.instance.collection('hazir_mesajlar').doc(liste[i].id), {'sira': i + 1});
    }
    await batch.commit();
  }

  void _mesajEkleDialog(BuildContext context) {
    final metinCtrl  = TextEditingController();
    String seciliIkon = 'message';
    bool yukleniyor  = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('Yeni Mesaj',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _navy)),
            const SizedBox(height: 16),
            TextField(
              controller: metinCtrl, maxLength: 100,
              decoration: InputDecoration(
                labelText: 'Mesaj metni', hintText: 'Örn: Durağa yaklaşıyoruz',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _navy, width: 2)),
              ),
            ),
            const SizedBox(height: 12),
            const Text('İkon Seç', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 8),
            _IkonSecici(secili: seciliIkon, onSecildi: (ikon) => setS(() => seciliIkon = ikon)),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _turuncu,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: yukleniyor ? null : () async {
                if (metinCtrl.text.trim().isEmpty) return;
                setS(() => yukleniyor = true);
                await HazirMesajService.mesajEkle(
                    firmaId: firmaId, metin: metinCtrl.text.trim(), tip: tip, ikon: seciliIkon);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: yukleniyor
                  ? const SizedBox(height: 20, width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Ekle',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            )),
          ]),
        ),
      ),
    );
  }

  void _mesajDuzenleDialog(BuildContext context, String docId, Map<String, dynamic> data) {
    final metinCtrl  = TextEditingController(text: data['metin'] ?? '');
    String seciliIkon = data['ikon'] ?? 'message';
    bool yukleniyor  = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('Mesajı Düzenle',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _navy)),
            const SizedBox(height: 16),
            TextField(
              controller: metinCtrl, maxLength: 100,
              decoration: InputDecoration(
                labelText: 'Mesaj metni',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _navy, width: 2)),
              ),
            ),
            const SizedBox(height: 12),
            const Text('İkon', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 8),
            _IkonSecici(secili: seciliIkon, onSecildi: (ikon) => setS(() => seciliIkon = ikon)),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _navy,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: yukleniyor ? null : () async {
                if (metinCtrl.text.trim().isEmpty) return;
                setS(() => yukleniyor = true);
                await HazirMesajService.mesajGuncelle(docId, {'metin': metinCtrl.text.trim(), 'ikon': seciliIkon});
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: yukleniyor
                  ? const SizedBox(height: 20, width: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Kaydet',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            )),
          ]),
        ),
      ),
    );
  }

  Future<void> _silOnay(BuildContext context, String docId) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Mesajı Sil'),
        content: const Text('Bu hazır mesaj silinsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Sil', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (onay == true) await HazirMesajService.mesajSil(docId);
  }
}

class _IkonSecici extends StatelessWidget {
  final String secili;
  final void Function(String) onSecildi;
  static const _navy = Color(0xFF1a3a6b);
  static const _ikonlar = {
    'location': Icons.location_on_outlined,
    'time':     Icons.access_time_outlined,
    'cancel':   Icons.cancel_outlined,
    'bus':      Icons.directions_bus_outlined,
    'bell':     Icons.notifications_outlined,
    'check':    Icons.check_circle_outlined,
    'school':   Icons.school_outlined,
    'message':  Icons.message_outlined,
  };
  const _IkonSecici({required this.secili, required this.onSecildi});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: _ikonlar.entries.map((e) {
        final aktif = secili == e.key;
        return GestureDetector(
          onTap: () => onSecildi(e.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: aktif ? _navy : Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: aktif ? _navy : Colors.grey[300]!, width: aktif ? 2 : 1),
            ),
            child: Icon(e.value, color: aktif ? Colors.white : Colors.grey[500], size: 20),
          ),
        );
      }).toList(),
    );
  }
}
