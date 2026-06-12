import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

// ======================================================================
// PERSONEL PANEL SCREEN  --  Servisim360 Mobil
// Personelin kendi paneli: servis takip, devamsizlik bildir, duyurular
// ======================================================================

class PersonelPanelScreen extends StatefulWidget {
  const PersonelPanelScreen({super.key});
  @override
  State<PersonelPanelScreen> createState() => _PersonelPanelScreenState();
}

class _PersonelPanelScreenState extends State<PersonelPanelScreen> {
  static const _navy   = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);

  int    _tab      = 0;
  String _firmaId  = '';
  String _personelId = '';
  Map<String, dynamic> _personelBilgi = {};
  Map<String, dynamic> _servisBilgi   = {};
  bool   _yukleniyor = true;

  @override
  void initState() { super.initState(); _baslat(); }

  Future<void> _baslat() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _personelId = user.uid;
    try {
      // Kullanici bilgisi
      final kulDoc = await FirebaseFirestore.instance
          .collection('kullanicilar').doc(user.uid).get();
      _firmaId = kulDoc.data()?['firmaId'] ?? '';

      // Personel bilgisi
      final perDoc = await FirebaseFirestore.instance
          .collection('personnel').doc(user.uid).get();
      if (perDoc.exists) {
        _personelBilgi = perDoc.data() ?? {};
      } else {
        // Email ile ara
        final snap = await FirebaseFirestore.instance
            .collection('personnel')
            .where('firmaId', isEqualTo: _firmaId)
            .where('email', isEqualTo: user.email)
            .limit(1).get();
        if (snap.docs.isNotEmpty) {
          _personelBilgi = {'id': snap.docs.first.id, ...snap.docs.first.data()};
          _personelId = snap.docs.first.id;
        }
      }

      // Servis bilgisi - personele atanmis servis
      if (_firmaId.isNotEmpty) {
        final servisSnap = await FirebaseFirestore.instance
            .collection('vehicles')
            .where('firmaId', isEqualTo: _firmaId)
            .where('servisAktif', isEqualTo: true)
            .limit(1).get();
        if (servisSnap.docs.isNotEmpty) {
          _servisBilgi = {'id': servisSnap.docs.first.id, ...servisSnap.docs.first.data()};
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _yukleniyor = false);
  }

  static const _tablar = [
    {'ikon': Icons.home_outlined,         'label': 'Ana Sayfa'},
    {'ikon': Icons.directions_bus_outlined,'label': 'Servisim'},
    {'ikon': Icons.event_busy_outlined,    'label': 'Devamsizlik'},
    {'ikon': Icons.notifications_outlined, 'label': 'Duyurular'},
  ];

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return const Scaffold(
        backgroundColor: _navy,
        body: Center(child: CircularProgressIndicator(color: _orange)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Servisim360', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(_personelBilgi['ad'] ?? 'Personel',
              style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: _tabIcerigi(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _navy,
        unselectedItemColor: Colors.grey,
        items: _tablar.map((t) => BottomNavigationBarItem(
          icon: Icon(t['ikon'] as IconData),
          label: t['label'] as String,
        )).toList(),
      ),
    );
  }

  Widget _tabIcerigi() {
    switch (_tab) {
      case 0: return _AnaSayfa(
          firmaId: _firmaId,
          personelBilgi: _personelBilgi,
          servisBilgi: _servisBilgi);
      case 1: return _ServisimSekme(
          firmaId: _firmaId,
          personelBilgi: _personelBilgi);
      case 2: return _DevamsizlikSekme(
          firmaId: _firmaId,
          personelId: _personelId,
          personelBilgi: _personelBilgi);
      case 3: return _DuyurularSekme(firmaId: _firmaId);
      default: return _AnaSayfa(
          firmaId: _firmaId,
          personelBilgi: _personelBilgi,
          servisBilgi: _servisBilgi);
    }
  }
}

// ======================================================================
// ANA SAYFA
// ======================================================================
class _AnaSayfa extends StatelessWidget {
  final String firmaId;
  final Map<String, dynamic> personelBilgi;
  final Map<String, dynamic> servisBilgi;
  const _AnaSayfa({
    required this.firmaId,
    required this.personelBilgi,
    required this.servisBilgi,
  });

  static const _navy   = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);

  @override
  Widget build(BuildContext context) {
    final ad        = personelBilgi['ad'] ?? 'Personel';
    final departman = personelBilgi['departman'] ?? '';
    final gorev     = personelBilgi['gorevUnvani'] ?? '';
    final servisVar = servisBilgi.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Hosgeldin karti
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [_navy, Color(0xFF2a4d8b)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: _orange,
                child: Text(ad.isNotEmpty ? ad[0].toUpperCase() : 'P',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 20)),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Merhaba, $ad',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 16)),
                if (departman.isNotEmpty)
                  Text(departman,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                if (gorev.isNotEmpty)
                  Text(gorev,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11)),
              ])),
            ]),
          ]),
        ),

        const SizedBox(height: 20),

        // Servis durumu
        const Text('Bugunun Servisi',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: _navy)),
        const SizedBox(height: 10),

        if (!servisVar)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [
              Icon(Icons.info_outline, color: Colors.grey),
              SizedBox(width: 10),
              Text('Aktif servis bulunamadi',
                  style: TextStyle(color: Colors.grey)),
            ]),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3))),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.directions_bus_outlined,
                    color: Colors.green, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(servisBilgi['plaka'] ?? '-',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16, letterSpacing: 1)),
                Text(servisBilgi['soforAd'] ?? 'Sofor bilgisi yok',
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 12)),
                if (servisBilgi['sabahSaati'] != null)
                  Text('Kalkis: ${servisBilgi['sabahSaati']}',
                      style: const TextStyle(
                          color: _orange,
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: const Text('Aktif',
                    style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 11)),
              ),
            ]),
          ),

        const SizedBox(height: 20),

        // Hizli islemler
        const Text('Hizli Islemler',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: _navy)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _hizliButon(
              context,
              Icons.event_busy_outlined,
              'Devamsizlik\nBildir',
              Colors.red,
                  () => _devamsizlikDialog(context, firmaId,
                  personelBilgi['ad'] ?? '', personelBilgi['departman'] ?? ''))),
          const SizedBox(width: 12),
          Expanded(child: _hizliButon(
              context,
              Icons.directions_bus_outlined,
              'Servisi\nTakip Et',
              _navy,
                  () {})),
          const SizedBox(width: 12),
          Expanded(child: _hizliButon(
              context,
              Icons.campaign_outlined,
              'Duyuru\nGor',
              _orange,
                  () {})),
        ]),

        const SizedBox(height: 20),

        // Son devamsizliklar
        const Text('Son Devamsizliklarim',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: _navy)),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('personel_devamsizlik')
              .where('firmaId', isEqualTo: firmaId)
              .where('personelId', isEqualTo:
          FirebaseAuth.instance.currentUser?.uid ?? '')
              .orderBy('tarih', descending: true)
              .limit(3)
              .snapshots(),
          builder: (_, snap) {
            final docs = snap.data?.docs ?? [];
            if (docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10)),
                child: const Text('Devamsizlik kaydiniz yok',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
              );
            }
            return Column(children: docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final tip = d['tip'] ?? 'tam_gun';
              final renk = tip == 'sabah' ? Colors.orange
                  : tip == 'aksam' ? Colors.blue : Colors.red;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: renk.withValues(alpha: 0.2))),
                child: Row(children: [
                  Icon(Icons.event_busy_outlined, color: renk, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                      tip == 'sabah' ? 'Sabah gelmedim'
                          : tip == 'aksam' ? 'Aksam gelmedim'
                          : 'Tam gun gelmedim',
                      style: TextStyle(
                          color: renk,
                          fontWeight: FontWeight.w600,
                          fontSize: 13))),
                  if (d['tarih'] != null)
                    Text(_tarihBicim(d['tarih']),
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 11)),
                ]),
              );
            }).toList());
          },
        ),
      ]),
    );
  }

  Widget _hizliButon(BuildContext context, IconData ikon,
      String label, Color renk, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: renk.withValues(alpha: 0.2))),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(ikon, color: renk, size: 26),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: renk,
                    fontWeight: FontWeight.bold,
                    fontSize: 11)),
          ]),
        ),
      );

  String _tarihBicim(dynamic ts) {
    if (ts == null) return '';
    final dt = (ts as Timestamp).toDate();
    return '${dt.day}.${dt.month}.${dt.year}';
  }

  void _devamsizlikDialog(BuildContext context, String firmaId,
      String personelAd, String departman) {
    String tip = 'tam_gun';
    final acikCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const Text('Devamsizlik Bildir',
              style: TextStyle(
                  color: _navy, fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            ...{
              'tam_gun': 'Bugun gelmeyecegim',
              'sabah':   'Sabah gelmeyecegim',
              'aksam':   'Aksam gelmeyecegim',
            }.entries.map((e) {
              final sec = tip == e.key;
              return GestureDetector(
                onTap: () => setD(() => tip = e.key),
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                      color: sec
                          ? _navy.withValues(alpha: 0.08)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: sec ? _navy : Colors.grey.shade200)),
                  child: Row(children: [
                    Icon(
                        sec
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: sec ? _navy : Colors.grey,
                        size: 18),
                    const SizedBox(width: 10),
                    Text(e.value,
                        style: TextStyle(
                            color: sec ? _navy : Colors.grey[700],
                            fontWeight: sec
                                ? FontWeight.bold
                                : FontWeight.normal)),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 8),
            TextField(
              controller: acikCtrl,
              decoration: InputDecoration(
                hintText: 'Aciklama (opsiyonel)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(12),
              ),
              maxLines: 2,
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx),
                child: const Text('Iptal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                await FirebaseFirestore.instance
                    .collection('personel_devamsizlik').add({
                  'firmaId':     firmaId,
                  'personelId':  user?.uid ?? '',
                  'personelAd':  personelAd,
                  'departman':   departman,
                  'tip':         tip,
                  'aciklama':    acikCtrl.text.trim(),
                  'tarih':       FieldValue.serverTimestamp(),
                  'okundu':      false,
                });
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Devamsizlik bildiriminiz gonderildi'),
                          backgroundColor: Colors.green));
                }
              },
              child: const Text('Gonder',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// SERVISIM SEKMESI
// ======================================================================
class _ServisimSekme extends StatefulWidget {
  final String firmaId;
  final Map<String, dynamic> personelBilgi;
  const _ServisimSekme({
    required this.firmaId,
    required this.personelBilgi,
  });
  @override
  State<_ServisimSekme> createState() => _ServisimSekmeState();
}

class _ServisimSekmeState extends State<_ServisimSekme> {
  static const _navy   = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);

  List<Map<String, dynamic>> _servisler = [];
  bool _yukleniyor = true;

  @override
  void initState() { super.initState(); _yukle(); }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('vehicles')
          .where('firmaId', isEqualTo: widget.firmaId)
          .get();
      if (mounted) setState(() {
        _servisler = snap.docs
            .map((d) => {'id': d.id, ...d.data()}).toList();
        _yukleniyor = false;
      });
    } catch (_) {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Servis Bilgilerim',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: _navy)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10)),
            child: const Row(children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 14),
              SizedBox(width: 8),
              Expanded(child: Text(
                  'Firmanizdaki aktif servisler asagida listelenmektedir.',
                  style: TextStyle(color: Colors.blue, fontSize: 12))),
            ]),
          ),
          const SizedBox(height: 16),
          if (_yukleniyor)
            const Center(child: CircularProgressIndicator(color: _orange))
          else if (_servisler.isEmpty)
            const Center(child: Text('Servis bulunamadi',
                style: TextStyle(color: Colors.grey)))
          else
            Expanded(
              child: ListView.separated(
                itemCount: _servisler.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final s = _servisler[i];
                  final aktif = s['servisAktif'] == true;
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: aktif
                                ? Colors.green.withValues(alpha: 0.3)
                                : Colors.grey.withValues(alpha: 0.2))),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: aktif
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.directions_bus_outlined,
                            color: aktif ? Colors.green : Colors.grey,
                            size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s['plaka'] ?? '-',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15, letterSpacing: 1)),
                            Text(s['soforAd'] ?? 'Sofor atanmamis',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                            if (s['sabahSaati'] != null)
                              Text('Sabah: ${s['sabahSaati']}',
                                  style: TextStyle(
                                      color: _orange, fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                          ])),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: aktif
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(aktif ? 'Aktif' : 'Pasif',
                            style: TextStyle(
                                color: aktif ? Colors.green : Colors.grey,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                    ]),
                  );
                },
              ),
            ),
        ]),
      ),
    );
  }
}

// ======================================================================
// DEVAMSIZLIK SEKMESI
// ======================================================================
class _DevamsizlikSekme extends StatefulWidget {
  final String firmaId;
  final String personelId;
  final Map<String, dynamic> personelBilgi;
  const _DevamsizlikSekme({
    required this.firmaId,
    required this.personelId,
    required this.personelBilgi,
  });
  @override
  State<_DevamsizlikSekme> createState() => _DevamsizlikSekmeState();
}

class _DevamsizlikSekmeState extends State<_DevamsizlikSekme> {
  static const _navy   = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);
  bool _gonderiyor = false;
  String _secilenTip = 'tam_gun';
  final _acikCtrl = TextEditingController();

  @override
  void dispose() { _acikCtrl.dispose(); super.dispose(); }

  Future<void> _gonder() async {
    setState(() => _gonderiyor = true);
    try {
      await FirebaseFirestore.instance
          .collection('personel_devamsizlik').add({
        'firmaId':    widget.firmaId,
        'personelId': widget.personelId,
        'personelAd': widget.personelBilgi['ad'] ?? '',
        'departman':  widget.personelBilgi['departman'] ?? '',
        'tip':        _secilenTip,
        'aciklama':   _acikCtrl.text.trim(),
        'tarih':      FieldValue.serverTimestamp(),
        'okundu':     false,
      });
      _acikCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Devamsizlik bildiriminiz gonderildi'),
                backgroundColor: Colors.green));
      }
    } catch (_) {}
    if (mounted) setState(() => _gonderiyor = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Devamsizlik Bildir',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: _navy)),
          const SizedBox(height: 16),

          // Tip secim
          const Text('Devamsizlik Tipi',
              style: TextStyle(fontWeight: FontWeight.bold, color: _navy)),
          const SizedBox(height: 10),

          ...{
            'tam_gun': {
              'label': 'Bugun Gelmeyecegim',
              'alt':   'Sabah ve aksam servisi kullanmayacagim',
              'ikon':  Icons.cancel_outlined,
              'renk':  Colors.red,
            },
            'sabah': {
              'label': 'Sabah Gelmeyecegim',
              'alt':   'Sadece aksam servisi kullanacagim',
              'ikon':  Icons.wb_sunny_outlined,
              'renk':  Colors.orange,
            },
            'aksam': {
              'label': 'Aksam Gelmeyecegim',
              'alt':   'Sadece sabah servisi kullanacagim',
              'ikon':  Icons.nights_stay_outlined,
              'renk':  Colors.blue,
            },
          }.entries.map((e) {
            final tip = e.key;
            final info = e.value;
            final sec = _secilenTip == tip;
            final renk = info['renk'] as Color;

            return GestureDetector(
              onTap: () => setState(() => _secilenTip = tip),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: sec ? renk.withValues(alpha: 0.08) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: sec ? renk : Colors.grey.shade200,
                        width: sec ? 2 : 1)),
                child: Row(children: [
                  Icon(info['ikon'] as IconData,
                      color: sec ? renk : Colors.grey, size: 24),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(info['label'] as String,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: sec ? renk : Colors.black87)),
                        Text(info['alt'] as String,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12)),
                      ])),
                  if (sec) Icon(Icons.check_circle, color: renk, size: 20),
                ]),
              ),
            );
          }),

          const SizedBox(height: 16),

          // Aciklama
          const Text('Aciklama',
              style: TextStyle(fontWeight: FontWeight.bold, color: _navy)),
          const SizedBox(height: 8),
          TextField(
            controller: _acikCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Devamsizlik nedeninizi yazabilirsiniz (opsiyonel)',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(14),
            ),
          ),

          const SizedBox(height: 20),

          // Gonder
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              onPressed: _gonderiyor ? null : _gonder,
              icon: _gonderiyor
                  ? const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_outlined),
              label: Text(_gonderiyor ? 'Gonderiliyor...' : 'Bildir'),
            ),
          ),

          const SizedBox(height: 24),

          // Gecmis
          const Text('Gecmis Bildirimlerim',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: _navy)),
          const SizedBox(height: 10),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('personel_devamsizlik')
                .where('firmaId', isEqualTo: widget.firmaId)
                .where('personelId', isEqualTo: widget.personelId)
                .orderBy('tarih', descending: true)
                .limit(10)
                .snapshots(),
            builder: (_, snap) {
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Text('Gecmis devamsizlik kaydi yok',
                      style: TextStyle(color: Colors.grey)),
                );
              }
              return Column(children: docs.map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final tip = d['tip'] ?? 'tam_gun';
                final renk = tip == 'sabah' ? Colors.orange
                    : tip == 'aksam' ? Colors.blue : Colors.red;
                final tipLabel = tip == 'sabah' ? 'Sabah Gelmedi'
                    : tip == 'aksam' ? 'Aksam Gelmedi' : 'Tam Gun';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: renk.withValues(alpha: 0.2))),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: renk.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.event_busy_outlined,
                          color: renk, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tipLabel,
                              style: TextStyle(
                                  color: renk,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                          if (d['aciklama'] != null && d['aciklama'] != '')
                            Text(d['aciklama'],
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 11)),
                        ])),
                    if (d['tarih'] != null)
                      Text(_tarihBicim(d['tarih']),
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 11)),
                  ]),
                );
              }).toList());
            },
          ),
        ]),
      ),
    );
  }

  String _tarihBicim(dynamic ts) {
    if (ts == null) return '';
    final dt = (ts as Timestamp).toDate();
    return '${dt.day}.${dt.month}.${dt.year}';
  }
}

// ======================================================================
// DUYURULAR SEKMESI
// ======================================================================
class _DuyurularSekme extends StatelessWidget {
  final String firmaId;
  const _DuyurularSekme({required this.firmaId});

  static const _navy = Color(0xFF1a3a6b);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Duyurular',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: _navy)),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bildirimler')
                  .where('firmaId', isEqualTo: firmaId)
                  .orderBy('tarih', descending: true)
                  .limit(30)
                  .snapshots(),
              builder: (_, snap) {
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                      child: Text('Duyuru bulunamadi',
                          style: TextStyle(color: Colors.grey)));
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final d = docs[i].data() as Map<String, dynamic>;
                    final ts = d['tarih'];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 4)]),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: _navy.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Icon(
                                  Icons.campaign_outlined,
                                  color: _navy, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(d['mesaj'] ?? '',
                                      style: const TextStyle(fontSize: 13)),
                                  const SizedBox(height: 4),
                                  if (ts != null)
                                    Text(_tarihBicim(ts),
                                        style: const TextStyle(
                                            color: Colors.grey, fontSize: 11)),
                                ])),
                          ]),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  String _tarihBicim(dynamic ts) {
    if (ts == null) return '';
    final dt = (ts as Timestamp).toDate();
    return '${dt.day}.${dt.month}.${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}
