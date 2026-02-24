import 'dart:convert';

import 'package:http/http.dart' as http;

const _baseUrl = 'http://127.0.0.1:8000/api/v1';

/// Cliente para el backend APV. Cambiar _baseUrl en producción.
class ApiClient {
  ApiClient({String? baseUrl}) : _base = baseUrl ?? _baseUrl;

  final String _base;

  Future<Map<String, dynamic>> getParametros() async {
    final r = await http.get(Uri.parse('$_base/parametros'));
    _throwIfNotOk(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// POST /simulate/apv con [body] (UserInput).
  Future<Map<String, dynamic>> simulateApv(Map<String, dynamic> body) async {
    final r = await http.post(
      Uri.parse('$_base/simulate/apv'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    _throwIfNotOk(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  void _throwIfNotOk(http.Response r) {
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw ApiException(r.statusCode, r.body);
    }
  }
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.body);
  final int statusCode;
  final String body;
  @override
  String toString() => 'ApiException($statusCode): $body';
}
