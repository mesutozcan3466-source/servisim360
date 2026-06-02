import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/session_service.dart';
import 'web_super_admin.dart';
import 'web_admin_panel.dart';
import 'web_veli_panel.dart';
import 'web_sofor_panel.dart';
import 'veli_basvuru_form_screen.dart';

// ════════════════════════════════════════════════════════════════
// WEB GİRİŞ YÖNLENDİRİCİ
// URL'ye göre doğru ekranı açar:
//   /                 → Login veya rol paneli
//   /kayit/LINK_ID    → Veli kayıt formu (giriş gerekmez)
//   /basvuru/LINK_ID  → Veli kayıt formu (giriş gerekmez)
// ════════════════════════════════════════════════════════════════
class WebGirisYonlendirici extends StatefulWidget {
  const WebGirisYonlendirici({super.key});
  @override
  State<WebGirisYonlendirici> createState() =>
      _WebGirisYonlendiriciState();
}

class _WebGirisYonlendiriciState extends State<WebGirisYonlendirici> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  bool    _yukleniyor = true;
  String? _hataMesaj;

  @override
  void initState() {
    super.initState();
    _baslat();
  }

  Future<void> _baslat() async {
    // Web URL'sinden link kontrolü
    final linkId = _urldenLinkId();
    if (linkId != null && linkId.isNotEmpty) {
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (_) => VeliBasvuruFormScreen(linkId: linkId)));
      }
      return;
    }
    await _rolKontrol();
  }

  // Web URL'sinden linkId çıkar
  // servisim360.web.app/kayit/ABC123
  // servisim360.web.app/#/kayit/ABC123
  String? _urldenLinkId() {
    try {
      // ignore: undefined_prefixed_name
      // flutter web'de Uri.base kullanılır
      final uri = Uri.base;
      final segments = uri.pathSegments;

      // /kayit/LINK_ID veya /basvuru/LINK_ID
      if (segments.length >= 2 &&
          (segments[0] == 'kayit' || segments[0] == 'basvuru')) {
        return segments[1];
      }

      // Hash routing: /#/kayit/LINK_ID
      final fragment = uri.fragment;
      if (fragment.isNotEmpty) {
        final fSegments = fragment.split('/').where((s) => s.isNotEmpty).toList();
        if (fSegments.length >= 2 &&
            (fSegments[0] == 'kayit' || fSegments[0] == 'basvuru')) {
          return fSegments[1];
        }
      }

      // Query param: ?linkId=ABC123
      final linkId = uri.queryParameters['linkId'] ??
                     uri.queryParameters['id']     ??
                     uri.queryParameters['link'];
      return linkId;
    } catch (_) {
      return null;
    }
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
      final rol     = doc.data()?['rol'] as String? ?? '';
      final firmaId = doc.data()?['firmaId'] as String? ?? '';

      // Session'a firmaId yaz
      if (firmaId.isNotEmpty) {
        SessionService.instance.cachedFirmaIdSet(firmaId);
      }

      if (!mounted) return;

      if (_superAdminMi(rol)) {
        Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (_) => const WebSuperAdminSayfasi()));
      } else if (_firmaAdminMi(rol)) {
        Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (_) => const WebAdminPanel()));
      } else if (rol == 'sofor') {
        // Şoför web paneline girebilir (sadece liste görünümü)
        Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (_) => const WebSoforPanel()));
      } else if (rol == 'veli') {
        // Veli web paneline girebilir
        Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (_) => const WebVeliPanel()));
      } else {
        setState(() {
          _yukleniyor  = false;
          _hataMesaj   = rol;
        });
      }
    } catch (e) {
      setState(() { _yukleniyor = false; _hataMesaj = 'error'; });
    }
  }

  bool _superAdminMi(String r) =>
      r == 'superAdmin' || r == 'superadmin' || r == 'super_admin';
  bool _firmaAdminMi(String r) =>
      r == 'firmaAdmin' || r == 'admin' || r == 'kolejAdmin' ||
      r == 'firma_admin' || r == 'sekreter';

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return const Scaffold(
        backgroundColor: _navy,
        body: Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _turuncu),
            SizedBox(height: 20),
            Text('Servisim360 yukleniyor...',
                style: TextStyle(color: Colors.white70, fontSize: 16)),
          ],
        )),
      );
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const _WebLoginEkrani();
    return _YanlisRolEkrani(rol: _hataMesaj ?? '');
  }
}

// ════════════════════════════════════════════════════════════════
// WEB LOGIN
// ════════════════════════════════════════════════════════════════
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
  bool    _yukleniyor = false;
  bool    _sifreGoster = false;
  String? _hata;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _sifreCtrl.dispose();
    super.dispose();
  }

  Future<void> _girisYap() async {
    if (_emailCtrl.text.trim().isEmpty || _sifreCtrl.text.trim().isEmpty) {
      setState(() => _hata = 'E-posta ve sifre giriniz.');
      return;
    }
    setState(() { _yukleniyor = true; _hata = null; });
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _sifreCtrl.text.trim(),
      );
      final doc = await FirebaseFirestore.instance
          .collection('kullanicilar').doc(cred.user!.uid).get();
      final rol     = doc.data()?['rol']     as String? ?? '';
      final firmaId = doc.data()?['firmaId'] as String? ?? '';

      if (firmaId.isNotEmpty) {
        SessionService.instance.cachedFirmaIdSet(firmaId);
      }

      if (!mounted) return;

      if (_superAdminMi(rol)) {
        Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (_) => const WebSuperAdminSayfasi()));
      } else if (_firmaAdminMi(rol)) {
        Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (_) => const WebAdminPanel()));
      } else if (rol == 'sofor') {
        Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (_) => const WebSoforPanel()));
      } else if (rol == 'veli') {
        Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (_) => const WebVeliPanel()));
      } else {
        await FirebaseAuth.instance.signOut();
        setState(() {
          _hata = rol.isEmpty
              ? 'Hesap bulunamadi.'
              : 'Bu rol web panelini kullanamaz.';
          _yukleniyor = false;
        });
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _hata = switch (e.code) {
          'user-not-found'  => 'E-posta adresi bulunamadi.',
          'wrong-password'  => 'Sifre yanlis.',
          'invalid-email'   => 'Gecersiz e-posta adresi.',
          'user-disabled'   => 'Hesap devre disi birakildi.',
          'too-many-requests' => 'Cok fazla deneme. Lutfen bekleyin.',
          _                 => 'Giris hatasi: ${e.message}',
        };
        _yukleniyor = false;
      });
    } catch (e) {
      setState(() { _hata = 'Hata: $e'; _yukleniyor = false; });
    }
  }

  bool _superAdminMi(String r) =>
      r == 'superAdmin' || r == 'superadmin' || r == 'super_admin';
  bool _firmaAdminMi(String r) =>
      r == 'firmaAdmin' || r == 'admin' || r == 'kolejAdmin' ||
      r == 'firma_admin' || r == 'sekreter';

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final darGenis = w > 600;

    return Scaffold(
      backgroundColor: _navy,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
              horizontal: darGenis ? 0 : 24, vertical: 40),
          child: Container(
            width: darGenis ? 440 : double.infinity,
            padding: EdgeInsets.all(darGenis ? 40 : 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(darGenis ? 24 : 20),
              boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 40,
                  offset: const Offset(0, 20))],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [

              // Logo
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                    color: _navy,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(
                        color: _navy.withValues(alpha: 0.3),
                        blurRadius: 16, offset: const Offset(0, 8))]),
                child: const Center(child: Text('S', style: TextStyle(
                    color: Colors.white, fontSize: 38,
                    fontWeight: FontWeight.bold))),
              ),
              const SizedBox(height: 18),
              const Text('Servisim360', style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.bold, color: _navy)),
              const Text('Yonetim Paneli', style: TextStyle(
                  color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 32),

              // Email
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'E-posta',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),

              // Şifre
              TextField(
                controller: _sifreCtrl,
                obscureText: !_sifreGoster,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _girisYap(),
                decoration: InputDecoration(
                  labelText: 'Sifre',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_sifreGoster
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () =>
                        setState(() => _sifreGoster = !_sifreGoster),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),

              // Hata
              if (_hata != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3))),
                  child: Row(children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_hata!, style: const TextStyle(
                        color: Colors.red, fontSize: 13))),
                  ]),
                ),
              ],
              const SizedBox(height: 22),

              // Giriş butonu
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: _yukleniyor ? null : _girisYap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _yukleniyor
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Giris Yap', style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),

              // Alt bilgi
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10)),
                child: Column(children: [
                  const Row(children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.grey),
                    SizedBox(width: 6),
                    Text('Web paneli rolleri:', style: TextStyle(
                        fontSize: 11, color: Colors.grey,
                        fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 6),
                  _rolBilgiSatir(Icons.admin_panel_settings_outlined,
                      'Firma Admin', 'Tam yonetim paneli', _navy),
                  _rolBilgiSatir(Icons.directions_bus_outlined,
                      'Sofor', 'Ogrenci listesi, devamsizlik', Colors.teal),
                  _rolBilgiSatir(Icons.family_restroom_outlined,
                      'Veli', 'Canli takip, bildirimler', _turuncu),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _rolBilgiSatir(IconData icon, String rol, String acik, Color renk) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(icon, size: 14, color: renk),
        const SizedBox(width: 6),
        Text('$rol: ', style: TextStyle(
            fontSize: 11, color: renk, fontWeight: FontWeight.bold)),
        Text(acik, style: const TextStyle(
            fontSize: 11, color: Colors.grey)),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// YANLIŞ ROL UYARISI
// ════════════════════════════════════════════════════════════════
class _YanlisRolEkrani extends StatelessWidget {
  final String rol;
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  const _YanlisRolEkrani({required this.rol});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      body: Center(
        child: Container(
          width: 400, padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.warning_amber_rounded,
                size: 64, color: _turuncu),
            const SizedBox(height: 16),
            const Text('Erisim Engellendi', style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: _navy)),
            const SizedBox(height: 12),
            Text(
              rol.isEmpty
                  ? 'Rol bilgisi tanimli degil. Yoneticinizle iletisime gecin.'
                  : '"$rol" rolu icin ozel bir panel tanimli degil.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.pushReplacement(context, MaterialPageRoute(
                      builder: (_) => const WebGirisYonlendirici()));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _navy),
              icon: const Icon(Icons.logout_outlined, color: Colors.white),
              label: const Text('Cikis Yap',
                  style: TextStyle(color: Colors.white)),
            ),
          ]),
        ),
      ),
    );
  }
}
