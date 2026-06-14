import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/session_service.dart';
import 'web_dashboard.dart';
import 'package:servisim360/screens/web_admin_panel.dart' show WebAdminPanel;
import 'web_harita.dart';
import 'web_fiyat.dart';
import 'web_ayarlar.dart';
import 'web_super_admin.dart';

// ════════════════════════════════════════════════════════════════
//  WEB LAYOUT — Rol bazli sol sidebar
//  superAdmin  → Super Admin menusu
//  firmaAdmin  → Firma Admin menusu
// ════════════════════════════════════════════════════════════════
class WebLayout extends StatefulWidget {
  const WebLayout({super.key});
  @override
  State<WebLayout> createState() => _WebLayoutState();
}

class _WebLayoutState extends State<WebLayout> {
  static const _navy   = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);

  int    _seciliMenu  = 0;
  bool   _sidebarAcik = true;
  String _rol         = '';
  String _firmaAd     = '';
  String _email       = '';
  bool   _yukleniyor  = true;

  // Firma Admin menuleri
  final List<_MenuItem> _firmaMenuler = [
    _MenuItem(Icons.dashboard_outlined,      'Dashboard'),
    _MenuItem(Icons.people_outline,          'Ogrenciler'),
    _MenuItem(Icons.directions_bus_outlined, 'Soforler'),
    _MenuItem(Icons.map_outlined,            'Harita & Rota'),
    _MenuItem(Icons.bar_chart_outlined,      'Raporlar'),
    _MenuItem(Icons.attach_money_outlined,   'Fiyat & Fatura'),
    _MenuItem(Icons.settings_outlined,       'Ayarlar'),
  ];

  // Super Admin menuleri
  final List<_MenuItem> _superMenuler = [
    _MenuItem(Icons.business_outlined,       'Firmalar'),
    _MenuItem(Icons.verified_user_outlined,  'Lisanslar'),
    _MenuItem(Icons.map_outlined,            'Global Harita'),
    _MenuItem(Icons.people_outline,          'Kullanicilar'),
    _MenuItem(Icons.bar_chart_outlined,      'Istatistikler'),
    _MenuItem(Icons.settings_outlined,       'Sistem'),
  ];

  List<_MenuItem> get _menuler =>
      _rol == 'superAdmin' ? _superMenuler : _firmaMenuler;

  @override
  void initState() { super.initState(); _yukle(); }

  Future<void> _yukle() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _email = FirebaseAuth.instance.currentUser?.email ?? '';
    if (uid == null) { setState(() => _yukleniyor = false); return; }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('kullanicilar').doc(uid).get();
      final rawRol = doc.data()?['rol'] as String? ?? '';
      // Tum rol varyantlarini normalize et
      if (rawRol == 'superAdmin' || rawRol == 'super_admin' ||
          rawRol == 'superadmin' || rawRol == 'super yonetici' ||
          rawRol == 'Super Admin') {
        _rol = 'superAdmin';
      } else if (rawRol == 'firmaAdmin' || rawRol == 'firma_admin' ||
          rawRol == 'firmaadmin' || rawRol == 'firma yoneticisi' ||
          rawRol == 'Firma Admin' || rawRol == 'admin') {
        _rol = 'firmaAdmin';
      } else {
        _rol = rawRol;
      }

      final firmaId = doc.data()?['firmaId'] as String? ?? '';
      if (firmaId.isNotEmpty) {
        final fd = await FirebaseFirestore.instance
            .collection('firms').doc(firmaId).get();
        _firmaAd = fd.data()?['firmaAdi'] ?? fd.data()?['ad'] ?? '';
        // firmaId zaten session'da, sadece firma adini local tut
      }
    } catch (_) {}

    if (mounted) setState(() => _yukleniyor = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_yukleniyor) return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: Color(0xFF1a3a6b))),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Row(children: [

        // ── SOL SIDEBAR ──────────────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: _sidebarAcik ? 240 : 68,
          child: Container(
            color: _navy,
            child: Column(children: [
              // Logo + firma adi
              Container(
                height: 68,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                        color: _orange, borderRadius: BorderRadius.circular(10)),
                    child: const Center(child: Text('S',
                        style: TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold, fontSize: 22))),
                  ),
                  if (_sidebarAcik) ...[
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Servisim360',
                            style: TextStyle(color: Colors.white,
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        if (_firmaAd.isNotEmpty)
                          Text(_firmaAd,
                              style: const TextStyle(color: Colors.white60, fontSize: 11),
                              overflow: TextOverflow.ellipsis),
                      ],
                    )),
                  ],
                ]),
              ),

              // Rol badge
              if (_sidebarAcik)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: _rol == 'superAdmin'
                          ? Colors.amber.withValues(alpha: 0.2)
                          : _orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(_rol == 'superAdmin'
                        ? Icons.shield_outlined : Icons.business_outlined,
                        size: 12,
                        color: _rol == 'superAdmin' ? Colors.amber : _orange),
                    const SizedBox(width: 5),
                    Text(
                      _rol == 'superAdmin' ? 'Super Admin' :
                      _rol == 'firmaAdmin' ? 'Firma Admin' : _rol,
                      style: TextStyle(
                          color: _rol == 'superAdmin' ? Colors.amber : _orange,
                          fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ]),
                ),

              const Divider(color: Colors.white12, height: 1),

              // Menu items
              Expanded(child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: _menuler.length,
                itemBuilder: (_, i) {
                  final item  = _menuler[i];
                  final aktif = _seciliMenu == i;
                  return Tooltip(
                    message: _sidebarAcik ? '' : item.etiket,
                    child: InkWell(
                      onTap: () => setState(() => _seciliMenu = i),
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        padding: EdgeInsets.symmetric(
                            horizontal: _sidebarAcik ? 14 : 10, vertical: 11),
                        decoration: BoxDecoration(
                          color: aktif ? _orange : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(children: [
                          Icon(item.ikon,
                              color: aktif ? Colors.white : Colors.white60,
                              size: 20),
                          if (_sidebarAcik) ...[
                            const SizedBox(width: 12),
                            Expanded(child: Text(item.etiket,
                                style: TextStyle(
                                    color: aktif ? Colors.white : Colors.white70,
                                    fontWeight: aktif
                                        ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 13),
                                overflow: TextOverflow.ellipsis)),
                          ],
                        ]),
                      ),
                    ),
                  );
                },
              )),

              const Divider(color: Colors.white12, height: 1),

              // Kullanici bilgisi + cikis
              Container(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: _orange.withValues(alpha: 0.3),
                    child: Text(_email.isNotEmpty ? _email[0].toUpperCase() : 'A',
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  if (_sidebarAcik) ...[
                    const SizedBox(width: 8),
                    Expanded(child: Text(_email,
                        style: const TextStyle(color: Colors.white60, fontSize: 11),
                        overflow: TextOverflow.ellipsis)),
                    IconButton(
                      icon: const Icon(Icons.logout_outlined,
                          color: Colors.white54, size: 18),
                      tooltip: 'Cikis Yap',
                      onPressed: _cikisYap,
                    ),
                  ] else ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.logout_outlined,
                          color: Colors.white54, size: 16),
                      onPressed: _cikisYap,
                    ),
                  ],
                ]),
              ),
            ]),
          ),
        ),

        // ── SAG ICERIK ───────────────────────────────────────────
        Expanded(child: Column(children: [
          // Ust bar
          Container(
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 4, offset: const Offset(0, 2))],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              IconButton(
                icon: Icon(_sidebarAcik ? Icons.menu_open : Icons.menu,
                    color: _navy),
                onPressed: () => setState(() => _sidebarAcik = !_sidebarAcik),
              ),
              const SizedBox(width: 8),
              Text(_menuler[_seciliMenu].etiket,
                  style: const TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 18, color: _navy)),
              const Spacer(),

              // Proje secici (firma admin icin)
              if (_rol != 'superAdmin') ...[
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/proje_sec'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                        color: _navy.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _navy.withValues(alpha: 0.15))),
                    child: Row(children: [
                      const Icon(Icons.folder_outlined, size: 15, color: _navy),
                      const SizedBox(width: 6),
                      Text(
                        SessionService.instance.aktifProjeAdi ?? 'Proje Sec',
                        style: const TextStyle(color: _navy, fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.swap_horiz, size: 13, color: _navy),
                    ]),
                  ),
                ),
                const SizedBox(width: 12),
              ],

              // Bildirimler
              Stack(children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: _navy),
                  onPressed: () => Navigator.pushNamed(context, '/bildirimler'),
                ),
                Positioned(top: 8, right: 8, child: Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle),
                )),
              ]),
              const SizedBox(width: 8),
            ]),
          ),

          // Sayfa
          Expanded(child: _sayfaAl()),
        ])),
      ]),
    );
  }

  Widget _sayfaAl() {
    if (_rol == 'superAdmin') {
      switch (_seciliMenu) {
        case 0: return const WebSuperAdminFirmalar();
        case 1: return const WebSuperAdminLisanslar();
        case 2: return const WebSuperAdminHarita();
        case 3: return const WebSuperAdminKullanicilar();
        case 4: return const WebSuperAdminIstatistik();
        case 5: return const WebAyarlar();
        default: return const WebSuperAdminFirmalar();
      }
    } else {
      switch (_seciliMenu) {
        case 0: return const WebDashboard();
        case 1: return const WebAdminPanelRedirect(menu:5);
        case 2: return const WebAdminPanelRedirect(menu:4);
        case 3: return const WebHarita();
        case 4: return const WebAdminPanelRedirect(menu:15);
        case 5: return const WebFiyat();
        case 6: return const WebAyarlar();
        default: return const WebDashboard();
      }
    }
  }

  Future<void> _cikisYap() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }
}

class _MenuItem {
  final IconData ikon;
  final String etiket;
  const _MenuItem(this.ikon, this.etiket);
}

class WebAdminPanelRedirect extends StatelessWidget{
  final int menu;
  const WebAdminPanelRedirect({required this.menu});
  @override Widget build(BuildContext context)=>const WebAdminPanel();
}
