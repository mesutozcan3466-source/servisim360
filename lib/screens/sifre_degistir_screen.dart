import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SifreDegistirScreen extends StatefulWidget {
  final String rol; // 'sofor', 'veli', 'admin' vb.

  const SifreDegistirScreen({super.key, this.rol = 'kullanici'});

  @override
  State<SifreDegistirScreen> createState() => _SifreDegistirScreenState();
}

class _SifreDegistirScreenState extends State<SifreDegistirScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _mevcutCtrl = TextEditingController();
  final _yeniCtrl   = TextEditingController();
  final _tekrarCtrl = TextEditingController();
  bool _yukleniyor  = false;
  bool _mevcutGizli = true;
  bool _yeniGizli   = true;
  bool _tekrarGizli = true;

  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  @override
  void dispose() {
    _mevcutCtrl.dispose();
    _yeniCtrl.dispose();
    _tekrarCtrl.dispose();
    super.dispose();
  }

  Future<void> _sifreDegistir() async {
    if (!_formKey.currentState!.validate()) return;
    if (_yeniCtrl.text != _tekrarCtrl.text) {
      _snack('Yeni sifreler eslesmiyor', Colors.red);
      return;
    }
    setState(() => _yukleniyor = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final cred = EmailAuthProvider.credential(
        email:    user.email!,
        password: _mevcutCtrl.text.trim(),
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(_yeniCtrl.text.trim());
      if (mounted) {
        _snack('Sifre basariyla guncellendi', Colors.green);
        // ilkGiris flag'ini temizle
        try {
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid != null) {
            await FirebaseFirestore.instance
                .collection('kullanicilar').doc(uid)
                .update({'ilkGiris': false});
          }
        } catch (_) {}
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Bir hata olustu';
      if (e.code == 'wrong-password')  msg = 'Mevcut sifre yanlis';
      if (e.code == 'weak-password')   msg = 'Yeni sifre en az 6 karakter olmali';
      if (e.code == 'too-many-requests') msg = 'Cok fazla deneme, lutfen bekleyin';
      _snack(msg, Colors.red);
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  void _snack(String msg, Color renk) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: renk),
    );
  }

  String get _baslik {
    switch (widget.rol) {
      case 'sofor': return 'Sofor Sifre Degistir';
      case 'veli':  return 'Veli Sifre Degistir';
      case 'admin': return 'Admin Sifre Degistir';
      default:      return 'Sifre Degistir';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_baslik),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Bilgi kutusu
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _navy.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _navy.withValues(alpha: 0.15)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline, color: _navy, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Yeni sifreniz en az 6 karakter olmali.',
                      style: TextStyle(color: _navy.withValues(alpha: 0.8), fontSize: 13),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 24),
              _sifreAlani(
                controller: _mevcutCtrl,
                label:     'Mevcut Sifre',
                gizli:     _mevcutGizli,
                onToggle:  () => setState(() => _mevcutGizli = !_mevcutGizli),
              ),
              const SizedBox(height: 16),
              _sifreAlani(
                controller: _yeniCtrl,
                label:     'Yeni Sifre',
                gizli:     _yeniGizli,
                onToggle:  () => setState(() => _yeniGizli = !_yeniGizli),
                minLength: 6,
              ),
              const SizedBox(height: 16),
              _sifreAlani(
                controller: _tekrarCtrl,
                label:     'Yeni Sifre (Tekrar)',
                gizli:     _tekrarGizli,
                onToggle:  () => setState(() => _tekrarGizli = !_tekrarGizli),
                minLength: 6,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _yukleniyor ? null : _sifreDegistir,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _turuncu,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _yukleniyor
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    'Sifre Degistir',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sifreAlani({
    required TextEditingController controller,
    required String label,
    required bool gizli,
    required VoidCallback onToggle,
    int minLength = 1,
  }) {
    return TextFormField(
      controller:   controller,
      obscureText:  gizli,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(
            gizli ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey,
          ),
          onPressed: onToggle,
        ),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return '$label bos birakilamaz';
        if (v.length < minLength)   return 'En az $minLength karakter giriniz';
        return null;
      },
    );
  }
}
