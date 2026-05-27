import 'dart:convert';
import 'package:http/http.dart' as http;

class AiService {
  static const _baseUrl = 'https://api.anthropic.com/v1/messages';
  static const _model   = 'claude-opus-4-6';
  static const _apiKey  = 'YOUR_API_KEY_HERE';

  static Future<String> sor(String prompt, {String? sistemMesaji}) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type':      'application/json',
          'x-api-key':         _apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model':      _model,
          'max_tokens': 1024,
          'system':     sistemMesaji ?? _sistem,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['content'][0]['text'] as String;
      } else {
        final hata = jsonDecode(response.body);
        return 'Hata: ${hata['error']['message'] ?? response.statusCode}';
      }
    } catch (e) {
      return 'Baglanti hatasi: $e';
    }
  }

  static Future<String> sohbet(
      List<Map<String, String>> gecmis,
      String yeniMesaj, {
        String? sistemMesaji,
      }) async {
    try {
      final mesajlar = [
        ...gecmis,
        {'role': 'user', 'content': yeniMesaj},
      ];
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type':      'application/json',
          'x-api-key':         _apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model':      _model,
          'max_tokens': 1024,
          'system':     sistemMesaji ?? _sistem,
          'messages':   mesajlar,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['content'][0]['text'] as String;
      } else {
        return 'Hata olustu. Lutfen tekrar deneyin.';
      }
    } catch (e) {
      return 'Baglanti hatasi: $e';
    }
  }

  static Future<Map<String, dynamic>?> sorJson(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type':      'application/json',
          'x-api-key':         _apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model':      _model,
          'max_tokens': 2048,
          'system':     'Sadece gecerli JSON don dur. Baska hicbir sey yazma.',
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
        }),
      );
      if (response.statusCode == 200) {
        final data  = jsonDecode(utf8.decode(response.bodyBytes));
        final metin = data['content'][0]['text'] as String;
        final temiz = metin.replaceAll('```json', '').replaceAll('```', '').trim();
        return jsonDecode(temiz) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static const _sistem =
      'Sen Servisim360 okul servisi yonetim sisteminin AI asistanisin. '
      'Turkce yanitlar verirsin. '
      'Okul servisi, ogrenci takibi, rota optimizasyonu, sofor yonetimi konularinda uzmansin. '
      'Kisa, net ve pratik yanitlar verirsin.';
}
