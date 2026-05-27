import 'package:flutter/material.dart';
import '../services/session_service.dart';

class CompanyLoginScreen extends StatefulWidget {
  const CompanyLoginScreen({super.key});
  @override
  State<CompanyLoginScreen> createState() => _CompanyLoginScreenState();
}

class _CompanyLoginScreenState extends State<CompanyLoginScreen> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  final _emailCtrl = TextEditingController();
  final _sifreCtrl = TextEditingController();
  final _formKey   = GlobalKey<FormState>();

  bool _yukleniyor   = false;
  bool _sifreGizli   = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _sifreCtrl.dispose();
    super.dispose();
  }

  Future<void> _girisYap() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _yukleniyor = true);

    final sonuc = await SessionService.instance.girisYap(
      email: _emailCtrl.text.trim(),
      sifre: _sifreCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _yukleniyor = false);

    if (sonuc['basarili'] == true) {
      Navigator.pushReplacementNamed(context, '/rol');
    } else {
      final hata = sonuc['hata'] as String? ?? 'Giris basarisiz';
      if (hata == 'onay_bekleniyor') {
        Navigator.pushReplacementNamed(context, '/onay_bekleme');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(hata),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const SizedBox(height: 40),

            // Logo
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: _turuncu.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                    color: _turuncu.withValues(alpha: 0.4), width: 2),
              ),
              child: const Center(
                child: Text('S', style: TextStyle(color: _turuncu,
                    fontSize: 40, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Servisim360',
                style: TextStyle(color: Colors.white, fontSize: 24,
                    fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 6),
            Text('Firma Girisi',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14)),
            const SizedBox(height: 40),

            // Form
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Form(
                key: _formKey,
                child: Column(children: [
                  // Email
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-posta',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'E-posta girin';
                      if (!v.contains('@')) return 'Gecersiz e-posta';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Sifre
                  TextFormField(
                    controller: _sifreCtrl,
                    obscureText: _sifreGizli,
                    decoration: InputDecoration(
                      labelText: 'Sifre',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(_sifreGizli
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () =>
                            setState(() => _sifreGizli = !_sifreGizli),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Sifre girin';
                      if (v.length < 6) return 'En az 6 karakter';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Giris butonu
                  SizedBox(
                    width: double.infinity, height: 52,
                    child: ElevatedButton(
                      onPressed: _yukleniyor ? null : _girisYap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _navy,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _yukleniyor
                          ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                          : const Text('Giris Yap',
                          style: TextStyle(fontSize: 16,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sifre sifirla
                  TextButton(
                    onPressed: _sifreSifirla,
                    child: Text('Sifremi Unuttum',
                        style: TextStyle(color: Colors.grey[600])),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 20),

            // Geri
            TextButton.icon(
              onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
              icon: const Icon(Icons.arrow_back_outlined, color: Colors.white54),
              label: const Text('Normal Girise Don',
                  style: TextStyle(color: Colors.white54)),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _sifreSifirla() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Once e-posta adresinizi girin'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    final sonuc = await SessionService.instance.sifreSifirla(email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(sonuc['basarili'] == true
          ? 'Sifre sifirlama e-postasi gonderildi'
          : sonuc['hata'] ?? 'Gonderilemedi'),
      backgroundColor:
      sonuc['basarili'] == true ? Colors.green : Colors.red,
    ));
  }
}
