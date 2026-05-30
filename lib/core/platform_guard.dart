import 'package:flutter/foundation.dart';

class PlatformGuard {
  // ── Platform tespiti ──────────────────────────────────────────
  static bool get isWeb    => kIsWeb;
  static bool get isMobile => !kIsWeb;

  // ── Rol bazlı web erişim kontrolü ────────────────────────────
  // Web'de tam yetkili roller
  static bool webdeYetkili(String rol) {
    return rol == 'superAdmin' ||
        rol == 'admin'      ||
        rol == 'firmaAdmin' ||
        rol == 'kolejAdmin';
  }

  // Sadece mobilde çalışan özellikler
  static bool get gpsKullanabilir         => isMobile;
  static bool get qrTarayabilir           => isMobile;
  static bool get ocrKullanabilir         => isMobile;
  static bool get sesliYonlendirme        => isMobile;
  static bool get arkaplanServis          => isMobile;
  static bool get canliKonumPaylasabilir  => isMobile;

  // Her platformda çalışan özellikler
  static bool get haritaGorebilir         => true;
  static bool get raporGorebilir          => true;
  static bool get bildirimAlabilir        => true;
  static bool get ogrenciYonetebilir      => true;
  static bool get surucuYonetebilir       => true;

  // Web'e özel özellikler
  static bool get webPaneliGorebilir      => isWeb;
  static bool get genisEkranLayout        => isWeb;
}