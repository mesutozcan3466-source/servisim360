// â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
// â•‘  DOSYA: lib/screens/web_soforler.dart
// â•‘  PROJE: servisim360
// â•‘  WEB: ÅofÃ¶r listesi + Ekle formu
// â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/session_service.dart';

class WebSoforler extends StatefulWidget {
  final String firmaId;
  final String projeId;
  const WebSoforler({super.key, this.firmaId = '', this.projeId = ''});
  @override
  State<WebSoforler> createState() => _WebSoforlerState();
}

class _WebSoforlerState extends State<WebSoforler> {
  static const _navy   = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);

  List<Map<String, dynamic>> _soforler    = [];
  List<Map<String, dynamic>> _filtreliSof = [];
  List<Map<String, dynamic>> _projeler    = [];
  List<Map<String, dynamic>> _servisler   = [];
  bool _yukleniyor = true;
  bool _formAcik   = false;
  final _aramaCtrl = TextEditingController();

  // Form controller'larÄ±
  final _adCtrl       = TextEditingController();
  final _telCtrl      = TextEditingController();
  final _plakaCtrl    = TextEditingController();
  final _kapasiteCtrl = TextEditingController();
  final _modelCtrl    = TextEditingController();
  final _kulAdiCtrl   = TextEditingController();
  final _sifreCtrl    = TextEditingController();
  // Belge alanları
  final _tcCtrl       = TextEditingController();
  final _ehliyetCtrl  = TextEditingController();
  final _srcCtrl      = TextEditingController();
  final _psikoCtrl    = TextEditingController();
  final _adresCtrl2   = TextEditingController();
  final _notCtrl      = TextEditingController();
  String _durumFiltre = 'tumu';
  String? _seciliProjeId;
  String  _servisTuru = 'okul';
  bool    _aktif      = true;
  bool    _soforKayitYuk = false;

  @override
  void initState() { super.initState(); _yukle(); }

  @override
  void dispose() {
    _aramaCtrl.dispose(); _adCtrl.dispose(); _telCtrl.dispose();
    _plakaCtrl.dispose(); _kapasiteCtrl.dispose(); _modelCtrl.dispose();
    _kulAdiCtrl.dispose(); _sifreCtrl.dispose();
    _tcCtrl.dispose(); _ehliyetCtrl.dispose(); _srcCtrl.dispose();
    _psikoCtrl.dispose(); _adresCtrl2.dispose(); _notCtrl.dispose();
    super.dispose();
  }

  String get _firmaId => widget.firmaId;

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    final fId = _firmaId.isNotEmpty
        ? _firmaId
        : await SessionService.instance.firmaIdAl() ?? '';
    if (fId.isEmpty) { if (mounted) setState(() => _yukleniyor = false); return; }

    try {
      // ÅofÃ¶rler
      final sSnap = await FirebaseFirestore.instance
          .collection('drivers')
          .where('firmaId', isEqualTo: fId)
          .orderBy('ad').get();
      _soforler = sSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      for (final s in _soforler) {
        try {
          final c = await FirebaseFirestore.instance
              .collection('students')
              .where('surucuId', isEqualTo: s['id'])
              .count().get();
          s['ogrenciSayi'] = c.count ?? 0;
        } catch (_) { s['ogrenciSayi'] = 0; }
      }

      // Projeler
      final pSnap = await FirebaseFirestore.instance
          .collection('projects')
          .where('firmaId', isEqualTo: fId)
          .where('aktif', isEqualTo: true).get();
      _projeler = pSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      if (_seciliProjeId == null && _projeler.isNotEmpty) {
        _seciliProjeId = null; // boÅŸta olarak baÅŸla
      }
    } catch (e) { debugPrint('WebSoforler hata: $e'); }

    // Servisleri yukle
    try {
      final srvSnap = await FirebaseFirestore.instance
          .collection('services')
          .where('firmaId', isEqualTo: _firmaId.isNotEmpty ? _firmaId : await SessionService.instance.firmaIdAl() ?? '')
          .get();
      _servisler = srvSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (_) {}

    _filtrele();
    if (mounted) setState(() => _yukleniyor = false);
  }

  void _filtrele() {
    final ara = _aramaCtrl.text.toLowerCase();
    setState(() {
      _filtreliSof = ara.isEmpty ? List.from(_soforler)
          : _soforler.where((s) =>
      (s['ad']       ?? '').toString().toLowerCase().contains(ara) ||
          (s['telefon']  ?? '').toString().contains(ara) ||
          (s['aracPlaka']?? '').toString().toLowerCase().contains(ara)
      ).toList();
    });
  }

  Future<void> _soforKaydet() async {
    if (_adCtrl.text.trim().isEmpty)     { _snack('Ad zorunlu!');            return; }
    if (_telCtrl.text.trim().isEmpty)    { _snack('Telefon zorunlu!');       return; }
    if (_plakaCtrl.text.trim().isEmpty)  { _snack('Plaka zorunlu!');         return; }
    if (_kulAdiCtrl.text.trim().isEmpty) { _snack('KullanÄ±cÄ± adÄ± zorunlu!'); return; }
    if (_sifreCtrl.text.trim().isEmpty)  { _snack('Åifre zorunlu!');         return; }

    setState(() => _soforKayitYuk = true);
    try {
      final fId = _firmaId.isNotEmpty
          ? _firmaId
          : await SessionService.instance.firmaIdAl() ?? '';

      // KullanÄ±cÄ± adÄ± kontrolÃ¼
      final kKont = await FirebaseFirestore.instance
          .collection('drivers')
          .where('kullaniciAdi', isEqualTo: _kulAdiCtrl.text.trim())
          .get();
      if (kKont.docs.isNotEmpty) {
        _snack('KullanÄ±cÄ± adÄ± zaten kullanÄ±lÄ±yor!');
        setState(() => _soforKayitYuk = false);
        return;
      }

      final now = FieldValue.serverTimestamp();
      final ref = await FirebaseFirestore.instance.collection('drivers').add({
        'adSoyad'       : _adCtrl.text.trim(),
        'ad'            : _adCtrl.text.trim(),
        'telefon'       : _telCtrl.text.trim(),
        'plaka'         : _plakaCtrl.text.trim(),
        'aracPlaka'     : _plakaCtrl.text.trim(),
        'aracKapasitesi': _kapasiteCtrl.text.trim(),
        'aracModeli'    : _modelCtrl.text.trim(),
        'kullaniciAdi'  : _kulAdiCtrl.text.trim(),
        'geciciSifre'   : _sifreCtrl.text.trim(),
        'aktif'         : _aktif,
        'aktifMi'       : _aktif,
        'firmaId'       : fId,
        'projeId'       : _seciliProjeId ?? '',
        'servisTuru'    : _servisTuru,
        'rol'           : 'sofor',
        'durum'         : _seciliProjeId != null ? 'projeye_dahil' : 'bosta',
        'servisAktif'   : false,
        'tc'            : _tcCtrl.text.trim(),
        'ehliyetNo'     : _ehliyetCtrl.text.trim(),
        'srcBelge'      : _srcCtrl.text.trim(),
        'psikoteknik'   : _psikoCtrl.text.trim(),
        'adres'         : _adresCtrl2.text.trim(),
        'not'           : _notCtrl.text.trim(),
        'toplamServis'  : 0,
        'aktifGorev'    : 0,
        'olusturma'     : now,
        'createdAt'     : now,
      });

      await FirebaseFirestore.instance.collection('kullanicilar').doc(ref.id).set({
        'ad'          : _adCtrl.text.trim(),
        'telefon'     : _telCtrl.text.trim(),
        'kullaniciAdi': _kulAdiCtrl.text.trim(),
        'sifre'       : _sifreCtrl.text.trim(),
        'rol'         : 'sofor',
        'firmaId'     : fId,
        'projeId'     : _seciliProjeId ?? '',
        'driverId'    : ref.id,
        'aktif'       : _aktif,
        'olusturma'   : now,
      });

      _adCtrl.clear(); _telCtrl.clear(); _plakaCtrl.clear();
      _kapasiteCtrl.clear(); _modelCtrl.clear();
      _kulAdiCtrl.clear(); _sifreCtrl.clear();
      setState(() { _formAcik = false; _soforKayitYuk = false; });
      _yukle();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('ÅofÃ¶r kaydedildi!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating));
    } catch (e) {
      _snack('Hata: $e');
      setState(() => _soforKayitYuk = false);
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m), backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating));
  }

  Widget _inp(TextEditingController c, String label, IconData icon,
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

  // â”€â”€ Form paneli â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _formPaneli() {
    return Container(
      width: 340,
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(right: BorderSide(color: Color(0xFFEEEEEE)))),
      child: Column(children: [
        // BaÅŸlÄ±k
        Container(
          padding: const EdgeInsets.all(16),
          color: _navy,
          child: Row(children: [
            const Icon(Icons.person_add_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            const Expanded(child: Text('ÅofÃ¶r Ekle',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                onPressed: () => setState(() => _formAcik = false)),
          ]),
        ),

        // Form alanlarÄ±
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Proje
            if (_projeler.isNotEmpty) ...[
              const Text('Proje (opsiyonel)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _navy)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String?>(
                value: _seciliProjeId,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.folder_outlined, size: 16, color: _navy),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('BoÅŸta ekle')),
                  ..._projeler.map((p) => DropdownMenuItem<String?>(
                      value: p['id'] as String,
                      child: Text(p['projeAd'] ?? ''))),
                ],
                onChanged: (v) => setState(() => _seciliProjeId = v),
              ),
              const SizedBox(height: 14),
            ],

            // ÅofÃ¶r bilgileri
            const Text('ÅofÃ¶r Bilgileri',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _navy)),
            const SizedBox(height: 8),
            _inp(_adCtrl, 'Ad Soyad *', Icons.person_outlined),
            const SizedBox(height: 8),
            _inp(_telCtrl, 'Telefon *', Icons.phone_outlined, tip: TextInputType.phone),
            const SizedBox(height: 8),
            _inp(_plakaCtrl, 'AraÃ§ PlakasÄ± *', Icons.directions_bus_outlined),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _inp(_kapasiteCtrl, 'Kapasite',
                  Icons.people_outlined, tip: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: _inp(_modelCtrl, 'AraÃ§ Modeli',
                  Icons.directions_car_outlined)),
            ]),
            const SizedBox(height: 14),

            // GiriÅŸ bilgileri
            const Text('GiriÅŸ Bilgileri',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _navy)),
            const SizedBox(height: 4),
            const Text('ÅofÃ¶r bu bilgilerle uygulamaya giriÅŸ yapar',
                style: TextStyle(color: Colors.grey, fontSize: 11)),
            const SizedBox(height: 8),
            _inp(_kulAdiCtrl, 'KullanÄ±cÄ± AdÄ± *', Icons.account_circle_outlined),
            const SizedBox(height: 8),
            _inp(_sifreCtrl, 'GeÃ§ici Åifre *', Icons.key_outlined),
            const SizedBox(height: 14),

            // Servis tÃ¼rÃ¼
            const Text('Servis TÃ¼rÃ¼',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _navy)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6,
                children: ['okul', 'kolej', 'personel', 'sabah', 'aksam'].map((t) {
                  final sec = _servisTuru == t;
                  return GestureDetector(
                    onTap: () => setState(() => _servisTuru = t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: sec ? _navy : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: sec ? _navy : Colors.grey.shade300)),
                      child: Text(t[0].toUpperCase() + t.substring(1),
                          style: TextStyle(
                              color: sec ? Colors.white : Colors.grey,
                              fontSize: 11,
                              fontWeight: sec ? FontWeight.bold : FontWeight.normal)),
                    ),
                  );
                }).toList()),
            const SizedBox(height: 12),

            // Aktif
            Row(children: [
              const Text('Aktif', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              Switch(
                value: _aktif,
                activeColor: Colors.green,
                onChanged: (v) => setState(() => _aktif = v),
              ),
            ]),
          ]),
        )),

        // Kaydet butonu
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _navy, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              onPressed: _soforKayitYuk ? null : _soforKaydet,
              icon: _soforKayitYuk
                  ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_rounded),
              label: Text(_soforKayitYuk ? 'Kaydediliyor...' : 'ÅofÃ¶rÃ¼ Kaydet',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ]),
    );
  }

  // â”€â”€ Liste paneli â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _listePaneli() {
    return Column(children: [
      // Ãœst bar
      Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: Row(children: [
          Expanded(child: TextField(
            controller: _aramaCtrl,
            decoration: InputDecoration(
              hintText: 'ÅofÃ¶r ara...',
              prefixIcon: const Icon(Icons.search, color: _navy, size: 18),
              filled: true, fillColor: const Color(0xFFF5F7FA),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none),
              isDense: true,
            ),
            onChanged: (_) => _filtrele(),
          )),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _orange, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => setState(() => _formAcik = !_formAcik),
            icon: Icon(_formAcik ? Icons.close : Icons.person_add_rounded, size: 18),
            label: Text(_formAcik ? 'Kapat' : 'ÅofÃ¶r Ekle',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _navy, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pushNamed(context, '/gruplama'),
            icon: const Icon(Icons.add_road_outlined, size: 18),
            label: const Text('Rota OluÅŸtur',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ]),
      ),

      // SayaÃ§
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        color: const Color(0xFFF5F7FA),
        child: Row(children: [
          Text('${_filtreliSof.length} ÅŸofÃ¶r',
              style: const TextStyle(color: _navy, fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(width: 16),
          Container(width: 8, height: 8,
              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text('${_soforler.where((s) => s['servisAktif'] == true).length} aktif serviste',
              style: const TextStyle(color: Colors.green, fontSize: 12)),
          const Spacer(),
          IconButton(
              icon: const Icon(Icons.refresh_outlined, size: 18, color: _navy),
              onPressed: _yukle, tooltip: 'Yenile'),
        ]),
      ),

      // ── Filtre Butonları ──────────────────────────────────────
      SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(children: [
            for (final f in [
              ('tumu',   'Tum Soforler'),
              ('aktif',  'Aktif'),
              ('bosta',  'Bosta'),
              ('projede','Projede'),
              ('izinli', 'Izinli'),
            ])
              GestureDetector(
                  onTap: () {
                    setState(() => _durumFiltre = f.$1);
                    _filtrele();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                        color: _durumFiltre == f.$1 ? _navy : Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _durumFiltre == f.$1 ? _navy : Colors.grey.shade200)),
                    child: Text(f.$2, style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: _durumFiltre == f.$1 ? Colors.white : Colors.grey[700])),
                  )),
          ])),

      // Kartlar
      Expanded(child: _yukleniyor
          ? const Center(child: CircularProgressIndicator(color: _navy))
          : _filtreliSof.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.directions_bus_outlined, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 12),
        Text('ÅofÃ¶r bulunamadÄ±',
            style: TextStyle(color: Colors.grey[400], fontSize: 16)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: _orange,
                foregroundColor: Colors.white),
            onPressed: () => setState(() => _formAcik = true),
            icon: const Icon(Icons.add),
            label: const Text('Ä°lk ÅofÃ¶rÃ¼ Ekle')),
      ]))
          : GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 340, mainAxisExtent: 210,
          crossAxisSpacing: 12, mainAxisSpacing: 12,
        ),
        itemCount: _filtreliSof.length,
        itemBuilder: (_, i) => _SoforKarti(
          sofor: _filtreliSof[i],
          onDuzenle: () => _soforDuzenleDialog(_filtreliSof[i]),
          onRota: () => Navigator.pushNamed(context, '/gruplama'),
        ),
      )),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_formAcik) _formPaneli(),
      Expanded(child: _listePaneli()),
    ]);
  }
  void _soforDuzenleDialog(Map<String, dynamic> sofor) {
    final soforId     = sofor['id'] as String;
    final adCtrl      = TextEditingController(text: sofor['ad'] ?? sofor['adSoyad'] ?? '');
    final telCtrl     = TextEditingController(text: sofor['telefon'] ?? '');
    final plakaCtrl   = TextEditingController(text: sofor['aracPlaka'] ?? sofor['plaka'] ?? '');
    final kapCtrl     = TextEditingController(text: sofor['aracKapasitesi']?.toString() ?? '17');
    final kulAdiCtrl  = TextEditingController(text: sofor['kullaniciAdi'] ?? '');
    final sifreCtrl   = TextEditingController(text: sofor['geciciSifre'] ?? '');
    final sabahCtrl   = TextEditingController(text: sofor['sabahSaati'] ?? '');
    final aksamCtrl   = TextEditingController(text: sofor['aksamSaati'] ?? '');
    final tcCtrl      = TextEditingController(text: sofor['tc'] ?? '');
    final ehlCtrl     = TextEditingController(text: sofor['ehliyetNo'] ?? '');
    final srcCtrl     = TextEditingController(text: sofor['srcBelge'] ?? '');
    final adresCtrl   = TextEditingController(text: sofor['adres'] ?? '');
    String? secProjeId = sofor['projeId']?.toString().isNotEmpty == true ? sofor['projeId'] : null;
    String? secServisId= sofor['servisId']?.toString().isNotEmpty == true ? sofor['servisId'] : null;
    bool   aktif       = sofor['aktif'] == true || sofor['aktifMi'] == true;
    bool   kaydediliyor= false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: EdgeInsets.zero,
          content: SizedBox(
            width: 500,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Baslik
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                    color: _navy,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                child: Row(children: [
                  CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      child: Text(
                          (adCtrl.text.isNotEmpty ? adCtrl.text[0] : 'S').toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                      adCtrl.text.isNotEmpty ? adCtrl.text : 'Sofor Duzenle',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints()),
                ]),
              ),
              // Form
              Flexible(child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  // Kisisel
                  Row(children: [
                    Expanded(child: _inp(adCtrl,    'Ad Soyad *',   Icons.person_outlined)),
                    const SizedBox(width: 10),
                    Expanded(child: _inp(telCtrl,   'Telefon',      Icons.phone_outlined)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _inp(plakaCtrl, 'Arac Plakasi', Icons.directions_car_outlined)),
                    const SizedBox(width: 10),
                    Expanded(child: _inp(kapCtrl,   'Kapasite',     Icons.people_outlined)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _inp(kulAdiCtrl,'Kullanici Adi',Icons.account_circle_outlined)),
                    const SizedBox(width: 10),
                    Expanded(child: _inp(sifreCtrl, 'Gecici Sifre', Icons.key_outlined)),
                  ]),
                  const SizedBox(height: 14),
                  // Belgeler
                  const Align(alignment: Alignment.centerLeft,
                      child: Text('Belgeler', style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13, color: _navy))),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _inp(tcCtrl,   'TC Kimlik No', Icons.badge_outlined)),
                    const SizedBox(width: 10),
                    Expanded(child: _inp(ehlCtrl,  'Ehliyet No',  Icons.drive_eta_outlined)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _inp(srcCtrl,  'SRC Belge',   Icons.assignment_outlined)),
                    const SizedBox(width: 10),
                    Expanded(child: _inp(adresCtrl,'Adres',       Icons.home_outlined)),
                  ]),
                  const SizedBox(height: 14),
                  // Proje & Servis
                  const Align(alignment: Alignment.centerLeft,
                      child: Text('Proje & Servis', style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13, color: _navy))),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    value: secProjeId,
                    decoration: const InputDecoration(
                        labelText: 'Proje',
                        prefixIcon: Icon(Icons.folder_outlined, size: 18, color: _navy),
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                        isDense: true),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Proje Sec...')),
                      ..._projeler.map((p) => DropdownMenuItem<String?>(
                          value: p['id'] as String,
                          child: Text(p['projeAd'] ?? p['ad'] ?? ''))),
                    ],
                    onChanged: (v) => setS(() { secProjeId = v; secServisId = null; }),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    value: secServisId,
                    decoration: const InputDecoration(
                        labelText: 'Bagli Servis',
                        prefixIcon: Icon(Icons.directions_bus_outlined, size: 18, color: _navy),
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                        isDense: true),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Servis Sec...')),
                      ..._servisler
                          .where((s) => secProjeId == null || s['projeId'] == secProjeId)
                          .map((s) => DropdownMenuItem<String?>(
                          value: s['id'] as String,
                          child: Text(s['ad'] ?? s['servisAdi'] ?? 'Servis'))),
                    ],
                    onChanged: (v) => setS(() => secServisId = v),
                  ),
                  const SizedBox(height: 14),
                  // Servis saatleri
                  const Align(alignment: Alignment.centerLeft,
                      child: Text('Servis Saatleri', style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13, color: _navy))),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _inp(sabahCtrl, 'Sabah (07:30)', Icons.wb_sunny_outlined)),
                    const SizedBox(width: 10),
                    Expanded(child: _inp(aksamCtrl, 'Aksam (16:30)', Icons.nights_stay_outlined)),
                  ]),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Icon(Icons.toggle_on_outlined, size: 18, color: _navy),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('Aktif',
                          style: TextStyle(fontWeight: FontWeight.w600))),
                      Switch(value: aktif, activeColor: Colors.green,
                          onChanged: (v) => setS(() => aktif = v)),
                    ]),
                  ),
                ]),
              )),
              // Kaydet
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Iptal'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _navy, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: kaydediliyor ? null : () async {
                      if (adCtrl.text.trim().isEmpty) return;
                      setS(() => kaydediliyor = true);
                      try {
                        final secilenServis = _servisler.firstWhere(
                                (s) => s['id'] == secServisId, orElse: () => {});
                        final secilenProje  = _projeler.firstWhere(
                                (p) => p['id'] == secProjeId, orElse: () => {});
                        await FirebaseFirestore.instance
                            .collection('drivers').doc(soforId).update({
                          'ad':          adCtrl.text.trim(),
                          'adSoyad':     adCtrl.text.trim(),
                          'telefon':     telCtrl.text.trim(),
                          'aracPlaka':   plakaCtrl.text.trim(),
                          'plaka':       plakaCtrl.text.trim(),
                          'aracKapasitesi': kapCtrl.text.trim(),
                          'kullaniciAdi':kulAdiCtrl.text.trim(),
                          'geciciSifre': sifreCtrl.text.trim(),
                          'sabahSaati':  sabahCtrl.text.trim(),
                          'aksamSaati':  aksamCtrl.text.trim(),
                          'tc':          tcCtrl.text.trim(),
                          'ehliyetNo':   ehlCtrl.text.trim(),
                          'srcBelge':    srcCtrl.text.trim(),
                          'adres':       adresCtrl.text.trim(),
                          'projeId':     secProjeId ?? '',
                          'projeAd':     secilenProje['projeAd'] ?? '',
                          'servisId':    secServisId ?? '',
                          'servisAd':    secilenServis['ad'] ?? '',
                          'aktif':       aktif,
                          'aktifMi':     aktif,
                          'durum':       secProjeId != null ? 'projeye_dahil' : 'bosta',
                          'updatedAt':   FieldValue.serverTimestamp(),
                        });
                        // kullanicilar koleksiyonunu güncelle
                        await FirebaseFirestore.instance
                            .collection('kullanicilar').doc(soforId).set({
                          'ad':          adCtrl.text.trim(),
                          'kullaniciAdi':kulAdiCtrl.text.trim(),
                          'projeId':     secProjeId ?? '',
                          'aktif':       aktif,
                        }, SetOptions(merge: true));
                        if (ctx.mounted) Navigator.pop(ctx);
                        _yukle();
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Sofor guncellendi'),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating));
                      } catch (e) {
                        setS(() => kaydediliyor = false);
                        _snack('Hata: \$e');
                      }
                    },
                    icon: kaydediliyor
                        ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save_outlined, size: 16),
                    label: Text(kaydediliyor ? 'Kaydediliyor...' : 'Guncelle',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  )),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

}

class _SoforKarti extends StatelessWidget {
  final Map<String, dynamic> sofor;
  final VoidCallback onDuzenle, onRota;
  static const _navy = Color(0xFF1a3a6b);

  const _SoforKarti({
    required this.sofor,
    required this.onDuzenle,
    required this.onRota,
  });

  @override
  Widget build(BuildContext context) {
    final aktif   = sofor['servisAktif'] == true;
    final ogrSayi = sofor['ogrenciSayi'] as int? ?? 0;
    final hiz     = (sofor['hiz'] as num? ?? 0).toStringAsFixed(0);
    final ad      = sofor['ad'] as String? ?? 'ÅofÃ¶r';
    final plaka   = sofor['aracPlaka'] ?? sofor['plaka'] ?? '-';
    final tel     = sofor['telefon'] as String? ?? '-';
    final durum   = sofor['durum'] as String? ?? 'bosta';

    Color durumRenk;
    String durumAd;
    switch (durum) {
      case 'aktif_gorevde': durumRenk = Colors.green;  durumAd = 'GÃ¶revde'; break;
      case 'projeye_dahil': durumRenk = Colors.blue;   durumAd = 'Projede'; break;
      case 'pasif':         durumRenk = Colors.red;    durumAd = 'Pasif';   break;
      default:              durumRenk = Colors.orange; durumAd = 'BoÅŸta';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: aktif ? Border.all(color: Colors.green.withOpacity(0.4), width: 1.5) : null,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: aktif
                ? Colors.green.withOpacity(0.15)
                : _navy.withOpacity(0.1),
            child: Text(ad.isNotEmpty ? ad[0].toUpperCase() : 'Å',
                style: TextStyle(
                    color: aktif ? Colors.green : _navy,
                    fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ad, style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14, color: _navy),
                overflow: TextOverflow.ellipsis),
            Text(plaka.toString(),
                style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: durumRenk.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Text(durumAd, style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.bold, color: durumRenk)),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _mini(Icons.people_outline, '$ogrSayi Ã¶ÄŸr', Colors.blue),
          const SizedBox(width: 12),
          _mini(Icons.phone_outlined, tel, Colors.grey),
          if (aktif) ...[
            const SizedBox(width: 12),
            _mini(Icons.speed_outlined, '$hiz km/s', Colors.green),
          ],
        ]),
        const Spacer(),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                foregroundColor: _navy,
                side: const BorderSide(color: _navy),
                padding: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            icon: const Icon(Icons.edit_outlined, size: 14),
            label: const Text('DÃ¼zenle', style: TextStyle(fontSize: 11)),
            onPressed: onDuzenle,
          )),
          const SizedBox(width: 8),
          Expanded(child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _navy, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            icon: const Icon(Icons.route_outlined, size: 14),
            label: const Text('Rota', style: TextStyle(fontSize: 11)),
            onPressed: onRota,
          )),
        ]),
      ]),
    );
  }

  Widget _mini(IconData icon, String text, Color renk) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: renk),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11, color: renk)),
      ]);
}

