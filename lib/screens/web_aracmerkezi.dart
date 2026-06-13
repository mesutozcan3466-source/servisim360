import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/session_service.dart';

// ======================================================================
// WEB ARAC MERKEZI  --  Servisim360
// Arac karti, bakim takibi, masraf, belgeler
// ======================================================================

const Color _mNavy   = Color(0xFF1a3a6b);
const Color _mOrange = Color(0xFFFF8C00);
const Color _mBg     = Color(0xFFF0F2F5);

class WebAracMerkezi extends StatefulWidget {
  const WebAracMerkezi({super.key});
  @override
  State<WebAracMerkezi> createState() => _WebAracMerkeziState();
}

class _WebAracMerkeziState extends State<WebAracMerkezi> {
  int    _tab     = 0;
  String _firmaId = '';
  String? _seciliAracId;

  @override
  void initState() {
    super.initState();
    _firmaId = SessionService.instance.cachedFirmaId ?? '';
  }

  static const _tablar = [
    'Arac Listesi', 'Bakim Takibi', 'Masraflar', 'Belgeler',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _mBg,
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: _mNavy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.directions_bus_outlined,
                  color: _mNavy, size: 24),
            ),
            const SizedBox(width: 14),
            const Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Arac Yonetim Merkezi',
                      style: TextStyle(fontSize: 18,
                          fontWeight: FontWeight.bold, color: _mNavy)),
                  Text('Filo takip ve bakim sistemi',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ]),
            const Spacer(),
            Row(children: _tablar.asMap().entries.map((e) {
              final aktif = _tab == e.key;
              return GestureDetector(
                onTap: () => setState(() => _tab = e.key),
                child: Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                      color: aktif ? _mNavy : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(e.value,
                      style: TextStyle(
                          color: aktif ? Colors.white : Colors.grey,
                          fontWeight: aktif
                              ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13)),
                ),
              );
            }).toList()),
          ]),
        ),
        Expanded(child: _tabIcerigi()),
      ]),
    );
  }

  Widget _tabIcerigi() {
    switch (_tab) {
      case 0: return _AracListesi(
          firmaId: _firmaId,
          onSecildi: (id) => setState(() => _seciliAracId = id));
      case 1: return _BakimTakibi(firmaId: _firmaId, aracId: _seciliAracId);
      case 2: return _MasrafTakibi(firmaId: _firmaId, aracId: _seciliAracId);
      case 3: return _AracBelgeleri(firmaId: _firmaId, aracId: _seciliAracId);
      default: return _AracListesi(
          firmaId: _firmaId,
          onSecildi: (id) => setState(() => _seciliAracId = id));
    }
  }
}

// ======================================================================
// ARAC LISTESI
// ======================================================================
class _AracListesi extends StatefulWidget {
  final String firmaId;
  final void Function(String) onSecildi;
  const _AracListesi({required this.firmaId, required this.onSecildi});
  @override
  State<_AracListesi> createState() => _AracListesiState();
}

class _AracListesiState extends State<_AracListesi> {
  List<Map<String, dynamic>> _araclar = [];
  bool _yukleniyor = true;
  String? _seciliId;

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
        _araclar = snap.docs
            .map((d) => {'id': d.id, ...d.data()}).toList();
        _yukleniyor = false;
      });
    } catch (_) {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  void _aracDialog(String? aracId, Map<String, dynamic>? mevcut) {
    final plakaCtrl  = TextEditingController(text: mevcut?['plaka'] ?? mevcut?['plakaNo'] ?? '');
    final markaCtrl  = TextEditingController(text: mevcut?['marka'] ?? '');
    final modelCtrl  = TextEditingController(text: mevcut?['model'] ?? '');
    final yilCtrl    = TextEditingController(text: mevcut?['yil']?.toString() ?? '');
    final koltukCtrl = TextEditingController(text: mevcut?['koltukSayisi']?.toString() ?? '');
    final kmCtrl     = TextEditingController(text: mevcut?['km']?.toString() ?? '');
    final yakitCtrl  = TextEditingController(text: mevcut?['yakitTuru'] ?? 'Dizel');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(aracId == null ? 'Yeni Arac Ekle' : 'Arac Duzenle',
            style: const TextStyle(
                color: _mNavy, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _tf(plakaCtrl,  'Plaka *',        Icons.credit_card_outlined),
              Row(children: [
                Expanded(child: _tf(markaCtrl, 'Marka', Icons.directions_bus_outlined)),
                const SizedBox(width: 12),
                Expanded(child: _tf(modelCtrl, 'Model', Icons.model_training_outlined)),
              ]),
              Row(children: [
                Expanded(child: _tf(yilCtrl, 'Yil', Icons.calendar_today_outlined,
                    keyboard: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: _tf(koltukCtrl, 'Koltuk Sayisi', Icons.airline_seat_recline_normal_outlined,
                    keyboard: TextInputType.number)),
              ]),
              Row(children: [
                Expanded(child: _tf(kmCtrl, 'KM', Icons.speed_outlined,
                    keyboard: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: _tf(yakitCtrl, 'Yakit Turu', Icons.local_gas_station_outlined)),
              ]),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Iptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _mNavy),
            onPressed: () async {
              if (plakaCtrl.text.isEmpty) return;
              final veri = {
                'firmaId':      widget.firmaId,
                'plaka':        plakaCtrl.text.trim().toUpperCase(),
                'plakaNo':      plakaCtrl.text.trim().toUpperCase(),
                'marka':        markaCtrl.text.trim(),
                'model':        modelCtrl.text.trim(),
                'yil':          int.tryParse(yilCtrl.text) ?? 0,
                'koltukSayisi': int.tryParse(koltukCtrl.text) ?? 0,
                'km':           int.tryParse(kmCtrl.text) ?? 0,
                'yakitTuru':    yakitCtrl.text.trim(),
                'guncelleme':   FieldValue.serverTimestamp(),
              };
              if (aracId == null) {
                veri['olusturma'] = FieldValue.serverTimestamp();
                veri['aktif'] = true;
                await FirebaseFirestore.instance
                    .collection('vehicles').add(veri);
              } else {
                await FirebaseFirestore.instance
                    .collection('vehicles').doc(aracId).update(veri);
              }
              if (mounted) Navigator.pop(context);
              _yukle();
            },
            child: const Text('Kaydet',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _tf(TextEditingController c, String label, IconData ikon,
      {TextInputType keyboard = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c, keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label, prefixIcon: Icon(ikon, size: 18),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10)),
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
          Text('Araclar (${_araclar.length})',
              style: const TextStyle(fontSize: 18,
                  fontWeight: FontWeight.bold, color: _mNavy)),
          if (_seciliId != null) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: _mOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(
                  'Secili: ${_araclar.firstWhere((a) => a['id'] == _seciliId, orElse: () => {})['plaka'] ?? ''}',
                  style: const TextStyle(
                      color: _mOrange, fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
          ],
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _mNavy, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () => _aracDialog(null, null),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Arac Ekle'),
          ),
        ]),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8)),
          child: const Row(children: [
            Icon(Icons.info_outline, color: Colors.blue, size: 14),
            SizedBox(width: 6),
            Text('Araci secince Bakim, Masraf ve Belge tablari o arac icin acilir',
                style: TextStyle(color: Colors.blue, fontSize: 11)),
          ]),
        ),
        const SizedBox(height: 16),
        if (_yukleniyor)
          const Center(child: CircularProgressIndicator(color: _mOrange))
        else
          Expanded(
            child: ListView.separated(
              itemCount: _araclar.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final a      = _araclar[i];
                final plaka  = a['plaka'] ?? a['plakaNo'] ?? '-';
                final aktif  = a['servisAktif'] == true;
                final sec    = _seciliId == a['id'];

                // Sigorta/muayene uyari kontrol
                bool uyariVar = false;
                final sigortaBitis = a['sigortaBitis'];
                if (sigortaBitis != null) {
                  final dt = (sigortaBitis as Timestamp).toDate();
                  if (dt.difference(DateTime.now()).inDays < 30) {
                    uyariVar = true;
                  }
                }

                return GestureDetector(
                  onTap: () {
                    setState(() => _seciliId = a['id']);
                    widget.onSecildi(a['id']);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: sec
                              ? _mNavy
                              : uyariVar
                              ? Colors.orange.withValues(alpha: 0.4)
                              : Colors.transparent,
                          width: sec ? 2 : 1),
                      boxShadow: [BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 6)],
                    ),
                    child: Row(children: [
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                            color: aktif
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12)),
                        child: Icon(Icons.directions_bus_outlined,
                            color: aktif ? Colors.green : Colors.grey,
                            size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text(plaka, style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16, color: _mNavy,
                                  letterSpacing: 1)),
                              if (uyariVar) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.warning_amber_outlined,
                                    color: Colors.orange, size: 16),
                              ],
                            ]),
                            Text('${a['marka'] ?? ''} ${a['model'] ?? ''} ${a['yil'] != null ? '(${a['yil']})' : ''}',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                            Row(children: [
                              if (a['koltukSayisi'] != null) ...[
                                const Icon(Icons.airline_seat_recline_normal_outlined,
                                    size: 12, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text('${a['koltukSayisi']} koltuk',
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 11)),
                                const SizedBox(width: 10),
                              ],
                              if (a['km'] != null) ...[
                                const Icon(Icons.speed_outlined,
                                    size: 12, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text('${a['km']} km',
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 11)),
                              ],
                            ]),
                          ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
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
                                      color: aktif
                                          ? Colors.green : Colors.grey,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ),
                            if (a['soforAd'] != null) ...[
                              const SizedBox(height: 4),
                              Text(a['soforAd'],
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 11)),
                            ],
                          ]),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.grey),
                        onSelected: (v) {
                          if (v == 'duzenle') _aracDialog(a['id'], a);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'duzenle',
                              child: Text('Duzenle')),
                        ],
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
      ]),
    );
  }
}

// ======================================================================
// BAKIM TAKIBI
// ======================================================================
class _BakimTakibi extends StatefulWidget {
  final String firmaId;
  final String? aracId;
  const _BakimTakibi({required this.firmaId, this.aracId});
  @override
  State<_BakimTakibi> createState() => _BakimTakibiState();
}

class _BakimTakibiState extends State<_BakimTakibi> {
  List<Map<String, dynamic>> _bakimlar = [];
  bool _yukleniyor = true;

  static const _bakimTipleri = [
    'Yag Bakimi', 'Filtre Bakimi', 'Lastik Degisimi',
    'Agir Bakim', 'Fren Bakimi', 'Klima Bakimi', 'Genel Kontrol',
  ];

  @override
  void initState() { super.initState(); _yukle(); }

  @override
  void didUpdateWidget(_BakimTakibi oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.aracId != widget.aracId) _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      Query query = FirebaseFirestore.instance
          .collection('arac_bakim')
          .where('firmaId', isEqualTo: widget.firmaId)
          .orderBy('tarih', descending: true);
      if (widget.aracId != null) {
        query = query.where('aracId', isEqualTo: widget.aracId);
      }
      final snap = await query.limit(50).get();
      if (mounted) setState(() {
        _bakimlar = snap.docs
            .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
            .toList();
        _yukleniyor = false;
      });
    } catch (_) {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  void _bakimDialog() {
    if (widget.aracId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lutfen once Arac Listesinden bir arac secin')));
      return;
    }
    final kmCtrl      = TextEditingController();
    final notCtrl     = TextEditingController();
    final maliyetCtrl = TextEditingController();
    String bakimTip   = _bakimTipleri.first;
    DateTime tarih    = DateTime.now();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Bakim Kaydi Ekle',
              style: TextStyle(
                  color: _mNavy, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 460,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: bakimTip,
                decoration: InputDecoration(
                  labelText: 'Bakim Tipi',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                items: _bakimTipleri.map((t) =>
                    DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) =>
                    setD(() => bakimTip = v ?? bakimTip),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(
                  controller: kmCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'KM',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                )),
                const SizedBox(width: 12),
                Expanded(child: TextField(
                  controller: maliyetCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Maliyet (TL)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                )),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: notCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Notlar',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final dt = await showDatePicker(
                    context: context,
                    initialDate: tarih,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (dt != null) setD(() => tarih = dt);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 16, color: _mNavy),
                    const SizedBox(width: 8),
                    Text(
                        '${tarih.day}.${tarih.month}.${tarih.year}',
                        style: const TextStyle(color: _mNavy)),
                  ]),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context),
                child: const Text('Iptal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _mNavy),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('arac_bakim').add({
                  'firmaId':  widget.firmaId,
                  'aracId':   widget.aracId,
                  'tip':      bakimTip,
                  'km':       int.tryParse(kmCtrl.text) ?? 0,
                  'maliyet':  double.tryParse(maliyetCtrl.text) ?? 0,
                  'not':      notCtrl.text.trim(),
                  'tarih':    Timestamp.fromDate(tarih),
                  'olusturma':FieldValue.serverTimestamp(),
                });
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
          const Text('Bakim Kayitlari',
              style: TextStyle(fontSize: 18,
                  fontWeight: FontWeight.bold, color: _mNavy)),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _mNavy, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: _bakimDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Bakim Ekle'),
          ),
        ]),
        if (widget.aracId == null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10)),
            child: const Row(children: [
              Icon(Icons.info_outline, color: Colors.orange, size: 16),
              SizedBox(width: 8),
              Text('Arac Listesinden bir arac secerek bakim kayitlarini gorun',
                  style: TextStyle(color: Colors.orange, fontSize: 12)),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        if (_yukleniyor)
          const Center(child: CircularProgressIndicator(color: _mOrange))
        else if (_bakimlar.isEmpty)
          const Center(child: Padding(
            padding: EdgeInsets.all(40),
            child: Text('Bakim kaydi bulunamadi',
                style: TextStyle(color: Colors.grey)),
          ))
        else
          Expanded(
            child: ListView.separated(
              itemCount: _bakimlar.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final b = _bakimlar[i];
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
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.build_outlined,
                          color: Colors.teal, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b['tip'] ?? 'Bakim',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          if (b['km'] != null && b['km'] != 0)
                            Text('${b['km']} km',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 11)),
                          if (b['not'] != null && b['not'] != '')
                            Text(b['not'],
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 11)),
                        ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (b['maliyet'] != null && b['maliyet'] != 0)
                            Text('${b['maliyet']} TL',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _mOrange, fontSize: 13)),
                          Text(_tarihBicim(b['tarih']),
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
// MASRAF TAKIBI
// ======================================================================
class _MasrafTakibi extends StatefulWidget {
  final String firmaId;
  final String? aracId;
  const _MasrafTakibi({required this.firmaId, this.aracId});
  @override
  State<_MasrafTakibi> createState() => _MasrafTakibiState();
}

class _MasrafTakibiState extends State<_MasrafTakibi> {
  List<Map<String, dynamic>> _masraflar = [];
  bool _yukleniyor = true;
  double _toplamMasraf = 0;

  static const _masrafTipleri = [
    'Yakit', 'Bakim', 'Lastik', 'Sigorta', 'Kasko',
    'Muayene', 'Onarim', 'Diger',
  ];

  @override
  void initState() { super.initState(); _yukle(); }

  @override
  void didUpdateWidget(_MasrafTakibi oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.aracId != widget.aracId) _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      Query query = FirebaseFirestore.instance
          .collection('arac_masraf')
          .where('firmaId', isEqualTo: widget.firmaId)
          .orderBy('tarih', descending: true);
      if (widget.aracId != null) {
        query = query.where('aracId', isEqualTo: widget.aracId);
      }
      final snap = await query.limit(100).get();
      final liste = snap.docs
          .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
          .toList();
      final toplam = liste.fold<double>(
          0, (sum, m) => sum + (m['tutar'] as num? ?? 0).toDouble());
      if (mounted) setState(() {
        _masraflar   = liste;
        _toplamMasraf = toplam;
        _yukleniyor  = false;
      });
    } catch (_) {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  void _masrafDialog() {
    if (widget.aracId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lutfen once bir arac secin')));
      return;
    }
    final tutarCtrl = TextEditingController();
    final notCtrl   = TextEditingController();
    String masrafTip = _masrafTipleri.first;
    DateTime tarih   = DateTime.now();

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Masraf Ekle',
              style: TextStyle(
                  color: _mNavy, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 400,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: masrafTip,
                decoration: InputDecoration(
                  labelText: 'Masraf Tipi',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                items: _masrafTipleri.map((t) =>
                    DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) =>
                    setD(() => masrafTip = v ?? masrafTip),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tutarCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Tutar (TL) *',
                  prefixIcon: const Icon(Icons.attach_money_outlined,
                      size: 18),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notCtrl,
                decoration: InputDecoration(
                  labelText: 'Not',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final dt = await showDatePicker(
                    context: context,
                    initialDate: tarih,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (dt != null) setD(() => tarih = dt);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 16, color: _mNavy),
                    const SizedBox(width: 8),
                    Text('${tarih.day}.${tarih.month}.${tarih.year}',
                        style: const TextStyle(color: _mNavy)),
                  ]),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context),
                child: const Text('Iptal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _mNavy),
              onPressed: () async {
                if (tutarCtrl.text.isEmpty) return;
                await FirebaseFirestore.instance
                    .collection('arac_masraf').add({
                  'firmaId':  widget.firmaId,
                  'aracId':   widget.aracId,
                  'tip':      masrafTip,
                  'tutar':    double.tryParse(tutarCtrl.text) ?? 0,
                  'not':      notCtrl.text.trim(),
                  'tarih':    Timestamp.fromDate(tarih),
                  'olusturma':FieldValue.serverTimestamp(),
                });
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
    // Tip bazli ozet
    final tipOzetleri = <String, double>{};
    for (final m in _masraflar) {
      final tip  = m['tip'] as String? ?? 'Diger';
      final tutar = (m['tutar'] as num? ?? 0).toDouble();
      tipOzetleri[tip] = (tipOzetleri[tip] ?? 0) + tutar;
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Masraf Takibi',
              style: TextStyle(fontSize: 18,
                  fontWeight: FontWeight.bold, color: _mNavy)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
                color: _mOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20)),
            child: Text(
                'Toplam: ${_toplamMasraf.toStringAsFixed(0)} TL',
                style: const TextStyle(
                    color: _mOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _mNavy, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: _masrafDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Masraf Ekle'),
          ),
        ]),
        const SizedBox(height: 16),
        // Tip bazli ozet
        if (tipOzetleri.isNotEmpty) ...[
          Wrap(
            spacing: 8, runSpacing: 8,
            children: tipOzetleri.entries.map((e) {
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4)]),
                child: Column(children: [
                  Text(e.key,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 11)),
                  Text('${e.value.toStringAsFixed(0)} TL',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _mNavy, fontSize: 13)),
                ]),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
        if (_yukleniyor)
          const Center(child: CircularProgressIndicator(color: _mOrange))
        else if (_masraflar.isEmpty)
          const Center(child: Padding(
            padding: EdgeInsets.all(40),
            child: Text('Masraf kaydi bulunamadi',
                style: TextStyle(color: Colors.grey)),
          ))
        else
          Expanded(
            child: ListView.separated(
              itemCount: _masraflar.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final m = _masraflar[i];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: _mOrange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.receipt_long_outlined,
                          color: _mOrange, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m['tip'] ?? 'Masraf',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          if (m['not'] != null && m['not'] != '')
                            Text(m['not'],
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 11)),
                        ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${(m['tutar'] as num? ?? 0).toStringAsFixed(0)} TL',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _mOrange, fontSize: 14)),
                          Text(_tarihBicim(m['tarih']),
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
// ARAC BELGELERI
// ======================================================================
class _AracBelgeleri extends StatefulWidget {
  final String firmaId;
  final String? aracId;
  const _AracBelgeleri({required this.firmaId, this.aracId});
  @override
  State<_AracBelgeleri> createState() => _AracBelgeleriState();
}

class _AracBelgeleriState extends State<_AracBelgeleri> {
  List<Map<String, dynamic>> _belgeler = [];
  bool _yukleniyor = true;

  @override
  void initState() { super.initState(); _yukle(); }

  @override
  void didUpdateWidget(_AracBelgeleri oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.aracId != widget.aracId) _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      Query query = FirebaseFirestore.instance
          .collection('arac_belgeler')
          .where('firmaId', isEqualTo: widget.firmaId);
      if (widget.aracId != null) {
        query = query.where('aracId', isEqualTo: widget.aracId);
      }
      final snap = await query.get();
      if (mounted) setState(() {
        _belgeler = snap.docs
            .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
            .toList();
        _yukleniyor = false;
      });
    } catch (_) {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  void _belgeDialog() {
    if (widget.aracId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lutfen once bir arac secin')));
      return;
    }
    final adCtrl = TextEditingController();
    String tip   = 'Ruhsat';
    DateTime? bitisTarihi;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Belge Ekle',
              style: TextStyle(
                  color: _mNavy, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 400,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: tip,
                decoration: InputDecoration(
                  labelText: 'Belge Tipi',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                items: ['Ruhsat', 'Sigorta', 'Kasko', 'Muayene']
                    .map((t) => DropdownMenuItem(
                    value: t, child: Text(t))).toList(),
                onChanged: (v) => setD(() => tip = v ?? tip),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: adCtrl,
                decoration: InputDecoration(
                  labelText: 'Belge Adi / Not',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final dt = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now()
                        .add(const Duration(days: 365)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2035),
                  );
                  if (dt != null) setD(() => bitisTarihi = dt);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 16, color: _mNavy),
                    const SizedBox(width: 8),
                    Text(
                        bitisTarihi != null
                            ? 'Bitis: ${bitisTarihi!.day}.${bitisTarihi!.month}.${bitisTarihi!.year}'
                            : 'Bitis Tarihi Sec',
                        style: TextStyle(
                            color: bitisTarihi != null
                                ? _mNavy : Colors.grey)),
                  ]),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context),
                child: const Text('Iptal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _mNavy),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('arac_belgeler').add({
                  'firmaId':     widget.firmaId,
                  'aracId':      widget.aracId,
                  'tip':         tip,
                  'ad':          adCtrl.text.trim(),
                  'bitisTarihi': bitisTarihi != null
                      ? Timestamp.fromDate(bitisTarihi!) : null,
                  'olusturma':   FieldValue.serverTimestamp(),
                });
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
    // Yakinda bitecek belgeleri bul
    final uyarilar = _belgeler.where((b) {
      final bitis = b['bitisTarihi'];
      if (bitis == null) return false;
      final dt = (bitis as Timestamp).toDate();
      return dt.difference(DateTime.now()).inDays < 30;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Arac Belgeleri',
              style: TextStyle(fontSize: 18,
                  fontWeight: FontWeight.bold, color: _mNavy)),
          if (uyarilar.isNotEmpty) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('${uyarilar.length} Bitmek Uzere',
                  style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          ],
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _mNavy, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: _belgeDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Belge Ekle'),
          ),
        ]),
        const SizedBox(height: 16),
        if (_yukleniyor)
          const Center(child: CircularProgressIndicator(color: _mOrange))
        else if (_belgeler.isEmpty)
          const Center(child: Padding(
            padding: EdgeInsets.all(40),
            child: Text('Belge bulunamadi',
                style: TextStyle(color: Colors.grey)),
          ))
        else
          Expanded(
            child: ListView.separated(
              itemCount: _belgeler.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final b = _belgeler[i];
                final bitis = b['bitisTarihi'];
                int? kalanGun;
                bool uyari = false;
                if (bitis != null) {
                  final dt = (bitis as Timestamp).toDate();
                  kalanGun = dt.difference(DateTime.now()).inDays;
                  uyari = kalanGun < 30;
                }

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: uyari
                            ? Colors.red.withValues(alpha: 0.3)
                            : Colors.transparent),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: uyari
                              ? Colors.red.withValues(alpha: 0.1)
                              : Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.description_outlined,
                          color: uyari ? Colors.red : Colors.green,
                          size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b['tip'] ?? 'Belge',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
                          if (b['ad'] != null && b['ad'] != '')
                            Text(b['ad'],
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 11)),
                        ])),
                    if (kalanGun != null)
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                                kalanGun > 0
                                    ? '$kalanGun gun kaldi'
                                    : 'SURESI DOLDU',
                                style: TextStyle(
                                    color: uyari ? Colors.red : Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                            Text(_tarihBicim(bitis),
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
