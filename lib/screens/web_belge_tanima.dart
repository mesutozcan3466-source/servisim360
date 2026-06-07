import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../services/session_service.dart';

// ════════════════════════════════════════════════════════════════
//  AI BELGE TANIMA — PDF/Görsel → Otomatik Sisteme Yükleme
//  Fiyat listesi, öğrenci listesi, sözleşme vb. tanır
// ════════════════════════════════════════════════════════════════

class WebBelgeTanima extends StatefulWidget {
  const WebBelgeTanima({super.key});
  @override
  State<WebBelgeTanima> createState() => _WebBelgeTanimaState();
}

class _WebBelgeTanimaState extends State<WebBelgeTanima> {
  static const _navy    = Color(0xFF1a3a6b);
  static const _turuncu = Color(0xFFFF8C00);

  String  _firmaId  = '';
  String  _projeId  = '';
  bool    _yukleniyor = false;
  String  _durum    = '';
  String  _aiCevap  = '';
  String  _belgeTipi = ''; // 'fiyat_listesi' | 'ogrenci_listesi' | 'sozlesme' | 'bilinmiyor'

  // Tanınan veriler
  List<Map<String, dynamic>> _taninanVeriler = [];
  Uint8List? _gorselBytes;
  String _gorselBase64 = '';

  // Adım
  int _adim = 0; // 0=yükle, 1=tanıyor, 2=önizleme, 3=tamamlandı

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _firmaId = await SessionService.instance.firmaIdAl() ?? '';
    _projeId = SessionService.instance.aktifProjeld ?? '';
  }

  // ── DOSYA SEÇ ────────────────────────────────────────────────
  Future<void> _dosyaSec() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'webp'],
      withData: true,
    );
    if (result == null || result.files.first.bytes == null) return;

    final bytes = result.files.first.bytes!;
    final ext   = result.files.first.extension?.toLowerCase() ?? '';

    setState(() {
      _gorselBytes  = bytes;
      _gorselBase64 = base64Encode(bytes);
      _adim         = 1;
      _durum        = 'Belge analiz ediliyor...';
      _taninanVeriler = [];
      _aiCevap      = '';
      _belgeTipi    = '';
    });

    await _aiIleAnalizEt(ext);
  }

  // ── PANO'DAN YAPISTIR ────────────────────────────────────────
  Future<void> _panodenYapistir() async {
    if (!kIsWeb) return;
    // Web Clipboard API
    setState(() {
      _durum = 'Panodan görsel alınıyor...';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lütfen dosyayı seçin veya sürükleyip bırakın'),
          behavior: SnackBarBehavior.floating),
    );
  }

  // ── CLAUDE AI İLE ANALİZ ─────────────────────────────────────
  Future<void> _aiIleAnalizEt(String ext) async {
    setState(() { _adim = 1; _yukleniyor = true; });

    try {
      final mediaType = ext == 'pdf' ? 'application/pdf'
          : ext == 'png' ? 'image/png'
          : ext == 'webp' ? 'image/webp'
          : 'image/jpeg';

      final prompt = '''Bu belgeyi analiz et ve içeriğini JSON formatında çıkar.

Belge türünü belirle:
- "fiyat_listesi": Mahalle/ilçe/km bazlı fiyat tablosu içeriyorsa
- "ogrenci_listesi": Öğrenci adları, telefon, adres bilgileri içeriyorsa  
- "sozlesme": Sözleşme/anlaşma belgesi ise
- "bilinmiyor": Diğer belgeler

SADECE JSON döndür, başka hiçbir şey yazma:

Fiyat listesi için:
{
  "belge_tipi": "fiyat_listesi",
  "okul_adi": "...",
  "ilce": "...",
  "kayitlar": [
    {"no": 1, "mahalle": "...", "km": "...", "ibb": "...", "donem1_ucret": 3600, "donem2_ucret": 4320}
  ]
}

Öğrenci listesi için:
{
  "belge_tipi": "ogrenci_listesi",
  "kayitlar": [
    {"ad": "...", "soyad": "...", "ogrenciTel": "...", "anneTel": "...", "babaTel": "...", "adres": "..."}
  ]
}

Bilinmeyen belge için:
{
  "belge_tipi": "bilinmiyor",
  "ozet": "belgenin kısa açıklaması"
}''';

      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-sonnet-4-20250514',
          'max_tokens': 4000,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': ext == 'pdf' ? 'document' : 'image',
                  'source': {
                    'type': 'base64',
                    'media_type': mediaType,
                    'data': _gorselBase64,
                  },
                },
                {
                  'type': 'text',
                  'text': prompt,
                }
              ]
            }
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data    = jsonDecode(response.body);
        final content = (data['content'] as List)
            .where((c) => c['type'] == 'text')
            .map((c) => c['text'] as String)
            .join('');

        setState(() { _aiCevap = content; });
        _jsonCozumle(content);
      } else {
        setState(() {
          _durum = 'AI hatası: ${response.statusCode}';
          _adim  = 0;
        });
      }
    } catch (e) {
      setState(() {
        _durum = 'Hata: $e';
        _adim  = 0;
      });
    }
    setState(() => _yukleniyor = false);
  }

  // ── JSON ÇÖZÜMLE ─────────────────────────────────────────────
  void _jsonCozumle(String content) {
    try {
      // JSON'u temizle
      String jsonStr = content.trim();
      if (jsonStr.contains('```json')) {
        jsonStr = jsonStr.split('```json')[1].split('```')[0].trim();
      } else if (jsonStr.contains('```')) {
        jsonStr = jsonStr.split('```')[1].split('```')[0].trim();
      }

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final tip  = json['belge_tipi'] as String? ?? 'bilinmiyor';

      setState(() {
        _belgeTipi = tip;
        _adim      = 2;
      });

      if (tip == 'fiyat_listesi') {
        final kayitlar = (json['kayitlar'] as List? ?? []);
        final ilce     = json['ilce'] as String? ?? '';
        final okul     = json['okul_adi'] as String? ?? '';
        _taninanVeriler = kayitlar.map<Map<String, dynamic>>((k) => {
          'mahalle'     : k['mahalle'] ?? '',
          'ilce'        : ilce,
          'okul'        : okul,
          'km'          : k['km']?.toString() ?? '',
          'ibb'         : k['ibb']?.toString() ?? '',
          'donem1_ucret': _parseUcret(k['donem1_ucret']),
          'donem2_ucret': _parseUcret(k['donem2_ucret']),
          'ucret'       : _parseUcret(k['donem1_ucret']), // varsayılan 1. dönem
          'tip'         : 'mahalle',
          'firmaId'     : _firmaId,
        }).toList();
        setState(() => _durum = '${_taninanVeriler.length} mahalle fiyatı tanındı');

      } else if (tip == 'ogrenci_listesi') {
        final kayitlar = (json['kayitlar'] as List? ?? []);
        _taninanVeriler = kayitlar.map<Map<String, dynamic>>((k) => {
          'ad'         : k['ad'] ?? '',
          'soyad'      : k['soyad'] ?? '',
          'adSoyad'    : '${k['ad'] ?? ''} ${k['soyad'] ?? ''}'.trim(),
          'ogrenciTel' : k['ogrenciTel'] ?? k['telefon'] ?? '',
          'anneTel'    : k['anneTel'] ?? '',
          'babaTel'    : k['babaTel'] ?? '',
          'adres'      : k['adres'] ?? '',
          'firmaId'    : _firmaId,
          'projeId'    : _projeId,
          'aktif'      : true,
          'bindi'      : false,
          'kayitTipi'  : 'belge_tanima',
        }).toList();
        setState(() => _durum = '${_taninanVeriler.length} öğrenci tanındı');

      } else {
        setState(() {
          _durum = json['ozet'] ?? 'Belge türü tanınamadı';
        });
      }
    } catch (e) {
      setState(() {
        _durum = 'JSON çözümleme hatası: $e\n\nAI Cevabı:\n$content';
        _adim  = 2;
        _belgeTipi = 'bilinmiyor';
      });
    }
  }

  double _parseUcret(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    final s = v.toString().replaceAll(RegExp(r'[^0-9,.]'), '').replaceAll(',', '.');
    return double.tryParse(s) ?? 0;
  }

  // ── SİSTEME KAYDET ───────────────────────────────────────────
  Future<void> _sistemeKaydet() async {
    if (_taninanVeriler.isEmpty || _firmaId.isEmpty) return;
    setState(() { _yukleniyor = true; _durum = 'Kaydediliyor...'; });

    int basarili = 0;
    if (_belgeTipi == 'fiyat_listesi') {
      for (final v in _taninanVeriler) {
        try {
          if (!_secili.contains(_taninanVeriler.indexOf(v))) continue;
          await FirebaseFirestore.instance.collection('fiyatlar').add({
            ...v,
            'olusturma': FieldValue.serverTimestamp(),
          });
          basarili++;
        } catch (_) {}
      }
    } else if (_belgeTipi == 'ogrenci_listesi') {
      for (int i = 0; i < _taninanVeriler.length; i++) {
        try {
          if (!_secili.contains(i)) continue;
          await FirebaseFirestore.instance.collection('students').add({
            ..._taninanVeriler[i],
            'olusturma': FieldValue.serverTimestamp(),
          });
          basarili++;
        } catch (_) {}
      }
    }

    setState(() {
      _yukleniyor = false;
      _adim       = 3;
      _durum      = '$basarili kayıt başarıyla eklendi ✓';
    });
  }

  // Seçili satırlar
  final Set<int> _secili = {};
  bool _tumSecili = true;

  void _tumunuSec(bool? v) {
    setState(() {
      _tumSecili = v ?? true;
      if (_tumSecili) {
        _secili.addAll(List.generate(_taninanVeriler.length, (i) => i));
      } else {
        _secili.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: const Row(children: [
          Icon(Icons.auto_awesome_rounded, size: 20),
          SizedBox(width: 8),
          Text('AI Belge Tanıma', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        actions: [
          if (_adim > 0)
            TextButton.icon(
              onPressed: () => setState(() {
                _adim = 0; _taninanVeriler = []; _gorselBytes = null;
                _belgeTipi = ''; _durum = ''; _secili.clear();
              }),
              icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 18),
              label: const Text('Yeni Belge', style: TextStyle(color: Colors.white70)),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_adim) {
      case 0: return _buildYukle();
      case 1: return _buildTaniyor();
      case 2: return _buildOnizleme();
      case 3: return _buildTamamlandi();
      default: return _buildYukle();
    }
  }

  // ── ADIM 0: YÜKLE ────────────────────────────────────────────
  Widget _buildYukle() {
    return Center(
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Başlık
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12)],
            ),
            child: Column(children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: _navy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.document_scanner_rounded, size: 40, color: _navy),
              ),
              const SizedBox(height: 16),
              const Text('AI Belge Tanıma',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _navy)),
              const SizedBox(height: 8),
              Text(
                'Fiyat listesi, öğrenci listesi veya sözleşme belgelerini\nyükleyin — AI otomatik tanıyıp sisteme eklesin',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 30),

              // Desteklenen belge türleri
              Row(children: [
                _tipKart(Icons.price_change_outlined, 'Fiyat Listesi',
                    'Mahalle/km fiyatları', Colors.green),
                const SizedBox(width: 12),
                _tipKart(Icons.people_outline, 'Öğrenci Listesi',
                    'Öğrenci bilgileri', Colors.blue),
                const SizedBox(width: 12),
                _tipKart(Icons.description_outlined, 'Sözleşme',
                    'Yakında...', Colors.grey),
              ]),
              const SizedBox(height: 30),

              // Yükleme butonu
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navy, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _dosyaSec,
                  icon: const Icon(Icons.upload_file_rounded, size: 22),
                  label: const Text('Belge Seç (PDF, JPG, PNG)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              Text('Desteklenen formatlar: PDF, JPG, PNG, WEBP',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _tipKart(IconData ikon, String baslik, String aciklama, Color renk) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: renk.withValues(alpha: 0.2)),
      ),
      child: Column(children: [
        Icon(ikon, color: renk, size: 28),
        const SizedBox(height: 6),
        Text(baslik, style: TextStyle(fontWeight: FontWeight.bold, color: renk, fontSize: 12)),
        Text(aciklama, style: TextStyle(color: Colors.grey[500], fontSize: 10),
            textAlign: TextAlign.center),
      ]),
    ));
  }

  // ── ADIM 1: TANIYOR ──────────────────────────────────────────
  Widget _buildTaniyor() {
    return Center(
      child: Container(
        width: 400, padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(
            width: 60, height: 60,
            child: CircularProgressIndicator(strokeWidth: 4, color: _navy),
          ),
          const SizedBox(height: 24),
          const Text('AI Analiz Ediyor...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _navy)),
          const SizedBox(height: 8),
          Text(_durum, style: TextStyle(color: Colors.grey[500], fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          // Görsel önizleme
          if (_gorselBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(_gorselBytes!, height: 150, fit: BoxFit.contain),
            ),
        ]),
      ),
    );
  }

  // ── ADIM 2: ÖNİZLEME ─────────────────────────────────────────
  Widget _buildOnizleme() {
    if (_belgeTipi == 'bilinmiyor') {
      return Center(child: Container(
        width: 500, padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.help_outline_rounded, size: 60, color: Colors.orange),
          const SizedBox(height: 16),
          const Text('Belge Türü Tanınamadı',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_durum, textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _navy, foregroundColor: Colors.white),
            onPressed: () => setState(() { _adim = 0; _gorselBytes = null; }),
            child: const Text('Tekrar Dene'),
          ),
        ]),
      ));
    }

    // Tüm seçililer başlangıçta seçili
    if (_secili.isEmpty && _taninanVeriler.isNotEmpty) {
      _secili.addAll(List.generate(_taninanVeriler.length, (i) => i));
    }

    return Column(children: [
      // Üst bilgi
      Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: Row(children: [
          Icon(_belgeTipi == 'fiyat_listesi' ? Icons.price_change_outlined : Icons.people_outline,
              color: _navy, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              _belgeTipi == 'fiyat_listesi' ? 'Fiyat Listesi Tanındı' : 'Öğrenci Listesi Tanındı',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _navy),
            ),
            Text(_durum, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ])),
          // Görsel küçük önizleme
          if (_gorselBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(_gorselBytes!, height: 50, width: 60, fit: BoxFit.cover),
            ),
          const SizedBox(width: 12),
          // Tümünü seç
          Row(children: [
            Checkbox(
              value: _tumSecili,
              onChanged: _tumunuSec,
              activeColor: _navy,
            ),
            const Text('Tümü', style: TextStyle(fontSize: 12)),
          ]),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: _turuncu, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: _secili.isEmpty ? null : _sistemeKaydet,
            icon: _yukleniyor
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded, size: 18),
            label: Text('${_secili.length} Kaydı Ekle',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ]),
      ),

      // Tablo
      Expanded(child: _belgeTipi == 'fiyat_listesi'
          ? _buildFiyatTablosu()
          : _buildOgrenciTablosu()),
    ]);
  }

  Widget _buildFiyatTablosu() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
        ),
        child: Column(children: [
          // Başlık
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: _navy,
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(children: const [
              SizedBox(width: 48),
              Expanded(flex: 3, child: Text('MAHALLE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 2, child: Text('İLÇE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(child: Text('KM', style: TextStyle(color: Colors.white70, fontSize: 12))),
              Expanded(child: Text('İBB', style: TextStyle(color: Colors.white70, fontSize: 12))),
              Expanded(flex: 2, child: Text('1.DÖNEM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 2, child: Text('2.DÖNEM', style: TextStyle(color: Colors.white70, fontSize: 12))),
            ]),
          ),
          ...List.generate(_taninanVeriler.length, (i) {
            final v   = _taninanVeriler[i];
            final sec = _secili.contains(i);
            return Container(
              decoration: BoxDecoration(
                color: sec ? Colors.white : Colors.grey.shade50,
                border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
              ),
              child: Row(children: [
                Checkbox(value: sec, activeColor: _navy,
                    onChanged: (v) => setState(() {
                      if (v == true) _secili.add(i); else _secili.remove(i);
                    })),
                Expanded(flex: 3, child: Text(v['mahalle'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                Expanded(flex: 2, child: Text(v['ilce'] ?? '',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12))),
                Expanded(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.yellow.shade100, borderRadius: BorderRadius.circular(4)),
                  child: Text(v['km'] ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                )),
                Expanded(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.yellow.shade100, borderRadius: BorderRadius.circular(4)),
                  child: Text(v['ibb']?.toString() ?? '', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                )),
                Expanded(flex: 2, child: Text(
                  '${(v['donem1_ucret'] as double?)?.toInt() ?? 0} TL',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13),
                )),
                Expanded(flex: 2, child: Text(
                  '${(v['donem2_ucret'] as double?)?.toInt() ?? 0} TL',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                )),
              ]),
            );
          }),
        ]),
      ),
    );
  }

  Widget _buildOgrenciTablosu() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: _navy,
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(children: const [
              SizedBox(width: 48),
              Expanded(flex: 2, child: Text('AD SOYAD', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
              Expanded(flex: 2, child: Text('ÖĞRENCİ TEL', style: TextStyle(color: Colors.white70, fontSize: 12))),
              Expanded(flex: 2, child: Text('ANNE TEL', style: TextStyle(color: Colors.white70, fontSize: 12))),
              Expanded(flex: 2, child: Text('BABA TEL', style: TextStyle(color: Colors.white70, fontSize: 12))),
              Expanded(flex: 3, child: Text('ADRES', style: TextStyle(color: Colors.white70, fontSize: 12))),
            ]),
          ),
          ...List.generate(_taninanVeriler.length, (i) {
            final v   = _taninanVeriler[i];
            final sec = _secili.contains(i);
            return Container(
              decoration: BoxDecoration(
                color: sec ? Colors.white : Colors.grey.shade50,
                border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
              ),
              child: Row(children: [
                Checkbox(value: sec, activeColor: _navy,
                    onChanged: (val) => setState(() {
                      if (val == true) _secili.add(i); else _secili.remove(i);
                    })),
                Expanded(flex: 2, child: Text('${v['ad'] ?? ''} ${v['soyad'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                Expanded(flex: 2, child: Text(v['ogrenciTel'] ?? '',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12))),
                Expanded(flex: 2, child: Text(v['anneTel'] ?? '',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12))),
                Expanded(flex: 2, child: Text(v['babaTel'] ?? '',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12))),
                Expanded(flex: 3, child: Text(v['adres'] ?? '',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            );
          }),
        ]),
      ),
    );
  }

  // ── ADIM 3: TAMAMLANDI ───────────────────────────────────────
  Widget _buildTamamlandi() {
    return Center(
      child: Container(
        width: 420, padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded, size: 50, color: Colors.green),
          ),
          const SizedBox(height: 20),
          const Text('Başarıyla Eklendi!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
          const SizedBox(height: 8),
          Text(_durum, textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const SizedBox(height: 30),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  foregroundColor: _navy,
                  side: const BorderSide(color: _navy),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () => setState(() {
                _adim = 0; _taninanVeriler = []; _gorselBytes = null;
                _belgeTipi = ''; _durum = ''; _secili.clear();
              }),
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: const Text('Yeni Belge'),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _navy, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Tamam'),
            )),
          ]),
        ]),
      ),
    );
  }
}
