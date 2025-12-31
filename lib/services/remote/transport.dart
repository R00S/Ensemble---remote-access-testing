/// Transport Interface
///
/// Defines the common interface for both WebSocket and WebRTC transports.
/// This allows the MA API client to work with either transport transparently.

import 'dart:async';

enum TransportState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}

/// Base transport interface that all transports must implement
abstract class ITransport {
  /// Current connection state
  TransportState get state;

  /// Stream of transport state changes
  Stream<TransportState> get stateStream;

  /// Stream of incoming messages (JSON strings)
  Stream<String> get messageStream;

  /// Stream of errors
  Stream<Exception> get errorStream;

  /// Connect to the server
  Future<void> connect();

  /// Disconnect from the server
  void disconnect();

  /// Send a message (JSON string)
  void send(String data);

  /// Dispose resources
  void dispose();
}

/// Base transport implementation with common functionality
abstract class BaseTransport implements ITransport {
  TransportState _state = TransportState.disconnected;
  
  final _stateController = StreamController<TransportState>.broadcast();
  final _messageController = StreamController<String>.broadcast();
  final _errorController = StreamController<Exception>.broadcast();

  @override
  TransportState get state => _state;

  @override
  Stream<TransportState> get stateStream => _stateController.stream;

  @override
  Stream<String> get messageStream => _messageController.stream;

  @override
  Stream<Exception> get errorStream => _errorController.stream;

  void setState(TransportState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  void emitMessage(String message) {
    _messageController.add(message);
  }

  void emitError(Exception error) {
    _errorController.add(error);
  }

  @override
  void dispose() {
    _stateController.close();
    _messageController.close();
    _errorController.close();
  }
}
