// ╔══════════════════════════════════════════════════════════════╗
// ║  DOSYA: lib/screens/proje_arsiv_screen.dart
// ║  Proje Dosya & Arşiv Merkezi
// ║  Öğrenci/Veli/Şoför sözleşmeleri, PDF, evraklar
// ╚══════════════════════════════════════════════════════════════╝
import 'package:flutter/material.dart';
import 'ai_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/session_service.dart';
import 'yardim_widget.dart';

class ProjeArsivScreen extends StatefulWidget {
  const ProjeArsivScreen({super.key});
  @override
  State<ProjeArsivScreen> createState() => _ProjeArsivScreenState();
}

class _ProjeArsivScreenState extends State<ProjeArsivScreen>
    with SingleTickerProviderStateMixin {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  late TabController _tab;
  String _firmaId = '';
  String _projeId = '';
  String _aramaMetni = '';
  bool _yukleniyor = false;
  final _aramaCtrl = TextEditingController();

  // Dosya kategorileri
  final _kategoriler = [
    _Kategori('tumu',          'Tümü',                Icons.folder_outlined,         Colors.grey),
    _Kategori('ogr_sozlesme',  'Öğrenci Sözleşmeleri',Icons.description_outlined,    Colors.blue),
    _Kategori('sofor_sozlesme','Şoför Sözleşmeleri',  Icons.directions_car_outlined,  _navy),
    _Kategori('pdf',           'PDF Belgeler',         Icons.picture_as_pdf_outlined, Colors.red),
    _Kategori('evrak',         'Evraklar',             Icons.insert_drive_file_outlined,Colors.green),
    _Kategori('diger',         'Diğer',                Icons.attach_file_outlined,    Colors.purple),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _kategoriler.length, vsync: this);
    _yukle();
  }

  @override
  void dispose() { _tab.dispose(); _aramaCtrl.dispose(); super.dispose(); }

  Future<void> _yukle() async {
    _firmaId = await SessionService.instance.firmaIdAl() ?? '';
    _projeId = SessionService.instance.aktifProjeId ?? '';
    if (mounted) setState(() {});
  }

  Future<void> _dosyaYukle(String kategori) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
      );
      if (result == null || result.files.isEmpty) return;

      final dosya = result.files.first;
      if (dosya.bytes == null) return;

      setState(() => _yukleniyor = true);

      final now = DateTime.now();
      final dosyaAdi = '${now.millisecondsSinceEpoch}_${dosya.name}';
      final ref = FirebaseStorage.instance
          .ref('arsiv/$_firmaId/$_projeId/$kategori/$dosyaAdi');

      await ref.putData(dosya.bytes!,
          SettableMetadata(contentType: _mimeType(dosya.extension ?? '')));
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('proje_arsiv').add({
        'firmaId'    : _firmaId,
        'projeId'    : _projeId,
        'kategori'   : kategori,
        'dosyaAdi'   : dosya.name,
        'dosyaYolu'  : ref.fullPath,
        'url'        : url,
        'boyut'      : dosya.size,
        'uzanti'     : dosya.extension ?? '',
        'olusturma'  : FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() => _yukleniyor = false);
        _snack('${dosya.name} yüklendi!', renk: Colors.green);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _yukleniyor = false);
        _snack('Hata: $e');
      }
    }
  }

  String _mimeType(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':  return 'application/pdf';
      case 'png':  return 'image/png';
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:     return 'application/octet-stream';
    }
  }

  void _snack(String m, {Color renk = Colors.red}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m), backgroundColor: renk,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
  }

  Future<void> _dosyaSil(String docId, String dosyaYolu) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Dosyayı Sil'),
        content: const Text('Bu dosya kalıcı olarak silinecek. Emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_, false),
              child: const Text('Vazgeç')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(_, true),
            child: const Text('Sil')),
        ],
      ),
    );
    if (onay != true) return;
    try {
      await FirebaseStorage.instance.ref(dosyaYolu).delete();
      await FirebaseFirestore.instance.collection('proje_arsiv').doc(docId).delete();
      _snack('Dosya silindi', renk: Colors.green);
    } catch (e) {
      _snack('Hata: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white,
        title: const Text('Proje Arşivi',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_yukleniyor)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))),
          AiAsistanButonu(ekranAdi: 'Arsiv'),
          YardimButonu(ekranAdi: 'Arsiv'),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: _turuncu,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: _kategoriler.map((k) => Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(k.ikon, size: 14),
              const SizedBox(width: 5),
              Text(k.label, style: const TextStyle(fontSize: 11)),
            ]),
          )).toList(),
        ),
      ),
      body: Column(children: [
        // Arama + Yükle
        Container(
          color: Colors.white, padding: const EdgeInsets.all(14),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _aramaCtrl,
              onChanged: (v) => setState(() => _aramaMetni = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Dosya adı ara...',
                prefixIcon: const Icon(Icons.search_rounded, color: _navy, size: 18),
                filled: true, fillColor: const Color(0xFFF5F7FA),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
                isDense: true,
              ),
            )),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _turuncu, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () {
                final kat = _kategoriler[_tab.index];
                _dosyaYukle(kat.kat == 'tumu' ? 'diger' : kat.kat);
              },
              icon: const Icon(Icons.upload_rounded, size: 16),
              label: const Text('Yükle',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          ]),
        ),

        // Özet istatistik
        if (_firmaId.isNotEmpty)
          _OzetSatir(firmaId: _firmaId, projeId: _projeId),

        // Dosya listesi
        Expanded(child: TabBarView(
          controller: _tab,
          children: _kategoriler.map((k) =>
              _DosyaListesi(
                firmaId: _firmaId,
                projeId: _projeId,
                kategori: k.kat,
                aramaMetni: _aramaMetni,
                onSil: _dosyaSil,
              )
          ).toList(),
        )),
      ]),
    );
  }
}

// ── Özet satır ────────────────────────────────────────────────
class _OzetSatir extends StatelessWidget {
  final String firmaId, projeId;
  const _OzetSatir({required this.firmaId, required this.projeId});

  @override
  Widget build(BuildContext context) {
    var query = FirebaseFirestore.instance
        .collection('proje_arsiv')
        .where('firmaId', isEqualTo: firmaId);
    if (projeId.isNotEmpty) query = query.where('projeId', isEqualTo: projeId);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        final toplamBoyut = docs.fold<int>(0,
            (sum, d) => sum + ((d.data() as Map)['boyut'] as int? ?? 0));
        final mb = (toplamBoyut / 1024 / 1024).toStringAsFixed(1);

        return Container(
          color: const Color(0xFFF5F7FA),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            const Icon(Icons.folder_outlined, size: 14, color: Color(0xFF1a3a6b)),
            const SizedBox(width: 6),
            Text('${docs.length} dosya • $mb MB',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF1a3a6b),
                    fontWeight: FontWeight.w600)),
          ]),
        );
      },
    );
  }
}

// ── Dosya listesi ─────────────────────────────────────────────
class _DosyaListesi extends StatelessWidget {
  final String firmaId, projeId, kategori, aramaMetni;
  final Function(String, String) onSil;

  static const _navy = Color(0xFF1a3a6b);

  const _DosyaListesi({
    required this.firmaId, required this.projeId,
    required this.kategori, required this.aramaMetni,
    required this.onSil,
  });

  IconData _dosyaIkon(String? ext) {
    switch ((ext ?? '').toLowerCase()) {
      case 'pdf':  return Icons.picture_as_pdf_outlined;
      case 'png':
      case 'jpg':
      case 'jpeg': return Icons.image_outlined;
      case 'docx':
      case 'doc':  return Icons.description_outlined;
      case 'xlsx':
      case 'xls':  return Icons.table_chart_outlined;
      default:     return Icons.insert_drive_file_outlined;
    }
  }

  Color _dosyaRenk(String? ext) {
    switch ((ext ?? '').toLowerCase()) {
      case 'pdf':  return Colors.red;
      case 'png':
      case 'jpg':
      case 'jpeg': return Colors.green;
      case 'docx':
      case 'doc':  return Colors.blue;
      case 'xlsx': return Colors.teal;
      default:     return Colors.grey;
    }
  }

  String _boyutStr(int? boyut) {
    if (boyut == null) return '';
    if (boyut < 1024) return '$boyut B';
    if (boyut < 1024 * 1024) return '${(boyut/1024).toStringAsFixed(0)} KB';
    return '${(boyut/1024/1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    if (firmaId.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    var query = FirebaseFirestore.instance
        .collection('proje_arsiv')
        .where('firmaId', isEqualTo: firmaId);

    if (projeId.isNotEmpty) {
      query = query.where('projeId', isEqualTo: projeId);
    }
    if (kategori != 'tumu') {
      query = query.where('kategori', isEqualTo: kategori);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _navy));
        }

        var docs = snap.data?.docs ?? [];

        if (aramaMetni.isNotEmpty) {
          docs = docs.where((d) {
            final ad = ((d.data() as Map)['dosyaAdi'] ?? '').toLowerCase();
            return ad.contains(aramaMetni);
          }).toList();
        }

        if (docs.isEmpty) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.folder_open_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            const Text('Henüz dosya yüklenmedi',
                style: TextStyle(color: Colors.grey, fontSize: 15)),
            const SizedBox(height: 8),
            const Text('Sağ üstteki "Yükle" butonunu kullanın',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ]));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final id   = docs[i].id;
            final ext  = data['uzanti'] as String? ?? '';
            final renk = _dosyaRenk(ext);
            final tarih = data['olusturma'] is Timestamp
                ? (data['olusturma'] as Timestamp).toDate()
                : DateTime.now();

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 1,
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: renk.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(_dosyaIkon(ext), color: renk, size: 22),
                ),
                title: Text(data['dosyaAdi'] ?? '-',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${_boyutStr(data['boyut'])}  •  '
                  '${tarih.day}.${tarih.month}.${tarih.year}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  // İndir
                  IconButton(
                    icon: const Icon(Icons.download_outlined,
                        color: Colors.blue, size: 20),
                    onPressed: () async {
                      final url = data['url'] as String?;
                      if (url != null) {
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      }
                    }),
                  // Sil
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red, size: 20),
                    onPressed: () => onSil(id, data['dosyaYolu'] ?? '')),
                ]),
              ),
            );
          },
        );
      },
    );
  }
}

class _Kategori {
  final String kat, label;
  final IconData ikon;
  final Color renk;
  const _Kategori(this.kat, this.label, this.ikon, this.renk);
}
