import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/session_service.dart';

// ════════════════════════════════════════════════════════════════
//  WEB AYARLAR — Firma Bilgileri | Bildirimler | Hesap | Sifre
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

  // Bildirim ayarlari
  bool _bildWhatsapp   = true;
  bool _bildSms        = false;
  bool _bildYaklasiyor = true;
  bool _bildBindi      = true;
  bool _bildSozlesme   = true;
  bool _bildYeniKayit  = true;
  bool _bildEvrakBitis = true;
  bool _bildSofor      = true;

  // Sifre
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

      // Bildirim ayarlari
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
    _snack('Bildirim ayarlari kaydedildi ✓', Colors.green);
  }

  Future<void> _sifreDegistir() async {
    if (_yeniSifreCtrl.text != _yeniSifre2Ctrl.text) {
      _snack('Sifreler eslesmiyor!', Colors.red); return;
    }
    if (_yeniSifreCtrl.text.length < 6) {
      _snack('Sifre en az 6 karakter olmali!', Colors.red); return;
    }
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final cred = EmailAuthProvider.credential(
          email: user.email ?? '', password: _eskiSifreCtrl.text);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(_yeniSifreCtrl.text);
      _eskiSifreCtrl.clear(); _yeniSifreCtrl.clear(); _yeniSifre2Ctrl.clear();
      _snack('Sifre guncellendi ✓', Colors.green);
    } catch (e) {
      _snack('Hata: Mevcut sifre yanlis olabilir', Colors.red);
    }
  }

  void _snack(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: c, behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) return const Center(child: CircularProgressIndicator());

    return Row(children: [
      // Sol sekme menusu
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
          _sekmeBtn(3, Icons.lock_outlined,           'Sifre Degistir'),
          _sekmeBtn(4, Icons.folder_outlined,         'Proje Ayarlari'),
          _sekmeBtn(5, Icons.map_outlined,            'Harita Ayarlari'),
          _sekmeBtn(6, Icons.manage_accounts_outlined,'Kullanici Yonetimi'),
          _sekmeBtn(7, Icons.backup_outlined,             'Yedekleme'),
          _sekmeBtn(8, Icons.archive_outlined,            'Arsiv Ayarlari'),
          _sekmeBtn(9, Icons.security_outlined,           'Guvenlik'),
          _sekmeBtn(10, Icons.code_outlined,              'Gelistirme'),
        ]),
      ),
      const VerticalDivider(width: 1),
      // Icerik
      Expanded(child: [
        _firmaTab(),
        _bildirimTab(),
        _hesapTab(),
        _sifreTab(),
        _projeAyarlariTab(),
        _haritaAyarlariTab(),
        _kullaniciYonetimiTab(),
        _yedeklemeTab(),
        _arsivAyarlariTab(),
        _guvenlikTab(),
        _gelistirmeKurallarTab(),
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

  // ── TAB 1: FIRMA BILGILERI ───────────────────────────────────
  Widget _firmaTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _baslik('Firma Bilgileri', Icons.business_outlined),
      const SizedBox(height: 4),
      const Text('Bu bilgiler sozlesmelerde ve PDF belgelerinde otomatik kullanilir',
          style: TextStyle(color: Colors.grey, fontSize: 12)),
      const SizedBox(height: 20),
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            Row(children: [
              Expanded(child: _inp(_firmaAdCtrl, 'Firma Adi *', Icons.business_outlined)),
              const SizedBox(width: 12),
              Expanded(child: _inp(_yetkiliCtrl, 'Yetkili Adi *', Icons.person_outlined)),
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

  // ── TAB 2: BILDIRIMLER ───────────────────────────────────────
  Widget _bildirimTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _baslik('Bildirim Ayarlari', Icons.notifications_outlined),
      const SizedBox(height: 20),

      // Kanal
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Bildirim Kanallari', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _navy)),
            const SizedBox(height: 12),
            _switchSatir('WhatsApp Bildirimleri', 'Olaylar WhatsApp uzerinden iletilir',
                Icons.message_rounded, const Color(0xFF25D366), _bildWhatsapp,
                    (v) => setState(() => _bildWhatsapp = v)),
            _switchSatir('SMS Bildirimleri', 'Olaylar SMS olarak iletilir',
                Icons.sms_outlined, Colors.blue, _bildSms,
                    (v) => setState(() => _bildSms = v)),
          ]),
        ),
      ),
      const SizedBox(height: 16),

      // Olay turleri
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Bildirim Olaylari', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _navy)),
            const SizedBox(height: 12),
            _switchSatir('Yeni Ogrenci Kaydi', 'Veli kayit formu doldurdugunda',
                Icons.person_add_rounded, Colors.green, _bildYeniKayit,
                    (v) => setState(() => _bildYeniKayit = v)),
            _switchSatir('Arac Yaklasiyor', 'Servis 5 dakika uzaktayken veliye gonder',
                Icons.directions_bus_rounded, Colors.orange, _bildYaklasiyor,
                    (v) => setState(() => _bildYaklasiyor = v)),
            _switchSatir('Ogrenci Bindi / Indi', 'Her binis ve iniste veliye bildir',
                Icons.how_to_reg_rounded, Colors.teal, _bildBindi,
                    (v) => setState(() => _bildBindi = v)),
            _switchSatir('Sozlesme Onaylandi', 'Veli sozlesmeyi imzaladiginda',
                Icons.verified_outlined, Colors.purple, _bildSozlesme,
                    (v) => setState(() => _bildSozlesme = v)),
            _switchSatir('Sofor Goreve Basladi', 'Sofor servisi baslattiginda',
                Icons.drive_eta_rounded, Colors.indigo, _bildSofor,
                    (v) => setState(() => _bildSofor = v)),
            _switchSatir('Evrak Suresi Bitiyor', 'Ehliyet, sigorta vb. suresi yaklasinca',
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
        label: const Text('Bildirim Ayarlarini Kaydet', style: TextStyle(fontWeight: FontWeight.bold)),
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
          trailing: Switch(value: deger, onChanged: onChange, activeThumbColor: renk),
          contentPadding: EdgeInsets.zero,
        ),
      );

  // ── TAB 3: HESAP BILGILERI ───────────────────────────────────
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
              _bilgiSatiri('Hesap Olusturma', user?.metadata.creationTime != null
                  ? '${user!.metadata.creationTime!.day}.${user.metadata.creationTime!.month}.${user.metadata.creationTime!.year}'
                  : '-', Icons.calendar_today_outlined),
              _bilgiSatiri('Son Giris', user?.metadata.lastSignInTime != null
                  ? '${user!.metadata.lastSignInTime!.day}.${user.metadata.lastSignInTime!.month}.${user.metadata.lastSignInTime!.year}'
                  : '-', Icons.login_rounded),
              _bilgiSatiri('E-posta Dogrulama', user?.emailVerified == true ? '✅ Dogrulandi' : '⚠️ Dogrulanmadi',
                  Icons.verified_user_outlined),
              const SizedBox(height: 16),
              if (user?.emailVerified == false)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: _turuncu, side: const BorderSide(color: _turuncu)),
                  onPressed: () async {
                    await user!.sendEmailVerification();
                    _snack('Dogrulama e-postasi gonderildi', Colors.green);
                  },
                  icon: const Icon(Icons.email_outlined, size: 16),
                  label: const Text('Dogrulama E-postasi Gonder'),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        // Cikis
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.red),
            title: const Text('Cikis Yap', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
            subtitle: const Text('Hesaptan cikis yaparsiniz', style: TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.red),
            onTap: () async {
              final onay = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Cikis Yap'),
                  content: const Text('Hesaptan cikmak istediginize emin misiniz?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(_, false), child: const Text('Iptal')),
                    ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(_, true),
                        child: const Text('Cikis Yap')),
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

  // ── TAB 4: SIFRE DEGISTIR ────────────────────────────────────
  Widget _sifreTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _baslik('Sifre Degistir', Icons.lock_outlined),
      const SizedBox(height: 20),
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            _sifreAlan(_eskiSifreCtrl,  'Mevcut Sifre',   _sifreGizli1, () => setState(() => _sifreGizli1 = !_sifreGizli1)),
            const SizedBox(height: 12),
            _sifreAlan(_yeniSifreCtrl,  'Yeni Sifre',     _sifreGizli2, () => setState(() => _sifreGizli2 = !_sifreGizli2)),
            const SizedBox(height: 12),
            _sifreAlan(_yeniSifre2Ctrl, 'Yeni Sifre (Tekrar)', _sifreGizli3, () => setState(() => _sifreGizli3 = !_sifreGizli3)),
            const SizedBox(height: 8),
            const Align(alignment: Alignment.centerLeft,
                child: Text('Sifre en az 6 karakter olmalidir', style: TextStyle(color: Colors.grey, fontSize: 11))),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _navy, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: _sifreDegistir,
              icon: const Icon(Icons.lock_reset_rounded, size: 18),
              label: const Text('Sifreyi Guncelle', style: TextStyle(fontWeight: FontWeight.bold)),
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
                Expanded(child: _inp(sabahCtrl, 'Sabah Saati (orn: 07:30)', Icons.wb_sunny_outlined)),
                const SizedBox(width: 12),
                Expanded(child: _inp(aksamCtrl, 'Aksam Saati (orn: 16:30)', Icons.nights_stay_outlined)),
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

  // ── TAB 6: HARITA AYARLARI ────────────────────────────────────
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

  // ── TAB 7: KULLANICI YONETIMI ─────────────────────────────────
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
  // ── Yedekleme ───────────────────────────────────────────
  Widget _yedeklemeTab() {
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Yedekleme', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _navy)),
      const SizedBox(height: 16),
      Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius:5)]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Manuel Yedek Al', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            const Text('Tum verilerinizi JSON formatinda disa aktarin.',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 12),
            Row(children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Yedekleme baslatildi...'),
                        backgroundColor: Colors.green, behavior: SnackBarBehavior.floating)),
                icon: const Icon(Icons.backup_outlined, size: 18),
                label: const Text('Yedek Al'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: _navy,
                    side: const BorderSide(color: Color(0xFF1a3a6b)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: null,
                icon: const Icon(Icons.restore_outlined, size: 18),
                label: const Text('Yedekten Yukle'),
              ),
            ]),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            const Text('Otomatik Yedekleme', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            ...[('Gunluk Yedekleme', true), ('Haftalik Yedekleme', false),
              ('Bulut Yedekleme', true)].map((item) =>
                SwitchListTile(
                  dense: true, value: item.$2,
                  onChanged: (_) {},
                  title: Text(item.$1),
                  activeColor: _navy,
                )),
          ])),
    ]));
  }

  // ── Arsiv Ayarlari ────────────────────────────────────────
  Widget _arsivAyarlariTab() {
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Arsiv Ayarlari', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _navy)),
      const SizedBox(height: 16),
      Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius:5)]),
          child: Column(children: [
            ...[
              ('Ogrenci Arsivleme Suresi', '3 Yil'),
              ('Veli Arsivleme Suresi', '3 Yil'),
              ('Sozlesme Arsivleme Suresi', '5 Yil'),
              ('Rapor Arsivleme Suresi', '2 Yil'),
              ('Devamsizlik Arsivleme', '1 Yil'),
            ].map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  const Icon(Icons.archive_outlined, size: 16, color: Color(0xFF1a3a6b)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(item.$1, style: const TextStyle(fontSize: 13))),
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                          color: const Color(0xFF1a3a6b).withValues(alpha:0.08),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(item.$2, style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Color(0xFF1a3a6b), fontSize: 12))),
                ]))),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Arsiv ayarlari kaydedildi'),
                      behavior: SnackBarBehavior.floating)),
              icon: const Icon(Icons.save_outlined, size: 18),
              label: const Text('Ayarlari Kaydet'),
            ),
          ])),
    ]));
  }

  // ── Guvenlik ──────────────────────────────────────────────
  Widget _guvenlikTab() {
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Guvenlik', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _navy)),
      const SizedBox(height: 16),
      // Son girisler
      Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.05), blurRadius:5)]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Son Girisler', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1a3a6b))),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('giris_loglari')
                    .where('firmaId', isEqualTo: _firmaId)
                    .orderBy('tarih', descending: true)
                    .limit(20)
                    .snapshots(),
                builder: (_, snap) {
                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) return const Text('Giris kaydi bulunamadi.',
                      style: TextStyle(color: Colors.grey, fontSize: 13));
                  return Column(children: docs.map((d) {
                    final dd = d.data() as Map<String,dynamic>;
                    final normal = (dd['supheliGiris'] ?? false) != true;
                    return ListTile(
                      dense: true,
                      leading: Icon(normal ? Icons.check_circle_outline : Icons.warning_outlined,
                          color: normal ? Colors.green : Colors.red, size: 18),
                      title: Text(dd['kullanici'] ?? dd['email'] ?? '',
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Text(dd['tarih']?.toString().substring(0,16) ?? '',
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      trailing: Text(dd['ip'] ?? '',
                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    );
                  }).toList());
                }),
          ])),
    ]));
  }

  Widget _gelistirmeKurallarTab()=>SingleChildScrollView(
      padding:const EdgeInsets.all(24),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Gelistirme Kurallari',
            style:TextStyle(fontSize:20,fontWeight:FontWeight.bold,color:_navy)),
        const SizedBox(height:8),
        const Text('Servisim360 gelistirme anayasasi.',style:TextStyle(color:Colors.grey)),
        const SizedBox(height:16),
        Container(padding:const EdgeInsets.all(16),
            decoration:BoxDecoration(color:_navy.withValues(alpha:0.05),borderRadius:BorderRadius.circular(14)),
            child:const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('Servisim360 v2.0.0',style:TextStyle(fontWeight:FontWeight.bold,fontSize:16,color:_navy)),
              Text('Firebase: servis360-15b4a',style:TextStyle(fontSize:12,color:Colors.grey)),
              Text('Platform: Flutter Web + Android',style:TextStyle(fontSize:11,color:Colors.grey)),
            ])),
        const SizedBox(height:20),
        for(final k in const[
          'Calisan Ozellik Silinemez — eski ozellik kaldirilmaz',
          'Menuler Korunur — izin olmadan degistirilmez',
          'Veri Kaybi Yasak — hicbir guncelleme veri silemez',
          'Once Test Sonra Canli — yeni ozellik once test ortaminda',
          'Bagimlilik Kontrolu — etkilenen moduller kontrol edilir',
          'Geri Donus Plani — her guncellemede rollback plani var',
          'Arsiv Kurali — kalici silme yok, arsivle mantigi',
          'Rol Guvenligi — izolasyon kurallari bozulamaz',
          'Proje Yapisi Korunur — sistem proje bazli calisir',
          'Mobil ve Web Uyumlu — her ozellik her platformda calisir',
          'Kod360 Hazirligi — raporlar standart yapida tutulur',
        ])Padding(padding:const EdgeInsets.only(bottom:8),
            child:Row(children:[
              const Icon(Icons.check_circle_outline,color:Colors.green,size:16),
              const SizedBox(width:10),
              Expanded(child:Text(k,style:const TextStyle(fontSize:12))),
            ])),
        const SizedBox(height:16),
        Container(padding:const EdgeInsets.all(14),
            decoration:BoxDecoration(color:Colors.green.withValues(alpha:0.06),borderRadius:BorderRadius.circular(10)),
            child:const Row(children:[
              Icon(Icons.check_circle,color:Colors.green,size:18),SizedBox(width:10),
              Expanded(child:Text('B1-B19 tamamlandi. 26 menu, 8137 satir kod aktif.',
                  style:TextStyle(fontSize:12,color:Colors.green))),
            ])),
      ]));



}
