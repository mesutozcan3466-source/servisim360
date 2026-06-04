import 'package:flutter/material.dart';
import 'yardim_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/session_service.dart';

class AyarlarScreen extends StatefulWidget {
  const AyarlarScreen({super.key});
  @override
  State<AyarlarScreen> createState() => _AyarlarScreenState();
}

class _AyarlarScreenState extends State<AyarlarScreen> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  bool _bildirimAktif   = true;
  bool _sesAktif        = true;
  bool _gelmeyecekHatir = true;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('kullanicilar').doc(uid).get();
    if (mounted) setState(() => _userData = doc.data());
  }

  Future<void> _cikisYap() async {
    await SessionService.instance.cikisYap();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white,
        actions: [YardimButonu(ekranAdi: 'Ayarlar')],
        title: const Text('Ayarlar', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Profil
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_navy, Color(0xFF2a5298)]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            CircleAvatar(
              radius: 28, backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: Text((_userData?['email'] ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_userData?['email'] ?? '',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text(_userData?['rol'] ?? '',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ])),
          ]),
        ),
        const SizedBox(height: 20),

        _bolumBaslik('Bildirimler', Icons.notifications_outlined),
        _karti(Column(children: [
          _switchSatir('Tüm Bildirimler', _bildirimAktif,
                  (v) => setState(() => _bildirimAktif = v)),
          const Divider(height: 1),
          _switchSatir('Ses', _sesAktif,
                  (v) => setState(() => _sesAktif = v)),
          const Divider(height: 1),
          _switchSatir('Gelmeyecek Hatırlatıcı', _gelmeyecekHatir,
                  (v) => setState(() => _gelmeyecekHatir = v)),
        ])),
        const SizedBox(height: 16),

        _bolumBaslik('Uygulama', Icons.settings_outlined),
        _karti(Column(children: [
          _menuSatir(Icons.map_outlined,         'Harita Görünümü', () => Navigator.pushNamed(context, '/harita')),
          const Divider(height: 1),
          _menuSatir(Icons.message_outlined,     'Hazır Mesajlar',  () => Navigator.pushNamed(context, '/hazir_mesajlar')),
          const Divider(height: 1),
          _menuSatir(Icons.access_time_outlined, 'Servis Saati',    () => Navigator.pushNamed(context, '/servis_saati')),
        ])),
        const SizedBox(height: 16),

        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red, side: const BorderSide(color: Colors.red),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _cikisYap,
          icon: const Icon(Icons.logout_outlined),
          label: const Text('Çıkış Yap', style: TextStyle(fontWeight: FontWeight.bold)),
        )),
        const SizedBox(height: 40),
      ]),
    );
  }

  Widget _bolumBaslik(String baslik, IconData ikon) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Icon(ikon, color: _navy, size: 16), const SizedBox(width: 8),
      Text(baslik, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _navy)),
    ]),
  );

  Widget _karti(Widget child) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
    ),
    child: child,
  );

  Widget _switchSatir(String label, bool value, ValueChanged<bool> onChanged) =>
      SwitchListTile(
        title: Text(label, style: const TextStyle(fontSize: 13)),
        value: value, onChanged: onChanged,
        activeColor: _navy,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        dense: true,
      );

  Widget _menuSatir(IconData ikon, String label, VoidCallback onTap) =>
      ListTile(
        leading: Icon(ikon, color: _navy, size: 20),
        title: Text(label, style: const TextStyle(fontSize: 13)),
        trailing: const Icon(Icons.chevron_right_outlined, color: Colors.grey, size: 18),
        onTap: onTap, dense: true,
      );
}
