import 'package:flutter/material.dart';
import 'yardim_widget.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as ex; // pubspec: excel: ^4.0.6
import 'package:firebase_storage/firebase_storage.dart';
import '../services/session_service.dart';

// ════════════════════════════════════════════════════════════════
//  TOPLU YÜKLEME — Excel + PDF'den veli/şoför kaydı
// ════════════════════════════════════════════════════════════════
class TopluYukleScreen extends StatefulWidget {
  const TopluYukleScreen({super.key});
  @override
  State<TopluYukleScreen> createState() => _TopluYukleScreenState();
}

class _TopluYukleScreenState extends State<TopluYukleScreen>
    with SingleTickerProviderStateMixin {
  static const _navy   = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);

  late TabController _tab;
  String _firmaId = '';
  String _projeId = '';
  bool   _yukleniyor = false;
  String _sonuc = '';
  List<Map<String, dynamic>> _onizleme = [];
  String _yuklemeTipi = 'ogrenci'; // ogrenci | sofor | veli

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _baslat();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _baslat() async {
    _firmaId = await SessionService.instance.firmaIdAl() ?? '';
    _projeId = SessionService.instance.aktifProjeId ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white,
        actions: [YardimButonu(ekranAdi: 'Kayitlar')],
        title: const Text('Toplu Yukle', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: _orange,
          tabs: const [
            Tab(icon: Icon(Icons.table_chart_outlined), text: 'Excel (.xlsx)'),
            Tab(icon: Icon(Icons.picture_as_pdf_outlined), text: 'PDF'),
          ],
        ),
      ),
      body: TabBarView(controller: _tab, children: [
        _ExcelYukle(
          firmaId: _firmaId, projeId: _projeId,
          yukleniyor: _yukleniyor, onizleme: _onizleme, sonuc: _sonuc,
          yuklemeTipi: _yuklemeTipi,
          onTipiDegistir: (t) => setState(() => _yuklemeTipi = t),
          onExcelYukle: _excelDosyaAc,
          onKaydet: _kaydet,
        ),
        _PdfYukle(
          firmaId: _firmaId, projeId: _projeId,
          yukleniyor: _yukleniyor,
          onPdfYukle: _pdfDosyaAc,
        ),
      ]),
    );
  }

  // ── EXCEL ──────────────────────────────────────────────────────
  Future<void> _excelDosyaAc() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );
      if (result == null || result.files.isEmpty) return;

      setState(() { _yukleniyor = true; _sonuc = ''; _onizleme = []; });

      final bytes = result.files.first.bytes;
      if (bytes == null) throw Exception('Dosya okunamadi');

      final excel = ex.Excel.decodeBytes(bytes);
      final sheet = excel.tables.values.first;

      final rows = <Map<String, dynamic>>[];
      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        if (row.isEmpty || row[0]?.value == null) continue;

        if (_yuklemeTipi == 'sofor') {
          rows.add({
            'ad':        row[0]?.value?.toString() ?? '',
            'telefon':   row[1]?.value?.toString() ?? '',
            'aracPlaka': row[2]?.value?.toString() ?? '',
            'firmaId':   _firmaId,
            'aktif':     true,
          });
        } else {
          // ogrenci veya veli
          rows.add({
            'ad':       row[0]?.value?.toString() ?? '',
            'veliTel':  row[1]?.value?.toString() ?? '',
            'adres':    row[2]?.value?.toString() ?? '',
            'veliAd':   row[3]?.value?.toString() ?? '',
            'sinif':    row[4]?.value?.toString() ?? '',
            'firmaId':  _firmaId,
            'projeId':  _projeId,
            'durum':    'onayli',
          });
        }
      }

      setState(() {
        _onizleme = rows;
        _yukleniyor = false;
        _sonuc = '${rows.length} kayit hazirlandi';
      });
    } catch (e) {
      setState(() {
        _yukleniyor = false;
        _sonuc = 'Hata: ${e.toString()}';
      });
    }
  }

  Future<void> _kaydet() async {
    if (_onizleme.isEmpty) return;
    setState(() => _yukleniyor = true);

    try {
      final koleksiyon = _yuklemeTipi == 'sofor' ? 'drivers' : 'students';
      final batch = FirebaseFirestore.instance.batch();
      for (final kayit in _onizleme) {
        final ref = FirebaseFirestore.instance.collection(koleksiyon).doc();
        batch.set(ref, kayit);
      }
      await batch.commit();
      setState(() {
        _sonuc = '✅ ${_onizleme.length} kayit basariyla kaydedildi!';
        _onizleme = [];
        _yukleniyor = false;
      });
    } catch (e) {
      setState(() {
        _sonuc = 'Kayit hatasi: $e';
        _yukleniyor = false;
      });
    }
  }

  // ── PDF ────────────────────────────────────────────────────────
  Future<void> _pdfDosyaAc() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result == null || result.files.isEmpty) return;

      setState(() => _yukleniyor = true);

      // PDF'i Firebase Storage'a yükle
      final bytes = result.files.first.bytes;
      final dosyaAdi = result.files.first.name;
      if (bytes == null) throw Exception('Dosya okunamadi');

      final ref = FirebaseStorage.instance
          .ref('pdf_yuklemeler/$_firmaId/${DateTime.now().millisecondsSinceEpoch}_$dosyaAdi');
      await ref.putData(bytes);
      final url = await ref.getDownloadURL();

      // Admin bilgilendir
      await FirebaseFirestore.instance.collection('pdf_yuklemeler').add({
        'firmaId':    _firmaId,
        'dosyaAdi':   dosyaAdi,
        'url':        url,
        'tarih':      FieldValue.serverTimestamp(),
        'durum':      'isleniyor',
        'aciklama':   'PDF manuel inceleme gerekiyor',
      });

      setState(() {
        _yukleniyor = false;
        _sonuc = '✅ PDF yuklendi. Admin inceledikten sonra kayitlar eklenecek.';
      });
    } catch (e) {
      setState(() {
        _yukleniyor = false;
        _sonuc = 'PDF yuklenemedi: $e';
      });
    }
  }
}

// ── EXCEL SEKME ──────────────────────────────────────────────────
class _ExcelYukle extends StatelessWidget {
  final String firmaId, projeId, yuklemeTipi, sonuc;
  final bool yukleniyor;
  final List<Map<String, dynamic>> onizleme;
  final ValueChanged<String> onTipiDegistir;
  final VoidCallback onExcelYukle, onKaydet;

  static const _navy = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);

  const _ExcelYukle({
    required this.firmaId, required this.projeId,
    required this.yuklemeTipi, required this.sonuc,
    required this.yukleniyor, required this.onizleme,
    required this.onTipiDegistir, required this.onExcelYukle,
    required this.onKaydet,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // Tip seçici
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Ne yuklemek istiyorsunuz?',
              style: TextStyle(fontWeight: FontWeight.bold, color: _navy)),
          const SizedBox(height: 12),
          Row(children: [
            _TipBtn('Ogrenci', 'ogrenci', Icons.school_outlined, yuklemeTipi, onTipiDegistir),
            const SizedBox(width: 10),
            _TipBtn('Sofor', 'sofor', Icons.directions_bus_outlined, yuklemeTipi, onTipiDegistir),
            const SizedBox(width: 10),
            _TipBtn('Veli', 'veli', Icons.family_restroom_outlined, yuklemeTipi, onTipiDegistir),
          ]),
        ]),
      ),

      const SizedBox(height: 16),

      // Excel format rehberi
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.2))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.info_outline, color: Colors.blue, size: 16),
            SizedBox(width: 6),
            Text('Excel Kolon Sirasi', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          ]),
          const SizedBox(height: 8),
          Text(
            yuklemeTipi == 'sofor'
                ? 'A: Ad Soyad  |  B: Telefon  |  C: Arac Plakasi'
                : 'A: Ad Soyad  |  B: Veli Tel  |  C: Adres  |  D: Veli Ad  |  E: Sinif',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ]),
      ),

      const SizedBox(height: 16),

      // Yükle butonu
      SizedBox(width: double.infinity, child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
            backgroundColor: _navy, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        icon: yukleniyor
            ? const SizedBox(width: 16, height: 16,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.upload_file_outlined),
        label: Text(yukleniyor ? 'Yukleniyor...' : 'Excel Dosyasi Sec',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        onPressed: yukleniyor ? null : onExcelYukle,
      )),

      if (sonuc.isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: sonuc.startsWith('✅') ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Text(sonuc, style: TextStyle(
              color: sonuc.startsWith('✅') ? Colors.green : Colors.orange,
              fontWeight: FontWeight.w600)),
        ),
      ],

      // Önizleme tablosu
      if (onizleme.isNotEmpty) ...[
        const SizedBox(height: 16),
        Row(children: [
          Text('${onizleme.length} kayit hazir',
              style: const TextStyle(fontWeight: FontWeight.bold, color: _navy)),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _orange, foregroundColor: Colors.white),
            icon: const Icon(Icons.save_outlined, size: 16),
            label: const Text('Hepsini Kaydet'),
            onPressed: onKaydet,
          ),
        ]),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)]),
          child: Column(children: onizleme.take(10).toList().asMap().entries.map((e) {
            final d = e.value;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade100))),
              child: Row(children: [
                CircleAvatar(radius: 14, backgroundColor: _navy.withValues(alpha: 0.1),
                    child: Text('${e.key + 1}',
                        style: const TextStyle(fontSize: 10, color: _navy))),
                const SizedBox(width: 10),
                Expanded(child: Text(d['ad'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                Text(d['veliTel'] ?? d['telefon'] ?? '',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ]),
            );
          }).toList()),
        ),
        if (onizleme.length > 10)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('... ve ${onizleme.length - 10} kayit daha',
                style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ),
      ],
    ]),
  );
}

class _TipBtn extends StatelessWidget {
  final String etiket, deger, secili; final IconData ikon;
  final ValueChanged<String> onSec;
  static const _navy = Color(0xFF1a3a6b);
  const _TipBtn(this.etiket, this.deger, this.ikon, this.secili, this.onSec);
  @override
  Widget build(BuildContext context) {
    final aktif = secili == deger;
    return GestureDetector(
      onTap: () => onSec(deger),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
            color: aktif ? _navy : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(ikon, size: 16, color: aktif ? Colors.white : Colors.grey),
          const SizedBox(width: 6),
          Text(etiket, style: TextStyle(
              color: aktif ? Colors.white : Colors.grey,
              fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      ),
    );
  }
}

// ── PDF SEKME ────────────────────────────────────────────────────
class _PdfYukle extends StatelessWidget {
  final String firmaId, projeId;
  final bool yukleniyor;
  final VoidCallback onPdfYukle;
  static const _navy = Color(0xFF1a3a6b);

  const _PdfYukle({required this.firmaId, required this.projeId,
    required this.yukleniyor, required this.onPdfYukle});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.picture_as_pdf_outlined, color: Colors.red, size: 24),
            SizedBox(width: 10),
            Text('PDF Yukleme', style: TextStyle(fontWeight: FontWeight.bold,
                fontSize: 16, color: _navy)),
          ]),
          const SizedBox(height: 12),
          const Text(
            'Okul kayit formu, veli basvuru formu veya sofor bilgi formunu '
                'PDF olarak yukleyebilirsiniz. Admin inceledikten sonra kayitlar '
                'sisteme eklenecektir.',
            style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3))),
            child: const Row(children: [
              Icon(Icons.info_outline, color: Colors.orange, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text(
                'PDF icindeki veriler manuel olarak incelenecek ve 24 saat icinde sisteme eklenecektir.',
                style: TextStyle(fontSize: 12, color: Colors.orange),
              )),
            ]),
          ),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            icon: yukleniyor
                ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.upload_file_outlined),
            label: Text(yukleniyor ? 'Yukleniyor...' : 'PDF Dosyasi Sec',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: yukleniyor ? null : onPdfYukle,
          )),
        ]),
      ),
      const SizedBox(height: 16),
      // Yüklenen PDF'ler
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('pdf_yuklemeler')
            .where('firmaId', isEqualTo: firmaId)
            .orderBy('tarih', descending: true).limit(10).snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return const SizedBox();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Yuklenen PDF\'ler', style: TextStyle(
                fontWeight: FontWeight.bold, color: _navy)),
            const SizedBox(height: 8),
            ...docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final durum = d['durum'] as String? ?? 'isleniyor';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]),
                child: Row(children: [
                  const Icon(Icons.picture_as_pdf_outlined, color: Colors.red, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(d['dosyaAdi'] ?? 'PDF',
                      style: const TextStyle(fontSize: 13))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: (durum == 'tamamlandi' ? Colors.green : Colors.orange)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(durum, style: TextStyle(fontSize: 11,
                        color: durum == 'tamamlandi' ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.bold)),
                  ),
                ]),
              );
            }),
          ]);
        },
      ),
    ]),
  );
}
