// ╔══════════════════════════════════════════════════════════════╗
// ║  DOSYA: lib/screens/arsiv_screen.dart
// ║  Arşiv Sistemi — imzalanan sözleşmeler kalıcı
// ║  Durum: Taslak→OnayBekliyor→İmzalandı→İptal→Arşiv
// ╚══════════════════════════════════════════════════════════════╝
import 'package:flutter/material.dart';
import 'ai_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/session_service.dart';
import 'yardim_widget.dart';

class ArsivScreen extends StatefulWidget {
  const ArsivScreen({super.key});
  @override
  State<ArsivScreen> createState() => _ArsivScreenState();
}

class _ArsivScreenState extends State<ArsivScreen>
    with SingleTickerProviderStateMixin {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  late TabController _tab;
  String _firmaId = '';
  String _projeId  = '';
  String _projeAdi = '';
  String _arama   = '';
  final _aramaCtrl = TextEditingController();

  final List<_SozlesmeDurum> _durumlar = [
    _SozlesmeDurum('tumu',         'Tümü',            Icons.all_inclusive_rounded,      Colors.grey),
    _SozlesmeDurum('taslak',       'Taslak',          Icons.edit_outlined,              Colors.blueGrey),
    _SozlesmeDurum('onay_bekliyor','Onay Bekliyor',   Icons.hourglass_empty_rounded,    Colors.orange),
    _SozlesmeDurum('imzalandi',    'İmzalandı',       Icons.verified_outlined,          Colors.green),
    _SozlesmeDurum('iptal',        'İptal',           Icons.cancel_outlined,            Colors.red),
    _SozlesmeDurum('arsivlendi',   'Arşiv',           Icons.archive_outlined,           Colors.purple),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _durumlar.length, vsync: this);
    _yukle();
  }

  @override
  void dispose() { _tab.dispose(); _aramaCtrl.dispose(); super.dispose(); }

  Future<void> _yukle() async {
    _firmaId  = await SessionService.instance.firmaIdAl() ?? '';
    _projeId  = SessionService.instance.aktifProjeld  ?? '';
    _projeAdi = SessionService.instance.aktifProjeAdi ?? '';
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white,
        title: const Text('Arşiv', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
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
          tabs: _durumlar.map((d) => Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(d.ikon, size: 14),
              const SizedBox(width: 5),
              Text(d.label, style: const TextStyle(fontSize: 12)),
            ]),
          )).toList(),
        ),
      ),
      body: Column(children: [
        // Arama
        Container(
          color: Colors.white, padding: const EdgeInsets.all(14),
          child: TextField(
            controller: _aramaCtrl,
            onChanged: (v) => setState(() => _arama = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Öğrenci adı, veli adı ara...',
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
          ),
        ),

        Expanded(child: TabBarView(
          controller: _tab,
          children: _durumlar.map((d) => _buildListe(d.durum)).toList(),
        )),
      ]),
    );
  }

  Widget _buildListe(String durum) {
    if (_firmaId.isEmpty) return const Center(child: CircularProgressIndicator());

    var query = FirebaseFirestore.instance
        .collection('sozlesmeler')
        .where('firmaId', isEqualTo: _firmaId)
          .where('projeId', isEqualTo: _projeId);

    if (durum != 'tumu') {
      query = query.where('durum', isEqualTo: durum);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _navy));
        }

        var docs = snap.data?.docs ?? [];

        // Arama filtresi
        if (_arama.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final ogrenci = (data['ogrenciAd'] ?? '').toLowerCase();
            final veli    = (data['veliAd']    ?? '').toLowerCase();
            return ogrenci.contains(_arama) || veli.contains(_arama);
          }).toList();
        }

        if (docs.isEmpty) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.archive_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(durum == 'tumu' ? 'Henüz sözleşme yok' : 'Bu durumda sözleşme yok',
                style: const TextStyle(color: Colors.grey, fontSize: 15)),
          ]));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final id   = docs[i].id;
            return _SozlesmeKarti(
              id: id, data: data,
              onDurumDegistir: (yeniDurum) => _durumDegistir(id, yeniDurum),
            );
          },
        );
      },
    );
  }

  Future<void> _durumDegistir(String id, String yeniDurum) async {
    // Tamamen silme engellendi — sadece durum değişir
    await FirebaseFirestore.instance.collection('sozlesmeler').doc(id).update({
      'durum'      : yeniDurum,
      'updatedAt'  : FieldValue.serverTimestamp(),
      'durumGecmisi': FieldValue.arrayUnion([{
        'durum'   : yeniDurum,
        'tarih'   : Timestamp.now().toDate().toString(),
      }]),
    });
  }
}

// ── Sözleşme Kartı ────────────────────────────────────────────
class _SozlesmeKarti extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  final Function(String) onDurumDegistir;

  static const _navy = Color(0xFF1a3a6b);

  const _SozlesmeKarti({
    required this.id, required this.data,
    required this.onDurumDegistir,
  });

  Color _durumRenk(String? d) {
    switch (d) {
      case 'taslak':        return Colors.blueGrey;
      case 'onay_bekliyor': return Colors.orange;
      case 'imzalandi':     return Colors.green;
      case 'iptal':         return Colors.red;
      case 'arsivlendi':    return Colors.purple;
      default:              return Colors.grey;
    }
  }

  String _durumLabel(String? d) {
    switch (d) {
      case 'taslak':        return 'Taslak';
      case 'onay_bekliyor': return 'Onay Bekliyor';
      case 'imzalandi':     return 'İmzalandı';
      case 'iptal':         return 'İptal';
      case 'arsivlendi':    return 'Arşivlendi';
      default:              return 'Bilinmiyor';
    }
  }

  @override
  Widget build(BuildContext context) {
    final durum      = data['durum'] as String? ?? 'taslak';
    final ogrenciAd  = data['ogrenciAd'] ?? data['ogrenciAdi'] ?? '-';
    final veliAd     = data['veliAd']    ?? data['veliAdi']    ?? '-';
    final tarih      = data['olusturma'] is Timestamp
        ? (data['olusturma'] as Timestamp).toDate()
        : DateTime.now();
    final imzaTarih  = data['onayTarihi'] is Timestamp
        ? (data['onayTarihi'] as Timestamp).toDate()
        : null;
    final ucret      = data['ucret'] ?? data['hesaplananFiyat'];
    final renk       = _durumRenk(durum);
    final imzaVar    = data['imzaData'] != null || data['dijitalOnay'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                  color: renk.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.description_outlined, color: renk, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ogrenciAd, style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
              Text('Veli: $veliAd',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: renk.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(_durumLabel(durum),
                    style: TextStyle(color: renk, fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 4),
              Text('${tarih.day}.${tarih.month}.${tarih.year}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ]),
          ]),

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),

          Wrap(spacing: 10, children: [
            if (ucret != null)
              _bilgi(Icons.attach_money_outlined, '$ucret TL', Colors.blue),
            if (imzaVar)
              _bilgi(Icons.verified_user_outlined, 'İmzalı', Colors.green),
            if (imzaTarih != null)
              _bilgi(Icons.calendar_today_outlined,
                  '${imzaTarih.day}.${imzaTarih.month}.${imzaTarih.year}',
                  Colors.purple),
            if (data['ipAdresi'] != null)
              _bilgi(Icons.computer_outlined, data['ipAdresi'], Colors.grey),
          ]),

          const SizedBox(height: 10),

          // Aksiyonlar — KALICI SİLME YOK
          Row(children: [
            // PDF
            Expanded(child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              onPressed: () => _pdfGoster(context),
              icon: const Icon(Icons.picture_as_pdf_outlined,
                  size: 14, color: Colors.red),
              label: const Text('PDF', style: TextStyle(fontSize: 11)),
            )),
            const SizedBox(width: 6),

            // Durum değiştir — akıllı buton
            if (durum == 'onay_bekliyor')
              Expanded(child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
                onPressed: () => onDurumDegistir('imzalandi'),
                icon: const Icon(Icons.check_rounded, size: 14),
                label: const Text('Onayla', style: TextStyle(fontSize: 11)),
              ))
            else if (durum == 'imzalandi')
              Expanded(child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
                onPressed: () => onDurumDegistir('arsivlendi'),
                icon: const Icon(Icons.archive_outlined, size: 14),
                label: const Text('Arşivle', style: TextStyle(fontSize: 11)),
              ))
            else if (durum != 'arsivlendi' && durum != 'iptal')
              Expanded(child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8))),
                onPressed: () => _iptalOnay(context),
                icon: const Icon(Icons.cancel_outlined, size: 14),
                label: const Text('İptal', style: TextStyle(fontSize: 11)),
              ))
            else
              Expanded(child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('Kalıcı Arşiv',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              )),
          ]),
        ]),
      ),
    );
  }

  Widget _bilgi(IconData icon, String text, Color renk) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 12, color: renk),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 11, color: renk)),
    ],
  );

  void _pdfGoster(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('PDF hazırlanıyor...'),
        behavior: SnackBarBehavior.floating));
  }

  Future<void> _iptalOnay(BuildContext context) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sözleşmeyi İptal Et'),
        content: const Text(
            'Sözleşme iptal edilecek ancak sistemde görünmeye devam edecek. '
            'Tamamen gizlemek için daha sonra "Arşivle" butonunu kullanın.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(_, false),
              child: const Text('Vazgeç')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(_, true),
            child: const Text('İptal Et')),
        ],
      ),
    );
    if (onay == true) onDurumDegistir('iptal');
  }
}

class _SozlesmeDurum {
  final String durum, label;
  final IconData ikon;
  final Color renk;
  const _SozlesmeDurum(this.durum, this.label, this.ikon, this.renk);
}
