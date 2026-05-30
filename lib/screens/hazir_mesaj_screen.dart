import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Kullanim:
// Sofor: HazirMesajScreen(mod: 'sofor', karsiId: veliId, karsiAdi: veliAdi)
// Veli:  HazirMesajScreen(mod: 'veli',  karsiId: surucuId, karsiAdi: surucuAdi)

class HazirMesajScreen extends StatefulWidget {
  final String mod; // 'sofor' veya 'veli'
  final String karsiId;
  final String karsiAdi;

  const HazirMesajScreen({
    super.key,
    required this.mod,
    required this.karsiId,
    required this.karsiAdi,
  });

  @override
  State<HazirMesajScreen> createState() => _HazirMesajScreenState();
}

class _HazirMesajScreenState extends State<HazirMesajScreen> {
  static const Color navy = Color(0xFF1a3a6b);
  static const Color orange = Color(0xFFFF8C00);

  static const List<Map<String, dynamic>> _varsayilanMesajlar = [
    {'ikon': '?', 'metin': 'Servis nerede?', 'kime': 'veli'},
    {'ikon': '?', 'metin': '5 dakika gecikeceGiz', 'kime': 'sofor'},
    {'ikon': '?', 'metin': 'Servis yola cikti', 'kime': 'sofor'},
    {'ikon': '?', 'metin': 'DuraSa yaklasiyoruz', 'kime': 'sofor'},
    {'ikon': '?', 'metin': 'OGrencı bindı', 'kime': 'sofor'},
    {'ikon': '?', 'metin': 'OGrencı bugun yok', 'kime': 'veli'},
    {'ikon': '?', 'metin': '10 dak sonra duraGinızdayız', 'kime': 'sofor'},
    {'ikon': '?', 'metin': 'Lutfen telefona cıkın', 'kime': 'her'},
    {'ikon': '?', 'metin': 'Hazir olun geliyoruz', 'kime': 'sofor'},
    {'ikon': '?', 'metin': 'OGrencı okula ulastı', 'kime': 'sofor'},
    {'ikon': '?', 'metin': 'OGrencı eve ulastı', 'kime': 'sofor'},
    {'ikon': '?', 'metin': 'Acil durum lutfen arayın', 'kime': 'her'},
  ];

  String _konusmaId = '';
  bool _yukleniyor = true;
  final ScrollController _scrollCtrl = ScrollController();

  String get _benimId =>
      FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _konusmaIdBelirle();
  }

  Future<void> _konusmaIdBelirle() async {
    if (_benimId.isEmpty) return;
    final ids = [_benimId, widget.karsiId]..sort();
    final id = '${ids[0]}_${ids[1]}';
    final ref =
    FirebaseFirestore.instance.collection('konusmalar').doc(id);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'surucuId':
        widget.mod == 'sofor' ? _benimId : widget.karsiId,
        'veliId':
        widget.mod == 'veli' ? _benimId : widget.karsiId,
        'olusturmaTarihi': FieldValue.serverTimestamp(),
        'sonMesaj': '',
        'sonMesajZamani': FieldValue.serverTimestamp(),
      });
    }
    setState(() {
      _konusmaId = id;
      _yukleniyor = false;
    });
  }

  Future<void> _mesajGonder(String metin) async {
    if (_konusmaId.isEmpty || _benimId.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('konusmalar')
        .doc(_konusmaId)
        .collection('mesajlar')
        .add({
      'gondericId': _benimId,
      'gondericMod': widget.mod,
      'metin': metin,
      'zaman': FieldValue.serverTimestamp(),
      'okundu': false,
    });
    await FirebaseFirestore.instance
        .collection('konusmalar')
        .doc(_konusmaId)
        .update({
      'sonMesaj': metin,
      'sonMesajZamani': FieldValue.serverTimestamp(),
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  List<Map<String, dynamic>> get _benimMesajlarim =>
      _varsayilanMesajlar.where((m) {
        final kime = m['kime'] as String;
        return kime == 'her' || kime == widget.mod;
      }).toList();

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: orange,
              radius: 18,
              child: Text(
                widget.karsiAdi.isNotEmpty
                    ? widget.karsiAdi[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Text(widget.karsiAdi,
                style:
                const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _mesajListesi()),
          _hazirMesajBar(),
        ],
      ),
    );
  }

  Widget _mesajListesi() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('konusmalar')
          .doc(_konusmaId)
          .collection('mesajlar')
          .orderBy('zaman')
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final mesajlar = snap.data!.docs;
        if (mesajlar.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                const Text('Henuz mesaj yok',
                    style: TextStyle(color: Colors.grey)),
                const Text('Asagidan hazir mesaj gonderin',
                    style:
                    TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          );
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollCtrl.hasClients) {
            _scrollCtrl
                .jumpTo(_scrollCtrl.position.maxScrollExtent);
          }
        });
        return ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 12),
          itemCount: mesajlar.length,
          itemBuilder: (ctx, i) {
            final d = mesajlar[i].data() as Map<String, dynamic>;
            final benimMesajim = d['gondericId'] == _benimId;
            final zaman = d['zaman'] as Timestamp?;
            final zamanStr = zaman != null
                ? '${zaman.toDate().hour.toString().padLeft(2, '0')}:${zaman.toDate().minute.toString().padLeft(2, '0')}'
                : '';
            return Align(
              alignment: benimMesajim
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                constraints: BoxConstraints(
                    maxWidth:
                    MediaQuery.of(context).size.width * 0.75),
                decoration: BoxDecoration(
                  color: benimMesajim ? navy : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft:
                    Radius.circular(benimMesajim ? 16 : 4),
                    bottomRight:
                    Radius.circular(benimMesajim ? 4 : 16),
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: benimMesajim
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Text(d['metin'] ?? '',
                        style: TextStyle(
                            color: benimMesajim
                                ? Colors.white
                                : Colors.black87,
                            fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(zamanStr,
                        style: TextStyle(
                            color: benimMesajim
                                ? Colors.white54
                                : Colors.grey,
                            fontSize: 11)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _hazirMesajBar() {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            child: Text('Hazir Mesajlar',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500)),
          ),
          SizedBox(
            height: 120,
            child: ListView.separated(
              padding:
              const EdgeInsets.fromLTRB(12, 0, 12, 12),
              scrollDirection: Axis.horizontal,
              itemCount: _benimMesajlarim.length,
              separatorBuilder: (_, __) =>
              const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final m = _benimMesajlarim[i];
                return GestureDetector(
                  onTap: () =>
                      _mesajGonder('${m['ikon']} ${m['metin']}'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: navy.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: navy.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(m['ikon'],
                            style: const TextStyle(fontSize: 22)),
                        const SizedBox(height: 4),
                        Text(m['metin'],
                            style: const TextStyle(
                                fontSize: 11, color: navy),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }
}
