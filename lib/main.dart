import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:app_links/app_links.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/onay_bekleme_screen.dart';
import 'screens/veli_basvuru_form_screen.dart';

// â”€â”€ Global navigator key (deep link iÃ§in gerekli) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // âœ… Google Maps beyaz ekran dÃ¼zeltmesi
  final GoogleMapsFlutterPlatform mapsImpl =
      GoogleMapsFlutterPlatform.instance;
  if (mapsImpl is GoogleMapsFlutterAndroid) {
    mapsImpl.useAndroidViewSurface = true;
  }

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
    _deepLinkDinle();
  }

  // â”€â”€ Deep Link Dinleyici â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _deepLinkDinle() {
    _appLinks = AppLinks();

    // Uygulama kapalÄ±yken aÃ§Ä±lan link
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _linkIsle(uri);
    });

    // Uygulama aÃ§Ä±kken gelen link
    _appLinks.uriLinkStream.listen(
      (uri) => _linkIsle(uri),
      onError: (e) => debugPrint('Deep link hatasÄ±: $e'),
    );
  }

  // â”€â”€ Link Ä°ÅŸle â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _linkIsle(Uri uri) {
    debugPrint('Deep link geldi: $uri');

    // https://servisim360.app/kayit?uid=XXX&proje=YYY
    // servisim360://kayit?uid=XXX&proje=YYY
    if (uri.pathSegments.contains('kayit') ||
        uri.host == 'kayit') {
      final linkId = uri.queryParameters['linkId'] ?? uri.queryParameters['uid'] ?? '';
      if (linkId.isEmpty) return;
      // Kullanici giris yapti mi kontrol et
      if (linkId.isEmpty) return;

      // KullanÄ±cÄ± giriÅŸ yapmÄ±ÅŸ mÄ± kontrol et
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // GiriÅŸ yapÄ±lmamÄ±ÅŸsa linki hatÄ±rla, giriÅŸ sonrasÄ± aÃ§
        debugPrint('KullanÄ±cÄ± giriÅŸ yapmamÄ±ÅŸ, link beklemeye alÄ±ndÄ±');
        return;
      }

      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => VeliBasvuruFormScreen(linkId: linkId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Servis360',
      debugShowCheckedModeBanner: false,
      // âœ… navigatorKey eklendi
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
    );
  }
}

// â”€â”€ Auth Kontrol â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class AuthKontrol extends StatelessWidget {
  const AuthKontrol({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == null) {
          return const LoginScreen();
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('kullanicilar')
              .doc(snapshot.data!.uid)
              .snapshots(),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (!userSnap.hasData || !userSnap.data!.exists) {
              return const DashboardScreen();
            }

            final durum = userSnap.data!.get('durum') ?? 'beklemede';

            if (durum == 'onaylÄ±') {
              return const DashboardScreen();
            } else {
              return const OnayBeklemeScreen();
            }
          },
        );
      },
    );
  }
}


