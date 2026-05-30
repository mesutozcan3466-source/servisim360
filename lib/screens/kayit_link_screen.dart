import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class KayitLinkScreen extends StatefulWidget {
  const KayitLinkScreen({super.key});

  @override
  State<KayitLinkScreen> createState() => _KayitLinkScreenState();
}

class _KayitLinkScreenState extends State<KayitLinkScreen> {
  static const Color navy = Color(0xFF1a3a6b);
  static const Color orange = Color(0xFFFF8C00);

  final _mesajController = TextEditingController();
  final _telefonController = TextEditingController();
  bool _yukleniyor = false;
  String? _olusturulanLink;
  String _secilenProjeId = '';
  String _secilenProjeAdi = '';
  List<Map<String, dynamic>> _projeler = [];
  String _firmaId = '';

  @override
  void initState() {
    super.initState();
    _firmaIdAl();
    _mesajController.text =
    'Sayin Velimiz, servis kayit islemleri baslamistir. '
        'Asagidaki link uzerinden kaydinizi tamamlayabilirsiniz.';
  }

  Future<void> _firmaIdAl() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('kullanicilar')
        .doc(uid)
        .get();
    final fid = snap.data()?['firmaId'] ?? '';
    setState(() => _firmaId = fid);
    await _projeleriYukle(fid);
  }

  Future<void> _projeleriYukle(String firmaId) async {
    if (firmaId.isEmpty) return;
    final snap = await FirebaseFirestore.instance
        .collection('projects')
        .where('firmaId', isEqualTo: firmaId)
        .get();
    setState(() {
      _projeler = snap.docs
          .map((d) => {'id': d.id, 'ad': d.data()['ad'] ?? d.id})
          .toList();
      if (_projeler.isNotEmpty) {
        _secilenProjeId = _projeler[0]['id'];
        _secilenProjeAdi = _projeler[0]['ad'];
      }
    });
  }

  String _linkOlustur(String linkId) {
    return 'https://servisim.org.tr/kayit/$linkId';
  }

  Future<void> _linkOlusturVeKaydet() async {
    if (_secilenProjeId.isEmpty) {
      _snack('Lutfen proje secin', hata: true);
      return;
    }
    setState(() => _yukleniyor = true);
    try {
      final ref = await FirebaseFirestore.instance
          .collection('kayit_linkleri')
          .add({
        'firmaId': _firmaId,
        'projeId': _secilenProjeId,
        'projeAdi': _secilenProjeAdi,
        'mesaj': _mesajController.text.trim(),
        'olusturmaTarihi': FieldValue.serverTimestamp(),
        'aktif': true,
        'kullanilmaSayisi': 0,
      });
      setState(() => _olusturulanLink = _linkOlustur(ref.id));
      _snack('Link olusturuldu!');
    } catch (e) {
      _snack('Hata: $e', hata: true);
    } finally {
      setState(() => _yukleniyor = false);
    }
  }

  void _linkKopyala() {
    if (_olusturulanLink == null) return;
    Clipboard.setData(ClipboardData(text: _olusturulanLink!));
    _snack('Kopyalandi!');
  }

  Future<void> _whatsappGonder() async {
    if (_olusturulanLink == null) return;
    final telefon = _telefonController.text.trim().replaceAll(' ', '');
    final mesaj = Uri.encodeComponent(
        '${_mesajController.text.trim()}\n\n$_olusturulanLink');
    final uri = telefon.isNotEmpty
        ? Uri.parse('https://wa.me/$telefon?text=$mesaj')
        : Uri.parse('https://wa.me/?text=$mesaj');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _smsGonder() async {
    if (_olusturulanLink == null) return;
    final telefon = _telefonController.text.trim().replaceAll(' ', '');
    final mesaj = Uri.encodeComponent(
        '${_mesajController.text.trim()}\n\n$_olusturulanLink');
    final uri = Uri.parse('sms:$telefon?body=$mesaj');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _snack(String mesaj, {bool hata = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(mesaj),
      backgroundColor: hata ? Colors.red : Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        title: const Text('Kayit Linki Olustur',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _baslik('Proje Sec'),
            const SizedBox(height: 8),
            _dropdown(),
            const SizedBox(height: 20),
            _baslik('Mesaj Icerigi'),
            const SizedBox(height: 8),
            _mesajAlani(),
            const SizedBox(height: 20),
            _baslik('Telefon (Opsiyonel - tek kisi icin)'),
            const SizedBox(height: 8),
            _telefonAlani(),
            const SizedBox(height: 24),
            _linkButon(),
            if (_olusturulanLink != null) ...[
              const SizedBox(height: 24),
              _linkKarti(),
              const SizedBox(height: 16),
              _aksiyonSatiri(),
            ],
            const SizedBox(height: 32),
            _gecmisLinkler(),
          ],
        ),
      ),
    );
  }

  Widget _dropdown() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _secilenProjeId.isEmpty ? null : _secilenProjeId,
        isExpanded: true,
        hint: const Text('Proje secin'),
        items: _projeler
            .map((p) => DropdownMenuItem<String>(
          value: p['id'],
          child: Text(p['ad']),
        ))
            .toList(),
        onChanged: (val) {
          if (val == null) return;
          final proje = _projeler.firstWhere((p) => p['id'] == val);
          setState(() {
            _secilenProjeId = val;
            _secilenProjeAdi = proje['ad'];
            _olusturulanLink = null;
          });
        },
      ),
    ),
  );

  Widget _mesajAlani() => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: TextField(
      controller: _mesajController,
      maxLines: 4,
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.all(16),
        border: InputBorder.none,
        hintText: 'Velilere gonderilecek mesaj...',
      ),
    ),
  );

  Widget _telefonAlani() => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: TextField(
      controller: _telefonController,
      keyboardType: TextInputType.phone,
      decoration: const InputDecoration(
        contentPadding:
        EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: InputBorder.none,
        hintText: '905xxxxxxxxx  (bos = toplu gonderim)',
        prefixIcon: Icon(Icons.phone, color: Colors.grey),
      ),
    ),
  );

  Widget _linkButon() => SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton.icon(
      onPressed: _yukleniyor ? null : _linkOlusturVeKaydet,
      icon: _yukleniyor
          ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
              color: Colors.white, strokeWidth: 2))
          : const Icon(Icons.link),
      label: Text(
        _yukleniyor ? 'Olusturuluyor...' : 'Link Olustur',
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );

  Widget _linkKarti() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.green.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.green.shade200),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Link Hazir!',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green)),
          ],
        ),
        const SizedBox(height: 8),
        Text(_olusturulanLink!,
            style:
            const TextStyle(fontSize: 13, color: Colors.blue)),
      ],
    ),
  );

  Widget _aksiyonSatiri() => Row(
    children: [
      Expanded(
          child: _aksiyonButon(
              ikon: Icons.copy,
              etiket: 'Kopyala',
              renk: navy,
              onTap: _linkKopyala)),
      const SizedBox(width: 10),
      Expanded(
          child: _aksiyonButon(
              ikon: Icons.chat,
              etiket: 'WhatsApp',
              renk: const Color(0xFF25D366),
              onTap: _whatsappGonder)),
      const SizedBox(width: 10),
      Expanded(
          child: _aksiyonButon(
              ikon: Icons.sms,
              etiket: 'SMS',
              renk: orange,
              onTap: _smsGonder)),
    ],
  );

  Widget _baslik(String text) => Text(text,
      style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF333333)));

  Widget _aksiyonButon({
    required IconData ikon,
    required String etiket,
    required Color renk,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: renk,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(ikon, color: Colors.white, size: 20),
              const SizedBox(height: 4),
              Text(etiket,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12)),
            ],
          ),
        ),
      );

  Widget _gecmisLinkler() {
    if (_firmaId.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _baslik('Gecmis Linkler'),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('kayit_linkleri')
              .where('firmaId', isEqualTo: _firmaId)
              .orderBy('olusturmaTarihi', descending: true)
              .limit(10)
              .snapshots(),
          builder: (ctx, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = snap.data!.docs;
            if (docs.isEmpty) {
              return const Text('Henuz link olusturulmadi.',
                  style: TextStyle(color: Colors.grey));
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final d = docs[i].data() as Map<String, dynamic>;
                final aktif = d['aktif'] ?? true;
                final kullanim = d['kullanilmaSayisi'] ?? 0;
                final link = _linkOlustur(docs[i].id);
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: aktif ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d['projeAdi'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            Text('$kullanim kez kullanildi',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: link));
                          _snack('Kopyalandi!');
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          aktif ? Icons.toggle_on : Icons.toggle_off,
                          color: aktif ? Colors.green : Colors.grey,
                          size: 28,
                        ),
                        onPressed: () =>
                            docs[i].reference.update({'aktif': !aktif}),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    _mesajController.dispose();
    _telefonController.dispose();
    super.dispose();
  }
}
