// ╔══════════════════════════════════════════════════════════════╗
// ║  DOSYA: lib/screens/sofor_sozlesme_screen.dart
// ║  Şoför Sözleşmesi — PDF + arşiv entegrasyonu
// ╚══════════════════════════════════════════════════════════════╝
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dijital_imza_screen.dart';
import 'yardim_widget.dart';

class SoforSozlesmeScreen extends StatefulWidget {
  final String surucuId;
  final Map<String, dynamic> soforData;

  const SoforSozlesmeScreen({
    super.key,
    required this.surucuId,
    required this.soforData,
  });

  @override
  State<SoforSozlesmeScreen> createState() => _SoforSozlesmeScreenState();
}

class _SoforSozlesmeScreenState extends State<SoforSozlesmeScreen>
    with SingleTickerProviderStateMixin {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  late TabController _tab;
  bool _kaydediliyor = false;

  // Sözleşme maddeleri
  final _maddeler = [
    _SoforMadde('is_tanimi', 'İş Tanımı',
        'Şoför, işbu sözleşme kapsamında belirlenen güzergah ve saatlerde öğrenci/personel taşıma hizmetini yürütmeyi kabul eder.'),
    _SoforMadde('calisma_saatleri', 'Çalışma Saatleri',
        'Çalışma saatleri proje bazında belirlenir. Değişiklikler 3 iş günü öncesinden bildirilir.'),
    _SoforMadde('belge_zorunlulugu', 'Belge Zorunluluğu',
        'Geçerli ehliyet, SRC belgesi ve psikoteknik belgesi bulundurmak zorunludur. Belge süreleri firma tarafından takip edilir.'),
    _SoforMadde('arac_kullanimi', 'Araç Kullanımı',
        'Araç yalnızca servis hizmetlerinde kullanılacaktır. Kişisel kullanım yasaktır. Yakıt, bakım ve sigorta firma sorumluluğundadır.'),
    _SoforMadde('gizlilik', 'Gizlilik',
        'Öğrenci ve veli bilgileri gizli tutulacaktır. Üçüncü kişilerle paylaşılması yasaktır.'),
    _SoforMadde('kvkk', 'KVKK',
        '6698 sayılı KVKK kapsamında kişisel veriler yalnızca hizmet amacıyla işlenecektir.'),
    _SoforMadde('uyguama_kullanimi', 'Servisim360 Kullanımı',
        'Şoför, Servisim360 uygulamasını aktif olarak kullanmak, servis başladığında konum paylaşımını açmak ve öğrenci yoklaması yapmakla yükümlüdür.'),
    _SoforMadde('fesih', 'Sözleşme Feshi',
        '15 gün önceden yazılı ihbar koşuluyla her iki taraf sözleşmeyi feshedebilir. Haklı nedenle fesihte ihbar süresi aranmaz.'),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final ad      = widget.soforData['adSoyad'] ?? widget.soforData['ad'] ?? 'Şoför';
    final tc      = widget.soforData['tcKimlik'] ?? '';
    final ehliyet = widget.soforData['ehliyetSinifi'] ?? '';
    final src     = widget.soforData['srcBelgesi'] ?? '';
    final plaka   = widget.soforData['plaka'] ?? widget.soforData['aracPlaka'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white,
        title: Text('$ad — Sözleşme',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [YardimButonu(ekranAdi: 'Servisler'), const SizedBox(width: 8)],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: _turuncu,
          labelColor: Colors.white, unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(icon: Icon(Icons.person_outlined, size: 16), text: 'Bilgiler'),
            Tab(icon: Icon(Icons.description_outlined, size: 16), text: 'Sözleşme'),
            Tab(icon: Icon(Icons.history_outlined, size: 16), text: 'Geçmiş'),
          ],
        ),
      ),
      body: TabBarView(controller: _tab, children: [
        // TAB 1 — Şoför Bilgileri
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _bilgiKarti('Kişisel Bilgiler', Icons.person_outlined, [
              _bilgiSatir('Ad Soyad', ad, Icons.badge_outlined),
              _bilgiSatir('Telefon', widget.soforData['telefon'] ?? '-', Icons.phone_outlined),
              if (tc.isNotEmpty) _bilgiSatir('TC Kimlik', tc, Icons.credit_card_outlined),
            ]),
            const SizedBox(height: 12),
            _bilgiKarti('Belgeler', Icons.folder_outlined, [
              if (ehliyet.isNotEmpty) _bilgiSatir('Ehliyet', ehliyet, Icons.drive_eta_outlined),
              if (src.isNotEmpty) _bilgiSatir('SRC', src, Icons.article_outlined),
              if ((widget.soforData['psikoTarih'] ?? '').isNotEmpty)
                _bilgiSatir('Psikoteknik', widget.soforData['psikoTarih'], Icons.calendar_today_outlined),
            ]),
            const SizedBox(height: 12),
            _bilgiKarti('Araç Bilgisi', Icons.directions_bus_outlined, [
              if (plaka.isNotEmpty) _bilgiSatir('Plaka', plaka, Icons.badge_outlined),
              if ((widget.soforData['aracModeli'] ?? '').isNotEmpty)
                _bilgiSatir('Model', widget.soforData['aracModeli'], Icons.directions_car_outlined),
              if ((widget.soforData['aracKapasitesi'] ?? '').isNotEmpty)
                _bilgiSatir('Kapasite', '${widget.soforData['aracKapasitesi']} kişi', Icons.people_outlined),
            ]),
            const SizedBox(height: 20),

            // İmza durumu
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('drivers').doc(widget.surucuId).snapshots(),
              builder: (_, snap) {
                final data = snap.data?.data() as Map<String, dynamic>? ?? {};
                final imzali = data['sozlesmeImzali'] == true;
                final imzaTarih = data['sozlesmeImzaTarihi'];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: imzali ? Colors.green.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: imzali ? Colors.green.shade200 : Colors.orange.shade200)),
                  child: Row(children: [
                    Icon(imzali ? Icons.verified_outlined : Icons.pending_outlined,
                        color: imzali ? Colors.green : Colors.orange, size: 24),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(imzali ? 'Sözleşme İmzalandı' : 'İmza Bekleniyor',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14,
                              color: imzali ? Colors.green : Colors.orange)),
                      if (imzali && imzaTarih is Timestamp)
                        Text('${(imzaTarih).toDate().day}.${(imzaTarih).toDate().month}.${(imzaTarih).toDate().year}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ])),
                    if (!imzali)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _navy, foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8))),
                        onPressed: () => _imzaAl(context, ad),
                        child: const Text('İmzala', style: TextStyle(fontWeight: FontWeight.bold))),
                  ]),
                );
              },
            ),
          ]),
        ),

        // TAB 2 — Sözleşme Metni
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8)]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('ŞOFÖR HİZMET SÖZLEŞMESİ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                        color: _navy),
                    textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text(
                  'İşbu sözleşme, servis firması ile şoför $ad arasında '
                  'akdedilmiş olup aşağıdaki hükümleri kapsar.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  textAlign: TextAlign.center),
                const Divider(height: 24),

                ..._maddeler.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('MADDE ${e.key + 1} — ${e.value.baslik.toUpperCase()}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11, color: _navy)),
                    const SizedBox(height: 4),
                    Text(e.value.icerik,
                        style: const TextStyle(fontSize: 12, height: 1.6)),
                  ]),
                )),

                const Divider(height: 24),
                Row(children: [
                  Expanded(child: Column(children: [
                    const Text('FİRMA', style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 30),
                    const Divider(),
                    const Text('Yetkili İmzası', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ])),
                  const SizedBox(width: 40),
                  Expanded(child: Column(children: [
                    Text(ad.toUpperCase(), style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 30),
                    const Divider(),
                    const Text('Şoför İmzası', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ])),
                ]),
              ]),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                onPressed: () => _whatsappGonder(ad),
                icon: const Icon(Icons.share_outlined, size: 16),
                label: const Text('WhatsApp'),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _navy, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                onPressed: () => _imzaAl(context, ad),
                icon: const Icon(Icons.draw_outlined, size: 16),
                label: const Text('İmzala',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              )),
            ]),
          ]),
        ),

        // TAB 3 — İmza Geçmişi
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('drivers').doc(widget.surucuId).snapshots(),
          builder: (_, snap) {
            final data = snap.data?.data() as Map<String, dynamic>? ?? {};
            final imzaData = data['sozlesmeImzaData'] as Map<String, dynamic>?;

            if (imzaData == null) {
              return const Center(child: Text('Henüz imza yok',
                  style: TextStyle(color: Colors.grey, fontSize: 15)));
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('İmza Bilgileri',
                          style: TextStyle(fontWeight: FontWeight.bold,
                              fontSize: 15, color: _navy)),
                      const SizedBox(height: 12),
                      _bilgiSatir('İmzalayan', imzaData['adSoyad'] ?? ad,
                          Icons.person_outlined),
                      _bilgiSatir('Tarih', imzaData['tarihStr'] ?? '-',
                          Icons.calendar_today_outlined),
                      _bilgiSatir('Tür',
                          imzaData['tip'] == 'cizim' ? 'Çizim İmza' : 'Yazılı İmza',
                          Icons.draw_outlined),
                      _bilgiSatir('Cihaz', imzaData['cihazBilgisi'] ?? '-',
                          Icons.devices_outlined),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8)),
                        child: const Row(children: [
                          Icon(Icons.verified_outlined,
                              color: Colors.green, size: 16),
                          SizedBox(width: 8),
                          Text('Geçerli dijital imza kaydı mevcut',
                              style: TextStyle(
                                  color: Colors.green, fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ]),
    );
  }

  void _imzaAl(BuildContext context, String ad) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => DijitalImzaScreen(
        sozlesmeId: widget.surucuId,
        veliAd: ad,
        onImzaTamamlandi: (imzaVeri) async {
          await FirebaseFirestore.instance
              .collection('drivers').doc(widget.surucuId).update({
            'sozlesmeImzali'     : true,
            'sozlesmeImzaTarihi' : FieldValue.serverTimestamp(),
            'sozlesmeImzaData'   : imzaVeri,
          });
          if (mounted) setState(() {});
        },
      ),
    ));
  }

  void _whatsappGonder(String ad) async {
    final mesaj = 'Sayın $ad, şoför hizmet sözleşmeniz hazırlanmıştır. '
        'Servisim360 uygulamasından inceleyebilir ve imzalayabilirsiniz.';
    final tel = (widget.soforData['telefon'] ?? '').replaceAll(RegExp(r'[^\d]'), '');
    final url = Uri.parse('https://wa.me/90$tel?text=${Uri.encodeComponent(mesaj)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Widget _bilgiKarti(String baslik, IconData ikon,
      List<Widget> satirlar) => Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(ikon, color: _navy, size: 18),
          const SizedBox(width: 8),
          Text(baslik, style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 14, color: _navy)),
        ]),
        const Divider(height: 16),
        ...satirlar,
      ]),
    ),
  );

  Widget _bilgiSatir(String label, String deger, IconData ikon) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(ikon, size: 15, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(
              fontSize: 12, color: Colors.grey)),
          Expanded(child: Text(deger, style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600))),
        ]),
      );
}

class _SoforMadde {
  final String id, baslik, icerik;
  const _SoforMadde(this.id, this.baslik, this.icerik);
}
