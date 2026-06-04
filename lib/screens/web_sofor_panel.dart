import 'package:flutter/material.dart';
import 'yardim_widget.dart';
import 'responsive_wrapper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

// ════════════════════════════════════════════════════════════════
//  WEB ŞOFÖR PANELİ — Şoför web'de kullanır
//  Öğrenci listesi, devamsızlık, mesaj
// ════════════════════════════════════════════════════════════════
class WebSoforPanel extends StatefulWidget {
  const WebSoforPanel({super.key});
  @override
  State<WebSoforPanel> createState() => _WebSoforPanelState();
}

class _WebSoforPanelState extends State<WebSoforPanel>
    with SingleTickerProviderStateMixin {
  static const _navy   = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);

  late TabController _tab;
  String _surucuId = '';
  String _firmaId  = '';
  String _soforAd  = '';
  bool   _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _yukle();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _yukle() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { setState(() => _yukleniyor = false); return; }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('kullanicilar').doc(uid).get();
      _firmaId  = doc.data()?['firmaId']  as String? ?? '';
      _surucuId = doc.data()?['surucuId'] as String? ?? uid;

      final sDoc = await FirebaseFirestore.instance
          .collection('drivers').doc(_surucuId).get();
      if (sDoc.exists) {
        _soforAd = sDoc.data()?['ad'] as String? ?? 'Sofor';
        _firmaId = sDoc.data()?['firmaId'] as String? ?? _firmaId;
      }
    } catch (_) {}
    if (mounted) setState(() => _yukleniyor = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: _navy)));

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white,
        title: Row(children: [
          const Icon(Icons.directions_bus_outlined, size: 20),
          const SizedBox(width: 8),
          Text(_soforAd, style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
        actions: [
          YardimButonu(ekranAdi: 'Sofor Paneli'),
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: _orange,
          tabs: const [
            Tab(icon: Icon(Icons.people_outline), text: 'Ogrencilerim'),
            Tab(icon: Icon(Icons.event_busy_outlined), text: 'Devamsizlik'),
            Tab(icon: Icon(Icons.message_outlined), text: 'Mesajlar'),
          ],
        ),
      ),
      body: TabBarView(controller: _tab, children: [
        _OgrenciListesi(surucuId: _surucuId, firmaId: _firmaId),
        _DevamsizlikListesi(surucuId: _surucuId, firmaId: _firmaId),
        _MesajListesi(surucuId: _surucuId, firmaId: _firmaId, soforAd: _soforAd),
      ]),
    );
  }
}

// ── ÖĞRENCİ LİSTESİ ─────────────────────────────────────────────
class _OgrenciListesi extends StatelessWidget {
  final String surucuId, firmaId;
  static const _navy = Color(0xFF1a3a6b);
  const _OgrenciListesi({required this.surucuId, required this.firmaId});

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('students')
        .where('surucuId', isEqualTo: surucuId)
        .where('firmaId', isEqualTo: firmaId)
        .orderBy('sira').snapshots(),
    builder: (_, snap) {
      final docs = snap.data?.docs ?? [];
      return Column(children: [
        Container(
          padding: const EdgeInsets.all(12), color: Colors.white,
          child: Row(children: [
            const Icon(Icons.people_outline, color: _navy, size: 18),
            const SizedBox(width: 8),
            Text('${docs.length} ogrenci', style: const TextStyle(
                fontWeight: FontWeight.bold, color: _navy)),
          ]),
        ),
        Expanded(child: docs.isEmpty
            ? const Center(child: Text('Henuz ogrenci atanmadi'))
            : ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final bindi = d['bindi'] == true;
            final tel   = d['veliTel'] ?? d['telefon'] ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: bindi ? Border.all(color: Colors.green.withValues(alpha: 0.5)) : null,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
              ),
              child: Row(children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: bindi
                      ? Colors.green.withValues(alpha: 0.15)
                      : _navy.withValues(alpha: 0.1),
                  child: Text('${i+1}', style: TextStyle(
                      color: bindi ? Colors.green : _navy,
                      fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d['ad'] ?? '', style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(d['adres'] ?? '', style: TextStyle(
                      fontSize: 11, color: Colors.grey[500]),
                      overflow: TextOverflow.ellipsis),
                ])),
                if (bindi) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6)),
                  child: const Text('Bindi', style: TextStyle(
                      color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                if (tel.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.phone_outlined, color: _navy, size: 18),
                    onPressed: () => launchUrl(Uri.parse('tel:$tel')),
                    tooltip: 'Ara',
                  ),
                  IconButton(
                    icon: const Icon(Icons.message, color: Color(0xFF25D366), size: 18),
                    onPressed: () => launchUrl(Uri.parse(
                        'https://wa.me/90${tel.replaceAll(RegExp(r'[^\d]'), '')}')),
                    tooltip: 'WhatsApp',
                  ),
                ],
              ]),
            );
          },
        )),
      ]);
    },
  );
}

// ── DEVAMSIZLIK LİSTESİ ──────────────────────────────────────────
class _DevamsizlikListesi extends StatelessWidget {
  final String surucuId, firmaId;
  static const _navy = Color(0xFF1a3a6b);
  const _DevamsizlikListesi({required this.surucuId, required this.firmaId});

  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('absence_requests')
        .where('surucuId', isEqualTo: surucuId)
        .orderBy('tarih', descending: true)
        .limit(50).snapshots(),
    builder: (_, snap) {
      final docs = snap.data?.docs ?? [];
      return Column(children: [
        Container(
          padding: const EdgeInsets.all(12), color: Colors.white,
          child: Row(children: [
            const Icon(Icons.event_busy_outlined, color: Colors.red, size: 18),
            const SizedBox(width: 8),
            Text('${docs.length} devamsizlik bildirimi',
                style: const TextStyle(fontWeight: FontWeight.bold, color: _navy)),
          ]),
        ),
        Expanded(child: docs.isEmpty
            ? const Center(child: Text('Devamsizlik bildirimi yok'))
            : ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final t = d['tarih'] as Timestamp?;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]),
              child: Row(children: [
                Container(padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.event_busy_outlined, color: Colors.red, size: 18)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d['ogrenciAd'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(d['aciklama'] ?? d['tip'] ?? '',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ])),
                if (t != null) Text(
                  '${t.toDate().day}.${t.toDate().month}.${t.toDate().year}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                ),
              ]),
            );
          },
        )),
      ]);
    },
  );
}

// ── MESAJ LİSTESİ ────────────────────────────────────────────────
class _MesajListesi extends StatelessWidget {
  final String surucuId, firmaId, soforAd;
  static const _navy = Color(0xFF1a3a6b);
  const _MesajListesi({required this.surucuId, required this.firmaId, required this.soforAd});

  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.message_outlined, size: 64, color: _navy),
      const SizedBox(height: 16),
      const Text('Toplu mesaj gondermek icin',
          style: TextStyle(color: Colors.grey)),
      const SizedBox(height: 12),
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
            backgroundColor: _navy, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
        icon: const Icon(Icons.send_outlined),
        label: const Text('Toplu WhatsApp Gonder'),
        onPressed: () => Navigator.pushNamed(context, '/toplu_whatsapp'),
      ),
    ]),
  ));
}
