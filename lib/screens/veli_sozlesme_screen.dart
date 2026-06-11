import 'dart:math';
import 'package:flutter/material.dart';
import 'yardim_widget.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'fiyat_yonetim_screen.dart' show FiyatHesaplamaServisi, FiyatSonucu;

// ════════════════════════════════════════════════════════════════
//  VELİ SOZLESME EKRANI
//  dolduran: 'veli' (link) veya 'admin' (manuel)
// ════════════════════════════════════════════════════════════════
class VeliSozlesmeScreen extends StatefulWidget {
  final String  dolduran;  // 'veli' | 'admin'
  final String? linkId;
  final String? linkKod;
  final String? firmaId;

  const VeliSozlesmeScreen({
    super.key,
    this.dolduran = 'veli',
    this.linkId,
    this.linkKod,
    this.firmaId,
  });

  @override
  State<VeliSozlesmeScreen> createState() => _VeliSozlesmeScreenState();
}

class _VeliSozlesmeScreenState extends State<VeliSozlesmeScreen> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  final _pageCtrl = PageController();
  int  _sayfa    = 0;
  bool _okudum   = false;
  bool _kabul    = false;

  String  _firmaId  = '';
  String  _firmaAd  = '';
  Map<String, dynamic> _sozlesmeAyar = {};

  final _ogrAd     = TextEditingController();
  final _ogrSoyad  = TextEditingController();
  final _ogrTc     = TextEditingController();
  final _ogrTel    = TextEditingController();
  final _anneTel   = TextEditingController();
  final _babaTel   = TextEditingController();
  final _anneAd    = TextEditingController();
  final _babaAd    = TextEditingController();
  final _anneEmail = TextEditingController();
  final _adresCtrl = TextEditingController();

  LatLng? _seciliKonum;
  GoogleMapController? _mapCtrl;

  FiyatSonucu? _fiyatSonucu;
  bool _fiyatYukleniyor = false;

  bool _sozlesmeOnay = false;
  bool _kvkkOnay     = false;
  bool _yukleniyor   = false;
  bool _formYuklendi = false;
  bool _tamamlandi   = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    for (final c in [_ogrAd, _ogrSoyad, _ogrTc, _ogrTel, _anneTel,
      _babaTel, _anneAd, _babaAd, _anneEmail, _adresCtrl]) {
      c.dispose();
    }
    _mapCtrl?.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    try {
      String? fId = widget.firmaId;

      if (fId == null && widget.linkId != null) {
        final doc = await FirebaseFirestore.instance
            .collection('kayit_linkleri').doc(widget.linkId).get();
        if (doc.exists) {
          fId = doc.data()?['firmaId'] as String?;
        }
      }

      // Admin girisi: Firebase Auth'dan firmaId al
      if (fId == null && widget.dolduran == 'admin') {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          final snap = await FirebaseFirestore.instance
              .collection('kullanicilar').doc(uid).get();
          fId = snap.data()?['firmaId'] as String?;
        }
      }

      if (fId == null || fId.isEmpty) {
        if (mounted) setState(() => _formYuklendi = true);
        return;
      }

      _firmaId = fId;

      final firmaDoc = await FirebaseFirestore.instance
          .collection('firms').doc(_firmaId).get();
      _firmaAd = firmaDoc.data()?['firmaAd'] ?? 'Firma';

      final sozDoc = await FirebaseFirestore.instance
          .collection('firms').doc(_firmaId)
          .collection('ayarlar').doc('sozlesme').get();
      if (sozDoc.exists) _sozlesmeAyar = sozDoc.data() ?? {};

    } catch (e) {
      debugPrint('VeliSozlesme yukle hata: $e');
    }
    if (mounted) setState(() => _formYuklendi = true);
  }

  Future<void> _fiyatHesapla() async {
    if (_firmaId.isEmpty || _adresCtrl.text.trim().isEmpty) return;
    setState(() { _fiyatYukleniyor = true; _fiyatSonucu = null; });
    try {
      final sonuc = await FiyatHesaplamaServisi.hesapla(
        firmaId: _firmaId,
        veliAdresi: _adresCtrl.text.trim(),
      );
      if (mounted) setState(() => _fiyatSonucu = sonuc);
    } catch (e) {
      if (mounted) setState(() => _fiyatSonucu = const FiyatSonucu(
        ucret: null, ilce: '', mahalle: '', bulundu: false,
        aciklama: 'Hata olustu', tip: 'yok',
      ));
    } finally {
      if (mounted) setState(() => _fiyatYukleniyor = false);
    }
  }

  void _ileri() {
    if (_sayfa == 0 && !_bilgilerDolu()) {
      _snack('Lutfen zorunlu alanlari doldurun', Colors.orange);
      return;
    }
    if (_sayfa == 1 && _seciliKonum == null) {
      _snack('Lutfen haritadan konum secin', Colors.orange);
      return;
    }
    if (_sayfa < 4) {
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut);
      setState(() => _sayfa++);
      if (_sayfa == 2) _fiyatHesapla();
    }
  }

  void _geri() {
    if (_sayfa > 0) {
      _pageCtrl.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut);
      setState(() => _sayfa--);
    }
  }

  bool _bilgilerDolu() =>
      _ogrAd.text.trim().isNotEmpty &&
          _ogrSoyad.text.trim().isNotEmpty &&
          _anneTel.text.trim().isNotEmpty &&
          _anneEmail.text.trim().isNotEmpty;

  Future<void> _kaydet() async {
    if (!_sozlesmeOnay || !_kvkkOnay) {
      _snack('Lutfen sozlesmeyi ve KVKK\'yi onaylayin', Colors.orange);
      return;
    }
    setState(() => _yukleniyor = true);
    try {
      final sifre = _sifreOlustur();
      final email = _anneEmail.text.trim();

      UserCredential? cred;
      try {
        cred = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: sifre);
      } on FirebaseAuthException catch (e) {
        if (e.code != 'email-already-in-use') rethrow;
        _snack('E-posta zaten kayitli, guncelleniyor', Colors.orange);
      }

      final veliUid = cred?.user?.uid ?? '';
      final now = FieldValue.serverTimestamp();

      final parentRef = await FirebaseFirestore.instance
          .collection('parents').add({
        'uid':         veliUid,
        'firmaId':     _firmaId,
        'ad':          _anneAd.text.trim(),
        'babaAd':      _babaAd.text.trim(),
        'email':       email,
        'anneTel':     _anneTel.text.trim(),
        'babaTel':     _babaTel.text.trim(),
        'telefon':     _anneTel.text.trim(),
        'kayitTarihi': now,
        'durum':       'aktif',
      });

      if (veliUid.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('kullanicilar').doc(veliUid).set({
          'email':       email,
          'firmaId':     _firmaId,
          'rol':         'veli',
          'durum':       'aktif',
          'kayitTarihi': now,
        });
      }

      await FirebaseFirestore.instance.collection('students').add({
        'firmaId':          _firmaId,
        'veliId':           parentRef.id,
        'uid':              veliUid,
        'ad':               _ogrAd.text.trim(),
        'soyad':            _ogrSoyad.text.trim(),
        'tc':               _ogrTc.text.trim(),
        'telefon':          _ogrTel.text.trim(),
        'adres':            _adresCtrl.text.trim(),
        'konum':            _seciliKonum != null
            ? GeoPoint(_seciliKonum!.latitude, _seciliKonum!.longitude)
            : null,
        'fiyat':            _fiyatSonucu?.ucret,
        'fiyatKilitli':     true,
        'fiyatAciklama':    _fiyatSonucu?.aciklama ?? '',
        'bindi':            false,
        'kayitTarihi':      now,
        'durum':            'aktif',
        'sozlesmeOnay':     true,
        'sozlesmeTarihi':   now,
        'dolduran':         widget.dolduran,
      });

      await FirebaseFirestore.instance
          .collection('firms').doc(_firmaId)
          .collection('sozlesmeler').add({
        'veliId':       parentRef.id,
        'ogrenciAd':    '${_ogrAd.text.trim()} ${_ogrSoyad.text.trim()}',
        'anneAd':       _anneAd.text.trim(),
        'babaAd':       _babaAd.text.trim(),
        'email':        email,
        'anneTel':      _anneTel.text.trim(),
        'babaTel':      _babaTel.text.trim(),
        'adres':        _adresCtrl.text.trim(),
        'fiyat':        _fiyatSonucu?.ucret,
        'onayTarihi':   now,
        'dolduran':     widget.dolduran,
      });

      await _whatsappGonder(
        tel:   _anneTel.text.trim(),
        ad:    _anneAd.text.trim().isNotEmpty ? _anneAd.text.trim() : 'Veli',
        ogrAd: '${_ogrAd.text.trim()} ${_ogrSoyad.text.trim()}',
        email: email,
        sifre: sifre,
      );

      if (_babaTel.text.trim().isNotEmpty) {
        await _whatsappGonder(
          tel:   _babaTel.text.trim(),
          ad:    _babaAd.text.trim().isNotEmpty ? _babaAd.text.trim() : 'Veli',
          ogrAd: '${_ogrAd.text.trim()} ${_ogrSoyad.text.trim()}',
          email: email,
          sifre: sifre,
        );
      }

      if (mounted) setState(() => _tamamlandi = true);
    } catch (e) {
      if (mounted) _snack('Hata: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _whatsappGonder({
    required String tel,
    required String ad,
    required String ogrAd,
    required String email,
    required String sifre,
  }) async {
    try {
      final n = tel.replaceAll(RegExp(r'[^\d]'), '');
      final mesaj = Uri.encodeComponent(
        'Merhaba $ad,\n\n'
            '$ogrAd icin $_firmaAd servis kaydı tamamlandi.\n\n'
            'Kullanici: $email\n'
            'Sifre: $sifre\n\n'
            'Servisim360',
      );
      final url = Uri.parse('https://wa.me/90$n?text=$mesaj');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  String _sifreOlustur() {
    const chars = 'abcdefghjkmnpqrstuvwxyz23456789';
    final rng = Random.secure();
    return List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  void _snack(String msg, Color renk) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: renk));
  }

  @override
  Widget build(BuildContext context) {
    if (!_formYuklendi) {
      return const Scaffold(
          backgroundColor: _navy,
          body: Center(
              child: CircularProgressIndicator(color: _turuncu)));
    }
    if (_tamamlandi) return _TamamlandiEkrani(firmaAd: _firmaAd);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [YardimButonu(ekranAdi: 'Sozlesmeler'), const SizedBox(width:8)],
        title: Text(
            widget.dolduran == 'admin'
                ? 'Yeni Ogrenci Kaydi'
                : '$_firmaAd - Kayit Formu',
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16)),
        leading: _sayfa > 0
            ? IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _geri)
            : null,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: _IlerlemeBar(sayfa: _sayfa, toplam: 5),
        ),
      ),
      body: PageView(
        controller: _pageCtrl,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _BilgilerSayfasi(
            ogrAd: _ogrAd, ogrSoyad: _ogrSoyad,
            ogrTc: _ogrTc, ogrTel: _ogrTel,
            anneTel: _anneTel, babaTel: _babaTel,
            anneAd: _anneAd, babaAd: _babaAd,
            anneEmail: _anneEmail,
          ),
          _AdresSayfasi(
            adresCtrl: _adresCtrl,
            seciliKonum: _seciliKonum,
            onKonumSec: (ll) => setState(() => _seciliKonum = ll),
            onMapCreated: (ctrl) => _mapCtrl = ctrl,
          ),
          _FiyatSayfasi(
            adres: _adresCtrl.text.trim(),
            fiyatSonucu: _fiyatSonucu,
            yukleniyor: _fiyatYukleniyor,
            onYenile: _fiyatHesapla,
          ),
          _SozlesmeSayfasi(ayar: _sozlesmeAyar, firmaAd: _firmaAd),
          _OnaySayfasi(
            ayar: _sozlesmeAyar,
            sozlesmeOnay: _sozlesmeOnay,
            kvkkOnay: _kvkkOnay,
            yukleniyor: _yukleniyor,
            fiyatSonucu: _fiyatSonucu,
            ogrAd: '${_ogrAd.text} ${_ogrSoyad.text}',
            adres: _adresCtrl.text,
            onSozlesme: (v) => setState(() => _sozlesmeOnay = v ?? false),
            onKvkk: (v) => setState(() => _kvkkOnay = v ?? false),
            onKaydet: _kaydet,
            onYazdir: () => _snack(
                'Yazdir ozelligi yakin zamanda eklenecek', Colors.blue),
          ),
        ],
      ),
      bottomNavigationBar: _AltBar(
        sayfa: _sayfa, toplam: 5,
        onIleri: _sayfa < 4 ? _ileri : null,
        onGeri:  _sayfa > 0 ? _geri  : null,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  SAYFA 1 — BILGILER
// ════════════════════════════════════════════════════════════════
class _BilgilerSayfasi extends StatelessWidget {
  final TextEditingController ogrAd, ogrSoyad, ogrTc, ogrTel;
  final TextEditingController anneTel, babaTel, anneAd, babaAd, anneEmail;
  static const _navy = Color(0xFF1a3a6b);

  const _BilgilerSayfasi({
    required this.ogrAd, required this.ogrSoyad,
    required this.ogrTc,  required this.ogrTel,
    required this.anneTel, required this.babaTel,
    required this.anneAd, required this.babaAd,
    required this.anneEmail,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SayfaBaslik('Ogrenci & Aile Bilgileri', Icons.person_outline),
        const SizedBox(height: 20),
        _Bolum('Ogrenci Bilgileri', Icons.school_outlined),
        _FormAlan(ctrl: ogrAd,    label: 'Ad *',        ikon: Icons.person_outline),
        _FormAlan(ctrl: ogrSoyad, label: 'Soyad *',     ikon: Icons.person_outline),
        _FormAlan(ctrl: ogrTc,    label: 'TC Kimlik',   ikon: Icons.badge_outlined,
            tip: TextInputType.number, uzunluk: 11),
        _FormAlan(ctrl: ogrTel,   label: 'Ogrenci Tel', ikon: Icons.phone_outlined,
            tip: TextInputType.phone),
        const SizedBox(height: 16),
        _Bolum('Anne Bilgileri', Icons.woman_outlined),
        _FormAlan(ctrl: anneAd,    label: 'Anne Ad Soyad *',         ikon: Icons.person_outline),
        _FormAlan(ctrl: anneTel,   label: 'Anne Telefon *',          ikon: Icons.phone_outlined,
            tip: TextInputType.phone),
        _FormAlan(ctrl: anneEmail, label: 'E-posta * (giris icin)',  ikon: Icons.email_outlined,
            tip: TextInputType.emailAddress),
        const SizedBox(height: 16),
        _Bolum('Baba Bilgileri', Icons.man_outlined),
        _FormAlan(ctrl: babaAd,  label: 'Baba Ad Soyad', ikon: Icons.person_outline),
        _FormAlan(ctrl: babaTel, label: 'Baba Telefon',  ikon: Icons.phone_outlined,
            tip: TextInputType.phone),
        Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.2))),
          child: const Row(children: [
            Icon(Icons.info_outline, color: Colors.blue, size: 16),
            SizedBox(width: 8),
            Expanded(child: Text(
              'Giris e-postasi ve sifresi WhatsApp ile gonderilecek.',
              style: TextStyle(color: Colors.blue, fontSize: 12),
            )),
          ]),
        ),
        const SizedBox(height: 80),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  SAYFA 2 — ADRES & HARITA
// ════════════════════════════════════════════════════════════════
class _AdresSayfasi extends StatefulWidget {
  final TextEditingController adresCtrl;
  final LatLng? seciliKonum;
  final ValueChanged<LatLng> onKonumSec;
  final Function(GoogleMapController) onMapCreated;

  const _AdresSayfasi({
    required this.adresCtrl,
    required this.seciliKonum,
    required this.onKonumSec,
    required this.onMapCreated,
  });

  @override
  State<_AdresSayfasi> createState() => _AdresSayfasiState();
}

class _AdresSayfasiState extends State<_AdresSayfasi> {
  static const _navy = Color(0xFF1a3a6b);
  static const _baslangic = LatLng(41.0082, 28.9784);

  LatLng? _konum;

  @override
  void initState() {
    super.initState();
    _konum = widget.seciliKonum;
    _konumAl();
  }

  Future<void> _konumAl() async {
    try {
      final izin = await Geolocator.requestPermission();
      if (izin == LocationPermission.denied ||
          izin == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
          locationSettings:
          const LocationSettings(accuracy: LocationAccuracy.high));
      if (mounted) {
        setState(() => _konum = LatLng(pos.latitude, pos.longitude));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{};
    if (_konum != null) {
      markers.add(Marker(
        markerId: const MarkerId('konum'),
        position: _konum!,
        infoWindow: const InfoWindow(title: 'Evinizin konumu'),
      ));
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SayfaBaslik('Adres & Konum', Icons.location_on_outlined),
          const SizedBox(height: 12),
          TextField(
            controller: widget.adresCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Ev adresi (il, ilce, mahalle, sokak)',
              prefixIcon:
              const Icon(Icons.home_outlined, color: _navy),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3))),
            child: const Row(children: [
              Icon(Icons.touch_app, color: Colors.orange, size: 16),
              SizedBox(width: 8),
              Expanded(
                  child: Text(
                    'Haritada evinizin konumunu isaretleyin.',
                    style: TextStyle(color: Colors.orange, fontSize: 11),
                  )),
            ]),
          ),
          const SizedBox(height: 8),
        ]),
      ),
      Expanded(
        child: Stack(children: [
          GoogleMap(
            onMapCreated: (ctrl) {
              widget.onMapCreated(ctrl);
              if (_konum != null) {
                ctrl.animateCamera(
                    CameraUpdate.newLatLngZoom(_konum!, 15));
              }
            },
            initialCameraPosition: CameraPosition(
                target: _konum ?? _baslangic, zoom: 14),
            markers: markers,
            onTap: (latLng) {
              setState(() => _konum = latLng);
              widget.onKonumSec(latLng);
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
          ),
          if (_konum != null)
            Positioned(
              bottom: 16, left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.check_circle,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(
                        'Konum secildi: '
                            '${_konum!.latitude.toStringAsFixed(4)}, '
                            '${_konum!.longitude.toStringAsFixed(4)}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12),
                      )),
                ]),
              ),
            ),
        ]),
      ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════
//  SAYFA 3 — FIYAT
// ════════════════════════════════════════════════════════════════
class _FiyatSayfasi extends StatelessWidget {
  final String adres;
  final FiyatSonucu? fiyatSonucu;
  final bool yukleniyor;
  final VoidCallback onYenile;
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  const _FiyatSayfasi({
    required this.adres, required this.fiyatSonucu,
    required this.yukleniyor, required this.onYenile,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SayfaBaslik('Ucret Bilgisi', Icons.attach_money),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.grey.withValues(alpha: 0.2))),
          child: Row(children: [
            const Icon(Icons.home_outlined, color: _navy, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(
              adres.isNotEmpty ? adres : 'Adres girilmedi',
              style: const TextStyle(fontSize: 13),
            )),
          ]),
        ),
        const SizedBox(height: 20),
        if (yukleniyor)
          const Center(child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(children: [
              CircularProgressIndicator(color: _navy),
              SizedBox(height: 12),
              Text('Fiyat hesaplaniyor...',
                  style: TextStyle(color: Colors.grey)),
            ]),
          ))
        else if (fiyatSonucu == null)
          Center(child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: _navy),
            onPressed: onYenile,
            icon: const Icon(Icons.calculate_outlined),
            label: const Text('Fiyat Hesapla'),
          ))
        else if (fiyatSonucu!.ucret != null)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [_navy, Color(0xFF2a5298)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(
                      color: _navy.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4))]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text('Fiyatiniz Belirlendi',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                ]),
                const SizedBox(height: 12),
                Text(
                  '${fiyatSonucu!.ucret!.toStringAsFixed(0)} TL / ay',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(fiyatSonucu!.aciklama,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13)),
              ]),
            )
          else
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3))),
              child: Column(children: [
                const Icon(Icons.pending_outlined,
                    color: Colors.orange, size: 48),
                const SizedBox(height: 12),
                const Text('Fiyatiniz Belirleniyor',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.orange)),
                const SizedBox(height: 8),
                const Text(
                  'Bolgeniz icin fiyat tanimlanmamis. '
                      'Firma yetkilisi inceleyip bildirecek.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                TextButton.icon(
                    onPressed: onYenile,
                    icon: const Icon(Icons.refresh, color: Colors.orange),
                    label: const Text('Tekrar Dene',
                        style: TextStyle(color: Colors.orange))),
              ]),
            ),
        const SizedBox(height: 80),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  SAYFA 4 — SOZLESME METNI
// ════════════════════════════════════════════════════════════════
class _SozlesmeSayfasi extends StatelessWidget {
  final Map<String, dynamic> ayar;
  final String firmaAd;
  static const _navy = Color(0xFF1a3a6b);

  const _SozlesmeSayfasi({required this.ayar, required this.firmaAd});

  // Dinamik madde listesi: şablondan veya varsayılandan gelir
  List<Map<String, dynamic>> get _maddeler {
    final sablonMaddeler = List<Map<String, dynamic>>.from(
        ayar['maddeler'] ?? []);
    final ozelMaddeler = List<Map<String, dynamic>>.from(
        ayar['ozelMaddeler'] ?? []);

    // Eğer şablondan madde geliyorsa kullan
    if (sablonMaddeler.isNotEmpty) {
      final aktifler = sablonMaddeler
          .where((m) => m['aktif'] == true)
          .toList();
      return [...aktifler, ...ozelMaddeler];
    }

    // Yoksa varsayılan metni kullan
    return [];
  }

  String get _sozlesmeMetniVarsayilan => '''
$firmaAd HİZMET SÖZLEŞMESİ

${ayar['sozlesme'] ?? 'Taraflar arasında akdedilen bu sözleşme ile veli/vasi aşağıdaki şartları kabul etmektedir.'}

MADDE 1 - KAPSAM
Bu sözleşme bir eğitim-öğretim dönemi için geçerlidir.

MADDE 2 - ÜCRET
${ayar['ucretBilgi'] ?? 'Ücret adresinize göre otomatik hesaplanır.'}
${ayar['odeme'] ?? 'Ödeme her ayın 1-5. günleri arasında yapılır.'}

MADDE 3 - İPTAL
${ayar['iptal'] ?? 'İptal bildirimi en az 15 gün öncesinde yapılmalıdır.'}

MADDE 4 - SERVİS KURALLARI
${ayar['kurallar'] ?? '- Öğrenci belirlenen noktada hazır olmalıdır.\n- Servis bekleme süresi 3 dakikadır.'}

MADDE 5 - VERİ GİZLİLİĞİ
${ayar['kvkk'] ?? 'Kişisel verileriniz KVKK kapsamında işlenmektedir.'}
''';

  @override
  Widget build(BuildContext context) {
    final dinamikMaddeler = _maddeler;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: _SayfaBaslik('Sözleşme', Icons.description_outlined),
      ),
      Expanded(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2))),
          child: dinamikMaddeler.isEmpty
          // Eski statik metin — geriye dönük uyum
              ? Text(_sozlesmeMetniVarsayilan,
              style: const TextStyle(fontSize: 13, height: 1.7, color: Colors.black87))
          // Dinamik madde listesi
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$firmaAd HİZMET SÖZLEŞMESİ',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15, color: _navy)),
            const SizedBox(height: 4),
            Text('Bu sözleşme, taraflar arasında akdedilmiş olup '
                'aşağıdaki hüküm ve koşulları kapsamaktadır.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const Divider(height: 24),
            ...dinamikMaddeler.asMap().entries.map((e) {
              final i = e.key + 1;
              final m = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MADDE $i — ${(m['baslik'] ?? '').toUpperCase()}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12, color: _navy)),
                      const SizedBox(height: 4),
                      Text(m['icerik'] ?? '',
                          style: const TextStyle(
                              fontSize: 13, height: 1.6)),
                    ]),
              );
            }),
          ]),
        ),
      )),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════
//  SAYFA 5 — ONAY & KAYIT
// ════════════════════════════════════════════════════════════════
class _OnaySayfasi extends StatelessWidget {
  final Map<String, dynamic> ayar;
  final bool sozlesmeOnay, kvkkOnay, yukleniyor;
  final FiyatSonucu? fiyatSonucu;
  final String ogrAd, adres;
  final ValueChanged<bool?> onSozlesme, onKvkk;
  final VoidCallback onKaydet, onYazdir;
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  const _OnaySayfasi({
    required this.ayar,
    required this.sozlesmeOnay, required this.kvkkOnay,
    required this.yukleniyor, required this.fiyatSonucu,
    required this.ogrAd, required this.adres,
    required this.onSozlesme, required this.onKvkk,
    required this.onKaydet, required this.onYazdir,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SayfaBaslik('Onay & Kayit', Icons.verified_outlined),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: _navy.withValues(alpha: 0.15))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Kayit Ozeti',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _navy,
                    fontSize: 14)),
            const Divider(height: 16),
            _OzetSatir('Ogrenci', ogrAd),
            _OzetSatir('Adres',
                adres.length > 50 ? '${adres.substring(0, 50)}...' : adres),
            _OzetSatir('Ucret', fiyatSonucu?.ucret != null
                ? '${fiyatSonucu!.ucret!.toStringAsFixed(0)} TL / ay'
                : 'Belirleniyor'),
          ]),
        ),
        const SizedBox(height: 20),
        _OnayKutu(
          deger: sozlesmeOnay,
          metin: ayar['onayKutu'] ??
              'Sozlesmeyi okudum, anladim ve kabul ediyorum.',
          onChange: onSozlesme,
        ),
        const SizedBox(height: 10),
        _OnayKutu(
          deger: kvkkOnay,
          metin:
          'KVKK kapsaminda kisisel verilerimin islenmesini kabul ediyorum.',
          onChange: onKvkk,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                foregroundColor: _navy,
                side: BorderSide(
                    color: _navy.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: onYazdir,
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('Sozlesmeyi Yazdir',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor:
                sozlesmeOnay && kvkkOnay ? Colors.green : Colors.grey,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: sozlesmeOnay && kvkkOnay ? 4 : 0),
            onPressed: (sozlesmeOnay && kvkkOnay && !yukleniyor)
                ? onKaydet
                : null,
            child: yukleniyor
                ? const CircularProgressIndicator(color: Colors.white)
                : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 20),
                  SizedBox(width: 8),
                  Text('Kaydi Tamamla',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ]),
          ),
        ),
        const SizedBox(height: 80),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  TAMAMLANDI
// ════════════════════════════════════════════════════════════════
class _TamamlandiEkrani extends StatelessWidget {
  final String firmaAd;
  const _TamamlandiEkrani({required this.firmaAd});
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      body: Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                shape: BoxShape.circle),
            child: const Icon(Icons.check_circle,
                color: Colors.green, size: 80),
          ),
          const SizedBox(height: 24),
          const Text('Kayit Tamamlandi!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            '$firmaAd servis sistemine kaydiniz olusturuldu.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _turuncu,
                  foregroundColor: Colors.white,
                  padding:
                  const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              onPressed: () =>
                  Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Text('Kapat',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ]),
      )),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  ORTAK WIDGETLAR
// ════════════════════════════════════════════════════════════════
class _SayfaBaslik extends StatelessWidget {
  final String baslik; final IconData ikon;
  static const _navy = Color(0xFF1a3a6b);
  const _SayfaBaslik(this.baslik, this.ikon);
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(ikon, color: _navy, size: 22),
    const SizedBox(width: 10),
    Text(baslik, style: const TextStyle(
        fontSize: 18, fontWeight: FontWeight.bold, color: _navy)),
  ]);
}

class _Bolum extends StatelessWidget {
  final String baslik; final IconData ikon;
  static const _navy = Color(0xFF1a3a6b);
  const _Bolum(this.baslik, this.ikon);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 4),
    child: Row(children: [
      Icon(ikon, color: _navy, size: 15),
      const SizedBox(width: 6),
      Text(baslik, style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.bold, color: _navy)),
    ]),
  );
}

class _FormAlan extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData ikon;
  final TextInputType tip;
  final int? uzunluk;
  static const _navy = Color(0xFF1a3a6b);

  const _FormAlan({
    required this.ctrl, required this.label, required this.ikon,
    this.tip = TextInputType.text, this.uzunluk,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: ctrl,
      keyboardType: tip,
      inputFormatters: uzunluk != null
          ? [LengthLimitingTextInputFormatter(uzunluk!)] : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(ikon, color: _navy, size: 18),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
      ),
    ),
  );
}

class _OzetSatir extends StatelessWidget {
  final String etiket, deger;
  const _OzetSatir(this.etiket, this.deger);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 70, child: Text('$etiket:',
          style: TextStyle(color: Colors.grey[600], fontSize: 12))),
      Expanded(child: Text(deger,
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 12))),
    ]),
  );
}

class _OnayKutu extends StatelessWidget {
  final bool deger;
  final String metin;
  final ValueChanged<bool?> onChange;
  static const _navy = Color(0xFF1a3a6b);
  const _OnayKutu({
    required this.deger, required this.metin, required this.onChange});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
        color: deger ? _navy.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: deger
                ? _navy
                : Colors.grey.withValues(alpha: 0.3))),
    child: CheckboxListTile(
      value: deger,
      onChanged: onChange,
      activeColor: _navy,
      title: Text(metin, style: const TextStyle(fontSize: 13)),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    ),
  );
}

class _IlerlemeBar extends StatelessWidget {
  final int sayfa, toplam;
  static const _turuncu = Color(0xFFFF8C00);
  const _IlerlemeBar({required this.sayfa, required this.toplam});
  @override
  Widget build(BuildContext context) => Container(
    height: 6,
    color: Colors.white24,
    child: FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: (sayfa + 1) / toplam,
      child: Container(color: _turuncu),
    ),
  );
}

class _AltBar extends StatelessWidget {
  final int sayfa, toplam;
  final VoidCallback? onIleri, onGeri;
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  static const _adlar = ['Bilgiler', 'Adres', 'Ucret', 'Sozlesme', 'Onay'];
  const _AltBar({required this.sayfa, required this.toplam,
    required this.onIleri, required this.onGeri});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
    decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8)]),
    child: Row(children: [
      if (onGeri != null)
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              foregroundColor: _navy,
              side: const BorderSide(color: _navy),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          onPressed: onGeri,
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('Geri'),
        )
      else
        const SizedBox(width: 80),
      Expanded(child: Center(child: Text(
        '${sayfa + 1}/$toplam — ${_adlar[sayfa]}',
        style: TextStyle(color: Colors.grey[500], fontSize: 12),
      ))),
      if (onIleri != null && sayfa < 4)
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: _turuncu,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          onPressed: onIleri,
          label: const Text('Ileri',
              style: TextStyle(fontWeight: FontWeight.bold)),
          icon: const Icon(Icons.arrow_forward, size: 16),
        )
      else
        const SizedBox(width: 80),
    ]),
  );
}
