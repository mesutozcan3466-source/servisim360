import 'package:flutter/material.dart';
import 'ai_widget.dart';
import '../services/sozlesme_pdf_service.dart';
import 'yardim_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class VeliBasvurularScreen extends StatefulWidget {
  const VeliBasvurularScreen({super.key});

  @override
  State<VeliBasvurularScreen> createState() => _VeliBasvurularScreenState();
}

class _VeliBasvurularScreenState extends State<VeliBasvurularScreen>
    with SingleTickerProviderStateMixin {
  static const Color navy   = Color(0xFF1a3a6b);
  static const Color orange = Color(0xFFFF8C00);

  late TabController _tabCtrl;
  String _firmaId = '';
  String _aramaMetni = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _firmaIdAl();
  }

  Future<void> _firmaIdAl() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('kullanicilar').doc(uid).get();
    setState(() => _firmaId = snap.data()?['firmaId'] ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        title: const Text('Veli Basvurulari',
            style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: orange,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Bekleyen'),
            Tab(text: 'Onaylanan'),
            Tab(text: 'Reddedilen'),
          ],
        ),
        actions: [
          AiAsistanButonu(ekranAdi: 'Kayitlar'),
          YardimButonu(ekranAdi: 'Kayitlar'),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _aramaAc,
          ),
        ],
      ),
      body: _firmaId.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabCtrl,
        children: [
          _BasvuruListesi(firmaId: _firmaId, durum: 'beklemede', aramaMetni: _aramaMetni),
          _BasvuruListesi(firmaId: _firmaId, durum: 'onaylandi', aramaMetni: _aramaMetni),
          _BasvuruListesi(firmaId: _firmaId, durum: 'reddedildi', aramaMetni: _aramaMetni),
        ],
      ),
    );
  }

  void _aramaAc() {
    showSearch(
      context: context,
      delegate: _BasvuruAramaDelegate(firmaId: _firmaId),
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }
}

// ─── Başvuru Listesi ─────────────────────────────────────────────────────────
class _BasvuruListesi extends StatelessWidget {
  final String firmaId, durum, aramaMetni;
  static const Color navy   = Color(0xFF1a3a6b);
  static const Color orange = Color(0xFFFF8C00);

  const _BasvuruListesi({
    required this.firmaId,
    required this.durum,
    required this.aramaMetni,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('veli_basvurular')
          .where('firmaId', isEqualTo: firmaId)
          .where('durum', isEqualTo: durum)
          .orderBy('basvuruTarihi', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        var docs = snap.data!.docs;
        if (aramaMetni.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final metin = '${data['ogrenciAdi']} ${data['veliAdi']}'
                .toLowerCase();
            return metin.contains(aramaMetni.toLowerCase());
          }).toList();
        }
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 64,
                    color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text(
                  durum == 'beklemede'
                      ? 'Bekleyen basvuru yok'
                      : durum == 'onaylandi'
                      ? 'Onaylanan basvuru yok'
                      : 'Reddedilen basvuru yok',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            return _BasvuruKarti(
              docId: docs[i].id,
              data: d,
              durum: durum,
            );
          },
        );
      },
    );
  }
}

// ─── Başvuru Kartı ───────────────────────────────────────────────────────────
class _BasvuruKarti extends StatelessWidget {
  final String docId, durum;
  final Map<String, dynamic> data;
  static const Color navy   = Color(0xFF1a3a6b);
  static const Color orange = Color(0xFFFF8C00);

  const _BasvuruKarti({
    required this.docId,
    required this.data,
    required this.durum,
  });

  Color get _durumRenk {
    switch (durum) {
      case 'beklemede':  return Colors.orange;
      case 'onaylandi':  return Colors.green;
      case 'reddedildi': return Colors.red;
      default:           return Colors.grey;
    }
  }

  String get _durumEtiket {
    switch (durum) {
      case 'beklemede':  return 'Bekliyor';
      case 'onaylandi':  return 'Onaylandi';
      case 'reddedildi': return 'Reddedildi';
      default:           return durum;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ts = data['basvuruTarihi'] as Timestamp?;
    final tarih = ts != null
        ? '${ts.toDate().day}.${ts.toDate().month}.${ts.toDate().year}'
        : '';
    final fiyat = data['hesaplananFiyat'];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _detayAc(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _durumRenk.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _durumRenk.withValues(alpha: 0.4)),
                  ),
                  child: Text(_durumEtiket,
                      style: TextStyle(
                          color: _durumRenk,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                Text(tarih,
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 12)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.school, color: navy, size: 16),
                const SizedBox(width: 6),
                Text(data['ogrenciAdi'] ?? '',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.person, color: Colors.grey, size: 14),
                const SizedBox(width: 6),
                Text(data['veliAdi'] ?? '',
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 13)),
                const SizedBox(width: 12),
                const Icon(Icons.phone, color: Colors.grey, size: 14),
                const SizedBox(width: 4),
                Text(data['telefon'] ?? '',
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 13)),
              ]),
              if (data['adres'] != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.location_on,
                      color: Colors.grey, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(data['adres'],
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ],
              if (fiyat != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${(fiyat as num).toStringAsFixed(0)} TL / ay',
                    style: TextStyle(
                        color: orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ),
              ],
              if (durum == 'beklemede') ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _reddet(context),
                      icon: const Icon(Icons.close,
                          size: 16, color: Colors.red),
                      label: const Text('Reddet',
                          style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _onayla(context),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Onayla & Kaydet',
                          style: TextStyle(
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onayla(BuildContext context) async {
    final now = FieldValue.serverTimestamp();

    // 1. Başvuruyu onayla
    await FirebaseFirestore.instance
        .collection('veli_basvurular').doc(docId).update({
      'durum'     : 'onaylandi',
      'onayTarihi': now,
    });

    // 2. Öğrenci kaydı
    final ogrRef = await FirebaseFirestore.instance
        .collection('students').add({
      'firmaId'      : data['firmaId'],
      'projeId'      : data['projeId'] ?? '',
      'ad'           : (data['ogrenciAdi'] as String?)?.split(' ').first ?? '',
      'soyad'        : (data['ogrenciAdi'] as String?)?.split(' ').skip(1).join(' ') ?? '',
      'adSoyad'      : data['ogrenciAdi'] ?? '',
      'ogrenciTc'    : data['ogrenciTc'] ?? '',
      'veliAd'       : data['veliAdi'] ?? '',
      'veliTc'       : data['veliTc'] ?? '',
      'veliTel'      : data['telefon'] ?? '',
      'babaTel'      : data['babaTel'] ?? data['telefon'] ?? '',
      'anneTel'      : data['anneTel'] ?? '',
      'okul'         : data['okulAdi'] ?? '',
      'sinif'        : data['sinif'] ?? '',
      'okulNo'       : data['okulNo'] ?? '',
      'adres'        : data['adres'] ?? '',
      'konum'        : data['konum'],
      'aylikUcret'   : data['hesaplananFiyat'],
      'sozlesmeDurum': 'imzalandi',
      'bindi'        : false,
      'aktif'        : true,
      'kayitTarihi'  : now,
      'basvuruId'    : docId,
      'kayitTipi'    : 'link_basvuru',
    });

    // 3. Otomatik veli hesabı
    final geciciSifre = (data['telefon'] ?? '').toString();
    await FirebaseFirestore.instance
        .collection('parents').doc(ogrRef.id).set({
      'firmaId'     : data['firmaId'],
      'ogrenciId'   : ogrRef.id,
      'ad'          : data['veliAdi'] ?? '',
      'telefon'     : data['telefon'] ?? '',
      'kullaniciAdi': geciciSifre,
      'geciciSifre' : geciciSifre,
      'ilkGiris'    : true,
      'aktif'       : true,
      'rol'         : 'veli',
      'olusturma'   : now,
    });
    await FirebaseFirestore.instance
        .collection('kullanicilar').doc(ogrRef.id).set({
      'firmaId'     : data['firmaId'],
      'ad'          : data['veliAdi'] ?? '',
      'telefon'     : data['telefon'] ?? '',
      'kullaniciAdi': geciciSifre,
      'sifre'       : geciciSifre,
      'ilkGiris'    : true,
      'rol'         : 'veli',
      'ogrenciId'   : ogrRef.id,
      'olusturma'   : now,
    });

    // 4. Sözleşme arşivine kaydet
    await FirebaseFirestore.instance.collection('sozlesmeler').add({
      'firmaId'        : data['firmaId'],
      'projeId'        : data['projeId'] ?? '',
      'ogrenciId'      : ogrRef.id,
      'ogrenciAd'      : data['ogrenciAdi'] ?? '',
      'veliAd'         : data['veliAdi'] ?? '',
      'ucret'          : data['hesaplananFiyat'] ?? '',
      'adres'          : data['adres'] ?? '',
      'durum'          : 'imzalandi',
      'kayitTipi'      : 'link_basvuru',
      'sozlesmeOnay'   : data['sozlesmeOnay'] ?? false,
      'kvkkOnay'       : data['kvkkOnay'] ?? false,
      'dijitalOnay'    : data['dijitalOnay'] ?? false,
      'imzaVeri'       : data['imzaVeri'],
      'onayTarihi'     : now,
      'sozlesmeSablonId': data['sozlesmeSablonId'] ?? '',
      'olusturma'      : now,
      'durumGecmisi'   : [{'durum': 'imzalandi', 'tarih': DateTime.now().toString()}],
    });

    // 5. PDF oluştur
    try {
      await SozlesmePdfServisi.olusturVePaylasim(
        firmaAd     : data['firmaAdi'] ?? data['firmaId'] ?? '',
        ogrenciAd   : data['ogrenciAdi'] ?? '',
        veliAd      : data['veliAdi'] ?? '',
        anneTel     : data['telefon'] ?? '',
        adres       : data['adres'] ?? '',
        aylikUcret  : (data['hesaplananFiyat'] as num?)?.toDouble(),
        sozlesmeMetni: data['sozlesmeMetni'] ?? '',
      );
    } catch (_) {}

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Onaylandi — Ogrenci + Veli hesabi + Arsiv kaydedildi'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _duzenle(BuildContext context) async {
    final adCtrl   = TextEditingController(text: data['ogrenciAdi'] ?? '');
    final veliCtrl = TextEditingController(text: data['veliAdi'] ?? '');
    final telCtrl  = TextEditingController(text: data['telefon'] ?? '');
    final adresCtrl = TextEditingController(text: data['adres'] ?? '');

    final onay = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Başvuruyu Düzenle'),
        content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: adCtrl,
              decoration: const InputDecoration(labelText: 'Öğrenci Ad Soyad',
                  border: OutlineInputBorder(), isDense: true)),
          const SizedBox(height: 8),
          TextField(controller: veliCtrl,
              decoration: const InputDecoration(labelText: 'Veli Ad Soyad',
                  border: OutlineInputBorder(), isDense: true)),
          const SizedBox(height: 8),
          TextField(controller: telCtrl,
              decoration: const InputDecoration(labelText: 'Telefon',
                  border: OutlineInputBorder(), isDense: true),
              keyboardType: TextInputType.phone),
          const SizedBox(height: 8),
          TextField(controller: adresCtrl,
              decoration: const InputDecoration(labelText: 'Adres',
                  border: OutlineInputBorder(), isDense: true)),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_, false), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1a3a6b),
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(_, true),
            child: const Text('Kaydet')),
        ],
      ),
    );

    if (onay == true) {
      await FirebaseFirestore.instance
          .collection('veli_basvurular').doc(docId).update({
        'ogrenciAdi': adCtrl.text.trim(),
        'veliAdi'   : veliCtrl.text.trim(),
        'telefon'   : telCtrl.text.trim(),
        'adres'     : adresCtrl.text.trim(),
        'updatedAt' : FieldValue.serverTimestamp(),
        'duzenlendi': true,
      });
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Düzenlendi!'),
              backgroundColor: Colors.blue,
              behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _reddet(BuildContext context) async {
    final sebep = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Reddetme Sebebi'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              hintText: 'Sebep (opsiyonel)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Iptal')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red),
              child: const Text('Reddet',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
    if (sebep == null) return;
    await FirebaseFirestore.instance
        .collection('veli_basvurular')
        .doc(docId)
        .update({
      'durum':        'reddedildi',
      'redSebebi':    sebep,
      'redTarihi':    FieldValue.serverTimestamp(),
    });
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Basvuru reddedildi'),
            backgroundColor: Colors.red),
      );
    }
  }

  void _detayAc(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BasvuruDetay(data: data, docId: docId),
    );
  }
}

// ─── Detay Bottom Sheet ───────────────────────────────────────────────────────
class _BasvuruDetay extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  static const Color navy   = Color(0xFF1a3a6b);
  static const Color orange = Color(0xFFFF8C00);

  const _BasvuruDetay({required this.data, required this.docId});

  @override
  Widget build(BuildContext context) {
    final konum = data['konum'] as GeoPoint?;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              const Text('Basvuru Detayi',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              if (data['telefon'] != null)
                IconButton(
                  icon: const Icon(Icons.call, color: Colors.green),
                  onPressed: () async {
                    final uri = Uri.parse('tel:${data['telefon']}');
                    if (await canLaunchUrl(uri)) launchUrl(uri);
                  },
                ),
              if (data['telefon'] != null)
                IconButton(
                  icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
                  onPressed: () async {
                    final tel = (data['telefon'] as String)
                        .replaceAll(RegExp(r'[^\d]'), '');
                    final uri = Uri.parse('https://wa.me/90$tel');
                    if (await canLaunchUrl(uri)) {
                      launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detaySatir('Ogrenci', data['ogrenciAdi'] ?? ''),
                  _detaySatir('Veli', data['veliAdi'] ?? ''),
                  _detaySatir('Telefon', data['telefon'] ?? ''),
                  _detaySatir('Adres', data['adres'] ?? ''),
                  _detaySatir('Proje', data['projeAdi'] ?? ''),
                  if (data['hesaplananFiyat'] != null)
                    _detaySatir('Fiyat',
                        '${(data['hesaplananFiyat'] as num).toStringAsFixed(0)} TL/ay'),
                  if (konum != null) ...[
                    const SizedBox(height: 16),
                    const Text('Konum',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: Colors.grey)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 200,
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(
                                konum.latitude, konum.longitude),
                            zoom: 15,
                          ),
                          markers: {
                            Marker(
                              markerId: const MarkerId('basvuru'),
                              position: LatLng(
                                  konum.latitude, konum.longitude),
                            )
                          },
                          zoomControlsEnabled: false,
                          myLocationButtonEnabled: false,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detaySatir(String etiket, String deger) {
    if (deger.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 80,
          child: Text(etiket,
              style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(deger,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

// ─── Arama Delegate ───────────────────────────────────────────────────────────
class _BasvuruAramaDelegate extends SearchDelegate<String> {
  final String firmaId;
  _BasvuruAramaDelegate({required this.firmaId});

  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, ''),
  );

  @override
  Widget buildResults(BuildContext context) => _sonuclar();

  @override
  Widget buildSuggestions(BuildContext context) => _sonuclar();

  Widget _sonuclar() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('veli_basvurular')
          .where('firmaId', isEqualTo: firmaId)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final metin = '${data['ogrenciAdi']} ${data['veliAdi']}'
              .toLowerCase();
          return query.isEmpty || metin.contains(query.toLowerCase());
        }).toList();
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            return ListTile(
              leading: const Icon(Icons.person),
              title: Text(d['ogrenciAdi'] ?? ''),
              subtitle: Text(d['veliAdi'] ?? ''),
              trailing: Text(d['durum'] ?? '',
                  style: const TextStyle(color: Colors.grey)),
            );
          },
        );
      },
    );
  }
}
