import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/session_service.dart';

class BildirimlerScreen extends StatelessWidget {
  const BildirimlerScreen({super.key});

  static const _navy = Color(0xFF1a3a6b);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white,
        title: const Text('Bildirimler', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<String?>(
        future: SessionService.instance.firmaIdAl(),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: _navy));
          }
          final firmaId = snap.data!;
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('bildirimler')
                .where('firmaId', isEqualTo: firmaId)
                .orderBy('tarih', descending: true)
                .limit(50)
                .snapshots(),
            builder: (_, snap) {
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_none_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('Bildirim yok', style: TextStyle(color: Colors.grey)),
                  ],
                ));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final data   = docs[i].data() as Map<String, dynamic>;
                  final tarih  = data['tarih'] as Timestamp?;
                  final okundu = data['okundu'] ?? false;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: okundu ? Colors.white : const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: okundu
                          ? Colors.grey.withValues(alpha: 0.15)
                          : _navy.withValues(alpha: 0.2)),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _navy.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.notifications_outlined, color: _navy, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(data['baslik'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        if ((data['mesaj'] ?? '').isNotEmpty)
                          Text(data['mesaj'],
                              style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        if (tarih != null)
                          Text(
                            '${tarih.toDate().day}.${tarih.toDate().month}.${tarih.toDate().year} '
                                '${tarih.toDate().hour}:${tarih.toDate().minute.toString().padLeft(2, '0')}',
                            style: TextStyle(color: Colors.grey[400], fontSize: 10),
                          ),
                      ])),
                      if (!okundu)
                        Container(width: 8, height: 8,
                            decoration: const BoxDecoration(color: _navy, shape: BoxShape.circle)),
                    ]),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
