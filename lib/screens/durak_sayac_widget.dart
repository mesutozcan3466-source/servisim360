import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Veli panelinde servisin kac durak uzakta oldugunu ve ETA'yi gosterir
class DurakSayacWidget extends StatelessWidget {
  final String? surucuId;
  final String? ogrenciId;

  static const _navy = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  const DurakSayacWidget({
    super.key,
    required this.surucuId,
    required this.ogrenciId,
  });

  @override
  Widget build(BuildContext context) {
    if (surucuId == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('surucu_konumlar')
          .doc(surucuId)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return const SizedBox.shrink();
        }

        final data = snap.data!.data() as Map<String, dynamic>?;
        if (data == null) return const SizedBox.shrink();

        final aktif = data['aktif'] ?? false;
        if (!aktif) return const SizedBox.shrink();

        final kalanDurak = (data['kalanDurak'] ?? 0) as int;
        final etaDakika = (data['etaDakika'] ?? 0) as int;
        final mesafe = (data['kalanMesafe'] ?? 0.0) as double;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: kalanDurak <= 1
                  ? [Colors.green, const Color(0xFF059669)]
                  : kalanDurak <= 3
                  ? [const Color(0xFFFF8C00), const Color(0xFFF59E0B)]
                  : [_navy, const Color(0xFF2a5298)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Row(
            children: [
              // Servis ikonu
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.directions_bus,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kalanDurak == 0
                          ? 'Servis kapinizda!'
                          : kalanDurak == 1
                          ? 'Bir sonraki durak sizsiniz'
                          : '$kalanDurak durak kaldi',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (etaDakika > 0) ...[
                          const Icon(Icons.access_time,
                              color: Colors.white70, size: 13),
                          const SizedBox(width: 4),
                          Text('~$etaDakika dakika',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                          const SizedBox(width: 12),
                        ],
                        if (mesafe > 0) ...[
                          const Icon(Icons.straighten,
                              color: Colors.white70, size: 13),
                          const SizedBox(width: 4),
                          Text('${mesafe.toStringAsFixed(1)} km',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Renk indikatoru
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: kalanDurak == 0
                      ? Colors.white
                      : kalanDurak <= 2
                      ? Colors.yellowAccent
                      : Colors.white.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Renk sistemi legend widget'i
class DurakRenkLegend extends StatelessWidget {
  const DurakRenkLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RenkItem(renk: Colors.green, etiket: 'Yaklasıyor'),
          SizedBox(width: 12),
          _RenkItem(renk: Colors.orange, etiket: '3 durak'),
          SizedBox(width: 12),
          _RenkItem(renk: Color(0xFF1a3a6b), etiket: 'Uzak'),
        ],
      ),
    );
  }
}

class _RenkItem extends StatelessWidget {
  final Color renk;
  final String etiket;

  const _RenkItem({required this.renk, required this.etiket});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: renk, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(etiket, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
