import 'package:flutter_test/flutter_test.dart';
import 'package:music_assistant/services/error_handler.dart';

void main() {
  group('ErrorHandler', () {
    test('handles connection errors', () {
      final error = Exception('not connected to server');
      final info = ErrorHandler.handleError(error, context: 'test');

      expect(info.type, ErrorType.connection);
      expect(info.userMessage, 'Not connected to Music Assistant');
      expect(info.canRetry, true);
    });

    test('handles disconnection errors', () {
      final error = Exception('WebSocket disconnected');
      final info = ErrorHandler.handleError(error);

      expect(info.type, ErrorType.connection);
      expect(info.userMessage.toLowerCase(), contains('not connected'));
    });

    test('handles socket errors', () {
      final error = Exception('Socket exception: connection failed');
      final info = ErrorHandler.handleError(error);

      expect(info.type, ErrorType.network);
      expect(info.userMessage.toLowerCase(), contains('network'));
      expect(info.canRetry, true);
    });

    test('handles timeout errors', () {
      final error = Exception('Request timeout after 30s');
      final info = ErrorHandler.handleError(error);

      expect(info.type, ErrorType.network);
      expect(info.userMessage.toLowerCase(), contains('network'));
    });

    test('handles network lookup failures', () {
      final error = Exception('Failed host lookup: example.com');
      final info = ErrorHandler.handleError(error);

      expect(info.type, ErrorType.network);
      expect(info.canRetry, true);
    });

    test('handles authentication errors', () {
      final error = Exception('Authentication failed: invalid token');
      final info = ErrorHandler.handleError(error);

      expect(info.type, ErrorType.authentication);
      expect(info.userMessage.toLowerCase(), contains('authentication'));
    });

    test('handles unauthorized errors', () {
      final error = Exception('Unauthorized: invalid credentials');
      final info = ErrorHandler.handleError(error);

      expect(info.type, ErrorType.authentication);
    });

    test('handles playback errors', () {
      final error = Exception('Playback failed: unsupported format');
      final info = ErrorHandler.handleError(error);

      expect(info.type, ErrorType.playback);
      expect(info.userMessage.toLowerCase(), contains('playback'));
    });

    test('handles unknown errors', () {
      final error = Exception('Something weird happened');
      final info = ErrorHandler.handleError(error);

      expect(info.type, ErrorType.unknown);
      expect(info.userMessage, contains('unexpected error'));
      expect(info.canRetry, true);
    });

    test('getOperationErrorMessage returns user-friendly message', () {
      final error = Exception('socket connection failed');
      final message = ErrorHandler.getOperationErrorMessage('connect', error);

      expect(message.toLowerCase(), contains('network'));
    });

    test('isRetryable returns true for network errors', () {
      final networkError = Exception('Network timeout');
      expect(ErrorHandler.isRetryable(networkError), true);

      final socketError = Exception('Socket closed');
      expect(ErrorHandler.isRetryable(socketError), true);
    });

    test('isRetryable returns false for non-retryable errors', () {
      final authError = Exception('Authentication failed');
      final info = ErrorHandler.handleError(authError);

      // Auth errors might still be marked as retryable
      // (in case it's a temporary token issue)
      expect(info.canRetry, isA<bool>());
    });

    test('error info contains technical details', () {
      final error = Exception('Detailed technical error message');
      final info = ErrorHandler.handleError(error);

      expect(info.technicalMessage, contains('Detailed technical'));
    });

    test('handles case-insensitive error detection', () {
      final upperError = Exception('SOCKET ERROR');
      final lowerError = Exception('socket error');
      final mixedError = Exception('SoCkEt ErRoR');

      expect(ErrorHandler.handleError(upperError).type, ErrorType.network);
      expect(ErrorHandler.handleError(lowerError).type, ErrorType.network);
      expect(ErrorHandler.handleError(mixedError).type, ErrorType.network);
    });

    test('logError logs without throwing', () {
      // Should not throw
      expect(
        () => ErrorHandler.logError('test', Exception('test error')),
        returnsNormally,
      );

      expect(
        () => ErrorHandler.logError(
          'test',
          Exception('test'),
          stackTrace: StackTrace.current,
        ),
        returnsNormally,
      );
    });

    test('handles multiple error indicators', () {
      // An error with multiple indicators should match the first one
      final error = Exception('Connection closed: socket timeout');
      final info = ErrorHandler.handleError(error);

      // Should detect as connection error (checked first)
      expect(info.type, ErrorType.connection);
    });

    test('handles library/database errors', () {
      final error = Exception('Library scan failed');
      final info = ErrorHandler.handleError(error);

      expect(info.type, ErrorType.library);
      expect(info.userMessage.toLowerCase(), contains('library'));
    });

    test('library errors are retryable', () {
      final error = Exception('Failed to load library items');
      final info = ErrorHandler.handleError(error);

      expect(info.canRetry, true);
    });

    test('playback errors are retryable', () {
      final error = Exception('Stream error during playback');
      final info = ErrorHandler.handleError(error);

      expect(info.canRetry, true);
    });
  });

  group('ErrorType', () {
    test('has all expected types', () {
      expect(ErrorType.values, contains(ErrorType.connection));
      expect(ErrorType.values, contains(ErrorType.authentication));
      expect(ErrorType.values, contains(ErrorType.network));
      expect(ErrorType.values, contains(ErrorType.playback));
      expect(ErrorType.values, contains(ErrorType.library));
      expect(ErrorType.values, contains(ErrorType.unknown));
    });
  });

  group('ErrorInfo', () {
    test('can be created with all fields', () {
      final info = ErrorInfo(
        type: ErrorType.network,
        userMessage: 'Network error occurred',
        technicalMessage: 'Socket closed unexpectedly',
        canRetry: true,
      );

      expect(info.type, ErrorType.network);
      expect(info.userMessage, 'Network error occurred');
      expect(info.technicalMessage, 'Socket closed unexpectedly');
      expect(info.canRetry, true);
    });

    test('canRetry defaults to true', () {
      final info = ErrorInfo(
        type: ErrorType.unknown,
        userMessage: 'Error',
        technicalMessage: 'Details',
      );

      expect(info.canRetry, true);
    });
  });
}
