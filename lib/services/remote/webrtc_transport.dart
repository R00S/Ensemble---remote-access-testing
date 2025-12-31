/// WebRTC Transport
///
/// Implements the transport interface using WebRTC DataChannel.
/// Used for remote connections to Music Assistant instances via NAT traversal.
/// 
/// Adapted from: music-assistant/desktop-companion/src/plugins/remote/webrtc-transport.ts
/// Original Copyright 2024 Music Assistant (Apache License 2.0)
/// Adapted for Flutter/Dart by Ensemble contributors (MIT License)

import 'dart:async';
import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'transport.dart';
import 'signaling.dart';
import '../debug_logger.dart';

class WebRTCTransportOptions {
  final String signalingServerUrl;
  final String remoteId;
  final String dataChannelLabel;
  final bool reconnect;
  final int reconnectDelay;
  final int maxReconnectDelay;
  final double reconnectDelayGrowth;
  final int maxReconnectAttempts;

  WebRTCTransportOptions({
    required this.signalingServerUrl,
    required this.remoteId,
    this.dataChannelLabel = 'ma-api',
    this.reconnect = true,
    this.reconnectDelay = 1000,
    this.maxReconnectDelay = 30000,
    this.reconnectDelayGrowth = 1.5,
    this.maxReconnectAttempts = 999999,
  });
}

/// Fallback ICE servers (only public STUN servers - no TURN)
/// These will only be used if the server doesn't provide ICE servers
const _fallbackIceServers = [
  {'urls': 'stun:stun.l.google.com:19302'},
  {'urls': 'stun:stun.cloudflare.com:3478'},
];

class WebRTCTransport extends BaseTransport {
  final WebRTCTransportOptions options;
  final _logger = DebugLogger();

  SignalingClient? _signaling;
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  
  final List<RTCIceCandidate> _iceCandidateBuffer = [];
  bool _remoteDescriptionSet = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  bool _intentionalClose = false;
  List<Map<String, dynamic>> _iceServers = [];
  
  // Keep-alive mechanism
  Timer? _keepAliveTimer;
  DateTime? _lastMessageReceived;
  DateTime? _lastMessageSent;
  static const _keepAliveInterval = Duration(seconds: 30);
  static const _keepAliveTimeout = Duration(seconds: 60);

  WebRTCTransport(this.options) : super();

  @override
  Future<void> connect() async {
    _intentionalClose = false;
    setState(TransportState.connecting);
    _logger.log('[WebRTC] Connecting to Remote ID: ${options.remoteId}');

    try {
      // Create and connect signaling client
      _signaling = SignalingClient(SignalingConfig(
        serverUrl: options.signalingServerUrl,
        reconnect: false, // We handle reconnection at transport level
      ));

      _setupSignalingHandlers();
      await _signaling!.connect();

      // Request connection - receives ICE servers from MA server
      _logger.log('[WebRTC] Requesting connection to Remote ID');
      final connectedEvent = await _signaling!.requestConnection(options.remoteId);
      
      // Convert IceServerConfig to Map format for flutter_webrtc
      if (connectedEvent.iceServers != null && connectedEvent.iceServers!.isNotEmpty) {
        _iceServers = connectedEvent.iceServers!
            .map((config) => config.toJson())
            .toList();
        _logger.log('[WebRTC] Received ${_iceServers.length} ICE servers from MA server');
      } else {
        _iceServers = List<Map<String, dynamic>>.from(_fallbackIceServers);
        _logger.log('[WebRTC] Using fallback ICE servers');
      }

      // Create peer connection
      await _createPeerConnection();

      // Create data channel (we're the initiator)
      await _createDataChannel();

      // Create and send offer
      _logger.log('[WebRTC] Creating offer');
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      
      // Send offer via signaling
      _signaling!.sendOffer({
        'type': offer.type,
        'sdp': offer.sdp,
      });

      // Wait for connection to be established
      await _waitForConnection();

      // Reset reconnect attempts on successful connection
      _reconnectAttempts = 0;
      setState(TransportState.connected);
      _logger.log('[WebRTC] Connection established successfully');
      
      // Start keep-alive mechanism
      _startKeepAlive();
    } catch (e) {
      _logger.log('[WebRTC] Connection failed: $e');
      _cleanup();

      if (_reconnectAttempts == 0) {
        setState(TransportState.failed);
      } else if (_reconnectAttempts >= options.maxReconnectAttempts) {
        setState(TransportState.failed);
      }

      rethrow;
    }
  }

  @override
  void disconnect() {
    _intentionalClose = true;
    _stopKeepAlive();
    _clearReconnectTimer();
    _cleanup();
    setState(TransportState.disconnected);
    _logger.log('[WebRTC] Disconnected');
  }

  @override
  void send(String data) {
    if (_dataChannel == null || _dataChannel!.state != RTCDataChannelState.RTCDataChannelOpen) {
      throw Exception('DataChannel is not open');
    }
    _dataChannel!.send(RTCDataChannelMessage(data));
    _lastMessageSent = DateTime.now();
  }

  void _setupSignalingHandlers() {
    // Handle answer from remote peer
    _signaling!.answerStream.listen((answer) {
      _handleAnswer(answer);
    });

    // Handle ICE candidates from remote peer
    _signaling!.iceCandidateStream.listen((candidate) {
      _handleIceCandidate(candidate);
    });

    // Handle peer disconnection
    _signaling!.peerDisconnectedStream.listen((_) {
      _handlePeerDisconnected();
    });

    // Handle signaling errors
    _signaling!.errorStream.listen((error) {
      _logger.log('[WebRTC] Signaling error: $error');
      emitError(Exception(error));
    });
  }

  Future<void> _createPeerConnection() async {
    final configuration = {
      'iceServers': _iceServers,
      'sdpSemantics': 'unified-plan',
    };

    _logger.log('[WebRTC] Creating peer connection with ${_iceServers.length} ICE servers');
    _peerConnection = await createPeerConnection(configuration);

    // Handle ICE candidates
    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        _logger.log('[WebRTC] Local ICE candidate generated');
        _signaling!.sendIceCandidate({
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      }
    };

    // Handle ICE connection state changes
    _peerConnection!.onIceConnectionState = (state) {
      _logger.log('[WebRTC] ICE connection state: $state');
      
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
          state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
        if (!_intentionalClose && options.reconnect) {
          _scheduleReconnect();
        }
      }
    };

    // Handle connection state changes
    _peerConnection!.onConnectionState = (state) {
      _logger.log('[WebRTC] Peer connection state: $state');
    };
  }

  Future<void> _createDataChannel() async {
    final dataChannelConfig = RTCDataChannelInit()
      ..ordered = true
      ..maxRetransmits = -1; // Reliable channel

    _dataChannel = await _peerConnection!.createDataChannel(
      options.dataChannelLabel,
      dataChannelConfig,
    );

    _dataChannel!.onDataChannelState = (state) {
      _logger.log('[WebRTC] Data channel state: $state');
      
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        _logger.log('[WebRTC] Data channel opened');
      } else if (state == RTCDataChannelState.RTCDataChannelClosed) {
        _logger.log('[WebRTC] Data channel closed');
        if (!_intentionalClose && options.reconnect) {
          _scheduleReconnect();
        }
      }
    };

    _dataChannel!.onMessage = (message) {
      if (message.text != null) {
        _lastMessageReceived = DateTime.now();
        emitMessage(message.text);
      }
    };
  }

  Future<void> _handleAnswer(Map<String, dynamic> answer) async {
    _logger.log('[WebRTC] Received answer from remote peer');
    
    try {
      final description = RTCSessionDescription(
        answer['sdp'] as String,
        answer['type'] as String,
      );
      
      await _peerConnection!.setRemoteDescription(description);
      _remoteDescriptionSet = true;

      // Add buffered ICE candidates
      if (_iceCandidateBuffer.isNotEmpty) {
        _logger.log('[WebRTC] Adding ${_iceCandidateBuffer.length} buffered ICE candidates');
        for (final candidate in _iceCandidateBuffer) {
          await _peerConnection!.addCandidate(candidate);
        }
        _iceCandidateBuffer.clear();
      }
    } catch (e) {
      _logger.log('[WebRTC] Error handling answer: $e');
      emitError(Exception('Failed to set remote description: $e'));
    }
  }

  Future<void> _handleIceCandidate(Map<String, dynamic> candidateData) async {
    _logger.log('[WebRTC] Received ICE candidate from remote peer');

    try {
      final candidate = RTCIceCandidate(
        candidateData['candidate'] as String?,
        candidateData['sdpMid'] as String?,
        candidateData['sdpMLineIndex'] as int?,
      );

      if (_remoteDescriptionSet) {
        await _peerConnection!.addCandidate(candidate);
      } else {
        // Buffer candidates until remote description is set
        _iceCandidateBuffer.add(candidate);
      }
    } catch (e) {
      _logger.log('[WebRTC] Error handling ICE candidate: $e');
    }
  }

  void _handlePeerDisconnected() {
    _logger.log('[WebRTC] Remote peer disconnected');
    
    if (!_intentionalClose && options.reconnect) {
      _scheduleReconnect();
    }
  }

  Future<void> _waitForConnection() async {
    final completer = Completer<void>();
    final timeout = Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        completer.completeError(Exception('Connection timeout'));
      }
    });

    // Wait for data channel to open
    StreamSubscription? subscription;
    subscription = _dataChannel!.stateChangeStream?.listen((state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        timeout.cancel();
        subscription?.cancel();
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });

    return completer.future;
  }

  void _scheduleReconnect() {
    if (_intentionalClose || state == TransportState.reconnecting) {
      return;
    }

    _clearReconnectTimer();
    setState(TransportState.reconnecting);

    _reconnectAttempts++;
    final delay = (options.reconnectDelay * 
        (options.reconnectDelayGrowth * _reconnectAttempts))
        .clamp(options.reconnectDelay, options.maxReconnectDelay)
        .toInt();

    _logger.log('[WebRTC] Scheduling reconnect attempt $_reconnectAttempts in ${delay}ms');

    _reconnectTimer = Timer(Duration(milliseconds: delay), () {
      if (!_intentionalClose) {
        _logger.log('[WebRTC] Attempting reconnect...');
        connect().catchError((e) {
          _logger.log('[WebRTC] Reconnect failed: $e');
        });
      }
    });
  }

  void _clearReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }
  
  /// Start keep-alive mechanism to detect stale connections
  void _startKeepAlive() {
    _stopKeepAlive();
    _lastMessageReceived = DateTime.now();
    _lastMessageSent = DateTime.now();
    
    _keepAliveTimer = Timer.periodic(_keepAliveInterval, (_) {
      _checkKeepAlive();
    });
    _logger.log('[WebRTC] Keep-alive started (interval: ${_keepAliveInterval.inSeconds}s)');
  }
  
  /// Stop keep-alive timer
  void _stopKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }
  
  /// Check connection health and send keep-alive if needed
  void _checkKeepAlive() {
    final now = DateTime.now();
    
    // Check if we've received any messages recently
    if (_lastMessageReceived != null) {
      final timeSinceLastMessage = now.difference(_lastMessageReceived!);
      
      if (timeSinceLastMessage > _keepAliveTimeout) {
        _logger.log('[WebRTC] Keep-alive timeout - no messages for ${timeSinceLastMessage.inSeconds}s');
        if (!_intentionalClose && options.reconnect) {
          _scheduleReconnect();
        }
        return;
      }
    }
    
    // Send keep-alive ping if we haven't sent anything recently
    if (_lastMessageSent != null) {
      final timeSinceLastSent = now.difference(_lastMessageSent!);
      
      if (timeSinceLastSent > _keepAliveInterval) {
        try {
          // Send a minimal ping message
          send('{"type":"ping"}');
          _logger.log('[WebRTC] Keep-alive ping sent');
        } catch (e) {
          _logger.log('[WebRTC] Keep-alive ping failed: $e');
          if (!_intentionalClose && options.reconnect) {
            _scheduleReconnect();
          }
        }
      }
    }
  }

  void _cleanup() {
    _dataChannel?.close();
    _dataChannel = null;
    
    _peerConnection?.close();
    _peerConnection = null;

    _signaling?.disconnect();
    _signaling?.dispose();
    _signaling = null;

    _iceCandidateBuffer.clear();
    _remoteDescriptionSet = false;
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
