import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class HataRaporlama {
  static void kur() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      _logla(details.exceptionAsString(), details.stack.toString());
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      _logla(error.toString(), stack.toString());
      return false;
    };
  }

  static Future<void> _logla(String hata, String stack) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      await FirebaseFirestore.instance.collection('hata_kayitlari').add({
        'hata':    hata,
        'stack':   stack.length > 500 ? stack.substring(0, 500) : stack,
        'uid':     uid,
        'tarih':   FieldValue.serverTimestamp(),
        'platform': defaultTargetPlatform.name,
      });
    } catch (_) {
      // Loglama hatası sessizce geç
    }
  }

  static Future<void> hataRaporla(dynamic hata, StackTrace? stack) async {
    await _logla(hata.toString(), stack?.toString() ?? '');
  }
}