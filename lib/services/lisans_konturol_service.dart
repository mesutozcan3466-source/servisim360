import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/session_service.dart';

// ════════════════════════════════════════════════════════════════
//  LİSANS KONTROL SERVİSİ
//  splash_screen ve dashboard_screen tarafından çağrılır.
//  firms/{firmaId}.lisansBitis tarihi geçmişse uyarı gösterir.
// ════════════════════════════════════════════════════════════════
class LisansKontrolService {
  LisansKontrolService._();

  /// Lisansı kontrol et. Sorun varsa context ile uyarı göster.
  /// Lisans geçerliyse `true`, süresi dolmuşsa `false` döner.
  static Future<bool> kontrol(BuildContext context) async {
    try {
      final firmaId = await SessionService.instance.firmaldAl();
      if (firmaId == null || firmaId.isEmpty) return true;

      final doc = await FirebaseFirestore.instance
          .collection('firms').doc(firmaId).get();
      if (!doc.exists) return true;

      final data = doc.data()!;

      // Firma askıya alınmış mı?
      final durum = data['durum'] as String? ?? 'aktif';
      if (durum == 'askida') {
        if (context.mounted) _uyariGoster(context,
          baslik: 'Hesap Askiya Alindi',
          mesaj: 'Hesabiniz gecici olarak askiya alindi. '
              'Lutfen yoneticinizle iletisime gecin.',
          ikon: Icons.pause_circle_outline,
          renk: Colors.orange,
        );
        return false;
      }

      // Lisans tarihi kontrolü
      final lisansBitis = data['lisansBitis'];
      DateTime? bitisTarih;
      if (lisansBitis is Timestamp) {
        bitisTarih = lisansBitis.toDate();
      } else if (lisansBitis is String) {
        bitisTarih = DateTime.tryParse(lisansBitis);
      }

      if (bitisTarih == null) return true; // Tarih yoksa geçerli

      final now    = DateTime.now();
      final kalan  = bitisTarih.difference(now).inDays;

      if (bitisTarih.isBefore(now)) {
        // Süresi dolmuş
        if (context.mounted) _uyariGoster(context,
          baslik: 'Lisans Suresi Doldu',
          mesaj: 'Lisansinizin suresi ${bitisTarih.day}.${bitisTarih.month}.${bitisTarih.year} '
              'tarihinde doldu. Devam etmek icin yenileyin.',
          ikon: Icons.lock_outline,
          renk: Colors.red,
          kritik: true,
        );
        return false;
      } else if (kalan <= 7) {
        // 7 gün kala uyarı (engellemez)
        if (context.mounted) _uyariGoster(context,
          baslik: 'Lisans Yakinda Bitiyor',
          mesaj: 'Lisansiniz $kalan gun sonra sona erecek. '
              'Lutfen yenilemeyi unutmayin.',
          ikon: Icons.warning_amber_outlined,
          renk: Colors.orange,
          kritik: false,
        );
        return true; // Uyarı ver ama devam et
      }

      return true;
    } catch (_) {
      return true; // Kontrol yapılamazsa erişime izin ver
    }
  }

  static void _uyariGoster(
      BuildContext context, {
        required String baslik,
        required String mesaj,
        required IconData ikon,
        required Color renk,
        bool kritik = false,
      }) {
    showDialog(
      context: context,
      barrierDismissible: !kritik,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(ikon, color: renk, size: 24),
          const SizedBox(width: 8),
          Expanded(child: Text(baslik,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: renk))),
        ]),
        content: Text(mesaj, style: const TextStyle(fontSize: 13, height: 1.5)),
        actions: [
          if (!kritik)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tamam'),
            ),
          if (kritik) ...[
            TextButton(
              onPressed: () async {
                await SessionService.instance.cikisYap();
                if (context.mounted) {
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
              child: const Text('Cikis Yap', style: TextStyle(color: Colors.red)),
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  LİSANS UYARI EKRANI — kritik durumlarda tam sayfa gösterilir
// ════════════════════════════════════════════════════════════════
class LisansUyariEkrani extends StatelessWidget {
  final String mesaj;
  final bool askida;
  const LisansUyariEkrani({super.key, required this.mesaj, this.askida = false});

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF1a3a6b);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
                color: (askida ? Colors.orange : Colors.red).withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child: Icon(
                askida ? Icons.pause_circle_outline : Icons.lock_outline,
                color: askida ? Colors.orange : Colors.red, size: 48),
          ),
          const SizedBox(height: 24),
          Text(askida ? 'Hesap Askiya Alindi' : 'Lisans Suresi Doldu',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: navy)),
          const SizedBox(height: 12),
          Text(mesaj, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5)),
          const SizedBox(height: 32),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: navy, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              await SessionService.instance.cikisYap();
              if (context.mounted) Navigator.pushReplacementNamed(context, '/login');
            },
            icon: const Icon(Icons.logout_outlined),
            label: const Text('Cikis Yap', style: TextStyle(fontWeight: FontWeight.bold)),
          )),
        ]),
      )),
    );
  }
}
