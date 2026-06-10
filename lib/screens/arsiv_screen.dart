// â•”â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•—
// â•‘  DOSYA: lib/screens/arsiv_screen.dart                       â•‘
// â•‘  Servisim360 â€” Evrak & Belge YÃ¶netim Sistemi                â•‘
// â•‘  v4 â€” Kategorili, Otomatik, Kalici Silme Yok               â•‘
// â•šâ•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
import 'package:flutter/material.dart';
import 'ai_widget.dart';
import 'yardim_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import '../services/session_service.dart';

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// EVRAK KATEGORÄ°LERÄ°
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _EvrakKategori {
  final String id, ad, ikon;
  final Color renk;
  final List<String> altTurler;
  const _EvrakKategori(this.id, this.ad, this.ikon, this.renk, this.altTurler);
}

const List<_EvrakKategori> _kategoriler = [
  _EvrakKategori('ogrenci', 'Ã–ÄŸrenci Evraklari', 'ğŸ“', Color(0xFF2196F3), [
    'KayÄ±t Formu', 'SÃ¶zleÅŸme', 'Kimlik Fotokopisi', 'Ä°kametgah', 'FotoÄŸraf', 'DiÄŸer'
  ]),
  _EvrakKategori('sofor', 'ÅofÃ¶r Evraklari', 'ğŸš—', Color(0xFF4CAF50), [
    'Ehliyet', 'SRC Belgesi', 'Psikoteknik', 'Adli Sicil', 'Kimlik', 'SaÄŸlÄ±k Raporu', 'DiÄŸer'
  ]),
  _EvrakKategori('arac', 'Arac Evraklari', 'ğŸšŒ', Color(0xFFFF9800), [
    'Ruhsat', 'Sigorta', 'Kasko', 'Muayene', 'Trafik Belgesi', 'DiÄŸer'
  ]),
  _EvrakKategori('firma', 'Firma Evraklari', 'ğŸ¢', Color(0xFF9C27B0), [
    'Vergi LevhasÄ±', 'Yetki Belgesi', 'TaÅŸÄ±ma Ä°zni', 'Ticaret Sicil', 'Ä°mza SirkÃ¼leri', 'DiÄŸer'
  ]),
  _EvrakKategori('sozlesme', 'Sozlesmeler', 'ğŸ“„', Color(0xFF1a3a6b), [
    'Ã–ÄŸrenci SÃ¶zleÅŸmesi', 'Personel SÃ¶zleÅŸmesi', 'Turizm SÃ¶zleÅŸmesi', 'Hizmet SÃ¶zleÅŸmesi', 'DiÄŸer'
  ]),
  _EvrakKategori('sistem', 'Sistem Belgeleri', 'ğŸ’¾', Color(0xFF607D8B), [
    'PDF Rapor', 'Excel Rapor', 'Otomatik Belge', 'Ä°ndirilen Dosya', 'DiÄŸer'
  ]),
];

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// ANA EKRAN
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class ArsivScreen extends StatefulWidget {
  const ArsivScreen({super.key});
  @override
  State<ArsivScreen> createState() => _ArsivScreenState();
}

class _ArsivScreenState extends State<ArsivScreen> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  String _firmaId  = '';
  String _projeId  = '';
  String _arama    = '';
  String _seciliKategori = 'tumu';
  bool   _sadecePasif    = false;
  final _aramaCtrl = TextEditingController();
  bool _yukleniyor = true;

  @override
  void initState() { super.initState(); _yukle(); }

  @override
  void dispose() { _aramaCtrl.dispose(); super.dispose(); }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    _firmaId = await SessionService.instance.firmaIdAl() ?? '';
    _projeId = SessionService.instance.aktifProjeId ?? '';
    if (mounted) setState(() => _yukleniyor = false);
  }

  // â”€â”€ DOSYA YÃœKLE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _dosyaYukle({String? kategori, String? iliskiId, String? iliskiAd}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any, withData: true,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    // Kategori seÃ§imi dialog
    String secilenKat = kategori ?? ((_seciliKategori == 'tumu') ? 'ogrenci' : _seciliKategori);
    String secilenAlt = '';

    if (!mounted) return;
    final secim = await _kategoriSecDialog(secilenKat, secilenAlt);
    if (secim == null) return;
    secilenKat = secim['kategori']!;
    secilenAlt = secim['altTur']!;
    final iliskiIdFinal = secim['iliskiId'] ?? iliskiId ?? '';
    final iliskiAdFinal = secim['iliskiAd'] ?? iliskiAd ?? '';

    int basarili = 0;
    for (final file in result.files) {
      if (file.bytes == null) continue;
      try {
        // Web'de base64 olarak kaydet (kÃ¼Ã§Ã¼k dosyalar iÃ§in)
        // BÃ¼yÃ¼k dosyalar iÃ§in Firebase Storage kullanÄ±lmalÄ±
        final boyutKB = file.bytes!.length ~/ 1024;
        String? base64Data;
        if (boyutKB < 500) { // 500KB altÄ± base64
          base64Data = Uri.dataFromBytes(file.bytes!).toString();
        }

        await FirebaseFirestore.instance.collection('evraklar').add({
          'firmaId'    : _firmaId,
          'projeId'    : _projeId,
          'kategori'   : secilenKat,
          'altTur'     : secilenAlt,
          'dosyaAdi'   : file.name,
          'boyutKB'    : boyutKB,
          'uzanti'     : file.extension ?? '',
          'iliskiId'   : iliskiIdFinal,
          'iliskiAd'   : iliskiAdFinal,
          'base64'     : base64Data,
          'aktif'      : true,
          'kaynak'     : 'manuel',
          'olusturma'  : FieldValue.serverTimestamp(),
        });
        basarili++;
      } catch (e) { debugPrint('YÃ¼kleme hatasÄ±: $e'); }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$basarili dosya yÃ¼klendi âœ“'),
          backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
    }
  }

  // â”€â”€ KATEGORÄ° + Ä°LÄ°ÅKÄ° SEÃ‡Ä°M DIALOG â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<Map<String, String>?> _kategoriSecDialog(String initKat, String initAlt) async {
    String secilenKat = initKat;
    String secilenAlt = initAlt;
    String iliskiId = '', iliskiAd = '';

    return showDialog<Map<String, String>>(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, ss) {
        final katObj = _kategoriler.firstWhere((k) => k.id == secilenKat,
            orElse: () => _kategoriler.first);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.folder_outlined, color: _navy),
            SizedBox(width: 8),
            Text('Evrak Kategorisi SeÃ§'),
          ]),
          content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Kategori seÃ§
            const Align(alignment: Alignment.centerLeft,
                child: Text('Kategori', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: _kategoriler.map((k) {
              final sec = secilenKat == k.id;
              return GestureDetector(
                onTap: () => ss(() { secilenKat = k.id; secilenAlt = ''; }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: sec ? k.renk : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${k.ikon} ${k.ad}', style: TextStyle(
                      color: sec ? Colors.white : Colors.black87, fontSize: 11)),
                ),
              );
            }).toList()),
            const SizedBox(height: 16),
            // Alt tÃ¼r seÃ§
            const Align(alignment: Alignment.centerLeft,
                child: Text('Belge TÃ¼rÃ¼', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: katObj.altTurler.map((a) {
              final sec = secilenAlt == a;
              return GestureDetector(
                onTap: () => ss(() => secilenAlt = a),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: sec ? katObj.renk.withValues(alpha: 0.15) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: sec ? katObj.renk : Colors.grey.shade200),
                  ),
                  child: Text(a, style: TextStyle(
                      color: sec ? katObj.renk : Colors.black87, fontSize: 11,
                      fontWeight: sec ? FontWeight.bold : FontWeight.normal)),
                ),
              );
            }).toList()),
            const SizedBox(height: 16),
            // Ä°liÅŸki (kiÅŸi/araÃ§ adÄ±)
            TextField(
              decoration: const InputDecoration(
                labelText: 'Ä°lgili KiÅŸi/AraÃ§ (Ä°steÄŸe BaÄŸlÄ±)',
                hintText: 'Ã–rn: Ahmet YÄ±lmaz, 34ABC123',
                prefixIcon: Icon(Icons.link_rounded, size: 16),
                border: OutlineInputBorder(), isDense: true,
              ),
              onChanged: (v) => iliskiAd = v,
            ),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(_), child: const Text('Ä°ptal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
              onPressed: secilenAlt.isEmpty ? null : () => Navigator.pop(_, {
                'kategori': secilenKat, 'altTur': secilenAlt,
                'iliskiId': iliskiId, 'iliskiAd': iliskiAd,
              }),
              child: const Text('YÃ¼kle'),
            ),
          ],
        );
      }),
    );
  }

  // â”€â”€ KLASÃ–R OLUÅTUR â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _klasorOlustur() async {
    final ctrl = TextEditingController();
    final onay = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.create_new_folder_rounded, color: _navy),
          SizedBox(width: 8),
          Text('Yeni KlasÃ¶r'),
        ]),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'KlasÃ¶r AdÄ±',
            hintText: 'Ã–rn: 2026 Ã–ÄŸrenci Evraklari',
            prefixIcon: Icon(Icons.folder_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_, false), child: const Text('Ä°ptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(_, true),
            child: const Text('OluÅŸtur'),
          ),
        ],
      ),
    );
    if (onay != true || ctrl.text.trim().isEmpty) return;
    await FirebaseFirestore.instance.collection('evrak_klasorler').add({
      'firmaId'  : _firmaId,
      'ad'       : ctrl.text.trim(),
      'aktif'    : true,
      'olusturma': FieldValue.serverTimestamp(),
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('KlasÃ¶r oluÅŸturuldu âœ“'), backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white,
        title: const Row(children: [
          Icon(Icons.archive_rounded, size: 20),
          SizedBox(width: 8),
          Text('Evrak & ArÅŸiv', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: 'KlasÃ¶r OluÅŸtur',
            onPressed: _klasorOlustur,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file_rounded),
            tooltip: 'Dosya YÃ¼kle',
            onPressed: _dosyaYukle,
          ),
          AiAsistanButonu(ekranAdi: 'Arsiv'),
          YardimButonu(ekranAdi: 'Arsiv'),
          const SizedBox(width: 8),
        ],
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
        // Ãœst bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            // Arama
            Expanded(child: TextField(
              controller: _aramaCtrl,
              onChanged: (v) => setState(() => _arama = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Dosya adÄ±, kiÅŸi adÄ± ara...',
                prefixIcon: const Icon(Icons.search_rounded, color: _navy, size: 18),
                suffixIcon: _arama.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear_rounded, size: 16),
                    onPressed: () { _aramaCtrl.clear(); setState(() => _arama = ''); })
                    : null,
                filled: true, fillColor: const Color(0xFFF5F7FA),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
                isDense: true,
              ),
            )),
            const SizedBox(width: 10),
            // Pasif filtre
            FilterChip(
              label: const Text('Pasifler', style: TextStyle(fontSize: 12)),
              selected: _sadecePasif,
              onSelected: (v) => setState(() => _sadecePasif = v),
              selectedColor: Colors.orange.shade100,
            ),
            const SizedBox(width: 10),
            // YÃ¼kle butonu
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _turuncu, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: _dosyaYukle,
              icon: const Icon(Icons.upload_file_rounded, size: 16),
              label: const Text('Dosya YÃ¼kle', style: TextStyle(fontSize: 12)),
            ),
          ]),
        ),

        // Kategori filtreleri
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _katBtn('tumu', 'ğŸ“ TÃ¼mÃ¼', Colors.grey),
              ...  _kategoriler.map((k) => _katBtn(k.id, '${k.ikon} ${k.ad}', k.renk)),
            ]),
          ),
        ),

        const Divider(height: 1),

        // Ä°Ã§erik
        Expanded(child: Row(children: [
          // Sol â€” KlasÃ¶rler
          _buildKlasorPanel(),
          const VerticalDivider(width: 1),
          // SaÄŸ â€” Dosyalar
          Expanded(child: _buildDosyaListesi()),
        ])),
      ]),
    );
  }

  Widget _katBtn(String id, String ad, Color renk) {
    final sec = _seciliKategori == id;
    return GestureDetector(
      onTap: () => setState(() => _seciliKategori = id),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sec ? renk : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sec ? renk : Colors.transparent),
        ),
        child: Text(ad, style: TextStyle(
            color: sec ? Colors.white : Colors.black87,
            fontSize: 11, fontWeight: sec ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  // â”€â”€ SOL PANEL â€” KLASÃ–RLER â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildKlasorPanel() {
    return Container(
      width: 220,
      color: const Color(0xFFF8F9FA),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            const Icon(Icons.folder_outlined, color: _navy, size: 16),
            const SizedBox(width: 6),
            const Text('KlasÃ¶rler', style: TextStyle(fontWeight: FontWeight.bold, color: _navy, fontSize: 13)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.add_rounded, size: 18, color: _turuncu),
              onPressed: _klasorOlustur,
              tooltip: 'Yeni KlasÃ¶r',
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
          ]),
        ),
        const Divider(height: 1),
        Expanded(child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('evrak_klasorler')
              .where('firmaId', isEqualTo: _firmaId)
              .snapshots(),
          builder: (_, snap) {
            final klasorler = snap.data?.docs ?? [];
            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                // Otomatik kategoriler
                ...  _kategoriler.map((k) => ListTile(
                  dense: true,
                  leading: Text(k.ikon, style: const TextStyle(fontSize: 18)),
                  title: Text(k.ad, style: const TextStyle(fontSize: 12)),
                  selected: _seciliKategori == k.id,
                  selectedColor: k.renk,
                  selectedTileColor: k.renk.withValues(alpha: 0.08),
                  onTap: () => setState(() => _seciliKategori = k.id),
                )),
                if (klasorler.isNotEmpty) ...[
                  const Divider(),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Text('Ã–ZEL KLASÃ–RLER', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold))),
                  ...klasorler.map((k) {
                    final d = k.data() as Map<String, dynamic>;
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.folder_rounded, color: _turuncu, size: 18),
                      title: Text(d['ad'] ?? '', style: const TextStyle(fontSize: 12)),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, size: 14),
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'pasif', child: Text('Pasife Al')),
                        ],
                        onSelected: (v) {
                          if (v == 'pasif') {
                            k.reference.update({'aktif': false});
                          }
                        },
                      ),
                    );
                  }),
                ],
              ],
            );
          },
        )),
      ]),
    );
  }

  // â”€â”€ SAÄ PANEL â€” DOSYALAR â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildDosyaListesi() {
    var query = FirebaseFirestore.instance
        .collection('evraklar')
        .where('firmaId', isEqualTo: _firmaId);

    if (_seciliKategori != 'tumu') {
      query = query.where('kategori', isEqualTo: _seciliKategori);
    }
    if (!_sadecePasif) {
      query = query.where('aktif', isEqualTo: true);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _navy));
        }

        var docs = snap.data?.docs ?? [];

        // Arama
        if (_arama.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return (data['dosyaAdi'] ?? '').toLowerCase().contains(_arama) ||
                (data['iliskiAd'] ?? '').toLowerCase().contains(_arama) ||
                (data['altTur']   ?? '').toLowerCase().contains(_arama);
          }).toList();
        }

        if (docs.isEmpty) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.folder_open_outlined, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 12),
            const Text('HenÃ¼z dosya yok', style: TextStyle(color: Colors.grey, fontSize: 15)),
            const SizedBox(height: 8),
            const Text('SaÄŸ Ã¼stteki "Dosya YÃ¼kle" ile ekleyin\nveya sistem otomatik ekler',
                style: TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: _turuncu, foregroundColor: Colors.white),
              onPressed: _dosyaYukle,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Dosya YÃ¼kle'),
            ),
          ]));
        }

        // Grupla â€” alt tÃ¼re gÃ¶re
        final gruplar = <String, List<QueryDocumentSnapshot>>{};
        for (final d in docs) {
          final data = d.data() as Map<String, dynamic>;
          final tur = data['altTur'] as String? ?? 'DiÄŸer';
          gruplar.putIfAbsent(tur, () => []).add(d);
        }

        return Column(children: [
          // Ã–zet bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFF8F9FA),
            child: Row(children: [
              Text('${docs.length} belge', style: const TextStyle(fontWeight: FontWeight.bold, color: _navy)),
              const Spacer(),
              Text('${gruplar.length} kategori', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(child: ListView(
            padding: const EdgeInsets.all(16),
            children: gruplar.entries.map((e) {
              final kat = _kategoriRenk(_seciliKategori);
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, top: 4),
                  child: Row(children: [
                    Container(width: 3, height: 16, color: kat, margin: const EdgeInsets.only(right: 8)),
                    Text(e.key, style: TextStyle(fontWeight: FontWeight.bold, color: kat, fontSize: 13)),
                    const SizedBox(width: 8),
                    Text('${e.value.length} dosya', style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                  ]),
                ),
                ...e.value.map((d) => _EvrakKarti(doc: d, onPasif: _pasifYap, onIndir: _dosyaIndir)),
                const SizedBox(height: 12),
              ]);
            }).toList(),
          )),
        ]);
      },
    );
  }

  Color _kategoriRenk(String id) {
    final k = _kategoriler.where((k) => k.id == id);
    return k.isNotEmpty ? k.first.renk : _navy;
  }

  Future<void> _pasifYap(String id) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.archive_outlined, color: Colors.orange),
          SizedBox(width: 8),
          Text('Pasife Al'),
        ]),
        content: const Text(
            'Belge pasife alÄ±nacak. Kalici olarak silinmeyecek, '
                '"Pasifler" filtresinden eriÅŸebilirsiniz.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_, false), child: const Text('Ä°ptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(_, true),
            child: const Text('Pasife Al'),
          ),
        ],
      ),
    );
    if (onay == true) {
      await FirebaseFirestore.instance.collection('evraklar').doc(id).update({
        'aktif': false, 'pasifTarihi': FieldValue.serverTimestamp(),
      });
    }
  }

  void _dosyaIndir(Map<String, dynamic> data) {
    final base64 = data['base64'] as String?;
    if (base64 == null || !kIsWeb) return;
    try {
      // PDF indirme web'de desteklenmiyor - mobilde share kullan
      // final blob = html.Blob([base64]);
      // final url = html.Url.createObjectUrlFromBlob(blob);
      if (true) return; // Web PDF indir devre disi
      // ..click();
      // html.Url.revokeObjectUrl(url);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ä°ndirme hatasÄ±'), behavior: SnackBarBehavior.floating));
    }
  }
}

// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
// EVRAK KARTI
// â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•
class _EvrakKarti extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final Future<void> Function(String) onPasif;
  final void Function(Map<String, dynamic>) onIndir;

  const _EvrakKarti({required this.doc, required this.onPasif, required this.onIndir});

  IconData _uzantiIkon(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':  return Icons.picture_as_pdf_rounded;
      case 'jpg':
      case 'jpeg':
      case 'png':  return Icons.image_outlined;
      case 'xlsx':
      case 'xls':  return Icons.table_chart_outlined;
      case 'doc':
      case 'docx': return Icons.description_outlined;
      default:     return Icons.insert_drive_file_outlined;
    }
  }

  Color _uzantiRenk(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':  return Colors.red;
      case 'jpg':
      case 'jpeg':
      case 'png':  return Colors.blue;
      case 'xlsx':
      case 'xls':  return Colors.green;
      case 'doc':
      case 'docx': return Colors.indigo;
      default:     return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final data    = doc.data() as Map<String, dynamic>;
    final dosyaAd = data['dosyaAdi'] as String? ?? 'Dosya';
    final ext     = data['uzanti']   as String? ?? '';
    final boyut   = data['boyutKB']  as int? ?? 0;
    final iliski  = data['iliskiAd'] as String? ?? '';
    final kaynak  = data['kaynak']   as String? ?? 'manuel';
    final aktif   = data['aktif']    as bool? ?? true;
    final tarih   = data['olusturma'] is Timestamp
        ? (data['olusturma'] as Timestamp).toDate()
        : DateTime.now();
    final renk = _uzantiRenk(ext);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: aktif ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: aktif ? Colors.grey.shade200 : Colors.orange.shade200),
        boxShadow: aktif ? [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4)] : null,
      ),
      child: Row(children: [
        // Ä°kon
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
              color: renk.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(_uzantiIkon(ext), color: renk, size: 20),
        ),
        const SizedBox(width: 12),
        // Bilgiler
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(dosyaAd, style: TextStyle(
              fontWeight: FontWeight.w600, fontSize: 13,
              color: aktif ? Colors.black87 : Colors.grey)),
          Row(children: [
            if (iliski.isNotEmpty) ...[
              const Icon(Icons.link_rounded, size: 11, color: Colors.grey),
              const SizedBox(width: 3),
              Text(iliski, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(width: 8),
            ],
            Text('${boyut}KB', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(width: 8),
            Text('${tarih.day}.${tarih.month}.${tarih.year}',
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
            if (kaynak == 'otomatik') ...[
              const SizedBox(width: 8),
              const Icon(Icons.auto_awesome, size: 10, color: Colors.purple),
              const Text(' Otomatik', style: TextStyle(fontSize: 10, color: Colors.purple)),
            ],
          ]),
        ])),
        // Aksiyonlar
        if (!aktif)
          const Padding(padding: EdgeInsets.only(right: 8),
              child: Text('Pasif', style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold))),
        // Ä°ndir
        if (data['base64'] != null)
          IconButton(
            icon: const Icon(Icons.download_rounded, size: 18, color: Colors.blue),
            tooltip: 'Ä°ndir',
            onPressed: () => onIndir(data),
          ),
        // MenÃ¼
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, size: 16, color: Colors.grey),
          itemBuilder: (_) => [
            if (aktif) const PopupMenuItem(value: 'pasif', child: Row(children: [
              Icon(Icons.archive_outlined, size: 16, color: Colors.orange),
              SizedBox(width: 8), Text('Pasife Al'),
            ])),
            if (!aktif) const PopupMenuItem(value: 'aktif', child: Row(children: [
              Icon(Icons.unarchive_outlined, size: 16, color: Colors.green),
              SizedBox(width: 8), Text('Aktife Al'),
            ])),
          ],
          onSelected: (v) async {
            if (v == 'pasif') await onPasif(doc.id);
            if (v == 'aktif') await FirebaseFirestore.instance
                .collection('evraklar').doc(doc.id)
                .update({'aktif': true});
          },
        ),
      ]),
    );
  }
}

