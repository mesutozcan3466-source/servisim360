import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/session_service.dart';
import '../screens/giris_log_servisi.dart';

class RolYonlendirici extends StatefulWidget {
  const RolYonlendirici({super.key});
  @override
  State<RolYonlendirici> createState() => _RolYonlendiriciState();
}

class _RolYonlendiriciState extends State<RolYonlendirici> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  final _session = SessionService.instance;
  String _durum  = 'Yukleniyor...';

  @override
  void initState() { super.initState(); _yonlendir(); }

  void _setDurum(String d) {
    if (mounted) setState(() => _durum = d);
  }

  // Admin rolleri — onay beklemiyor
  bool _adminRolMu(String? rol) {
    return rol == 'admin' || rol == 'firmaAdmin' || rol == 'kolejAdmin' ||
        rol == 'superAdmin' || rol == 'superadmin';
  }

  Future<void> _yonlendir() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { _git('/login'); return; }

    _setDurum('Kimlik dogrulanıyor...');

    try {
      // Önce rolü al
      String? rol = await _rolBulDirekt(user.uid);

      // Admin ise onay kontrolü YOK — direkt yönlendir
      if (_adminRolMu(rol)) {
        _setDurum('Panele yonlendiriliyor...');
        final firmaId = await _firmaIdAl(user.uid, rol!);
        await GirisLogServisi.instance.girisLogYaz(
          uid:     user.uid,
          email:   user.email ?? '',
          rol:     rol,
          firmaId: firmaId,
        );
        _rolePushla(rol);
        return;
      }

      // Admin değilse normal kontrol
      final girisOk = await _session.girisKontrol()
          .timeout(const Duration(seconds: 10), onTimeout: () {
        return {'girisYapilmis': false, 'rol': null};
      });

      final girisYapilmis = girisOk['girisYapilmis'] as bool? ?? false;

      if (!girisYapilmis) {
        final hata = girisOk['hata'] as String? ?? '';
        if (hata == 'onay_bekleniyor') {
          _git('/onay_bekleme');
        } else if (hata == 'askida') {
          _hataDialog('Hesabiniz askiya alindi. Yoneticinizle iletisime gecin.');
        } else if (hata == 'reddedildi') {
          _hataDialog('Hesabiniz reddedildi.');
        } else {
          _git('/login');
        }
        return;
      }

      _setDurum('Rol belirleniyor...');
      rol ??= girisOk['rol'] as String?;

      if (rol == null) {
        await _session.cikisYap();
        _hataDialog('Rol bilginiz tanimli degil.\nYoneticinizle iletisime gecin.');
        return;
      }

      final firmaId = await _firmaIdAl(user.uid, rol);

      if (rol == 'sofor' || rol == 'bireyselSofor' || rol == 'veli') {
        if (firmaId == null || firmaId.isEmpty) {
          _hataDialog('Firma atamaniz bulunamadi.\nYoneticinizle iletisime gecin.');
          return;
        }
        final firmaAktif = await _firmaAktifMi(firmaId);
        if (!firmaAktif) {
          _hataDialog('Firmaniz su an aktif degil.\nYoneticinizle iletisime gecin.');
          return;
        }
      }

      _setDurum('Panele yonlendiriliyor...');

      await GirisLogServisi.instance.girisLogYaz(
        uid:     user.uid,
        email:   user.email ?? '',
        rol:     rol,
        firmaId: firmaId,
      );

      _kacakGirisKontrol(user.uid, rol);
      _rolePushla(rol);

    } catch (e) {
      debugPrint('RolYonlendirici hata: $e');
      _setDurum('Baglanti hatasi...');
      await Future.delayed(const Duration(seconds: 2));
      _baglantiHataEkrani();
    }
  }

  // Direkt rol okuma — durum kontrolü olmadan
  Future<String?> _rolBulDirekt(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('kullanicilar').doc(uid).get();
      if (!doc.exists) return null;
      return doc.data()?['rol'] as String?;
    } catch (_) { return null; }
  }

  Future<String?> _firmaIdAl(String uid, String rol) async {
    try {
      final kulDoc  = await FirebaseFirestore.instance.collection('kullanicilar').doc(uid).get();
      final firmaId = kulDoc.data()?['firmaId'] as String?;
      if (firmaId != null && firmaId.isNotEmpty) return firmaId;

      if (rol == 'sofor' || rol == 'bireyselSofor') {
        var snap = await FirebaseFirestore.instance
            .collection('drivers').where('uid', isEqualTo: uid).limit(1).get();
        if (snap.docs.isEmpty) {
          final u = FirebaseAuth.instance.currentUser;
          if (u?.email != null) {
            snap = await FirebaseFirestore.instance
                .collection('drivers').where('email', isEqualTo: u!.email).limit(1).get();
          }
        }
        if (snap.docs.isNotEmpty) {
          final dFirmaId = snap.docs.first.data()['firmaId'] as String?;
          if (dFirmaId != null && dFirmaId.isNotEmpty) {
            await FirebaseFirestore.instance.collection('kullanicilar').doc(uid).update({'firmaId': dFirmaId});
            return dFirmaId;
          }
        }
      }

      if (rol == 'veli') {
        final u = FirebaseAuth.instance.currentUser;
        var snap = await FirebaseFirestore.instance
            .collection('parents').where('uid', isEqualTo: uid).limit(1).get();
        if (snap.docs.isEmpty && u?.email != null) {
          snap = await FirebaseFirestore.instance
              .collection('parents').where('email', isEqualTo: u!.email).limit(1).get();
        }
        if (snap.docs.isNotEmpty) {
          final pFirmaId = snap.docs.first.data()['firmaId'] as String?;
          if (pFirmaId != null && pFirmaId.isNotEmpty) {
            await FirebaseFirestore.instance.collection('kullanicilar').doc(uid).update({'firmaId': pFirmaId});
            return pFirmaId;
          }
        }
      }

      return null;
    } catch (_) { return null; }
  }

  Future<bool> _firmaAktifMi(String firmaId) async {
    try {
      var doc = await FirebaseFirestore.instance.collection('firms').doc(firmaId).get();
      if (!doc.exists) doc = await FirebaseFirestore.instance.collection('firmalar').doc(firmaId).get();
      if (!doc.exists) return true;
      final durum = doc.data()?['durum'] as String? ?? 'aktif';
      return durum == 'aktif' || durum == 'onayli' || durum == 'onaylı';
    } catch (_) { return true; }
  }

  Future<void> _kacakGirisKontrol(String uid, String rol) async {
    if (_adminRolMu(rol)) return;
    final kacak = await GirisLogServisi.instance.kacakGirisKontrolu(uid);
    if (kacak && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Guvenlik uyarisi: Hesabiniza farkli cihazlardan giris yapildi!'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(label: 'Tamam', textColor: Colors.white, onPressed: () {})));
    }
  }

  void _rolePushla(String rol) {
    switch (rol) {
      case 'superAdmin':
      case 'superadmin':
        _git('/super_admin');
        break;
      case 'admin':
      case 'firmaAdmin':
      case 'kolejAdmin':
        _git('/dashboard');
        break;
      case 'sofor':
        _git('/sofor_panel');
        break;
      case 'bireyselSofor':
        _git('/bireysel_sofor_panel');
        break;
      case 'personel':
        _git('/personel_panel');
        break;
      case 'veli':
        _git('/veli_panel');
        break;
      default:
        debugPrint('Tanimsiz rol: $rol');
        _git('/login');
    }
  }

  void _hataDialog(String mesaj) {
    if (!mounted) return;
    showDialog(context: context, barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Erisim Engellendi', style: TextStyle(color: Colors.red)),
          content: Text(mesaj),
          actions: [ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _navy),
              onPressed: () async {
                Navigator.pop(context);
                await _session.cikisYap();
                _git('/login');
              },
              child: const Text('Tamam'))],
        ));
  }

  void _baglantiHataEkrani() {
    if (!mounted) return;
    showDialog(context: context, barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Baglanti Hatasi'),
          content: const Text('Sunucuya baglanamadi.\nInternet baglantinizi kontrol edin.'),
          actions: [
            TextButton(onPressed: () { Navigator.pop(context); _yonlendir(); }, child: const Text('Tekrar Dene')),
            TextButton(onPressed: () async {
              Navigator.pop(context);
              await _session.cikisYap();
              _git('/login');
            }, child: const Text('Cikis Yap', style: TextStyle(color: Colors.red))),
          ],
        ));
  }

  void _git(String rota) {
    if (mounted) Navigator.pushReplacementNamed(context, rota);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 80, height: 80,
            decoration: BoxDecoration(color: _turuncu.withValues(alpha: 0.15), shape: BoxShape.circle,
                border: Border.all(color: _turuncu.withValues(alpha: 0.4), width: 2)),
            child: const Center(child: Text('S',
                style: TextStyle(color: _turuncu, fontSize: 40, fontWeight: FontWeight.bold)))),
        const SizedBox(height: 32),
        const CircularProgressIndicator(color: _turuncu, strokeWidth: 2.5),
        const SizedBox(height: 20),
        const Text('Servisim360', style: TextStyle(color: Colors.white, fontSize: 20,
            fontWeight: FontWeight.w300, letterSpacing: 2)),
        const SizedBox(height: 8),
        AnimatedSwitcher(duration: const Duration(milliseconds: 300),
            child: Text(_durum, key: ValueKey(_durum),
                style: const TextStyle(color: Colors.white38, fontSize: 12))),
      ])),
    );
  }
}
