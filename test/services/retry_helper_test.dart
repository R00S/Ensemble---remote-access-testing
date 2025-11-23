import 'package:flutter_test/flutter_test.dart';
import 'package:music_assistant/services/retry_helper.dart';

void main() {
  group('RetryHelper', () {
    test('retry succeeds on first attempt', () async {
      int attempts = 0;

      final result = await RetryHelper.retry(
        operation: () async {
          attempts++;
          return 'success';
        },
      );

      expect(result, 'success');
      expect(attempts, 1);
    });

    test('retry succeeds after failures', () async {
      int attempts = 0;

      final result = await RetryHelper.retry(
        operation: () async {
          attempts++;
          if (attempts < 3) {
            throw Exception('Network error');
          }
          return 'success';
        },
        maxAttempts: 5,
      );

      expect(result, 'success');
      expect(attempts, 3);
    });

    test('retry fails after max attempts', () async {
      int attempts = 0;

      expect(
        () async => await RetryHelper.retry(
          operation: () async {
            attempts++;
            throw Exception('Persistent error');
          },
          maxAttempts: 3,
          initialDelaySeconds: 0, // no delay for test speed
        ),
        throwsException,
      );

      expect(attempts, 3);
    });

    test('retry respects shouldRetry callback', () async {
      int attempts = 0;

      // Should not retry on specific error
      expect(
        () async => await RetryHelper.retry(
          operation: () async {
            attempts++;
            throw Exception('Fatal error');
          },
          shouldRetry: (error) {
            return !error.toString().contains('Fatal');
          },
          initialDelaySeconds: 0,
        ),
        throwsException,
      );

      expect(attempts, 1); // Only tried once, didn't retry
    });

    test('retry continues on retryable errors', () async {
      int attempts = 0;

      final result = await RetryHelper.retry(
        operation: () async {
          attempts++;
          if (attempts < 2) {
            throw Exception('Network timeout');
          }
          return 'recovered';
        },
        shouldRetry: (error) {
          return error.toString().contains('Network');
        },
        initialDelaySeconds: 0,
      );

      expect(result, 'recovered');
      expect(attempts, 2);
    });

    test('retryNetwork uses correct settings', () async {
      int attempts = 0;

      final result = await RetryHelper.retryNetwork(
        operation: () async {
          attempts++;
          if (attempts < 3) {
            throw Exception('Socket error');
          }
          return 'connected';
        },
      );

      expect(result, 'connected');
      expect(attempts, 3);
    });

    test('retryNetwork only retries on network errors', () async {
      int attempts = 0;

      // Non-network error should not retry
      expect(
        () async => await RetryHelper.retryNetwork(
          operation: () async {
            attempts++;
            throw Exception('Database error');
          },
        ),
        throwsException,
      );

      expect(attempts, 1); // Didn't retry
    });

    test('retryNetwork retries on socket errors', () async {
      int attempts = 0;

      final result = await RetryHelper.retryNetwork(
        operation: () async {
          attempts++;
          if (attempts < 2) {
            throw Exception('Socket connection failed');
          }
          return 'ok';
        },
      );

      expect(result, 'ok');
      expect(attempts, 2);
    });

    test('retryNetwork retries on timeout errors', () async {
      int attempts = 0;

      final result = await RetryHelper.retryNetwork(
        operation: () async {
          attempts++;
          if (attempts < 2) {
            throw Exception('Connection timeout');
          }
          return 'ok';
        },
      );

      expect(result, 'ok');
      expect(attempts, 2);
    });

    test('retryCritical uses more aggressive retry', () async {
      int attempts = 0;

      final result = await RetryHelper.retryCritical(
        operation: () async {
          attempts++;
          if (attempts < 4) {
            throw Exception('Temporary failure');
          }
          return 'critical_success';
        },
      );

      expect(result, 'critical_success');
      expect(attempts, 4);
    });

    test('retryCritical fails after 5 attempts', () async {
      int attempts = 0;

      expect(
        () async => await RetryHelper.retryCritical(
          operation: () async {
            attempts++;
            throw Exception('Cannot recover');
          },
        ),
        throwsException,
      );

      expect(attempts, 5); // Max attempts for critical
    });

    test('retry returns correct type', () async {
      final stringResult = await RetryHelper.retry<String>(
        operation: () async => 'text',
      );
      expect(stringResult, isA<String>());

      final intResult = await RetryHelper.retry<int>(
        operation: () async => 42,
      );
      expect(intResult, isA<int>());

      final boolResult = await RetryHelper.retry<bool>(
        operation: () async => true,
      );
      expect(boolResult, isA<bool>());
    });

    test('retry handles async operations correctly', () async {
      final result = await RetryHelper.retry(
        operation: () async {
          await Future.delayed(Duration(milliseconds: 10));
          return 'async_result';
        },
      );

      expect(result, 'async_result');
    });
  });
}
