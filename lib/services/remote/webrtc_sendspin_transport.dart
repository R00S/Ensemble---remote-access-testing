/// WebRTC Sendspin Transport
///
/// Manages the second peer connection specifically for Sendspin audio streaming.
/// This is separate from the MA API connection and is signaled through the API
/// data channel using sendspin/ice_servers and sendspin/connect endpoints.
///
/// Architecture:
/// - Connection 1 (MA API): Already established via WebRTCTransport
/// - Connection 2 (Sendspin): This transport, signaled through Connection 1
///
/// The signaling happens via the MA API connection, not the signaling server.

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../debug_logger.dart';
import '../music_assistant_api.dart';

/// State of the Sendspin WebRTC connection
enum SendspinWebRTCState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}

/// Configuration for WebRTC Sendspin transport
class WebRTCSendspinConfig {
  final List<Map<String, dynamic>> iceServers;
  final bool reconnect;
  final int reconnectDelay;
  final int maxReconnectDelay;

  WebRTCSendspinConfig({
    required this.iceServers,
    this.reconnect = true,
    this.reconnectDelay = 1000,
    this.maxReconnectDelay = 30000,
  });
}

/// WebRTC transport for Sendspin audio streaming
/// This handles the second peer connection for audio data
class WebRTCSendspinTransport {
  final MusicAssistantAPI api;
  final _logger = DebugLogger();

  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;

  SendspinWebRTCState _state = SendspinWebRTCState.disconnected;
  SendspinWebRTCState get state => _state;

  final _stateController = StreamController<SendspinWebRTCState>.broadcast();
  Stream<SendspinWebRTCState> get stateStream => _stateController.stream;

  // Message streams
  final _textMessageController = StreamController<String>.broadcast();
  Stream<String> get textMessageStream => _textMessageController.stream;

  final _binaryMessageController = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get binaryMessageStream => _binaryMessageController.stream;

  final _errorController = StreamController<Exception>.broadcast();
  Stream<Exception> get errorStream => _errorController.stream;

  final List<RTCIceCandidate> _iceCandidateBuffer = [];
  bool _remoteDescriptionSet = false;
  bool _intentionalClose = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  List<Map<String, dynamic>> _iceServers = [];

  WebRTCSendspinTransport(this.api);

  /// Connect and establish the Sendspin audio peer connection
  Future<void> connect() async {
    _intentionalClose = false;
    _setState(SendspinWebRTCState.connecting);
    _logger.log('[SendspinWebRTC] Starting connection for audio streaming');

    try {
      // Step 1: Get ICE servers from MA API
      _logger.log('[SendspinWebRTC] Requesting ICE servers from MA API');
      _iceServers = await api.getSendspinIceServers();
      _logger.log('[SendspinWebRTC] Received ${_iceServers.length} ICE servers');

      // Step 2: Create peer connection
      await _createPeerConnection();

      // Step 3: Create data channel for audio
      await _createDataChannel();

      // Step 4: Create and send SDP offer
      _logger.log('[SendspinWebRTC] Creating SDP offer');
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      // Step 5: Send offer to MA server via API and get answer
      _logger.log('[SendspinWebRTC] Sending SDP offer to MA API');
      final answer = await api.sendspinConnect({
        'type': offer.type,
        'sdp': offer.sdp,
      });

      // Step 6: Set remote description (answer from server)
      _logger.log('[SendspinWebRTC] Setting remote description from answer');
      final remoteDesc = RTCSessionDescription(
        answer['sdp'] as String,
        answer['type'] as String,
      );
      await _peerConnection!.setRemoteDescription(remoteDesc);
      _remoteDescriptionSet = true;

      // Step 7: Add any buffered ICE candidates
      if (_iceCandidateBuffer.isNotEmpty) {
        _logger.log('[SendspinWebRTC] Adding ${_iceCandidateBuffer.length} buffered ICE candidates');
        for (final candidate in _iceCandidateBuffer) {
          await _peerConnection!.addCandidate(candidate);
        }
        _iceCandidateBuffer.clear();
      }

      // Wait for connection to be established
      await _waitForConnection();

      _reconnectAttempts = 0;
      _setState(SendspinWebRTCState.connected);
      _logger.log('[SendspinWebRTC] Audio connection established successfully');
    } catch (e) {
      _logger.log('[SendspinWebRTC] Connection failed: $e');
      _cleanup();
      _setState(SendspinWebRTCState.failed);
      rethrow;
    }
  }

  /// Create the WebRTC peer connection
  Future<void> _createPeerConnection() async {
    final configuration = {
      'iceServers': _iceServers,
      'sdpSemantics': 'unified-plan',
    };

    _logger.log('[SendspinWebRTC] Creating peer connection');
    _peerConnection = await createPeerConnection(configuration);

    // Handle ICE candidates - send them to MA server via API
    _peerConnection!.onIceCandidate = (candidate) {
      if (candidate.candidate != null) {
        _logger.log('[SendspinWebRTC] Local ICE candidate generated');
        // Send to MA server via API
        api.sendspinIceCandidate({
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        }).catchError((e) {
          _logger.log('[SendspinWebRTC] Error sending ICE candidate: $e');
        });
      }
    };

    // Handle ICE connection state changes
    _peerConnection!.onIceConnectionState = (state) {
      _logger.log('[SendspinWebRTC] ICE connection state: $state');

      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
          state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
        if (!_intentionalClose) {
          _scheduleReconnect();
        }
      }
    };

    // Handle connection state changes
    _peerConnection!.onConnectionState = (state) {
      _logger.log('[SendspinWebRTC] Peer connection state: $state');

      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _logger.log('[SendspinWebRTC] Connection failed, scheduling reconnect');
        if (!_intentionalClose) {
          _scheduleReconnect();
        }
      }
    };
  }

  /// Create data channel for Sendspin protocol
  Future<void> _createDataChannel() async {
    final dataChannelConfig = RTCDataChannelInit()
      ..ordered = true
      ..maxRetransmits = -1; // Reliable channel

    _dataChannel = await _peerConnection!.createDataChannel(
      'sendspin',
      dataChannelConfig,
    );

    _dataChannel!.onDataChannelState = (state) {
      _logger.log('[SendspinWebRTC] Data channel state: $state');

      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        _logger.log('[SendspinWebRTC] Data channel opened for audio');
      } else if (state == RTCDataChannelState.RTCDataChannelClosed) {
        _logger.log('[SendspinWebRTC] Data channel closed');
        if (!_intentionalClose) {
          _scheduleReconnect();
        }
      }
    };

    // Handle incoming messages
    _dataChannel!.onMessage = (message) {
      if (message.isBinary) {
        // Binary audio data
        final data = message.binary;
        if (!_binaryMessageController.isClosed) {
          _binaryMessageController.add(data);
        }
      } else if (message.text != null) {
        // JSON control messages
        if (!_textMessageController.isClosed) {
          _textMessageController.add(message.text);
        }
      }
    };
  }

  /// Wait for data channel to open
  Future<void> _waitForConnection() async {
    final completer = Completer<void>();
    final timeout = Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        completer.completeError(Exception('Connection timeout'));
      }
    });

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

  /// Handle incoming ICE candidate from server (via API event)
  Future<void> handleRemoteIceCandidate(Map<String, dynamic> candidateData) async {
    _logger.log('[SendspinWebRTC] Received remote ICE candidate');

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
      _logger.log('[SendspinWebRTC] Error handling ICE candidate: $e');
    }
  }

  /// Send a text message (JSON) through the data channel
  void sendText(String message) {
    if (_dataChannel == null || _dataChannel!.state != RTCDataChannelState.RTCDataChannelOpen) {
      throw Exception('Data channel is not open');
    }
    _dataChannel!.send(RTCDataChannelMessage(message));
  }

  /// Send binary data through the data channel
  void sendBinary(Uint8List data) {
    if (_dataChannel == null || _dataChannel!.state != RTCDataChannelState.RTCDataChannelOpen) {
      throw Exception('Data channel is not open');
    }
    _dataChannel!.send(RTCDataChannelMessage.fromBinary(data));
  }

  /// Disconnect the audio connection
  void disconnect() {
    _intentionalClose = true;
    _clearReconnectTimer();
    _cleanup();
    _setState(SendspinWebRTCState.disconnected);
    _logger.log('[SendspinWebRTC] Disconnected');
  }

  /// Schedule reconnection attempt
  void _scheduleReconnect() {
    if (_intentionalClose || _state == SendspinWebRTCState.reconnecting) {
      return;
    }

    _clearReconnectTimer();
    _setState(SendspinWebRTCState.reconnecting);

    _reconnectAttempts++;
    final delay = 1000 * _reconnectAttempts;
    final clampedDelay = delay.clamp(1000, 30000);

    _logger.log('[SendspinWebRTC] Scheduling reconnect attempt $_reconnectAttempts in ${clampedDelay}ms');

    _reconnectTimer = Timer(Duration(milliseconds: clampedDelay), () {
      if (!_intentionalClose) {
        _logger.log('[SendspinWebRTC] Attempting reconnect...');
        connect().catchError((e) {
          _logger.log('[SendspinWebRTC] Reconnect failed: $e');
        });
      }
    });
  }

  void _clearReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _cleanup() {
    _dataChannel?.close();
    _dataChannel = null;

    _peerConnection?.close();
    _peerConnection = null;

    _iceCandidateBuffer.clear();
    _remoteDescriptionSet = false;
  }

  void _setState(SendspinWebRTCState newState) {
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  /// Dispose all resources
  void dispose() {
    disconnect();
    _stateController.close();
    _textMessageController.close();
    _binaryMessageController.close();
    _errorController.close();
  }
}
