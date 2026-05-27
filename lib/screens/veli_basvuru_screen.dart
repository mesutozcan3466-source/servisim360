import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// geocoding paketi kullanilmiyor - fiyat Firestore'dan cekilir
import 'fiyat_yonetim_screen.dart';

// ════════════════════════════════════════════════════════════════
//  VELİ BASVURU FORMU
//  Veli kayit linkini acar:
//  1. Bilgilendirme + sozlesme
//  2. Adres girer, fiyat otomatik hesaplanir
//  3. Formu doldurur, gonderir
//  4. Admin panelinde bekleyene duser
// ════════════════════════════════════════════════════════════════
class VeliBasvuruFormScreen extends StatefulWidget {
  final String? linkId;
  final String? linkKod;
  const VeliBasvuruFormScreen({super.key, this.linkId, this.linkKod});
  @override
  State<VeliBasvuruFormScreen> createState() => _VeliBasvuruFormScreenState();
}

class _VeliBasvuruFormScreenState extends State<VeliBasvuruFormScreen> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  // Adimlar: 0=bilgilendirme, 1=adres+fiyat, 2=form, 3=basarili
  int _adim = 0;

  // Link ve firma bilgileri
  String _firmaId   = '';
  String _firmaAdi  = '';
  String _projeId   = '';
  Map<String, dynamic> _sozlesme = {};
  Map<String, dynamic> _fiyatlar = {};
  bool _yukleniyor  = true;
  bool _onaylandi   = false;

  // Adres ve fiyat
  final _adresCtrl  = TextEditingController();
  double? _hesaplananUcret;
  String  _fiyatBilgi = '';
  bool _adresYukleniyor = false;

  // Form alanlari
  final _ogrenciAdCtrl = TextEditingController();
  final _sinifCtrl     = TextEditingController();
  final _okulCtrl      = TextEditingController();
  final _veliAdCtrl    = TextEditingController();
  final _veliTelCtrl   = TextEditingController();
  final _notCtrl       = TextEditingController();
  String _servisTip    = 'sabah_aksam'; // sabah / aksam / sabah_aksam
  bool _gonderiyor     = false;

  // PDF kayit belgesi icin
  String  _pdfOgrenciAd = '';
  String  _pdfVeliAd    = '';
  String  _pdfTel       = '';
  String  _pdfAdres     = '';
  String  _pdfSinif     = '';
  String  _pdfFirmaAd   = '';
  String  _pdfTarih     = '';
  double? _pdfUcret;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    for (final c in [_adresCtrl, _ogrenciAdCtrl, _sinifCtrl, _okulCtrl,
      _veliAdCtrl, _veliTelCtrl, _notCtrl]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _yukle() async {
    try {
      // Link bilgisini cek
      if (widget.linkId != null && widget.linkId!.isNotEmpty) {
        final linkDoc = await FirebaseFirestore.instance
            .collection('kayit_linkleri').doc(widget.linkId).get();
        if (linkDoc.exists) {
          final ld = linkDoc.data()!;
          _firmaId  = ld['firmaId'] ?? '';
          _projeId  = ld['projeId'] ?? '';
          _firmaAdi = ld['projeAdi'] ?? '';
        }
      }

      if (_firmaId.isEmpty) {
        // Test modu - firmaid yoksa
        setState(() => _yukleniyor = false);
        return;
      }

      // Firma bilgilerini cek
      final firmaDoc = await FirebaseFirestore.instance.collection('firms').doc(_firmaId).get();
      if (firmaDoc.exists) {
        _firmaAdi = firmaDoc.data()?['firmaAdi'] ?? _firmaAdi;
      }

      // Sozlesme metnini cek
      final sozDoc = await FirebaseFirestore.instance
          .collection('firms').doc(_firmaId).collection('ayarlar').doc('sozlesme').get();
      if (sozDoc.exists) _sozlesme = sozDoc.data()!;

      // Fiyat sistemi _fiyatHesapla() icinde direk Firestore'dan cekilir

      if (mounted) setState(() => _yukleniyor = false);
    } catch (e) {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  // Adrese gore ucret hesapla
  // fiyatlar koleksiyonu yapisi:
  //   tip:'mahalle' -> mahalle, fiyat
  //   tip:'km'      -> kmBaslangic, kmBitis, fiyat
  Future<void> _fiyatHesapla() async {
    final adres = _adresCtrl.text.trim();
    if (adres.isEmpty) return;
    if (_firmaId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Firma bilgisi alinamadi'), backgroundColor: Colors.orange));
      return;
    }
    setState(() => _adresYukleniyor = true);

    try {
      double? ucret;
      String bilgi = '';

      // 1. Ilce+Mahalle bazli fiyata bak (yeni yapi)
      final mahalleSnap = await FirebaseFirestore.instance
          .collection('fiyatlar')
          .where('firmaId', isEqualTo: _firmaId)
          .where('tip', isEqualTo: 'mahalle')
          .get();

      if (mahalleSnap.docs.isNotEmpty) {
        final adresLower = adres.toLowerCase();
        // Once ilce+mahalle eslesimi dene
        for (final doc in mahalleSnap.docs) {
          final d      = doc.data();
          final ilce   = (d['ilce']    ?? '').toString().toLowerCase();
          final mahalle= (d['mahalle'] ?? '').toString().toLowerCase();
          // Hem ilce hem mahalle adreste geciyorsa tam eslesmesi
          if (ilce.isNotEmpty && mahalle.isNotEmpty &&
              adresLower.contains(ilce) &&
              adresLower.contains(mahalle)) {
            ucret = (d['fiyat'] as num?)?.toDouble();
            bilgi = '${d['ilce']} / ${d['mahalle']}';
            break;
          }
        }
        // Tam eslesmedi, sadece mahalle ile dene
        if (ucret == null) {
          for (final doc in mahalleSnap.docs) {
            final d       = doc.data();
            final mahalle = (d['mahalle'] ?? '').toString().toLowerCase();
            if (mahalle.isNotEmpty && adresLower.contains(mahalle)) {
              ucret = (d['fiyat'] as num?)?.toDouble();
              bilgi = '${d['ilce'] ?? ''} / ${d['mahalle']} bolgesi';
              break;
            }
          }
        }
      }

      // 2. Mahalle eslesmedi, km bazli dene (geocoding ile)
      if (ucret == null) {
        final kmSnap = await FirebaseFirestore.instance
            .collection('fiyatlar')
            .where('firmaId', isEqualTo: _firmaId)
            .where('tip', isEqualTo: 'km')
            .orderBy('kmBaslangic')
            .get();

        if (kmSnap.docs.isNotEmpty) {
          // Gecici: adres uzunluguna gore yaklasik km tahmini
          // Gercek uygulamada Google Distance Matrix API kullanilir
          // Simdilik ilk km araligini varsayilan olarak ver
          final ilk = kmSnap.docs.first.data();
          ucret = (ilk['fiyat'] as num?)?.toDouble();
          final kmB = (ilk['kmBaslangic'] ?? 0).toString();
          final kmE = (ilk['kmBitis'] ?? 0).toString();
          bilgi = '$kmB - $kmE km araligi';
        }
      }

      // 3. Hic fiyat tanimlanmamissa proje fiyatina bak
      if (ucret == null && _projeId.isNotEmpty) {
        final projeDoc = await FirebaseFirestore.instance
            .collection('projects').doc(_projeId).get();
        if (projeDoc.exists) {
          ucret = (projeDoc.data()?['aylikUcret'] as num?)?.toDouble();
          if (ucret != null) bilgi = 'Proje standart ucreti';
        }
      }

      setState(() {
        _hesaplananUcret = ucret;
        _fiyatBilgi = bilgi.isNotEmpty ? bilgi : 'Hesaplandi';
        _adresYukleniyor = false;
      });
    } catch (e) {
      setState(() => _adresYukleniyor = false);
    }
  }

  Future<void> _basvuruGonder() async {
    if (_ogrenciAdCtrl.text.trim().isEmpty || _veliTelCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ogrenci adi ve telefon zorunlu!'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _gonderiyor = true);
    try {
      await FirebaseFirestore.instance.collection('parents').add({
        'firmaId':     _firmaId,
        'projeId':     _projeId,
        'linkId':      widget.linkId ?? '',
        'durum':       'beklemede',
        // Ogrenci bilgileri
        'ogrenciAd':   _ogrenciAdCtrl.text.trim(),
        'sinif':       _sinifCtrl.text.trim(),
        'okul':        _okulCtrl.text.trim(),
        'adres':       _adresCtrl.text.trim(),
        'servisTip':   _servisTip,
        // Veli bilgileri
        'veliAd':      _veliAdCtrl.text.trim(),
        'ad':          _veliAdCtrl.text.trim(),
        'telefon':     _veliTelCtrl.text.trim(),
        'not':         _notCtrl.text.trim(),
        // Fiyat
        'hesaplananUcret': _hesaplananUcret,
        'fiyatBilgi':  _fiyatBilgi,
        // Sistem
        'basvuruTipi': 'uzaktan_link',
        'basvuruTarihi': FieldValue.serverTimestamp(),
        'sozlesmeOnaylandi': _onaylandi,
      });

      // Students koleksiyonuna da ekle (beklemede olarak)
      await FirebaseFirestore.instance.collection('students').add({
        'firmaId':   _firmaId,
        'projeId':   _projeId,
        'ad':        _ogrenciAdCtrl.text.trim(),
        'sinif':     _sinifCtrl.text.trim(),
        'okul':      _okulCtrl.text.trim(),
        'adres':     _adresCtrl.text.trim(),
        'veliAd':    _veliAdCtrl.text.trim(),
        'veliTel':   _veliTelCtrl.text.trim(),
        'servisTip': _servisTip,
        'durum':     'beklemede',
        'aktif':     false,
        'bindi':     false,
        'kayitTipi': 'uzaktan',
        'olusturma': FieldValue.serverTimestamp(),
      });

      // PDF için bilgileri sakla
      final now = DateTime.now();
      _pdfOgrenciAd = _ogrenciAdCtrl.text.trim();
      _pdfVeliAd    = _veliAdCtrl.text.trim();
      _pdfTel       = _veliTelCtrl.text.trim();
      _pdfAdres     = _adresCtrl.text.trim();
      _pdfSinif     = _sinifCtrl.text.trim();
      _pdfFirmaAd   = _firmaAdi;
      _pdfUcret     = _hesaplananUcret;
      _pdfTarih     = '${now.day.toString().padLeft(2,'0')}.${now.month.toString().padLeft(2,'0')}.${now.year}';
      if (mounted) setState(() => _adim = 3);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _gonderiyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: _navy)));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white, elevation: 0,
        title: Text(_firmaAdi.isNotEmpty ? _firmaAdi : 'Servis Kayit',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
              value: (_adim + 1) / 4,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(_turuncu)),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _adim == 0 ? _bilgilendirmeAdimi()
            : _adim == 1 ? _adresFiyatAdimi()
            : _adim == 2 ? _formAdimi()
            : _basariAdimi(),
      ),
    );
  }

  // ── Adim 0: Bilgilendirme ─────────────────────────────────────
  Widget _bilgilendirmeAdimi() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Baslik
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_navy, Color(0xFF2a5298)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_firmaAdi.isNotEmpty ? _firmaAdi : 'Servis Kayit',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Servis Kayit Formu', style: TextStyle(color: Colors.white70, fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 16),

        // Firma aciklamasi
        if ((_sozlesme['aciklama'] ?? '').isNotEmpty) ...[
          _InfoKart(_sozlesme['aciklama'], Icons.info_outline, Colors.blue),
          const SizedBox(height: 12),
        ],

        // Ucret bilgisi
        if ((_sozlesme['ucretBilgi'] ?? '').isNotEmpty) ...[
          _BilgiBaslik('Ucret Bilgisi', Icons.attach_money_outlined),
          _InfoKart(_sozlesme['ucretBilgi'], Icons.payments_outlined, Colors.green),
          const SizedBox(height: 12),
        ],

        // Odeme sartlari
        if ((_sozlesme['odeme'] ?? '').isNotEmpty) ...[
          _BilgiBaslik('Odeme Sartlari', Icons.payment_outlined),
          _InfoKart(_sozlesme['odeme'], Icons.payment_outlined, Colors.orange),
          const SizedBox(height: 12),
        ],

        // Iptal sartlari
        if ((_sozlesme['iptal'] ?? '').isNotEmpty) ...[
          _BilgiBaslik('Iptal Sartlari', Icons.cancel_outlined),
          _InfoKart(_sozlesme['iptal'], Icons.cancel_outlined, Colors.red),
          const SizedBox(height: 12),
        ],

        // Servis kurallari
        if ((_sozlesme['kurallar'] ?? '').isNotEmpty) ...[
          _BilgiBaslik('Servis Kurallari', Icons.rule_outlined),
          _InfoKart(_sozlesme['kurallar'], Icons.rule_outlined, _navy),
          const SizedBox(height: 16),
        ],

        // Sozlesme metni
        if ((_sozlesme['sozlesme'] ?? '').isNotEmpty) ...[
          _BilgiBaslik('Sozlesme', Icons.description_outlined),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3))),
            child: Text(_sozlesme['sozlesme'] ?? '',
                style: const TextStyle(fontSize: 12, height: 1.6)),
          ),
          const SizedBox(height: 16),
        ],

        // KVKK
        if ((_sozlesme['kvkk'] ?? '').isNotEmpty)
          Text(_sozlesme['kvkk'] ?? '',
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        const SizedBox(height: 16),

        // Onay kutusu
        GestureDetector(
          onTap: () => setState(() => _onaylandi = !_onaylandi),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: _onaylandi ? Colors.green.withValues(alpha: 0.05) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _onaylandi ? Colors.green : Colors.grey.withValues(alpha: 0.3))),
            child: Row(children: [
              Icon(_onaylandi ? Icons.check_box : Icons.check_box_outline_blank,
                  color: _onaylandi ? Colors.green : Colors.grey, size: 24),
              const SizedBox(width: 12),
              Expanded(child: Text(
                  _sozlesme['onayKutu'] ?? 'Yukardaki sartlari okudum ve kabul ediyorum.',
                  style: TextStyle(fontSize: 13,
                      color: _onaylandi ? Colors.green : Colors.black87,
                      fontWeight: _onaylandi ? FontWeight.w600 : FontWeight.normal))),
            ]),
          ),
        ),
        const SizedBox(height: 20),

        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: _onaylandi ? _turuncu : Colors.grey,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: _onaylandi ? () => setState(() => _adim = 1) : null,
          icon: const Icon(Icons.arrow_forward),
          label: const Text('Devam Et', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        )),
        const SizedBox(height: 40),
      ]),
    );
  }

  // ── Adim 1: Adres + Fiyat ─────────────────────────────────────
  Widget _adresFiyatAdimi() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _AdimBaslik('Adres Bilgisi', '2/3', Icons.location_on_outlined),
        const SizedBox(height: 16),

        const Text('Ev Adresiniz', style: TextStyle(fontWeight: FontWeight.bold, color: _navy, fontSize: 13)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(
            controller: _adresCtrl,
            maxLines: 2,
            decoration: InputDecoration(
                hintText: 'Mahalle, cadde, sokak, bina no...',
                prefixIcon: const Icon(Icons.home_outlined, color: _navy),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _navy, width: 2)),
                contentPadding: const EdgeInsets.all(14),
                filled: true, fillColor: Colors.white),
          )),
        ]),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          onPressed: _adresYukleniyor ? null : _fiyatHesapla,
          icon: _adresYukleniyor
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.calculate_outlined),
          label: Text(_adresYukleniyor ? 'Hesaplaniyor...' : 'Ucreti Hesapla'),
          style: OutlinedButton.styleFrom(
              foregroundColor: _navy, side: const BorderSide(color: _navy),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        )),

        // Fiyat sonucu
        if (_hesaplananUcret != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.green.shade600, Colors.green.shade400]),
                borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 28),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Tahmini Aylik Ucret', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text('${_hesaplananUcret!.toStringAsFixed(0)} TL',
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                if (_fiyatBilgi.isNotEmpty)
                  Text(_fiyatBilgi, style: const TextStyle(color: Colors.white70, fontSize: 11)),
              ])),
            ]),
          ),
        ],

        const SizedBox(height: 20),

        // Servis tipi
        const Text('Servis Tipi', style: TextStyle(fontWeight: FontWeight.bold, color: _navy, fontSize: 13)),
        const SizedBox(height: 8),
        Row(children: [
          _ServisTipBtn('sabah',       'Sadece Sabah',  Icons.wb_sunny_outlined,  _servisTip, (v) => setState(() => _servisTip = v)),
          const SizedBox(width: 8),
          _ServisTipBtn('aksam',       'Sadece Aksam',  Icons.nights_stay_outlined,_servisTip, (v) => setState(() => _servisTip = v)),
          const SizedBox(width: 8),
          _ServisTipBtn('sabah_aksam', 'Sabah+Aksam',   Icons.swap_horiz_outlined,  _servisTip, (v) => setState(() => _servisTip = v)),
        ]),

        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: () => setState(() => _adim = 0),
            style: OutlinedButton.styleFrom(foregroundColor: _navy, side: const BorderSide(color: _navy),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Geri'),
          )),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: ElevatedButton.icon(
            onPressed: _adresCtrl.text.isNotEmpty ? () => setState(() => _adim = 2) : null,
            style: ElevatedButton.styleFrom(
                backgroundColor: _turuncu, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Forma Gec', style: TextStyle(fontWeight: FontWeight.bold)),
          )),
        ]),
        const SizedBox(height: 40),
      ]),
    );
  }

  // ── Adim 2: Form ──────────────────────────────────────────────
  Widget _formAdimi() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _AdimBaslik('Kayit Formu', '3/3', Icons.edit_outlined),
        const SizedBox(height: 16),

        _FormBaslik('Ogrenci Bilgileri', Icons.school_outlined),
        _FormAlan(ctrl: _ogrenciAdCtrl, label: 'Ogrenci Adi Soyadi *', ikon: Icons.person_outline),
        _FormAlan(ctrl: _sinifCtrl,     label: 'Sinif',                 ikon: Icons.class_outlined),
        _FormAlan(ctrl: _okulCtrl,      label: 'Okul Adi',              ikon: Icons.account_balance_outlined),

        const SizedBox(height: 8),
        _FormBaslik('Veli Bilgileri', Icons.family_restroom_outlined),
        _FormAlan(ctrl: _veliAdCtrl,  label: 'Veli Adi Soyadi',         ikon: Icons.person_outlined),
        _FormAlan(ctrl: _veliTelCtrl, label: 'Telefon * (WhatsApp)',     ikon: Icons.phone_outlined, tipi: TextInputType.phone),

        const SizedBox(height: 8),
        _FormBaslik('Ek Bilgi', Icons.notes_outlined),
        _FormAlan(ctrl: _notCtrl, label: 'Not (opsiyonel)',             ikon: Icons.notes_outlined, satir: 2),

        // Ozet
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: _navy.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _navy.withValues(alpha: 0.15))),
          child: Column(children: [
            _OzetSatir('Adres', _adresCtrl.text),
            _OzetSatir('Servis', _servisTip == 'sabah' ? 'Sadece Sabah' : _servisTip == 'aksam' ? 'Sadece Aksam' : 'Sabah + Aksam'),
            if (_hesaplananUcret != null)
              _OzetSatir('Ucret', '${_hesaplananUcret!.toStringAsFixed(0)} TL/ay'),
          ]),
        ),

        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: () => setState(() => _adim = 1),
            style: OutlinedButton.styleFrom(foregroundColor: _navy, side: const BorderSide(color: _navy),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Geri'),
          )),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: ElevatedButton.icon(
            onPressed: _gonderiyor ? null : _basvuruGonder,
            style: ElevatedButton.styleFrom(
                backgroundColor: _turuncu, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            icon: _gonderiyor
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.send_rounded),
            label: Text(_gonderiyor ? 'Gonderiliyor...' : 'Basvuru Gonder',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          )),
        ]),
        const SizedBox(height: 40),
      ]),
    );
  }

  // ── Adim 3: Basari ────────────────────────────────────────────

  Future<void> _pdfKayitBelgesi() async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('1a3a6b'),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Servisim360',
                    style: pw.TextStyle(color: PdfColors.white,
                        fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.Text('Servis Kayit Belgesi',
                    style: pw.TextStyle(color: PdfColors.grey300, fontSize: 13)),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Text(_pdfFirmaAd,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.Text('Kayit Tarihi: $_pdfTarih',
              style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          pw.SizedBox(height: 20),
          pw.Divider(),
          pw.SizedBox(height: 12),
          pw.Text('OGRENCI BILGILERI',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('1a3a6b'))),
          pw.SizedBox(height: 8),
          _pdfSatir('Ogrenci Adi', _pdfOgrenciAd),
          if (_pdfSinif.isNotEmpty) _pdfSatir('Sinif', _pdfSinif),
          pw.SizedBox(height: 16),
          pw.Text('VELI BILGILERI',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('1a3a6b'))),
          pw.SizedBox(height: 8),
          _pdfSatir('Veli Adi',  _pdfVeliAd),
          _pdfSatir('Telefon',   _pdfTel),
          _pdfSatir('Adres',     _pdfAdres),
          if (_pdfUcret != null)
            _pdfSatir('Ucret', '${_pdfUcret!.toStringAsFixed(0)} TL / ay'),
          pw.SizedBox(height: 20),
          pw.Divider(),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('FFF3E0'),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text('Durum: ONAY BEKLENIYOR',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('E65100'))),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Bu belge Servisim360 tarafindan olusturulmustur.',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
        ],
      ),
    ));
    await Printing.layoutPdf(onLayout: (fmt) async => pdf.save());
  }

  pw.Widget _pdfSatir(String baslik, String deger) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 5),
    child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.SizedBox(width: 110,
          child: pw.Text('$baslik:',
              style: pw.TextStyle(color: PdfColors.grey700))),
      pw.Expanded(child: pw.Text(deger,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
    ]),
  );

  Widget _basariAdimi() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 90, height: 90,
          decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle),
          child: const Icon(Icons.check_circle_outline, color: Colors.green, size: 52),
        ),
        const SizedBox(height: 24),
        const Text('Basvurunuz Alindi!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _navy)),
        const SizedBox(height: 12),
        Text(
            'Basvurunuz $_firmaAdi tarafindan incelenecektir. Onaylandiginda size bildirilecektir.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.5)),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.2))),
          child: const Row(children: [
            Icon(Icons.access_time, color: Colors.orange, size: 20),
            SizedBox(width: 10),
            Expanded(child: Text('Basvurunuz onaylandiginda WhatsApp ile bilgilendirileceksiniz.',
                style: TextStyle(fontSize: 12, color: Colors.orange))),
          ]),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1a3a6b),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _pdfKayitBelgesi,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Kayit Belgesini Indir (PDF)',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    ));
  }
}

// ── Yardimci Widget'lar ──────────────────────────────────────────
class _InfoKart extends StatelessWidget {
  final String metin; final IconData ikon; final Color renk;
  const _InfoKart(this.metin, this.ikon, this.renk);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: renk.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: renk.withValues(alpha: 0.2))),
      child: Text(metin, style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.5)));
}

class _BilgiBaslik extends StatelessWidget {
  final String baslik; final IconData ikon;
  static const _navy = Color(0xFF1a3a6b);
  const _BilgiBaslik(this.baslik, this.ikon);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Icon(ikon, color: _navy, size: 14), const SizedBox(width: 6),
      Text(baslik, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _navy)),
    ]),
  );
}

class _AdimBaslik extends StatelessWidget {
  final String baslik, adim; final IconData ikon;
  static const _navy = Color(0xFF1a3a6b);
  const _AdimBaslik(this.baslik, this.adim, this.ikon);
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: _navy.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(ikon, color: _navy, size: 20)),
    const SizedBox(width: 12),
    Expanded(child: Text(baslik, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _navy))),
    Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: _navy.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
        child: Text(adim, style: const TextStyle(color: _navy, fontSize: 11, fontWeight: FontWeight.bold))),
  ]);
}

class _FormBaslik extends StatelessWidget {
  final String baslik; final IconData ikon;
  static const _navy = Color(0xFF1a3a6b);
  const _FormBaslik(this.baslik, this.ikon);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Icon(ikon, color: _navy, size: 15), const SizedBox(width: 8),
      Text(baslik, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _navy)),
    ]),
  );
}

class _FormAlan extends StatelessWidget {
  final TextEditingController ctrl;
  final String label; final IconData ikon;
  final TextInputType tipi; final int satir;
  static const _navy = Color(0xFF1a3a6b);
  const _FormAlan({required this.ctrl, required this.label, required this.ikon,
    this.tipi = TextInputType.text, this.satir = 1});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: ctrl, keyboardType: tipi, maxLines: satir,
      decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(ikon, color: _navy, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _navy, width: 2)),
          contentPadding: const EdgeInsets.all(14),
          filled: true, fillColor: Colors.white),
    ),
  );
}

class _OzetSatir extends StatelessWidget {
  final String etiket, deger;
  const _OzetSatir(this.etiket, this.deger);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      SizedBox(width: 60, child: Text(etiket, style: TextStyle(color: Colors.grey[500], fontSize: 11))),
      Expanded(child: Text(deger, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12), overflow: TextOverflow.ellipsis)),
    ]),
  );
}

class _ServisTipBtn extends StatelessWidget {
  final String deger, etiket, secili; final IconData ikon;
  final ValueChanged<String> onSec;
  static const _navy = Color(0xFF1a3a6b);
  const _ServisTipBtn(this.deger, this.etiket, this.ikon, this.secili, this.onSec);
  @override
  Widget build(BuildContext context) {
    final aktif = secili == deger;
    return Expanded(child: GestureDetector(
      onTap: () => onSec(deger),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
            color: aktif ? _navy : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: aktif ? _navy : Colors.grey.withValues(alpha: 0.3))),
        child: Column(children: [
          Icon(ikon, color: aktif ? Colors.white : Colors.grey, size: 18),
          const SizedBox(height: 3),
          Text(etiket, style: TextStyle(fontSize: 9, color: aktif ? Colors.white : Colors.grey,
              fontWeight: aktif ? FontWeight.bold : FontWeight.normal), textAlign: TextAlign.center),
        ]),
      ),
    ));
  }
}

// VeliOnayScreen - admin onay/red ekrani (mevcut kod ile uyumlu)
class VeliOnayScreen extends StatelessWidget {
  const VeliOnayScreen({super.key});
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
          backgroundColor: _navy, foregroundColor: Colors.white,
          title: const Text('Basvuru Onay', style: TextStyle(fontWeight: FontWeight.bold))),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('parents')
            .where('durum', isEqualTo: 'beklemede')
            .orderBy('basvuruTarihi', descending: true).snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return const Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                SizedBox(height: 12),
                Text('Bekleyen basvuru yok', style: TextStyle(color: Colors.grey)),
              ]));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d  = docs[i].data() as Map<String, dynamic>;
              final id = docs[i].id;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _turuncu.withValues(alpha: 0.3)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    CircleAvatar(radius: 20, backgroundColor: _turuncu.withValues(alpha: 0.1),
                        child: Text((d['ogrenciAd'] ?? '?')[0].toUpperCase(),
                            style: const TextStyle(color: _turuncu, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d['ogrenciAd'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('Veli: ${d['veliAd'] ?? d['ad'] ?? '-'}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ])),
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Text('Bekliyor', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold))),
                  ]),
                  const SizedBox(height: 10),
                  if ((d['adres'] ?? '').isNotEmpty) _DetaySatir(Icons.location_on_outlined, d['adres']),
                  if ((d['okul'] ?? '').isNotEmpty)  _DetaySatir(Icons.school_outlined, d['okul']),
                  if ((d['telefon'] ?? '').isNotEmpty) _DetaySatir(Icons.phone_outlined, d['telefon']),
                  if (d['hesaplananUcret'] != null)
                    _DetaySatir(Icons.attach_money, '${d['hesaplananUcret']} TL/ay'),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(
                      onPressed: () => FirebaseFirestore.instance.collection('parents').doc(id).update({'durum': 'reddedildi'}),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Reddet'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: ElevatedButton.icon(
                      onPressed: () async {
                        await FirebaseFirestore.instance.collection('parents').doc(id).update({'durum': 'onayli'});
                        // Ogrenciyi de aktif yap
                        final ogrSnap = await FirebaseFirestore.instance.collection('students')
                            .where('veliTel', isEqualTo: d['telefon'])
                            .where('firmaId', isEqualTo: d['firmaId']).limit(1).get();
                        if (ogrSnap.docs.isNotEmpty) {
                          await ogrSnap.docs.first.reference.update({'durum': 'onayli', 'aktif': true});
                        }
                      },
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Onayla'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    )),
                  ]),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

class _DetaySatir extends StatelessWidget {
  final IconData ikon; final String metin;
  const _DetaySatir(this.ikon, this.metin);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      Icon(ikon, size: 13, color: Colors.grey),
      const SizedBox(width: 6),
      Expanded(child: Text(metin, style: TextStyle(fontSize: 12, color: Colors.grey[600]), overflow: TextOverflow.ellipsis)),
    ]),
  );
}
