// ╔══════════════════════════════════════════════════════════════╗
// ║  DOSYA: lib/main.dart
// ║  PROJE: servisim360
// ╚══════════════════════════════════════════════════════════════╝
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:app_links/app_links.dart';
import 'dart:async';

import 'firebase_options.dart';

import 'services/notification_service.dart';
import 'services/hata_raporlama.dart';
import 'services/push_bildirim_service.dart';
import 'services/remote_config_service.dart';
import 'services/crashlytics_service.dart';
import 'services/fcm_service.dart';

import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/rol_yonlendirici.dart';
import 'screens/login_screen.dart';
import 'screens/company_login_screen.dart';
import 'screens/kayit_screen.dart';
import 'screens/onay_bekleme_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/proje_sec_screen.dart';
import 'screens/projeler_screen.dart';
import 'screens/ogrenciler_screen.dart';
import 'screens/ogrenci_paneli_screen.dart';
import 'screens/suruculer_screen.dart';
import 'screens/gruplama_screen.dart';
import 'screens/bolge_atama_screen.dart';
import 'screens/servis_bolme_screen.dart';
import 'screens/harita_screen.dart';
import 'screens/canli_rota_screen.dart';
import 'screens/canli_takip_screen.dart';
import 'screens/veli_panel_screen.dart';
import 'screens/sofor_panel_screen.dart';
import 'screens/ayarlar_screen.dart';
import 'screens/bildirimler_screen.dart';
import 'screens/fiyat_yonetim_screen.dart';
import 'screens/araclar_screen.dart';
import 'screens/sozlesme_yonetim_screen.dart';
import 'screens/sofor_sozlesme_screen.dart';
import 'screens/dijital_imza_screen.dart';
import 'screens/arsiv_screen.dart';
import 'screens/proje_arsiv_screen.dart';
import 'screens/yoklama_screen.dart';
import 'screens/rotalar_screen.dart';
import 'screens/admin_arac_takip_screen.dart';
import 'screens/guzergah_kayit_screen.dart';
import 'screens/hazir_mesajlar_screen.dart';
import 'screens/guzergah_gecmis_screen.dart';
import 'screens/kayit_link_screen.dart';
import 'screens/servis_saati_screen.dart';
import 'screens/analiz_screen.dart';
import 'screens/toplu_mesaj_screen.dart';
import 'screens/toplu_whatsapp_screen.dart';
import 'screens/ai_asistan_screen.dart';
import 'screens/bireysel_sofor_screen.dart';
import 'screens/personel_panel_screen.dart';
import 'screens/super_admin_screen.dart';
import 'screens/veli_basvuru_form_screen.dart';
import 'screens/veli_basvurular_screen.dart';
import 'screens/sofor_rota_screen.dart';
import 'screens/sifre_degistir_screen.dart';
import 'screens/kullanici_firma_transfer_screen.dart';
import 'screens/veli_sozlesme_screen.dart';
import 'screens/qr_afis_screen.dart';
import 'screens/veli_kayit_yuz_yuze_scren.dart';
import 'screens/toplu_yukle_screen.dart';
import 'screens/veli_kayit_link_screen.dart';
import 'screens/acil_durum_screen.dart';
import 'screens/firma_ekle_screen.dart';
import 'screens/web_layout.dart';
import 'screens/web_veli_takip.dart';
import 'screens/web_sofor_panel.dart';
import 'screens/web_veli_panel.dart';
import 'screens/web_admin_panel.dart';
import 'screens/web_giris_yonlendirici.dart';

// ── Global navigator key — deep link yönlendirmesi için ──────────
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (!kIsWeb) {
    try { await CrashlyticsService.instance.baslat(); } catch (_) {}
    try { await RemoteConfigService.instance.baslat(); } catch (_) {}
    try { await NotificationService.baslat(); } catch (_) {}
    try { await PushBildirimService.baslat(); } catch (_) {}
    try { await FcmServisi.instance.baslat(); } catch (_) {}
  }

  HataRaporlama.kur();

  if (!kIsWeb) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ServisimApp());
}

class ServisimApp extends StatefulWidget {
  const ServisimApp({super.key});
  @override
  State<ServisimApp> createState() => _ServisimAppState();
}

class _ServisimAppState extends State<ServisimApp> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _deepLinkBaslat();
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  // ── Deep Link Sistemi ─────────────────────────────────────────
  void _deepLinkBaslat() async {
    final appLinks = AppLinks();

    // Uygulama kapalıyken açılan link
    try {
      final ilkLink = await appLinks.getInitialLink();
      if (ilkLink != null) {
        _linkIsle(ilkLink);
      }
    } catch (_) {}

    // Uygulama açıkken gelen link
    _linkSub = appLinks.uriLinkStream.listen(
      (uri) => _linkIsle(uri),
      onError: (_) {},
    );
  }

  void _linkIsle(Uri uri) {
    debugPrint('Deep link geldi: $uri');

    // servisim360://kayit/LINK_ID
    // https://servisim360.page.link/kayit/LINK_ID
    final segments = uri.pathSegments;

    // Veli kayıt formu: /kayit/{linkId} veya /basvuru/{linkId}
    if (segments.isNotEmpty &&
        (segments[0] == 'kayit' || segments[0] == 'basvuru') &&
        segments.length >= 2) {
      final linkId = segments[1];
      _git('/veli_basvuru', {'linkId': linkId});
      return;
    }

    // Query param ile: ?linkId=XXX
    final linkId = uri.queryParameters['linkId'] ??
                   uri.queryParameters['id']     ??
                   uri.queryParameters['link'];
    if (linkId != null && linkId.isNotEmpty) {
      _git('/veli_basvuru', {'linkId': linkId});
      return;
    }

    // Sadece path varsa ilk segment linkId'dir
    // servisim360://LINK_ID
    if (segments.isNotEmpty && segments[0].length > 5) {
      _git('/veli_basvuru', {'linkId': segments[0]});
    }
  }

  void _git(String rota, [Map<String, String?>? args]) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      // Navigator henüz hazır değil — kısa bekle
      Future.delayed(const Duration(milliseconds: 500), () {
        navigatorKey.currentState?.pushNamed(rota, arguments: args);
      });
      return;
    }
    navigatorKey.currentState?.pushNamed(rota, arguments: args);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Servisim360',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey, // ← deep link için zorunlu
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: _navy,
          primary: _navy,
          secondary: _turuncu,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Roboto'),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: _navy,
              foregroundColor: Colors.white,
              elevation: 2,
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12))),
              textStyle: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14),
            )),
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: _navy,
              side: const BorderSide(color: _navy),
              shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12))),
            )),
        textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: _navy)),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFFF8F9FA),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Color(0xFFE0E0E0))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Color(0xFFE0E0E0))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: _navy, width: 1.5)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              borderSide: BorderSide(color: Colors.red)),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          labelStyle: TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
        ),
        cardTheme: const CardThemeData(
          elevation: 2,
          shadowColor: Color(0x14000000),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16))),
          color: Colors.white,
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(10))),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.all(Colors.white),
          trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? Colors.green
              : Colors.grey[300]),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16))),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        dividerTheme: const DividerThemeData(
            color: Color(0xFFEEEEEE), thickness: 0.5),
      ),

      home: kIsWeb ? const WebGirisYonlendirici() : const SplashScreen(),

      routes: {
        '/onboarding':     (_) => const OnboardingScreen(),
        '/login':          (_) => kIsWeb
            ? const WebGirisYonlendirici()
            : const LoginScreen(),
        '/company_login':  (_) => const CompanyLoginScreen(),
        '/kayit':          (_) => const KayitScreen(),
        '/onay_bekleme':   (_) => const OnayBeklemeScreen(),
        '/rol':            (_) => const RolYonlendirici(),

        '/super_admin':    (_) => kIsWeb
            ? const WebGirisYonlendirici()
            : const SuperAdminShell(),
        '/firma_admin':    (_) => kIsWeb
            ? const WebAdminPanel()
            : const DashboardScreen(),
        '/dashboard':      (_) => kIsWeb
            ? const WebAdminPanel()
            : const DashboardScreen(),
        '/web_panel':      (_) => const WebLayout(),
        '/web_admin':      (_) => const WebAdminPanel(),
        '/web_veli':       (_) => const WebVeliTakip(),
        '/web_sofor':      (_) => const WebSoforPanel(),
        '/web_veli_panel': (_) => const WebVeliPanel(),

        '/proje_sec':      (_) => const ProjeSecScreen(),
        '/projeler':       (_) => const ProjelerScreen(),
        '/ogrenci':        (_) => const OgrencilerScreen(),
        '/ogrenci_paneli': (_) => const OgrenciPaneliScreen(),
        '/suruculer':      (_) => const SurucularScreen(),

        '/gruplama':        (_) => const GruplamaScreen(),
        '/bolge_atama':     (_) => const BolgeAtamaScreen(),
        '/servis_bolme':    (_) => const ServisBolmeScreen(),
        '/harita':          (_) => const HaritaScreen(),
        '/durak_takip':     (_) => const HaritaScreen(),
        '/rotalar':         (_) => const RotalarScreen(),
        '/akilli_rota':     (_) => const GruplamaScreen(),
        '/admin_takip':     (_) => const AdminAracTakipScreen(),
        '/canli_rota':      (_) => const CanliRotaScreen(),
        '/canli_takip':     (_) => const CanliTakipScreen(),
        '/guzergah_kayit':  (_) => const GuzergahKayitScreen(),
        '/guzergah_gecmis': (_) => const GuzergahGecmisScreen(),

        '/fiyat_yonetim':  (_) => const FiyatYonetimScreen(),
        '/fiyat':           (_) => const FiyatYonetimScreen(),
        '/araclar':         (_) => const AraclarScreen(),
        '/sozlesme':        (_) => const SozlesmeYonetimScreen(), // eski → yeni
        '/sozlesme_yonetim': (_) => const SozlesmeYonetimScreen(),
        '/arsiv':           (_) => const ArsivScreen(),
        '/proje_arsiv':     (_) => const ProjeArsivScreen(),

        '/kayit_link':          (_) => const KayitLinkScreen(),
        '/veli_basvurular':     (_) => const VeliBasvurularScreen(),
        '/qr_afis':             (_) => const QrAfisScreen(),
        '/yuz_yuze_kayit':      (_) => const VeliKayitYuzYuzeScreen(),
        '/toplu_yukle':         (_) => const TopluYukleScreen(),
        '/veli_kayit_link':     (_) => const VeliKayitLinkiScreen(),

        '/hazir_mesajlar':  (_) => const HazirMesajlarScreen(),
        '/toplu_mesaj':     (_) => const TopluMesajScreen(),
        '/toplu_whatsapp':  (_) => const TopluWhatsappScreen(),

        '/ayarlar':         (_) => const AyarlarScreen(),
        '/bildirimler':     (_) => const BildirimlerScreen(),
        '/servis_saati':    (_) => const ServisSaatiScreen(),

        '/sofor_panel':            (_) => const SoforPanelScreen(),
        '/bireysel_sofor_panel':   (_) => const BireyselSoforScreen(),
        '/bireysel_sofor_basvuru': (_) => const BireyselSoforScreen(),
        '/veli_panel':             (_) => const VeliPanelScreen(),
        '/personel_panel':         (_) => const PersonelPanelScreen(),

        '/yoklama':        (_) => const YoklamaScreen(),
        '/analiz':         (_) => const AnalizScreen(),
        '/ai_asistan':     (_) => const AiAsistanScreen(),
        '/sifre_degistir': (_) => const SifreDegistirScreen(),
        '/veli_sozlesme':  (_) =>
            const VeliSozlesmeScreen(dolduran: 'admin'),
        '/acil_durum':     (_) => const AcilDurumScreen(),
        '/sekreter':       (_) => const DashboardScreen(),
        '/firma_ekle':     (_) => const FirmaEkleScreen(),
      },

      onGenerateRoute: (settings) {
        // ── Veli Başvuru Formu — deep link veya normal route ──────
        if (settings.name == '/veli_basvuru') {
          final args = settings.arguments as Map<String, String?>?;
          final linkId = args?['linkId'] ?? '';
          if (linkId.isEmpty) return null;
          return MaterialPageRoute(
              builder: (_) => VeliBasvuruFormScreen(linkId: linkId));
        }

        if (settings.name == '/sofor_rota') {
          final args = settings.arguments as Map<String, String?>?;
          return MaterialPageRoute(
              builder: (_) => SoforRotaScreen(
                surucuId: args?['surucuId'] ?? '',
                surucuAd: args?['surucuAd'] ?? 'Sofor',
              ));
        }
        if (settings.name == '/firma_transfer') {
          final args = settings.arguments as Map<String, String>?;
          return MaterialPageRoute(
              builder: (_) => KullaniciFirmaTransferScreen(
                kullaniciId: args?['kullaniciId'] ?? '',
                kullaniciAd: args?['kullaniciAd'] ?? '',
                koleksiyon:  args?['koleksiyon']  ?? 'drivers',
                mevcutFirmaId: args?['firmaId']   ?? '',
              ));
        }
        if (settings.name == '/veli_sozlesme_link') {
          final args = settings.arguments as Map<String, String?>?;
          return MaterialPageRoute(
              builder: (_) => VeliSozlesmeScreen(
                dolduran: 'veli',
                linkId:   args?['linkId'],
                linkKod:  args?['kod'],
              ));
        }
        if (settings.name == '/hazir_mesaj') {
          return MaterialPageRoute(
              builder: (_) => const HazirMesajlarScreen());
        }
        return null;
      },
    );
  }
}
