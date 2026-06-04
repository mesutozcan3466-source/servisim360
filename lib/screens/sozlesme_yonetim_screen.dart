// ╔══════════════════════════════════════════════════════════════╗
// ║  DOSYA: lib/screens/sozlesme_yonetim_screen.dart
// ║  PROJE: servisim360
// ║  v3 — Tam Sözleşme Yönetim Sistemi
// ║  Şablonlar | Hazır Maddeler | Firma Bilgileri | Önizleme | PDF
// ╚══════════════════════════════════════════════════════════════╝
import 'package:flutter/material.dart';
import 'ai_widget.dart';
import 'yardim_widget.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/session_service.dart';
import '../services/sozlesme_pdf_service.dart';

// ════════════════════════════════════════════════════════════════
// HAZIR MADDE MODELİ
// ════════════════════════════════════════════════════════════════
class HazirMadde {
  final String id, baslik, icerik, kategori;
  final bool zorunlu;
  bool aktif;

  HazirMadde({
    required this.id,
    required this.baslik,
    required this.icerik,
    required this.kategori,
    this.zorunlu = false,
    this.aktif   = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'baslik': baslik, 'icerik': icerik,
    'kategori': kategori, 'zorunlu': zorunlu, 'aktif': aktif,
  };

  factory HazirMadde.fromMap(Map<String, dynamic> m) => HazirMadde(
    id: m['id'] ?? '', baslik: m['baslik'] ?? '',
    icerik: m['icerik'] ?? '', kategori: m['kategori'] ?? '',
    zorunlu: m['zorunlu'] ?? false, aktif: m['aktif'] ?? false,
  );
}

// ── Varsayılan madde havuzu ────────────────────────────────────
List<HazirMadde> varsayilanMaddeler() => [
  HazirMadde(id: 'odeme', kategori: 'Ödeme', aktif: true,
    baslik: 'Ödeme Şartları',
    icerik: 'Servis ücreti her ayın 1-5. günleri arasında ödenecektir. Gecikme halinde aylık %2 faiz uygulanır.'),
  HazirMadde(id: 'adres', kategori: 'Servis',
    baslik: 'Adres Değişikliği',
    icerik: 'Adres değişikliği en az 3 iş günü öncesinden bildirilmelidir. Güzergah dışı adresler için ek ücret talep edilebilir.'),
  HazirMadde(id: 'kural', kategori: 'Servis', aktif: true,
    baslik: 'Servis Kullanım Kuralları',
    icerik: 'Öğrenci servis saatinden en az 5 dakika önce belirlenen durakta hazır bulunmalıdır. Servis 2 dakikadan fazla beklemez.'),
  HazirMadde(id: 'devamsiz', kategori: 'Servis',
    baslik: 'Devamsızlık Kuralları',
    icerik: 'Devamsızlık durumunda ücret iadesi yapılmaz. Uzun süreli devamsızlık için firma ile görüşülmelidir.'),
  HazirMadde(id: 'bugun', kategori: 'Servis', aktif: true,
    baslik: 'Bugün Gelmeyecek Bildirimi',
    icerik: 'Öğrencinin servise binmeyeceği günlerde en geç servis saatinden 30 dakika önce uygulama üzerinden bildirim yapılmalıdır.'),
  HazirMadde(id: 'iptal', kategori: 'Sözleşme',
    baslik: 'İptal ve Ayrılma Şartları',
    icerik: 'Sözleşme feshi en az 15 gün önceden yazılı olarak bildirilmelidir. Peşin ödemelerin iadesi prorate hesaplanır.'),
  HazirMadde(id: 'kvkk', kategori: 'Yasal', aktif: true, zorunlu: true,
    baslik: 'KVKK Aydınlatma Metni',
    icerik: '6698 sayılı KVKK kapsamında kişisel verileriniz yalnızca servis hizmetinin yürütülmesi amacıyla işlenmektedir. Verileriniz üçüncü kişilerle paylaşılmaz.'),
  HazirMadde(id: 'takip', kategori: 'Yasal', aktif: true,
    baslik: 'Canlı Takip Bilgilendirmesi',
    icerik: 'Servis aracı Servisim360 uygulaması aracılığıyla gerçek zamanlı takip edilebilir. Konum verisi yalnızca yetkili veliler tarafından görüntülenebilir.'),
  HazirMadde(id: 'bildirim', kategori: 'Yasal',
    baslik: 'Bildirim Sistemi Kullanımı',
    icerik: 'Servis bildirimleri (yaklaşıyor, geldi, bindi vb.) uygulama üzerinden anlık olarak iletilecektir. Bildirimleri kapatmanız durumunda sorumluluk veliye aittir.'),
  HazirMadde(id: 'acil', kategori: 'Güvenlik', aktif: true,
    baslik: 'Acil Durum Kuralları',
    icerik: 'Araç içi acil durumlarda şoför yetkililidir. Veli acil durum bildirimini uygulamadan anlık olarak alacaktır. Firma 112 ve ilgili birimleri derhal bilgilendirir.'),
  HazirMadde(id: 'kemer', kategori: 'Güvenlik', aktif: true, zorunlu: true,
    baslik: 'Emniyet Kemeri Zorunluluğu',
    icerik: 'Araç içinde emniyet kemeri takılması zorunludur. Uymayan öğrenciler servisten çıkarılabilir.'),
  HazirMadde(id: 'firma_ozel', kategori: 'Firma',
    baslik: 'Firma Özel Kuralları',
    icerik: 'Firma tarafından belirlenen ek kurallar geçerlidir ve veli tarafından kabul edilmiş sayılır.'),
];

// ════════════════════════════════════════════════════════════════
// ANA EKRAN
// ════════════════════════════════════════════════════════════════
class SozlesmeYonetimScreen extends StatefulWidget {
  const SozlesmeYonetimScreen({super.key});
  @override
  State<SozlesmeYonetimScreen> createState() => _SozlesmeYonetimScreenState();
}

class _SozlesmeYonetimScreenState extends State<SozlesmeYonetimScreen>
    with SingleTickerProviderStateMixin {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  late TabController _tab;
  String _firmaId  = '';
  String _projeId  = '';
  String _projeAdi = '';
  bool   _yukleniyor = true;
  bool   _projeFiltresi = true; // true=sadece bu proje, false=firma geneli

  // Şablonlar
  List<Map<String, dynamic>> _sablonlar     = [];
  List<Map<String, dynamic>> _tumSablonlar  = []; // firma geneli
  String? _seciliSablonId;

  // Hazır maddeler
  List<HazirMadde> _hazirMaddeler = varsayilanMaddeler();

  // Özel maddeler
  List<Map<String, dynamic>> _ozelMaddeler = [];

  // Firma bilgileri
  final _firmaAdCtrl     = TextEditingController();
  final _yetkiliCtrl     = TextEditingController();
  final _firmaTelaCtrl   = TextEditingController();
  final _firmaEmailCtrl  = TextEditingController();
  final _firmaAdresCtrl  = TextEditingController();
  final _vergiCtrl       = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
    _yukle();
  }

  @override
  void dispose() {
    _tab.dispose();
    _firmaAdCtrl.dispose(); _yetkiliCtrl.dispose();
    _firmaTelaCtrl.dispose(); _firmaEmailCtrl.dispose();
    _firmaAdresCtrl.dispose(); _vergiCtrl.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    _firmaId  = await SessionService.instance.firmaIdAl() ?? '';
    _projeId  = SessionService.instance.aktifProjeld ?? '';
    _projeAdi = SessionService.instance.aktifProjeAdi ?? '';
    if (_firmaId.isEmpty) { setState(() => _yukleniyor = false); return; }

    try {
      // Firma bilgilerini yükle
      final firmaDoc = await FirebaseFirestore.instance
          .collection('firms').doc(_firmaId).get();
      final fd = firmaDoc.data() ?? {};
      _firmaAdCtrl.text    = fd['firmaAdi']    ?? fd['ad'] ?? '';
      _yetkiliCtrl.text    = fd['yetkiliAd']   ?? fd['yetkili'] ?? '';
      _firmaTelaCtrl.text  = fd['telefon']     ?? '';
      _firmaEmailCtrl.text = fd['email']       ?? '';
      _firmaAdresCtrl.text = fd['adres']       ?? '';
      _vergiCtrl.text      = fd['vergiBilgisi'] ?? '';

      // Tüm şablonları yükle
      final sabSnap = await FirebaseFirestore.instance
          .collection('firms').doc(_firmaId)
          .collection('sozlesme_sablonlar')
          .get();
      _tumSablonlar = sabSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      // Proje filtresi — projeye atanmış şablonlar
      if (_projeId.isNotEmpty && _projeFiltresi) {
        final projeDoc = await FirebaseFirestore.instance
            .collection('projects').doc(_projeId).get();
        final sablonId = projeDoc.data()?['sozlesmeSablonId'] as String?;
        _sablonlar = sablonId != null && sablonId.isNotEmpty
            ? _tumSablonlar.where((s) => s['id'] == sablonId).toList()
            : [];
        // Proje şablonu yoksa tümünü göster
        if (_sablonlar.isEmpty) _sablonlar = _tumSablonlar;
      } else {
        _sablonlar = _tumSablonlar;
      }

      if (_seciliSablonId == null && _sablonlar.isNotEmpty) {
        _seciliSablonId = _sablonlar.first['id'];
      }
      if (_seciliSablonId != null) await _sablonYukle(_seciliSablonId!);
    } catch (e) { debugPrint('SozlesmeYonetim hata: $e'); }
    if (mounted) setState(() => _yukleniyor = false);
  }

  Future<void> _sablonYukle(String id) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('firms').doc(_firmaId)
          .collection('sozlesme_sablonlar').doc(id).get();
      final data = doc.data() ?? {};

      // Maddeleri güncelle
      final kayitli = List<Map<String, dynamic>>.from(data['maddeler'] ?? []);
      _hazirMaddeler = varsayilanMaddeler();
      for (final m in _hazirMaddeler) {
        final k = kayitli.firstWhere((k) => k['id'] == m.id, orElse: () => {});
        if (k.isNotEmpty) m.aktif = k['aktif'] ?? m.aktif;
      }

      _ozelMaddeler = List<Map<String, dynamic>>.from(data['ozelMaddeler'] ?? []);
      setState(() {});
    } catch (e) { debugPrint('Şablon yükleme hata: $e'); }
  }

  Future<void> _sablonKaydet() async {
    if (_seciliSablonId == null) {
      _snack('Önce bir şablon seçin veya oluşturun'); return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('firms').doc(_firmaId)
          .collection('sozlesme_sablonlar').doc(_seciliSablonId)
          .update({
        'maddeler'    : _hazirMaddeler.map((m) => m.toMap()).toList(),
        'ozelMaddeler': _ozelMaddeler,
        'updatedAt'   : FieldValue.serverTimestamp(),
      });
      _snack('Sözleşme kaydedildi!', renk: Colors.green);
    } catch (e) { _snack('Hata: $e'); }
  }

  Future<void> _firmaBilgiKaydet() async {
    if (_firmaId.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('firms').doc(_firmaId)
          .set({
        'firmaAdi'    : _firmaAdCtrl.text.trim(),
        'ad'          : _firmaAdCtrl.text.trim(),
        'yetkiliAd'   : _yetkiliCtrl.text.trim(),
        'yetkili'     : _yetkiliCtrl.text.trim(),
        'telefon'     : _firmaTelaCtrl.text.trim(),
        'email'       : _firmaEmailCtrl.text.trim(),
        'adres'       : _firmaAdresCtrl.text.trim(),
        'vergiBilgisi': _vergiCtrl.text.trim(),
        'updatedAt'   : FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _snack('Firma bilgileri kaydedildi!', renk: Colors.green);
    } catch (e) { _snack('Hata: $e'); }
  }

  void _snack(String m, {Color renk = Colors.red}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m), backgroundColor: renk,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white,
        title: const Text('Sözleşme Yönetimi',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          AiAsistanButonu(ekranAdi: 'Sozlesmeler'),
          YardimButonu(ekranAdi: 'Sozlesmeler'),
          if (_seciliSablonId != null)
            TextButton.icon(
              onPressed: _sablonKaydet,
              icon: const Icon(Icons.save_rounded, color: Colors.white, size: 18),
              label: const Text('Kaydet',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: _turuncu, labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          isScrollable: true, tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.folder_outlined,    size: 16), text: 'Şablonlar'),
            Tab(icon: Icon(Icons.checklist_outlined, size: 16), text: 'Hazır Maddeler'),
            Tab(icon: Icon(Icons.business_outlined,  size: 16), text: 'Firma Bilgileri'),
            Tab(icon: Icon(Icons.preview_outlined,   size: 16), text: 'Önizleme'),
            Tab(icon: Icon(Icons.picture_as_pdf_outlined, size: 16), text: 'PDF & Gönder'),
          ],
        ),
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(controller: _tab, children: [
              _sablonlarTab(),
              _hazirMaddelerTab(),
              _firmaBilgileriTab(),
              _onizlemeTab(),
              _pdfGonderTab(),
            ]),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // TAB 1 — ŞABLONLAR
  // ════════════════════════════════════════════════════════════════
  Widget _sablonlarTab() => Column(children: [
    // Proje / Firma bilgi kutusu — fiyat sistemi gibi
    Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(children: [
        Expanded(child: GestureDetector(
          onTap: () async {
            setState(() { _projeFiltresi = true; _seciliSablonId = null; });
            await _yukle();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
                color: _projeFiltresi ? _navy : Colors.transparent,
                borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.folder_outlined,
                  color: _projeFiltresi ? Colors.white : Colors.grey, size: 14),
              const SizedBox(width: 6),
              Text(
                _projeAdi.isNotEmpty ? _projeAdi : 'Bu Proje',
                style: TextStyle(
                    color: _projeFiltresi ? Colors.white : Colors.grey,
                    fontWeight: FontWeight.bold, fontSize: 12),
                overflow: TextOverflow.ellipsis),
            ]),
          ),
        )),
        const SizedBox(width: 8),
        Expanded(child: GestureDetector(
          onTap: () async {
            setState(() { _projeFiltresi = false; _seciliSablonId = null; });
            await _yukle();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
                color: !_projeFiltresi ? _navy : Colors.transparent,
                borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.business_outlined,
                  color: !_projeFiltresi ? Colors.white : Colors.grey, size: 14),
              const SizedBox(width: 6),
              Text('Firma Geneli',
                  style: TextStyle(
                      color: !_projeFiltresi ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.bold, fontSize: 12)),
            ]),
          ),
        )),
      ]),
    ),
    if (_projeFiltresi && _projeAdi.isNotEmpty)
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            const Icon(Icons.info_outline, color: Colors.blue, size: 12),
            const SizedBox(width: 6),
            Expanded(child: Text(
              '"$_projeAdi" projesine ait şablonlar gösteriliyor. '
              'Firma Geneli butonuna gecerek tum sablonlari goruntuleyebilir ve projeye atayabilirsiniz.',
              style: const TextStyle(fontSize: 10, color: Colors.blue))),
          ]),
        ),
      ),
    const SizedBox(height: 12),

    Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(children: [
        Expanded(child: _sablonlar.isEmpty
            ? const Text('Henüz şablon oluşturulmadı',
                style: TextStyle(color: Colors.grey))
            : DropdownButtonFormField<String>(
                value: _seciliSablonId,
                decoration: const InputDecoration(
                    labelText: 'Aktif Şablon',
                    prefixIcon: Icon(Icons.folder_outlined),
                    border: OutlineInputBorder(), isDense: true),
                items: _sablonlar.map((s) => DropdownMenuItem(
                  value: s['id'] as String,
                  child: Text(s['ad'] ?? ''),
                )).toList(),
                onChanged: (v) async {
                  setState(() => _seciliSablonId = v);
                  if (v != null) await _sablonYukle(v);
                },
              )),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: _turuncu, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: _yeniSablonDialog,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Yeni Şablon')),
      ]),
    ),

    Expanded(child: _sablonlar.isEmpty
        ? _bosEkran(
            Icons.folder_outlined, 'Henüz şablon oluşturulmadı',
            'Farklı projeler için ayrı sözleşmeler oluşturun',
            buton: 'İlk Şablonu Oluştur', onTap: _yeniSablonDialog)
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _sablonlar.length,
            itemBuilder: (_, i) {
              final s = _sablonlar[i];
              final secili = s['id'] == _seciliSablonId;
              final maddeSayi = (s['maddeler'] as List? ?? [])
                  .where((m) => m['aktif'] == true).length;
              final ozelSayi = (s['ozelMaddeler'] as List? ?? []).length;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: secili
                        ? const BorderSide(color: _navy, width: 2)
                        : BorderSide.none),
                elevation: secili ? 3 : 1,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: _navy.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.description_outlined,
                        color: secili ? _turuncu : _navy, size: 22),
                  ),
                  title: Text(s['ad'] ?? '',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: secili ? _navy : Colors.black87)),
                  subtitle: Wrap(spacing: 8, children: [
                    _chip('$maddeSayi hazır madde', Colors.blue),
                    if (ozelSayi > 0) _chip('$ozelSayi özel madde', _turuncu),
                    if (secili) _chip('Aktif', Colors.green),
                  ]),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (secili) const Icon(Icons.check_circle_rounded,
                        color: _navy, size: 20),
                    PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'sil') {
                          await FirebaseFirestore.instance
                              .collection('firms').doc(_firmaId)
                              .collection('sozlesme_sablonlar')
                              .doc(s['id']).delete();
                          setState(() {
                            if (_seciliSablonId == s['id']) _seciliSablonId = null;
                          });
                          await _yukle();
                        }
                        if (v == 'kopyala') await _sablonKopyala(s);
                        if (v == 'projeAta') await _sabloniProjeyeAta(s);
                      },
                      itemBuilder: (_) => [
                        if (_projeId.isNotEmpty)
                          PopupMenuItem(value: 'projeAta',
                              child: Row(children: [
                                const Icon(Icons.folder_outlined, color: Colors.green, size: 16),
                                const SizedBox(width: 8),
                                Text('"$_projeAdi" projesine ata',
                                    style: const TextStyle(color: Colors.green, fontSize: 13)),
                              ])),
                        const PopupMenuItem(value: 'kopyala',
                            child: Row(children: [
                              Icon(Icons.copy_outlined, color: Colors.blue, size: 16),
                              SizedBox(width: 8), Text('Kopyala'),
                            ])),
                        const PopupMenuItem(value: 'sil',
                            child: Row(children: [
                              Icon(Icons.delete_outlined, color: Colors.red, size: 16),
                              SizedBox(width: 8),
                              Text('Sil', style: TextStyle(color: Colors.red)),
                            ])),
                      ],
                    ),
                  ]),
                  onTap: () async {
                    setState(() => _seciliSablonId = s['id']);
                    await _sablonYukle(s['id']);
                  },
                ),
              );
            },
          )),
  ]);

  void _yeniSablonDialog() {
    final adCtrl = TextEditingController();
    bool projeYeAta = _projeFiltresi && _projeId.isNotEmpty;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setSt) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Yeni Sözleşme Şablonu'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: adCtrl, autofocus: true,
            decoration: const InputDecoration(
                labelText: 'Şablon Adı *',
                hintText: 'Örn: Okul Servisi 2026, Personel Servisi...',
                border: OutlineInputBorder(), isDense: true),
          ),
          if (_projeId.isNotEmpty) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => setSt(() => projeYeAta = !projeYeAta),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: projeYeAta ? Colors.green.shade50 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: projeYeAta ? Colors.green.shade300 : Colors.grey.shade300)),
                child: Row(children: [
                  Icon(projeYeAta ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                      color: projeYeAta ? Colors.green : Colors.grey, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('"$_projeAdi" projesine ata',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12,
                            color: projeYeAta ? Colors.green : Colors.grey[700])),
                    Text('İşaretsizse firma genelinde kalır',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                  ])),
                ]),
              ),
            ),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _navy, foregroundColor: Colors.white),
            onPressed: () async {
              if (adCtrl.text.trim().isEmpty) return;
              final now = FieldValue.serverTimestamp();
              final ref = await FirebaseFirestore.instance
                  .collection('firms').doc(_firmaId)
                  .collection('sozlesme_sablonlar').add({
                'ad'          : adCtrl.text.trim(),
                'maddeler'    : varsayilanMaddeler()
                    .where((m) => m.aktif || m.zorunlu)
                    .map((m) => m.toMap()).toList(),
                'ozelMaddeler': [],
                'olusturma'   : now, 'updatedAt': now,
              });
              if (projeYeAta && _projeId.isNotEmpty) {
                await FirebaseFirestore.instance
                    .collection('projects').doc(_projeId).update({
                  'sozlesmeSablonId': ref.id,
                  'sozlesmeSablonAd': adCtrl.text.trim(),
                  'updatedAt'       : now,
                });
              }
              if (ctx.mounted) Navigator.pop(ctx);
              setState(() => _seciliSablonId = ref.id);
              await _yukle();
            },
            child: const Text('Oluştur')),
        ],
      )),
    );
  }

  Future<void> _sabloniProjeyeAta(Map<String, dynamic> s) async {
    if (_projeId.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('projects').doc(_projeId).update({
      'sozlesmeSablonId': s['id'],
      'sozlesmeSablonAd': s['ad'] ?? '',
      'updatedAt'       : FieldValue.serverTimestamp(),
    });
    _snack('"${s['ad']}" şablonu "$_projeAdi" projesine atandı!',
        renk: Colors.green);
    setState(() => _seciliSablonId = s['id']);
    await _yukle();
  }

  Future<void> _sablonKopyala(Map<String, dynamic> s) async {
    final now = FieldValue.serverTimestamp();
    final ref = await FirebaseFirestore.instance
        .collection('firms').doc(_firmaId)
        .collection('sozlesme_sablonlar').add({
      'ad'          : '${s['ad']} (Kopya)',
      'maddeler'    : s['maddeler'] ?? [],
      'ozelMaddeler': s['ozelMaddeler'] ?? [],
      'olusturma'   : now, 'updatedAt': now,
    });
    setState(() => _seciliSablonId = ref.id);
    await _yukle();
    _snack('Kopyalandı', renk: Colors.green);
  }

  // ════════════════════════════════════════════════════════════════
  // TAB 2 — HAZIR MADDELER
  // ════════════════════════════════════════════════════════════════
  Widget _hazirMaddelerTab() {
    if (_seciliSablonId == null) return _secinizUyarisi();

    final kategoriler = <String, List<HazirMadde>>{};
    for (final m in _hazirMaddeler) {
      kategoriler.putIfAbsent(m.kategori, () => []).add(m);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _bilgiKutusu(
          'Aktif maddeler sözleşmeye dahil edilir. '
          'Zorunlu maddeler kapatılamaz. '
          'En altta özel madde ekleyebilirsiniz.',
          Colors.blue),
        const SizedBox(height: 16),

        ...kategoriler.entries.map((kat) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Icon(_katIkon(kat.key), color: _navy, size: 15),
                const SizedBox(width: 8),
                Text(kat.key, style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14, color: _navy)),
                const SizedBox(width: 8),
                Expanded(child: Divider(color: _navy.withValues(alpha: 0.2))),
              ]),
            ),
            ...kat.value.map((m) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Switch(
                    value: m.aktif, activeColor: Colors.green,
                    onChanged: m.zorunlu ? null : (v) {
                      setState(() => m.aktif = v);
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(m.baslik, style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13,
                          color: m.aktif ? Colors.black87 : Colors.grey))),
                      if (m.zorunlu)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6)),
                          child: const Text('Zorunlu',
                              style: TextStyle(fontSize: 10, color: Colors.red,
                                  fontWeight: FontWeight.bold))),
                    ]),
                    const SizedBox(height: 4),
                    Text(m.icerik, style: TextStyle(
                        fontSize: 12, color: m.aktif ? Colors.grey[600] : Colors.grey[400]),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ])),
                ]),
              ),
            )),
            const SizedBox(height: 8),
          ],
        )),

        // Özel maddeler
        const Divider(height: 24),
        Row(children: [
          const Icon(Icons.edit_note_outlined, color: _navy, size: 16),
          const SizedBox(width: 8),
          const Text('Özel Maddeler', style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 14, color: _navy)),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _ozelMaddeDialog(),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('Madde Ekle')),
        ]),
        const SizedBox(height: 8),

        if (_ozelMaddeler.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200)),
            child: const Text('Henüz özel madde eklenmedi',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center),
          )
        else
          ..._ozelMaddeler.asMap().entries.map((e) {
            final i = e.key;
            final m = e.value;
            final no = _hazirMaddeler.where((h) => h.aktif).length + i + 1;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                    radius: 14, backgroundColor: _turuncu.withValues(alpha: 0.1),
                    child: Text('$no', style: const TextStyle(
                        fontSize: 11, color: _turuncu, fontWeight: FontWeight.bold))),
                title: Text(m['baslik'] ?? '', style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text(m['icerik'] ?? '',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.blue),
                    onPressed: () => _ozelMaddeDialog(duzenle: m, index: i)),
                  IconButton(
                    icon: const Icon(Icons.delete_outlined, size: 16, color: Colors.red),
                    onPressed: () => setState(() => _ozelMaddeler.removeAt(i))),
                ]),
              ),
            );
          }),
        const SizedBox(height: 80),
      ],
    );
  }

  void _ozelMaddeDialog({Map<String, dynamic>? duzenle, int? index}) {
    final baslikCtrl = TextEditingController(text: duzenle?['baslik'] ?? '');
    final icerikCtrl = TextEditingController(text: duzenle?['icerik'] ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(duzenle != null ? 'Maddeyi Düzenle' : 'Özel Madde Ekle'),
        content: SizedBox(width: 480, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: baslikCtrl,
              decoration: const InputDecoration(labelText: 'Madde Başlığı *',
                  border: OutlineInputBorder(), isDense: true)),
          const SizedBox(height: 10),
          TextField(controller: icerikCtrl, maxLines: 4,
              decoration: const InputDecoration(labelText: 'Madde İçeriği *',
                  border: OutlineInputBorder(), alignLabelWithHint: true)),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _navy, foregroundColor: Colors.white),
            onPressed: () {
              if (baslikCtrl.text.trim().isEmpty) return;
              final madde = {'baslik': baslikCtrl.text.trim(),
                  'icerik': icerikCtrl.text.trim()};
              setState(() {
                if (index != null) _ozelMaddeler[index] = madde;
                else _ozelMaddeler.add(madde);
              });
              Navigator.pop(_);
            },
            child: const Text('Kaydet')),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // TAB 3 — FİRMA BİLGİLERİ
  // ════════════════════════════════════════════════════════════════
  Widget _firmaBilgileriTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(children: [
      _bilgiKutusu('Bu bilgiler PDF sözleşmede otomatik kullanılır.', Colors.blue),
      const SizedBox(height: 16),

      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Firma Bilgileri', style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15, color: _navy)),
            const SizedBox(height: 16),
            _formSatir('Firma Adı *', _firmaAdCtrl, Icons.business_outlined),
            const SizedBox(height: 12),
            _formSatir('Yetkili Adı *', _yetkiliCtrl, Icons.person_outlined),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _formSatir('Telefon', _firmaTelaCtrl,
                  Icons.phone_outlined, tip: TextInputType.phone)),
              const SizedBox(width: 12),
              Expanded(child: _formSatir('E-Posta', _firmaEmailCtrl,
                  Icons.email_outlined, tip: TextInputType.emailAddress)),
            ]),
            const SizedBox(height: 12),
            _formSatir('Adres', _firmaAdresCtrl, Icons.location_on_outlined),
            const SizedBox(height: 12),
            _formSatir('Vergi No / Vergi Dairesi', _vergiCtrl,
                Icons.receipt_outlined),
          ]),
        ),
      ),
      const SizedBox(height: 16),

      // Veli onay maddeleri
      Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Veli Onay Maddeleri', style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15, color: _navy)),
            const SizedBox(height: 4),
            const Text('Velinin kayıt sırasında onaylaması gereken maddeler',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),
            ...[
              'Sözleşmeyi okudum, anladım ve kabul ediyorum.',
              'Servis ücretini ve ödeme koşullarını kabul ediyorum.',
              'KVKK aydınlatma metnini okudum ve kabul ediyorum.',
              'Verdiğim bilgilerin doğruluğunu beyan ediyorum.',
              'Dijital onayımın fiziksel imza ile aynı hukuki geçerliliğe sahip olduğunu kabul ediyorum.',
            ].map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                const SizedBox(width: 10),
                Expanded(child: Text(m, style: const TextStyle(fontSize: 13))),
              ]),
            )),
          ]),
        ),
      ),
      const SizedBox(height: 20),

      SizedBox(width: double.infinity, child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
            backgroundColor: _navy, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        onPressed: _firmaBilgiKaydet,
        icon: const Icon(Icons.save_rounded),
        label: const Text('Firma Bilgilerini Kaydet',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      )),
    ]),
  );

  Widget _formSatir(String label, TextEditingController ctrl, IconData icon,
      {TextInputType? tip}) =>
      TextField(controller: ctrl, keyboardType: tip,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon, size: 18, color: _navy),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            isDense: true, contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 12),
          ));

  // ════════════════════════════════════════════════════════════════
  // TAB 4 — ÖNİZLEME
  // ════════════════════════════════════════════════════════════════
  Widget _onizlemeTab() {
    if (_seciliSablonId == null) return _secinizUyarisi();

    final aktifMaddeler = _hazirMaddeler.where((m) => m.aktif).toList();
    final sablonAd = _sablonlar.firstWhere(
        (s) => s['id'] == _seciliSablonId, orElse: () => {})['ad'] ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Firma başlığı
          if (_firmaAdCtrl.text.isNotEmpty)
            Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Text(_firmaAdCtrl.text.toUpperCase(), style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: _navy),
                  textAlign: TextAlign.center),
              if (_firmaAdresCtrl.text.isNotEmpty)
                Text(_firmaAdresCtrl.text, style: const TextStyle(
                    fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center),
              if (_firmaTelaCtrl.text.isNotEmpty)
                Text('Tel: ${_firmaTelaCtrl.text}  |  ${_firmaEmailCtrl.text}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center),
              const SizedBox(height: 16),
              const Divider(thickness: 2),
            ]),

          // Sözleşme başlığı
          Text(sablonAd.isNotEmpty ? '$sablonAd HİZMET SÖZLEŞMESİ'
              : 'HİZMET SÖZLEŞMESİ',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                  color: _navy),
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          const Text(
            'İşbu sözleşme, aşağıdaki taraflar arasında '
            'akdedilmiş olup belirtilen hüküm ve koşulları kapsar.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center),
          const SizedBox(height: 20),

          // Öğrenci & Veli Bilgi Formu (Örnek)
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('ÖĞRENCİ BİLGİLERİ',
                  style: TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 11, color: _navy)),
              const Divider(height: 10),
              _onizlemeSatir('Öğrenci Ad Soyad', '..............................'),
              _onizlemeSatir('TC Kimlik No', '..............................'),
              _onizlemeSatir('Okul Adı', '..............................'),
              _onizlemeSatir('Sınıf / Okul No', '..............................'),
              _onizlemeSatir('Öğrenci Tel', '..............................'),
              const SizedBox(height: 8),
              const Text('VELİ BİLGİLERİ',
                  style: TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 11, color: _navy)),
              const Divider(height: 10),
              _onizlemeSatir('Veli Ad Soyad', '..............................'),
              _onizlemeSatir('Veli TC', '..............................'),
              _onizlemeSatir('Baba Telefonu', '..............................'),
              _onizlemeSatir('Anne Telefonu', '..............................'),
              const SizedBox(height: 8),
              const Text('ADRES & ÜCRET',
                  style: TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 11, color: _navy)),
              const Divider(height: 10),
              _onizlemeSatir('Ev Adresi', '..............................'),
              _onizlemeSatir('Mesafe', 'Otomatik hesaplanır'),
              _onizlemeSatir('Aylık Aidat', 'Fiyatlandırmadan otomatik'),
            ]),
          ),

          // Maddeler
          ...aktifMaddeler.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('MADDE ${e.key + 1} — ${e.value.baslik.toUpperCase()}',
                  style: const TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 12, color: _navy)),
              const SizedBox(height: 4),
              Text(e.value.icerik,
                  style: const TextStyle(fontSize: 13, height: 1.6)),
            ]),
          )),

          // Özel maddeler
          ..._ozelMaddeler.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('MADDE ${aktifMaddeler.length + e.key + 1} — '
                  '${(e.value['baslik'] ?? '').toUpperCase()}',
                  style: const TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 12, color: _navy)),
              const SizedBox(height: 4),
              Text(e.value['icerik'] ?? '',
                  style: const TextStyle(fontSize: 13, height: 1.6)),
            ]),
          )),

          // İmza alanı
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Column(children: [
              const Text('VELİ İMZASI', style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 30),
              const Divider(),
              const Text('Ad Soyad / Tarih',
                  style: TextStyle(fontSize: 10, color: Colors.grey)),
            ])),
            const SizedBox(width: 40),
            Expanded(child: Column(children: [
              Text(_firmaAdCtrl.text.isNotEmpty
                  ? _firmaAdCtrl.text.toUpperCase() : 'FİRMA',
                  style: const TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 30),
              const Divider(),
              Text(_yetkiliCtrl.text.isNotEmpty
                  ? _yetkiliCtrl.text : 'Yetkili Adı',
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ])),
          ]),
        ]),
      ),
    );
  }

  Widget _onizlemeSatir(String label, String deger) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      SizedBox(width: 120, child: Text(label,
          style: const TextStyle(fontSize: 11, color: Colors.grey))),
      Expanded(child: Text(deger,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500))),
    ]),
  );

  // ════════════════════════════════════════════════════════════════
  // TAB 5 — PDF & GÖNDER
  // ════════════════════════════════════════════════════════════════
  Widget _pdfGonderTab() {
    if (_seciliSablonId == null) return _secinizUyarisi();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        _bilgiKutusu(
          'PDF oluşturmak için önce veli kayıt formunda sözleşme '
          'onaylandıktan sonra sistem otomatik PDF oluşturur. '
          'Buradan şablonu test edebilir ve paylaşabilirsiniz.',
          Colors.blue),
        const SizedBox(height: 20),

        // PDF içerik özeti
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('PDF İçeriği', style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15, color: _navy)),
              const SizedBox(height: 14),
              _pdfIcerikSatir(Icons.business_outlined, 'Firma Bilgileri',
                  _firmaAdCtrl.text.isNotEmpty ? '✓' : 'Eksik', 
                  _firmaAdCtrl.text.isNotEmpty ? Colors.green : Colors.orange),
              _pdfIcerikSatir(Icons.person_outlined, 'Öğrenci & Veli Bilgileri',
                  'Kayıt sırasında doldurulur', Colors.blue),
              _pdfIcerikSatir(Icons.location_on_outlined, 'Adres & Mesafe',
                  'Kayıt sırasında hesaplanır', Colors.blue),
              _pdfIcerikSatir(Icons.attach_money_outlined, 'Servis Ücreti',
                  'Fiyatlandırmadan otomatik', Colors.blue),
              _pdfIcerikSatir(Icons.checklist_outlined, 'Sözleşme Maddeleri',
                  '${_hazirMaddeler.where((m) => m.aktif).length + _ozelMaddeler.length} madde',
                  Colors.green),
              _pdfIcerikSatir(Icons.verified_outlined, 'Dijital Onay',
                  'Tarih & onay bilgisi', Colors.green),
            ]),
          ),
        ),
        const SizedBox(height: 16),

        // Gönderim seçenekleri
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Şablonu Paylaş', style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15, color: _navy)),
              const SizedBox(height: 4),
              const Text('Sözleşme içeriğini kopyalayın veya paylaşın',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 14),

              _gonderimBtn(
                Icons.picture_as_pdf_outlined, Colors.red, 'PDF Oluştur & İndir',
                'Sözleşmeyi PDF olarak oluşturur ve paylaşır',
                () => _pdfOlustur()),
              const SizedBox(height: 10),
              _gonderimBtn(
                Icons.print_outlined, Colors.grey, 'Yazdır',
                'Sözleşmeyi tarayıcı yazdırma menüsüyle yazdır',
                () async {
                  final mesaj = 'Yazdırmak için: Önizleme sekmesine geçin, '
                      'ardından tarayıcıda Ctrl+P (Windows) veya Cmd+P (Mac) tuşlayın.';
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(mesaj),
                      duration: const Duration(seconds: 4),
                      behavior: SnackBarBehavior.floating));
                }),
              const SizedBox(height: 10),
              _gonderimBtn(
                Icons.copy_outlined, Colors.blue, 'Metni Kopyala',
                'Tüm sözleşme metnini panoya kopyalar',
                () => _metniKopyala()),
              const SizedBox(height: 10),
              _gonderimBtn(
                Icons.message_outlined, const Color(0xFF25D366), 'WhatsApp ile Gönder',
                'Sözleşme linkini WhatsApp\'tan ilet',
                () => _whatsappGonder()),
              const SizedBox(height: 10),
              _gonderimBtn(
                Icons.link_outlined, _turuncu, 'Kayıt Linki Oluştur',
                'Veliye gönderilecek kayıt formu linki',
                () => Navigator.pushNamed(context, '/kayit_link')),
              const SizedBox(height: 10),
              _gonderimBtn(
                Icons.visibility_outlined, _navy, 'Veli Panelinde Göster',
                'Onaylanmış sözleşmeleri görüntüle',
                () => Navigator.pushNamed(context, '/veli_basvurular')),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _pdfIcerikSatir(IconData icon, String baslik, String deger, Color renk) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Icon(icon, color: renk, size: 18),
          const SizedBox(width: 12),
          Expanded(child: Text(baslik,
              style: const TextStyle(fontSize: 13))),
          Text(deger, style: TextStyle(
              fontSize: 12, color: renk, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _gonderimBtn(IconData icon, Color renk, String baslik,
      String aciklama, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: renk.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: renk.withValues(alpha: 0.2))),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: renk.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: renk, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(baslik, style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
              Text(aciklama, style: TextStyle(
                  color: Colors.grey[600], fontSize: 12)),
            ])),
            Icon(Icons.arrow_forward_ios_rounded, color: renk, size: 14),
          ]),
        ),
      );

  Future<void> _pdfOlustur() async {
    if (_seciliSablonId == null) {
      _snack('Önce bir şablon seçin'); return;
    }
    try {
      final aktifler = _hazirMaddeler.where((m) => m.aktif).toList();
      final buf = StringBuffer();
      for (var i = 0; i < aktifler.length; i++) {
        buf.writeln('Madde ${i+1} — ${aktifler[i].baslik}');
        buf.writeln(aktifler[i].icerik);
        buf.writeln();
      }
      for (var i = 0; i < _ozelMaddeler.length; i++) {
        buf.writeln('Madde ${aktifler.length + i + 1} — ${_ozelMaddeler[i]['baslik'] ?? ''}');
        buf.writeln(_ozelMaddeler[i]['icerik'] ?? '');
        buf.writeln();
      }
      await SozlesmePdfServisi.olusturVePaylasim(
        firmaAd     : _firmaAdCtrl.text.isNotEmpty ? _firmaAdCtrl.text : 'Firma',
        ogrenciAd   : 'Öğrenci Adı',
        veliAd      : 'Veli Adı',
        anneTel     : _firmaTelaCtrl.text,
        adres       : _firmaAdresCtrl.text,
        sozlesmeMetni: buf.toString(),
      );
    } catch (e) {
      _snack('PDF oluşturma hatası: $e');
    }
  }

  void _metniKopyala() {
    final aktifler = _hazirMaddeler.where((m) => m.aktif).toList();
    final sablonAd = _sablonlar.firstWhere(
        (s) => s['id'] == _seciliSablonId, orElse: () => {})['ad'] ?? '';
    final buf = StringBuffer();
    buf.writeln('${_firmaAdCtrl.text.toUpperCase()} HİZMET SÖZLEŞMESİ');
    buf.writeln('$sablonAd');
    buf.writeln('─' * 40);
    for (var i = 0; i < aktifler.length; i++) {
      buf.writeln('\nMADDE ${i + 1} — ${aktifler[i].baslik.toUpperCase()}');
      buf.writeln(aktifler[i].icerik);
    }
    for (var i = 0; i < _ozelMaddeler.length; i++) {
      buf.writeln('\nMADDE ${aktifler.length + i + 1} — '
          '${(_ozelMaddeler[i]['baslik'] ?? '').toUpperCase()}');
      buf.writeln(_ozelMaddeler[i]['icerik'] ?? '');
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    _snack('Sözleşme metni kopyalandı!', renk: Colors.green);
  }

  void _whatsappGonder() async {
    final sablonAd = _sablonlar.firstWhere(
        (s) => s['id'] == _seciliSablonId, orElse: () => {})['ad'] ?? '';
    final mesaj = '${_firmaAdCtrl.text} - $sablonAd Hizmet Sözleşmesi\n'
        'Kayıt formunuza aşağıdaki linkten ulaşabilirsiniz.';
    final url = Uri.parse(
        'https://wa.me/?text=${Uri.encodeComponent(mesaj)}');
    if (await canLaunchUrl(url)) {
      launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  // ── Yardımcılar ───────────────────────────────────────────────
  Widget _secinizUyarisi() => Center(child: Column(
    mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.folder_outlined, size: 72, color: Colors.grey[300]),
      const SizedBox(height: 12),
      const Text('Önce Şablonlar sekmesinden bir şablon seçin',
          style: TextStyle(color: Colors.grey, fontSize: 15)),
      const SizedBox(height: 16),
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
            backgroundColor: _turuncu, foregroundColor: Colors.white),
        onPressed: () => _tab.animateTo(0),
        icon: const Icon(Icons.folder_outlined),
        label: const Text('Şablonlara Git')),
    ]));

  Widget _bosEkran(IconData icon, String baslik, String alt,
      {String? buton, VoidCallback? onTap}) =>
      Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 72, color: Colors.grey[300]),
        const SizedBox(height: 12),
        Text(baslik, style: const TextStyle(fontSize: 16, color: Colors.grey,
            fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(alt, style: const TextStyle(color: Colors.grey, fontSize: 13),
            textAlign: TextAlign.center),
        if (buton != null && onTap != null) ...[
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _turuncu, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: onTap,
            icon: const Icon(Icons.add_rounded),
            label: Text(buton, style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
      ]));

  Widget _bilgiKutusu(String metin, Color renk) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: renk.withValues(alpha: 0.2))),
    child: Row(children: [
      Icon(Icons.info_outline, color: renk, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(metin,
          style: TextStyle(fontSize: 12, color: renk))),
    ]),
  );

  Widget _chip(String label, Color renk) => Container(
    margin: const EdgeInsets.only(top: 4),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(fontSize: 10, color: renk,
        fontWeight: FontWeight.w600)),
  );

  IconData _katIkon(String kat) {
    switch (kat) {
      case 'Ödeme':     return Icons.payments_outlined;
      case 'Servis':    return Icons.directions_bus_outlined;
      case 'Sözleşme': return Icons.description_outlined;
      case 'Yasal':     return Icons.gavel_outlined;
      case 'Güvenlik': return Icons.security_outlined;
      case 'Firma':     return Icons.business_outlined;
      default:          return Icons.article_outlined;
    }
  }
}
