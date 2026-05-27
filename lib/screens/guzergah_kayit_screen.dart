import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../services/guzergah_kayit_service.dart';
import '../services/session_service.dart';

class GuzergahKayitScreen extends StatefulWidget {
  const GuzergahKayitScreen({super.key});

  @override
  State<GuzergahKayitScreen> createState() => _GuzergahKayitScreenState();
}

class _GuzergahKayitScreenState extends State<GuzergahKayitScreen> {
  static const _navy = Color(0xFF1a3a6b);

  String? _firmaId;
  String? _surucuId;
  String? _aktifOturumId;
  bool    _aktif       = false;
  bool    _yukleniyor  = false;
  double  _toplamKm    = 0;
  int     _noktaSayisi = 0;
  Position? _sonKonum;
  StreamSubscription<Position>? _konumStream;
  DateTime? _baslangicZaman;

  @override
  void initState() { super.initState(); _init(); }

  @override
  void dispose() { _konumStream?.cancel(); super.dispose(); }

  Future<void> _init() async {
    _firmaId  = await SessionService.instance.firmaldAl();
    _surucuId = FirebaseAuth.instance.currentUser?.uid;
    if (mounted) setState(() {});
  }

  Future<void> _baslatDurdur() async {
    if (_aktif) await _durdur(); else await _baslat();
  }

  Future<void> _baslat() async {
    final izin = await Geolocator.requestPermission();
    if (izin == LocationPermission.denied || izin == LocationPermission.deniedForever) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konum izni gerekli'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _yukleniyor = true);
    final oturumId = await GuzergahKayitService.oturumBaslat(
        surucuId: _surucuId ?? '', firmaId: _firmaId ?? '');

    setState(() {
      _aktifOturumId = oturumId; _aktif = true;
      _toplamKm = 0; _noktaSayisi = 0;
      _baslangicZaman = DateTime.now(); _yukleniyor = false;
    });

    _konumStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, distanceFilter: 20),
    ).listen((pos) async {
      if (_sonKonum != null) {
        final mesafe = Geolocator.distanceBetween(
            _sonKonum!.latitude, _sonKonum!.longitude, pos.latitude, pos.longitude);
        setState(() => _toplamKm += mesafe / 1000);
      }
      setState(() { _sonKonum = pos; _noktaSayisi++; });
      if (_firmaId != null && _surucuId != null) {
        await GuzergahKayitService.konumKaydet(
          surucuId: _surucuId!, firmaId: _firmaId!,
          lat: pos.latitude, lng: pos.longitude, hiz: pos.speed * 3.6,
        );
      }
    });
  }

  Future<void> _durdur() async {
    await _konumStream?.cancel(); _konumStream = null;
    if (_aktifOturumId != null) {
      await GuzergahKayitService.oturumBitir(
          oturumId: _aktifOturumId!, toplamKm: _toplamKm);
    }
    setState(() { _aktif = false; _aktifOturumId = null; });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Güzergah kaydedildi! ${_toplamKm.toStringAsFixed(2)} km • $_noktaSayisi nokta'),
      backgroundColor: Colors.green, behavior: SnackBarBehavior.floating,
    ));
  }

  String get _sureBicim {
    if (_baslangicZaman == null) return '00:00';
    final fark = DateTime.now().difference(_baslangicZaman!);
    return '${fark.inMinutes.toString().padLeft(2, '0')}:${(fark.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: _navy, foregroundColor: Colors.white, elevation: 0,
        title: const Text('Güzergah Kayıt', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          Container(
            width: double.infinity, padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _aktif ? [Colors.green, const Color(0xFF2E7D32)] : [_navy, const Color(0xFF2a5298)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(
                color: (_aktif ? Colors.green : _navy).withValues(alpha: 0.3),
                blurRadius: 12, offset: const Offset(0, 6),
              )],
            ),
            child: Column(children: [
              Icon(_aktif ? Icons.route : Icons.route_outlined, color: Colors.white, size: 48),
              const SizedBox(height: 12),
              Text(_aktif ? 'Kayıt Aktif' : 'Kayıt Hazır',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              if (_aktif) ...[
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _StatKarti(ikon: Icons.straighten,    deger: '${_toplamKm.toStringAsFixed(2)} km', etiket: 'Mesafe'),
                  _StatKarti(ikon: Icons.place_outlined, deger: '$_noktaSayisi',                      etiket: 'Nokta'),
                  _StatKarti(ikon: Icons.timer_outlined, deger: _sureBicim,                           etiket: 'Süre'),
                ]),
              ],
            ]),
          ),
          const SizedBox(height: 30),
          if (!_aktif)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _navy.withValues(alpha: 0.1)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, color: _navy, size: 18),
                SizedBox(width: 10),
                Expanded(child: Text(
                  'Güzergah kaydını başlat. Servis boyunca konum ve rota Firestore\'a kaydedilir. Son 4 gün saklanır.',
                  style: TextStyle(fontSize: 12, height: 1.5),
                )),
              ]),
            ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _aktif ? Colors.red : Colors.green, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 6,
              ),
              onPressed: _yukleniyor ? null : _baslatDurdur,
              icon: _yukleniyor
                  ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Icon(_aktif ? Icons.stop : Icons.play_arrow, size: 28),
              label: Text(_aktif ? 'Kaydı Durdur' : 'Kaydı Başlat',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: _navy,
              side: BorderSide(color: _navy.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => Navigator.pushNamed(context, '/guzergah_gecmis'),
            icon: const Icon(Icons.history, size: 20),
            label: const Text('Geçmiş Güzergahlar'),
          ),
          const SizedBox(height: 30),
        ]),
      ),
    );
  }
}

class _StatKarti extends StatelessWidget {
  final IconData ikon; final String deger, etiket;
  const _StatKarti({required this.ikon, required this.deger, required this.etiket});

  @override
  Widget build(BuildContext context) => Column(children: [
    Icon(ikon, color: Colors.white70, size: 18), const SizedBox(height: 4),
    Text(deger, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
    Text(etiket, style: const TextStyle(color: Colors.white60, fontSize: 11)),
  ]);
}
