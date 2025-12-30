/// WebSocket Bridge Transport
///
/// A thin adapter that wraps an underlying transport (WebRTC DataChannel)
/// and bridges it to look like a WebSocket for the MA API.
/// This allows the existing MusicAssistantAPI to work transparently over WebRTC.
///
/// Adapted from: music-assistant/desktop-companion/src/plugins/remote/websocket-transport.ts
/// Original Copyright 2024 Music Assistant (Apache License 2.0)
/// Adapted for Flutter/Dart by Ensemble contributors (MIT License)

import 'dart:async';
import 'transport.dart';
import '../debug_logger.dart';

/// Bridge transport that makes a raw transport (like WebRTC) look like a WebSocket
/// This is used to transparently route MA WebSocket API calls over a WebRTC data channel
class WebSocketBridgeTransport extends BaseTransport {
  final ITransport underlying;
  final _logger = DebugLogger();
  
  StreamSubscription? _stateSubscription;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _errorSubscription;

  WebSocketBridgeTransport(this.underlying) : super() {
    _setupBridge();
  }

  void _setupBridge() {
    // Forward state changes from underlying transport
    _stateSubscription = underlying.stateStream.listen((state) {
      setState(state);
    });

    // Forward messages from underlying transport
    _messageSubscription = underlying.messageStream.listen((message) {
      emitMessage(message);
    });

    // Forward errors from underlying transport
    _errorSubscription = underlying.errorStream.listen((error) {
      emitError(error);
    });

    // Initialize state to match underlying transport
    setState(underlying.state);
  }

  @override
  Future<void> connect() async {
    _logger.log('[Bridge] Connecting underlying transport');
    await underlying.connect();
  }

  @override
  void disconnect() {
    _logger.log('[Bridge] Disconnecting underlying transport');
    underlying.disconnect();
  }

  @override
  void send(String data) {
    underlying.send(data);
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _messageSubscription?.cancel();
    _errorSubscription?.cancel();
    underlying.dispose();
    super.dispose();
  }
}
