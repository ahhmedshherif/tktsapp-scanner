import 'package:flutter_test/flutter_test.dart';
import 'package:tktsapp_scanner/src/core/api_client.dart';

void main() {
  group('ApiClient.normalizeBaseUrl', () {
    test('keeps a complete API v1 URL', () {
      expect(
        ApiClient.normalizeBaseUrl('https://tktsapp.com/api/v1/'),
        'https://tktsapp.com/api/v1',
      );
    });

    test('adds the API v1 path when CI provides only the origin', () {
      expect(
        ApiClient.normalizeBaseUrl('https://tktsapp.com'),
        'https://tktsapp.com/api/v1',
      );
    });

    test('falls back to the production API for invalid configuration', () {
      expect(
        ApiClient.normalizeBaseUrl('not a URL'),
        'https://tktsapp.com/api/v1',
      );
    });
  });
}
