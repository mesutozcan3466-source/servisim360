// ╔══════════════════════════════════════════════════════════════╗
// ║  DOSYA: lib/screens/suruculer_screen.dart
// ║  PROJE: servisim360
// ║  WEB + MOBİL: Tam şoför yönetimi
// ╚══════════════════════════════════════════════════════════════╝
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/session_service.dart';

class SurucularScreen extends StatefulWidget {
  const SurucularScreen({super.key});
  @override
  State<SurucularScreen> createState() => _SurucularScreenState();
}

class _SurucularScreenState extends State<SurucularScreen> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  String? _firmaId;
  String  _filtrePraje = ''; // '' = tümü
  List<Map<String, dynamic>> _projeler = [];

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final fId = await SessionService.instance.firmaIdAl();
    if (!mounted) return;
    setState(() => _firmaId = fId);
    if (fId == null) return;

    // Projeleri yükle
    final snap = await FirebaseFirestore.instance
        .collection('projects')
        .where('firmaId', isEqualTo: fId)
        .where('aktif', isEqualTo: true)
        .get();
    if (mounted) {
      setState(() {
        _projeler = snap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_firmaId == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: const Text('Şoförler',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // Proje filtresi
          if (_projeler.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.filter_list_rounded),
              tooltip: 'Proje Filtrele',
              onSelected: (v) => setState(() => _filtrePraje = v),
              itemBuilder: (_) => [
                const PopupMenuItem(value: '',
                    child: Text('Tümü')),
                ..._projeler.map((p) => PopupMenuItem(
                    value: p['id'] as String,
                    child: Text(p['projeAd'] ?? ''))),
              ],
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _turuncu,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Şoför Ekle',
            style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _soforEkleDialog(context),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _filtrePraje.isEmpty
            ? FirebaseFirestore.instance
                .collection('drivers')
                .where('firmaId', isEqualTo: _firmaId)
                .orderBy('olusturma', descending: true)
                .snapshots()
            : FirebaseFirestore.instance
                .collection('drivers')
                .where('firmaId', isEqualTo: _firmaId)
                .where('projeId', isEqualTo: _filtrePraje)
                .orderBy('olusturma', descending: true)
                .snapshots(),
        builder: (_, snap) {
          final soforler = snap.data?.docs ?? [];

          if (soforler.isEmpty) {
            return Center(child: Column(
                mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.directions_bus_outlined,
                  size: 80, color: Colors.grey[300]),
              const SizedBox(height: 16),
              const Text('Henüz şoför eklenmedi',
                  style: TextStyle(fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1a3a6b))),
              const SizedBox(height: 8),
              const Text('Şoför ekleyerek servisi başlatın',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _turuncu,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                onPressed: () => _soforEkleDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Şoför Ekle',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ]));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: soforler.length,
            itemBuilder: (_, i) {
              final doc  = soforler[i];
              final data = doc.data() as Map<String, dynamic>;
              return _SoforKarti(
                docId: doc.id,
                data: data,
                projeler: _projeler,
                onDuzenle: () => _soforDuzenleDialog(context, doc.id, data),
              );
            },
          );
        },
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // ŞOFÖR EKLE DİALOG — Tam spec
  // ════════════════════════════════════════════════════════════
  void _soforEkleDialog(BuildContext context) {
    final adCtrl       = TextEditingController();
    final telCtrl      = TextEditingController();
    final plakaCtrl    = TextEditingController();
    final kapasiteCtrl = TextEditingController();
    final modelCtrl    = TextEditingController();
    final kulAdiCtrl   = TextEditingController();
    final sifreCtrl    = TextEditingController();

    String? seciliProjeId;
    String  seciliProjeAd = '';
    String  servisTuru    = 'okul';
    bool    aktif         = true;
    bool    yukleniyor    = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 560,
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.9),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white),
            child: Column(children: [

              // Başlık
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                    color: _navy,
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20))),
                child: Row(children: [
                  const Icon(Icons.person_add_rounded,
                      color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Yeni Şoför Ekle',
                      style: TextStyle(color: Colors.white,
                          fontSize: 18, fontWeight: FontWeight.bold))),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx)),
                ]),
              ),

              // Form
              Expanded(child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                  // 1. PROJE SEÇ
                  _bolumBaslik('1. Proje Seç', Icons.folder_outlined),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: _inputDec('Proje / Okul *',
                        Icons.folder_outlined),
                    hint: const Text('Proje seçin'),
                    value: seciliProjeId,
                    items: _projeler.map((p) => DropdownMenuItem(
                      value: p['id'] as String,
                      child: Text(p['projeAd'] ?? ''),
                    )).toList(),
                    onChanged: (v) => setSt(() {
                      seciliProjeId = v;
                      seciliProjeAd = _projeler.firstWhere(
                          (p) => p['id'] == v,
                          orElse: () => {})['projeAd'] ?? '';
                    }),
                  ),
                  const SizedBox(height: 20),

                  // 2. ŞOFÖR BİLGİLERİ
                  _bolumBaslik('2. Şoför Bilgileri',
                      Icons.person_outlined),
                  const SizedBox(height: 8),
                  _satirIkiIki(
                    _inp2(adCtrl, 'Şoför Adı Soyadı *',
                        Icons.person_outlined),
                    _inp2(telCtrl, 'Telefon *',
                        Icons.phone_outlined,
                        tip: TextInputType.phone),
                  ),
                  const SizedBox(height: 10),
                  _satirIkiIki(
                    _inp2(plakaCtrl, 'Araç Plakası *',
                        Icons.directions_bus_outlined),
                    _inp2(kapasiteCtrl, 'Araç Kapasitesi',
                        Icons.people_outlined,
                        tip: TextInputType.number),
                  ),
                  const SizedBox(height: 10),
                  _inp2(modelCtrl, 'Araç Markası / Modeli',
                      Icons.directions_car_outlined),
                  const SizedBox(height: 10),

                  // Aktif toggle
                  Row(children: [
                    const Text('Aktif Şoför',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Switch(
                      value: aktif,
                      activeColor: Colors.green,
                      onChanged: (v) => setSt(() => aktif = v),
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // 3. GİRİŞ BİLGİLERİ
                  _bolumBaslik('3. Giriş Bilgileri',
                      Icons.lock_outlined),
                  const SizedBox(height: 4),
                  const Text(
                    'Şoför bu bilgilerle sisteme giriş yapar. '
                    'Sonradan şifresini değiştirebilir.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  _satirIkiIki(
                    _inp2(kulAdiCtrl, 'Kullanıcı Adı *',
                        Icons.account_circle_outlined),
                    _inp2(sifreCtrl, 'Geçici Şifre *',
                        Icons.key_outlined),
                  ),
                  const SizedBox(height: 20),

                  // 4. GÖREV TÜRÜ
                  _bolumBaslik('4. Servis Türü',
                      Icons.assignment_outlined),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    _turBtn('okul',     '🏫 Okul',     servisTuru,
                        (v) => setSt(() => servisTuru = v)),
                    _turBtn('kolej',    '🎓 Kolej',    servisTuru,
                        (v) => setSt(() => servisTuru = v)),
                    _turBtn('personel', '👔 Personel', servisTuru,
                        (v) => setSt(() => servisTuru = v)),
                    _turBtn('sabah',    '🌅 Sabah',    servisTuru,
                        (v) => setSt(() => servisTuru = v)),
                    _turBtn('aksam',    '🌇 Akşam',    servisTuru,
                        (v) => setSt(() => servisTuru = v)),
                  ]),

                  const SizedBox(height: 20),

                  // Bilgi notu
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.amber.shade200)),
                    child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Icon(Icons.info_outline,
                          color: Colors.amber, size: 16),
                      SizedBox(width: 8),
                      Expanded(child: Text(
                        'Kayıt sonrası şoföre güzergah ve öğrenci '
                        'listesi atayı. Bu bağlantı olmadan şoför '
                        'paneli boş görünür.',
                        style: TextStyle(fontSize: 12,
                            color: Colors.amber),
                      )),
                    ]),
                  ),
                ]),
              )),

              // Alt butonlar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                    border: Border(top: BorderSide(
                        color: Color(0xFFEEEEEE)))),
                child: Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    child: const Text('İptal'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _navy,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    onPressed: yukleniyor
                        ? null
                        : () async {
                            // Validasyon
                            if (adCtrl.text.trim().isEmpty) {
                              _snack(ctx, 'Şoför adı zorunlu!');
                              return;
                            }
                            if (telCtrl.text.trim().isEmpty) {
                              _snack(ctx, 'Telefon zorunlu!');
                              return;
                            }
                            if (plakaCtrl.text.trim().isEmpty) {
                              _snack(ctx, 'Araç plakası zorunlu!');
                              return;
                            }
                            if (kulAdiCtrl.text.trim().isEmpty) {
                              _snack(ctx, 'Kullanıcı adı zorunlu!');
                              return;
                            }
                            if (sifreCtrl.text.trim().isEmpty) {
                              _snack(ctx, 'Şifre zorunlu!');
                              return;
                            }
                            if (seciliProjeId == null) {
                              _snack(ctx, 'Proje seçimi zorunlu!');
                              return;
                            }

                            setSt(() => yukleniyor = true);

                            // Kullanıcı adı kullanılmış mı?
                            final kulAdiKont = await FirebaseFirestore
                                .instance.collection('drivers')
                                .where('kullaniciAdi',
                                    isEqualTo: kulAdiCtrl.text.trim())
                                .get();
                            if (kulAdiKont.docs.isNotEmpty) {
                              setSt(() => yukleniyor = false);
                              _snack(ctx,
                                  'Bu kullanıcı adı zaten kullanılıyor!');
                              return;
                            }

                            // Telefon kullanılmış mı?
                            final telKont = await FirebaseFirestore
                                .instance.collection('drivers')
                                .where('firmaId', isEqualTo: _firmaId)
                                .where('telefon',
                                    isEqualTo: telCtrl.text.trim())
                                .get();
                            if (telKont.docs.isNotEmpty) {
                              setSt(() => yukleniyor = false);
                              _snack(ctx,
                                  'Bu telefon numarası zaten kayıtlı!');
                              return;
                            }

                            try {
                              final now = FieldValue.serverTimestamp();
                              final ref = await FirebaseFirestore.instance
                                  .collection('drivers').add({
                                'adSoyad'       : adCtrl.text.trim(),
                                'ad'            : adCtrl.text.trim(),
                                'telefon'       : telCtrl.text.trim(),
                                'plaka'         : plakaCtrl.text.trim(),
                                'aracPlaka'     : plakaCtrl.text.trim(),
                                'aracKapasitesi': kapasiteCtrl.text.trim(),
                                'aracModeli'    : modelCtrl.text.trim(),
                                'kullaniciAdi'  : kulAdiCtrl.text.trim(),
                                'geciciSifre'   : sifreCtrl.text.trim(),
                                'aktifMi'       : aktif,
                                'aktif'         : aktif,
                                'firmaId'       : _firmaId,
                                'projeId'       : seciliProjeId,
                                'projeAd'       : seciliProjeAd,
                                'servisTuru'    : servisTuru,
                                'rol'           : 'sofor',
                                'servisAktif'   : false,
                                'olusturma'     : now,
                                'createdAt'     : now,
                                'updatedAt'     : now,
                              });

                              // kullanicilar koleksiyonuna da ekle
                              await FirebaseFirestore.instance
                                  .collection('kullanicilar')
                                  .doc(ref.id).set({
                                'ad'          : adCtrl.text.trim(),
                                'telefon'     : telCtrl.text.trim(),
                                'kullaniciAdi': kulAdiCtrl.text.trim(),
                                'sifre'       : sifreCtrl.text.trim(),
                                'rol'         : 'sofor',
                                'firmaId'     : _firmaId,
                                'projeId'     : seciliProjeId,
                                'driverId'    : ref.id,
                                'aktif'       : aktif,
                                'olusturma'   : now,
                              });

                              if (ctx.mounted) Navigator.pop(ctx);

                              // WhatsApp gönder seçeneği
                              if (context.mounted) {
                                _whatsappOneriDialog(
                                  context,
                                  adCtrl.text.trim(),
                                  telCtrl.text.trim(),
                                  kulAdiCtrl.text.trim(),
                                  sifreCtrl.text.trim(),
                                );
                              }
                            } catch (e) {
                              setSt(() => yukleniyor = false);
                              _snack(ctx, 'Hata: $e');
                            }
                          },
                    icon: yukleniyor
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save_rounded),
                    label: Text(yukleniyor
                        ? 'Kaydediliyor...' : 'Şoförü Kaydet',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  )),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── WhatsApp önerisi ──────────────────────────────────────────
  void _whatsappOneriDialog(BuildContext ctx, String ad, String tel,
      String kulAdi, String sifre) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(width: 36, height: 36,
              decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withOpacity(0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.message,
                  color: Color(0xFF25D366), size: 20)),
          const SizedBox(width: 10),
          const Text('WhatsApp ile Gönder'),
        ]),
        content: Text(
          '$ad eklendi! Giriş bilgilerini WhatsApp ile '
          'göndermek ister misiniz?\n\n'
          '👤 Kullanıcı: $kulAdi\n'
          '🔑 Şifre: $sifre',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(_),
            child: const Text('Hayır'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(_);
              final temizTel = tel.replaceAll(
                  RegExp(r'[^0-9]'), '');
              final mesaj = Uri.encodeComponent(
                'Servisim360 Giris Bilgileriniz:\n'
                'Kullanici Adi: $kulAdi\n'
                'Gecici Sifre: $sifre\n'
                'Uygulamamizi indirin ve giris yapin.');
              final url = Uri.parse(
                  'https://wa.me/90$temizTel?text=$mesaj');
              if (await canLaunchUrl(url)) {
                await launchUrl(url,
                    mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('WhatsApp Gönder',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Şoför Düzenle ─────────────────────────────────────────────
  void _soforDuzenleDialog(BuildContext context, String docId,
      Map<String, dynamic> data) {
    final adCtrl       = TextEditingController(
        text: data['adSoyad'] ?? data['ad'] ?? '');
    final telCtrl      = TextEditingController(
        text: data['telefon'] ?? '');
    final plakaCtrl    = TextEditingController(
        text: data['plaka'] ?? data['aracPlaka'] ?? '');
    final kapasiteCtrl = TextEditingController(
        text: data['aracKapasitesi'] ?? '');
    final modelCtrl    = TextEditingController(
        text: data['aracModeli'] ?? '');
    bool aktif         = data['aktif'] as bool? ?? true;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Text('${data['adSoyad'] ?? data['ad'] ?? ''} '
              'Düzenle'),
          content: SizedBox(width: 480,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min,
                  children: [
                _inp2(adCtrl, 'Şoför Adı *', Icons.person_outlined),
                const SizedBox(height: 10),
                _inp2(telCtrl, 'Telefon', Icons.phone_outlined,
                    tip: TextInputType.phone),
                const SizedBox(height: 10),
                _inp2(plakaCtrl, 'Plaka',
                    Icons.directions_bus_outlined),
                const SizedBox(height: 10),
                _inp2(kapasiteCtrl, 'Kapasite',
                    Icons.people_outlined,
                    tip: TextInputType.number),
                const SizedBox(height: 10),
                _inp2(modelCtrl, 'Araç Modeli',
                    Icons.directions_car_outlined),
                const SizedBox(height: 10),
                Row(children: [
                  const Text('Aktif',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Switch(
                    value: aktif,
                    activeColor: Colors.green,
                    onChanged: (v) => setSt(() => aktif = v),
                  ),
                ]),
              ]),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _navy, foregroundColor: Colors.white),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('drivers').doc(docId).update({
                  'adSoyad'       : adCtrl.text.trim(),
                  'ad'            : adCtrl.text.trim(),
                  'telefon'       : telCtrl.text.trim(),
                  'plaka'         : plakaCtrl.text.trim(),
                  'aracPlaka'     : plakaCtrl.text.trim(),
                  'aracKapasitesi': kapasiteCtrl.text.trim(),
                  'aracModeli'    : modelCtrl.text.trim(),
                  'aktif'         : aktif,
                  'aktifMi'       : aktif,
                  'updatedAt'     : FieldValue.serverTimestamp(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  void _snack(BuildContext ctx, String m) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(m),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating));
  }

  // ── Yardımcı widgetlar ────────────────────────────────────────
  Widget _bolumBaslik(String text, IconData icon) => Row(children: [
    Icon(icon, color: _navy, size: 18),
    const SizedBox(width: 8),
    Text(text, style: const TextStyle(
        fontWeight: FontWeight.bold, fontSize: 14, color: _navy)),
  ]);

  Widget _satirIkiIki(Widget a, Widget b) =>
      Row(children: [Expanded(child: a),
        const SizedBox(width: 10), Expanded(child: b)]);

  InputDecoration _inputDec(String label, IconData icon) =>
      InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _navy, size: 18),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 12),
      );

  Widget _inp2(TextEditingController c, String label, IconData icon,
      {TextInputType tip = TextInputType.text}) =>
      TextField(
        controller: c, keyboardType: tip,
        decoration: _inputDec(label, icon),
      );

  Widget _turBtn(String deger, String label, String secili,
      Function(String) onChange) {
    final sec = secili == deger;
    return GestureDetector(
      onTap: () => onChange(deger),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: sec ? _navy : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: sec ? _navy : Colors.grey.shade300)),
        child: Text(label, style: TextStyle(
            color: sec ? Colors.white : Colors.grey,
            fontSize: 12, fontWeight: sec
                ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ŞOFÖR KARTI
// ════════════════════════════════════════════════════════════════
class _SoforKarti extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final List<Map<String, dynamic>> projeler;
  final VoidCallback onDuzenle;

  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  const _SoforKarti({
    required this.docId, required this.data,
    required this.projeler, required this.onDuzenle,
  });

  @override
  Widget build(BuildContext context) {
    final ad       = data['adSoyad'] ?? data['ad'] ?? '';
    final tel      = data['telefon'] ?? '';
    final plaka    = data['plaka']   ?? data['aracPlaka'] ?? '';
    final projeAd  = data['projeAd'] ?? '';
    final kapasite = data['aracKapasitesi'] ?? '';
    final model    = data['aracModeli']     ?? '';
    final kulAdi   = data['kullaniciAdi']   ?? '';
    final servis   = data['servisTuru']     ?? '';
    final aktif    = data['aktif']  as bool? ?? true;
    final servisAk = data['servisAktif'] as bool? ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [

          // Üst satır
          Row(children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: aktif
                  ? _navy.withOpacity(0.1) : Colors.grey.shade200,
              child: Text(
                ad.isNotEmpty ? ad[0].toUpperCase() : 'Ş',
                style: TextStyle(
                    color: aktif ? _navy : Colors.grey,
                    fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Row(children: [
                Expanded(child: Text(ad,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15, color: _navy))),
                // Servis durumu
                if (servisAk)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.green.shade200)),
                    child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      Icon(Icons.circle,
                          color: Colors.green, size: 8),
                      SizedBox(width: 4),
                      Text('Serviste',
                          style: TextStyle(
                              color: Colors.green,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ]),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: aktif
                            ? Colors.grey.shade100
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(aktif ? 'Bekliyor' : 'Pasif',
                        style: TextStyle(
                            color: aktif
                                ? Colors.grey : Colors.red,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
              ]),
              const SizedBox(height: 4),
              Wrap(spacing: 12, children: [
                if (tel.isNotEmpty)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.phone_outlined,
                        size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(tel, style: const TextStyle(
                        fontSize: 12, color: Colors.grey)),
                  ]),
                if (kulAdi.isNotEmpty)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.account_circle_outlined,
                        size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('@$kulAdi', style: const TextStyle(
                        fontSize: 12, color: Colors.grey)),
                  ]),
              ]),
            ])),
          ]),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Araç ve proje bilgisi
          Row(children: [
            _bilgiCip(Icons.directions_bus_rounded,
                plaka.isNotEmpty ? plaka : 'Plaka yok',
                Colors.blue),
            const SizedBox(width: 8),
            if (kapasite.isNotEmpty)
              _bilgiCip(Icons.people_rounded,
                  '$kapasite kişi', Colors.purple),
            if (kapasite.isNotEmpty) const SizedBox(width: 8),
            if (projeAd.isNotEmpty)
              Expanded(child: _bilgiCip(Icons.folder_rounded,
                  projeAd, _navy)),
          ]),
          if (model.isNotEmpty || servis.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              if (model.isNotEmpty)
                _bilgiCip(Icons.directions_car_rounded,
                    model, Colors.teal),
              if (model.isNotEmpty && servis.isNotEmpty)
                const SizedBox(width: 8),
              if (servis.isNotEmpty)
                _bilgiCip(Icons.schedule_rounded,
                    _servisTuruAd(servis), _turuncu),
            ]),
          ],

          const SizedBox(height: 12),

          // Aksiyon butonları
          Row(children: [
            // Telefon
            _akBtn(Icons.phone_rounded, 'Ara', Colors.green,
                tel.isNotEmpty ? () async {
              final uri = Uri.parse('tel:$tel');
              if (await canLaunchUrl(uri)) launchUrl(uri);
            } : null),
            const SizedBox(width: 8),
            // WhatsApp
            _akBtn(Icons.message_rounded, 'WA',
                const Color(0xFF25D366),
                tel.isNotEmpty ? () async {
              final temiz = tel.replaceAll(RegExp(r'[^0-9]'), '');
              final url   = Uri.parse('https://wa.me/90$temiz');
              if (await canLaunchUrl(url)) {
                launchUrl(url, mode: LaunchMode.externalApplication);
              }
            } : null),
            const Spacer(),
            // Aktif/Pasif toggle
            Switch(
              value: aktif,
              activeColor: Colors.green,
              onChanged: (v) async {
                await FirebaseFirestore.instance
                    .collection('drivers').doc(docId)
                    .update({'aktif': v, 'aktifMi': v,
                      'updatedAt': FieldValue.serverTimestamp()});
              },
            ),
            const SizedBox(width: 8),
            // Düzenle
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: _navy),
              onPressed: onDuzenle,
              tooltip: 'Düzenle',
            ),
            // Sil
            IconButton(
              icon: const Icon(Icons.delete_rounded,
                  color: Colors.red),
              tooltip: 'Sil',
              onPressed: () async {
                final onay = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Şoförü Sil'),
                    content: Text('$ad silinsin mi? '
                        'Bu işlem geri alınamaz.'),
                    actions: [
                      TextButton(
                          onPressed: () =>
                              Navigator.pop(context, false),
                          child: const Text('İptal')),
                      ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red),
                          onPressed: () =>
                              Navigator.pop(context, true),
                          child: const Text('Sil',
                              style: TextStyle(
                                  color: Colors.white))),
                    ],
                  ),
                );
                if (onay == true) {
                  await FirebaseFirestore.instance
                      .collection('drivers').doc(docId).delete();
                  // kullanicilar koleksiyonundan da sil
                  await FirebaseFirestore.instance
                      .collection('kullanicilar').doc(docId).delete();
                }
              },
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _bilgiCip(IconData icon, String label, Color renk) =>
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: renk.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: renk.withOpacity(0.2))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: renk),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(
              fontSize: 11, color: renk,
              fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _akBtn(IconData icon, String label, Color renk,
      VoidCallback? onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: onTap != null
                  ? renk.withOpacity(0.1) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: onTap != null
                      ? renk.withOpacity(0.3)
                      : Colors.grey.shade300)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14,
                color: onTap != null ? renk : Colors.grey),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold,
                color: onTap != null ? renk : Colors.grey)),
          ]),
        ),
      );

  String _servisTuruAd(String t) {
    switch (t) {
      case 'okul':     return 'Okul';
      case 'kolej':    return 'Kolej';
      case 'personel': return 'Personel';
      case 'sabah':    return 'Sabah';
      case 'aksam':    return 'Akşam';
      default:         return t;
    }
  }
}
