// ╔══════════════════════════════════════════════════════════════╗
// ║  DOSYA: lib/screens/veli_kayit_yuz_yuze_scren.dart
// ║  Yüz Yüze Kayıt — proje seçimi → form → sözleşme → imza → PDF
// ║  Link sistemiyle aynı mantık, proje bazlı
// ╚══════════════════════════════════════════════════════════════╝
import 'package:flutter/material.dart';
import 'ai_widget.dart';
import 'yardim_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/session_service.dart';
import 'dijital_imza_screen.dart';

class VeliKayitYuzYuzeScreen extends StatefulWidget {
  const VeliKayitYuzYuzeScreen({super.key});
  @override
  State<VeliKayitYuzYuzeScreen> createState() => _VeliKayitYuzYuzeScreenState();
}

class _VeliKayitYuzYuzeScreenState extends State<VeliKayitYuzYuzeScreen> {
  static const _navy   = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);

  // ── Adımlar ──────────────────────────────────────────────────
  // 0=Proje Seç  1=Form  2=Sözleşme  3=İmza  4=Tamamlandı
  int _adim = 0;

  // Proje
  String _firmaId  = '';
  List<Map<String, dynamic>> _projeler = [];
  String _seciliProjeId  = '';
  String _seciliProjeAdi = '';
  bool _projelerYukleniyor = true;

  // Sözleşme şablonu
  List<Map<String, dynamic>> _sablonMaddeleri = [];
  List<Map<String, dynamic>> _ozelMaddeler    = [];
  String _bilgi  = '';
  String _firmaAdi = '';

  // Form controller'ları
  final _veliAdCtrl      = TextEditingController();
  final _veliSoyadCtrl   = TextEditingController();
  final _veliTcCtrl      = TextEditingController();
  final _babaTelCtrl     = TextEditingController();
  final _anneTelCtrl     = TextEditingController();
  final _ogrAdCtrl       = TextEditingController();
  final _ogrTcCtrl       = TextEditingController();
  final _ogrSinifCtrl    = TextEditingController();
  final _ogrOkulNoCtrl   = TextEditingController();
  final _okulAdiCtrl     = TextEditingController();
  final _ogrTelCtrl      = TextEditingController();
  final _adresCtrl       = TextEditingController();
  final _notCtrl         = TextEditingController();

  // Fiyat
  String _hesaplananFiyat = '';
  List<Map<String, dynamic>> _fiyatlar = [];

  // Onaylar
  bool _sozlesmeOnay = false;
  bool _ucretOnay    = false;
  bool _kvkkOnay     = false;
  bool _dogruOnay    = false;
  bool _dijitalOnay  = false;

  // İmza
  bool _imzaTamamlandi = false;
  Map<String, dynamic>? _imzaVeri;

  // Kayıt
  bool _yukleniyor = false;
  String _kayitliOgrAd = '';
  String _kayitliVeliAd = '';

  @override
  void initState() {
    super.initState();
    _yukle();
    _adresCtrl.addListener(_fiyatHesapla);
  }

  @override
  void dispose() {
    _veliAdCtrl.dispose(); _veliSoyadCtrl.dispose(); _veliTcCtrl.dispose();
    _babaTelCtrl.dispose(); _anneTelCtrl.dispose();
    _ogrAdCtrl.dispose(); _ogrTcCtrl.dispose(); _ogrSinifCtrl.dispose();
    _ogrOkulNoCtrl.dispose(); _okulAdiCtrl.dispose(); _ogrTelCtrl.dispose();
    _adresCtrl.dispose(); _notCtrl.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    _firmaId = await SessionService.instance.firmaIdAl() ?? '';
    if (_firmaId.isEmpty) { setState(() => _projelerYukleniyor = false); return; }

    final firmaDoc = await FirebaseFirestore.instance
        .collection('firms').doc(_firmaId).get();
    _firmaAdi = firmaDoc.data()?['firmaAdi'] ?? firmaDoc.data()?['ad'] ?? '';

    final snap = await FirebaseFirestore.instance
        .collection('projects')
        .where('firmaId', isEqualTo: _firmaId)
        .where('aktif', isEqualTo: true)
        .get();

    _projeler = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

    // Aktif proje varsa onu ön seç
    final aktifId = SessionService.instance.aktifProjeId ?? '';
    if (aktifId.isNotEmpty) {
      final aktif = _projeler.firstWhere(
              (p) => p['id'] == aktifId, orElse: () => {});
      if (aktif.isNotEmpty) {
        _seciliProjeId  = aktifId;
        _seciliProjeAdi = aktif['projeAd'] ?? aktif['ad'] ?? '';
      }
    }

    setState(() => _projelerYukleniyor = false);
  }

  Future<void> _projeSec(Map<String, dynamic> proje) async {
    _seciliProjeId  = proje['id'];
    _seciliProjeAdi = proje['projeAd'] ?? proje['ad'] ?? '';

    // Projeye ait sözleşme şablonunu yükle
    _sablonMaddeleri = [];
    _ozelMaddeler    = [];
    _bilgi           = proje['bilgilendirme'] ?? '';

    final sablonId = proje['sozlesmeSablonId'] as String?;
    if (sablonId != null && sablonId.isNotEmpty) {
      final sabDoc = await FirebaseFirestore.instance
          .collection('firms').doc(_firmaId)
          .collection('sozlesme_sablonlar').doc(sablonId).get();
      final sabData = sabDoc.data() ?? {};
      _sablonMaddeleri = List<Map<String, dynamic>>.from(
          sabData['maddeler'] ?? []).where((m) => m['aktif'] == true).toList();
      _ozelMaddeler = List<Map<String, dynamic>>.from(
          sabData['ozelMaddeler'] ?? []);
    }

    // Fiyatları yükle
    final fSnap = await FirebaseFirestore.instance
        .collection('fiyatlar')
        .where('firmaId', isEqualTo: _firmaId)
        .get();
    _fiyatlar = fSnap.docs.map((d) => d.data()).toList();

    setState(() => _adim = 1);
  }

  void _fiyatHesapla() {
    final adres = _adresCtrl.text.toLowerCase();
    if (adres.length < 4) { setState(() => _hesaplananFiyat = ''); return; }

    String bulunan = '';
    for (final f in _fiyatlar) {
      final ilce    = (f['ilce']    ?? '').toString().toLowerCase();
      final mahalle = (f['mahalle'] ?? '').toString().toLowerCase();
      if (ilce.isNotEmpty && mahalle.isNotEmpty &&
          adres.contains(ilce) && adres.contains(mahalle)) {
        bulunan = '${(f['fiyat'] ?? f['ucret'])?.toStringAsFixed(0) ?? ''} TL / ay';
        break;
      }
    }
    if (bulunan.isEmpty) {
      for (final f in _fiyatlar) {
        final mahalle = (f['mahalle'] ?? '').toString().toLowerCase();
        if (mahalle.isNotEmpty && adres.contains(mahalle)) {
          bulunan = '${(f['fiyat'] ?? f['ucret'])?.toStringAsFixed(0) ?? ''} TL / ay';
          break;
        }
      }
    }
    setState(() => _hesaplananFiyat = bulunan);
  }

  bool get _formGecerli =>
      _veliAdCtrl.text.trim().isNotEmpty &&
          _babaTelCtrl.text.trim().isNotEmpty &&
          _ogrAdCtrl.text.trim().isNotEmpty &&
          _adresCtrl.text.trim().isNotEmpty &&
          _okulAdiCtrl.text.trim().isNotEmpty;

  bool get _onaylarTam =>
      _sozlesmeOnay && _ucretOnay && _kvkkOnay &&
          _dogruOnay && _dijitalOnay && _imzaTamamlandi;

  Future<void> _kaydet() async {
    setState(() => _yukleniyor = true);
    try {
      final now = FieldValue.serverTimestamp();
      final geciciSifre = _babaTelCtrl.text.trim();
      final kulAdi      = _babaTelCtrl.text.trim();

      // 1. Öğrenci kaydı
      final ogrRef = await FirebaseFirestore.instance
          .collection('students').add({
        'firmaId'    : _firmaId,
        'projeId'    : _seciliProjeId,
        'ad'         : _ogrAdCtrl.text.trim(),
        'soyad'      : '',
        'adSoyad'    : _ogrAdCtrl.text.trim(),
        'ogrenciTc'  : _ogrTcCtrl.text.trim(),
        'sinif'      : _ogrSinifCtrl.text.trim(),
        'okulNo'     : _ogrOkulNoCtrl.text.trim(),
        'okul'       : _okulAdiCtrl.text.trim(),
        'ogrenciTel' : _ogrTelCtrl.text.trim(),
        'adres'      : _adresCtrl.text.trim(),
        'veliAd'     : '${_veliAdCtrl.text.trim()} ${_veliSoyadCtrl.text.trim()}'.trim(),
        'veliTc'     : _veliTcCtrl.text.trim(),
        'veliTel'    : _babaTelCtrl.text.trim(),
        'babaTel'    : _babaTelCtrl.text.trim(),
        'anneTel'    : _anneTelCtrl.text.trim(),
        'aylikUcret' : _hesaplananFiyat,
        'sozlesmeDurum': 'imzalandi',
        'imzaVeri'   : _imzaVeri,
        'kayitTipi'  : 'yuz_yuze',
        'aktif'      : true,
        'bindi'      : false,
        'olusturma'  : now,
      });

      // 2. Veli kaydı
      await FirebaseFirestore.instance
          .collection('parents').doc(ogrRef.id).set({
        'firmaId'     : _firmaId,
        'ogrenciId'   : ogrRef.id,
        'ad'          : '${_veliAdCtrl.text.trim()} ${_veliSoyadCtrl.text.trim()}'.trim(),
        'tc'          : _veliTcCtrl.text.trim(),
        'telefon'     : _babaTelCtrl.text.trim(),
        'kullaniciAdi': kulAdi,
        'geciciSifre' : geciciSifre,
        'ilkGiris'    : true,
        'aktif'       : true,
        'rol'         : 'veli',
        'olusturma'   : now,
      });

      // 3. Kullanıcı hesabı
      await FirebaseFirestore.instance
          .collection('kullanicilar').doc(ogrRef.id).set({
        'firmaId'     : _firmaId,
        'ad'          : '${_veliAdCtrl.text.trim()} ${_veliSoyadCtrl.text.trim()}'.trim(),
        'kullaniciAdi': kulAdi,
        'sifre'       : geciciSifre,
        'ilkGiris'    : true,
        'rol'         : 'veli',
        'ogrenciId'   : ogrRef.id,
        'olusturma'   : now,
      });

      // 4. Sözleşme arşivi
      await FirebaseFirestore.instance.collection('sozlesmeler').add({
        'firmaId'     : _firmaId,
        'projeId'     : _seciliProjeId,
        'ogrenciId'   : ogrRef.id,
        'ogrenciAd'   : _ogrAdCtrl.text.trim(),
        'veliAd'      : '${_veliAdCtrl.text.trim()} ${_veliSoyadCtrl.text.trim()}'.trim(),
        'ucret'       : _hesaplananFiyat,
        'durum'       : 'imzalandi',
        'imzaVeri'    : _imzaVeri,
        'kayitTipi'   : 'yuz_yuze',
        'onayTarihi'  : now,
        'olusturma'   : now,
      });

      _kayitliOgrAd  = _ogrAdCtrl.text.trim();
      _kayitliVeliAd = '${_veliAdCtrl.text.trim()} ${_veliSoyadCtrl.text.trim()}'.trim();

      setState(() { _yukleniyor = false; _adim = 4; });
    } catch (e) {
      setState(() => _yukleniyor = false);
      _snack('Hata: $e');
    }
  }

  void _snack(String m, {Color renk = Colors.red}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m), backgroundColor: renk,
        behavior: SnackBarBehavior.floating));
  }

  // ════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white,
        actions: [AiAsistanButonu(ekranAdi: 'Kayitlar'),
          YardimButonu(ekranAdi: 'Kayitlar')],
        title: Text(_adimBasligi(), style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: _adim > 0 && _adim < 4
            ? IconButton(icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => setState(() => _adim--))
            : null,
        bottom: _adim > 0 && _adim < 4
            ? PreferredSize(
            preferredSize: const Size.fromHeight(6),
            child: LinearProgressIndicator(
                value: _adim / 3,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(_orange)))
            : null,
      ),
      body: IndexedStack(index: _adim, children: [
        _adim0ProjeSecimi(),
        _adim1Form(),
        _adim2Sozlesme(),
        _adim3Imza(),
        _adim4Tamamlandi(),
      ]),
    );
  }

  String _adimBasligi() {
    switch (_adim) {
      case 0:  return 'Proje Seçin';
      case 1:  return 'Kayıt Formu — $_seciliProjeAdi';
      case 2:  return 'Sözleşme — $_seciliProjeAdi';
      case 3:  return 'Dijital İmza';
      case 4:  return 'Kayıt Tamamlandı';
      default: return 'Yüz Yüze Kayıt';
    }
  }

  // ── ADIM 0: Proje Seç ────────────────────────────────────────
  Widget _adim0ProjeSecimi() {
    if (_projelerYukleniyor) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_projeler.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.folder_off_outlined, size: 72, color: Colors.grey[300]),
        const SizedBox(height: 12),
        const Text('Henüz aktif proje yok',
            style: TextStyle(fontSize: 16, color: Colors.grey)),
        const SizedBox(height: 8),
        const Text('Önce bir proje oluşturun',
            style: TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _navy, foregroundColor: Colors.white),
            onPressed: () => Navigator.pushNamed(context, '/projeler'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Proje Oluştur')),
      ]));
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
              color: _navy.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _navy.withValues(alpha: 0.2))),
          child: const Row(children: [
            Icon(Icons.info_outline, color: Color(0xFF1a3a6b), size: 16),
            SizedBox(width: 10),
            Expanded(child: Text(
              'Kayıt yapacağınız projeyi seçin. Her proje kendi sözleşmesini ve fiyatlarını kullanır.',
              style: TextStyle(fontSize: 12, color: Color(0xFF1a3a6b)),
            )),
          ]),
        ),

        ..._projeler.map((p) {
          final ad    = p['projeAd'] ?? p['ad'] ?? 'Proje';
          final donem = p['donem']   ?? '';
          final tip   = p['tip']     ?? '';
          final secili = p['id'] == _seciliProjeId;

          return GestureDetector(
            onTap: () => _projeSec(p),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: secili ? _navy : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: secili ? _navy : Colors.grey.shade200,
                      width: secili ? 2 : 1),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6)]),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: secili
                          ? Colors.white.withValues(alpha: 0.2)
                          : _navy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.folder_outlined,
                      color: secili ? Colors.white : _navy, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ad, style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15,
                      color: secili ? Colors.white : Colors.black87)),
                  if (donem.isNotEmpty || tip.isNotEmpty)
                    Text('${donem.isNotEmpty ? donem : ''}'
                        '${donem.isNotEmpty && tip.isNotEmpty ? ' · ' : ''}'
                        '${tip.isNotEmpty ? tip : ''}',
                        style: TextStyle(
                            fontSize: 12,
                            color: secili
                                ? Colors.white.withValues(alpha:0.7) : Colors.grey[500])),
                ])),
                Icon(Icons.arrow_forward_ios_rounded,
                    color: secili ? Colors.white.withValues(alpha:0.7) : Colors.grey[300], size: 16),
              ]),
            ),
          );
        }),
      ],
    );
  }

  // ── ADIM 1: Form ─────────────────────────────────────────────
  Widget _adim1Form() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // Bilgilendirme
      if (_bilgi.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200)),
          child: Text(_bilgi, style: TextStyle(color: Colors.blue[800], fontSize: 13)),
        ),

      _bolum('Öğrenci Bilgileri', Icons.school_outlined),
      const SizedBox(height: 10),
      _inp(_ogrAdCtrl,    'Öğrenci Ad Soyad *', Icons.badge_outlined),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _inp(_ogrTcCtrl, 'TC Kimlik', Icons.credit_card_outlined,
            tip: TextInputType.number)),
        const SizedBox(width: 8),
        Expanded(child: _inp(_ogrTelCtrl, 'Öğrenci Tel', Icons.phone_outlined,
            tip: TextInputType.phone)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _inp(_ogrSinifCtrl, 'Sınıf *', Icons.class_outlined)),
        const SizedBox(width: 8),
        Expanded(child: _inp(_ogrOkulNoCtrl, 'Okul No', Icons.numbers_outlined,
            tip: TextInputType.number)),
      ]),
      const SizedBox(height: 8),
      _inp(_okulAdiCtrl, 'Okul Adı *', Icons.account_balance_outlined),

      const SizedBox(height: 20),
      _bolum('Veli Bilgileri', Icons.person_outlined),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _inp(_veliAdCtrl, 'Veli Adı *', Icons.person_outlined)),
        const SizedBox(width: 8),
        Expanded(child: _inp(_veliSoyadCtrl, 'Veli Soyadı', Icons.person_outlined)),
      ]),
      const SizedBox(height: 8),
      _inp(_veliTcCtrl, 'Veli TC Kimlik', Icons.credit_card_outlined,
          tip: TextInputType.number),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _inp(_babaTelCtrl, 'Baba Tel *', Icons.phone_outlined,
            tip: TextInputType.phone)),
        const SizedBox(width: 8),
        Expanded(child: _inp(_anneTelCtrl, 'Anne Tel', Icons.phone_outlined,
            tip: TextInputType.phone)),
      ]),

      const SizedBox(height: 20),
      _bolum('Adres & Aidat', Icons.location_on_outlined),
      const SizedBox(height: 10),
      TextField(
        controller: _adresCtrl,
        maxLines: 2,
        decoration: InputDecoration(
          labelText: 'Ev Adresi * (Mahalle, Sokak, No)',
          hintText: 'Adres yazılmazsa fiyat hesaplanamaz',
          prefixIcon: const Icon(Icons.location_on_outlined, color: _navy, size: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          helperText: 'Doğru mahalle yazılmazsa fiyat hesaplanamaz',
          helperStyle: const TextStyle(color: Colors.orange, fontSize: 11),
        ),
      ),

      // Fiyat göster
      if (_hesaplananFiyat.isNotEmpty) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200)),
          child: Row(children: [
            const Icon(Icons.check_circle_outline,
                color: Colors.green, size: 20),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Aylık Aidat',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
              Text(_hesaplananFiyat, style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 20,
                  color: Colors.green)),
            ]),
          ]),
        ),
      ] else if (_adresCtrl.text.length > 4) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.shade200)),
          child: const Row(children: [
            Icon(Icons.warning_amber_outlined, color: Colors.orange, size: 16),
            SizedBox(width: 8),
            Expanded(child: Text(
                'Bu adres için fiyat bulunamadı. Fiyat Yönetimi\'nden mahalle bazlı fiyat ekleyin.',
                style: TextStyle(fontSize: 11, color: Colors.orange))),
          ]),
        ),
      ],

      const SizedBox(height: 8),
      _inp(_notCtrl, 'Not (opsiyonel)', Icons.notes_outlined, satir: 2),

      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
            backgroundColor: _orange, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        onPressed: _formGecerli
            ? () => setState(() => _adim = 2)
            : null,
        icon: const Icon(Icons.arrow_forward_rounded),
        label: const Text('Sözleşmeye Geç',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      )),
      if (!_formGecerli)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('* ile işaretli alanlar zorunludur',
              style: TextStyle(color: Colors.red, fontSize: 11),
              textAlign: TextAlign.center),
        ),
      const SizedBox(height: 40),
    ]),
  );

  // ── ADIM 2: Sözleşme ─────────────────────────────────────────
  Widget _adim2Sozlesme() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(children: [

      // Sözleşme metni
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$_firmaAdi HİZMET SÖZLEŞMESİ',
              style: const TextStyle(fontWeight: FontWeight.bold,
                  fontSize: 15, color: _navy),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('Proje: $_seciliProjeAdi',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
              textAlign: TextAlign.center),
          const Divider(height: 20),

          // Öğrenci bilgileri özet
          _sozlesmeBilgiSatir('Öğrenci', _ogrAdCtrl.text.trim()),
          _sozlesmeBilgiSatir('Okul', _okulAdiCtrl.text.trim()),
          _sozlesmeBilgiSatir('Sınıf', _ogrSinifCtrl.text.trim()),
          _sozlesmeBilgiSatir('Veli', '${_veliAdCtrl.text.trim()} ${_veliSoyadCtrl.text.trim()}'.trim()),
          _sozlesmeBilgiSatir('Adres', _adresCtrl.text.trim()),
          if (_hesaplananFiyat.isNotEmpty)
            _sozlesmeBilgiSatir('Aylık Aidat', _hesaplananFiyat,
                renk: Colors.green, kalin: true),
          const Divider(height: 20),

          // Şablon maddeleri
          if (_sablonMaddeleri.isEmpty && _ozelMaddeler.isEmpty)
            const Text(
                'Bu proje için sözleşme şablonu atanmamış. '
                    'Projeler → Sözleşme sekmesinden şablon seçin.',
                style: TextStyle(color: Colors.orange, fontSize: 12))
          else ...[
            ..._sablonMaddeleri.asMap().entries.map((e) =>
                _sozlesmeMaddesi(e.key + 1, e.value['baslik'] ?? '',
                    e.value['icerik'] ?? '')),
            ..._ozelMaddeler.asMap().entries.map((e) =>
                _sozlesmeMaddesi(_sablonMaddeleri.length + e.key + 1,
                    e.value['baslik'] ?? '', e.value['icerik'] ?? '')),
          ],
        ]),
      ),
      const SizedBox(height: 16),

      // Onay kutuları
      ...[
        ['_sozlesmeOnay',  'Sözleşmeyi okudum ve kabul ediyorum.'],
        ['_ucretOnay',     'Aylık aidatı ve ödeme koşullarını kabul ediyorum.'],
        ['_kvkkOnay',      'KVKK aydınlatma metnini okudum ve kabul ediyorum.'],
        ['_dogruOnay',     'Verdiğim bilgilerin doğru olduğunu beyan ediyorum.'],
        ['_dijitalOnay',   'Dijital imzamın fiziksel imzayla aynı geçerliliğe sahip olduğunu kabul ediyorum.'],
      ].map((item) => _onayKutusu(item[0], item[1])),

      const SizedBox(height: 20),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
            backgroundColor: _navy, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        onPressed: (_sozlesmeOnay && _ucretOnay && _kvkkOnay &&
            _dogruOnay && _dijitalOnay)
            ? () => setState(() => _adim = 3)
            : null,
        icon: const Icon(Icons.draw_outlined),
        label: const Text('İmzala',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      )),
      const SizedBox(height: 40),
    ]),
  );

  Widget _sozlesmeBilgiSatir(String label, String deger,
      {Color? renk, bool kalin = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 90, child: Text('$label:',
              style: const TextStyle(fontSize: 12, color: Colors.grey))),
          Expanded(child: Text(deger, style: TextStyle(
              fontSize: 12, fontWeight: kalin ? FontWeight.bold : FontWeight.w500,
              color: renk))),
        ]),
      );

  Widget _sozlesmeMaddesi(int no, String baslik, String icerik) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('MADDE $no — ${baslik.toUpperCase()}',
          style: const TextStyle(fontWeight: FontWeight.bold,
              fontSize: 11, color: _navy)),
      const SizedBox(height: 3),
      Text(icerik, style: const TextStyle(fontSize: 12, height: 1.5)),
    ]),
  );

  Widget _onayKutusu(String field, String metin) {
    bool deger = false;
    switch (field) {
      case '_sozlesmeOnay': deger = _sozlesmeOnay; break;
      case '_ucretOnay':    deger = _ucretOnay;    break;
      case '_kvkkOnay':     deger = _kvkkOnay;     break;
      case '_dogruOnay':    deger = _dogruOnay;    break;
      case '_dijitalOnay':  deger = _dijitalOnay;  break;
    }
    return GestureDetector(
      onTap: () => setState(() {
        switch (field) {
          case '_sozlesmeOnay': _sozlesmeOnay = !_sozlesmeOnay; break;
          case '_ucretOnay':    _ucretOnay    = !_ucretOnay;    break;
          case '_kvkkOnay':     _kvkkOnay     = !_kvkkOnay;     break;
          case '_dogruOnay':    _dogruOnay    = !_dogruOnay;    break;
          case '_dijitalOnay':  _dijitalOnay  = !_dijitalOnay;  break;
        }
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: deger ? Colors.green.shade50 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: deger ? Colors.green.shade300 : Colors.grey.shade300)),
        child: Row(children: [
          Icon(deger ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
              color: deger ? Colors.green : Colors.grey, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(metin,
              style: TextStyle(fontSize: 12,
                  color: deger ? Colors.green.shade800 : Colors.grey[700]))),
        ]),
      ),
    );
  }

  // ── ADIM 3: İmza ─────────────────────────────────────────────
  Widget _adim3Imza() => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: _navy.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.person_outlined, color: _navy, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${_veliAdCtrl.text.trim()} ${_veliSoyadCtrl.text.trim()}'.trim(),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: _navy)),
                Text('Öğrenci: ${_ogrAdCtrl.text.trim()}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ])),
        ]),
      ),
      const SizedBox(height: 20),

      // İmza durumu
      GestureDetector(
        onTap: () async {
          final imza = await Navigator.push<Map<String, dynamic>>(
            context,
            MaterialPageRoute(builder: (_) => DijitalImzaScreen(
              sozlesmeId: '',
              veliAd: '${_veliAdCtrl.text.trim()} ${_veliSoyadCtrl.text.trim()}'.trim(),
              onImzaTamamlandi: (v) {},
            )),
          );
          if (imza != null && mounted) {
            setState(() { _imzaVeri = imza; _imzaTamamlandi = true; });
          }
        },
        child: Container(
          width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: _imzaTamamlandi ? Colors.green.shade50 : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: _imzaTamamlandi ? Colors.green : Colors.grey.shade300,
                  width: _imzaTamamlandi ? 2 : 1)),
          child: Column(children: [
            Icon(
                _imzaTamamlandi ? Icons.verified_outlined : Icons.draw_outlined,
                color: _imzaTamamlandi ? Colors.green : Colors.grey,
                size: 48),
            const SizedBox(height: 12),
            Text(
                _imzaTamamlandi ? 'İmza Alındı ✓' : 'Dijital İmza Al',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16,
                    color: _imzaTamamlandi ? Colors.green : Colors.grey[700])),
            Text(
                _imzaTamamlandi
                    ? 'Parmak izi veya yazılı imza kaydedildi'
                    : 'Tıklayarak imza ekranını açın',
                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ]),
        ),
      ),
      const Spacer(),

      SizedBox(width: double.infinity, child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
            backgroundColor: _imzaTamamlandi ? Colors.green : Colors.grey,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        onPressed: _imzaTamamlandi && !_yukleniyor ? _kaydet : null,
        icon: _yukleniyor
            ? const SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.save_rounded),
        label: Text(_yukleniyor ? 'Kaydediliyor...' : 'Kaydı Tamamla',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      )),
    ]),
  );

  // ── ADIM 4: Tamamlandı ───────────────────────────────────────
  Widget _adim4Tamamlandi() => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 80, height: 80,
          decoration: BoxDecoration(
              color: Colors.green.shade100, shape: BoxShape.circle),
          child: const Icon(Icons.check_circle_outline,
              color: Colors.green, size: 50)),
      const SizedBox(height: 24),
      const Text('Kayıt Tamamlandı!',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
              color: Color(0xFF1a3a6b))),
      const SizedBox(height: 12),
      Text(
          '$_kayitliOgrAd sisteme eklendi.\n'
              '$_kayitliVeliAd velisi olarak kaydedildi.\n'
              'Kullanıcı adı: ${_babaTelCtrl.text.trim()}',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600], height: 1.6)),
      const SizedBox(height: 32),

      SizedBox(width: double.infinity, child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
            backgroundColor: _navy, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        onPressed: _pdfYazdir,
        icon: const Icon(Icons.picture_as_pdf_outlined),
        label: const Text('PDF Kayıt Belgesi Yazdır',
            style: TextStyle(fontWeight: FontWeight.bold)),
      )),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
            foregroundColor: _navy, side: const BorderSide(color: Color(0xFF1a3a6b)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        onPressed: () {
          // Formu sıfırla yeni kayıt için
          _veliAdCtrl.clear(); _veliSoyadCtrl.clear(); _veliTcCtrl.clear();
          _babaTelCtrl.clear(); _anneTelCtrl.clear();
          _ogrAdCtrl.clear(); _ogrTcCtrl.clear(); _ogrSinifCtrl.clear();
          _ogrOkulNoCtrl.clear(); _okulAdiCtrl.clear(); _ogrTelCtrl.clear();
          _adresCtrl.clear(); _notCtrl.clear();
          setState(() {
            _adim = 1;
            _sozlesmeOnay = false; _ucretOnay = false; _kvkkOnay = false;
            _dogruOnay = false; _dijitalOnay = false;
            _imzaTamamlandi = false; _imzaVeri = null;
            _hesaplananFiyat = '';
          });
        },
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Yeni Kayıt',
            style: TextStyle(fontWeight: FontWeight.bold)),
      )),
      const SizedBox(height: 12),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Geri Dön'),
      ),
    ]),
  ));

  // ── PDF Yazdır ───────────────────────────────────────────────
  Future<void> _pdfYazdir() async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity, padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('1a3a6b'),
                borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(_firmaAdi.isNotEmpty ? _firmaAdi : 'Servisim360',
                  style: pw.TextStyle(color: PdfColors.white,
                      fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Text('Hizmet Sozlesmesi — $_seciliProjeAdi',
                  style: pw.TextStyle(color: PdfColors.grey300, fontSize: 11)),
            ]),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Kayit Tarihi: ${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year}',
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          pw.Divider(),
          pw.SizedBox(height: 8),
          _pdfBaslik('OGRENCI BILGILERI'),
          _pdfSatir('Ad Soyad',  _ogrAdCtrl.text.trim()),
          _pdfSatir('TC',        _ogrTcCtrl.text.trim()),
          _pdfSatir('Okul',      _okulAdiCtrl.text.trim()),
          _pdfSatir('Sinif',     _ogrSinifCtrl.text.trim()),
          pw.SizedBox(height: 8),
          _pdfBaslik('VELI BILGILERI'),
          _pdfSatir('Ad Soyad',   '${_veliAdCtrl.text.trim()} ${_veliSoyadCtrl.text.trim()}'.trim()),
          _pdfSatir('TC',         _veliTcCtrl.text.trim()),
          _pdfSatir('Baba Tel',   _babaTelCtrl.text.trim()),
          _pdfSatir('Anne Tel',   _anneTelCtrl.text.trim()),
          _pdfSatir('Adres',      _adresCtrl.text.trim()),
          if (_hesaplananFiyat.isNotEmpty)
            _pdfSatir('Aylik Aidat', _hesaplananFiyat),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('E8F5E9'),
                borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Text('DURUM: IMZALANDI — Yuz yuze kayit',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('2E7D32'))),
          ),
          pw.Spacer(),
          pw.Text('Bu belge Servisim360 tarafindan olusturulmustur.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        ],
      ),
    ));
    await Printing.layoutPdf(onLayout: (fmt) async => pdf.save());
  }

  pw.Widget _pdfBaslik(String m) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6, top: 4),
      child: pw.Text(m, style: pw.TextStyle(fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromHex('1a3a6b'))));

  pw.Widget _pdfSatir(String b, String d) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(children: [
      pw.SizedBox(width: 90, child: pw.Text('$b:',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))),
      pw.Expanded(child: pw.Text(d,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
    ]),
  );

  // ── Yardımcı widget'lar ───────────────────────────────────────
  Widget _bolum(String baslik, IconData ikon) => Row(children: [
    Container(width: 4, height: 20,
        decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Icon(ikon, color: _navy, size: 18),
    const SizedBox(width: 6),
    Text(baslik, style: const TextStyle(fontWeight: FontWeight.w800,
        fontSize: 14, color: _navy)),
  ]);

  Widget _inp(TextEditingController ctrl, String label, IconData ikon,
      {TextInputType tip = TextInputType.text, int satir = 1}) =>
      TextField(
        controller: ctrl, keyboardType: tip, maxLines: satir,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(ikon, color: _navy, size: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      );
}
