// ╔══════════════════════════════════════════════════════════════╗
// ║  DOSYA: lib/screens/rol_yonlendirici.dart                    ║
// ║  Servisim360 — Giriş Sonrası Rol Yönlendirici                ║
// ║  v3 — Belgedeki tüm roller + firmaId/projeId kontrolü        ║
// ╚══════════════════════════════════════════════════════════════╝
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RolYonlendirici extends StatefulWidget {
  const RolYonlendirici({super.key});
  @override
  State<RolYonlendirici> createState() => _RolYonlendiriciState();
}

class _RolYonlendiriciState extends State<RolYonlendirici> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  @override
  void initState() {
    super.initState();
    _yonlendir();
  }

  Future<void> _yonlendir() async {
    // Kısa gecikme — auth state stabilize olsun
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) { _git('/login'); return; }

      final doc = await FirebaseFirestore.instance
          .collection('kullanicilar')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 10));

      if (!doc.exists || doc.data() == null) { _git('/login'); return; }

      final data    = doc.data()!;
      String rol    = (data['rol']    as String? ?? '').trim();
      final durum   = (data['durum']  as String? ?? '').trim();
      final firmaId = (data['firmaId'] as String? ?? '').trim();

      // ── Durum Kontrolleri ──────────────────────────────────
      if (durum == 'beklemede' || durum == 'lisans_bitis') {
        _git('/onay_bekleme'); return;
      }
      if (durum == 'reddedildi' || durum == 'askida') {
        _git('/login'); return;
      }

      // ── Rol Normalize ──────────────────────────────────────
      if (rol == 'super_admin')  rol = 'superAdmin';
      if (rol == 'firma_admin')  rol = 'firmaAdmin';
      if (rol == 'driver')       rol = 'sofor';
      if (rol == 'parent')       rol = 'veli';
      if (rol == 'staff')        rol = 'personel';

      // ── firmaId zorunluluk kontrolü (superAdmin hariç) ─────
      if (rol != 'superAdmin' && firmaId.isEmpty) {
        _hataGoster(
          'Hesabınız bir firmaya bağlanmamış.\nYöneticinizle iletişime geçin.',
        );
        return;
      }

      if (!mounted) return;

      // ── Rol bazlı yönlendirme ─────────────────────────────
      switch (rol) {

        case 'superAdmin':
          _git(kIsWeb ? '/web_panel' : '/super_admin');

        case 'firmaAdmin':
        case 'admin':
          _git(kIsWeb ? '/web_admin' : '/dashboard');

        case 'sofor':
        case 'bireyselSofor':
          _git(kIsWeb ? '/web_sofor' : '/sofor_panel');

        case 'veli':
          _git(kIsWeb ? '/web_veli_panel' : '/veli_panel');

        case 'personel':
          _git('/personel_panel');

        default:
          // Tanımsız rol → düzgün hata mesajı
          _hataGoster(
            'Hesabınız için tanımlı bir rol bulunamadı.\n'
            'Yöneticinizle iletişime geçin.\n\n'
            'Rol: ${rol.isEmpty ? "(boş)" : rol}',
          );
      }
    } catch (e) {
      debugPrint('RolYonlendirici hata: $e');
      if (mounted) _git('/login');
    }
  }

  void _git(String rota) {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, rota);
  }

  void _hataGoster(String mesaj) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => _HataEkrani(mesaj: mesaj),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: _navy,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 32, height: 32,
              child: CircularProgressIndicator(
                  color: _turuncu, strokeWidth: 2.5),
            ),
            SizedBox(height: 16),
            Text('Yükleniyor...',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ── Hata Ekranı ───────────────────────────────────────────────
// Rol/firmaId eksikliğinde kullanıcıya açıklayıcı mesaj gösterir.
class _HataEkrani extends StatelessWidget {
  final String mesaj;
  const _HataEkrani({required this.mesaj});

  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: _turuncu, size: 48),
              ),
              const SizedBox(height: 24),
              const Text('Erişim Sorunu',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(
                mesaj,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.6),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 220,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _turuncu,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    FirebaseAuth.instance.signOut();
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Giriş Ekranına Dön',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
