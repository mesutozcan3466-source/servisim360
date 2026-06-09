import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_links/app_links.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/rol_yonlendirici.dart';
import 'screens/onay_bekleme_screen.dart';
import 'screens/veli_basvuru_form_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/web_admin_panel.dart';
import 'screens/web_super_admin.dart';
import 'screens/sofor_panel_screen.dart';
import 'screens/web_sofor_panel.dart';
import 'screens/veli_panel_screen.dart';
import 'screens/web_veli_panel.dart';
import 'screens/personel_panel_screen.dart';
import 'screens/super_admin_screen.dart';
import 'screens/bireysel_sofor_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const Servis360App());
}

class Servis360App extends StatefulWidget {
  const Servis360App({super.key});
  @override
  State<Servis360App> createState() => _Servis360AppState();
}

class _Servis360AppState extends State<Servis360App> {
  late final AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _appLinks.getInitialLink().then((uri) { if (uri != null) _linkIsle(uri); });
    _appLinks.uriLinkStream.listen((uri) => _linkIsle(uri),
        onError: (e) => debugPrint('Deep link: $e'));
  }

  void _linkIsle(Uri uri) {
    if (uri.pathSegments.contains('kayit') || uri.host == 'kayit') {
      final linkId = uri.queryParameters['linkId'] ?? uri.queryParameters['uid'] ?? '';
      if (linkId.isEmpty) return;
      if (FirebaseAuth.instance.currentUser == null) return;
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => VeliBasvuruFormScreen(linkId: linkId)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Servisim360',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1a3a6b),
          primary: const Color(0xFF1a3a6b),
          secondary: const Color(0xFFFF8C00),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const AuthKontrol(),
      routes: {
        '/login':                (_) => const LoginScreen(),
        '/onay_bekleme':         (_) => const OnayBeklemeScreen(),
        '/dashboard':            (_) => const DashboardScreen(),
        '/web_admin':            (_) => const WebAdminPanel(),
        '/web_panel':            (_) => const WebSuperAdminSayfasi(),
        '/sofor_panel':          (_) => const SoforPanelScreen(),
        '/bireysel_sofor_panel': (_) => const BireyselSoforScreen(),
        '/web_sofor':            (_) => const WebSoforler(),
        '/veli_panel':           (_) => const VeliPanelScreen(),
        '/web_veli_panel':       (_) => const WebVeliPanel(),
        '/personel_panel':       (_) => const PersonelPanelScreen(),
        '/super_admin':          (_) => const SuperAdminShell(),
      },
    );
  }
}

class AuthKontrol extends StatelessWidget {
  const AuthKontrol({super.key});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              backgroundColor: Color(0xFF1a3a6b),
              body: Center(child: CircularProgressIndicator(
                  color: Color(0xFFFF8C00), strokeWidth: 2.5)));
        }
        if (snapshot.data == null) return const LoginScreen();
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('kullanicilar')
              .doc(snapshot.data!.uid)
              .snapshots(),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                  backgroundColor: Color(0xFF1a3a6b),
                  body: Center(child: CircularProgressIndicator(
                      color: Color(0xFFFF8C00), strokeWidth: 2.5)));
            }
            if (!userSnap.hasData || !userSnap.data!.exists) {
              return const RolYonlendirici();
            }
            final data = userSnap.data!.data() as Map<String, dynamic>? ?? {};
            final durum = data['durum'] as String? ?? 'beklemede';
            if (durum == 'beklemede' || durum == 'lisans_bitis') {
              return const OnayBeklemeScreen();
            }
            return const RolYonlendirici();
          },
        );
      },
    );
  }
}
