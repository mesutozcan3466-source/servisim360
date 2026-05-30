// Admin Dashboard'a eklenecek Başvuru Özeti Widget'ı
// dashboard_screen.dart içinde kullanım:
// AdminBasvuruWidget(firmaId: _firmaId)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminBasvuruWidget extends StatelessWidget {
  final String firmaId;
  static const Color navy   = Color(0xFF1a3a6b);
  static const Color orange = Color(0xFFFF8C00);

  const AdminBasvuruWidget({super.key, required this.firmaId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('veli_basvurular')
          .where('firmaId', isEqualTo: firmaId)
          .where('durum',   isEqualTo: 'beklemede')
          .snapshots(),
      builder: (ctx, snap) {
        final sayi = snap.data?.docs.length ?? 0;
        if (sayi == 0) return const SizedBox();

        return GestureDetector(
          onTap: () =>
              Navigator.pushNamed(context, '/veli_basvurular'),
          child: Container(
            margin: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [orange, orange.withValues(alpha: 0.8)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: orange.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_add,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$sayi Yeni Veli Basvurusu',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                    const Text(
                      'Onay bekliyor — incele ve kaydet',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.white, size: 16),
            ]),
          ),
        );
      },
    );
  }
}
