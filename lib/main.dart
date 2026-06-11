// ╔══════════════════════════════════════════════════════════════╗
// ║  DOSYA: lib/main.dart                                        ║
// ║  Servisim360 — Ana Giriş Noktası                             ║
// ║  Tüm route'lar burada tanımlı                                ║
// ╚══════════════════════════════════════════════════════════════╝
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

// ── Servisler ────────────────────────────────────────────────────

// ── Temel Ekranlar ───────────────────────────────────────────────
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/kayit_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/onay_bekleme_screen.dart';
import 'screens/rol_yonlendirici.dart';

// ── Web Ekranları ────────────────────────────────────────────────
import 'screens/web_giris_yonlendirici.dart';
import 'screens/web_admin_panel.dart';
import 'screens/web_ayarlar.dart';
import 'screens/web_super_admin.dart';
import 'screens/web_sofor_panel.dart';
import 'screens/web_veli_panel.dart';
import 'screens/web_kolej_panel.dart';              // ← YENİ

// ── Dashboard & Yönlendirme ──────────────────────────────────────
import 'screens/dashboard_screen.dart';
import 'screens/proje_sec_screen.dart';

// ── Şoför Ekranları ──────────────────────────────────────────────
import 'screens/sofor_panel_screen.dart';
import 'screens/suruculer_screen.dart';
import 'screens/surucu_ekrani_screen.dart';
import 'screens/yoklama_screen.dart';

// ── Veli Ekranları ───────────────────────────────────────────────
import 'screens/veli_panel_screen.dart';
import 'screens/veli_sozlesme_screen.dart';
import 'screens/veli_basvuru_screen.dart';
import 'screens/veli_basvurular_screen.dart';
import 'screens/veli_kayit_link_screen.dart';
import 'screens/veli_kayit_yuz_yuze_scren.dart';

// ── Öğrenci & Kayıt ─────────────────────────────────────────────
import 'screens/ogrenciler_screen.dart';
import 'screens/ogrenci_paneli_screen.dart';
import 'screens/kayit_sistemi_screen.dart';
import 'screens/kayit_havuzu_screen.dart';
import 'screens/toplu_yukle_screen.dart';

// ── Harita & Rota ────────────────────────────────────────────────
import 'screens/harita_screen.dart';
import 'screens/gruplama_screen.dart';
import 'screens/rotalar_screen.dart';
import 'screens/servis_bolme_screen.dart';
import 'screens/canli_rota_screen.dart';
import 'screens/guzergah_gecmis_screen.dart';
import 'screens/admin_arac_takip_screen.dart';

// ── Proje & Servis ───────────────────────────────────────────────
import 'screens/projeler_screen.dart';
import 'screens/proje_arsiv_screen.dart';
import 'screens/servis_saati_screen.dart';
import 'screens/araclar_screen.dart';

// ── Fiyat & Sözleşme ─────────────────────────────────────────────
import 'screens/fiyat_yonetim_screen.dart';
import 'screens/sozlesme_yonetim_screen.dart';
import 'screens/sozlesme_screen.dart';

// ── Bildirim & Mesaj ─────────────────────────────────────────────
import 'screens/bildirimler_screen.dart';
import 'screens/toplu_mesaj_screen.dart';
import 'screens/toplu_whatsapp_screen.dart';
import 'screens/hazir_mesajlar_screen.dart';

// ── QR & Plaka ──────────────────────────────────────────────────
import 'screens/qr_olustur_screen.dart';
import 'screens/qr_okut_screen.dart';
import 'screens/qr_afis_screen.dart';
import 'screens/plaka_tanima_screen.dart';

// ── Analiz & Arşiv ──────────────────────────────────────────────
import 'screens/analiz_screen.dart';
import 'screens/arsiv_screen.dart';
import 'screens/gecmis_screen.dart';

// ── Ayarlar & Profil ─────────────────────────────────────────────
import 'screens/ayarlar_screen.dart';
import 'screens/sifre_degistir_screen.dart';

// ── AI & Yardım ──────────────────────────────────────────────────
import 'screens/ai_asistan_screen.dart';
import 'screens/global_ai_asistan.dart';

// ── Personel ─────────────────────────────────────────────────────
import 'screens/personel_panel_screen.dart';

// ────────────────────────────────────────────────────────────────
// BACKGROUND MESSAGE HANDLER (FCM)
// ────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Arka plan mesajı: ${message.messageId}');
}

// ────────────────────────────────────────────────────────────────
// MAIN
// ────────────────────────────────────────────────────────────────
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // FCM background handler (sadece mobilde)
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  runApp(const Servisim360App());
}

// ────────────────────────────────────────────────────────────────
// APP
// ────────────────────────────────────────────────────────────────
class Servisim360App extends StatelessWidget {
  const Servisim360App({super.key});

  @override
  Widget build(BuildContext context) {
    return GlobalAiAsistanWrapper(
      child: MaterialApp(
        title: 'Servisim360',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1a3a6b),
            primary: const Color(0xFF1a3a6b),
            secondary: const Color(0xFFFF8C00),
          ),
          useMaterial3: true,
          fontFamily: 'Roboto',
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1a3a6b),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1a3a6b),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        initialRoute: kIsWeb ? '/web' : '/',
        routes: _routes(),
        onUnknownRoute: (settings) => MaterialPageRoute(
          builder: (_) => const _BilinmeyenRoute(),
        ),
      ),
    );
  }

  Map<String, WidgetBuilder> _routes() => {
    // ── Başlangıç ───────────────────────────────────────────────
    '/':           (_) => const SplashScreen(),
    '/rol':        (_) => const RolYonlendirici(),
    '/login':      (_) => const LoginScreen(),
    '/kayit':      (_) => const KayitScreen(),
    '/onboarding': (_) => const OnboardingScreen(),
    '/onay_bekleme':(_)=> const OnayBeklemeScreen(),

    // ── Web ─────────────────────────────────────────────────────
    '/web':        (_) => const WebGirisYonlendirici(),
    '/web_admin':  (_) => const WebAdminPanel(),
    '/web_panel':  (_) => const WebSuperAdminSayfasi(),
    '/web_sofor':  (_) => const WebSoforPanel(),
    '/web_veli_panel': (_) => const WebVeliPanel(),
    '/web_ayarlar': (_) => const WebAyarlar(),
    '/web_kolej':  (_) => const WebKolejPanel(),          // ← YENİ

    // ── Dashboard & Proje Seç ────────────────────────────────────
    '/dashboard':  (_) => const DashboardScreen(),
    '/proje_sec':  (_) => const ProjeSecScreen(),
    '/projeler':   (_) => const ProjelerScreen(),
    '/proje_arsiv':(_) => const ProjeArsivScreen(),

    // ── Şoför Paneli ─────────────────────────────────────────────
    '/sofor_panel':(_) => const SoforPanelScreen(),
    '/suruculer':  (_) => const SurucularScreen(),
    '/surucu_ekrani':(_)=> const SurucuEkraniScreen(),
    '/yoklama':    (_) => const YoklamaScreen(),

    // ── Veli Paneli ──────────────────────────────────────────────
    '/veli_panel': (_) => const VeliPanelScreen(),
    '/veli_sozlesme':(_)=> const VeliSozlesmeScreen(),
    '/veli_basvuru':(_) => const VeliBasvuruFormScreen(),
    '/veli_basvurular':(_)=>const VeliBasvurularScreen(),
    '/kayit_link': (_) => const VeliKayitLinkiScreen(),
    '/yuz_yuze_kayit':(_)=> const VeliKayitYuzYuzeScreen(),

    // ── Öğrenci & Kayıt ─────────────────────────────────────────
    '/ogrenci':    (_) => const OgrencilerScreen(),
    '/ogrenci_panel':(_)=> const OgrenciPaneliScreen(),
    '/kayit_sistemi':(_)=> const KayitSistemiScreen(),
    '/kayit_havuzu':(_) => const KayitHavuzuScreen(),
    '/toplu_yukle':(_) => const TopluYukleScreen(),

    // ── Harita & Rota ────────────────────────────────────────────
    '/harita':     (_) => const HaritaScreen(),
    '/gruplama':   (_) => const GruplamaScreen(),
    '/rotalar':    (_) => const RotalarScreen(),
    '/servis_bolme':(_)=> const ServisBolmeScreen(),
    '/canli_rota': (_) => const CanliRotaScreen(),
    '/guzergah_gecmis':(_)=> const GuzergahGecmisScreen(),
    '/admin_takip':(_) => const AdminAracTakipScreen(),

    // ── Servis & Araç ────────────────────────────────────────────
    '/servis_saati':(_)=> const ServisSaatiScreen(),
    '/araclar':    (_) => const AraclarScreen(),

    // ── Fiyat & Sözleşme ─────────────────────────────────────────
    '/fiyat_yonetim':(_)=> const FiyatYonetimScreen(),
    '/sozlesme_yonetim':(_)=>const SozlesmeYonetimScreen(),
    '/sozlesme':   (_) => const SozlesmeScreen(),

    // ── Bildirim & Mesaj ─────────────────────────────────────────
    '/bildirimler':(_) => const BildirimlerScreen(),
    '/toplu_mesaj':(_) => const TopluMesajScreen(),
    '/toplu_whatsapp':(_)=>const TopluWhatsappScreen(),
    '/hazir_mesajlar':(_)=>const HazirMesajlarScreen(),

    // ── QR & Plaka ──────────────────────────────────────────────
    '/qr_olustur': (_) => const QrOlusturScreen(),
    '/qr_okut':    (_) => const QrOkutScreen(),
    '/qr_afis':    (_) => const QrAfisScreen(),
    '/plaka_tanima':(_)=> const PlakaTanimaScreen(),

    // ── Analiz & Arşiv ──────────────────────────────────────────
    '/analiz':     (_) => const AnalizScreen(),
    '/arsiv':      (_) => const ArsivScreen(),
    '/gecmis':     (_) => const GecmisScreen(),

    // ── Ayarlar ─────────────────────────────────────────────────
    '/ayarlar':    (_) => const AyarlarScreen(),
    '/sifre_degistir':(_)=>const SifreDegistirScreen(),

    // ── AI Asistan ───────────────────────────────────────────────
    '/ai_asistan': (_) => const AiAsistanScreen(),

    // ── Personel ─────────────────────────────────────────────────
    '/personel_panel':(_)=>const PersonelPanelScreen(),
  };
}

// ────────────────────────────────────────────────────────────────
// BİLİNMEYEN ROUTE
// ────────────────────────────────────────────────────────────────
class _BilinmeyenRoute extends StatelessWidget {
  const _BilinmeyenRoute();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: const Color(0xFF1a3a6b),
      foregroundColor: Colors.white,
      title: const Text('Sayfa Bulunamadı'),
    ),
    body: Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 72, color: Colors.grey[300]),
        const SizedBox(height: 16),
        const Text('Bu sayfa bulunamadı.',
            style: TextStyle(fontSize: 18, color: Colors.grey)),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1a3a6b),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          onPressed: () => Navigator.pushReplacementNamed(context, '/'),
          icon: const Icon(Icons.home_outlined),
          label: const Text('Ana Sayfaya Dön'),
        ),
      ],
    )),
  );
}
