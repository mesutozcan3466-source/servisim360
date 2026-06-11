import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/session_service.dart';
import 'web_giris_yonlendirici.dart';

// ======================================================================
// WEB KOLEJ PANEL=  =  Servisim360
// Rol: kolejAdmin  |  Sadece izler, y=netemez
// ======================================================================

const Color _kNavy   = Color(0xFF1a3a6b);
const Color _kOrange = Color(0xFFFF8C00);
const Color _kBg     = Color(0xFFF0F2F5);

class WebKolejPanel extends StatefulWidget {
  const WebKolejPanel({super.key});
  @override
  State<WebKolejPanel> createState() => _WebKolejPanelState();
}

class _WebKolejPanelState extends State<WebKolejPanel> {
  int  _menu    = 0;
  bool _sidebar = true;

  String _kolejAdi  = 'Kolej Paneli';
  String _firmaId   = '';
  bool   _yukleniyor = true;

  static const _menuler = [
    {'ikon': Icons.dashboard_outlined,       'etiket': 'Ana Ekran'},
    {'ikon': Icons.directions_bus_outlined,  'etiket': 'Canli Takip'},
    {'ikon': Icons.qr_code_scanner_outlined, 'etiket': 'Plaka Tanima'},
    {'ikon': Icons.security_outlined,        'etiket': 'Guvenlik'},
    {'ikon': Icons.map_outlined,             'etiket': 'Harita'},
    {'ikon': Icons.bar_chart_outlined,       'etiket': 'Raporlar'},
    {'ikon': Icons.campaign_outlined,        'etiket': 'Duyurular'},
  ];

  @override
  void initState() {
    super.initState();
    _baslat();
  }

  Future<void> _baslat() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('kullanicilar').doc(user.uid).get();
      final data = doc.data() ?? {};
      final fid  = data['firmaId'] as String? ?? '';
      final kad  = data['kolejAdi'] as String? ?? data['ad'] as String? ?? 'Kolej Paneli';
      if (fid.isNotEmpty) SessionService.instance.cachedFirmaIdSet(fid);
      if (mounted) {
        setState(() {
          _firmaId   = fid;
          _kolejAdi  = kad;
          _yukleniyor = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return const Scaffold(
        backgroundColor: _kNavy,
        body: Center(child: CircularProgressIndicator(color: _kOrange)),
      );
    }

    return Scaffold(
      backgroundColor: _kBg,
      body: Row(children: [
        // == Sidebar ==================================================
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: _sidebar ? 230 : 64,
          child: Container(
            color: _kNavy,
            child: Column(children: [
              // Logo
              Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                        color: _kOrange,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Center(
                        child: Text('K',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20))),
                  ),
                  if (_sidebar) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_kolejAdi,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                            const Text('Kolej Paneli',
                                style: TextStyle(
                                    color: Colors.amber, fontSize: 10)),
                          ]),
                    ),
                  ],
                ]),
              ),
              const Divider(color: Colors.white12, height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _menuler.length,
                  itemBuilder: (_, i) {
                    final aktif = _menu == i;
                    return InkWell(
                      onTap: () => setState(() => _menu = i),
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        padding: EdgeInsets.symmetric(
                            horizontal: _sidebar ? 12 : 8, vertical: 11),
                        decoration: BoxDecoration(
                          color: aktif ? _kOrange : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(children: [
                          Icon(_menuler[i]['ikon'] as IconData,
                              color: aktif ? Colors.white : Colors.white60,
                              size: 19),
                          if (_sidebar) ...[
                            const SizedBox(width: 10),
                            Text(_menuler[i]['etiket'] as String,
                                style: TextStyle(
                                    color: aktif
                                        ? Colors.white
                                        : Colors.white70,
                                    fontWeight: aktif
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 13)),
                          ],
                        ]),
                      ),
                    );
                  },
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              // Sadece izle uyar=s=
              if (_sidebar)
                Container(
                  margin: const EdgeInsets.all(10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Row(children: [
                    Icon(Icons.visibility_outlined,
                        color: Colors.white38, size: 14),
                    SizedBox(width: 6),
                    Expanded(
                        child: Text('Sadece izleme yetkisi',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 10))),
                  ]),
                ),
              InkWell(
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  if (mounted) {
                    Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                            const WebGirisYonlendirici()));
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    const Icon(Icons.logout_outlined,
                        color: Colors.white54, size: 18),
                    if (_sidebar) ...[
                      const SizedBox(width: 8),
                      const Text('Cikis Yap',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 12)),
                    ],
                  ]),
                ),
              ),
            ]),
          ),
        ),

        // == ==erik ===================================================
        Expanded(
          child: Column(children: [
            // Topbar
            Container(
              height: 60,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                IconButton(
                  icon: Icon(
                      _sidebar ? Icons.menu_open : Icons.menu,
                      color: _kNavy),
                  onPressed: () =>
                      setState(() => _sidebar = !_sidebar),
                ),
                const SizedBox(width: 8),
                Text(_menuler[_menu]['etiket'] as String,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: _kNavy)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(children: [
                    const Icon(Icons.school_outlined,
                        size: 14, color: Colors.blue),
                    const SizedBox(width: 6),
                    Text(_kolejAdi,
                        style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ]),
                ),
                const SizedBox(width: 12),
              ]),
            ),
            // Sayfa
            Expanded(child: _sayfaAl()),
          ]),
        ),
      ]),
    );
  }

  Widget _sayfaAl() {
    if (_firmaId.isEmpty) {
      return const Center(
          child: Text('Firma bilgisi bulunamadi.',
              style: TextStyle(color: Colors.grey)));
    }
    switch (_menu) {
      case 0: return _KolejAnaSayfa(firmaId: _firmaId);
      case 1: return _KolejCanliTakip(firmaId: _firmaId);
      case 2: return _KolejPlakaTanima(firmaId: _firmaId);
      case 3: return _KolejGuvenlik(firmaId: _firmaId);
      case 4: return _KolejHarita(firmaId: _firmaId);
      case 5: return _KolejRaporlar(firmaId: _firmaId);
      case 6: return _KolejDuyurular(firmaId: _firmaId);
      default: return _KolejAnaSayfa(firmaId: _firmaId);
    }
  }
}

// ======================================================================
// ANA EKRAN
// ======================================================================
class _KolejAnaSayfa extends StatefulWidget {
  final String firmaId;
  const _KolejAnaSayfa({required this.firmaId});
  @override
  State<_KolejAnaSayfa> createState() => _KolejAnaSayfaState();
}

class _KolejAnaSayfaState extends State<_KolejAnaSayfa> {
  Map<String, int> _sayilar = {};
  List<Map<String, dynamic>> _sonGirisler = [];
  List<Map<String, dynamic>> _acilar = [];
  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final bugun = DateTime.now();
      final bugunBaslangic = DateTime(bugun.year, bugun.month, bugun.day);

      final results = await Future.wait([
        // Toplam ara=
        FirebaseFirestore.instance
            .collection('vehicles')
            .where('firmaId', isEqualTo: widget.firmaId)
            .count().get(),
        // Aktif ara=lar
        FirebaseFirestore.instance
            .collection('vehicles')
            .where('firmaId', isEqualTo: widget.firmaId)
            .where('servisAktif', isEqualTo: true)
            .count().get(),
        // Bug=n plaka giri=
        FirebaseFirestore.instance
            .collection('plaka_kayitlari')
            .where('firmaId', isEqualTo: widget.firmaId)
            .where('tarih', isGreaterThanOrEqualTo:
        Timestamp.fromDate(bugunBaslangic))
            .count().get(),
        // Toplam =of=r
        FirebaseFirestore.instance
            .collection('drivers')
            .where('firmaId', isEqualTo: widget.firmaId)
            .count().get(),
      ]);

      // Son 5 giri=
      final sonGirisSnap = await FirebaseFirestore.instance
          .collection('plaka_kayitlari')
          .where('firmaId', isEqualTo: widget.firmaId)
          .orderBy('tarih', descending: true)
          .limit(5)
          .get();

      // Acil bildirimler
      final acilarSnap = await FirebaseFirestore.instance
          .collection('acil_bildirimler')
          .where('firmaId', isEqualTo: widget.firmaId)
          .where('okundu', isEqualTo: false)
          .orderBy('tarih', descending: true)
          .limit(3)
          .get();

      if (mounted) {
        setState(() {
          _sayilar = {
            'Toplam Arac':    results[0].count ?? 0,
            'Aktif Servis':   results[1].count ?? 0,
            'Bugun Giris':    results[2].count ?? 0,
            'Toplam Sofor':   results[3].count ?? 0,
          };
          _sonGirisler = sonGirisSnap.docs
              .map((d) => {'id': d.id, ...d.data()})
              .toList();
          _acilar = acilarSnap.docs
              .map((d) => {'id': d.id, ...d.data()})
              .toList();
          _yukleniyor = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ikonlar = [
      Icons.directions_bus_outlined,
      Icons.check_circle_outline,
      Icons.login_outlined,
      Icons.person_outlined,
    ];
    final renkler = [Colors.blue, Colors.green, _kOrange, Colors.purple];

    if (_yukleniyor) {
      return const Center(
          child: CircularProgressIndicator(color: _kOrange));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Acil bildirimler
        if (_acilar.isNotEmpty) ...[
          ..._acilar.map((a) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.red, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a['baslik'] ?? 'Acil Durum',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red)),
                    Text(a['mesaj'] ?? '',
                        style: const TextStyle(
                            color: Colors.red, fontSize: 12)),
                  ])),
              Text(_saatBicim(a['tarih']),
                  style: const TextStyle(
                      color: Colors.red, fontSize: 11)),
            ]),
          )),
          const SizedBox(height: 8),
        ],

        // =zet kartlar
        Row(children: [
          const Text('Genel Durum',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _kNavy)),
          const Spacer(),
          TextButton.icon(
              onPressed: _yukle,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Yenile')),
        ]),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16, runSpacing: 16,
          children: _sayilar.entries.toList().asMap().entries.map((e) {
            final i     = e.key;
            final entry = e.value;
            return Container(
              width: 160,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8)],
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: renkler[i % renkler.length]
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(ikonlar[i % ikonlar.length],
                          color: renkler[i % renkler.length], size: 22),
                    ),
                    const SizedBox(height: 12),
                    Text('${entry.value}',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: renkler[i % renkler.length])),
                    const SizedBox(height: 4),
                    Text(entry.key,
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12)),
                  ]),
            );
          }).toList(),
        ),

        const SizedBox(height: 28),

        // Son giri=ler
        const Text('Son Plaka Girisleri',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _kNavy)),
        const SizedBox(height: 12),
        if (_sonGirisler.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12)),
            child: const Center(
                child: Text('Henuz giris kaydi yok',
                    style: TextStyle(color: Colors.grey))),
          )
        else
          Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8)]),
            child: Column(
              children: _sonGirisler.asMap().entries.map((e) {
                final i = e.key;
                final g = e.value;
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: i < _sonGirisler.length - 1
                        ? const Border(
                        bottom: BorderSide(
                            color: Color(0xFFEEEEEE)))
                        : null,
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                          color: _kNavy.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(
                          g['plaka'] ?? '-',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _kNavy,
                              fontSize: 13,
                              letterSpacing: 1)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(g['soforAd'] ?? 'Sofor bilgisi yok',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                          Text(g['projeAdi'] ?? '',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 11)),
                        ])),
                    Text(_saatBicim(g['tarih']),
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20)),
                      child: const Text('Giris',
                          style: TextStyle(
                              color: Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ]),
                );
              }).toList(),
            ),
          ),
      ]),
    );
  }

  String _saatBicim(dynamic ts) {
    if (ts == null) return '-';
    final dt = (ts as Timestamp).toDate();
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ======================================================================
// CANLI TAK=P
// ======================================================================
class _KolejCanliTakip extends StatefulWidget {
  final String firmaId;
  const _KolejCanliTakip({required this.firmaId});
  @override
  State<_KolejCanliTakip> createState() => _KolejCanliTakipState();
}

class _KolejCanliTakipState extends State<_KolejCanliTakip> {
  List<Map<String, dynamic>> _araclar = [];
  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('vehicles')
          .where('firmaId', isEqualTo: widget.firmaId)
          .get();
      if (mounted) {
        setState(() {
          _araclar = snap.docs
              .map((d) => {'id': d.id, ...d.data()})
              .toList();
          _yukleniyor = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Canli Servis Takibi',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _kNavy)),
          const Spacer(),
          TextButton.icon(
              onPressed: _yukle,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Yenile')),
        ]),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10)),
          child: const Row(children: [
            Icon(Icons.info_outline, color: Colors.blue, size: 16),
            SizedBox(width: 8),
            Text('Arac konumlari gercek zamanli guncellenir',
                style: TextStyle(color: Colors.blue, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 16),
        if (_yukleniyor)
          const Center(child: CircularProgressIndicator(color: _kOrange))
        else if (_araclar.isEmpty)
          const Center(
              child: Text('Kayitli arac bulunamadi',
                  style: TextStyle(color: Colors.grey)))
        else
          Expanded(
            child: ListView.separated(
              itemCount: _araclar.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final a   = _araclar[i];
                final aktif = a['servisAktif'] == true;
                final plaka = a['plaka'] ?? a['plakaNo'] ?? '-';
                final sofor = a['soforAd'] ?? a['soforAdi'] ?? 'Atanmamis';
                final proje = a['projeAdi'] ?? '';

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: aktif
                            ? Colors.green.withValues(alpha: 0.3)
                            : Colors.grey.withValues(alpha: 0.2)),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6)],
                  ),
                  child: Row(children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                          color: aktif
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.directions_bus_outlined,
                          color: aktif ? Colors.green : Colors.grey,
                          size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(plaka,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: _kNavy,
                                    letterSpacing: 1)),
                            const SizedBox(width: 8),
                            if (proje.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                    color: _kNavy.withValues(alpha: 0.08),
                                    borderRadius:
                                    BorderRadius.circular(20)),
                                child: Text(proje,
                                    style: const TextStyle(
                                        color: _kNavy,
                                        fontSize: 10)),
                              ),
                          ]),
                          const SizedBox(height: 4),
                          Text(sofor,
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                          if (a['yaklasmaKm'] != null)
                            Text(
                                '${a['yaklasmaKm']} km uzakta - ~${a['yaklasmaDk'] ?? '?'} dk',
                                style: const TextStyle(
                                    color: _kOrange,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                        ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                                color: aktif
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : Colors.grey.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20)),
                            child: Text(
                                aktif ? 'Aktif' : 'Pasif',
                                style: TextStyle(
                                    color: aktif
                                        ? Colors.green
                                        : Colors.grey,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                          if (a['ogrenciSayisi'] != null) ...[
                            const SizedBox(height: 6),
                            Text('${a['ogrenciSayisi']} ogrenci',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 11)),
                          ],
                        ]),
                  ]),
                );
              },
            ),
          ),
      ]),
    );
  }
}

// ======================================================================
// PLAKA TANIMA
// ======================================================================
class _KolejPlakaTanima extends StatefulWidget {
  final String firmaId;
  const _KolejPlakaTanima({required this.firmaId});
  @override
  State<_KolejPlakaTanima> createState() => _KolejPlakaTanimaState();
}

class _KolejPlakaTanimaState extends State<_KolejPlakaTanima> {
  List<Map<String, dynamic>> _kayitlar = [];
  bool _yukleniyor = true;
  String _aramaPlaka = '';
  DateTime _seciliGun = DateTime.now();

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final baslangic = DateTime(
          _seciliGun.year, _seciliGun.month, _seciliGun.day);
      final bitis = baslangic.add(const Duration(days: 1));

      final snap = await FirebaseFirestore.instance
          .collection('plaka_kayitlari')
          .where('firmaId', isEqualTo: widget.firmaId)
          .where('tarih',
          isGreaterThanOrEqualTo: Timestamp.fromDate(baslangic))
          .where('tarih', isLessThan: Timestamp.fromDate(bitis))
          .orderBy('tarih', descending: true)
          .get();

      if (mounted) {
        setState(() {
          _kayitlar = snap.docs
              .map((d) => {'id': d.id, ...d.data()})
              .toList();
          _yukleniyor = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  List<Map<String, dynamic>> get _filtreli {
    if (_aramaPlaka.isEmpty) return _kayitlar;
    return _kayitlar
        .where((k) => (k['plaka'] ?? '')
        .toString()
        .toUpperCase()
        .contains(_aramaPlaka.toUpperCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Plaka Tanima Kayitlari',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _kNavy)),
          const Spacer(),
          // Tarih se=ici
          InkWell(
            onTap: () async {
              final tarih = await showDatePicker(
                context: context,
                initialDate: _seciliGun,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
              );
              if (tarih != null) {
                setState(() => _seciliGun = tarih);
                _yukle();
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                  color: _kNavy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 16, color: _kNavy),
                const SizedBox(width: 8),
                Text(
                    '${_seciliGun.day}.${_seciliGun.month}.${_seciliGun.year}',
                    style: const TextStyle(
                        color: _kNavy, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          TextButton.icon(
              onPressed: _yukle,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Yenile')),
        ]),
        const SizedBox(height: 16),
        // Arama
        TextField(
          onChanged: (v) => setState(() => _aramaPlaka = v),
          decoration: InputDecoration(
            hintText: 'Plaka ara...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),
        // =zet
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6)]),
          child: Row(children: [
            _ozet('Toplam Giris', '${_kayitlar.length}', Colors.blue),
            const SizedBox(width: 24),
            _ozet('Filtrelenen', '${_filtreli.length}', _kOrange),
          ]),
        ),
        const SizedBox(height: 16),
        if (_yukleniyor)
          const Center(child: CircularProgressIndicator(color: _kOrange))
        else if (_filtreli.isEmpty)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Text('Bu tarihte kayit bulunamadi',
                      style: TextStyle(color: Colors.grey))))
        else
          Expanded(
            child: ListView.separated(
              itemCount: _filtreli.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final k = _filtreli[i];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4)],
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                          color: _kNavy,
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(k['plaka'] ?? '-',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              fontSize: 14)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(k['soforAd'] ?? 'Sofor bilgisi yok',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                          Row(children: [
                            if (k['projeAdi'] != null) ...[
                              const Icon(Icons.folder_outlined,
                                  size: 12, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(k['projeAdi'],
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 11)),
                              const SizedBox(width: 10),
                            ],
                          ]),
                        ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_tarihBicim(k['tarih']),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _kNavy,
                                  fontSize: 13)),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color:
                                Colors.green.withValues(alpha: 0.1),
                                borderRadius:
                                BorderRadius.circular(20)),
                            child: const Text('Giris',
                                style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ]),
                  ]),
                );
              },
            ),
          ),
      ]),
    );
  }

  Widget _ozet(String baslik, String deger, Color renk) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(deger,
          style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: renk)),
      Text(baslik,
          style: const TextStyle(color: Colors.grey, fontSize: 12)),
    ]);
  }

  String _tarihBicim(dynamic ts) {
    if (ts == null) return '-';
    final dt = (ts as Timestamp).toDate();
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ======================================================================
// G=VENL=K
// ======================================================================
class _KolejGuvenlik extends StatefulWidget {
  final String firmaId;
  const _KolejGuvenlik({required this.firmaId});
  @override
  State<_KolejGuvenlik> createState() => _KolejGuvenlikState();
}

class _KolejGuvenlikState extends State<_KolejGuvenlik> {
  List<Map<String, dynamic>> _bekleyenler  = [];
  List<Map<String, dynamic>> _geldi        = [];
  List<Map<String, dynamic>> _gelmedi      = [];
  bool _yukleniyor = true;
  int  _tab = 0;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final bugun  = DateTime.now();
      final baslangic =
      DateTime(bugun.year, bugun.month, bugun.day);

      // T=m ara=lar
      final aracSnap = await FirebaseFirestore.instance
          .collection('vehicles')
          .where('firmaId', isEqualTo: widget.firmaId)
          .get();
      final tumAraclar = aracSnap.docs
          .map((d) => {'id': d.id, ...d.data()})
          .toList();

      // Bug=n gelen plakalar
      final girisSnap = await FirebaseFirestore.instance
          .collection('plaka_kayitlari')
          .where('firmaId', isEqualTo: widget.firmaId)
          .where('tarih',
          isGreaterThanOrEqualTo: Timestamp.fromDate(baslangic))
          .get();
      final gelenPlakalar = girisSnap.docs
          .map((d) => d.data()['plaka'] as String? ?? '')
          .toSet();

      if (mounted) {
        setState(() {
          _geldi = tumAraclar
              .where((a) =>
              gelenPlakalar.contains(a['plaka'] ?? a['plakaNo']))
              .toList();
          _gelmedi = tumAraclar
              .where((a) =>
          !gelenPlakalar.contains(a['plaka'] ?? a['plakaNo']))
              .toList();
          _bekleyenler = tumAraclar;
          _yukleniyor = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Guvenlik Paneli',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _kNavy)),
          const Spacer(),
          TextButton.icon(
              onPressed: _yukle,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Yenile')),
        ]),
        const SizedBox(height: 16),
        // =zet chips
        Row(children: [
          _chip('Tum Araclar', _bekleyenler.length, Colors.blue),
          const SizedBox(width: 10),
          _chip('Geldi', _geldi.length, Colors.green),
          const SizedBox(width: 10),
          _chip('Gelmedi', _gelmedi.length, Colors.red),
        ]),
        const SizedBox(height: 16),
        // Tab
        Row(children: [
          _tabButon(0, 'Tumu (${_bekleyenler.length})'),
          const SizedBox(width: 8),
          _tabButon(1, 'Geldi (${_geldi.length})'),
          const SizedBox(width: 8),
          _tabButon(2, 'Gelmedi (${_gelmedi.length})'),
        ]),
        const SizedBox(height: 16),
        if (_yukleniyor)
          const Center(child: CircularProgressIndicator(color: _kOrange))
        else
          Expanded(child: _liste()),
      ]),
    );
  }

  Widget _liste() {
    final liste = _tab == 0
        ? _bekleyenler
        : _tab == 1
        ? _geldi
        : _gelmedi;

    if (liste.isEmpty) {
      return Center(
          child: Text(
              _tab == 2 ? 'Tum araclar geldi!' : 'Kayit bulunamadi',
              style: TextStyle(
                  color: _tab == 2 ? Colors.green : Colors.grey)));
    }

    return ListView.separated(
      itemCount: liste.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final a     = liste[i];
        final plaka = a['plaka'] ?? a['plakaNo'] ?? '-';
        final sofor = a['soforAd'] ?? a['soforAdi'] ?? 'Atanmamis';
        final geldi = _tab == 1 ||
            (_tab == 0 &&
                _geldi.any((g) =>
                (g['plaka'] ?? g['plakaNo']) ==
                    (a['plaka'] ?? a['plakaNo'])));

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: geldi
                    ? Colors.green.withValues(alpha: 0.3)
                    : Colors.red.withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            Icon(
                geldi
                    ? Icons.check_circle_outline
                    : Icons.cancel_outlined,
                color: geldi ? Colors.green : Colors.red,
                size: 22),
            const SizedBox(width: 12),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plaka,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: _kNavy,
                          letterSpacing: 1)),
                  Text(sofor,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 12)),
                ])),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: geldi
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(geldi ? 'Geldi' : 'Bekleniyor',
                  style: TextStyle(
                      color: geldi ? Colors.green : Colors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
          ]),
        );
      },
    );
  }

  Widget _chip(String label, int sayi, Color renk) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
          color: renk.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        Text('$sayi',
            style: TextStyle(
                color: renk,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(color: renk, fontSize: 12)),
      ]),
    );
  }

  Widget _tabButon(int index, String label) {
    final aktif = _tab == index;
    return GestureDetector(
      onTap: () => setState(() => _tab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
            color: aktif ? _kNavy : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: aktif ? _kNavy : Colors.grey.shade300)),
        child: Text(label,
            style: TextStyle(
                color: aktif ? Colors.white : Colors.grey,
                fontWeight: aktif
                    ? FontWeight.bold
                    : FontWeight.normal,
                fontSize: 13)),
      ),
    );
  }
}

// ======================================================================
// HAR=TA (placeholder = Google Maps entegrasyonu ayr= ad=mda)
// ======================================================================
class _KolejHarita extends StatelessWidget {
  final String firmaId;
  const _KolejHarita({required this.firmaId});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 20)]),
          child: Column(children: [
            const Icon(Icons.map_outlined, size: 64, color: _kNavy),
            const SizedBox(height: 16),
            const Text('Yaklasan Servisleri Goruntule',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _kNavy)),
            const SizedBox(height: 8),
            Text('Google Maps entegrasyonu aktif edilecek',
                style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _kNavy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () {},
              icon: const Icon(Icons.location_on_outlined),
              label: const Text('Haritayi Ac'),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ======================================================================
// RAPORLAR
// ======================================================================
class _KolejRaporlar extends StatefulWidget {
  final String firmaId;
  const _KolejRaporlar({required this.firmaId});
  @override
  State<_KolejRaporlar> createState() => _KolejRaporlarState();
}

class _KolejRaporlarState extends State<_KolejRaporlar> {
  List<Map<String, dynamic>> _kayitlar = [];
  bool _yukleniyor = true;
  String _periyot  = 'bugun';

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final now = DateTime.now();
      DateTime baslangic;
      switch (_periyot) {
        case 'bugun':
          baslangic = DateTime(now.year, now.month, now.day);
          break;
        case 'hafta':
          baslangic = now.subtract(const Duration(days: 7));
          break;
        case 'ay':
          baslangic = DateTime(now.year, now.month, 1);
          break;
        default:
          baslangic = DateTime(now.year, now.month, now.day);
      }

      final snap = await FirebaseFirestore.instance
          .collection('plaka_kayitlari')
          .where('firmaId', isEqualTo: widget.firmaId)
          .where('tarih',
          isGreaterThanOrEqualTo: Timestamp.fromDate(baslangic))
          .orderBy('tarih', descending: true)
          .get();

      if (mounted) {
        setState(() {
          _kayitlar = snap.docs
              .map((d) => {'id': d.id, ...d.data()})
              .toList();
          _yukleniyor = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  // Plakaya g=re grupla
  Map<String, List<Map<String, dynamic>>> get _aracBazli {
    final Map<String, List<Map<String, dynamic>>> grup = {};
    for (final k in _kayitlar) {
      final p = k['plaka'] ?? '-';
      grup.putIfAbsent(p, () => []).add(k);
    }
    return grup;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Raporlar',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _kNavy)),
          const Spacer(),
          // Periyot se=ici
          DropdownButton<String>(
            value: _periyot,
            items: const [
              DropdownMenuItem(value: 'bugun', child: Text('Bugun')),
              DropdownMenuItem(value: 'hafta',  child: Text('Son 7 Gun')),
              DropdownMenuItem(value: 'ay',     child: Text('Bu Ay')),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() => _periyot = v);
                _yukle();
              }
            },
          ),
          const SizedBox(width: 10),
          TextButton.icon(
              onPressed: _yukle,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Yenile')),
        ]),
        const SizedBox(height: 16),
        // =zet
        Row(children: [
          _raporKart('Toplam Giris', '${_kayitlar.length}',
              Icons.login_outlined, Colors.blue),
          const SizedBox(width: 16),
          _raporKart('Farkli Arac', '${_aracBazli.keys.length}',
              Icons.directions_bus_outlined, _kOrange),
        ]),
        const SizedBox(height: 24),
        const Text('Arac Bazli Girisler',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _kNavy)),
        const SizedBox(height: 12),
        if (_yukleniyor)
          const Center(child: CircularProgressIndicator(color: _kOrange))
        else if (_aracBazli.isEmpty)
          const Center(
              child: Text('Bu periyotta kayit yok',
                  style: TextStyle(color: Colors.grey)))
        else
          Expanded(
            child: ListView(
              children: _aracBazli.entries.map((e) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4)],
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                          color: _kNavy,
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(e.key,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Text(
                        e.value.isNotEmpty
                            ? (e.value.first['soforAd'] ?? '')
                            : '',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12))),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                          color: _kOrange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('${e.value.length} giris',
                          style: const TextStyle(
                              color: _kOrange,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ),
                  ]),
                );
              }).toList(),
            ),
          ),
      ]),
    );
  }

  Widget _raporKart(
      String baslik, String deger, IconData ikon, Color renk) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8)]),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: renk.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(ikon, color: renk, size: 22),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(deger,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: renk)),
          Text(baslik,
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
      ]),
    );
  }
}

// ======================================================================
// DUYURULAR
// ======================================================================
class _KolejDuyurular extends StatefulWidget {
  final String firmaId;
  const _KolejDuyurular({required this.firmaId});
  @override
  State<_KolejDuyurular> createState() => _KolejDuyurularState();
}

class _KolejDuyurularState extends State<_KolejDuyurular> {
  final _mesajCtrl = TextEditingController();
  List<Map<String, dynamic>> _mesajlar = [];
  bool _yukleniyor  = true;
  bool _gonderiyor  = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _mesajCtrl.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('kolej_mesajlar')
          .where('firmaId', isEqualTo: widget.firmaId)
          .orderBy('tarih', descending: true)
          .limit(20)
          .get();
      if (mounted) {
        setState(() {
          _mesajlar = snap.docs
              .map((d) => {'id': d.id, ...d.data()})
              .toList();
          _yukleniyor = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _gonder() async {
    final mesaj = _mesajCtrl.text.trim();
    if (mesaj.isEmpty) return;
    setState(() => _gonderiyor = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('kolej_mesajlar').add({
        'firmaId': widget.firmaId,
        'mesaj': mesaj,
        'gonderen': user?.email ?? 'Kolej',
        'tarih': FieldValue.serverTimestamp(),
        'okundu': false,
        'tip': 'kolej_duyuru',
      });
      _mesajCtrl.clear();
      _yukle();
    } catch (_) {}
    if (mounted) setState(() => _gonderiyor = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Firma Adminlere Mesaj',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _kNavy)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: _kOrange.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10)),
          child: const Row(children: [
            Icon(Icons.info_outline, color: _kOrange, size: 16),
            SizedBox(width: 8),
            Expanded(
                child: Text(
                    'Gonderdiginiz mesajlar firma adminine iletilir',
                    style: TextStyle(color: _kOrange, fontSize: 12))),
          ]),
        ),
        const SizedBox(height: 16),
        // Mesaj g=nder
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: TextField(
              controller: _mesajCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText:
                'Mesajinizi yazin (acil durum, gecikme bildirimi...)',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 80,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _kNavy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              onPressed: _gonderiyor ? null : _gonder,
              child: _gonderiyor
                  ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                  : const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.send_outlined, size: 20),
                    SizedBox(height: 4),
                    Text('Gonder', style: TextStyle(fontSize: 12)),
                  ]),
            ),
          ),
        ]),
        const SizedBox(height: 24),
        const Text('Gecmis Mesajlar',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _kNavy)),
        const SizedBox(height: 12),
        if (_yukleniyor)
          const Center(child: CircularProgressIndicator(color: _kOrange))
        else if (_mesajlar.isEmpty)
          const Center(
              child: Text('Henuz mesaj gonderilmemis',
                  style: TextStyle(color: Colors.grey)))
        else
          Expanded(
            child: ListView.separated(
              itemCount: _mesajlar.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final m    = _mesajlar[i];
                final okundu = m['okundu'] == true;
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: okundu
                            ? Colors.grey.withValues(alpha: 0.2)
                            : _kOrange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: _kNavy.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.campaign_outlined,
                              color: _kNavy, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m['mesaj'] ?? '',
                                  style: const TextStyle(fontSize: 13)),
                              const SizedBox(height: 4),
                              Text(m['gonderen'] ?? '',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 11)),
                            ])),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(_tarihBicim(m['tarih']),
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 11)),
                              const SizedBox(height: 4),
                              Icon(
                                  okundu
                                      ? Icons.done_all
                                      : Icons.done,
                                  size: 14,
                                  color: okundu ? Colors.blue : Colors.grey),
                            ]),
                      ]),
                );
              },
            ),
          ),
      ]),
    );
  }

  String _tarihBicim(dynamic ts) {
    if (ts == null) return '-';
    final dt = (ts as Timestamp).toDate();
    return '${dt.day}.${dt.month} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}
