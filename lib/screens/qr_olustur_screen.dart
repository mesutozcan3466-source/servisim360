import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QrOlusturScreen extends StatefulWidget {
  const QrOlusturScreen({super.key});

  @override
  State<QrOlusturScreen> createState() => _QrOlusturScreenState();
}

class _QrOlusturScreenState extends State<QrOlusturScreen> {
  static const navyBlue = Color(0xFF1a3a6b);
  static const turuncu = Color(0xFFFF8C00);

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _firmaId;
  bool _yukleniyor = true;
  List<Map<String, dynamic>> _ogrenciler = [];
  Map<String, dynamic>? _seciliOgrenci;

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
    final firmaId = doc.data()?['firmaId'] ?? '';
    setState(() => _firmaId = firmaId);
    if (firmaId.isNotEmpty) {
      final snap = await _db
          .collection('firms')
          .doc(firmaId)
          .collection('ogrenciler')
          .get();
      _ogrenciler =
          snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    }
    setState(() => _yukleniyor = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: navyBlue,
        title: const Text('QR Kod Olustur',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(color: turuncu, height: 2),
        ),
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ogrenci Sec',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: navyBlue)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.3)),
              ),
              child: DropdownButtonFormField<String>(
                decoration:
                const InputDecoration(border: InputBorder.none),
                hint: const Text('Ogrenci secin'),
                value: _seciliOgrenci?['id'],
                items: _ogrenciler.map((o) {
                  return DropdownMenuItem<String>(
                    value: o['id'],
                    child: Text(
                        '${o['ad'] ?? ''} ${o['soyad'] ?? ''}'
                            .trim()),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _seciliOgrenci = _ogrenciler.firstWhere(
                            (o) => o['id'] == val,
                        orElse: () => {});
                  });
                },
              ),
            ),
            const SizedBox(height: 24),
            if (_seciliOgrenci != null) ...[
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: 0.1),
                              blurRadius: 12)
                        ],
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.qr_code,
                                size: 100, color: navyBlue),
                            const SizedBox(height: 8),
                            Text(
                              '${_seciliOgrenci!['ad']} ${_seciliOgrenci!['soyad']}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: navyBlue),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'ID: ${_seciliOgrenci!['id']}',
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 11),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: navyBlue.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Not: Tam QR kod ozelligi icin\n"qr_flutter" paketi gereklidir.',
                        style: TextStyle(
                            fontSize: 12, color: navyBlue),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              Center(
                child: Column(
                  children: [
                    Icon(Icons.qr_code_2,
                        size: 80, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text('Ogrenci secin',
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: 15)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
