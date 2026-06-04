import 'package:flutter/material.dart';
import 'yardim_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/session_service.dart';

class SozlesmeScreen extends StatefulWidget {
  const SozlesmeScreen({super.key});

  @override
  State<SozlesmeScreen> createState() => _SozlesmeScreenState();
}

class _SozlesmeScreenState extends State<SozlesmeScreen> {
  static const _navy = Color(0xFF1a3a6b);
  static const _orange = Color(0xFFFF8C00);

  final _ctrl = TextEditingController();
  bool _yukleniyor = true;
  bool _kaydediliyor = false;
  String _firmaId = '';

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    final firmaId = await SessionService.instance.firmaIdAl();
    if (firmaId == null) { setState(() => _yukleniyor = false); return; }
    _firmaId = firmaId;

    final doc = await FirebaseFirestore.instance
        .collection('firms').doc(firmaId).get();
    _ctrl.text = doc.data()?['sozlesme'] ?? '';

    setState(() => _yukleniyor = false);
  }

  Future<void> _kaydet() async {
    if (_firmaId.isEmpty) return;
    setState(() => _kaydediliyor = true);
    try {
      await FirebaseFirestore.instance
          .collection('firms').doc(_firmaId)
          .update({'sozlesme': _ctrl.text.trim()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sozlesme kaydedildi!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _kaydediliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text(
          'Hizmet Sozlesmesi',
          style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
        ),
        backgroundColor: _navy,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          YardimButonu(ekranAdi: 'Sozlesmeler'),
          if (!_yukleniyor)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton(
                onPressed: _kaydediliyor ? null : _kaydet,
                child: _kaydediliyor
                    ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                    : const Text(
                  'Kaydet',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bilgi karti
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: _orange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Bu sozlesme velilere kayit formunda gosterilecek. '
                          'Veli onaylamadan kayit tamamlanamayacak.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Sozlesme metin alani
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4, height: 20,
                        decoration: BoxDecoration(
                          color: _orange,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Sozlesme Metni',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0d1f3c),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _ctrl,
                    maxLines: 20,
                    style: const TextStyle(
                        fontSize: 13, height: 1.6),
                    decoration: InputDecoration(
                      hintText:
                      'Hizmet sozlesmesi metnini buraya girin...\n\n'
                          'Ornek:\n'
                          'SERVIS HIZMET SOZLESMESI\n\n'
                          '1. Hizmet kapsami\n'
                          '2. Ucret ve odeme kosullari\n'
                          '3. Iptal kosullari\n'
                          '4. Taraflarin yukumlulukler\n...',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                        BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                        BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _navy),
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Onizleme
            if (_ctrl.text.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade200),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.visibility_outlined,
                            color: Colors.green.shade600, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Veli Onizlemesi',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _ctrl.text,
                      style: const TextStyle(
                          fontSize: 12, height: 1.7,
                          color: Color(0xFF374151)),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _kaydediliyor ? null : _kaydet,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _kaydediliyor
                    ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                    : const Text(
                  'Sozlesmeyi Kaydet',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
