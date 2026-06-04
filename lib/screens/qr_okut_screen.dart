import 'package:flutter/material.dart';
import 'yardim_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QrOkutScreen extends StatefulWidget {
  const QrOkutScreen({super.key});

  @override
  State<QrOkutScreen> createState() => _QrOkutScreenState();
}

class _QrOkutScreenState extends State<QrOkutScreen> {
  static const navyBlue = Color(0xFF1a3a6b);
  static const turuncu = Color(0xFFFF8C00);

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _firmaId;
  bool _yukleniyor = true;
  Map<String, dynamic>? _bulunanOgrenci;
  bool _taraniyor = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await _db.collection('kullanicilar').doc(uid).get();
    if (!doc.exists) return;
    setState(() {
      _firmaId = doc.data()?['firmaId'] ?? '';
      _yukleniyor = false;
    });
  }

  Future<void> _ogrenciOkut(String ogrenciId) async {
    if (_firmaId == null) return;
    setState(() => _taraniyor = true);

    final doc = await _db
        .collection('firms')
        .doc(_firmaId)
        .collection('students')
        .doc(ogrenciId)
        .get();

    if (doc.exists) {
      final d = doc.data()!;
      await _db
          .collection('firms')
          .doc(_firmaId)
          .collection('students')
          .doc(ogrenciId)
          .update({
        'bindiMi': true,
        'bindiZamani': FieldValue.serverTimestamp(),
      });
      setState(() {
        _bulunanOgrenci = {'id': doc.id, ...d};
        _taraniyor = false;
      });
    } else {
      setState(() => _taraniyor = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Ogrenci bulunamadi!'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: navyBlue,
        title: const Text('QR Okut',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          YardimButonu(ekranAdi: 'Kayitlar'),
          if (_bulunanOgrenci != null)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () => setState(() => _bulunanOgrenci = null),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(color: turuncu, height: 2),
        ),
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : _bulunanOgrenci != null
          ? _sonucGoster()
          : _tarayiciGoster(),
    );
  }

  Widget _tarayiciGoster() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 12)
                ],
              ),
              child: const Center(
                child: Icon(Icons.qr_code_scanner,
                    size: 100, color: navyBlue),
              ),
            ),
            const SizedBox(height: 24),
            const Text('QR Kodu Kameranin Onune Tutun',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: navyBlue),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Not: Tam kamera ozelligi icin\n"mobile_scanner" paketi gereklidir.',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // Manuel ID girisi test icin
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: turuncu,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.edit),
              label: const Text('Manuel ID Gir (Test)'),
              onPressed: () => _manuelIdDialog(),
            ),
          ],
        ),
      ),
    );
  }

  void _manuelIdDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ogrenci ID',
            style: TextStyle(color: navyBlue)),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
              labelText: 'Ogrenci ID', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Iptal')),
          ElevatedButton(
            style:
            ElevatedButton.styleFrom(backgroundColor: turuncu),
            onPressed: () {
              Navigator.pop(ctx);
              if (ctrl.text.trim().isNotEmpty) {
                _ogrenciOkut(ctrl.text.trim());
              }
            },
            child: const Text('Sorgula',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _sonucGoster() {
    final d = _bulunanOgrenci!;
    final ad = '${d['ad'] ?? ''} ${d['soyad'] ?? ''}'.trim();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                  color: Colors.green, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 56),
            ),
            const SizedBox(height: 24),
            Text(ad,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: navyBlue)),
            const SizedBox(height: 8),
            if ((d['rotaAd'] ?? '').isNotEmpty)
              Text('Rota: ${d['rotaAd']}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            const SizedBox(height: 6),
            const Text('Bindi olarak isaretlendi',
                style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: navyBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Tekrar Okut'),
              onPressed: () => setState(() => _bulunanOgrenci = null),
            ),
          ],
        ),
      ),
    );
  }
}
