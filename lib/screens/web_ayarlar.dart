import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/session_service.dart';

// ════════════════════════════════════════════════════════════════
//  WEB AYARLAR — Firma Bilgileri | Bildirimler | Hesap | Şifre
// ════════════════════════════════════════════════════════════════
class WebAyarlar extends StatefulWidget {
  const WebAyarlar({super.key});
  @override
  State<WebAyarlar> createState() => _WebAyarlarState();
}

class _WebAyarlarState extends State<WebAyarlar> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  int    _sekme     = 0;
  String _firmaId   = '';
  bool   _yukleniyor = true;

  // Firma bilgileri
  final _firmaAdCtrl    = TextEditingController();
  final _yetkiliCtrl    = TextEditingController();
  final _telCtrl        = TextEditingController();
  final _emailCtrl      = TextEditingController();
  final _adresCtrl      = TextEditingController();
  final _vergiCtrl      = TextEditingController();
  final _websiteCtrl    = TextEditingController();

  // Bildirim ayarları
  bool _bildWhatsapp   = true;
  bool _bildSms        = false;
  bool _bildYaklasiyor = true;
  bool _bildBindi      = true;
  bool _bildSozlesme   = true;
  bool _bildYeniKayit  = true;
  bool _bildEvrakBitis = true;
  bool _bildSofor      = true;

  // Şifre
  final _eskiSifreCtrl = TextEditingController();
  final _yeniSifreCtrl = TextEditingController();
  final _yeniSifre2Ctrl= TextEditingController();
  bool _sifreGizli1    = true;
  bool _sifreGizli2    = true;
  bool _sifreGizli3    = true;

  @override
  void initState() { super.initState(); _yukle(); }

  @override
  void dispose() {
    _firmaAdCtrl.dispose(); _yetkiliCtrl.dispose();
    _telCtrl.dispose(); _emailCtrl.dispose();
    _adresCtrl.dispose(); _vergiCtrl.dispose(); _websiteCtrl.dispose();
    _eskiSifreCtrl.dispose(); _yeniSifreCtrl.dispose(); _yeniSifre2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    _firmaId = await SessionService.instance.firmaIdAl() ?? '';
    if (_firmaId.isNotEmpty) {
      final doc = await FirebaseFirestore.instance.collection('firms').doc(_firmaId).get();
      final d   = doc.data() ?? {};
      _firmaAdCtrl.text  = d['firmaAdi']     ?? d['ad']       ?? '';
      _yetkiliCtrl.text  = d['yetkiliAd']    ?? d['yetkili']  ?? '';
      _telCtrl.text      = d['telefon']       ?? '';
      _emailCtrl.text    = d['email']         ?? '';
      _adresCtrl.text    = d['adres']         ?? '';
      _vergiCtrl.text    = d['vergiBilgisi']  ?? '';
      _websiteCtrl.text  = d['website']       ?? '';

      // Bildirim ayarları
      final bild = d['bildirimAyarlari'] as Map<String, dynamic>? ?? {};
      _bildWhatsapp   = bild['whatsapp']   ?? true;
      _bildSms        = bild['sms']        ?? false;
      _bildYaklasiyor = bild['yaklasiyor'] ?? true;
      _bildBindi      = bild['bindi']      ?? true;
      _bildSozlesme   = bild['sozlesme']   ?? true;
      _bildYeniKayit  = bild['yeniKayit']  ?? true;
      _bildEvrakBitis = bild['evrakBitis'] ?? true;
      _bildSofor      = bild['sofor']      ?? true;
    }
    if (mounted) setState(() => _yukleniyor = false);
  }

  Future<void> _firmaBilgiKaydet() async {
    if (_firmaId.isEmpty) return;
    await FirebaseFirestore.instance.collection('firms').doc(_firmaId).set({
      'firmaAdi'    : _firmaAdCtrl.text.trim(),
      'ad'          : _firmaAdCtrl.text.trim(),
      'yetkiliAd'   : _yetkiliCtrl.text.trim(),
      'yetkili'     : _yetkiliCtrl.text.trim(),
      'telefon'     : _telCtrl.text.trim(),
      'email'       : _emailCtrl.text.trim(),
      'adres'       : _adresCtrl.text.trim(),
      'vergiBilgisi': _vergiCtrl.text.trim(),
      'website'     : _websiteCtrl.text.trim(),
      'updatedAt'   : FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _snack('Firma bilgileri kaydedildi ✓', Colors.green);
  }

  Future<void> _bildirimKaydet() async {
    if (_firmaId.isEmpty) return;
    await FirebaseFirestore.instance.collection('firms').doc(_firmaId).update({
      'bildirimAyarlari': {
        'whatsapp'   : _bildWhatsapp,
        'sms'        : _bildSms,
        'yaklasiyor' : _bildYaklasiyor,
        'bindi'      : _bildBindi,
        'sozlesme'   : _bildSozlesme,
        'yeniKayit'  : _bildYeniKayit,
        'evrakBitis' : _bildEvrakBitis,
        'sofor'      : _bildSofor,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _snack('Bildirim ayarları kaydedildi ✓', Colors.green);
  }

  Future<void> _sifreDegistir() async {
    if (_yeniSifreCtrl.text != _yeniSifre2Ctrl.text) {
      _snack('Şifreler eşleşmiyor!', Colors.red); return;
    }
    if (_yeniSifreCtrl.text.length < 6) {
      _snack('Şifre en az 6 karakter olmalı!', Colors.red); return;
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final cred = EmailAuthProvider.credential(
          email: user.email ?? '', password: _eskiSifreCtrl.text);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(_yeniSifreCtrl.text);
      _eskiSifreCtrl.clear(); _yeniSifreCtrl.clear(); _yeniSifre2Ctrl.clear();
      _snack('Şifre güncellendi ✓', Colors.green);
    } catch (e) {
      _snack('Hata: Mevcut şifre yanlış olabilir', Colors.red);
    }
  }

  void _snack(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: c, behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) return const Center(child: CircularProgressIndicator());

    return Row(children: [
      // Sol sekme menüsü
      Container(
        width: 200,
        color: const Color(0xFFF8F9FA),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: _navy,
            child: const Row(children: [
              Icon(Icons.settings_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Ayarlar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
          ),
          const SizedBox(height: 8),
          _sekmeBtn(0, Icons.business_outlined,       'Firma Bilgileri'),
          _sekmeBtn(1, Icons.notifications_outlined,  'Bildirimler'),
          _sekmeBtn(2, Icons.account_circle_outlined, 'Hesap Bilgileri'),
          _sekmeBtn(3, Icons.lock_outlined,           'Şifre Değiştir'),
          _sekmeBtn(4, Icons.folder_outlined,         'Proje Ayarlari'),
          _sekmeBtn(5, Icons.map_outlined,            'Harita Ayarlari'),
          _sekmeBtn(6, Icons.manage_accounts_outlined,'Kullanici Yonetimi'),
        ]),
      ),
      const VerticalDivider(width: 1),
      // İçerik
      Expanded(child: [
        _firmaTab(),
        _bildirimTab(),
        _hesapTab(),
        _sifreTab(),
        _projeAyarlariTab(),
        _haritaAyarlariTab(),
        _kullaniciYonetimiTab(),
      ][_sekme]),
    ]);
  }

  Widget _sekmeBtn(int idx, IconData ikon, String ad) {
    final sec = _sekme == idx;
    return GestureDetector(
      onTap: () => setState(() => _sekme = idx),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: sec ? _navy.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: sec ? Border.all(color: _navy.withValues(alpha: 0.2)) : null,
        ),
        child: Row(children: [
          Icon(ikon, size: 18, color: sec ? _navy : Colors.grey),
          const SizedBox(width: 10),
          Text(ad, style: TextStyle(
              fontWeight: sec ? FontWeight.bold : FontWeight.normal,
              color: sec ? _navy : Colors.grey[700], fontSize: 13)),
        ]),
      ),
    );
  }

  // ── TAB 1: FİRMA BİLGİLERİ ───────────────────────────────────
  Widget _firmaTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _baslik('Firma Bilgileri', Icons.business_outlined),
      const SizedBox(height: 4),
      const Text('Bu bilgiler sözleşmelerde ve PDF belgelerinde otomatik kullanılır',
          style: TextStyle(color: Colors.grey, fontSize: 12)),
      const SizedBox(height: 20),
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Row(children: [
              Expanded(child: _inp(_firmaAdCtrl, 'Firma Adı *', Icons.business_outlined)),
              const SizedBox(width: 12),
              Expanded(child: _inp(_yetkiliCtrl, 'Yetkili Adı *', Icons.person_outlined)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _inp(_telCtrl,   'Telefon', Icons.phone_outlined, TextInputType.phone)),
              const SizedBox(width: 12),
              Expanded(child: _inp(_emailCtrl, 'E-posta', Icons.email_outlined, TextInputType.emailAddress)),
            ]),
            const SizedBox(height: 12),
            _inp(_adresCtrl,  'Adres', Icons.location_on_outlined),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _inp(_vergiCtrl,   'Vergi / VKN', Icons.receipt_outlined)),
              const SizedBox(width: 12),
              Expanded(child: _inp(_websiteCtrl, 'Website', Icons.language_outlined)),
            ]),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _navy, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: _firmaBilgiKaydet,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.bold)),
            )),
          ]),
        ),
      ),
    ]),
  );

  // ── TAB 2: BİLDİRİMLER ───────────────────────────────────────
  Widget _bildirimTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _baslik('Bildirim Ayarları', Icons.notifications_outlined),
      const SizedBox(height: 20),

      // Kanal
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Bildirim Kanalları', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _navy)),
            const SizedBox(height: 12),
            _switchSatir('WhatsApp Bildirimleri', 'Olaylar WhatsApp üzerinden iletilir',
                Icons.message_rounded, const Color(0xFF25D366), _bildWhatsapp,
                    (v) => setState(() => _bildWhatsapp = v)),
            _switchSatir('SMS Bildirimleri', 'Olaylar SMS olarak iletilir',
                Icons.sms_outlined, Colors.blue, _bildSms,
                    (v) => setState(() => _bildSms = v)),
          ]),
        ),
      ),
      const SizedBox(height: 16),

      // Olay türleri
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Bildirim Olayları', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _navy)),
            const SizedBox(height: 12),
            _switchSatir('Yeni Öğrenci Kaydı', 'Veli kayıt formu doldurduğunda',
                Icons.person_add_rounded, Colors.green, _bildYeniKayit,
                    (v) => setState(() => _bildYeniKayit = v)),
            _switchSatir('Araç Yaklaşıyor', 'Servis 5 dakika uzaktayken veliye gönder',
                Icons.directions_bus_rounded, Colors.orange, _bildYaklasiyor,
                    (v) => setState(() => _bildYaklasiyor = v)),
            _switchSatir('Öğrenci Bindi / İndi', 'Her biniş ve inişte veliye bildir',
                Icons.how_to_reg_rounded, Colors.teal, _bildBindi,
                    (v) => setState(() => _bildBindi = v)),
            _switchSatir('Sözleşme Onaylandı', 'Veli sözleşmeyi imzaladığında',
                Icons.verified_outlined, Colors.purple, _bildSozlesme,
                    (v) => setState(() => _bildSozlesme = v)),
            _switchSatir('Şoför Göreve Başladı', 'Şoför servisi başlattığında',
                Icons.drive_eta_rounded, Colors.indigo, _bildSofor,
                    (v) => setState(() => _bildSofor = v)),
            _switchSatir('Evrak Süresi Bitiyor', 'Ehliyet, sigorta vb. süresi yaklaşınca',
                Icons.warning_amber_rounded, Colors.red, _bildEvrakBitis,
                    (v) => setState(() => _bildEvrakBitis = v)),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
            backgroundColor: _navy, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        onPressed: _bildirimKaydet,
        icon: const Icon(Icons.save_rounded, size: 18),
        label: const Text('Bildirim Ayarlarını Kaydet', style: TextStyle(fontWeight: FontWeight.bold)),
      )),
    ]),
  );

  Widget _switchSatir(String baslik, String alt, IconData ikon, Color renk, bool deger, Function(bool) onChange) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: ListTile(
          dense: true,
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: renk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(ikon, color: renk, size: 18),
          ),
          title: Text(baslik, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          subtitle: Text(alt, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          trailing: Switch(value: deger, onChanged: onChange, activeColor: renk),
          contentPadding: EdgeInsets.zero,
        ),
      );

  // ── TAB 3: HESAP BİLGİLERİ ───────────────────────────────────
  Widget _hesapTab() {
    final user = FirebaseAuth.instance.currentUser;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _baslik('Hesap Bilgileri', Icons.account_circle_outlined),
        const SizedBox(height: 20),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              // Avatar
              CircleAvatar(
                radius: 40,
                backgroundColor: _navy.withValues(alpha: 0.1),
                child: Text(
                  (user?.email ?? 'A').substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _navy),
                ),
              ),
              const SizedBox(height: 16),
              Text(user?.email ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text('Firma ID: $_firmaId', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),

              // Bilgiler
              _bilgiSatiri('E-posta', user?.email ?? '-', Icons.email_outlined),
              _bilgiSatiri('Hesap Oluşturma', user?.metadata.creationTime != null
                  ? '${user!.metadata.creationTime!.day}.${user.metadata.creationTime!.month}.${user.metadata.creationTime!.year}'
                  : '-', Icons.calendar_today_outlined),
              _bilgiSatiri('Son Giriş', user?.metadata.lastSignInTime != null
                  ? '${user!.metadata.lastSignInTime!.day}.${user.metadata.lastSignInTime!.month}.${user.metadata.lastSignInTime!.year}'
                  : '-', Icons.login_rounded),
              _bilgiSatiri('E-posta Doğrulama', user?.emailVerified == true ? '✅ Doğrulandı' : '⚠️ Doğrulanmadı',
                  Icons.verified_user_outlined),
              const SizedBox(height: 16),
              if (user?.emailVerified == false)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: _turuncu, side: const BorderSide(color: _turuncu)),
                  onPressed: () async {
                    await user!.sendEmailVerification();
                    _snack('Doğrulama e-postası gönderildi', Colors.green);
                  },
                  icon: const Icon(Icons.email_outlined, size: 16),
                  label: const Text('Doğrulama E-postası Gönder'),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        // Çıkış
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red),
            title: const Text('Çıkış Yap', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
            subtitle: const Text('Hesaptan çıkış yaparsınız', style: TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.red),
            onTap: () async {
              final onay = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Çıkış Yap'),
                  content: const Text('Hesaptan çıkmak istediğinize emin misiniz?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(_, false), child: const Text('İptal')),
                    ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(_, true),
                        child: const Text('Çıkış Yap')),
                  ],
                ),
              );
              if (onay == true) {
                await FirebaseAuth.instance.signOut();
                if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
              }
            },
          ),
        ),
      ]),
    );
  }

  Widget _bilgiSatiri(String baslik, String deger, IconData ikon) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Icon(ikon, size: 16, color: Colors.grey[400]),
      const SizedBox(width: 10),
      Text('$baslik:', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
      const SizedBox(width: 8),
      Text(deger, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
    ]),
  );

  // ── TAB 4: ŞİFRE DEĞİŞTİR ────────────────────────────────────
  Widget _sifreTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _baslik('Şifre Değiştir', Icons.lock_outlined),
      const SizedBox(height: 20),
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            _sifreAlan(_eskiSifreCtrl,  'Mevcut Şifre',   _sifreGizli1, () => setState(() => _sifreGizli1 = !_sifreGizli1)),
            const SizedBox(height: 12),
            _sifreAlan(_yeniSifreCtrl,  'Yeni Şifre',     _sifreGizli2, () => setState(() => _sifreGizli2 = !_sifreGizli2)),
            const SizedBox(height: 12),
            _sifreAlan(_yeniSifre2Ctrl, 'Yeni Şifre (Tekrar)', _sifreGizli3, () => setState(() => _sifreGizli3 = !_sifreGizli3)),
            const SizedBox(height: 8),
            const Align(alignment: Alignment.centerLeft,
                child: Text('Şifre en az 6 karakter olmalıdır', style: TextStyle(color: Colors.grey, fontSize: 11))),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _navy, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: _sifreDegistir,
              icon: const Icon(Icons.lock_reset_rounded, size: 18),
              label: const Text('Şifreyi Güncelle', style: TextStyle(fontWeight: FontWeight.bold)),
            )),
          ]),
        ),
      ),
    ]),
  );

  Widget _sifreAlan(TextEditingController ctrl, String label, bool gizli, VoidCallback toggle) =>
      TextField(
        controller: ctrl,
        obscureText: gizli,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.lock_outlined, size: 18),
          suffixIcon: IconButton(
            icon: Icon(gizli ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
            onPressed: toggle,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          isDense: true,
        ),
      );

  // ── TAB 5: PROJE AYARLARI ─────────────────────────────────────
  Widget _projeAyarlariTab() {
    final sabahCtrl = TextEditingController(text: '07:30');
    final aksamCtrl = TextEditingController(text: '16:30');
    final okulAdresCtrl = TextEditingController();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _baslik('Proje Ayarlari', Icons.folder_outlined),
        const SizedBox(height: 4),
        const Text('Tum projeler icin varsayilan servis saatleri ve okul adresi',
            style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 20),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Varsayilan Servis Saatleri',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _navy)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _inp(sabahCtrl, 'Sabah Saati (örn: 07:30)', Icons.wb_sunny_outlined)),
                const SizedBox(width: 12),
                Expanded(child: _inp(aksamCtrl, 'Aksam Saati (örn: 16:30)', Icons.nights_stay_outlined)),
              ]),
              const SizedBox(height: 14),
              _inp(okulAdresCtrl, 'Varsayilan Okul / Is Yeri Adresi', Icons.location_on_outlined),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _navy, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () async {
                  if (_firmaId.isEmpty) return;
                  await FirebaseFirestore.instance.collection('firms').doc(_firmaId).update({
                    'varsayilanSabahSaati': sabahCtrl.text.trim(),
                    'varsayilanAksamSaati': aksamCtrl.text.trim(),
                    'varsayilanOkulAdresi': okulAdresCtrl.text.trim(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                  _snack('Proje ayarlari kaydedildi', Colors.green);
                },
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.bold)),
              )),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── TAB 6: HARİTA AYARLARI ────────────────────────────────────
  Widget _haritaAyarlariTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _baslik('Harita Ayarlari', Icons.map_outlined),
        const SizedBox(height: 20),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              _switchSatir('Gercek Zamanli Konum', 'Sofor konumu 30 saniyede bir guncellenir',
                  Icons.my_location_outlined, Colors.blue, true, (_) {}),
              _switchSatir('Rota Gosterimi', 'Haritada rotayi goster',
                  Icons.route_outlined, Colors.green, true, (_) {}),
              _switchSatir('Trafik Katmani', 'Haritada trafik bilgisi goster',
                  Icons.traffic_outlined, Colors.orange, false, (_) {}),
              const SizedBox(height: 14),
              const Align(alignment: Alignment.centerLeft,
                  child: Text('Yaklasma Mesafesi (metre)', style: TextStyle(fontWeight: FontWeight.bold, color: _navy, fontSize: 13))),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [200, 300, 500, 1000].map((m) =>
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                        color: m == 500 ? _navy : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('$m m', style: TextStyle(
                        color: m == 500 ? Colors.white : Colors.grey[700], fontWeight: FontWeight.bold)),
                  )).toList()),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _navy, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () => _snack('Harita ayarlari kaydedildi', Colors.green),
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.bold)),
              )),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── TAB 7: KULLANICI YÖNETİMİ ─────────────────────────────────
  Widget _kullaniciYonetimiTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _baslik('Kullanici Yonetimi', Icons.manage_accounts_outlined),
        const SizedBox(height: 4),
        const Text('Sofor ve veli giris ayarlari',
            style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 20),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Giris Ayarlari', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _navy)),
              const SizedBox(height: 12),
              _switchSatir('Sofor Ilk Giris Sifre Degistirme', 'Sofor ilk giriste sifresini degistirsin',
                  Icons.lock_reset_outlined, _navy, true, (_) {}),
              _switchSatir('Veli Ilk Giris Sifre Degistirme', 'Veli ilk giriste sifresini degistirsin',
                  Icons.lock_reset_outlined, Colors.purple, false, (_) {}),
              _switchSatir('Cihaz Kilidi', 'Sofor sadece kayitli cihazdan girebilir',
                  Icons.phone_android_outlined, Colors.red, false, (_) {}),
            ]),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Aktif Kullanicilar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _navy)),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('kullanicilar')
                    .where('firmaId', isEqualTo: _firmaId).snapshots(),
                builder: (_, snap) {
                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) return const Text('Kullanici bulunamadi', style: TextStyle(color: Colors.grey));
                  return Column(children: docs.map((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final aktif = d['aktif'] == true;
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(radius: 16,
                          backgroundColor: (d['rol'] == 'sofor' ? Colors.blue : Colors.purple).withValues(alpha: 0.1),
                          child: Icon(d['rol'] == 'sofor' ? Icons.person_outlined : Icons.family_restroom_outlined,
                              size: 16, color: d['rol'] == 'sofor' ? Colors.blue : Colors.purple)),
                      title: Text(d['ad'] ?? d['kullaniciAdi'] ?? '', style: const TextStyle(fontSize: 13)),
                      subtitle: Text('${d['rol'] ?? ''} — ${d['kullaniciAdi'] ?? ''}',
                          style: const TextStyle(fontSize: 11)),
                      trailing: Switch(
                        value: aktif,
                        activeColor: Colors.green,
                        onChanged: (v) => FirebaseFirestore.instance.collection('kullanicilar')
                            .doc(doc.id).update({'aktif': v}),
                      ),
                    );
                  }).toList());
                },
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _baslik(String ad, IconData ikon) => Row(children: [
    Icon(ikon, color: _navy, size: 22),
    const SizedBox(width: 10),
    Text(ad, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _navy)),
  ]);

  Widget _inp(TextEditingController c, String label, IconData ikon, [TextInputType? tip]) =>
      TextField(
        controller: c, keyboardType: tip,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(ikon, size: 16, color: _navy),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      );
}
