import 'package:flutter_tts/flutter_tts.dart';

/// Servisim360 — Sesli Yönlendirme Servisi
/// Şoföre sıradaki durak, yakınlık ve öğrenci bilgilerini sesli olarak bildirir.
class SesliYonlendirmeServisi {
  static final SesliYonlendirmeServisi _instance =
  SesliYonlendirmeServisi._internal();
  factory SesliYonlendirmeServisi() => _instance;
  SesliYonlendirmeServisi._internal();

  final FlutterTts _tts = FlutterTts();
  bool _hazir = false;
  bool _aktif = true; // kullanıcı kapatabilir

  // Son söylenen mesajı takip et (tekrar etmesin)
  String? _sonMesaj;
  DateTime? _sonMesajZamani;
  static const int _tekrarEngelleSaniye = 15;

  // ─── BAŞLAT ─────────────────────────────────────────────────────
  Future<void> baslat() async {
    if (_hazir) return;
    try {
      await _tts.setLanguage('tr-TR');
      await _tts.setSpeechRate(0.5);   // konuşma hızı (0.0–1.0)
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      // Android için ses kanalı ayarı
      await _tts.setEngine('com.google.android.tts');

      _tts.setStartHandler(() {});
      _tts.setCompletionHandler(() {});
      _tts.setErrorHandler((msg) {});

      _hazir = true;
    } catch (e) {
      // TTS başlatılamazsa sessizce devam et
    }
  }

  // ─── AKTİF/PASİF ────────────────────────────────────────────────
  void sesliAcik(bool deger) => _aktif = deger;
  bool get aktifMi => _aktif;

  // ─── DURDUR ─────────────────────────────────────────────────────
  Future<void> durdur() async {
    await _tts.stop();
  }

  Future<void> dispose() async {
    await _tts.stop();
    _hazir = false;
  }

  // ─── SÖYLE ──────────────────────────────────────────────────────
  Future<void> soyle(String mesaj, {bool zorla = false}) async {
    if (!_aktif) return;
    if (!_hazir) await baslat();

    // Aynı mesajı kısa süre içinde tekrar etme
    if (!zorla && _sonMesaj == mesaj && _sonMesajZamani != null) {
      final gecenSaniye =
          DateTime.now().difference(_sonMesajZamani!).inSeconds;
      if (gecenSaniye < _tekrarEngelleSaniye) return;
    }

    _sonMesaj = mesaj;
    _sonMesajZamani = DateTime.now();

    try {
      await _tts.stop();
      await _tts.speak(mesaj);
    } catch (_) {}
  }

  // ─── HAZIR MESAJLAR ─────────────────────────────────────────────

  /// Servis başladığında
  Future<void> servisBasladi() =>
      soyle('Servis başladı. İyi yolculuklar.', zorla: true);

  /// Servis durduğunda
  Future<void> servisDurdu() =>
      soyle('Servis durduruldu.', zorla: true);

  /// Sıradaki durağa yönlendir
  Future<void> siradakiDurak(String durakAd, String? eta) {
    final etaMetin = eta != null ? ', tahmini süre $eta' : '';
    return soyle('Sıradaki durak: $durakAd$etaMetin');
  }

  /// Durağa yaklaşıldı (200m)
  Future<void> duragaYaklasiliyor(String durakAd) =>
      soyle('$durakAd durağına yaklaşıyorsunuz. Hazır olun.');

  /// Durağa ulaşıldı (50m)
  Future<void> duragaUlasildi(String durakAd) =>
      soyle('$durakAd durağındasınız. Öğrencileri bekleyin.', zorla: true);

  /// Durak tamamlandı, sonraki durağa geç
  Future<void> durakTamamlandi(String? sonrakiDurakAd) {
    if (sonrakiDurakAd != null) {
      return soyle(
          'Durak tamamlandı. Sonraki durak: $sonrakiDurakAd');
    }
    return soyle(
        'Son durak tamamlandı. Okula gidiyorsunuz.', zorla: true);
  }

  /// Öğrenci bindirme bildirimi
  Future<void> ogrenciBindi(String ogrenciAd) =>
      soyle('$ogrenciAd bindi.');

  /// Tüm öğrenciler bindi
  Future<void> tumOgrencilerBindi() =>
      soyle('Tüm öğrenciler bindi. Okula gidebilirsiniz.', zorla: true);

  /// Veli gelmeyecek bildirimi
  Future<void> ogrenciGelmeyecek(String ogrenciAd) =>
      soyle('$ogrenciAd bugün servise gelmeyecek.',
          zorla: true);

  /// Okula yaklaşıldı
  Future<void> okulaYaklasiliyor() =>
      soyle('Okula yaklaşıyorsunuz.', zorla: true);

  /// Rota tamamlandı
  Future<void> rotaTamamlandi() =>
      soyle('Rota tamamlandı. İyi günler.', zorla: true);

  /// Genel bildirim
  Future<void> bildirim(String mesaj, {bool zorla = false}) => soyle(mesaj, zorla: zorla);
}
