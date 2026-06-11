import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/session_service.dart';

// ======================================================================
// WEB PERSONEL PANEL  --  Servisim360
// Firma Admin > Personel Servisi > Personel Yonetimi
// Koleksiyon: personnel  |  firmaId ile izole
// ======================================================================

const Color _pNavy   = Color(0xFF1a3a6b);
const Color _pOrange = Color(0xFFFF8C00);
const Color _pBg     = Color(0xFFF0F2F5);

class WebPersonelPanel extends StatefulWidget {
  const WebPersonelPanel({super.key});
  @override
  State<WebPersonelPanel> createState() => _WebPersonelPanelState();
}

class _WebPersonelPanelState extends State<WebPersonelPanel> {
  int  _menu    = 0;
  bool _sidebar = true;
  String _firmaId = '';
  bool _yukleniyor = true;

  static const _menuler = [
    {'ikon': Icons.people_outline,          'etiket': 'Personel Listesi'},
    {'ikon': Icons.access_time_outlined,    'etiket': 'Vardiyalar'},
    {'ikon': Icons.directions_bus_outlined, 'etiket': 'Servisler'},
    {'ikon': Icons.event_busy_outlined,     'etiket': 'Devamsizliklar'},
    {'ikon': Icons.bar_chart_outlined,      'etiket': 'Raporlar'},
    {'ikon': Icons.settings_outlined,       'etiket': 'Proje Ayarlari'},
  ];

  @override
  void initState() {
    super.initState();
    _baslat();
  }

  Future<void> _baslat() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final fid = await SessionService.instance.firmaIdAl();
    if (mounted) setState(() { _firmaId = fid ?? ''; _yukleniyor = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) {
      return const Scaffold(
        backgroundColor: _pNavy,
        body: Center(child: CircularProgressIndicator(color: _pOrange)),
      );
    }
    return Scaffold(
      backgroundColor: _pBg,
      body: Row(children: [
        // Sidebar
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: _sidebar ? 230 : 64,
          child: Container(
            color: _pNavy,
            child: Column(children: [
              Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                        color: _pOrange,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Center(child: Text('P',
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold, fontSize: 20))),
                  ),
                  if (_sidebar) ...[
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Personel Servisi',
                            style: TextStyle(color: Colors.white,
                                fontWeight: FontWeight.bold, fontSize: 12)),
                        Text('Yonetim Paneli',
                            style: TextStyle(color: Colors.amber, fontSize: 10)),
                      ],
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
                          color: aktif ? _pOrange : Colors.transparent,
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
                                    color: aktif ? Colors.white : Colors.white70,
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
            ]),
          ),
        ),
        // Icerik
        Expanded(
          child: Column(children: [
            Container(
              height: 60, color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                IconButton(
                  icon: Icon(_sidebar ? Icons.menu_open : Icons.menu,
                      color: _pNavy),
                  onPressed: () => setState(() => _sidebar = !_sidebar),
                ),
                const SizedBox(width: 8),
                Text(_menuler[_menu]['etiket'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold,
                        fontSize: 18, color: _pNavy)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20)),
                  child: const Row(children: [
                    Icon(Icons.factory_outlined, size: 14, color: Colors.teal),
                    SizedBox(width: 6),
                    Text('Personel Modu',
                        style: TextStyle(color: Colors.teal,
                            fontSize: 12, fontWeight: FontWeight.bold)),
                  ]),
                ),
                const SizedBox(width: 12),
              ]),
            ),
            Expanded(child: _sayfaAl()),
          ]),
        ),
      ]),
    );
  }

  Widget _sayfaAl() {
    switch (_menu) {
      case 0: return _PersonelListesi(firmaId: _firmaId);
      case 1: return _VardiyaYonetimi(firmaId: _firmaId);
      case 2: return _PersonelServisleri(firmaId: _firmaId);
      case 3: return _DevamsizlikListesi(firmaId: _firmaId);
      case 4: return _PersonelRaporlar(firmaId: _firmaId);
      case 5: return _ProjeAyarlari(firmaId: _firmaId);
      default: return _PersonelListesi(firmaId: _firmaId);
    }
  }
}

// ======================================================================
// PERSONEL LISTESI
// ======================================================================
class _PersonelListesi extends StatefulWidget {
  final String firmaId;
  const _PersonelListesi({required this.firmaId});
  @override
  State<_PersonelListesi> createState() => _PersonelListesiState();
}

class _PersonelListesiState extends State<_PersonelListesi> {
  List<Map<String, dynamic>> _personeller = [];
  List<Map<String, dynamic>> _filtrelenmis = [];
  bool _yukleniyor = true;
  String _aramaMetni = '';
  String _departmanFiltre = 'Tumu';
  List<String> _departmanlar = ['Tumu'];

  @override
  void initState() { super.initState(); _yukle(); }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('personnel')
          .where('firmaId', isEqualTo: widget.firmaId)
          .orderBy('ad')
          .get();
      final liste = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      final deps = <String>{'Tumu'};
      for (final p in liste) {
        final d = p['departman'] as String? ?? '';
        if (d.isNotEmpty) deps.add(d);
      }
      if (mounted) setState(() {
        _personeller = liste;
        _filtrelenmis = liste;
        _departmanlar = deps.toList();
        _yukleniyor = false;
      });
    } catch (_) {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  void _filtrele(String arama) {
    setState(() {
      _aramaMetni = arama;
      _filtrelenmis = _personeller.where((p) {
        final depUygun = _departmanFiltre == 'Tumu' ||
            p['departman'] == _departmanFiltre;
        final aramaUygun = arama.isEmpty ||
            (p['ad'] ?? '').toString().toLowerCase()
                .contains(arama.toLowerCase()) ||
            (p['sicilNo'] ?? '').toString().toLowerCase()
                .contains(arama.toLowerCase());
        return depUygun && aramaUygun;
      }).toList();
    });
  }

  void _personelDialog(String? personelId, Map<String, dynamic>? mevcut) {
    final adCtrl      = TextEditingController(text: mevcut?['ad'] ?? '');
    final sicilCtrl   = TextEditingController(text: mevcut?['sicilNo'] ?? '');
    final telCtrl     = TextEditingController(text: mevcut?['telefon'] ?? '');
    final depCtrl     = TextEditingController(text: mevcut?['departman'] ?? '');
    final gorevCtrl   = TextEditingController(text: mevcut?['gorevUnvani'] ?? '');
    final adresCtrl   = TextEditingController(text: mevcut?['adres'] ?? '');
    final calismaCtrl = TextEditingController(text: mevcut?['calismaSaatleri'] ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(personelId == null ? 'Yeni Personel' : 'Personel Duzenle',
            style: const TextStyle(color: _pNavy, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _tf(adCtrl,      'Ad Soyad *',         Icons.person_outline),
              _tf(sicilCtrl,   'Sicil No *',          Icons.badge_outlined),
              _tf(telCtrl,     'Telefon',             Icons.phone_outlined,
                  keyboard: TextInputType.phone),
              _tf(depCtrl,     'Departman',           Icons.domain_outlined),
              _tf(gorevCtrl,   'Gorev Unvani',        Icons.work_outline),
              _tf(calismaCtrl, 'Calisma Saatleri',    Icons.schedule_outlined),
              _tf(adresCtrl,   'Adres',               Icons.location_on_outlined),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Iptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _pNavy),
            onPressed: () async {
              if (adCtrl.text.isEmpty || sicilCtrl.text.isEmpty) return;
              final veri = {
                'firmaId':        widget.firmaId,
                'ad':             adCtrl.text.trim(),
                'sicilNo':        sicilCtrl.text.trim(),
                'telefon':        telCtrl.text.trim(),
                'departman':      depCtrl.text.trim(),
                'gorevUnvani':    gorevCtrl.text.trim(),
                'calismaSaatleri':calismaCtrl.text.trim(),
                'adres':          adresCtrl.text.trim(),
                'guncelleme':     FieldValue.serverTimestamp(),
              };
              if (personelId == null) {
                veri['kayitTarihi'] = FieldValue.serverTimestamp();
                veri['aktif'] = true;
                await FirebaseFirestore.instance
                    .collection('personnel').add(veri);
              } else {
                await FirebaseFirestore.instance
                    .collection('personnel').doc(personelId).update(veri);
              }
              if (mounted) Navigator.pop(context);
              _yukle();
            },
            child: Text(personelId == null ? 'Kaydet' : 'Guncelle',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _sil(String id, String ad) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Personeli Sil'),
        content: Text('"$ad" silinecek. Emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Iptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (onay == true) {
      await FirebaseFirestore.instance.collection('personnel').doc(id).delete();
      _yukle();
    }
  }

  Widget _tf(TextEditingController c, String label, IconData ikon,
      {TextInputType keyboard = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c, keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label, prefixIcon: Icon(ikon, size: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Personel (${_filtrelenmis.length})',
              style: const TextStyle(fontSize: 20,
                  fontWeight: FontWeight.bold, color: _pNavy)),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _pNavy, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => _personelDialog(null, null),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Personel Ekle'),
          ),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: TextField(
              onChanged: _filtrele,
              decoration: InputDecoration(
                hintText: 'Ad veya sicil no ara...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                filled: true, fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: _departmanFiltre,
            items: _departmanlar.map((d) =>
                DropdownMenuItem(value: d, child: Text(d))).toList(),
            onChanged: (v) {
              if (v != null) {
                _departmanFiltre = v;
                _filtrele(_aramaMetni);
              }
            },
          ),
        ]),
        const SizedBox(height: 16),
        if (_yukleniyor)
          const Center(child: CircularProgressIndicator(color: _pOrange))
        else if (_filtrelenmis.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(children: [
              const Icon(Icons.people_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                  _personeller.isEmpty
                      ? 'Henuz personel eklenmemis'
                      : 'Arama sonucu bulunamadi',
                  style: const TextStyle(color: Colors.grey)),
            ]),
          ))
        else
          Expanded(
            child: ListView.separated(
              itemCount: _filtrelenmis.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final p = _filtrelenmis[i];
                final ad      = p['ad'] ?? 'Personel';
                final sicil   = p['sicilNo'] ?? '-';
                final dep     = p['departman'] ?? '';
                final gorev   = p['gorevUnvani'] ?? '';
                final aktif   = p['aktif'] != false;
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6)],
                  ),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: _pNavy.withValues(alpha: 0.1),
                      child: Text(
                          ad.isNotEmpty ? ad[0].toUpperCase() : 'P',
                          style: const TextStyle(
                              color: _pNavy, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ad, style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                          Row(children: [
                            const Icon(Icons.badge_outlined,
                                size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(sicil, style: const TextStyle(
                                color: Colors.grey, fontSize: 12)),
                            if (dep.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              const Icon(Icons.domain_outlined,
                                  size: 12, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(dep, style: const TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                            ],
                          ]),
                          if (gorev.isNotEmpty)
                            Text(gorev, style: const TextStyle(
                                color: Colors.grey, fontSize: 11)),
                        ])),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
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
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                      onSelected: (v) {
                        if (v == 'duzenle') _personelDialog(p['id'], p);
                        if (v == 'sil') _sil(p['id'], ad);
                        if (v == 'pasif') {
                          FirebaseFirestore.instance
                              .collection('personnel')
                              .doc(p['id'])
                              .update({'aktif': false});
                          _yukle();
                        }
                        if (v == 'aktif') {
                          FirebaseFirestore.instance
                              .collection('personnel')
                              .doc(p['id'])
                              .update({'aktif': true});
                          _yukle();
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'duzenle',
                            child: Row(children: [
                              Icon(Icons.edit_outlined,
                                  color: Colors.blue, size: 18),
                              SizedBox(width: 8), Text('Duzenle'),
                            ])),
                        if (aktif)
                          const PopupMenuItem(value: 'pasif',
                              child: Row(children: [
                                Icon(Icons.pause_circle_outline,
                                    color: Colors.orange, size: 18),
                                SizedBox(width: 8), Text('Pasife Al'),
                              ]))
                        else
                          const PopupMenuItem(value: 'aktif',
                              child: Row(children: [
                                Icon(Icons.check_circle_outline,
                                    color: Colors.green, size: 18),
                                SizedBox(width: 8), Text('Aktife Al'),
                              ])),
                        const PopupMenuItem(value: 'sil',
                            child: Row(children: [
                              Icon(Icons.delete_outline,
                                  color: Colors.red, size: 18),
                              SizedBox(width: 8),
                              Text('Sil', style: TextStyle(color: Colors.red)),
                            ])),
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
}

// ======================================================================
// VARDIYA YNETIMI
// ======================================================================
class _VardiyaYonetimi extends StatefulWidget {
  final String firmaId;
  const _VardiyaYonetimi({required this.firmaId});
  @override
  State<_VardiyaYonetimi> createState() => _VardiyaYonetimiState();
}

class _VardiyaYonetimiState extends State<_VardiyaYonetimi> {
  List<Map<String, dynamic>> _vardiyalar = [];
  bool _yukleniyor = true;

  static const _vardiyaRenkleri = {
    'sabah':  Colors.orange,
    'aksam':  Colors.blue,
    'gece':   Colors.purple,
    'ozel':   Colors.teal,
  };

  @override
  void initState() { super.initState(); _yukle(); }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('vardiyalar')
          .where('firmaId', isEqualTo: widget.firmaId)
          .get();
      if (mounted) setState(() {
        _vardiyalar = snap.docs
            .map((d) => {'id': d.id, ...d.data()}).toList();
        _yukleniyor = false;
      });
    } catch (_) {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  void _vardiyaDialog(String? vid, Map<String, dynamic>? mevcut) {
    final adCtrl      = TextEditingController(text: mevcut?['ad'] ?? '');
    final baslangicCtrl = TextEditingController(
        text: mevcut?['baslangicSaati'] ?? '08:00');
    final bitisCtrl   = TextEditingController(
        text: mevcut?['bitisSaati'] ?? '17:00');
    String tip = mevcut?['tip'] ?? 'sabah';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(vid == null ? 'Yeni Vardiya' : 'Vardiya Duzenle',
              style: const TextStyle(
                  color: _pNavy, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 400,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: adCtrl,
                decoration: InputDecoration(
                  labelText: 'Vardiya Adi *',
                  prefixIcon: const Icon(Icons.label_outline, size: 18),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(
                  controller: baslangicCtrl,
                  decoration: InputDecoration(
                    labelText: 'Baslangic',
                    prefixIcon: const Icon(Icons.schedule, size: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                )),
                const SizedBox(width: 12),
                Expanded(child: TextField(
                  controller: bitisCtrl,
                  decoration: InputDecoration(
                    labelText: 'Bitis',
                    prefixIcon: const Icon(Icons.schedule_outlined, size: 18),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                )),
              ]),
              const SizedBox(height: 12),
              const Align(alignment: Alignment.centerLeft,
                  child: Text('Vardiya Tipi',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: _pNavy))),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: ['sabah', 'aksam', 'gece', 'ozel']
                  .map((t) {
                final sec = tip == t;
                final renk = _vardiyaRenkleri[t] ?? Colors.grey;
                return GestureDetector(
                  onTap: () => setD(() => tip = t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                        color: sec ? renk : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: sec ? renk : Colors.grey.shade300)),
                    child: Text(t,
                        style: TextStyle(
                            color: sec ? Colors.white : Colors.black87,
                            fontSize: 12)),
                  ),
                );
              }).toList()),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context),
                child: const Text('Iptal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _pNavy),
              onPressed: () async {
                if (adCtrl.text.isEmpty) return;
                final veri = {
                  'firmaId':        widget.firmaId,
                  'ad':             adCtrl.text.trim(),
                  'tip':            tip,
                  'baslangicSaati': baslangicCtrl.text.trim(),
                  'bitisSaati':     bitisCtrl.text.trim(),
                  'guncelleme':     FieldValue.serverTimestamp(),
                };
                if (vid == null) {
                  veri['olusturma'] = FieldValue.serverTimestamp();
                  await FirebaseFirestore.instance
                      .collection('vardiyalar').add(veri);
                } else {
                  await FirebaseFirestore.instance
                      .collection('vardiyalar').doc(vid).update(veri);
                }
                if (mounted) Navigator.pop(context);
                _yukle();
              },
              child: const Text('Kaydet',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Vardiya Yonetimi',
              style: TextStyle(fontSize: 20,
                  fontWeight: FontWeight.bold, color: _pNavy)),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _pNavy, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => _vardiyaDialog(null, null),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Vardiya Ekle'),
          ),
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
            Text('Vardiyalar servislere ve personele atanabilir',
                style: TextStyle(color: Colors.blue, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 16),
        if (_yukleniyor)
          const Center(child: CircularProgressIndicator(color: _pOrange))
        else if (_vardiyalar.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(children: [
              const Icon(Icons.access_time_outlined,
                  size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              const Text('Henuz vardiya tanimlanmamis',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _pNavy),
                onPressed: () => _vardiyaDialog(null, null),
                child: const Text('Ilk Vardiyayi Ekle',
                    style: TextStyle(color: Colors.white)),
              ),
            ]),
          ))
        else
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 300,
                  mainAxisSpacing: 16, crossAxisSpacing: 16,
                  childAspectRatio: 1.6),
              itemCount: _vardiyalar.length,
              itemBuilder: (_, i) {
                final v = _vardiyalar[i];
                final tip = v['tip'] ?? 'ozel';
                final renk = _vardiyaRenkleri[tip] ?? Colors.teal;
                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: renk.withValues(alpha: 0.3)),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8)],
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: renk.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8)),
                            child: Icon(Icons.access_time_outlined,
                                color: renk, size: 18),
                          ),
                          const Spacer(),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert,
                                color: Colors.grey, size: 18),
                            onSelected: (val) {
                              if (val == 'duzenle') _vardiyaDialog(v['id'], v);
                              if (val == 'sil') {
                                FirebaseFirestore.instance
                                    .collection('vardiyalar')
                                    .doc(v['id']).delete();
                                _yukle();
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'duzenle',
                                  child: Text('Duzenle')),
                              const PopupMenuItem(value: 'sil',
                                  child: Text('Sil',
                                      style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        ]),
                        const SizedBox(height: 8),
                        Text(v['ad'] ?? 'Vardiya',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15, color: _pNavy)),
                        const SizedBox(height: 4),
                        Text(
                            '${v['baslangicSaati'] ?? '-'} - '
                                '${v['bitisSaati'] ?? '-'}',
                            style: TextStyle(color: renk,
                                fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: renk.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(tip,
                              style: TextStyle(
                                  color: renk, fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
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
// PERSONEL SERVISLERI
// ======================================================================
class _PersonelServisleri extends StatefulWidget {
  final String firmaId;
  const _PersonelServisleri({required this.firmaId});
  @override
  State<_PersonelServisleri> createState() => _PersonelServisleriState();
}

class _PersonelServisleriState extends State<_PersonelServisleri> {
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Personel Servisleri (${_servisler.length})',
              style: const TextStyle(fontSize: 20,
                  fontWeight: FontWeight.bold, color: _pNavy)),
          const Spacer(),
          TextButton.icon(
              onPressed: _yukle,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Yenile')),
        ]),
        const SizedBox(height: 16),
        if (_yukleniyor)
          const Center(child: CircularProgressIndicator(color: _pOrange))
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
                final plaka  = s['plaka'] ?? s['plakaNo'] ?? '-';
                final sofor  = s['soforAd'] ?? 'Atanmamis';
                final aktif  = s['servisAktif'] == true;
                final vardiya = s['vardiya'] ?? '';
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
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
                          Text(plaka, style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15, color: _pNavy,
                              letterSpacing: 1)),
                          Text(sofor, style: const TextStyle(
                              color: Colors.grey, fontSize: 12)),
                          if (vardiya.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10)),
                              child: Text(vardiya,
                                  style: const TextStyle(
                                      color: Colors.blue, fontSize: 10)),
                            ),
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
    );
  }
}

// ======================================================================
// DEVAMSIZLIK LISTESI
// ======================================================================
class _DevamsizlikListesi extends StatefulWidget {
  final String firmaId;
  const _DevamsizlikListesi({required this.firmaId});
  @override
  State<_DevamsizlikListesi> createState() => _DevamsizlikListesiState();
}

class _DevamsizlikListesiState extends State<_DevamsizlikListesi> {
  List<Map<String, dynamic>> _kayitlar = [];
  bool _yukleniyor = true;

  @override
  void initState() { super.initState(); _yukle(); }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('personel_devamsizlik')
          .where('firmaId', isEqualTo: widget.firmaId)
          .orderBy('tarih', descending: true)
          .limit(50)
          .get();
      if (mounted) setState(() {
        _kayitlar = snap.docs
            .map((d) => {'id': d.id, ...d.data()}).toList();
        _yukleniyor = false;
      });
    } catch (_) {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Color _tipRenk(String tip) {
    switch (tip) {
      case 'tam_gun': return Colors.red;
      case 'sabah':   return Colors.orange;
      case 'aksam':   return Colors.blue;
      default:        return Colors.grey;
    }
  }

  String _tipLabel(String tip) {
    switch (tip) {
      case 'tam_gun': return 'Tam Gun';
      case 'sabah':   return 'Sabah Gelmiyor';
      case 'aksam':   return 'Aksam Gelmiyor';
      default:        return tip;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Devamsizlik Kayitlari',
              style: TextStyle(fontSize: 20,
                  fontWeight: FontWeight.bold, color: _pNavy)),
          const Spacer(),
          TextButton.icon(
              onPressed: _yukle,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Yenile')),
        ]),
        const SizedBox(height: 16),
        if (_yukleniyor)
          const Center(child: CircularProgressIndicator(color: _pOrange))
        else if (_kayitlar.isEmpty)
          const Center(child: Padding(
            padding: EdgeInsets.all(40),
            child: Text('Devamsizlik kaydi bulunamadi',
                style: TextStyle(color: Colors.grey)),
          ))
        else
          Expanded(
            child: ListView.separated(
              itemCount: _kayitlar.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final k    = _kayitlar[i];
                final tip  = k['tip'] ?? 'tam_gun';
                final renk = _tipRenk(tip);
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: renk.withValues(alpha: 0.2)),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4)],
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: renk.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.event_busy_outlined,
                          color: renk, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(k['personelAd'] ?? 'Personel',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(k['departman'] ?? '',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 11)),
                          if (k['aciklama'] != null && k['aciklama'] != '')
                            Text(k['aciklama'],
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 11)),
                        ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: renk.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20)),
                            child: Text(_tipLabel(tip),
                                style: TextStyle(
                                    color: renk, fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 4),
                          Text(_tarihBicim(k['tarih']),
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 11)),
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
    return '${dt.day}.${dt.month}.${dt.year}';
  }
}

// ======================================================================
// PERSONEL RAPORLAR
// ======================================================================
class _PersonelRaporlar extends StatefulWidget {
  final String firmaId;
  const _PersonelRaporlar({required this.firmaId});
  @override
  State<_PersonelRaporlar> createState() => _PersonelRaporlarState();
}

class _PersonelRaporlarState extends State<_PersonelRaporlar> {
  Map<String, int> _sayilar = {};
  Map<String, int> _depSayilari = {};
  bool _yukleniyor = true;

  @override
  void initState() { super.initState(); _yukle(); }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('personnel')
          .where('firmaId', isEqualTo: widget.firmaId)
          .get();
      final personeller = snap.docs
          .map((d) => {'id': d.id, ...d.data()}).toList();

      final aktifSay = personeller
          .where((p) => p['aktif'] != false).length;

      final depMap = <String, int>{};
      for (final p in personeller) {
        final dep = p['departman'] as String? ?? 'Diger';
        depMap[dep] = (depMap[dep] ?? 0) + 1;
      }

      final devSnap = await FirebaseFirestore.instance
          .collection('personel_devamsizlik')
          .where('firmaId', isEqualTo: widget.firmaId)
          .where('tarih', isGreaterThanOrEqualTo: Timestamp.fromDate(
          DateTime.now().subtract(const Duration(days: 30))))
          .count().get();

      if (mounted) setState(() {
        _sayilar = {
          'Toplam Personel': personeller.length,
          'Aktif':           aktifSay,
          'Pasif':           personeller.length - aktifSay,
          'Son 30 Gun Devamsizlik': devSnap.count ?? 0,
        };
        _depSayilari = depMap;
        _yukleniyor = false;
      });
    } catch (_) {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final renkler = [Colors.blue, Colors.green, Colors.orange, Colors.red];
    final ikonlar = [Icons.people_outline, Icons.check_circle_outline,
      Icons.pause_circle_outline, Icons.event_busy_outlined];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Personel Raporlari',
              style: TextStyle(fontSize: 20,
                  fontWeight: FontWeight.bold, color: _pNavy)),
          const Spacer(),
          TextButton.icon(
              onPressed: _yukle,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Yenile')),
        ]),
        const SizedBox(height: 20),
        if (_yukleniyor)
          const Center(child: CircularProgressIndicator(color: _pOrange))
        else ...[
          Wrap(
            spacing: 16, runSpacing: 16,
            children: _sayilar.entries.toList().asMap().entries.map((e) {
              final i = e.key;
              final entry = e.value;
              return Container(
                width: 180,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8)]),
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
                          style: TextStyle(fontSize: 28,
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
          const Text('Departman Bazli Dagilim',
              style: TextStyle(fontSize: 16,
                  fontWeight: FontWeight.bold, color: _pNavy)),
          const SizedBox(height: 12),
          if (_depSayilari.isEmpty)
            const Text('Departman bilgisi bulunamadi',
                style: TextStyle(color: Colors.grey))
          else
            ..._depSayilari.entries.map((e) {
              final max = _depSayilari.values
                  .fold(0, (a, b) => a > b ? a : b);
              final oran = max > 0 ? e.value / max : 0.0;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  SizedBox(width: 140,
                      child: Text(e.key,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600))),
                  Expanded(child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: oran,
                      backgroundColor: Colors.grey.shade200,
                      color: _pNavy,
                      minHeight: 8,
                    ),
                  )),
                  const SizedBox(width: 12),
                  Text('${e.value} kisi',
                      style: const TextStyle(
                          color: _pNavy, fontWeight: FontWeight.bold)),
                ]),
              );
            }),
        ],
      ]),
    );
  }
}

// ======================================================================
// PROJE AYARLARI
// ======================================================================
class _ProjeAyarlari extends StatefulWidget {
  final String firmaId;
  const _ProjeAyarlari({required this.firmaId});
  @override
  State<_ProjeAyarlari> createState() => _ProjeAyarlariState();
}

class _ProjeAyarlariState extends State<_ProjeAyarlari> {
  List<Map<String, dynamic>> _projeler = [];
  bool _yukleniyor = true;

  static const _projecTipleri = [
    {'deger': 'okul',     'label': 'Okul Servisi',     'ikon': Icons.school_outlined},
    {'deger': 'kolej',    'label': 'Kolej Servisi',    'ikon': Icons.account_balance_outlined},
    {'deger': 'personel', 'label': 'Personel Servisi', 'ikon': Icons.factory_outlined},
    {'deger': 'ozel',     'label': 'Ozel Servis',      'ikon': Icons.directions_car_outlined},
  ];

  @override
  void initState() { super.initState(); _yukle(); }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('projects')
          .where('firmaId', isEqualTo: widget.firmaId)
          .get();
      if (mounted) setState(() {
        _projeler = snap.docs
            .map((d) => {'id': d.id, ...d.data()}).toList();
        _yukleniyor = false;
      });
    } catch (_) {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _tipGuncelle(String projeId, String yeniTip) async {
    await FirebaseFirestore.instance
        .collection('projects').doc(projeId)
        .update({'projecTipi': yeniTip});
    _yukle();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Proje tipi "$yeniTip" olarak guncellendi'),
          backgroundColor: Colors.green));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Proje Tipi Ayarlari',
            style: TextStyle(fontSize: 20,
                fontWeight: FontWeight.bold, color: _pNavy)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: _pOrange.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10)),
          child: const Row(children: [
            Icon(Icons.info_outline, color: _pOrange, size: 16),
            SizedBox(width: 8),
            Expanded(child: Text(
                'Proje tipini degistirerek sistem personel moduna gecis yapar',
                style: TextStyle(color: _pOrange, fontSize: 12))),
          ]),
        ),
        const SizedBox(height: 16),
        if (_yukleniyor)
          const Center(child: CircularProgressIndicator(color: _pOrange))
        else if (_projeler.isEmpty)
          const Center(child: Text('Proje bulunamadi',
              style: TextStyle(color: Colors.grey)))
        else
          Expanded(
            child: ListView.separated(
              itemCount: _projeler.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final p = _projeler[i];
                final mevcutTip = p['projecTipi'] ?? p['projetipi'] ?? 'okul';
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 6)]),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['ad'] ?? p['projeAdi'] ?? 'Proje',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15, color: _pNavy)),
                        const SizedBox(height: 12),
                        const Text('Proje Tipi Sec:',
                            style: TextStyle(
                                color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: _projecTipleri.map((tip) {
                            final sec = mevcutTip == tip['deger'];
                            return GestureDetector(
                              onTap: () => _tipGuncelle(
                                  p['id'], tip['deger'] as String),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                    color: sec ? _pNavy : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: sec
                                            ? _pNavy
                                            : Colors.grey.shade300)),
                                child: Row(mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(tip['ikon'] as IconData,
                                          color: sec ? Colors.white : Colors.grey,
                                          size: 16),
                                      const SizedBox(width: 6),
                                      Text(tip['label'] as String,
                                          style: TextStyle(
                                              color: sec
                                                  ? Colors.white
                                                  : Colors.black87,
                                              fontSize: 12,
                                              fontWeight: sec
                                                  ? FontWeight.bold
                                                  : FontWeight.normal)),
                                    ]),
                              ),
                            );
                          }).toList(),
                        ),
                      ]),
                );
              },
            ),
          ),
      ]),
    );
  }
}
