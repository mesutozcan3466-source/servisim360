import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/session_service.dart';

// ════════════════════════════════════════════════════════════════
//  QR CHECK-IN EKRANI — Cloud Functions gerektirmez
//  Direkt Firestore'a yazar:
//   binis → students/{id}.bindi = true, bindiZaman, surucuId
//   inis  → students/{id}.bindi = false, indiZaman
//  Durak sırası → surucuId'ye göre güncellenip
//  notifications koleksiyonuna bildirim yazılır
// ════════════════════════════════════════════════════════════════
class QrCheckInScreen extends StatefulWidget {
  final String tip; // 'binis' veya 'inis'
  const QrCheckInScreen({super.key, required this.tip});
  @override
  State<QrCheckInScreen> createState() => _QrCheckInScreenState();
}

class _QrCheckInScreenState extends State<QrCheckInScreen> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _orange  = Color(0xFFFF8C00);

  final MobileScannerController _kamera = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  bool    _isleniyor  = false;
  bool    _tamamlandi = false;
  String? _sonucMesaj;
  bool    _basarili   = false;
  String? _sonucAd;

  @override
  void dispose() { _kamera.dispose(); super.dispose(); }

  Future<void> _qrOkundu(BarcodeCapture capture) async {
    if (_isleniyor || _tamamlandi) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;
    final qrDeger = barcode!.rawValue!;

    if (!qrDeger.startsWith('servisim360:ogrenci:')) {
      _sonucGoster(false, 'Gecersiz QR kod'); return;
    }

    final ogrenciId = qrDeger.replaceFirst('servisim360:ogrenci:', '');
    if (ogrenciId.isEmpty) { _sonucGoster(false, 'QR bozuk'); return; }

    setState(() => _isleniyor = true);
    _kamera.stop();

    try {
      final uid      = FirebaseAuth.instance.currentUser?.uid ?? '';
      final firmaId  = await SessionService.instance.firmaldAl() ?? '';

      // Öğrenci belgesini çek
      final ogrDoc = await FirebaseFirestore.instance
          .collection('students').doc(ogrenciId).get();
      if (!ogrDoc.exists) {
        _sonucGoster(false, 'Ogrenci bulunamadi'); return;
      }
      final ogrData = ogrDoc.data()!;
      final ogrAdi  = ogrData['ad'] as String? ?? 'Ogrenci';

      // Şoförü uid ile bul
      String surucuDocId = '';
      final dSnap = await FirebaseFirestore.instance
          .collection('drivers')
          .where('uid', isEqualTo: uid)
          .limit(1).get();
      if (dSnap.docs.isNotEmpty) {
        surucuDocId = dSnap.docs.first.id;
      }

      // Güvenlik: bu öğrenci bu şoföre atanmış mı?
      final ogrSurucuId = ogrData['surucuId'] ?? ogrData['soforId'] ?? '';
      if (surucuDocId.isNotEmpty &&
          ogrSurucuId.isNotEmpty &&
          ogrSurucuId != surucuDocId) {
        _sonucGoster(false, '$ogrAdi farkli servise atanmis!'); return;
      }

      // Firestore güncelle
      final now = FieldValue.serverTimestamp();
      if (widget.tip == 'binis') {
        await FirebaseFirestore.instance.collection('students').doc(ogrenciId).update({
          'bindi':      true,
          'bindiZaman': now,
          'surucuId':   surucuDocId.isNotEmpty ? surucuDocId : ogrSurucuId,
        });

        // Güzergah kaydına ekle
        if (surucuDocId.isNotEmpty) {
          await FirebaseFirestore.instance.collection('guzergah_kayitlar').add({
            'surucuId':   surucuDocId,
            'ogrenciId':  ogrenciId,
            'ogrenciAd':  ogrAdi,
            'firmaId':    firmaId,
            'tip':        'binis',
            'zaman':      now,
          });
        }

        // Veliye bildirim yaz
        final veliId = ogrData['veliId'] ?? '';
        if (veliId.isNotEmpty) {
          await FirebaseFirestore.instance.collection('notifications').add({
            'aliciId':  veliId,
            'baslik':   'Servise Bindi',
            'mesaj':    '$ogrAdi servise bindi.',
            'tip':      'binis',
            'firmaId':  firmaId,
            'okundu':   false,
            'tarih':    now,
          });
        }

        _sonucGoster(true, '$ogrAdi servise BINDI');
      } else {
        // inis
        await FirebaseFirestore.instance.collection('students').doc(ogrenciId).update({
          'bindi':    false,
          'indiZaman': now,
        });

        // Veliye bildirim yaz
        final veliId = ogrData['veliId'] ?? '';
        if (veliId.isNotEmpty) {
          await FirebaseFirestore.instance.collection('notifications').add({
            'aliciId':  veliId,
            'baslik':   'Servisten Indi',
            'mesaj':    '$ogrAdi servisten indi.',
            'tip':      'inis',
            'firmaId':  firmaId,
            'okundu':   false,
            'tarih':    now,
          });
        }

        _sonucGoster(true, '$ogrAdi servisten INDI');
      }
    } catch (e) {
      _sonucGoster(false, 'Hata: $e');
    }
  }

  void _sonucGoster(bool basarili, String mesaj) {
    if (!mounted) return;
    setState(() {
      _isleniyor  = false;
      _tamamlandi = true;
      _basarili   = basarili;
      _sonucMesaj = mesaj;
    });
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() { _tamamlandi = false; _sonucMesaj = null; });
        _kamera.start();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: _navy,
        title: Text(widget.tip == 'binis' ? 'Binis Tara' : 'Inis Tara',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: const Icon(Icons.flash_on, color: Colors.white),
              onPressed: () => _kamera.toggleTorch()),
        ],
      ),
      body: Stack(children: [
        MobileScanner(controller: _kamera, onDetect: _qrOkundu),

        // Tarama çerçevesi
        Center(child: Container(
          width: 260, height: 260,
          decoration: BoxDecoration(
            border: Border.all(
              color: _tamamlandi
                  ? (_basarili ? Colors.green : Colors.red) : _orange,
              width: 3,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: _tamamlandi
              ? Center(child: Icon(
              _basarili ? Icons.check_circle : Icons.cancel,
              color: _basarili ? Colors.green : Colors.red, size: 80))
              : null,
        )),

        // Üst bilgi
        Positioned(top: 0, left: 0, right: 0,
          child: Container(
            color: Colors.black54,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              widget.tip == 'binis'
                  ? 'Ogrencinin binis QR kodunu tarayin'
                  : 'Ogrencinin inis QR kodunu tarayin',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ),

        // Alt sonuç
        if (_sonucMesaj != null)
          Positioned(bottom: 0, left: 0, right: 0,
            child: Container(
              color: _basarili
                  ? Colors.green.withValues(alpha: 0.92)
                  : Colors.red.withValues(alpha: 0.92),
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(_basarili ? Icons.check_circle : Icons.cancel,
                    color: Colors.white, size: 36),
                const SizedBox(height: 8),
                Text(_sonucMesaj!, textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ]),
            ),
          ),

        if (_isleniyor)
          Container(color: Colors.black54,
              child: const Center(child: CircularProgressIndicator(color: _orange))),
      ]),
    );
  }
}

// Öğrenci QR Kodu widget (veli panelinde gösterilir — değişmedi)
class OgrenciQrKodu extends StatelessWidget {
  final String ogrenciId, ogrenciAdi;
  const OgrenciQrKodu({super.key, required this.ogrenciId, required this.ogrenciAdi});

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF1a3a6b);
    final qrDeger = 'servisim360:ogrenci:$ogrenciId';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: navy, foregroundColor: Colors.white,
        title: Text('$ogrenciAdi - QR'),
      ),
      body: Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(ogrenciAdi, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: navy)),
          const SizedBox(height: 6),
          Text('Servis binis/inis QR kodu', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 4))],
                border: Border.all(color: navy.withValues(alpha: 0.2), width: 2)),
            child: QrImageView(
              data: qrDeger, version: QrVersions.auto, size: 220,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: navy),
              dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square, color: Color(0xFF0d1f3c)),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFF5F6FA), borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [
              Icon(Icons.info_outline, color: navy, size: 20),
              SizedBox(width: 10),
              Expanded(child: Text(
                'Bu QR kodu soforunuze gosterin. Servise binerken ve inerken taratilacaktir.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              )),
            ]),
          ),
        ]),
      )),
    );
  }
}
