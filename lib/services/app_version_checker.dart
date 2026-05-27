import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Uygulama versiyon kontrolü.
/// Firestore'daki 'sistem_ayarlari/versiyon' belgesiyle karşılaştırır.
///
/// Firestore belgesi yapısı:
/// sistem_ayarlari/versiyon → {
///   minVersiyon: "1.0.0",      // zorunlu güncelleme eşiği
///   onerilenVersiyon: "1.0.2", // önerilen sürüm
/// }

enum VersizonDurum {
  guncel,
  onerilenGuncelleme,
  zorunluGuncelleme,
}

class AppVersionChecker {
  /// Uygulamanın mevcut sürümü — pubspec.yaml ile eşleşmeli
  static const String mevcutVersiyon = '1.0.0';

  /// Firestore'daki versiyon belgesiyle karşılaştırır.
  static Future<VersizonDurum> kontrol() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('sistem_ayarlari')
          .doc('versiyon')
          .get();

      if (!doc.exists) return VersizonDurum.guncel;

      final data             = doc.data()!;
      final minVersiyon      = data['minVersiyon']      as String? ?? '1.0.0';
      final onerilenVersiyon = data['onerilenVersiyon'] as String? ?? '1.0.0';

      if (_versizonKucukMu(mevcutVersiyon, minVersiyon)) {
        return VersizonDurum.zorunluGuncelleme;
      }
      if (_versizonKucukMu(mevcutVersiyon, onerilenVersiyon)) {
        return VersizonDurum.onerilenGuncelleme;
      }
      return VersizonDurum.guncel;

    } catch (e) {
      debugPrint('AppVersionChecker kontrol hatası: $e');
      return VersizonDurum.guncel; // Hata durumunda güncelleme zorlamayalım
    }
  }

  /// v1 < v2 ise true döner.
  /// "1.0.0" formatındaki versiyonları karşılaştırır.
  static bool _versizonKucukMu(String v1, String v2) {
    try {
      final p1 = v1.split('.').map(int.parse).toList();
      final p2 = v2.split('.').map(int.parse).toList();

      // Kısa olan listeyi 0 ile tamamla
      while (p1.length < 3) p1.add(0);
      while (p2.length < 3) p2.add(0);

      for (int i = 0; i < 3; i++) {
        if (p1[i] < p2[i]) return true;
        if (p1[i] > p2[i]) return false;
      }
      return false; // Eşit
    } catch (e) {
      return false;
    }
  }
}
