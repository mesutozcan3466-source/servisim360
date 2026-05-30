import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─── FiyatSonucu modeli ──────────────────────────────────────────────────────
// tip: 'mahalle' | 'ilce' | 'yok'
class FiyatSonucu {
  final double? ucret;   // null = fiyat bulunamadi
  final String ilce;
  final String mahalle;
  final bool bulundu;
  final String aciklama;
  final String tip;      // 'mahalle' | 'ilce' | 'yok'

  const FiyatSonucu({
    required this.ucret,
    required this.ilce,
    required this.mahalle,
    required this.bulundu,
    required this.aciklama,
    required this.tip,
  });

  static const FiyatSonucu bulunamadi = FiyatSonucu(
    ucret: null,
    ilce: '',
    mahalle: '',
    bulundu: false,
    aciklama: 'Bu bolge icin fiyat belirlenmemis.',
    tip: 'yok',
  );
}

// ─── FiyatHesaplamaServisi ───────────────────────────────────────────────────
class FiyatHesaplamaServisi {
  /// [veliAdresi] ile cagrilabilir (veli_sozlesme_screen uyumu)
  /// veya [ilce]+[mahalle] ile direkt cagrilabilir.
  static Future<FiyatSonucu> hesapla({
    required String firmaId,
    String ilce = '',
    String mahalle = '',
    String? veliAdresi, // veli_sozlesme_screen'den gelir, adres string'i
  }) async {
    if (firmaId.isEmpty) return FiyatSonucu.bulunamadi;

    // veliAdresi varsa adres stringinden ilce/mahalle cikarmaya calis
    // (basit kelime eslesmesi — geolocator olmadan)
    String _ilce = ilce;
    String _mahalle = mahalle;
    if (veliAdresi != null && veliAdresi.isNotEmpty) {
      // Adres string'ini parcala: "Merkez Mahallesi, Kadikoy, Istanbul"
      final parcalar = veliAdresi
          .split(RegExp(r'[,/\n]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (parcalar.isNotEmpty && _ilce.isEmpty) _ilce = parcalar.length > 1 ? parcalar[1] : parcalar[0];
      if (parcalar.isNotEmpty && _mahalle.isEmpty) _mahalle = parcalar[0];
    }

    if (_ilce.isEmpty) return FiyatSonucu.bulunamadi;

    // 1. Mahalle bazli
    if (_mahalle.isNotEmpty) {
      final snap = await FirebaseFirestore.instance
          .collection('fiyatlar')
          .where('firmaId', isEqualTo: firmaId)
          .where('ilce', isEqualTo: _ilce)
          .where('mahalle', isEqualTo: _mahalle)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        final d = snap.docs.first.data();
        return FiyatSonucu(
          ucret: (d['ucret'] as num?)?.toDouble(),
          ilce: _ilce,
          mahalle: _mahalle,
          bulundu: true,
          aciklama: '$_ilce / $_mahalle bolgesi icin aylik servis ucreti',
          tip: 'mahalle',
        );
      }
    }

    // 2. Ilce bazli
    final snap = await FirebaseFirestore.instance
        .collection('fiyatlar')
        .where('firmaId', isEqualTo: firmaId)
        .where('ilce', isEqualTo: _ilce)
        .where('mahalle', isEqualTo: '')
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) {
      final d = snap.docs.first.data();
      return FiyatSonucu(
        ucret: (d['ucret'] as num?)?.toDouble(),
        ilce: _ilce,
        mahalle: '',
        bulundu: true,
        aciklama: '$_ilce ilcesi geneli icin aylik servis ucreti',
        tip: 'ilce',
      );
    }

    return FiyatSonucu.bulunamadi;
  }
}

// ─── FiyatYonetimScreen ──────────────────────────────────────────────────────
class FiyatYonetimScreen extends StatefulWidget {
  const FiyatYonetimScreen({super.key});

  @override
  State<FiyatYonetimScreen> createState() => _FiyatYonetimScreenState();
}

class _FiyatYonetimScreenState extends State<FiyatYonetimScreen>
    with SingleTickerProviderStateMixin {
  static const Color navy = Color(0xFF1a3a6b);
  static const Color orange = Color(0xFFFF8C00);

  late TabController _tabCtrl;
  final _ilceCtrl = TextEditingController();
  final _mahalleCtrl = TextEditingController();
  final _ucretCtrl = TextEditingController();
  final _notCtrl = TextEditingController();
  bool _yukleniyor = false;
  String _firmaId = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _firmaIdAl();
  }

  Future<void> _firmaIdAl() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('kullanicilar')
        .doc(uid)
        .get();
    setState(() => _firmaId = snap.data()?['firmaId'] ?? '');
  }

  Future<void> _fiyatEkle() async {
    final ilce = _ilceCtrl.text.trim();
    final mahalle = _mahalleCtrl.text.trim();
    final ucretStr = _ucretCtrl.text.trim();
    if (ilce.isEmpty || ucretStr.isEmpty) {
      _snack('Ilce ve ucret zorunlu', hata: true);
      return;
    }
    final ucret = double.tryParse(ucretStr.replaceAll(',', '.'));
    if (ucret == null) {
      _snack('Gecerli ucret girin', hata: true);
      return;
    }
    setState(() => _yukleniyor = true);
    try {
      final sorgu = await FirebaseFirestore.instance
          .collection('fiyatlar')
          .where('firmaId', isEqualTo: _firmaId)
          .where('ilce', isEqualTo: ilce)
          .where('mahalle', isEqualTo: mahalle)
          .get();
      if (sorgu.docs.isNotEmpty) {
        await sorgu.docs.first.reference.update({
          'ucret': ucret,
          'not': _notCtrl.text.trim(),
          'guncellenmeTarihi': FieldValue.serverTimestamp(),
        });
        _snack('Fiyat guncellendi');
      } else {
        await FirebaseFirestore.instance.collection('fiyatlar').add({
          'firmaId': _firmaId,
          'ilce': ilce,
          'mahalle': mahalle,
          'ucret': ucret,
          'not': _notCtrl.text.trim(),
          'olusturmaTarihi': FieldValue.serverTimestamp(),
          'guncellenmeTarihi': FieldValue.serverTimestamp(),
        });
        _snack('Fiyat eklendi');
      }
      _ilceCtrl.clear();
      _mahalleCtrl.clear();
      _ucretCtrl.clear();
      _notCtrl.clear();
      _tabCtrl.animateTo(1);
    } catch (e) {
      _snack('Hata: $e', hata: true);
    } finally {
      setState(() => _yukleniyor = false);
    }
  }

  Future<void> _fiyatSil(String docId) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fiyati Sil'),
        content: const Text('Bu fiyat kaydini silmek istiyor musunuz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Iptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (onay != true) return;
    await FirebaseFirestore.instance
        .collection('fiyatlar')
        .doc(docId)
        .delete();
    _snack('Silindi');
  }

  void _duzenlemeyiAc(Map<String, dynamic> data) {
    _ilceCtrl.text = data['ilce'] ?? '';
    _mahalleCtrl.text = data['mahalle'] ?? '';
    _ucretCtrl.text = (data['ucret'] ?? '').toString();
    _notCtrl.text = data['not'] ?? '';
    _tabCtrl.animateTo(0);
  }

  void _snack(String msg, {bool hata = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: hata ? Colors.red : Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        title: const Text('Fiyat Yonetimi',
            style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: orange,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.add), text: 'Fiyat Ekle'),
            Tab(icon: Icon(Icons.list), text: 'Fiyat Listesi'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [_eklemeFormu(), _fiyatListesi()],
      ),
    );
  }

  Widget _eklemeFormu() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: navy.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: navy.withValues(alpha: 0.1)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: navy, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mahalle bos birakilirsa ilce geneli uygulanir. '
                        'Mahalle bazli fiyat onceliklidir.',
                    style: TextStyle(fontSize: 12, color: navy),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _etiket('Ilce *'),
          _alan(ctrl: _ilceCtrl, hint: 'Ornek: Merkez, Kadiköy', ikon: Icons.location_city),
          const SizedBox(height: 14),
          _etiket('Mahalle (Opsiyonel)'),
          _alan(ctrl: _mahalleCtrl, hint: 'Ornek: Bagcilar Mah.', ikon: Icons.map),
          const SizedBox(height: 14),
          _etiket('Aylik Ucret (TL) *'),
          _alan(
            ctrl: _ucretCtrl,
            hint: 'Ornek: 2500',
            ikon: Icons.attach_money,
            tip: TextInputType.number,
          ),
          const SizedBox(height: 14),
          _etiket('Not (Opsiyonel)'),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: TextField(
              controller: _notCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                contentPadding: EdgeInsets.all(14),
                border: InputBorder.none,
                hintText: 'Varsa ozel not...',
              ),
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _yukleniyor ? null : _fiyatEkle,
              icon: _yukleniyor
                  ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save),
              label: const Text('Kaydet',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fiyatListesi() {
    if (_firmaId.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('fiyatlar')
          .where('firmaId', isEqualTo: _firmaId)
          .orderBy('ilce')
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.price_change, size: 64, color: Colors.grey),
                SizedBox(height: 12),
                Text('Henuz fiyat eklenmemis',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }
        final Map<String, List<QueryDocumentSnapshot>> gruplar = {};
        for (final doc in docs) {
          final d = doc.data() as Map<String, dynamic>;
          final ilce = d['ilce'] ?? 'Diger';
          gruplar.putIfAbsent(ilce, () => []).add(doc);
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: gruplar.entries.map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: navy,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(entry.key,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Text('${entry.value.length} kayit',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                ...entry.value.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final mahalle = (d['mahalle'] ?? '') as String;
                  final ucret =
                      (d['ucret'] as num?)?.toDouble() ?? 0;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          mahalle.isEmpty
                              ? Icons.location_city
                              : Icons.map,
                          color: orange,
                        ),
                      ),
                      title: Text(
                        mahalle.isEmpty
                            ? '${d['ilce']} (Genel)'
                            : mahalle,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14),
                      ),
                      subtitle:
                      (d['not'] != null && (d['not'] as String).isNotEmpty)
                          ? Text(d['not'],
                          style: const TextStyle(fontSize: 12))
                          : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${ucret.toStringAsFixed(0)} TL',
                                style: TextStyle(
                                    color: orange,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                              ),
                              const Text('/ay',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 11)),
                            ],
                          ),
                          PopupMenuButton<String>(
                            onSelected: (val) {
                              if (val == 'duzenle') _duzenlemeyiAc(d);
                              if (val == 'sil') _fiyatSil(doc.id);
                            },
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(
                                  value: 'duzenle',
                                  child: Row(children: [
                                    Icon(Icons.edit, size: 16),
                                    SizedBox(width: 8),
                                    Text('Duzenle'),
                                  ])),
                              const PopupMenuItem(
                                  value: 'sil',
                                  child: Row(children: [
                                    Icon(Icons.delete,
                                        size: 16, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Sil',
                                        style:
                                        TextStyle(color: Colors.red)),
                                  ])),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            );
          }).toList(),
        );
      },
    );
  }

  Widget _etiket(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF444444))),
  );

  Widget _alan({
    required TextEditingController ctrl,
    required String hint,
    required IconData ikon,
    TextInputType tip = TextInputType.text,
  }) =>
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: TextField(
          controller: ctrl,
          keyboardType: tip,
          decoration: InputDecoration(
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: InputBorder.none,
            hintText: hint,
            prefixIcon: Icon(ikon, color: Colors.grey, size: 20),
          ),
        ),
      );

  @override
  void dispose() {
    _tabCtrl.dispose();
    _ilceCtrl.dispose();
    _mahalleCtrl.dispose();
    _ucretCtrl.dispose();
    _notCtrl.dispose();
    super.dispose();
  }
}
