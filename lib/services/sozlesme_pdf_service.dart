import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class SozlesmePdfServisi {
  static Future<void> olusturVePaylasim({
    required String firmaAd,
    required String ogrenciAd,
    required String veliAd,
    required String anneTel,
    String babaTel = '',
    required String adres,
    double? aylikUcret,
    String sozlesmeMetni = '',
    String? tarih,
  }) async {
    final tarihStr = tarih ??
        DateFormat('dd.MM.yyyy').format(DateTime.now());

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (ctx) => _header(firmaAd, tarihStr),
        footer: (ctx) => _footer(ctx),
        build: (ctx) => [
          pw.SizedBox(height: 20),

          // Taraf bilgileri
          _bolum('TARAF BILGILERI'),
          pw.SizedBox(height: 8),
          _tablo([
            ['Firma', firmaAd],
            ['Ogrenci', ogrenciAd],
            ['Veli (Anne)', veliAd],
            ['Anne Telefon', anneTel],
            if (babaTel.isNotEmpty) ['Baba Telefon', babaTel],
            ['Adres', adres],
            if (aylikUcret != null)
              ['Aylik Ucret', '${aylikUcret.toStringAsFixed(0)} TL / ay'],
          ]),

          pw.SizedBox(height: 20),

          // Sözleşme metni
          _bolum('SOZLESME METNI'),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              sozlesmeMetni.isNotEmpty
                  ? sozlesmeMetni
                  : _varsayilanSozlesme(firmaAd),
              style: const pw.TextStyle(
                  fontSize: 10, lineSpacing: 3),
            ),
          ),

          pw.SizedBox(height: 30),

          // Fiyat kutusu
          if (aylikUcret != null) ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#1a3a6b'),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Sozlesmede Belirlenen Aylik Ucret:',
                      style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                      '${aylikUcret.toStringAsFixed(0)} TL',
                      style: pw.TextStyle(
                          color: PdfColor.fromHex('#FF8C00'),
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
            pw.SizedBox(height: 24),
          ],

          // İmza alanları
          _bolum('IMZA'),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              _imzaAlani('Firma Yetkilisi', firmaAd),
              _imzaAlani('Veli / Vasi', veliAd),
            ],
          ),

          pw.SizedBox(height: 20),
          pw.Center(
            child: pw.Text(
              'Bu belge Servisim360 platformu uzerinden dijital olarak onaylanmistir. '
                  'Tarih: $tarihStr',
              style: const pw.TextStyle(
                  fontSize: 8, color: PdfColors.grey600),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name:
      'sozlesme_${ogrenciAd.replaceAll(' ', '_')}_$tarihStr.pdf',
    );
  }

  // Sadece Uint8List döndür (paylaşım için)
  static Future<Uint8List> pdfVerisi({
    required String firmaAd,
    required String ogrenciAd,
    required String veliAd,
    required String anneTel,
    String babaTel = '',
    required String adres,
    double? aylikUcret,
    String sozlesmeMetni = '',
  }) async {
    final tarihStr =
    DateFormat('dd.MM.yyyy').format(DateTime.now());
    final pdf = pw.Document();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      header: (ctx) => _header(firmaAd, tarihStr),
      footer: (ctx) => _footer(ctx),
      build: (ctx) => [
        pw.SizedBox(height: 20),
        _bolum('TARAF BILGILERI'),
        pw.SizedBox(height: 8),
        _tablo([
          ['Firma', firmaAd],
          ['Ogrenci', ogrenciAd],
          ['Veli', veliAd],
          ['Telefon', anneTel],
          ['Adres', adres],
          if (aylikUcret != null)
            ['Ucret', '${aylikUcret.toStringAsFixed(0)} TL/ay'],
        ]),
        pw.SizedBox(height: 20),
        _bolum('SOZLESME'),
        pw.SizedBox(height: 8),
        pw.Text(
          sozlesmeMetni.isNotEmpty
              ? sozlesmeMetni
              : _varsayilanSozlesme(firmaAd),
          style: const pw.TextStyle(fontSize: 10, lineSpacing: 3),
        ),
      ],
    ));

    return pdf.save();
  }

  // ── Yardımcı widget'lar ──────────────────────────────────

  static pw.Widget _header(String firmaAd, String tarih) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#1a3a6b'),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              firmaAd.toUpperCase(),
              style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('SERVIS SOZLESMESI',
                  style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#1a3a6b'))),
              pw.Text(tarih,
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey600)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _footer(pw.Context ctx) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
            top: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Servisim360 | servisim.org.tr',
              style: const pw.TextStyle(
                  fontSize: 8, color: PdfColors.grey)),
          pw.Text('Sayfa ${ctx.pageNumber}/${ctx.pagesCount}',
              style: const pw.TextStyle(
                  fontSize: 8, color: PdfColors.grey)),
        ],
      ),
    );
  }

  static pw.Widget _bolum(String baslik) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(
          horizontal: 10, vertical: 5),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#f0f4ff'),
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border(
            left: pw.BorderSide(
                color: PdfColor.fromHex('#1a3a6b'), width: 3)),
      ),
      child: pw.Text(
        baslik,
        style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: PdfColor.fromHex('#1a3a6b')),
      ),
    );
  }

  static pw.Widget _tablo(List<List<String>> satirlar) {
    return pw.Table(
      border: pw.TableBorder.all(
          color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(110),
        1: const pw.FlexColumnWidth(),
      },
      children: satirlar.map((satir) {
        return pw.TableRow(children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(satir[0],
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(6),
            child: pw.Text(satir[1],
                style: const pw.TextStyle(fontSize: 10)),
          ),
        ]);
      }).toList(),
    );
  }

  static pw.Widget _imzaAlani(String rol, String ad) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          width: 160,
          height: 70,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400),
            borderRadius: pw.BorderRadius.circular(4),
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(rol,
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700)),
        pw.Text(ad,
            style: const pw.TextStyle(
                fontSize: 9, color: PdfColors.grey)),
      ],
    );
  }

  static String _varsayilanSozlesme(String firmaAd) => '''
$firmaAd OKUL SERVIS HIZMETLERI SOZLESMESI

MADDE 1 - KAPSAM
Bu sozlesme, $firmaAd ile yukarida bilgileri yazili ogrencinin velisi/vasisi arasinda akdedilmistir. Sozlesme bir egitim-ogretim donemi (Eylul - Haziran) icin gecerlidir.

MADDE 2 - UCRET VE ODEME
Servis ucreti yukarida belirtilmistir. Odeme her ayin 1-5 gunleri arasinda yapilir. Gecikme durumunda aylik yuzde bes (5) gecikme faizi uygulanir.

MADDE 3 - IPTAL VE IADE
Sozlesme iptali en az 15 (on bes) gun oncesinde yazili olarak bildirilmelidir. Donem ortasinda yapilan iptallerden kalan ay ucreti iade edilmez.

MADDE 4 - SERVIS KURALLARI
- Ogrenci, belirlenen durakta hazir olmalidir.
- Servis bekleme suresi 3 (uc) dakikadir.
- Ogrencinin servise binmeyecegi durumlar en az 1 saat oncesinden uygulama uzerinden bildirilmelidir.
- Servis guzergahinda degisiklik talepleri yazili olarak yapilmalidir.

MADDE 5 - SORUMLULUK
Firma; ogrenciyi belirlenen duraktan teslim alip egitim kurumuna birakma ve donus saatinde teslim alma islemlerinden sorumludur.

MADDE 6 - VERI GIZLILIGI
Taraflara ait kisisel veriler, 6698 sayili KVKK kapsaminda islenmekte olup ucuncu taraflarla paylasilmamaktadir.

Is bu sozlesme, taraflarca okunup anlasilarak kabul edilmistir.
''';
}
