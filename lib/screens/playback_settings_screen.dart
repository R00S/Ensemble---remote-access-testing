import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/settings.dart';
import '../providers/settings_provider.dart';

class PlaybackSettingsScreen extends StatelessWidget {
  const PlaybackSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      appBar: AppBar(
        title: const Text('Playback Settings'),
        backgroundColor: const Color(0xFF1a1a1a),
        elevation: 0,
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          if (!settingsProvider.isLoaded) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          final settings = settingsProvider.settings;

          return ListView(
            children: [
              // Audio Quality Section
              _buildSectionHeader('Audio Quality'),
              _buildSwitchTile(
                title: 'Prefer Lossless',
                subtitle: 'Use FLAC when available',
                value: settings.preferLossless,
                onChanged: (value) {
                  settingsProvider.setPreferLossless(value);
                },
              ),
              if (!settings.preferLossless) ...[
                _buildListTile(
                  title: 'Quality',
                  subtitle: settings.audioQuality.description,
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white70),
                  onTap: () {
                    _showQualityPicker(context, settingsProvider);
                  },
                ),
                if (settings.audioQuality == AudioQuality.veryHigh)
                  _buildSliderTile(
                    title: 'Max Bitrate',
                    subtitle: '${settings.maxBitrate} kbps',
                    value: settings.maxBitrate.toDouble(),
                    min: 128,
                    max: 320,
                    divisions: 4,
                    onChanged: (value) {
                      settingsProvider.setMaxBitrate(value.round());
                    },
                  ),
              ],
              const Divider(color: Colors.white12, height: 32),

              // Network Section
              _buildSectionHeader('Network'),
              _buildSwitchTile(
                title: 'Stream on Cellular',
                subtitle: 'Allow streaming over mobile data',
                value: settings.cellularStreaming,
                onChanged: (value) {
                  settingsProvider.setCellularStreaming(value);
                },
              ),
              _buildSwitchTile(
                title: 'Download on Cellular',
                subtitle: 'Allow downloads over mobile data',
                value: settings.downloadOnCellular,
                onChanged: (value) {
                  settingsProvider.setDownloadOnCellular(value);
                },
              ),
              const Divider(color: Colors.white12, height: 32),

              // Appearance Section
              _buildSectionHeader('Appearance'),
              _buildSwitchTile(
                title: 'Album Art in Mini Player',
                subtitle: 'Show artwork in now playing bar',
                value: settings.showAlbumArtInMiniPlayer,
                onChanged: (value) {
                  settingsProvider.setShowAlbumArtInMiniPlayer(value);
                },
              ),
              _buildSwitchTile(
                title: 'Enable Animations',
                subtitle: 'Smooth transitions and effects',
                value: settings.enableAnimations,
                onChanged: (value) {
                  settingsProvider.setEnableAnimations(value);
                },
              ),
              const Divider(color: Colors.white12, height: 32),

              // Actions Section
              _buildSectionHeader('Actions'),
              _buildListTile(
                title: 'Reset to Defaults',
                subtitle: 'Restore default settings',
                trailing: const Icon(Icons.restore, size: 20, color: Colors.white70),
                onTap: () {
                  _showResetDialog(context, settingsProvider);
                },
              ),

              const SizedBox(height: 32),

              // Current Quality Display
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.high_quality_rounded,
                        color: Colors.white70,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Current Quality',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        settings.qualityDescription,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 80), // Space for mini player
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.grey[400],
          fontSize: 14,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: Colors.white,
      activeTrackColor: Colors.white.withOpacity(0.3),
    );
  }

  Widget _buildListTile({
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.grey[400],
          fontSize: 14,
        ),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }

  Widget _buildSliderTile({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white.withOpacity(0.3),
            thumbColor: Colors.white,
            overlayColor: Colors.white.withOpacity(0.2),
            valueIndicatorColor: Colors.white,
            valueIndicatorTextStyle: const TextStyle(
              color: Color(0xFF1a1a1a),
            ),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: '${value.round()} kbps',
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  void _showQualityPicker(BuildContext context, SettingsProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2a2a2a),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Audio Quality',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...AudioQuality.values.map((quality) {
                final isSelected = provider.settings.audioQuality == quality;
                return ListTile(
                  title: Text(
                    quality.displayName,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    quality.description,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                  onTap: () {
                    provider.setAudioQuality(quality);
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showResetDialog(BuildContext context, SettingsProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2a2a2a),
          title: const Text(
            'Reset Settings',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to reset all playback settings to their default values?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () {
                provider.resetToDefaults();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Settings reset to defaults'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text(
                'Reset',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}
