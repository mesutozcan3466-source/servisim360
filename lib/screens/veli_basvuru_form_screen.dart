import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'fiyat_yonetim_screen.dart'; // FiyatSonucu + FiyatHesaplamaServisi

class VeliBasvuruFormScreen extends StatefulWidget {
  final String linkId;
  const VeliBasvuruFormScreen({super.key, required this.linkId});

  @override
  State<VeliBasvuruFormScreen> createState() =>
      _VeliBasvuruFormScreenState();
}

class _VeliBasvuruFormScreenState
    extends State<VeliBasvuruFormScreen> {
  static const Color navy = Color(0xFF1a3a6b);
  static const Color orange = Color(0xFFFF8C00);

  final _formKey = GlobalKey<FormState>();
  final _ogrenciAdiCtrl  = TextEditingController();
  final _veliAdiCtrl     = TextEditingController();
  final _telefonCtrl     = TextEditingController();
  final _babaTelCtrl     = TextEditingController();
  final _anneTelCtrl     = TextEditingController();
  final _ogrenciTcCtrl   = TextEditingController();
  final _sinifCtrl       = TextEditingController();
  final _adresCtrl       = TextEditingController();

  int _adim = 0;
  bool _yukleniyor = false;
  bool _sozlesmeOnay = false;
  bool _sartlarOnay = false;

  LatLng? _konum;
  double? _hesaplananFiyat;
  String? _fiyatBilgisi;
  Map<String, dynamic>? _linkBilgisi;
  String _projeAdi = '';
  String _firmaId = '';
  String _projeId = '';

  @override
  void initState() {
    super.initState();
    _linkBilgisiniYukle();
  }

  Future<void> _linkBilgisiniYukle() async {
    setState(() => _yukleniyor = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('kayit_linkleri')
          .doc(widget.linkId)
          .get();
      if (!doc.exists || !(doc.data()?['aktif'] ?? false)) {
        setState(() => _yukleniyor = false);
        return;
      }
      final data = doc.data()!;
      setState(() {
        _linkBilgisi = data;
        _projeAdi = data['projeAdi'] ?? '';
        _firmaId = data['firmaId'] ?? '';
        _projeId = data['projeId'] ?? '';
        _yukleniyor = false;
      });
      doc.reference
          .update({'kullanilmaSayisi': FieldValue.increment(1)});
    } catch (e) {
      setState(() => _yukleniyor = false);
    }
  }

  Future<void> _konumBul() async {
    setState(() => _yukleniyor = true);
    try {
      bool servisAktif = await Geolocator.isLocationServiceEnabled();
      if (!servisAktif) {
        _snack('Konum servisi kapali', hata: true);
        setState(() => _yukleniyor = false);
        return;
      }
      LocationPermission izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied) {
        izin = await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition();
      final adresler =
      await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (adresler.isNotEmpty) {
        final a = adresler.first;
        _adresCtrl.text =
        '${a.street}, ${a.subLocality}, ${a.locality}';
      }
      setState(() => _konum = LatLng(pos.latitude, pos.longitude));
      await _fiyatHesapla();
    } catch (e) {
      _snack('Konum alinamadi', hata: true);
    } finally {
      setState(() => _yukleniyor = false);
    }
  }

  Future<void> _fiyatHesapla() async {
    if (_konum == null || _firmaId.isEmpty) return;
    try {
      final adresler = await placemarkFromCoordinates(
          _konum!.latitude, _konum!.longitude);
      if (adresler.isEmpty) return;
      final a = adresler.first;
      final ilce = a.subAdministrativeArea ?? '';
      final mahalle = a.subLocality ?? '';

      final sonuc = await FiyatHesaplamaServisi.hesapla(
        firmaId: _firmaId,
        ilce: ilce,
        mahalle: mahalle,
        veliAdresi: _adresCtrl.text.trim(),
      );

      setState(() {
        _hesaplananFiyat = sonuc.bulundu ? sonuc.ucret : null;
        _fiyatBilgisi = sonuc.bulundu
            ? sonuc.aciklama
            : 'Bu bolge icin fiyat belirlenmemis. Lutfen admin ile iletisime gecin.';
      });
    } catch (_) {}
  }

  Future<void> _basvuruTamamla() async {
    if (!_sozlesmeOnay || !_sartlarOnay) {
      _snack('Lutfen sozlesme ve sartlari onaylayin', hata: true);
      return;
    }
    setState(() => _yukleniyor = true);
    try {
      await FirebaseFirestore.instance
          .collection('veli_basvurular')
          .add({
        'firmaId': _firmaId,
        'projeId': _projeId,
        'projeAdi': _projeAdi,
        'linkId': widget.linkId,
        'ogrenciAdi':  _ogrenciAdiCtrl.text.trim(),
        'ogrenciTc':   _ogrenciTcCtrl.text.trim(),
        'sinif':       _sinifCtrl.text.trim(),
        'veliAdi':     _veliAdiCtrl.text.trim(),
        'telefon':     _telefonCtrl.text.trim(),
        'babaTel':     _babaTelCtrl.text.trim(),
        'anneTel':     _anneTelCtrl.text.trim(),
        'adres':       _adresCtrl.text.trim(),
        'konum': _konum != null
            ? GeoPoint(_konum!.latitude, _konum!.longitude)
            : null,
        'hesaplananFiyat': _hesaplananFiyat,
        'durum': 'beklemede',
        'sozlesmeOnay': _sozlesmeOnay,
        'basvuruTarihi': FieldValue.serverTimestamp(),
      });
      setState(() => _adim = 3);
    } catch (e) {
      _snack('Hata: $e', hata: true);
    } finally {
      setState(() => _yukleniyor = false);
    }
  }

  void _snack(String msg, {bool hata = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: hata ? Colors.red : Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor && _linkBilgisi == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    if (_linkBilgisi == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.link_off, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Bu kayit linki gecersiz veya suresi dolmus.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        title: Text(_projeAdi,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: Row(
            children: List.generate(3, (i) => Expanded(
              child: Container(
                height: 4,
                color: i <= _adim ? orange : Colors.white24,
              ),
            )),
          ),
        ),
      ),
      body: _adim == 3 ? _tamamlandiEkrani() : _adimIcerigi(),
    );
  }

  Widget _adimIcerigi() {
    switch (_adim) {
      case 0: return _formAdimi();
      case 1: return _haritaFiyatAdimi();
      case 2: return _onayAdimi();
      default: return _formAdimi();
    }
  }

  Widget _formAdimi() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _baslikKart('Ogrenci ve Veli Bilgileri',
                'Lutfen bilgileri eksiksiz doldurun'),
            const SizedBox(height: 20),
            _etiket('Ogrenci Adi Soyadi *'),
            _alan(ctrl: _ogrenciAdiCtrl, hint: 'Ogrencinin tam adi', ikon: Icons.school,
                validator: (v) => v == null || v.isEmpty ? 'Zorunlu alan' : null),
            const SizedBox(height: 12),
            _etiket('Ogrenci TC Kimlik No'),
            _alan(ctrl: _ogrenciTcCtrl, hint: '11 haneli TC', ikon: Icons.badge_outlined,
                tip: TextInputType.number),
            const SizedBox(height: 12),
            _etiket('Sinif'),
            _alan(ctrl: _sinifCtrl, hint: 'Ornek: 5-A', ikon: Icons.class_outlined),
            const SizedBox(height: 12),
            _etiket('Veli Adi Soyadi *'),
            _alan(ctrl: _veliAdiCtrl, hint: 'Velinin tam adi', ikon: Icons.person,
                validator: (v) => v == null || v.isEmpty ? 'Zorunlu alan' : null),
            const SizedBox(height: 12),
            _etiket('Ogrenci / Veli Telefon *'),
            _alan(ctrl: _telefonCtrl, hint: '05xx xxx xx xx', ikon: Icons.phone,
                tip: TextInputType.phone,
                validator: (v) => v == null || v.length < 10 ? 'Gecerli telefon girin' : null),
            const SizedBox(height: 12),
            _etiket('Baba Telefon'),
            _alan(ctrl: _babaTelCtrl, hint: '05xx xxx xx xx', ikon: Icons.phone_outlined,
                tip: TextInputType.phone),
            const SizedBox(height: 12),
            _etiket('Anne Telefon'),
            _alan(ctrl: _anneTelCtrl, hint: '05xx xxx xx xx', ikon: Icons.phone_outlined,
                tip: TextInputType.phone),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    setState(() => _adim = 1);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: navy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Devam Et',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _haritaFiyatAdimi() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _baslikKart('Adres Bilgisi', 'Konumunuzu belirleyin'),
          const SizedBox(height: 20),
          _etiket('Ev Adresi'),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextField(
              controller: _adresCtrl,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                border: InputBorder.none,
                hintText: 'Sokak, mahalle, ilce',
                prefixIcon: Icon(Icons.home, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _yukleniyor ? null : _konumBul,
              icon: _yukleniyor
                  ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location, color: navy),
              label: const Text('Konumumu Otomatik Bul',
                  style: TextStyle(color: navy)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: navy),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          if (_konum != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 200,
                child: GoogleMap(
                  initialCameraPosition:
                  CameraPosition(target: _konum!, zoom: 15),
                  markers: {
                    Marker(
                        markerId: const MarkerId('konum'),
                        position: _konum!)
                  },
                  onTap: (latlng) async {
                    setState(() => _konum = latlng);
                    final adresler = await placemarkFromCoordinates(
                        latlng.latitude, latlng.longitude);
                    if (adresler.isNotEmpty) {
                      final a = adresler.first;
                      _adresCtrl.text =
                      '${a.street}, ${a.subLocality}, ${a.locality}';
                    }
                    await _fiyatHesapla();
                  },
                ),
              ),
            ),
          ],
          if (_fiyatBilgisi != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _hesaplananFiyat != null
                    ? orange.withValues(alpha: 0.1)
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _hesaplananFiyat != null
                        ? orange
                        : Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_fiyatBilgisi!,
                      style: const TextStyle(
                          color: Colors.black87, fontSize: 13)),
                  if (_hesaplananFiyat != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${_hesaplananFiyat!.toStringAsFixed(0)} TL / ay',
                      style: TextStyle(
                          color: orange,
                          fontSize: 24,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _adim = 0),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: navy),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Geri',
                      style: TextStyle(color: navy)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _adresCtrl.text.isEmpty
                      ? null
                      : () => setState(() => _adim = 2),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Devam Et',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _onayAdimi() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _baslikKart('Ozet ve Onay', 'Bilgilerinizi kontrol edin'),
          const SizedBox(height: 20),
          _ozetSatir('Ogrenci', _ogrenciAdiCtrl.text),
          if (_ogrenciTcCtrl.text.isNotEmpty)
            _ozetSatir('TC', _ogrenciTcCtrl.text),
          if (_sinifCtrl.text.isNotEmpty)
            _ozetSatir('Sinif', _sinifCtrl.text),
          _ozetSatir('Veli', _veliAdiCtrl.text),
          _ozetSatir('Telefon', _telefonCtrl.text),
          if (_babaTelCtrl.text.isNotEmpty)
            _ozetSatir('Baba Tel', _babaTelCtrl.text),
          if (_anneTelCtrl.text.isNotEmpty)
            _ozetSatir('Anne Tel', _anneTelCtrl.text),
          _ozetSatir('Adres', _adresCtrl.text),
          if (_hesaplananFiyat != null)
            _ozetSatir('Aylik Ucret',
                '${_hesaplananFiyat!.toStringAsFixed(0)} TL'),
          const SizedBox(height: 20),
          _onayKutusu(
            deger: _sozlesmeOnay,
            metin: 'Servis sozlesmesini okudum ve kabul ediyorum.',
            onChange: (v) =>
                setState(() => _sozlesmeOnay = v ?? false),
          ),
          const SizedBox(height: 10),
          _onayKutusu(
            deger: _sartlarOnay,
            metin: 'Kullanim sartlarini ve KVKK metnini okudum, onayliyorum.',
            onChange: (v) =>
                setState(() => _sartlarOnay = v ?? false),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _adim = 1),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: navy),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Geri',
                      style: TextStyle(color: navy)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed:
                  (_yukleniyor || !_sozlesmeOnay || !_sartlarOnay)
                      ? null
                      : _basvuruTamamla,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _yukleniyor
                      ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : const Text('Kaydi Tamamla',
                      style: TextStyle(
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tamamlandiEkrani() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle,
                  size: 64, color: Colors.green),
            ),
            const SizedBox(height: 24),
            const Text('Kayit Tamamlandi!',
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              'Basvurunuz alindi. $_projeAdi yetkilileri en kisa surede sizinle iletisime gececektir.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15, color: Colors.black54),
            ),
            if (_hesaplananFiyat != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Tahmini aylik ucret:\n${_hesaplananFiyat!.toStringAsFixed(0)} TL',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: orange,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _baslikKart(String baslik, String altBaslik) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [navy, Color(0xFF2a5298)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.assignment, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(baslik,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              Text(altBaslik,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _etiket(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF444444))),
  );

  Widget _alan({
    required TextEditingController ctrl,
    required String hint,
    required IconData ikon,
    TextInputType tip = TextInputType.text,
    String? Function(String?)? validator,
  }) =>
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: TextFormField(
          controller: ctrl,
          keyboardType: tip,
          validator: validator,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            border: InputBorder.none,
            hintText: hint,
            prefixIcon:
            Icon(ikon, color: Colors.grey, size: 20),
          ),
        ),
      );

  Widget _ozetSatir(String etiket, String deger) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(etiket,
              style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(deger,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );

  Widget _onayKutusu({
    required bool deger,
    required String metin,
    required void Function(bool?) onChange,
  }) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
              value: deger, onChanged: onChange, activeColor: navy),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(metin,
                  style: const TextStyle(fontSize: 13)),
            ),
          ),
        ],
      );

  @override
  void dispose() {
    _ogrenciAdiCtrl.dispose();
    _ogrenciTcCtrl.dispose();
    _sinifCtrl.dispose();
    _veliAdiCtrl.dispose();
    _telefonCtrl.dispose();
    _babaTelCtrl.dispose();
    _anneTelCtrl.dispose();
    _adresCtrl.dispose();
    super.dispose();
  }
}
