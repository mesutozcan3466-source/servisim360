import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

// ════════════════════════════════════════════════════════════════
//  WEB SOFOR PANELI v3
//  - Proje secimi + otomatik saat bazli gecis
//  - Servisi baslat / bitir
//  - Navigasyon ac
//  - Yoklama alma
//  - Ogrenci geldi / Yaklasiyor bildirimi
//  - Konum paylasma
//  - Acil durum
//  - Guvenlik: sadece kendi projesi
// ════════════════════════════════════════════════════════════════
class WebSoforPanel extends StatefulWidget {
  const WebSoforPanel({super.key});
  @override
  State<WebSoforPanel> createState() => _WebSoforPanelState();
}

class _WebSoforPanelState extends State<WebSoforPanel> {
  static const _navy   = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);
  static const _red    = Color(0xFFE53935);
  static const _green  = Color(0xFF43A047);

  String _soforId  = '';
  String _firmaId  = '';
  String _soforAd  = '';
  String _soforTel = '';
  bool   _yukleniyor  = true;
  bool   _servisAktif = false;
  String _sabahSaati  = '';
  String _aksamSaati  = '';
  int    _aktifTab    = 0; // 0=Ana, 1=Ogrenciler, 2=Yoklama

  List<Map<String, dynamic>> _projeler   = [];
  Map<String, dynamic>?      _aktifProje;
  List<Map<String, dynamic>> _ogrenciler = [];
  bool _ogrencilerYuk = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { setState(() => _yukleniyor = false); return; }
    try {
      final kulDoc = await FirebaseFirestore.instance
          .collection('kullanicilar').doc(uid).get();
      _firmaId = kulDoc.data()?['firmaId']  as String? ?? '';
      _soforId = kulDoc.data()?['soforId']  as String? ??
          kulDoc.data()?['surucuId'] as String? ?? uid;

      final sDoc = await FirebaseFirestore.instance
          .collection('drivers').doc(_soforId).get();
      if (sDoc.exists) {
        _soforAd    = sDoc.data()?['ad']          as String? ?? 'Sofor';
        _soforTel   = sDoc.data()?['telefon']     as String? ?? '';
        _firmaId    = sDoc.data()?['firmaId']     as String? ?? _firmaId;
        _servisAktif= sDoc.data()?['servisAktif'] as bool?   ?? false;
        _sabahSaati = sDoc.data()?['sabahSaati']  as String? ?? '';
        _aksamSaati = sDoc.data()?['aksamSaati']  as String? ?? '';

        final projeId = sDoc.data()?['projeId'] as String? ?? '';
        if (projeId.isNotEmpty) {
          final pDoc = await FirebaseFirestore.instance
              .collection('projects').doc(projeId).get();
          if (pDoc.exists) {
            _projeler   = [{'id': pDoc.id, ...pDoc.data()!}];
            _aktifProje = _projeler.first;
          }
        }
      }

      // Coklu proje: firmaId + soforId ile ara
      if (_projeler.isEmpty) {
        final snap = await FirebaseFirestore.instance
            .collection('projects')
            .where('firmaId', isEqualTo: _firmaId)
            .where('soforId', isEqualTo: _soforId)
            .where('durum', isEqualTo: 'aktif')
            .get();
        _projeler = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        if (_projeler.isNotEmpty) {
          _aktifProje = _saateBakOtomatikSec(_projeler);
        }
      }

      if (_aktifProje != null) await _ogrencileriYukle();
    } catch (e) { debugPrint('Sofor yukleme: $e'); }
    if (mounted) setState(() => _yukleniyor = false);
  }

  // Saate gore en yakin projeyi sec
  Map<String, dynamic> _saateBakOtomatikSec(List<Map<String, dynamic>> projeler) {
    final now = TimeOfDay.now();
    final nowMin = now.hour * 60 + now.minute;
    Map<String, dynamic>? enYakin;
    int enYakinFark = 9999;
    for (final p in projeler) {
      final bas = p['baslangicSaati'] as String? ?? '';
      if (bas.isEmpty) continue;
      final parts = bas.split(':');
      if (parts.length < 2) continue;
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final fark = ((h * 60 + m) - nowMin).abs();
      if (fark < enYakinFark) {
        enYakinFark = fark;
        enYakin = p;
      }
    }
    return enYakin ?? projeler.first;
  }

  Future<void> _ogrencileriYukle() async {
    setState(() => _ogrencilerYuk = true);
    try {
      // Once surucuId ile sorgula (en dogru yontem)
      var snap = await FirebaseFirestore.instance
          .collection('students')
          .where('firmaId', isEqualTo: _firmaId)
          .where('surucuId', isEqualTo: _soforId)
          .get();
      _ogrenciler = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      // surucuId ile bulunamazsa projeId ile dene
      if (_ogrenciler.isEmpty && _aktifProje != null) {
        snap = await FirebaseFirestore.instance
            .collection('students')
            .where('firmaId', isEqualTo: _firmaId)
            .where('projeId', isEqualTo: _aktifProje!['id'])
            .get();
        _ogrenciler = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      }
    } catch (e) { debugPrint('Ogrenci: $e'); }
    if (mounted) setState(() => _ogrencilerYuk = false);
  }

  // ── Servis Baslat/Bitir ───────────────────────────────────────
  Future<void> _servisBaslat() async {
    try {
      await FirebaseFirestore.instance.collection('drivers').doc(_soforId)
          .update({'servisAktif': true, 'servisBaslamaZamani': FieldValue.serverTimestamp()});
      // Tum velilere "Servis basladi" bildirimi kaydi
      await _bildirimKaydet('Servis basladi', 'servis_basladi');
      setState(() => _servisAktif = true);
      _snack('Servis baslatildi!', _green);
    } catch (e) { _snack('Hata: $e', _red); }
  }

  Future<void> _servisBitir() async {
    final onay = await _onayDialog('Servisi Bitir',
        'Servisi bitirmek istediginize emin misiniz?');
    if (!onay) return;
    try {
      await FirebaseFirestore.instance.collection('drivers').doc(_soforId)
          .update({'servisAktif': false, 'servisBitisZamani': FieldValue.serverTimestamp()});
      await _bildirimKaydet('Servis tamamlandi', 'servis_bitti');
      setState(() => _servisAktif = false);
      _snack('Servis tamamlandi!', _green);
    } catch (e) { _snack('Hata: $e', _red); }
  }

  // ── Navigasyon ────────────────────────────────────────────────
  Future<void> _navigasyonAc() async {
    final gelecekler = _ogrenciler
        .where((o) => !(o['bugunGelmeyecek'] as bool? ?? false))
        .toList();
    if (gelecekler.isEmpty) { _snack('Bugun gelecek ogrenci yok', _orange); return; }
    final ilk = gelecekler.first;
    final lat = ilk['konum']?['lat'] ?? ilk['lat'];
    final lng = ilk['konum']?['lng'] ?? ilk['lng'];
    if (lat != null && lng != null) {
      final url = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
      if (await canLaunchUrl(url)) await launchUrl(url);
    } else {
      _snack('Ogrenci konumu bulunamadi', _orange);
    }
  }

  // ── Bildirimler ───────────────────────────────────────────────
  Future<void> _yaklasiyorBildirimi() async {
    await _bildirimKaydet('Servis yaklasiyor', 'yaklasisyor');
    _snack('Yaklasiyor bildirimi gonderildi!', _green);
  }

  Future<void> _ogrenGeldiBildirimi(Map<String, dynamic> ogr) async {
    await _bildirimKaydet(
        '${ogr['ad']} alindi', 'ogrenci_alindi',
        ogrenciId: ogr['id']);
    // Ogrenciyi alindi olarak isaretleme
    await FirebaseFirestore.instance
        .collection('students').doc(ogr['id'])
        .update({'alindi': true, 'alinmaZamani': FieldValue.serverTimestamp()});
    setState(() => ogr['alindi'] = true);
    _snack('${ogr['ad']} alindi olarak isaretlendi', _green);
  }

  Future<void> _bildirimKaydet(String mesaj, String tip,
      {String? ogrenciId}) async {
    try {
      await FirebaseFirestore.instance.collection('bildirimler').add({
        'soforId'  : _soforId,
        'firmaId'  : _firmaId,
        'projeId'  : _aktifProje?['id'] ?? '',
        'ogrenciId': ogrenciId ?? '',
        'mesaj'    : mesaj,
        'tip'      : tip,
        'zaman'    : FieldValue.serverTimestamp(),
      });
    } catch (e) { debugPrint('Bildirim: $e'); }
  }

  // ── Konum Paylas ──────────────────────────────────────────────
  Future<void> _konumPaylas() async {
    _snack('Konum paylasimi mobil uygulamada aktif olur', _orange);
  }

  // ── Acil Durum ────────────────────────────────────────────────
  Future<void> _acilDurum() async {
    final onay = await _onayDialog('🚨 Acil Durum',
        'Acil durum bildirimi gonderilecek.\nFirma yoneticiniz aninda haberdar edilecek.',
        tehlikeli: true);
    if (!onay) return;
    try {
      await FirebaseFirestore.instance.collection('acil_durumlar').add({
        'soforId': _soforId, 'soforAd': _soforAd,
        'firmaId': _firmaId, 'projeId': _aktifProje?['id'] ?? '',
        'zaman'  : FieldValue.serverTimestamp(), 'durum': 'beklemede',
      });
      _snack('Acil durum bildirimi gonderildi!', _red);
    } catch (e) { _snack('Hata: $e', _red); }
  }

  // ── Yoklama ───────────────────────────────────────────────────
  void _yoklamaDialog() {
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            const Icon(Icons.fact_check_outlined, color: _navy),
            const SizedBox(width: 8),
            Text('Yoklama (${_ogrenciler.length} ogrenci)',
                style: const TextStyle(fontSize: 16)),
          ]),
          content: SizedBox(
            width: 360,
            child: _ogrenciler.isEmpty
                ? const Text('Ogrenci yok')
                : ListView.builder(
              shrinkWrap: true,
              itemCount: _ogrenciler.length,
              itemBuilder: (_, i) {
                final o = _ogrenciler[i];
                final alindi = o['alindi'] as bool? ?? false;
                final gelmeyecek = o['bugunGelmeyecek'] as bool? ?? false;
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: gelmeyecek
                        ? Colors.grey[200]
                        : alindi
                        ? _green.withValues(alpha: 0.1)
                        : _navy.withValues(alpha: 0.1),
                    child: Icon(
                      gelmeyecek ? Icons.close
                          : alindi ? Icons.check : Icons.person_outline,
                      size: 16,
                      color: gelmeyecek ? Colors.grey
                          : alindi ? _green : _navy,
                    ),
                  ),
                  title: Text(o['ad'] as String? ?? '',
                      style: TextStyle(
                          decoration: gelmeyecek
                              ? TextDecoration.lineThrough
                              : null,
                          color: gelmeyecek ? Colors.grey : null)),
                  subtitle: Text(
                    gelmeyecek ? 'Bugun gelmeyecek'
                        : alindi ? 'Alindi ✓' : 'Bekleniyor',
                    style: TextStyle(
                        fontSize: 11,
                        color: gelmeyecek ? Colors.grey
                            : alindi ? _green : Colors.orange),
                  ),
                  trailing: !gelmeyecek && !alindi
                      ? ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6))),
                    onPressed: () async {
                      await _ogrenGeldiBildirimi(o);
                      setD(() {});
                    },
                    child: const Text('Aldim', style: TextStyle(fontSize: 11)),
                  )
                      : null,
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('Kapat')),
          ],
        ),
      ),
    );
  }

  // ── Yardimcilar ───────────────────────────────────────────────
  Future<bool> _onayDialog(String baslik, String icerik,
      {bool tehlikeli = false}) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text(baslik),
        content: Text(icerik),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgec')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: tehlikeli ? _red : _navy,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tehlikeli ? 'Gonder' : 'Evet'),
          ),
        ],
      ),
    ) ??
        false;
  }

  void _snack(String msg, Color renk) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg), backgroundColor: renk,
        behavior: SnackBarBehavior.floating));
  }

  // ── UI ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return const Scaffold(
        backgroundColor: _navy,
        body: Center(child: CircularProgressIndicator(
            color: _orange, strokeWidth: 2.5)),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: _appBar(),
      body: _projeler.isEmpty ? _atanmamisEkran() : _anaIcerik(),
      bottomNavigationBar: _projeler.isEmpty ? null : _altMenu(),
    );
  }

  AppBar _appBar() => AppBar(
    backgroundColor: _navy,
    foregroundColor: Colors.white,
    elevation: 0,
    title: Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.directions_bus_outlined, size: 18),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_soforAd,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(_servisAktif ? '● Servis Aktif' : '○ Bekleniyor',
            style: TextStyle(fontSize: 11,
                color: _servisAktif ? Colors.greenAccent : Colors.white60)),
      ]),
    ]),
    actions: [
      // Yaklasiyor bildirimi
      if (_servisAktif)
        IconButton(
          icon: const Icon(Icons.notifications_active_outlined),
          tooltip: 'Yaklasiyor Bildirimi',
          onPressed: _yaklasiyorBildirimi,
        ),
      // Cikis
      IconButton(
        icon: const Icon(Icons.logout_outlined),
        tooltip: 'Cikis',
        onPressed: () async {
          await FirebaseAuth.instance.signOut();
          if (mounted) Navigator.pushReplacementNamed(context, '/login');
        },
      ),
    ],
  );

  BottomNavigationBar _altMenu() => BottomNavigationBar(
    currentIndex: _aktifTab,
    onTap: (i) { setState(() => _aktifTab = i); if (i==3) Navigator.pushNamed(context, '/harita', arguments: {'soforId': _soforId, 'firmaId': _firmaId}); if (i==4) Navigator.pushNamed(context, '/rotalar', arguments: {'soforId': _soforId}); },
    selectedItemColor: _navy,
    unselectedItemColor: Colors.grey,
    type: BottomNavigationBarType.fixed,
    items: const [
      BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Ana'),
      BottomNavigationBarItem(icon: Icon(Icons.school_outlined), label: 'Ogrenciler'),
      BottomNavigationBarItem(icon: Icon(Icons.fact_check_outlined), label: 'Yoklama'),
      BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Harita'),
      BottomNavigationBarItem(icon: Icon(Icons.route_outlined), label: 'Rota'),
    ],
  );

  // ── Atanmamis ─────────────────────────────────────────────────
  Widget _atanmamisEkran() => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.directions_bus_outlined, size: 80, color: Colors.grey[300]),
      const SizedBox(height: 16),
      const Text('Atanmis Servis Yok',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _navy)),
      const SizedBox(height: 8),
      const Text('Henuz size atanmis aktif servis bulunmuyor.\nFirma yoneticinizle iletisime gecin.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 14)),
    ]),
  );

  // ── Ana Icerik ────────────────────────────────────────────────
  Widget _anaIcerik() {
    switch (_aktifTab) {
      case 1: return _ogrencilerSekme();
      case 2:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _yoklamaDialog();
          setState(() => _aktifTab = 0);
        });
        return _anaSekme();
      default: return _anaSekme();
    }
  }

  Widget _anaSekme() => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      if (_projeler.length > 1) ...[_projeSecici(), const SizedBox(height: 12)],
      _anaButonlar(),
      const SizedBox(height: 16),
      if (_aktifProje != null) _projeKarti(),
      const SizedBox(height: 16),
      _ogrenciOzet(),
    ]),
  );

  // ── Proje Secici ──────────────────────────────────────────────
  Widget _projeSecici() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Proje Sec', style: TextStyle(
          fontWeight: FontWeight.bold, color: _navy, fontSize: 13)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8,
        children: _projeler.map((p) {
          final secili = _aktifProje?['id'] == p['id'];
          return GestureDetector(
            onTap: () async { setState(() => _aktifProje = p); await _ogrencileriYukle(); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: secili ? _navy : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8)),
              child: Text(p['projeAd'] ?? p['ad'] ?? 'Proje',
                  style: TextStyle(color: secili ? Colors.white : Colors.black87,
                      fontWeight: secili ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12)),
            ),
          );
        }).toList(),
      ),
    ]),
  );

  // ── Ana Butonlar ──────────────────────────────────────────────
  Widget _anaButonlar() => GridView.count(
    crossAxisCount: 2, shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisSpacing: 12, mainAxisSpacing: 12,
    childAspectRatio: 2.2,
    children: [
      _buyukButon(_servisAktif ? Icons.stop_circle_outlined : Icons.play_circle_outlined,
          _servisAktif ? 'Servisi Bitir' : 'Servisi Baslat',
          _servisAktif ? _red : _green,
          _servisAktif ? _servisBitir : _servisBaslat),
      _buyukButon(Icons.map_outlined, 'Navigasyon Ac', Colors.blue, _navigasyonAc),
      _buyukButon(Icons.fact_check_outlined, 'Yoklama Al', _navy, _yoklamaDialog),
      _buyukButon(Icons.emergency_outlined, 'Acil Durum', _red, _acilDurum),
    ],
  );

  Widget _buyukButon(IconData ikon, String etiket, Color renk, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(color: renk,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: renk.withValues(alpha: 0.3),
                  blurRadius: 8, offset: const Offset(0, 3))]),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(ikon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Flexible(child: Text(etiket,
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 13),
                overflow: TextOverflow.ellipsis)),
          ]),
        ),
      );

  // ── Proje Karti ───────────────────────────────────────────────
  Widget _projeKarti() {
    final p   = _aktifProje!;
    final bas = p['baslangicSaati'] as String? ?? '';
    final bit = p['bitisSaati']     as String? ?? '';
    final tip = p['servisTuru']     as String? ?? '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
      child: Row(children: [
        const Icon(Icons.folder_outlined, color: _navy, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p['projeAd'] ?? p['ad'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, color: _navy)),
          if (bas.isNotEmpty)
            Text('$tip  $bas — $bit',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          if (_sabahSaati.isNotEmpty || _aksamSaati.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [
              if (_sabahSaati.isNotEmpty) ...[
                const Icon(Icons.wb_sunny_outlined, size: 11, color: Colors.orange),
                const SizedBox(width: 3),
                Text(_sabahSaati, style: const TextStyle(fontSize: 11, color: Colors.orange)),
                const SizedBox(width: 10),
              ],
              if (_aksamSaati.isNotEmpty) ...[
                const Icon(Icons.nights_stay_outlined, size: 11, color: Colors.indigo),
                const SizedBox(width: 3),
                Text(_aksamSaati, style: const TextStyle(fontSize: 11, color: Colors.indigo)),
              ],
            ])),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: _servisAktif ? _green.withValues(alpha: 0.1) : Colors.grey[100],
              borderRadius: BorderRadius.circular(6)),
          child: Text(_servisAktif ? 'Aktif' : 'Bekliyor',
              style: TextStyle(fontSize: 11,
                  color: _servisAktif ? _green : Colors.grey,
                  fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  // ── Ogrenci Ozet ─────────────────────────────────────────────
  Widget _ogrenciOzet() {
    if (_ogrencilerYuk) return const Center(
        child: CircularProgressIndicator(color: _navy));
    final gelecek = _ogrenciler
        .where((o) => !(o['bugunGelmeyecek'] as bool? ?? false)).length;
    final alindi  = _ogrenciler
        .where((o) => o['alindi'] as bool? ?? false).length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)]),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.school_outlined, color: _navy, size: 18),
          const SizedBox(width: 8),
          const Text('Ogrenci Durumu',
              style: TextStyle(fontWeight: FontWeight.bold, color: _navy)),
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _miniStat('Toplam', '${_ogrenciler.length}', Colors.blue),
          _miniStat('Gelecek', '$gelecek', _green),
          _miniStat('Alindi', '$alindi', _orange),
          _miniStat('Gelmeyecek',
              '${_ogrenciler.length - gelecek}', _red),
        ]),
      ]),
    );
  }

  Widget _miniStat(String label, String deger, Color renk) => Column(children: [
    Text(deger, style: TextStyle(
        fontSize: 22, fontWeight: FontWeight.bold, color: renk)),
    Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
  ]);

  // ── Ogrenciler Sekmesi ────────────────────────────────────────
  Widget _ogrencilerSekme() {
    if (_ogrencilerYuk) return const Center(
        child: CircularProgressIndicator(color: _navy));
    if (_ogrenciler.isEmpty) return const Center(
        child: Text('Bu projeye kayitli ogrenci yok',
            style: TextStyle(color: Colors.grey)));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _ogrenciler.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _ogrenciKarti(_ogrenciler[i]),
    );
  }

  Widget _ogrenciKarti(Map<String, dynamic> o) {
    final ad        = o['ad']      as String? ?? '';
    final gelecek   = !(o['bugunGelmeyecek'] as bool? ?? false);
    final alindi    = o['alindi']  as bool?   ?? false;
    final tel       = o['veliTelefon'] as String? ?? o['anneTelefon'] as String? ?? '';
    final adres     = o['sabahAdres']  as String? ?? o['adres']       as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)]),
      child: Row(children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: !gelecek ? Colors.grey[200]
              : alindi ? _green.withValues(alpha: 0.1)
              : _navy.withValues(alpha: 0.1),
          child: Text(ad.isNotEmpty ? ad[0].toUpperCase() : '?',
              style: TextStyle(
                  color: !gelecek ? Colors.grey : alindi ? _green : _navy,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ad, style: TextStyle(
              fontWeight: FontWeight.bold,
              decoration: gelecek ? null : TextDecoration.lineThrough,
              color: gelecek ? Colors.black87 : Colors.grey)),
          if (adres.isNotEmpty)
            Text(adres, style: const TextStyle(fontSize: 11, color: Colors.grey),
                overflow: TextOverflow.ellipsis),
          Text(!gelecek ? 'Bugun gelmeyecek'
              : alindi ? '✓ Alindi' : 'Bekleniyor',
              style: TextStyle(fontSize: 11,
                  color: !gelecek ? Colors.grey
                      : alindi ? _green : Colors.orange,
                  fontWeight: FontWeight.w500)),
        ])),
        Column(children: [
          if (tel.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.phone_outlined, color: _navy, size: 20),
              onPressed: () async {
                final url = Uri.parse('tel:$tel');
                if (await canLaunchUrl(url)) await launchUrl(url);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          if (gelecek && !alindi)
            TextButton(
              onPressed: () => _ogrenGeldiBildirimi(o),
              style: TextButton.styleFrom(
                  foregroundColor: _green,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: const Text('Aldim', style: TextStyle(fontSize: 11)),
            ),
        ]),
      ]),
    );
  }
}
