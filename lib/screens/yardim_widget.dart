// ╔══════════════════════════════════════════════════════════════╗
// ║  DOSYA: lib/screens/yardim_widget.dart
// ║  PROJE: servisim360
// ║  v2 — Sesli okuma + AI + ekran bazlı yardım sistemi
// ╚══════════════════════════════════════════════════════════════╝
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class YardimButonu extends StatelessWidget {
  final String ekranAdi;
  const YardimButonu({super.key, required this.ekranAdi});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.help_outline_rounded),
      tooltip: 'Yardım',
      onPressed: () => YardimPanel.goster(context, ekranAdi),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// YARDIM PANELİ
// ════════════════════════════════════════════════════════════════
class YardimPanel {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  static void goster(BuildContext context, String ekranAdi) {
    final maddeler = _icerikler[ekranAdi] ?? _icerikler['Genel']!;
    final FlutterTts tts = FlutterTts();
    bool okuyor = false;

    tts.setLanguage('tr-TR');
    tts.setSpeechRate(0.9);
    tts.setPitch(1.0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => Container(
          height: MediaQuery.of(context).size.height * 0.82,
          decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            // Tutamaç
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),

            // Başlık
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: _navy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.help_rounded, color: _navy, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ekranAdi, style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16, color: _navy)),
                  const Text('Nasıl kullanılır?',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ])),

                // Sesli okuma butonu
                GestureDetector(
                  onTap: () async {
                    if (okuyor) {
                      await tts.stop();
                      setSt(() => okuyor = false);
                    } else {
                      setSt(() => okuyor = true);
                      final metin = _tumMetniOlustur(ekranAdi, maddeler);
                      await tts.speak(metin);
                      tts.setCompletionHandler(() {
                        if (ctx.mounted) setSt(() => okuyor = false);
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                        color: okuyor ? Colors.red.withValues(alpha: 0.1) : _turuncu.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: okuyor ? Colors.red.withValues(alpha: 0.3) : _turuncu.withValues(alpha: 0.3))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(okuyor ? Icons.stop_rounded : Icons.volume_up_rounded,
                          color: okuyor ? Colors.red : _turuncu, size: 16),
                      const SizedBox(width: 5),
                      Text(okuyor ? 'Durdur' : 'Sesli Oku',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold,
                              color: okuyor ? Colors.red : _turuncu)),
                    ]),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                  onPressed: () { tts.stop(); Navigator.pop(ctx); }),
              ]),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),

            // İçerik
            Expanded(child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              itemCount: maddeler.length,
              itemBuilder: (_, i) {
                final m = maddeler[i];
                final tip = m['tip'] ?? 'bilgi';

                Color renk;
                IconData ikon;
                switch (tip) {
                  case 'ipucu':  renk = Colors.green;  ikon = Icons.tips_and_updates_outlined; break;
                  case 'uyari':  renk = Colors.orange; ikon = Icons.warning_amber_outlined; break;
                  case 'adim':   renk = _navy;         ikon = Icons.play_circle_outline; break;
                  default:       renk = Colors.blue;   ikon = Icons.info_outline;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: renk.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: renk.withValues(alpha: 0.2))),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: renk.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(ikon, color: renk, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m['baslik'] ?? '',
                          style: TextStyle(fontWeight: FontWeight.bold,
                              fontSize: 13, color: renk)),
                      const SizedBox(height: 3),
                      Text(m['aciklama'] ?? '',
                          style: TextStyle(fontSize: 12,
                              color: Colors.grey[700], height: 1.5)),
                    ])),
                  ]),
                );
              },
            )),

            // Alt butonlar
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20,
                  MediaQuery.of(ctx).viewInsets.bottom + 16),
              child: Row(children: [
                Expanded(child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  onPressed: () { tts.stop(); Navigator.pop(ctx); },
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Kapat'),
                )),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _navy, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  onPressed: () {
                    tts.stop();
                    Navigator.pop(ctx);
                    Navigator.pushNamed(ctx, '/ai_asistan');
                  },
                  icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                  label: const Text('AI Asistan',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                )),
              ]),
            ),
          ]),
        ),
      ),
    ).whenComplete(() => tts.stop());
  }

  static String _tumMetniOlustur(String ekran,
      List<Map<String, String>> maddeler) {
    final buf = StringBuffer('$ekran ekranı hakkında bilgi. ');
    for (final m in maddeler) {
      buf.write('${m['baslik']}. ${m['aciklama']} ');
    }
    return buf.toString();
  }

  // ════════════════════════════════════════════════════════════════
  // YARDIM İÇERİKLERİ
  // ════════════════════════════════════════════════════════════════
  static const Map<String, List<Map<String, String>>> _icerikler = {

    'Ana Ekran': [
      {'tip': 'bilgi',  'baslik': 'Ana Ekran Nedir?',
       'aciklama': 'Tüm servis operasyonunuzun özet görünümüdür. Toplam şoför, öğrenci, aktif servis ve bekleyen devamsızlık sayılarını buradan görebilirsiniz.'},
      {'tip': 'adim',   'baslik': 'İstatistik Kartları',
       'aciklama': 'Üstteki kartlara tıklayarak o bölüme hızlıca geçebilirsiniz. Örneğin "Servisler" kartına tıklayınca servis yönetim ekranı açılır.'},
      {'tip': 'adim',   'baslik': 'Canlı Harita',
       'aciklama': 'Harita bölümünde şoförlerin anlık konumlarını görebilirsiniz. "Tam Ekran" butonuyla haritayı büyütebilirsiniz.'},
      {'tip': 'ipucu',  'baslik': 'Proje Seçimi',
       'aciklama': 'Sol üstteki proje seçiciden aktif projeyi değiştirebilirsiniz. Her proje kendi öğrenci, şoför ve servis listesine sahiptir.'},
      {'tip': 'uyari',  'baslik': 'Bekleyen Devamsızlıklar',
       'aciklama': 'Ana sayfada bekleyen devamsızlık sayısı kırmızı gösteriliyorsa velilerin gönderdiği devamsızlık bildirimleri var demektir. Hemen kontrol edin.'},
    ],

    'Servisler': [
      {'tip': 'bilgi',  'baslik': 'Servis Nedir?',
       'aciklama': '"1 Servis = 1 Şoför = 1 Araç" mantığıyla çalışır. Her servis sabah ve akşam rotasını yönetir. Akşam rotası sabahın otomatik tersidir.'},
      {'tip': 'adim',   'baslik': 'Servis Ekle',
       'aciklama': 'Sağ üstteki "Servis Ekle" butonuna basın. Şoför adı, telefon, araç plakası ve kapasiteyi girin. Kaydettiğinizde şoför hesabı ve araç kaydı otomatik oluşur.'},
      {'tip': 'adim',   'baslik': 'Şoför Girişi',
       'aciklama': 'Kaydedilen şoför, "Kullanıcı Adı" ve "Geçici Şifre" ile uygulamaya giriş yapabilir. İlk girişte şifresini değiştirmesi gerekir.'},
      {'tip': 'ipucu',  'baslik': 'Belgeler',
       'aciklama': 'TC Kimlik, Ehliyet Sınıfı, SRC Belgesi ve Psikoteknik Tarihi form alanlarına girerek kaydedebilirsiniz. Bu bilgiler şoför profilinde görünür.'},
      {'tip': 'uyari',  'baslik': 'Pasif Yapma',
       'aciklama': 'Şoförü silmek yerine "Pasif Yap" butonunu kullanın. Bu şekilde geçmiş servis kayıtları korunur, şoför uygulamaya giremez hale gelir.'},
    ],

    'Kayitlar': [
      {'tip': 'bilgi',  'baslik': 'Kayıtlar Nedir?',
       'aciklama': 'Öğrenci ve veli bilgilerinin merkezi yönetim ekranıdır. Sözleşme durumunu, atanan servisi ve aylık ücreti buradan görebilirsiniz.'},
      {'tip': 'adim',   'baslik': 'Kayıt Ekle',
       'aciklama': '"Kayıt Ekle" butonuna basın. Yüz yüze kayıt formunda öğrenci ve veli bilgilerini girin. Adres girince sistem fiyatı otomatik hesaplar.'},
      {'tip': 'adim',   'baslik': 'Durum Filtreleme',
       'aciklama': 'Dropdown menüden "Bekliyor", "Onaylı" veya "İmzalı" seçerek kayıtları filtreleyebilirsiniz.'},
      {'tip': 'ipucu',  'baslik': 'Veli Hesabı',
       'aciklama': 'Öğrenci kaydedildiğinde veli için otomatik kullanıcı hesabı oluşturulur. Telefon numarası kullanıcı adı, sistem rastgele şifre üretir.'},
      {'tip': 'uyari',  'baslik': 'Servise Atama',
       'aciklama': 'Öğrenciyi servise atamak için öğrenci detayından "Servis" alanını güncelleyin. Atama yapılmadan şoför öğrenciyi göremez.'},
    ],

    'Sozlesmeler': [
      {'tip': 'bilgi',  'baslik': 'Sözleşme Sistemi',
       'aciklama': 'Her firma kendi sözleşme şablonlarını oluşturabilir. Farklı projeler için farklı şablonlar kullanılabilir.'},
      {'tip': 'adim',   'baslik': 'Şablon Oluştur',
       'aciklama': '"Yeni Şablon" butonuna basın, şablon adını girin. Sistem otomatik olarak zorunlu maddeleri (KVKK, Emniyet Kemeri) ekler.'},
      {'tip': 'adim',   'baslik': 'Madde Yönetimi',
       'aciklama': '"Hazır Maddeler" sekmesinde istediğiniz maddeleri açıp kapatabilirsiniz. Zorunlu maddeler (kırmızı etiketli) kapatılamaz.'},
      {'tip': 'adim',   'baslik': 'Firma Bilgileri',
       'aciklama': '"Firma Bilgileri" sekmesinde firma adı, yetkili, adres ve vergi bilgilerini girin. Bu bilgiler PDF sözleşmede otomatik görünür.'},
      {'tip': 'adim',   'baslik': 'PDF Oluştur',
       'aciklama': '"PDF & Gönder" sekmesinden PDF oluşturabilir, WhatsApp ile paylaşabilir veya metni kopyalayabilirsiniz.'},
      {'tip': 'ipucu',  'baslik': 'Proje Bazlı Şablon',
       'aciklama': 'Her projeye farklı şablon atayabilirsiniz. Projeler → ilgili proje → Sözleşme sekmesinden şablon seçin.'},
    ],

    'Rotalar': [
      {'tip': 'bilgi',  'baslik': 'Rota Sistemi',
       'aciklama': '3 sekme: Rotalar (şoför bazlı), Atamasızlar (servise atanmamış öğrenciler) ve Servisler (proje bazlı servisler).'},
      {'tip': 'adim',   'baslik': 'Sabah / Akşam Ayrımı',
       'aciklama': 'Her şoförün altında sabah ve akşam güzergahı ayrı gösterilir. Akşam rotası sabahın otomatik tersidir — Ev→Okul, Okul→Ev.'},
      {'tip': 'adim',   'baslik': 'Filtreler',
       'aciklama': 'Üstteki Sabah/Akşam/Öğle butonlarına tıklayarak sadece o tipteki rotaları görebilirsiniz.'},
      {'tip': 'uyari',  'baslik': 'Atamasız Öğrenciler',
       'aciklama': '"Atamasızlar" sekmesinde servise atanmamış öğrenciler görünür. Bu öğrencileri bir servise atayana kadar şoför göremez.'},
      {'tip': 'ipucu',  'baslik': 'Haritada Göster',
       'aciklama': 'Öğrenci adresinin yanındaki harita ikonuna tıklayarak konumu Google Maps\'ta görebilirsiniz.'},
    ],

    'Harita': [
      {'tip': 'bilgi',  'baslik': 'Canlı Takip Haritası',
       'aciklama': 'Şoförlerin anlık GPS konumlarını haritada görebilirsiniz. Şoför uygulamada aktif servis başlattığında konumu otomatik güncellenir.'},
      {'tip': 'adim',   'baslik': 'Şoför İkonu',
       'aciklama': 'Haritadaki araç ikonuna tıklayınca şoför adı, plaka ve son güncelleme zamanı görünür.'},
      {'tip': 'adim',   'baslik': 'Öğrenci Durakları',
       'aciklama': 'Öğrenci ikonlarına tıklayınca o öğrencinin adı ve bindi/binmedi durumu görünür.'},
      {'tip': 'ipucu',  'baslik': 'Otomatik Takip',
       'aciklama': 'Harita 30 saniyede bir otomatik güncellenir. Manuel yenilemek için sağ üstteki yenile butonunu kullanın.'},
      {'tip': 'uyari',  'baslik': 'Konum Kapalıysa',
       'aciklama': 'Şoförün konumu gözükmüyorsa uygulamada konum izni verilmemiş olabilir. Şoföre uygulamada konumu açmasını söyleyin.'},
    ],

    'Raporlar': [
      {'tip': 'bilgi',  'baslik': 'Raporlar Ekranı',
       'aciklama': 'Öğrenci sayıları, şoför durumları, devamsızlık istatistikleri ve gelir özetini bu ekranda görebilirsiniz.'},
      {'tip': 'adim',   'baslik': 'Excel Aktar',
       'aciklama': '"Excel Aktar" butonuna basınca öğrenci ve şoför listesi Excel formatında hazırlanır.'},
      {'tip': 'adim',   'baslik': 'Metin Kopyala',
       'aciklama': 'Öğrenci Listesi, Şoför Listesi, Devamsızlık Raporu ve Genel Özet butonları bilgileri panoya kopyalar. WhatsApp\'a yapıştırabilirsiniz.'},
      {'tip': 'ipucu',  'baslik': 'Devamsızlık Raporu',
       'aciklama': 'Son 30 günlük devamsızlıklar listelenir. Velinin gönderdiği bildirimler burada görünür.'},
    ],

    'Ayarlar': [
      {'tip': 'bilgi',  'baslik': 'Ayarlar',
       'aciklama': 'Firma profili, bildirim ayarları, kullanıcı yönetimi ve sistem yapılandırmasını buradan yapabilirsiniz.'},
      {'tip': 'adim',   'baslik': 'Firma Profili',
       'aciklama': 'Firma adı, logo, adres ve iletişim bilgilerini güncelleyin. Bu bilgiler sözleşme PDF\'lerinde ve kayıt formlarında otomatik kullanılır.'},
      {'tip': 'adim',   'baslik': 'Kullanıcı Yönetimi',
       'aciklama': 'Yönetici, şoför ve veli hesaplarını buradan yönetebilirsiniz. Hesap askıya alma ve silme işlemleri burada yapılır.'},
      {'tip': 'ipucu',  'baslik': 'Bildirimler',
       'aciklama': 'Devamsızlık bildirimi, öğrenci bindi/indi ve servis başladı bildirimlerini açıp kapatabilirsiniz.'},
    ],

    'Fiyatlandirma': [
      {'tip': 'bilgi',  'baslik': 'Fiyat Sistemi',
       'aciklama': 'Üç farklı fiyatlandırma yöntemi: Mahalle bazlı, İlçe bazlı ve Kilometre bazlı. Veli adresini girince sistem otomatik fiyat hesaplar.'},
      {'tip': 'adim',   'baslik': 'Mahalle / İlçe Bazlı',
       'aciklama': '"Fiyat Ekle" sekmesinde ilçe ve mahalle seçip fiyat girin. Veli o mahalleden kayıt yaptırınca bu fiyat otomatik atanır.'},
      {'tip': 'adim',   'baslik': 'Km Bazlı Fiyat',
       'aciklama': '"Km Bazlı" sekmesinde iki yöntem var: Kademe (0-5km: 1500 TL) veya Birim fiyat (Baz + km×fiyat formülü).'},
      {'tip': 'ipucu',  'baslik': 'Öncelik Sırası',
       'aciklama': 'Sistem önce mahalleye bakar, bulamazsa ilçeye, sonra km bazlı hesaplar. En spesifik fiyat geçerlidir.'},
      {'tip': 'uyari',  'baslik': 'Fiyat Sözleşmeye İşlenir',
       'aciklama': 'Hesaplanan fiyat otomatik olarak sözleşmeye ve PDF\'e işlenir. Velinin onaylaması gereken ücret buradaki fiyattır.'},
    ],

    'Sofor Paneli': [
      {'tip': 'bilgi',  'baslik': 'Şoför Paneli',
       'aciklama': 'Bu ekran şoförlere özeldir. Öğrenci listesi, güzergah, devamsızlık bildirimi ve canlı navigasyon özelliklerini içerir.'},
      {'tip': 'adim',   'baslik': 'Servisi Başlat',
       'aciklama': 'Turuncu "Servisi Başlat" butonuna basınca konumunuz yayınlanmaya başlar ve veliler sizi haritada görür.'},
      {'tip': 'adim',   'baslik': 'Öğrenci Listesi',
       'aciklama': 'Her öğrencinin yanındaki ✓ butonuna basarak öğrencinin bindi bilgisini kaydedin. Veli anlık bildirim alır.'},
      {'tip': 'adim',   'baslik': 'Devamsızlık',
       'aciklama': 'Öğrenci gelmeyecekse "Devamsız" butonuna basın. Veliye otomatik bildirim gider.'},
      {'tip': 'ipucu',  'baslik': 'Navigasyon',
       'aciklama': 'Öğrenci adresine tıklayarak Google Maps navigasyonu açabilirsiniz.'},
      {'tip': 'uyari',  'baslik': 'Çoklu Görev',
       'aciklama': 'Sabah ve akşam farklı projelerde göreviniz varsa, giriş yapınca proje seçim ekranı açılır. Doğru projeyi seçin.'},
    ],

    'Veli Paneli': [
      {'tip': 'bilgi',  'baslik': 'Veli Paneli',
       'aciklama': 'Çocuğunuzun servis durumunu anlık takip edebileceğiniz ekrandır. Bindi/inmedi bilgisi, şoför konumu ve devamsızlık bildirimi burada.'},
      {'tip': 'adim',   'baslik': 'Canlı Konum',
       'aciklama': 'Harita bölümünde servis aracının anlık konumunu görebilirsiniz. Araç yaklaşınca bildirim alırsınız.'},
      {'tip': 'adim',   'baslik': 'Devamsızlık Bildir',
       'aciklama': 'Çocuğunuz servise binmeyecekse sabah servis saatinden en az 30 dakika önce "Bugün Gelmiyor" butonuna basın.'},
      {'tip': 'adim',   'baslik': 'Şoförle İletişim',
       'aciklama': 'Şoförün telefon numarasına tıklayarak arayabilir veya WhatsApp ile mesaj atabilirsiniz.'},
      {'tip': 'ipucu',  'baslik': 'Bindi Bildirimi',
       'aciklama': 'Çocuğunuz servise binerken şoför sisteme kaydeder, siz anlık bildirim alırsınız.'},
    ],

    'Projeler': [
      {'tip': 'bilgi',  'baslik': 'Proje Sistemi',
       'aciklama': 'Her proje tamamen bağımsızdır. Farklı okullar, dönemler veya servis türleri için ayrı projeler oluşturun.'},
      {'tip': 'adim',   'baslik': 'Proje Oluştur',
       'aciklama': '"Yeni Proje Oluştur" butonuna basın. Proje adı, dönem ve türü seçin. Okul, Kolej veya Personel servisi için ayrı projeler açabilirsiniz.'},
      {'tip': 'adim',   'baslik': 'Proje Sekmeleri',
       'aciklama': 'Her proje 8 sekme içerir: Genel, Servisler, Harita, Öğrenciler, Şoförler, Araçlar, Sözleşme, Fiyat, Kayıt Linki.'},
      {'tip': 'adim',   'baslik': 'Sözleşme Şablonu',
       'aciklama': 'Sözleşme sekmesinde bu projeye özel şablon seçin. Veliler kayıt formunda bu şablonu görecektir.'},
      {'tip': 'ipucu',  'baslik': 'Proje Değiştirme',
       'aciklama': 'Sol üstteki proje seçiciden aktif projeyi değiştirebilirsiniz. Tüm ekranlar seçili projeye göre güncellenir.'},
    ],

    'Arsiv': [
      {'tip': 'bilgi',  'baslik': 'Arşiv Sistemi',
       'aciklama': 'İmzalanan sözleşmeler kalıcı olarak arşivlenir. Hiçbir sözleşme tamamen silinemez, sadece arşive kaldırılabilir.'},
      {'tip': 'adim',   'baslik': 'Durum Akışı',
       'aciklama': 'Sözleşmeler şu aşamalardan geçer: Taslak → Onay Bekliyor → İmzalandı → Arşivlendi. Her aşamada tarih ve işlemi yapan kişi kaydedilir.'},
      {'tip': 'adim',   'baslik': 'Filtreleme',
       'aciklama': 'Üstteki filtrelerden duruma göre sözleşmeleri bulabilirsiniz. Tarih aralığı ve proje bazlı filtreleme de desteklenir.'},
      {'tip': 'adim',   'baslik': 'PDF İndir',
       'aciklama': 'Her sözleşmenin yanındaki PDF butonuna basarak o sözleşmenin PDF\'ini indirebilirsiniz.'},
      {'tip': 'uyari',  'baslik': 'İptal Edilen Sözleşmeler',
       'aciklama': 'İptal edilen sözleşmeler sistemde görünür olmaya devam eder. Tamamen gizlemek için "Arşive Kaldır" seçeneğini kullanın.'},
    ],

    'Genel': [
      {'tip': 'bilgi',  'baslik': 'Servisim360 Hakkında',
       'aciklama': 'Servisim360, okul ve personel servis firmalarına özel akıllı yönetim sistemidir. Web ve mobil uyumludur.'},
      {'tip': 'adim',   'baslik': 'Temel Akış',
       'aciklama': 'Proje oluştur → Servis ekle → Öğrenci kaydet → Sözleşme imzala → Rota oluştur → Canlı takip. Bu sırayı takip edin.'},
      {'tip': 'ipucu',  'baslik': 'AI Asistan',
       'aciklama': 'Her sayfada sağ üstteki AI butonuna tıklayarak yapay zeka destekli yardım alabilirsiniz. Sorularınızı yazarak veya sesli sorabilirsiniz.'},
      {'tip': 'uyari',  'baslik': 'Proje Seçimi Önemli',
       'aciklama': 'Sisteme girince ilk olarak çalışacağınız projeyi seçin. Yanlış projede veri göremeyebilirsiniz.'},
    ],
  };
}

// ════════════════════════════════════════════════════════════════
// YARDIM FAB — Sabit yardım butonu (her sayfaya eklenebilir)
// ════════════════════════════════════════════════════════════════
class YardimFab extends StatelessWidget {
  final String ekranAdi;
  const YardimFab({super.key, required this.ekranAdi});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      backgroundColor: const Color(0xFF1a3a6b),
      foregroundColor: Colors.white,
      tooltip: 'Yardım & Sesli Rehber',
      onPressed: () => YardimPanel.goster(context, ekranAdi),
      child: const Icon(Icons.help_outline_rounded, size: 20),
    );
  }
}
