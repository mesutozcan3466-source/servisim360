import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

// ════════════════════════════════════════════════════════════════
//  VELi KAYIT LiNK EKRANI
//  - Kayit linki olustur ve paylas
//  - WhatsApp mesajina Play Store linki ekle
//  - Basvuru istatistigi
// ════════════════════════════════════════════════════════════════
class KayitLinkScreen extends StatefulWidget {
  const KayitLinkScreen({super.key});
  @override
  State<KayitLinkScreen> createState() => _KayitLinkScreenState();
}

class _KayitLinkScreenState extends State<KayitLinkScreen> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  // Play Store linki - yayinlaninca guncelle
  static const _playStoreLink =
      'https://play.google.com/store/apps/details?id=com.servisim.servisim';

  final _db = FirebaseFirestore.instance;
  String? _firmaId;
  String? _firmaAd;
  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await _db.collection('kullanicilar').doc(uid).get();
    final firmaId = doc.data()?['firmaId'] as String? ?? '';
    String firmaAd = '';
    if (firmaId.isNotEmpty) {
      // firms veya firmalar koleksiyonu
      var fd = await _db.collection('firms').doc(firmaId).get();
      if (!fd.exists) fd = await _db.collection('firmalar').doc(firmaId).get();
      firmaAd = fd.data()?['firmaAdi'] ?? fd.data()?['ad'] ?? '';
    }
    if (mounted) setState(() { _firmaId = firmaId; _firmaAd = firmaAd; _yukleniyor = false; });
  }

  String get _kayitLinki {
    if (_firmaId == null || _firmaId!.isEmpty) return '';
    return 'https://servisim360.app/kayit?firma=$_firmaId';
  }

  void _linkKopyala() {
    Clipboard.setData(ClipboardData(text: _kayitLinki));
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link kopyalandi!'), backgroundColor: Colors.green));
  }

  // Tek kisi WhatsApp
  Future<void> _whatsappTekKisi() async {
    final mesaj = _veliMesaji();
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(mesaj)}');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // Genel WhatsApp paylasimi
  Future<void> _whatsappGenel() async {
    final mesaj = _veliMesaji();
    final uri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(mesaj)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      final web = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(mesaj)}');
      if (await canLaunchUrl(web)) await launchUrl(web, mode: LaunchMode.externalApplication);
    }
  }

  String _veliMesaji() {
    return 'Sayin Velimiz,\n\n'
        '${_firmaAd ?? 'Okul Servisimiz'} icin Servisim360 uygulamasina '
        'kayit olmanizi rica ediyoruz.\n\n'
        '--- Kayit Adimlariniz ---\n\n'
        '1. Asagidaki linkten kayit formunu doldurun:\n'
        '$_kayitLinki\n\n'
        '2. Uygulamayi Play Store\'dan indirin:\n'
        '$_playStoreLink\n\n'
        '3. Kaydiniz onaylandiktan sonra\n'
        '   e-posta ve sifrenizle giris yapabilirsiniz.\n\n'
        'Servisim360 - Akilli Servis Yonetimi';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: _navy,
        title: const Text('Veli Kayit Linki', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(2),
            child: Container(color: _turuncu, height: 2)),
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Link karti
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_navy, Color(0xFF2a5298)]),
                borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.link, color: Colors.white, size: 24),
                SizedBox(width: 10),
                Text('Kayit Linki', style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 18)),
              ]),
              const SizedBox(height: 12),
              const Text('Bu linki velilerle paylasin. Veliler bu link uzerinden '
                  'kayit basvurusu yapabilir.',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Expanded(child: Text(_kayitLinki,
                      style: const TextStyle(color: Colors.white, fontSize: 12,
                          fontFamily: 'monospace'),
                      maxLines: 2, overflow: TextOverflow.ellipsis)),
                  IconButton(
                      icon: const Icon(Icons.copy, color: Colors.white70, size: 20),
                      onPressed: _linkKopyala),
                ]),
              ),

              // Play Store linki
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _turuncu.withValues(alpha: 0.5))),
                child: Row(children: [
                  const Icon(Icons.shop_outlined, color: _turuncu, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Play Store', style: TextStyle(color: _turuncu,
                        fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(_playStoreLink,
                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
                  GestureDetector(
                      onTap: () async {
                        await Clipboard.setData(const ClipboardData(text: _playStoreLink));
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Play Store linki kopyalandi!'),
                                backgroundColor: Colors.green));
                      },
                      child: const Icon(Icons.copy, color: Colors.white54, size: 16)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 24),

          // Mesaj onizleme
          const Text('WhatsApp Mesaj Onizleme',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _navy)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: const Color(0xFFDCF8C6),
                borderRadius: BorderRadius.circular(12)),
            child: Text(_veliMesaji(),
                style: const TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF1a1a1a))),
          ),
          const SizedBox(height: 20),

          // Paylasim butonlari
          const Text('Paylasim Secenekleri',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _navy)),
          const SizedBox(height: 12),
          _PaylasimButonu(icon: Icons.copy, label: 'Linki Kopyala',
              aciklama: 'Panoya kopyala', renk: _navy, onTap: _linkKopyala),
          const SizedBox(height: 10),
          _PaylasimButonu(icon: Icons.chat, label: 'WhatsApp ile Paylas',
              aciklama: 'Kisi sec veya gruba gonder', renk: const Color(0xFF25D366),
              onTap: _whatsappTekKisi),
          const SizedBox(height: 24),

          // Basvuru istatistigi
          const Text('Basvuru Durumu',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _navy)),
          const SizedBox(height: 12),
          if (_firmaId != null && _firmaId!.isNotEmpty)
            StreamBuilder<QuerySnapshot>(
              stream: _db.collection('parents')
                  .where('firmaId', isEqualTo: _firmaId).snapshots(),
              builder: (ctx, snap) {
                final docs = snap.data?.docs ?? [];
                final bekleyen = docs.where((d) => (d.data() as Map)['durum'] == 'beklemede').length;
                final onaylandi = docs.where((d) => (d.data() as Map)['durum'] == 'onayli').length;
                return Row(children: [
                  _IstatKarti(Icons.people, '${docs.length}', 'Toplam', Colors.blue),
                  const SizedBox(width: 10),
                  _IstatKarti(Icons.pending_actions, '$bekleyen', 'Bekleyen', Colors.orange),
                  const SizedBox(width: 10),
                  _IstatKarti(Icons.check_circle, '$onaylandi', 'Onayli', Colors.green),
                ]);
              },
            ),
          const SizedBox(height: 40),
        ]),
      ),
    );
  }
}

class _PaylasimButonu extends StatelessWidget {
  final IconData icon; final String label, aciklama; final Color renk; final VoidCallback onTap;
  const _PaylasimButonu({required this.icon, required this.label, required this.aciklama,
    required this.renk, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
      child: Container(padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)]),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: renk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: renk, size: 24)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              Text(aciklama, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ])),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
          ])));
}

class _IstatKarti extends StatelessWidget {
  final IconData icon; final String deger, label; final Color renk;
  const _IstatKarti(this.icon, this.deger, this.label, this.renk);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: renk.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Icon(icon, color: renk, size: 20),
        const SizedBox(height: 4),
        Text(deger, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: renk)),
        Text(label, style: TextStyle(fontSize: 10, color: renk)),
      ])));
}
