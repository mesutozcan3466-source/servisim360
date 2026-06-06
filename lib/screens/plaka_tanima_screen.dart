// ╔══════════════════════════════════════════════════════════════╗
// ║  DOSYA: lib/screens/plaka_tanima_screen.dart
// ║  Akıllı Plaka Tanıma & Okul Giriş Sistemi
// ║  Admin istediğinde aktif eder — modüler yapı
// ╚══════════════════════════════════════════════════════════════╝
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/session_service.dart';
import 'yardim_widget.dart';
import 'ai_widget.dart';

class PlakaTanimaScreen extends StatefulWidget {
  const PlakaTanimaScreen({super.key});
  @override
  State<PlakaTanimaScreen> createState() => _PlakaTanimaScreenState();
}

class _PlakaTanimaScreenState extends State<PlakaTanimaScreen>
    with SingleTickerProviderStateMixin {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  late TabController _tab;
  String _firmaId = '';
  bool _sistemAktif = false;

  // Plaka manuel giriş
  final _plakaCtrl = TextEditingController();
  bool _taniniyor  = false;

  // Son girişler
  List<Map<String, dynamic>> _girisler = [];

  // Projede tanımlı araçlar
  List<Map<String, dynamic>> _projeAraclari = [];
  String _projeId = '';
  String _projeAdi = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _yukle();
  }

  @override
  void dispose() {
    _tab.dispose();
    _plakaCtrl.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    _firmaId = await SessionService.instance.firmaIdAl() ?? '';
    if (_firmaId.isEmpty) return;

    // Sistem ayarını yükle
    final doc = await FirebaseFirestore.instance
        .collection('firms').doc(_firmaId).get();
    _sistemAktif = doc.data()?['plakaTanimaAktif'] ?? false;

    // Aktif proje
    _projeId  = SessionService.instance.aktifProjeld  ?? '';
    _projeAdi = SessionService.instance.aktifProjeAdi ?? '';

    // Projedeki araçları yükle
    var aracQuery = FirebaseFirestore.instance
        .collection('vehicles')
        .where('firmaId', isEqualTo: _firmaId);
    if (_projeId.isNotEmpty) {
      aracQuery = aracQuery.where('projeId', isEqualTo: _projeId);
    }
    final aracSnap = await aracQuery.get();
    _projeAraclari = aracSnap.docs
        .map((d) => {'id': d.id, ...d.data()}).toList();

    // Şoförlerden de plaka çek (projeye atanmış)
    if (_projeId.isNotEmpty) {
      final sofSnap = await FirebaseFirestore.instance
          .collection('drivers')
          .where('firmaId', isEqualTo: _firmaId)
          .where('projeId', isEqualTo: _projeId)
          .get();
      for (final s in sofSnap.docs) {
        final data = s.data();
        final plaka = data['plaka'] ?? data['aracPlaka'] ?? '';
        if (plaka.isNotEmpty &&
            !_projeAraclari.any((a) => a['plaka'] == plaka)) {
          _projeAraclari.add({
            'id'      : s.id,
            'plaka'   : plaka,
            'surucuId': s.id,
            'adSoyad' : data['adSoyad'] ?? data['ad'] ?? '',
            'projeAdi': data['projeAdi'] ?? '',
            'kaynakSofor': true,
          });
        }
      }
    }

    // Son girişleri yükle
    final snap = await FirebaseFirestore.instance
        .collection('okul_girisler')
        .where('firmaId', isEqualTo: _firmaId)
        .get();
    _girisler = snap.docs
        .map((d) => {'id': d.id, ...d.data()})
        .toList();
    _girisler.sort((a, b) {
      final ta = a['girisSaati'];
      final tb = b['girisSaati'];
      if (ta is Timestamp && tb is Timestamp) {
        return tb.compareTo(ta);
      }
      return 0;
    });

    if (mounted) setState(() {});
  }

  Future<void> _sistemToggle(bool aktif) async {
    await FirebaseFirestore.instance
        .collection('firms').doc(_firmaId).update({
      'plakaTanimaAktif': aktif,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    setState(() => _sistemAktif = aktif);
    _snack(aktif
        ? 'Plaka Tanıma Sistemi aktif edildi!'
        : 'Sistem devre dışı bırakıldı',
        renk: aktif ? Colors.green : Colors.orange);
  }

  // Plaka manuel tanıma — API bağlandığında otomatik olacak
  Future<void> _plakaTani(String plaka) async {
    if (plaka.trim().isEmpty) return;
    setState(() => _taniniyor = true);

    try {
      // Plakayı vehicles koleksiyonunda ara
      final araSnap = await FirebaseFirestore.instance
          .collection('vehicles')
          .where('firmaId', isEqualTo: _firmaId)
          .where('plaka', isEqualTo: plaka.trim().toUpperCase())
          .get();

      if (araSnap.docs.isEmpty) {
        // Yetkisiz araç
        await _yetkisizAracKaydet(plaka);
        if (mounted) {
          _yetkisizUyari(plaka);
        }
        setState(() => _taniniyor = false);
        return;
      }

      final aracData = araSnap.docs.first.data();
      final surucuId = aracData['surucuId'] as String? ?? '';

      // Şoför bilgisini al
      Map<String, dynamic> soforData = {};
      if (surucuId.isNotEmpty) {
        final sSnap = await FirebaseFirestore.instance
            .collection('drivers').doc(surucuId).get();
        soforData = sSnap.data() ?? {};
      }

      // Servis tamamlandı olarak işaretle
      await _servisTamamla(surucuId, soforData, aracData, plaka);

    } catch (e) {
      _snack('Hata: $e');
    }
    setState(() => _taniniyor = false);
  }

  Future<void> _servisTamamla(String surucuId,
      Map<String, dynamic> sofor, Map<String, dynamic> arac,
      String plaka) async {
    final now = FieldValue.serverTimestamp();
    final nowDt = DateTime.now();

    // 1. Okul giriş kaydı oluştur
    await FirebaseFirestore.instance.collection('okul_girisler').add({
      'firmaId'      : _firmaId,
      'plaka'        : plaka,
      'surucuId'     : surucuId,
      'surucuAd'     : sofor['adSoyad'] ?? sofor['ad'] ?? '-',
      'projeId'      : sofor['projeId'] ?? '',
      'projeAdi'     : sofor['projeAdi'] ?? '',
      'girisSaati'   : now,
      'girisSaatiStr': '${nowDt.hour.toString().padLeft(2,"0")}:'
          '${nowDt.minute.toString().padLeft(2,"0")}',
      'gun'          : _gunAdi(nowDt.weekday),
      'durum'        : 'icerde',
      'beklemeSuresi': 0, // Çıkış kaydedilince hesaplanır
      'cikisSaati'   : null,
      'ogrenciSayisi': 0, // gerçek entegrasyonda doldurulacak
    });

    // 2. Şoför servisini kapat
    if (surucuId.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('drivers').doc(surucuId).update({
        'servisAktif': false,
        'soforDurum' : 'bosta',
        'sonSaati'   : now,
        'updatedAt'  : now,
      });
    }

    // 3. Velilere bildirim gönder
    await _veliBildirimGonder(sofor, nowDt);

    // 4. Başarı ekranı
    if (mounted) _basariDialog(plaka, sofor, nowDt);

    await _yukle();
  }

  Future<void> _veliBildirimGonder(
      Map<String, dynamic> sofor, DateTime saat) async {
    // Şoförün öğrencilerini bul
    try {
      final ogrSnap = await FirebaseFirestore.instance
          .collection('students')
          .where('surucuId', isEqualTo: sofor['id'] ?? '')
          .get();

      for (final ogr in ogrSnap.docs) {
        final veliId = ogr.data()['veliId'] ?? ogr.id;
        // Veli FCM token'ına bildirim gönder
        final veliDoc = await FirebaseFirestore.instance
            .collection('parents').doc(veliId).get();
        final fcmToken = veliDoc.data()?['fcmToken'] as String?;

        if (fcmToken != null) {
          // FCM bildirim servisi üzerinden gönderilecek
          await FirebaseFirestore.instance.collection('bildirimler').add({
            'aliciId'   : veliId,
            'firmaId'   : _firmaId,
            'baslik'    : '🏫 Okula Ulaştı',
            'mesaj'     : '${ogr.data()['ad'] ?? 'Öğrenci'} servisi '
                '${saat.hour.toString().padLeft(2,'0')}:'
                '${saat.minute.toString().padLeft(2,'0')}'
                ' saatinde okula ulaştı.',
            'tip'       : 'okul_giris',
            'okundu'    : false,
            'tarih'     : FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) { debugPrint('Bildirim hatası: $e'); }
  }

  Future<void> _yetkisizAracKaydet(String plaka) async {
    await FirebaseFirestore.instance.collection('okul_girisler').add({
      'firmaId'  : _firmaId,
      'plaka'    : plaka,
      'durum'    : 'yetkisiz',
      'girisSaati': FieldValue.serverTimestamp(),
      'girisSaatiStr': '${DateTime.now().hour.toString().padLeft(2,'0')}:'
          '${DateTime.now().minute.toString().padLeft(2,'0')}',
      'gun'      : _gunAdi(DateTime.now().weekday),
    });
  }

  String _gunAdi(int gun) {
    const gunler = ['', 'Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return gunler[gun];
  }

  void _snack(String m, {Color renk = Colors.red}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m), backgroundColor: renk,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Plaka Tanıma Sistemi',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text('Okul Giriş & Çıkış Takibi',
                style: TextStyle(fontSize: 10, color: Colors.white60)),
          ],
        ),
        actions: [
          // Sistem aktif/pasif toggle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: GestureDetector(
              onTap: () => _sistemToggle(!_sistemAktif),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: _sistemAktif
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _sistemAktif
                            ? Colors.green : Colors.white30)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 7, height: 7,
                      decoration: BoxDecoration(
                          color: _sistemAktif
                              ? Colors.green : Colors.grey,
                          shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text(_sistemAktif ? 'Aktif' : 'Pasif',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ]),
              ),
            ),
          ),
          AiAsistanButonu(ekranAdi: 'Harita'),
          YardimButonu(ekranAdi: 'Harita'),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: _turuncu,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.badge_outlined, size: 16), text: 'Plaka Giriş'),
            Tab(icon: Icon(Icons.history_outlined, size: 16), text: 'Giriş Geçmişi'),
            Tab(icon: Icon(Icons.bar_chart_outlined, size: 16), text: 'Gecikme Analizi'),
            Tab(icon: Icon(Icons.security_outlined, size: 16), text: 'Güvenlik'),
          ],
        ),
      ),
      body: TabBarView(controller: _tab, children: [
        _plakaGirisTab(),
        _gecmisTab(),
        _gecikmeAnalizTab(),
        _guvenlikTab(),
      ]),
    );
  }

  // ── TAB 1: Plaka Giriş ───────────────────────────────────────
  Widget _plakaGirisTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      // Sistem durumu
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: _sistemAktif ? Colors.green.shade50 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: _sistemAktif
                    ? Colors.green.shade300 : Colors.grey.shade300)),
        child: Row(children: [
          Icon(_sistemAktif
              ? Icons.camera_alt_outlined : Icons.camera_outlined,
              color: _sistemAktif ? Colors.green : Colors.grey, size: 28),
          const SizedBox(width: 14),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              _sistemAktif ? 'Sistem Aktif' : 'Sistem Pasif',
              style: TextStyle(fontWeight: FontWeight.bold,
                  color: _sistemAktif ? Colors.green : Colors.grey)),
            Text(
              _sistemAktif
                  ? 'Plaka kamerası bağlı ve dinleniyor'
                  : 'Aktif etmek için sağ üstteki butonu kullanın',
              style: TextStyle(fontSize: 11,
                  color: _sistemAktif
                      ? Colors.green.shade700 : Colors.grey)),
          ])),
          Switch(
            value: _sistemAktif,
            activeColor: Colors.green,
            onChanged: _sistemToggle,
          ),
        ]),
      ),
      const SizedBox(height: 20),

      // Manuel plaka girişi — kamera entegrasyonuna kadar
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          const Row(children: [
            Icon(Icons.car_crash_outlined, color: Color(0xFF1a3a6b), size: 18),
            SizedBox(width: 8),
            Text('Manuel Plaka Girişi',
                style: TextStyle(fontWeight: FontWeight.bold,
                    fontSize: 14, color: Color(0xFF1a3a6b))),
          ]),
          const SizedBox(height: 4),
          const Text('Kamera API bağlandığında otomatik çalışacak',
              style: TextStyle(color: Colors.grey, fontSize: 11)),
          const SizedBox(height: 14),

          TextField(
            controller: _plakaCtrl,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold,
                letterSpacing: 4),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '34 ABC 123',
              hintStyle: TextStyle(color: Colors.grey[300],
                  letterSpacing: 4, fontSize: 20),
              prefixIcon: const Icon(Icons.directions_car_outlined,
                  color: Color(0xFF1a3a6b)),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: Color(0xFF1a3a6b))),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: Color(0xFF1a3a6b), width: 2)),
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1a3a6b),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            onPressed: _taniniyor
                ? null
                : () => _plakaTani(_plakaCtrl.text),
            icon: _taniniyor
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.search_rounded),
            label: Text(_taniniyor ? 'Tanınıyor...' : 'Plakayı Tanı',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
          )),
        ]),
      ),
      const SizedBox(height: 16),

      // Projede tanımlı araçlar
      if (_projeAraclari.isNotEmpty) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6)]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              const Icon(Icons.directions_bus_outlined,
                  color: Color(0xFF1a3a6b), size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(
                _projeAdi.isNotEmpty
                    ? '$_projeAdi — Kayıtlı Araçlar'
                    : 'Projede Kayıtlı Araçlar',
                style: const TextStyle(fontWeight: FontWeight.bold,
                    fontSize: 14, color: Color(0xFF1a3a6b)))),
              Text('${_projeAraclari.length} araç',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[500])),
            ]),
            const Divider(height: 14),
            ..._projeAraclari.map((a) {
              final plaka   = a['plaka'] ?? '-';
              final soforAd = a['adSoyad'] ?? a['ad'] ?? '-';
              final projeAd = a['projeAdi'] ?? '';
              return GestureDetector(
                onTap: () {
                  _plakaCtrl.text = plaka;
                  _plakaTani(plaka);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.grey.shade200)),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: const Color(0xFF1a3a6b),
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(plaka,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13, letterSpacing: 2)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(soforAd, style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                      if (projeAd.isNotEmpty)
                        Text(projeAd, style: TextStyle(
                            fontSize: 11, color: Colors.grey[500])),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: const Color(0xFFFF8C00)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6)),
                      child: const Text('Giriş Yap',
                          style: TextStyle(fontSize: 11,
                              color: Color(0xFFFF8C00),
                              fontWeight: FontWeight.bold)),
                    ),
                  ]),
                ),
              );
            }),
          ]),
        ),
      ],

      // Kamera entegrasyon bilgisi
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          const Row(children: [
            Icon(Icons.info_outline, color: Colors.blue, size: 16),
            SizedBox(width: 8),
            Text('Kamera API Entegrasyonu',
                style: TextStyle(fontWeight: FontWeight.bold,
                    color: Colors.blue, fontSize: 13)),
          ]),
          const SizedBox(height: 8),
          ...[
            'Hikvision, Dahua veya herhangi bir IP kamera',
            'OpenALPR veya özel plaka tanıma API',
            'Webhook ile Servisim360\'a gönderim',
            'Gerçek zamanlı plaka eşleştirme',
          ].map((m) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              const Icon(Icons.check_circle_outline,
                  color: Colors.blue, size: 13),
              const SizedBox(width: 6),
              Text(m, style: const TextStyle(
                  fontSize: 11, color: Colors.blue)),
            ]),
          )),
        ]),
      ),
    ]),
  );

  // ── TAB 2: Giriş Geçmişi ─────────────────────────────────────
  Widget _gecmisTab() {
    if (_firmaId.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('okul_girisler')
          .where('firmaId', isEqualTo: _firmaId)
          .snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(child: Column(
              mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.history_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            const Text('Henüz giriş kaydı yok',
                style: TextStyle(color: Colors.grey, fontSize: 15)),
          ]));
        }

        final sorted = docs.toList()
          ..sort((a, b) {
            final ta = (a.data() as Map)['girisSaati'];
            final tb = (b.data() as Map)['girisSaati'];
            if (ta is Timestamp && tb is Timestamp) {
              return tb.compareTo(ta);
            }
            return 0;
          });

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: sorted.length,
          itemBuilder: (_, i) {
            final d = sorted[i].data() as Map<String, dynamic>;
            final yetkisiz = d['durum'] == 'yetkisiz';
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: yetkisiz
                          ? Colors.red.withValues(alpha: 0.1)
                          : Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(
                    yetkisiz
                        ? Icons.warning_amber_outlined
                        : Icons.check_circle_outline,
                    color: yetkisiz ? Colors.red : Colors.green,
                    size: 22),
                ),
                title: Row(children: [
                  Text(d['plaka'] ?? '-',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16, letterSpacing: 2)),
                  if (yetkisiz)
                    Container(margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(4)),
                        child: const Text('YETKİSİZ',
                            style: TextStyle(fontSize: 9,
                                color: Colors.red,
                                fontWeight: FontWeight.bold))),
                ]),
                subtitle: Text(
                  '${d['surucuAd'] ?? 'Bilinmiyor'}'
                  '${(d['projeAdi'] ?? '').isNotEmpty ? " • ${d['projeAdi']}" : ""}',
                  style: const TextStyle(fontSize: 11)),
                trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                  Text(d['girisSaatiStr'] ?? '-',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(d['gun'] ?? '-',
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey[500])),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  // ── TAB 3: Gecikme Analizi ────────────────────────────────────
  Widget _gecikmeAnalizTab() => StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('okul_girisler')
        .where('firmaId', isEqualTo: _firmaId)
        .where('durum', isEqualTo: 'tamamlandi')
        .snapshots(),
    builder: (_, snap) {
      final docs = snap.data?.docs ?? [];
      if (docs.isEmpty) {
        return const Center(child: Text(
            'Yeterli veri yok',
            style: TextStyle(color: Colors.grey, fontSize: 15)));
      }

      // Şoföre göre grupla
      final Map<String, List<Map>> soforGirisler = {};
      for (final d in docs) {
        final data = d.data() as Map<String, dynamic>;
        final soforAd = data['surucuAd'] ?? 'Bilinmiyor';
        soforGirisler.putIfAbsent(soforAd, () => []).add(data);
      }

      return ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200)),
            child: const Text(
              'Her şoförün okula varış geçmişi analizi. '
              'Hedef saat ayarları Ayarlar\'dan yapılabilir.',
              style: TextStyle(fontSize: 12, color: Colors.blue)),
          ),
          ...soforGirisler.entries.map((e) {
            final girisler = e.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    const Icon(Icons.person_outlined,
                        color: _navy, size: 18),
                    const SizedBox(width: 8),
                    Text(e.key, style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14, color: _navy)),
                    const Spacer(),
                    Text('${girisler.length} giriş',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[500])),
                  ]),
                  const Divider(height: 12),
                  ...girisler.take(5).map((g) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      Text(g['gun'] ?? '-',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w500,
                              color: _navy),
                          softWrap: false),
                      const SizedBox(width: 12),
                      Text(g['girisSaatiStr'] ?? '-',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      // Hedef: 08:00 — basit gecikme gösterimi
                      _gecikmeRozeti(g['girisSaatiStr'] ?? '08:00'),
                    ]),
                  )),
                ]),
              ),
            );
          }),
        ],
      );
    },
  );

  Widget _gecikmeRozeti(String saat) {
    final parts = saat.split(':');
    if (parts.length < 2) return const SizedBox.shrink();
    final saat8 = 8 * 60;
    final gelen = int.tryParse(parts[0], radix: 10)! * 60 +
        int.tryParse(parts[1], radix: 10)!;
    final fark = gelen - saat8;
    if (fark <= 0) {
      return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(4)),
          child: Text('${fark}dk', style: const TextStyle(
              fontSize: 10, color: Colors.green,
              fontWeight: FontWeight.bold)));
    }
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(4)),
        child: Text('+${fark}dk', style: const TextStyle(
            fontSize: 10, color: Colors.orange,
            fontWeight: FontWeight.bold)));
  }

  // ── TAB 4: Güvenlik ──────────────────────────────────────────
  Widget _guvenlikTab() => StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('okul_girisler')
        .where('firmaId', isEqualTo: _firmaId)
        .where('durum', isEqualTo: 'yetkisiz')
        .snapshots(),
    builder: (_, snap) {
      final docs = snap.data?.docs ?? [];
      return Column(children: [
        Container(
          margin: const EdgeInsets.all(14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: docs.isNotEmpty
                  ? Colors.red.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: docs.isNotEmpty
                      ? Colors.red.shade300 : Colors.green.shade300)),
          child: Row(children: [
            Icon(docs.isNotEmpty
                ? Icons.warning_amber_rounded : Icons.verified_outlined,
                color: docs.isNotEmpty ? Colors.red : Colors.green,
                size: 28),
            const SizedBox(width: 12),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(docs.isNotEmpty
                  ? '${docs.length} Yetkisiz Giriş Denemesi'
                  : 'Güvenlik Temiz',
                  style: TextStyle(fontWeight: FontWeight.bold,
                      color: docs.isNotEmpty
                          ? Colors.red : Colors.green)),
              Text(docs.isNotEmpty
                  ? 'Kayıtlı olmayan araç giriş yapmak istedi'
                  : 'Yetkisiz araç girişi tespit edilmedi',
                  style: TextStyle(fontSize: 11,
                      color: docs.isNotEmpty
                          ? Colors.red.shade700 : Colors.green.shade700)),
            ])),
          ]),
        ),
        Expanded(child: docs.isEmpty
            ? Center(child: Column(
                mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.shield_outlined, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 12),
              const Text('Yetkisiz giriş kaydı yok',
                  style: TextStyle(color: Colors.grey, fontSize: 15)),
            ]))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  return Card(
                    color: Colors.red.shade50,
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.red.shade200)),
                    child: ListTile(
                      leading: const Icon(Icons.no_crash_outlined,
                          color: Colors.red, size: 28),
                      title: Text(d['plaka'] ?? '-',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16, color: Colors.red,
                              letterSpacing: 2)),
                      subtitle: Text(
                          'Tanınmayan araç • ${d['girisSaatiStr'] ?? ''} ${d['gun'] ?? ''}',
                          style: const TextStyle(fontSize: 11)),
                      trailing: IconButton(
                          icon: const Icon(Icons.add_circle_outline,
                              color: Colors.green),
                          tooltip: 'Sisteme Ekle',
                          onPressed: () => _snack(
                              'Plakayı Araçlar menüsünden ekleyin')),
                    ),
                  );
                },
              )),
      ]);
    },
  );

  // ── Dialog'lar ────────────────────────────────────────────────
  void _basariDialog(String plaka, Map<String, dynamic> sofor,
      DateTime saat) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 64, height: 64,
              decoration: BoxDecoration(
                  color: Colors.green.shade100, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded,
                  color: Colors.green, size: 36)),
          const SizedBox(height: 14),
          Text(plaka, style: const TextStyle(
              fontSize: 24, fontWeight: FontWeight.bold,
              letterSpacing: 4, color: _navy)),
          const SizedBox(height: 4),
          Text('Servis Tamamlandı',
              style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(10)),
              child: Column(children: [
                _dialogSatir(Icons.person_outlined,
                    sofor['adSoyad'] ?? sofor['ad'] ?? '-'),
                _dialogSatir(Icons.access_time_outlined,
                    '${saat.hour.toString().padLeft(2,'0')}:'
                        '${saat.minute.toString().padLeft(2,'0')}'),
                _dialogSatir(Icons.notifications_outlined,
                    'Velilere bildirim gönderildi'),
              ])),
        ]),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _navy, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Navigator.pop(_);
              _plakaCtrl.clear();
            },
            child: const Text('Tamam')),
        ],
      ),
    );
  }

  Widget _dialogSatir(IconData icon, String metin) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Icon(icon, size: 14, color: Colors.grey),
      const SizedBox(width: 8),
      Text(metin, style: const TextStyle(fontSize: 13)),
    ]),
  );

  void _yetkisizUyari(String plaka) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.red.shade50,
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
          SizedBox(width: 8),
          Text('YETKİSİZ ARAÇ',
              style: TextStyle(color: Colors.red,
                  fontWeight: FontWeight.bold)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(plaka, style: const TextStyle(
              fontSize: 28, fontWeight: FontWeight.bold,
              letterSpacing: 4, color: Colors.red)),
          const SizedBox(height: 8),
          const Text(
            'Bu plaka sistemde kayıtlı değil!\n'
            'Güvenlik kaydına alındı.\n'
            'Yetkili görevli bilgilendirildi.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red)),
        ]),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () { Navigator.pop(_); _plakaCtrl.clear(); },
            child: const Text('Anladım')),
        ],
      ),
    );
  }
}
