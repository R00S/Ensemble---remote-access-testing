import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/settings.dart';
import '../services/debug_logger.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _settingsKey = 'app_settings';
  final _logger = DebugLogger();

  AppSettings _settings = AppSettings();
  bool _isLoaded = false;

  AppSettings get settings => _settings;
  bool get isLoaded => _isLoaded;

  SettingsProvider() {
    _loadSettings();
  }

  /// Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_settingsKey);

      if (settingsJson != null) {
        final json = jsonDecode(settingsJson) as Map<String, dynamic>;
        _settings = AppSettings.fromJson(json);
        _logger.log('✓ Settings loaded: ${_settings.qualityDescription}');
      } else {
        _logger.log('Using default settings');
      }
    } catch (e) {
      _logger.log('⚠️ Error loading settings: $e. Using defaults.');
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  /// Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = jsonEncode(_settings.toJson());
      await prefs.setString(_settingsKey, settingsJson);
      _logger.log('✓ Settings saved');
    } catch (e) {
      _logger.log('❌ Error saving settings: $e');
    }
  }

  /// Update audio quality
  Future<void> setAudioQuality(AudioQuality quality) async {
    _settings = _settings.copyWith(audioQuality: quality);
    notifyListeners();
    await _saveSettings();
    _logger.log('Audio quality set to: ${quality.displayName}');
  }

  /// Toggle lossless preference
  Future<void> setPreferLossless(bool prefer) async {
    _settings = _settings.copyWith(preferLossless: prefer);
    notifyListeners();
    await _saveSettings();
    _logger.log('Prefer lossless: $prefer');
  }

  /// Set max bitrate
  Future<void> setMaxBitrate(int bitrate) async {
    _settings = _settings.copyWith(maxBitrate: bitrate);
    notifyListeners();
    await _saveSettings();
    _logger.log('Max bitrate set to: $bitrate kbps');
  }

  /// Toggle cellular streaming
  Future<void> setCellularStreaming(bool enabled) async {
    _settings = _settings.copyWith(cellularStreaming: enabled);
    notifyListeners();
    await _saveSettings();
    _logger.log('Cellular streaming: $enabled');
  }

  /// Toggle download on cellular
  Future<void> setDownloadOnCellular(bool enabled) async {
    _settings = _settings.copyWith(downloadOnCellular: enabled);
    notifyListeners();
    await _saveSettings();
    _logger.log('Download on cellular: $enabled');
  }

  /// Toggle album art in mini player
  Future<void> setShowAlbumArtInMiniPlayer(bool show) async {
    _settings = _settings.copyWith(showAlbumArtInMiniPlayer: show);
    notifyListeners();
    await _saveSettings();
    _logger.log('Show album art in mini player: $show');
  }

  /// Toggle animations
  Future<void> setEnableAnimations(bool enabled) async {
    _settings = _settings.copyWith(enableAnimations: enabled);
    notifyListeners();
    await _saveSettings();
    _logger.log('Animations: $enabled');
  }

  /// Reset to default settings
  Future<void> resetToDefaults() async {
    _settings = AppSettings();
    notifyListeners();
    await _saveSettings();
    _logger.log('Settings reset to defaults');
  }
}
