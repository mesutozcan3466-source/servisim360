import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

class _Sutun {
  final String key;
  final String baslik;
  bool secili;
  _Sutun(this.key, this.baslik, {this.secili = true});
}

class WebOgrenciExportDialog extends StatefulWidget {
  final String firmaId;
  final String projeId;
  final String projeAdi;

  const WebOgrenciExportDialog({
    super.key,
    required this.firmaId,
    required this.projeId,
    required this.projeAdi,
  });

  @override
  State<WebOgrenciExportDialog> createState() => _WebOgrenciExportDialogState();
}

class _WebOgrenciExportDialogState extends State<WebOgrenciExportDialog> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  final List<_Sutun> _sutunlar = [
    _Sutun('ad',           'Ad',            secili: true),
    _Sutun('soyad',        'Soyad',         secili: true),
    _Sutun('ogrenciTel',   'Öğrenci Tel',   secili: true),
    _Sutun('anneTel',      'Anne Tel',      secili: true),
    _Sutun('babaTel',      'Baba Tel',      secili: true),
    _Sutun('adres',        'Açık Adres',    secili: true),
    _Sutun('projeAdi',     'Proje Adı',     secili: true),
    _Sutun('ogrenciTc',    'Öğrenci TC',    secili: false),
    _Sutun('okulNo',       'Okul No',       secili: false),
    _Sutun('okul',         'Okul Adı',      secili: false),
    _Sutun('sinif',        'Sınıf',         secili: false),
    _Sutun('veliAd',       'Veli Adı',      secili: false),
    _Sutun('veliTc',       'Veli TC',       secili: false),
    _Sutun('veliTel',      'Veli Tel',      secili: false),
    _Sutun('aylikUcret',   'Aylık Ücret',   secili: false),
    _Sutun('sozlesmeDurum','Sözleşme',      secili: false),
    _Sutun('kayitTipi',    'Kayıt Tipi',    secili: false),
    _Sutun('soforAd',      'Şoför',         secili: false),
    _Sutun('bindi',        'Durum',         secili: false),
    _Sutun('olusturma',    'Kayıt Tarihi',  secili: false),
  ];

  final List<_Sutun> _ekstraSutunlar = [];
  final _ekstraSutunCtrl = TextEditingController();

  bool _yukleniyor = false;
  List<Map<String, dynamic>> _ogrenciler = [];

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _ekstraSutunCtrl.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    var q = FirebaseFirestore.instance
        .collection('students')
        .where('firmaId', isEqualTo: widget.firmaId);
    if (widget.projeId.isNotEmpty) {
      q = q.where('projeId', isEqualTo: widget.projeId);
    }
    final snap = await q.get();
    setState(() {
      _ogrenciler = snap.docs.map((d) => {'_id': d.id, ...d.data()}).toList();
      _yukleniyor = false;
    });
  }

  List<_Sutun> get _seciliSutunlar =>
      [..._sutunlar, ..._ekstraSutunlar].where((s) => s.secili).toList();

  String _degerAl(Map<String, dynamic> ogr, String key) {
    final v = ogr[key];
    if (v == null) { return ''; }
    if (v is bool) { return v ? 'Evet' : 'Hayır'; }
    if (v is Timestamp) {
      final dt = v.toDate();
      return '${dt.day.toString().padLeft(2,'0')}.${dt.month.toString().padLeft(2,'0')}.${dt.year}';
    }
    return v.toString();
  }

  // ── EXCEL EXPORT ──────────────────────────────────────────────
  Future<void> _excelIndir() async {
    if (_ogrenciler.isEmpty) { return; }
    final excel  = Excel.createExcel();
    final sheet  = excel['Ogrenciler'];
    final secili = _seciliSutunlar;

    sheet.appendRow(secili.map((s) => TextCellValue(s.baslik)).toList());
    for (final ogr in _ogrenciler) {
      sheet.appendRow(secili.map((s) => TextCellValue(_degerAl(ogr, s.key))).toList());
    }

    final bytes = excel.encode();
    if (bytes == null) { return; }
    if (kIsWeb) {
      final blob = html.Blob([Uint8List.fromList(bytes)]);
      final url  = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download',
            'ogrenciler_${widget.projeAdi.replaceAll(' ', '_')}.xlsx')
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  // ── WORD/HTML EXPORT ──────────────────────────────────────────
  void _wordIndir() {
    if (_ogrenciler.isEmpty) { return; }
    final secili = _seciliSutunlar;
    final tarih  = DateTime.now();
    final sb     = StringBuffer();

    sb.write('<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Öğrenci Listesi</title>');
    sb.write('<style>');
    sb.write('@page { margin: 15mm; }');
    sb.write('body { font-family: Arial, sans-serif; font-size: 11pt; }');
    sb.write('h1 { color: #1a3a6b; font-size: 16pt; margin: 0 0 4px; }');
    sb.write('h2 { color: #666; font-size: 10pt; margin: 0; font-weight: normal; }');
    sb.write('table { width: 100%; border-collapse: collapse; margin-top: 12px; font-size: 9pt; }');
    sb.write('th { background: #1a3a6b; color: white; padding: 7px 8px; text-align: left; }');
    sb.write('td { padding: 6px 8px; border-bottom: 1px solid #e0e0e0; }');
    sb.write('tr:nth-child(even) td { background: #f5f7fa; }');
    sb.write('</style></head><body>');
    sb.write('<h1>Öğrenci Listesi — Servisim360</h1>');
    sb.write('<h2>Proje: ${widget.projeAdi} | Tarih: ${tarih.day}.${tarih.month}.${tarih.year} | Toplam: ${_ogrenciler.length} öğrenci</h2>');
    sb.write('<table><tr><th>#</th>');

    for (final s in secili) {
      sb.write('<th>${s.baslik}</th>');
    }
    sb.write('</tr>');

    for (int i = 0; i < _ogrenciler.length; i++) {
      sb.write('<tr><td>${i + 1}</td>');
      for (final s in secili) {
        final v    = _degerAl(_ogrenciler[i], s.key);
        final bold = s.key == 'ad' || s.key == 'soyad';
        sb.write('<td>${bold ? '<b>$v</b>' : v}</td>');
      }
      sb.write('</tr>');
    }
    sb.write('</table></body></html>');

    if (kIsWeb) {
      final blob = html.Blob([sb.toString()], 'application/msword');
      final url  = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download',
            'ogrenciler_${widget.projeAdi.replaceAll(' ', '_')}.doc')
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  // ── YAZDIR ────────────────────────────────────────────────────
  void _yazdir() {
    if (_ogrenciler.isEmpty) { return; }
    final secili = _seciliSutunlar;
    final tarih  = DateTime.now();
    final sb     = StringBuffer();

    sb.write('<!DOCTYPE html><html><head><meta charset="UTF-8">');
    sb.write('<style>');
    sb.write('@page { margin: 10mm; size: A4 landscape; }');
    sb.write('body { font-family: Arial, sans-serif; font-size: 9pt; }');
    sb.write('h1 { color: #1a3a6b; font-size: 13pt; margin: 0 0 2px; }');
    sb.write('h2 { color: #555; font-size: 9pt; margin: 0 0 10px; }');
    sb.write('table { width: 100%; border-collapse: collapse; }');
    sb.write('th { background: #1a3a6b; color: white; padding: 5px 6px; font-size: 8pt; }');
    sb.write('td { padding: 4px 6px; border-bottom: 1px solid #ddd; font-size: 8pt; }');
    sb.write('tr:nth-child(even) td { background: #f5f7fa; }');
    sb.write('</style></head><body>');
    sb.write('<h1>Öğrenci Listesi — ${widget.projeAdi}</h1>');
    sb.write('<h2>Tarih: ${tarih.day}.${tarih.month}.${tarih.year} | Toplam: ${_ogrenciler.length} öğrenci</h2>');
    sb.write('<table><tr><th>#</th>');
    for (final s in secili) {
      sb.write('<th>${s.baslik}</th>');
    }
    sb.write('</tr>');
    for (int i = 0; i < _ogrenciler.length; i++) {
      sb.write('<tr><td>${i + 1}</td>');
      for (final s in secili) {
        sb.write('<td>${_degerAl(_ogrenciler[i], s.key)}</td>');
      }
      sb.write('</tr>');
    }
    sb.write('</table></body></html>');

    if (kIsWeb) {
      final blob = html.Blob([sb.toString()], 'text/html');
      final url  = html.Url.createObjectUrl(blob);
      final win  = html.window.open(url, '_blank');
      if (win != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          try { (win as dynamic).print(); } catch (e) { debugPrint('print: $e'); }
        });
      }
    }
  }

  // ── EXCEL IMPORT ──────────────────────────────────────────────
  Future<void> _excelYukle() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['xlsx', 'xls'], withData: true,
    );
    if (result == null || result.files.first.bytes == null) { return; }

    final excel = Excel.decodeBytes(result.files.first.bytes!);
    final sheet = excel.tables.values.first;
    if (sheet.rows.length < 2) { return; }

    final basliklar = sheet.rows[0]
        .map((c) => c?.value?.toString().toLowerCase().trim() ?? '')
        .toList();

    final Map<String, int> kolonMap = {};
    for (int i = 0; i < basliklar.length; i++) {
      final b = basliklar[i];
      if (b.contains('ad') && !b.contains('soy') && !b.contains('veli') && !b.contains('okul')) { kolonMap['ad'] = i; }
      if (b.contains('soyad')) { kolonMap['soyad'] = i; }
      if (b.contains('öğrenci tel') || b.contains('ogrenci tel') ||
          (b.contains('tel') && !b.contains('anne') && !b.contains('baba') && !b.contains('veli'))) {
        kolonMap['ogrenciTel'] = i;
      }
      if (b.contains('anne')) { kolonMap['anneTel'] = i; }
      if (b.contains('baba')) { kolonMap['babaTel'] = i; }
      if (b.contains('adres') || b.contains('açık')) { kolonMap['adres'] = i; }
      if (b.contains('okul') && !b.contains('no')) { kolonMap['okul'] = i; }
      if (b.contains('okul no') || b.contains('okulno')) { kolonMap['okulNo'] = i; }
      if (b.contains('sınıf') || b.contains('sinif')) { kolonMap['sinif'] = i; }
      if (b.contains('veli') && b.contains('ad')) { kolonMap['veliAd'] = i; }
      if (b.contains('veli') && b.contains('tel')) { kolonMap['veliTel'] = i; }
      if (b.contains('tc') && b.contains('öğ')) { kolonMap['ogrenciTc'] = i; }
      if (b.contains('tc') && b.contains('vel')) { kolonMap['veliTc'] = i; }
      if (b.contains('ücret') || b.contains('ucret')) { kolonMap['aylikUcret'] = i; }
    }

    String val(List<dynamic> row, String key) {
      final idx = kolonMap[key];
      if (idx == null || idx >= row.length) { return ''; }
      return row[idx]?.value?.toString().trim() ?? '';
    }

    final satirlar = <Map<String, dynamic>>[];
    for (int i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      final ad  = val(row, 'ad');
      if (ad.isEmpty) { continue; }
      final soyad = val(row, 'soyad');
      satirlar.add({
        'ad'        : ad,
        'soyad'     : soyad,
        'adSoyad'   : '$ad $soyad'.trim(),
        'ogrenciTel': val(row, 'ogrenciTel'),
        'anneTel'   : val(row, 'anneTel'),
        'babaTel'   : val(row, 'babaTel'),
        'adres'     : val(row, 'adres'),
        'okul'      : val(row, 'okul'),
        'okulNo'    : val(row, 'okulNo'),
        'sinif'     : val(row, 'sinif'),
        'veliAd'    : val(row, 'veliAd'),
        'veliTel'   : val(row, 'veliTel'),
        'ogrenciTc' : val(row, 'ogrenciTc'),
        'veliTc'    : val(row, 'veliTc'),
        'aylikUcret': val(row, 'aylikUcret'),
        'projeAdi'  : widget.projeAdi,
        'firmaId'   : widget.firmaId,
        'projeId'   : widget.projeId,
        'kayitTipi' : 'excel_import',
        'aktif'     : true,
        'bindi'     : false,
        'olusturma' : FieldValue.serverTimestamp(),
      });
    }

    if (satirlar.isEmpty || !mounted) { return; }

    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.upload_file_rounded, color: _navy),
          const SizedBox(width: 8),
          Text('${satirlar.length} öğrenci yüklenecek'),
        ]),
        content: SizedBox(
          width: 500, height: 320,
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                  color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.folder_outlined, color: Colors.blue, size: 16),
                const SizedBox(width: 6),
                Text('Proje: ${widget.projeAdi}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              ]),
            ),
            Expanded(child: ListView.builder(
              itemCount: satirlar.length > 8 ? 8 : satirlar.length,
              itemBuilder: (_, i) {
                final s = satirlar[i];
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: _navy.withValues(alpha: 0.1),
                    child: Text('${i + 1}',
                        style: const TextStyle(fontSize: 10, color: _navy)),
                  ),
                  title: Text('${s['ad']} ${s['soyad']}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text(
                      '📞 ${s['ogrenciTel']}  👩 ${s['anneTel']}  👨 ${s['babaTel']}\n📍 ${s['adres']}',
                      style: const TextStyle(fontSize: 11)),
                  isThreeLine: true,
                );
              },
            )),
            if (satirlar.length > 8)
              Text('... ve ${satirlar.length - 8} öğrenci daha',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _navy, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('${satirlar.length} Öğrenciyi Kaydet'),
          ),
        ],
      ),
    );

    if (onay != true) { return; }

    setState(() => _yukleniyor = true);
    int basarili = 0;
    for (final ogr in satirlar) {
      try {
        await FirebaseFirestore.instance.collection('students').add(ogr);
        basarili++;
      } catch (e) {
        debugPrint('Kayıt hatası: $e');
      }
    }
    setState(() => _yukleniyor = false);
    await _yukle();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$basarili öğrenci eklendi ✓'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ── ŞABLON İNDİR ──────────────────────────────────────────────
  void _sablonIndir() {
    final excel = Excel.createExcel();
    final sheet = excel['Ogrenciler'];
    sheet.appendRow([
      TextCellValue('Ad'),           TextCellValue('Soyad'),
      TextCellValue('Ogrenci Tel'),  TextCellValue('Anne Tel'),
      TextCellValue('Baba Tel'),     TextCellValue('Acik Adres'),
      TextCellValue('Okul'),         TextCellValue('Sinif'),
      TextCellValue('Veli Adi'),     TextCellValue('Veli Tel'),
    ]);
    sheet.appendRow([
      TextCellValue('Ahmet'),        TextCellValue('Yilmaz'),
      TextCellValue('05301234567'),  TextCellValue('05321234567'),
      TextCellValue('05331234567'),  TextCellValue('Kadikoy Mah. No:5'),
      TextCellValue('Ataturk Ilkokulu'), TextCellValue('3-A'),
      TextCellValue('Mehmet Yilmaz'), TextCellValue('05351234567'),
    ]);
    final bytes = excel.encode();
    if (bytes == null) { return; }
    if (kIsWeb) {
      final blob = html.Blob([Uint8List.fromList(bytes)]);
      final url  = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'ogrenci_sablonu.xlsx')
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  void _ekstraSutunEkle() {
    final text = _ekstraSutunCtrl.text.trim();
    if (text.isEmpty) { return; }
    setState(() {
      _ekstraSutunlar.add(_Sutun(
        text.toLowerCase().replaceAll(' ', '_'),
        text,
        secili: true,
      ));
      _ekstraSutunCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 800, height: 600,
        child: Column(children: [
          // BAŞLIK
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: _navy,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(children: [
              const Icon(Icons.table_chart_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Öğrenci Listesi — Dışa Aktar / İçe Aktar',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                Text('${widget.projeAdi} • ${_ogrenciler.length} öğrenci',
                    style: const TextStyle(color: Colors.white60, fontSize: 11)),
              ])),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),

          Expanded(child: Row(children: [
            // SOL — Sütun seçimi
            Container(
              width: 280,
              decoration: BoxDecoration(
                border: Border(right: const BorderSide(color: Color(0xFFEEEEEE))),
              ),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  color: const Color(0xFFF8F9FA),
                  child: const Row(children: [
                    Icon(Icons.tune_rounded, size: 16, color: _navy),
                    SizedBox(width: 6),
                    Text('Sütun Seç',
                        style: TextStyle(fontWeight: FontWeight.bold, color: _navy, fontSize: 13)),
                  ]),
                ),
                Expanded(child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Text('STANDART ALANLAR',
                          style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),
                    ..._sutunlar.map((s) => CheckboxListTile(
                      dense: true,
                      value: s.secili,
                      onChanged: (v) => setState(() => s.secili = v ?? false),
                      title: Text(s.baslik, style: const TextStyle(fontSize: 12)),
                      subtitle: Text(s.key,
                          style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      activeColor: _navy,
                      controlAffinity: ListTileControlAffinity.leading,
                    )),
                    if (_ekstraSutunlar.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Text('EK SÜTUNLAR',
                            style: TextStyle(
                                fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                      ),
                      ..._ekstraSutunlar.map((s) => CheckboxListTile(
                        dense: true,
                        value: s.secili,
                        onChanged: (v) => setState(() => s.secili = v ?? false),
                        title: Text(s.baslik, style: const TextStyle(fontSize: 12)),
                        secondary: IconButton(
                          icon: const Icon(Icons.close, size: 14, color: Colors.red),
                          onPressed: () => setState(() => _ekstraSutunlar.remove(s)),
                        ),
                        activeColor: _turuncu,
                        controlAffinity: ListTileControlAffinity.leading,
                      )),
                    ],
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        Expanded(child: TextField(
                          controller: _ekstraSutunCtrl,
                          decoration: InputDecoration(
                            hintText: 'Sütun adı...',
                            hintStyle: const TextStyle(fontSize: 11),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                          ),
                          style: const TextStyle(fontSize: 12),
                          onSubmitted: (_) => _ekstraSutunEkle(),
                        )),
                        const SizedBox(width: 6),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _turuncu,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(36, 36),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: _ekstraSutunEkle,
                          child: const Icon(Icons.add, size: 18),
                        ),
                      ]),
                    ),
                  ],
                )),
              ]),
            ),

            // SAĞ — Önizleme + Butonlar
            Expanded(child: Column(children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: const Color(0xFFF8F9FA),
                child: Row(children: [
                  const Icon(Icons.upload_file_rounded, size: 16, color: _navy),
                  const SizedBox(width: 6),
                  const Text('İçe Aktar:',
                      style: TextStyle(fontWeight: FontWeight.bold, color: _navy, fontSize: 12)),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _sablonIndir,
                    icon: const Icon(Icons.download_rounded, size: 14),
                    label: const Text('Şablon', style: TextStyle(fontSize: 11)),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _yukleniyor ? null : _excelYukle,
                    icon: _yukleniyor
                        ? const SizedBox(width: 12, height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.upload_rounded, size: 14),
                    label: const Text('Excel Yükle', style: TextStyle(fontSize: 11)),
                  ),
                ]),
              ),

              Expanded(child: _yukleniyor
                  ? const Center(child: CircularProgressIndicator())
                  : _ogrenciler.isEmpty
                  ? const Center(child: Text('Öğrenci bulunamadı',
                  style: TextStyle(color: Colors.grey)))
                  : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columnSpacing: 16,
                    headingRowColor: WidgetStateProperty.all(
                        const Color(0xFFF0F2F5)),
                    columns: [
                      const DataColumn(
                        label: Text('#',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11)),
                      ),
                      ..._seciliSutunlar.map((s) => DataColumn(
                        label: Text(s.baslik,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11)),
                      )),
                    ],
                    rows: _ogrenciler.take(10).toList().asMap().entries.map((e) =>
                        DataRow(cells: [
                          DataCell(Text('${e.key + 1}',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey))),
                          ..._seciliSutunlar.map((s) => DataCell(
                            Text(_degerAl(e.value, s.key),
                                style: const TextStyle(fontSize: 11),
                                overflow: TextOverflow.ellipsis),
                          )),
                        ]),
                    ).toList(),
                  ),
                ),
              )),

              if (_ogrenciler.length > 10)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                      '... ve ${_ogrenciler.length - 10} öğrenci daha (hepsi dışa aktarılır)',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                ),

              // Export butonları
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border(top: const BorderSide(color: Color(0xFFEEEEEE))),
                ),
                child: Row(children: [
                  Text('${_seciliSutunlar.length} sütun seçili',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  const Spacer(),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.purple,
                      side: const BorderSide(color: Colors.purple),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _yazdir,
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: const Text('Yazdır', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _wordIndir,
                    icon: const Icon(Icons.description_rounded, size: 16),
                    label: const Text('Word İndir', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _excelIndir,
                    icon: const Icon(Icons.table_chart_rounded, size: 16),
                    label: const Text('Excel İndir', style: TextStyle(fontSize: 12)),
                  ),
                ]),
              ),
            ])),
          ])),
        ]),
      ),
    );
  }
}