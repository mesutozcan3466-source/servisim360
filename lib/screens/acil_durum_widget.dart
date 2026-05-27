import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/acil_durum_service.dart';
import '../services/session_service.dart';

/// Şoför paneline eklenen acil durum butonu
class AcilDurumButonu extends StatefulWidget {
  final String surucuId;
  final String surucuAd;
  final String? plaka;

  const AcilDurumButonu({
    super.key,
    required this.surucuId,
    required this.surucuAd,
    this.plaka,
  });

  @override
  State<AcilDurumButonu> createState() => _AcilDurumButonuState();
}

class _AcilDurumButonuState extends State<AcilDurumButonu>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double>   _pulseAnim;
  bool _yukleniyor = false;
  bool _acilAktif  = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut));
    _acilDurumKontrol();
  }

  @override
  void dispose() { _animCtrl.dispose(); super.dispose(); }

  Future<void> _acilDurumKontrol() async {
    // ✅ drivers koleksiyonu — düzeltildi
    final doc = await FirebaseFirestore.instance
        .collection('drivers')
        .doc(widget.surucuId)
        .get();
    if (mounted) setState(() => _acilAktif = doc.data()?['acilDurum'] ?? false);
  }

  Future<void> _acilDurumBasildi() async {
    if (_acilAktif) { _acilIptalDialog(); return; }

    final onay = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
          ),
          const SizedBox(width: 12),
          const Text('Acil Durum!',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ]),
        content: const Text(
            'Admin ve yetkililere acil durum bildirimi gönderilecek.\n\nDevam etmek istiyor musunuz?',
            style: TextStyle(fontSize: 14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ACİL YARDIM ÇAĞIR'),
          ),
        ],
      ),
    );

    if (onay != true) return;
    setState(() => _yukleniyor = true);

    try {
      final firmaId = await SessionService.instance.firmaldAl() ?? '';
      await AcilDurumService.acilDurumGonder(
        surucuId: widget.surucuId,
        surucuAd: widget.surucuAd,
        firmaId:  firmaId,
        plaka:    widget.plaka,
      );
      if (mounted) {
        setState(() => _acilAktif = true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('🚨 Acil durum bildirimi gönderildi!'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  void _acilIptalDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Acil Durumu İptal Et'),
        content: const Text('Acil durum çözüldü mü? Bildirimi iptal etmek istiyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hayır')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              // ✅ drivers koleksiyonu
              final snap = await FirebaseFirestore.instance
                  .collection('acil_durumlar')
                  .where('surucuId', isEqualTo: widget.surucuId)
                  .where('durum', isEqualTo: 'aktif')
                  .limit(1).get();
              if (snap.docs.isNotEmpty) {
                await AcilDurumService.acilDurumCoz(
                    snap.docs.first.id, widget.surucuId);
              }
              if (mounted) setState(() => _acilAktif = false);
            },
            child: const Text('Evet, Çözüldü'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (_acilAktif)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.red,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            const Text('ACİL DURUM AKTİF',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold,
                    fontSize: 13, letterSpacing: 1)),
            const Spacer(),
            GestureDetector(
              onTap: _acilIptalDialog,
              child: const Text('Çözüldü', style: TextStyle(
                  color: Colors.white70, fontSize: 12,
                  decoration: TextDecoration.underline)),
            ),
          ]),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ScaleTransition(
          scale: _acilAktif ? _pulseAnim : const AlwaysStoppedAnimation(1.0),
          child: SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _acilAktif ? Colors.red : Colors.red.shade700,
                foregroundColor: Colors.white,
                elevation: _acilAktif ? 8 : 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _yukleniyor ? null : _acilDurumBasildi,
              icon: _yukleniyor
                  ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Icon(_acilAktif ? Icons.warning_amber_rounded : Icons.emergency_outlined,
                  size: 22),
              label: Text(_acilAktif ? 'ACİL DURUM AKTİF' : 'ACİL DURUM',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1)),
            ),
          ),
        ),
      ),
    ]);
  }
}

// ─── Admin Acil Durum Paneli ──────────────────────────────────────────────────
class AcilDurumPaneli extends StatelessWidget {
  final String firmaId;
  const AcilDurumPaneli({super.key, required this.firmaId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: AcilDurumService.aktifAcilDurumlari(firmaId),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.red.shade50, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.red.shade200, width: 1.5),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('${docs.length} ACİL DURUM BİLDİRİMİ',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
              ]),
            ),
            ...docs.map((doc) {
              final data    = doc.data() as Map<String, dynamic>;
              final tarih   = data['tarih'] as Timestamp?;
              final saatStr = tarih != null
                  ? '${tarih.toDate().hour}:${tarih.toDate().minute.toString().padLeft(2, '0')}'
                  : '';
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Row(children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.red.withValues(alpha: 0.15),
                    child: Text((data['surucuAd'] ?? '?')[0].toUpperCase(),
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(data['surucuAd'] ?? 'Şoför',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('${data['plaka'] ?? ''}  •  $saatStr',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ])),
                  TextButton(
                    onPressed: () async =>
                        AcilDurumService.acilDurumCoz(doc.id, data['surucuId']),
                    style: TextButton.styleFrom(foregroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                    child: const Text('Çözüldü', style: TextStyle(fontSize: 12)),
                  ),
                ]),
              );
            }),
            const SizedBox(height: 10),
          ]),
        );
      },
    );
  }
}
