import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/session_service.dart';

class OgrencilerScreen extends StatefulWidget {
  const OgrencilerScreen({super.key});
  @override
  State<OgrencilerScreen> createState() => _OgrencilerScreenState();
}

class _OgrencilerScreenState extends State<OgrencilerScreen> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  String? _firmaId;
  String  _arama = '';

  @override
  void initState() {
    super.initState();
    SessionService.instance.firmaldAl().then((id) {
      if (mounted) setState(() => _firmaId = id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white,
        title: const Text('Öğrenciler', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () => _ogrenciEkleDialog(context),
          ),
        ],
      ),
      body: _firmaId == null
          ? const Center(child: CircularProgressIndicator(color: _navy))
          : Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (v) => setState(() => _arama = v),
            decoration: InputDecoration(
              hintText: 'Öğrenci ara...',
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
              .where('firmaId', isEqualTo: _firmaId)
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
              return const Center(child: Text('Öğrenci bulunamadı',
                  style: TextStyle(color: Colors.grey)));
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: docs.length,
              itemBuilder: (_, i) {
                final data  = docs[i].data() as Map<String, dynamic>;
                final docId = docs[i].id;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
                  child: Row(children: [
                    CircleAvatar(radius: 20, backgroundColor: _turuncu.withValues(alpha: 0.1),
                        child: Text((data['ad'] ?? '?')[0].toUpperCase(),
                            style: const TextStyle(color: _turuncu, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(data['ad'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      if ((data['adres'] ?? '').isNotEmpty)
                        Text(data['adres'], style: TextStyle(color: Colors.grey[500], fontSize: 11),
                            overflow: TextOverflow.ellipsis),
                      if ((data['veliAd'] ?? '').isNotEmpty)
                        Text('Veli: ${data['veliAd']}', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                    ])),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.grey, size: 18),
                      onSelected: (v) async {
                        if (v == 'sil') {
                          await FirebaseFirestore.instance
                              .collection('students').doc(docId).delete();
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'sil',
                            child: Text('Sil', style: TextStyle(color: Colors.red))),
                      ],
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

  void _ogrenciEkleDialog(BuildContext context) {
    final adCtrl    = TextEditingController();
    final adresCtrl = TextEditingController();
    final veliCtrl  = TextEditingController();
    final telCtrl   = TextEditingController();

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Öğrenci Ekle',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _navy)),
          const SizedBox(height: 16),
          _input(adCtrl,    'Öğrenci Adı *', Icons.person_outline),
          const SizedBox(height: 10),
          _input(adresCtrl, 'Adres',          Icons.location_on_outlined),
          const SizedBox(height: 10),
          _input(veliCtrl,  'Veli Adı',       Icons.family_restroom_outlined),
          const SizedBox(height: 10),
          _input(telCtrl,   'Veli Telefon',   Icons.phone_outlined,
              tipi: TextInputType.phone),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _turuncu, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (adCtrl.text.trim().isEmpty) return;
              await FirebaseFirestore.instance.collection('students').add({
                'firmaId': _firmaId,
                'ad':      adCtrl.text.trim(),
                'adres':   adresCtrl.text.trim(),
                'veliAd':  veliCtrl.text.trim(),
                'veliTel': telCtrl.text.trim(),
                'aktif':   true,
                'olusturma': FieldValue.serverTimestamp(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Ekle',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          )),
        ]),
      ),
    );
  }

  Widget _input(TextEditingController c, String label, IconData icon,
      {TextInputType tipi = TextInputType.text}) =>
      TextField(
        controller: c, keyboardType: tipi,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _navy, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );
}
