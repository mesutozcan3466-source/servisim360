import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_file/open_file.dart';

/// Sözleşme ve fatura PDF oluşturma servisi
class SozlesmeService {
  // ── Sözleşme PDF Oluştur ────────────────────────────────────────────────────
  static Future<String?> sozlesmeOlustur({
    required String veliAd,
    required String veliTelefon,
    required String ogrenciAd,
    required String okulAd,
    required String adres,
    required double aylikUcret,
    required String baslangicTarihi,
    required String firmaAdi,
    required String surucuAdi,
    required String plaka,
  }) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Başlık
              pw.Center(child: pw.Column(children: [
                pw.Text('SERVİS HİZMET SÖZLEŞMESİ',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(firmaAdi,
                    style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Divider(),
              ])),
              pw.SizedBox(height: 16),

              _satirEkle('Sözleşme Tarihi',   baslangicTarihi),
              pw.SizedBox(height: 20),

              // Veli Bilgileri
              _baslikEkle('VELİ BİLGİLERİ'),
              _satirEkle('Veli Adı Soyadı',   veliAd),
              _satirEkle('Telefon',            veliTelefon),
              pw.SizedBox(height: 12),

              // Öğrenci Bilgileri
              _baslikEkle('ÖĞRENCİ BİLGİLERİ'),
              _satirEkle('Öğrenci Adı',        ogrenciAd),
              _satirEkle('Okul',               okulAd),
              _satirEkle('Adres',              adres),
              pw.SizedBox(height: 12),

              // Servis Bilgileri
              _baslikEkle('SERVİS BİLGİLERİ'),
              _satirEkle('Şoför',              surucuAdi),
              _satirEkle('Araç Plakası',       plaka),
              _satirEkle('Aylık Ücret',        '${aylikUcret.toStringAsFixed(2)} TL'),
              pw.SizedBox(height: 20),

              // Maddeler
              _baslikEkle('SÖZLEŞME KOŞULLARI'),
              _maddeEkle('1. Servis hizmeti okul günlerinde sağlanacaktır.'),
              _maddeEkle('2. Aylık ücret her ayın ilk 5 iş günü içinde ödenecektir.'),
              _maddeEkle('3. Devamsızlık durumunda en az 1 gün önceden bildirim yapılacaktır.'),
              _maddeEkle('4. Güzergah değişikliklerinde taraflar karşılıklı anlaşacaktır.'),
              _maddeEkle('5. Sözleşme iki tarafın onayı olmadan feshedilemez.'),
              pw.SizedBox(height: 30),

              // İmzalar
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
                    pw.Text('VELİ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 40),
                    pw.Text(veliAd),
                  ]),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
                    pw.Text('FİRMA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 40),
                    pw.Text(firmaAdi),
                  ]),
                ],
              ),
            ],
          );
        },
      ));

      return await _kaydetVeAc(pdf, 'sozlesme_${veliAd.replaceAll(' ', '_')}_$baslangicTarihi.pdf');
    } catch (e) {
      return null;
    }
  }

  // ── Fatura PDF Oluştur ──────────────────────────────────────────────────────
  static Future<String?> faturaOlustur({
    required String veliAd,
    required String ogrenciAd,
    required String firmaAdi,
    required double tutar,
    required String ay,
    required int faturaSayisi,
  }) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Column(children: [
                pw.Text('FATURA',
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(firmaAdi,
                    style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Divider(),
              ])),
              pw.SizedBox(height: 16),

              _satirEkle('Fatura No',    'FAT-${faturaSayisi.toString().padLeft(4, '0')}'),
              _satirEkle('Dönem',        ay),
              _satirEkle('Tarih',        _bugunStr()),
              pw.SizedBox(height: 16),

              _baslikEkle('ALICI BİLGİLERİ'),
              _satirEkle('Veli Adı',     veliAd),
              _satirEkle('Öğrenci',      ogrenciAd),
              pw.SizedBox(height: 16),

              _baslikEkle('ÖDEME DETAYI'),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('$ay Dönemi Servis Ücreti'),
                    pw.Text('${tutar.toStringAsFixed(2)} TL',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text('TOPLAM: ${tutar.toStringAsFixed(2)} TL',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 40),
              pw.Center(child: pw.Text('Teşekkür ederiz.',
                  style: const pw.TextStyle(color: PdfColors.grey600))),
            ],
          );
        },
      ));

      return await _kaydetVeAc(pdf, 'fatura_${veliAd.replaceAll(' ', '_')}_$ay.pdf');
    } catch (e) {
      return null;
    }
  }

  // ── Yardımcı ────────────────────────────────────────────────────────────────
  static pw.Widget _baslikEkle(String baslik) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Text(baslik,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
  );

  static pw.Widget _satirEkle(String etiket, String deger) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(children: [
      pw.SizedBox(width: 140,
          child: pw.Text(etiket,
              style: const pw.TextStyle(color: PdfColors.grey700))),
      pw.Text(': '),
      pw.Expanded(child: pw.Text(deger,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
    ]),
  );

  static pw.Widget _maddeEkle(String metin) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 4, left: 8),
    child: pw.Text(metin, style: const pw.TextStyle(fontSize: 10)),
  );

  static String _bugunStr() {
    final d = DateTime.now();
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  static Future<String?> _kaydetVeAc(pw.Document pdf, String dosyaAdi) async {
    final dir  = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$dosyaAdi');
    await file.writeAsBytes(await pdf.save());
    await OpenFile.open(file.path);
    return file.path;
  }
}
