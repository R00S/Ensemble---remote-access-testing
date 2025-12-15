import 'dart:async';
import 'dart:typed_data';
import 'package:raw_sound/raw_sound_player.dart';
import 'debug_logger.dart';

/// Audio format configuration matching Sendspin protocol
class PcmAudioFormat {
  final int sampleRate;
  final int channels;
  final int bitDepth;

  const PcmAudioFormat({
    this.sampleRate = 48000,
    this.channels = 2,
    this.bitDepth = 16,
  });

  /// Default Sendspin format: 48kHz, stereo, 16-bit PCM
  static const sendspin = PcmAudioFormat();
}

/// Player state for PCM audio
enum PcmPlayerState {
  idle,
  initializing,
  ready,
  playing,
  paused,
  error,
}

/// Service to play raw PCM audio data from Sendspin WebSocket stream
/// Uses raw_sound plugin for low-level PCM playback
class PcmAudioPlayer {
  final _logger = DebugLogger();

  RawSoundPlayer? _player;
  PcmPlayerState _state = PcmPlayerState.idle;
  PcmAudioFormat _format = PcmAudioFormat.sendspin;

  StreamSubscription<Uint8List>? _audioSubscription;

  // Audio buffer for smooth playback
  final List<Uint8List> _audioBuffer = [];
  bool _isFeeding = false;

  // Stats
  int _framesPlayed = 0;
  int _bytesPlayed = 0;

  PcmPlayerState get state => _state;
  bool get isPlaying => _state == PcmPlayerState.playing;
  bool get isReady => _state == PcmPlayerState.ready || _state == PcmPlayerState.playing || _state == PcmPlayerState.paused;
  int get framesPlayed => _framesPlayed;
  int get bytesPlayed => _bytesPlayed;

  /// Initialize the PCM player with the given format
  Future<bool> initialize({PcmAudioFormat? format}) async {
    if (_state == PcmPlayerState.initializing) return false;

    _format = format ?? PcmAudioFormat.sendspin;
    _state = PcmPlayerState.initializing;

    try {
      _logger.log('PcmAudioPlayer: Initializing (${_format.sampleRate}Hz, ${_format.channels}ch, ${_format.bitDepth}bit)');

      _player = RawSoundPlayer();

      // Initialize with Sendspin audio format
      // Buffer size: larger buffer for network jitter tolerance
      await _player!.initialize(
        bufferSize: 4096 << 4,  // ~65KB buffer for smooth streaming
        nChannels: _format.channels,
        sampleRate: _format.sampleRate,
        pcmType: _format.bitDepth == 16 ? RawSoundPCMType.PCMI16 : RawSoundPCMType.PCMF32,
      );

      _state = PcmPlayerState.ready;
      _logger.log('PcmAudioPlayer: Initialized successfully');
      return true;
    } catch (e) {
      _logger.log('PcmAudioPlayer: Initialization failed: $e');
      _state = PcmPlayerState.error;
      return false;
    }
  }

  /// Connect to a Sendspin audio data stream and start playback
  Future<bool> connectToStream(Stream<Uint8List> audioStream) async {
    if (_player == null) {
      _logger.log('PcmAudioPlayer: Cannot connect - player not initialized');
      return false;
    }

    // Cancel any existing subscription
    await _audioSubscription?.cancel();

    _logger.log('PcmAudioPlayer: Connecting to audio stream');

    // Subscribe to the audio stream
    _audioSubscription = audioStream.listen(
      _onAudioData,
      onError: _onStreamError,
      onDone: _onStreamDone,
    );

    return true;
  }

  /// Handle incoming audio data from the stream
  void _onAudioData(Uint8List audioData) {
    if (_state == PcmPlayerState.error) return;

    // Add to buffer
    _audioBuffer.add(audioData);

    // Start feeding if not already doing so
    if (!_isFeeding) {
      _startFeeding();
    }
  }

  /// Start the audio feeding loop
  Future<void> _startFeeding() async {
    if (_isFeeding || _player == null) return;

    _isFeeding = true;

    try {
      // Start playback if not already playing
      if (_state == PcmPlayerState.ready) {
        await _player!.play();
        _state = PcmPlayerState.playing;
        _logger.log('PcmAudioPlayer: Started playback');
      }

      // Feed audio data from buffer
      while (_isFeeding && _state == PcmPlayerState.playing) {
        if (_audioBuffer.isEmpty) {
          // Wait a bit for more data
          await Future.delayed(const Duration(milliseconds: 10));
          continue;
        }

        final chunk = _audioBuffer.removeAt(0);
        await _player!.feed(chunk);

        _framesPlayed++;
        _bytesPlayed += chunk.length;

        // Log periodically
        if (_framesPlayed % 100 == 0) {
          _logger.log('PcmAudioPlayer: Played $_framesPlayed frames (${(_bytesPlayed / 1024).toStringAsFixed(1)} KB)');
        }
      }
    } catch (e) {
      _logger.log('PcmAudioPlayer: Error feeding audio: $e');
      _state = PcmPlayerState.error;
    }

    _isFeeding = false;
  }

  /// Handle stream errors
  void _onStreamError(dynamic error) {
    _logger.log('PcmAudioPlayer: Stream error: $error');
  }

  /// Handle stream completion
  void _onStreamDone() {
    _logger.log('PcmAudioPlayer: Audio stream ended');
    // Don't stop immediately - let buffered audio finish
  }

  /// Start playback (if paused)
  Future<void> play() async {
    if (_player == null || _state == PcmPlayerState.error) return;

    if (_state == PcmPlayerState.paused || _state == PcmPlayerState.ready) {
      await _player!.play();
      _state = PcmPlayerState.playing;
      _logger.log('PcmAudioPlayer: Resumed playback');

      // Resume feeding
      if (!_isFeeding && _audioBuffer.isNotEmpty) {
        _startFeeding();
      }
    }
  }

  /// Pause playback (preserves buffer)
  Future<void> pause() async {
    if (_player == null || _state != PcmPlayerState.playing) return;

    await _player!.pause();
    _state = PcmPlayerState.paused;
    _logger.log('PcmAudioPlayer: Paused playback');
  }

  /// Stop playback (clears buffer)
  Future<void> stop() async {
    if (_player == null) return;

    _isFeeding = false;
    _audioBuffer.clear();

    await _player!.stop();
    _state = PcmPlayerState.ready;
    _framesPlayed = 0;
    _bytesPlayed = 0;
    _logger.log('PcmAudioPlayer: Stopped playback');
  }

  /// Disconnect from audio stream
  Future<void> disconnect() async {
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await stop();
    _logger.log('PcmAudioPlayer: Disconnected from stream');
  }

  /// Release all resources
  Future<void> dispose() async {
    _isFeeding = false;
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    _audioBuffer.clear();

    if (_player != null) {
      await _player!.release();
      _player = null;
    }

    _state = PcmPlayerState.idle;
    _logger.log('PcmAudioPlayer: Disposed');
  }
}
