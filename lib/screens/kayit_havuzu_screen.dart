import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class KayitHavuzuScreen extends StatefulWidget {
  const KayitHavuzuScreen({super.key});

  @override
  State<KayitHavuzuScreen> createState() => _KayitHavuzuScreenState();
}

class _KayitHavuzuScreenState extends State<KayitHavuzuScreen> {
  static const navyBlue = Color(0xFF1a3a6b);
  static const turuncu = Color(0xFFFF8C00);

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _firmaId;
  bool _yukleniyor = true;

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

  Future<void> _basvuruOnayla(DocumentSnapshot doc) async {
    if (_firmaId == null) return;
    final d = doc.data() as Map<String, dynamic>;

    // Ogrenciler koleksiyonuna ekle
    await _db
        .collection('firms')
        .doc(_firmaId)
        .collection('ogrenciler')
        .add({
      'ad': d['ad'] ?? '',
      'soyad': d['soyad'] ?? '',
      'veliAd': d['veliAd'] ?? '',
      'veliTel': d['veliTel'] ?? '',
      'adres': d['adres'] ?? '',
      'veliEmail': d['veliEmail'] ?? '',
      'lat': d['lat'],
      'lng': d['lng'],
      'rotaId': '',
      'rotaAd': '',
      'aktif': true,
      'durum': 'aktif',
      'olusturmaTarihi': FieldValue.serverTimestamp(),
    });

    // Basvuruyu onayli yap
    await doc.reference.update({'durum': 'onaylandi'});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Basvuru onaylandi, ogrenci eklendi.'),
            backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _basvuruReddet(DocumentSnapshot doc) async {
    await doc.reference.update({'durum': 'reddedildi'});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Basvuru reddedildi.'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          backgroundColor: navyBlue,
          title: const Text('Kayit Havuzu',
              style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            indicatorColor: turuncu,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(icon: Icon(Icons.pending_actions), text: 'Bekleyenler'),
              Tab(icon: Icon(Icons.done_all), text: 'Tamamlananlar'),
            ],
          ),
        ),
        body: _yukleniyor
            ? const Center(child: CircularProgressIndicator())
            : _firmaId == null || _firmaId!.isEmpty
            ? const Center(
            child: Text('Firma bilgisi bulunamadi.',
                style: TextStyle(color: Colors.grey)))
            : TabBarView(
          children: [
            _basvuruListesi('beklemede'),
            _basvuruListesi('onaylandi'),
          ],
        ),
      ),
    );
  }

  Widget _basvuruListesi(String durum) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('firms')
          .doc(_firmaId)
          .collection('basvurular')
          .where('durum', isEqualTo: durum)
          .orderBy('basvuruTarihi', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text(
                    durum == 'beklemede'
                        ? 'Bekleyen basvuru yok'
                        : 'Tamamlanan basvuru yok',
                    style: TextStyle(color: Colors.grey[500], fontSize: 15)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: snap.data!.docs.length,
          itemBuilder: (context, i) {
            final doc = snap.data!.docs[i];
            final d = doc.data() as Map<String, dynamic>;
            final ad = '${d['ad'] ?? ''} ${d['soyad'] ?? ''}'.trim();
            final onaylandi = durum == 'onaylandi';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border(
                    left: BorderSide(
                        color: onaylandi ? Colors.green : turuncu,
                        width: 4)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6)
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                          onaylandi ? Colors.green : turuncu,
                          radius: 20,
                          child: Text(
                            ad.isNotEmpty ? ad[0].toUpperCase() : '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ad,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                              if ((d['veliAd'] ?? '').isNotEmpty)
                                Text('Veli: ${d['veliAd']}',
                                    style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if ((d['adres'] ?? '').isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text('Adres: ${d['adres']}',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 12)),
                    ],
                    if ((d['veliTel'] ?? '').isNotEmpty)
                      Text('Tel: ${d['veliTel']}',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 12)),
                    if (durum == 'beklemede') ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.close,
                                color: Colors.red, size: 16),
                            label: const Text('Reddet',
                                style: TextStyle(color: Colors.red)),
                            onPressed: () => _basvuruReddet(doc),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Onayla'),
                            onPressed: () => _basvuruOnayla(doc),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
