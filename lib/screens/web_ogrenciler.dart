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
    final projeId = SessionService.instance.aktifProjeld ?? '';
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
                  SizedBox(width: 80, child: Row(children: [
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
    final adCtrl    = TextEditingController();
    final soyadCtrl = TextEditingController();
    final veliCtrl  = TextEditingController();
    final telCtrl   = TextEditingController();
    final adresCtrl = TextEditingController();
    final okulCtrl  = TextEditingController();
    bool yukleniyor = false;

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
                    Expanded(child: _webInp(okulCtrl, 'Okul', Icons.school_outlined)),
                  ]),
                  const SizedBox(height: 8),
                  _webInp(adresCtrl, 'Adres', Icons.location_on_outlined),
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
                          'veliAd'  : veliCtrl.text.trim(),
                          'veliTel' : telCtrl.text.trim(),
                          'aktif'   : true,
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
  static const _navy = Color(0xFF1a3a6b);
  late TextEditingController _adCtrl, _telCtrl, _adresCtrl;
  String _surucuId = '';
  String _durum    = 'onayli';

  @override
  void initState() {
    super.initState();
    _adCtrl    = TextEditingController(text: widget.ogr['ad'] ?? '');
    _telCtrl   = TextEditingController(text: widget.ogr['veliTel'] ?? '');
    _adresCtrl = TextEditingController(text: widget.ogr['adres'] ?? '');
    _surucuId  = (widget.ogr['surucuId'] ?? widget.ogr['soforId'] ?? '').toString();
    _durum     = widget.ogr['durum'] as String? ?? 'onayli';
  }

  @override
  void dispose() {
    _adCtrl.dispose(); _telCtrl.dispose(); _adresCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    title: const Text('Ogrenci Duzenle',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _navy)),
    content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
      _Alan(_adCtrl, 'Ad Soyad', Icons.person_outline),
      const SizedBox(height: 10),
      _Alan(_telCtrl, 'Veli Telefon', Icons.phone_outlined,
          tip: TextInputType.phone),
      const SizedBox(height: 10),
      _Alan(_adresCtrl, 'Adres', Icons.location_on_outlined),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        value: _surucuId.isEmpty ? null : _surucuId,
        decoration: const InputDecoration(
            labelText: 'Servis Atama',
            prefixIcon: Icon(Icons.directions_bus_outlined, color: _navy),
            border: OutlineInputBorder()),
        items: [
          const DropdownMenuItem(value: null, child: Text('Atanmamis')),
          ...widget.soforler.map((s) => DropdownMenuItem(
              value: s['id'] as String,
              child: Text(s['ad'] as String? ?? 'Sofor'))),
        ],
        onChanged: (v) => setState(() => _surucuId = v ?? ''),
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        value: _durum,
        decoration: const InputDecoration(
            labelText: 'Durum',
            prefixIcon: Icon(Icons.verified_outlined, color: _navy),
            border: OutlineInputBorder()),
        items: const [
          DropdownMenuItem(value: 'onayli',     child: Text('Onayli')),
          DropdownMenuItem(value: 'beklemede',  child: Text('Beklemede')),
          DropdownMenuItem(value: 'pasif',      child: Text('Pasif')),
        ],
        onChanged: (v) => setState(() => _durum = v ?? 'onayli'),
      ),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Iptal')),
      ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
        onPressed: () {
          Navigator.pop(context);
          widget.onKaydet({
            'ad':       _adCtrl.text.trim(),
            'veliTel':  _telCtrl.text.trim(),
            'adres':    _adresCtrl.text.trim(),
            'surucuId': _surucuId,
            'soforId':  _surucuId,
            'durum':    _durum,
          });
        },
        child: const Text('Kaydet'),
      ),
    ],
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
