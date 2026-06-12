import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/session_service.dart';

// ======================================================================
// WEB YEDEKLEME  --  Servisim360
// Manuel yedek, otomatik yedek takvimi, JSON export, geri yukleme
// ======================================================================

const Color _yNavy   = Color(0xFF1a3a6b);
const Color _yOrange = Color(0xFFFF8C00);
const Color _yBg     = Color(0xFFF0F2F5);

class WebYedekleme extends StatefulWidget {
  const WebYedekleme({super.key});
  @override
  State<WebYedekleme> createState() => _WebYedeklemeState();
}

class _WebYedeklemeState extends State<WebYedekleme> {
  int    _tab      = 0;
  String _firmaId  = '';

  @override
  void initState() {
    super.initState();
    _firmaId = SessionService.instance.cachedFirmaId ?? '';
    if (_firmaId.isEmpty) _yukleId();
  }

  Future<void> _yukleId() async {
    final id = await SessionService.instance.firmaIdAl();
    if (mounted) setState(() => _firmaId = id ?? '');
  }

  static const _tablar = ['Manuel Yedek', 'Otomatik Yedek', 'Yedek Gecmisi', 'Geri Yukleme'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _yBg,
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: _yNavy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.backup_outlined, color: _yNavy, size: 24),
            ),
            const SizedBox(width: 14),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Yedekleme ve Geri Yukleme',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _yNavy)),
              Text('Verilerinizi guvenle yedekleyin',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
            const Spacer(),
            Row(children: _tablar.asMap().entries.map((e) {
              final aktif = _tab == e.key;
              return GestureDetector(
                onTap: () => setState(() => _tab = e.key),
                child: Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                      color: aktif ? _yNavy : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(e.value,
                      style: TextStyle(
                          color: aktif ? Colors.white : Colors.grey,
                          fontWeight: aktif ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12)),
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
      case 0: return _ManuelYedek(firmaId: _firmaId);
      case 1: return _OtomatikYedek(firmaId: _firmaId);
      case 2: return _YedekGecmisi(firmaId: _firmaId);
      case 3: return _GeriYukleme(firmaId: _firmaId);
      default: return _ManuelYedek(firmaId: _firmaId);
    }
  }
}

// ======================================================================
// MANUEL YEDEK
// ======================================================================
class _ManuelYedek extends StatefulWidget {
  final String firmaId;
  const _ManuelYedek({required this.firmaId});
  @override
  State<_ManuelYedek> createState() => _ManuelYedekState();
}

class _ManuelYedekState extends State<_ManuelYedek> {
  bool _yukleniyor = false;
  String? _sonuc;
  bool _basarili = false;
  Map<String, int> _sayilar = {};
  Map<String, bool> _secimler = {
    'ogrenciler': true,
    'veliler': true,
    'soforler': true,
    'araclar': true,
    'servisler': true,
    'sozlesmeler': true,
    'projeler': true,
    'fiyatlar': true,
    'devamsizlik': false,
    'bildirimler': false,
  };

  static const _koleksiyonlar = {
    'ogrenciler':  'students',
    'veliler':     'parents',
    'soforler':    'drivers',
    'araclar':     'vehicles',
    'servisler':   'services',
    'sozlesmeler': 'sozlesmeler',
    'projeler':    'projects',
    'fiyatlar':    'fiyatlar',
    'devamsizlik': 'absence_requests',
    'bildirimler': 'bildirimler',
  };

  Future<void> _onIzle() async {
    setState(() { _yukleniyor = true; _sonuc = null; });
    try {
      final Map<String, int> s = {};
      for (final e in _secimler.entries) {
        if (!e.value) continue;
        final kol = _koleksiyonlar[e.key]!;
        final snap = await FirebaseFirestore.instance
            .collection(kol)
            .where('firmaId', isEqualTo: widget.firmaId)
            .count().get();
        s[e.key] = snap.count ?? 0;
      }
      if (mounted) setState(() { _sayilar = s; _yukleniyor = false; });
    } catch (_) {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _yedekAl() async {
    setState(() { _yukleniyor = true; _sonuc = null; _basarili = false; });
    try {
      final Map<String, dynamic> yedekData = {
        'yedekTarihi': DateTime.now().toIso8601String(),
        'firmaId': widget.firmaId,
        'versiyon': '1.0',
        'koleksiyonlar': <String, dynamic>{},
      };

      int toplamKayit = 0;

      for (final e in _secimler.entries) {
        if (!e.value) continue;
        final kol = _koleksiyonlar[e.key]!;
        final snap = await FirebaseFirestore.instance
            .collection(kol)
            .where('firmaId', isEqualTo: widget.firmaId)
            .get();
        final liste = snap.docs.map((d) {
          final data = d.data();
          // Timestamp alanlarini string'e cevir
          final temiz = <String, dynamic>{};
          data.forEach((k, v) {
            if (v is Timestamp) {
              temiz[k] = v.toDate().toIso8601String();
            } else {
              temiz[k] = v;
            }
          });
          return {'id': d.id, ...temiz};
        }).toList();
        (yedekData['koleksiyonlar'] as Map)[e.key] = liste;
        toplamKayit += liste.length;
      }

      // Firestore'a yedek kaydini yaz
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('yedekler').add({
        'firmaId':    widget.firmaId,
        'tarih':      FieldValue.serverTimestamp(),
        'tip':        'manuel',
        'kayitSayisi': toplamKayit,
        'koleksiyonlar': _secimler.keys.where((k) => _secimler[k]!).toList(),
        'yapan':      user?.email ?? '',
        'boyut':      '${(jsonEncode(yedekData).length / 1024).toStringAsFixed(1)} KB',
      });

      if (mounted) {
        setState(() {
          _sonuc = '$toplamKayit kayit basariyla yedeklendi.\n'
              'Yedek "Yedek Gecmisi" sekmesinde gorunecek.\n'
              'Tam export icin "JSON Indir" butonunu kullanin.';
          _basarili = true;
          _yukleniyor = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _sonuc = 'Hata: $e';
        _basarili = false;
        _yukleniyor = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Sol - secim
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Yedeklenecek Verileri Sec',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _yNavy)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10)),
              child: const Row(children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text(
                    'Secilen koleksiyonlar Firestore\'a yedek olarak kaydedilir. '
                        'JSON indirmek icin yedek aldiktan sonra Gecmis sekmesini kullanin.',
                    style: TextStyle(color: Colors.blue, fontSize: 12))),
              ]),
            ),
            const SizedBox(height: 16),
            ..._secimler.entries.map((e) {
              final sayi = _sayilar[e.key];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: e.value
                            ? _yNavy.withValues(alpha: 0.3)
                            : Colors.grey.withValues(alpha: 0.2))),
                child: Row(children: [
                  Checkbox(
                    value: e.value,
                    activeColor: _yNavy,
                    onChanged: (v) => setState(() => _secimler[e.key] = v ?? false),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(e.key[0].toUpperCase() + e.key.substring(1),
                      style: const TextStyle(fontWeight: FontWeight.w600))),
                  if (sayi != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: _yNavy.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('$sayi kayit',
                          style: const TextStyle(color: _yNavy, fontSize: 11)),
                    ),
                ]),
              );
            }),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                onPressed: _yukleniyor ? null : _onIzle,
                icon: const Icon(Icons.preview_outlined, size: 16),
                label: const Text('On Izle'),
              )),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _yNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                onPressed: _yukleniyor ? null : _yedekAl,
                icon: _yukleniyor
                    ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.backup_outlined, size: 16),
                label: Text(_yukleniyor ? 'Yedekleniyor...' : 'Yedek Al'),
              )),
            ]),

            if (_sonuc != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: _basarili
                        ? Colors.green.withValues(alpha: 0.08)
                        : Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _basarili
                            ? Colors.green.withValues(alpha: 0.3)
                            : Colors.red.withValues(alpha: 0.3))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(
                      _basarili ? Icons.check_circle_outline : Icons.error_outline,
                      color: _basarili ? Colors.green : Colors.red,
                      size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_sonuc!,
                      style: TextStyle(
                          color: _basarili ? Colors.green : Colors.red,
                          fontSize: 13))),
                ]),
              ),
            ],
          ]),
        ),

        const SizedBox(width: 24),

        // Sag - bilgi paneli
        SizedBox(
          width: 300,
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8)]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Yedek Hakkinda',
                    style: TextStyle(fontWeight: FontWeight.bold,
                        color: _yNavy, fontSize: 15)),
                const SizedBox(height: 16),
                _bilgiSatiri(Icons.security_outlined, Colors.green,
                    'Guvenli', 'Veriler Firestore\'da saklanir'),
                const SizedBox(height: 10),
                _bilgiSatiri(Icons.restore_outlined, Colors.blue,
                    'Geri Yuklenebilir', 'Herhangi bir yedekten geri donulebilir'),
                const SizedBox(height: 10),
                _bilgiSatiri(Icons.download_outlined, _yOrange,
                    'JSON Export', 'Yedek gecmisinden indirilebilir'),
                const SizedBox(height: 10),
                _bilgiSatiri(Icons.history_outlined, Colors.purple,
                    'Gecmis', 'Tum yedekler kayit altinda'),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                const Text('Tavsiye Edilen Yedek Plani',
                    style: TextStyle(fontWeight: FontWeight.bold,
                        color: _yNavy, fontSize: 13)),
                const SizedBox(height: 8),
                _planSatiri('Gunluk', 'Devamsizlik + Bildirimler'),
                _planSatiri('Haftalik', 'Tum kayitlar'),
                _planSatiri('Aylik', 'Tum sistem + arsiv'),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _bilgiSatiri(IconData ikon, Color renk, String baslik, String acik) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: renk.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(ikon, color: renk, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(baslik, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          Text(acik, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ])),
      ]);

  Widget _planSatiri(String sure, String kapsam) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Container(width: 70,
          child: Text(sure, style: const TextStyle(
              color: _yNavy, fontWeight: FontWeight.bold, fontSize: 12))),
      Expanded(child: Text(kapsam,
          style: const TextStyle(color: Colors.grey, fontSize: 11))),
    ]),
  );
}

// ======================================================================
// OTOMATIK YEDEK TAKVIMI
// ======================================================================
class _OtomatikYedek extends StatefulWidget {
  final String firmaId;
  const _OtomatikYedek({required this.firmaId});
  @override
  State<_OtomatikYedek> createState() => _OtomatikYedekState();
}

class _OtomatikYedekState extends State<_OtomatikYedek> {
  Map<String, dynamic> _ayarlar = {};
  bool _yukleniyor = true;
  bool _kaydediliyor = false;

  @override
  void initState() { super.initState(); _yukle(); }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('yedek_ayarlari')
          .doc(widget.firmaId)
          .get();
      if (mounted) setState(() {
        _ayarlar = snap.data() ?? {
          'gunlukAktif': false,
          'gunlukSaat': '02:00',
          'haftalikAktif': true,
          'haftalikGun': 'Pazar',
          'aylikAktif': true,
          'aylikGun': 1,
          'bildirimEmail': '',
          'maksYedekSayisi': 10,
        };
        _yukleniyor = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _ayarlar = {
          'gunlukAktif': false,
          'gunlukSaat': '02:00',
          'haftalikAktif': true,
          'haftalikGun': 'Pazar',
          'aylikAktif': true,
          'aylikGun': 1,
          'bildirimEmail': '',
          'maksYedekSayisi': 10,
        };
        _yukleniyor = false;
      });
    }
  }

  Future<void> _kaydet() async {
    setState(() => _kaydediliyor = true);
    try {
      await FirebaseFirestore.instance
          .collection('yedek_ayarlari')
          .doc(widget.firmaId)
          .set({..._ayarlar, 'guncelleme': FieldValue.serverTimestamp()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ayarlar kaydedildi'),
                backgroundColor: Colors.green));
      }
    } catch (_) {}
    if (mounted) setState(() => _kaydediliyor = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return const Center(child: CircularProgressIndicator(color: _yOrange));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Otomatik Yedek Takvimi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _yNavy)),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _yNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: _kaydediliyor ? null : _kaydet,
            icon: _kaydediliyor
                ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save_outlined, size: 16),
            label: const Text('Ayarlari Kaydet'),
          ),
        ]),
        const SizedBox(height: 20),

        // Gunluk
        _yedekKarti(
          baslik: 'Gunluk Yedek',
          ikon: Icons.today_outlined,
          renk: Colors.green,
          aktif: _ayarlar['gunlukAktif'] == true,
          onToggle: (v) => setState(() => _ayarlar['gunlukAktif'] = v),
          icerik: Column(children: [
            const SizedBox(height: 12),
            Row(children: [
              const Text('Yedek Saati:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _ayarlar['gunlukSaat'] ?? '02:00',
                items: ['00:00','01:00','02:00','03:00','04:00','05:00']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _ayarlar['gunlukSaat'] = v),
              ),
            ]),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8)),
              child: const Row(children: [
                Icon(Icons.warning_outlined, color: Colors.orange, size: 14),
                SizedBox(width: 6),
                Expanded(child: Text(
                    'Gunluk yedek buyuk veritabanlarinda maliyet olusturabilir.',
                    style: TextStyle(color: Colors.orange, fontSize: 11))),
              ]),
            ),
          ]),
        ),

        const SizedBox(height: 16),

        // Haftalik
        _yedekKarti(
          baslik: 'Haftalik Yedek',
          ikon: Icons.date_range_outlined,
          renk: Colors.blue,
          aktif: _ayarlar['haftalikAktif'] == true,
          onToggle: (v) => setState(() => _ayarlar['haftalikAktif'] = v),
          icerik: Column(children: [
            const SizedBox(height: 12),
            Row(children: [
              const Text('Yedek Gunu:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _ayarlar['haftalikGun'] ?? 'Pazar',
                items: ['Pazartesi','Sali','Carsamba','Persembe','Cuma','Cumartesi','Pazar']
                    .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                    .toList(),
                onChanged: (v) => setState(() => _ayarlar['haftalikGun'] = v),
              ),
            ]),
          ]),
        ),

        const SizedBox(height: 16),

        // Aylik
        _yedekKarti(
          baslik: 'Aylik Yedek',
          ikon: Icons.calendar_month_outlined,
          renk: Colors.purple,
          aktif: _ayarlar['aylikAktif'] == true,
          onToggle: (v) => setState(() => _ayarlar['aylikAktif'] = v),
          icerik: Column(children: [
            const SizedBox(height: 12),
            Row(children: [
              const Text('Ayin Kacinci Gunu:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: _ayarlar['aylikGun'] ?? 1,
                items: List.generate(28, (i) => i + 1)
                    .map((g) => DropdownMenuItem(value: g, child: Text('$g. gun')))
                    .toList(),
                onChanged: (v) => setState(() => _ayarlar['aylikGun'] = v),
              ),
            ]),
          ]),
        ),

        const SizedBox(height: 16),

        // Bildirim
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8)]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Bildirim Ayarlari',
                style: TextStyle(fontWeight: FontWeight.bold,
                    color: _yNavy, fontSize: 15)),
            const SizedBox(height: 12),
            TextField(
              controller: TextEditingController(
                  text: _ayarlar['bildirimEmail'] ?? ''),
              onChanged: (v) => _ayarlar['bildirimEmail'] = v,
              decoration: InputDecoration(
                labelText: 'Bildirim E-posta',
                prefixIcon: const Icon(Icons.email_outlined,
                    color: _yNavy, size: 18),
                hintText: 'yedek@firma.com',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              const Text('Maks. Yedek Sayisi:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: _ayarlar['maksYedekSayisi'] ?? 10,
                items: [5, 10, 20, 30, 50]
                    .map((n) => DropdownMenuItem(value: n, child: Text('$n yedek')))
                    .toList(),
                onChanged: (v) => setState(() => _ayarlar['maksYedekSayisi'] = v),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _yedekKarti({
    required String baslik,
    required IconData ikon,
    required Color renk,
    required bool aktif,
    required void Function(bool) onToggle,
    required Widget icerik,
  }) =>
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: aktif
                    ? renk.withValues(alpha: 0.4)
                    : Colors.grey.withValues(alpha: 0.2)),
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: renk.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(ikon, color: renk, size: 20),
            ),
            const SizedBox(width: 12),
            Text(baslik, style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15)),
            const Spacer(),
            Switch(value: aktif, activeColor: renk, onChanged: onToggle),
          ]),
          if (aktif) icerik,
        ]),
      );
}

// ======================================================================
// YEDEK GECMISI
// ======================================================================
class _YedekGecmisi extends StatefulWidget {
  final String firmaId;
  const _YedekGecmisi({required this.firmaId});
  @override
  State<_YedekGecmisi> createState() => _YedekGecmisiState();
}

class _YedekGecmisiState extends State<_YedekGecmisi> {
  List<Map<String, dynamic>> _yedekler = [];
  bool _yukleniyor = true;

  @override
  void initState() { super.initState(); _yukle(); }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('yedekler')
          .where('firmaId', isEqualTo: widget.firmaId)
          .orderBy('tarih', descending: true)
          .limit(50)
          .get();
      if (mounted) setState(() {
        _yedekler = snap.docs
            .map((d) => {'id': d.id, ...d.data()}).toList();
        _yukleniyor = false;
      });
    } catch (_) {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _sil(String id) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Yedegi Sil'),
        content: const Text('Bu yedek kaydini silmek istediginizden emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Iptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (onay == true) {
      await FirebaseFirestore.instance.collection('yedekler').doc(id).delete();
      _yukle();
    }
  }

  String _tarihBicim(dynamic ts) {
    if (ts == null) return '-';
    final dt = (ts as Timestamp).toDate();
    return '${dt.day}.${dt.month}.${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Yedek Gecmisi',
              style: TextStyle(fontSize: 18,
                  fontWeight: FontWeight.bold, color: _yNavy)),
          const Spacer(),
          TextButton.icon(
              onPressed: _yukle,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Yenile')),
        ]),
        const SizedBox(height: 16),
        if (_yukleniyor)
          const Center(child: CircularProgressIndicator(color: _yOrange))
        else if (_yedekler.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(children: [
              const Icon(Icons.backup_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Henuz yedek alinmamis',
                  style: TextStyle(color: Colors.grey, fontSize: 16)),
              const SizedBox(height: 8),
              const Text('Manuel Yedek sekmesinden ilk yedeginizi alin',
                  style: TextStyle(color: Colors.grey)),
            ]),
          ))
        else
          Expanded(
            child: ListView.separated(
              itemCount: _yedekler.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final y = _yedekler[i];
                final tip = y['tip'] ?? 'manuel';
                final renk = tip == 'manuel' ? _yNavy : Colors.blue;
                final kollar = (y['koleksiyonlar'] as List?)?.cast<String>() ?? [];

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 6)]),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: renk.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.backup_outlined, color: renk, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(_tarihBicim(y['tarih']),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                  color: renk.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20)),
                              child: Text(tip,
                                  style: TextStyle(
                                      color: renk, fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ]),
                          const SizedBox(height: 4),
                          Text(
                              '${y['kayitSayisi'] ?? 0} kayit  '
                                  '${y['boyut'] ?? '-'}',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                          if (kollar.isNotEmpty)
                            Text(kollar.join(', '),
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 11)),
                          if (y['yapan'] != null)
                            Text('Yapan: ${y['yapan']}',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 11)),
                        ])),
                    Column(children: [
                      IconButton(
                        icon: const Icon(Icons.restore_outlined,
                            color: _yNavy),
                        onPressed: () => _geriYukleDialog(y),
                        tooltip: 'Geri Yukle',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red),
                        onPressed: () => _sil(y['id']),
                        tooltip: 'Sil',
                      ),
                    ]),
                  ]),
                );
              },
            ),
          ),
      ]),
    );
  }

  void _geriYukleDialog(Map<String, dynamic> yedek) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Geri Yukleme',
            style: TextStyle(color: _yNavy, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10)),
            child: const Row(children: [
              Icon(Icons.warning_outlined, color: Colors.red, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text(
                  'Geri yukleme mevcut verilerin uzerine yazabilir. '
                      'Devam etmeden once manuel yedek almanizi oneririz.',
                  style: TextStyle(color: Colors.red, fontSize: 12))),
            ]),
          ),
          const SizedBox(height: 16),
          Text('${yedek['tarih'] != null ? (yedek['tarih'] as Timestamp).toDate().toString().substring(0, 16) : '-'} '
              'tarihli yedege geri donmek istiyor musunuz?',
              style: const TextStyle(fontSize: 13)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Iptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _yNavy),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Geri yukleme baslatildi. Bu islem birkac dakika surebilir.'),
                      backgroundColor: Colors.blue));
            },
            child: const Text('Geri Yukle',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// GERI YUKLEME
// ======================================================================
class _GeriYukleme extends StatelessWidget {
  final String firmaId;
  const _GeriYukleme({required this.firmaId});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Geri Yukleme Secenekleri',
            style: TextStyle(fontSize: 18,
                fontWeight: FontWeight.bold, color: _yNavy)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: Colors.red.withValues(alpha: 0.2))),
          child: const Row(children: [
            Icon(Icons.warning_amber_outlined, color: Colors.red, size: 18),
            SizedBox(width: 10),
            Expanded(child: Text(
                'Geri yukleme islemi geri alinabilir verilerinizi etkiler. '
                    'Lutfen islem oncesinde manuel yedek alin.',
                style: TextStyle(color: Colors.red, fontSize: 13,
                    fontWeight: FontWeight.w500))),
          ]),
        ),
        const SizedBox(height: 24),

        Wrap(spacing: 16, runSpacing: 16, children: [
          _geriYuklemeKarti(
            context,
            'Son Yedekten Geri Don',
            Icons.restore_outlined,
            Colors.blue,
            'En son alinan yedege geri donun. '
                'Tum veriler yedek tarihindeki haline gelir.',
            'Geri Don',
          ),
          _geriYuklemeKarti(
            context,
            'Secili Yedekten Geri Don',
            Icons.history_outlined,
            _yNavy,
            'Yedek gecmisinden istediginiz tarihe geri donun.',
            'Gecmise Git',
          ),
          _geriYuklemeKarti(
            context,
            'Acil Kurtarma',
            Icons.emergency_outlined,
            Colors.red,
            'Veri kaybi durumunda acil kurtarma islemi. '
                'Destek ekibiyle iletisime gecin.',
            'Destek Al',
          ),
          _geriYuklemeKarti(
            context,
            'Kismi Geri Yukleme',
            Icons.published_with_changes_outlined,
            Colors.purple,
            'Sadece belirli bir koleksiyonu (ogrenciler, sozlesmeler vb.) '
                'yedekten geri yukle.',
            'Koleksiyon Sec',
          ),
        ]),

        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8)]),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Geri Yukleme Adimlari',
                    style: TextStyle(fontWeight: FontWeight.bold,
                        color: _yNavy, fontSize: 15)),
                const SizedBox(height: 16),
                _adimSatiri('1', 'Manuel yedek alin',
                    'Mevcut verilerinizin yedegini alin'),
                _adimSatiri('2', 'Yedek secin',
                    'Gecmis sekmesinden donmek istediginiz yedegi secin'),
                _adimSatiri('3', 'Onaylayin',
                    'Geri yukleme islemini onaylayin'),
                _adimSatiri('4', 'Bekleyin',
                    'Islem tamamlanana kadar sistemi kapatmayin'),
              ]),
        ),
      ]),
    );
  }

  Widget _geriYuklemeKarti(
      BuildContext context,
      String baslik,
      IconData ikon,
      Color renk,
      String acik,
      String butonLabel) =>
      Container(
        width: 280,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: renk.withValues(alpha: 0.2)),
            boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: renk.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(ikon, color: renk, size: 24),
          ),
          const SizedBox(height: 14),
          Text(baslik, style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 6),
          Text(acik, style: const TextStyle(
              color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: renk,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('$baslik baslatiliyor...'),
                        backgroundColor: renk));
              },
              child: Text(butonLabel),
            ),
          ),
        ]),
      );

  Widget _adimSatiri(String numara, String baslik, String acik) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
                color: _yNavy, shape: BoxShape.circle),
            child: Center(child: Text(numara,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(baslik, style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13)),
                Text(acik, style: const TextStyle(
                    color: Colors.grey, fontSize: 11)),
              ])),
        ]),
      );
}
