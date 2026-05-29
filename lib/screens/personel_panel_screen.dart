import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/session_service.dart';

class PersonelPanelScreen extends StatefulWidget {
  const PersonelPanelScreen({super.key});
  @override
  State<PersonelPanelScreen> createState() => _PersonelPanelScreenState();
}

class _PersonelPanelScreenState extends State<PersonelPanelScreen>
    with SingleTickerProviderStateMixin {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  late final TabController _tabCtrl;
  Map<String, dynamic> _personelData = {};
  bool   _yukleniyor = true;
  String? _firmaId;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _yukle();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  Future<void> _yukle() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { setState(() => _yukleniyor = false); return; }

    _firmaId = await SessionService.instance.firmaIdAl();

    try {
      final kulDoc = await FirebaseFirestore.instance
          .collection('kullanicilar').doc(user.uid).get();
      _personelData = kulDoc.data() ?? {};

      // staff_members koleksiyonunda da ara
      final staffSnap = await FirebaseFirestore.instance
          .collection('staff_members')
          .where('uid', isEqualTo: user.uid).limit(1).get();
      if (staffSnap.docs.isNotEmpty) {
        _personelData = {
          ..._personelData,
          ...staffSnap.docs.first.data()
        };
      }
    } catch (e) {
      debugPrint('Personel yukle hata: $e');
    }

    if (mounted) setState(() => _yukleniyor = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return const Scaffold(
        backgroundColor: _navy,
        body: Center(child: CircularProgressIndicator(color: _turuncu)),
      );
    }

    final ad = _personelData['ad'] != null
        ? '${_personelData['ad']} ${_personelData['soyad'] ?? ''}'.trim()
        : _personelData['email'] ?? 'Personel';
    final gorev = _personelData['gorev'] as String? ?? 'Personel';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ad, style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold)),
          Text(gorev, style: const TextStyle(
              fontSize: 11, color: Colors.white60)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined, color: Colors.white70),
            onPressed: () async {
              await SessionService.instance.cikisYap();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: _turuncu,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Gorevler'),
            Tab(text: 'Ogrenciler'),
            Tab(text: 'Profil'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _gorevlerTab(),
          _ogrencilerTab(),
          _profilTab(ad, gorev),
        ],
      ),
    );
  }

  // ── Gorevler Tab ─────────────────────────────────────────────────────────────
  Widget _gorevlerTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // Hizli islemler
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12, mainAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _IslemKarti('Yoklama', Icons.fact_check_outlined,
                Colors.blue, () => Navigator.pushNamed(context, '/yoklama')),
            _IslemKarti('Ogrenciler', Icons.people_outline,
                _navy, () => Navigator.pushNamed(context, '/ogrenci')),
            _IslemKarti('Rotalar', Icons.route_outlined,
                Colors.teal, () => Navigator.pushNamed(context, '/rotalar')),
            _IslemKarti('Bildirimler', Icons.notifications_outlined,
                Colors.orange, () => Navigator.pushNamed(context, '/bildirimler')),
          ],
        ),
        const SizedBox(height: 20),

        // Bugunun gorevleri
        _Baslik('Bugunun Gorevleri'),
        const SizedBox(height: 8),
        if (_firmaId != null)
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('absence_requests')
                .where('firmaId', isEqualTo: _firmaId)
                .orderBy('tarih', descending: true)
                .limit(10)
                .snapshots(),
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6)],
                  ),
                  child: const Center(child: Text(
                      'Bekleyen devamsizlik bildirimi yok',
                      style: TextStyle(color: Colors.grey))),
                );
              }
              return Column(
                children: docs.map((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0x1AFF8C00),
                        child: Icon(Icons.person_off_outlined,
                            color: Colors.orange, size: 18),
                      ),
                      title: Text(
                          data['ogrenciAd'] as String? ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          data['sebep'] as String? ?? 'Sebep belirtilmedi',
                          style: const TextStyle(fontSize: 12)),
                      trailing: Text(
                          data['rotaAdi'] as String? ?? '',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                    ),
                  );
                }).toList(),
              );
            },
          )
        else
          const Text('Firma bilgisi yok',
              style: TextStyle(color: Colors.grey)),
      ]),
    );
  }

  // ── Ogrenciler Tab ───────────────────────────────────────────────────────────
  Widget _ogrencilerTab() {
    if (_firmaId == null) {
      return const Center(child: Text('Firma bilgisi yok',
          style: TextStyle(color: Colors.grey)));
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('students')
          .where('firmaId', isEqualTo: _firmaId)
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('Ogrenci bulunamadi',
              style: TextStyle(color: Colors.grey)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final bindi = data['bindi'] == true;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _navy.withValues(alpha: 0.1),
                  child: Text(
                    (data['ad'] as String? ?? 'O')[0].toUpperCase(),
                    style: const TextStyle(color: _navy,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                    '${data['ad'] ?? ''} ${data['soyad'] ?? ''}'.trim(),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(data['sinif'] as String? ?? '',
                    style: const TextStyle(fontSize: 12)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: bindi
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(bindi ? 'Serviste' : 'Bekliyor',
                      style: TextStyle(
                          color: bindi ? Colors.green : Colors.orange,
                          fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Profil Tab ───────────────────────────────────────────────────────────────
  Widget _profilTab(String ad, String gorev) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Avatar
        Center(
          child: Column(children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: _navy.withValues(alpha: 0.1),
              child: Text(
                ad.isNotEmpty ? ad[0].toUpperCase() : 'P',
                style: const TextStyle(color: _navy, fontSize: 32,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            Text(ad, style: const TextStyle(fontSize: 18,
                fontWeight: FontWeight.bold, color: _navy)),
            Text(gorev, style: const TextStyle(
                fontSize: 13, color: Colors.grey)),
          ]),
        ),
        const SizedBox(height: 24),

        _BilgiSatiri('E-posta',
            _personelData['email'] as String? ?? '-'),
        _BilgiSatiri('Telefon',
            _personelData['telefon'] as String? ?? '-'),
        _BilgiSatiri('Firma ID', _firmaId ?? '-'),
        _BilgiSatiri('Rol',
            _personelData['rol'] as String? ?? 'personel'),
        const SizedBox(height: 16),

        ListTile(
          leading: const Icon(Icons.settings_outlined, color: _navy),
          title: const Text('Ayarlar'),
          trailing: const Icon(Icons.arrow_forward_ios_outlined,
              size: 14, color: Colors.grey),
          onTap: () => Navigator.pushNamed(context, '/ayarlar'),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout_outlined, color: Colors.red),
          title: const Text('Cikis Yap',
              style: TextStyle(color: Colors.red)),
          onTap: () async {
            await SessionService.instance.cikisYap();
            if (mounted) Navigator.pushReplacementNamed(context, '/login');
          },
        ),
      ],
    );
  }
}

// ── Yardimci Widgetlar ────────────────────────────────────────────────────────
class _IslemKarti extends StatelessWidget {
  final String etiket;
  final IconData ikon;
  final Color renk;
  final VoidCallback onTap;
  const _IslemKarti(this.etiket, this.ikon, this.renk, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: renk.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(ikon, color: renk, size: 24),
        ),
        const SizedBox(height: 8),
        Text(etiket, style: TextStyle(color: renk,
            fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
    ),
  );
}

class _Baslik extends StatelessWidget {
  final String text;
  const _Baslik(this.text);
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Text(text, style: const TextStyle(fontSize: 15,
        fontWeight: FontWeight.bold, color: Color(0xFF1a3a6b))),
  );
}

class _BilgiSatiri extends StatelessWidget {
  final String etiket, deger;
  static const _navy = Color(0xFF1a3a6b);
  const _BilgiSatiri(this.etiket, this.deger);

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
    ),
    child: Row(children: [
      Text(etiket, style: const TextStyle(
          fontSize: 13, color: Colors.grey)),
      const Spacer(),
      Text(deger, style: const TextStyle(fontSize: 13,
          fontWeight: FontWeight.bold, color: _navy)),
    ]),
  );
}
