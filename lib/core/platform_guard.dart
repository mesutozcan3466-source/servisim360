import 'package:flutter/foundation.dart';

class PlatformGuard {
  // Web'de çalışmayan özellikler için kontrol
  static bool get isMobileOnly => !kIsWeb;
  static bool get isWeb => kIsWeb;

  // Rol bazlı platform kısıtı
  // Şoför ekranları sadece mobilde açılır
  static bool canAccessDriverFeatures() => !kIsWeb;

  // QR okuma sadece mobilde
  static bool canScanQR() => !kIsWeb;

  // OCR sadece mobilde
  static bool canUseOCR() => !kIsWeb;

  // Canlı konum takibi her yerde
  static bool canTrackLocation() => true;

  // Harita her yerde
  static bool canShowMap() => true;

  // Admin paneli her yerde
  static bool canAccessAdmin() => true;

  // Veli paneli her yerde
  static bool canAccessParent() => true;
}