import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/session_service.dart';

class OnayBeklemeScreen extends StatefulWidget {
  const OnayBeklemeScreen({super.key});

  @override
  State<OnayBeklemeScreen> createState() => _OnayBeklemeScreenState();
}

class _OnayBeklemeScreenState extends State<OnayBeklemeScreen>
    with SingleTickerProviderStateMixin {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  static const _wpNumara = '905533498766';

  late AnimationController _animCtrl;
  late Animation<double> _pulseAnim;
  bool _kontrol = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.9, end: 1.1).animate(
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _durumKontrol() async {
    setState(() => _kontrol = true);
    try {
      final sonuc = await SessionService.instance.girisKontrol();
      if (!mounted) return;
      if (sonuc['girisYapilmis'] == true) {
        Navigator.pushReplacementNamed(context, '/rol');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Henuz onaylanmadi, bekleyin...'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _kontrol = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: _navy,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animasyonlu ikon
              ScaleTransition(
                scale: _pulseAnim,
                child: Container(
                  width: 110, height: 110,
                  decoration: BoxDecoration(
                    color: _turuncu.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: _turuncu.withValues(alpha: 0.4), width: 2),
                  ),
                  child: const Icon(Icons.hourglass_top_rounded, color: _turuncu, size: 52),
                ),
              ),
              const SizedBox(height: 28),

              const Text('Onay Bekleniyor',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              Text(
                'Basvurunuz incelemeye alindi.\nYonetici onayladiktan sonra giris yapabilirsiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 15, height: 1.6),
              ),

              if (email.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _turuncu.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _turuncu.withValues(alpha: 0.3)),
                  ),
                  child: Text(email,
                      style: const TextStyle(color: _turuncu, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],

              const SizedBox(height: 12),

              // Durum gostergesi
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _AdimSatiri(ikon: Icons.check_circle_rounded, renk: Colors.green,
                        metin: 'Basvuru alindi', tamamlandi: true),
                    const SizedBox(height: 8),
                    _AdimSatiri(ikon: Icons.hourglass_top_rounded, renk: _turuncu,
                        metin: 'Inceleniyor...', tamamlandi: false, aktif: true),
                    const SizedBox(height: 8),
                    _AdimSatiri(ikon: Icons.login_rounded, renk: Colors.white38,
                        metin: 'Giris yapabilirsiniz', tamamlandi: false),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // WhatsApp butonu
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    final mesaj = Uri.encodeComponent(
                        'Merhaba, Servisim360 basvurum onay bekliyor.\nE-posta: $email');
                    final url = Uri.parse('https://wa.me/$_wpNumara?text=$mesaj');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.message_outlined, color: Colors.white),
                  label: const Text('WhatsApp ile Iletisim',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 10),

              // Durum kontrol butonu
              SizedBox(
                width: double.infinity, height: 52,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white30),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _kontrol ? null : _durumKontrol,
                  icon: _kontrol
                      ? const SizedBox(height: 18, width: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.refresh_rounded),
                  label: const Text('Onay Durumunu Kontrol Et'),
                ),
              ),
              const SizedBox(height: 20),

              TextButton(
                onPressed: () async {
                  await SessionService.instance.cikisYap();
                  if (!mounted) return;
                  Navigator.pushReplacementNamed(context, '/login');
                },
                child: Text('Cikis Yap',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdimSatiri extends StatelessWidget {
  final IconData ikon;
  final Color renk;
  final String metin;
  final bool tamamlandi;
  final bool aktif;

  const _AdimSatiri({
    required this.ikon,
    required this.renk,
    required this.metin,
    required this.tamamlandi,
    this.aktif = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(ikon, color: renk, size: 20),
      const SizedBox(width: 10),
      Text(metin, style: TextStyle(
        color: tamamlandi || aktif ? Colors.white : Colors.white38,
        fontSize: 13,
        fontWeight: aktif ? FontWeight.bold : FontWeight.normal,
      )),
      if (aktif) ...[
        const SizedBox(width: 6),
        const SizedBox(height: 12, width: 12,
            child: CircularProgressIndicator(color: Color(0xFFFF8C00), strokeWidth: 1.5)),
      ],
    ]);
  }
}
