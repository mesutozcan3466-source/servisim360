import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Servisim360 — Firebase Remote Config Servisi
/// API key ve diger konfigurasyonlari guvenli sekilde yonetir.
class RemoteConfigService {
  RemoteConfigService._();
  static final RemoteConfigService instance = RemoteConfigService._();

  final _rc = FirebaseRemoteConfig.instance;
  bool _baslatildi = false;

  // Varsayilan degerler — Firebase'den alinamazsa bunlar kullanilir
  static const _varsayilanlar = {
    'claude_api_key':        '',       // BURAYI BOŞ BIRAK — Firebase'den gelecek
    'servis_sabah_baslangic': '06:30',
    'servis_sabah_bitis':    '09:30',
    'servis_aksam_baslangic': '15:00',
    'servis_aksam_bitis':    '18:30',
    'ai_asistan_aktif':      true,
    'ai_max_tokens':         200,
    'hata_bildirimi_aktif':  true,
  };

  // ── Başlat ────────────────────────────────────────────────────────────────
  Future<void> baslat() async {
    if (_baslatildi) return;
    try {
      await _rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout:         const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await _rc.setDefaults(_varsayilanlar);
      await _rc.fetchAndActivate();
      _baslatildi = true;
      debugPrint('RemoteConfig baslatildi');
    } catch (e) {
      debugPrint('RemoteConfig hata: $e — varsayilanlar kullanilacak');
      _baslatildi = true; // Hata olsa da devam et
    }
  }

  // ── Claude API Key ─────────────────────────────────────────────────────────
  String get claudeApiKey {
    final key = _rc.getString('claude_api_key');
    if (key.isEmpty) {
      debugPrint('UYARI: claude_api_key bos! Firebase Remote Config kontrol edin.');
    }
    return key;
  }

  // ── Servis Saatleri ────────────────────────────────────────────────────────
  String get servisSabahBaslangic =>
      _rc.getString('servis_sabah_baslangic');
  String get servisSabahBitis =>
      _rc.getString('servis_sabah_bitis');
  String get servisAksamBaslangic =>
      _rc.getString('servis_aksam_baslangic');
  String get servisAksamBitis =>
      _rc.getString('servis_aksam_bitis');

  // Saat string'ini TimeOfDay'e cevirir ("06:30" -> TimeOfDay(hour:6, minute:30))
  static _SaatBilgisi saatiCozumle(String saat) {
    try {
      final parts = saat.split(':');
      return _SaatBilgisi(
        saat:   int.parse(parts[0]),
        dakika: int.parse(parts[1]),
      );
    } catch (_) {
      return _SaatBilgisi(saat: 6, dakika: 30);
    }
  }

  // ── AI Asistan ─────────────────────────────────────────────────────────────
  bool get aiAsistanAktif => _rc.getBool('ai_asistan_aktif');
  int  get aiMaxTokens    => _rc.getInt('ai_max_tokens');

  // ── Diger ─────────────────────────────────────────────────────────────────
  bool get hataBildirimiAktif => _rc.getBool('hata_bildirimi_aktif');

  // ── Yenile ────────────────────────────────────────────────────────────────
  Future<void> yenile() async {
    try {
      await _rc.fetchAndActivate();
    } catch (e) {
      debugPrint('RemoteConfig yenileme hatasi: $e');
    }
  }
}

class _SaatBilgisi {
  final int saat;
  final int dakika;
  const _SaatBilgisi({required this.saat, required this.dakika});
}
