import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Servisim360 — Crashlytics Hata Takip Servisi
class CrashlyticsService {
  CrashlyticsService._();
  static final CrashlyticsService instance = CrashlyticsService._();

  // ── Başlat ────────────────────────────────────────────────────────────────
  Future<void> baslat() async {
    // Debug modda crashlytics'i devre disi birak
    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(!kDebugMode);

    // Flutter hata yakalayici
    FlutterError.onError =
        FirebaseCrashlytics.instance.recordFlutterFatalError;

    // Dart async hatalari
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    debugPrint('Crashlytics baslatildi (debug: $kDebugMode)');
  }

  // ── Kullanici Bilgisi Ayarla ───────────────────────────────────────────────
  Future<void> kullaniciBilgisiAyarla({
    required String uid,
    required String rol,
    String? firmaId,
  }) async {
    try {
      await FirebaseCrashlytics.instance.setUserIdentifier(uid);
      await FirebaseCrashlytics.instance.setCustomKey('rol', rol);
      if (firmaId != null) {
        await FirebaseCrashlytics.instance.setCustomKey('firmaId', firmaId);
      }
    } catch (_) {}
  }

  // ── Hata Kaydet ───────────────────────────────────────────────────────────
  Future<void> hataKaydet(
      dynamic hata,
      StackTrace? stack, {
        String? aciklama,
        bool fatal = false,
      }) async {
    try {
      if (aciklama != null) {
        await FirebaseCrashlytics.instance.log(aciklama);
      }
      await FirebaseCrashlytics.instance.recordError(
        hata, stack, fatal: fatal,
      );
    } catch (_) {}
  }

  // ── Log ───────────────────────────────────────────────────────────────────
  Future<void> log(String mesaj) async {
    try {
      await FirebaseCrashlytics.instance.log(mesaj);
    } catch (_) {}
  }
}
