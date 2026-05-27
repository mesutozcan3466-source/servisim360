import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../services/session_service.dart';

// ════════════════════════════════════════════════════════════════
//  TOPLU YUKLE EKRANI
//  Tip: ogrenci | sofor
//  Yontem: CSV | PDF (tarama) | Kamera
// ════════════════════════════════════════════════════════════════
class TopluYukleScreen extends StatefulWidget {
  const TopluYukleScreen({super.key});
  @override
  State<TopluYukleScreen> createState() => _TopluYukleScreenState();
}

class _TopluYukleScreenState extends State<TopluYukleScreen> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  String  _firmaId    = '';
  bool    _yukleniyor = true;
  bool    _isleniyor  = false;
  String  _tip        = '';       // 'ogrenci' | 'sofor'
  String  _yontem     = '';       // 'csv' | 'kamera'
  List<Map<String, dynamic>> _onizleme = [];
  String? _hata;
  int     _yuklenenSayisi = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final fId = await SessionService.instance.firmaldAl();
    if (mounted) setState(() { _firmaId = fId ?? ''; _yukleniyor = false; });
  }

  // ── CSV seç ve işle ─────────────────────────────────────────
  Future<void> _csvSec() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );
      if (result == null || result.files.isEmpty) return;
      final file = File(result.files.first.path!);
      final lines = await file.readAsLines();
      _csvIsle(lines);
    } catch (e) {
      setState(() => _hata = 'Dosya okuma hatasi: $e');
    }
  }

  void _csvIsle(List<String> lines) {
    final liste = <Map<String, dynamic>>[];
    setState(() => _hata = null);

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final cols = line.split(',');

      if (_tip == 'ogrenci' && cols.length >= 2) {
        liste.add({
          'ad':      cols[0].trim(),
          'soyad':   cols.length > 1 ? cols[1].trim() : '',
          'tc':      cols.length > 2 ? cols[2].trim() : '',
          'anneAd':  cols.length > 3 ? cols[3].trim() : '',
          'anneTel': cols.length > 4 ? cols[4].trim() : '',
          'babaAd':  cols.length > 5 ? cols[5].trim() : '',
          'babaTel': cols.length > 6 ? cols[6].trim() : '',
          'adres':   cols.length > 7 ? cols[7].trim() : '',
        });
      } else if (_tip == 'sofor' && cols.length >= 2) {
        liste.add({
          'ad':       cols[0].trim(),
          'soyad':    cols.length > 1 ? cols[1].trim() : '',
          'telefon':  cols.length > 2 ? cols[2].trim() : '',
          'aracPlaka':cols.length > 3 ? cols[3].trim() : '',
          'email':    cols.length > 4 ? cols[4].trim() : '',
        });
      }
    }

    setState(() => _onizleme = liste);
    if (liste.isEmpty) {
      setState(() => _hata = 'Gecerli veri bulunamadi. CSV formatini kontrol edin.');
    }
  }

  // ── Kamera ile manuel ekle ───────────────────────────────────
  Future<void> _kameraIleEkle() async {
    // Manuel giriş dialog aç
    _manuelEkleDialog();
  }

  void _manuelEkleDialog() {
    final ad     = TextEditingController();
    final soyad  = TextEditingController();
    final tel    = TextEditingController();
    final extra  = TextEditingController(); // TC veya plaka

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) => Container(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              _tip == 'ogrenci' ? 'Ogrenci Ekle' : 'Sofor Ekle',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: _navy),
            ),
            const SizedBox(height: 16),
            _Alan(ad,    'Ad *',          Icons.person_outline),
            const SizedBox(height: 10),
            _Alan(soyad, 'Soyad *',       Icons.person_outline),
            const SizedBox(height: 10),
            _Alan(tel,   'Telefon',       Icons.phone_outlined,
                tip: TextInputType.phone),
            const SizedBox(height: 10),
            _Alan(extra,
              _tip == 'ogrenci' ? 'TC Kimlik No' : 'Arac Plakasi',
              _tip == 'ogrenci' ? Icons.badge_outlined : Icons.directions_car_outlined,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _turuncu,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  if (ad.text.trim().isEmpty) return;
                  final kayit = _tip == 'ogrenci'
                      ? {'ad': ad.text.trim(), 'soyad': soyad.text.trim(),
                    'tc': extra.text.trim(), 'anneTel': tel.text.trim()}
                      : {'ad': ad.text.trim(), 'soyad': soyad.text.trim(),
                    'telefon': tel.text.trim(), 'aracPlaka': extra.text.trim()};
                  setState(() => _onizleme.add(kayit));
                  Navigator.pop(ctx);
                },
                child: const Text('Listeye Ekle',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Firestore'a yükle ────────────────────────────────────────
  Future<void> _yukle() async {
    if (_firmaId.isEmpty || _onizleme.isEmpty) return;
    setState(() { _isleniyor = true; _hata = null; });

    try {
      final koleksiyon = _tip == 'ogrenci' ? 'students' : 'drivers';
      final batch = FirebaseFirestore.instance.batch();
      int sayac = 0;

      for (final veri in _onizleme) {
        final ref = FirebaseFirestore.instance.collection(koleksiyon).doc();
        batch.set(ref, {
          ...veri,
          'firmaId':     _firmaId,
          'durum':       'aktif',
          'kayitTarihi': FieldValue.serverTimestamp(),
          'topluYukleme': true,
        });
        sayac++;
        // Firestore batch max 500
        if (sayac % 499 == 0) await batch.commit();
      }
      await batch.commit();

      if (mounted) {
        setState(() {
          _yuklenenSayisi = _onizleme.length;
          _onizleme = [];
          _isleniyor = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$_yuklenenSayisi kayit basariyla yuklendi!'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) setState(() {
        _isleniyor = false;
        _hata = 'Yukleme hatasi: $e';
      });
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return const Scaffold(
        backgroundColor: _navy,
        body: Center(child: CircularProgressIndicator(color: _turuncu)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white, elevation: 0,
        title: const Text('Toplu Yukle',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── ADIM 1: Tip seç ──────────────────────────────────
          _AdimBaslik('1. Ne yuklemek istiyorsunuz?'),
          const SizedBox(height: 12),
          Row(children: [
            _TipButonu(
              deger: 'ogrenci', secili: _tip,
              metin: 'Ogrenci', ikon: Icons.school_outlined,
              renk: Colors.blue,
              onTap: () => setState(() { _tip = 'ogrenci'; _onizleme = []; _yontem = ''; }),
            ),
            const SizedBox(width: 12),
            _TipButonu(
              deger: 'sofor', secili: _tip,
              metin: 'Sofor', ikon: Icons.drive_eta_outlined,
              renk: Colors.green,
              onTap: () => setState(() { _tip = 'sofor'; _onizleme = []; _yontem = ''; }),
            ),
          ]),

          if (_tip.isNotEmpty) ...[
            const SizedBox(height: 20),

            // ── ADIM 2: Yöntem seç ───────────────────────────
            _AdimBaslik('2. Nasıl yuklemek istiyorsunuz?'),
            const SizedBox(height: 12),

            // CSV butonu
            _YontemButon(
              ikon: Icons.table_chart_outlined,
              baslik: 'Excel / CSV Dosyasi',
              aciklama: 'Hazirladiginiz CSV dosyasini yukleyin',
              renk: Colors.teal,
              secili: _yontem == 'csv',
              onTap: () {
                setState(() => _yontem = 'csv');
                _csvSec();
              },
            ),
            const SizedBox(height: 10),

            // Manuel kamera
            _YontemButon(
              ikon: Icons.add_circle_outline,
              baslik: 'Manuel Ekle',
              aciklama: 'Tek tek form doldurarak listeye ekle',
              renk: Colors.orange,
              secili: _yontem == 'kamera',
              onTap: () {
                setState(() => _yontem = 'kamera');
                _kameraIleEkle();
              },
            ),

            // CSV format bilgisi
            if (_yontem == 'csv') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _navy.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _navy.withValues(alpha: 0.15)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Row(children: [
                    Icon(Icons.info_outline, color: _navy, size: 15),
                    SizedBox(width: 6),
                    Text('CSV Kolon Sirasi',
                        style: TextStyle(fontWeight: FontWeight.bold,
                            color: _navy, fontSize: 12)),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    _tip == 'ogrenci'
                        ? 'Ad, Soyad, TC, AnneAd, AnneTel, BabaAd, BabaTel, Adres\n\n'
                        'Ornek:\nAhmet, Yilmaz, 12345678901, Fatma Yilmaz, 5551234567, Ali Yilmaz, 5557654321, Istanbul'
                        : 'Ad, Soyad, Telefon, AracPlaka, Email\n\n'
                        'Ornek:\nMehmet, Kaya, 5559876543, 34ABC123, mehmet@mail.com',
                    style: const TextStyle(
                        fontSize: 11, fontFamily: 'monospace', color: _navy, height: 1.5),
                  ),
                ]),
              ),
            ],
          ],

          // ── Hata ─────────────────────────────────────────────
          if (_hata != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_hata!,
                    style: const TextStyle(color: Colors.red, fontSize: 13))),
              ]),
            ),
          ],

          // ── Önizleme ─────────────────────────────────────────
          if (_onizleme.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                const Icon(Icons.list_alt, color: _navy, size: 18),
                const SizedBox(width: 6),
                Text('${_onizleme.length} kayit hazir',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: _navy, fontSize: 14)),
              ]),
              Row(children: [
                TextButton.icon(
                  onPressed: _kameraIleEkle,
                  icon: const Icon(Icons.add, size: 16, color: _turuncu),
                  label: const Text('Ekle', style: TextStyle(color: _turuncu, fontSize: 12)),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _onizleme = []),
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                  label: const Text('Temizle', style: TextStyle(color: Colors.red, fontSize: 12)),
                ),
              ]),
            ]),
            const SizedBox(height: 8),

            // Liste önizleme
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
              ),
              child: Column(
                children: _onizleme.asMap().entries.take(10).map((e) {
                  final i = e.key;
                  final v = e.value;
                  final ad = '${v['ad'] ?? ''} ${v['soyad'] ?? ''}'.trim();
                  final alt = _tip == 'ogrenci'
                      ? (v['anneTel'] ?? v['tc'] ?? '')
                      : (v['telefon'] ?? v['aracPlaka'] ?? '');
                  return Container(
                    decoration: BoxDecoration(
                      border: i > 0
                          ? Border(top: BorderSide(
                          color: Colors.grey.withValues(alpha: 0.1)))
                          : null,
                    ),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: _navy.withValues(alpha: 0.1),
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                color: _navy, fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                      title: Text(ad.isNotEmpty ? ad : 'Isimsiz',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text(alt.toString(),
                          style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 16, color: Colors.red),
                        onPressed: () => setState(() => _onizleme.removeAt(i)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            if (_onizleme.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '... ve ${_onizleme.length - 10} kayit daha',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ),

            const SizedBox(height: 16),

            // Yükle butonu
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 3,
                ),
                onPressed: _isleniyor ? null : _yukle,
                icon: _isleniyor
                    ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text(
                  _isleniyor
                      ? 'Yukleniyor...'
                      : '${_onizleme.length} Kaydi Firestore\'a Yukle',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],

          const SizedBox(height: 80),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  ORTAK WİDGETLAR
// ════════════════════════════════════════════════════════════════
class _AdimBaslik extends StatelessWidget {
  final String metin;
  const _AdimBaslik(this.metin);
  @override
  Widget build(BuildContext context) => Text(metin,
      style: const TextStyle(
          fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1a3a6b)));
}

class _TipButonu extends StatelessWidget {
  final String deger, secili, metin;
  final IconData ikon;
  final Color renk;
  final VoidCallback onTap;
  const _TipButonu({
    required this.deger, required this.secili, required this.metin,
    required this.ikon, required this.renk, required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final aktif = secili == deger;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: aktif ? renk : renk.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: aktif ? renk : renk.withValues(alpha: 0.2), width: 2),
            boxShadow: aktif ? [BoxShadow(
                color: renk.withValues(alpha: 0.3), blurRadius: 8,
                offset: const Offset(0, 3))] : [],
          ),
          child: Column(children: [
            Icon(ikon, color: aktif ? Colors.white : renk, size: 28),
            const SizedBox(height: 6),
            Text(metin, style: TextStyle(
                color: aktif ? Colors.white : renk,
                fontWeight: FontWeight.bold, fontSize: 13)),
          ]),
        ),
      ),
    );
  }
}

class _YontemButon extends StatelessWidget {
  final IconData ikon;
  final String baslik, aciklama;
  final Color renk;
  final bool secili;
  final VoidCallback onTap;
  const _YontemButon({
    required this.ikon, required this.baslik, required this.aciklama,
    required this.renk, required this.secili, required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: secili ? renk.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: secili ? renk : Colors.grey.withValues(alpha: 0.2),
            width: secili ? 2 : 1),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: renk.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(ikon, color: renk, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(baslik, style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13,
              color: secili ? renk : Colors.black87)),
          Text(aciklama, style: TextStyle(
              fontSize: 11, color: Colors.grey[500])),
        ])),
        Icon(secili ? Icons.check_circle : Icons.chevron_right,
            color: secili ? renk : Colors.grey[300], size: 20),
      ]),
    ),
  );
}

Widget _Alan(TextEditingController ctrl, String label, IconData ikon,
    {TextInputType tip = TextInputType.text}) =>
    TextField(
      controller: ctrl, keyboardType: tip,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(ikon, color: const Color(0xFF1a3a6b), size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
        filled: true, fillColor: const Color(0xFFF8F9FA),
      ),
    );
