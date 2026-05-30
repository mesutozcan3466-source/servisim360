import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/session_service.dart';
import 'web_super_admin.dart';
import 'web_admin_panel.dart'; // firma admin için

class WebGirisYonlendirici extends StatefulWidget {
  const WebGirisYonlendirici({super.key});

  @override
  State<WebGirisYonlendirici> createState() => _WebGirisYonlendiriciState();
}

class _WebGirisYonlendiriciState extends State<WebGirisYonlendirici> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  bool    _yukleniyor = true;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _rolKontrol();
  }

  Future<void> _rolKontrol() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _yukleniyor = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('kullanicilar').doc(user.uid).get();
      final rol = doc.data()?['rol'] as String? ?? '';

      if (!mounted) return;

      if (rol == 'superAdmin') {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const WebSuperAdmin()));
      } else if (rol == 'admin' || rol == 'firmaAdmin' || rol == 'kolejAdmin') {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const WebAdminPanel()));
      } else {
        // Şoför veya veli web'e girmeye çalışıyor
        setState(() {
          _yukleniyor = false;
          _hata = rol;
        });
      }
    } catch (e) {
      setState(() { _yukleniyor = false; _hata = 'error'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (_yukleniyor) {
      return const Scaffold(
        backgroundColor: _navy,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: _turuncu),
              SizedBox(height: 20),
              Text('Servisim360 yukleniyor...',
                  style: TextStyle(color: Colors.white70, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    // Giriş yapılmamış
    if (user == null) {
      return const _WebLoginEkrani();
    }

    // Yanlış rol (şoför/veli)
    return _YanlisRolEkrani(rol: _hata ?? '');
  }
}

// ── Web Login ─────────────────────────────────────────────────────
class _WebLoginEkrani extends StatefulWidget {
  const _WebLoginEkrani();

  @override
  State<_WebLoginEkrani> createState() => _WebLoginEkraniState();
}

class _WebLoginEkraniState extends State<_WebLoginEkrani> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  final _emailCtrl = TextEditingController();
  final _sifreCtrl = TextEditingController();
  bool  _yukleniyor = false;
  String? _hata;

  Future<void> _girisYap() async {
    setState(() { _yukleniyor = true; _hata = null; });
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _sifreCtrl.text.trim(),
      );

      final doc = await FirebaseFirestore.instance
          .collection('kullanicilar').doc(cred.user!.uid).get();
      final rol = doc.data()?['rol'] as String? ?? '';

      await SessionService.instance.firmaldAl();

      if (!mounted) return;

      if (rol == 'superAdmin') {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const WebSuperAdmin()));
      } else if (rol == 'admin' || rol == 'firmaAdmin' || rol == 'kolejAdmin') {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const WebAdminPanel()));
      } else {
        await FirebaseAuth.instance.signOut();
        setState(() {
          _hata = 'Web paneline sadece Admin ve Super Admin girebilir.';
          _yukleniyor = false;
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _hata = e.code == 'user-not-found'
            ? 'Kullanici bulunamadi'
            : e.code == 'wrong-password'
            ? 'Sifre yanlis'
            : 'Giris hatasi: ${e.message}';
        _yukleniyor = false;
      });
    } catch (e) {
      setState(() { _hata = 'Hata: $e'; _yukleniyor = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      body: Center(
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo
              Container(
                width: 70, height: 70,
                decoration: BoxDecoration(
                  color: _navy,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Center(
                  child: Text('S',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Servisim360',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _navy)),
              const Text('Yonetim Paneli',
                  style: TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 32),

              // Email
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'E-posta',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // Şifre
              TextField(
                controller: _sifreCtrl,
                obscureText: true,
                onSubmitted: (_) => _girisYap(),
                decoration: InputDecoration(
                  labelText: 'Sifre',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),

              if (_hata != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_hata!,
                        style: const TextStyle(
                            color: Colors.red, fontSize: 13))),
                  ]),
                ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _yukleniyor ? null : _girisYap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _yukleniyor
                      ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : const Text('Giris Yap',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 20),
              Text(
                'Sadece Admin ve Super Admin girebilir.\n'
                    'Sofor ve Veli icin mobil uygulamayi kullanin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Yanlış Rol Uyarısı ────────────────────────────────────────────
class _YanlisRolEkrani extends StatelessWidget {
  final String rol;
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  const _YanlisRolEkrani({required this.rol});

  @override
  Widget build(BuildContext context) {
    final mesaj = rol == 'sofor'
        ? 'Sofor hesabi web panelini kullanamazsiniz.\nLutfen mobil uygulamayi kullanin.'
        : rol == 'veli'
        ? 'Veli hesabi web panelini kullanamazsiniz.\nLutfen mobil uygulamayi kullanin.'
        : 'Bu hesap web paneline erisemez.';

    return Scaffold(
      backgroundColor: _navy,
      body: Center(
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.phone_android, size: 64, color: _turuncu),
              const SizedBox(height: 20),
              const Text('Mobil Uygulama Gerekli',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _navy)),
              const SizedBox(height: 12),
              Text(mesaj,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.grey[600], fontSize: 14)),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                            const WebGirisYonlendirici()));
                  }
                },
                icon: const Icon(Icons.logout_outlined),
                label: const Text('Cikis Yap'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: _navy,
                    side: const BorderSide(color: _navy)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}