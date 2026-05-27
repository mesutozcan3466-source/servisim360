import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/hazir_mesaj_service.dart';
import '../services/session_service.dart';

class MesajWidget extends StatefulWidget {
  final String tip; // 'veli' veya 'sofor'
  final String aliciId;
  final String aliciAd;
  final String? surucuId;
  final String? veliId;

  const MesajWidget({
    super.key,
    required this.tip,
    required this.aliciId,
    required this.aliciAd,
    this.surucuId,
    this.veliId,
  });

  @override
  State<MesajWidget> createState() => _MesajWidgetState();
}

class _MesajWidgetState extends State<MesajWidget> {
  static const _navy = Color(0xFF1a3a6b);
  static const _ikonlar = {
    'location': Icons.location_on_outlined,
    'time':     Icons.access_time_outlined,
    'cancel':   Icons.cancel_outlined,
    'bus':      Icons.directions_bus_outlined,
    'bell':     Icons.notifications_outlined,
    'check':    Icons.check_circle_outlined,
    'school':   Icons.school_outlined,
    'message':  Icons.message_outlined,
  };

  String? _firmaId;
  String? _uid;
  String? _adim;
  List<Map<String, dynamic>> _hazirMesajlar = [];
  bool _yukleniyor = true;

  @override
  void initState() { super.initState(); _yukle(); }

  Future<void> _yukle() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _uid     = user.uid;
    _firmaId = await SessionService.instance.firmaldAl();

    final doc = await FirebaseFirestore.instance
        .collection('kullanicilar').doc(user.uid).get();
    _adim = doc.data()?['ad'] ?? 'Kullanıcı';

    if (_firmaId != null) {
      _hazirMesajlar = await HazirMesajService.mesajlariGetir(
          firmaId: _firmaId!, tip: widget.tip);
    }
    if (mounted) setState(() => _yukleniyor = false);
  }

  Future<void> _gonder(String metin) async {
    if (_uid == null || _firmaId == null) return;
    await HazirMesajService.mesajGonder(
      firmaId:     _firmaId!,
      gonderen:    widget.tip,
      gonderenId:  _uid!,
      gonderenAd:  _adim ?? '',
      aliciId:     widget.aliciId,
      mesajMetni:  metin,
      surucuId:    widget.surucuId,
      veliId:      widget.veliId,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text('Gönderildi: $metin'),
        ]),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
    }
  }

  void _konusmayiAc() {
    if (widget.surucuId == null || widget.veliId == null) return;
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _KonusmaSheet(
        surucuId: widget.surucuId!, veliId: widget.veliId!,
        aliciAd: widget.aliciAd, tip: widget.tip, uid: _uid ?? '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) return const Center(child: CircularProgressIndicator(color: _navy));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: _navy.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.message_outlined, color: _navy, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Hızlı Mesaj',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _navy)),
            Text(widget.aliciAd, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ])),
          if (widget.surucuId != null && widget.veliId != null)
            TextButton.icon(
              onPressed: _konusmayiAc,
              icon: const Icon(Icons.history, size: 15),
              label: const Text('Geçmiş', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                  foregroundColor: _navy,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
            ),
        ]),
        const SizedBox(height: 14),
        const Divider(height: 1, thickness: 0.5),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _hazirMesajlar.map((mesaj) {
            final ikonAdi = mesaj['ikon'] ?? 'message';
            final ikon    = _ikonlar[ikonAdi] ?? Icons.message_outlined;
            final metin   = mesaj['metin'] ?? '';
            return _MesajButonu(metin: metin, ikon: ikon, onTap: () => _gonder(metin));
          }).toList(),
        ),
      ]),
    );
  }
}

class _MesajButonu extends StatefulWidget {
  final String metin; final IconData ikon; final VoidCallback onTap;
  const _MesajButonu({required this.metin, required this.ikon, required this.onTap});

  @override
  State<_MesajButonu> createState() => _MesajButonuState();
}

class _MesajButonuState extends State<_MesajButonu> {
  static const _navy = Color(0xFF1a3a6b);
  bool _gonderildi = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _gonderildi ? null : () async {
        setState(() => _gonderildi = true);
        widget.onTap();
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) setState(() => _gonderildi = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _gonderildi ? Colors.green.withValues(alpha: 0.1) : _navy.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _gonderildi ? Colors.green.withValues(alpha: 0.4) : _navy.withValues(alpha: 0.15),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(_gonderildi ? Icons.check : widget.ikon,
              size: 14, color: _gonderildi ? Colors.green : _navy),
          const SizedBox(width: 6),
          Text(widget.metin,
              style: TextStyle(fontSize: 12, color: _gonderildi ? Colors.green : _navy,
                  fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

class _KonusmaSheet extends StatelessWidget {
  final String surucuId, veliId, aliciAd, tip, uid;
  static const _navy = Color(0xFF1a3a6b);
  const _KonusmaSheet({required this.surucuId, required this.veliId,
    required this.aliciAd, required this.tip, required this.uid});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFFF5F7FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.history, color: _navy),
              const SizedBox(width: 8),
              Text('$aliciAd ile Mesajlar',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _navy)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
          ]),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: HazirMesajService.konusmaDinle(surucuId: surucuId, veliId: veliId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: _navy));
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.message_outlined, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Text('Henüz mesaj yok', style: TextStyle(color: Colors.grey[400])),
                ]));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                reverse: true,
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final data    = docs[i].data() as Map<String, dynamic>;
                  final benden  = data['gonderenId'] == uid;
                  final tarih   = data['tarih'] as Timestamp?;
                  final saatStr = tarih != null
                      ? '${tarih.toDate().hour}:${tarih.toDate().minute.toString().padLeft(2, '0')}'
                      : '';
                  return Align(
                    alignment: benden ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                      decoration: BoxDecoration(
                        color: benden ? _navy : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(benden ? 16 : 4),
                          bottomRight: Radius.circular(benden ? 4 : 16),
                        ),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))],
                      ),
                      child: Column(
                        crossAxisAlignment: benden ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Text(data['metin'] ?? '',
                              style: TextStyle(color: benden ? Colors.white : Colors.black87, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(saatStr,
                              style: TextStyle(color: benden ? Colors.white60 : Colors.grey[400], fontSize: 10)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}
