import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/session_service.dart';

class SurucularScreen extends StatefulWidget {
  const SurucularScreen({super.key});
  @override
  State<SurucularScreen> createState() => _SurucularScreenState();
}

class _SurucularScreenState extends State<SurucularScreen> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  String? _firmaId;

  @override
  void initState() {
    super.initState();
    SessionService.instance.firmaIdAl().then((id) {
      if (mounted) setState(() => _firmaId = id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white,
        title: const Text('Şoförler', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () => _surucuEkleDialog(context),
          ),
        ],
      ),
      body: _firmaId == null
          ? const Center(child: CircularProgressIndicator(color: _navy))
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('drivers')
            .where('firmaId', isEqualTo: _firmaId)
            .snapshots(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _navy));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.drive_eta_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 12),
                Text('Henüz şoför eklenmemiş',
                    style: TextStyle(color: Colors.grey)),
              ],
            ));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final data  = docs[i].data() as Map<String, dynamic>;
              final aktif = data['aktif'] ?? true;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
                child: Row(children: [
                  CircleAvatar(radius: 22,
                      backgroundColor: _navy.withValues(alpha: 0.1),
                      child: Text((data['ad'] ?? '?')[0].toUpperCase(),
                          style: const TextStyle(color: _navy, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(data['ad'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(data['telefon'] ?? '',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    if ((data['aracPlaka'] ?? '').isNotEmpty)
                      Text('Araç: ${data['aracPlaka']}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                  ])),
                  Switch(
                    value: aktif, activeColor: Colors.green,
                    onChanged: (v) => FirebaseFirestore.instance
                        .collection('drivers').doc(docs[i].id).update({'aktif': v}),
                  ),
                ]),
              );
            },
          );
        },
      ),
    );
  }

  void _surucuEkleDialog(BuildContext context) {
    final adCtrl    = TextEditingController();
    final telCtrl   = TextEditingController();
    final plakaCtrl = TextEditingController();

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Şoför Ekle',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _navy)),
          const SizedBox(height: 16),
          _inp(adCtrl,    'Şoför Adı *',  Icons.person_outline),
          const SizedBox(height: 10),
          _inp(telCtrl,   'Telefon',      Icons.phone_outlined, tipi: TextInputType.phone),
          const SizedBox(height: 10),
          _inp(plakaCtrl, 'Araç Plakası', Icons.directions_bus_outlined),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _turuncu, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (adCtrl.text.trim().isEmpty) return;
              await FirebaseFirestore.instance.collection('drivers').add({
                'firmaId':    _firmaId,
                'ad':         adCtrl.text.trim(),
                'telefon':    telCtrl.text.trim(),
                'aracPlaka':  plakaCtrl.text.trim(),
                'aktif':      true,
                'servisAktif': false,
                'olusturma':  FieldValue.serverTimestamp(),
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

  Widget _inp(TextEditingController c, String label, IconData icon,
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
