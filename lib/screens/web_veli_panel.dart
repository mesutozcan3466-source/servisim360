import 'package:flutter/material.dart';
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
  double _fiyat = 0;
  bool _sozlesmeOnay = false;
  String _projeAd = '';
  String _ogrenciId = '';

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
    // Fiyat ve sözleşme bilgisi
    try {
      if (_ogrenci != null) {
        _fiyat = (_ogrenci!['fiyat'] ?? _ogrenci!['ucret'] ?? 0).toDouble();
        _sozlesmeOnay = _ogrenci!['sozlesmeOnay'] == true;
        _projeAd = _ogrenci!['projeAd'] ?? '';
        _ogrenciId = _ogrenci!['id'] ?? '';
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
              const SizedBox(height: 4),
              const Text('Bugunkü veya ilerleyen gun icin devamsizlik bildirin.',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 14),
              Wrap(spacing: 10, runSpacing: 10, children: [
                _DevBtn(Icons.event_busy_outlined, 'Bugun Gelmeyecek', const Color(0xFF1a3a6b), () => _devamsizlikBildir('bugun')),
                _DevBtn(Icons.wb_sunny_outlined, 'Sabah Gelmeyecek', Colors.orange, () => _devamsizlikBildir('sabah')),
                _DevBtn(Icons.nights_stay_outlined, 'Aksam Gelmeyecek', Colors.indigo, () => _devamsizlikBildir('aksam')),
                _DevBtn(Icons.calendar_month_outlined, 'Tarih Sec', Colors.teal, () => _devamsizlikBildir('tarih')),
              ]),
            ]),
          ),

          const SizedBox(height: 16),

          // Ücret ve sözleşme bilgisi
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Ücret kartı
            Expanded(child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.payments_outlined, color: Colors.teal, size: 16),
                  SizedBox(width: 6),
                  Text('Ucret Bilgisi', style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 13)),
                ]),
                const SizedBox(height: 12),
                if (_fiyat > 0) ...[
                  Text('${_fiyat.toStringAsFixed(0)} TL',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.teal)),
                  const Text('/ aylik', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ] else
                  const Text('Henuz belirlenmedi', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: (_sozlesmeOnay ? Colors.green : Colors.orange).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(_sozlesmeOnay ? '✓ Sozlesme Onaylandi' : '⏳ Sozlesme Bekleniyor',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                            color: _sozlesmeOnay ? Colors.green : Colors.orange))),
              ]),
            )),
            const SizedBox(width: 16),
            // Proje/servis bilgisi
            Expanded(child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.folder_outlined, color: Color(0xFF1a3a6b), size: 16),
                  SizedBox(width: 6),
                  Text('Servis Bilgisi', style: TextStyle(
                      fontWeight: FontWeight.bold, color: Color(0xFF1a3a6b), fontSize: 13)),
                ]),
                const SizedBox(height: 12),
                if (_projeAd.isNotEmpty) ...[
                  Text(_projeAd, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 4),
                ],
                if (_sofor != null) ...[
                  Text(_sofor!['ad'] ?? '', style: const TextStyle(fontSize: 13)),
                  Text(_sofor!['aracPlaka'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  if ((_sofor!['sabahSaati'] ?? '').isNotEmpty)
                    Padding(padding: const EdgeInsets.only(top: 4),
                        child: Row(children: [
                          const Icon(Icons.wb_sunny_outlined, size: 12, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(_sofor!['sabahSaati'], style: const TextStyle(fontSize: 11, color: Colors.orange)),
                          const SizedBox(width: 8),
                          if ((_sofor!['aksamSaati'] ?? '').isNotEmpty) ...[
                            const Icon(Icons.nights_stay_outlined, size: 12, color: Colors.indigo),
                            const SizedBox(width: 4),
                            Text(_sofor!['aksamSaati'], style: const TextStyle(fontSize: 11, color: Colors.indigo)),
                          ],
                        ])),
                ],
              ]),
            )),
          ]),

          const SizedBox(height: 16),

          // Servis geçmişi - son devamsızlıklar
          if (_ogrenciId.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.history_outlined, color: Color(0xFF1a3a6b), size: 18),
                  SizedBox(width: 8),
                  Text('Devamsizlik Gecmisi', style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1a3a6b))),
                ]),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('absence_requests')
                      .where('ogrenciId', isEqualTo: _ogrenciId)
                      .orderBy('tarih', descending: true).limit(5).snapshots(),
                  builder: (_, snap) {
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) return const Text('Devamsizlik kaydi yok.',
                        style: TextStyle(color: Colors.grey, fontSize: 13));
                    return Column(children: docs.map((doc) {
                      final d = doc.data() as Map<String, dynamic>;
                      final durum = d['durum'] ?? 'bildirildi';
                      final renk = durum == 'onaylandi' ? Colors.green : durum == 'reddedildi' ? Colors.red : Colors.orange;
                      final tarih = d['tarih'] is Timestamp
                          ? (d['tarih'] as Timestamp).toDate()
                          : DateTime.now();
                      return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: renk.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: renk.withValues(alpha: 0.2))),
                          child: Row(children: [
                            Icon(Icons.event_busy_outlined, color: renk, size: 14),
                            const SizedBox(width: 8),
                            Expanded(child: Text(d['aciklama'] ?? 'Devamsizlik',
                                style: const TextStyle(fontSize: 12))),
                            Text('${tarih.day}.${tarih.month}.${tarih.year}',
                                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                            const SizedBox(width: 6),
                            Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: renk.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4)),
                                child: Text(durum, style: TextStyle(fontSize: 10, color: renk, fontWeight: FontWeight.bold))),
                          ]));
                    }).toList());
                  },
                ),
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
    final aciklama = tip == 'sabah' ? 'Sadece sabah gelmeyecek (web)' :
    tip == 'aksam' ? 'Sadece aksam gelmeyecek (web)' :
    'Bugun hic gelmeyecek (web)';
    try {
      await FirebaseFirestore.instance.collection('absence_requests').add({
        'ogrenciId': _ogrenci!['id'],
        'ogrenciAd': _ogrenci!['ad'],
        'veliId':    FirebaseAuth.instance.currentUser?.uid,
        'surucuId':  _ogrenci!['surucuId'] ?? '',
        'firmaId':   _firmaId,
        'tarih':     Timestamp.fromDate(tarih),
        'aciklama':  aciklama,
        'tip':       tip == 'tarih' ? 'bugun' : tip,
        'durum':     'bildirildi',
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

class _DevBtn extends StatelessWidget {
  final IconData ikon; final String etiket; final Color renk; final VoidCallback onTap;
  const _DevBtn(this.ikon, this.etiket, this.renk, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: renk.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: renk.withValues(alpha: 0.25))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(ikon, size: 16, color: renk),
          const SizedBox(width: 6),
          Text(etiket, style: TextStyle(fontSize: 12, color: renk, fontWeight: FontWeight.w600)),
        ])),
  );
}
