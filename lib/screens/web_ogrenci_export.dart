import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
//  TÃœM KAYIT SÄ°STEMLERÄ°NDEN GELEN Ã–ÄRENCÄ° ALANLARI
//  (yÃ¼z yÃ¼ze, link, afiÅŸ/QR)
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•

class _Sutun {
  final String key;      // Firestore alan adÄ±
  final String baslik;   // Excel/Word baÅŸlÄ±k
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

  // TÃ¼m olasÄ± sÃ¼tunlar - tÃ¼m kayÄ±t sistemlerinden gelen alanlar
  final List<_Sutun> _sutunlar = [
    // Zorunlu - her zaman seÃ§ili
    _Sutun('ad',          'Ad',              secili: true),
    _Sutun('soyad',       'Soyad',           secili: true),
    _Sutun('ogrenciTel',  'Ã–ÄŸrenci Tel',     secili: true),
    _Sutun('anneTel',     'Anne Tel',        secili: true),
    _Sutun('babaTel',     'Baba Tel',        secili: true),
    _Sutun('adres',       'AÃ§Ä±k Adres',      secili: true),
    _Sutun('projeAdi',    'Proje AdÄ±',       secili: true),
    // Ek alanlar - seÃ§ilebilir
    _Sutun('ogrenciTc',   'Ã–ÄŸrenci TC',      secili: false),
    _Sutun('okulNo',      'Okul No',         secili: false),
    _Sutun('okul',        'Okul AdÄ±',        secili: false),
    _Sutun('sinif',       'SÄ±nÄ±f',           secili: false),
    _Sutun('veliAd',      'Veli AdÄ±',        secili: false),
    _Sutun('veliTc',      'Veli TC',         secili: false),
    _Sutun('veliTel',     'Veli Tel',        secili: false),
    _Sutun('aylikUcret',  'AylÄ±k Ãœcret',     secili: false),
    _Sutun('sozlesmeDurum','SÃ¶zleÅŸme',       secili: false),
    _Sutun('kayitTipi',   'KayÄ±t Tipi',      secili: false),
    _Sutun('soforAd',     'ÅofÃ¶r',           secili: false),
    _Sutun('bindi',       'Durum',           secili: false),
    _Sutun('olusturma',   'KayÄ±t Tarihi',    secili: false),
  ];

  // Ekstra sÃ¼tunlar (admin ekler)
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

  // SeÃ§ili sÃ¼tunlar
  List<_Sutun> get _seciliSutunlar =>
      [..._sutunlar, ..._ekstraSutunlar].where((s) => s.secili).toList();

  String _degerAl(Map<String, dynamic> ogr, String key) {
    final v = ogr[key];
    if (v == null) return '';
    if (v is bool) return v ? 'Evet' : 'HayÄ±r';
    if (v is Timestamp) {
      final dt = v.toDate();
      return '${dt.day.toString().padLeft(2,'0')}.${dt.month.toString().padLeft(2,'0')}.${dt.year}';
    }
    return v.toString();
  }

  // â”€â”€ EXCEL EXPORT â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _excelIndir() async {
    if (_ogrenciler.isEmpty) return;
    final excel  = Excel.createExcel();
    final sheet  = excel['Ogrenciler'];
    final secili = _seciliSutunlar;

    // BaÅŸlÄ±k
    sheet.appendRow(secili.map((s) => TextCellValue(s.baslik)).toList());

    // Veriler
    for (final ogr in _ogrenciler) {
      sheet.appendRow(secili.map((s) => TextCellValue(_degerAl(ogr, s.key))).toList());
    }

    final bytes = excel.encode();
    if (bytes == null) return;
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

  // â”€â”€ WORD/HTML EXPORT â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _wordIndir() {
    if (_ogrenciler.isEmpty) return;
    final secili = _seciliSutunlar;
    final tarih  = DateTime.now();
    final sb     = StringBuffer();

    sb.write('''<!DOCTYPE html>
<html><head><meta charset="UTF-8"><title>Ã–ÄŸrenci Listesi</title>
<style>
  @page { margin: 15mm; }
  body  { font-family: Arial, sans-serif; font-size: 11pt; }
  .header { border-bottom: 3px solid #1a3a6b; padding-bottom: 10px; margin-bottom: 16px; }
  h1  { color: #1a3a6b; font-size: 16pt; margin: 0 0 4px; }
  h2  { color: #666; font-size: 10pt; margin: 0; font-weight: normal; }
  table { width: 100%; border-collapse: collapse; margin-top: 12px; font-size: 9pt; }
  th  { background: #1a3a6b; color: white; padding: 7px 8px; text-align: left; }
  td  { padding: 6px 8px; border-bottom: 1px solid #e0e0e0; }
  tr:nth-child(even) td { background: #f5f7fa; }
  .footer { margin-top: 20px; font-size: 9pt; color: #999; text-align: right; }
</style></head><body>
<div class="header">
  <h1>&#128100; Ã–ÄŸrenci Listesi â€” Servisim360</h1>
  <h2>Proje: ${widget.projeAdi} &nbsp;|&nbsp; 
      Tarih: ${tarih.day.toString().padLeft(2,'0')}.${tarih.month.toString().padLeft(2,'0')}.${tarih.year} &nbsp;|&nbsp; 
      Toplam: ${_ogrenciler.length} Ã¶ÄŸrenci</h2>
</div>
<table>
<tr><th>#</th>''');

    for (final s in secili) {
      sb.write('<th>${s.baslik}</th>');
    }
    sb.write('</tr>');

    for (int i = 0; i < _ogrenciler.length; i++) {
      sb.write('<tr><td>${i + 1}</td>');
      for (final s in secili) {
        final v = _degerAl(_ogrenciler[i], s.key);
        final bold = s.key == 'ad' || s.key == 'soyad';
        sb.write('<td>${bold ? '<b>$v</b>' : v}</td>');
      }
      sb.write('</tr>');
    }
    sb.write('''</table>
<div class="footer">Servisim360 â€” ${tarih.day}.${tarih.month}.${tarih.year}</div>
</body></html>''');

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

  // â”€â”€ YAZDIR (tarayÄ±cÄ± print) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _yazdir() {
    if (_ogrenciler.isEmpty) return;
    final secili = _seciliSutunlar;
    final tarih  = DateTime.now();
    final sb     = StringBuffer();
    sb.write('''<!DOCTYPE html><html><head><meta charset="UTF-8">
<style>
  @page { margin: 10mm; size: A4 landscape; }
  body  { font-family: Arial, sans-serif; font-size: 9pt; }
  h1    { color: #1a3a6b; font-size: 13pt; margin: 0 0 2px; }
  h2    { color: #555; font-size: 9pt; margin: 0 0 10px; }
  table { width: 100%; border-collapse: collapse; }
  th    { background: #1a3a6b; color: white; padding: 5px 6px; font-size: 8pt; }
  td    { padding: 4px 6px; border-bottom: 1px solid #ddd; font-size: 8pt; }
  tr:nth-child(even) td { background: #f5f7fa; }
</style></head><body>
<h1>Ã–ÄŸrenci Listesi â€” ${widget.projeAdi}</h1>
<h2>Tarih: ${tarih.day}.${tarih.month}.${tarih.year} | Toplam: ${_ogrenciler.length} Ã¶ÄŸrenci</h2>
<table><tr><th>#</th>''');
    for (final s in secili) sb.write('<th>${s.baslik}</th>');
    sb.write('</tr>');
    for (int i = 0; i < _ogrenciler.length; i++) {
      sb.write('<tr><td>${i+1}</td>');
      for (final s in secili) sb.write('<td>${_degerAl(_ogrenciler[i], s.key)}</td>');
      sb.write('</tr>');
    }
    sb.write('</table></body></html>');

    if (kIsWeb) {
      // final win = html.window.open('', '_blank');
      // win?.document.write(sb.toString());
      // win?.document.close();
      // win?.print();
    }
  }

  // â”€â”€ EXCEL IMPORT â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _excelYukle() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['xlsx', 'xls'], withData: true,
    );
    if (result == null || result.files.first.bytes == null) return;

    final excel = Excel.decodeBytes(result.files.first.bytes!);
    final sheet = excel.tables.values.first;
    if (sheet.rows.length < 2) return;

    // BaÅŸlÄ±k satÄ±rÄ±ndan sÃ¼tun eÅŸlemesi
    final basliklar = sheet.rows[0].map((c) => c?.value?.toString()?.toLowerCase().trim() ?? '').toList();
    
    final Map<String, int> kolonMap = {};
    for (int i = 0; i < basliklar.length; i++) {
      final b = basliklar[i];
      if (b.contains('ad') && !b.contains('soy') && !b.contains('veli') && !b.contains('okul')) kolonMap['ad'] = i;
      if (b.contains('soyad')) kolonMap['soyad'] = i;
      if (b.contains('Ã¶ÄŸrenci tel') || b.contains('ogrenci tel') || (b.contains('tel') && !b.contains('anne') && !b.contains('baba') && !b.contains('veli'))) kolonMap['ogrenciTel'] = i;
      if (b.contains('anne')) kolonMap['anneTel'] = i;
      if (b.contains('baba')) kolonMap['babaTel'] = i;
      if (b.contains('adres') || b.contains('aÃ§Ä±k')) kolonMap['adres'] = i;
      if (b.contains('okul') && !b.contains('no')) kolonMap['okul'] = i;
      if (b.contains('okul no') || b.contains('okulno')) kolonMap['okulNo'] = i;
      if (b.contains('sÄ±nÄ±f') || b.contains('sinif')) kolonMap['sinif'] = i;
      if (b.contains('veli') && b.contains('ad')) kolonMap['veliAd'] = i;
      if (b.contains('veli') && b.contains('tel')) kolonMap['veliTel'] = i;
      if (b.contains('tc') && b.contains('Ã¶ÄŸ')) kolonMap['ogrenciTc'] = i;
      if (b.contains('tc') && b.contains('vel')) kolonMap['veliTc'] = i;
      if (b.contains('Ã¼cret') || b.contains('ucret')) kolonMap['aylikUcret'] = i;
    }

    String val(List row, String key) {
      final idx = kolonMap[key];
      if (idx == null || idx >= row.length) return '';
      return row[idx]?.value?.toString()?.trim() ?? '';
    }

    final satirlar = <Map<String, dynamic>>[];
    for (int i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      final ad = val(row, 'ad');
      if (ad.isEmpty) continue;
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

    if (satirlar.isEmpty || !mounted) return;

    final onay = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.upload_file_rounded, color: _navy),
          const SizedBox(width: 8),
          Text('${satirlar.length} Ã¶ÄŸrenci yÃ¼klenecek'),
        ]),
        content: SizedBox(
          width: 500, height: 320,
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
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
                return ListTile(dense: true,
                  leading: CircleAvatar(radius: 14, backgroundColor: _navy.withValues(alpha: 0.1),
                      child: Text('${i+1}', style: const TextStyle(fontSize: 10, color: _navy))),
                  title: Text('${s['ad']} ${s['soyad']}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: Text(
                    'ğŸ“ ${s['ogrenciTel']}  ğŸ‘© ${s['anneTel']}  ğŸ‘¨ ${s['babaTel']}\nğŸ“ ${s['adres']}',
                    style: const TextStyle(fontSize: 11)),
                  isThreeLine: true,
                );
              },
            )),
            if (satirlar.length > 8)
              Text('... ve ${satirlar.length - 8} Ã¶ÄŸrenci daha',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_, false), child: const Text('Ä°ptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(_, true),
            child: Text('${satirlar.length} Ã–ÄŸrenciyi Kaydet')),
        ],
      ),
    );
    if (onay != true) return;

    setState(() => _yukleniyor = true);
    int basarili = 0;
    for (final ogr in satirlar) {
      try { await FirebaseFirestore.instance.collection('students').add(ogr); basarili++; } catch (_) {}
    }
    setState(() => _yukleniyor = false);
    await _yukle();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$basarili Ã¶ÄŸrenci eklendi âœ“'),
        backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
  }

  // â”€â”€ ÅABLON Ä°NDÄ°R â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _sablonIndir() {
    final excel = Excel.createExcel();
    final sheet = excel['Ogrenciler'];
    sheet.appendRow([
      TextCellValue('Ad'), TextCellValue('Soyad'),
      TextCellValue('Ogrenci Tel'), TextCellValue('Anne Tel'),
      TextCellValue('Baba Tel'), TextCellValue('Acik Adres'),
      TextCellValue('Okul'), TextCellValue('Sinif'),
      TextCellValue('Veli Adi'), TextCellValue('Veli Tel'),
    ]);
    sheet.appendRow([
      TextCellValue('Ahmet'), TextCellValue('Yilmaz'),
      TextCellValue('05301234567'), TextCellValue('05321234567'),
      TextCellValue('05331234567'), TextCellValue('Kadikoy Mah. Ataturk Cad. No:5 D:3'),
      TextCellValue('Ataturk Ilkokulu'), TextCellValue('3-A'),
      TextCellValue('Mehmet Yilmaz'), TextCellValue('05351234567'),
    ]);
    final bytes = excel.encode();
    if (bytes == null) return;
    if (kIsWeb) {
      final blob = html.Blob([Uint8List.fromList(bytes)]);
      final url  = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'ogrenci_sablonu.xlsx')
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 800, height: 600,
        child: Column(children: [
          // BAÅLIK
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
                const Text('Ã–ÄŸrenci Listesi â€” DÄ±ÅŸa Aktar / Ä°Ã§e Aktar',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                Text('${widget.projeAdi} â€¢ ${_ogrenciler.length} Ã¶ÄŸrenci',
                    style: const TextStyle(color: Colors.white60, fontSize: 11)),
              ])),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),

          Expanded(child: Row(children: [
            // SOL - SÃ¼tun seÃ§imi
            Container(
              width: 280,
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: Color(0xFFEEEEEE))),
              ),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  color: const Color(0xFFF8F9FA),
                  child: const Row(children: [
                    Icon(Icons.tune_rounded, size: 16, color: _navy),
                    SizedBox(width: 6),
                    Text('SÃ¼tun SeÃ§', style: TextStyle(fontWeight: FontWeight.bold, color: _navy, fontSize: 13)),
                  ]),
                ),
                Expanded(child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: [
                    // Standart sÃ¼tunlar
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
                      subtitle: Text(s.key, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      activeColor: _navy,
                      controlAffinity: ListTileControlAffinity.leading,
                    )),
                    // Ekstra sÃ¼tunlar
                    if (_ekstraSutunlar.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: Text('EK SÃœTUNLAR',
                            style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
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
                    // Ekstra sÃ¼tun ekle
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        Expanded(child: TextField(
                          controller: _ekstraSutunCtrl,
                          decoration: InputDecoration(
                            hintText: 'SÃ¼tun adÄ±...',
                            hintStyle: const TextStyle(fontSize: 11),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                          style: const TextStyle(fontSize: 12),
                          onSubmitted: (_) => _ekstraSutunEkle(),
                        )),
                        const SizedBox(width: 6),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: _turuncu, foregroundColor: Colors.white,
                              minimumSize: const Size(36, 36), padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          onPressed: _ekstraSutunEkle,
                          child: const Icon(Icons.add, size: 18),
                        ),
                      ]),
                    ),
                  ],
                )),
              ]),
            ),

            // SAÄ - Ã–nizleme + Butonlar
            Expanded(child: Column(children: [
              // Import butonlarÄ±
              Container(
                padding: const EdgeInsets.all(12),
                color: const Color(0xFFF8F9FA),
                child: Row(children: [
                  const Icon(Icons.upload_file_rounded, size: 16, color: _navy),
                  const SizedBox(width: 6),
                  const Text('Ä°Ã§e Aktar:', style: TextStyle(fontWeight: FontWeight.bold, color: _navy, fontSize: 12)),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: _sablonIndir,
                    icon: const Icon(Icons.download_rounded, size: 14),
                    label: const Text('Åablon', style: TextStyle(fontSize: 11)),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: _yukleniyor ? null : _excelYukle,
                    icon: _yukleniyor
                        ? const SizedBox(width: 12, height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.upload_rounded, size: 14),
                    label: const Text('Excel YÃ¼kle', style: TextStyle(fontSize: 11)),
                  ),
                ]),
              ),

              // Ã–nizleme tablosu
              Expanded(child: _yukleniyor
                  ? const Center(child: CircularProgressIndicator())
                  : _ogrenciler.isEmpty
                      ? const Center(child: Text('Ã–ÄŸrenci bulunamadÄ±', style: TextStyle(color: Colors.grey)))
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              columnSpacing: 16,
                              headingRowColor: WidgetStateProperty.all(const Color(0xFFF0F2F5)),
                              columns: [
                                const DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                ..._seciliSutunlar.map((s) => DataColumn(
                                  label: Text(s.baslik,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                )),
                              ],
                              rows: _ogrenciler.take(10).toList().asMap().entries.map((e) =>
                                DataRow(cells: [
                                  DataCell(Text('${e.key + 1}', style: const TextStyle(fontSize: 11, color: Colors.grey))),
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
                  child: Text('... ve ${_ogrenciler.length - 10} Ã¶ÄŸrenci daha (hepsi dÄ±ÅŸa aktarÄ±lÄ±r)',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                ),

              // Export butonlarÄ±
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
                ),
                child: Row(children: [
                  Text('${_seciliSutunlar.length} sÃ¼tun seÃ§ili',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  const Spacer(),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.purple,
                        side: const BorderSide(color: Colors.purple),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: _yazdir,
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: const Text('YazdÄ±r', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: _wordIndir,
                    icon: const Icon(Icons.description_rounded, size: 16),
                    label: const Text('Word Ä°ndir', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: _excelIndir,
                    icon: const Icon(Icons.table_chart_rounded, size: 16),
                    label: const Text('Excel Ä°ndir', style: TextStyle(fontSize: 12)),
                  ),
                ]),
              ),
            ])),
          ])),
        ]),
      ),
    );
  }

  void _ekstraSutunEkle() {
    final text = _ekstraSutunCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _ekstraSutunlar.add(_Sutun(
        text.toLowerCase().replaceAll(' ', '_'),
        text,
        secili: true,
      ));
      _ekstraSutunCtrl.clear();
    });
  }
}

