import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl      = TextEditingController();
  final _sifreCtrl      = TextEditingController();
  final _projeKoduCtrl  = TextEditingController();
  final _kullaniciCtrl  = TextEditingController();
  final _projeSifreCtrl = TextEditingController();
  String _secilenRol    = 'sofor';

  bool _sifreGoster      = false;
  bool _projeSifreGoster = false;
  bool _yukleniyor       = false;
  bool _beniHatirla      = false;

  late TabController _tabController;

  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _kayitliGirisiYukle();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _sifreCtrl.dispose();
    _projeKoduCtrl.dispose();
    _kullaniciCtrl.dispose();
    _projeSifreCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _kayitliGirisiYukle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hatirla = prefs.getBool('beni_hatirla') ?? false;
      if (hatirla) {
        final email = prefs.getString('kayitli_email') ?? '';
        final sifre = prefs.getString('kayitli_sifre') ?? '';
        if (email.isNotEmpty) {
          setState(() {
            _emailCtrl.text = email;
            _sifreCtrl.text = sifre;
            _beniHatirla    = true;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _girisiKaydet(String email, String sifre) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_beniHatirla) {
        await prefs.setString('kayitli_email', email);
        await prefs.setString('kayitli_sifre', sifre);
        await prefs.setBool('beni_hatirla', true);
      } else {
        await prefs.remove('kayitli_email');
        await prefs.remove('kayitli_sifre');
        await prefs.setBool('beni_hatirla', false);
      }
    } catch (_) {}
  }

  String _rotaAl(String rol) {
    switch (rol) {
      case 'superAdmin':
      case 'super_admin':
      case 'superadmin':
      case 'süper yönetici':
        return kIsWeb ? '/web_panel' : '/super_admin';
      case 'firmaAdmin':
      case 'firma_admin':
      case 'firmaadmin':
      case 'firma yöneticisi':
        return kIsWeb ? '/web_panel' : '/firma_admin';
      case 'sofor':
        return '/sofor_panel';
      case 'veli':
        return kIsWeb ? '/web_veli' : '/veli_panel';
      default:
        return kIsWeb ? '/web_veli' : '/veli_panel';
    }
  }

  Future<void> _emailIleGiris() async {
    final email = _emailCtrl.text.trim();
    final sifre = _sifreCtrl.text;
    if (email.isEmpty || sifre.isEmpty) {
      _snack('E-posta ve sifre giriniz', Colors.red); return;
    }
    setState(() => _yukleniyor = true);
    try {
      final cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: sifre);
      final uid = cred.user?.uid;
      if (uid == null) { _snack('Giris basarisiz', Colors.red); return; }
      final doc = await FirebaseFirestore.instance
          .collection('kullanicilar').doc(uid).get();
      final durum = doc.data()?['durum'] as String? ?? 'aktif';
      if (durum == 'beklemede') {
        if (mounted) Navigator.pushReplacementNamed(context, '/onay_bekleme'); return;
      }
      if (durum == 'askida') { _snack('Hesabiniz askiya alindi', Colors.orange); return; }
      final rol = doc.data()?['rol'] as String? ?? 'veli';
      await _girisiKaydet(email, sifre);
      _cihazBilgisiGuncelle();
      if (mounted) Navigator.pushReplacementNamed(context, _rotaAl(rol));
    } on FirebaseAuthException catch (e) {
      _snack(e.code == 'wrong-password' || e.code == 'user-not-found'
          ? 'E-posta veya sifre yanlis' : 'Hata: ${e.message}', Colors.red);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('wrong-password') || msg.contains('invalid-credential') ||
          msg.contains('INVALID_LOGIN_CREDENTIALS') || msg.contains('user-not-found')) {
        _snack('E-posta veya sifre yanlis', Colors.red);
      } else if (msg.contains('network')) {
        _snack('Internet baglantisi yok', Colors.red);
      } else {
        _snack(msg.replaceAll('Exception: ', '').replaceAll('[firebase_auth/','').replaceAll(']',''), Colors.red);
      }
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _projeKoduIleGiris() async {
    final projeKodu    = _projeKoduCtrl.text.trim();
    final kullaniciAdi = _kullaniciCtrl.text.trim();
    final sifre        = _projeSifreCtrl.text;
    if (projeKodu.isEmpty || kullaniciAdi.isEmpty || sifre.isEmpty) {
      _snack('Tum alanlari doldurunuz', Colors.red); return;
    }
    setState(() => _yukleniyor = true);
    try {
      // Proje kodu ile kullanıcı ara
      final projSnap = await FirebaseFirestore.instance
          .collection('projects').where('projeKodu', isEqualTo: projeKodu).limit(1).get();
      if (projSnap.docs.isEmpty) {
        _snack('Proje kodu bulunamadi', Colors.red); return;
      }
      final firmaId  = projSnap.docs.first.data()['firmaId'] as String? ?? '';
      // Kullanıcıyı bul (telefon veya ad + firma)
      var q = FirebaseFirestore.instance.collection(_secilenRol == 'sofor' ? 'drivers' : 'parents')
          .where('firmaId', isEqualTo: firmaId);
      final snap1 = await q.where('telefon', isEqualTo: kullaniciAdi).limit(1).get();
      final snap2 = snap1.docs.isEmpty
          ? await q.where('ad', isEqualTo: kullaniciAdi).limit(1).get()
          : snap1;
      if (snap2.docs.isEmpty) {
        _snack('Kullanici bulunamadi', Colors.red); return;
      }
      final data  = snap2.docs.first.data();
      final email = data['email'] as String? ?? '';
      if (email.isEmpty) { _snack('Giris bilgisi eksik — admin ile iletisime gecin', Colors.orange); return; }
      final cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: sifre);
      if (cred.user != null && mounted) {
        Navigator.pushReplacementNamed(context, _rotaAl(_secilenRol));
      }
    } on FirebaseAuthException catch (e) {
      _snack(e.code == 'invalid-credential'
          ? 'Kullanici adi veya sifre yanlis'
          : 'Giris hatasi: \${e.code}', Colors.red);
    } catch (e) {
      _snack('Hata: \${e.toString().replaceAll("Exception: ", "")}', Colors.red);
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }



  Future<void> _sifreSifirla() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _snack('Once e-posta adresinizi girin', Colors.orange);
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _snack('Sifre sifirlama e-postasi gonderildi', Colors.green);
    } catch (e) {
      _snack('Gonderilemedi: $e', Colors.red);
    }
  }

  void _cihazBilgisiGuncelle() {}

  void _snack(String mesaj, Color renk) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mesaj), backgroundColor: renk));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1a3a6b), Color(0xFF2a5298)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(children: [
              const SizedBox(height: 52),

              // Logo
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset('assets/logo_app.png', fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                        child: Text('S', style: TextStyle(color: _turuncu, fontSize: 52, fontWeight: FontWeight.bold))),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Servisim360', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const Text('Akilli Servis Yonetim Sistemi', style: TextStyle(color: Colors.white60, fontSize: 13)),
              const SizedBox(height: 36),

              // Tab
              Container(
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14)),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(color: _turuncu, borderRadius: BorderRadius.circular(12)),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [
                    Tab(text: 'Admin Girisi'),
                    Tab(text: 'Sofor / Veli'),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Form karti
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: SizedBox(
                  height: 360,
                  child: TabBarView(
                    controller: _tabController,
                    children: [_adminForm(), _projeKoduForm()],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Kayit ol butonu
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KayitOlScreen())),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3))),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.business_outlined, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text('Firmanizi Kayit Edin',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 14),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              const Text('Ucretsiz basvurun, onaylandiktan sonra kullanin',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _adminForm() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Yonetici Girisi', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _navy)),
      const SizedBox(height: 6),
      const Text('Super Admin veya Firma Admin', style: TextStyle(fontSize: 12, color: Colors.grey)),
      const SizedBox(height: 16),
      TextField(
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        decoration: _inputDecor('E-posta', Icons.email_outlined),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _sifreCtrl,
        obscureText: !_sifreGoster,
        decoration: _inputDecor('Sifre', Icons.lock_outline,
          suffix: IconButton(
            icon: Icon(_sifreGoster ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
            onPressed: () => setState(() => _sifreGoster = !_sifreGoster),
          ),
        ),
      ),
      Row(children: [
        GestureDetector(
          onTap: () => setState(() => _beniHatirla = !_beniHatirla),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 24, height: 24,
              child: Checkbox(
                value: _beniHatirla, activeColor: _navy,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (v) => setState(() => _beniHatirla = v ?? false),
              ),
            ),
            const SizedBox(width: 6),
            const Text('Beni Hatirla', style: TextStyle(fontSize: 12, color: _navy)),
          ]),
        ),
        const Spacer(),
        TextButton(
          onPressed: _sifreSifirla,
          style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          child: const Text('Sifremi Unuttum', style: TextStyle(color: _navy, fontSize: 12)),
        ),
      ]),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _turuncu,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _yukleniyor ? null : _emailIleGiris,
          child: _yukleniyor
              ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Giris Yap', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    ]);
  }

  Widget _projeKoduForm() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Sofor / Veli Girisi', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _navy)),
      const SizedBox(height: 6),
      Row(children: [
        _rolChip('sofor', 'Sofor'),
        const SizedBox(width: 8),
        _rolChip('veli',  '👨‍👦  Veli'),
      ]),
      const SizedBox(height: 12),
      TextField(
        controller: _projeKoduCtrl,
        textCapitalization: TextCapitalization.characters,
        decoration: _inputDecor('Proje Kodu', Icons.qr_code_outlined),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _kullaniciCtrl,
        decoration: _inputDecor('Kullanici Adi / Telefon', Icons.person_outline),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _projeSifreCtrl,
        obscureText: !_projeSifreGoster,
        decoration: _inputDecor('Sifre', Icons.lock_outline,
          suffix: IconButton(
            icon: Icon(_projeSifreGoster ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
            onPressed: () => setState(() => _projeSifreGoster = !_projeSifreGoster),
          ),
        ),
      ),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _turuncu,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _yukleniyor ? null : _projeKoduIleGiris,
          child: _yukleniyor
              ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Giris Yap', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    ]);
  }

  Widget _rolChip(String rol, String etiket) {
    final secili = _secilenRol == rol;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _secilenRol = rol),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
            color: secili ? _navy : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: secili ? _navy : Colors.grey.shade300)),
        child: Text(etiket, textAlign: TextAlign.center,
            style: TextStyle(color: secili ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    ));
  }

  InputDecoration _inputDecor(String label, IconData ikon, {Widget? suffix}) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(ikon, color: _navy),
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _navy, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );
}

// ════════════════════════════════════════════════════════════════
//  KAYIT OL EKRANI
// ════════════════════════════════════════════════════════════════
class KayitOlScreen extends StatefulWidget {
  const KayitOlScreen({super.key});
  @override
  State<KayitOlScreen> createState() => _KayitOlScreenState();
}

class _KayitOlScreenState extends State<KayitOlScreen> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  static const _apiKey  = 'AIzaSyDtuxahEVj78OTSIZKaa6z8Q69CNWymO78';

  final _firmaAdiCtrl = TextEditingController();
  final _yetkiliCtrl  = TextEditingController();
  final _telefonCtrl  = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _sifreCtrl    = TextEditingController();
  final _sehirCtrl    = TextEditingController();

  bool   _sifreGoster    = false;
  bool   _yukleniyor     = false;
  String _secilenPaket   = 'Standart';

  @override
  void dispose() {
    _firmaAdiCtrl.dispose(); _yetkiliCtrl.dispose();
    _telefonCtrl.dispose();  _emailCtrl.dispose();
    _sifreCtrl.dispose();    _sehirCtrl.dispose();
    super.dispose();
  }

  Future<String?> _authKayit(String email, String sifre) async {
    try {
      final resp = await http.post(
        Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': sifre, 'returnSecureToken': true}),
      );
      final data = jsonDecode(resp.body);
      if (resp.statusCode == 200) return data['localId'] as String?;
      final kod = data['error']?['message'] ?? '';
      if (kod.toString().contains('EMAIL_EXISTS')) throw Exception('Bu e-posta zaten kayitli!');
      throw Exception(kod);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _basvur() async {
    if (_firmaAdiCtrl.text.trim().isEmpty) {
      _snack('Firma adi zorunlu!', Colors.red); return;
    }
    if (!_emailCtrl.text.contains('@')) {
      _snack('Gecerli e-posta girin!', Colors.red); return;
    }
    if (_sifreCtrl.text.trim().length < 6) {
      _snack('Sifre en az 6 karakter olmali!', Colors.red); return;
    }

    setState(() => _yukleniyor = true);
    try {
      final uid = await _authKayit(_emailCtrl.text.trim(), _sifreCtrl.text.trim());

      final firmaRef = await FirebaseFirestore.instance.collection('firms').add({
        'firmaAdi':    _firmaAdiCtrl.text.trim(),
        'yetkiliAd':   _yetkiliCtrl.text.trim(),
        'telefon':     _telefonCtrl.text.trim(),
        'email':       _emailCtrl.text.trim(),
        'sehir':       _sehirCtrl.text.trim(),
        'paket':       _secilenPaket,
        'durum':       'beklemede',
        'adminUid':    uid ?? '',
        'kayitTarihi': FieldValue.serverTimestamp(),
        'basvuruTipi': 'kendikayit',
      });

      if (uid != null && uid.isNotEmpty) {
        await FirebaseFirestore.instance.collection('kullanicilar').doc(uid).set({
          'email':       _emailCtrl.text.trim(),
          'telefon':     _telefonCtrl.text.trim(),
          'rol':         'firmaAdmin',
          'durum':       'beklemede',
          'firmaId':     firmaRef.id,
          'firmaAdi':    _firmaAdiCtrl.text.trim(),
          'kayitTarihi': FieldValue.serverTimestamp(),
        });

        await FirebaseFirestore.instance.collection('firms').doc(firmaRef.id).update({
          'firmaId': firmaRef.id,
        });
      }

      if (mounted) _basariDialog();
    } catch (e) {
      _snack('Hata: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  void _basariDialog() {
    showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: const Icon(Icons.hourglass_empty_rounded, color: _turuncu, size: 38),
        ),
        const SizedBox(height: 16),
        const Text('Basvurunuz Alindi!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _navy)),
        const SizedBox(height: 10),
        Text(
            '${_firmaAdiCtrl.text.trim()} firmanizin basvurusu incelenmek uzere alindi.\n\nYonetici onayladiginda giris yapabilirsiniz.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () {
            Navigator.pop(context);
            Navigator.pop(context);
          },
          child: const Text('Tamam', style: TextStyle(fontWeight: FontWeight.bold)),
        )),
      ]),
    ));
  }

  void _snack(String mesaj, Color renk) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mesaj), backgroundColor: renk));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white,
        title: const Text('Firma Kayit', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Bilgi karti
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2))),
            child: const Row(children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 18),
              SizedBox(width: 10),
              Expanded(child: Text(
                  'Kaydiniz yonetici onayladiginda aktif olur ve giris yapabilirsiniz.',
                  style: TextStyle(color: Colors.blue, fontSize: 12))),
            ]),
          ),
          const SizedBox(height: 20),

          // Paket secimi
          const Text('Paket Secin', style: TextStyle(fontWeight: FontWeight.bold, color: _navy, fontSize: 13)),
          const SizedBox(height: 8),
          Row(children: ['Mini', 'Standart', 'Kurumsal'].map((p) {
            final sec = _secilenPaket == p;
            return Expanded(child: GestureDetector(
              onTap: () => setState(() => _secilenPaket = p),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                    color: sec ? _navy : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: sec ? _navy : Colors.grey.shade300)),
                child: Text(p, textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                        color: sec ? Colors.white : Colors.grey.shade600)),
              ),
            ));
          }).toList()),
          const SizedBox(height: 20),

          // Firma bilgileri
          _baslik('Firma Bilgileri', Icons.business_outlined),
          const SizedBox(height: 12),
          _inp(_firmaAdiCtrl, 'Firma Adi *',       Icons.business_outlined),
          const SizedBox(height: 10),
          _inp(_yetkiliCtrl,  'Yetkili Ad Soyad',  Icons.person_outlined),
          const SizedBox(height: 10),
          _inp(_telefonCtrl,  'Telefon',            Icons.phone_outlined, tipi: TextInputType.phone),
          const SizedBox(height: 10),
          _inp(_sehirCtrl,    'Sehir',              Icons.location_city_outlined),
          const SizedBox(height: 20),

          // Giris bilgileri
          _baslik('Giris Bilgileri', Icons.lock_outlined),
          const SizedBox(height: 12),
          _inp(_emailCtrl, 'E-posta *', Icons.email_outlined, tipi: TextInputType.emailAddress),
          const SizedBox(height: 10),
          TextField(
            controller: _sifreCtrl,
            obscureText: !_sifreGoster,
            decoration: InputDecoration(
              labelText: 'Sifre * (en az 6 karakter)',
              prefixIcon: const Icon(Icons.lock_outline, color: _navy),
              suffixIcon: IconButton(
                icon: Icon(_sifreGoster ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                onPressed: () => setState(() => _sifreGoster = !_sifreGoster),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _turuncu, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _yukleniyor ? null : _basvur,
              icon: _yukleniyor
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded),
              label: Text(_yukleniyor ? 'Gonderiliyor...' : 'Basvuru Gonder',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _baslik(String t, IconData ikon) => Row(children: [
    Icon(ikon, color: _navy, size: 18),
    const SizedBox(width: 8),
    Text(t, style: const TextStyle(fontWeight: FontWeight.bold, color: _navy, fontSize: 14)),
  ]);

  Widget _inp(TextEditingController c, String label, IconData ikon,
      {TextInputType tipi = TextInputType.text}) =>
      TextField(
        controller: c, keyboardType: tipi,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(ikon, color: _navy, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      );
}
