import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  final _ctrl = PageController();
  int _sayfa  = 0;

  static const _sayfalar = [
    {
      'ikon':     Icons.directions_bus_outlined,
      'baslik':   'Servisim360',
      'aciklama': 'Akilli okul servis yonetim sistemi. Ogrenciler, soforler ve veliler icin.',
    },
    {
      'ikon':     Icons.map_outlined,
      'baslik':   'Canli Takip',
      'aciklama': 'Araclarin anlik konumunu harita uzerinde takip edin.',
    },
    {
      'ikon':     Icons.family_restroom_outlined,
      'baslik':   'Veli Bildirimi',
      'aciklama': 'Veliler servisi canli izleyebilir, devamsizlik bildirebilir.',
    },
  ];

  Future<void> _tamamla() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_tamamlandi', true);
    if (mounted) _anaEkranaGit();
  }

  void _anaEkranaGit() {
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      body: SafeArea(
        child: Column(
          children: [
            // Slider
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                onPageChanged: (i) => setState(() => _sayfa = i),
                itemCount: _sayfalar.length,
                itemBuilder: (_, i) {
                  final s = _sayfalar[i];
                  return Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(color: _turuncu.withValues(alpha: 0.3), width: 2),
                          ),
                          child: Icon(s['ikon'] as IconData, color: _turuncu, size: 64),
                        ),
                        const SizedBox(height: 40),
                        Text(s['baslik'] as String,
                            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        Text(s['aciklama'] as String,
                            style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.6),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Nokta indikatoru
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_sayfalar.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _sayfa == i ? 24 : 8, height: 8,
                decoration: BoxDecoration(
                  color: _sayfa == i ? _turuncu : Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
            ),

            const SizedBox(height: 40),

            // Son sayfada 3 secenek, diger sayfalarda Devam butonu
            if (_sayfa < _sayfalar.length - 1) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _turuncu,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _ctrl.nextPage(
                        duration: const Duration(milliseconds: 300), curve: Curves.ease),
                    child: const Text('Devam', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _ctrl.animateToPage(_sayfalar.length - 1,
                    duration: const Duration(milliseconds: 400), curve: Curves.ease),
                child: const Text('Atla', style: TextStyle(color: Colors.white54)),
              ),
            ] else ...[
              // Ana secenekler
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _AnaSecenek(
                      ikon: Icons.business_rounded,
                      renk: _turuncu,
                      baslik: 'Firma Kaydol',
                      aciklama: 'Okul servisi firmanizi kaydedin',
                      onTap: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('onboarding_tamamlandi', true);
                        if (mounted) Navigator.pushReplacementNamed(context, '/kayit');
                      },
                    ),
                    const SizedBox(height: 12),
                    _AnaSecenek(
                      ikon: Icons.drive_eta_rounded,
                      renk: Colors.teal,
                      baslik: 'Bireysel Sofor',
                      aciklama: 'Tek basina calisiyorsaniz buradan',
                      onTap: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('onboarding_tamamlandi', true);
                        if (mounted) Navigator.pushReplacementNamed(context, '/bireysel_sofor_basvuru');
                      },
                    ),
                    const SizedBox(height: 12),
                    _AnaSecenek(
                      ikon: Icons.login_rounded,
                      renk: const Color(0xFF1a3a6b),
                      baslik: 'Giris Yap',
                      aciklama: 'Hesabiniz varsa giris yapin',
                      beyazArkaplan: true,
                      onTap: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('onboarding_tamamlandi', true);
                        if (mounted) Navigator.pushReplacementNamed(context, '/login');
                      },
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _AnaSecenek extends StatelessWidget {
  final IconData ikon;
  final Color renk;
  final String baslik;
  final String aciklama;
  final VoidCallback onTap;
  final bool beyazArkaplan;

  const _AnaSecenek({
    required this.ikon,
    required this.renk,
    required this.baslik,
    required this.aciklama,
    required this.onTap,
    this.beyazArkaplan = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: beyazArkaplan ? Colors.white : renk,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: beyazArkaplan ? renk.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(ikon, color: beyazArkaplan ? renk : Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(baslik, style: TextStyle(
                        color: beyazArkaplan ? renk : Colors.white,
                        fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(aciklama, style: TextStyle(
                        color: beyazArkaplan ? Colors.grey : Colors.white70,
                        fontSize: 12)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: beyazArkaplan ? renk.withValues(alpha: 0.5) : Colors.white60,
                  size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
