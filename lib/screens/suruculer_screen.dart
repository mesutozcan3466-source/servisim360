// ╔══════════════════════════════════════════════════════════════╗
// ║  DOSYA: lib/screens/suruculer_screen.dart
// ║  PROJE: servisim360
// ║  GÜNCELLEME: Şoför Yönetimi v2 – Tam Özellik Seti
// ╚══════════════════════════════════════════════════════════════╝
import 'package:flutter/material.dart';
import 'ai_widget.dart';
import 'yardim_widget.dart';
import 'sofor_sozlesme_screen.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../services/session_service.dart';

// ── Şoför Durum Enum ─────────────────────────────────────────────
enum SoforDurum { bosta, projeyeDahil, aktifGorevde, pasif }

extension SoforDurumExt on SoforDurum {
  String get label {
    switch (this) {
      case SoforDurum.bosta:         return 'Boşta';
      case SoforDurum.projeyeDahil:  return 'Projeye Dahil';
      case SoforDurum.aktifGorevde:  return 'Aktif Görevde';
      case SoforDurum.pasif:         return 'Pasif';
    }
  }

  Color get renk {
    switch (this) {
      case SoforDurum.bosta:         return Colors.orange;
      case SoforDurum.projeyeDahil:  return Colors.blue;
      case SoforDurum.aktifGorevde:  return Colors.green;
      case SoforDurum.pasif:         return Colors.grey;
    }
  }

  IconData get ikon {
    switch (this) {
      case SoforDurum.bosta:         return Icons.hourglass_empty_rounded;
      case SoforDurum.projeyeDahil:  return Icons.folder_special_rounded;
      case SoforDurum.aktifGorevde:  return Icons.directions_bus_rounded;
      case SoforDurum.pasif:         return Icons.block_rounded;
    }
  }

  String get firestoreKey {
    switch (this) {
      case SoforDurum.bosta:         return 'bosta';
      case SoforDurum.projeyeDahil:  return 'projeyeDahil';
      case SoforDurum.aktifGorevde:  return 'aktifGorevde';
      case SoforDurum.pasif:         return 'pasif';
    }
  }

  static SoforDurum fromString(String? s) {
    switch (s) {
      case 'projeyeDahil':  return SoforDurum.projeyeDahil;
      case 'aktifGorevde':  return SoforDurum.aktifGorevde;
      case 'pasif':         return SoforDurum.pasif;
      default:              return SoforDurum.bosta;
    }
  }
}

// ════════════════════════════════════════════════════════════════
// ANA EKRAN
// ════════════════════════════════════════════════════════════════
class SurucularScreen extends StatefulWidget {
  const SurucularScreen({super.key});
  @override
  State<SurucularScreen> createState() => _SurucularScreenState();
}

class _SurucularScreenState extends State<SurucularScreen> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  String? _firmaId;
  String  _aramaMetni   = '';
  SoforDurum? _filtredurum; // null = tümü
  List<Map<String, dynamic>> _projeler = [];
  final _aramaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _aramaCtrl.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    final fId = await SessionService.instance.firmaIdAl();
    if (!mounted) return;
    setState(() => _firmaId = fId);
    if (fId == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('projects')
        .where('firmaId', isEqualTo: fId)
        .where('aktif', isEqualTo: true)
        .get();
    if (mounted) {
      setState(() {
        _projeler = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      });
    }
  }

  // ── Filtre çipleri ─────────────────────────────────────────────
  Widget _filtreCipleri() {
    final List<MapEntry<SoforDurum?, String>> secenekler = [
      const MapEntry(null, 'Tümü'),
      MapEntry(SoforDurum.bosta,        'Boşta'),
      MapEntry(SoforDurum.projeyeDahil, 'Projeye Dahil'),
      MapEntry(SoforDurum.aktifGorevde, 'Aktif Görevde'),
      MapEntry(SoforDurum.pasif,        'Pasif'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: secenekler.map((e) {
          final secili = _filtredurum == e.key;
          final renk   = e.key?.renk ?? _navy;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: secili,
              label: Text(e.value,
                  style: TextStyle(
                      fontSize: 12,
                      color: secili ? Colors.white : renk,
                      fontWeight: FontWeight.w600)),
              backgroundColor: renk.withValues(alpha: 0.08),
              selectedColor: renk,
              checkmarkColor: Colors.white,
              side: BorderSide(color: renk.withValues(alpha: 0.3)),
              onSelected: (_) => setState(() => _filtredurum = e.key),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Arama kutusu ───────────────────────────────────────────────
  Widget _aramaKutusu() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: TextField(
      controller: _aramaCtrl,
      onChanged: (v) => setState(() => _aramaMetni = v.toLowerCase()),
      decoration: InputDecoration(
        hintText: 'Ad, telefon, plaka veya kullanıcı adı ara...',
        hintStyle: const TextStyle(fontSize: 13),
        prefixIcon: const Icon(Icons.search_rounded, color: _navy),
        suffixIcon: _aramaMetni.isNotEmpty
            ? IconButton(
            icon: const Icon(Icons.clear_rounded),
            onPressed: () {
              _aramaCtrl.clear();
              setState(() => _aramaMetni = '');
            })
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
      ),
    ),
  );

  bool _aramaFiltrele(Map<String, dynamic> data) {
    if (_aramaMetni.isEmpty) return true;
    final ad    = (data['adSoyad'] ?? data['ad'] ?? '').toLowerCase();
    final tel   = (data['telefon'] ?? '').toLowerCase();
    final plaka = (data['plaka'] ?? data['aracPlaka'] ?? '').toLowerCase();
    final kadi  = (data['kullaniciAdi'] ?? '').toLowerCase();
    return ad.contains(_aramaMetni)   ||
        tel.contains(_aramaMetni)  ||
        plaka.contains(_aramaMetni)||
        kadi.contains(_aramaMetni);
  }

  @override
  Widget build(BuildContext context) {
    if (_firmaId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: const Text('Şoförler',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          AiAsistanButonu(ekranAdi: 'Servisler'),
          YardimButonu(ekranAdi: 'Servisler'),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yenile',
            onPressed: _yukle,
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
      body: Column(children: [
        const SizedBox(height: 8),
        _aramaKutusu(),
        _filtreCipleri(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('drivers')
                .where('firmaId', isEqualTo: _firmaId)
                .orderBy('olusturma', descending: true)
                .snapshots(),
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              var soforler = (snap.data?.docs ?? [])
                  .map((d) => {'_id': d.id, ...d.data() as Map<String, dynamic>})
                  .where(_aramaFiltrele)
                  .toList();

              // Durum filtresi
              if (_filtredurum != null) {
                soforler = soforler.where((d) {
                  final durum = SoforDurumExt.fromString(d['soforDurum']);
                  return durum == _filtredurum;
                }).toList();
              }

              if (soforler.isEmpty) {
                return Center(child: Column(
                    mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.directions_bus_outlined,
                      size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                      _aramaMetni.isNotEmpty || _filtredurum != null
                          ? 'Arama sonucu bulunamadı'
                          : 'Henüz şoför eklenmedi',
                      style: const TextStyle(fontSize: 18,
                          fontWeight: FontWeight.bold, color: _navy)),
                  const SizedBox(height: 24),
                  if (_aramaMetni.isEmpty && _filtredurum == null)
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
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                itemCount: soforler.length,
                itemBuilder: (_, i) {
                  final data  = soforler[i];
                  final docId = data['_id'] as String;
                  return _SoforKarti(
                    docId: docId,
                    data: data,
                    projeler: _projeler,
                    firmaId: _firmaId!,
                    onDuzenle: () => _soforDuzenleDialog(context, docId, data),
                    onDetay: () => _soforDetayDialog(context, docId, data),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // ŞOFÖR EKLE DİALOG
  // ════════════════════════════════════════════════════════════════
  void _soforEkleDialog(BuildContext context) {
    final adCtrl        = TextEditingController();
    final telCtrl       = TextEditingController();
    final plakaCtrl     = TextEditingController();
    final kapasiteCtrl  = TextEditingController();
    final modelCtrl     = TextEditingController();
    final kulAdiCtrl    = TextEditingController();
    final sifreCtrl     = TextEditingController();
    final tcCtrl        = TextEditingController();
    final ehliyetCtrl   = TextEditingController();
    final srcCtrl       = TextEditingController();
    final psikoCtrl     = TextEditingController();

    String servisTuru = 'okul';
    bool   aktif      = true;
    bool   yukleniyor = false;

    // Geçici şifre otomatik oluştur
    sifreCtrl.text = _rastgeleKod();

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
                  const Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Yeni Şoför Ekle',
                          style: TextStyle(color: Colors.white,
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Firma havuzuna kayıt — proje sonra atanır',
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  )),
                  IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx)),
                ]),
              ),

              // Form
              Expanded(child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Akış bilgisi
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.blue.shade200)),
                        child: const Row(children: [
                          Icon(Icons.info_outline, color: Colors.blue, size: 16),
                          SizedBox(width: 8),
                          Expanded(child: Text(
                            'Şoför → Firma Havuzu → Boşta → Projeye Dahil Et → Öğrenci Ata → Aktif Görev',
                            style: TextStyle(fontSize: 11, color: Colors.blue),
                          )),
                        ]),
                      ),

                      // 1. ŞOFÖR BİLGİLERİ
                      _bolumBaslik('1. Şoför Bilgileri', Icons.person_outlined),
                      const SizedBox(height: 8),
                      _satirIkiIki(
                        _inp2(adCtrl, 'Şoför Adı Soyadı *', Icons.person_outlined),
                        _inp2(telCtrl, 'Telefon *', Icons.phone_outlined,
                            tip: TextInputType.phone),
                      ),
                      const SizedBox(height: 10),
                      _satirIkiIki(
                        _inp2(plakaCtrl, 'Araç Plakası *',
                            Icons.directions_bus_outlined),
                        _inp2(kapasiteCtrl, 'Kapasite',
                            Icons.people_outlined,
                            tip: TextInputType.number),
                      ),
                      const SizedBox(height: 10),
                      _inp2(modelCtrl, 'Araç Markası / Modeli',
                          Icons.directions_car_outlined),
                      const SizedBox(height: 10),
                      Row(children: [
                        const Text('Aktif Şoför',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Switch(
                          value: aktif, activeColor: Colors.green,
                          onChanged: (v) => setSt(() => aktif = v),
                        ),
                      ]),
                      const SizedBox(height: 20),

                      // 2. GİRİŞ BİLGİLERİ
                      _bolumBaslik('2. Giriş Bilgileri', Icons.lock_outlined),
                      const SizedBox(height: 4),
                      const Text(
                        'Şoför bu bilgilerle sisteme giriş yapar.',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      _inp2(kulAdiCtrl, 'Kullanıcı Adı *',
                          Icons.account_circle_outlined),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: _inp2(sifreCtrl, 'Geçici Şifre *',
                            Icons.key_outlined)),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Yeni şifre üret',
                          icon: const Icon(Icons.refresh_rounded, color: _navy),
                          onPressed: () =>
                              setSt(() => sifreCtrl.text = _rastgeleKod()),
                        ),
                      ]),
                      const SizedBox(height: 20),

                      // 2b. İSTEĞE BAĞLI BELGELER
                      _bolumBaslik('2b. İsteğe Bağlı Belgeler', Icons.badge_outlined),
                      const SizedBox(height: 4),
                      const Text('Zorunlu değil, ileride eklenebilir',
                          style: TextStyle(color: Colors.grey, fontSize: 11)),
                      const SizedBox(height: 8),
                      _satirIkiIki(
                        _inp2(tcCtrl, 'TC Kimlik No', Icons.credit_card_outlined,
                            tip: TextInputType.number),
                        _inp2(ehliyetCtrl, 'Ehliyet Sınıfı', Icons.drive_eta_outlined),
                      ),
                      const SizedBox(height: 10),
                      _satirIkiIki(
                        _inp2(srcCtrl, 'SRC Belgesi No', Icons.article_outlined),
                        _inp2(psikoCtrl, 'Psikoteknik Tarihi',
                            Icons.calendar_today_outlined),
                      ),
                      const SizedBox(height: 20),

                      // 3. SERVİS TÜRÜ
                      _bolumBaslik('3. Servis Türü', Icons.assignment_outlined),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        _turBtn('okul',     '🏫 Okul',     servisTuru,
                                (v) => setSt(() => servisTuru = v)),
                        _turBtn('kolej',    '🎓 Kolej',    servisTuru,
                                (v) => setSt(() => servisTuru = v)),
                        _turBtn('personel', '👔 Personel', servisTuru,
                                (v) => setSt(() => servisTuru = v)),
                        _turBtn('ozel',     '🚐 Özel',     servisTuru,
                                (v) => setSt(() => servisTuru = v)),
                        _turBtn('sabah',    '🌅 Sabah',    servisTuru,
                                (v) => setSt(() => servisTuru = v)),
                        _turBtn('aksam',    '🌇 Akşam',    servisTuru,
                                (v) => setSt(() => servisTuru = v)),
                      ]),

                      const SizedBox(height: 20),

                      // Not
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.shade200)),
                        child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline, color: Colors.amber, size: 16),
                              SizedBox(width: 8),
                              Expanded(child: Text(
                                'Proje atanmadan şoför paneli boş görünür. '
                                    'Kayıt sonrası "Projeye Dahil Et" ile proje atayın.',
                                style: TextStyle(fontSize: 12, color: Colors.amber),
                              )),
                            ]),
                      ),
                    ]),
              )),

              // Alt butonlar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFEEEEEE)))),
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
                    onPressed: yukleniyor ? null : () async {
                      if (adCtrl.text.trim().isEmpty) {
                        _snack(ctx, 'Şoför adı zorunlu!'); return;
                      }
                      if (telCtrl.text.trim().isEmpty) {
                        _snack(ctx, 'Telefon zorunlu!'); return;
                      }
                      if (plakaCtrl.text.trim().isEmpty) {
                        _snack(ctx, 'Plaka zorunlu!'); return;
                      }
                      if (kulAdiCtrl.text.trim().isEmpty) {
                        _snack(ctx, 'Kullanıcı adı zorunlu!'); return;
                      }
                      if (sifreCtrl.text.trim().isEmpty) {
                        _snack(ctx, 'Şifre zorunlu!'); return;
                      }

                      setSt(() => yukleniyor = true);

                      // Kullanıcı adı kontrolü
                      final kulKont = await FirebaseFirestore.instance
                          .collection('drivers')
                          .where('kullaniciAdi',
                          isEqualTo: kulAdiCtrl.text.trim())
                          .get();
                      if (kulKont.docs.isNotEmpty) {
                        setSt(() => yukleniyor = false);
                        _snack(ctx, 'Bu kullanıcı adı zaten kullanılıyor!');
                        return;
                      }

                      // Telefon kontrolü
                      final telKont = await FirebaseFirestore.instance
                          .collection('drivers')
                          .where('firmaId', isEqualTo: _firmaId)
                          .where('telefon', isEqualTo: telCtrl.text.trim())
                          .get();
                      if (telKont.docs.isNotEmpty) {
                        setSt(() => yukleniyor = false);
                        _snack(ctx, 'Bu telefon zaten kayıtlı!');
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
                          'servisTuru'    : servisTuru,
                          'rol'           : 'sofor',
                          'servisAktif'   : false,
                          'tcKimlik'      : tcCtrl.text.trim(),
                          'ehliyetSinifi' : ehliyetCtrl.text.trim(),
                          'srcBelgesi'    : srcCtrl.text.trim(),
                          'psikoTarih'    : psikoCtrl.text.trim(),
                          'soforDurum'    : aktif ? 'bosta' : 'pasif',
                          'projeler'      : [],   // Birden fazla proje desteği
                          'projeId'       : null,
                          'projeAd'       : null,
                          'olusturma'     : now,
                          'createdAt'     : now,
                          'updatedAt'     : now,
                          'sonGiris'      : null,
                        });

                        await FirebaseFirestore.instance
                            .collection('kullanicilar')
                            .doc(ref.id).set({
                          'ad'          : adCtrl.text.trim(),
                          'telefon'     : telCtrl.text.trim(),
                          'kullaniciAdi': kulAdiCtrl.text.trim(),
                          'sifre'       : sifreCtrl.text.trim(),
                          'rol'         : 'sofor',
                          'firmaId'     : _firmaId,
                          'driverId'    : ref.id,
                          'aktif'       : aktif,
                          'olusturma'   : now,
                        });

                        if (ctx.mounted) Navigator.pop(ctx);

                        if (context.mounted) {
                          _girisGonderDialog(
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
                    label: Text(yukleniyor ? 'Kaydediliyor...' : 'Şoförü Kaydet',
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

  // ════════════════════════════════════════════════════════════════
  // GİRİŞ BİLGİLERİ GÖNDER DİALOG
  // ════════════════════════════════════════════════════════════════
  void _girisGonderDialog(BuildContext ctx, String ad, String tel,
      String kulAdi, String sifre) {
    final mesaj =
        'Servisim360 Giriş Bilgileri\n'
        '👤 Kullanıcı Adı: $kulAdi\n'
        '🔑 Geçici Şifre: $sifre\n'
        'Uygulamayı indirip giriş yapabilirsiniz.';

    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: _navy.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.send_rounded, color: _navy, size: 18)),
          const SizedBox(width: 10),
          const Expanded(child: Text('Giriş Bilgilerini Gönder')),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200)),
            child: Text(mesaj, style: const TextStyle(fontSize: 13)),
          ),
          const SizedBox(height: 16),
          const Text('Nasıl göndermek istersiniz?',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
        actions: [
          // Kopyala
          OutlinedButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Kopyala'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: mesaj));
              Navigator.pop(_);
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                  content: Text('Kopyalandı!'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating));
            },
          ),
          // WhatsApp
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(_);
              final temizTel = tel.replaceAll(RegExp(r'[^0-9]'), '');
              final waUrl = Uri.parse(
                  'https://wa.me/90$temizTel?text=${Uri.encodeComponent(mesaj)}');
              if (await canLaunchUrl(waUrl)) {
                launchUrl(waUrl, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.message_rounded, size: 16),
            label: const Text('WhatsApp',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(_),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // ŞOFÖR DETAY DİALOG
  // ════════════════════════════════════════════════════════════════
  void _soforDetayDialog(BuildContext context, String docId,
      Map<String, dynamic> data) {
    final ad      = data['adSoyad'] ?? data['ad'] ?? '';
    final tel     = data['telefon'] ?? '';
    final plaka   = data['plaka'] ?? data['aracPlaka'] ?? '';
    final model   = data['aracModeli'] ?? '';
    final kapasite= data['aracKapasitesi'] ?? '';
    final kulAdi    = data['kullaniciAdi'] ?? '';
    final tcKimlik  = data['tcKimlik'] ?? '';
    final ehliyet   = data['ehliyetSinifi'] ?? '';
    final src       = data['srcBelgesi'] ?? '';
    final psiko     = data['psikoTarih'] ?? '';
    final durum     = SoforDurumExt.fromString(data['soforDurum']);
    final projeler  = (data['projeler'] as List?)?.cast<String>() ?? [];
    final sonGirisTs = data['sonGiris'];

    String sonGirisStr = 'Henüz giriş yapılmadı';
    if (sonGirisTs is Timestamp) {
      sonGirisStr = DateFormat('dd.MM.yyyy HH:mm').format(sonGirisTs.toDate());
    }

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 480,
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20), color: Colors.white),
          child: Column(children: [
            // Başlık
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                  color: _navy,
                  borderRadius:
                  BorderRadius.vertical(top: Radius.circular(20))),
              child: Row(children: [
                CircleAvatar(
                  radius: 24, backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(
                      ad.isNotEmpty ? ad[0].toUpperCase() : 'Ş',
                      style: const TextStyle(color: Colors.white,
                          fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ad, style: const TextStyle(color: Colors.white,
                      fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                        color: durum.renk.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(durum.ikon, color: durum.renk, size: 12),
                      const SizedBox(width: 4),
                      Text(durum.label,
                          style: TextStyle(color: durum.renk,
                              fontSize: 11, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ])),
                IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(_)),
              ]),
            ),

            // İçerik
            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                _detaySatir(Icons.phone_outlined, 'Telefon', tel),
                _detaySatir(Icons.directions_bus_rounded, 'Plaka', plaka),
                _detaySatir(Icons.directions_car_rounded, 'Araç Modeli',
                    model.isNotEmpty ? model : '-'),
                _detaySatir(Icons.people_rounded, 'Kapasite',
                    kapasite.isNotEmpty ? '$kapasite kişi' : '-'),
                _detaySatir(Icons.account_circle_outlined, 'Kullanıcı Adı',
                    kulAdi.isNotEmpty ? '@$kulAdi' : '-'),
                _detaySatir(Icons.access_time_rounded, 'Son Giriş',
                    sonGirisStr),

                // Belgeler bölümü
                if (tcKimlik.isNotEmpty || ehliyet.isNotEmpty ||
                    src.isNotEmpty || psiko.isNotEmpty) ...[
                  const Divider(height: 24),
                  Align(alignment: Alignment.centerLeft,
                      child: Text('Belgeler', style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13,
                          color: Colors.grey[600]))),
                  const SizedBox(height: 8),
                  if (tcKimlik.isNotEmpty)
                    _detaySatir(Icons.credit_card_outlined, 'TC Kimlik', tcKimlik),
                  if (ehliyet.isNotEmpty)
                    _detaySatir(Icons.drive_eta_outlined, 'Ehliyet Sınıfı', ehliyet),
                  if (src.isNotEmpty)
                    _detaySatir(Icons.article_outlined, 'SRC Belgesi', src),
                  if (psiko.isNotEmpty)
                    _detaySatir(Icons.calendar_today_outlined, 'Psikoteknik', psiko),
                ],

                const Divider(height: 24),

                // Atandığı projeler
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(children: [
                          Icon(Icons.folder_rounded,
                              color: Colors.blue, size: 16),
                          SizedBox(width: 6),
                          Text('Atandığı Projeler',
                              style: TextStyle(fontWeight: FontWeight.bold,
                                  color: Colors.blue)),
                        ]),
                        const SizedBox(height: 8),
                        if (projeler.isEmpty)
                          const Text('Henüz proje atanmadı',
                              style: TextStyle(color: Colors.grey, fontSize: 13))
                        else
                          ...projeler.map((p) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(children: [
                              const Icon(Icons.check_circle_rounded,
                                  color: Colors.blue, size: 14),
                              const SizedBox(width: 6),
                              Text(p, style: const TextStyle(fontSize: 13)),
                            ]),
                          )),
                      ]),
                ),

                const SizedBox(height: 12),

                // Öğrenci sayısı
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('students')
                      .where('surucuId', isEqualTo: docId)
                      .snapshots(),
                  builder: (_, snap) {
                    final sayi = snap.data?.docs.length ?? 0;
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade100)),
                      child: Row(children: [
                        const Icon(Icons.school_rounded,
                            color: Colors.green, size: 20),
                        const SizedBox(width: 10),
                        Column(crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Atanan Öğrenci',
                                  style: TextStyle(color: Colors.green,
                                      fontWeight: FontWeight.bold)),
                              Text('$sayi öğrenci',
                                  style: const TextStyle(
                                      fontSize: 20, fontWeight: FontWeight.bold)),
                            ]),
                      ]),
                    );
                  },
                ),
              ]),
            )),

            // Kapat butonu
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  onPressed: () => Navigator.pop(_),
                  child: const Text('Kapat',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _detaySatir(IconData icon, String label, String deger) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
            color: _navy.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: _navy, size: 18),
      ),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(
            fontSize: 11, color: Colors.grey)),
        Text(deger, style: const TextStyle(
            fontWeight: FontWeight.w600, fontSize: 14)),
      ]),
    ]),
  );

  // ════════════════════════════════════════════════════════════════
  // ŞOFÖR DÜZENLE DİALOG
  // ════════════════════════════════════════════════════════════════
  void _soforDuzenleDialog(BuildContext context, String docId,
      Map<String, dynamic> data) {
    final adCtrl       = TextEditingController(
        text: data['adSoyad'] ?? data['ad'] ?? '');
    final telCtrl      = TextEditingController(text: data['telefon'] ?? '');
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
          title: Text('${data['adSoyad'] ?? ''} — Düzenle'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _inp2(adCtrl, 'Şoför Adı *', Icons.person_outlined),
                const SizedBox(height: 10),
                _inp2(telCtrl, 'Telefon', Icons.phone_outlined,
                    tip: TextInputType.phone),
                const SizedBox(height: 10),
                _satirIkiIki(
                  _inp2(plakaCtrl, 'Plaka',
                      Icons.directions_bus_outlined),
                  _inp2(kapasiteCtrl, 'Kapasite',
                      Icons.people_outlined,
                      tip: TextInputType.number),
                ),
                const SizedBox(height: 10),
                _inp2(modelCtrl, 'Araç Modeli',
                    Icons.directions_car_outlined),
                const SizedBox(height: 10),
                Row(children: [
                  const Text('Aktif',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Switch(
                    value: aktif, activeColor: Colors.green,
                    onChanged: (v) => setSt(() => aktif = v),
                  ),
                ]),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('İptal')),
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
                    'soforDurum'    : aktif ? 'bosta' : 'pasif',
                    'updatedAt'     : FieldValue.serverTimestamp(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Kaydet')),
          ],
        ),
      ),
    );
  }

  // ── Yardımcı ──────────────────────────────────────────────────
  String _rastgeleKod() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final buf = StringBuffer();
    for (var i = 0; i < 6; i++) {
      buf.write(chars[DateTime.now().microsecond % chars.length + i % 8 < chars.length
          ? DateTime.now().microsecond % chars.length + i % 8
          : i % chars.length]);
    }
    return buf.toString();
  }

  void _snack(BuildContext ctx, String m) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(m),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating));
  }

  Widget _bolumBaslik(String text, IconData icon) => Row(children: [
    Icon(icon, color: _navy, size: 18),
    const SizedBox(width: 8),
    Text(text, style: const TextStyle(
        fontWeight: FontWeight.bold, fontSize: 14, color: _navy)),
  ]);

  Widget _satirIkiIki(Widget a, Widget b) =>
      Row(children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]);

  InputDecoration _inputDec(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: _navy, size: 18),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: sec ? _navy : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: sec ? _navy : Colors.grey.shade300)),
        child: Text(label, style: TextStyle(
            color: sec ? Colors.white : Colors.grey,
            fontSize: 12,
            fontWeight: sec ? FontWeight.bold : FontWeight.normal)),
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
  final String firmaId;
  final VoidCallback onDuzenle;
  final VoidCallback onDetay;

  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  const _SoforKarti({
    required this.docId, required this.data, required this.projeler,
    required this.firmaId, required this.onDuzenle, required this.onDetay,
  });

  @override
  Widget build(BuildContext context) {
    final ad       = data['adSoyad'] ?? data['ad'] ?? '';
    final tel      = data['telefon'] ?? '';
    final plaka    = data['plaka']   ?? data['aracPlaka'] ?? '';
    final kapasite = data['aracKapasitesi'] ?? '';
    final model    = data['aracModeli'] ?? '';
    final kulAdi   = data['kullaniciAdi'] ?? '';
    final geciciSifre = data['geciciSifre'] ?? '';
    final durum    = SoforDurumExt.fromString(data['soforDurum']);
    final aktif    = data['aktif'] as bool? ?? true;
    final sonGirisTs = data['sonGiris'];

    String sonGirisStr = 'Giriş yok';
    if (sonGirisTs is Timestamp) {
      sonGirisStr = DateFormat('dd.MM HH:mm').format(sonGirisTs.toDate());
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onDetay,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            // Üst satır
            Row(children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: durum.renk.withValues(alpha: 0.12),
                child: Text(
                    ad.isNotEmpty ? ad[0].toUpperCase() : 'Ş',
                    style: TextStyle(color: durum.renk,
                        fontWeight: FontWeight.bold, fontSize: 20)),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(ad, style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15, color: _navy))),
                  // Durum çipi
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: durum.renk.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: durum.renk.withValues(alpha: 0.3))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(durum.ikon, color: durum.renk, size: 10),
                      const SizedBox(width: 4),
                      Text(durum.label,
                          style: TextStyle(color: durum.renk,
                              fontSize: 10, fontWeight: FontWeight.bold)),
                    ]),
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

            // Araç bilgileri
            Row(children: [
              _bilgiCip(Icons.directions_bus_rounded,
                  plaka.isNotEmpty ? plaka : 'Plaka yok', Colors.blue),
              const SizedBox(width: 8),
              if (kapasite.isNotEmpty)
                _bilgiCip(Icons.people_rounded,
                    '$kapasite kişi', Colors.purple),
              if (kapasite.isNotEmpty) const SizedBox(width: 8),
              if (model.isNotEmpty)
                Expanded(child: _bilgiCip(
                    Icons.directions_car_rounded, model, Colors.teal)),
            ]),

            const SizedBox(height: 8),

            // Son giriş
            Row(children: [
              const Icon(Icons.access_time_rounded,
                  size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Text('Son giriş: $sonGirisStr',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const Spacer(),
              // Hızlı menü butonu
              _hizliMenuBtn(context, ad, tel, kulAdi, geciciSifre, aktif),
            ]),

            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Alt butonlar
            Row(children: [
              // Ara
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
                    final url = Uri.parse('https://wa.me/90$temiz');
                    if (await canLaunchUrl(url)) {
                      launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  } : null),
              const Spacer(),
              // Aktif toggle
              Switch(
                value: aktif, activeColor: Colors.green,
                onChanged: (v) async {
                  await FirebaseFirestore.instance
                      .collection('drivers').doc(docId).update({
                    'aktif'     : v,
                    'aktifMi'   : v,
                    'soforDurum': v ? 'bosta' : 'pasif',
                    'updatedAt' : FieldValue.serverTimestamp(),
                  });
                },
              ),
              // Düzenle
              IconButton(
                  icon: const Icon(Icons.edit_rounded, color: _navy),
                  onPressed: onDuzenle, tooltip: 'Düzenle'),
              // Sil
              IconButton(
                  icon: const Icon(Icons.delete_rounded, color: Colors.red),
                  tooltip: 'Sil',
                  onPressed: () => _silOnay(context, ad)),
            ]),
          ]),
        ),
      ),
    );
  }

  // ── Hızlı İşlem Menüsü ────────────────────────────────────────
  Widget _hizliMenuBtn(BuildContext context, String ad, String tel,
      String kulAdi, String geciciSifre, bool aktif) {
    return PopupMenuButton<String>(
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: _navy.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.more_horiz_rounded, color: _navy, size: 16),
          SizedBox(width: 4),
          Text('İşlem', style: TextStyle(
              color: _navy, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (v) async {
        switch (v) {
          case 'duzenle':
            onDuzenle();
            break;
          case 'serviseAta':
            _serviseAtaDialog(context);
            break;
          case 'proje':
            _projeAtaDialog(context);
            break;
          case 'ogrenci':
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Öğrenci Ata ekranına gidin'),
                    behavior: SnackBarBehavior.floating));
            break;
          case 'sifre':
            _sifreYenileDialog(context);
            break;
          case 'pasif':
            await FirebaseFirestore.instance
                .collection('drivers').doc(docId).update({
              'aktif'     : false,
              'aktifMi'   : false,
              'soforDurum': 'pasif',
              'updatedAt' : FieldValue.serverTimestamp(),
            });
            break;
          case 'girisGonder':
            _girisGonderKopyala(context, ad, tel, kulAdi, geciciSifre);
            break;
          case 'sil':
            _silOnay(context, ad);
            break;
        }
      },
      itemBuilder: (_) => [
        _menuItem('duzenle',    Icons.edit_rounded,         'Düzenle',        Colors.blue),
        _menuItem('proje',      Icons.folder_special_rounded,'Projeye Dahil Et', Colors.indigo),
        _menuItem('ogrenci',    Icons.school_rounded,       'Öğrenci Ata',    Colors.green),
        _menuItem('girisGonder',Icons.send_rounded,         'Giriş Bilgisi Gönder', _navy),
        _menuItem('sifre',      Icons.key_rounded,          'Şifre Yenile',   Colors.orange),
        if (aktif)
          _menuItem('pasif',    Icons.block_rounded,        'Pasif Yap',      Colors.grey),
        const PopupMenuDivider(),
        _menuItem('sil',        Icons.delete_rounded,       'Sil',            Colors.red),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(
      String value, IconData icon, String label, Color renk) =>
      PopupMenuItem(
        value: value,
        child: Row(children: [
          Icon(icon, color: renk, size: 18),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: renk, fontWeight: FontWeight.w500)),
        ]),
      );

  // ── Servise Ata Dialog ───────────────────────────────────────
  void _serviseAtaDialog(BuildContext context) {
    String? seciliProjeId;
    String? seciliServisId;
    String? seciliAracId;
    String  seciliProjeAd  = '';
    String  seciliServisAd = '';
    List<Map<String,dynamic>> servisler = [];
    List<Map<String,dynamic>> araclar   = [];

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 500,
            constraints: const BoxConstraints(maxHeight: 600),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                    color: _navy,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                child: Row(children: [
                  const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Servise Ata',
                      style: TextStyle(color: Colors.white,
                          fontSize: 17, fontWeight: FontWeight.bold))),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx)),
                ]),
              ),
              Expanded(child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Akış göstergesi
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.shade200)),
                    child: const Row(children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 14),
                      SizedBox(width: 8),
                      Expanded(child: Text('Proje → Servis → Araç seçerek şoförü bağlayın',
                          style: TextStyle(fontSize: 11, color: Colors.blue))),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // 1. Proje seç
                  const Text('1. Proje Seç', style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13, color: _navy)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                        labelText: 'Proje', prefixIcon: Icon(Icons.folder_outlined),
                        border: OutlineInputBorder(), isDense: true),
                    hint: const Text('Proje seçin'),
                    value: seciliProjeId,
                    items: projeler.map((p) => DropdownMenuItem(
                      value: p['id'] as String,
                      child: Text(p['projeAd'] ?? ''),
                    )).toList(),
                    onChanged: (v) async {
                      setSt(() {
                        seciliProjeId  = v;
                        seciliServisId = null;
                        seciliAracId   = null;
                        seciliProjeAd  = projeler.firstWhere(
                                (p) => p['id'] == v, orElse: () => {})['projeAd'] ?? '';
                        servisler      = [];
                        araclar        = [];
                      });
                      if (v == null) return;
                      // Servis ve araçları yükle
                      try {
                        final sSnap = await FirebaseFirestore.instance
                            .collection('services')
                            .where('projeId', isEqualTo: v)
                            .get();
                        final aSnap = await FirebaseFirestore.instance
                            .collection('vehicles')
                            .where('firmaId', isEqualTo: firmaId)
                            .where('durum', isEqualTo: 'musait')
                            .get();
                        setSt(() {
                          servisler = sSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
                          araclar   = aSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
                        });
                      } catch (_) {}
                    },
                  ),
                  const SizedBox(height: 14),

                  // 2. Servis seç
                  if (seciliProjeId != null) ...[
                    const Text('2. Servis Seç', style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13, color: _navy)),
                    const SizedBox(height: 8),
                    if (servisler.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8)),
                        child: const Text('Bu projede henüz servis yok.',
                            style: TextStyle(color: Colors.orange, fontSize: 12)),
                      )
                    else
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                            labelText: 'Servis', prefixIcon: Icon(Icons.route_outlined),
                            border: OutlineInputBorder(), isDense: true),
                        hint: const Text('Servis seçin'),
                        value: seciliServisId,
                        items: servisler.map((s) => DropdownMenuItem(
                          value: s['id'] as String,
                          child: Text(s['servisAdi'] ?? s['ad'] ?? ''),
                        )).toList(),
                        onChanged: (v) => setSt(() {
                          seciliServisId = v;
                          seciliServisAd = servisler.firstWhere(
                                  (s) => s['id'] == v, orElse: () => {})['servisAdi'] ?? '';
                        }),
                      ),
                    const SizedBox(height: 14),
                  ],

                  // 3. Araç seç
                  if (seciliServisId != null) ...[
                    const Text('3. Araç Seç', style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13, color: _navy)),
                    const SizedBox(height: 8),
                    if (araclar.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8)),
                        child: const Text('Müsait araç bulunamadı.',
                            style: TextStyle(color: Colors.orange, fontSize: 12)),
                      )
                    else
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                            labelText: 'Araç', prefixIcon: Icon(Icons.directions_bus_outlined),
                            border: OutlineInputBorder(), isDense: true),
                        hint: const Text('Araç seçin'),
                        value: seciliAracId,
                        items: araclar.map((a) => DropdownMenuItem(
                          value: a['id'] as String,
                          child: Text('${a['plaka'] ?? ''} — ${a['model'] ?? a['aracModeli'] ?? ''}'),
                        )).toList(),
                        onChanged: (v) => setSt(() => seciliAracId = v),
                      ),
                  ],
                ]),
              )),

              // Butonlar
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    child: const Text('İptal'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    onPressed: (seciliProjeId == null || seciliServisId == null)
                        ? null
                        : () async {
                      final now = FieldValue.serverTimestamp();
                      await FirebaseFirestore.instance
                          .collection('drivers').doc(docId).update({
                        'projeId'    : seciliProjeId,
                        'projeAd'    : seciliProjeAd,
                        'servisId'   : seciliServisId,
                        'servisAd'   : seciliServisAd,
                        'vehicleId'  : seciliAracId,
                        'soforDurum' : 'projeyeDahil',
                        'projeler'   : FieldValue.arrayUnion([seciliProjeAd]),
                        'updatedAt'  : now,
                      });
                      // Araç güncelle
                      if (seciliAracId != null) {
                        await FirebaseFirestore.instance
                            .collection('vehicles').doc(seciliAracId).update({
                          'surucuId' : docId,
                          'durum'    : 'gorevde',
                          'updatedAt': now,
                        });
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('$seciliServisAd servisine atandı'),
                            backgroundColor: Colors.teal,
                            behavior: SnackBarBehavior.floating));
                      }
                    },
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Servise Ata',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  )),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Proje Ata Dialog ─────────────────────────────────────────
  void _projeAtaDialog(BuildContext context) {
    String? seciliProjeId;
    String  seciliProjeAd = '';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('Projeye Dahil Et'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Bu şoförü hangi projeye dahil etmek istersiniz?',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Proje Seç',
                prefixIcon: Icon(Icons.folder_outlined),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              hint: const Text('Proje seçin'),
              value: seciliProjeId,
              items: projeler.map((p) => DropdownMenuItem(
                value: p['id'] as String,
                child: Text(p['projeAd'] ?? ''),
              )).toList(),
              onChanged: (v) => setSt(() {
                seciliProjeId = v;
                seciliProjeAd = projeler.firstWhere(
                        (p) => p['id'] == v, orElse: () => {})['projeAd'] ?? '';
              }),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('İptal')),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _navy, foregroundColor: Colors.white),
                onPressed: seciliProjeId == null ? null : () async {
                  await FirebaseFirestore.instance
                      .collection('drivers').doc(docId).update({
                    'projeId'    : seciliProjeId,
                    'projeAd'    : seciliProjeAd,
                    'soforDurum' : 'projeyeDahil',
                    'projeler'   : FieldValue.arrayUnion([seciliProjeAd]),
                    'updatedAt'  : FieldValue.serverTimestamp(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('$seciliProjeAd projesine dahil edildi'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating));
                  }
                },
                child: const Text('Dahil Et')),
          ],
        ),
      ),
    );
  }

  // ── Şifre Yenile Dialog ───────────────────────────────────────
  void _sifreYenileDialog(BuildContext context) {
    final yeniSifreCtrl = TextEditingController(text: _rastgeleKodStatic());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Şifre Yenile'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Yeni geçici şifre belirleyin.',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 16),
          TextField(
            controller: yeniSifreCtrl,
            decoration: InputDecoration(
              labelText: 'Yeni Şifre',
              prefixIcon: const Icon(Icons.key_outlined),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              suffixIcon: IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () =>
                  yeniSifreCtrl.text = _rastgeleKodStatic()),
            ),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(_),
              child: const Text('İptal')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _navy, foregroundColor: Colors.white),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('drivers').doc(docId).update({
                  'geciciSifre': yeniSifreCtrl.text.trim(),
                  'updatedAt'  : FieldValue.serverTimestamp(),
                });
                await FirebaseFirestore.instance
                    .collection('kullanicilar').doc(docId).update({
                  'sifre': yeniSifreCtrl.text.trim(),
                });
                if (_.mounted) Navigator.pop(_);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Şifre güncellendi: ${yeniSifreCtrl.text}'),
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating));
                }
              },
              child: const Text('Güncelle')),
        ],
      ),
    );
  }

  // ── Giriş Bilgisi Kopyala/Gönder ─────────────────────────────
  void _girisGonderKopyala(BuildContext context, String ad, String tel,
      String kulAdi, String sifre) {
    final mesaj =
        'Servisim360 Giriş Bilgileri\n'
        '👤 Kullanıcı Adı: $kulAdi\n'
        '🔑 Geçici Şifre: $sifre\n'
        'Uygulamayı indirip giriş yapabilirsiniz.';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('$ad — Giriş Bilgileri'),
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
                    content: Text('Kopyalandı!'),
                    backgroundColor: Colors.green,
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
                    'https://wa.me/90$temiz?text=${Uri.encodeComponent(mesaj)}');
                if (await canLaunchUrl(url)) {
                  launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('WhatsApp')),
        ],
      ),
    );
  }

  // ── Sil Onay ─────────────────────────────────────────────────
  void _silOnay(BuildContext context, String ad) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Şoförü Sil'),
        content: Text('$ad silinsin mi? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(_, false),
              child: const Text('İptal')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(_, true),
              child: const Text('Sil',
                  style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (onay == true) {
      await FirebaseFirestore.instance
          .collection('drivers').doc(docId).delete();
      await FirebaseFirestore.instance
          .collection('kullanicilar').doc(docId).delete();
    }
  }

  // ── Yardımcılar ───────────────────────────────────────────────
  static String _rastgeleKodStatic() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final now = DateTime.now();
    final buf = StringBuffer();
    for (var i = 0; i < 6; i++) {
      buf.write(chars[(now.microsecond + i * 7) % chars.length]);
    }
    return buf.toString();
  }

  Widget _bilgiCip(IconData icon, String label, Color renk) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: renk.withValues(alpha: 0.2))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: renk),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(
          fontSize: 11, color: renk, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _akBtn(IconData icon, String label, Color renk,
      VoidCallback? onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: onTap != null
                  ? renk.withValues(alpha: 0.1) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: onTap != null
                      ? renk.withValues(alpha: 0.3) : Colors.grey.shade300)),
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
}
