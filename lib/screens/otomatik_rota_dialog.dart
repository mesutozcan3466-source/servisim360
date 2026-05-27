import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/akilli_rota_ai_service.dart';
import '../services/session_service.dart';

class OtomatikRotaButonu extends StatefulWidget {
  const OtomatikRotaButonu({super.key});

  @override
  State<OtomatikRotaButonu> createState() => _OtomatikRotaButonuState();
}

class _OtomatikRotaButonuState extends State<OtomatikRotaButonu> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  bool _yukleniyor = false;

  Future<void> _otomatikAta() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: _turuncu.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.auto_awesome, color: _turuncu, size: 20),
          ),
          const SizedBox(width: 10),
          const Text('AI Rota Önerisi',
              style: TextStyle(color: _navy, fontWeight: FontWeight.bold)),
        ]),
        content: const Text(
            'AI, öğrenci adreslerini analiz edip en mantıklı şoför atamalarını yapacak.\n\nMevcut atamalar değiştirilecek. Devam etmek istiyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _turuncu, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('AI ile Ata'),
          ),
        ],
      ),
    );

    if (onay != true) return;
    setState(() => _yukleniyor = true);

    try {
      final firmaId = await SessionService.instance.firmaldAl();
      if (firmaId == null) return;

      final db = FirebaseFirestore.instance;

      // Yeni koleksiyon adları: students / drivers
      final ogrSnap = await db.collection('students').where('firmaId', isEqualTo: firmaId).get();
      final surSnap = await db.collection('drivers').where('firmaId', isEqualTo: firmaId).get();

      final ogrenciler = ogrSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      final suruculer  = surSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      if (ogrenciler.isEmpty || suruculer.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Öğrenci veya şoför bulunamadı'), backgroundColor: Colors.orange),
        );
        return;
      }

      final sonuc = await AkilliRotaAiService.rotaOner(
        firmaId: firmaId, ogrenciler: ogrenciler, suruculer: suruculer,
      );

      if (!sonuc.basarili) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: ${sonuc.aciklama}'), backgroundColor: Colors.red),
        );
        return;
      }

      if (mounted) await _sonucDialog(sonuc, suruculer, ogrenciler);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _sonucDialog(
      AkilliRotaSonuc sonuc,
      List<Map<String, dynamic>> suruculer,
      List<Map<String, dynamic>> ogrenciler,
      ) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.check_circle, color: Colors.green),
          SizedBox(width: 8),
          Text('AI Rota Önerisi Hazır',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ]),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF0F4FF), borderRadius: BorderRadius.circular(10)),
              child: Text(sonuc.aciklama, style: const TextStyle(fontSize: 12, height: 1.4)),
            ),
            const SizedBox(height: 12),
            Text('${sonuc.toplamAtanan} öğrenci atanacak:',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            ...sonuc.atamalar.entries.map((e) {
              final surucuAd = suruculer
                  .firstWhere((s) => s['id'] == e.key, orElse: () => {'ad': e.key})['ad']
                  .toString();
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  const Icon(Icons.drive_eta, size: 14, color: Color(0xFF1a3a6b)),
                  const SizedBox(width: 6),
                  Expanded(child: Text('$surucuAd — ${e.value.length} öğrenci',
                      style: const TextStyle(fontSize: 12))),
                ]),
              );
            }),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              await AkilliRotaAiService.atamalariUygula(sonuc.atamalar);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Atamalar başarıyla uygulandı!'),
                    backgroundColor: Colors.green, behavior: SnackBarBehavior.floating),
              );
            },
            child: const Text('Uygula'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: _yukleniyor ? null : _otomatikAta,
      backgroundColor: _turuncu, foregroundColor: Colors.white,
      icon: _yukleniyor
          ? const SizedBox(width: 18, height: 18,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Icon(Icons.auto_awesome),
      label: Text(_yukleniyor ? 'AI Analiz Ediyor...' : 'AI Rota Öner',
          style: const TextStyle(fontWeight: FontWeight.bold)),
      elevation: 6,
    );
  }
}
