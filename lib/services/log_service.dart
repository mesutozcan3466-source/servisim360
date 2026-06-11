import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ======================================================================
// LOG SERVICE  --  Servisim360
// Tum kritik islemleri hareket_kayitlari koleksiyonuna yazar.
// Kullanim: LogService.instance.kaydet(...)
// ======================================================================

enum LogTip {
  giris,
  cikis,
  ogrenciEklendi,
  ogrenciSilindi,
  ogrenciGuncellendi,
  soforEklendi,
  soforSilindi,
  servisOlusturuldu,
  servisSilindi,
  servisGuncellendi,
  fiyatDegistirildi,
  sozlesmeDegistirildi,
  sifreSifirlandi,
  personelEklendi,
  personelSilindi,
  acilDurum,
  lisansVerildi,
  firmaOlusturuldu,
  firmaPasifAlindi,
  yedekAlindi,
}

class LogService {
  LogService._();
  static final LogService instance = LogService._();

  final _db   = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Mevcut kullanici bilgisi
  User? get _kullanici => _auth.currentUser;

  // ------------------------------------------------------------------
  // Ana kayit metodu
  // ------------------------------------------------------------------
  Future<void> kaydet({
    required LogTip tip,
    required String firmaId,
    String? hedefId,       // silinen/eklenen dokuman id
    String? hedefAdi,      // okunabilir isim (Ali Yilmaz, 34 ABC 123 gibi)
    String? aciklama,
    Map<String, dynamic>? ekBilgi,
  }) async {
    try {
      final user = _kullanici;
      if (user == null) return;

      await _db.collection('hareket_kayitlari').add({
        'tip':          tip.name,
        'firmaId':      firmaId,
        'kullaniciId':  user.uid,
        'kullaniciEmail': user.email ?? '',
        'hedefId':      hedefId,
        'hedefAdi':     hedefAdi,
        'aciklama':     aciklama ?? _varsayilanAciklama(tip, hedefAdi),
        'ekBilgi':      ekBilgi,
        'tarih':        FieldValue.serverTimestamp(),
        'platform':     'flutter',
      });
    } catch (e) {
      // Log hatasi uygulamayi durdurmasin
      // ignore
    }
  }

  // ------------------------------------------------------------------
  // Oturum loglari
  // ------------------------------------------------------------------
  Future<void> girisKaydet(String firmaId) async {
    await kaydet(
      tip:     LogTip.giris,
      firmaId: firmaId,
      aciklama: 'Kullanici sisteme giris yapti',
    );

    // Son giris ve cihaz bilgisini kullanicilar koleksiyonuna yaz
    final user = _kullanici;
    if (user == null) return;
    try {
      await _db.collection('kullanicilar').doc(user.uid).update({
        'sonGiris':    FieldValue.serverTimestamp(),
        'toplamGirisSayisi': FieldValue.increment(1),
      });
    } catch (_) {}
  }

  Future<void> cikisKaydet(String firmaId) async {
    await kaydet(
      tip:     LogTip.cikis,
      firmaId: firmaId,
      aciklama: 'Kullanici sistemden cikis yapti',
    );
  }

  // ------------------------------------------------------------------
  // Ogrenci loglari
  // ------------------------------------------------------------------
  Future<void> ogrenciEklendi(String firmaId, String ogrenciId, String ad) =>
      kaydet(
        tip:      LogTip.ogrenciEklendi,
        firmaId:  firmaId,
        hedefId:  ogrenciId,
        hedefAdi: ad,
        aciklama: '$ad adli ogrenci sisteme eklendi',
      );

  Future<void> ogrenciSilindi(String firmaId, String ogrenciId, String ad) =>
      kaydet(
        tip:      LogTip.ogrenciSilindi,
        firmaId:  firmaId,
        hedefId:  ogrenciId,
        hedefAdi: ad,
        aciklama: '$ad adli ogrenci silindi',
      );

  // ------------------------------------------------------------------
  // Sofor loglari
  // ------------------------------------------------------------------
  Future<void> soforEklendi(String firmaId, String soforId, String ad) =>
      kaydet(
        tip:      LogTip.soforEklendi,
        firmaId:  firmaId,
        hedefId:  soforId,
        hedefAdi: ad,
        aciklama: '$ad adli sofor eklendi',
      );

  Future<void> soforSilindi(String firmaId, String soforId, String ad) =>
      kaydet(
        tip:      LogTip.soforSilindi,
        firmaId:  firmaId,
        hedefId:  soforId,
        hedefAdi: ad,
        aciklama: '$ad adli sofor silindi',
      );

  // ------------------------------------------------------------------
  // Servis loglari
  // ------------------------------------------------------------------
  Future<void> servisOlusturuldu(String firmaId, String servisId, String plaka) =>
      kaydet(
        tip:      LogTip.servisOlusturuldu,
        firmaId:  firmaId,
        hedefId:  servisId,
        hedefAdi: plaka,
        aciklama: '$plaka plakali servis olusturuldu',
      );

  Future<void> servisSilindi(String firmaId, String servisId, String plaka) =>
      kaydet(
        tip:      LogTip.servisSilindi,
        firmaId:  firmaId,
        hedefId:  servisId,
        hedefAdi: plaka,
        aciklama: '$plaka plakali servis silindi',
      );

  // ------------------------------------------------------------------
  // Kritik islem loglari
  // ------------------------------------------------------------------
  Future<void> fiyatDegistirildi(String firmaId, String eskiFiyat, String yeniFiyat) =>
      kaydet(
        tip:      LogTip.fiyatDegistirildi,
        firmaId:  firmaId,
        aciklama: 'Fiyat guncellendi: $eskiFiyat -> $yeniFiyat',
        ekBilgi:  {'eskiFiyat': eskiFiyat, 'yeniFiyat': yeniFiyat},
      );

  Future<void> sozlesmeDegistirildi(String firmaId, String sozlesmeId) =>
      kaydet(
        tip:      LogTip.sozlesmeDegistirildi,
        firmaId:  firmaId,
        hedefId:  sozlesmeId,
        aciklama: 'Sozlesme guncellendi',
      );

  Future<void> sifreSifirlandi(String firmaId, String hedefEmail) =>
      kaydet(
        tip:      LogTip.sifreSifirlandi,
        firmaId:  firmaId,
        hedefAdi: hedefEmail,
        aciklama: '$hedefEmail hesabinin sifresi sifirlandi',
      );

  Future<void> acilDurumBildirimi(String firmaId, String soforAd, String plaka) =>
      kaydet(
        tip:      LogTip.acilDurum,
        firmaId:  firmaId,
        hedefAdi: plaka,
        aciklama: '$soforAd - $plaka: ACIL DURUM bildirimi gonderdi',
        ekBilgi:  {'soforAd': soforAd, 'plaka': plaka},
      );

  // ------------------------------------------------------------------
  // Lisans / Firma loglari (SuperAdmin)
  // ------------------------------------------------------------------
  Future<void> lisansVerildi(String firmaId, String sureTip) =>
      kaydet(
        tip:      LogTip.lisansVerildi,
        firmaId:  firmaId,
        aciklama: 'Lisans verildi: $sureTip',
        ekBilgi:  {'sureTip': sureTip},
      );

  Future<void> firmaOlusturuldu(String firmaId, String firmaAdi) =>
      kaydet(
        tip:      LogTip.firmaOlusturuldu,
        firmaId:  firmaId,
        hedefAdi: firmaAdi,
        aciklama: '$firmaAdi firmasi olusturuldu',
      );

  // ------------------------------------------------------------------
  // Log listesi cekme (FirmaAdmin / SuperAdmin icin)
  // ------------------------------------------------------------------
  Future<List<Map<String, dynamic>>> firmaLoglariniGetir({
    required String firmaId,
    int limit = 50,
    LogTip? tipFiltre,
  }) async {
    try {
      Query query = _db
          .collection('hareket_kayitlari')
          .where('firmaId', isEqualTo: firmaId)
          .orderBy('tarih', descending: true)
          .limit(limit);

      if (tipFiltre != null) {
        query = query.where('tip', isEqualTo: tipFiltre.name);
      }

      final snap = await query.get();
      return snap.docs.map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>}).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> tumLoglarGetir({int limit = 100}) async {
    try {
      final snap = await _db
          .collection('hareket_kayitlari')
          .orderBy('tarih', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>}).toList();
    } catch (_) {
      return [];
    }
  }

  // ------------------------------------------------------------------
  // Varsayilan aciklama
  // ------------------------------------------------------------------
  String _varsayilanAciklama(LogTip tip, String? hedef) {
    final h = hedef != null ? ' ($hedef)' : '';
    switch (tip) {
      case LogTip.giris:               return 'Giris yapildi';
      case LogTip.cikis:               return 'Cikis yapildi';
      case LogTip.ogrenciEklendi:      return 'Ogrenci eklendi$h';
      case LogTip.ogrenciSilindi:      return 'Ogrenci silindi$h';
      case LogTip.ogrenciGuncellendi:  return 'Ogrenci guncellendi$h';
      case LogTip.soforEklendi:        return 'Sofor eklendi$h';
      case LogTip.soforSilindi:        return 'Sofor silindi$h';
      case LogTip.servisOlusturuldu:   return 'Servis olusturuldu$h';
      case LogTip.servisSilindi:       return 'Servis silindi$h';
      case LogTip.servisGuncellendi:   return 'Servis guncellendi$h';
      case LogTip.fiyatDegistirildi:   return 'Fiyat degistirildi';
      case LogTip.sozlesmeDegistirildi:return 'Sozlesme guncellendi$h';
      case LogTip.sifreSifirlandi:     return 'Sifre sifirlandi$h';
      case LogTip.personelEklendi:     return 'Personel eklendi$h';
      case LogTip.personelSilindi:     return 'Personel silindi$h';
      case LogTip.acilDurum:           return 'ACIL DURUM$h';
      case LogTip.lisansVerildi:       return 'Lisans verildi$h';
      case LogTip.firmaOlusturuldu:    return 'Firma olusturuldu$h';
      case LogTip.firmaPasifAlindi:    return 'Firma pasife alindi$h';
      case LogTip.yedekAlindi:         return 'Yedek alindi';
    }
  }
}
