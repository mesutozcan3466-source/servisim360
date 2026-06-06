import 'package:flutter/material.dart';
import 'yardim_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class KullaniciFirmaTransferScreen extends StatefulWidget {
  final String kullaniciId;
  final String kullaniciAd;
  final String koleksiyon;
  final String mevcutFirmaId;

  const KullaniciFirmaTransferScreen({
    super.key,
    required this.kullaniciId,
    required this.kullaniciAd,
    required this.koleksiyon,
    required this.mevcutFirmaId,
  });

  @override
  State<KullaniciFirmaTransferScreen> createState() =>
      _KullaniciFirmaTransferScreenState();
}

class _KullaniciFirmaTransferScreenState
    extends State<KullaniciFirmaTransferScreen> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  List<Map<String, dynamic>> _firmalar = [];
  String? _seciliFirmaId;
  bool _yukleniyor = true;
  bool _transferYapiliyor = false;

  @override
  void initState() {
    super.initState();
    _firmalariYukle();
  }

  Future<void> _firmalariYukle() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('firms').get();
      setState(() {
        _firmalar = snap.docs
            .where((d) => d.id != widget.mevcutFirmaId)
            .map((d) => {
          'id': d.id,
          'ad': d.data()['firmaAd'] ?? d.id,
        })
            .toList();
        _yukleniyor = false;
      });
    } catch (e) {
      setState(() => _yukleniyor = false);
      _snack('Firmalar yuklenemedi: $e', Colors.red);
    }
  }

  Future<void> _transferEt() async {
    if (_seciliFirmaId == null) {
      _snack('Lutfen bir firma secin', Colors.orange);
      return;
    }
    setState(() => _transferYapiliyor = true);
    try {
      await FirebaseFirestore.instance
          .collection(widget.koleksiyon)
          .doc(widget.kullaniciId)
          .update({'firmaId': _seciliFirmaId});
      if (mounted) {
        _snack('${widget.kullaniciAd} basariyla transfer edildi', Colors.green);
        Navigator.pop(context, true);
      }
    } catch (e) {
      _snack('Transfer hatasi: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _transferYapiliyor = false);
    }
  }

  void _snack(String msg, Color renk) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: renk),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [YardimButonu(ekranAdi: 'Ayarlar')],
        title: const Text('Firma Transfer'),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: _navy),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Transfer Edilecek',
                          style: TextStyle(
                              color: Colors.grey, fontSize: 12),
                        ),
                        Text(
                          widget.kullaniciAd,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Hedef Firma Secin',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: _navy),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _firmalar.isEmpty
                  ? const Center(child: Text('Baska firma bulunamadi'))
                  : ListView.builder(
                itemCount: _firmalar.length,
                itemBuilder: (ctx, i) {
                  final f = _firmalar[i];
                  final secili = _seciliFirmaId == f['id'];
                  return Card(
                    color: secili
                        ? _navy.withValues(alpha: 0.08)
                        : Colors.white,
                    child: ListTile(
                      leading: Icon(
                        Icons.business,
                        color: secili ? _navy : Colors.grey,
                      ),
        title: Text(
                        f['ad'],
                        style: TextStyle(
                          fontWeight: secili
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: secili
                          ? const Icon(Icons.check_circle,
                          color: _turuncu)
                          : null,
                      onTap: () => setState(
                              () => _seciliFirmaId = f['id']),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _transferYapiliyor ? null : _transferEt,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _turuncu,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _transferYapiliyor
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  'Transfer Et',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
