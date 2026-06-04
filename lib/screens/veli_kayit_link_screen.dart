import 'package:flutter/material.dart';
import 'yardim_widget.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/session_service.dart';

class VeliKayitLinkiScreen extends StatefulWidget {
  const VeliKayitLinkiScreen({super.key});

  @override
  State<VeliKayitLinkiScreen> createState() => _VeliKayitLinkiScreenState();
}

class _VeliKayitLinkiScreenState extends State<VeliKayitLinkiScreen> {
  static const String _baseUrl = 'https://servisim360-15b4a.web.app/kayit';

  final _mesajController = TextEditingController();

  List<Map<String, dynamic>> _projeler = [];
  Map<String, dynamic>? _seciliProje;
  bool _yukleniyor = true;
  bool _linkOlusturuluyor = false;
  List<Map<String, dynamic>> _mevcutLinkler = [];

  @override
  void initState() {
    super.initState();
    _verileriYukle();
  }

  Future<void> _verileriYukle() async {
    final firmaId = await SessionService.instance.firmaIdAl();
    if (firmaId == null) return;

    try {
      final projSnap = await FirebaseFirestore.instance
          .collection('firms')
          .doc(firmaId)
          .collection('projects')
          .where('durum', isEqualTo: 'aktif')
          .get();

      final linkSnap = await FirebaseFirestore.instance
          .collection('kayit_linkleri')
          .where('firmaId', isEqualTo: firmaId)
          .where('aktif', isEqualTo: true)
          .orderBy('olusturma', descending: true)
          .get();

      setState(() {
        _projeler = projSnap.docs.map((d) {
          return {'id': d.id, ...d.data()};
        }).toList();

        _mevcutLinkler = linkSnap.docs.map((d) {
          return {'id': d.id, ...d.data()};
        }).toList();

        _yukleniyor = false;
      });
    } catch (e) {
      setState(() => _yukleniyor = false);
    }
  }

  Future<void> _linkOlustur() async {
    if (_seciliProje == null) {
      _snackbar('Lutfen bir proje secin', Colors.orange);
      return;
    }

    setState(() => _linkOlusturuluyor = true);

    try {
      final firmaId = await SessionService.instance.firmaIdAl();
      final firmaAdi = await SessionService.instance.firmaAdiAl();

      final gecerlilikBitis = DateTime.now().add(const Duration(days: 7));

      final docRef = await FirebaseFirestore.instance
          .collection('kayit_linkleri')
          .add({
        'firmaId': firmaId,
        'firmaAdi': firmaAdi ?? '',
        'projeId': _seciliProje!['id'],
        'projeAdi': _seciliProje!['ad'] ?? _seciliProje!['adi'] ?? '',
        'ozelMesaj': _mesajController.text.trim(),
        'aktif': true,
        'kullanim': 0,
        'gecerlilikGun': 7,
        'gecerlilikBitis': Timestamp.fromDate(gecerlilikBitis),
        'olusturma': Timestamp.now(),
      });

      final yeniLink = {
        'id': docRef.id,
        'firmaId': firmaId,
        'firmaAdi': firmaAdi ?? '',
        'projeId': _seciliProje!['id'],
        'projeAdi': _seciliProje!['ad'] ?? _seciliProje!['adi'] ?? '',
        'ozelMesaj': _mesajController.text.trim(),
        'aktif': true,
        'kullanim': 0,
        'gecerlilikBitis': Timestamp.fromDate(gecerlilikBitis),
      };

      setState(() {
        _mevcutLinkler.insert(0, yeniLink);
        _linkOlusturuluyor = false;
        _seciliProje = null;
        _mesajController.clear();
      });

      _snackbar('Link olusturuldu!', Colors.green);
    } catch (e) {
      setState(() => _linkOlusturuluyor = false);
      _snackbar('Hata: $e', Colors.red);
    }
  }

  Future<void> _linkiDeaktifEt(String linkId) async {
    await FirebaseFirestore.instance
        .collection('kayit_linkleri')
        .doc(linkId)
        .update({'aktif': false});

    setState(() {
      _mevcutLinkler.removeWhere((l) => l['id'] == linkId);
    });
    _snackbar('Link devre disi birakildi', Colors.orange);
  }

  void _linkiKopyala(String linkId) {
    final url = '$_baseUrl?link=$linkId';
    Clipboard.setData(ClipboardData(text: url));
    _snackbar('Link kopyalandi!', const Color(0xFF1a3a6b));
  }

  String _whatsappMesaji(Map<String, dynamic> link) {
    final url = '$_baseUrl?link=${link['id']}';
    final firma = link['firmaAdi'] ?? '';
    final proje = link['projeAdi'] ?? '';
    final mesaj = link['ozelMesaj'] ?? '';
    return 'Sayin Velimiz,\n\n$firma - $proje icin Servisim360 uygulamasina kayit olmanizi rica ediyoruz.\n\n${mesaj.isNotEmpty ? '$mesaj\n\n' : ''}--- Kayit Adimlariniz ---\n\n1. Asagidaki linkten kayit formunu doldurun:\n$url\n\n2. Uygulamayi Play Store\'dan indirin:\nhttps://play.google.com/store/apps/details?id=com.servisim.servisim\n\n3. Kaydiniz onaylandiktan sonra e-posta ve sifrenizle giris yapabilirsiniz.\n\nServisim360 - Akilli Servis Yonetimi';
  }

  void _whatsappKopyala(Map<String, dynamic> link) {
    Clipboard.setData(ClipboardData(text: _whatsappMesaji(link)));
    _snackbar('WhatsApp mesaji kopyalandi!', const Color(0xFF25D366));
  }

  void _snackbar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text(
          'Veli Kayit Linki',
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1a3a6b),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildYeniLinkKarti(),
            const SizedBox(height: 24),
            if (_mevcutLinkler.isNotEmpty) ...[
              const Text(
                'Aktif Linkler',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0d1f3c),
                ),
              ),
              const SizedBox(height: 12),
              ..._mevcutLinkler.map(_buildLinkKarti),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildYeniLinkKarti() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4, height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8C00),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Yeni Kayit Linki Olustur',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0d1f3c),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          const Text(
            'Proje Sec',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0d1f3c),
            ),
          ),
          const SizedBox(height: 8),
          if (_projeler.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFFF8C00).withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFFFF8C00), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Aktif proje bulunamadi',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFF8C00),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: _projeler.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final proje = entry.value;
                  final isSelected = _seciliProje?['id'] == proje['id'];
                  final isLast = idx == _projeler.length - 1;

                  return GestureDetector(
                    onTap: () => setState(() => _seciliProje = proje),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF1a3a6b).withValues(alpha: 0.05)
                            : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: idx == 0
                              ? const Radius.circular(12)
                              : Radius.zero,
                          topRight: idx == 0
                              ? const Radius.circular(12)
                              : Radius.zero,
                          bottomLeft:
                          isLast ? const Radius.circular(12) : Radius.zero,
                          bottomRight:
                          isLast ? const Radius.circular(12) : Radius.zero,
                        ),
                        border: !isLast
                            ? Border(
                            bottom:
                            BorderSide(color: Colors.grey.shade100))
                            : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 20, height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF1a3a6b)
                                    : Colors.grey.shade300,
                                width: 2,
                              ),
                              color: isSelected
                                  ? const Color(0xFF1a3a6b)
                                  : Colors.transparent,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                size: 12, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              proje['ad'] ?? proje['adi'] ?? 'Proje',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? const Color(0xFF1a3a6b)
                                    : const Color(0xFF374151),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 16),

          const Text(
            'Ozel Mesaj (opsiyonel)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0d1f3c),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _mesajController,
            maxLines: 2,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'Ornek: Aziz Sancar Okulu icin...',
              hintStyle:
              TextStyle(color: Colors.grey.shade400, fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF1a3a6b)),
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _linkOlusturuluyor ? null : _linkOlustur,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8C00),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _linkOlusturuluyor
                  ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                  AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Text(
                'Link Olustur',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkKarti(Map<String, dynamic> link) {
    final linkId = link['id'] as String;
    final url = '$_baseUrl?link=$linkId';
    final projeAdi = link['projeAdi'] ?? '';
    final kullanim = link['kullanim'] ?? 0;
    final Timestamp? bitis = link['gecerlilikBitis'];
    String bitisStr = '';
    if (bitis != null) {
      final d = bitis.toDate();
      bitisStr = '${d.day}.${d.month}.${d.year}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFF1a3a6b),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.folder_outlined,
                    color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    projeAdi.isNotEmpty ? projeAdi : 'Proje',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$kullanim kayit',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.link,
                          size: 16, color: Color(0xFF6b7280)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          url,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6b7280),
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (bitisStr.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 14, color: Color(0xFF9ca3af)),
                      const SizedBox(width: 6),
                      Text(
                        'Gecerlilik: $bitisStr',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9ca3af),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _actionBtn(
                        icon: Icons.copy,
                        label: 'Linki Kopyala',
                        color: const Color(0xFF1a3a6b),
                        onTap: () => _linkiKopyala(linkId),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _actionBtn(
                        icon: Icons.chat,
                        label: 'WhatsApp',
                        color: const Color(0xFF25D366),
                        onTap: () => _whatsappKopyala(link),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _actionBtn(
                      icon: Icons.delete_outline,
                      label: '',
                      color: Colors.red.shade400,
                      onTap: () => _onaylaDeaktif(linkId),
                      small: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool small = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: small ? 12 : 10,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _onaylaDeaktif(String linkId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Linki Deaktif Et',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Bu link artik calismasin mi?'),
        actions: [
          YardimButonu(ekranAdi: 'Kayitlar'),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgec'),
          ),
          ElevatedButton(
            style:
            ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deaktif Et',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) _linkiDeaktifEt(linkId);
  }
}
