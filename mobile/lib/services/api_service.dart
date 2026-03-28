import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// API Exception
// ─────────────────────────────────────────────────────────────────────────────
class ApiException implements Exception {
  final String message;
  final int statusCode;
  const ApiException(this.message, this.statusCode);
  @override
  String toString() => message;
}

// ─────────────────────────────────────────────────────────────────────────────
// ApiService
// ─────────────────────────────────────────────────────────────────────────────
class ApiService {
  /// Override with:
  /// `flutter run --dart-define=API_BASE_URL=http://<HOST_IP>:5001/api`
  /// Android emulator  → `http://10.0.2.2:5001/api`
  /// iOS simulator     → `http://localhost:5001/api`
  /// Android USB (adb reverse) → `http://127.0.0.1:5001/api`
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static const String _legacyLanBaseUrl = 'http://192.168.1.3:5001/api';
  static String _activeBaseUrl = _initialBaseUrl();

  static String get baseUrl => _activeBaseUrl;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _bgTokenKey = 'jwt_token_bg';
  static const _bgBaseUrlKey = 'api_base_url_bg';

  static String _initialBaseUrl() {
    final configured = _configuredBaseUrl.trim();
    if (configured.isNotEmpty) return configured;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://127.0.0.1:5001/api';
    }
    return _legacyLanBaseUrl;
  }

  static List<String> _candidateBaseUrls() {
    final candidates = <String>[];
    void add(String value) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty && !candidates.contains(trimmed)) {
        candidates.add(trimmed);
      }
    }

    add(_activeBaseUrl);
    add(_configuredBaseUrl);

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      add('http://127.0.0.1:5001/api');
      add('http://10.0.2.2:5001/api');
      add(_legacyLanBaseUrl);
    } else {
      add('http://localhost:5001/api');
      add(_legacyLanBaseUrl);
    }
    return candidates;
  }

  static String absoluteFileUrl(String urlOrPath) {
    if (urlOrPath.startsWith('http://') || urlOrPath.startsWith('https://')) {
      return urlOrPath;
    }
    final apiUri = Uri.parse(baseUrl);
    final normalizedPath = urlOrPath.startsWith('/') ? urlOrPath : '/$urlOrPath';
    return Uri(
      scheme: apiUri.scheme,
      host: apiUri.host,
      port: apiUri.hasPort ? apiUri.port : null,
      path: normalizedPath,
    ).toString();
  }

  // ── Token ──────────────────────────────────────────────────────────────────
  static Future<String?> getToken() => _storage.read(key: 'jwt_token');
  static Future<void> saveToken(String t) async {
    await _storage.write(key: 'jwt_token', value: t);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bgTokenKey, t);
  }

  static Future<void> deleteToken() async {
    await _storage.delete(key: 'jwt_token');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_bgTokenKey);
  }

  static Future<void> syncBackgroundConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bgBaseUrlKey, _activeBaseUrl);
  }

  // ── User ───────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> getSavedUser() async {
    final raw = await _storage.read(key: 'user_data');
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> saveUser(Map<String, dynamic> user) =>
      _storage.write(key: 'user_data', value: jsonEncode(user));

  static Future<void> clearAll() async {
    await _storage.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_bgTokenKey);
  }

  // ── Headers ────────────────────────────────────────────────────────────────
  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final h = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await getToken();
      if (token != null) h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  // ── Response handler ───────────────────────────────────────────────────────
  static Map<String, dynamic> _decode(http.Response res) {
    final raw = utf8.decode(res.bodyBytes);
    Map<String, dynamic> body;
    try {
      body = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return {'message': raw};
      }
      throw ApiException(
        'Server returned an unexpected response (${res.statusCode}). Check backend logs.',
        res.statusCode,
      );
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    throw ApiException(
      body['message'] ?? 'Request failed (${res.statusCode})',
      res.statusCode,
    );
  }

  static Never _networkError(Object error) {
    if (error is ApiException) {
      throw error;
    }
    if (error is TimeoutException) {
      throw ApiException(
        'Connection timeout at $baseUrl. For USB Android run: adb reverse tcp:5001 tcp:5001',
        0,
      );
    }
    if (error is SocketException) {
      throw ApiException(
        'Cannot connect to server at $baseUrl. For USB Android run: adb reverse tcp:5001 tcp:5001',
        0,
      );
    }
    throw ApiException('Unexpected network error: $error', 0);
  }

  static Future<Map<String, dynamic>> _requestWithFallback(
    Future<http.Response> Function(String currentBaseUrl) request,
  ) async {
    Object? lastNetworkError;
    for (final candidate in _candidateBaseUrls()) {
      try {
        final response = await request(candidate);
        final data = _decode(response);
        if (_activeBaseUrl != candidate) {
          _activeBaseUrl = candidate;
          await syncBackgroundConfig();
        }
        return data;
      } on ApiException {
        rethrow;
      } on TimeoutException catch (e) {
        lastNetworkError = e;
      } on SocketException catch (e) {
        lastNetworkError = e;
      }
    }

    if (lastNetworkError != null) {
      _networkError(lastNetworkError);
    }
    throw ApiException('Cannot connect to server at $baseUrl', 0);
  }

  // ── GET ────────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      return _requestWithFallback((currentBaseUrl) async {
        return http
            .get(
              Uri.parse('$currentBaseUrl$endpoint'),
              headers: await _headers(),
            )
            .timeout(const Duration(seconds: 15));
      });
    } catch (e) {
      _networkError(e);
    }
  }

  // ── POST ───────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    try {
      return _requestWithFallback((currentBaseUrl) async {
        return http
            .post(
              Uri.parse('$currentBaseUrl$endpoint'),
              headers: await _headers(auth: auth),
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 15));
      });
    } catch (e) {
      _networkError(e);
    }
  }

  // ── PATCH ──────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> patch(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      return _requestWithFallback((currentBaseUrl) async {
        return http
            .patch(
              Uri.parse('$currentBaseUrl$endpoint'),
              headers: await _headers(),
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 15));
      });
    } catch (e) {
      _networkError(e);
    }
  }

  // ── PUT ────────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      return _requestWithFallback((currentBaseUrl) async {
        return http
            .put(
              Uri.parse('$currentBaseUrl$endpoint'),
              headers: await _headers(),
              body: jsonEncode(body),
            )
            .timeout(const Duration(seconds: 15));
      });
    } catch (e) {
      _networkError(e);
    }
  }

  // ── Multipart File Upload ──────────────────────────────────────────────────
  static Future<Map<String, dynamic>> uploadFile(
    String endpoint,
    String filePath,
    Map<String, String> fields,
  ) async {
    try {
      return _requestWithFallback((currentBaseUrl) async {
        final token = await getToken();
        final request =
            http.MultipartRequest('POST', Uri.parse('$currentBaseUrl$endpoint'));
        if (token != null) request.headers['Authorization'] = 'Bearer $token';
        request.fields.addAll(fields);
        request.files.add(await http.MultipartFile.fromPath('file', filePath));
        final streamed = await request.send().timeout(const Duration(seconds: 20));
        return http.Response.fromStream(streamed);
      });
    } catch (e) {
      _networkError(e);
    }
  }
}
