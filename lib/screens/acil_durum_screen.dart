import 'package:flutter/material.dart';
import 'yardim_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

class AcilDurumScreen extends StatefulWidget {
  const AcilDurumScreen({super.key});

  @override
  State<AcilDurumScreen> createState() => _AcilDurumScreenState();
}

class _AcilDurumScreenState extends State<AcilDurumScreen>
    with SingleTickerProviderStateMixin {
  static const Color navy = Color(0xFF1a3a6b);

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  bool _gonderildi = false;
  bool _yukleniyor = false;
  String _secilenTur = 'genel';

  final List<Map<String, dynamic>> _acilTurleri = [
    {'id': 'genel', 'baslik': 'Genel Acil', 'renk': Colors.red},
    {'id': 'kaza', 'baslik': 'Kaza', 'renk': Colors.orange},
    {'id': 'arac_arizasi', 'baslik': 'Arac Arizasi', 'renk': Colors.amber},
    {'id': 'saglik', 'baslik': 'Saglik', 'renk': Colors.pink},
    {'id': 'guvensiz', 'baslik': 'Guvensiz Durum', 'renk': Colors.deepOrange},
    {'id': 'kayip_ogrenci', 'baslik': 'Kayip Ogrenci', 'renk': Colors.purple},
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  Future<void> _acilDurumBildir() async {
    setState(() => _yukleniyor = true);
    try {
      Position? konum;
      try {
        konum = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high)
            .timeout(const Duration(seconds: 5));
      } catch (_) {}

      final uid = FirebaseAuth.instance.currentUser?.uid;
      final tur =
      _acilTurleri.firstWhere((t) => t['id'] == _secilenTur);

      await FirebaseFirestore.instance.collection('acil_durumlar').add({
        'surucuId': uid ?? '',
        'tur': _secilenTur,
        'turBaslik': tur['baslik'],
        'konum': konum != null
            ? {'lat': konum.latitude, 'lng': konum.longitude}
            : null,
        'zaman': FieldValue.serverTimestamp(),
        'durum': 'aktif',
        'okundu': false,
      });

      setState(() => _gonderildi = true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: Colors.red));
    } finally {
      setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _gonderildi
          ? Colors.green.shade50
          : const Color(0xFFFFF5F5),
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        actions: [YardimButonu(ekranAdi: 'Genel')],
        title: const Text('Acil Durum',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _gonderildi ? _gonderildiEkrani() : _acilEkrani(),
    );
  }

  Widget _acilEkrani() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          const Text('Acil Durum Turu Secin',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.4,
            ),
            itemCount: _acilTurleri.length,
            itemBuilder: (ctx, i) {
              final tur = _acilTurleri[i];
              final secili = _secilenTur == tur['id'];
              final renk = tur['renk'] as Color;
              return GestureDetector(
                onTap: () =>
                    setState(() => _secilenTur = tur['id']),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: secili
                        ? renk.withValues(alpha: 0.15)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: secili ? renk : Colors.grey.shade200,
                        width: secili ? 2 : 1),
                  ),
                  child: Center(
                    child: Text(tur['baslik'],
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: secili
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: secili ? renk : Colors.black87)),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 40),
          ScaleTransition(
            scale: _pulseAnim,
            child: GestureDetector(
              onTap: _yukleniyor ? null : _acilDurumBildir,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.red.withValues(alpha: 0.4),
                        blurRadius: 30,
                        spreadRadius: 10)
                  ],
                ),
                child: _yukleniyor
                    ? const Center(
                    child: CircularProgressIndicator(
                        color: Colors.white))
                    : const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 56, color: Colors.white),
                    Text('ACIL\nYARDIM',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            height: 1.2)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Bu butona basildiginda konumunuz ve\nacil durum bilgisi yonetime iletilecektir.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _gonderildiEkrani() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 80),
          const SizedBox(height: 20),
          const Text('Acil Durum Bildirimi Gonderildi!',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text(
            'Yonetim bilgilendirildi.\nEn kisa surede geri donulecek.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () =>
                setState(() => _gonderildi = false),
            style: ElevatedButton.styleFrom(
              backgroundColor: navy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 14),
            ),
            child: const Text('Yeni Bildirim'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }
}
