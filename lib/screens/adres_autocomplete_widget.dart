import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// ════════════════════════════════════════════════════════════════
//  ADRES AUTOCOMPLETE — Google Places API
//  Öğrenci/Veli kayıt formunda adres yazarken öneri listesi
// ════════════════════════════════════════════════════════════════
class AdresAutocomplete extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final ValueChanged<String>? onAdresSecildi;
  final double? lat;
  final double? lng;

  const AdresAutocomplete({
    super.key,
    required this.controller,
    this.labelText = 'Adres',
    this.onAdresSecildi,
    this.lat,
    this.lng,
  });

  @override
  State<AdresAutocomplete> createState() => _AdresAutocompleteState();
}

class _AdresAutocompleteState extends State<AdresAutocomplete> {
  static const _navy   = Color(0xFF1a3a6b);
  static const _apiKey = 'AIzaSyAyPvU0fP3lpqCqWuB29jl6ScVZXFFKOgU';

  List<_Oneri> _oneriler = [];
  bool _yukleniyor = false;
  bool _listeleGoster = false;
  final _layerLink = LayerLink();
  OverlayEntry? _overlay;

  @override
  void dispose() {
    _overlayKapat();
    super.dispose();
  }

  Future<void> _ara(String girdi) async {
    if (girdi.length < 3) {
      _overlayKapat();
      return;
    }

    setState(() => _yukleniyor = true);

    try {
      final konum = widget.lat != null && widget.lng != null
          ? '&location=${widget.lat},${widget.lng}&radius=50000'
          : '&components=country:tr';

      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/autocomplete/json'
              '?input=${Uri.encodeComponent(girdi)}'
              '&language=tr'
              '$konum'
              '&key=$_apiKey'
      );

      final resp = await http.get(url);
      final data = jsonDecode(resp.body);

      if (data['status'] == 'OK') {
        final oneriler = (data['predictions'] as List).map((p) => _Oneri(
          tanim:    p['description'] as String,
          placeId:  p['place_id'] as String,
        )).toList();

        setState(() { _oneriler = oneriler; _yukleniyor = false; });
        _overlayGoster();
      } else {
        setState(() { _oneriler = []; _yukleniyor = false; });
        _overlayKapat();
      }
    } catch (_) {
      setState(() { _yukleniyor = false; });
    }
  }

  void _overlayGoster() {
    _overlayKapat();
    if (_oneriler.isEmpty) return;

    _overlay = OverlayEntry(
      builder: (_) => Positioned(
        width: 400,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 56),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _oneriler.length,
                itemBuilder: (_, i) {
                  final o = _oneriler[i];
                  return InkWell(
                    onTap: () => _sec(o),
                    borderRadius: i == 0
                        ? const BorderRadius.vertical(top: Radius.circular(12))
                        : i == _oneriler.length - 1
                        ? const BorderRadius.vertical(bottom: Radius.circular(12))
                        : BorderRadius.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(children: [
                        const Icon(Icons.location_on_outlined, color: _navy, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(o.tanim,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis)),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlay!);
  }

  void _overlayKapat() {
    _overlay?.remove();
    _overlay = null;
  }

  void _sec(_Oneri oneri) {
    widget.controller.text = oneri.tanim;
    widget.onAdresSecildi?.call(oneri.tanim);
    _overlayKapat();
    setState(() => _oneriler = []);
  }

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
    link: _layerLink,
    child: TextField(
      controller: widget.controller,
      decoration: InputDecoration(
        labelText: widget.labelText,
        prefixIcon: const Icon(Icons.location_on_outlined, color: _navy, size: 18),
        suffixIcon: _yukleniyor
            ? const SizedBox(width: 16, height: 16,
            child: Padding(padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2, color: _navy)))
            : widget.controller.text.isNotEmpty
            ? IconButton(
            icon: const Icon(Icons.clear, size: 16),
            onPressed: () {
              widget.controller.clear();
              _overlayKapat();
              setState(() => _oneriler = []);
            })
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      onChanged: _ara,
      onTap: () {
        if (widget.controller.text.length >= 3) _ara(widget.controller.text);
      },
    ),
  );
}

class _Oneri {
  final String tanim, placeId;
  const _Oneri({required this.tanim, required this.placeId});
}

// ════════════════════════════════════════════════════════════════
//  İSİM AUTOCOMPLETE — Öğrenci/Veli kayıtta isim önerisi
// ════════════════════════════════════════════════════════════════
class IsimAutocomplete extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String koleksiyon; // 'students' veya 'parents'
  final String firmaId;

  const IsimAutocomplete({
    super.key,
    required this.controller,
    required this.koleksiyon,
    required this.firmaId,
    this.labelText = 'Ad Soyad',
  });

  @override
  State<IsimAutocomplete> createState() => _IsimAutocompleteState();
}

class _IsimAutocompleteState extends State<IsimAutocomplete> {
  static const _navy = Color(0xFF1a3a6b);
  List<String> _oneriler = [];
  final _layerLink = LayerLink();
  OverlayEntry? _overlay;

  @override
  void dispose() { _overlayKapat(); super.dispose(); }

  void _overlayKapat() { _overlay?.remove(); _overlay = null; }

  void _overlayGoster() {
    _overlayKapat();
    if (_oneriler.isEmpty) return;

    _overlay = OverlayEntry(builder: (_) => Positioned(
      width: 300,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 56),
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: _oneriler.map((ad) => InkWell(
                onTap: () {
                  widget.controller.text = ad;
                  _overlayKapat();
                  setState(() => _oneriler = []);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(children: [
                    const Icon(Icons.person_outline, color: _navy, size: 16),
                    const SizedBox(width: 8),
                    Text(ad, style: const TextStyle(fontSize: 13)),
                  ]),
                ),
              )).toList(),
            ),
          ),
        ),
      ),
    ));
    Overlay.of(context).insert(_overlay!);
  }

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
    link: _layerLink,
    child: TextField(
      controller: widget.controller,
      decoration: InputDecoration(
        labelText: widget.labelText,
        prefixIcon: const Icon(Icons.person_outline, color: _navy, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      onChanged: (v) {
        // Türkçe karakter dönüşüm önerileri
        if (v.isNotEmpty) {
          // Basit öneri: büyük harf ilk harfler
          final duzeltilmis = v.split(' ')
              .map((k) => k.isNotEmpty ? k[0].toUpperCase() + k.substring(1).toLowerCase() : '')
              .join(' ');
          if (duzeltilmis != v && v.endsWith(' ')) {
            widget.controller.value = TextEditingValue(
              text: duzeltilmis,
              selection: TextSelection.collapsed(offset: duzeltilmis.length),
            );
          }
        }
      },
    ),
  );
}
