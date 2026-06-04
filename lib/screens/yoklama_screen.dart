import 'package:flutter/material.dart';
import 'yardim_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/session_service.dart';
import '../services/push_bildirim_service.dart';

class YoklamaScreen extends StatefulWidget {
  const YoklamaScreen({super.key});
  @override
  State<YoklamaScreen> createState() => _YoklamaScreenState();
}

class _YoklamaScreenState extends State<YoklamaScreen> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  String? _firmaId;
  List<Map<String, dynamic>> _ogrenciler = [];
  bool _yukleniyor = true;
  final Map<String, String> _durumlar = {};

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    _firmaId = await SessionService.instance.firmaldAl();
    if (_firmaId == null) { setState(() => _yukleniyor = false); return; }

    final snap = await FirebaseFirestore.instance
        .collection('students')
        .where('firmaId', isEqualTo: _firmaId)
        .where('aktif', isEqualTo: true)
        .get();

    final bugun     = DateTime.now();
    final baslangic = Timestamp.fromDate(DateTime(bugun.year, bugun.month, bugun.day));
    final bitis     = Timestamp.fromDate(DateTime(bugun.year, bugun.month, bugun.day, 23, 59));

    final yokSnap = await FirebaseFirestore.instance
        .collection('absence_requests')
        .where('firmaId', isEqualTo: _firmaId)
        .where('tarih', isGreaterThanOrEqualTo: baslangic)
        .where('tarih', isLessThanOrEqualTo: bitis)
        .get();

    final durumMap = <String, String>{};
    for (final doc in yokSnap.docs) {
      final data = doc.data();
      durumMap[data['ogrenciId'] as String? ?? ''] = data['tip'] as String? ?? 'gelmeyecek';
    }

    if (mounted) {
      setState(() {
        _ogrenciler = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        _durumlar
          ..clear()
          ..addAll(durumMap);
        _yukleniyor = false;
      });
    }
  }

  Future<void> _durumDegistir(String ogrenciId, String ad, String durum) async {
    if (_firmaId == null) return;
    if (durum == 'gelecek') {
      final bugun = DateTime.now();
      final snap  = await FirebaseFirestore.instance
          .collection('absence_requests')
          .where('firmaId',   isEqualTo: _firmaId)
          .where('ogrenciId', isEqualTo: ogrenciId)
          .where('tarih', isGreaterThanOrEqualTo:
      Timestamp.fromDate(DateTime(bugun.year, bugun.month, bugun.day)))
          .get();
      for (final doc in snap.docs) { await doc.reference.delete(); }
      if (mounted) setState(() => _durumlar.remove(ogrenciId));
    } else {
      await FirebaseFirestore.instance.collection('absence_requests').add({
        'firmaId':   _firmaId,
        'ogrenciId': ogrenciId,
        'ogrenciAd': ad,
        'tip':       durum,
        'tarih':     Timestamp.now(),
      });
      // Öğrencinin şoförüne push bildirim gönder
      await _soforePushGonder(ogrenciId, ad, durum);
      if (mounted) setState(() => _durumlar[ogrenciId] = durum);
    }
  }


  // Şoföre push bildirimi gönder
  Future<void> _soforePushGonder(String ogrenciId, String ogrenciAd, String durum) async {
    try {
      // Öğrencinin şoförünü bul
      final ogrDoc = await FirebaseFirestore.instance
          .collection('students').doc(ogrenciId).get();
      final surucuId = ogrDoc.data()?['surucuId'] as String?;
      if (surucuId == null || surucuId.isEmpty) return;

      // Şoförün FCM token'ını bul
      final soforDoc = await FirebaseFirestore.instance
          .collection('drivers').doc(surucuId).get();
      final fcmToken = soforDoc.data()?['fcmToken'] as String?;

      final mesaj = durum == 'gelmeyecek'
          ? '$ogrenciAd bugun servise gelmeyecek.'
          : '$ogrenciAd gecikecek.';

      // Bildirimi Firestore'a yaz (Cloud Functions tetikler veya manuel göster)
      await FirebaseFirestore.instance.collection('notifications').add({
        'aliciId':    surucuId,
        'aliciToken': fcmToken ?? '',
        'baslik':     'Devamsizlik Bildirimi',
        'mesaj':      mesaj,
        'tip':        'devamsizlik',
        'ogrenciId':  ogrenciId,
        'ogrenciAd':  ogrenciAd,
        'firmaId':    _firmaId,
        'okundu':     false,
        'tarih':      FieldValue.serverTimestamp(),
      });

      // FCM token varsa direkt push dene
      if (fcmToken != null && fcmToken.isNotEmpty) {
        await PushBildirimService.tokenaPushGonder(
          token:  fcmToken,
          baslik: 'Devamsizlik Bildirimi',
          govde: mesaj,
          data:   {'tip': 'devamsizlik', 'ogrenciId': ogrenciId},
        );
      }
    } catch (e) {
      debugPrint('Sofor push hatasi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final gelmeyecekSayi = _durumlar.length;
    final bugun = DateTime.now();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white,
        title: const Text('Yoklama', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          YardimButonu(ekranAdi: 'Sofor Paneli'),IconButton(icon: const Icon(Icons.refresh), onPressed: _yukle)],
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator(color: _navy))
          : Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            const Icon(Icons.today_outlined, color: _navy, size: 18),
            const SizedBox(width: 8),
            Text('${bugun.day}.${bugun.month}.${bugun.year}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: _navy)),
            const Spacer(),
            if (gelmeyecekSayi > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$gelmeyecekSayi gelmeyecek',
                    style: const TextStyle(color: Colors.orange,
                        fontWeight: FontWeight.bold, fontSize: 12)),
              ),
          ]),
        ),
        Expanded(
          child: _ogrenciler.isEmpty
              ? const Center(child: Text('Öğrenci bulunamadı',
              style: TextStyle(color: Colors.grey)))
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _ogrenciler.length,
            itemBuilder: (_, i) {
              final ogr     = _ogrenciler[i];
              final id      = ogr['id'] as String;
              final ad      = ogr['ad'] as String? ?? '';
              final durum   = _durumlar[id];
              final geliyor = durum == null;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: geliyor
                      ? Colors.green.withValues(alpha: 0.2)
                      : Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: geliyor
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    child: Text(
                      ad.isNotEmpty ? ad[0].toUpperCase() : '?',
                      style: TextStyle(
                          color: geliyor ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ad, style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(
                        geliyor ? 'Geliyor' : _durumEtiket(durum!),
                        style: TextStyle(
                            fontSize: 11,
                            color: geliyor ? Colors.green : Colors.orange),
                      ),
                    ],
                  )),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert,
                        color: Colors.grey, size: 20),
                    onSelected: (v) => _durumDegistir(id, ad, v),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'gelecek',    child: Text('Geliyor')),
                      PopupMenuItem(value: 'gelmeyecek', child: Text('Gelmeyecek')),
                      PopupMenuItem(value: 'hasta',      child: Text('Hasta')),
                      PopupMenuItem(value: 'izinli',     child: Text('İzinli')),
                    ],
                  ),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }

  String _durumEtiket(String d) {
    switch (d) {
      case 'hasta':  return 'Hasta';
      case 'izinli': return 'İzinli';
      default:       return 'Gelmeyecek';
    }
  }
}
