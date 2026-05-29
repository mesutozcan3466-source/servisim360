import 'package:flutter/material.dart';
import '../services/session_service.dart';

class WebAyarlar extends StatelessWidget {
  const WebAyarlar({super.key});
  static const _navy = Color(0xFF1a3a6b);

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Ayarlar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _navy)),
      const SizedBox(height: 20),
      Wrap(spacing: 16, runSpacing: 16, children: [
        _AyarKart(Icons.access_time_outlined, 'Servis Saatleri', 'Calisma saatlerini duzenle',
            Colors.blue, () => Navigator.pushNamed(context, '/servis_saati')),
        _AyarKart(Icons.description_outlined, 'Sozlesme', 'Veli sozlesmesini duzenle',
            Colors.teal, () => Navigator.pushNamed(context, '/sozlesme')),
        _AyarKart(Icons.link_outlined, 'Kayit Linki', 'Yeni kayit linki olustur',
            _navy, () => Navigator.pushNamed(context, '/kayit_link')),
        _AyarKart(Icons.qr_code_2, 'QR Afis', 'QR kod afisi olustur',
            Colors.indigo, () => Navigator.pushNamed(context, '/qr_afis')),
        _AyarKart(Icons.notifications_outlined, 'Bildirimler', 'Bildirim ayarlari',
            Colors.orange, () => Navigator.pushNamed(context, '/bildirimler')),
        _AyarKart(Icons.folder_outlined, 'Proje Sec', 'Aktif projeyi degistir',
            Colors.purple, () => Navigator.pushNamed(context, '/proje_sec')),
        _AyarKart(Icons.people_outline, 'Sofor Yonetimi', 'Sofor ekle / duzenle',
            Colors.green, () => Navigator.pushNamed(context, '/suruculer')),
        _AyarKart(Icons.lock_outlined, 'Sifre Degistir', 'Hesap sifreni guncelle',
            Colors.grey, () => Navigator.pushNamed(context, '/sifre_degistir')),
      ]),
    ]),
  );
}

class _AyarKart extends StatelessWidget {
  final IconData ikon; final String baslik, alt; final Color renk; final VoidCallback onTap;
  const _AyarKart(this.ikon, this.baslik, this.alt, this.renk, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: renk.withValues(alpha: 0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: renk.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(ikon, color: renk, size: 24)),
        const SizedBox(height: 12),
        Text(baslik, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 4),
        Text(alt, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ]),
    ),
  );
}
