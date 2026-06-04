import 'package:flutter/material.dart';
import 'yardim_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/session_service.dart';
import '../services/kayit_link_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// VELİ BAŞVURU FORM EKRANI
// İki mod:
//   1. Deep link → linkId + kod parametresiyle gelir, firmaId otomatik
//   2. Firma kodu → veli manuel girer
// ═══════════════════════════════════════════════════════════════════════════

class VeliBasvuruFormScreen extends StatefulWidget {
  // Deep linkten gelen parametreler (opsiyonel)
  final String? linkId;
  final String? linkKod;

  const VeliBasvuruFormScreen({
    super.key,
    this.linkId,
    this.linkKod,
  });

  @override
  State<VeliBasvuruFormScreen> createState() => _VeliBasvuruFormScreenState();
}

class _VeliBasvuruFormScreenState extends State<VeliBasvuruFormScreen> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  final _formKey      = GlobalKey<FormState>();
  final _adCtrl       = TextEditingController();
  final _soyadCtrl    = TextEditingController();
  final _telefonCtrl  = TextEditingController();
  final _ogrAdCtrl    = TextEditingController();
  final _ogrSoyadCtrl = TextEditingController();
  final _sinifCtrl    = TextEditingController();
  final _adresCtrl    = TextEditingController();
  final _firmaKodCtrl = TextEditingController();

  bool    _yukleniyor   = false;
  bool    _gonderildi   = false;
  bool    _kodDogrulandi = false;
  String? _firmaId;
  String? _firmaAdi;
  String? _hata;

  // Mod: 'deeplink' veya 'firmakod'
  String _mod = 'firmakod';

  @override
  void initState() {
    super.initState();
    _baslat();
  }

  @override
  void dispose() {
    _adCtrl.dispose(); _soyadCtrl.dispose(); _telefonCtrl.dispose();
    _ogrAdCtrl.dispose(); _ogrSoyadCtrl.dispose();
    _sinifCtrl.dispose(); _adresCtrl.dispose();
    _firmaKodCtrl.dispose();
    super.dispose();
  }

  Future<void> _baslat() async {
    // Deep link parametresi varsa otomatik dogrula
    if (widget.linkId != null && widget.linkKod != null) {
      _mod = 'deeplink';
      setState(() => _yukleniyor = true);
      await _deepLinkDogrula();
      setState(() => _yukleniyor = false);
    }
  }

  // Deep link ile gelen linkId + kod dogrulama
  Future<void> _deepLinkDogrula() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('kayit_linkleri')
          .doc(widget.linkId)
          .get();

      if (!snap.exists) {
        setState(() => _hata = 'Gecersiz veya suresi dolmus link.');
        return;
      }

      final data  = snap.data()!;
      final aktif = data['aktif'] as bool? ?? false;
      final bitis = (data['gecerlilikBitis'] as Timestamp?)?.toDate();
      final kod   = data['kod'] as String?;

      if (!aktif || (bitis != null && bitis.isBefore(DateTime.now()))) {
        setState(() => _hata = 'Bu linkin suresi dolmus.');
        return;
      }

      if (kod != widget.linkKod) {
        setState(() => _hata = 'Link kodu eslesmiyor.');
        return;
      }

      // Firma bilgisini al
      final firma = await FirebaseFirestore.instance
          .collection('firms')
          .doc(data['firmaId'] as String)
          .get();

      // Kullanim sayisini artir
      await KayitLinkService.kullanimArtir(widget.linkId!);

      setState(() {
        _firmaId      = data['firmaId'] as String;
        _firmaAdi     = firma.data()?['firmaAdi'] as String? ?? 'Firma';
        _kodDogrulandi = true;
      });
    } catch (e) {
      setState(() => _hata = 'Dogrulama hatasi: $e');
    }
  }

  // Manuel firma kodu dogrulama
  Future<void> _firmaKoduDogrula() async {
    final kod = _firmaKodCtrl.text.trim().toUpperCase();
    if (kod.isEmpty) return;

    setState(() { _yukleniyor = true; _hata = null; });

    try {
      final firmaId = await KayitLinkService.koduDogrula(kod);
      if (firmaId == null) {
        setState(() => _hata = 'Gecersiz veya suresi dolmus firma kodu.');
        return;
      }

      final firma = await FirebaseFirestore.instance
          .collection('firms')
          .doc(firmaId)
          .get();

      setState(() {
        _firmaId       = firmaId;
        _firmaAdi      = firma.data()?['firmaAdi'] as String? ?? 'Firma';
        _kodDogrulandi = true;
      });
    } catch (e) {
      setState(() => _hata = 'Hata: $e');
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _gonder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_firmaId == null) {
      setState(() => _hata = 'Firma bilgisi bulunamadi.');
      return;
    }

    setState(() => _yukleniyor = true);

    try {
      final uid   = FirebaseAuth.instance.currentUser?.uid;
      final email = FirebaseAuth.instance.currentUser?.email ?? '';

      await FirebaseFirestore.instance.collection('parents').add({
        'uid':           uid,
        'email':         email,
        'ad':            _adCtrl.text.trim(),
        'soyad':         _soyadCtrl.text.trim(),
        'telefon':       _telefonCtrl.text.trim(),
        'ogrenciAd':     _ogrAdCtrl.text.trim(),
        'ogrenciSoyad':  _ogrSoyadCtrl.text.trim(),
        'sinif':         _sinifCtrl.text.trim(),
        'adres':         _adresCtrl.text.trim(),
        'firmaId':       _firmaId,
        'firmaAdi':      _firmaAdi,
        'durum':         'beklemede',
        'kayitModu':     _mod,
        'basvuruTarihi': FieldValue.serverTimestamp(),
      });

      if (mounted) setState(() => _gonderildi = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        actions: [YardimButonu(ekranAdi: 'Kayitlar')],
        title: const Text('Servis Kayit Formu'),
      ),
      body: _yukleniyor && !_kodDogrulandi
          ? const Center(child: CircularProgressIndicator())
          : _gonderildi
          ? _basariEkrani()
          : _hata != null && _mod == 'deeplink'
          ? _hataEkrani()
          : _kodDogrulandi
          ? _form()
          : _kodGirisEkrani(),
    );
  }

  // ── Firma kodu giriş ekranı ──────────────────────────────────────────────
  Widget _kodGirisEkrani() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 80, height: 80,
            decoration: const BoxDecoration(
              color: Color(0xFF1a3a6b),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('S', style: TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.bold,
              )),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Servisim360\'a Hosgeldiniz',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0d1f3c),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Kayit olmak icin servis firmanizdan\naldiginiz kodu girin.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], height: 1.5),
          ),
          const SizedBox(height: 40),

          // Firma kodu girisi
          TextField(
            controller: _firmaKodCtrl,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
            ),
            decoration: InputDecoration(
              hintText: 'XXXXXXXX',
              hintStyle: TextStyle(
                color: Colors.grey[400],
                letterSpacing: 4,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _navy, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 18),
            ),
            onChanged: (v) {
              if (_hata != null) setState(() => _hata = null);
            },
          ),

          if (_hata != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_hata!,
                    style: const TextStyle(color: Colors.red, fontSize: 13))),
              ]),
            ),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _yukleniyor ? null : _firmaKoduDogrula,
              child: _yukleniyor
                  ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                  : const Text('Devam Et',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Kodu servis firmanizdan veya\nyoneticinizden alabilirsiniz.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  // ── Başvuru formu ────────────────────────────────────────────────────────
  Widget _form() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(children: [

          // Firma bilgisi bandı
          if (_firmaAdi != null)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(children: [
                const Icon(Icons.business, color: Colors.green, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Firma dogrulandi',
                        style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                    Text(_firmaAdi!,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                )),
                const Icon(Icons.check_circle, color: Colors.green),
              ]),
            ),

          _bolumBaslik('Veli Bilgileri', Icons.person_outline),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _alan(_adCtrl, 'Ad', Icons.person_outline)),
            const SizedBox(width: 12),
            Expanded(child: _alan(_soyadCtrl, 'Soyad', Icons.person_outline)),
          ]),
          const SizedBox(height: 12),
          _alan(_telefonCtrl, 'Telefon', Icons.phone_outlined,
              tipi: TextInputType.phone),
          const SizedBox(height: 20),

          _bolumBaslik('Ogrenci Bilgileri', Icons.school_outlined),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _alan(_ogrAdCtrl, 'Ogrenci Adi',
                Icons.face_outlined)),
            const SizedBox(width: 12),
            Expanded(child: _alan(_ogrSoyadCtrl, 'Soyadi',
                Icons.face_outlined)),
          ]),
          const SizedBox(height: 12),
          _alan(_sinifCtrl, 'Sinif (ornek: 3-A)', Icons.class_outlined),
          const SizedBox(height: 12),
          _alan(_adresCtrl, 'Ev Adresi', Icons.home_outlined, satir: 2),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _yukleniyor ? null : _gonder,
              icon: _yukleniyor
                  ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_outlined),
              label: Text(_yukleniyor ? 'Gonderiliyor...' : 'Basvuruyu Gonder',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Başarı ekranı ────────────────────────────────────────────────────────
  Widget _basariEkrani() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.check_circle_outline, color: Colors.green, size: 80),
        const SizedBox(height: 20),
        const Text('Basvurunuz Alindi!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                color: _navy)),
        const SizedBox(height: 12),
        Text(
          'Yoneticiniz basvurunuzu inceledikten sonra\n'
              'hesabiniz aktif edilecektir.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600], height: 1.6),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () =>
              Navigator.pushReplacementNamed(context, '/veli_panel'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _navy,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Ana Sayfaya Don',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ]),
    ),
  );

  // ── Hata ekranı (deep link geçersizse) ──────────────────────────────────
  Widget _hataEkrani() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.link_off, color: Colors.red.shade300, size: 80),
        const SizedBox(height: 20),
        const Text('Gecersiz Link',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                color: Colors.red)),
        const SizedBox(height: 12),
        Text(
          _hata ?? 'Bu link gecersiz veya suresi dolmus.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 32),
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Geri Don'),
        ),
      ]),
    ),
  );

  Widget _bolumBaslik(String baslik, IconData ikon) => Row(children: [
    Icon(ikon, color: _navy, size: 20),
    const SizedBox(width: 8),
    Text(baslik, style: const TextStyle(
        fontSize: 15, fontWeight: FontWeight.bold, color: _navy)),
    const Expanded(child: Divider(indent: 12)),
  ]);

  Widget _alan(
      TextEditingController ctrl,
      String etiket,
      IconData ikon, {
        TextInputType tipi = TextInputType.text,
        int satir = 1,
      }) =>
      TextFormField(
        controller: ctrl,
        keyboardType: tipi,
        maxLines: satir,
        decoration: InputDecoration(
          labelText: etiket,
          prefixIcon: Icon(ikon),
        ),
        validator: (v) =>
        v == null || v.trim().isEmpty ? '$etiket zorunludur' : null,
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// VELİ ONAY EKRANI (Admin panelinde — bekleyen başvuruları onaylar)
// ═══════════════════════════════════════════════════════════════════════════

class VeliOnayScreen extends StatefulWidget {
  const VeliOnayScreen({super.key});

  @override
  State<VeliOnayScreen> createState() => _VeliOnayScreenState();
}

class _VeliOnayScreenState extends State<VeliOnayScreen>
    with SingleTickerProviderStateMixin {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  late final TabController _tabCtrl;
  String? _firmaId;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _yukle();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    _firmaId = await SessionService.instance.firmaldAl();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        actions: [YardimButonu(ekranAdi: 'Kayitlar')],
        title: const Text('Veli Basvurulari'),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: _turuncu,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.hourglass_empty, size: 18), text: 'Bekleyenler'),
            Tab(icon: Icon(Icons.check_circle_outline, size: 18), text: 'Onaylananlar'),
          ],
        ),
      ),
      body: _firmaId == null
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabCtrl,
        children: [
          _BasvuruListesi(
              firmaId: _firmaId!, durum: 'beklemede'),
          _BasvuruListesi(
              firmaId: _firmaId!, durum: 'onaylandi'),
        ],
      ),
    );
  }
}

class _BasvuruListesi extends StatelessWidget {
  final String firmaId;
  final String durum;
  static const _navy = Color(0xFF1a3a6b);

  const _BasvuruListesi({required this.firmaId, required this.durum});

  Future<void> _onayla(BuildContext context, DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;

    // 1. Parent belgesini guncelle
    await doc.reference.update({
      'durum':        'onaylandi',
      'onayTarihi':   FieldValue.serverTimestamp(),
    });

    // 2. Student belgesi olustur
    await FirebaseFirestore.instance.collection('students').add({
      'ad':        data['ogrenciAd'],
      'soyad':     data['ogrenciSoyad'],
      'sinif':     data['sinif'],
      'adres':     data['adres'],
      'veliId':    data['uid'],
      'veliAd':    '${data['ad']} ${data['soyad']}',
      'veliEmail': data['email'],
      'veliTel':   data['telefon'],
      'firmaId':   data['firmaId'],
      'aktif':     true,
      'bindi':     false,
      'kayitTarihi': FieldValue.serverTimestamp(),
    });

    // 3. kullanicilar belgesinde rol = veli yap
    if (data['uid'] != null) {
      await FirebaseFirestore.instance
          .collection('kullanicilar')
          .doc(data['uid'] as String)
          .set({
        'rol':     'veli',
        'firmaId': data['firmaId'],
        'durum':   'aktif',
        'email':   data['email'],
      }, SetOptions(merge: true));
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Basvuru onaylandi, ogrenci olusturuldu'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _reddet(BuildContext context, DocumentSnapshot doc) async {
    await doc.reference.update({
      'durum':      'reddedildi',
      'redTarihi':  FieldValue.serverTimestamp(),
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Basvuru reddedildi'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _detayGoster(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text(
              '${data['ad']} ${data['soyad']}',
              style: const TextStyle(fontSize: 18,
                  fontWeight: FontWeight.bold, color: _navy),
            ),
            const SizedBox(height: 16),
            _DetayRow('Telefon',        data['telefon'] ?? '-'),
            _DetayRow('Email',          data['email'] ?? '-'),
            _DetayRow('Ogrenci',        '${data['ogrenciAd']} ${data['ogrenciSoyad']}'),
            _DetayRow('Sinif',          data['sinif'] ?? '-'),
            _DetayRow('Adres',          data['adres'] ?? '-'),
            _DetayRow('Kayit Modu',     data['kayitModu'] ?? '-'),
            const SizedBox(height: 20),
            if (data['durum'] == 'beklemede')
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _onayla(context, doc);
                    },
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text('Onayla',
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _reddet(context, doc);
                    },
                    icon: const Icon(Icons.close, color: Colors.white),
                    label: const Text('Reddet',
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('parents')
          .where('firmaId', isEqualTo: firmaId)
          .where('durum',   isEqualTo: durum)
          .orderBy('basvuruTarihi', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  durum == 'beklemede'
                      ? Icons.hourglass_empty
                      : Icons.check_circle_outline,
                  size: 64,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 12),
                Text(
                  durum == 'beklemede'
                      ? 'Bekleyen basvuru yok'
                      : 'Onaylanmis basvuru yok',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final tarih =
            (data['basvuruTarihi'] as Timestamp?)?.toDate();
            final tarihStr = tarih != null
                ? '${tarih.day}.${tarih.month}.${tarih.year}'
                : '-';

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: _navy.withValues(alpha: 0.1),
                  child: Text(
                    (data['ad'] as String? ?? 'V')[0].toUpperCase(),
                    style: const TextStyle(
                        color: _navy, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  '${data['ad']} ${data['soyad']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${data['ogrenciAd']} ${data['ogrenciSoyad']} • $tarihStr',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: durum == 'beklemede'
                    ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle,
                          color: Colors.green),
                      onPressed: () => _onayla(context, docs[i]),
                      tooltip: 'Onayla',
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel,
                          color: Colors.red),
                      onPressed: () => _reddet(context, docs[i]),
                      tooltip: 'Reddet',
                    ),
                  ],
                )
                    : const Icon(Icons.check_circle,
                    color: Colors.green),
                onTap: () => _detayGoster(context, docs[i]),
              ),
            );
          },
        );
      },
    );
  }
}

class _DetayRow extends StatelessWidget {
  final String etiket;
  final String deger;
  const _DetayRow(this.etiket, this.deger);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(etiket,
                style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(deger,
                style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
