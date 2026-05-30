import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Sozlesme ve fatura PDF olusturma servisi (Web + Mobil)
class SozlesmeService {

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
              pw.Center(child: pw.Column(children: [
                pw.Text('SERVIS HIZMET SOZLESMESI',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(firmaAdi,
                    style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Divider(),
              ])),
              pw.SizedBox(height: 16),
              _satirEkle('Sozlesme Tarihi', baslangicTarihi),
              pw.SizedBox(height: 20),
              _baslikEkle('VELI BILGILERI'),
              _satirEkle('Veli Adi Soyadi', veliAd),
              _satirEkle('Telefon', veliTelefon),
              pw.SizedBox(height: 12),
              _baslikEkle('OGRENCI BILGILERI'),
              _satirEkle('Ogrenci Adi', ogrenciAd),
              _satirEkle('Okul', okulAd),
              _satirEkle('Adres', adres),
              pw.SizedBox(height: 12),
              _baslikEkle('SERVIS BILGILERI'),
              _satirEkle('Sofor', surucuAdi),
              _satirEkle('Arac Plakasi', plaka),
              _satirEkle('Aylik Ucret', '${aylikUcret.toStringAsFixed(2)} TL'),
              pw.SizedBox(height: 20),
              _baslikEkle('SOZLESME KOSULLARI'),
              _maddeEkle('1. Servis hizmeti okul gunlerinde saglanacaktir.'),
              _maddeEkle('2. Aylik ucret her ayin ilk 5 is gunu icinde odenecektir.'),
              _maddeEkle('3. Devamsizlik durumunda en az 1 gun onceden bildirim yapilacaktir.'),
              _maddeEkle('4. Guzergah degisikliklerinde taraflar karssilikli anlasacaktir.'),
              _maddeEkle('5. Sozlesme iki tarafin onayi olmadan feshedilemez.'),
              pw.SizedBox(height: 30),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
                    pw.Text('VELI', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 40),
                    pw.Text(veliAd),
                  ]),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
                    pw.Text('FIRMA', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 40),
                    pw.Text(firmaAdi),
                  ]),
                ],
              ),
            ],
          );
        },
      ));
      final dosyaAdi = 'sozlesme_${veliAd.replaceAll(' ', '_')}_$baslangicTarihi.pdf';
      return await _kaydetVeAc(pdf, dosyaAdi);
    } catch (e) {
      return null;
    }
  }

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
              _satirEkle('Fatura No', 'FAT-${faturaSayisi.toString().padLeft(4, '0')}'),
              _satirEkle('Donem', ay),
              _satirEkle('Tarih', _bugunStr()),
              pw.SizedBox(height: 16),
              _baslikEkle('ALICI BILGILERI'),
              _satirEkle('Veli Adi', veliAd),
              _satirEkle('Ogrenci', ogrenciAd),
              pw.SizedBox(height: 16),
              _baslikEkle('ODEME DETAYI'),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('$ay Donemi Servis Ucreti'),
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
              pw.Center(child: pw.Text('Tesekkur ederiz.',
                  style: const pw.TextStyle(color: PdfColors.grey600))),
            ],
          );
        },
      ));
      final dosyaAdi = 'fatura_${veliAd.replaceAll(' ', '_')}_$ay.pdf';
      return await _kaydetVeAc(pdf, dosyaAdi);
    } catch (e) {
      return null;
    }
  }

  // Web + Mobil PDF ac
  static Future<String?> _kaydetVeAc(pw.Document pdf, String dosyaAdi) async {
    final bytes = await pdf.save();
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: dosyaAdi,
    );
    return dosyaAdi;
  }

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
}