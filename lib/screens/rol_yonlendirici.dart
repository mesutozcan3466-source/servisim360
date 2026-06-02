import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RolYonlendirici extends StatefulWidget {
  const RolYonlendirici({super.key});
  @override
  State<RolYonlendirici> createState() => _RolYonlendiriciState();
}

class _RolYonlendiriciState extends State<RolYonlendirici> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  @override
  void initState() {
    super.initState();
    _yonlendir();
  }

  Future<void> _yonlendir() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _git(kIsWeb ? '/login' : '/login');
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('kullanicilar')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 8));

      if (!doc.exists) {
        _git('/login');
        return;
      }

      final data  = doc.data() ?? {};
      String rol  = data['rol'] as String? ?? '';
      final durum = data['durum'] as String? ?? '';

      // Normalize rol
      if (rol == 'super_admin')  rol = 'superAdmin';
      if (rol == 'firma_admin')  rol = 'firmaAdmin';

      if (durum == 'beklemede') { _git('/onay_bekleme'); return; }
      if (durum == 'lisans_bitis') { _git('/onay_bekleme'); return; }

      if (!mounted) return;

      switch (rol) {
        case 'superAdmin':
          _git(kIsWeb ? '/web_panel' : '/super_admin');
          break;
        case 'firmaAdmin':
        case 'admin':
          _git(kIsWeb ? '/web_admin' : '/dashboard');
          break;
        case 'sofor':
          _git(kIsWeb ? '/web_sofor' : '/sofor_panel');
          break;
        case 'bireyselSofor':
          _git('/bireysel_sofor_panel');
          break;
        case 'personel':
          _git('/personel_panel');
          break;
        case 'veli':
          _git(kIsWeb ? '/web_veli_panel' : '/veli_panel');
          break;
        default:
          _git('/onay_bekleme');
      }
    } catch (e) {
      debugPrint('RolYonlendirici hata: $e');
      if (mounted) _git('/login');
    }
  }

  void _git(String rota) {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, rota);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: _navy,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 32, height: 32,
              child: CircularProgressIndicator(color: _turuncu, strokeWidth: 2.5),
            ),
            SizedBox(height: 16),
            Text('Yukluyor...', style: TextStyle(color: Colors.white54, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
