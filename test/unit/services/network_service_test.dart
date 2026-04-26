import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motive_me/Services/network_service.dart';

/// connectivity_plus_platform_interface uses:
///   - MethodChannel: 'dev.fluttercommunity.plus/connectivity'
///   - Method name:   'check'
///   - Return type:   List<String>  e.g. ['wifi'], ['none'], []
const _connectivityChannel =
    MethodChannel('dev.fluttercommunity.plus/connectivity');

void _mockConnectivity(List<String> results) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_connectivityChannel, (call) async {
    if (call.method == 'check') return results;
    return null;
  });
}

void _clearConnectivityMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_connectivityChannel, null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(_clearConnectivityMock);

  group('NetworkService.isConnected()', () {
    test('returns true when wifi is available', () async {
      _mockConnectivity(['wifi']);
      final result = await NetworkService.isConnected();
      expect(result, isTrue);
    });

    test('returns true when mobile is available', () async {
      _mockConnectivity(['mobile']);
      final result = await NetworkService.isConnected();
      expect(result, isTrue);
    });

    test('returns true when ethernet is available', () async {
      _mockConnectivity(['ethernet']);
      final result = await NetworkService.isConnected();
      expect(result, isTrue);
    });

    test('returns false when no connectivity', () async {
      _mockConnectivity(['none']);
      final result = await NetworkService.isConnected();
      expect(result, isFalse);
    });

    test('returns false when list is empty', () async {
      _mockConnectivity([]);
      final result = await NetworkService.isConnected();
      expect(result, isFalse);
    });

    test('returns true when multiple results include wifi', () async {
      _mockConnectivity(['wifi', 'bluetooth']);
      final result = await NetworkService.isConnected();
      expect(result, isTrue);
    });

    test('returns false when multiple results are all none', () async {
      _mockConnectivity(['none', 'none']);
      final result = await NetworkService.isConnected();
      expect(result, isFalse);
    });
  });

  group('NetworkService.checkOrThrow()', () {
    test('completes without throwing when connected', () async {
      _mockConnectivity(['wifi']);
      await expectLater(NetworkService.checkOrThrow(), completes);
    });

    test('throws Exception when not connected', () async {
      _mockConnectivity(['none']);
      await expectLater(
        NetworkService.checkOrThrow(),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('No internet connection'),
        )),
      );
    });

    test('throws Exception when list is empty', () async {
      _mockConnectivity([]);
      await expectLater(
        NetworkService.checkOrThrow(),
        throwsA(isA<Exception>()),
      );
    });
  });
}
