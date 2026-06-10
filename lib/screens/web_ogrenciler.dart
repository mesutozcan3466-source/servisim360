import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/session_service.dart';

class WebOgrenciler extends StatefulWidget {
  const WebOgrenciler({super.key});
  @override
  State<WebOgrenciler> createState() => _WebOgrencilerState();
}

class _WebOgrencilerState extends State<WebOgrenciler> {
  static const _navy   = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);

  String _firmaId = '';
  List<Map<String, dynamic>> _ogrenciler = [];
  List<Map<String, dynamic>> _filtreliOgr = [];
  List<Map<String, dynamic>> _soforler = [];
  bool _yukleniyor = true;
  String _aramaMetni = '';
  String _durumFiltre = 'hepsi';
  String _soforFiltre = 'hepsi';
  final _aramaCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _yukle(); }

  @override
  void dispose() { _aramaCtrl.dispose(); super.dispose(); }

  Future<void> _yukle() async {
    final firmaId = await SessionService.instance.firmaIdAl() ?? '';
    _firmaId = firmaId;
    final projeId = SessionService.instance.aktifProjeId ?? '';
    if (firmaId.isEmpty) { setState(() => _yukleniyor = false); return; }

    try {
      var q = FirebaseFirestore.instance.collection('students')
          .where('firmaId', isEqualTo: firmaId);
      if (projeId.isNotEmpty) q = q.where('projeId', isEqualTo: projeId);
      final snap = await q.orderBy('ad').get();
      _ogrenciler = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      final sSnap = await FirebaseFirestore.instance.collection('drivers')
          .where('firmaId', isEqualTo: firmaId).get();
      _soforler = sSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (_) {}

    _filtrele();
    if (mounted) setState(() => _yukleniyor = false);
  }

  void _filtrele() {
    var liste = List<Map<String, dynamic>>.from(_ogrenciler);
    if (_aramaMetni.isNotEmpty) {
      liste = liste.where((o) =>
      (o['ad'] ?? '').toString().toLowerCase().contains(_aramaMetni) ||
          (o['veliTel'] ?? '').toString().contains(_aramaMetni) ||
          (o['adres'] ?? '').toString().toLowerCase().contains(_aramaMetni)
      ).toList();
    }
    if (_durumFiltre != 'hepsi') {
      liste = liste.where((o) => o['durum'] == _durumFiltre).toList();
    }
    if (_soforFiltre != 'hepsi') {
      liste = liste.where((o) =>
      (o['surucuId'] ?? o['soforId'] ?? '') == _soforFiltre).toList();
    }
    setState(() => _filtreliOgr = liste);
  }

  String _soforAd(String id) {
    if (id.isEmpty) return 'Atanmamis';
    final s = _soforler.firstWhere((s) => s['id'] == id, orElse: () => {});
    return s.isNotEmpty ? s['ad'] ?? 'Sofor' : 'Atanmamis';
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── ÜST BAR ──
      Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: Row(children: [
          // Arama
          Expanded(child: TextField(
            controller: _aramaCtrl,
            decoration: InputDecoration(
              hintText: 'Ogrenci ara (isim, telefon, adres...)',
              prefixIcon: const Icon(Icons.search, color: _navy, size: 18),
              filled: true, fillColor: const Color(0xFFF5F7FA),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onChanged: (v) { _aramaMetni = v.toLowerCase(); _filtrele(); },
          )),
          const SizedBox(width: 12),

          // Durum filtresi
          _DropFilter('Durum', _durumFiltre, {
            'hepsi': 'Hepsi',
            'onayli': 'Onayli',
            'beklemede': 'Beklemede',
          }, (v) { setState(() => _durumFiltre = v); _filtrele(); }),
          const SizedBox(width: 12),

          // Şoför filtresi
          _DropFilter('Servis', _soforFiltre, {
            'hepsi': 'Hepsi',
            '': 'Atanmamis',
            ..._soforler.asMap().map((_, s) =>
                MapEntry(s['id'] as String, s['ad'] as String? ?? 'Sofor')),
          }, (v) { setState(() => _soforFiltre = v); _filtrele(); }),
          const SizedBox(width: 12),

          // Yeni kayıt butonları
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            icon: const Icon(Icons.person_add_rounded, size: 16),
            label: const Text('Hizli Ekle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: () => _hizliOgrenciEkleDialog(),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _navy, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            icon: const Icon(Icons.person_add_outlined, size: 16),
            label: const Text('Yuz Yuze Kayit', style: TextStyle(fontSize: 12)),
            onPressed: () => Navigator.pushNamed(context, '/yuz_yuze_kayit'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _orange, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            icon: const Icon(Icons.upload_file_outlined, size: 16),
            label: const Text('Excel Yukle', style: TextStyle(fontSize: 12)),
            onPressed: () => Navigator.pushNamed(context, '/toplu_yukle'),
          ),
        ]),
      ),

      // Sayaç
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        color: const Color(0xFFF5F7FA),
        child: Row(children: [
          Text('${_filtreliOgr.length} ogrenci',
              style: const TextStyle(color: _navy, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(width: 12),
          Text('/ ${_ogrenciler.length} toplam',
              style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.refresh_outlined, size: 15),
            label: const Text('Yenile', style: TextStyle(fontSize: 12)),
            onPressed: () { setState(() => _yukleniyor = true); _yukle(); },
          ),
        ]),
      ),

      // ── TABLO ──
      Expanded(child: _yukleniyor
          ? const Center(child: CircularProgressIndicator(color: _navy))
          : _filtreliOgr.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.person_off_outlined, size: 64, color: Colors.grey),
        const SizedBox(height: 12),
        Text('Ogrenci bulunamadi', style: TextStyle(color: Colors.grey[400], fontSize: 15)),
      ]))
          : Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)]),
        child: Column(children: [
          // Tablo başlığı
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
                color: _navy.withValues(alpha: 0.04),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
            child: const Row(children: [
              SizedBox(width: 40, child: Text('#', style: _baslik)),
              SizedBox(width: 160, child: Text('Ad Soyad', style: _baslik)),
              SizedBox(width: 140, child: Text('Veli Tel', style: _baslik)),
              Expanded(child: Text('Adres', style: _baslik)),
              SizedBox(width: 150, child: Text('Servis', style: _baslik)),
              SizedBox(width: 90, child: Text('Durum', style: _baslik)),
              SizedBox(width: 80, child: Text('Islem', style: _baslik)),
            ]),
          ),
          // Satırlar
          Expanded(child: ListView.separated(
            itemCount: _filtreliOgr.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF0F0F0)),
            itemBuilder: (_, i) {
              final ogr = _filtreliOgr[i];
              final surucuId = (ogr['surucuId'] ?? ogr['soforId'] ?? '').toString();
              final durum   = ogr['durum'] as String? ?? 'beklemede';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(children: [
                  SizedBox(width: 40, child: Text('${i+1}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12))),
                  SizedBox(width: 160, child: Row(children: [
                    CircleAvatar(radius: 14,
                        backgroundColor: _navy.withValues(alpha: 0.1),
                        child: Text((ogr['ad'] ?? '?')[0].toUpperCase(),
                            style: const TextStyle(color: _navy, fontSize: 11,
                                fontWeight: FontWeight.bold))),
                    const SizedBox(width: 8),
                    Expanded(child: Text(ogr['ad'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        overflow: TextOverflow.ellipsis)),
                  ])),
                  SizedBox(width: 140, child: Text(ogr['veliTel'] ?? ogr['telefon'] ?? '-',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12))),
                  Expanded(child: Text(ogr['adres'] ?? '-',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      overflow: TextOverflow.ellipsis)),
                  SizedBox(width: 150, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: surucuId.isNotEmpty
                          ? Colors.blue.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(_soforAd(surucuId),
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: surucuId.isNotEmpty ? Colors.blue : Colors.orange),
                        overflow: TextOverflow.ellipsis),
                  )),
                  SizedBox(width: 90, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: (durum == 'onayli' ? Colors.green : Colors.orange)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(durum,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                            color: durum == 'onayli' ? Colors.green : Colors.orange)),
                  )),
                  SizedBox(width: 110, child: Row(children: [
                    IconButton(
                      icon: const Icon(Icons.info_outline, size: 16, color: Colors.teal),
                      onPressed: () => _ogrenciDetayDialog(ogr),
                      tooltip: 'Detay',
                      splashRadius: 16,
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 16, color: _navy),
                      onPressed: () => _ogrenciDuzenle(ogr),
                      tooltip: 'Duzenle',
                      splashRadius: 16,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                      onPressed: () => _silOnay(ogr),
                      tooltip: 'Sil',
                      splashRadius: 16,
                    ),
                  ])),
                ]),
              );
            },
          )),
        ]),
      )),
    ]);
  }

  static const _baslik = TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
      color: Color(0xFF1a3a6b));

  String _rastgeleKod() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final now = DateTime.now();
    final buf = StringBuffer();
    for (var i = 0; i < 6; i++) buf.write(chars[(now.microsecond + i * 7) % chars.length]);
    return buf.toString();
  }

  void _hizliOgrenciEkleDialog() {
    final adCtrl     = TextEditingController();
    final soyadCtrl  = TextEditingController();
    final sinifCtrl  = TextEditingController();
    final tcCtrl     = TextEditingController();
    final veliCtrl   = TextEditingController();
    final telCtrl    = TextEditingController();
    final acilTelCtrl= TextEditingController();
    final adresCtrl  = TextEditingController();
    final okulCtrl   = TextEditingController();
    final notCtrl    = TextEditingController();
    bool yukleniyor  = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 540,
            constraints: const BoxConstraints(maxHeight: 680),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20), color: Colors.white),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                    color: _navy,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                child: Row(children: [
                  const Icon(Icons.person_add_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Öğrenci Ekle',
                        style: TextStyle(color: Colors.white,
                            fontSize: 17, fontWeight: FontWeight.bold)),
                    Text('Veli hesabı otomatik oluşturulacak',
                        style: TextStyle(color: Colors.white60, fontSize: 11)),
                  ])),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx)),
                ]),
              ),
              Expanded(child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Öğrenci Bilgileri', style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13, color: _navy)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _webInp(adCtrl, 'Ad *', Icons.person_outline)),
                    const SizedBox(width: 8),
                    Expanded(child: _webInp(soyadCtrl, 'Soyad', Icons.person_outline)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _webInp(okulCtrl,   'Okul',   Icons.school_outlined)),
                    const SizedBox(width: 8),
                    Expanded(child: _webInp(sinifCtrl,  'Sinif',  Icons.class_outlined)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _webInp(tcCtrl,     'TC Kimlik (opsiyonel)', Icons.badge_outlined)),
                  ]),
                  const SizedBox(height: 8),
                  _webInp(adresCtrl, 'Adres', Icons.location_on_outlined),
                  const SizedBox(height: 4),
                  const Text(
                      'Adres girilince sistem fiyatı otomatik hesaplar.',
                      style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 16),
                  const Text('Veli Bilgileri', style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13, color: _navy)),
                  const SizedBox(height: 4),
                  const Text('Veli hesabı otomatik oluşturulur (tel no = kullanıcı adı)',
                      style: TextStyle(color: Colors.grey, fontSize: 11)),
                  const SizedBox(height: 8),
                  _webInp(veliCtrl, 'Veli Adı Soyadı *', Icons.family_restroom_outlined),
                  const SizedBox(height: 8),
                  _webInp(telCtrl, 'Veli Telefon *', Icons.phone_outlined,
                      tip: TextInputType.phone),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200)),
                    child: const Row(children: [
                      Icon(Icons.auto_awesome, color: Colors.green, size: 14),
                      SizedBox(width: 8),
                      Expanded(child: Text(
                        'Kayıt sonrası veli hesabı otomatik oluşturulur. WhatsApp ile bildirim gönderebilirsiniz.',
                        style: TextStyle(fontSize: 11, color: Colors.green),
                      )),
                    ]),
                  ),
                ]),
              )),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    child: const Text('İptal'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _navy, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    onPressed: yukleniyor ? null : () async {
                      if (adCtrl.text.trim().isEmpty || telCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                            content: Text('Ad ve telefon zorunlu!'),
                            behavior: SnackBarBehavior.floating));
                        return;
                      }
                      setSt(() => yukleniyor = true);
                      try {
                        final now      = FieldValue.serverTimestamp();
                        final geciciSif = _rastgeleKod();
                        final kulAdi    = telCtrl.text.trim();

                        final ogrRef = await FirebaseFirestore.instance
                            .collection('students').add({
                          'firmaId' : _firmaId,
                          'ad'      : adCtrl.text.trim(),
                          'soyad'   : soyadCtrl.text.trim(),
                          'adSoyad' : '${adCtrl.text.trim()} ${soyadCtrl.text.trim()}'.trim(),
                          'adres'   : adresCtrl.text.trim(),
                          'okul'    : okulCtrl.text.trim(),
                          'veliAd'    : veliCtrl.text.trim(),
                          'veliTel'   : telCtrl.text.trim(),
                          'sinif'     : sinifCtrl.text.trim(),
                          'tc'        : tcCtrl.text.trim(),
                          'acilTel'   : acilTelCtrl.text.trim(),
                          'not'       : notCtrl.text.trim(),
                          'fiyat'     : 0,
                          'sozlesmeDurum': 'bekliyor',
                          'aktif'     : true,
                          'olusturma': now,
                        });
                        await FirebaseFirestore.instance
                            .collection('parents').doc(ogrRef.id).set({
                          'firmaId'     : _firmaId,
                          'ogrenciId'   : ogrRef.id,
                          'ad'          : veliCtrl.text.trim(),
                          'telefon'     : telCtrl.text.trim(),
                          'kullaniciAdi': kulAdi,
                          'geciciSifre' : geciciSif,
                          'ilkGiris'    : true,
                          'aktif'       : true,
                          'rol'         : 'veli',
                          'olusturma'   : now,
                        });
                        await FirebaseFirestore.instance
                            .collection('kullanicilar').doc(ogrRef.id).set({
                          'firmaId'     : _firmaId,
                          'ad'          : veliCtrl.text.trim(),
                          'telefon'     : telCtrl.text.trim(),
                          'kullaniciAdi': kulAdi,
                          'sifre'       : geciciSif,
                          'ilkGiris'    : true,
                          'rol'         : 'veli',
                          'ogrenciId'   : ogrRef.id,
                          'olusturma'   : now,
                        });
                        await FirebaseFirestore.instance
                            .collection('students').doc(ogrRef.id).update({'veliId': ogrRef.id});

                        if (ctx.mounted) Navigator.pop(ctx);
                        await _yukle();
                        if (context.mounted) {
                          _veliGirisDialog(
                              veliCtrl.text.trim(), telCtrl.text.trim(),
                              kulAdi, geciciSif, adCtrl.text.trim());
                        }
                      } catch (e) {
                        setSt(() => yukleniyor = false);
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text('Hata: \$e'),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating));
                      }
                    },
                    icon: yukleniyor
                        ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save_rounded),
                    label: Text(yukleniyor ? 'Kaydediliyor...' : 'Kaydet & Veli Hesabı Oluştur',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  )),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _veliGirisDialog(String veliAd, String tel, String kulAdi,
      String sifre, String ogrAd) {
    final mesaj = 'Servisim360 Giriş Bilgileri\n'
        'Öğrenci: \$ogrAd\n'
        'Kullanıcı Adı: \$kulAdi\n'
        'Geçici Şifre: \$sifre\n'
        'Uygulamaya giriş yapabilirsiniz.';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('\$veliAd — Giriş Bilgileri'),
        content: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200)),
          child: Text(mesaj, style: const TextStyle(fontSize: 13)),
        ),
        actions: [
          OutlinedButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Kopyala'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: mesaj));
                Navigator.pop(_);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Kopyalandı!'), backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating));
              }),
          ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(_);
                final temiz = tel.replaceAll(RegExp(r'[^0-9]'), '');
                final url = Uri.parse(
                    'https://wa.me/90\$temiz?text=\${Uri.encodeComponent(mesaj)}');
                if (await canLaunchUrl(url)) {
                  launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('WhatsApp',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          TextButton(onPressed: () => Navigator.pop(_), child: const Text('Kapat')),
        ],
      ),
    );
  }

  Widget _webInp(TextEditingController c, String label, IconData icon,
      {TextInputType? tip}) =>
      TextField(
        controller: c, keyboardType: tip,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 16, color: _navy),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      );

  void _ogrenciDuzenle(Map<String, dynamic> ogr) {
    showDialog(context: context, builder: (_) => _OgrenciDuzenleDialog(
      ogr: ogr, soforler: _soforler,
      onKaydet: (data) async {
        await FirebaseFirestore.instance
            .collection('students').doc(ogr['id']).update(data);
        _yukle();
      },
    ));
  }


  // ── Öğrenci Detay Dialog ───────────────────────────────────────

  // Fiyat hesaplama - adres'e gore fiyat tablosundan bul
  Future<double> _fiyatHesapla(String adres) async {
    if (adres.isEmpty || _firmaId.isEmpty) return 0;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('fiyatlar')
          .where('firmaId', isEqualTo: _firmaId)
          .get();
      for (final doc in snap.docs) {
        final d = doc.data();
        final bolge = (d['bolge'] ?? '').toString().toLowerCase();
        if (bolge.isNotEmpty && adres.toLowerCase().contains(bolge)) {
          return ((d['ucret'] ?? d['fiyat'] ?? 0) as num).toDouble();
        }
      }
    } catch (_) {}
    return 0;
  }

  void _ogrenciDetayDialog(Map<String, dynamic> ogr) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: 500,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Başlık
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                  color: _navy,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
              child: Row(children: [
                CircleAvatar(
                    radius: 20, backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(
                        (ogr['ad'] ?? '?').isNotEmpty ? (ogr['ad'] as String)[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ogr['adSoyad'] ?? ogr['ad'] ?? '',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  Text('${ogr['okul'] ?? ''} ${ogr['sinif'] ?? ''}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ])),
                IconButton(icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                    onPressed: () => Navigator.pop(_),
                    padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              ]),
            ),
            // İçerik
            Flexible(child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Öğrenci Bilgileri
                _detayBaslik('Ogrenci Bilgileri', Icons.school_outlined),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _infoBant2('Adres', ogr['adres'] ?? ogr['sabahAdres'] ?? '-', Icons.location_on_outlined, Colors.blue),
                  _infoBant2('Okul', ogr['okul'] ?? '-', Icons.school_outlined, _navy),
                  _infoBant2('Sinif', ogr['sinif'] ?? '-', Icons.class_outlined, Colors.teal),
                  _infoBant2('TC', ogr['tc'] ?? '-', Icons.badge_outlined, Colors.grey),
                  _infoBant2('Konum', ogr['konumVar'] == true ? 'Var' : 'Bekleniyor',
                      Icons.location_on, ogr['konumVar'] == true ? Colors.green : Colors.orange),
                  GestureDetector(
                      onTap: () {
                        Navigator.pop(_);
                        Navigator.pushNamed(context, '/harita');
                      },
                      child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.withValues(alpha: 0.2))),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.edit_location_outlined, size: 12, color: Colors.blue),
                            SizedBox(width: 5),
                            Text('Konum Duzenle', style: TextStyle(fontSize: 11, color: Colors.blue)),
                          ]))),
                ]),
                const SizedBox(height: 14),
                // Veli
                _detayBaslik('Veli Bilgileri', Icons.family_restroom_outlined),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _infoBant2('Veli', ogr['veliAd'] ?? '-', Icons.person_outlined, Colors.purple),
                  _infoBant2('Tel', ogr['veliTel'] ?? ogr['anneTelefon'] ?? '-', Icons.phone_outlined, Colors.green),
                  if ((ogr['acilTel'] ?? '').isNotEmpty)
                    _infoBant2('Acil', ogr['acilTel'], Icons.emergency_outlined, Colors.red),
                ]),
                const SizedBox(height: 14),
                // Servis
                _detayBaslik('Servis Bilgileri', Icons.directions_bus_outlined),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _infoBant2('Servis', ogr['soforAd'] ?? ogr['servisAd'] ?? (ogr['surucuId']?.isNotEmpty == true ? 'Atanmis' : 'Atanmamis'),
                      Icons.directions_bus_outlined, ogr['surucuId']?.isNotEmpty == true ? Colors.blue : Colors.orange),
                  _infoBant2('Proje', ogr['projeAd'] ?? ogr['projeId'] ?? '-', Icons.folder_outlined, _navy),
                  _infoBant2('Sabah', ogr['sabahKullan'] == true ? 'Evet' : 'Hayir', Icons.wb_sunny_outlined, Colors.orange),
                  _infoBant2('Aksam', ogr['aksamKullan'] == true ? 'Evet' : 'Hayir', Icons.nights_stay_outlined, Colors.indigo),
                ]),
                const SizedBox(height: 14),
                // Sistem
                _detayBaslik('Sistem Bilgileri', Icons.info_outline),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _infoBant2('Durum', ogr['durum'] ?? 'onayli', Icons.verified_outlined, Colors.green),
                  _infoBant2('Sozlesme', ogr['sozlesmeDurum'] ?? 'bekliyor', Icons.description_outlined,
                      ogr['sozlesmeDurum'] == 'imzalandi' ? Colors.green : Colors.orange),
                  _infoBant2('Fiyat', '${ogr['fiyat'] ?? 0} TL', Icons.payments_outlined, Colors.teal),
                ]),
              ]),
            )),
            // Alt butonlar
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Expanded(child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: _navy, side: const BorderSide(color: _navy),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () { Navigator.pop(_); _ogrenciDuzenle(ogr); },
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Duzenle'),
                )),
                const SizedBox(width: 6),
                // Servise Ata
                Expanded(child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () { Navigator.pop(_); _ogrenciDuzenle(ogr); },
                  icon: const Icon(Icons.directions_bus_outlined, size: 16),
                  label: const Text('ServiseAta'),
                )),
                const SizedBox(width: 6),
                Expanded(child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _navy, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () => Navigator.pop(_),
                  icon: const Icon(Icons.close_outlined, size: 16),
                  label: const Text('Kapat'),
                )),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _detayBaslik(String baslik, IconData ikon) => Row(children: [
    Icon(ikon, color: _navy, size: 16), const SizedBox(width: 8),
    Text(baslik, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _navy)),
  ]);

  Widget _infoBant2(String label, String deger, IconData ikon, Color renk) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: renk.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: renk.withValues(alpha: 0.2))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(ikon, size: 12, color: renk),
          const SizedBox(width: 5),
          Text('$label: ', style: TextStyle(fontSize: 11, color: renk, fontWeight: FontWeight.bold)),
          Text(deger, style: TextStyle(fontSize: 11, color: renk)),
        ]),
      );

  void _silOnay(Map<String, dynamic> ogr) {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Ogrenci Sil', style: TextStyle(fontSize: 15)),
      content: Text('"${ogr['ad']}" silinecek. Emin misiniz?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Iptal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            Navigator.pop(context);
            await FirebaseFirestore.instance
                .collection('students').doc(ogr['id']).delete();
            _yukle();
          },
          child: const Text('Sil', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }
}

// ── DROP FİLTRE ──────────────────────────────────────────────────
class _DropFilter extends StatelessWidget {
  final String label, secili;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;
  const _DropFilter(this.label, this.secili, this.items, this.onChanged);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
        color: const Color(0xFFF5F7FA)),
    child: DropdownButtonHideUnderline(child: DropdownButton<String>(
      value: secili,
      style: const TextStyle(fontSize: 12, color: Color(0xFF1a3a6b)),
      items: items.entries.map((e) =>
          DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
      onChanged: (v) => v != null ? onChanged(v) : null,
    )),
  );
}

// ── ÖĞRENCI DÜZENLE DİALOG ──────────────────────────────────────
class _OgrenciDuzenleDialog extends StatefulWidget {
  final Map<String, dynamic> ogr;
  final List<Map<String, dynamic>> soforler;
  final ValueChanged<Map<String, dynamic>> onKaydet;
  const _OgrenciDuzenleDialog(
      {required this.ogr, required this.soforler, required this.onKaydet});
  @override
  State<_OgrenciDuzenleDialog> createState() => _OgrenciDuzenleDialogState();
}

class _OgrenciDuzenleDialogState extends State<_OgrenciDuzenleDialog> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  late TextEditingController _adCtrl, _telCtrl, _adresCtrl, _sinifCtrl, _okulCtrl;
  String  _surucuId  = '';
  String  _durum     = 'onayli';
  String? _projeId;
  String? _servisId;
  bool    _sabahKullan = true;
  bool    _aksamKullan = true;

  List<Map<String, dynamic>> _projeler  = [];
  List<Map<String, dynamic>> _servisler = [];

  @override
  void initState() {
    super.initState();
    final o = widget.ogr;
    _adCtrl    = TextEditingController(text: o['ad']      ?? '');
    _telCtrl   = TextEditingController(text: o['veliTel'] ?? o['anneTelefon'] ?? '');
    _adresCtrl = TextEditingController(text: o['adres']   ?? o['sabahAdres'] ?? '');
    _sinifCtrl = TextEditingController(text: o['sinif']   ?? '');
    _okulCtrl  = TextEditingController(text: o['okul']    ?? '');
    _surucuId  = (o['surucuId'] ?? o['soforId'] ?? '').toString();
    _durum     = o['durum']    as String? ?? 'onayli';
    _projeId   = o['projeId']  as String?;
    _servisId  = o['servisId'] as String?;
    _sabahKullan = o['sabahKullan'] as bool? ?? o['morningEnabled'] as bool? ?? true;
    _aksamKullan = o['aksamKullan'] as bool? ?? o['eveningEnabled'] as bool? ?? true;
    if (_projeId?.isEmpty ?? true) _projeId = null;
    if (_servisId?.isEmpty ?? true) _servisId = null;
    _projeleriYukle();
  }

  @override
  void dispose() {
    _adCtrl.dispose(); _telCtrl.dispose(); _adresCtrl.dispose();
    _sinifCtrl.dispose(); _okulCtrl.dispose();
    super.dispose();
  }

  Future<void> _projeleriYukle() async {
    final firmaId = widget.ogr['firmaId'] as String? ?? '';
    if (firmaId.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('projects')
          .where('firmaId', isEqualTo: firmaId)
          .where('durum', isEqualTo: 'aktif')
          .get();
      if (mounted) setState(() {
        _projeler = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      });
      if (_projeId != null) await _servisleriYukle(_projeId!);
    } catch (_) {}
  }

  Future<void> _servisleriYukle(String projeId) async {
    final firmaId = widget.ogr['firmaId'] as String? ?? '';
    try {
      final snap = await FirebaseFirestore.instance
          .collection('drivers')
          .where('firmaId', isEqualTo: firmaId)
          .where('projeId', isEqualTo: projeId)
          .get();
      if (mounted) setState(() {
        _servisler = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    contentPadding: EdgeInsets.zero,
    content: SizedBox(
      width: 460,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Başlık
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
              color: _navy,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          child: Row(children: [
            CircleAvatar(
              radius: 18, backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: Text(
                  (widget.ogr['ad'] as String? ?? '?').isNotEmpty
                      ? (widget.ogr['ad'] as String)[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(widget.ogr['ad'] as String? ?? 'Öğrenci',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            IconButton(icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          ]),
        ),
        // Form
        Flexible(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            // Bağlantı bilgileri (sadece göster)
            if ((widget.ogr['veliAd'] ?? widget.ogr['veliId'] ?? '').isNotEmpty)
              _infoBant('Bağlı Veli', widget.ogr['veliAd'] ?? widget.ogr['veliId'],
                  Icons.family_restroom_outlined, Colors.purple),
            if (_surucuId.isNotEmpty) ...[
              const SizedBox(height: 6),
              _infoBant('Bağlı Şoför',
                  widget.soforler.firstWhere((s) => s['id'] == _surucuId,
                      orElse: () => {'ad': _surucuId})['ad'] ?? _surucuId,
                  Icons.person_outlined, Colors.blue),
            ],
            const SizedBox(height: 12),

            // Ad, okul, sınıf
            _Alan(_adCtrl, 'Ad Soyad *', Icons.person_outline),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _Alan(_okulCtrl, 'Okul', Icons.school_outlined)),
              const SizedBox(width: 10),
              Expanded(child: _Alan(_sinifCtrl, 'Sınıf', Icons.class_outlined)),
            ]),
            const SizedBox(height: 10),
            _Alan(_telCtrl, 'Veli Telefon', Icons.phone_outlined, tip: TextInputType.phone),
            const SizedBox(height: 10),
            _Alan(_adresCtrl, 'Adres', Icons.location_on_outlined),
            const SizedBox(height: 14),

            // Proje seçimi
            DropdownButtonFormField<String?>(
              value: _projeId,
              decoration: InputDecoration(
                  labelText: 'Proje',
                  prefixIcon: const Icon(Icons.folder_outlined, color: _navy, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Proje seç...')),
                ..._projeler.map((p) => DropdownMenuItem<String?>(
                    value: p['id'] as String,
                    child: Text(p['projeAd'] as String? ?? 'Proje'))),
              ],
              onChanged: (v) {
                setState(() { _projeId = v; _servisId = null; _servisler = []; });
                if (v != null) _servisleriYukle(v);
              },
            ),
            const SizedBox(height: 10),

            // Servis/Şoför seçimi
            DropdownButtonFormField<String?>(
              value: _servisId,
              decoration: InputDecoration(
                  labelText: 'Servise Ata',
                  prefixIcon: const Icon(Icons.directions_bus_outlined, color: _navy, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Atanmamış')),
                ..._servisler.map((s) => DropdownMenuItem<String?>(
                    value: s['id'] as String,
                    child: Text('${s['ad'] ?? 'Şoför'} — ${s['aracPlaka'] ?? ''}'))),
                // Eski şoförler listesi de göster
                ...widget.soforler.where((s) =>
                !_servisler.any((ss) => ss['id'] == s['id'])).map((s) =>
                    DropdownMenuItem<String?>(
                        value: s['id'] as String,
                        child: Text(s['ad'] as String? ?? 'Şoför'))),
              ],
              onChanged: (v) => setState(() { _servisId = v; _surucuId = v ?? ''; }),
            ),
            const SizedBox(height: 14),

            // Sabah/akşam kullanım
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.grey[50], borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200)),
              child: Column(children: [
                Row(children: [
                  const Icon(Icons.wb_sunny_outlined, size: 16, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Sabah Servisi', style: TextStyle(fontSize: 13))),
                  Switch(value: _sabahKullan,
                      onChanged: (v) => setState(() => _sabahKullan = v),
                      activeColor: _turuncu),
                ]),
                Row(children: [
                  const Icon(Icons.nights_stay_outlined, size: 16, color: Colors.indigo),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Akşam Servisi', style: TextStyle(fontSize: 13))),
                  Switch(value: _aksamKullan,
                      onChanged: (v) => setState(() => _aksamKullan = v),
                      activeColor: _turuncu),
                ]),
              ]),
            ),
            const SizedBox(height: 10),

            // Durum
            DropdownButtonFormField<String>(
              value: _durum,
              decoration: InputDecoration(
                  labelText: 'Durum',
                  prefixIcon: const Icon(Icons.verified_outlined, color: _navy, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true),
              items: const [
                DropdownMenuItem(value: 'onayli',    child: Text('Onaylı')),
                DropdownMenuItem(value: 'beklemede', child: Text('Beklemede')),
                DropdownMenuItem(value: 'pasif',     child: Text('Pasif')),
                DropdownMenuItem(value: 'mezun',     child: Text('Mezun')),
                DropdownMenuItem(value: 'ayrildi',   child: Text('Ayrıldı')),
                DropdownMenuItem(value: 'arsiv',     child: Text('Arşiv')),
              ],
              onChanged: (v) => setState(() => _durum = v ?? 'onayli'),
            ),
          ]),
        )),
        // Kaydet
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity, height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _navy, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                Navigator.pop(context);
                widget.onKaydet({
                  'ad'          : _adCtrl.text.trim(),
                  'okul'        : _okulCtrl.text.trim(),
                  'sinif'       : _sinifCtrl.text.trim(),
                  'veliTel'     : _telCtrl.text.trim(),
                  'anneTelefon' : _telCtrl.text.trim(),
                  'adres'       : _adresCtrl.text.trim(),
                  'sabahAdres'  : _adresCtrl.text.trim(),
                  'surucuId'    : _surucuId,
                  'soforId'     : _surucuId,
                  'servisId'    : _servisId ?? '',
                  'projeId'     : _projeId ?? '',
                  'durum'       : _durum,
                  'sabahKullan' : _sabahKullan,
                  'aksamKullan' : _aksamKullan,
                  'morningEnabled': _sabahKullan,
                  'eveningEnabled': _aksamKullan,
                });
              },
              icon: const Icon(Icons.save_outlined, size: 16),
              label: const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ]),
    ),
  );

  Widget _infoBant(String label, String deger, IconData ikon, Color renk) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
            color: renk.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: renk.withValues(alpha: 0.2))),
        child: Row(children: [
          Icon(ikon, size: 14, color: renk),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(fontSize: 12, color: renk, fontWeight: FontWeight.bold)),
          Expanded(child: Text(deger, style: TextStyle(fontSize: 12, color: renk))),
        ]),
      );
}

class _Alan extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData ikon;
  final TextInputType tip;
  const _Alan(this.ctrl, this.label, this.ikon,
      {this.tip = TextInputType.text});
  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl, keyboardType: tip,
    decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(ikon, color: const Color(0xFF1a3a6b), size: 18),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
  );
}