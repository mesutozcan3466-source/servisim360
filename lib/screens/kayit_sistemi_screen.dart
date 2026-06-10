import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/session_service.dart';

// ════════════════════════════════════════════════════════════════
//  KAYIT SİSTEMİ — 4 Sekme
//  1. Yüz Yüze Kayıt
//  2. Link ile Kayıt
//  3. QR Kayıt
//  4. Bekleyen Kayıtlar
// ════════════════════════════════════════════════════════════════
class KayitSistemiScreen extends StatefulWidget {
  const KayitSistemiScreen({super.key});
  @override
  State<KayitSistemiScreen> createState() => _KayitSistemiScreenState();
}

class _KayitSistemiScreenState extends State<KayitSistemiScreen>
    with SingleTickerProviderStateMixin {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  late TabController _tab;
  String _firmaId = '';
  String _projeId = '';
  List<Map<String, dynamic>> _projeler  = [];
  List<Map<String, dynamic>> _servisler = [];
  int _bekleyenSayi = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _yukle();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _yukle() async {
    _firmaId = await SessionService.instance.firmaIdAl() ?? '';
    _projeId = SessionService.instance.aktifProjeId ?? '';
    if (_firmaId.isEmpty) return;

    final pSnap = await FirebaseFirestore.instance
        .collection('projects')
        .where('firmaId', isEqualTo: _firmaId)
        .where('durum', isEqualTo: 'aktif').get();
    _projeler = pSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

    if (_projeId.isNotEmpty) await _servisleriYukle();

    final bSnap = await FirebaseFirestore.instance
        .collection('veli_basvurulari')
        .where('firmaId', isEqualTo: _firmaId)
        .where('durum', isEqualTo: 'beklemede').count().get();

    if (mounted) setState(() => _bekleyenSayi = bSnap.count ?? 0);
  }

  Future<void> _servisleriYukle() async {
    if (_projeId.isEmpty) return;
    final sSnap = await FirebaseFirestore.instance
        .collection('drivers')
        .where('firmaId', isEqualTo: _firmaId)
        .where('projeId', isEqualTo: _projeId).get();
    if (mounted) setState(() {
      _servisler = sSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Row(children: [
          Icon(Icons.how_to_reg_outlined, size: 20),
          SizedBox(width: 10),
          Text('Kayıt Sistemi',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: _turuncu,
          tabs: [
            const Tab(icon: Icon(Icons.person_add_outlined, size: 18), text: 'Yüz Yüze'),
            const Tab(icon: Icon(Icons.link_outlined, size: 18), text: 'Link'),
            const Tab(icon: Icon(Icons.qr_code_outlined, size: 18), text: 'QR Kod'),
            Tab(
              icon: Stack(clipBehavior: Clip.none, children: [
                const Icon(Icons.pending_actions_outlined, size: 18),
                if (_bekleyenSayi > 0) Positioned(
                  right: -8, top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    child: Text('$_bekleyenSayi',
                        style: const TextStyle(color: Colors.white, fontSize: 9,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
              text: 'Bekleyen',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _YuzYuzeSekmesi(
              firmaId: _firmaId, projeId: _projeId,
              projeler: _projeler, servisler: _servisler,
              onProjeSecildi: (id) {
                setState(() => _projeId = id);
                _servisleriYukle();
              }),
          _LinkSekmesi(firmaId: _firmaId, projeler: _projeler),
          _QrSekmesi(firmaId: _firmaId, projeler: _projeler),
          _BekleyenSekmesi(firmaId: _firmaId, servisler: _servisler,
              onOnaylandi: _yukle),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  1. YÜZ YÜZE KAYIT SEKMESİ
// ════════════════════════════════════════════════════════════════
class _YuzYuzeSekmesi extends StatefulWidget {
  final String firmaId, projeId;
  final List<Map<String, dynamic>> projeler, servisler;
  final ValueChanged<String> onProjeSecildi;
  const _YuzYuzeSekmesi({
    required this.firmaId, required this.projeId,
    required this.projeler, required this.servisler,
    required this.onProjeSecildi,
  });
  @override
  State<_YuzYuzeSekmesi> createState() => _YuzYuzeSekmesiState();
}

class _YuzYuzeSekmesiState extends State<_YuzYuzeSekmesi> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  static const _yesil   = Color(0xFF43A047);

  // Öğrenci
  final _ogrAdCtrl    = TextEditingController();
  final _okulCtrl     = TextEditingController();
  final _sinifCtrl    = TextEditingController();
  final _adresCtrl    = TextEditingController();
  // Veli
  final _veliAdCtrl   = TextEditingController();
  final _veliTelCtrl  = TextEditingController();
  final _veliTel2Ctrl = TextEditingController();
  final _veliMailCtrl = TextEditingController();
  final _kulAdiCtrl   = TextEditingController();
  final _sifreCtrl    = TextEditingController();

  String? _secilenProjeId;
  String? _secilenServisId;
  bool _sabah = true, _aksam = true;
  bool _yukleniyor = false;
  String? _basari;

  @override
  void initState() {
    super.initState();
    _secilenProjeId  = widget.projeId.isNotEmpty ? widget.projeId : null;
    _secilenServisId = widget.servisler.isNotEmpty ? null : null;
  }

  @override
  void dispose() {
    _ogrAdCtrl.dispose(); _okulCtrl.dispose(); _sinifCtrl.dispose();
    _adresCtrl.dispose(); _veliAdCtrl.dispose(); _veliTelCtrl.dispose();
    _veliTel2Ctrl.dispose(); _veliMailCtrl.dispose();
    _kulAdiCtrl.dispose(); _sifreCtrl.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    if (_ogrAdCtrl.text.trim().isEmpty) {
      _snack('Öğrenci adı zorunlu!', Colors.red); return;
    }
    if (_veliAdCtrl.text.trim().isEmpty) {
      _snack('Veli adı zorunlu!', Colors.red); return;
    }
    setState(() { _yukleniyor = true; _basari = null; });
    try {
      final db = FirebaseFirestore.instance;
      final kulAdi = _kulAdiCtrl.text.trim().isNotEmpty
          ? _kulAdiCtrl.text.trim()
          : _veliTelCtrl.text.trim();
      final sifre = _sifreCtrl.text.trim().isNotEmpty
          ? _sifreCtrl.text.trim() : '123456';

      // 1. Öğrenci kaydı
      final ogrRef = await db.collection('students').add({
        'firmaId'    : widget.firmaId,
        'projeId'    : _secilenProjeId ?? '',
        'servisId'   : _secilenServisId ?? '',
        'ad'         : _ogrAdCtrl.text.trim(),
        'okul'       : _okulCtrl.text.trim(),
        'sinif'      : _sinifCtrl.text.trim(),
        'adres'      : _adresCtrl.text.trim(),
        'sabahAdres' : _adresCtrl.text.trim(),
        'sabahKullan': _sabah,
        'aksamKullan': _aksam,
        'morningEnabled': _sabah,
        'eveningEnabled': _aksam,
        'veliAd'     : _veliAdCtrl.text.trim(),
        'veliTelefon': _veliTelCtrl.text.trim(),
        'anneTelefon': _veliTelCtrl.text.trim(),
        'durum'      : 'onayli',
        'kayitTuru'  : 'yuz_yuze',
        'olusturmaTarihi': FieldValue.serverTimestamp(),
      });

      // 2. Veli kaydı (kullanicilar + parents)
      final veliEmail = _veliMailCtrl.text.trim().isNotEmpty
          ? _veliMailCtrl.text.trim()
          : '${kulAdi}@servisim360.app';

      await db.collection('parents').add({
        'firmaId'     : widget.firmaId,
        'projeId'     : _secilenProjeId ?? '',
        'ogrenciId'   : ogrRef.id,
        'ogrenciAd'   : _ogrAdCtrl.text.trim(),
        'ad'          : _veliAdCtrl.text.trim(),
        'telefon'     : _veliTelCtrl.text.trim(),
        'telefon2'    : _veliTel2Ctrl.text.trim(),
        'email'       : veliEmail,
        'kullaniciAdi': kulAdi,
        'sifre'       : sifre,
        'durum'       : 'aktif',
        'rol'         : 'veli',
        'olusturmaTarihi': FieldValue.serverTimestamp(),
      });

      // 3. Servise öğrenci sayısı güncelle
      if (_secilenServisId != null) {
        await db.collection('drivers').doc(_secilenServisId)
            .update({'ogrenciSayi': FieldValue.increment(1)});
      }

      // Formu temizle
      _ogrAdCtrl.clear(); _okulCtrl.clear(); _sinifCtrl.clear();
      _adresCtrl.clear(); _veliAdCtrl.clear(); _veliTelCtrl.clear();
      _veliTel2Ctrl.clear(); _veliMailCtrl.clear();
      _kulAdiCtrl.clear(); _sifreCtrl.clear();

      setState(() { _basari = 'Kayıt başarıyla oluşturuldu!\nKullanıcı Adı: $kulAdi | Şifre: $sifre'; });
    } catch (e) { _snack('Hata: $e', Colors.red); }
    setState(() => _yukleniyor = false);
  }

  void _snack(String m, Color r) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m), backgroundColor: r, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Sol: Öğrenci
        Expanded(child: _bolum('Öğrenci Bilgileri', Icons.school_outlined, Colors.blue, [
          _alan(_ogrAdCtrl, 'Ad Soyad *', Icons.person_outline),
          _alan(_okulCtrl,  'Okul',        Icons.school_outlined),
          _alan(_sinifCtrl, 'Sınıf',       Icons.class_outlined),
          _alan(_adresCtrl, 'Adres',        Icons.location_on_outlined, maxLines: 2),
          const SizedBox(height: 10),
          // Proje seçimi
          _dropdown<String?>(
            label: 'Proje',
            ikon: Icons.folder_outlined,
            value: _secilenProjeId,
            items: [
              const DropdownMenuItem(value: null, child: Text('Proje seç...')),
              ...widget.projeler.map((p) => DropdownMenuItem(
                  value: p['id'] as String,
                  child: Text(p['projeAd'] as String? ?? 'Proje'))),
            ],
            onChanged: (v) {
              setState(() { _secilenProjeId = v; _secilenServisId = null; });
              if (v != null) widget.onProjeSecildi(v);
            },
          ),
          const SizedBox(height: 8),
          // Servis seçimi
          _dropdown<String?>(
            label: 'Servise Ata',
            ikon: Icons.directions_bus_outlined,
            value: _secilenServisId,
            items: [
              const DropdownMenuItem(value: null, child: Text('Servis seç...')),
              ...widget.servisler.map((s) => DropdownMenuItem(
                  value: s['id'] as String,
                  child: Text('${s['ad'] ?? 'Şoför'} — ${s['aracPlaka'] ?? ''}'))),
            ],
            onChanged: (v) => setState(() => _secilenServisId = v),
          ),
          const SizedBox(height: 10),
          // Sabah/Akşam toggle
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.grey[50], borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200)),
            child: Column(children: [
              _toggle('Sabah Servisi', _sabah, Icons.wb_sunny_outlined, Colors.orange,
                      (v) => setState(() => _sabah = v)),
              _toggle('Akşam Servisi', _aksam, Icons.nights_stay_outlined, Colors.indigo,
                      (v) => setState(() => _aksam = v)),
            ]),
          ),
        ])),
        const SizedBox(width: 20),
        // Sağ: Veli + Kaydet
        Expanded(child: Column(children: [
          _bolum('Veli Bilgileri', Icons.family_restroom_outlined, Colors.purple, [
            _alan(_veliAdCtrl,   'Veli Adı *',       Icons.person_outline),
            _alan(_veliTelCtrl,  'Telefon (Anne) *',  Icons.phone_outlined,
                tip: TextInputType.phone),
            _alan(_veliTel2Ctrl, 'Telefon (Baba)',    Icons.phone_outlined,
                tip: TextInputType.phone),
            _alan(_veliMailCtrl, 'E-posta',            Icons.email_outlined,
                tip: TextInputType.emailAddress),
          ]),
          const SizedBox(height: 16),
          _bolum('Giriş Bilgileri', Icons.lock_outline, Colors.teal, [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8)),
              child: const Row(children: [
                Icon(Icons.info_outline, size: 14, color: Colors.blue),
                SizedBox(width: 6),
                Expanded(child: Text(
                    'Boş bırakılırsa telefon numarası kullanıcı adı, 123456 şifre olur.',
                    style: TextStyle(fontSize: 11, color: Colors.blue))),
              ]),
            ),
            const SizedBox(height: 8),
            _alan(_kulAdiCtrl, 'Kullanıcı Adı', Icons.person_pin_outlined),
            _alan(_sifreCtrl,  'Geçici Şifre',   Icons.lock_outline),
          ]),
          const SizedBox(height: 16),
          // Başarı mesajı
          if (_basari != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: _yesil.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _yesil.withValues(alpha: 0.4))),
              child: Row(children: [
                const Icon(Icons.check_circle_outline, color: _yesil, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(_basari!,
                    style: const TextStyle(color: _yesil, fontSize: 13))),
              ]),
            ),
          const SizedBox(height: 12),
          // Kaydet butonu
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _navy, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: _yukleniyor ? null : _kaydet,
              icon: _yukleniyor
                  ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: Text(_yukleniyor ? 'Kaydediliyor...' : 'Kayıt Oluştur',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ])),
      ]),
    );
  }

  Widget _bolum(String baslik, IconData ikon, Color renk, List<Widget> children) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(ikon, size: 16, color: renk),
            const SizedBox(width: 8),
            Text(baslik, style: TextStyle(
                fontWeight: FontWeight.bold, color: renk, fontSize: 14)),
          ]),
          const Divider(height: 20),
          ...children.map((w) => Padding(
              padding: const EdgeInsets.only(bottom: 8), child: w)),
        ]),
      );

  Widget _alan(TextEditingController ctrl, String label, IconData ikon,
      {TextInputType? tip, int maxLines = 1}) =>
      TextField(
        controller: ctrl,
        keyboardType: tip,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(ikon, size: 18, color: _navy),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      );

  Widget _dropdown<T>({
    required String label,
    required IconData ikon,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) =>
      DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(ikon, size: 18, color: _navy),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        items: items,
        onChanged: onChanged,
      );

  Widget _toggle(String label, bool value, IconData ikon, Color renk,
      ValueChanged<bool> onChanged) =>
      Row(children: [
        Icon(ikon, size: 14, color: renk),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        Switch(value: value, onChanged: onChanged, activeColor: _turuncu),
      ]);
}

// ════════════════════════════════════════════════════════════════
//  2. LİNK İLE KAYIT SEKMESİ
// ════════════════════════════════════════════════════════════════
class _LinkSekmesi extends StatefulWidget {
  final String firmaId;
  final List<Map<String, dynamic>> projeler;
  const _LinkSekmesi({required this.firmaId, required this.projeler});
  @override
  State<_LinkSekmesi> createState() => _LinkSekmesiState();
}

class _LinkSekmesiState extends State<_LinkSekmesi> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  String? _secilenProjeId;
  String  _olusturulanLink = '';
  bool    _yukleniyor = false;
  List<Map<String, dynamic>> _linkler = [];

  @override
  void initState() { super.initState(); _linkleriYukle(); }

  Future<void> _linkleriYukle() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('kayit_linkleri')
          .where('firmaId', isEqualTo: widget.firmaId)
          .orderBy('olusturmaTarihi', descending: true)
          .limit(10).get();
      if (mounted) setState(() {
        _linkler = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      });
    } catch (_) {}
  }

  Future<void> _linkOlustur() async {
    if (_secilenProjeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Lütfen proje seçin'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() => _yukleniyor = true);
    try {
      final ref = await FirebaseFirestore.instance
          .collection('kayit_linkleri').add({
        'firmaId'        : widget.firmaId,
        'projeId'        : _secilenProjeId,
        'projeAd'        : widget.projeler.firstWhere(
                (p) => p['id'] == _secilenProjeId,
            orElse: () => {})['projeAd'] ?? '',
        'aktif'          : true,
        'kullanımSayisi' : 0,
        'olusturmaTarihi': FieldValue.serverTimestamp(),
      });
      final link = 'https://servis360-15b4a.web.app/kayit?linkId=${ref.id}';
      setState(() => _olusturulanLink = link);
      await _linkleriYukle();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Hata: $e'), backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating));
    }
    setState(() => _yukleniyor = false);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        // Link oluştur kartı
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.link_outlined, color: _navy, size: 18),
              SizedBox(width: 8),
              Text('Kayıt Linki Oluştur',
                  style: TextStyle(fontWeight: FontWeight.bold,
                      color: _navy, fontSize: 15)),
            ]),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              value: _secilenProjeId,
              decoration: InputDecoration(
                labelText: 'Proje Seç',
                prefixIcon: const Icon(Icons.folder_outlined, color: _navy, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Proje seç...')),
                ...widget.projeler.map((p) => DropdownMenuItem(
                    value: p['id'] as String,
                    child: Text(p['projeAd'] as String? ?? 'Proje'))),
              ],
              onChanged: (v) => setState(() => _secilenProjeId = v),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity, height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _turuncu, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                onPressed: _yukleniyor ? null : _linkOlustur,
                icon: _yukleniyor
                    ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.add_link_outlined),
                label: Text(_yukleniyor ? 'Oluşturuluyor...' : 'Link Oluştur',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            // Oluşturulan link
            if (_olusturulanLink.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.shade200)),
                child: Column(children: [
                  const Row(children: [
                    Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                    SizedBox(width: 6),
                    Text('Link oluşturuldu!',
                        style: TextStyle(color: Colors.green,
                            fontWeight: FontWeight.bold, fontSize: 13)),
                  ]),
                  const SizedBox(height: 8),
                  SelectableText(_olusturulanLink,
                      style: const TextStyle(fontSize: 12, color: Colors.blue)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _olusturulanLink));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Link kopyalandı!'),
                            behavior: SnackBarBehavior.floating));
                      },
                      icon: const Icon(Icons.copy_outlined, size: 14),
                      label: const Text('Kopyala', style: TextStyle(fontSize: 12)),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(
                      onPressed: () async {
                        final encoded = Uri.encodeComponent(_olusturulanLink);
                        final wa = Uri.parse('https://wa.me/?text=$encoded');
                        if (await canLaunchUrl(wa)) await launchUrl(wa);
                      },
                      icon: const Icon(Icons.share_outlined, size: 14),
                      label: const Text('WhatsApp', style: TextStyle(fontSize: 12)),
                    )),
                  ]),
                ]),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 16),
        // Mevcut linkler
        if (_linkler.isNotEmpty) Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Oluşturulan Linkler',
                style: TextStyle(fontWeight: FontWeight.bold,
                    color: _navy, fontSize: 14)),
            const SizedBox(height: 12),
            ..._linkler.map((l) {
              final linkId = l['id'] as String;
              final link = 'https://servis360-15b4a.web.app/kayit?linkId=$linkId';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200)),
                child: Row(children: [
                  const Icon(Icons.link_outlined, color: _navy, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l['projeAd'] as String? ?? 'Proje',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(link, style: const TextStyle(fontSize: 10, color: Colors.grey),
                        overflow: TextOverflow.ellipsis),
                    Text('${l['kullanımSayisi'] ?? 0} kez kullanıldı',
                        style: const TextStyle(fontSize: 11, color: Colors.blue)),
                  ])),
                  IconButton(
                    icon: const Icon(Icons.copy_outlined, size: 16, color: _navy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: link));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Kopyalandı!'),
                          behavior: SnackBarBehavior.floating));
                    },
                  ),
                ]),
              );
            }),
          ]),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  3. QR KOD SEKMESİ
// ════════════════════════════════════════════════════════════════
class _QrSekmesi extends StatefulWidget {
  final String firmaId;
  final List<Map<String, dynamic>> projeler;
  const _QrSekmesi({required this.firmaId, required this.projeler});
  @override
  State<_QrSekmesi> createState() => _QrSekmesiState();
}

class _QrSekmesiState extends State<_QrSekmesi> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  String? _secilenProjeId;
  String  _qrLink = '';

  void _qrOlustur() {
    if (_secilenProjeId == null) return;
    setState(() {
      _qrLink = 'https://servis360-15b4a.web.app/kayit?linkId=qr_${widget.firmaId}_$_secilenProjeId';
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
          child: Column(children: [
            const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.qr_code_outlined, color: _navy, size: 24),
              SizedBox(width: 10),
              Text('QR Kod Oluştur',
                  style: TextStyle(fontWeight: FontWeight.bold,
                      color: _navy, fontSize: 18)),
            ]),
            const SizedBox(height: 6),
            const Text('Veliler QR kodu okutarak kayıt formuna ulaşır',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 20),
            DropdownButtonFormField<String?>(
              value: _secilenProjeId,
              decoration: InputDecoration(
                labelText: 'Proje Seç',
                prefixIcon: const Icon(Icons.folder_outlined, color: _navy, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Proje seç...')),
                ...widget.projeler.map((p) => DropdownMenuItem(
                    value: p['id'] as String,
                    child: Text(p['projeAd'] as String? ?? 'Proje'))),
              ],
              onChanged: (v) => setState(() => _secilenProjeId = v),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity, height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _turuncu, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                onPressed: _secilenProjeId == null ? null : _qrOlustur,
                icon: const Icon(Icons.qr_code_2_outlined),
                label: const Text('QR Oluştur',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            if (_qrLink.isNotEmpty) ...[
              const SizedBox(height: 24),
              QrImageView(
                data: _qrLink,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 10),
              const Text(
                  'Veliler bu kodu okutarak kayıt formuna ulaşır.',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                  textAlign: TextAlign.center),
            ],
          ]),
        ),
      )),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  4. BEKLEYEN KAYITLAR SEKMESİ
// ════════════════════════════════════════════════════════════════
class _BekleyenSekmesi extends StatelessWidget {
  final String firmaId;
  final List<Map<String, dynamic>> servisler;
  final VoidCallback onOnaylandi;
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  static const _yesil   = Color(0xFF43A047);
  static const _kirmizi = Color(0xFFE53935);

  const _BekleyenSekmesi({
    required this.firmaId, required this.servisler,
    required this.onOnaylandi,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('veli_basvurulari')
          .where('firmaId', isEqualTo: firmaId)
          .orderBy('olusturmaTarihi', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _navy));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 12),
              Text('Bekleyen kayıt yok',
                  style: TextStyle(color: Colors.grey, fontSize: 16)),
            ],
          ));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d     = docs[i].data() as Map<String, dynamic>;
            final docId = docs[i].id;
            final durum = d['durum'] as String? ?? 'beklemede';
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _durumRenk(durum).withValues(alpha: 0.3)),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)]),
              child: Column(children: [
                // Başlık
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: _durumRenk(durum).withValues(alpha: 0.06),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(14))),
                  child: Row(children: [
                    CircleAvatar(radius: 18,
                        backgroundColor: _durumRenk(durum).withValues(alpha: 0.15),
                        child: Text(
                            (d['ogrenciAd'] as String? ?? '?').isNotEmpty
                                ? (d['ogrenciAd'] as String)[0].toUpperCase() : '?',
                            style: TextStyle(color: _durumRenk(durum),
                                fontWeight: FontWeight.bold))),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d['ogrenciAd'] as String? ?? 'Öğrenci',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('Veli: ${d['veliAd'] ?? '-'}  •  ${d['veliTelefon'] ?? ''}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: _durumRenk(durum).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(durum,
                          style: TextStyle(fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _durumRenk(durum))),
                    ),
                  ]),
                ),
                // Detaylar
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(children: [
                    Row(children: [
                      Expanded(child: _satir('Okul', d['okul'] ?? '-', Icons.school_outlined)),
                      Expanded(child: _satir('Sınıf', d['sinif'] ?? '-', Icons.class_outlined)),
                    ]),
                    _satir('Adres', d['adres'] ?? '-', Icons.location_on_outlined),
                    _satir('Proje', d['projeAd'] ?? '-', Icons.folder_outlined),
                    if ((d['fiyat'] ?? '').toString().isNotEmpty)
                      _satir('Hesaplanan Fiyat', '${d['fiyat']} ₺', Icons.payments_outlined),
                  ]),
                ),
                // Butonlar
                if (durum == 'beklemede')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Row(children: [
                      // Servise ata dropdown
                      Expanded(child: DropdownButtonFormField<String?>(
                        value: null,
                        decoration: InputDecoration(
                          labelText: 'Servise Ata',
                          isDense: true,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Servis seç...')),
                          ...servisler.map((s) => DropdownMenuItem(
                              value: s['id'] as String,
                              child: Text('${s['ad'] ?? 'Şoför'}', overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (servisId) async {
                          if (servisId == null) return;
                          await _onayla(context, docId, d, servisId);
                          onOnaylandi();
                        },
                      )),
                      const SizedBox(width: 8),
                      // Reddet
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: _kirmizi,
                            side: const BorderSide(color: _kirmizi),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                        onPressed: () async {
                          await FirebaseFirestore.instance
                              .collection('veli_basvurulari')
                              .doc(docId)
                              .update({'durum': 'reddedildi'});
                        },
                        icon: const Icon(Icons.close_outlined, size: 14),
                        label: const Text('Reddet', style: TextStyle(fontSize: 12)),
                      ),
                    ]),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: _durumRenk(durum).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(durum == 'onaylandi'
                            ? Icons.check_circle_outline : Icons.cancel_outlined,
                            color: _durumRenk(durum), size: 16),
                        const SizedBox(width: 6),
                        Text(durum == 'onaylandi' ? 'Onaylandı' : 'Reddedildi',
                            style: TextStyle(color: _durumRenk(durum),
                                fontWeight: FontWeight.bold, fontSize: 13)),
                      ]),
                    ),
                  ),
              ]),
            );
          },
        );
      },
    );
  }

  Future<void> _onayla(BuildContext ctx, String docId,
      Map<String, dynamic> d, String servisId) async {
    final db = FirebaseFirestore.instance;
    try {
      final kulAdi = d['veliTelefon']?.toString() ?? 'veli_${docId.substring(0, 6)}';
      final sifre  = '123456';

      // Öğrenci oluştur
      final ogrRef = await db.collection('students').add({
        'firmaId'    : firmaId,
        'projeId'    : d['projeId'] ?? '',
        'servisId'   : servisId,
        'ad'         : d['ogrenciAd'] ?? '',
        'okul'       : d['okul'] ?? '',
        'sinif'      : d['sinif'] ?? '',
        'adres'      : d['adres'] ?? '',
        'sabahAdres' : d['adres'] ?? '',
        'veliAd'     : d['veliAd'] ?? '',
        'veliTelefon': d['veliTelefon'] ?? '',
        'anneTelefon': d['veliTelefon'] ?? '',
        'durum'      : 'onayli',
        'kayitTuru'  : 'link',
        'olusturmaTarihi': FieldValue.serverTimestamp(),
      });

      // Veli oluştur
      await db.collection('parents').add({
        'firmaId'     : firmaId,
        'projeId'     : d['projeId'] ?? '',
        'ogrenciId'   : ogrRef.id,
        'ogrenciAd'   : d['ogrenciAd'] ?? '',
        'ad'          : d['veliAd'] ?? '',
        'telefon'     : d['veliTelefon'] ?? '',
        'email'       : d['veliEmail'] ?? '',
        'kullaniciAdi': kulAdi,
        'sifre'       : sifre,
        'durum'       : 'aktif',
        'rol'         : 'veli',
        'olusturmaTarihi': FieldValue.serverTimestamp(),
      });

      // Başvuruyu güncelle
      await db.collection('veli_basvurulari').doc(docId)
          .update({'durum': 'onaylandi', 'servisId': servisId});

      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
            content: Text('Onaylandı! Kullanıcı Adı: $kulAdi | Şifre: $sifre'),
            backgroundColor: _yesil,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5)));
      }
    } catch (e) {
      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text('Hata: $e'), backgroundColor: _kirmizi,
          behavior: SnackBarBehavior.floating));
    }
  }

  Widget _satir(String label, String deger, IconData ikon) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Icon(ikon, size: 13, color: Colors.grey),
      const SizedBox(width: 6),
      Text('$label: ', style: const TextStyle(fontSize: 12, color: Colors.grey)),
      Expanded(child: Text(deger,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis)),
    ]),
  );

  Color _durumRenk(String durum) {
    switch (durum) {
      case 'onaylandi':  return _yesil;
      case 'reddedildi': return _kirmizi;
      default:           return _turuncu;
    }
  }
}
