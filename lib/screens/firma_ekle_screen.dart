import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class FirmaEkleScreen extends StatefulWidget {
  const FirmaEkleScreen({super.key});

  @override
  State<FirmaEkleScreen> createState() => _FirmaEkleScreenState();
}

class _FirmaEkleScreenState extends State<FirmaEkleScreen> {
  static const _navy    = Color(0xFF0d1f3c);

  final _formKey      = GlobalKey<FormState>();
  final _firmaAdiCtrl = TextEditingController();
  final _yetkiliCtrl  = TextEditingController();
  final _telefonCtrl  = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _sifreCtrl    = TextEditingController();
  final _sehirCtrl    = TextEditingController();
  final _ilceCtrl     = TextEditingController();
  final _adresCtrl    = TextEditingController();
  final _notCtrl      = TextEditingController();

  String _secilenPaket = 'Standart Paket';
  bool   _yukleniyor   = false;
  bool   _sifreGoster  = false;

  @override
  void dispose() {
    _firmaAdiCtrl.dispose(); _yetkiliCtrl.dispose();
    _telefonCtrl.dispose();  _emailCtrl.dispose();
    _sifreCtrl.dispose();    _sehirCtrl.dispose();
    _ilceCtrl.dispose();     _adresCtrl.dispose();
    _notCtrl.dispose();
    super.dispose();
  }

  Future<void> _whatsappGonder(String telefon, String mesaj) async {
    try {
      var numara = telefon.replaceAll(RegExp(r'[^0-9]'), '');
      if (numara.startsWith('0')) numara = '9$numara';
      if (!numara.startsWith('90')) numara = '90$numara';
      final url = Uri.parse('https://wa.me/$numara?text=${Uri.encodeComponent(mesaj)}');
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('WhatsApp hata: $e');
    }
  }

  // Firebase REST API ile yeni kullanici olustur — mevcut oturumu BOZMAZ
  Future<String?> _restApiIleKullaniciOlustur(String email, String sifre) async {
    // DUZELTILDI: buyuk O harfi (sifir degil)
    const apiKey = 'AIzaSyDtuxahEVj78OTSIZKaa6z8Q69CNWymO78';
    try {
      final response = await http.post(
        Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': sifre,
          'returnSecureToken': true,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data['localId'] as String?;
      } else {
        final hataKodu = data['error']?['message'] ?? 'BILINMEYEN_HATA';
        throw FirebaseAuthException(code: hataKodu.toString().toLowerCase().replaceAll('_', '-'));
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _kaydet() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _yukleniyor = true);

    try {
      // 1. REST API ile yeni kullanici olustur — mevcut oturum BOZULMAZ
      final uid = await _restApiIleKullaniciOlustur(
        _emailCtrl.text.trim(),
        _sifreCtrl.text.trim(),
      );

      if (uid == null) throw Exception('UID alinamadi');

      // 2. Firma Firestore'a ekle
      final firmaRef = await FirebaseFirestore.instance.collection('firms').add({
        'firmaAdi':    _firmaAdiCtrl.text.trim(),
        'yetkiliAd':   _yetkiliCtrl.text.trim(),
        'telefon':     _telefonCtrl.text.trim(),
        'email':       _emailCtrl.text.trim(),
        'sehir':       _sehirCtrl.text.trim(),
        'ilce':        _ilceCtrl.text.trim(),
        'adres':       _adresCtrl.text.trim(),
        'not':         _notCtrl.text.trim(),
        'paket':       _secilenPaket,
        'durum':       'aktif',
        'adminUid':    uid,
        'kayitTarihi': FieldValue.serverTimestamp(),
        'basvuruTipi': 'superAdmin',
      });

      // 3. kullanicilar kaydini olustur — UID ile
      await FirebaseFirestore.instance.collection('kullanicilar').doc(uid).set({
        'email':       _emailCtrl.text.trim(),
        'telefon':     _telefonCtrl.text.trim(),
        'rol':         'firmaAdmin',
        'durum':       'onayli',
        'firmaId':     firmaRef.id,
        'firmaAdi':    _firmaAdiCtrl.text.trim(),
        'kayitTarihi': FieldValue.serverTimestamp(),
      });

      // 4. firms dokumanina firmaId'yi guncelle
      await FirebaseFirestore.instance.collection('firms').doc(firmaRef.id).update({
        'firmaId': firmaRef.id,
      });

      // 5. WhatsApp mesaji
      final wpMesaj =
          'Merhaba ${_yetkiliCtrl.text.trim()}!\n\n'
          'Servisim360 - ${_firmaAdiCtrl.text.trim()} hesabiniz olusturuldu.\n\n'
          'E-posta: ${_emailCtrl.text.trim()}\n'
          'Sifre: ${_sifreCtrl.text.trim()}\n\n'
          'Hesabiniz aktif. Uygulamayi indirip giris yapabilirsiniz.\n\n'
          'Servisim360 - Akilli Servis Yonetim Sistemi';

      final telefon = _telefonCtrl.text.trim();

      if (mounted) {
        Navigator.pop(context, true);
        await _whatsappGonder(telefon, wpMesaj);
      }

    } on FirebaseAuthException catch (e) {
      setState(() => _yukleniyor = false);
      String mesaj = 'Kayit hatasi';
      if (e.code.contains('email-already-in-use') || e.code.contains('email_exists'))
        mesaj = 'Bu e-posta zaten kayitli!';
      else if (e.code.contains('weak-password') || e.code.contains('weak_password'))
        mesaj = 'Sifre en az 6 karakter olmali';
      else if (e.code.contains('invalid-email') || e.code.contains('invalid_email'))
        mesaj = 'Gecersiz e-posta adresi';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mesaj), backgroundColor: Colors.red));
    } catch (e) {
      setState(() => _yukleniyor = false);
      String mesaj = 'Hata: $e';
      if (e.toString().contains('EMAIL_EXISTS') || e.toString().contains('email-already-in-use'))
        mesaj = 'Bu e-posta zaten kayitli!';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mesaj), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: const Text('Yeni Firma Ekle',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        actions: [
          if (_yukleniyor)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Paket secimi
            const Text('Paket Secin',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            Row(children: ['Mini Paket', 'Standart Paket', 'Kurumsal Paket'].map((p) {
              final secili = _secilenPaket == p;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _secilenPaket = p),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: secili ? _navy : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: secili ? _navy : Colors.grey.shade300),
                    ),
                    child: Text(p.replaceAll(' Paket', ''),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                            color: secili ? Colors.white : Colors.grey.shade600)),
                  ),
                ),
              );
            }).toList()),

            const SizedBox(height: 20),
            _bolumBaslik('Firma Bilgileri', Icons.business_rounded, const Color(0xFF1a3a6b)),
            const SizedBox(height: 12),

            _inputAlan(_firmaAdiCtrl, 'Firma Adi *', Icons.business_outlined,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Zorunlu alan' : null),
            const SizedBox(height: 10),
            _inputAlan(_yetkiliCtrl, 'Yetkili Ad Soyad *', Icons.person_outlined,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Zorunlu alan' : null),
            const SizedBox(height: 10),
            _inputAlan(_telefonCtrl, 'Telefon * (WhatsApp)', Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || v.trim().length < 10) ? 'Gecerli telefon girin' : null),
            const SizedBox(height: 10),

            Row(children: [
              Expanded(child: _inputAlan(_sehirCtrl, 'Sehir *', Icons.location_city_outlined,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Zorunlu' : null)),
              const SizedBox(width: 10),
              Expanded(child: _inputAlan(_ilceCtrl, 'Ilce', Icons.map_outlined)),
            ]),
            const SizedBox(height: 10),

            TextFormField(
              controller: _adresCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Acik Adres',
                alignLabelWithHint: true,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: Icon(Icons.home_outlined, color: Color(0xFF1a3a6b)),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),
            const SizedBox(height: 10),

            TextFormField(
              controller: _notCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Not (istege bagli)',
                alignLabelWithHint: true,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: Icon(Icons.notes_outlined, color: Color(0xFF1a3a6b)),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
            ),

            const SizedBox(height: 20),
            _bolumBaslik('Giris Bilgileri', Icons.lock_rounded, Colors.indigo),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.indigo.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.indigo.withValues(alpha: 0.2)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, color: Colors.indigo, size: 15),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'Email ve sifre firma adminine WhatsApp ile gonderilecek.',
                  style: TextStyle(fontSize: 12, color: Colors.indigo),
                )),
              ]),
            ),
            const SizedBox(height: 10),

            _inputAlan(_emailCtrl, 'E-posta *', Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || !v.contains('@')) ? 'Gecerli e-posta girin' : null),
            const SizedBox(height: 10),

            TextFormField(
              controller: _sifreCtrl,
              obscureText: !_sifreGoster,
              decoration: InputDecoration(
                labelText: 'Sifre *',
                prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF1a3a6b)),
                suffixIcon: IconButton(
                  icon: Icon(_sifreGoster ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                  onPressed: () => setState(() => _sifreGoster = !_sifreGoster),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              validator: (v) => (v == null || v.trim().length < 6) ? 'En az 6 karakter' : null,
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _yukleniyor ? null : _kaydet,
                icon: _yukleniyor
                    ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded, color: Colors.white),
                label: Text(
                  _yukleniyor ? 'Kaydediliyor...' : 'Firma Ekle ve WhatsApp Gonder',
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _bolumBaslik(String baslik, IconData ikon, Color renk) {
    return Row(children: [
      Container(padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: renk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(ikon, color: renk, size: 16)),
      const SizedBox(width: 8),
      Text(baslik, style: TextStyle(fontWeight: FontWeight.bold, color: renk, fontSize: 13)),
    ]);
  }

  Widget _inputAlan(TextEditingController ctrl, String label, IconData ikon,
      {TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(ikon, color: const Color(0xFF1a3a6b)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }
}
