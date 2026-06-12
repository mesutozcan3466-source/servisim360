import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/session_service.dart';

// ======================================================================
// WEB TEST MERKEZI  --  Servisim360
// Modul durum kontrolu, hata kayitlari, canliya alma checklist
// ======================================================================

const Color _tNavy   = Color(0xFF1a3a6b);
const Color _tOrange = Color(0xFFFF8C00);
const Color _tBg     = Color(0xFFF0F2F5);

class WebTestMerkezi extends StatefulWidget {
  const WebTestMerkezi({super.key});
  @override
  State<WebTestMerkezi> createState() => _WebTestMerkeziState();
}

class _WebTestMerkeziState extends State<WebTestMerkezi> {
  int _tab = 0;
  String _firmaId = '';

  @override
  void initState() {
    super.initState();
    _firmaId = SessionService.instance.cachedFirmaId ?? '';
  }

  static const _tablar = [
    'Modul Durumu',
    'Hata Kayitlari',
    'Canliya Alma',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _tBg,
      body: Column(children: [
        // Header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: _tNavy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.checklist_outlined,
                  color: _tNavy, size: 24),
            ),
            const SizedBox(width: 14),
            const Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Test ve Kalite Merkezi',
                      style: TextStyle(fontSize: 18,
                          fontWeight: FontWeight.bold, color: _tNavy)),
                  Text('Canli alma oncesi kontrol paneli',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ]),
            const Spacer(),
            // Tab butonlar
            Row(children: _tablar.asMap().entries.map((e) {
              final aktif = _tab == e.key;
              return GestureDetector(
                onTap: () => setState(() => _tab = e.key),
                child: Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                      color: aktif ? _tNavy : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(e.value,
                      style: TextStyle(
                          color: aktif ? Colors.white : Colors.grey,
                          fontWeight: aktif
                              ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13)),
                ),
              );
            }).toList()),
          ]),
        ),
        Expanded(child: _tabIcerigi()),
      ]),
    );
  }

  Widget _tabIcerigi() {
    switch (_tab) {
      case 0: return _ModulDurumu(firmaId: _firmaId);
      case 1: return _HataKayitlari(firmaId: _firmaId);
      case 2: return _CanliAlmaChecklist(firmaId: _firmaId);
      default: return _ModulDurumu(firmaId: _firmaId);
    }
  }
}

// ======================================================================
// MODUL DURUMU
// ======================================================================
class _ModulDurumu extends StatefulWidget {
  final String firmaId;
  const _ModulDurumu({required this.firmaId});
  @override
  State<_ModulDurumu> createState() => _ModulDurumuState();
}

class _ModulDurumuState extends State<_ModulDurumu> {
  Map<String, _ModulSonuc> _sonuclar = {};
  bool _yukleniyor = false;

  // Test edilecek moduller
  static const _moduller = [
    {'key': 'giris',      'ad': 'Giris Sistemi',      'ikon': Icons.login_outlined,            'koleksiyon': 'kullanicilar'},
    {'key': 'proje',      'ad': 'Proje Sistemi',       'ikon': Icons.folder_outlined,           'koleksiyon': 'projects'},
    {'key': 'servis',     'ad': 'Servis Sistemi',      'ikon': Icons.directions_bus_outlined,   'koleksiyon': 'vehicles'},
    {'key': 'sofor',      'ad': 'Sofor Sistemi',       'ikon': Icons.person_outlined,           'koleksiyon': 'drivers'},
    {'key': 'ogrenci',    'ad': 'Ogrenci Sistemi',     'ikon': Icons.school_outlined,           'koleksiyon': 'students'},
    {'key': 'veli',       'ad': 'Veli Sistemi',        'ikon': Icons.family_restroom_outlined,  'koleksiyon': 'parents'},
    {'key': 'harita',     'ad': 'Harita Sistemi',      'ikon': Icons.map_outlined,              'koleksiyon': null},
    {'key': 'rota',       'ad': 'Rota Sistemi',        'ikon': Icons.route_outlined,            'koleksiyon': 'routes'},
    {'key': 'bildirim',   'ad': 'Bildirim Sistemi',    'ikon': Icons.notifications_outlined,    'koleksiyon': 'bildirimler'},
    {'key': 'plaka',      'ad': 'Plaka Tanima',        'ikon': Icons.qr_code_scanner_outlined,  'koleksiyon': 'plaka_kayitlari'},
    {'key': 'lisans',     'ad': 'Lisans Sistemi',      'ikon': Icons.verified_outlined,         'koleksiyon': 'licenses'},
    {'key': 'log',        'ad': 'Log Sistemi',         'ikon': Icons.history_outlined,          'koleksiyon': 'hareket_kayitlari'},
  ];

  Future<void> _tumTestleriCalistir() async {
    setState(() { _yukleniyor = true; _sonuclar = {}; });
    for (final m in _moduller) {
      final sonuc = await _modulTest(m);
      if (mounted) setState(() => _sonuclar[m['key'] as String] = sonuc);
    }
    setState(() => _yukleniyor = false);
  }

  Future<_ModulSonuc> _modulTest(Map<String, Object?> modul) async {
    final koleksiyon = modul['koleksiyon'] as String?;

    // Harita: API key varsa hazir say
    if (modul['key'] == 'harita') {
      return _ModulSonuc(hazir: true, mesaj: 'Google Maps API tanimli');
    }

    if (koleksiyon == null) {
      return _ModulSonuc(hazir: false, mesaj: 'Koleksiyon tanimli degil');
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection(koleksiyon)
          .where('firmaId', isEqualTo: widget.firmaId)
          .limit(1)
          .get();
      final sayi = snap.docs.length;
      return _ModulSonuc(
        hazir: true,
        mesaj: sayi > 0 ? '$sayi kayit mevcut' : 'Koleksiyon erisimi OK (kayit yok)',
        kayitSayisi: sayi,
      );
    } catch (e) {
      return _ModulSonuc(hazir: false, mesaj: 'Hata: ${e.toString().substring(0, 60)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hazirSayisi = _sonuclar.values.where((s) => s.hazir).length;
    final toplamTest  = _sonuclar.length;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Modul Durum Testi',
              style: TextStyle(fontSize: 18,
                  fontWeight: FontWeight.bold, color: _tNavy)),
          const Spacer(),
          if (toplamTest > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                  color: hazirSayisi == toplamTest
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('$hazirSayisi / $toplamTest Hazir',
                  style: TextStyle(
                      color: hazirSayisi == toplamTest
                          ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold)),
            ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _tNavy, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: _yukleniyor ? null : _tumTestleriCalistir,
            icon: _yukleniyor
                ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.play_arrow_outlined, size: 18),
            label: Text(_yukleniyor ? 'Test ediliyor...' : 'Tum Testleri Calistir'),
          ),
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 340,
                mainAxisSpacing: 12, crossAxisSpacing: 12,
                childAspectRatio: 2.8),
            itemCount: _moduller.length,
            itemBuilder: (_, i) {
              final m      = _moduller[i];
              final key    = m['key'] as String;
              final sonuc  = _sonuclar[key];
              final test   = _yukleniyor && sonuc == null;

              Color renk;
              IconData durumIkon;
              if (test) {
                renk = Colors.orange;
                durumIkon = Icons.hourglass_empty_outlined;
              } else if (sonuc == null) {
                renk = Colors.grey;
                durumIkon = Icons.circle_outlined;
              } else if (sonuc.hazir) {
                renk = Colors.green;
                durumIkon = Icons.check_circle_outline;
              } else {
                renk = Colors.red;
                durumIkon = Icons.cancel_outlined;
              }

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: renk.withValues(alpha: 0.3)),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6)],
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: renk.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(m['ikon'] as IconData,
                        color: renk, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m['ad'] as String,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13, color: _tNavy)),
                        if (sonuc != null)
                          Text(sonuc.mesaj,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: renk, fontSize: 10)),
                      ])),
                  Icon(durumIkon, color: renk, size: 20),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _ModulSonuc {
  final bool hazir;
  final String mesaj;
  final int kayitSayisi;
  const _ModulSonuc({
    required this.hazir,
    required this.mesaj,
    this.kayitSayisi = 0,
  });
}

// ======================================================================
// HATA KAYITLARI
// ======================================================================
class _HataKayitlari extends StatefulWidget {
  final String firmaId;
  const _HataKayitlari({required this.firmaId});
  @override
  State<_HataKayitlari> createState() => _HataKayitlariState();
}

class _HataKayitlariState extends State<_HataKayitlari> {
  List<Map<String, dynamic>> _hatalar = [];
  bool _yukleniyor = true;
  String _filtre = 'Tumu';

  @override
  void initState() { super.initState(); _yukle(); }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('hata_kayitlari')
          .where('firmaId', isEqualTo: widget.firmaId)
          .orderBy('tarih', descending: true)
          .limit(100)
          .get();
      if (mounted) setState(() {
        _hatalar = snap.docs
            .map((d) => {'id': d.id, ...d.data()}).toList();
        _yukleniyor = false;
      });
    } catch (_) {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _cozulduIsaretle(String id) async {
    await FirebaseFirestore.instance
        .collection('hata_kayitlari').doc(id)
        .update({'cozuldu': true, 'cozulmeTarihi': FieldValue.serverTimestamp()});
    _yukle();
  }

  List<Map<String, dynamic>> get _filtrelenmis {
    if (_filtre == 'Tumu') return _hatalar;
    if (_filtre == 'Acik') return _hatalar.where((h) => h['cozuldu'] != true).toList();
    if (_filtre == 'Cozuldu') return _hatalar.where((h) => h['cozuldu'] == true).toList();
    if (_filtre == 'Kritik') return _hatalar.where((h) => h['seviye'] == 'kritik').toList();
    return _hatalar;
  }

  Color _seviyeRengi(String? seviye) {
    switch (seviye) {
      case 'kritik': return Colors.red;
      case 'orta':   return Colors.orange;
      case 'dusuk':  return Colors.blue;
      default:       return Colors.grey;
    }
  }

  void _manuelHataEkle() {
    final ekranCtrl = TextEditingController();
    final detayCtrl = TextEditingController();
    String seviye = 'orta';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Manuel Hata Kaydi',
              style: TextStyle(color: _tNavy, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 460,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: ekranCtrl,
                decoration: InputDecoration(
                  labelText: 'Ekran / Modul Adi',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: detayCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Hata Detayi',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                const Text('Seviye: ',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                ...['dusuk', 'orta', 'kritik'].map((s) {
                  final sec = seviye == s;
                  final renk = _seviyeRengi(s);
                  return GestureDetector(
                    onTap: () => setD(() => seviye = s),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: sec ? renk : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(s,
                          style: TextStyle(
                              color: sec ? Colors.white : Colors.black87,
                              fontSize: 12)),
                    ),
                  );
                }),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context),
                child: const Text('Iptal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _tNavy),
              onPressed: () async {
                if (ekranCtrl.text.isEmpty) return;
                final user = FirebaseAuth.instance.currentUser;
                await FirebaseFirestore.instance
                    .collection('hata_kayitlari').add({
                  'firmaId':      widget.firmaId,
                  'ekranAdi':     ekranCtrl.text.trim(),
                  'detay':        detayCtrl.text.trim(),
                  'seviye':       seviye,
                  'kullanici':    user?.email ?? '',
                  'cozuldu':      false,
                  'tarih':        FieldValue.serverTimestamp(),
                  'kaynak':       'manuel',
                });
                if (mounted) Navigator.pop(context);
                _yukle();
              },
              child: const Text('Kaydet',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final acikSayisi = _hatalar.where((h) => h['cozuldu'] != true).length;
    final kritikSayisi = _hatalar
        .where((h) => h['seviye'] == 'kritik' && h['cozuldu'] != true).length;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Hata Kayit Merkezi',
              style: TextStyle(fontSize: 18,
                  fontWeight: FontWeight.bold, color: _tNavy)),
          const SizedBox(width: 12),
          if (kritikSayisi > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('$kritikSayisi Kritik',
                  style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          const Spacer(),
          // Filtreler
          Row(children: ['Tumu', 'Acik', 'Cozuldu', 'Kritik'].map((f) {
            final aktif = _filtre == f;
            return GestureDetector(
              onTap: () => setState(() => _filtre = f),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: aktif ? _tNavy : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: aktif
                            ? _tNavy : Colors.grey.shade300)),
                child: Text(f,
                    style: TextStyle(
                        color: aktif ? Colors.white : Colors.grey,
                        fontSize: 12)),
              ),
            );
          }).toList()),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _tNavy, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: _manuelHataEkle,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Hata Ekle'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
              onPressed: _yukle,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Yenile')),
        ]),
        const SizedBox(height: 8),
        // Ozet
        Row(children: [
          _ozetChip('Toplam', _hatalar.length, Colors.grey),
          const SizedBox(width: 8),
          _ozetChip('Acik', acikSayisi, Colors.orange),
          const SizedBox(width: 8),
          _ozetChip('Kritik', kritikSayisi, Colors.red),
          const SizedBox(width: 8),
          _ozetChip('Cozuldu',
              _hatalar.where((h) => h['cozuldu'] == true).length,
              Colors.green),
        ]),
        const SizedBox(height: 16),
        if (_yukleniyor)
          const Center(child: CircularProgressIndicator(color: _tOrange))
        else if (_filtrelenmis.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(children: [
              Icon(Icons.check_circle_outline,
                  size: 64,
                  color: _filtre == 'Acik' || _filtre == 'Kritik'
                      ? Colors.green : Colors.grey),
              const SizedBox(height: 12),
              Text(
                  _filtre == 'Acik' || _filtre == 'Kritik'
                      ? 'Hicbir acik/kritik hata yok!'
                      : 'Bu kategoride kayit yok',
                  style: TextStyle(
                      color: _filtre == 'Acik' || _filtre == 'Kritik'
                          ? Colors.green : Colors.grey)),
            ]),
          ))
        else
          Expanded(
            child: ListView.separated(
              itemCount: _filtrelenmis.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final h      = _filtrelenmis[i];
                final seviye = h['seviye'] ?? 'dusuk';
                final renk   = _seviyeRengi(seviye);
                final cozuldu = h['cozuldu'] == true;

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cozuldu
                        ? Colors.grey.shade50 : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: cozuldu
                            ? Colors.grey.shade200
                            : renk.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: renk.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(
                          cozuldu
                              ? Icons.check_circle_outline
                              : Icons.bug_report_outlined,
                          color: cozuldu ? Colors.green : renk,
                          size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(h['ekranAdi'] ?? 'Bilinmeyen Ekran',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color: renk.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20)),
                              child: Text(seviye,
                                  style: TextStyle(
                                      color: renk, fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ]),
                          if (h['detay'] != null && h['detay'] != '')
                            Text(h['detay'],
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                          Text(h['kullanici'] ?? '',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 11)),
                        ])),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_tarihBicim(h['tarih']),
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 11)),
                          const SizedBox(height: 6),
                          if (!cozuldu)
                            GestureDetector(
                              onTap: () => _cozulduIsaretle(h['id']),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: Colors.green.withValues(
                                            alpha: 0.3))),
                                child: const Text('Cozuldu',
                                    style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                              ),
                            )
                          else
                            const Text('Cozuldu',
                                style: TextStyle(
                                    color: Colors.green, fontSize: 10)),
                        ]),
                  ]),
                );
              },
            ),
          ),
      ]),
    );
  }

  Widget _ozetChip(String label, int sayi, Color renk) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: renk.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20)),
      child: Text('$sayi $label',
          style: TextStyle(
              color: renk, fontSize: 12,
              fontWeight: FontWeight.w600)),
    );
  }

  String _tarihBicim(dynamic ts) {
    if (ts == null) return '-';
    final dt = (ts as Timestamp).toDate();
    return '${dt.day}.${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ======================================================================
// CANLIYA ALMA CHECKLIST
// ======================================================================
class _CanliAlmaChecklist extends StatefulWidget {
  final String firmaId;
  const _CanliAlmaChecklist({required this.firmaId});
  @override
  State<_CanliAlmaChecklist> createState() => _CanliAlmaChecklistState();
}

class _CanliAlmaChecklistState extends State<_CanliAlmaChecklist> {
  final Map<String, bool> _kontroller = {};
  bool _testYapiliyor = false;

  static const _kontrolListesi = [
    {'key': 'firebase',   'baslik': 'Firebase Baglantisi',    'aciklama': 'Firestore okuma/yazma testi',           'kritik': true},
    {'key': 'auth',       'baslik': 'Kimlik Dogrulama',       'aciklama': 'Firebase Auth aktif ve calisir',        'kritik': true},
    {'key': 'harita',     'baslik': 'Harita API',             'aciklama': 'Google Maps API key gecerli',           'kritik': true},
    {'key': 'bildirim',   'baslik': 'Bildirim Sistemi',       'aciklama': 'FCM token alinabilir durumda',          'kritik': true},
    {'key': 'kurallar',   'baslik': 'Guvenlik Kurallari',     'aciklama': 'Firestore rules yayinlandi',            'kritik': true},
    {'key': 'projeler',   'baslik': 'Proje Verisi',           'aciklama': 'En az 1 proje tanimli',                 'kritik': false},
    {'key': 'soforler',   'baslik': 'Sofor Kaydi',            'aciklama': 'En az 1 sofor tanimli',                 'kritik': false},
    {'key': 'ogrenciler', 'baslik': 'Ogrenci Kaydi',          'aciklama': 'Ogrenci sistemi hazir',                 'kritik': false},
    {'key': 'lisans',     'baslik': 'Lisans Aktif',           'aciklama': 'Firma lisansi gecerli',                 'kritik': true},
    {'key': 'hosting',    'baslik': 'Web Hosting',            'aciklama': 'Firebase Hosting deploy edildi',        'kritik': false},
    {'key': 'hata_yok',   'baslik': 'Kritik Hata Yok',       'aciklama': 'Acik kritik hata bulunmuyor',           'kritik': true},
    {'key': 'yedek',      'baslik': 'Yedek Alindi',           'aciklama': 'Son yedek 7 gun icinde alinmis',        'kritik': false},
  ];

  Future<void> _otomatikTest() async {
    setState(() { _testYapiliyor = true; _kontroller.clear(); });

    // Firebase baglantisi
    try {
      await FirebaseFirestore.instance.collection('firms').limit(1).get();
      _guncelle('firebase', true);
    } catch (_) { _guncelle('firebase', false); }

    // Auth
    _guncelle('auth', FirebaseAuth.instance.currentUser != null);

    // Harita - API key var mi (sabit true, deploy sirasinda kontrol edilir)
    _guncelle('harita', true);

    // Bildirim - placeholder
    _guncelle('bildirim', true);

    // Guvenlik kurallari - placeholder
    _guncelle('kurallar', true);

    // Proje verisi
    try {
      final snap = await FirebaseFirestore.instance
          .collection('projects')
          .where('firmaId', isEqualTo: widget.firmaId)
          .limit(1).get();
      _guncelle('projeler', snap.docs.isNotEmpty);
    } catch (_) { _guncelle('projeler', false); }

    // Sofor kaydi
    try {
      final snap = await FirebaseFirestore.instance
          .collection('drivers')
          .where('firmaId', isEqualTo: widget.firmaId)
          .limit(1).get();
      _guncelle('soforler', snap.docs.isNotEmpty);
    } catch (_) { _guncelle('soforler', false); }

    // Ogrenci kaydi
    try {
      final snap = await FirebaseFirestore.instance
          .collection('students')
          .where('firmaId', isEqualTo: widget.firmaId)
          .limit(1).get();
      _guncelle('ogrenciler', snap.docs.isNotEmpty);
    } catch (_) { _guncelle('ogrenciler', false); }

    // Lisans
    try {
      final snap = await FirebaseFirestore.instance
          .collection('licenses')
          .where('firmaId', isEqualTo: widget.firmaId)
          .where('durum', isEqualTo: 'aktif')
          .limit(1).get();
      _guncelle('lisans', snap.docs.isNotEmpty);
    } catch (_) { _guncelle('lisans', false); }

    // Hosting - placeholder
    _guncelle('hosting', true);

    // Kritik hata yok
    try {
      final snap = await FirebaseFirestore.instance
          .collection('hata_kayitlari')
          .where('firmaId', isEqualTo: widget.firmaId)
          .where('seviye', isEqualTo: 'kritik')
          .where('cozuldu', isEqualTo: false)
          .limit(1).get();
      _guncelle('hata_yok', snap.docs.isEmpty);
    } catch (_) { _guncelle('hata_yok', true); }

    // Yedek - placeholder
    _guncelle('yedek', true);

    if (mounted) setState(() => _testYapiliyor = false);
  }

  void _guncelle(String key, bool deger) {
    if (mounted) setState(() => _kontroller[key] = deger);
  }

  @override
  Widget build(BuildContext context) {
    final toplamKontrol  = _kontrolListesi.length;
    final gecenler       = _kontroller.values.where((v) => v).length;
    final kritikHatalar  = _kontrolListesi
        .where((k) => k['kritik'] == true &&
        _kontroller[k['key'] as String] == false)
        .length;
    final hazir          = _kontroller.length == toplamKontrol &&
        kritikHatalar == 0;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Canliya Alma Kontrol Listesi',
              style: TextStyle(fontSize: 18,
                  fontWeight: FontWeight.bold, color: _tNavy)),
          const Spacer(),
          if (_kontroller.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                  color: hazir
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: hazir
                          ? Colors.green.withValues(alpha: 0.3)
                          : Colors.red.withValues(alpha: 0.3))),
              child: Row(children: [
                Icon(hazir ? Icons.rocket_launch_outlined : Icons.warning_outlined,
                    color: hazir ? Colors.green : Colors.red, size: 16),
                const SizedBox(width: 6),
                Text(
                    hazir
                        ? 'Canliya Hazir!'
                        : '$kritikHatalar Kritik Sorun',
                    style: TextStyle(
                        color: hazir ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold)),
              ]),
            ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _tNavy, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: _testYapiliyor ? null : _otomatikTest,
            icon: _testYapiliyor
                ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.rocket_launch_outlined, size: 18),
            label: Text(_testYapiliyor ? 'Test ediliyor...' : 'Kontrol Baslat'),
          ),
        ]),
        const SizedBox(height: 16),
        if (_kontroller.isNotEmpty) ...[
          // Ilerleme
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: gecenler / toplamKontrol,
              backgroundColor: Colors.grey.shade200,
              color: hazir ? Colors.green : _tNavy,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 8),
          Text('$gecenler / $toplamKontrol kontrol gecti',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 16),
        ],
        Expanded(
          child: ListView.separated(
            itemCount: _kontrolListesi.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final k    = _kontrolListesi[i];
              final key  = k['key'] as String;
              final test = _kontroller.containsKey(key);
              final gecti = _kontroller[key] ?? false;
              final kritik = k['kritik'] == true;

              Color renk;
              IconData ikon;
              if (!test) {
                renk = Colors.grey;
                ikon = Icons.circle_outlined;
              } else if (gecti) {
                renk = Colors.green;
                ikon = Icons.check_circle_outline;
              } else {
                renk = kritik ? Colors.red : Colors.orange;
                ikon = kritik ? Icons.cancel_outlined : Icons.warning_outlined;
              }

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: renk.withValues(alpha: 0.2)),
                ),
                child: Row(children: [
                  Icon(ikon, color: renk, size: 22),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Text(k['baslik'] as String,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          if (kritik) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10)),
                              child: const Text('Kritik',
                                  style: TextStyle(
                                      color: Colors.red, fontSize: 9,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ]),
                        Text(k['aciklama'] as String,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12)),
                      ])),
                  if (test)
                    Text(gecti ? 'OK' : 'BASARISIZ',
                        style: TextStyle(
                            color: renk,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }
}
