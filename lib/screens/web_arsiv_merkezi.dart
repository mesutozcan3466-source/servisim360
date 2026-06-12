import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/session_service.dart';

// ======================================================================
// WEB ARSIV MERKEZI  --  Servisim360
// Dijital arsiv: ogrenci, veli, sofor, arac evraklari
// ======================================================================

const Color _aNavy   = Color(0xFF1a3a6b);
const Color _aOrange = Color(0xFFFF8C00);
const Color _aBg     = Color(0xFFF0F2F5);

class WebArsivMerkezi extends StatefulWidget {
  const WebArsivMerkezi({super.key});
  @override
  State<WebArsivMerkezi> createState() => _WebArsivMerkeziState();
}

class _WebArsivMerkeziState extends State<WebArsivMerkezi> {
  String _kategori = 'ogrenci';
  String _firmaId  = '';

  static const _kategoriler = [
    {'key': 'ogrenci',   'label': 'Ogrenciler',    'ikon': Icons.school_outlined},
    {'key': 'veli',      'label': 'Veliler',        'ikon': Icons.family_restroom_outlined},
    {'key': 'sofor',     'label': 'Soforler',       'ikon': Icons.person_outlined},
    {'key': 'arac',      'label': 'Araclar',        'ikon': Icons.directions_bus_outlined},
    {'key': 'sozlesme',  'label': 'Sozlesmeler',    'ikon': Icons.description_outlined},
    {'key': 'rapor',     'label': 'Raporlar',       'ikon': Icons.bar_chart_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _firmaId = SessionService.instance.cachedFirmaId ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _aBg,
      body: Row(children: [
        // Sol kategori paneli
        Container(
          width: 200,
          color: Colors.white,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Arsiv Merkezi',
                            style: TextStyle(fontSize: 16,
                                fontWeight: FontWeight.bold, color: _aNavy)),
                        Text('Dijital dokuman yonetimi',
                            style: TextStyle(
                                color: Colors.grey, fontSize: 11)),
                      ]),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: _kategoriler.map((k) {
                      final aktif = _kategori == k['key'];
                      return InkWell(
                        onTap: () => setState(
                                () => _kategori = k['key'] as String),
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                              color: aktif
                                  ? _aNavy.withValues(alpha: 0.08)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: aktif
                                  ? Border.all(
                                  color: _aNavy.withValues(alpha: 0.2))
                                  : null),
                          child: Row(children: [
                            Icon(k['ikon'] as IconData,
                                color: aktif ? _aNavy : Colors.grey,
                                size: 18),
                            const SizedBox(width: 10),
                            Text(k['label'] as String,
                                style: TextStyle(
                                    color: aktif ? _aNavy : Colors.grey,
                                    fontWeight: aktif
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 13)),
                          ]),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ]),
        ),
        // Icerik
        Expanded(child: _KategoriIcerigi(
          firmaId: _firmaId,
          kategori: _kategori,
        )),
      ]),
    );
  }
}

// ======================================================================
// KATEGORI ICERIGI
// ======================================================================
class _KategoriIcerigi extends StatefulWidget {
  final String firmaId;
  final String kategori;
  const _KategoriIcerigi({
    required this.firmaId,
    required this.kategori,
  });
  @override
  State<_KategoriIcerigi> createState() => _KategoriIcerigiState();
}

class _KategoriIcerigiState extends State<_KategoriIcerigi> {
  List<Map<String, dynamic>> _evraklar = [];
  bool _yukleniyor = true;
  String _durumFiltre = 'aktif';

  @override
  void didUpdateWidget(_KategoriIcerigi oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kategori != widget.kategori) _yukle();
  }

  @override
  void initState() { super.initState(); _yukle(); }

  Future<void> _yukle() async {
    setState(() { _yukleniyor = true; _evraklar = []; });
    try {
      Query query = FirebaseFirestore.instance
          .collection('arsiv_belgeler')
          .where('firmaId', isEqualTo: widget.firmaId)
          .where('kategori', isEqualTo: widget.kategori)
          .where('durum', isEqualTo: _durumFiltre)
          .orderBy('yuklemeTarihi', descending: true);

      final snap = await query.get();
      if (mounted) setState(() {
        _evraklar = snap.docs
            .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
            .toList();
        _yukleniyor = false;
      });
    } catch (_) {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  void _evrakEkleDialog() {
    final adCtrl      = TextEditingController();
    final acikCtrl    = TextEditingController();
    final sahipCtrl   = TextEditingController();
    String evrakTip   = _evrakTipleri(widget.kategori).first;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('${_kategoriLabel(widget.kategori)} Evrak Ekle',
              style: const TextStyle(
                  color: _aNavy, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 480,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: adCtrl,
                decoration: InputDecoration(
                  labelText: 'Belge Adi *',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: sahipCtrl,
                decoration: InputDecoration(
                  labelText: 'Ait Oldugu Kisi / Arac',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: evrakTip,
                decoration: InputDecoration(
                  labelText: 'Evrak Tipi',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                items: _evrakTipleri(widget.kategori).map((t) =>
                    DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) =>
                    setD(() => evrakTip = v ?? evrakTip),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: acikCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Aciklama',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10)),
                child: const Row(children: [
                  Icon(Icons.info_outline,
                      color: Colors.blue, size: 16),
                  SizedBox(width: 8),
                  Expanded(child: Text(
                      'Dosya yuklemesi Firebase Storage ile yapilir. '
                          'Su an sadece kayit bilgisi tutulur.',
                      style: TextStyle(
                          color: Colors.blue, fontSize: 11))),
                ]),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context),
                child: const Text('Iptal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _aNavy),
              onPressed: () async {
                if (adCtrl.text.isEmpty) return;
                final user = FirebaseAuth.instance.currentUser;
                await FirebaseFirestore.instance
                    .collection('arsiv_belgeler').add({
                  'firmaId':       widget.firmaId,
                  'kategori':      widget.kategori,
                  'evrakTip':      evrakTip,
                  'ad':            adCtrl.text.trim(),
                  'sahip':         sahipCtrl.text.trim(),
                  'aciklama':      acikCtrl.text.trim(),
                  'durum':         'aktif',
                  'ekleyen':       user?.email ?? '',
                  'yuklemeTarihi': FieldValue.serverTimestamp(),
                  'dosyaUrl':      null,
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

  Future<void> _durumDegistir(String id, String yeniDurum) async {
    await FirebaseFirestore.instance
        .collection('arsiv_belgeler').doc(id)
        .update({'durum': yeniDurum});
    _yukle();
  }

  List<String> _evrakTipleri(String kategori) {
    switch (kategori) {
      case 'ogrenci': return ['Kayit Formu', 'Sozlesme', 'Adres Belgesi', 'Ozel Evrak'];
      case 'veli':    return ['Kimlik', 'Onay Formu', 'Sozlesme', 'Vekaletname'];
      case 'sofor':   return ['Ehliyet', 'SRC', 'Psikoteknik', 'Kimlik', 'Ise Giris'];
      case 'arac':    return ['Ruhsat', 'Sigorta', 'Kasko', 'Muayene'];
      case 'sozlesme':return ['Hizmet Sozlesmesi', 'Veli Sozlesmesi', 'Is Sozlesmesi'];
      case 'rapor':   return ['Aylik Rapor', 'Yillik Rapor', 'Devamsizlik', 'Gelir'];
      default:        return ['Genel Evrak'];
    }
  }

  String _kategoriLabel(String k) {
    const m = {
      'ogrenci': 'Ogrenci', 'veli': 'Veli', 'sofor': 'Sofor',
      'arac': 'Arac', 'sozlesme': 'Sozlesme', 'rapor': 'Rapor',
    };
    return m[k] ?? k;
  }

  Color _durumRengi(String durum) {
    switch (durum) {
      case 'aktif':  return Colors.green;
      case 'pasif':  return Colors.orange;
      case 'arsiv':  return Colors.grey;
      default:       return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('${_kategoriLabel(widget.kategori)} Evraklari (${_evraklar.length})',
              style: const TextStyle(fontSize: 18,
                  fontWeight: FontWeight.bold, color: _aNavy)),
          const Spacer(),
          // Durum filtresi
          Row(children: ['aktif', 'pasif', 'arsiv'].map((d) {
            final aktif = _durumFiltre == d;
            return GestureDetector(
              onTap: () {
                setState(() => _durumFiltre = d);
                _yukle();
              },
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: aktif ? _aNavy : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: aktif
                            ? _aNavy : Colors.grey.shade300)),
                child: Text(d,
                    style: TextStyle(
                        color: aktif ? Colors.white : Colors.grey,
                        fontSize: 12)),
              ),
            );
          }).toList()),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _aNavy, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: _evrakEkleDialog,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Evrak Ekle'),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
              onPressed: _yukle,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Yenile')),
        ]),
        const SizedBox(height: 16),
        if (_yukleniyor)
          const Center(child: CircularProgressIndicator(color: _aOrange))
        else if (_evraklar.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(children: [
              const Icon(Icons.folder_open_outlined,
                  size: 64, color: Colors.grey),
              const SizedBox(height: 12),
              Text('Bu kategoride ${_durumFiltre} evrak bulunamadi',
                  style: const TextStyle(color: Colors.grey)),
            ]),
          ))
        else
          Expanded(
            child: ListView.separated(
              itemCount: _evraklar.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final e     = _evraklar[i];
                final durum = e['durum'] ?? 'aktif';
                final renk  = _durumRengi(durum);
                final tip   = e['evrakTip'] ?? 'Evrak';
                final dosyaVar = e['dosyaUrl'] != null;

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
                          color: _aNavy.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(
                          dosyaVar
                              ? Icons.picture_as_pdf_outlined
                              : Icons.description_outlined,
                          color: _aNavy, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e['ad'] ?? 'Evrak',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color: _aNavy.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10)),
                              child: Text(tip,
                                  style: const TextStyle(
                                      color: _aNavy, fontSize: 10)),
                            ),
                            if (e['sahip'] != null &&
                                e['sahip'].isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(e['sahip'],
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 11)),
                            ],
                          ]),
                          if (e['aciklama'] != null &&
                              e['aciklama'].isNotEmpty)
                            Text(e['aciklama'],
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 11)),
                        ])),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: renk.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20)),
                            child: Text(durum,
                                style: TextStyle(
                                    color: renk, fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 6),
                          if (dosyaVar)
                            Icon(Icons.download_outlined,
                                color: _aNavy, size: 18),
                        ]),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                      onSelected: (v) {
                        if (v == 'aktif' || v == 'pasif' || v == 'arsiv') {
                          _durumDegistir(e['id'], v);
                        }
                      },
                      itemBuilder: (_) => [
                        if (durum != 'aktif')
                          const PopupMenuItem(value: 'aktif',
                              child: Text('Aktife Al')),
                        if (durum != 'pasif')
                          const PopupMenuItem(value: 'pasif',
                              child: Text('Pasife Al')),
                        if (durum != 'arsiv')
                          const PopupMenuItem(value: 'arsiv',
                              child: Text('Arsive Tasi')),
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
