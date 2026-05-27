import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<double>   _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _animCtrl,
            curve: const Interval(0.0, 0.6, curve: Curves.easeIn)));
    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: _animCtrl,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack)));
    _animCtrl.forward();
    Future.delayed(const Duration(milliseconds: 2000), _yonlendir);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _yonlendir() async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final onboardingOk = prefs.getBool('onboarding_tamamlandi') ?? false;
    if (!onboardingOk) {
      if (mounted) Navigator.pushReplacementNamed(context, '/onboarding');
      return;
    }

    final auth = AuthService();
    final kullanici = await auth.sessionKontrol();

    if (!mounted) return;

    if (kullanici == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final rota = auth.rolRotasi(kullanici);
    Navigator.pushReplacementNamed(context, rota);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      body: Center(
        child: AnimatedBuilder(
          animation: _animCtrl,
          builder: (_, __) => FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 110, height: 110,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20, offset: const Offset(0, 8),
                      )],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: Image.asset('assets/logo_app.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Text('S', style: TextStyle(
                              color: _turuncu, fontSize: 60,
                              fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Servisim360', style: TextStyle(
                      color: Colors.white, fontSize: 30,
                      fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const SizedBox(height: 6),
                  const Text('Akıllı Servis Yönetim Sistemi',
                      style: TextStyle(
                          color: Colors.white54, fontSize: 13,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 48),
                  const SizedBox(width: 28, height: 28,
                      child: CircularProgressIndicator(
                          color: _turuncu, strokeWidth: 2.5)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}