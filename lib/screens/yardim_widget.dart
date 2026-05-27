import 'package:flutter/material.dart';

class YardimButonu extends StatelessWidget {
  final String ekranAdi;
  const YardimButonu({super.key, required this.ekranAdi});

  static const navyBlue = Color(0xFF1a3a6b);

  static const Map<String, List<Map<String, String>>> _yardimlar = {
    'Dashboard': [
      {'baslik': 'Ana Harita', 'aciklama': 'Suruculerin canli konumlarini haritada gorebilirsiniz.'},
      {'baslik': 'Stat Kartlari', 'aciklama': 'Ogrenci, sofor ve rota sayilarini aninda gorursunuz.'},
      {'baslik': 'Hizli Islem', 'aciklama': 'Sag alttaki + butonu ile hizlica ogrenci veya sofor ekleyebilirsiniz.'},
    ],
    'Ogrenciler': [
      {'baslik': 'Ogrenci Ekle', 'aciklama': 'Sag alttaki + butonuna basarak yeni ogrenci ekleyebilirsiniz.'},
      {'baslik': 'Rota Atama', 'aciklama': 'Ogrenci eklerken veya duzenlerken rota atayabilirsiniz.'},
      {'baslik': 'Filtrele', 'aciklama': 'Atanmis/atanmamis filtreleri ile ogrencileri gruplayabilirsiniz.'},
    ],
    'Soforler': [
      {'baslik': 'Sofor Ekle', 'aciklama': '+ butonuyla sofor bilgilerini girebilirsiniz.'},
      {'baslik': 'Renk Atama', 'aciklama': 'Her sofore farkli renk atayarak haritada kolayca ayirt edebilirsiniz.'},
    ],
    'Rotalar': [
      {'baslik': 'Rota Olustur', 'aciklama': '+ butonuyla yeni rota ekleyebilirsiniz.'},
      {'baslik': 'Sofor Atama', 'aciklama': 'Rotaya sofor atayarak servisleri yonetebilirsiniz.'},
    ],
    'Gruplama': [
      {'baslik': 'Durak Ekle', 'aciklama': 'Harita sekmesinden istediginiz konuma durak ekleyebilirsiniz.'},
      {'baslik': 'Sofor Ata', 'aciklama': 'Her duraga sofor atayarak gruplamayi tamamlayabilirsiniz.'},
      {'baslik': 'Ogrenci Ata', 'aciklama': 'Ogrenciler sekmesinden ogrencileri duraklara atayabilirsiniz.'},
    ],
    'default': [
      {'baslik': 'Yardim', 'aciklama': 'Bu ekranla ilgili yardim icin yoneticinizle iletisime gecin.'},
    ],
  };

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.help_outline, color: Colors.white),
      onPressed: () => _yardimGoster(context),
    );
  }

  void _yardimGoster(BuildContext context) {
    final maddeler = _yardimlar[ekranAdi] ?? _yardimlar['default']!;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.help_outline, color: navyBlue, size: 22),
                const SizedBox(width: 8),
                Text('$ekranAdi - Yardim',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: navyBlue)),
              ],
            ),
            const SizedBox(height: 16),
            ...maddeler.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 5),
                    decoration: const BoxDecoration(
                        color: Color(0xFFFF8C00),
                        shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m['baslik']!,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        Text(m['aciklama']!,
                            style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kapat'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
