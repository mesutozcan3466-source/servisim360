// ╔══════════════════════════════════════════════════════════════╗
// ║  DOSYA: lib/screens/login_screen.dart                        ║
// ║  Servisim360 — 3 Tip Giriş Ekranı                           ║
// ║  v3 — FirmaAdmin / Şoför / Veli+Personel ayrı sekmeler      ║
// ╚══════════════════════════════════════════════════════════════╝
import 'package:flutter/material.dart';
import '../services/session_service.dart';
import 'rol_yonlendirici.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {

  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  late TabController _tab;

  final _adminEmailCtrl     = TextEditingController();
  final _adminSifreCtrl     = TextEditingController();
  bool  _adminSifreGoster   = false;

  final _soforKullaniciCtrl = TextEditingController();
  final _soforSifreCtrl     = TextEditingController();
  bool  _soforSifreGoster   = false;

  final _veliKullaniciCtrl  = TextEditingController();
  final _veliSifreCtrl      = TextEditingController();
  bool  _veliSifreGoster    = false;

  bool    _yukleniyor = false;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() => setState(() => _hata = null));
  }

  @override
  void dispose() {
    _tab.dispose();
    _adminEmailCtrl.dispose();    _adminSifreCtrl.dispose();
    _soforKullaniciCtrl.dispose(); _soforSifreCtrl.dispose();
    _veliKullaniciCtrl.dispose(); _veliSifreCtrl.dispose();
    super.dispose();
  }

  // ── Giriş İşlemleri ──────────────────────────────────────────

  Future<void> _adminGiris() async {
    final email = _adminEmailCtrl.text.trim();
    final sifre = _adminSifreCtrl.text;
    if (email.isEmpty || sifre.isEmpty) {
      setState(() => _hata = 'E-posta ve şifre boş olamaz');
      return;
    }
    setState(() { _yukleniyor = true; _hata = null; });

    final sonuc = await SessionService.instance.girisYap(
        email: email, sifre: sifre);

    if (!mounted) return;
    setState(() => _yukleniyor = false);

    if (!sonuc['basarili']) {
      final hata = sonuc['hata'] as String? ?? 'Giriş başarısız';
      if (hata == 'onay_bekleniyor') { _onayBeklemeGit(); return; }
      setState(() => _hata = hata);
      return;
    }

    final rol = sonuc['rol'] as String? ?? '';
    if (rol != 'firmaAdmin' && rol != 'admin' && rol != 'superAdmin') {
      await SessionService.instance.cikisYap();
      setState(() => _hata = 'Bu giriş tipi Firma Admin içindir');
      return;
    }
    _yonlendir();
  }

  Future<void> _soforGiris() async {
    final ku = _soforKullaniciCtrl.text.trim();
    final si = _soforSifreCtrl.text;
    if (ku.isEmpty || si.isEmpty) {
      setState(() => _hata = 'Kullanıcı adı ve şifre boş olamaz');
      return;
    }
    setState(() { _yukleniyor = true; _hata = null; });

    final sonuc = await SessionService.instance.kullaniciAdiIleGiris(
        kullaniciAdi: ku, sifre: si, beklenenRol: 'sofor');

    if (!mounted) return;
    setState(() => _yukleniyor = false);

    if (!sonuc['basarili']) {
      final hata = sonuc['hata'] as String? ?? 'Giriş başarısız';
      if (hata == 'onay_bekleniyor') { _onayBeklemeGit(); return; }
      setState(() => _hata = hata);
      return;
    }
    _yonlendir();
  }

  Future<void> _veliPersonelGiris() async {
    final ku = _veliKullaniciCtrl.text.trim();
    final si = _veliSifreCtrl.text;
    if (ku.isEmpty || si.isEmpty) {
      setState(() => _hata = 'Kullanıcı adı ve şifre boş olamaz');
      return;
    }
    setState(() { _yukleniyor = true; _hata = null; });

    final sonuc = await SessionService.instance.kullaniciAdiIleGiris(
        kullaniciAdi: ku, sifre: si);

    if (!mounted) return;
    setState(() => _yukleniyor = false);

    if (!sonuc['basarili']) {
      final hata = sonuc['hata'] as String? ?? 'Giriş başarısız';
      if (hata == 'onay_bekleniyor') { _onayBeklemeGit(); return; }
      setState(() => _hata = hata);
      return;
    }

    final rol = sonuc['rol'] as String? ?? '';
    if (rol != 'veli' && rol != 'personel' && rol != 'staff') {
      await SessionService.instance.cikisYap();
      setState(() => _hata = 'Bu giriş tipi Veli / Personel içindir');
      return;
    }
    _yonlendir();
  }

  void _yonlendir() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RolYonlendirici()),
    );
  }

  void _onayBeklemeGit() {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/onay_bekleme');
  }

  void _sifreSifirlaDialog() {
    final ctrl = TextEditingController(text: _adminEmailCtrl.text.trim());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Şifre Sıfırla'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.emailAddress,
          decoration: _inputDeko('E-posta adresiniz', Icons.email_outlined),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _navy, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await SessionService.instance.sifreSifirla(ctrl.text.trim());
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(res['basarili'] == true
                    ? 'Sıfırlama bağlantısı gönderildi'
                    : res['hata'] ?? 'Gönderilemedi'),
                backgroundColor: res['basarili'] == true ? Colors.green : Colors.red,
                behavior: SnackBarBehavior.floating,
              ));
            },
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
  }

  // ── UI ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final genis = MediaQuery.of(context).size.width > 700;
    return Scaffold(
      backgroundColor: _navy,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: genis ? 440 : double.infinity),
            child: Column(children: [
              _logo(),
              const SizedBox(height: 32),
              _kart(),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _logo() => Column(children: [
    Container(
      width: 68, height: 68,
      decoration: BoxDecoration(
          color: _turuncu, borderRadius: BorderRadius.circular(18)),
      child: const Icon(Icons.directions_bus_rounded,
          color: Colors.white, size: 38),
    ),
    const SizedBox(height: 14),
    const Text('Servisim360',
        style: TextStyle(color: Colors.white, fontSize: 24,
            fontWeight: FontWeight.bold, letterSpacing: .4)),
    const SizedBox(height: 4),
    const Text('Servis Yönetim Sistemi',
        style: TextStyle(color: Colors.white60, fontSize: 13)),
  ]);

  Widget _kart() => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 24, offset: const Offset(0, 8))],
    ),
    child: Column(children: [
      // Tab bar
      Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF5F7FA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: TabBar(
          controller: _tab,
          labelColor: _navy,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          indicatorColor: _turuncu,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Firma Admin'),
            Tab(text: 'Şoför'),
            Tab(text: 'Veli / Personel'),
          ],
        ),
      ),
      // Hata
      if (_hata != null)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(_hata!,
                style: const TextStyle(color: Colors.red, fontSize: 13))),
          ]),
        ),
      // Tab içerikleri
      SizedBox(
        height: 310,
        child: TabBarView(controller: _tab, children: [
          _adminForm(), _soforForm(), _veliPersonelForm(),
        ]),
      ),
    ]),
  );

  Widget _adminForm() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      TextField(controller: _adminEmailCtrl,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration: _inputDeko('E-posta', Icons.email_outlined)),
      const SizedBox(height: 14),
      TextField(controller: _adminSifreCtrl,
          obscureText: !_adminSifreGoster,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _adminGiris(),
          decoration: _inputDeko('Şifre', Icons.lock_outline,
              sifre: true, goster: _adminSifreGoster,
              onTap: () => setState(() => _adminSifreGoster = !_adminSifreGoster))),
      const SizedBox(height: 4),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: _sifreSifirlaDialog,
          child: const Text('Şifremi unuttum',
              style: TextStyle(fontSize: 12, color: _navy)),
        ),
      ),
      const SizedBox(height: 8),
      _girisButonu('Giriş Yap', _yukleniyor ? null : _adminGiris),
    ]),
  );

  Widget _soforForm() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      _bilgiKutusu(
        'Kullanıcı adı ve şifreniz firma yöneticiniz tarafından verilir.',
        Colors.blue,
      ),
      const SizedBox(height: 16),
      TextField(controller: _soforKullaniciCtrl,
          textInputAction: TextInputAction.next,
          decoration: _inputDeko('Kullanıcı Adı', Icons.person_outline)),
      const SizedBox(height: 14),
      TextField(controller: _soforSifreCtrl,
          obscureText: !_soforSifreGoster,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _soforGiris(),
          decoration: _inputDeko('Şifre', Icons.lock_outline,
              sifre: true, goster: _soforSifreGoster,
              onTap: () => setState(() => _soforSifreGoster = !_soforSifreGoster))),
      const SizedBox(height: 20),
      _girisButonu('Şoför Girişi', _yukleniyor ? null : _soforGiris),
    ]),
  );

  Widget _veliPersonelForm() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      _bilgiKutusu(
        'Kayıt linki veya firma yöneticinizden aldığınız bilgilerle giriş yapın.',
        Colors.green,
      ),
      const SizedBox(height: 16),
      TextField(controller: _veliKullaniciCtrl,
          textInputAction: TextInputAction.next,
          decoration: _inputDeko('Kullanıcı Adı', Icons.person_outline)),
      const SizedBox(height: 14),
      TextField(controller: _veliSifreCtrl,
          obscureText: !_veliSifreGoster,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _veliPersonelGiris(),
          decoration: _inputDeko('Şifre', Icons.lock_outline,
              sifre: true, goster: _veliSifreGoster,
              onTap: () => setState(() => _veliSifreGoster = !_veliSifreGoster))),
      const SizedBox(height: 20),
      _girisButonu('Giriş Yap', _yukleniyor ? null : _veliPersonelGiris),
    ]),
  );

  Widget _bilgiKutusu(String mesaj, MaterialColor renk) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: renk.shade50,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(children: [
      Icon(Icons.info_outline, color: renk.shade700, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(mesaj,
          style: TextStyle(fontSize: 11.5, color: renk.shade700))),
    ]),
  );

  InputDecoration _inputDeko(String hint, IconData ikon,
      {bool sifre = false, bool goster = false, VoidCallback? onTap}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
      prefixIcon: Icon(ikon, color: Colors.grey, size: 20),
      suffixIcon: sifre
          ? IconButton(
              icon: Icon(
                goster ? Icons.visibility_off_outlined
                       : Icons.visibility_outlined,
                color: Colors.grey, size: 20),
              onPressed: onTap)
          : null,
      filled: true,
      fillColor: const Color(0xFFF5F7FA),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _navy, width: 1.5)),
    );

  Widget _girisButonu(String etiket, VoidCallback? onTap) => SizedBox(
    width: double.infinity, height: 48,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: _navy, foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      onPressed: onTap,
      child: _yukleniyor && onTap == null
          ? const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Text(etiket,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
    ),
  );
}
