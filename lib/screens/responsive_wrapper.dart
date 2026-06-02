import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// ════════════════════════════════════════════════════════════════
// RESPONSIVE WRAPPER
// Web'de sidebar + içerik, mobilde normal ekran
// ════════════════════════════════════════════════════════════════

/// Ekran genişliğine göre layout tipi
enum LayoutTip { mobil, tablet, masaustu }

LayoutTip layoutTipAl(BuildContext context) {
  final w = MediaQuery.of(context).size.width;
  if (w < 600)  return LayoutTip.mobil;
  if (w < 1024) return LayoutTip.tablet;
  return LayoutTip.masaustu;
}

bool isMobil(BuildContext context) =>
    layoutTipAl(context) == LayoutTip.mobil;
bool isTablet(BuildContext context) =>
    layoutTipAl(context) == LayoutTip.tablet;
bool isMasaustu(BuildContext context) =>
    layoutTipAl(context) == LayoutTip.masaustu;

// ════════════════════════════════════════════════════════════════
// WEB SIDEBAR LAYOUT
// Sol sidebar + sağda içerik
// ════════════════════════════════════════════════════════════════
class WebSidebarLayout extends StatefulWidget {
  final List<SidebarMenuItem> menuler;
  final List<Widget> sayfalar;
  final String baslik;
  final String kullaniciAd;
  final String firmaAd;
  final VoidCallback onCikis;
  final int baslangicIndex;
  final Widget? ekAlan; // Header'da ekstra alan (proje seçici vb.)

  const WebSidebarLayout({
    super.key,
    required this.menuler,
    required this.sayfalar,
    required this.baslik,
    required this.kullaniciAd,
    required this.firmaAd,
    required this.onCikis,
    this.baslangicIndex = 0,
    this.ekAlan,
  });

  @override
  State<WebSidebarLayout> createState() => _WebSidebarLayoutState();
}

class _WebSidebarLayoutState extends State<WebSidebarLayout> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  int  _secili    = 0;
  bool _darSidebar = false;

  @override
  void initState() {
    super.initState();
    _secili = widget.baslangicIndex;
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final mobil = w < 700;

    if (mobil) {
      // Mobil: alt navigasyon
      return _MobilLayout(
        menuler:     widget.menuler,
        sayfalar:    widget.sayfalar,
        baslik:      widget.baslik,
        kullaniciAd: widget.kullaniciAd,
        firmaAd:     widget.firmaAd,
        onCikis:     widget.onCikis,
        ekAlan:      widget.ekAlan,
      );
    }

    // Web: sol sidebar
    final sidebarW = _darSidebar ? 64.0 : 220.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Row(children: [

        // ── Sol Sidebar ──────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: sidebarW,
          decoration: BoxDecoration(
              color: _navy,
              boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8)]),
          child: Column(children: [

            // Logo alanı
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                      color: _turuncu,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Center(child: Text('S', style: TextStyle(
                      color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.bold)))),
                if (!_darSidebar) ...[
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Servisim360',
                      style: TextStyle(color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis)),
                ],
              ]),
            ),

            // Firma adı
            if (!_darSidebar && widget.firmaAd.isNotEmpty)
              Container(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.business_outlined,
                        color: Colors.white54, size: 14),
                    const SizedBox(width: 6),
                    Expanded(child: Text(widget.firmaAd,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                        overflow: TextOverflow.ellipsis)),
                  ]),
                ),
              ),

            const Divider(color: Colors.white12, height: 1),

            // Menü öğeleri
            Expanded(child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: widget.menuler.length,
              itemBuilder: (_, i) {
                final m      = widget.menuler[i];
                final aktif  = _secili == i;
                return Tooltip(
                  message: _darSidebar ? m.etiket : '',
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: aktif
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10)),
                    child: ListTile(
                      leading: Stack(children: [
                        Icon(m.ikon,
                            color: aktif ? _turuncu : Colors.white60,
                            size: 22),
                        if (m.rozet != null && m.rozet! > 0)
                          Positioned(right: 0, top: 0,
                              child: Container(
                                width: 14, height: 14,
                                decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle),
                                child: Center(child: Text(
                                    '${m.rozet}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold))))),
                      ]),
                      title: _darSidebar ? null : Text(m.etiket,
                          style: TextStyle(
                              color: aktif ? Colors.white : Colors.white70,
                              fontSize: 13,
                              fontWeight: aktif
                                  ? FontWeight.bold : FontWeight.normal)),
                      dense: true,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: _darSidebar ? 18 : 12,
                          vertical: 2),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      onTap: () => setState(() => _secili = i),
                    ),
                  ),
                );
              },
            )),

            const Divider(color: Colors.white12, height: 1),

            // Alt: kullanıcı + çıkış
            Container(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                if (!_darSidebar)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: _turuncu,
                        child: Text(
                            widget.kullaniciAd.isNotEmpty
                                ? widget.kullaniciAd[0].toUpperCase() : 'U',
                            style: const TextStyle(color: Colors.white,
                                fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(widget.kullaniciAd,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                          overflow: TextOverflow.ellipsis)),
                    ]),
                  ),
                const SizedBox(height: 8),
                Row(children: [
                  // Sidebar toggle
                  Expanded(child: IconButton(
                    icon: Icon(
                        _darSidebar
                            ? Icons.chevron_right_rounded
                            : Icons.chevron_left_rounded,
                        color: Colors.white54),
                    onPressed: () =>
                        setState(() => _darSidebar = !_darSidebar),
                    tooltip: _darSidebar ? 'Genisl et' : 'Daralt',
                  )),
                  IconButton(
                    icon: const Icon(Icons.logout_outlined,
                        color: Colors.white54, size: 20),
                    onPressed: widget.onCikis,
                    tooltip: 'Cikis Yap',
                  ),
                ]),
              ]),
            ),
          ]),
        ),

        // ── Sağ İçerik ─────────────────────────────────
        Expanded(child: Column(children: [

          // Üst header
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(
                    color: Color(0xFFEEEEEE)))),
            child: Row(children: [
              Text(widget.menuler[_secili].etiket,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold,
                      color: Color(0xFF1a3a6b))),
              const Spacer(),
              if (widget.ekAlan != null) widget.ekAlan!,
            ]),
          ),

          // İçerik
          Expanded(child: widget.sayfalar.length > _secili
              ? widget.sayfalar[_secili]
              : const SizedBox()),
        ])),
      ]),
    );
  }
}

// ── Mobil Layout ─────────────────────────────────────────────────
class _MobilLayout extends StatefulWidget {
  final List<SidebarMenuItem> menuler;
  final List<Widget> sayfalar;
  final String baslik, kullaniciAd, firmaAd;
  final VoidCallback onCikis;
  final Widget? ekAlan;
  const _MobilLayout({
    required this.menuler, required this.sayfalar,
    required this.baslik,  required this.kullaniciAd,
    required this.firmaAd, required this.onCikis,
    this.ekAlan,
  });
  @override
  State<_MobilLayout> createState() => _MobilLayoutState();
}

class _MobilLayoutState extends State<_MobilLayout> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);
  int _secili = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.baslik, style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold)),
          if (widget.firmaAd.isNotEmpty)
            Text(widget.firmaAd, style: const TextStyle(
                fontSize: 11, color: Colors.white60)),
        ]),
        actions: [
          if (widget.ekAlan != null) widget.ekAlan!,
          IconButton(
              icon: const Icon(Icons.logout_outlined),
              onPressed: widget.onCikis,
              tooltip: 'Cikis Yap'),
        ],
      ),
      body: widget.sayfalar.length > _secili
          ? widget.sayfalar[_secili]
          : const SizedBox(),
      bottomNavigationBar: widget.menuler.length <= 5
          ? NavigationBar(
              selectedIndex: _secili,
              onDestinationSelected: (i) => setState(() => _secili = i),
              backgroundColor: Colors.white,
              indicatorColor: _navy.withValues(alpha: 0.12),
              destinations: widget.menuler.map((m) =>
                  NavigationDestination(
                      icon: Badge(
                        isLabelVisible:
                            m.rozet != null && m.rozet! > 0,
                        label: Text('${m.rozet ?? 0}'),
                        child: Icon(m.ikon)),
                      selectedIcon: Icon(m.ikon, color: _navy),
                      label: m.etiket)).toList(),
            )
          : _CokluAltMenu(
              menuler: widget.menuler,
              secili: _secili,
              onChange: (i) => setState(() => _secili = i)),
    );
  }
}

class _CokluAltMenu extends StatelessWidget {
  final List<SidebarMenuItem> menuler;
  final int secili;
  final ValueChanged<int> onChange;
  const _CokluAltMenu({
      required this.menuler, required this.secili, required this.onChange});

  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE)))),
      child: Row(children: menuler.asMap().entries.map((e) {
        final i     = e.key;
        final m     = e.value;
        final aktif = secili == i;
        return Expanded(child: InkWell(
          onTap: () => onChange(i),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(m.ikon,
                color: aktif ? _navy : Colors.grey,
                size: 22),
            const SizedBox(height: 3),
            Text(m.etiket, style: TextStyle(
                fontSize: 9,
                color: aktif ? _navy : Colors.grey,
                fontWeight: aktif ? FontWeight.bold : FontWeight.normal)),
          ]),
        ));
      }).toList()),
    );
  }
}

// ── Model ────────────────────────────────────────────────────────
class SidebarMenuItem {
  final IconData ikon;
  final String   etiket;
  final int?     rozet;
  const SidebarMenuItem(this.ikon, this.etiket, {this.rozet});
}
