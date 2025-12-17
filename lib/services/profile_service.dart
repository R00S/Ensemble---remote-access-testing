import 'database_service.dart';
import 'settings_service.dart';
import 'debug_logger.dart';
import '../database/database.dart';

/// Service for managing user profiles
/// Profiles are auto-created from MA authentication or manual name entry
class ProfileService {
  static ProfileService? _instance;
  static final _logger = DebugLogger();

  ProfileService._();

  /// Get the singleton instance
  static ProfileService get instance {
    _instance ??= ProfileService._();
    return _instance!;
  }

  DatabaseService get _db => DatabaseService.instance;

  /// Get the currently active profile
  Future<Profile?> getActiveProfile() async {
    if (!_db.isInitialized) return null;
    return _db.getActiveProfile();
  }

  /// Get the active profile's username/name
  Future<String?> getActiveProfileName() async {
    final profile = await getActiveProfile();
    return profile?.displayName ?? profile?.username;
  }

  /// Called after successful MA authentication
  /// Creates or activates profile based on MA user info
  Future<Profile> onMaAuthenticated({
    required String username,
    String? displayName,
  }) async {
    _logger.log('MA authenticated: username=$username, displayName=$displayName');

    final profile = await _db.setActiveProfile(
      username: username,
      displayName: displayName,
      source: 'ma_auth',
    );

    _logger.log('Profile activated: ${profile.username} (${profile.displayName})');
    return profile;
  }

  /// Called when user manually enters their name (no MA auth)
  /// Creates or activates profile based on entered name
  Future<Profile> onManualNameEntered(String name) async {
    _logger.log('Manual name entered: $name');

    // Use name as both username and display name for manual profiles
    final profile = await _db.setActiveProfile(
      username: name.toLowerCase().replaceAll(' ', '_'),
      displayName: name,
      source: 'manual',
    );

    _logger.log('Profile activated: ${profile.username} (${profile.displayName})');
    return profile;
  }

  /// Migrate existing ownerName to profile (one-time migration)
  Future<void> migrateFromOwnerName() async {
    if (!_db.isInitialized) return;

    // Check if we already have any profiles
    final profiles = await _db.getAllProfiles();
    if (profiles.isNotEmpty) {
      _logger.log('Migration skipped - profiles already exist');
      return;
    }

    // Check for existing ownerName in settings
    final ownerName = await SettingsService.getOwnerName();
    if (ownerName == null || ownerName.isEmpty) {
      _logger.log('Migration skipped - no ownerName to migrate');
      return;
    }

    _logger.log('Migrating ownerName "$ownerName" to profile...');

    // Create profile from ownerName
    // We don't know if it was MA auth or manual, so default to manual
    await _db.setActiveProfile(
      username: ownerName.toLowerCase().replaceAll(' ', '_'),
      displayName: ownerName,
      source: 'migrated',
    );

    _logger.log('Migration complete');
  }

  /// Get all profiles (for potential profile switcher UI)
  Future<List<Profile>> getAllProfiles() async {
    if (!_db.isInitialized) return [];
    return _db.getAllProfiles();
  }

  /// Check if any profile exists
  Future<bool> hasAnyProfile() async {
    final profiles = await getAllProfiles();
    return profiles.isNotEmpty;
  }
}
