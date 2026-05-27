import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/notification_service.dart';
import 'services/hata_raporlama.dart';
import 'services/push_bildirim_service.dart';
import 'services/remote_config_service.dart';
import 'services/crashlytics_service.dart';

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
import 'screens/sozlesme_screen.dart';
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
import 'screens/veli_basvuru_screen.dart';
import 'screens/sofor_rota_screen.dart';
import 'screens/sifre_degistir_screen.dart';
import 'screens/kullanici_firma_transfer_screen.dart';
import 'screens/veli_sozlesme_screen.dart';
import 'screens/qr_afis_screen.dart';
import 'screens/veli_kayit_yuz_yuze_scren.dart';
import 'screens/toplu_yukle_screen.dart';
import 'screens/veli_kayit_link_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  await CrashlyticsService.instance.baslat();
  await RemoteConfigService.instance.baslat();

  HataRaporlama.kur();
  await NotificationService.baslat();
  await PushBildirimService.baslat();

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ServisimApp());
}

class ServisimApp extends StatelessWidget {
  const ServisimApp({super.key});

  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Servisim360',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: _navy, primary: _navy, secondary: _turuncu, brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _navy, foregroundColor: Colors.white, elevation: 0, centerTitle: false,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Roboto'),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
          backgroundColor: _navy, foregroundColor: Colors.white, elevation: 2,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        )),
        outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
          foregroundColor: _navy, side: const BorderSide(color: _navy),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        )),
        textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: _navy)),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true, fillColor: Color(0xFFF8F9FA),
          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Color(0xFFE0E0E0))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Color(0xFFE0E0E0))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: _navy, width: 1.5)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Colors.red)),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          labelStyle: TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
        ),
        cardTheme: const CardThemeData(
          elevation: 2, shadowColor: Color(0x14000000),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
          color: Colors.white,
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.all(Colors.white),
          trackColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected) ? Colors.green : Colors.grey[300]),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: _navy, foregroundColor: Colors.white, elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        dividerTheme: const DividerThemeData(color: Color(0xFFEEEEEE), thickness: 0.5),
      ),
      home: const SplashScreen(),
      routes: {
        '/onboarding':       (_) => const OnboardingScreen(),
        '/login':            (_) => const LoginScreen(),
        '/company_login':    (_) => const CompanyLoginScreen(),
        '/kayit':            (_) => const KayitScreen(),
        '/onay_bekleme':     (_) => const OnayBeklemeScreen(),
        '/rol':              (_) => const RolYonlendirici(),
        '/super_admin':      (_) => const SuperAdminShell(),
        '/firma_admin':      (_) => const DashboardScreen(),
        '/dashboard':        (_) => const DashboardScreen(),
        '/sekreter':         (_) => const DashboardScreen(), // Sekreter de dashboard açar
        '/proje_sec':        (_) => const ProjeSecScreen(),
        '/projeler':         (_) => const ProjelerScreen(),
        '/ogrenci':          (_) => const OgrencilerScreen(),
        '/ogrenci_paneli':   (_) => const OgrenciPaneliScreen(),
        '/suruculer':        (_) => const SurucularScreen(),
        '/gruplama':         (_) => const GruplamaScreen(),
        '/bolge_atama':      (_) => const BolgeAtamaScreen(),
        '/servis_bolme':     (_) => const ServisBolmeScreen(),
        '/harita':           (_) => const HaritaScreen(),
        '/durak_takip':      (_) => const HaritaScreen(),
        '/rotalar':          (_) => const RotalarScreen(),
        '/akilli_rota':      (_) => const GruplamaScreen(),
        '/admin_takip':      (_) => const AdminAracTakipScreen(),
        '/canli_rota':       (_) => const CanliRotaScreen(),
        '/canli_takip':      (_) => const CanliTakipScreen(),
        '/guzergah_kayit':   (_) => const GuzergahKayitScreen(),
        '/guzergah_gecmis':  (_) => const GuzergahGecmisScreen(),
        '/fiyat_yonetim':    (_) => const FiyatYonetimScreen(),
        '/sozlesme':         (_) => const SozlesmeScreen(),
        '/ayarlar':          (_) => const AyarlarScreen(),
        '/bildirimler':      (_) => const BildirimlerScreen(),
        '/servis_saati':     (_) => const ServisSaatiScreen(),
        '/hazir_mesajlar':   (_) => const HazirMesajlarScreen(),
        '/toplu_mesaj':      (_) => const TopluMesajScreen(),
        '/toplu_whatsapp':   (_) => const TopluWhatsappScreen(),
        '/qr_afis':          (_) => const QrAfisScreen(),
        '/yuz_yuze_kayit':   (_) => const VeliKayitYuzYuzeScreen(),
        '/toplu_yukle':      (_) => const TopluYukleScreen(),
        '/veli_kayit_link':  (_) => const VeliKayitLinkiScreen(),
        '/sofor_panel':          (_) => const SoforPanelScreen(),
        '/bireysel_sofor_panel': (_) => const BireyselSoforScreen(),
        '/bireysel_sofor_basvuru': (_) => const BireyselSoforScreen(),
        '/veli_panel':       (_) => const VeliPanelScreen(),
        '/personel_panel':   (_) => const PersonelPanelScreen(),
        '/yoklama':          (_) => const YoklamaScreen(),
        '/kayit_link':       (_) => const KayitLinkScreen(),
        '/analiz':           (_) => const AnalizScreen(),
        '/ai_asistan':       (_) => const AiAsistanScreen(),
        '/sifre_degistir':   (_) => const SifreDegistirScreen(),
        '/veli_sozlesme':    (_) => const VeliSozlesmeScreen(dolduran: 'admin'),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/veli_basvuru') {
          final args = settings.arguments as Map<String, String?>?;
          return MaterialPageRoute(builder: (_) => VeliBasvuruFormScreen(linkId: args?['linkId'], linkKod: args?['kod']));
        }
        if (settings.name == '/sofor_rota') {
          final args = settings.arguments as Map<String, String?>?;
          return MaterialPageRoute(builder: (_) => SoforRotaScreen(surucuId: args?['surucuId'] ?? '', surucuAd: args?['surucuAd'] ?? 'Sofor'));
        }
        if (settings.name == '/firma_transfer') {
          final args = settings.arguments as Map<String, String>?;
          return MaterialPageRoute(builder: (_) => KullaniciFirmaTransferScreen(
              kullaniciId: args?['kullaniciId'] ?? '', kullaniciAd: args?['kullaniciAd'] ?? '',
              koleksiyon: args?['koleksiyon'] ?? 'drivers', mevcutFirmaId: args?['firmaId'] ?? ''));
        }
        if (settings.name == '/veli_sozlesme_link') {
          final args = settings.arguments as Map<String, String?>?;
          return MaterialPageRoute(builder: (_) => VeliSozlesmeScreen(dolduran: 'veli', linkId: args?['linkId'], linkKod: args?['kod']));
        }
        return null;
      },
    );
  }
}
