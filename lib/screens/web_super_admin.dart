import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

const Color _saNavy   = Color(0xFF1a3a6b);
const Color _saOrange = Color(0xFFFF8C00);

// ═══════════════════════════════════════════════════════
class WebSuperAdminSayfasi extends StatefulWidget {
  const WebSuperAdminSayfasi({super.key});
  @override
  State<WebSuperAdminSayfasi> createState() => _WebSuperAdminSayfasiState();
}
class _WebSuperAdminSayfasiState extends State<WebSuperAdminSayfasi> {
  int _menu = 0;
  bool _sidebar = true;
  static const _menuler = [
    {'ikon': Icons.bar_chart_outlined,     'etiket': 'Istatistikler'},
    {'ikon': Icons.business_outlined,      'etiket': 'Firmalar'},
    {'ikon': Icons.verified_user_outlined, 'etiket': 'Lisanslar'},
    {'ikon': Icons.map_outlined,           'etiket': 'Global Harita'},
    {'ikon': Icons.people_outline,         'etiket': 'Kullanicilar'},
    {'ikon': Icons.settings_outlined,      'etiket': 'Sistem'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: _sidebar ? 230 : 64,
          child: Container(
            color: _saNavy,
            child: Column(children: [
              Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: _saOrange, borderRadius: BorderRadius.circular(10)),
                    child: const Center(child: Text('S', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20))),
                  ),
                  if (_sidebar) ...[
                    const SizedBox(width: 10),
                    const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('Servisim360', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('Super Admin', style: TextStyle(color: Colors.amber, fontSize: 11)),
                    ]),
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
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        padding: EdgeInsets.symmetric(horizontal: _sidebar ? 12 : 8, vertical: 11),
                        decoration: BoxDecoration(
                          color: aktif ? _saOrange : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(children: [
                          Icon(_menuler[i]['ikon'] as IconData,
                              color: aktif ? Colors.white : Colors.white60, size: 19),
                          if (_sidebar) ...[
                            const SizedBox(width: 10),
                            Text(_menuler[i]['etiket'] as String,
                                style: TextStyle(
                                    color: aktif ? Colors.white : Colors.white70,
                                    fontWeight: aktif ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 13)),
                          ],
                        ]),
                      ),
                    );
                  },
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              InkWell(
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  if (mounted) Navigator.pushReplacementNamed(context, '/login');
                },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    const Icon(Icons.logout_outlined, color: Colors.white54, size: 18),
                    if (_sidebar) ...[const SizedBox(width: 8), const Text('Cikis Yap', style: TextStyle(color: Colors.white54, fontSize: 12))],
                  ]),
                ),
              ),
            ]),
          ),
        ),
        Expanded(child: Column(children: [
          Container(
            height: 60, color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              IconButton(
                icon: Icon(_sidebar ? Icons.menu_open : Icons.menu, color: _saNavy),
                onPressed: () => setState(() => _sidebar = !_sidebar),
              ),
              const SizedBox(width: 8),
              Text(_menuler[_menu]['etiket'] as String,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _saNavy)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: const Row(children: [
                  Icon(Icons.shield_outlined, size: 14, color: Colors.amber),
                  SizedBox(width: 6),
                  Text('Super Admin', style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                ]),
              ),
              const SizedBox(width: 12),
            ]),
          ),
          Expanded(child: _sayfaAl()),
        ])),
      ]),
    );
  }

  Widget _sayfaAl() {
    switch (_menu) {
      case 0: return const WebSuperAdminIstatistik();
      case 1: return const WebSuperAdminFirmalar();
      case 2: return const WebSuperAdminLisanslar();
      case 3: return const WebSuperAdminHarita();
      case 4: return const WebSuperAdminKullanicilar();
      case 5: return const _SaSistem();
      default: return const WebSuperAdminIstatistik();
    }
  }
}

// ═══════════════════════════════════════════════════════
//  İSTATİSTİKLER
// ═══════════════════════════════════════════════════════
class WebSuperAdminIstatistik extends StatefulWidget {
  const WebSuperAdminIstatistik({super.key});
  @override
  State<WebSuperAdminIstatistik> createState() => _WebSuperAdminIstatistikState();
}
class _WebSuperAdminIstatistikState extends State<WebSuperAdminIstatistik> {
  Map<String, int> _sayilar = {};
  bool _yukleniyor = true;

  @override
  void initState() { super.initState(); _yukle(); }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final r = await Future.wait([
        FirebaseFirestore.instance.collection('firms').count().get(),
        FirebaseFirestore.instance.collection('firms').where('durum', isEqualTo: 'aktif').count().get(),
        FirebaseFirestore.instance.collection('drivers').count().get(),
        FirebaseFirestore.instance.collection('drivers').where('servisAktif', isEqualTo: true).count().get(),
        FirebaseFirestore.instance.collection('parents').count().get(),
        FirebaseFirestore.instance.collection('students').count().get(),
        FirebaseFirestore.instance.collection('licenses').count().get(),
      ]);
      setState(() {
        _sayilar = {
          'Toplam Firma': r[0].count ?? 0,
          'Aktif Firma': r[1].count ?? 0,
          'Toplam Sofor': r[2].count ?? 0,
          'Aktif Servis': r[3].count ?? 0,
          'Toplam Veli': r[4].count ?? 0,
          'Toplam Ogrenci': r[5].count ?? 0,
          'Toplam Lisans': r[6].count ?? 0,
        };
        _yukleniyor = false;
      });
    } catch (_) {
      setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ikonlar = [Icons.business, Icons.check_circle, Icons.directions_bus, Icons.location_on, Icons.family_restroom, Icons.school, Icons.verified_user];
    final renkler = [Colors.blue, Colors.green, Colors.orange, Colors.red, Colors.purple, Colors.teal, Colors.amber];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Genel Bakis', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _saNavy)),
          const Spacer(),
          TextButton.icon(onPressed: _yukle, icon: const Icon(Icons.refresh, size: 16), label: const Text('Yenile')),
        ]),
        const SizedBox(height: 20),
        if (_yukleniyor)
          const Center(child: CircularProgressIndicator())
        else
          Wrap(
            spacing: 16, runSpacing: 16,
            children: _sayilar.entries.toList().asMap().entries.map((e) {
              final i = e.key;
              final entry = e.value;
              return Container(
                width: 160,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: renkler[i % renkler.length].withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(ikonlar[i % ikonlar.length], color: renkler[i % renkler.length], size: 22),
                  ),
                  const SizedBox(height: 12),
                  Text('${entry.value}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: renkler[i % renkler.length])),
                  const SizedBox(height: 4),
                  Text(entry.key, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ]),
              );
            }).toList(),
          ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  FİRMALAR
// ═══════════════════════════════════════════════════════
class WebSuperAdminFirmalar extends StatefulWidget {
  const WebSuperAdminFirmalar({super.key});
  @override
  State<WebSuperAdminFirmalar> createState() => _WebSuperAdminFirmalarState();
}
class _WebSuperAdminFirmalarState extends State<WebSuperAdminFirmalar> {
  List<Map<String, dynamic>> _firmalar = [];
  List<Map<String, dynamic>> _filtrelenmis = [];
  bool _yukleniyor = true;
  final _araCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _yukle(); }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('firms')
          .orderBy('kayitTarihi', descending: true).get();
      _firmalar = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      _filtrelenmis = List.from(_firmalar);
    } catch (_) {}
    setState(() => _yukleniyor = false);
  }

  void _ara(String q) {
    setState(() {
      _filtrelenmis = _firmalar.where((f) =>
      (f['firmaAdi'] ?? f['ad'] ?? '').toString().toLowerCase().contains(q.toLowerCase()) ||
          (f['email'] ?? '').toString().toLowerCase().contains(q.toLowerCase())).toList();
    });
  }

  Future<void> _durumDegistir(String id, String durum) async {
    await FirebaseFirestore.instance.collection('firms').doc(id).update({'durum': durum});
    _yukle();
  }

  Future<void> _sil(String id, String ad) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Firmay Sil'),
        content: Text('"$ad" silinecek. Emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Iptal')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sil', style: TextStyle(color: Colors.white))),
        ],
      ),
    );
    if (onay == true) {
      await FirebaseFirestore.instance.collection('firms').doc(id).delete();
      _yukle();
    }
  }

  Future<void> _whatsappGonder(String tel, String firmaAd, String email, String sifre) async {
    final n = tel.replaceAll(RegExp(r'\D'), '');
    final mesaj = Uri.encodeComponent(
        'Servisim360 Hosgeldiniz!\n\nFirma: $firmaAd\nKullanici: $email\nSifre: $sifre\n\nGiris: https://servis360-15b4a.web.app\n\nServisim360 - Akilli Servis Yonetim Sistemi');
    final url = Uri.parse('https://wa.me/90$n?text=$mesaj');
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Widget _tf(TextEditingController c, String label, IconData ikon,
      {TextInputType keyboard = TextInputType.text, bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c, keyboardType: keyboard, obscureText: obscure,
        decoration: InputDecoration(
          labelText: label, prefixIcon: Icon(ikon, size: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  void _firmaDialog(String? firmaId, Map<String, dynamic>? mevcut) {
    final adCtrl = TextEditingController(text: mevcut?['firmaAdi'] ?? mevcut?['ad'] ?? '');
    final sahipCtrl = TextEditingController(text: mevcut?['sahipAd'] ?? '');
    final telCtrl = TextEditingController(text: mevcut?['telefon'] ?? '');
    final emailCtrl = TextEditingController(text: mevcut?['email'] ?? '');
    final adresCtrl = TextEditingController(text: mevcut?['adres'] ?? '');
    final sifreCtrl = TextEditingController();
    String sureTip = '1_yil';
    bool suresiz = false;
    bool whatsappGonder = true;
    final sureler = {'1_ay': '1 Ay', '3_ay': '3 Ay', '6_ay': '6 Ay', '1_yil': '1 Yil', '2_yil': '2 Yil', '3_yil': '3 Yil', '5_yil': '5 Yil', 'suresiz': 'Suresiz'};

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(firmaId == null ? 'Yeni Firma Ekle' : 'Firma Duzenle',
              style: const TextStyle(color: _saNavy, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _tf(adCtrl, 'Firma Adi *', Icons.business_outlined),
                _tf(sahipCtrl, 'Sahip Ad Soyad *', Icons.person_outlined),
                _tf(telCtrl, 'Telefon *', Icons.phone_outlined, keyboard: TextInputType.phone),
                _tf(emailCtrl, 'E-posta *', Icons.email_outlined, keyboard: TextInputType.emailAddress),
                _tf(adresCtrl, 'Adres', Icons.location_on_outlined),
                if (firmaId == null) ...[
                  _tf(sifreCtrl, 'Giris Sifresi *', Icons.lock_outlined, obscure: true),
                  const SizedBox(height: 12),
                  const Align(alignment: Alignment.centerLeft,
                      child: Text('Lisans Suresi', style: TextStyle(fontWeight: FontWeight.w600, color: _saNavy))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: sureler.entries.map((e) {
                      final sec = sureTip == e.key;
                      return GestureDetector(
                        onTap: () => setD(() { sureTip = e.key; suresiz = e.key == 'suresiz'; }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: sec ? _saNavy : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: sec ? _saNavy : Colors.grey.shade300),
                          ),
                          child: Text(e.value, style: TextStyle(
                              color: sec ? Colors.white : Colors.black87,
                              fontWeight: sec ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Checkbox(value: whatsappGonder, onChanged: (v) => setD(() => whatsappGonder = v ?? true), activeColor: _saNavy),
                    const Text('Onay sonrasi WhatsApp ile bildirim gonder'),
                  ]),
                ],
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Iptal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _saNavy),
              onPressed: () async {
                if (adCtrl.text.isEmpty || emailCtrl.text.isEmpty) return;
                final veri = {
                  'firmaAdi': adCtrl.text.trim(), 'ad': adCtrl.text.trim(),
                  'sahipAd': sahipCtrl.text.trim(), 'telefon': telCtrl.text.trim(),
                  'email': emailCtrl.text.trim(), 'adres': adresCtrl.text.trim(),
                  'durum': mevcut?['durum'] ?? 'beklemede',
                  'guncelleme': FieldValue.serverTimestamp(),
                };
                if (firmaId == null) {
                  veri['kayitTarihi'] = FieldValue.serverTimestamp();
                  final ref = await FirebaseFirestore.instance.collection('firms').add(veri);
                  final gun = {'1_ay': 30, '3_ay': 90, '6_ay': 180, '1_yil': 365, '2_yil': 730, '3_yil': 1095, '5_yil': 1825};
                  final bitis = suresiz ? null : DateTime.now().add(Duration(days: gun[sureTip] ?? 365));
                  await FirebaseFirestore.instance.collection('licenses').add({
                    'firmaId': ref.id, 'sureTip': sureTip, 'suresiz': suresiz,
                    'baslangic': Timestamp.now(),
                    'bitis': bitis != null ? Timestamp.fromDate(bitis) : null,
                    'durum': 'aktif', 'olusturmaTarihi': FieldValue.serverTimestamp(),
                  });
                  await ref.update({'lisansDurum': 'aktif', 'lisansBitis': bitis != null ? Timestamp.fromDate(bitis) : null});
                  if (sifreCtrl.text.isNotEmpty) {
                    try {
                      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                          email: emailCtrl.text.trim(), password: sifreCtrl.text.trim());
                      final uid = cred.user?.uid;
                      if (uid != null) {
                        await FirebaseFirestore.instance.collection('kullanicilar').doc(uid).set({
                          'email': emailCtrl.text.trim(), 'rol': 'firmaAdmin',
                          'firmaId': ref.id, 'ad': sahipCtrl.text.trim(),
                          'kayitTarihi': FieldValue.serverTimestamp(),
                        });
                        await ref.update({'adminUid': uid});
                      }
                      if (whatsappGonder && telCtrl.text.isNotEmpty) {
                        await _whatsappGonder(telCtrl.text, adCtrl.text, emailCtrl.text, sifreCtrl.text);
                      }
                    } catch (e) { debugPrint('Auth: $e'); }
                  }
                } else {
                  await FirebaseFirestore.instance.collection('firms').doc(firmaId).update(veri);
                }
                if (mounted) Navigator.pop(context);
                _yukle();
              },
              child: Text(firmaId == null ? 'Ekle ve Bildir' : 'Kaydet', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _lisansUzatDialog(String firmaId, String firmaAd) {
    String sureTip = '1_yil';
    bool suresiz = false;
    final sureler = {'1_ay': '1 Ay', '3_ay': '3 Ay', '6_ay': '6 Ay', '1_yil': '1 Yil', '2_yil': '2 Yil', '3_yil': '3 Yil', '5_yil': '5 Yil', 'suresiz': 'Suresiz'};
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Lisans Uzat — $firmaAd', style: const TextStyle(color: _saNavy, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 400,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Yeni lisans suresi secin:', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: sureler.entries.map((e) {
                  final sec = sureTip == e.key;
                  return GestureDetector(
                    onTap: () => setD(() { sureTip = e.key; suresiz = e.key == 'suresiz'; }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: sec ? _saNavy : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: sec ? _saNavy : Colors.grey.shade300),
                      ),
                      child: Text(e.value, style: TextStyle(
                          color: sec ? Colors.white : Colors.black87, fontSize: 12)),
                    ),
                  );
                }).toList(),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Iptal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _saNavy),
              onPressed: () async {
                final gun = {'1_ay': 30, '3_ay': 90, '6_ay': 180, '1_yil': 365, '2_yil': 730, '3_yil': 1095, '5_yil': 1825};
                final bitis = suresiz ? null : DateTime.now().add(Duration(days: gun[sureTip] ?? 365));
                await FirebaseFirestore.instance.collection('licenses').add({
                  'firmaId': firmaId, 'sureTip': sureTip, 'suresiz': suresiz,
                  'baslangic': Timestamp.now(),
                  'bitis': bitis != null ? Timestamp.fromDate(bitis) : null,
                  'durum': 'aktif', 'olusturmaTarihi': FieldValue.serverTimestamp(),
                });
                await FirebaseFirestore.instance.collection('firms').doc(firmaId).update({
                  'lisansDurum': 'aktif',
                  'lisansBitis': bitis != null ? Timestamp.fromDate(bitis) : null,
                });
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Lisans uzatildi!'), backgroundColor: Colors.green));
                }
                _yukle();
              },
              child: const Text('Uzat', style: TextStyle(color: Colors.white)),
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
          const Text('Firmalar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _saNavy)),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: _saNavy, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => _firmaDialog(null, null),
            icon: const Icon(Icons.add, size: 18), label: const Text('Firma Ekle'),
          ),
        ]),
        const SizedBox(height: 16),
        TextField(
          controller: _araCtrl, onChanged: _ara,
          decoration: InputDecoration(
            hintText: 'Firma ara...', prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true, fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 16),
        if (_yukleniyor)
          const Center(child: CircularProgressIndicator())
        else
          Expanded(
            child: ListView.separated(
              itemCount: _filtrelenmis.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final f = _filtrelenmis[i];
                final ad = f['firmaAdi'] ?? f['ad'] ?? 'Firma';
                final durum = f['durum'] ?? 'beklemede';
                final dRenk = durum == 'aktif' ? Colors.green : durum == 'askida' ? Colors.orange : Colors.grey;
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
                  ),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 22, backgroundColor: _saNavy.withValues(alpha: 0.1),
                      child: Text(ad.isNotEmpty ? ad[0].toUpperCase() : 'F',
                          style: const TextStyle(color: _saNavy, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(ad, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(f['email'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      if (f['telefon'] != null) Text(f['telefon'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      if (f['sahipAd'] != null) Text(f['sahipAd'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      if (f['lisansBitis'] != null) Builder(builder: (_) {
                        final dt = (f['lisansBitis'] as Timestamp).toDate();
                        final kalan = dt.difference(DateTime.now()).inDays;
                        return Text('Lisans: ${dt.day}.${dt.month}.${dt.year} ($kalan gun)',
                            style: TextStyle(color: kalan < 30 ? Colors.red : Colors.green, fontSize: 11, fontWeight: FontWeight.w600));
                      }),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: dRenk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                      child: Text(durum, style: TextStyle(color: dRenk, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                      onSelected: (v) {
                        if (v == 'aktif' || v == 'askida' || v == 'beklemede') _durumDegistir(f['id'], v);
                        else if (v == 'duzenle') _firmaDialog(f['id'], f);
                        else if (v == 'sil') _sil(f['id'], ad);
                        else if (v == 'lisans') _lisansUzatDialog(f['id'], ad);
                        else if (v == 'whatsapp') {
                          final tel = f['telefon'] ?? '';
                          if (tel.isNotEmpty) _whatsappGonder(tel, ad, f['email'] ?? '', '[Sifreniz]');
                        }
                      },
                      itemBuilder: (_) => [
                        if (durum != 'aktif') const PopupMenuItem(value: 'aktif', child: Row(children: [Icon(Icons.check_circle, color: Colors.green, size: 18), SizedBox(width: 8), Text('Onayla')])),
                        if (durum != 'askida') const PopupMenuItem(value: 'askida', child: Row(children: [Icon(Icons.pause_circle, color: Colors.orange, size: 18), SizedBox(width: 8), Text('Askiya Al')])),
                        const PopupMenuItem(value: 'lisans', child: Row(children: [Icon(Icons.timer_outlined, color: Colors.blue, size: 18), SizedBox(width: 8), Text('Lisans Uzat')])),
                        const PopupMenuItem(value: 'whatsapp', child: Row(children: [Icon(Icons.chat, color: Color(0xFF25D366), size: 18), SizedBox(width: 8), Text('WhatsApp Gonder')])),
                        const PopupMenuItem(value: 'duzenle', child: Row(children: [Icon(Icons.edit_outlined, color: Colors.blue, size: 18), SizedBox(width: 8), Text('Duzenle')])),
                        const PopupMenuItem(value: 'sil', child: Row(children: [Icon(Icons.delete_outline, color: Colors.red, size: 18), SizedBox(width: 8), Text('Sil', style: TextStyle(color: Colors.red))])),
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

// ═══════════════════════════════════════════════════════
//  LİSANSLAR
// ═══════════════════════════════════════════════════════
class WebSuperAdminLisanslar extends StatefulWidget {
  const WebSuperAdminLisanslar({super.key});
  @override
  State<WebSuperAdminLisanslar> createState() => _WebSuperAdminLisanslarState();
}
class _WebSuperAdminLisanslarState extends State<WebSuperAdminLisanslar> {
  List<Map<String, dynamic>> _lisanslar = [];
  bool _yukleniyor = true;

  @override
  void initState() { super.initState(); _yukle(); }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final snap = await FirebaseFirestore.instance.collection('licenses')
          .orderBy('olusturmaTarihi', descending: true).get();
      _lisanslar = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (_) {}
    setState(() => _yukleniyor = false);
  }

  String _sureBicim(Map<String, dynamic> l) {
    if (l['suresiz'] == true) return 'Suresiz';
    final b = l['bitis'];
    if (b == null) return '-';
    final dt = (b as Timestamp).toDate();
    final kalan = dt.difference(DateTime.now()).inDays;
    return '${dt.day}.${dt.month}.${dt.year} (${kalan > 0 ? "$kalan gun kaldi" : "Suresi doldu"})';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Lisans Yonetimi', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _saNavy)),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: _saNavy, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {}, // Firmalar üzerinden yönetilir
            icon: const Icon(Icons.info_outline, size: 18),
            label: const Text('Lisanslar Firmalar uzerinden yonetilir'),
          ),
        ]),
        const SizedBox(height: 16),
        if (_yukleniyor)
          const Center(child: CircularProgressIndicator())
        else if (_lisanslar.isEmpty)
          Center(child: Padding(padding: const EdgeInsets.all(40),
              child: Text('Henuz lisans yok', style: TextStyle(color: Colors.grey[400]))))
        else
          Expanded(
            child: ListView.separated(
              itemCount: _lisanslar.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final l = _lisanslar[i];
                final durum = l['durum'] ?? 'aktif';
                final dRenk = durum == 'aktif' ? Colors.green : Colors.red;
                final suresiz = l['suresiz'] == true;
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: dRenk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: Icon(suresiz ? Icons.all_inclusive : Icons.timer_outlined, color: dRenk, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Firma: ${l['firmaId'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(_sureBicim(l), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      Text('Sure: ${l['sureTip'] ?? '-'}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: dRenk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                      child: Text(durum, style: TextStyle(color: dRenk, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.grey),
                      onSelected: (v) {
                        if (v == 'sil') { FirebaseFirestore.instance.collection('licenses').doc(l['id']).delete(); _yukle(); }
                        if (v == 'askida') { FirebaseFirestore.instance.collection('licenses').doc(l['id']).update({'durum': 'askida'}); _yukle(); }
                        if (v == 'aktif') { FirebaseFirestore.instance.collection('licenses').doc(l['id']).update({'durum': 'aktif'}); _yukle(); }
                      },
                      itemBuilder: (_) => [
                        if (durum != 'aktif') const PopupMenuItem(value: 'aktif', child: Row(children: [Icon(Icons.check_circle, color: Colors.green, size: 18), SizedBox(width: 8), Text('Aktifles')])),
                        if (durum != 'askida') const PopupMenuItem(value: 'askida', child: Row(children: [Icon(Icons.pause_circle, color: Colors.orange, size: 18), SizedBox(width: 8), Text('Askiya Al')])),
                        const PopupMenuItem(value: 'sil', child: Row(children: [Icon(Icons.delete_outline, color: Colors.red, size: 18), SizedBox(width: 8), Text('Sil', style: TextStyle(color: Colors.red))])),
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

// ═══════════════════════════════════════════════════════
//  GLOBAL HARİTA
// ═══════════════════════════════════════════════════════
class WebSuperAdminHarita extends StatelessWidget {
  const WebSuperAdminHarita({super.key});
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.map_outlined, size: 64, color: Colors.grey),
      SizedBox(height: 16),
      Text('Global Harita', style: TextStyle(fontSize: 18, color: Colors.grey)),
      Text('Tum aktif servisleri gosterir', style: TextStyle(color: Colors.grey)),
    ]),
  );
}

// ═══════════════════════════════════════════════════════
//  KULLANICILAR
// ═══════════════════════════════════════════════════════
class WebSuperAdminKullanicilar extends StatefulWidget {
  const WebSuperAdminKullanicilar({super.key});
  @override
  State<WebSuperAdminKullanicilar> createState() => _WebSuperAdminKullanicilarState();
}
class _WebSuperAdminKullanicilarState extends State<WebSuperAdminKullanicilar> {
  List<Map<String, dynamic>> _kullanicilar = [];
  List<Map<String, dynamic>> _filtrelenmis = [];
  bool _yukleniyor = true;
  String _filtre = 'Tumu';
  final _araCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _yukle(); }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    final snap = await FirebaseFirestore.instance.collection('kullanicilar').get();
    _kullanicilar = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    _filtrele(_araCtrl.text);
    setState(() => _yukleniyor = false);
  }

  void _filtrele(String q) {
    setState(() {
      _filtrelenmis = _kullanicilar.where((k) {
        final rolUygun = _filtre == 'Tumu' || k['rol'] == _filtre;
        final araUygun = q.isEmpty ||
            (k['email'] ?? '').toString().toLowerCase().contains(q.toLowerCase()) ||
            (k['ad'] ?? '').toString().toLowerCase().contains(q.toLowerCase());
        return rolUygun && araUygun;
      }).toList();
    });
  }

  Color _rolRenk(String rol) {
    switch (rol) {
      case 'superAdmin': return Colors.amber;
      case 'firmaAdmin': return Colors.blue;
      case 'sofor': return Colors.green;
      case 'veli': return Colors.purple;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Kullanicilar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _saNavy)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: TextField(
            controller: _araCtrl, onChanged: _filtrele,
            decoration: InputDecoration(
              hintText: 'Kullanici ara...', prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true, fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          )),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: _filtre,
            items: ['Tumu', 'superAdmin', 'firmaAdmin', 'sofor', 'veli']
                .map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: (v) { _filtre = v!; _filtrele(_araCtrl.text); },
          ),
        ]),
        const SizedBox(height: 16),
        if (_yukleniyor)
          const Center(child: CircularProgressIndicator())
        else
          Expanded(
            child: ListView.separated(
              itemCount: _filtrelenmis.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final k = _filtrelenmis[i];
                final rol = k['rol'] ?? 'bilinmiyor';
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
                  ),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: _rolRenk(rol).withValues(alpha: 0.15),
                      child: Text((k['email'] ?? 'U')[0].toUpperCase(),
                          style: TextStyle(color: _rolRenk(rol), fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(k['email'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      if (k['ad'] != null) Text(k['ad'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      if (k['firmaId'] != null) Text('Firma: ${k['firmaId']}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: _rolRenk(rol).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                      child: Text(rol, style: TextStyle(color: _rolRenk(rol), fontSize: 11, fontWeight: FontWeight.bold)),
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

// ═══════════════════════════════════════════════════════
//  SİSTEM
// ═══════════════════════════════════════════════════════
class _SaSistem extends StatelessWidget {
  const _SaSistem();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Sistem Ayarlari', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _saNavy)),
        const SizedBox(height: 24),
        _SistemKart(Icons.notifications_outlined, 'Bildirim Ayarlari', 'FCM ve push bildirim yapılandırması', onTap: () {
          showDialog(context: context, builder: (_) => AlertDialog(
            title: const Text('Bildirim Ayarlari'),
            content: const Text('FCM Server Key ve bildirim ayarlari Firebase Console uzerinden yonetilir.'),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat'))],
          ));
        }),
        const SizedBox(height: 12),
        _SistemKart(Icons.security_outlined, 'Guvenlik', 'Firestore rules ve API key yonetimi', onTap: () async {
          final url = Uri.parse('https://console.firebase.google.com/project/servis360-15b4a/firestore/rules');
          if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
        }),
        const SizedBox(height: 12),
        _SistemKart(Icons.backup_outlined, 'Firebase Console', 'Veri yedekleme ve disa aktarma', onTap: () async {
          final url = Uri.parse('https://console.firebase.google.com/project/servis360-15b4a/overview');
          if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
        }),
        const SizedBox(height: 12),
        _SistemKart(Icons.palette_outlined, 'Tema & Gorunum', 'Lacivert ve Turuncu tasarim sistemi', onTap: () {
          showDialog(context: context, builder: (_) => AlertDialog(
            title: const Text('Tema'),
            content: const Text('Varsayilan tema: Lacivert (#1a3a6b) & Turuncu (#FF8C00)'),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat'))],
          ));
        }),
        const SizedBox(height: 12),
        _SistemKart(Icons.info_outline, 'Uygulama Hakkinda', 'Servisim360 v1.0 — Akilli Servis Yonetim Sistemi', onTap: () {
          showDialog(context: context, builder: (_) => AlertDialog(
            title: const Text('Servisim360'),
            content: const Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Versiyon: 1.0.0'), SizedBox(height: 8),
              Text('Akilli Okul Servis Yonetim Sistemi'), SizedBox(height: 8),
              Text('Web: https://servis360-15b4a.web.app'),
            ]),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat'))],
          ));
        }),
      ]),
    );
  }
}

class _SistemKart extends StatelessWidget {
  final IconData ikon;
  final String baslik, aciklama;
  final VoidCallback onTap;
  const _SistemKart(this.ikon, this.baslik, this.aciklama, {required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
      ),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _saNavy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
            child: Icon(ikon, color: _saNavy, size: 20)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(baslik, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text(aciklama, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ])),
        const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      ]),
    ),
  );
}



