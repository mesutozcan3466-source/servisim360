// ======================================================================
// YETKI SERVICE  --  Servisim360
// Merkezi yetki matrisi. Rol bazli izin kontrolu.
// Kullanim: YetkiService.instance.izinVarMi(rol, Izin.ogrenciEkle)
// ======================================================================

enum Izin {
  // Firma islemleri
  firmaOlustur,
  firmaGor,
  firmaDuzenle,
  firmaSil,

  // Lisans islemleri
  lisansVer,
  lisansIptal,
  lisansGor,

  // Ogrenci islemleri
  ogrenciEkle,
  ogrenciSil,
  ogrenciDuzenle,
  ogrenciGor,

  // Sofor islemleri
  soforEkle,
  soforSil,
  soforDuzenle,
  soforGor,

  // Servis islemleri
  servisOlustur,
  servisSil,
  servisDuzenle,
  servisGor,
  servisBaslat,

  // Veli islemleri
  veliEkle,
  veliGor,
  veliSil,

  // Personel islemleri
  personelEkle,
  personelSil,
  personelGor,

  // Fiyat / Sozlesme
  fiyatGor,
  fiyatDuzenle,
  sozlesmeGor,
  sozlesmeDuzenle,

  // Raporlar
  raporGor,
  raporIndir,

  // Log / Guvenlik
  logGor,
  sifreSifirla,

  // Devamsizlik
  devamsizlikBildir,
  devamsizlikGor,
  devamsizlikOnayla,

  // Plaka / QR
  plakaKaydet,
  plakaGor,

  // Harita
  haritaGor,
  canliKonumGor,

  // Sistem
  sistemAyarlari,
  yedekAl,
}

class YetkiService {
  YetkiService._();
  static final YetkiService instance = YetkiService._();

  // ------------------------------------------------------------------
  // YETKI MATRISI
  // ------------------------------------------------------------------
  static const Map<String, Set<Izin>> _matris = {

    // SUPER ADMIN
    'superAdmin': {
      Izin.firmaOlustur, Izin.firmaGor, Izin.firmaDuzenle, Izin.firmaSil,
      Izin.lisansVer, Izin.lisansIptal, Izin.lisansGor,
      Izin.logGor, Izin.sifreSifirla,
      Izin.sistemAyarlari, Izin.yedekAl,
      Izin.raporGor, Izin.raporIndir,
      // SuperAdmin operasyonel islemleri gormez (guvenlik geregi)
    },

    // FIRMA ADMIN
    'firmaAdmin': {
      Izin.firmaGor,
      Izin.ogrenciEkle, Izin.ogrenciSil, Izin.ogrenciDuzenle, Izin.ogrenciGor,
      Izin.soforEkle, Izin.soforSil, Izin.soforDuzenle, Izin.soforGor,
      Izin.servisOlustur, Izin.servisSil, Izin.servisDuzenle, Izin.servisGor,
      Izin.veliEkle, Izin.veliGor, Izin.veliSil,
      Izin.personelEkle, Izin.personelSil, Izin.personelGor,
      Izin.fiyatGor, Izin.fiyatDuzenle,
      Izin.sozlesmeGor, Izin.sozlesmeDuzenle,
      Izin.raporGor, Izin.raporIndir,
      Izin.logGor,
      Izin.sifreSifirla,
      Izin.devamsizlikGor, Izin.devamsizlikOnayla,
      Izin.plakaKaydet, Izin.plakaGor,
      Izin.haritaGor, Izin.canliKonumGor,
      Izin.sistemAyarlari,
    },

    // KOLEJ ADMIN
    'kolejAdmin': {
      Izin.servisGor,
      Izin.ogrenciGor,
      Izin.soforGor,
      Izin.plakaGor,
      Izin.haritaGor,
      Izin.canliKonumGor,
      Izin.raporGor,
      // KolejAdmin fiyat ve sozlesme goremez
    },

    // SOFOR
    'sofor': {
      Izin.servisGor,
      Izin.servisBaslat,
      Izin.ogrenciGor,
      Izin.devamsizlikGor,
      Izin.plakaKaydet,
      Izin.haritaGor,
      Izin.canliKonumGor,
    },

    'bireyselSofor': {
      Izin.servisGor,
      Izin.servisBaslat,
      Izin.ogrenciGor,
      Izin.devamsizlikGor,
      Izin.plakaKaydet,
      Izin.haritaGor,
      Izin.canliKonumGor,
    },

    // VELI
    'veli': {
      Izin.ogrenciGor,
      Izin.servisGor,
      Izin.haritaGor,
      Izin.canliKonumGor,
      Izin.devamsizlikBildir,
      Izin.devamsizlikGor,
      Izin.sozlesmeGor,
    },

    // PERSONEL
    'personel': {
      Izin.servisGor,
      Izin.haritaGor,
      Izin.canliKonumGor,
      Izin.devamsizlikBildir,
      Izin.devamsizlikGor,
    },

    // SEKRETER (firma admin gibi ama bazi kisitlarla)
    'sekreter': {
      Izin.ogrenciEkle, Izin.ogrenciDuzenle, Izin.ogrenciGor,
      Izin.soforGor,
      Izin.servisGor,
      Izin.veliEkle, Izin.veliGor,
      Izin.devamsizlikGor, Izin.devamsizlikOnayla,
      Izin.plakaGor,
      Izin.haritaGor,
      Izin.raporGor,
    },
  };

  // ------------------------------------------------------------------
  // IZIN KONTROLU
  // ------------------------------------------------------------------
  bool izinVarMi(String rol, Izin izin) {
    final izinler = _matris[rol] ?? {};
    return izinler.contains(izin);
  }

  bool herhangiIzinVarMi(String rol, List<Izin> izinler) {
    return izinler.any((i) => izinVarMi(rol, i));
  }

  bool tumIzinlerVarMi(String rol, List<Izin> izinler) {
    return izinler.every((i) => izinVarMi(rol, i));
  }

  Set<Izin> rolunIzinleri(String rol) {
    return Set.unmodifiable(_matris[rol] ?? {});
  }

  // ------------------------------------------------------------------
  // ROL GRUPLARI
  // ------------------------------------------------------------------
  bool superAdminMi(String rol) =>
      rol == 'superAdmin' || rol == 'superadmin' || rol == 'super_admin';

  bool firmaAdminMi(String rol) =>
      rol == 'firmaAdmin' || rol == 'admin' ||
          rol == 'firma_admin' || rol == 'sekreter';

  bool kolejAdminMi(String rol) => rol == 'kolejAdmin';

  bool soforMu(String rol) => rol == 'sofor' || rol == 'bireyselSofor';

  bool veliMi(String rol) => rol == 'veli';

  bool personelMi(String rol) => rol == 'personel';

  bool operasyonelRolMu(String rol) =>
      soforMu(rol) || veliMi(rol) || personelMi(rol);

  // ------------------------------------------------------------------
  // UI YARDIMCISI - Widget gostermek icin
  // ------------------------------------------------------------------
  // Kullanim: if (YetkiService.instance.goster(rol, Izin.fiyatGor)) ...
  bool goster(String? rol, Izin izin) {
    if (rol == null) return false;
    return izinVarMi(rol, izin);
  }

  // ------------------------------------------------------------------
  // YETKI MATRISI TABLOSU (debug / SuperAdmin paneli icin)
  // ------------------------------------------------------------------
  Map<String, dynamic> matrisTablosu() {
    final tablo = <String, dynamic>{};
    for (final entry in _matris.entries) {
      tablo[entry.key] = entry.value.map((i) => i.name).toList();
    }
    return tablo;
  }
}
