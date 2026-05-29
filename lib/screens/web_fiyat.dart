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

  @override
  void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      color: Colors.white,
      child: TabBar(
        controller: _tab,
        labelColor: _navy, unselectedLabelColor: Colors.grey,
        indicatorColor: _orange,
        tabs: const [
          Tab(icon: Icon(Icons.attach_money_outlined), text: 'Fiyat Yonetimi'),
          Tab(icon: Icon(Icons.receipt_outlined),      text: 'Fatura & Odemeler'),
        ],
      ),
    ),
    Expanded(child: TabBarView(controller: _tab, children: [
      const _FiyatListesi(),
      const _FaturaListesi(),
    ])),
  ]);
}

class _FiyatListesi extends StatelessWidget {
  const _FiyatListesi();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text('Fiyat Tanimlari', style: TextStyle(fontWeight: FontWeight.bold,
            fontSize: 16, color: Color(0xFF1a3a6b))),
        const Spacer(),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1a3a6b),
              foregroundColor: Colors.white),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Fiyat Ekle'),
          onPressed: () => Navigator.pushNamed(context, '/fiyat_yonetim'),
        ),
      ]),
      const SizedBox(height: 16),
      Expanded(child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('fiyatlar')
            .where('firmaId', isEqualTo: SessionService.instance.cachedFirmaId ?? '')
            .snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return const Center(child: Text('Fiyat tanimi yok'));
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)]),
                child: Row(children: [
                  const Icon(Icons.attach_money_outlined, color: Color(0xFF1a3a6b), size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d['bolge'] ?? d['tip'] ?? 'Fiyat',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(d['aciklama'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFFFF8C00).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('${d['ucret'] ?? d['fiyat'] ?? 0} TL',
                        style: const TextStyle(fontWeight: FontWeight.bold,
                            color: Color(0xFFFF8C00), fontSize: 15)),
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

class _FaturaListesi extends StatelessWidget {
  const _FaturaListesi();
  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
      const SizedBox(height: 16),
      const Text('Fatura sistemi yakindan geliyor', style: TextStyle(color: Colors.grey)),
      const SizedBox(height: 12),
      ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1a3a6b),
            foregroundColor: Colors.white),
        onPressed: () => Navigator.pushNamed(context, '/fiyat_yonetim'),
        child: const Text('Fiyat Yonetimine Git'),
      ),
    ],
  ));
}
