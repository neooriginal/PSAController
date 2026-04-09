import 'dart:convert';

import 'package:http/http.dart' as http;
import 'http_client_factory.dart';

class ApiClient {
  ApiClient({
    String? baseUrl,
  }) : _baseUrl = baseUrl ?? const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8787') {
    _client = createHttpClient();
  }

  late final http.Client _client;
  final String _baseUrl;

  Future<dynamic> getJson(String path) => _requestJson('GET', path);

  Future<dynamic> postJson(String path, Map<String, dynamic> body, {String? csrfToken}) {
    return _requestJson('POST', path, body: body, csrfToken: csrfToken);
  }

  Future<dynamic> putJson(String path, Map<String, dynamic> body, {String? csrfToken}) {
    return _requestJson('PUT', path, body: body, csrfToken: csrfToken);
  }

  Future<void> delete(String path, {String? csrfToken}) async {
    await _requestJson('DELETE', path, csrfToken: csrfToken);
  }

  Future<dynamic> _requestJson(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? csrfToken,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final request = http.Request(method, uri)
      ..headers['accept'] = 'application/json'
      ..headers['content-type'] = 'application/json';

    if (csrfToken != null && csrfToken.isNotEmpty) {
      request.headers['x-csrf-token'] = csrfToken;
    }
    if (body != null) {
      request.body = jsonEncode(body);
    }

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode >= 400) {
      dynamic payload;
      try {
        payload = jsonDecode(response.body);
      } catch (_) {
        payload = {'error': response.body};
      }
      throw ApiException(response.statusCode, payload['error']?.toString() ?? 'Request failed.');
    }

    if (response.body.isEmpty) {
      return null;
    }

    return jsonDecode(response.body);
  }
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
