import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/session_service.dart';

class VeliKayitYuzYuzeScreen extends StatefulWidget {
  const VeliKayitYuzYuzeScreen({super.key});
  @override
  State<VeliKayitYuzYuzeScreen> createState() => _VeliKayitYuzYuzeScreenState();
}

class _VeliKayitYuzYuzeScreenState extends State<VeliKayitYuzYuzeScreen> {
  static const _navy   = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);

  final _adCtrl        = TextEditingController();
  final _soyadCtrl     = TextEditingController();
  final _telCtrl       = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _sifreCtrl     = TextEditingController();
  final _adresCtrl     = TextEditingController();
  final _ogrAdCtrl     = TextEditingController();
  final _ogrOkulCtrl   = TextEditingController();
  final _ogrSinifCtrl  = TextEditingController();
  final _notCtrl       = TextEditingController();

  bool _yukleniyor   = false;
  bool _sozlesmeOnay = false;
  String _sozlesme   = '';
  String _bilgi      = '';
  String _fiyat      = '';
  String _firmaId    = '';
  String _projeId    = '';
  String _projeAdi   = '';

  List<Map<String, dynamic>> _fiyatlar = [];

  @override
  void initState() {
    super.initState();
    _yukle();
    _adresCtrl.addListener(_fiyatHesapla);
  }

  @override
  void dispose() {
    _adCtrl.dispose(); _soyadCtrl.dispose(); _telCtrl.dispose();
    _emailCtrl.dispose(); _sifreCtrl.dispose(); _adresCtrl.dispose();
    _ogrAdCtrl.dispose(); _ogrOkulCtrl.dispose(); _ogrSinifCtrl.dispose();
    _notCtrl.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    _firmaId = await SessionService.instance.firmaIdAl() ?? '';
    _projeId = SessionService.instance.aktifProjeld ?? '';
    _projeAdi= SessionService.instance.aktifProjeAdi ?? '';

    if (_projeId.isNotEmpty) {
      final projeDoc = await FirebaseFirestore.instance.collection('projects').doc(_projeId).get();
      _sozlesme = projeDoc.data()?['sozlesme']      ?? '';
      _bilgi    = projeDoc.data()?['bilgilendirme'] ?? '';

      final fSnap = await FirebaseFirestore.instance.collection('fiyatlar')
          .where('projeId', isEqualTo: _projeId).get();
      _fiyatlar = fSnap.docs.map((d) => d.data()).toList();
    }
    setState(() {});
  }

  void _fiyatHesapla() {
    final adres = _adresCtrl.text.toLowerCase();
    if (adres.length < 4) { setState(() => _fiyat = ''); return; }

    String bulunan = '';
    for (final f in _fiyatlar) {
      final ilce    = (f['ilce']    ?? '').toString().toLowerCase();
      final mahalle = (f['mahalle'] ?? '').toString().toLowerCase();
      if (ilce.isNotEmpty && mahalle.isNotEmpty &&
          adres.contains(ilce) && adres.contains(mahalle)) {
        bulunan = '${f['fiyat']?.toStringAsFixed(0) ?? ''} TL / ay';
        break;
      }
    }
    if (bulunan.isEmpty) {
      for (final f in _fiyatlar) {
        final mahalle = (f['mahalle'] ?? '').toString().toLowerCase();
        if (mahalle.isNotEmpty && adres.contains(mahalle)) {
          bulunan = '${f['fiyat']?.toStringAsFixed(0) ?? ''} TL / ay';
          break;
        }
      }
    }
    setState(() => _fiyat = bulunan);
  }

  Future<void> _kaydet() async {
    if (_adCtrl.text.trim().isEmpty || _telCtrl.text.trim().isEmpty ||
        _ogrAdCtrl.text.trim().isEmpty || _adresCtrl.text.trim().isEmpty) {
      _snack('Ad, telefon, ogrenci adi ve adres zorunlu!', Colors.red);
      return;
    }
    if (_sozlesme.isNotEmpty && !_sozlesmeOnay) {
      _snack('Lutfen sozlesmeyi onaylayin!', Colors.orange);
      return;
    }

    setState(() => _yukleniyor = true);
    try {
      await FirebaseFirestore.instance.collection('parents').add({
        'ad':              _adCtrl.text.trim(),
        'soyad':           _soyadCtrl.text.trim(),
        'telefon':         _telCtrl.text.trim(),
        'email':           _emailCtrl.text.trim(),
        'sifre':           _sifreCtrl.text.trim(),
        'adres':           _adresCtrl.text.trim(),
        'ogrenciAd':       _ogrAdCtrl.text.trim(),
        'ogrenciOkul':     _ogrOkulCtrl.text.trim(),
        'ogrenciSinif':    _ogrSinifCtrl.text.trim(),
        'not':             _notCtrl.text.trim(),
        'fiyat':           _fiyat,
        'sozlesmeOnaylandi': _sozlesmeOnay,
        'firmaId':         _firmaId,
        'projeId':         _projeId,
        'projeAdi':        _projeAdi,
        'durum':           'onayli', // Yüz yüze kayıt direkt onaylı
        'kayitTarihi':     DateTime.now(),
        'kaynak':          'yuz_yuze',
      });
      _snack('Veli kaydedildi!', Colors.green);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack('Hata: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white,
        title: const Text('Yuz Yuze Veli Kayit', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Proje bilgisi
          if (_projeAdi.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _navy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.folder_outlined, color: _navy, size: 18),
                const SizedBox(width: 8),
                Text(_projeAdi, style: const TextStyle(fontWeight: FontWeight.w700, color: _navy)),
              ]),
            ),

          // Bilgilendirme
          if (_bilgi.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.withValues(alpha: 0.2))),
              child: Text(_bilgi, style: const TextStyle(color: Colors.blue, fontSize: 13)),
            ),

          _baslik('Veli Bilgileri', Icons.person_outline),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _input(_adCtrl,    'Ad *',    Icons.person_outline)),
            const SizedBox(width: 10),
            Expanded(child: _input(_soyadCtrl, 'Soyad',   Icons.person_outline)),
          ]),
          const SizedBox(height: 10),
          _input(_telCtrl,   'Telefon *',  Icons.phone_outlined, tipi: TextInputType.phone),
          const SizedBox(height: 10),
          _input(_emailCtrl, 'E-posta',    Icons.email_outlined,  tipi: TextInputType.emailAddress),
          const SizedBox(height: 10),
          _input(_sifreCtrl, 'Sifre',      Icons.lock_outline,    gizle: true),

          const SizedBox(height: 20),
          _baslik('Ogrenci Bilgileri', Icons.school_outlined),
          const SizedBox(height: 10),
          _input(_ogrAdCtrl,   'Ogrenci Adi Soyadi *', Icons.school_outlined),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _input(_ogrOkulCtrl,  'Okul',  Icons.account_balance_outlined)),
            const SizedBox(width: 10),
            Expanded(child: _input(_ogrSinifCtrl, 'Sinif', Icons.class_outlined)),
          ]),

          const SizedBox(height: 20),
          _baslik('Adres & Fiyat', Icons.location_on_outlined),
          const SizedBox(height: 10),
          _input(_adresCtrl, 'Eve Servis Adresi *', Icons.location_on_outlined),
          if (_fiyat.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFFF3E0), Color(0xFFFFF8F0)]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _orange.withValues(alpha: 0.5))),
              child: Row(children: [
                const Icon(Icons.attach_money, color: _orange),
                const SizedBox(width: 8),
                Text(_fiyat, style: const TextStyle(fontWeight: FontWeight.w800, color: _orange, fontSize: 16)),
              ]),
            ),
          ],

          const SizedBox(height: 10),
          _input(_notCtrl, 'Not (opsiyonel)', Icons.notes_outlined, satir: 2),

          // Sozlesme
          if (_sozlesme.isNotEmpty) ...[
            const SizedBox(height: 20),
            _baslik('Hizmet Sozlesmesi', Icons.description_outlined),
            const SizedBox(height: 10),
            Container(
              height: 160,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200)),
              child: SingleChildScrollView(child: Text(_sozlesme, style: const TextStyle(fontSize: 12, height: 1.6))),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => setState(() => _sozlesmeOnay = !_sozlesmeOnay),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: _sozlesmeOnay ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _sozlesmeOnay ? Colors.green : Colors.grey.shade300)),
                child: Row(children: [
                  Icon(_sozlesmeOnay ? Icons.check_box : Icons.check_box_outline_blank,
                      color: _sozlesmeOnay ? Colors.green : Colors.grey),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Sozlesmeyi okudum ve kabul ediyorum',
                      style: TextStyle(fontWeight: FontWeight.w600))),
                ]),
              ),
            ),
          ],

          const SizedBox(height: 24),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _orange, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _yukleniyor ? null : _kaydet,
            icon: _yukleniyor
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            label: Text(_yukleniyor ? 'Kaydediliyor...' : 'Kaydı Tamamla',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          )),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  Widget _baslik(String metin, IconData ikon) => Row(children: [
    Container(width: 4, height: 20, decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Icon(ikon, color: _navy, size: 18),
    const SizedBox(width: 6),
    Text(metin, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _navy)),
  ]);

  Widget _input(TextEditingController ctrl, String label, IconData ikon,
      {TextInputType tipi = TextInputType.text, bool gizle = false, int satir = 1}) =>
      TextField(
        controller: ctrl, keyboardType: tipi,
        obscureText: gizle, maxLines: satir,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(ikon, color: _navy, size: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _navy, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      );
}
