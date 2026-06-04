import 'package:flutter/material.dart';
import 'yardim_widget.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/session_service.dart';

class QrCheckInScreen extends StatefulWidget {
  final String tip; // 'binis' veya 'inis'
  const QrCheckInScreen({super.key, required this.tip});

  @override
  State<QrCheckInScreen> createState() => _QrCheckInScreenState();
}

class _QrCheckInScreenState extends State<QrCheckInScreen> {
  static const _navy   = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);

  bool    _isleniyor  = false;
  bool    _tamamlandi = false;
  String? _sonucMesaj;
  bool    _basarili   = false;

  // Manuel QR id girisi (web icin)
  final _qrCtrl = TextEditingController();

  @override
  void dispose() {
    _qrCtrl.dispose();
    super.dispose();
  }

  Future<void> _qrIsle(String qrDeger) async {
    if (_isleniyor || _tamamlandi) return;

    if (!qrDeger.startsWith('servisim360:ogrenci:')) {
      _sonucGoster(false, 'Gecersiz QR kod');
      return;
    }

    final ogrenciId = qrDeger.replaceFirst('servisim360:ogrenci:', '');
    if (ogrenciId.isEmpty) {
      _sonucGoster(false, 'QR bozuk');
      return;
    }

    setState(() => _isleniyor = true);

    try {
      final uid     = FirebaseAuth.instance.currentUser?.uid ?? '';
      final firmaId = await SessionService.instance.firmaIdAl() ?? '';

      final ogrDoc = await FirebaseFirestore.instance
          .collection('students').doc(ogrenciId).get();
      if (!ogrDoc.exists) {
        _sonucGoster(false, 'Ogrenci bulunamadi');
        return;
      }

      final ogrData = ogrDoc.data()!;
      final ogrAdi  = ogrData['ad'] as String? ?? 'Ogrenci';

      String surucuDocId = '';
      final dSnap = await FirebaseFirestore.instance
          .collection('drivers')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();
      if (dSnap.docs.isNotEmpty) {
        surucuDocId = dSnap.docs.first.id;
      }

      final ogrSurucuId = ogrData['surucuId'] ?? '';
      if (surucuDocId.isNotEmpty &&
          ogrSurucuId.isNotEmpty &&
          ogrSurucuId != surucuDocId) {
        _sonucGoster(false, '$ogrAdi farkli servise atanmis!');
        return;
      }

      final now = FieldValue.serverTimestamp();

      if (widget.tip == 'binis') {
        await FirebaseFirestore.instance
            .collection('students')
            .doc(ogrenciId)
            .update({
          'bindi':      true,
          'bindiZaman': now,
          'surucuId':   surucuDocId.isNotEmpty ? surucuDocId : ogrSurucuId,
        });

        if (surucuDocId.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('guzergah_kayitlar')
              .add({
            'surucuId':  surucuDocId,
            'ogrenciId': ogrenciId,
            'ogrenciAd': ogrAdi,
            'firmaId':   firmaId,
            'tip':       'binis',
            'zaman':     now,
          });
        }

        final veliId = ogrData['veliId'] ?? '';
        if (veliId.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('notifications')
              .add({
            'aliciId': veliId,
            'baslik':  'Servise Bindi',
            'mesaj':   '$ogrAdi servise bindi.',
            'tip':     'binis',
            'firmaId': firmaId,
            'okundu':  false,
            'tarih':   now,
          });
        }

        _sonucGoster(true, '$ogrAdi servise BINDI');
      } else {
        await FirebaseFirestore.instance
            .collection('students')
            .doc(ogrenciId)
            .update({
          'bindi':    false,
          'indiZaman': now,
        });

        final veliId = ogrData['veliId'] ?? '';
        if (veliId.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('notifications')
              .add({
            'aliciId': veliId,
            'baslik':  'Servisten Indi',
            'mesaj':   '$ogrAdi servisten indi.',
            'tip':     'inis',
            'firmaId': firmaId,
            'okundu':  false,
            'tarih':   now,
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
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() { _tamamlandi = false; _sonucMesaj = null; });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: Text(
          widget.tip == 'binis' ? 'Binis Tara' : 'Inis Tara',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: kIsWeb ? _webGorunu() : _mobilGorunu(),
    );
  }

  // ── Web: Manuel ID girisi ──────────────────────────────────────
  Widget _webGorunu() {
    return Center(
      child: Container(
        width: 400,
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_scanner, size: 64, color: _navy),
            const SizedBox(height: 16),
            const Text('QR Kod ID Girin',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: _navy)),
            const SizedBox(height: 8),
            Text(
              'Web\'de kamera tarama yoktur.\n'
                  'Ogrenci ID\'sini girerek islemi tamamlayin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _qrCtrl,
              decoration: InputDecoration(
                labelText: 'Ogrenci ID',
                hintText: 'servisim360:ogrenci:xxx',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            if (_sonucMesaj != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _basarili
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      _basarili ? Icons.check_circle : Icons.cancel,
                      color: _basarili ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_sonucMesaj!,
                          style: TextStyle(
                              color: _basarili ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isleniyor
                    ? null
                    : () {
                  final val = _qrCtrl.text.trim();
                  if (val.isEmpty) return;
                  final qr = val.startsWith('servisim360:ogrenci:')
                      ? val
                      : 'servisim360:ogrenci:$val';
                  _qrIsle(qr);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isleniyor
                    ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                    : Icon(widget.tip == 'binis'
                    ? Icons.login
                    : Icons.logout),
                label: Text(widget.tip == 'binis' ? 'Bindirdi' : 'Indirdi',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Mobil: Bilgi mesaji (mobile_scanner eklenince aktif olacak) ─
  Widget _mobilGorunu() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.qr_code_scanner, size: 80, color: Colors.white54),
            const SizedBox(height: 24),
            const Text(
              'QR Tarama',
              style: TextStyle(color: Colors.white,
                  fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              widget.tip == 'binis'
                  ? 'Ogrencinin binis QR kodunu tarayin'
                  : 'Ogrencinin inis QR kodunu tarayin',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _orange, width: 2),
              ),
              child: const Text(
                'Kamera modulu yakinda aktif edilecek.\n'
                    'Su an manuel ID girisi ile kullanabilirsiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
            const SizedBox(height: 32),
            // Manuel giris butonu
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _manuelGirisDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.keyboard),
                label: const Text('Manuel ID Gir',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _manuelGirisDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ogrenci ID'),
        content: TextField(
          controller: _qrCtrl,
          decoration: const InputDecoration(
            hintText: 'Ogrenci ID giriniz',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          YardimButonu(ekranAdi: 'Kayitlar'),
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Iptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _navy),
            onPressed: () {
              Navigator.pop(ctx);
              final val = _qrCtrl.text.trim();
              if (val.isEmpty) return;
              final qr = val.startsWith('servisim360:ogrenci:')
                  ? val
                  : 'servisim360:ogrenci:$val';
              _qrIsle(qr);
            },
            child: const Text('Tamam',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ── Ogrenci QR Kodu (Veli panelinde gosterilir) ────────────────────
class OgrenciQrKodu extends StatelessWidget {
  final String ogrenciId, ogrenciAdi;
  const OgrenciQrKodu(
      {super.key, required this.ogrenciId, required this.ogrenciAdi});

  @override
  Widget build(BuildContext context) {
    const navy    = Color(0xFF1a3a6b);
    final qrDeger = 'servisim360:ogrenci:$ogrenciId';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        title: Text('$ogrenciAdi - QR'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(ogrenciAdi,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: navy)),
              const SizedBox(height: 6),
              Text('Servis binis/inis QR kodu',
                  style: TextStyle(
                      fontSize: 14, color: Colors.grey.shade600)),
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
                        offset: const Offset(0, 4))
                  ],
                  border: Border.all(
                      color: navy.withValues(alpha: 0.2), width: 2),
                ),
                child: QrImageView(
                  data: qrDeger,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square, color: navy),
                  dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF0d1f3c)),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: const Color(0xFFF5F6FA),
                    borderRadius: BorderRadius.circular(12)),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: navy, size: 20),
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