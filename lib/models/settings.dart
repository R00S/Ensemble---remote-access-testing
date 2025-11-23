/// User settings for the Music Assistant app
class AppSettings {
  // Playback quality settings
  final AudioQuality audioQuality;
  final bool preferLossless;
  final int maxBitrate; // in kbps

  // Network settings
  final bool cellularStreaming;
  final bool downloadOnCellular;

  // UI settings
  final bool showAlbumArtInMiniPlayer;
  final bool enableAnimations;

  AppSettings({
    this.audioQuality = AudioQuality.high,
    this.preferLossless = true,
    this.maxBitrate = 320,
    this.cellularStreaming = true,
    this.downloadOnCellular = false,
    this.showAlbumArtInMiniPlayer = true,
    this.enableAnimations = true,
  });

  AppSettings copyWith({
    AudioQuality? audioQuality,
    bool? preferLossless,
    int? maxBitrate,
    bool? cellularStreaming,
    bool? downloadOnCellular,
    bool? showAlbumArtInMiniPlayer,
    bool? enableAnimations,
  }) {
    return AppSettings(
      audioQuality: audioQuality ?? this.audioQuality,
      preferLossless: preferLossless ?? this.preferLossless,
      maxBitrate: maxBitrate ?? this.maxBitrate,
      cellularStreaming: cellularStreaming ?? this.cellularStreaming,
      downloadOnCellular: downloadOnCellular ?? this.downloadOnCellular,
      showAlbumArtInMiniPlayer: showAlbumArtInMiniPlayer ?? this.showAlbumArtInMiniPlayer,
      enableAnimations: enableAnimations ?? this.enableAnimations,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'audioQuality': audioQuality.name,
      'preferLossless': preferLossless,
      'maxBitrate': maxBitrate,
      'cellularStreaming': cellularStreaming,
      'downloadOnCellular': downloadOnCellular,
      'showAlbumArtInMiniPlayer': showAlbumArtInMiniPlayer,
      'enableAnimations': enableAnimations,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      audioQuality: AudioQuality.values.firstWhere(
        (q) => q.name == json['audioQuality'],
        orElse: () => AudioQuality.high,
      ),
      preferLossless: json['preferLossless'] as bool? ?? true,
      maxBitrate: json['maxBitrate'] as int? ?? 320,
      cellularStreaming: json['cellularStreaming'] as bool? ?? true,
      downloadOnCellular: json['downloadOnCellular'] as bool? ?? false,
      showAlbumArtInMiniPlayer: json['showAlbumArtInMiniPlayer'] as bool? ?? true,
      enableAnimations: json['enableAnimations'] as bool? ?? true,
    );
  }

  // Get a description of the current quality setting
  String get qualityDescription {
    if (preferLossless) {
      return 'Lossless (FLAC)';
    }
    switch (audioQuality) {
      case AudioQuality.low:
        return 'Low (96 kbps)';
      case AudioQuality.normal:
        return 'Normal (128 kbps)';
      case AudioQuality.high:
        return 'High (256 kbps)';
      case AudioQuality.veryHigh:
        return 'Very High ($maxBitrate kbps)';
    }
  }

  // Get the target bitrate based on quality setting
  int get targetBitrate {
    if (preferLossless) {
      return 1411; // CD quality
    }
    switch (audioQuality) {
      case AudioQuality.low:
        return 96;
      case AudioQuality.normal:
        return 128;
      case AudioQuality.high:
        return 256;
      case AudioQuality.veryHigh:
        return maxBitrate;
    }
  }
}

enum AudioQuality {
  low,
  normal,
  high,
  veryHigh;

  String get displayName {
    switch (this) {
      case AudioQuality.low:
        return 'Low';
      case AudioQuality.normal:
        return 'Normal';
      case AudioQuality.high:
        return 'High';
      case AudioQuality.veryHigh:
        return 'Very High';
    }
  }

  String get description {
    switch (this) {
      case AudioQuality.low:
        return '96 kbps - Save data';
      case AudioQuality.normal:
        return '128 kbps - Good quality';
      case AudioQuality.high:
        return '256 kbps - Great quality';
      case AudioQuality.veryHigh:
        return '320 kbps - Best quality';
    }
  }
}
