import 'package:flutter/material.dart';
import 'responsive_wrapper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

// ════════════════════════════════════════════════════════════════
//  WEB VELİ PANELİ — PC'den çocuğunu takip eden veli
// ════════════════════════════════════════════════════════════════
class WebVeliPanel extends StatefulWidget {
  const WebVeliPanel({super.key});
  @override
  State<WebVeliPanel> createState() => _WebVeliPanelState();
}

class _WebVeliPanelState extends State<WebVeliPanel> {
  static const _navy   = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);

  Map<String, dynamic>? _ogrenci;
  Map<String, dynamic>? _sofor;
  bool _yukleniyor = true;
  String _firmaId  = '';
  String _veliAd   = '';
  bool _servisAktif = false;
  String _durumMesaji = 'Servis bekleniyor...';

  @override
  void initState() { super.initState(); _yukle(); }

  Future<void> _yukle() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    try {
      // Velinin bilgileri
      final veliDoc = await FirebaseFirestore.instance
          .collection('kullanicilar').doc(uid).get();
      _firmaId = veliDoc.data()?['firmaId'] as String? ?? '';
      _veliAd  = veliDoc.data()?['ad'] as String? ?? 'Veli';

      // Çocuğun bilgileri
      final oSnap = await FirebaseFirestore.instance.collection('students')
          .where('veliId', isEqualTo: uid)
          .limit(1).get();

      if (oSnap.docs.isEmpty) {
        // Email ile de dene
        final email = FirebaseAuth.instance.currentUser?.email ?? '';
        final oSnap2 = await FirebaseFirestore.instance.collection('students')
            .where('veliEmail', isEqualTo: email).limit(1).get();
        if (oSnap2.docs.isNotEmpty) {
          _ogrenci = {'id': oSnap2.docs.first.id, ...oSnap2.docs.first.data()};
        }
      } else {
        _ogrenci = {'id': oSnap.docs.first.id, ...oSnap.docs.first.data()};
      }

      // Şoför bilgileri
      if (_ogrenci != null) {
        final sid = (_ogrenci!['surucuId'] ?? '') as String;
        if (sid.isNotEmpty) {
          final sDoc = await FirebaseFirestore.instance
              .collection('drivers').doc(sid).get();
          if (sDoc.exists) {
            _sofor = sDoc.data();
            _servisAktif = _sofor!['servisAktif'] == true;
            _durumMesaji = _servisAktif ? 'Servis yolda' : 'Servis beklemede';
          }
        }
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
          const Icon(Icons.family_restroom_outlined, size: 20),
          const SizedBox(width: 8),
          Text(_veliAd.isEmpty ? 'Veli Paneli' : _veliAd,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: _ogrenci == null
          ? _kayitYokView()
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Servis durum kartı
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _servisAktif ? Colors.green : _navy,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(_servisAktif
                      ? Icons.directions_bus_outlined : Icons.schedule_outlined,
                      color: Colors.white, size: 28)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_durumMesaji,
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 18)),
                Text(_ogrenci!['ad'] ?? 'Ogrenci',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ])),
              if (_servisAktif)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20)),
                  child: const Text('CANLI', style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold, fontSize: 12)),
                ),
            ]),
          ),

          const SizedBox(height: 16),

          // Çocuk ve şoför bilgileri
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Çocuk bilgisi
            Expanded(child: _BilgiKarti(
              baslik: 'Ogrenci Bilgisi',
              ikon: Icons.school_outlined,
              renk: _navy,
              satirlar: [
                _BilgiSatir('Ad', _ogrenci!['ad'] ?? '-'),
                _BilgiSatir('Adres', _ogrenci!['adres'] ?? '-'),
                _BilgiSatir('Durum', _ogrenci!['bindi'] == true ? 'Bindi' : 'Bekliyor'),
              ],
            )),
            const SizedBox(width: 16),
            // Şoför bilgisi
            if (_sofor != null) Expanded(child: _BilgiKarti(
              baslik: 'Sofor Bilgisi',
              ikon: Icons.drive_eta_outlined,
              renk: _orange,
              satirlar: [
                _BilgiSatir('Ad', _sofor!['ad'] ?? '-'),
                _BilgiSatir('Plaka', _sofor!['aracPlaka'] ?? '-'),
                _BilgiSatir('Tel', _sofor!['telefon'] ?? '-'),
              ],
              aksiyonlar: [
                if ((_sofor!['telefon'] ?? '').isNotEmpty)
                  _AksiyonButon(Icons.phone_outlined, 'Ara', Colors.blue,
                          () => launchUrl(Uri.parse('tel:${_sofor!['telefon']}'))),
                if ((_sofor!['telefon'] ?? '').isNotEmpty)
                  _AksiyonButon(Icons.message, 'WhatsApp', const Color(0xFF25D366),
                          () => launchUrl(Uri.parse(
                          'https://wa.me/90${(_sofor!['telefon'] ?? '').replaceAll(RegExp(r'[^\d]'), '')}'))),
              ],
            )),
          ]),

          const SizedBox(height: 16),

          // Devamsızlık bildirimi
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.event_busy_outlined, color: Color(0xFF1a3a6b), size: 18),
                SizedBox(width: 8),
                Text('Devamsizlik Bildir', style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1a3a6b))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                  icon: const Icon(Icons.event_busy_outlined, size: 16),
                  label: const Text('Bugunku Devamsizlik'),
                  onPressed: () => _devamsizlikBildir('bugun'),
                )),
                const SizedBox(width: 12),
                Expanded(child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: _navy,
                      side: const BorderSide(color: Color(0xFF1a3a6b)),
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                  icon: const Icon(Icons.calendar_month_outlined, size: 16),
                  label: const Text('Tarih Sec'),
                  onPressed: () => _devamsizlikBildir('tarih'),
                )),
              ]),
            ]),
          ),

          const SizedBox(height: 16),

          // Mobil uygulama
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: _navy.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _navy.withValues(alpha: 0.2))),
            child: Row(children: [
              const Icon(Icons.android_outlined, color: Color(0xFF1a3a6b), size: 24),
              const SizedBox(width: 12),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Mobil Uygulama', style: TextStyle(fontWeight: FontWeight.bold,
                    color: Color(0xFF1a3a6b))),
                Text('Canli harita icin Android uygulamasini indirin',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              ])),
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: _navy,
                    side: const BorderSide(color: Color(0xFF1a3a6b))),
                onPressed: () => launchUrl(Uri.parse(
                    'https://play.google.com/store/apps/details?id=com.servisim.servisim')),
                child: const Text('Indir', style: TextStyle(fontSize: 12)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _kayitYokView() => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.child_care_outlined, size: 72, color: Colors.grey),
      const SizedBox(height: 16),
      const Text('Kayitli ogrenci bulunamadi',
          style: TextStyle(fontSize: 16, color: Colors.grey)),
      const SizedBox(height: 8),
      const Text('Servis firmanizla iletisime gecin.',
          style: TextStyle(color: Colors.grey)),
      const SizedBox(height: 20),
      ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
        onPressed: () async {
          await FirebaseAuth.instance.signOut();
          if (mounted) Navigator.pushReplacementNamed(context, '/login');
        },
        child: const Text('Cikis Yap'),
      ),
    ],
  ));

  Future<void> _devamsizlikBildir(String tip) async {
    if (_ogrenci == null) return;
    DateTime tarih = DateTime.now();
    if (tip == 'tarih') {
      final secilen = await showDatePicker(
        context: context,
        initialDate: tarih,
        firstDate: tarih,
        lastDate: tarih.add(const Duration(days: 30)),
        locale: const Locale('tr'),
      );
      if (secilen == null) return;
      tarih = secilen;
    }
    try {
      await FirebaseFirestore.instance.collection('absence_requests').add({
        'ogrenciId': _ogrenci!['id'],
        'ogrenciAd': _ogrenci!['ad'],
        'veliId':    FirebaseAuth.instance.currentUser?.uid,
        'surucuId':  _ogrenci!['surucuId'] ?? '',
        'firmaId':   _firmaId,
        'tarih':     Timestamp.fromDate(tarih),
        'aciklama':  'Veli bildirimi (web)',
        'okundu':    false,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Devamsizlik bildirildi'),
              backgroundColor: Colors.green));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hata olustu'), backgroundColor: Colors.red));
    }
  }
}

// ── YARDIMCI WİDGETLER ───────────────────────────────────────────
class _BilgiSatir {
  final String etiket, deger;
  const _BilgiSatir(this.etiket, this.deger);
}

class _AksiyonButon {
  final IconData ikon; final String etiket; final Color renk; final VoidCallback onTap;
  const _AksiyonButon(this.ikon, this.etiket, this.renk, this.onTap);
}

class _BilgiKarti extends StatelessWidget {
  final String baslik; final IconData ikon; final Color renk;
  final List<_BilgiSatir> satirlar;
  final List<_AksiyonButon> aksiyonlar;
  const _BilgiKarti({required this.baslik, required this.ikon,
    required this.renk, required this.satirlar, this.aksiyonlar = const []});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(ikon, color: renk, size: 16),
        const SizedBox(width: 6),
        Text(baslik, style: TextStyle(fontWeight: FontWeight.bold, color: renk, fontSize: 13)),
      ]),
      const SizedBox(height: 12),
      ...satirlar.map((s) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          SizedBox(width: 60, child: Text(s.etiket,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]))),
          Expanded(child: Text(s.deger,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        ]),
      )),
      if (aksiyonlar.isNotEmpty) ...[
        const SizedBox(height: 10),
        Row(children: aksiyonlar.map((a) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: a.onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: a.renk.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(a.ikon, size: 14, color: a.renk),
                const SizedBox(width: 4),
                Text(a.etiket, style: TextStyle(fontSize: 11, color: a.renk,
                    fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
        )).toList()),
      ],
    ]),
  );
}
