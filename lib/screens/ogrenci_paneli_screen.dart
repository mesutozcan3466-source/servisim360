import 'package:flutter/material.dart';
import 'yardim_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import '../services/session_service.dart';

// ════════════════════════════════════════════════════════════════
//  ÖĞRENCİ PANELİ — Tüm öğrenci bilgileri + hızlı arama + AI
//  Sekreter ve Admin için
//  Koleksiyon: students  |  parents
// ════════════════════════════════════════════════════════════════
class OgrenciPaneliScreen extends StatefulWidget {
  const OgrenciPaneliScreen({super.key});
  @override
  State<OgrenciPaneliScreen> createState() => _OgrenciPaneliScreenState();
}

class _OgrenciPaneliScreenState extends State<OgrenciPaneliScreen> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _orange  = Color(0xFFFF8C00);

  List<Map<String, dynamic>> _ogrenciler = [];
  List<Map<String, dynamic>> _soforler   = [];
  List<Map<String, dynamic>> _filtrelenmis = [];
  bool   _yukleniyor = true;
  String _firmaId    = '';
  String _projeId    = '';

  // Arama
  final _aramaCtrl = TextEditingController();
  Timer? _aramaTimer;

  // Sıralama + filtre
  String _siralama = 'ad';     // ad, servis, sinif, ucret
  String _filtre   = 'hepsi';  // hepsi, atanmis, atanamis

  @override
  void initState() {
    super.initState();
    _yukle();
    _aramaCtrl.addListener(_aramaGecikme);
  }

  @override
  void dispose() {
    _aramaCtrl.dispose();
    _aramaTimer?.cancel();
    super.dispose();
  }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    _firmaId = await SessionService.instance.firmaIdAl() ?? '';
    _projeId = SessionService.instance.aktifProjeId ?? '';
    try {
      // Şoförler
      final sSnap = await FirebaseFirestore.instance
          .collection('drivers').where('firmaId', isEqualTo: _firmaId).get();
      _soforler = sSnap.docs.map((d) => {'id': d.id, ...d.data()}).toList();

      // Öğrenciler
      var q = FirebaseFirestore.instance.collection('students').where('firmaId', isEqualTo: _firmaId);
      if (_projeId.isNotEmpty) q = q.where('projeId', isEqualTo: _projeId);
      final oSnap = await q.get();

      // Her öğrenci için veli bilgilerini birleştir
      final liste = <Map<String, dynamic>>[];
      for (final doc in oSnap.docs) {
        final data = {'id': doc.id, ...doc.data()};
        // Veli bilgisi ayrı koleksiyonda ise çek
        final veliId = data['veliId'] as String?;
        if (veliId != null && veliId.isNotEmpty) {
          try {
            final vDoc = await FirebaseFirestore.instance.collection('parents').doc(veliId).get();
            if (vDoc.exists) {
              final vData = vDoc.data()!;
              data['anneTel']   ??= vData['anneTel']   ?? vData['annetelefon']  ?? '';
              data['babaTel']   ??= vData['babaTel']   ?? vData['babatelefon']  ?? '';
              data['veliAd']    ??= '${vData['ad'] ?? ''} ${vData['soyad'] ?? ''}'.trim();
            }
          } catch (_) {}
        }
        liste.add(data);
      }
      _ogrenciler = liste;
      _filtrele();
    } catch (e) { debugPrint('OgrenciPaneli hata: $e'); }
    if (mounted) setState(() => _yukleniyor = false);
  }

  void _aramaGecikme() {
    _aramaTimer?.cancel();
    _aramaTimer = Timer(const Duration(milliseconds: 300), _filtrele);
  }

  void _filtrele() {
    final q = _aramaCtrl.text.toLowerCase().trim();
    var liste = List<Map<String, dynamic>>.from(_ogrenciler);

    // Filtre
    if (_filtre == 'atanmis')  liste = liste.where((o) => (o['surucuId'] ?? '').toString().isNotEmpty).toList();
    if (_filtre == 'atanamis') liste = liste.where((o) => (o['surucuId'] ?? '').toString().isEmpty).toList();

    // Arama
    if (q.isNotEmpty) {
      liste = liste.where((o) {
        final ad     = '${o['ad'] ?? ''} ${o['soyad'] ?? ''}'.toLowerCase();
        final tel    = (o['veliTel'] ?? o['telefon'] ?? '').toString();
        final adres  = (o['adres'] ?? '').toLowerCase();
        return ad.contains(q) || tel.contains(q) || adres.contains(q);
      }).toList();
    }

    // Sıralama
    liste.sort((a, b) {
      switch (_siralama) {
        case 'servis':
          return (a['surucuId'] ?? '').toString().compareTo((b['surucuId'] ?? '').toString());
        case 'sinif':
          return (a['sinif'] ?? '').toString().compareTo((b['sinif'] ?? '').toString());
        case 'ucret':
          final ua = (a['ucret'] ?? a['fiyat'] ?? 0) as num;
          final ub = (b['ucret'] ?? b['fiyat'] ?? 0) as num;
          return ub.compareTo(ua);
        default:
          return (a['ad'] ?? '').toString().compareTo((b['ad'] ?? '').toString());
      }
    });

    if (mounted) setState(() => _filtrelenmis = liste);
  }

  String _soforAd(String? surucuId) {
    if (surucuId == null || surucuId.isEmpty) return 'Atanmamis';
    final s = _soforler.firstWhere((s) => s['id'] == surucuId, orElse: () => {});
    return s.isNotEmpty ? '${s['ad'] ?? ''} — ${s['aracPlaka'] ?? ''}' : 'Bilinmiyor';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Öğrenci Paneli', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          Text('${_filtrelenmis.length} / ${_ogrenciler.length} öğrenci',
              style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ]),
        actions: [
          YardimButonu(ekranAdi: 'Veli Paneli'),
          IconButton(icon: const Icon(Icons.refresh_outlined), onPressed: _yukle),
        ],
      ),
      body: Column(children: [
        // ── ARAMA + FİLTRE ──
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Column(children: [
            // Hızlı arama
            TextField(
              controller: _aramaCtrl,
              decoration: InputDecoration(
                hintText: 'Ad, soyad, telefon veya adres ara...',
                prefixIcon: const Icon(Icons.search, color: _navy, size: 20),
                suffixIcon: _aramaCtrl.text.isNotEmpty
                    ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () { _aramaCtrl.clear(); _filtrele(); })
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true, fillColor: const Color(0xFFF5F7FA),
              ),
            ),
            const SizedBox(height: 8),
            // Filtre + Sıralama
            Row(children: [
              Expanded(child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _Chip('Hepsi', 'hepsi', _filtre, (v) => setState(() { _filtre = v; _filtrele(); })),
                  const SizedBox(width: 6),
                  _Chip('Servise Atanmis', 'atanmis', _filtre, (v) => setState(() { _filtre = v; _filtrele(); })),
                  const SizedBox(width: 6),
                  _Chip('Atanamis', 'atanamis', _filtre, (v) => setState(() { _filtre = v; _filtrele(); })),
                ]),
              )),
              const SizedBox(width: 8),
              // Sıralama dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: _navy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                  value: _siralama,
                  isDense: true,
                  icon: const Icon(Icons.sort, color: _navy, size: 16),
                  style: const TextStyle(color: _navy, fontSize: 11, fontWeight: FontWeight.w600),
                  items: const [
                    DropdownMenuItem(value: 'ad',     child: Text('A-Z')),
                    DropdownMenuItem(value: 'servis', child: Text('Servis')),
                    DropdownMenuItem(value: 'sinif',  child: Text('Sinif')),
                    DropdownMenuItem(value: 'ucret',  child: Text('Ucret')),
                  ],
                  onChanged: (v) => setState(() { _siralama = v!; _filtrele(); }),
                )),
              ),
            ]),
          ]),
        ),

        // ── LİSTE ──
        Expanded(
          child: _yukleniyor
              ? const Center(child: CircularProgressIndicator(color: _navy))
              : _filtrelenmis.isEmpty
              ? _bos()
              : ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
            itemCount: _filtrelenmis.length,
            itemBuilder: (_, i) => _OgrenciKarti(
              ogr:      _filtrelenmis[i],
              soforAd:  _soforAd(_filtrelenmis[i]['surucuId']),
              soforler: _soforler,
              onGuncelle: _yukle,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _bos() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.people_outline, size: 72, color: Colors.grey[300]),
    const SizedBox(height: 12),
    Text(_aramaCtrl.text.isNotEmpty ? 'Arama sonucu bulunamadi' : 'Henuz ogrenci eklenmemis',
        style: TextStyle(color: Colors.grey[500], fontSize: 14)),
  ]));
}

// ════════════════════════════════════════════════════════════════
//  ÖĞRENCİ KARTI — Tüm bilgiler + expand + şoför atama
// ════════════════════════════════════════════════════════════════
class _OgrenciKarti extends StatefulWidget {
  final Map<String, dynamic> ogr;
  final String soforAd;
  final List<Map<String, dynamic>> soforler;
  final VoidCallback onGuncelle;
  const _OgrenciKarti({required this.ogr, required this.soforAd, required this.soforler, required this.onGuncelle});
  @override
  State<_OgrenciKarti> createState() => _OgrenciKartiState();
}

class _OgrenciKartiState extends State<_OgrenciKarti> {
  static const _navy   = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);
  bool _acik = false;

  @override
  Widget build(BuildContext context) {
    final o = widget.ogr;
    final ad      = '${o['ad'] ?? ''} ${o['soyad'] ?? ''}'.trim();
    final sinif   = o['sinif']  ?? o['okul']   ?? '';
    final ucret   = o['ucret']  ?? o['fiyat']  ?? 0;
    final adres   = o['adres']  ?? o['panoAdres'] ?? '';
    final veliTel = o['veliTel'] ?? o['telefon'] ?? '';
    final anneTel = o['anneTel'] ?? '';
    final babaTel = o['babaTel'] ?? '';
    final servisAtanmis = (o['surucuId'] ?? '').toString().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
        border: Border.all(
            color: servisAtanmis ? Colors.green.withValues(alpha: 0.3) : Colors.orange.withValues(alpha: 0.3),
            width: 1.2),
      ),
      child: Column(children: [
        // Özet satırı
        GestureDetector(
          onTap: () => setState(() => _acik = !_acik),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: servisAtanmis
                    ? Colors.green.withValues(alpha: 0.12)
                    : Colors.orange.withValues(alpha: 0.12),
                child: Text(
                  ad.isNotEmpty ? ad[0].toUpperCase() : '?',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: servisAtanmis ? Colors.green : Colors.orange),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ad.isNotEmpty ? ad : 'Isimsiz',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(
                  '${sinif.isNotEmpty ? "$sinif • " : ""}${servisAtanmis ? widget.soforAd : "Servis Atanmamis"}',
                  style: TextStyle(
                      fontSize: 11,
                      color: servisAtanmis ? Colors.grey[600] : Colors.orange,
                      fontWeight: servisAtanmis ? FontWeight.normal : FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ])),
              // Ücret
              if ((ucret as num) > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: _navy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                  child: Text('${ucret.toStringAsFixed(0)} TL',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _navy)),
                ),
              const SizedBox(width: 4),
              Icon(_acik ? Icons.expand_less : Icons.expand_more, color: Colors.grey, size: 20),
            ]),
          ),
        ),

        // ── Detay (expand) ──
        if (_acik) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Bilgi satırları ──
              _BilgiSatiri(Icons.home_outlined, 'Adres', adres.isNotEmpty ? adres : '—'),
              if (veliTel.isNotEmpty) _BilgiSatiriTel(Icons.phone_outlined, 'Veli Tel', veliTel),
              if (anneTel.isNotEmpty) _BilgiSatiriTel(Icons.woman_outlined, 'Anne Tel', anneTel),
              if (babaTel.isNotEmpty) _BilgiSatiriTel(Icons.man_outlined,   'Baba Tel', babaTel),
              if (sinif.isNotEmpty)   _BilgiSatiri(Icons.school_outlined,   'Sinif', sinif),
              if ((ucret as num) > 0) _BilgiSatiri(Icons.attach_money_outlined, 'Ucret', '${ucret.toStringAsFixed(0)} TL / ay'),
              _BilgiSatiri(Icons.directions_bus_outlined, 'Servis', servisAtanmis ? widget.soforAd : 'Atanmamis'),

              const SizedBox(height: 10),

              // ── Butonlar ──
              Row(children: [
                Expanded(child: _AkBtn(
                  Icons.swap_horiz_outlined, 'Servis Ata', _navy,
                      () => _soforAtaDialog(context),
                )),
                const SizedBox(width: 8),
                if (veliTel.isNotEmpty)
                  Expanded(child: _AkBtn(
                    Icons.chat_outlined, 'WhatsApp', const Color(0xFF25D366),
                        () async {
                      final n = veliTel.replaceAll(RegExp(r'[^\d]'), '');
                      final url = Uri.parse('https://wa.me/90$n');
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    },
                  )),
                if (veliTel.isNotEmpty) const SizedBox(width: 8),
                if (veliTel.isNotEmpty)
                  Expanded(child: _AkBtn(
                    Icons.phone_outlined, 'Ara', Colors.green,
                        () async {
                      final url = Uri.parse('tel:$veliTel');
                      await launchUrl(url);
                    },
                  )),
              ]),
            ]),
          ),
        ],
      ]),
    );
  }

  // Şoför ata dialog
  void _soforAtaDialog(BuildContext context) {
    String? secili = widget.ogr['surucuId'] as String?;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Servis Ata — ${widget.ogr['ad'] ?? ''}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _navy)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String?>(
            value: secili?.isNotEmpty == true ? secili : null,
            decoration: InputDecoration(
              labelText: 'Sofor / Arac',
              prefixIcon: const Icon(Icons.directions_bus_outlined, color: _navy),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Atamayı Kaldir', style: TextStyle(color: Colors.red))),
              ...widget.soforler.map((s) => DropdownMenuItem(
                value: s['id'] as String,
                child: Text('${s['ad'] ?? 'Sofor'} — ${s['aracPlaka'] ?? ''}',
                    style: const TextStyle(fontSize: 13)),
              )),
            ],
            onChanged: (v) => setS(() => secili = v),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Iptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _navy),
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance.collection('students').doc(widget.ogr['id']).update({
                'surucuId': secili ?? '',
              });
              widget.onGuncelle();
            },
            child: const Text('Kaydet', style: TextStyle(color: Colors.white)),
          ),
        ],
      )),
    );
  }
}

// ── Yardımcı widget'lar ──
class _BilgiSatiri extends StatelessWidget {
  final IconData ikon; final String baslik, deger;
  static const _navy = Color(0xFF1a3a6b);
  const _BilgiSatiri(this.ikon, this.baslik, this.deger);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(ikon, color: _navy.withValues(alpha: 0.6), size: 15),
      const SizedBox(width: 8),
      SizedBox(width: 72, child: Text('$baslik:', style: TextStyle(fontSize: 11, color: Colors.grey[500]))),
      Expanded(child: Text(deger, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
    ]),
  );
}

class _BilgiSatiriTel extends StatelessWidget {
  final IconData ikon; final String baslik, tel;
  const _BilgiSatiriTel(this.ikon, this.baslik, this.tel);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(ikon, color: Colors.grey, size: 15),
      const SizedBox(width: 8),
      SizedBox(width: 72, child: Text('$baslik:', style: TextStyle(fontSize: 11, color: Colors.grey[500]))),
      Expanded(child: GestureDetector(
        onTap: () async { await launchUrl(Uri.parse('tel:$tel')); },
        child: Text(tel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue, decoration: TextDecoration.underline)),
      )),
    ]),
  );
}

class _AkBtn extends StatelessWidget {
  final IconData ikon; final String label; final Color color; final VoidCallback onTap;
  const _AkBtn(this.ikon, this.label, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(ikon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ]),
    ),
  );
}

class _Chip extends StatelessWidget {
  final String etiket, deger, secili; final ValueChanged<String> onSec;
  static const _navy = Color(0xFF1a3a6b);
  const _Chip(this.etiket, this.deger, this.secili, this.onSec);
  @override
  Widget build(BuildContext context) {
    final aktif = secili == deger;
    return GestureDetector(
      onTap: () => onSec(deger),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
            color: aktif ? _navy : Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
        child: Text(etiket, style: TextStyle(
            color: aktif ? Colors.white : Colors.grey[700],
            fontSize: 12, fontWeight: aktif ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }
}
