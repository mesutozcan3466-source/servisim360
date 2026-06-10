import 'package:flutter/material.dart';
import 'ai_widget.dart';
import 'yardim_widget.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/session_service.dart';

class OgrencilerScreen extends StatefulWidget {
  const OgrencilerScreen({super.key});
  @override
  State<OgrencilerScreen> createState() => _OgrencilerScreenState();
}

class _OgrencilerScreenState extends State<OgrencilerScreen> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  String? _firmaId;
  String  _projeId  = '';
  String  _projeAdi = '';
  String  _arama = '';

  @override
  void initState() {
    super.initState();
    SessionService.instance.firmaIdAl().then((id) {
      _projeId  = SessionService.instance.aktifProjeId  ?? '';
      _projeAdi = SessionService.instance.aktifProjeAdi ?? '';
      if (mounted) setState(() => _firmaId = id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white,
        title: const Text('Öğrenciler', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          AiAsistanButonu(ekranAdi: 'Kayitlar'),
          YardimButonu(ekranAdi: 'Kayitlar'),
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () => _ogrenciEkleDialog(context),
          ),
        ],
      ),
      body: _firmaId == null
          ? const Center(child: CircularProgressIndicator(color: _navy))
          : Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (v) => setState(() => _arama = v),
            decoration: InputDecoration(
              hintText: 'Öğrenci ara...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true, fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        Expanded(child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('students')
              .where('firmaId', isEqualTo: _firmaId)
              .where('projeId', isEqualTo: _projeId)
              .orderBy('ad')
              .snapshots(),
          builder: (_, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _navy));
            }
            var docs = snap.data?.docs ?? [];
            if (_arama.isNotEmpty) {
              docs = docs.where((d) {
                final ad = ((d.data() as Map)['ad'] ?? '').toString().toLowerCase();
                return ad.contains(_arama.toLowerCase());
              }).toList();
            }
            if (docs.isEmpty) {
              return const Center(child: Text('Öğrenci bulunamadı',
                  style: TextStyle(color: Colors.grey)));
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: docs.length,
              itemBuilder: (_, i) {
                final data  = docs[i].data() as Map<String, dynamic>;
                final docId = docs[i].id;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
                  child: Row(children: [
                    CircleAvatar(radius: 20, backgroundColor: _turuncu.withValues(alpha: 0.1),
                        child: Text((data['ad'] ?? '?')[0].toUpperCase(),
                            style: const TextStyle(color: _turuncu, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(data['ad'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      if ((data['adres'] ?? '').isNotEmpty)
                        Text(data['adres'], style: TextStyle(color: Colors.grey[500], fontSize: 11),
                            overflow: TextOverflow.ellipsis),
                      if ((data['veliAd'] ?? '').isNotEmpty)
                        Text('Veli: ${data['veliAd']}', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                    ])),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.grey, size: 18),
                      onSelected: (v) async {
                        if (v == 'sil') {
                          await FirebaseFirestore.instance
                              .collection('students').doc(docId).delete();
                        } else if (v == 'servise_ata') {
                          _serviseAtaDialog(context, docId, data);
                        } else if (v == 'detay') {
                          _ogrenciDetayDialog(context, docId, data);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'detay',
                            child: Row(children: [
                              Icon(Icons.info_outline, size: 16, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Detay Gör'),
                            ])),
                        PopupMenuItem(value: 'servise_ata',
                            child: Row(children: [
                              Icon(Icons.directions_bus_outlined, size: 16, color: Color(0xFF1a3a6b)),
                              SizedBox(width: 8),
                              Text('Servise Ata'),
                            ])),
                        PopupMenuItem(value: 'sil',
                            child: Row(children: [
                              Icon(Icons.delete_outline, size: 16, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Sil', style: TextStyle(color: Colors.red)),
                            ])),
                      ],
                    ),
                  ]),
                );
              },
            );
          },
        )),
      ]),
    );
  }


  // ── Öğrenci Detay Dialog ──────────────────────────────────────
  void _ogrenciDetayDialog(BuildContext context, String docId, Map<String, dynamic> data) {
    final navy = const Color(0xFF1a3a6b);
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: EdgeInsets.zero,
      content: SizedBox(width: 340, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: navy,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
            child: Row(children: [
              CircleAvatar(radius: 18, backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text((data['ad'] ?? '?')[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              const SizedBox(width: 10),
              Expanded(child: Text(data['ad'] ?? 'Öğrenci',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              IconButton(icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                  onPressed: () => Navigator.pop(_), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            ])),
        Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          _detaySatir('Adres', data['adres'] ?? data['sabahAdres'] ?? '-', Icons.location_on_outlined, navy),
          _detaySatir('Veli', data['veliAd'] ?? '-', Icons.family_restroom_outlined, Colors.purple),
          _detaySatir('Telefon', data['veliTel'] ?? data['anneTelefon'] ?? '-', Icons.phone_outlined, Colors.green),
          _detaySatir('Servis', data['soforAd'] ?? data['servisAd'] ?? (data['surucuId']?.isNotEmpty == true ? 'Atanmış' : 'Atanmamış'),
              Icons.directions_bus_outlined, data['surucuId']?.isNotEmpty == true ? Colors.blue : Colors.orange),
          _detaySatir('Proje', data['projeAd'] ?? data['projeId'] ?? '-', Icons.folder_outlined, Colors.teal),
          _detaySatir('Durum', data['durum'] ?? 'onayli', Icons.verified_outlined, Colors.green),
        ])),
        Padding(padding: const EdgeInsets.fromLTRB(16,0,16,16), child: Row(children: [
          Expanded(child: OutlinedButton(
              onPressed: () { Navigator.pop(_); _serviseAtaDialog(context, docId, data); },
              child: const Text('Servise Ata'))),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: navy, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(_),
              child: const Text('Kapat'))),
        ])),
      ])),
    ));
  }

  Widget _detaySatir(String label, String deger, IconData ikon, Color renk) =>
      Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
        Icon(ikon, size: 15, color: renk),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(fontSize: 12, color: renk, fontWeight: FontWeight.bold)),
        Expanded(child: Text(deger, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
      ]));

  // ── Servise Ata Dialog ────────────────────────────────────────
  void _serviseAtaDialog(BuildContext context, String docId, Map<String, dynamic> data) {
    String? seciliSoforId = data['surucuId'] as String?;
    List<Map<String,dynamic>> soforler = [];
    bool yukleniyor = true;

    showDialog(context: context, builder: (_) => StatefulBuilder(
      builder: (ctx, setS) {
        // Şoförleri yükle
        if (yukleniyor) {
          FirebaseFirestore.instance.collection('drivers')
              .where('firmaId', isEqualTo: _firmaId)
              .get().then((snap) {
            soforler = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
            setS(() => yukleniyor = false);
          });
        }
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Servise Ata', style: TextStyle(color: Color(0xFF1a3a6b), fontWeight: FontWeight.bold)),
          content: SizedBox(width: 300, child: yukleniyor
              ? const Center(child: CircularProgressIndicator())
              : Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Öğrenci: ${data['ad'] ?? ''}',
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 14),
            DropdownButtonFormField<String?>(
              value: seciliSoforId?.isEmpty == true ? null : seciliSoforId,
              decoration: const InputDecoration(
                  labelText: 'Servis / Şoför',
                  prefixIcon: Icon(Icons.directions_bus_outlined, size: 18, color: Color(0xFF1a3a6b)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                  isDense: true),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Atanmamış')),
                ...soforler.map((s) => DropdownMenuItem<String?>(
                    value: s['id'] as String,
                    child: Text('${s['ad'] ?? 'Şoför'}  •  ${s['aracPlaka'] ?? ''}'))),
              ],
              onChanged: (v) => setS(() => seciliSoforId = v),
            ),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1a3a6b), foregroundColor: Colors.white),
              onPressed: () async {
                final secilenSofor = soforler.firstWhere(
                        (s) => s['id'] == seciliSoforId, orElse: () => {});
                await FirebaseFirestore.instance.collection('students').doc(docId).update({
                  'surucuId': seciliSoforId ?? '',
                  'soforId':  seciliSoforId ?? '',
                  'soforAd':  secilenSofor['ad'] ?? '',
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Servis atama güncellendi'),
                        backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
              },
              child: const Text('Ata'),
            ),
          ],
        );
      },
    ));
  }

  // Rastgele 6 haneli şifre üret
  String _rastgeleKod() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final now = DateTime.now();
    final buf = StringBuffer();
    for (var i = 0; i < 6; i++) buf.write(chars[(now.microsecond + i * 7) % chars.length]);
    return buf.toString();
  }

  void _ogrenciEkleDialog(BuildContext context) {
    final adCtrl      = TextEditingController();
    final soyadCtrl   = TextEditingController();
    final adresCtrl   = TextEditingController();
    final veliCtrl    = TextEditingController();
    final telCtrl     = TextEditingController();
    final okulCtrl    = TextEditingController();
    final sinifCtrl   = TextEditingController();
    bool yukleniyor   = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 520,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: Colors.white),
            child: Column(children: [
              // Başlık
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                    color: _navy,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                child: Row(children: [
                  const Icon(Icons.person_add_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Öğrenci Ekle', style: TextStyle(color: Colors.white,
                        fontSize: 17, fontWeight: FontWeight.bold)),
                    Text('Veli hesabı otomatik oluşturulacak',
                        style: TextStyle(color: Colors.white60, fontSize: 11)),
                  ])),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx)),
                ]),
              ),

              Expanded(child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Öğrenci bilgileri
                  const Text('Öğrenci Bilgileri', style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13, color: _navy)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _input(adCtrl, 'Ad *', Icons.person_outline)),
                    const SizedBox(width: 8),
                    Expanded(child: _input(soyadCtrl, 'Soyad', Icons.person_outline)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _input(okulCtrl, 'Okul', Icons.school_outlined)),
                    const SizedBox(width: 8),
                    Expanded(child: _input(sinifCtrl, 'Sınıf', Icons.class_outlined)),
                  ]),
                  const SizedBox(height: 8),
                  _input(adresCtrl, 'Adres', Icons.location_on_outlined),
                  const SizedBox(height: 16),

                  // Veli bilgileri
                  const Text('Veli Bilgileri', style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13, color: _navy)),
                  const SizedBox(height: 4),
                  const Text('Veli hesabı otomatik oluşturulur',
                      style: TextStyle(color: Colors.grey, fontSize: 11)),
                  const SizedBox(height: 8),
                  _input(veliCtrl, 'Veli Adı Soyadı *', Icons.family_restroom_outlined),
                  const SizedBox(height: 8),
                  _input(telCtrl, 'Veli Telefon * (kullanıcı adı olacak)',
                      Icons.phone_outlined, tipi: TextInputType.phone),

                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade200)),
                    child: const Row(children: [
                      Icon(Icons.auto_awesome, color: Colors.green, size: 14),
                      SizedBox(width: 8),
                      Expanded(child: Text(
                        'Kayıt sonrası veli hesabı otomatik oluşturulur. '
                            'Kullanıcı adı telefon numarası, şifre otomatik üretilir.',
                        style: TextStyle(fontSize: 11, color: Colors.green),
                      )),
                    ]),
                  ),
                ]),
              )),

              // Kaydet butonu
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('İptal'),
                  )),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _turuncu, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: yukleniyor ? null : () async {
                      if (adCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                            content: Text('Öğrenci adı zorunlu!'),
                            behavior: SnackBarBehavior.floating));
                        return;
                      }
                      if (telCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                            content: Text('Veli telefonu zorunlu!'),
                            behavior: SnackBarBehavior.floating));
                        return;
                      }
                      setSt(() => yukleniyor = true);
                      try {
                        final now       = FieldValue.serverTimestamp();
                        final geciciSif = _rastgeleKod();
                        final temizTel  = telCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
                        final kulAdi    = telCtrl.text.trim(); // tel no = kullanıcı adı

                        // 1. Öğrenci kaydet
                        final ogrRef = await FirebaseFirestore.instance.collection('students').add({
                          'firmaId'   : _firmaId,
                          'ad'        : adCtrl.text.trim(),
                          'soyad'     : soyadCtrl.text.trim(),
                          'adSoyad'   : '${adCtrl.text.trim()} ${soyadCtrl.text.trim()}'.trim(),
                          'adres'     : adresCtrl.text.trim(),
                          'okul'      : okulCtrl.text.trim(),
                          'sinif'     : sinifCtrl.text.trim(),
                          'veliAd'    : veliCtrl.text.trim(),
                          'veliTel'   : telCtrl.text.trim(),
                          'aktif'       : true,
                          'durum'       : 'bekliyor',
                          'projeId'     : SessionService.instance.aktifProjeId ?? '',
                          'projeAd'     : SessionService.instance.aktifProjeAdi ?? '',
                          'surucuId'    : '',
                          'soforId'     : '',
                          'soforAd'     : '',
                          'servisId'    : '',
                          'servisAd'    : '',
                          'veliId'      : '',
                          'konumVar'    : false,
                          'sabahKullan' : true,
                          'aksamKullan' : true,
                          'sozlesmeOnay': false,
                          'fiyat'       : 0,
                          'olusturma'   : now,
                          'olusturmaTarihi': FieldValue.serverTimestamp(),
                        });

                        // 2. Otomatik veli hesabı oluştur
                        await FirebaseFirestore.instance.collection('parents').doc(ogrRef.id).set({
                          'firmaId'       : _firmaId,
                          'ogrenciId'     : ogrRef.id,
                          'ad'            : veliCtrl.text.trim(),
                          'telefon'       : telCtrl.text.trim(),
                          'kullaniciAdi'  : kulAdi,
                          'geciciSifre'   : geciciSif,
                          'ilkGiris'      : true,  // ilk girişte şifre değiştir
                          'aktif'         : true,
                          'rol'           : 'veli',
                          'olusturma'     : now,
                          'ogrenciId'    : ogrRef.id,
                          'projeId'      : SessionService.instance.aktifProjeId ?? '',
                          'sozlesmeOnay' : false,
                          'aktif'        : true,
                        });

                        // 3. kullanicilar koleksiyonuna da ekle
                        await FirebaseFirestore.instance.collection('kullanicilar').doc(ogrRef.id).set({
                          'firmaId'     : _firmaId,
                          'ad'          : veliCtrl.text.trim(),
                          'telefon'     : telCtrl.text.trim(),
                          'kullaniciAdi': kulAdi,
                          'sifre'       : geciciSif,
                          'ilkGiris'    : true,
                          'rol'         : 'veli',
                          'ogrenciId'   : ogrRef.id,
                          'olusturma'   : now,
                        });

                        // 4. Öğrenciye veliId bağla
                        await FirebaseFirestore.instance.collection('students').doc(ogrRef.id).update({
                          'veliId': ogrRef.id,
                        });

                        if (ctx.mounted) Navigator.pop(ctx);

                        // 5. Giriş bilgisi gönder dialog
                        if (context.mounted) {
                          _veliGirisDialog(context,
                            veliCtrl.text.trim(),
                            telCtrl.text.trim(),
                            kulAdi,
                            geciciSif,
                            adCtrl.text.trim(),
                          );
                        }
                      } catch (e) {
                        setSt(() => yukleniyor = false);
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text('Hata: \$e'),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating));
                      }
                    },
                    icon: yukleniyor
                        ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save_rounded),
                    label: Text(yukleniyor ? 'Kaydediliyor...' : 'Kaydet & Veli Hesabı Oluştur',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  )),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _veliGirisDialog(BuildContext context, String veliAd, String tel,
      String kulAdi, String sifre, String ogrAd) {
    final mesaj =
        'Servisim360\'a Hoş Geldiniz!\n'
        'Öğrenci: \$ogrAd\n'
        'Kullanıcı Adınız: \$kulAdi\n'
        'Geçici Şifreniz: \$sifre\n'
        'Uygulamaya giriş yapabilirsiniz.';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('\$veliAd — Giriş Bilgileri'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200)),
            child: Text(mesaj, style: const TextStyle(fontSize: 13)),
          ),
          const SizedBox(height: 12),
          const Text('Giriş bilgilerini gönderin:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
        actions: [
          OutlinedButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: const Text('Kopyala'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: mesaj));
                Navigator.pop(_);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Kopyalandı!'),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating));
              }),
          ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(_);
                final temiz = tel.replaceAll(RegExp(r'[^0-9]'), '');
                final url = Uri.parse(
                    'https://wa.me/90\$temiz?text=\${Uri.encodeComponent(mesaj)}');
                if (await canLaunchUrl(url)) {
                  launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold))),
          TextButton(onPressed: () => Navigator.pop(_), child: const Text('Kapat')),
        ],
      ),
    );
  }

  Widget _input(TextEditingController c, String label, IconData icon,
      {TextInputType tipi = TextInputType.text}) =>
      TextField(
        controller: c, keyboardType: tipi,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _navy, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );
}
