import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/api_service.dart';

void main() {
  test('default API points to the production Railway service', () {
    expect(
      Uri.parse(ApiService.baseUrl).origin,
      'https://medical-suivi-api-production.up.railway.app',
    );
    expect(Uri.parse(ApiService.baseUrl).path, '/api');
  });

  group('ApiService.apiUri', () {
    test('adds the API prefix when the base URL is the server root', () {
      expect(
        ApiService.apiUri('https://api.example.test', '/auth/register').path,
        '/api/auth/register',
      );
    });

    test('does not duplicate an existing API prefix', () {
      expect(
        ApiService.apiUri(
          'https://api.example.test/api/',
          '/auth/register',
        ).path,
        '/api/auth/register',
      );
    });

    test('preserves a deployment base path before the API prefix', () {
      expect(
        ApiService.apiUri(
          'https://example.test/medical',
          '/auth/register',
        ).path,
        '/medical/api/auth/register',
      );
    });
  });

  group('ApiService.absoluteFileUrl', () {
    test('resolves stored upload paths against the API host', () {
      final resolved = Uri.parse(
        ApiService.absoluteFileUrl('/uploads/lab-result.pdf'),
      );
      final api = Uri.parse(ApiService.baseUrl);

      expect(resolved.scheme, api.scheme);
      expect(resolved.host, api.host);
      expect(resolved.path, '/uploads/lab-result.pdf');
    });

    test('preserves absolute cloud-storage document URLs', () {
      const url = 'https://res.cloudinary.com/example/raw/result.pdf';
      expect(ApiService.absoluteFileUrl(url), url);
    });

    test('rejects missing and unsupported document URLs', () {
      expect(
        () => ApiService.absoluteFileUrl('  '),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => ApiService.absoluteFileUrl('file:///private/result.pdf'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
