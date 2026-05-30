import 'package:flutter/material.dart';

// Web'de mobile_scanner yok — stub widget
class QrMobileTarayici extends StatelessWidget {
  final String tip;
  final bool isleniyor, tamamlandi, basarili;
  final String? sonucMesaj;
  final void Function(String) onQrOkundu;
  final VoidCallback onManuelGiris;

  const QrMobileTarayici({
    super.key,
    required this.tip,
    required this.isleniyor,
    required this.tamamlandi,
    required this.basarili,
    required this.sonucMesaj,
    required this.onQrOkundu,
    required this.onManuelGiris,
  });

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Web stub'));
  }
}