import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'debug_logger.dart';

/// Service to generate unique per-installation player IDs
/// Simplified to match KMP client pattern: single storage key, lazy generation
/// This prevents the critical bug where multiple devices of the same model
/// would share the same player ID and trigger playback on all devices
class DeviceIdService {
  static const String _keyLocalPlayerId = 'local_player_id';
  static final _logger = DebugLogger();
  static const _uuid = Uuid();

  /// Get or generate a unique player ID for this installation
  /// ID is generated once and persisted across app restarts
  /// Format: ensemble_<uuid>
  ///
  /// This matches the KMP client pattern: generate on first access, store once
  static Future<String> getOrCreateDevicePlayerId() async {
    final prefs = await SharedPreferences.getInstance();

    // Single source of truth - no complex migration logic
    final existingId = prefs.getString(_keyLocalPlayerId);
    if (existingId != null && existingId.startsWith('ensemble_')) {
      _logger.log('Using existing player ID: $existingId');
      return existingId;
    }

    // Generate new ID on first access
    final playerId = 'ensemble_${_uuid.v4()}';
    await prefs.setString(_keyLocalPlayerId, playerId);
    _logger.log('Generated new player ID: $playerId');
    return playerId;
  }

  /// Adopt an existing player ID (used when claiming a ghost player)
  static Future<void> adoptPlayerId(String playerId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocalPlayerId, playerId);
    _logger.log('Adopted player ID: $playerId');
  }

  /// Check if this is a fresh installation (no player ID stored yet)
  static Future<bool> isFreshInstallation() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLocalPlayerId) == null;
  }
}
