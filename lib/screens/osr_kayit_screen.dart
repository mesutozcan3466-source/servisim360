import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:io';

class OcrKayitScreen extends StatefulWidget {
  const OcrKayitScreen({super.key});

  @override
  State<OcrKayitScreen> createState() => _OcrKayitScreenState();
}

class _OcrKayitScreenState extends State<OcrKayitScreen>
    with SingleTickerProviderStateMixin {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  final _db = FirebaseFirestore.instance;
  late final TabController _tabCtrl;

  final _textRecognizer =
  TextRecognizer(script: TextRecognitionScript.latin);

  bool _ocrYukleniyor = false;
  bool _dosyaYukleniyor = false;
  bool _kaydediliyor  = false;

  final List<Map<String, dynamic>> _ogrenciler = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════
  //  OCR — file_picker ile görsel seçimi (jpg, png)
  // ════════════════════════════════════════════════════════════════
  Future<void> _gorselSec() async {
    setState(() => _ocrYukleniyor = true);
    try {
      final sonuc = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
        withData: false,
      );
      if (sonuc == null || sonuc.files.isEmpty) return;

      final dosyaYolu = sonuc.files.first.path;
      if (dosyaYolu == null) {
        _snackbar('Dosya yolu alinamadi.', renk: Colors.orange);
        return;
      }

      final inputImage = InputImage.fromFilePath(dosyaYolu);
      final recognised =
      await _textRecognizer.processImage(inputImage);

      final ogrenci = _ocrMetniParsele(recognised.text);
      if (ogrenci != null) {
        await _koordinatEkle(ogrenci);
        setState(() => _ogrenciler.add(ogrenci));
        _snackbar('OCR tamamlandi — ${ogrenci['ad']}',
            renk: Colors.green);
      } else {
        _snackbar(
          'Metin okunamadi.\n'
              'Fotografta Ad, Adres, Sinif satirlari olmali.',
          renk: Colors.orange,
        );
      }
    } catch (e) {
      _snackbar('OCR hatasi: $e', renk: Colors.red);
    } finally {
      if (mounted) setState(() => _ocrYukleniyor = false);
    }
  }

  // ─── OCR metni → ogrenci map ──────────────────────────────────
  Map<String, dynamic>? _ocrMetniParsele(String metin) {
    final satirlar = metin
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (satirlar.isEmpty) return null;

    String ad = '', adres = '', sinif = '', telefon = '';

    for (final satir in satirlar) {
      final lower = satir.toLowerCase();
      if (ad.isEmpty && !lower.contains(':')) {
        ad = satir;
      } else if (lower.startsWith('adres')) {
        adres = satir.replaceFirst(
            RegExp(r'adres\s*:\s*', caseSensitive: false), '');
      } else if (lower.startsWith('sinif') ||
          lower.startsWith('s') && lower.contains('n') && lower.contains('f')) {
        sinif = satir.replaceFirst(
            RegExp(r'\w+\s*:\s*', caseSensitive: false), '');
      } else if (lower.startsWith('tel') || lower.startsWith('gsm')) {
        telefon = satir.replaceFirst(
            RegExp(r'(tel|gsm|telefon)\s*:\s*', caseSensitive: false), '');
      }
    }

    if (ad.isEmpty) return null;
    return {
      'ad': ad, 'adres': adres, 'sinif': sinif,
      'telefon': telefon, 'konum': null, 'kaynak': 'ocr',
    };
  }

  // ════════════════════════════════════════════════════════════════
  //  DOSYA YUKLE — PDF veya TXT
  // ════════════════════════════════════════════════════════════════
  Future<void> _dosyaYukle() async {
    setState(() => _dosyaYukleniyor = true);
    try {
      final sonuc = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt'],
        withData: true,
      );
      if (sonuc == null || sonuc.files.isEmpty) return;

      final dosya = sonuc.files.first;
      String metin = '';

      if (dosya.extension?.toLowerCase() == 'txt') {
        if (dosya.path != null) {
          metin = File(dosya.path!).readAsStringSync();
        } else if (dosya.bytes != null) {
          metin = String.fromCharCodes(dosya.bytes!);
        }
      } else {
        // PDF — text layer
        final bytes = dosya.bytes ??
            (dosya.path != null
                ? File(dosya.path!).readAsBytesSync()
                : null);
        if (bytes != null) metin = _pdfBytesdenMetin(bytes);
      }

      if (metin.trim().isEmpty) {
        _snackbar(
          'Dosyadan metin alinamadi.\n'
              'TXT formatini deneyin.',
          renk: Colors.orange,
        );
        return;
      }

      final liste = _metniParsele(metin);
      if (liste.isEmpty) {
        _snackbar('Ogrenci bilgisi okunamadi.', renk: Colors.orange);
        return;
      }

      for (final ogr in liste) {
        await _koordinatEkle(ogr);
      }

      setState(() => _ogrenciler.addAll(liste));
      _snackbar('${liste.length} ogrenci okundu.', renk: Colors.green);
    } catch (e) {
      _snackbar('Dosya okuma hatasi: $e', renk: Colors.red);
    } finally {
      if (mounted) setState(() => _dosyaYukleniyor = false);
    }
  }

  String _pdfBytesdenMetin(List<int> bytes) {
    try {
      final str = String.fromCharCodes(
          bytes.where((b) => b >= 32 && b < 127).toList());
      final satirlar = <String>[];
      final pattern = RegExp(r'\(([^\)]{2,80})\)');
      for (final m in pattern.allMatches(str)) {
        final s = m.group(1)?.trim() ?? '';
        if (s.length > 1) satirlar.add(s);
      }
      return satirlar.join('\n');
    } catch (_) {
      return '';
    }
  }

  List<Map<String, dynamic>> _metniParsele(String metin) {
    final liste   = <Map<String, dynamic>>[];
    final satirlar = metin
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Format 1: pipe  →  Ad | Sinif | Adres | Tel
    final pipeSatirlari =
    satirlar.where((s) => s.contains('|')).toList();
    if (pipeSatirlari.isNotEmpty) {
      for (final satir in pipeSatirlari) {
        final p = satir.split('|').map((s) => s.trim()).toList();
        if (p.isNotEmpty && p[0].isNotEmpty) {
          liste.add({
            'ad':      p[0],
            'sinif':   p.length > 1 ? p[1] : '',
            'adres':   p.length > 2 ? p[2] : '',
            'telefon': p.length > 3 ? p[3] : '',
            'konum':   null,
            'kaynak':  'dosya',
          });
        }
      }
      return liste;
    }

    // Format 2: numarali liste  →  1. Ad\nAdres: ...\nSinif: ...
    Map<String, dynamic>? mevcut;
    for (final satir in satirlar) {
      final lower = satir.toLowerCase();
      if (RegExp(r'^\d+[.)]\s').hasMatch(satir)) {
        if (mevcut != null &&
            (mevcut['ad'] as String).isNotEmpty) liste.add(mevcut);
        mevcut = {
          'ad':      satir.replaceFirst(RegExp(r'^\d+[.)]\s*'), ''),
          'adres':   '', 'sinif': '', 'telefon': '',
          'konum':   null, 'kaynak': 'dosya',
        };
        continue;
      }
      if (mevcut == null) continue;
      if (lower.startsWith('adres')) {
        mevcut['adres'] = satir.replaceFirst(
            RegExp(r'adres\s*:\s*', caseSensitive: false), '');
      } else if (lower.startsWith('sin')) {
        mevcut['sinif'] = satir.replaceFirst(
            RegExp(r'\w+\s*:\s*', caseSensitive: false), '');
      } else if (lower.startsWith('tel') || lower.startsWith('gsm')) {
        mevcut['telefon'] = satir.replaceFirst(
            RegExp(r'(tel|gsm)\s*:\s*', caseSensitive: false), '');
      }
    }
    if (mevcut != null && (mevcut['ad'] as String).isNotEmpty) {
      liste.add(mevcut);
    }

    return liste;
  }

  // ════════════════════════════════════════════════════════════════
  //  Geocoding
  // ════════════════════════════════════════════════════════════════
  Future<void> _koordinatEkle(Map<String, dynamic> ogr) async {
    final adres = ogr['adres'] as String? ?? '';
    if (adres.isEmpty) return;
    try {
      final locs = await locationFromAddress('$adres, Ankara, Turkey');
      if (locs.isNotEmpty) {
        ogr['konum'] =
            GeoPoint(locs.first.latitude, locs.first.longitude);
      }
    } catch (_) {}
  }

  // ════════════════════════════════════════════════════════════════
  //  Toplu Firestore kayit
  // ════════════════════════════════════════════════════════════════
  Future<void> _topluKaydet() async {
    if (_ogrenciler.isEmpty) return;
    setState(() => _kaydediliyor = true);
    try {
      final user  = FirebaseAuth.instance.currentUser;
      final batch = _db.batch();

      for (final ogr in _ogrenciler) {
        final ref = _db.collection('ogrenciler').doc();
        batch.set(ref, {
          'ad':          ogr['ad']      ?? '',
          'adres':       ogr['adres']   ?? '',
          'sinif':       ogr['sinif']   ?? '',
          'telefon':     ogr['telefon'] ?? '',
          'konum':       ogr['konum'],
          'servisId':    null,
          'veliId':      null,
          'alindi':      false,
          'kaynak':      ogr['kaynak']  ?? 'manuel',
          'firmaId':     user?.uid ?? '',
          'kayitTarihi': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      setState(() => _ogrenciler.clear());
      _snackbar('Tum ogrenciler kaydedildi.', renk: Colors.green);
    } catch (e) {
      _snackbar('Toplu kayit hatasi: $e', renk: Colors.red);
    } finally {
      if (mounted) setState(() => _kaydediliyor = false);
    }
  }

  void _snackbar(String mesaj, {Color renk = Colors.green}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(mesaj),
      backgroundColor: renk,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Toplu Ogrenci Kaydi',
            style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: _turuncu,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.document_scanner_outlined, size: 20),
                text: 'OCR Gorsel'),
            Tab(icon: Icon(Icons.upload_file_outlined, size: 20),
                text: 'Dosya Yukle'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ─ Tab giris alanlari ─
          SizedBox(
            height: 175,
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _OcrPanel(
                  yukleniyor: _ocrYukleniyor,
                  onGorselSec: _gorselSec,
                ),
                _DosyaPanel(
                  yukleniyor: _dosyaYukleniyor,
                  onYukle: _dosyaYukle,
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 0.5),

          // ─ Liste basligi ─
          if (_ogrenciler.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Text('${_ogrenciler.length} ogrenci hazir',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _navy, fontSize: 14)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _ogrenciler.clear()),
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red, size: 16),
                    label: const Text('Temizle',
                        style: TextStyle(
                            color: Colors.red, fontSize: 12)),
                  ),
                ],
              ),
            ),

          // ─ Liste ─
          Expanded(
            child: _ogrenciler.isEmpty
                ? _BosEkran()
                : ListView.builder(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              itemCount: _ogrenciler.length,
              itemBuilder: (_, i) => _OgrenciKarti(
                ogrenci: _ogrenciler[i],
                index: i,
                onSil: () =>
                    setState(() => _ogrenciler.removeAt(i)),
                onGuncelle: (g) =>
                    setState(() => _ogrenciler[i] = g),
              ),
            ),
          ),

          // ─ Kaydet butonu ─
          if (_ogrenciler.isNotEmpty)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _kaydediliyor ? null : _topluKaydet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: _kaydediliyor
                        ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save_outlined, size: 20),
                    label: Text(
                      _kaydediliyor
                          ? 'Kaydediliyor...'
                          : '${_ogrenciler.length} Ogrenciyi Kaydet',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  OCR PANELİ
// ════════════════════════════════════════════════════════════════
class _OcrPanel extends StatelessWidget {
  final bool yukleniyor;
  final VoidCallback onGorselSec;

  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  const _OcrPanel({
    required this.yukleniyor,
    required this.onGorselSec,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: yukleniyor
          ? const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: _navy),
              SizedBox(height: 10),
              Text('Gorsel okunuyor...',
                  style: TextStyle(color: Colors.grey)),
            ],
          ))
          : Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Ogrenci belge fotografini secin\n'
                '(JPG veya PNG)',
            style: TextStyle(
                color: Colors.grey[500], fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onGorselSec,
              icon: const Icon(
                  Icons.photo_library_outlined, size: 20),
              label: const Text('Gorsel Sec (JPG / PNG)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _navy,
                side: const BorderSide(color: _navy),
                padding:
                const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Belgede "Ad:", "Adres:", "Sinif:" satirlari olmali',
            style: TextStyle(
                color: Colors.grey[400], fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  DOSYA PANELİ
// ════════════════════════════════════════════════════════════════
class _DosyaPanel extends StatelessWidget {
  final bool yukleniyor;
  final VoidCallback onYukle;

  static const _navy = Color(0xFF1a3a6b);

  const _DosyaPanel({
    required this.yukleniyor,
    required this.onYukle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: yukleniyor
          ? const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: _navy),
              SizedBox(height: 10),
              Text('Dosya okunuyor...',
                  style: TextStyle(color: Colors.grey)),
            ],
          ))
          : Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Desteklenen format:\n'
                'Ad | Sinif | Adres | Tel  (pipe ile)\n'
                'veya numarali liste: 1. Ad',
            style: TextStyle(
                color: Colors.grey[500], fontSize: 11),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onYukle,
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                padding:
                const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(
                  Icons.upload_file_outlined, size: 20),
              label: const Text('PDF veya TXT Sec',
                  style:
                  TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  OGRENCI KARTI
// ════════════════════════════════════════════════════════════════
class _OgrenciKarti extends StatefulWidget {
  final Map<String, dynamic> ogrenci;
  final int index;
  final VoidCallback onSil;
  final void Function(Map<String, dynamic>) onGuncelle;

  const _OgrenciKarti({
    required this.ogrenci,
    required this.index,
    required this.onSil,
    required this.onGuncelle,
  });

  @override
  State<_OgrenciKarti> createState() => _OgrenciKartiState();
}

class _OgrenciKartiState extends State<_OgrenciKarti> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  bool _duzenle = false;
  late final TextEditingController _adCtrl;
  late final TextEditingController _sinifCtrl;
  late final TextEditingController _adresCtrl;
  late final TextEditingController _telefonCtrl;

  @override
  void initState() {
    super.initState();
    _adCtrl      = TextEditingController(
        text: widget.ogrenci['ad']      ?? '');
    _sinifCtrl   = TextEditingController(
        text: widget.ogrenci['sinif']   ?? '');
    _adresCtrl   = TextEditingController(
        text: widget.ogrenci['adres']   ?? '');
    _telefonCtrl = TextEditingController(
        text: widget.ogrenci['telefon'] ?? '');
  }

  @override
  void dispose() {
    _adCtrl.dispose();
    _sinifCtrl.dispose();
    _adresCtrl.dispose();
    _telefonCtrl.dispose();
    super.dispose();
  }

  void _kaydet() {
    widget.onGuncelle(Map<String, dynamic>.from(widget.ogrenci)
      ..['ad']      = _adCtrl.text.trim()
      ..['sinif']   = _sinifCtrl.text.trim()
      ..['adres']   = _adresCtrl.text.trim()
      ..['telefon'] = _telefonCtrl.text.trim());
    setState(() => _duzenle = false);
  }

  @override
  Widget build(BuildContext context) {
    final konum   = widget.ogrenci['konum'] as GeoPoint?;
    final kaynak  = widget.ogrenci['kaynak'] ?? 'manuel';
    final kaynakRenk =
    kaynak == 'dosya' ? Colors.purple : _turuncu;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _navy.withValues(alpha: 0.1),
                  child: Text('${widget.index + 1}',
                      style: const TextStyle(
                          color: _navy,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.ogrenci['ad'] ?? 'Ogrenci',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                              kaynakRenk.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(kaynak.toUpperCase(),
                                style: TextStyle(
                                    color: kaynakRenk,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                          ),
                          if (konum != null) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.location_on,
                                size: 12, color: Colors.green),
                            const Text(' Konum var',
                                style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 10)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _duzenle ? Icons.check : Icons.edit_outlined,
                    color: _duzenle ? Colors.green : Colors.grey,
                    size: 18,
                  ),
                  splashRadius: 18,
                  onPressed: _duzenle
                      ? _kaydet
                      : () => setState(() => _duzenle = true),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 18),
                  splashRadius: 18,
                  onPressed: widget.onSil,
                ),
              ],
            ),

            // Duzenle alanlari
            if (_duzenle) ...[
              const SizedBox(height: 10),
              _alan(_adCtrl,      'Ad Soyad',  Icons.person_outline),
              const SizedBox(height: 8),
              _alan(_sinifCtrl,   'Sinif',     Icons.class_outlined),
              const SizedBox(height: 8),
              _alan(_adresCtrl,   'Adres',     Icons.home_outlined),
              const SizedBox(height: 8),
              _alan(_telefonCtrl, 'Telefon',   Icons.phone_outlined,
                  tipi: TextInputType.phone),
            ] else if ((widget.ogrenci['adres'] as String? ?? '')
                .isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.home_outlined,
                      size: 13, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(widget.ogrenci['adres'] ?? '',
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  if ((widget.ogrenci['sinif'] as String? ?? '')
                      .isNotEmpty)
                    Text('  ${widget.ogrenci['sinif']}',
                        style: const TextStyle(
                            color: _navy,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _alan(TextEditingController ctrl, String label,
      IconData icon, {TextInputType? tipi}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: tipi,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
        prefixIcon: Icon(icon, size: 17, color: Colors.grey[400]),
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[200]!)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey[200]!)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(
                color: Color(0xFF1a3a6b), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 10),
        isDense: true,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  BOS EKRAN
// ════════════════════════════════════════════════════════════════
class _BosEkran extends StatelessWidget {
  static const _navy = Color(0xFF1a3a6b);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.upload_file_outlined,
                size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('Henuz ogrenci eklenmedi',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _navy, fontSize: 15)),
            const SizedBox(height: 8),
            Text(
              'Gorsel tarayin veya\n'
                  'PDF / TXT dosyasi yukleyin.',
              style: TextStyle(
                  color: Colors.grey[500], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
