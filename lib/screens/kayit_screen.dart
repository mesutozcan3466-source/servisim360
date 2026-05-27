import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class KayitScreen extends StatefulWidget {
  const KayitScreen({super.key});
  @override
  State<KayitScreen> createState() => _KayitScreenState();
}

class _KayitScreenState extends State<KayitScreen> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  final _formKey        = GlobalKey<FormState>();
  final _firmaAdiCtrl   = TextEditingController();
  final _yetkiliCtrl    = TextEditingController();
  final _telefonCtrl    = TextEditingController();
  final _emailCtrl      = TextEditingController();
  final _sifreCtrl      = TextEditingController();
  final _sifre2Ctrl     = TextEditingController();
  final _sehirCtrl      = TextEditingController();
  final _aracSayisiCtrl = TextEditingController();
  final _veliSayisiCtrl = TextEditingController();
  final _notCtrl        = TextEditingController();

  String _secilenPaket  = 'Standart Paket';
  bool   _yukleniyor    = false;
  bool   _sifreGoster   = false;
  bool   _sifre2Goster  = false;

  final List<Map<String, dynamic>> _paketler = [
    {'ad': 'Mini Paket',      'ikon': Icons.directions_bus, 'renk': Colors.teal},
    {'ad': 'Standart Paket',  'ikon': Icons.business,       'renk': const Color(0xFF1a3a6b)},
    {'ad': 'Kurumsal Paket',  'ikon': Icons.apartment,      'renk': Colors.purple},
  ];

  @override
  void dispose() {
    _firmaAdiCtrl.dispose(); _yetkiliCtrl.dispose();
    _telefonCtrl.dispose();  _emailCtrl.dispose();
    _sifreCtrl.dispose();    _sifre2Ctrl.dispose();
    _sehirCtrl.dispose();    _aracSayisiCtrl.dispose();
    _veliSayisiCtrl.dispose(); _notCtrl.dispose();
    super.dispose();
  }

  Future<void> _basvuruGonder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_sifreCtrl.text != _sifre2Ctrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sifreler eslesmiyor'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _yukleniyor = true);
    try {
      // 1. Firebase Auth'da hesap olustur
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _sifreCtrl.text,
      );
      final uid = cred.user!.uid;

      // 2. Firestore'a firma kaydi ekle
      final firmaRef = await FirebaseFirestore.instance.collection('firms').add({
        'firmaAdi':    _firmaAdiCtrl.text.trim(),
        'yetkiliAd':  _yetkiliCtrl.text.trim(),
        'telefon':    _telefonCtrl.text.trim(),
        'email':      _emailCtrl.text.trim(),
        'sehir':      _sehirCtrl.text.trim(),
        'aracSayisi': int.tryParse(_aracSayisiCtrl.text.trim()) ?? 0,
        'veliSayisi': int.tryParse(_veliSayisiCtrl.text.trim()) ?? 0,
        'not':        _notCtrl.text.trim(),
        'paket':      _secilenPaket,
        'durum':      'beklemede',
        'adminUid':   uid,
        'kayitTarihi': FieldValue.serverTimestamp(),
        'basvuruTipi': 'firma',
      });

      // 3. kullanicilar koleksiyonuna ekle (durum: beklemede — giris yapamaz)
      await FirebaseFirestore.instance.collection('kullanicilar').doc(uid).set({
        'email':     _emailCtrl.text.trim(),
        'telefon':   _telefonCtrl.text.trim(),
        'rol':       'firmaAdmin',
        'durum':     'beklemede',
        'firmaId':   firmaRef.id,
        'firmaAdi':  _firmaAdiCtrl.text.trim(),
        'kayitTarihi': FieldValue.serverTimestamp(),
      });

      // 4. Hemen cikis yaptir — onay gelene kadar giris yapamaz
      await FirebaseAuth.instance.signOut();

      // 5. Süper admin'e WhatsApp bildirimi
      await _superAdminaBildir(firmaRef.id);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 60),
                ),
                const SizedBox(height: 16),
                const Text('Basvurunuz Alindi!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  'Basvurunuz inceleniyor. Onay sonrasi giris yapabilirsiniz.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFF8C00).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.lock_outline, color: Color(0xFFFF8C00), size: 16),
                        SizedBox(width: 6),
                        Text('Giris Bilgileriniz:', style: TextStyle(
                            fontSize: 12, color: Color(0xFFFF8C00), fontWeight: FontWeight.bold)),
                      ]),
                      const SizedBox(height: 6),
                      Text('📧 ${_emailCtrl.text.trim()}',
                          style: const TextStyle(fontSize: 12, color: Colors.black87)),
                      Text('🔑 ${_sifreCtrl.text}',
                          style: const TextStyle(fontSize: 12, color: Colors.black87)),
                      const SizedBox(height: 4),
                      const Text('Onay sonrasi bu bilgilerle giris yapabilirsiniz.',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1a3a6b),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                  child: const Text('Tamam', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String mesaj = 'Kayit basarisiz';
      if (e.code == 'email-already-in-use') mesaj = 'Bu e-posta zaten kayitli';
      if (e.code == 'weak-password')        mesaj = 'Sifre en az 6 karakter olmali';
      if (e.code == 'invalid-email')        mesaj = 'Gecersiz e-posta adresi';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mesaj), backgroundColor: Colors.red));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _superAdminaBildir(String firmaId) async {
    try {
      const numara = '905533498766';
      final mesaj = Uri.encodeComponent(
        '🔔 Servisim360 - Yeni Firma Basvurusu\n\n'
            '🏢 ${_firmaAdiCtrl.text.trim()}\n'
            '👤 ${_yetkiliCtrl.text.trim()}\n'
            '📞 ${_telefonCtrl.text.trim()}\n'
            '📧 ${_emailCtrl.text.trim()}\n'
            '📍 ${_sehirCtrl.text.trim()}\n'
            '🚌 ${_aracSayisiCtrl.text.trim()} arac\n'
            '👨‍👩‍👧 ${_veliSayisiCtrl.text.trim()} veli planlaniyor\n'
            '📦 Paket: $_secilenPaket\n\n'
            '✅ Super Admin panelinden onay verin.',
      );
      final url = Uri.parse('https://wa.me/$numara?text=$mesaj');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text('Firma Kayit Basvurusu',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // Paket secimi
                      const Text('Paket Secin', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 10),
                      Row(
                        children: _paketler.map((p) {
                          final secili = _secilenPaket == p['ad'];
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _secilenPaket = p['ad']),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: secili ? Colors.white : Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: secili ? (p['renk'] as Color) : Colors.white24,
                                    width: secili ? 2 : 1,
                                  ),
                                ),
                                child: Column(children: [
                                  Icon(p['ikon'] as IconData,
                                      color: secili ? (p['renk'] as Color) : Colors.white60, size: 24),
                                  const SizedBox(height: 4),
                                  Text(p['ad'] as String,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: secili ? (p['renk'] as Color) : Colors.white60)),
                                ]),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 20),

                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 20, offset: const Offset(0, 8))],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Firma Bilgileri
                              const _FormBaslik('Firma Bilgileri', Icons.business_rounded, Color(0xFF1a3a6b)),
                              const SizedBox(height: 16),

                              _inputAlan(_firmaAdiCtrl, 'Firma Adi *', Icons.business_outlined,
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Zorunlu alan' : null),
                              const SizedBox(height: 12),
                              _inputAlan(_yetkiliCtrl, 'Yetkili Ad Soyad *', Icons.person_outlined,
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Zorunlu alan' : null),
                              const SizedBox(height: 12),
                              _inputAlan(_telefonCtrl, 'Telefon *', Icons.phone_outlined,
                                  keyboardType: TextInputType.phone,
                                  validator: (v) => (v == null || v.trim().length < 10) ? 'Gecerli telefon girin' : null),
                              const SizedBox(height: 12),
                              _inputAlan(_sehirCtrl, 'Sehir', Icons.location_city_outlined),

                              const SizedBox(height: 20),

                              // Giris Bilgileri
                              const _FormBaslik('Giris Bilgileri', Icons.lock_rounded, Colors.indigo),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                    color: Colors.indigo.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.indigo.withValues(alpha: 0.2))),
                                child: const Row(children: [
                                  Icon(Icons.info_outline, color: Colors.indigo, size: 16),
                                  SizedBox(width: 8),
                                  Expanded(child: Text(
                                    'Bu bilgilerle onay sonrasi giris yapacaksiniz.',
                                    style: TextStyle(fontSize: 12, color: Colors.indigo),
                                  )),
                                ]),
                              ),
                              const SizedBox(height: 12),
                              _inputAlan(_emailCtrl, 'E-posta *', Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) => (v == null || !v.contains('@')) ? 'Gecerli e-posta girin' : null),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _sifreCtrl,
                                obscureText: !_sifreGoster,
                                decoration: _inputDecor('Sifre *', Icons.lock_outline).copyWith(
                                  suffixIcon: IconButton(
                                    icon: Icon(_sifreGoster ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                                    onPressed: () => setState(() => _sifreGoster = !_sifreGoster),
                                  ),
                                ),
                                validator: (v) => (v == null || v.length < 6) ? 'En az 6 karakter' : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _sifre2Ctrl,
                                obscureText: !_sifre2Goster,
                                decoration: _inputDecor('Sifre Tekrar *', Icons.lock_outline).copyWith(
                                  suffixIcon: IconButton(
                                    icon: Icon(_sifre2Goster ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                                    onPressed: () => setState(() => _sifre2Goster = !_sifre2Goster),
                                  ),
                                ),
                                validator: (v) => (v == null || v.length < 6) ? 'En az 6 karakter' : null,
                              ),

                              const SizedBox(height: 20),

                              // Servis Bilgileri
                              const _FormBaslik('Servis Bilgileri', Icons.directions_bus_rounded, Colors.teal),
                              const SizedBox(height: 16),

                              Row(children: [
                                Expanded(child: _inputAlan(_aracSayisiCtrl, 'Arac Sayisi',
                                    Icons.directions_bus_outlined, keyboardType: TextInputType.number)),
                                const SizedBox(width: 12),
                                Expanded(child: _inputAlan(_veliSayisiCtrl, 'Tahmini Veli',
                                    Icons.family_restroom_outlined, keyboardType: TextInputType.number)),
                              ]),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _notCtrl,
                                maxLines: 3,
                                decoration: _inputDecor('Not (istege bagli)', Icons.notes_outlined),
                              ),

                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _turuncu,
                                    padding: const EdgeInsets.symmetric(vertical: 15),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: _yukleniyor ? null : _basvuruGonder,
                                  child: _yukleniyor
                                      ? const SizedBox(height: 22, width: 22,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.send_rounded, color: Colors.white, size: 18),
                                      SizedBox(width: 8),
                                      Text('Basvuru Gonder', style: TextStyle(
                                          color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(children: [
                          Icon(Icons.info_outline, color: Colors.white60, size: 18),
                          SizedBox(width: 10),
                          Expanded(child: Text(
                            'Basvurunuz onaylandiktan sonra belirlediginiz sifre ile giris yapabilirsiniz.',
                            style: TextStyle(color: Colors.white60, fontSize: 12),
                          )),
                        ]),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputAlan(TextEditingController ctrl, String label, IconData ikon,
      {TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: _inputDecor(label, ikon),
      validator: validator,
    );
  }

  InputDecoration _inputDecor(String label, IconData ikon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(ikon, color: _navy),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _navy, width: 2)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}

class _FormBaslik extends StatelessWidget {
  final String baslik;
  final IconData ikon;
  final Color renk;
  const _FormBaslik(this.baslik, this.ikon, this.renk);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: renk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(ikon, color: renk, size: 18),
      ),
      const SizedBox(width: 8),
      Text(baslik, style: TextStyle(fontWeight: FontWeight.bold, color: renk, fontSize: 14)),
    ]);
  }
}
