// ╔══════════════════════════════════════════════════════════════╗
// ║  DOSYA: lib/screens/dijital_imza_screen.dart
// ║  Dijital İmza — Canvas çizim + yazılı imza + IP/cihaz kayıt
// ╚══════════════════════════════════════════════════════════════╝
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'yardim_widget.dart';
import 'package:flutter/rendering.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class DijitalImzaScreen extends StatefulWidget {
  final String sozlesmeId;
  final String veliAd;
  final Function(Map<String, dynamic>) onImzaTamamlandi;

  const DijitalImzaScreen({
    super.key,
    required this.sozlesmeId,
    required this.veliAd,
    required this.onImzaTamamlandi,
  });

  @override
  State<DijitalImzaScreen> createState() => _DijitalImzaScreenState();
}

class _DijitalImzaScreenState extends State<DijitalImzaScreen>
    with SingleTickerProviderStateMixin {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  late TabController _tab;

  // Canvas imza
  final List<List<Offset?>> _imzaCizgiler = [];
  List<Offset?> _mevcutCizgi = [];
  final _imzaKey = GlobalKey();
  bool _imzaVar = false;

  // Yazılı imza
  final _adSoyadCtrl = TextEditingController();
  bool _yaziliImzaOnay = false;

  // Durum
  bool _kaydediliyor = false;
  String _cihazBilgisi = '';
  String _tarihSaat = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _bilgileriYukle();
  }

  @override
  void dispose() {
    _tab.dispose();
    _adSoyadCtrl.dispose();
    super.dispose();
  }

  Future<void> _bilgileriYukle() async {
    final now = DateTime.now();
    _tarihSaat = '${now.day}.${now.month}.${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    try {
      final info = DeviceInfoPlugin();
      if (kIsWeb) {
        final web = await info.webBrowserInfo;
        _cihazBilgisi = '${web.browserName.name} — ${web.platform ?? 'Web'}';
      } else {
        final android = await info.androidInfo;
        _cihazBilgisi = '${android.manufacturer} ${android.model}';
      }
    } catch (_) {
      _cihazBilgisi = 'Bilinmiyor';
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white,
        actions: [YardimButonu(ekranAdi: 'Sozlesmeler')],
        title: const Text('Dijital İmza', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: _turuncu,
          labelColor: Colors.white, unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.gesture_outlined, size: 18), text: 'Çiz'),
            Tab(icon: Icon(Icons.text_fields_outlined, size: 18), text: 'Yazı'),
          ],
        ),
      ),
      body: Column(children: [
        // Bilgi kutusu
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.person_outlined, size: 14, color: _navy),
                const SizedBox(width: 6),
                Text(widget.veliAd, style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13)),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                Icon(Icons.access_time_outlined, size: 12, color: Colors.grey[500]),
                const SizedBox(width: 5),
                Text(_tarihSaat, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                const SizedBox(width: 10),
                Icon(Icons.devices_outlined, size: 12, color: Colors.grey[500]),
                const SizedBox(width: 5),
                Text(_cihazBilgisi, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ]),
            ]),
          ]),
        ),

        Expanded(child: TabBarView(controller: _tab, children: [
          _imzaCizTab(),
          _yaziliImzaTab(),
        ])),
      ]),
    );
  }

  // ── Çizim İmza ───────────────────────────────────────────────
  Widget _imzaCizTab() => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      const Text('Parmağınızla veya mouse ile imzanızı çizin',
          style: TextStyle(color: Colors.grey, fontSize: 13)),
      const SizedBox(height: 12),

      Expanded(child: RepaintBoundary(
        key: _imzaKey,
        child: Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: _imzaVar ? _navy : Colors.grey.shade300,
                  width: _imzaVar ? 2 : 1),
              boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8)]),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: GestureDetector(
              onPanStart: (d) {
                setState(() {
                  _mevcutCizgi = [d.localPosition];
                  _imzaVar = true;
                });
              },
              onPanUpdate: (d) {
                setState(() => _mevcutCizgi.add(d.localPosition));
              },
              onPanEnd: (_) {
                _mevcutCizgi.add(null);
                _imzaCizgiler.add(List.from(_mevcutCizgi));
                _mevcutCizgi = [];
              },
              child: CustomPaint(
                painter: _ImzaPainter(
                    [..._imzaCizgiler, _mevcutCizgi]),
                child: SizedBox.expand(
                  child: _imzaVar ? null : Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.gesture_outlined, size: 48,
                          color: Colors.grey[300]),
                      const SizedBox(height: 8),
                      Text('Buraya imzalayın',
                          style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      )),

      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          onPressed: () => setState(() {
            _imzaCizgiler.clear();
            _imzaVar = false;
          }),
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Temizle'),
        )),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: _navy, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          onPressed: _imzaVar && !_kaydediliyor
              ? () => _imzaKaydet(cizim: true)
              : null,
          icon: _kaydediliyor
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.check_rounded),
          label: Text(_kaydediliyor ? 'Kaydediliyor...' : 'İmzayı Kaydet',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        )),
      ]),
    ]),
  );

  // ── Yazılı İmza ──────────────────────────────────────────────
  Widget _yaziliImzaTab() => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Ad ve soyadınızı yazarak imzalayabilirsiniz',
          style: TextStyle(color: Colors.grey, fontSize: 13)),
      const SizedBox(height: 16),

      TextField(
        controller: _adSoyadCtrl,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w300,
            fontStyle: FontStyle.italic),
        decoration: InputDecoration(
          labelText: 'Ad Soyad',
          hintText: widget.veliAd,
          prefixIcon: const Icon(Icons.edit_outlined, color: _navy),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true, fillColor: Colors.white,
        ),
      ),
      const SizedBox(height: 12),

      // İmza önizleme
      if (_adSoyadCtrl.text.isNotEmpty)
        Container(
          width: double.infinity, height: 100,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _navy.withValues(alpha: 0.3))),
          child: Text(_adSoyadCtrl.text,
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w300,
                  fontStyle: FontStyle.italic, color: _navy)),
        ),

      const SizedBox(height: 12),

      // Onay kutusu
      GestureDetector(
        onTap: () => setState(() => _yaziliImzaOnay = !_yaziliImzaOnay),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Checkbox(
            value: _yaziliImzaOnay, activeColor: Colors.green,
            onChanged: (v) => setState(() => _yaziliImzaOnay = v ?? false)),
          const Expanded(child: Padding(
            padding: EdgeInsets.only(top: 11),
            child: Text(
              'Yukarıdaki dijital imzamın fiziksel imzamla aynı '
              'hukuki geçerliliğe sahip olduğunu kabul ediyorum.',
              style: TextStyle(fontSize: 12),
            ),
          )),
        ]),
      ),

      const Spacer(),

      SizedBox(width: double.infinity, child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
            backgroundColor: _navy, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
        onPressed: (_adSoyadCtrl.text.trim().isNotEmpty &&
                _yaziliImzaOnay && !_kaydediliyor)
            ? () => _imzaKaydet(cizim: false)
            : null,
        icon: _kaydediliyor
            ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.check_rounded),
        label: Text(_kaydediliyor ? 'Kaydediliyor...' : 'İmzayı Tamamla',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      )),
    ]),
  );

  Future<void> _imzaKaydet({required bool cizim}) async {
    setState(() => _kaydediliyor = true);
    try {
      String? imzaBase64;

      if (cizim) {
        // Canvas'ı PNG'ye çevir
        final boundary = _imzaKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary != null) {
          final img = await boundary.toImage(pixelRatio: 2.0);
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          if (bytes != null) {
            imzaBase64 = base64Encode(bytes.buffer.asUint8List());
          }
        }
      }

      final now    = DateTime.now();
      final imzaVeri = {
        'tip'          : cizim ? 'cizim' : 'yazili',
        'adSoyad'      : cizim ? widget.veliAd : _adSoyadCtrl.text.trim(),
        'imzaData'     : imzaBase64,
        'tarih'        : Timestamp.fromDate(now),
        'tarihStr'     : _tarihSaat,
        'cihazBilgisi' : _cihazBilgisi,
        'sozlesmeId'   : widget.sozlesmeId,
        'gecerli'      : true,
      };

      // Firestore'a yaz
      if (widget.sozlesmeId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('sozlesmeler')
            .doc(widget.sozlesmeId)
            .update({
          'imzaData'   : imzaVeri,
          'durum'      : 'imzalandi',
          'onayTarihi' : FieldValue.serverTimestamp(),
          'cihazBilgisi': _cihazBilgisi,
          'updatedAt'  : FieldValue.serverTimestamp(),
        });
      }

      widget.onImzaTamamlandi(imzaVeri);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('İmza başarıyla kaydedildi!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating));
        Navigator.pop(context, imzaVeri);
      }
    } catch (e) {
      setState(() => _kaydediliyor = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Hata: $e'), backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating));
    }
  }
}

// ── Canvas Painter ────────────────────────────────────────────
class _ImzaPainter extends CustomPainter {
  final List<List<Offset?>> cizgiler;

  _ImzaPainter(this.cizgiler);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1a3a6b)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final cizgi in cizgiler) {
      for (var i = 0; i < cizgi.length - 1; i++) {
        if (cizgi[i] != null && cizgi[i + 1] != null) {
          canvas.drawLine(cizgi[i]!, cizgi[i + 1]!, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_ImzaPainter oldDelegate) => true;
}
