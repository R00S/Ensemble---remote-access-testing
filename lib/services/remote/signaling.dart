/// Signaling Client
///
/// Handles WebRTC signaling for establishing peer connections.
/// Connects to the Music Assistant signaling server to exchange SDP offers/answers and ICE candidates.
/// 
/// Adapted from: music-assistant/desktop-companion/src/plugins/remote/signaling.ts

import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../debug_logger.dart';

enum SignalingState {
  disconnected,
  connecting,
  connected,
  error,
}

class IceServerConfig {
  final dynamic urls; // String or List<String>
  final String? username;
  final String? credential;

  IceServerConfig({
    required this.urls,
    this.username,
    this.credential,
  });

  factory IceServerConfig.fromJson(Map<String, dynamic> json) {
    return IceServerConfig(
      urls: json['urls'],
      username: json['username'] as String?,
      credential: json['credential'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'urls': urls,
      if (username != null) 'username': username,
      if (credential != null) 'credential': credential,
    };
  }
}

class SignalingMessage {
  final String type; // "offer", "answer", "ice-candidate", "error", "connected", "peer-disconnected", "connect-request"
  final String? remoteId;
  final String? sessionId;
  final Map<String, dynamic>? data; // SDP or ICE candidate data
  final String? error;
  final List<IceServerConfig>? iceServers;

  SignalingMessage({
    required this.type,
    this.remoteId,
    this.sessionId,
    this.data,
    this.error,
    this.iceServers,
  });

  factory SignalingMessage.fromJson(Map<String, dynamic> json) {
    return SignalingMessage(
      type: json['type'] as String,
      remoteId: json['remoteId'] as String?,
      sessionId: json['sessionId'] as String?,
      data: json['data'] as Map<String, dynamic>?,
      error: json['error'] as String?,
      iceServers: (json['iceServers'] as List<dynamic>?)
          ?.map((e) => IceServerConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      if (remoteId != null) 'remoteId': remoteId,
      if (sessionId != null) 'sessionId': sessionId,
      if (data != null) 'data': data,
      if (error != null) 'error': error,
      if (iceServers != null)
        'iceServers': iceServers!.map((e) => e.toJson()).toList(),
    };
  }
}

class SignalingConfig {
  final String serverUrl;
  final bool reconnect;
  final int reconnectDelay;

  SignalingConfig({
    required this.serverUrl,
    this.reconnect = true,
    this.reconnectDelay = 3000,
  });
}

/// Signaling client for WebRTC connection establishment
class SignalingClient {
  final SignalingConfig config;
  final _logger = DebugLogger();
  
  WebSocketChannel? _channel;
  SignalingState _state = SignalingState.disconnected;
  Timer? _reconnectTimer;
  bool _intentionalClose = false;
  String? _currentRemoteId;
  String? _currentSessionId;

  // Event streams
  final _stateController = StreamController<SignalingState>.broadcast();
  final _offerController = StreamController<_OfferEvent>.broadcast();
  final _answerController = StreamController<Map<String, dynamic>>.broadcast();
  final _iceCandidateController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectedController = StreamController<_ConnectedEvent>.broadcast();
  final _peerDisconnectedController = StreamController<void>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  SignalingClient(this.config);

  SignalingState get state => _state;
  String? get sessionId => _currentSessionId;

  // Event streams
  Stream<SignalingState> get stateStream => _stateController.stream;
  Stream<_OfferEvent> get offerStream => _offerController.stream;
  Stream<Map<String, dynamic>> get answerStream => _answerController.stream;
  Stream<Map<String, dynamic>> get iceCandidateStream => _iceCandidateController.stream;
  Stream<_ConnectedEvent> get connectedStream => _connectedController.stream;
  Stream<void> get peerDisconnectedStream => _peerDisconnectedController.stream;
  Stream<String> get errorStream => _errorController.stream;

  /// Connect to the signaling server
  Future<void> connect() async {
    if (_channel != null) {
      return; // Already connected
    }

    _intentionalClose = false;
    _setState(SignalingState.connecting);
    _logger.log('[Signaling] Connecting to ${config.serverUrl}');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(config.serverUrl));

      // Listen to messages
      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message as String) as Map<String, dynamic>;
            _handleMessage(SignalingMessage.fromJson(data));
          } catch (e) {
            _logger.log('[Signaling] Failed to parse message: $e');
          }
        },
        onError: (error) {
          _logger.log('[Signaling] WebSocket error: $error');
          _setState(SignalingState.error);
        },
        onDone: () {
          _logger.log('[Signaling] Connection closed');
          _setState(SignalingState.disconnected);
          _channel = null;

          if (!_intentionalClose && config.reconnect) {
            _scheduleReconnect();
          }
        },
      );

      _setState(SignalingState.connected);
      _logger.log('[Signaling] Connected successfully');
    } catch (e) {
      _logger.log('[Signaling] Connection failed: $e');
      _setState(SignalingState.error);
      rethrow;
    }
  }

  /// Disconnect from the signaling server
  void disconnect() {
    _intentionalClose = true;
    _clearReconnectTimer();

    _channel?.sink.close();
    _channel = null;
    _currentRemoteId = null;
    _currentSessionId = null;
    _setState(SignalingState.disconnected);
  }

  /// Request connection to a remote Music Assistant instance
  /// Returns when connected with remote ID and ICE servers
  Future<_ConnectedEvent> requestConnection(String remoteId) async {
    if (_state != SignalingState.connected) {
      await connect();
    }

    _currentRemoteId = remoteId;
    _logger.log('[Signaling] Requesting connection to Remote ID: $remoteId');

    final completer = Completer<_ConnectedEvent>();
    final timeout = Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        completer.completeError(Exception('Connection request timeout'));
      }
    });

    // Listen for connected event
    final subscription = _connectedController.stream.listen((event) {
      if (!completer.isCompleted) {
        timeout.cancel();
        completer.complete(event);
      }
    });

    // Listen for error event
    final errorSubscription = _errorController.stream.listen((error) {
      if (!completer.isCompleted) {
        timeout.cancel();
        completer.completeError(Exception(error));
      }
    });

    // Send connect request
    _send({
      'type': 'connect-request',
      'remoteId': remoteId,
    });

    try {
      final result = await completer.future;
      subscription.cancel();
      errorSubscription.cancel();
      return result;
    } catch (e) {
      subscription.cancel();
      errorSubscription.cancel();
      rethrow;
    }
  }

  /// Send an SDP offer to the remote peer
  void sendOffer(Map<String, dynamic> offer) {
    _logger.log('[Signaling] Sending offer');
    _send({
      'type': 'offer',
      'remoteId': _currentRemoteId,
      'sessionId': _currentSessionId,
      'data': offer,
    });
  }

  /// Send an SDP answer to the remote peer
  void sendAnswer(Map<String, dynamic> answer) {
    _logger.log('[Signaling] Sending answer');
    _send({
      'type': 'answer',
      'remoteId': _currentRemoteId,
      'sessionId': _currentSessionId,
      'data': answer,
    });
  }

  /// Send an ICE candidate to the remote peer
  void sendIceCandidate(Map<String, dynamic> candidate) {
    _logger.log('[Signaling] Sending ICE candidate');
    _send({
      'type': 'ice-candidate',
      'remoteId': _currentRemoteId,
      'sessionId': _currentSessionId,
      'data': candidate,
    });
  }

  void _send(Map<String, dynamic> message) {
    if (_channel == null) {
      throw Exception('Not connected to signaling server');
    }
    _channel!.sink.add(jsonEncode(message));
  }

  void _handleMessage(SignalingMessage message) {
    _logger.log('[Signaling] Received message: ${message.type}');

    switch (message.type) {
      case 'connected':
        _currentSessionId = message.sessionId;
        _connectedController.add(_ConnectedEvent(
          remoteId: message.remoteId!,
          iceServers: message.iceServers,
        ));
        break;

      case 'offer':
        _offerController.add(_OfferEvent(
          offer: message.data!,
          sessionId: message.sessionId!,
        ));
        break;

      case 'answer':
        _answerController.add(message.data!);
        break;

      case 'ice-candidate':
        _iceCandidateController.add(message.data!);
        break;

      case 'peer-disconnected':
        _logger.log('[Signaling] Peer disconnected');
        _peerDisconnectedController.add(null);
        break;

      case 'error':
        _logger.log('[Signaling] Error: ${message.error}');
        _errorController.add(message.error ?? 'Unknown error');
        break;

      default:
        _logger.log('[Signaling] Unknown message type: ${message.type}');
    }
  }

  void _setState(SignalingState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  void _scheduleReconnect() {
    _clearReconnectTimer();
    _logger.log('[Signaling] Scheduling reconnect in ${config.reconnectDelay}ms');
    
    _reconnectTimer = Timer(Duration(milliseconds: config.reconnectDelay), () {
      if (_state == SignalingState.disconnected) {
        _logger.log('[Signaling] Attempting reconnect...');
        connect().catchError((e) {
          _logger.log('[Signaling] Reconnect failed: $e');
        });
      }
    });
  }

  void _clearReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void dispose() {
    disconnect();
    _stateController.close();
    _offerController.close();
    _answerController.close();
    _iceCandidateController.close();
    _connectedController.close();
    _peerDisconnectedController.close();
    _errorController.close();
  }
}

// Helper classes for event data
class _OfferEvent {
  final Map<String, dynamic> offer;
  final String sessionId;

  _OfferEvent({required this.offer, required this.sessionId});
}

class _ConnectedEvent {
  final String remoteId;
  final List<IceServerConfig>? iceServers;

  _ConnectedEvent({required this.remoteId, this.iceServers});
}
