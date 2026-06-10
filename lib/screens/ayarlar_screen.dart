// lib/screens/ayarlar_screen.dart — Servisim360 Mobil Ayarlar v2
import 'package:flutter/material.dart';
import 'yardim_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/session_service.dart';

class AyarlarScreen extends StatefulWidget {
  const AyarlarScreen({super.key});
  @override
  State<AyarlarScreen> createState() => _AyarlarScreenState();
}

class _AyarlarScreenState extends State<AyarlarScreen>
    with SingleTickerProviderStateMixin {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  late TabController _tab;
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _firmaData;
  bool _yukleniyor = true;

  // Bildirim ayarları
  bool _bildirimAktif   = true;
  bool _sesAktif        = true;
  bool _gelmeyecekHatir = true;
  bool _servisBasladi   = true;
  bool _yaklasiyor      = true;
  bool _aracGeldi       = true;

  // Firma bilgileri
  final _firmaAdiCtrl = TextEditingController();
  final _yetkiliCtrl  = TextEditingController();
  final _telCtrl      = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _adresCtrl    = TextEditingController();

  // Şifre
  final _eskiSifreCtrl = TextEditingController();
  final _yeniSifreCtrl = TextEditingController();
  final _yeniSifreTekrarCtrl = TextEditingController();
  bool _sifreGizle1 = true, _sifreGizle2 = true, _sifreGizle3 = true;

  String _firmaId = '';
  String _rol     = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
    _yukle();
  }

  @override
  void dispose() {
    _tab.dispose();
    _firmaAdiCtrl.dispose(); _yetkiliCtrl.dispose();
    _telCtrl.dispose(); _emailCtrl.dispose(); _adresCtrl.dispose();
    _eskiSifreCtrl.dispose(); _yeniSifreCtrl.dispose(); _yeniSifreTekrarCtrl.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('kullanicilar').doc(uid).get();
      _userData = doc.data();
      _rol      = _userData?['rol'] ?? '';
      _firmaId  = await SessionService.instance.firmaIdAl() ?? '';

      if (_firmaId.isNotEmpty) {
        final fDoc = await FirebaseFirestore.instance
            .collection('firms').doc(_firmaId).get();
        _firmaData = fDoc.data();
        _firmaAdiCtrl.text = _firmaData?['firmaAdi'] ?? _firmaData?['ad'] ?? '';
        _yetkiliCtrl.text  = _firmaData?['yetkiliAd'] ?? '';
        _telCtrl.text      = _firmaData?['telefon'] ?? '';
        _emailCtrl.text    = _firmaData?['email'] ?? '';
        _adresCtrl.text    = _firmaData?['adres'] ?? '';
      }

      // Bildirim tercihleri
      final bildirimDoc = await FirebaseFirestore.instance
          .collection('kullanicilar').doc(uid)
          .collection('tercihler').doc('bildirimler').get();
      if (bildirimDoc.exists) {
        final d = bildirimDoc.data()!;
        _bildirimAktif   = d['bildirimAktif']   ?? true;
        _sesAktif        = d['sesAktif']         ?? true;
        _gelmeyecekHatir = d['gelmeyecekHatir']  ?? true;
        _servisBasladi   = d['servisBasladi']     ?? true;
        _yaklasiyor      = d['yaklasiyor']        ?? true;
        _aracGeldi       = d['aracGeldi']         ?? true;
      }
    } catch (_) {}
    if (mounted) setState(() => _yukleniyor = false);
  }

  Future<void> _firmaKaydet() async {
    if (_firmaId.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('firms').doc(_firmaId).update({
        'firmaAdi':   _firmaAdiCtrl.text.trim(),
        'yetkiliAd':  _yetkiliCtrl.text.trim(),
        'telefon':    _telCtrl.text.trim(),
        'email':      _emailCtrl.text.trim(),
        'adres':      _adresCtrl.text.trim(),
        'updatedAt':  FieldValue.serverTimestamp(),
      });
      _snack('Firma bilgileri kaydedildi', Colors.green);
    } catch (e) {
      _snack('Hata: $e', Colors.red);
    }
  }

  Future<void> _bildirimKaydet() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('kullanicilar').doc(uid)
          .collection('tercihler').doc('bildirimler').set({
        'bildirimAktif':   _bildirimAktif,
        'sesAktif':        _sesAktif,
        'gelmeyecekHatir': _gelmeyecekHatir,
        'servisBasladi':   _servisBasladi,
        'yaklasiyor':      _yaklasiyor,
        'aracGeldi':       _aracGeldi,
        'updatedAt':       FieldValue.serverTimestamp(),
      });
      _snack('Bildirim tercihleri kaydedildi', Colors.green);
    } catch (e) {
      _snack('Hata: $e', Colors.red);
    }
  }

  Future<void> _sifreDegistir() async {
    if (_yeniSifreCtrl.text != _yeniSifreTekrarCtrl.text) {
      _snack('Yeni şifreler eşleşmiyor', Colors.red); return;
    }
    if (_yeniSifreCtrl.text.length < 6) {
      _snack('Şifre en az 6 karakter olmalı', Colors.red); return;
    }
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final cred = EmailAuthProvider.credential(
          email: user.email!, password: _eskiSifreCtrl.text);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(_yeniSifreCtrl.text);
      _eskiSifreCtrl.clear(); _yeniSifreCtrl.clear(); _yeniSifreTekrarCtrl.clear();
      _snack('Şifre başarıyla güncellendi', Colors.green);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        _snack('Mevcut şifre yanlış', Colors.red);
      } else {
        _snack('Hata: ${e.message}', Colors.red);
      }
    }
  }

  Future<void> _cikisYap() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Çıkış Yap'),
        content: const Text('Oturumu kapatmak istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_, false), child: const Text('Vazgeç')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(_, true),
              child: const Text('Çıkış Yap')),
        ],
      ),
    );
    if (onay == true) {
      await SessionService.instance.cikisYap();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _snack(String msg, Color renk) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg), backgroundColor: renk,
        behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) return const Scaffold(
        backgroundColor: Color(0xFFF5F7FA),
        body: Center(child: CircularProgressIndicator(color: _navy)));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white,
        title: const Text('Ayarlar', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [YardimButonu(ekranAdi: 'Ayarlar')],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          indicatorColor: _turuncu,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.business_outlined, size: 16), text: 'Firma'),
            Tab(icon: Icon(Icons.notifications_outlined, size: 16), text: 'Bildirimler'),
            Tab(icon: Icon(Icons.person_outlined, size: 16), text: 'Hesap'),
            Tab(icon: Icon(Icons.lock_outlined, size: 16), text: 'Şifre'),
            Tab(icon: Icon(Icons.settings_outlined, size: 16), text: 'Uygulama'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _firmaSekme(),
          _bildirimSekme(),
          _hesapSekme(),
          _sifreSekme(),
          _uygulamaSekme(),
        ],
      ),
    );
  }

  // ── SEKME 1: FİRMA BİLGİLERİ ─────────────────────────────────
  Widget _firmaSekme() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      _bolumBaslik('Firma Bilgileri', Icons.business_outlined),
      _karti(Column(children: [
        _tf(_firmaAdiCtrl, 'Firma Adı *', Icons.business_outlined),
        const SizedBox(height: 10),
        _tf(_yetkiliCtrl,  'Yetkili Adı Soyadı', Icons.person_outlined),
        const SizedBox(height: 10),
        _tf(_telCtrl,      'Telefon', Icons.phone_outlined, type: TextInputType.phone),
        const SizedBox(height: 10),
        _tf(_emailCtrl,    'E-posta', Icons.email_outlined, type: TextInputType.emailAddress),
        const SizedBox(height: 10),
        _tf(_adresCtrl,    'Adres', Icons.location_on_outlined, maxLines: 2),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: _turuncu, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: _rol == 'firmaAdmin' || _rol == 'firma_admin' ? _firmaKaydet : null,
          icon: const Icon(Icons.save_outlined, size: 18),
          label: const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.bold)),
        )),
        if (_rol != 'firmaAdmin' && _rol != 'firma_admin')
          const Padding(padding: EdgeInsets.only(top: 8),
              child: Text('Firma bilgilerini sadece firma admini düzenleyebilir.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center)),
      ])),
    ]),
  );

  // ── SEKME 2: BİLDİRİM AYARLARI ───────────────────────────────
  Widget _bildirimSekme() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      _bolumBaslik('Genel Bildirimler', Icons.notifications_outlined),
      _karti(Column(children: [
        _switch('Tüm Bildirimler', 'Bildirimler açık/kapalı', _bildirimAktif,
                (v) => setState(() => _bildirimAktif = v), Icons.notifications_outlined),
        const Divider(height: 1),
        _switch('Sesli Bildirim', 'Bildirim sesi', _sesAktif,
                (v) => setState(() => _sesAktif = v), Icons.volume_up_outlined),
        const Divider(height: 1),
        _switch('Gelmeyecek Hatırlatıcı', 'Servis öncesi hatırlatma', _gelmeyecekHatir,
                (v) => setState(() => _gelmeyecekHatir = v), Icons.alarm_outlined),
      ])),
      const SizedBox(height: 8),
      _bolumBaslik('Servis Bildirimleri', Icons.directions_bus_outlined),
      _karti(Column(children: [
        _switch('Servis Başladı', '', _servisBasladi,
                (v) => setState(() => _servisBasladi = v), Icons.play_circle_outlined),
        const Divider(height: 1),
        _switch('Servis Yaklaşıyor', '', _yaklasiyor,
                (v) => setState(() => _yaklasiyor = v), Icons.near_me_outlined),
        const Divider(height: 1),
        _switch('Araç Geldi', '', _aracGeldi,
                (v) => setState(() => _aracGeldi = v), Icons.directions_bus_outlined),
      ])),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
            backgroundColor: _navy, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        onPressed: _bildirimKaydet,
        icon: const Icon(Icons.save_outlined, size: 18),
        label: const Text('Tercihleri Kaydet', style: TextStyle(fontWeight: FontWeight.bold)),
      )),
    ]),
  );

  // ── SEKME 3: HESAP BİLGİLERİ ─────────────────────────────────
  Widget _hesapSekme() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      // Profil kartı
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_navy, Color(0xFF2a5298)]),
            borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          CircleAvatar(
            radius: 32, backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
                (_userData?['ad'] ?? _userData?['email'] ?? 'U').isNotEmpty
                    ? (_userData?['ad'] ?? _userData?['email'] ?? 'U')[0].toUpperCase()
                    : 'U',
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_userData?['ad'] ?? '',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(_userData?['email'] ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                  color: _turuncu.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12)),
              child: Text(_userData?['rol'] ?? '',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ])),
        ]),
      ),
      const SizedBox(height: 16),
      _bolumBaslik('Hesap Bilgileri', Icons.person_outlined),
      _karti(Column(children: [
        _bilgiSatiri('E-posta', _userData?['email'] ?? '-', Icons.email_outlined),
        const Divider(height: 1),
        _bilgiSatiri('Rol', _userData?['rol'] ?? '-', Icons.badge_outlined),
        const Divider(height: 1),
        _bilgiSatiri('Firma ID', _firmaId.isNotEmpty ? _firmaId.substring(0, 8) + '...' : '-',
            Icons.business_outlined),
        const Divider(height: 1),
        _bilgiSatiri('Durum', _userData?['durum'] ?? '-', Icons.verified_outlined),
      ])),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red, side: const BorderSide(color: Colors.red),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        onPressed: _cikisYap,
        icon: const Icon(Icons.logout_outlined),
        label: const Text('Çıkış Yap', style: TextStyle(fontWeight: FontWeight.bold)),
      )),
    ]),
  );

  // ── SEKME 4: ŞİFRE DEĞİŞTİR ──────────────────────────────────
  Widget _sifreSekme() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      _bolumBaslik('Şifre Değiştir', Icons.lock_outlined),
      _karti(Column(children: [
        // Mevcut şifre
        TextField(
          controller: _eskiSifreCtrl,
          obscureText: _sifreGizle1,
          decoration: InputDecoration(
              labelText: 'Mevcut Şifre',
              prefixIcon: const Icon(Icons.lock_outlined, color: _navy, size: 18),
              suffixIcon: IconButton(
                  icon: Icon(_sifreGizle1 ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 18),
                  onPressed: () => setState(() => _sifreGizle1 = !_sifreGizle1)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
        ),
        const SizedBox(height: 10),
        // Yeni şifre
        TextField(
          controller: _yeniSifreCtrl,
          obscureText: _sifreGizle2,
          decoration: InputDecoration(
              labelText: 'Yeni Şifre (min 6 karakter)',
              prefixIcon: const Icon(Icons.lock_reset_outlined, color: _navy, size: 18),
              suffixIcon: IconButton(
                  icon: Icon(_sifreGizle2 ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 18),
                  onPressed: () => setState(() => _sifreGizle2 = !_sifreGizle2)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
        ),
        const SizedBox(height: 10),
        // Yeni şifre tekrar
        TextField(
          controller: _yeniSifreTekrarCtrl,
          obscureText: _sifreGizle3,
          decoration: InputDecoration(
              labelText: 'Yeni Şifre Tekrar',
              prefixIcon: const Icon(Icons.check_circle_outlined, color: _navy, size: 18),
              suffixIcon: IconButton(
                  icon: Icon(_sifreGizle3 ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 18),
                  onPressed: () => setState(() => _sifreGizle3 = !_sifreGizle3)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
        ),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: _navy, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: _sifreDegistir,
          icon: const Icon(Icons.lock_reset_outlined, size: 18),
          label: const Text('Şifreyi Güncelle', style: TextStyle(fontWeight: FontWeight.bold)),
        )),
        const SizedBox(height: 8),
        const Text('Şifrenizi değiştirdikten sonra yeniden giriş yapmanız gerekebilir.',
            style: TextStyle(color: Colors.grey, fontSize: 11),
            textAlign: TextAlign.center),
      ])),
    ]),
  );

  // ── SEKME 5: UYGULAMA AYARLARI ────────────────────────────────
  Widget _uygulamaSekme() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      _bolumBaslik('Hızlı Erişim', Icons.apps_outlined),
      _karti(Column(children: [
        _menuSatir(Icons.map_outlined,         'Harita Görünümü',  '/harita'),
        const Divider(height: 1),
        _menuSatir(Icons.message_outlined,     'Hazır Mesajlar',   '/hazir_mesajlar'),
        const Divider(height: 1),
        _menuSatir(Icons.access_time_outlined, 'Servis Saati',     '/servis_saati'),
        const Divider(height: 1),
        _menuSatir(Icons.receipt_outlined,     'Sözleşmeler',      '/sozlesme'),
        const Divider(height: 1),
        _menuSatir(Icons.payments_outlined,    'Fiyatlandırma',    '/fiyat_yonetim'),
      ])),
      const SizedBox(height: 8),
      _bolumBaslik('Uygulama Bilgisi', Icons.info_outline),
      _karti(Column(children: [
        _bilgiSatiri('Versiyon',  '1.0.0',          Icons.tag_outlined),
        const Divider(height: 1),
        _bilgiSatiri('Platform',  'Android',         Icons.android_outlined),
        const Divider(height: 1),
        _bilgiSatiri('Firebase',  'servis360-15b4a', Icons.cloud_outlined),
      ])),
      const SizedBox(height: 8),
      _bolumBaslik('Destek', Icons.support_outlined),
      _karti(Column(children: [
        _menuSatir(Icons.help_outline,         'Yardım',           '/yardim'),
        const Divider(height: 1),
        _menuSatir(Icons.privacy_tip_outlined, 'Gizlilik',         '/gizlilik'),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.chat_outlined, color: _navy, size: 20),
          title: const Text('WhatsApp Destek', style: TextStyle(fontSize: 13)),
          trailing: const Icon(Icons.chevron_right_outlined, color: Colors.grey, size: 18),
          onTap: () {},
          dense: true,
        ),
      ])),
    ]),
  );

  // ── YARDIMCI WIDGETLAR ────────────────────────────────────────
  Widget _bolumBaslik(String baslik, IconData ikon) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Icon(ikon, color: _navy, size: 16), const SizedBox(width: 8),
      Text(baslik, style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.bold, color: _navy)),
    ]),
  );

  Widget _karti(Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)]),
    child: child,
  );

  Widget _tf(TextEditingController c, String label, IconData ikon,
      {TextInputType? type, int maxLines = 1}) =>
      TextField(
        controller: c,
        keyboardType: type,
        maxLines: maxLines,
        decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(ikon, color: _navy, size: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
      );

  Widget _switch(String baslik, String alt, bool deger,
      ValueChanged<bool> onChanged, IconData ikon) =>
      SwitchListTile(
        secondary: Icon(ikon, color: _navy, size: 20),
        title: Text(baslik, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: alt.isNotEmpty
            ? Text(alt, style: const TextStyle(fontSize: 11))
            : null,
        value: deger,
        onChanged: onChanged,
        activeColor: _navy,
        contentPadding: const EdgeInsets.symmetric(horizontal: 0),
        dense: true,
      );

  Widget _bilgiSatiri(String label, String deger, IconData ikon) =>
      ListTile(
        leading: Icon(ikon, color: _navy, size: 18),
        title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: Text(deger,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        dense: true,
        contentPadding: EdgeInsets.zero,
      );

  Widget _menuSatir(IconData ikon, String label, String route) =>
      ListTile(
        leading: Icon(ikon, color: _navy, size: 20),
        title: Text(label, style: const TextStyle(fontSize: 13)),
        trailing: const Icon(Icons.chevron_right_outlined, color: Colors.grey, size: 18),
        onTap: () => Navigator.pushNamed(context, route),
        dense: true,
      );
}
