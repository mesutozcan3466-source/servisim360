import 'package:flutter/material.dart';
import 'yardim_widget.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/session_service.dart';

class QrAfisScreen extends StatefulWidget {
  const QrAfisScreen({super.key});
  @override
  State<QrAfisScreen> createState() => _QrAfisScreenState();
}

class _QrAfisScreenState extends State<QrAfisScreen> {
  static const _navy   = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);
  static const _base   = 'https://servis360-15b4a.web.app/kayit';

  List<Map<String, dynamic>> _linkler = [];
  bool _yukleniyor = true;
  String _firmaAdi = '';
  String _projeAdi = '';
  bool _olusturuluyor = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final firmaId = await SessionService.instance.firmaIdAl() ?? '';
    if (firmaId.isEmpty) {
      setState(() => _yukleniyor = false);
      return;
    }
    final projeId = SessionService.instance.aktifProjeld ?? '';
    _projeAdi     = SessionService.instance.aktifProjeAdi ?? '';

    final firmaDoc = await FirebaseFirestore.instance.collection('firms').doc(firmaId).get();
    _firmaAdi = firmaDoc.data()?['firmaAdi'] ?? firmaDoc.data()?['ad'] ?? '';

    // projeId boşsa tüm firma linklerini getir
    var query = FirebaseFirestore.instance
        .collection('kayit_linkleri')
        .where('firmaId', isEqualTo: firmaId)
        .where('aktif', isEqualTo: true);

    if (projeId.isNotEmpty) {
      query = query.where('projeId', isEqualTo: projeId);
    }

    final snap = await query.get();

    setState(() {
      _linkler = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      _yukleniyor = false;
    });
  }

  Future<void> _yeniLinkOlustur() async {
    setState(() => _olusturuluyor = true);
    try {
      final firmaId = await SessionService.instance.firmaIdAl() ?? '';
      final projeId = SessionService.instance.aktifProjeld ?? '';
      final bitis   = DateTime.now().add(const Duration(days: 365)); // 1 yıl geçerli

      final docRef = await FirebaseFirestore.instance.collection('kayit_linkleri').add({
        'firmaId':         firmaId,
        'firmaAdi':        _firmaAdi,
        'projeId':         projeId,
        'projeAdi':        _projeAdi,
        'ozelMesaj':       '',
        'aktif':           true,
        'kullanim':        0,
        'gecerlilikGun':   365,
        'gecerlilikBitis': Timestamp.fromDate(bitis),
        'olusturma':       Timestamp.now(),
        'tip':             'qr_afis',
      });

      setState(() {
        _linkler.insert(0, {
          'id':      docRef.id,
          'projeAdi': _projeAdi,
          'kullanim': 0,
          'gecerlilikBitis': Timestamp.fromDate(bitis),
        });
        _olusturuluyor = false;
      });
    } catch (e) {
      setState(() => _olusturuluyor = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white,
        title: const Text('QR Kod Afis', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          YardimButonu(ekranAdi: 'Kayitlar'),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _olusturuluyor ? null : _yeniLinkOlustur,
            tooltip: 'Yeni QR Link',
          ),
        ],
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : _linkler.isEmpty
          ? _bosEkran()
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _linkler.length,
        itemBuilder: (_, i) => _QrKart(
          link:     _linkler[i],
          baseUrl:  _base,
          firmaAdi: _firmaAdi,
          projeAdi: _projeAdi,
          onSil: () async {
            await FirebaseFirestore.instance
                .collection('kayit_linkleri')
                .doc(_linkler[i]['id'])
                .update({'aktif': false});
            setState(() => _linkler.removeAt(i));
          },
        ),
      ),
    );
  }

  Widget _bosEkran() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.qr_code_2, size: 80, color: Colors.grey[300]),
    const SizedBox(height: 16),
    const Text('Henuz QR kod olusturulmamis', style: TextStyle(color: Colors.grey, fontSize: 15)),
    const SizedBox(height: 24),
    ElevatedButton.icon(
      style: ElevatedButton.styleFrom(backgroundColor: _orange, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      onPressed: _olusturuluyor ? null : _yeniLinkOlustur,
      icon: _olusturuluyor
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Icon(Icons.qr_code_outlined),
      label: const Text('QR Kod Olustur', style: TextStyle(fontWeight: FontWeight.bold)),
    ),
  ]));
}

class _QrKart extends StatelessWidget {
  final Map<String, dynamic> link;
  final String baseUrl, firmaAdi, projeAdi;
  final VoidCallback onSil;
  static const _navy   = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);

  const _QrKart({required this.link, required this.baseUrl,
    required this.firmaAdi, required this.projeAdi, required this.onSil});

  @override
  Widget build(BuildContext context) {
    final linkId   = link['id'] as String;
    final url      = '$baseUrl?link=$linkId';
    final kullanim = link['kullanim'] ?? 0;
    final Timestamp? bitis = link['gecerlilikBitis'];
    String bitisStr = '';
    if (bitis != null) {
      final d = bitis.toDate();
      bitisStr = '${d.day}.${d.month}.${d.year}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
              color: _navy,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))),
          child: Row(children: [
            const Icon(Icons.qr_code_2, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(firmaAdi, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              if (projeAdi.isNotEmpty)
                Text(projeAdi, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
              child: Text('$kullanim kayit', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),

        // QR Kod — büyük ve net
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _navy.withValues(alpha: 0.1), width: 2),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
              ),
              child: QrImageView(
                data: url,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: _navy),
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: _navy),
              ),
            ),
            const SizedBox(height: 16),

            // Firma + proje bilgisi altında
            Text(firmaAdi, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _navy)),
            if (projeAdi.isNotEmpty)
              Text(projeAdi, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 6),
            const Text('Bu QR kodu okutarak\nservis kaydınızı tamamlayın',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.4)),
            if (bitisStr.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Gecerlilik: $bitisStr', style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ]),
        ),

        // Butonlar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Row(children: [
            Expanded(child: _AkBtn(Icons.copy_outlined, 'Link Kopyala', _navy, () {
              Clipboard.setData(ClipboardData(text: url));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Link kopyalandi!'), backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating));
            })),
            const SizedBox(width: 8),
            Expanded(child: _AkBtn(Icons.chat, 'WhatsApp', const Color(0xFF25D366), () async {
              final msg = 'Servis kaydı için QR kodu okutun veya tıklayın:\n$url';
              final wp  = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(msg)}');
              await launchUrl(wp, mode: LaunchMode.externalApplication);
            })),
            const SizedBox(width: 8),
            _AkBtn(Icons.delete_outline, '', Colors.red, onSil, small: true),
          ]),
        ),
      ]),
    );
  }
}

class _AkBtn extends StatelessWidget {
  final IconData ikon; final String label; final Color color;
  final VoidCallback onTap; final bool small;
  const _AkBtn(this.ikon, this.label, this.color, this.onTap, {this.small = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 12 : 10, vertical: 10),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(ikon, size: 16, color: color),
        if (label.isNotEmpty) ...[const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color))],
      ]),
    ),
  );
}
