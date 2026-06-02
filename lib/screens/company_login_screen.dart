import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/session_service.dart';

class CompanyLoginScreen extends StatefulWidget {
  const CompanyLoginScreen({super.key});
  @override
  State<CompanyLoginScreen> createState() => _CompanyLoginScreenState();
}

class _CompanyLoginScreenState extends State<CompanyLoginScreen> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  final _kodCtrl = TextEditingController();
  bool _yukleniyor = false;

  @override
  void dispose() { _kodCtrl.dispose(); super.dispose(); }

  Future<void> _giris() async {
    final kod = _kodCtrl.text.trim();
    if (kod.isEmpty) return;
    setState(() => _yukleniyor = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('firms')
          .where('kayitKodu', isEqualTo: kod)
          .limit(1).get();
      if (snap.docs.isEmpty) {
        _snack('Geçersiz firma kodu', Colors.red);
      } else {
        if (mounted) Navigator.pushReplacementNamed(context, '/kayit');
      }
    } catch (e) {
      _snack('Hata: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  void _snack(String msg, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: c));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [_navy, Color(0xFF2a5298)]),
        ),
        child: SafeArea(child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.business_outlined, color: Colors.white, size: 64),
            const SizedBox(height: 20),
            const Text('Firma Kodu ile Giriş',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Firma yöneticinizden aldığınız kodu girin',
                style: TextStyle(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 40),
            TextField(
              controller: _kodCtrl,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 6),
              decoration: InputDecoration(
                hintText: 'XXXXX',
                hintStyle: const TextStyle(color: Colors.grey, letterSpacing: 6),
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _turuncu, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _yukleniyor ? null : _giris,
              child: _yukleniyor
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Devam', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            )),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
              child: const Text('E-posta ile Giriş Yap',
                  style: TextStyle(color: Colors.white70)),
            ),
          ]),
        )),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  ai_asistan_screen.dart
// ════════════════════════════════════════════════════════════════════════════