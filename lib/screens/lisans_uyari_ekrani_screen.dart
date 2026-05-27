import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/lisans_kontrol.dart';
import '../services/session_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// LİSANS UYARI EKRANI
// ═══════════════════════════════════════════════════════════════════════════

class LisansUyariEkrani extends StatelessWidget {
  final LisansDurum durum;
  final VoidCallback? onDevamEt;

  const LisansUyariEkrani({
    super.key,
    required this.durum,
    this.onDevamEt,
  });

  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  color: _renkAl().withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: _renkAl().withValues(alpha: 0.4), width: 2),
                ),
                child: Center(
                  child: Icon(_ikonAl(), color: _renkAl(), size: 50),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                _baslikAl(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _aciklamaAl(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 40),

              if (durum == LisansDurum.suresiDolmus ||
                  durum == LisansDurum.beklemede) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _turuncu,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _whatsappAc,
                    icon: const Icon(Icons.message, color: Colors.white),
                    label: const Text(
                      'WhatsApp ile Iletisim',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              if (onDevamEt != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: onDevamEt,
                    child: const Text('Anladim, Devam Et'),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              TextButton(
                onPressed: () async {
                  await SessionService.instance.cikisYap();
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                },
                child: Text(
                  'Cikis Yap',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _renkAl() {
    switch (durum) {
      case LisansDurum.suresiDolmus: return Colors.red;
      case LisansDurum.beklemede:    return _turuncu;
      case LisansDurum.askiya:       return Colors.orange;
      case LisansDurum.reddedildi:   return Colors.red;
      default:                       return Colors.grey;
    }
  }

  IconData _ikonAl() {
    switch (durum) {
      case LisansDurum.suresiDolmus: return Icons.timer_off_outlined;
      case LisansDurum.beklemede:    return Icons.hourglass_empty_outlined;
      case LisansDurum.askiya:       return Icons.pause_circle_outlined;
      case LisansDurum.reddedildi:   return Icons.cancel_outlined;
      default:                       return Icons.error_outline;
    }
  }

  String _baslikAl() {
    switch (durum) {
      case LisansDurum.suresiDolmus: return 'Lisans Suresi Doldu';
      case LisansDurum.beklemede:    return 'Hesabiniz Onay Bekliyor';
      case LisansDurum.askiya:       return 'Hesabiniz Askiya Alindi';
      case LisansDurum.reddedildi:   return 'Basvurunuz Reddedildi';
      default:                       return 'Erisim Engellendi';
    }
  }

  String _aciklamaAl() {
    switch (durum) {
      case LisansDurum.suresiDolmus:
        return 'Servisim360 lisansinizin suresi dolmustur.\n'
            'Devam etmek icin lisansinizi yenileyin.';
      case LisansDurum.beklemede:
        return 'Hesabiniz henuz onaylanmamistir.\n'
            'Yoneticiniz en kisa surede inceleyecektir.';
      case LisansDurum.askiya:
        return 'Hesabiniz gecici olarak askiya alinmistir.\n'
            'Detay icin destek ekibiyle iletisime gecin.';
      case LisansDurum.reddedildi:
        return 'Basvurunuz reddedilmistir.\n'
            'Detay icin destek ekibiyle iletisime gecin.';
      default:
        return 'Bu hesap icin erisim izni bulunmuyor.\n'
            'Lutfen destek ekibiyle iletisime gecin.';
    }
  }

  Future<void> _whatsappAc() async {
    // Kendi destek numaranizi girin (90 ile baslayan format)
    const tel  = '905XXXXXXXXX';
    final mesaj = Uri.encodeComponent(
        'Merhaba, Servisim360 lisans yenileme hakkinda bilgi almak istiyorum.');
    final url = Uri.parse('https://wa.me/$tel?text=$mesaj');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LİSANS KONTROL HELPER
// Admin/Sofor ekranlarinin initState'inde cagrilir
// ═══════════════════════════════════════════════════════════════════════════

class LisansKontrolHelper {
  /// Lisans durumunu kontrol et, sorunluysa uyari ekranina yonlendir
  static Future<void> kontrol(BuildContext context) async {
    final durum = await LisansKontrol.kontrol();
    if (!context.mounted) return;

    switch (durum) {
      case LisansDurum.gecerli:
        return; // Devam et

      case LisansDurum.suresiDolmus:
      case LisansDurum.beklemede:
      case LisansDurum.askiya:
      case LisansDurum.reddedildi:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => LisansUyariEkrani(durum: durum),
          ),
        );
        break;

      case LisansDurum.girisYapilmamis:
        Navigator.pushReplacementNamed(context, '/login');
        break;

      case LisansDurum.bulunamadi:
      case LisansDurum.hata:
        break; // Sessizce devam et
    }
  }

  /// Lisans bitis tarihine kalan gun
  static Future<int?> kalanGun() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('kullanicilar').doc(uid).get();
      final lisansBitis = doc.data()?['lisansBitis'];
      if (lisansBitis == null) return null;
      final bitis = (lisansBitis as Timestamp).toDate();
      return bitis.difference(DateTime.now()).inDays;
    } catch (_) {
      return null;
    }
  }
}
