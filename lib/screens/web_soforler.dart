// ╔══════════════════════════════════════════════════════════════╗
// ║  DOSYA: lib/screens/web_soforler.dart
// ║  PROJE: servisim360
// ║  WEB: Şoför listesi + Ekle formu
// ╚══════════════════════════════════════════════════════════════╝
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/session_service.dart';

class WebSoforler extends StatefulWidget {
  final String firmaId;
  const WebSoforler({super.key, this.firmaId = ''});
  @override
  State<WebSoforler> createState() => _WebSoforlerState();
}

class _WebSoforlerState extends State<WebSoforler> {
  static const _navy   = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);

  List<Map<String, dynamic>> _soforler    = [];
  List<Map<String, dynamic>> _filtreliSof = [];
  List<Map<String, dynamic>> _projeler    = [];
  bool _yukleniyor = true;
  bool _formAcik   = false;
  final _aramaCtrl = TextEditingController();

  // Form controller'ları
  final _adCtrl       = TextEditingController();
  final _telCtrl      = TextEditingController();
  final _plakaCtrl    = TextEditingController();
  final _kapasiteCtrl = TextEditingController();
  final _modelCtrl    = TextEditingController();
  final _kulAdiCtrl   = TextEditingController();
  final _sifreCtrl    = TextEditingController();
  final _tcCtrl       = TextEditingController();
  final _ehliyetCtrl  = TextEditingController();
  final _srcCtrl      = TextEditingController();
  final _psikoCtrl    = TextEditingController();
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
    _tcCtrl.dispose(); _ehliyetCtrl.dispose(); _srcCtrl.dispose(); _psikoCtrl.dispose();
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
      // Şoförler
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
        _seciliProjeId = null; // boşta olarak başla
      }
    } catch (e) { debugPrint('WebSoforler hata: $e'); }

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
    if (_kulAdiCtrl.text.trim().isEmpty) { _snack('Kullanıcı adı zorunlu!'); return; }
    if (_sifreCtrl.text.trim().isEmpty)  { _snack('Şifre zorunlu!');         return; }

    setState(() => _soforKayitYuk = true);
    try {
      final fId = _firmaId.isNotEmpty
          ? _firmaId
          : await SessionService.instance.firmaIdAl() ?? '';

      // Kullanıcı adı kontrolü
      final kKont = await FirebaseFirestore.instance
          .collection('drivers')
          .where('kullaniciAdi', isEqualTo: _kulAdiCtrl.text.trim())
          .get();
      if (kKont.docs.isNotEmpty) {
        _snack('Kullanıcı adı zaten kullanılıyor!');
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
          content: Text('Şoför kaydedildi!'),
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

  // ── Form paneli ──────────────────────────────────────────────
  Widget _formPaneli() {
    return Container(
      width: 340,
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(right: BorderSide(color: Color(0xFFEEEEEE)))),
      child: Column(children: [
        // Başlık
        Container(
          padding: const EdgeInsets.all(16),
          color: _navy,
          child: Row(children: [
            const Icon(Icons.person_add_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            const Expanded(child: Text('Şoför Ekle',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 18),
              onPressed: () => setState(() => _formAcik = false)),
          ]),
        ),

        // Form alanları
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
                  const DropdownMenuItem<String?>(value: null, child: Text('Boşta ekle')),
                  ..._projeler.map((p) => DropdownMenuItem<String?>(
                      value: p['id'] as String,
                      child: Text(p['projeAd'] ?? ''))),
                ],
                onChanged: (v) => setState(() => _seciliProjeId = v),
              ),
              const SizedBox(height: 14),
            ],

            // Şoför bilgileri
            const Text('Şoför Bilgileri',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _navy)),
            const SizedBox(height: 8),
            _inp(_adCtrl, 'Ad Soyad *', Icons.person_outlined),
            const SizedBox(height: 8),
            _inp(_telCtrl, 'Telefon *', Icons.phone_outlined, tip: TextInputType.phone),
            const SizedBox(height: 8),
            _inp(_plakaCtrl, 'Araç Plakası *', Icons.directions_bus_outlined),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _inp(_kapasiteCtrl, 'Kapasite',
                  Icons.people_outlined, tip: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: _inp(_modelCtrl, 'Araç Modeli',
                  Icons.directions_car_outlined)),
            ]),
            const SizedBox(height: 14),

            // Giriş bilgileri
            const Text('İsteğe Bağlı Belgeler',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _navy)),
            const SizedBox(height: 4),
            const Text('Zorunlu değil, ileride eklenebilir',
                style: TextStyle(color: Colors.grey, fontSize: 11)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(
                controller: _tcCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'TC Kimlik',
                  prefixIcon: const Icon(Icons.credit_card_outlined, size: 16, color: _navy),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              )),
              const SizedBox(width: 8),
              Expanded(child: TextField(
                controller: _ehliyetCtrl,
                decoration: InputDecoration(
                  labelText: 'Ehliyet Sınıfı',
                  prefixIcon: const Icon(Icons.drive_eta_outlined, size: 16, color: _navy),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              )),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(
                controller: _srcCtrl,
                decoration: InputDecoration(
                  labelText: 'SRC Belgesi',
                  prefixIcon: const Icon(Icons.article_outlined, size: 16, color: _navy),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              )),
              const SizedBox(width: 8),
              Expanded(child: TextField(
                controller: _psikoCtrl,
                decoration: InputDecoration(
                  labelText: 'Psikoteknik Tarihi',
                  prefixIcon: const Icon(Icons.calendar_today_outlined, size: 16, color: _navy),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              )),
            ]),
            const SizedBox(height: 16),

            const Text('Giriş Bilgileri',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _navy)),
            const SizedBox(height: 4),
            const Text('Şoför bu bilgilerle uygulamaya giriş yapar',
                style: TextStyle(color: Colors.grey, fontSize: 11)),
            const SizedBox(height: 8),
            _inp(_kulAdiCtrl, 'Kullanıcı Adı *', Icons.account_circle_outlined),
            const SizedBox(height: 8),
            _inp(_sifreCtrl, 'Geçici Şifre *', Icons.key_outlined),
            const SizedBox(height: 14),

            // Servis türü
            const Text('Servis Türü',
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
              label: Text(_soforKayitYuk ? 'Kaydediliyor...' : 'Şoförü Kaydet',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Liste paneli ─────────────────────────────────────────────
  Widget _listePaneli() {
    return Column(children: [
      // Üst bar
      Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: Row(children: [
          Expanded(child: TextField(
            controller: _aramaCtrl,
            decoration: InputDecoration(
              hintText: 'Şoför ara...',
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
            label: Text(_formAcik ? 'Kapat' : 'Şoför Ekle',
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
            label: const Text('Rota Oluştur',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ]),
      ),

      // Sayaç
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        color: const Color(0xFFF5F7FA),
        child: Row(children: [
          Text('${_filtreliSof.length} şoför',
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

      // Kartlar
      Expanded(child: _yukleniyor
          ? const Center(child: CircularProgressIndicator(color: _navy))
          : _filtreliSof.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.directions_bus_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('Şoför bulunamadı',
                      style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: _orange,
                        foregroundColor: Colors.white),
                    onPressed: () => setState(() => _formAcik = true),
                    icon: const Icon(Icons.add),
                    label: const Text('İlk Şoförü Ekle')),
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
                    onDuzenle: () => Navigator.pushNamed(context, '/suruculer'),
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
}

// ════════════════════════════════════════════════════════════════
// ŞOFÖR KARTI
// ════════════════════════════════════════════════════════════════
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
    final ad      = sofor['ad'] as String? ?? 'Şoför';
    final plaka   = sofor['aracPlaka'] ?? sofor['plaka'] ?? '-';
    final tel     = sofor['telefon'] as String? ?? '-';
    final durum   = sofor['durum'] as String? ?? 'bosta';

    Color durumRenk;
    String durumAd;
    switch (durum) {
      case 'aktif_gorevde': durumRenk = Colors.green;  durumAd = 'Görevde'; break;
      case 'projeye_dahil': durumRenk = Colors.blue;   durumAd = 'Projede'; break;
      case 'pasif':         durumRenk = Colors.red;    durumAd = 'Pasif';   break;
      default:              durumRenk = Colors.orange; durumAd = 'Boşta';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: aktif ? Border.all(color: Colors.green.withValues(alpha: 0.4), width: 1.5) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: aktif
                ? Colors.green.withValues(alpha: 0.15)
                : _navy.withValues(alpha: 0.1),
            child: Text(ad.isNotEmpty ? ad[0].toUpperCase() : 'Ş',
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
                color: durumRenk.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Text(durumAd, style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.bold, color: durumRenk)),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _mini(Icons.people_outline, '$ogrSayi öğr', Colors.blue),
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
            label: const Text('Düzenle', style: TextStyle(fontSize: 11)),
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
