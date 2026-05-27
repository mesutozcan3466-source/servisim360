import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/session_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// QR CHECK-IN EKRANI
// ═══════════════════════════════════════════════════════════════════════════

class QrCheckInScreen extends StatefulWidget {
  final String tip; // 'binis' veya 'inis'
  const QrCheckInScreen({super.key, required this.tip});

  @override
  State<QrCheckInScreen> createState() => _QrCheckInScreenState();
}

class _QrCheckInScreenState extends State<QrCheckInScreen> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  final MobileScannerController _kamera = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  bool _isleniyor  = false;
  bool _tamamlandi = false;
  String? _sonucMesaj;
  bool _basarili   = false;

  @override
  void dispose() {
    _kamera.dispose();
    super.dispose();
  }

  Future<void> _qrOkundu(BarcodeCapture capture) async {
    if (_isleniyor || _tamamlandi) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    final qrDeger = barcode!.rawValue!;

    if (!qrDeger.startsWith('servisim360:ogrenci:')) {
      _sonucGoster(false, 'Gecersiz QR kod');
      return;
    }

    final ogrenciId = qrDeger.replaceFirst('servisim360:ogrenci:', '');
    if (ogrenciId.isEmpty) {
      _sonucGoster(false, 'QR kod bozuk');
      return;
    }

    setState(() => _isleniyor = true);
    _kamera.stop();

    try {
      // uid dogrudan FirebaseAuth'tan al — SessionService.uidAl() yok
      final surucuId = FirebaseAuth.instance.currentUser?.uid ?? '';
      final firmaId  = await SessionService.instance.firmaldAl() ?? '';

      final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');
      final callable  = functions.httpsCallable('qrCheckIn');

      final sonuc = await callable.call({
        'ogrenciId': ogrenciId,
        'tip':       widget.tip,
        'surucuId':  surucuId,
        'firmaId':   firmaId,
      });

      final data   = sonuc.data as Map<String, dynamic>;
      final ogrAdi = data['ogrenciAdi'] ?? 'Ogrenci';
      final tipStr = widget.tip == 'binis' ? 'bindi' : 'indi';

      _sonucGoster(true, '$ogrAdi servise $tipStr');
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
        title: Text(
          widget.tip == 'binis' ? 'Binis Tara' : 'Inis Tara',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.white),
            onPressed: () => _kamera.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _kamera, onDetect: _qrOkundu),

          // Tarama cercevesi
          Center(
            child: Container(
              width: 260, height: 260,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _tamamlandi
                      ? (_basarili ? Colors.green : Colors.red)
                      : _turuncu,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: _tamamlandi
                  ? Center(
                child: Icon(
                  _basarili ? Icons.check_circle : Icons.cancel,
                  color: _basarili ? Colors.green : Colors.red,
                  size: 80,
                ),
              )
                  : null,
            ),
          ),

          // Ust bilgi
          Positioned(
            top: 0, left: 0, right: 0,
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

          // Alt sonuc
          if (_sonucMesaj != null)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                color: _basarili
                    ? Colors.green.withValues(alpha: 0.9)
                    : Colors.red.withValues(alpha: 0.9),
                padding: const EdgeInsets.all(20),
                child: Text(
                  _sonucMesaj!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // Yukleniyor
          if (_isleniyor)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF8C00)),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// OGRENCI QR KODU (Veli panelinde gösterilir)
// ═══════════════════════════════════════════════════════════════════════════

class OgrenciQrKodu extends StatelessWidget {
  final String ogrenciId;
  final String ogrenciAdi;

  const OgrenciQrKodu({
    super.key,
    required this.ogrenciId,
    required this.ogrenciAdi,
  });

  @override
  Widget build(BuildContext context) {
    final qrDeger = 'servisim360:ogrenci:$ogrenciId';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          '$ogrenciAdi - QR Kodu',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1a3a6b),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                ogrenciAdi,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0d1f3c),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Servis binis/inis QR kodu',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFF1a3a6b).withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: QrImageView(
                  data: qrDeger,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF1a3a6b),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF0d1f3c),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F6FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Color(0xFF1a3a6b), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Bu QR kodu soforunuze gosterin. '
                            'Servise binerken ve inerken taratilacaktir.',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
