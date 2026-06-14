// â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
// â•‘  DOSYA: lib/screens/web_soforler.dart
// â•‘  PROJE: servisim360
// â•‘  WEB: Sofor listesi + Ekle formu
// â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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

  // Form controller'lari
  final _adCtrl       = TextEditingController();
  final _telCtrl      = TextEditingController();
  final _plakaCtrl    = TextEditingController();
  final _kapasiteCtrl = TextEditingController();
  final _modelCtrl    = TextEditingController();
  final _kulAdiCtrl   = TextEditingController();
  final _sifreCtrl    = TextEditingController();
  // Belge alanlari
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
  int     _tabIndex   = 0;
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
      // Soforler
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
        _seciliProjeId = null; // bosta olarak basla
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
    if (_kulAdiCtrl.text.trim().isEmpty) { _snack('Kullanici adi zorunlu!'); return; }
    if (_sifreCtrl.text.trim().isEmpty)  { _snack('Sifre zorunlu!');         return; }

    setState(() => _soforKayitYuk = true);
    try {
      final fId = _firmaId.isNotEmpty
          ? _firmaId
          : await SessionService.instance.firmaIdAl() ?? '';

      // Kullanici adi kontrolu
      final kKont = await FirebaseFirestore.instance
          .collection('drivers')
          .where('kullaniciAdi', isEqualTo: _kulAdiCtrl.text.trim())
          .get();
      if (kKont.docs.isNotEmpty) {
        _snack('Kullanici adi zaten kullaniliyor!');
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
          content: Text('Sofor kaydedildi!'),
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
        // BaSŸlik
        Container(
          padding: const EdgeInsets.all(16),
          color: _navy,
          child: Row(children: [
            const Icon(Icons.person_add_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            const Expanded(child: Text('Sofor Ekle',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                onPressed: () => setState(() => _formAcik = false)),
          ]),
        ),

        // Form alanlari
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
                  const DropdownMenuItem<String?>(value: null, child: Text('BoSŸta ekle')),
                  ..._projeler.map((p) => DropdownMenuItem<String?>(
                      value: p['id'] as String,
                      child: Text(p['projeAd'] ?? ''))),
                ],
                onChanged: (v) => setState(() => _seciliProjeId = v),
              ),
              const SizedBox(height: 14),
            ],

            // Sofor bilgileri
            const Text('Sofor Bilgileri',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _navy)),
            const SizedBox(height: 8),
            _inp(_adCtrl, 'Ad Soyad *', Icons.person_outlined),
            const SizedBox(height: 8),
            _inp(_telCtrl, 'Telefon *', Icons.phone_outlined, tip: TextInputType.phone),
            const SizedBox(height: 8),
            _inp(_plakaCtrl, 'Arac Plakasi *', Icons.directions_bus_outlined),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _inp(_kapasiteCtrl, 'Kapasite',
                  Icons.people_outlined, tip: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: _inp(_modelCtrl, 'Arac Modeli',
                  Icons.directions_car_outlined)),
            ]),
            const SizedBox(height: 14),

            // GiriSŸ bilgileri
            const Text('GiriSŸ Bilgileri',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _navy)),
            const SizedBox(height: 4),
            const Text('Sofor bu bilgilerle uygulamaya giriSŸ yapar',
                style: TextStyle(color: Colors.grey, fontSize: 11)),
            const SizedBox(height: 8),
            _inp(_kulAdiCtrl, 'Kullanici Adi *', Icons.account_circle_outlined),
            const SizedBox(height: 8),
            _inp(_sifreCtrl, 'Gecici Sifre *', Icons.key_outlined),
            const SizedBox(height: 14),

            // Servis turu
            const Text('Servis Turu',
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
              label: Text(_soforKayitYuk ? 'Kaydediliyor...' : 'Soforu Kaydet',
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
              hintText: 'Sofor ara...',
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
            label: Text(_formAcik ? 'Kapat' : 'Sofor Ekle',
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
            label: const Text('Rota OluSŸtur',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ]),
      ),

      // Sayac
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        color: const Color(0xFFF5F7FA),
        child: Row(children: [
          Text('${_filtreliSof.length} SŸofor',
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

      // ── Filtre Butonlari ──────────────────────────────────────
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
        Text('Sofor bulunamadi',
            style: TextStyle(color: Colors.grey[400], fontSize: 16)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: _orange,
                foregroundColor: Colors.white),
            onPressed: () => setState(() => _formAcik = true),
            icon: const Icon(Icons.add),
            label: const Text('Ilk Soforu Ekle')),
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
          onArsivle: () => _soforArsivle(_filtreliSof[i]),
        ),
      )),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Tab bar
      Container(color: Colors.white, child: Row(children: [
        for (final t in [
          (0, 'Soforler', Icons.person_outlined),
          (1, 'Performans', Icons.bar_chart_outlined),
        ])
          GestureDetector(
            onTap: () => setState(() => _tabIndex = t.$1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(
                      color: _tabIndex == t.$1 ? const Color(0xFFFF8C00) : Colors.transparent,
                      width: 2))),
              child: Row(children: [
                Icon(t.$3, size: 16,
                    color: _tabIndex == t.$1 ? const Color(0xFF1a3a6b) : Colors.grey),
                const SizedBox(width: 6),
                Text(t.$2, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
                    color: _tabIndex == t.$1 ? const Color(0xFF1a3a6b) : Colors.grey)),
              ]),
            ),
          ),
      ])),
      Expanded(child: _tabIndex == 0
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_formAcik) _formPaneli(),
        Expanded(child: _listePaneli()),
      ])
          : _performansPaneli()),
    ]);
  }

  Widget _performansPaneli() {
    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('servis_raporlari')
            .where('firmaId', isEqualTo: widget.firmaId)
            .orderBy('tarih', descending: true).limit(100).snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.bar_chart_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            const Text('Performans raporu yok',
                style: TextStyle(color: Colors.grey, fontSize: 16)),
          ]));
          // Sofor bazli gruplama
          final Map<String, Map<String, dynamic>> soforPerf = {};
          for (final doc in docs) {
            final d = doc.data() as Map<String, dynamic>;
            final soforId = d['soforId'] as String? ?? '';
            if (soforId.isEmpty) continue;
            soforPerf.putIfAbsent(soforId, () => {
              'soforId': soforId, 'toplamServis': 0,
              'toplamOgrenci': 0, 'toplamBindi': 0,
            });
            soforPerf[soforId]!['toplamServis'] =
                (soforPerf[soforId]!['toplamServis'] as int) + 1;
            soforPerf[soforId]!['toplamOgrenci'] =
                (soforPerf[soforId]!['toplamOgrenci'] as int) +
                    ((d['toplamOgrenci'] as int?) ?? 0);
            soforPerf[soforId]!['toplamBindi'] =
                (soforPerf[soforId]!['toplamBindi'] as int) +
                    ((d['bindiler'] as int?) ?? 0);
          }
          return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: soforPerf.length,
              itemBuilder: (_, i) {
                final perf = soforPerf.values.toList()[i];
                final soforData = _soforler.firstWhere(
                        (s) => s['id'] == perf['soforId'], orElse: () => {});
                final toplamS = perf['toplamServis'] as int;
                final toplamO = perf['toplamOgrenci'] as int;
                final toplamB = perf['toplamBindi'] as int;
                final devam = toplamO > 0
                    ? (toplamB / toplamO * 100).round() : 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6)]),
                  child: Row(children: [
                    CircleAvatar(radius: 22,
                        backgroundColor:
                        const Color(0xFF1a3a6b).withValues(alpha: 0.1),
                        child: Text(
                            (soforData['ad'] ?? '?').toString().isNotEmpty
                                ? (soforData['ad'] ?? '?').toString()[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: Color(0xFF1a3a6b),
                                fontWeight: FontWeight.bold, fontSize: 16))),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(soforData['ad']?.toString() ?? 'Sofor',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 6),
                          Row(children: [
                            _perfChip(toplamS.toString() + ' servis',
                                Colors.blue),
                            const SizedBox(width: 6),
                            _perfChip(devam.toString() + '% devam',
                                devam > 90 ? Colors.green
                                    : devam > 70 ? Colors.orange : Colors.red),
                            const SizedBox(width: 6),
                            _perfChip(toplamB.toString() + '/' +
                                toplamO.toString() + ' ogr', Colors.teal),
                          ]),
                        ])),
                  ]),
                );
              });
        });
  }

  Widget _perfChip(String t, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6)),
      child: Text(t,
          style: TextStyle(fontSize: 11, color: c,
              fontWeight: FontWeight.bold)));
  // ── ARSIVLE ────────────────────────────────────────────────────
  Future<void> _soforArsivle(Map<String, dynamic> sofor) async {
    final arsivMi = sofor['arsiv'] == true;
    final onay = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
        title: Text(arsivMi ? 'Arsivden Cikar' : 'Soforii Arsivle'),
        content: Text((sofor['ad'] ?? '') + (arsivMi ? ' arsivden cikarilacak.' : ' arsive tasinacak. Silinmeyecek.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_, false), child: const Text('Iptal')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: arsivMi ? Colors.green : Colors.grey),
              onPressed: () => Navigator.pop(_, true),
              child: Text(arsivMi ? 'Cikar' : 'Arsivle', style: const TextStyle(color: Colors.white))),
        ]));
    if (onay == true) {
      await FirebaseFirestore.instance.collection('drivers').doc(sofor['id']).update({
        'arsiv': !arsivMi,
        'aktif': arsivMi,
        'arsivTarihi': FieldValue.serverTimestamp(),
      });
      _yukle();
    }
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
                  const SizedBox(width: 6),
                  // Sifre yenile
                  IconButton(
                    tooltip: 'Sifre Yenile',
                    style: IconButton.styleFrom(
                        backgroundColor: Colors.blue.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () async {
                      final yeni = 'S${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
                      await FirebaseFirestore.instance.collection('drivers').doc(soforId)
                          .update({'geciciSifre': yeni});
                      await FirebaseFirestore.instance.collection('kullanicilar').doc(soforId)
                          .set({'sifre': yeni}, SetOptions(merge: true));
                      setS(() { sifreCtrl.text = yeni; });
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Yeni sifre: $yeni'),
                          backgroundColor: Colors.blue, behavior: SnackBarBehavior.floating));
                    },
                    icon: const Icon(Icons.key_outlined, color: Colors.blue, size: 18),
                  ),
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
                        // kullanicilar koleksiyonunu guncelle
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
  final VoidCallback onDuzenle, onRota, onArsivle;
  static const _navy = Color(0xFF1a3a6b);

  const _SoforKarti({
    required this.sofor,
    required this.onDuzenle,
    required this.onRota,
    required this.onArsivle,
  });

  @override
  Widget build(BuildContext context) {
    final aktif   = sofor['servisAktif'] == true;
    final ogrSayi = sofor['ogrenciSayi'] as int? ?? 0;
    final hiz     = (sofor['hiz'] as num? ?? 0).toStringAsFixed(0);
    final ad      = sofor['ad'] as String? ?? 'Sofor';
    final plaka   = sofor['aracPlaka'] ?? sofor['plaka'] ?? '-';
    final tel     = sofor['telefon'] as String? ?? '-';
    final durum   = sofor['durum'] as String? ?? 'bosta';

    Color durumRenk;
    String durumAd;
    switch (durum) {
      case 'aktif_gorevde': durumRenk = Colors.green;  durumAd = 'Gorevde'; break;
      case 'projeye_dahil': durumRenk = Colors.blue;   durumAd = 'Projede'; break;
      case 'pasif':         durumRenk = Colors.red;    durumAd = 'Pasif';   break;
      default:              durumRenk = Colors.orange; durumAd = 'BoSŸta';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: aktif ? Border.all(color: Colors.green.withValues(alpha:0.4), width: 1.5) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.06), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: aktif
                ? Colors.green.withValues(alpha:0.15)
                : _navy.withValues(alpha:0.1),
            child: Text(ad.isNotEmpty ? ad[0].toUpperCase() : 'S',
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
                color: durumRenk.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Text(durumAd, style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.bold, color: durumRenk)),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _mini(Icons.people_outline, '$ogrSayi ogr', Colors.blue),
          const SizedBox(width: 12),
          _mini(Icons.phone_outlined, tel, Colors.grey),
          if ((sofor['projeAd'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(width: 12),
            _mini(Icons.folder_outlined, sofor['projeAd'].toString(), Colors.teal),
          ],
          if (aktif) ...[
            const SizedBox(width: 12),
            _mini(Icons.speed_outlined, '$hiz km/s', Colors.green),
          ],
          if (sofor['sonGiris'] is Timestamp) ...[
            const SizedBox(width: 12),
            _mini(Icons.access_time_outlined, () {
              final dt = (sofor['sonGiris'] as Timestamp).toDate();
              return '${dt.day.toString().padLeft(2,'0')}.${dt.month.toString().padLeft(2,'0')}.${dt.year}';
            }(), Colors.grey),
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
            label: const Text('Duzenle', style: TextStyle(fontSize: 11)),
            onPressed: onDuzenle,
          )),
          const SizedBox(width: 8),
          // WhatsApp giris bilgisi gonder
          if ((sofor['telefon'] ?? '').isNotEmpty)
            Expanded(child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                final tel = (sofor['telefon'] as String).replaceAll(RegExp(r'[^0-9]'), '');
                final kul = sofor['kullaniciAdi'] ?? '';
                final sif = sofor['geciciSifre'] ?? '';
                final msg = Uri.encodeComponent(
                    'Servisim360 giris bilgileriniz:%0A'
                        'Kullanici Adi: ' + kul + '%0A'
                        'Sifre: ' + sif + '%0A'
                        'servisim.org.tr');
                final uri = Uri.parse('https://wa.me/90' + tel + '?text=' + msg);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.chat_outlined, size: 13),
              label: const Text('WA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Arsivle',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: onArsivle,
            icon: const Icon(Icons.archive_outlined, size: 18, color: Colors.grey),
          ),
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

