/// Remote Access Manager
///
/// Non-invasive manager for Remote Access ID connections.
/// This is a SEPARATE, OPTIONAL service that works alongside the existing
/// connection system without modifying it.
///
/// Integration approach:
/// - Does NOT modify MusicAssistantAPI
/// - Does NOT reimplement authentication
/// - Does NOT touch existing ConnectionProvider
/// - Simply provides a WebRTC transport that can be used as a drop-in replacement
///   for the WebSocket URL when connecting in "remote mode"
///
/// Usage:
/// 1. User scans QR code or enters Remote ID
/// 2. RemoteAccessManager establishes WebRTC connection
/// 3. Manager provides a "virtual WebSocket URL" that routes through WebRTC
/// 4. Existing MusicAssistantAPI.connect() is called with this special URL
/// 5. Everything else works exactly the same

import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'webrtc_transport.dart';
import 'websocket_bridge_transport.dart';
import 'transport.dart';
import '../debug_logger.dart';

/// Connection mode for the app
enum ConnectionMode {
  local,   // Direct WebSocket to MA server
  remote,  // WebRTC via signaling server
}

/// Remote Access Manager State
enum RemoteAccessState {
  disabled,      // Remote access not in use
  connecting,    // Establishing WebRTC connection
  connected,     // WebRTC connected, ready for MA API
  failed,        // Connection failed
}

/// Storage keys for remote access settings
class _RemoteAccessKeys {
  static const String enabled = 'remote_access_enabled';
  static const String remoteId = 'remote_access_id';
  static const String connectionMode = 'remote_access_mode';
  static const String signalingServer = 'remote_access_signaling_server';
}

/// Default signaling server URL (Music Assistant official)
const String kDefaultSignalingServer = 'wss://signaling.music-assistant.io/ws';

/// Remote Access Manager
/// 
/// This manager is completely optional and self-contained.
/// It provides WebRTC connectivity but does NOT reimplement any existing functionality.
class RemoteAccessManager {
  static final RemoteAccessManager instance = RemoteAccessManager._();
  RemoteAccessManager._();

  final _logger = DebugLogger();
  
  RemoteAccessState _state = RemoteAccessState.disabled;
  ITransport? _transport;
  String? _currentRemoteId;
  String _signalingServer = kDefaultSignalingServer;

  final _stateController = StreamController<RemoteAccessState>.broadcast();

  /// Current state
  RemoteAccessState get state => _state;
  
  /// State change stream
  Stream<RemoteAccessState> get stateStream => _stateController.stream;

  /// Is remote access currently active?
  bool get isRemoteMode => _state == RemoteAccessState.connected;

  /// Get the current remote ID (if connected)
  String? get remoteId => _currentRemoteId;

  /// Get the transport (for integration with existing API)
  ITransport? get transport => _transport;

  /// Initialize from stored settings
  Future<void> initialize() async {
    _logger.log('[RemoteAccess] Initializing...');
    
    // Load saved settings directly from SharedPreferences (non-invasive)
    final prefs = await SharedPreferences.getInstance();
    final savedRemoteId = prefs.getString(_RemoteAccessKeys.remoteId);
    final savedMode = prefs.getString(_RemoteAccessKeys.connectionMode);
    final savedServer = prefs.getString(_RemoteAccessKeys.signalingServer);

    if (savedServer != null) {
      _signalingServer = savedServer;
    }

    _logger.log('[RemoteAccess] Saved mode: $savedMode, Remote ID: ${savedRemoteId != null ? "present" : "none"}');

    // If we were in remote mode, prepare for reconnection
    if (savedMode == 'remote' && savedRemoteId != null) {
      _currentRemoteId = savedRemoteId;
      _logger.log('[RemoteAccess] Ready to reconnect to Remote ID: $_currentRemoteId');
    }
  }

  /// Connect using Remote Access ID
  /// Returns a transport that can be used by the existing MusicAssistantAPI
  Future<ITransport> connectWithRemoteId(String remoteId) async {
    _logger.log('[RemoteAccess] Connecting with Remote ID: $remoteId');
    _setState(RemoteAccessState.connecting);

    try {
      // Normalize Remote ID (remove spaces, dashes, uppercase)
      final normalizedId = _normalizeRemoteId(remoteId);
      _logger.log('[RemoteAccess] Normalized ID: $normalizedId');

      // Create WebRTC transport
      final webrtcTransport = WebRTCTransport(
        WebRTCTransportOptions(
          signalingServerUrl: _signalingServer,
          remoteId: normalizedId,
          reconnect: true,
        ),
      );

      // Wrap in bridge to make it look like a WebSocket
      final bridgeTransport = WebSocketBridgeTransport(webrtcTransport);

      // Connect
      await bridgeTransport.connect();

      // Success - save state
      _transport = bridgeTransport;
      _currentRemoteId = normalizedId;
      _setState(RemoteAccessState.connected);

      // Persist settings
      await _saveSettings(ConnectionMode.remote, normalizedId);

      _logger.log('[RemoteAccess] Connected successfully');
      return bridgeTransport;
    } catch (e) {
      _logger.log('[RemoteAccess] Connection failed: $e');
      _setState(RemoteAccessState.failed);
      rethrow;
    }
  }

  /// Disconnect remote access (switch back to local mode)
  Future<void> disconnect() async {
    _logger.log('[RemoteAccess] Disconnecting');
    
    _transport?.disconnect();
    _transport?.dispose();
    _transport = null;
    _currentRemoteId = null;
    
    _setState(RemoteAccessState.disabled);
    
    // Clear remote mode from settings
    await _saveSettings(ConnectionMode.local, null);
  }

  /// Set custom signaling server URL (for testing/development)
  Future<void> setSignalingServer(String url) async {
    _signalingServer = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_RemoteAccessKeys.signalingServer, url);
    _logger.log('[RemoteAccess] Signaling server set to: $url');
  }

  /// Normalize Remote Access ID
  /// Removes spaces, dashes, converts to uppercase
  String _normalizeRemoteId(String id) {
    return id
        .replaceAll(' ', '')
        .replaceAll('-', '')
        .toUpperCase()
        .trim();
  }

  /// Save connection mode and remote ID
  Future<void> _saveSettings(ConnectionMode mode, String? remoteId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _RemoteAccessKeys.connectionMode,
      mode == ConnectionMode.remote ? 'remote' : 'local',
    );
    
    if (remoteId != null) {
      await prefs.setString(_RemoteAccessKeys.remoteId, remoteId);
    } else {
      await prefs.remove(_RemoteAccessKeys.remoteId);
    }
  }

  /// Get saved connection mode
  Future<ConnectionMode> getSavedMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_RemoteAccessKeys.connectionMode);
    return saved == 'remote' ? ConnectionMode.remote : ConnectionMode.local;
  }

  /// Get saved Remote ID
  Future<String?> getSavedRemoteId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_RemoteAccessKeys.remoteId);
  }

  void _setState(RemoteAccessState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  void dispose() {
    _transport?.dispose();
    _stateController.close();
  }
}
